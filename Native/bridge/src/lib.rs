#![allow(non_snake_case)]
//! BG3 Access native bridge, loaded into the game by the version.dll proxy (or any native loader).
//! Owns Prism (speech) and receives messages from the Lua half (see channel.rs). It hooks only an OS
//! API (CreateFileW), nothing game-specific, so it has no game-build dependency.

mod channel;
mod log;
mod mouse;
mod paths;
mod speech;
mod watchdog;

use std::ffi::c_void;
use windows_sys::Win32::Foundation::HMODULE;
use windows_sys::Win32::System::LibraryLoader::DisableThreadLibraryCalls;
use windows_sys::Win32::System::SystemServices::DLL_PROCESS_ATTACH;
use windows_sys::Win32::System::Threading::CreateThread;

pub const VERSION: &str = env!("CARGO_PKG_VERSION");

static mut SELF: HMODULE = std::ptr::null_mut();

/// `BG3Access/bridge_status.txt`: the bridge's answer to the Lua half (read with Ext.IO.LoadFile).
pub fn write_status(extra: &str) {
    let path = paths::mod_io_dir().join("bridge_status.txt");
    let body = format!("bridge {VERSION}\nbackend {}\n{extra}\n", speech::backend_name());
    let _ = std::fs::write(path, body);
}

unsafe extern "system" fn init(_: *mut c_void) -> u32 {
    let _ = std::fs::create_dir_all(paths::mod_io_dir().join("bridge"));
    log::init();
    log::info(&format!("BG3 Access bridge {VERSION} starting"));
    let dir = paths::bridge_dir(SELF);
    speech::start(&dir);
    match channel::start() {
        Ok(()) => log::info("channel hook installed (KernelBase!CreateFileW)"),
        Err(e) => log::info(&format!("channel hook FAILED: {e}")),
    }
    write_status("ready");
    watchdog::start();
    0
}

#[no_mangle]
#[allow(non_snake_case)]
pub unsafe extern "system" fn DllMain(module: HMODULE, reason: u32, _: *mut c_void) -> i32 {
    if reason == DLL_PROCESS_ATTACH {
        SELF = module;
        DisableThreadLibraryCalls(module);
        CreateThread(std::ptr::null(), 0, Some(init), std::ptr::null(), 0, std::ptr::null_mut());
    }
    1
}
