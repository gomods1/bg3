//! Cursor warp and clicks for the activation ladder's last rung (gate.md 5.5). Positions are fractions
//! of the game window's client area, so the Lua side needs no knowledge of the resolution. The Lua
//! side verifies the hover (IsMouseOver / picking helper) between `move` and `click`.

use windows_sys::core::BOOL;
use windows_sys::Win32::Foundation::{HWND, LPARAM, POINT, RECT};
use windows_sys::Win32::Graphics::Gdi::ClientToScreen;
use windows_sys::Win32::System::Threading::GetCurrentProcessId;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_MOUSE, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_RIGHTDOWN,
    MOUSEEVENTF_RIGHTUP, MOUSEINPUT,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    EnumWindows, GetClientRect, GetForegroundWindow, GetWindowThreadProcessId, IsWindowVisible, SetCursorPos,
};

struct Found {
    hwnd: HWND,
    area: i64,
}

unsafe extern "system" fn enum_cb(hwnd: HWND, lparam: LPARAM) -> BOOL {
    let found = &mut *(lparam as *mut Found);
    let mut pid = 0u32;
    GetWindowThreadProcessId(hwnd, &mut pid);
    if pid == GetCurrentProcessId() && IsWindowVisible(hwnd) != 0 {
        let mut r: RECT = std::mem::zeroed();
        GetClientRect(hwnd, &mut r);
        let area = (r.right as i64) * (r.bottom as i64);
        if area > found.area {
            found.hwnd = hwnd;
            found.area = area;
        }
    }
    1
}

/// The game's main window: the largest visible window of this process.
fn game_window() -> Option<HWND> {
    let mut found = Found { hwnd: std::ptr::null_mut(), area: 0 };
    unsafe { EnumWindows(Some(enum_cb), &mut found as *mut Found as LPARAM) };
    if found.hwnd.is_null() { None } else { Some(found.hwnd) }
}

fn foreground_is_game(hwnd: HWND) -> bool {
    unsafe { GetForegroundWindow() == hwnd }
}

pub fn move_to(fx: f64, fy: f64) -> Result<(), String> {
    let hwnd = game_window().ok_or("no game window")?;
    if !foreground_is_game(hwnd) {
        return Err("game window is not in the foreground".into());
    }
    unsafe {
        let mut r: RECT = std::mem::zeroed();
        GetClientRect(hwnd, &mut r);
        // Keep away from the edges so the camera never edge-scrolls.
        let fx = fx.clamp(0.02, 0.98);
        let fy = fy.clamp(0.02, 0.98);
        let mut p = POINT { x: (r.right as f64 * fx) as i32, y: (r.bottom as f64 * fy) as i32 };
        ClientToScreen(hwnd, &mut p);
        SetCursorPos(p.x, p.y);
    }
    Ok(())
}

pub fn click(right: bool) -> Result<(), String> {
    let hwnd = game_window().ok_or("no game window")?;
    if !foreground_is_game(hwnd) {
        return Err("game window is not in the foreground".into());
    }
    let (down, up) = if right { (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP) } else { (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP) };
    let make = |flags| INPUT {
        r#type: INPUT_MOUSE,
        Anonymous: INPUT_0 { mi: MOUSEINPUT { dx: 0, dy: 0, mouseData: 0, dwFlags: flags, time: 0, dwExtraInfo: 0 } },
    };
    let inputs = [make(down), make(up)];
    unsafe { SendInput(inputs.len() as u32, inputs.as_ptr(), std::mem::size_of::<INPUT>() as i32) };
    Ok(())
}
