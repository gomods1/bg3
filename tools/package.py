"""Release package for players (gate.md section 16): dist/BG3Access-<version>/ and its .zip.

    python tools/package.py

Layout (install/install.ps1 expects it):
    README.md, install.bat, install.ps1, uninstall.bat, uninstall.ps1
    files/bin/version.dll                      proxy that loads the speech bridge
    files/bin/BG3Access/BG3AccessBridge.dll    native bridge
    files/bin/BG3Access/prism.dll + prism-LICENSES/
    files/Mods/BG3Access.pak                   the Lua mod, release build (BG3Access.Debug = false:
                                               no dev channel)
The Script Extender is not included: the installer downloads it from its official releases.
"""
import os
import re
import shutil
import subprocess
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(REPO, "tools"))
import deploy  # noqa: E402  (shared paths: Divine, Prism)

META = os.path.join(REPO, "Mod", "Mods", "BG3Access", "meta.lsx")
DEBUG_LINE = re.compile(r"^BG3Access\.Debug = true\b.*$", re.M)


def mod_version():
    """meta.lsx Version64 -> "major.minor.revision" (BG3's 9/7/16/31-bit packing)."""
    with open(META, encoding="utf-8") as f:
        v = int(re.search(r'id="Version64" type="int64" value="(\d+)"', f.read()).group(1))
    return f"{v >> 55}.{(v >> 47) & 0xFF}.{(v >> 31) & 0xFFFF}"


def release_mod(stage):
    """Copy of Mod/ with the debug switch off in both bootstraps."""
    src = os.path.join(REPO, "Mod")
    dst = os.path.join(stage, "Mod")
    shutil.copytree(src, dst)
    lua = os.path.join(dst, "Mods", "BG3Access", "ScriptExtender", "Lua")
    for name in ("BootstrapClient.lua", "BootstrapServer.lua"):
        path = os.path.join(lua, name)
        with open(path, encoding="utf-8") as f:
            text = f.read()
        text, n = DEBUG_LINE.subn("BG3Access.Debug = false", text)
        if n != 1:
            sys.exit(f"{name}: expected one 'BG3Access.Debug = true' line, found {n}")
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    return dst


def main():
    version = mod_version()
    build = os.path.join(REPO, "build", "package")
    if os.path.exists(build):
        shutil.rmtree(build)
    os.makedirs(build)
    deploy.build_native()
    mod = release_mod(build)
    pak = os.path.join(build, "BG3Access.pak")
    deploy.run([deploy.DIVINE, "-g", "bg3", "-a", "create-package", "-s", mod, "-d", pak, "-c", "lz4"])

    out = os.path.join(REPO, "dist", f"BG3Access-{version}")
    if os.path.exists(out):
        shutil.rmtree(out)
    files = os.path.join(out, "files")
    rel = os.path.join(REPO, "Native", "target", "release")
    deploy.copy(os.path.join(rel, "version.dll"), os.path.join(files, "bin", "version.dll"))
    deploy.copy(os.path.join(rel, "BG3AccessBridge.dll"), os.path.join(files, "bin", "BG3Access", "BG3AccessBridge.dll"))
    deploy.copy(os.path.join(deploy.PRISM, "dynamic", "release", "bin", "prism.dll"),
                os.path.join(files, "bin", "BG3Access", "prism.dll"))
    licenses = os.path.join(deploy.PRISM, "LICENSES")
    if os.path.exists(licenses):
        shutil.copytree(licenses, os.path.join(files, "bin", "BG3Access", "prism-LICENSES"))
    deploy.copy(pak, os.path.join(files, "Mods", "BG3Access.pak"))
    for name in ("README.md", "install.bat", "install.ps1", "uninstall.bat", "uninstall.ps1"):
        deploy.copy(os.path.join(REPO, "install", name), os.path.join(out, name))

    archive = out + ".zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
        for root, _, names in os.walk(out):
            for name in names:
                path = os.path.join(root, name)
                z.write(path, os.path.relpath(path, os.path.dirname(out)))
    print("package:", archive)


if __name__ == "__main__":
    main()
