//! The only code that touches Prism. One worker thread owns the backend (a Prism backend is not
//! thread-safe); everything else enqueues.

use std::collections::VecDeque;
use std::ffi::{c_char, c_void, CStr, CString};
use std::path::Path;
use std::sync::{Condvar, Mutex};
use std::time::{Duration, Instant};

use windows_sys::Win32::System::LibraryLoader::{GetProcAddress, LoadLibraryExW, LOAD_WITH_ALTERED_SEARCH_PATH};

const FEATURE_SUPPORTS_OUTPUT: u64 = 1 << 5;

type InitFn = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
type CreateBestFn = unsafe extern "C" fn(*mut c_void) -> *mut c_void;
type BackendFreeFn = unsafe extern "C" fn(*mut c_void);
type BackendNameFn = unsafe extern "C" fn(*mut c_void) -> *const c_char;
type FeaturesFn = unsafe extern "C" fn(*mut c_void) -> u64;
type SpeakFn = unsafe extern "C" fn(*mut c_void, *const c_char, bool) -> i32;
type StopFn = unsafe extern "C" fn(*mut c_void) -> i32;
type ErrorStringFn = unsafe extern "C" fn(i32) -> *const c_char;

struct Api {
    init: InitFn,
    create_best: CreateBestFn,
    backend_free: BackendFreeFn,
    backend_name: BackendNameFn,
    features: FeaturesFn,
    speak: SpeakFn,
    output: SpeakFn,
    stop: StopFn,
    error_string: ErrorStringFn,
}

enum Job {
    Say { text: String, interrupt: bool },
    Stop,
}

struct Queue {
    jobs: VecDeque<Job>,
}

static QUEUE: Mutex<Queue> = Mutex::new(Queue { jobs: VecDeque::new() });
static WAKE: Condvar = Condvar::new();
static BACKEND_NAME: Mutex<String> = Mutex::new(String::new());

pub fn backend_name() -> String {
    BACKEND_NAME.lock().unwrap().clone()
}

pub fn say(text: &str, interrupt: bool) {
    let text = text.trim();
    if text.is_empty() {
        return;
    }
    if interrupt {
        crate::log::spoken(&format!("! {text}"));
    } else {
        crate::log::spoken(text);
    }
    let mut q = QUEUE.lock().unwrap();
    if interrupt {
        q.jobs.clear();
    }
    q.jobs.push_back(Job::Say { text: text.to_string(), interrupt });
    WAKE.notify_one();
}

pub fn stop() {
    let mut q = QUEUE.lock().unwrap();
    q.jobs.clear();
    q.jobs.push_back(Job::Stop);
    WAKE.notify_one();
}

unsafe fn load_api(dir: &Path) -> Result<Api, String> {
    let path: Vec<u16> = dir.join("prism.dll").as_os_str().to_string_lossy().encode_utf16().chain([0]).collect();
    let dll = LoadLibraryExW(path.as_ptr(), std::ptr::null_mut(), LOAD_WITH_ALTERED_SEARCH_PATH);
    if dll.is_null() {
        return Err(format!("could not load {} (error {})", dir.join("prism.dll").display(),
            windows_sys::Win32::Foundation::GetLastError()));
    }
    macro_rules! sym {
        ($name:literal) => {{
            match GetProcAddress(dll, concat!($name, "\0").as_ptr()) {
                Some(f) => std::mem::transmute(f),
                None => return Err(format!("prism.dll is missing export {}", $name)),
            }
        }};
    }
    Ok(Api {
        init: sym!("prism_init"),
        create_best: sym!("prism_registry_create_best"),
        backend_free: sym!("prism_backend_free"),
        backend_name: sym!("prism_backend_name"),
        features: sym!("prism_backend_get_features"),
        speak: sym!("prism_backend_speak"),
        output: sym!("prism_backend_output"),
        stop: sym!("prism_backend_stop"),
        error_string: sym!("prism_error_string"),
    })
}

struct Worker {
    api: Api,
    ctx: *mut c_void,
    backend: *mut c_void,
    last_retry: Option<Instant>,
}

impl Worker {
    unsafe fn create_backend(&mut self) {
        if !self.backend.is_null() {
            (self.api.backend_free)(self.backend);
            self.backend = std::ptr::null_mut();
        }
        self.backend = (self.api.create_best)(self.ctx); // returned already initialized
        if self.backend.is_null() {
            crate::log::info("Prism found no working speech backend");
            return;
        }
        let name = CStr::from_ptr((self.api.backend_name)(self.backend)).to_string_lossy().into_owned();
        crate::log::info(&format!("speech backend: {name} (features 0x{:x})", (self.api.features)(self.backend)));
        *BACKEND_NAME.lock().unwrap() = name;
    }

    unsafe fn output(&mut self, text: &CString, interrupt: bool) -> i32 {
        if self.backend.is_null() {
            return -1;
        }
        if (self.api.features)(self.backend) & FEATURE_SUPPORTS_OUTPUT != 0 {
            (self.api.output)(self.backend, text.as_ptr(), interrupt)
        } else {
            (self.api.speak)(self.backend, text.as_ptr(), interrupt)
        }
    }

    unsafe fn say(&mut self, text: &str, interrupt: bool) {
        let Ok(c) = CString::new(text.replace('\0', " ")) else { return };
        let err = self.output(&c, interrupt);
        if err != 0 {
            let msg = if err > 0 { CStr::from_ptr((self.api.error_string)(err)).to_string_lossy().into_owned() } else { "no backend".into() };
            crate::log::info(&format!("Prism error {err} ({msg})"));
            // Picks up a screen reader started or restarted after the game.
            if self.last_retry.map_or(true, |t| t.elapsed() > Duration::from_secs(3)) {
                self.last_retry = Some(Instant::now());
                self.create_backend();
                self.output(&c, interrupt);
            }
        }
    }
}

pub fn start(dir: &Path) {
    let api = match unsafe { load_api(dir) } {
        Ok(api) => api,
        Err(e) => {
            crate::log::info(&format!("speech disabled: {e}"));
            return;
        }
    };
    std::thread::Builder::new()
        .name("bg3access-speech".into())
        .spawn(move || unsafe {
            let ctx = (api.init)(std::ptr::null_mut());
            if ctx.is_null() {
                crate::log::info("prism_init failed");
                return;
            }
            let mut w = Worker { api, ctx, backend: std::ptr::null_mut(), last_retry: None };
            w.create_backend();
            loop {
                let job = {
                    let mut q = QUEUE.lock().unwrap();
                    while q.jobs.is_empty() {
                        q = WAKE.wait(q).unwrap();
                    }
                    q.jobs.pop_front().unwrap()
                };
                match job {
                    Job::Say { text, interrupt } => w.say(&text, interrupt),
                    Job::Stop => {
                        if !w.backend.is_null() {
                            (w.api.stop)(w.backend);
                        }
                    }
                }
            }
        })
        .ok();
}
