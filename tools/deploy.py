"""Development build + deploy into the dev game (the player installer is install/install.ps1, later).

    python tools/deploy.py            # build native (release), pack the mod, copy everything, register in modsettings
    python tools/deploy.py --lua      # only repack and copy the .pak (Lua changes)

What goes where:
    bin\\version.dll                         proxy that loads the bridge (Native/proxy)
    bin\\BG3Access\\BG3AccessBridge.dll      native bridge (Native/bridge)
    bin\\BG3Access\\prism.dll + LICENSES     Prism 0.18.2 (C:\\Users\\Nitropc\\code\\libs\\prism)
    bin\\DWrite.dll                          Script Extender updater v32 (downloads/, official GitHub release)
    bin\\ScriptExtenderSettings.json         dev settings (logging on, Larian launcher off)
    %LOCALAPPDATA%\\...\\Mods\\BG3Access.pak   the Lua mod, packed with LSLib's Divine
    modsettings.lsx                          BG3Access entry added (backup kept once as modsettings.lsx.bg3access-backup)
"""
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = r"S:\steam\steamapps\common\Baldurs Gate 3"
BIN = os.path.join(GAME, "bin")
PROFILE = os.path.join(os.environ["LOCALAPPDATA"], "Larian Studios", "Baldur's Gate 3")
MODS = os.path.join(PROFILE, "Mods")
MODSETTINGS = os.path.join(PROFILE, "PlayerProfiles", "Public", "modsettings.lsx")
PRISM = r"C:\Users\Nitropc\code\libs\prism\prism-windows-x64"
DIVINE = os.path.join(REPO, "vendor", "lslib", "Packed", "Tools", "Divine.exe")
SE_ZIP = os.path.join(REPO, "downloads", "BG3SE-Updater-20260621.zip")
SE_LOG_DIR = os.path.join(PROFILE, "Script Extender", "BG3Access", "logs", "se")

MOD_UUID = "808d24db-b159-4ee7-b745-408923b186ab"
MOD_VERSION64 = "36028797018963968"


def run(cmd, **kw):
    print(">", " ".join(cmd))
    subprocess.run(cmd, check=True, **kw)


def build_native():
    run(["cargo", "build", "--release"], cwd=os.path.join(REPO, "Native"))


def pack_mod():
    out = os.path.join(REPO, "build", "BG3Access.pak")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    run([DIVINE, "-g", "bg3", "-a", "create-package", "-s", os.path.join(REPO, "Mod"), "-d", out, "-c", "lz4"])
    return out


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)
    print(f"  {src} -> {dst}")


def deploy_native():
    rel = os.path.join(REPO, "Native", "target", "release")
    copy(os.path.join(rel, "version.dll"), os.path.join(BIN, "version.dll"))
    copy(os.path.join(rel, "BG3AccessBridge.dll"), os.path.join(BIN, "BG3Access", "BG3AccessBridge.dll"))
    copy(os.path.join(PRISM, "dynamic", "release", "bin", "prism.dll"), os.path.join(BIN, "BG3Access", "prism.dll"))
    lic = os.path.join(BIN, "BG3Access", "prism-LICENSES")
    if os.path.exists(os.path.join(PRISM, "LICENSES")) and not os.path.exists(lic):
        shutil.copytree(os.path.join(PRISM, "LICENSES"), lic)


def deploy_se():
    if not os.path.exists(os.path.join(BIN, "DWrite.dll")):
        with zipfile.ZipFile(SE_ZIP) as z:
            z.extract("DWrite.dll", BIN)
        print("  installed Script Extender updater DWrite.dll")
    settings = {
        "CreateConsole": False,
        "EnableLogging": True,
        "LogRuntime": True,
        "DeveloperMode": True,
        "LogDirectory": SE_LOG_DIR,
        "DisableLauncher": True,
    }
    with open(os.path.join(BIN, "ScriptExtenderSettings.json"), "w", encoding="utf-8") as f:
        json.dump(settings, f, indent=4)


def register_mod():
    with open(MODSETTINGS, encoding="utf-8") as f:
        text = f.read()
    if MOD_UUID in text:
        print("  modsettings.lsx already lists BG3Access")
        return
    backup = MODSETTINGS + ".bg3access-backup"
    if not os.path.exists(backup):
        shutil.copy2(MODSETTINGS, backup)
    entry = f"""                        <node id="ModuleShortDesc">
                            <attribute id="Folder" type="LSString" value="BG3Access"/>
                            <attribute id="MD5" type="LSString" value=""/>
                            <attribute id="Name" type="LSString" value="BG3 Access"/>
                            <attribute id="PublishHandle" type="uint64" value="0"/>
                            <attribute id="UUID" type="guid" value="{MOD_UUID}"/>
                            <attribute id="Version64" type="int64" value="{MOD_VERSION64}"/>
                        </node>
"""
    # Append after the last ModuleShortDesc inside the Mods node.
    m = list(re.finditer(r"( *)</node>\n(?=\s*</children>\s*</node>\s*</children>\s*</node>\s*</region>)", text))
    if not m:
        sys.exit("could not find where to add the mod in modsettings.lsx")
    pos = m[-1].end()
    text = text[:pos] + entry + text[pos:]
    with open(MODSETTINGS, "w", encoding="utf-8") as f:
        f.write(text)
    print("  added BG3Access to modsettings.lsx")


def sync_loose():
    r"""Dev only: loose copy under DataMods so Ext.Debug.Reset() (DeveloperMode) can reload Lua
    without restarting the game."""
    dst = os.path.join(GAME, "Data", "Mods", "BG3Access")
    if os.path.exists(dst):
        shutil.rmtree(dst)
    # Scripts only: a second meta.lsx next to the .pak's makes the game skip the module.
    shutil.copytree(os.path.join(REPO, "Mod", "Mods", "BG3Access", "ScriptExtender"), os.path.join(dst, "ScriptExtender"))


def check_strings():
    """The strings checker (tools/check_strings.py): a duplicate or missing key is a bug."""
    run([sys.executable, os.path.join(REPO, "tools", "check_strings.py")])


def main():
    lua_only = "--lua" in sys.argv
    check_strings()
    if not lua_only:
        build_native()
    pak = pack_mod()
    copy(pak, os.path.join(MODS, "BG3Access.pak"))
    sync_loose()
    if not lua_only:
        deploy_native()
        deploy_se()
        register_mod()
    print("deployed")


if __name__ == "__main__":
    main()
