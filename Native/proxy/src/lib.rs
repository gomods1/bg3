//! `version.dll` proxy for Baldur's Gate 3. The game imports version.dll, so Windows loads this file
//! from `bin\` first. Every export is forwarded to System32 by the linker (see build.rs); the only
//! code here loads `bin\BG3Access\BG3AccessBridge.dll` on a new thread (not under the loader lock).

use std::ffi::c_void;
use windows_sys::Win32::Foundation::{HMODULE, MAX_PATH};
use windows_sys::Win32::System::LibraryLoader::{
    DisableThreadLibraryCalls, GetModuleFileNameW, LoadLibraryExW, LOAD_WITH_ALTERED_SEARCH_PATH,
};
use windows_sys::Win32::System::SystemServices::DLL_PROCESS_ATTACH;
use windows_sys::Win32::System::Threading::CreateThread;

static mut SELF: HMODULE = std::ptr::null_mut();

fn is_game_process() -> bool {
    let mut buf = [0u16; MAX_PATH as usize];
    let n = unsafe { GetModuleFileNameW(std::ptr::null_mut(), buf.as_mut_ptr(), buf.len() as u32) } as usize;
    let path = String::from_utf16_lossy(&buf[..n]).to_ascii_lowercase();
    path.ends_with("\\bg3.exe") || path.ends_with("\\bg3_dx11.exe")
}

unsafe extern "system" fn load_bridge(_: *mut c_void) -> u32 {
    let mut buf = [0u16; MAX_PATH as usize];
    let n = GetModuleFileNameW(SELF, buf.as_mut_ptr(), buf.len() as u32) as usize;
    let me = String::from_utf16_lossy(&buf[..n]);
    let dir = me.rsplit_once('\\').map(|(d, _)| d).unwrap_or(".");
    let bridge: Vec<u16> = format!("{dir}\\BG3Access\\BG3AccessBridge.dll").encode_utf16().chain([0]).collect();
    // LOAD_WITH_ALTERED_SEARCH_PATH: prism.dll next to the bridge resolves from the bridge's folder.
    LoadLibraryExW(bridge.as_ptr(), std::ptr::null_mut(), LOAD_WITH_ALTERED_SEARCH_PATH);
    0
}

#[no_mangle]
#[allow(non_snake_case)]
pub unsafe extern "system" fn DllMain(module: HMODULE, reason: u32, _: *mut c_void) -> i32 {
    if reason == DLL_PROCESS_ATTACH {
        SELF = module;
        DisableThreadLibraryCalls(module);
        if is_game_process() {
            CreateThread(std::ptr::null(), 0, Some(load_bridge), std::ptr::null(), 0, std::ptr::null_mut());
        }
    }
    1
}
