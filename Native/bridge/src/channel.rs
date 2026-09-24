//! Lua -> native message channel.
//!
//! The Lua half calls `Ext.IO.SaveFile("BG3Access/bridge/out.msg", lines)`. The Script Extender
//! implements that with `std::ofstream`, i.e. `CreateFileW` + `WriteFile` + `CloseHandle`. We hook
//! `CreateFileW` in KernelBase: when that exact path is opened for writing, we return a duplicate of
//! the write end of one long-lived pipe instead of creating a file. The CRT writes the text into the
//! pipe and closes the duplicate; our reader thread gets the bytes in order, with no disk I/O and no
//! polling. Every other CreateFileW call goes straight to the original function.
//!
//! If the hook cannot be installed, SE writes a real (harmless, overwritten) file and the player
//! hears nothing; the bridge log says why.

use std::ffi::c_void;
use std::sync::atomic::{AtomicPtr, AtomicU64, Ordering};
use std::sync::OnceLock;
use std::time::Instant;

use retour::RawDetour;
use windows_sys::Win32::Foundation::{DuplicateHandle, DUPLICATE_SAME_ACCESS, GENERIC_WRITE, HANDLE};
use windows_sys::Win32::Storage::FileSystem::ReadFile;
use windows_sys::Win32::System::LibraryLoader::{GetModuleHandleW, GetProcAddress};
use windows_sys::Win32::System::Pipes::CreatePipe;
use windows_sys::Win32::System::Threading::GetCurrentProcess;

type CreateFileWFn = unsafe extern "system" fn(*const u16, u32, u32, *const c_void, u32, u32, HANDLE) -> HANDLE;

static ORIGINAL: AtomicPtr<c_void> = AtomicPtr::new(std::ptr::null_mut());
static PIPE_WRITE: AtomicPtr<c_void> = AtomicPtr::new(std::ptr::null_mut());
static OPENS: AtomicU64 = AtomicU64::new(0);
static DETOUR: OnceLock<RawDetour> = OnceLock::new();

/// Path suffix the Lua half writes to, compared case-insensitively with either slash.
const SUFFIX: &str = "script extender/bg3access/bridge/out.msg";

fn is_channel_path(p: *const u16) -> bool {
    if p.is_null() {
        return false;
    }
    let mut len = 0usize;
    unsafe {
        while *p.add(len) != 0 && len < 4096 {
            len += 1;
        }
    }
    let s = SUFFIX.as_bytes();
    if len < s.len() {
        return false;
    }
    let tail = unsafe { std::slice::from_raw_parts(p.add(len - s.len()), s.len()) };
    tail.iter().zip(s).all(|(&w, &b)| {
        let c = if w == b'\\' as u16 { b'/' as u16 } else { w };
        c < 128 && (c as u8).to_ascii_lowercase() == b
    })
}

unsafe extern "system" fn create_file_w_hook(
    name: *const u16, access: u32, share: u32, sa: *const c_void, disposition: u32, flags: u32, template: HANDLE,
) -> HANDLE {
    if access & GENERIC_WRITE != 0 && is_channel_path(name) {
        let pipe = PIPE_WRITE.load(Ordering::Acquire);
        let mut dup: HANDLE = std::ptr::null_mut();
        let me = GetCurrentProcess();
        if !pipe.is_null() && DuplicateHandle(me, pipe, me, &mut dup, 0, 0, DUPLICATE_SAME_ACCESS) != 0 {
            OPENS.fetch_add(1, Ordering::Relaxed);
            return dup;
        }
    }
    let original: CreateFileWFn = std::mem::transmute(ORIGINAL.load(Ordering::Acquire));
    original(name, access, share, sa, disposition, flags, template)
}

fn unescape(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut it = s.chars();
    while let Some(c) = it.next() {
        if c == '\\' {
            match it.next() {
                Some('n') => out.push('\n'),
                Some(other) => out.push(other),
                None => {}
            }
        } else {
            out.push(c);
        }
    }
    out
}

/// One message per line (see gate.md 4.3):
/// `say <interrupt 0|1> <channel> <ttlMs> <text>`, `stop`, `hello <modVersion>`, `log <text>`,
/// `mouse move <fx> <fy>` (fractions of the client area), `mouse click <left|right>`.
fn dispatch(line: &str) {
    let line = line.trim_end_matches('\r');
    let (cmd, rest) = line.split_once(' ').unwrap_or((line, ""));
    match cmd {
        "say" => {
            let mut parts = rest.splitn(4, ' ');
            let interrupt = parts.next() == Some("1");
            let _channel = parts.next();
            let _ttl = parts.next();
            let text = unescape(parts.next().unwrap_or(""));
            crate::speech::say(&text, interrupt);
        }
        "stop" => crate::speech::stop(),
        "hello" => {
            crate::log::info(&format!("hello from Lua: {rest}"));
            crate::write_status(&format!("hello {rest}"));
        }
        "log" => crate::log::info(&format!("lua: {}", unescape(rest))),
        "mouse" => {
            let args: Vec<&str> = rest.split(' ').collect();
            let result = match args.as_slice() {
                ["move", fx, fy] => match (fx.parse::<f64>(), fy.parse::<f64>()) {
                    (Ok(x), Ok(y)) => crate::mouse::move_to(x, y),
                    _ => Err("bad coordinates".into()),
                },
                ["click", button] => crate::mouse::click(*button == "right"),
                _ => Err(format!("bad mouse command '{rest}'")),
            };
            if let Err(e) = result {
                crate::log::info(&format!("mouse {rest}: {e}"));
            }
        }
        "" => {}
        other => crate::log::info(&format!("unknown message '{other}'")),
    }
}

fn reader(read: usize) {
    let read = read as HANDLE;
    let mut buf = vec![0u8; 64 * 1024];
    let mut pending: Vec<u8> = Vec::new();
    let started = Instant::now();
    let mut messages = 0u64;
    loop {
        let mut n = 0u32;
        let ok = unsafe { ReadFile(read, buf.as_mut_ptr(), buf.len() as u32, &mut n, std::ptr::null_mut()) };
        if ok == 0 || n == 0 {
            crate::log::info("channel pipe closed");
            return;
        }
        pending.extend_from_slice(&buf[..n as usize]);
        while let Some(pos) = pending.iter().position(|&b| b == b'\n') {
            let line: Vec<u8> = pending.drain(..=pos).collect();
            let text = String::from_utf8_lossy(&line[..line.len() - 1]);
            messages += 1;
            if messages <= 3 {
                crate::log::info(&format!("channel message {messages} at {} ms", started.elapsed().as_millis()));
            }
            dispatch(&text);
        }
    }
}

pub fn start() -> Result<(), String> {
    unsafe {
        let mut read: HANDLE = std::ptr::null_mut();
        let mut write: HANDLE = std::ptr::null_mut();
        if CreatePipe(&mut read, &mut write, std::ptr::null(), 1 << 20) == 0 {
            return Err("CreatePipe failed".into());
        }
        PIPE_WRITE.store(write, Ordering::Release);
        let r = read as usize;
        std::thread::Builder::new().name("bg3access-channel".into()).spawn(move || reader(r)).map_err(|e| e.to_string())?;

        // KernelBase, not kernel32: the CRT imports CreateFileW through api-ms-win-core-file, which
        // resolves to KernelBase and would bypass a hook on kernel32's stub.
        let kb: Vec<u16> = "kernelbase.dll".encode_utf16().chain([0]).collect();
        let module = GetModuleHandleW(kb.as_ptr());
        let target = GetProcAddress(module, b"CreateFileW\0".as_ptr()).ok_or("CreateFileW not found")?;
        let detour = RawDetour::new(target as *const (), create_file_w_hook as *const ()).map_err(|e| e.to_string())?;
        ORIGINAL.store(detour.trampoline() as *const () as *mut c_void, Ordering::Release);
        detour.enable().map_err(|e| e.to_string())?;
        let _ = DETOUR.set(detour);
    }
    Ok(())
}
