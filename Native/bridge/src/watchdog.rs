//! Tells the player when the Lua half never starts. The bridge loads with the game, the Lua half
//! only when the Script Extender loads the mod (about 20 s after launch). Known causes of silence:
//! the game skips every mod when `<profile>\ModCrashSanityCheck\` exists at launch (left behind by a
//! crash or a killed game; the game removes it at the main menu, so the next start works: verified
//! 2026-09-24), the Script Extender is missing or outdated, or the mod is not enabled.

use std::sync::atomic::{AtomicBool, Ordering};
use std::time::Duration;

static HELLO: AtomicBool = AtomicBool::new(false);

/// Measured: the Lua hello arrives 21-24 s after launch on the dev machine. Generous for slow disks.
const TIMEOUT: Duration = Duration::from_secs(90);

const MESSAGE: &str = "BG3 Access: the mod's scripts did not start, so menus and the game will not be read. \
The game skips all mods once after a crash or a forced close: quit with Alt F4 and start it again. \
If it keeps happening, run the BG3 Access installer again.";

/// Called by the channel for every `hello` from Lua.
pub fn hello() {
    HELLO.store(true, Ordering::Release);
}

pub fn start() {
    let _ = std::thread::Builder::new().name("bg3access-watchdog".into()).spawn(|| {
        std::thread::sleep(TIMEOUT);
        if !HELLO.load(Ordering::Acquire) {
            crate::log::info("no hello from Lua after 90 s: telling the player");
            crate::speech::say(MESSAGE, false);
        }
    });
}
