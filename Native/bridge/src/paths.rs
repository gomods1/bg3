use std::path::PathBuf;

/// `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\BG3Access`: the folder the Lua half
/// reaches with `Ext.IO.SaveFile("BG3Access/...")` / `LoadFile`.
pub fn mod_io_dir() -> PathBuf {
    let base = std::env::var_os("LOCALAPPDATA").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("."));
    base.join("Larian Studios").join("Baldur's Gate 3").join("Script Extender").join("BG3Access")
}

/// Folder holding this DLL (`bin\BG3Access`), where prism.dll lives.
pub fn bridge_dir(module: windows_sys::Win32::Foundation::HMODULE) -> PathBuf {
    use windows_sys::Win32::System::LibraryLoader::GetModuleFileNameW;
    let mut buf = [0u16; 1024];
    let n = unsafe { GetModuleFileNameW(module, buf.as_mut_ptr(), buf.len() as u32) } as usize;
    let p = PathBuf::from(String::from_utf16_lossy(&buf[..n]));
    p.parent().map(|d| d.to_path_buf()).unwrap_or_default()
}
