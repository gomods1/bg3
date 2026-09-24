// Forward every export of the real version.dll by absolute path, so the game's calls go straight
// to System32 without any code of ours in between (the "perfect DLL proxy" technique).
const EXPORTS: &[&str] = &[
    "GetFileVersionInfoA", "GetFileVersionInfoByHandle", "GetFileVersionInfoExA", "GetFileVersionInfoExW",
    "GetFileVersionInfoSizeA", "GetFileVersionInfoSizeExA", "GetFileVersionInfoSizeExW",
    "GetFileVersionInfoSizeW", "GetFileVersionInfoW", "VerFindFileA", "VerFindFileW", "VerInstallFileA",
    "VerInstallFileW", "VerLanguageNameA", "VerLanguageNameW", "VerQueryValueA", "VerQueryValueW",
];

fn main() {
    for name in EXPORTS {
        println!(
            r"cargo:rustc-cdylib-link-arg=/EXPORT:{name}=\\.\GLOBALROOT\SystemRoot\System32\version.dll.{name}"
        );
    }
    println!("cargo:rerun-if-changed=build.rs");
}
