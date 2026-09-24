//! Bridge log (`logs/bridge.log`) and spoken-line log (`logs/speech.log`), both overwritten per launch.
//! The spoken-line log is the development "ears": every line handed to Prism, verbatim.

use std::fs::File;
use std::io::Write;
use std::sync::Mutex;
use std::time::Instant;

struct Logs {
    bridge: Option<File>,
    speech: Option<File>,
    start: Instant,
}

static LOGS: Mutex<Option<Logs>> = Mutex::new(None);

pub fn init() {
    let dir = crate::paths::mod_io_dir().join("logs");
    let _ = std::fs::create_dir_all(&dir);
    *LOGS.lock().unwrap() = Some(Logs {
        bridge: File::create(dir.join("bridge.log")).ok(),
        speech: File::create(dir.join("speech.log")).ok(),
        start: Instant::now(),
    });
}

fn write(speech: bool, line: &str) {
    if let Ok(mut guard) = LOGS.lock() {
        if let Some(logs) = guard.as_mut() {
            let ms = logs.start.elapsed().as_millis();
            let f = if speech { &mut logs.speech } else { &mut logs.bridge };
            if let Some(f) = f {
                let _ = writeln!(f, "{:>9} {}", ms, line);
                let _ = f.flush();
            }
        }
    }
}

pub fn info(line: &str) {
    write(false, line);
}

pub fn spoken(line: &str) {
    write(true, line);
}
