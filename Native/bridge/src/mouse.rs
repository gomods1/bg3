//! Cursor warp and clicks for the activation ladder's last rung (gate.md 5.5). Positions are fractions
//! of the game window's client area, so the Lua side needs no knowledge of the resolution. The Lua
//! side verifies the hover (IsMouseOver / picking helper) between `move` and `click`.
//!
//! The wake-up press (measured 2026-09-24, Jump armed in combat): after keyboard input the game
//! swallows the first mouse button press (the second always counted; pure motion, even over several
//! frames, did not help). So every click starts with a press of the X1 side button, which the game
//! binds to nothing (bindings dump: only left2, right2, middle and motion are bound), then the real
//! button. This also was the whole story behind an earlier "in-process input is ignored in combat"
//! finding: the process that injects does not matter.

use std::sync::Mutex;
use std::time::Duration;

use windows_sys::core::BOOL;
use windows_sys::Win32::Foundation::{HWND, LPARAM, POINT, RECT};
use windows_sys::Win32::Graphics::Gdi::ClientToScreen;
use windows_sys::Win32::System::Threading::GetCurrentProcessId;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    SendInput, INPUT, INPUT_0, INPUT_MOUSE, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_RIGHTDOWN,
    MOUSEEVENTF_RIGHTUP, MOUSEEVENTF_XDOWN, MOUSEEVENTF_XUP, MOUSEINPUT,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    EnumWindows, GetClientRect, GetForegroundWindow, GetWindowThreadProcessId, IsWindowVisible, SetCursorPos,
};

/// How long a button stays down (a few frames, so the game sees the press).
const CLICK_HOLD_MS: u64 = 60;
/// Pause between the wake-up press and the real click.
const WAKE_MS: u64 = 100;
const XBUTTON1: u32 = 1;

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

/// The game window, only while it is in the foreground (input must never land elsewhere).
fn foreground_game() -> Result<HWND, String> {
    let hwnd = game_window().ok_or("no game window")?;
    if unsafe { GetForegroundWindow() } != hwnd {
        return Err("game window is not in the foreground".into());
    }
    Ok(hwnd)
}

pub fn move_to(fx: f64, fy: f64) -> Result<(), String> {
    let hwnd = foreground_game()?;
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

/// Serializes clicks: a second click waits for the first sequence to finish.
static CLICKING: Mutex<()> = Mutex::new(());

/// Runs on its own thread so the channel reader (and speech) is never delayed by the pauses.
pub fn click(right: bool) -> Result<(), String> {
    foreground_game()?;
    let (down, up) = if right { (MOUSEEVENTF_RIGHTDOWN, MOUSEEVENTF_RIGHTUP) } else { (MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP) };
    std::thread::spawn(move || {
        let _guard = CLICKING.lock().unwrap_or_else(|e| e.into_inner());
        press(MOUSEEVENTF_XDOWN, MOUSEEVENTF_XUP, XBUTTON1);
        std::thread::sleep(Duration::from_millis(WAKE_MS));
        press(down, up, 0);
    });
    Ok(())
}

fn press(down: u32, up: u32, data: u32) {
    send(down, data);
    std::thread::sleep(Duration::from_millis(CLICK_HOLD_MS));
    send(up, data);
}

fn send(flags: u32, data: u32) {
    let input = INPUT {
        r#type: INPUT_MOUSE,
        Anonymous: INPUT_0 { mi: MOUSEINPUT { dx: 0, dy: 0, mouseData: data, dwFlags: flags, time: 0, dwExtraInfo: 0 } },
    };
    unsafe { SendInput(1, &input, std::mem::size_of::<INPUT>() as i32) };
}
