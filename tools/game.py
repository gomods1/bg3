"""Drive Baldur's Gate 3 for testing.

    python tools/game.py launch [dx11] [keep-crash-flag]   # start bin\\bg3.exe (or bg3_dx11.exe) directly, skipping the Larian launcher
    python tools/game.py status          # game process, window, last lines of the mod's speech log
    python tools/game.py shot [name]     # capture the game window -> shots/<name>.png
    python tools/game.py press <key>...  # focus the game, SendInput scancodes (enter, ctrl+f5, hold:w:1500)
    python tools/game.py back            # Escape only if a screen or mod list is open (never the game menu)
    python tools/game.py click <x> <y>   # left click at full-resolution client coordinates (rclick: right)
    python tools/game.py lua <code>     # run Lua in the client state through the dev channel (debug builds)
    python tools/game.py lua-server <code>      (lua-server-file <path>: a file, server state)
    python tools/game.py wait-log <text> [timeout_s]   # wait until the speech log contains text
    python tools/game.py log [n]         # last n lines of the speech log
    python tools/game.py selog [n]       # last n lines of the newest Script Extender log
    python tools/game.py stop            # kill the game by PID
    python tools/game.py save <name> [note]   # quick-save (F5) and back it up to saves/NN_<name>
    python tools/game.py saves           # list the backups
    python tools/game.py restore <name|NN>    # copy a backup back into the profile (then load it)
"""
import ctypes
import ctypes.wintypes as wt
import glob
import os
import subprocess
import sys
import time

GAME = r"S:\steam\steamapps\common\Baldurs Gate 3"
BIN = os.path.join(GAME, "bin")
PROFILE = os.path.join(os.environ["LOCALAPPDATA"], "Larian Studios", "Baldur's Gate 3")
SE_DIR = os.path.join(PROFILE, "Script Extender")
MOD_IO = os.path.join(SE_DIR, "BG3Access")
SPEECH_LOG = os.path.join(MOD_IO, "logs", "speech.log")
BRIDGE_LOG = os.path.join(MOD_IO, "logs", "bridge.log")
SE_LOGS = os.path.join(MOD_IO, "logs", "se")
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXES = ["bg3.exe", "bg3_dx11.exe"]

user32 = ctypes.windll.user32
gdi32 = ctypes.windll.gdi32


def ps(cmd: str) -> str:
    r = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True)
    return r.stdout.strip()


def game_pid():
    out = ps("(Get-Process bg3,bg3_dx11 -ErrorAction SilentlyContinue | Select-Object -First 1).Id")
    return int(out.splitlines()[0]) if out else None


def find_window(pid):
    found = []

    @ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)
    def cb(hwnd, _):
        p = wt.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(p))
        if p.value == pid and user32.IsWindowVisible(hwnd):
            r = wt.RECT()
            user32.GetClientRect(hwnd, ctypes.byref(r))
            if r.right > 200:
                found.append(hwnd)
        return True

    user32.EnumWindows(cb, 0)
    return found[0] if found else None


def shot(name="shot"):
    """Desktop-duplication capture of the window rectangle (PrintWindow returns black for
    Vulkan swapchains). The window must be unobscured, so it is brought to the front first."""
    import mss
    from PIL import Image

    hwnd = focus_game()
    if not hwnd:
        print("no game window")
        return None
    r = wt.RECT()
    user32.GetClientRect(hwnd, ctypes.byref(r))
    pt = wt.POINT(0, 0)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    with mss.mss() as s:
        g = s.grab({"left": pt.x, "top": pt.y, "width": r.right, "height": r.bottom})
        img = Image.frombytes("RGB", g.size, g.bgra, "raw", "BGRX")
    if img.width > 1600:
        img = img.resize((img.width // 2, img.height // 2))
    os.makedirs(os.path.join(REPO, "shots"), exist_ok=True)
    path = os.path.join(REPO, "shots", f"{name}.png")
    img.save(path)
    print(path)
    return path


class KEYBDINPUT(ctypes.Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ctypes.c_size_t)]


class INPUT(ctypes.Structure):
    class _U(ctypes.Union):
        _fields_ = [("ki", KEYBDINPUT), ("pad", ctypes.c_byte * 32)]
    _anonymous_ = ("u",)
    _fields_ = [("type", wt.DWORD), ("u", _U)]


def send_vk(vk, down):
    """A virtual-key event (for Pause: its scancode is a special E1 sequence SendInput cannot send)."""
    inp = INPUT(type=1)
    inp.ki = KEYBDINPUT(vk, 0, 0 if down else 0x0002, 0, 0)
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))


def send_scan(sc, extended, down):
    flags = 0x0008 | (0 if down else 0x0002) | (0x0001 if extended else 0)  # SCANCODE, KEYUP, EXTENDED
    inp = INPUT(type=1)
    inp.ki = KEYBDINPUT(0, sc, flags, 0, 0)
    user32.SendInput(1, ctypes.byref(inp), ctypes.sizeof(INPUT))


def focus_game():
    pid = game_pid()
    hwnd = find_window(pid) if pid else None
    if not hwnd:
        return None
    if user32.GetForegroundWindow() != hwnd:
        # An Alt tap lets this process move the foreground window (SetForegroundWindow rules).
        send_scan(0x38, False, down=True)
        send_scan(0x38, False, down=False)
        user32.ShowWindow(hwnd, 9)  # SW_RESTORE
        user32.SetForegroundWindow(hwnd)
        time.sleep(0.5)
    return hwnd


VK = {"enter": 0x0D, "esc": 0x1B, "escape": 0x1B, "up": 0x26, "down": 0x28, "left": 0x25, "right": 0x27,
      "space": 0x20, "tab": 0x09, "backspace": 0x08, "home": 0x24, "end": 0x23, "pgup": 0x21, "pgdn": 0x22,
      "insert": 0x2D, "delete": 0x2E, "lalt": 0xA4, "ralt": 0xA5, "pause": 0x13,
      "minus": 0xBD, "comma": 0xBC, "period": 0xBE,
      **{f"f{i}": 0x6F + i for i in range(1, 13)}}
EXTENDED = {0x25, 0x26, 0x27, 0x28, 0x24, 0x23, 0x21, 0x22, 0x2D, 0x2E, 0xA5}
BY_VK = {0x13}  # keys sent as virtual keys, not scancodes
MODS = {"ctrl": 0x1D, "shift": 0x2A, "alt": 0x38}


def press_keys(keys, hold_ms=90):
    """Focus the game and press keys with SendInput scancodes (SDL reads these).
    A key can carry modifiers: ctrl+f5, shift+tab. 'hold:w:1500' holds W for 1.5 s."""
    if not focus_game():
        print("no game window")
        return 1
    # A modifier whose release got lost stays held in the game (session 6: every key arrived as
    # CTRL+..., and held Left Ctrl armed an attack): release them all first.
    for m in MODS.values():
        send_scan(m, False, down=False)
    send_scan(0x1D, True, down=False)  # right Ctrl
    for k in keys:
        hold = hold_ms
        if k.startswith("hold:"):
            _, k, ms = k.split(":")
            hold = int(ms)
        parts = k.lower().split("+")
        held = [MODS[p] for p in parts[:-1]]
        name = parts[-1]
        if name in VK:
            vk = VK[name]
        elif len(name) == 1:
            vk = ord(name.upper())
        else:
            # An unknown name used to press its first letter ("pause" pressed P and opened the
            # inspiration journal; "ctrl" alone pressed C).
            print(f"unknown key name: {name}")
            return 1
        sc = user32.MapVirtualKeyW(vk, 0)
        for m in held:
            send_scan(m, False, True)
        if vk in BY_VK:
            send_vk(vk, True)
            time.sleep(hold / 1000)
            send_vk(vk, False)
        else:
            send_scan(sc, vk in EXTENDED, True)
            time.sleep(hold / 1000)
            send_scan(sc, vk in EXTENDED, False)
        for m in reversed(held):
            send_scan(m, False, False)
        time.sleep(0.3)
    print("pressed", " ".join(keys))
    return 0


def click(x, y, right=False):
    """Click at client coordinates of the full-resolution window (screenshots wider than 1600 px are
    saved at half size: multiply their coordinates by 2)."""
    hwnd = focus_game()
    if not hwnd:
        print("no game window")
        return 1
    pt = wt.POINT(x, y)
    user32.ClientToScreen(hwnd, ctypes.byref(pt))
    user32.SetCursorPos(pt.x, pt.y)
    time.sleep(0.15)
    down, up = (0x0008, 0x0010) if right else (0x0002, 0x0004)
    user32.mouse_event(down, 0, 0, 0, 0)
    time.sleep(0.08)
    user32.mouse_event(up, 0, 0, 0, 0)
    print(f"clicked {x},{y}")
    return 0


def tail(path, n=30):
    if not os.path.exists(path):
        print(f"(no {path})")
        return
    with open(path, encoding="utf-8", errors="replace") as f:
        lines = f.readlines()
    print("".join(lines[-n:]), end="")


def newest_se_log():
    logs = glob.glob(os.path.join(SE_LOGS, "**", "*.log"), recursive=True)
    return max(logs, key=os.path.getmtime) if logs else None


def wait_log(text, timeout=300):
    end = time.time() + timeout
    while time.time() < end:
        if os.path.exists(SPEECH_LOG):
            with open(SPEECH_LOG, encoding="utf-8", errors="replace") as f:
                if text in f.read():
                    print(f"found: {text}")
                    return 0
        time.sleep(1)
    print(f"timeout waiting for: {text}")
    return 1


def lua_result(code, context="client", timeout=10):
    """The mod's dev channel (debug builds): write dev/<context>.lua, the mod runs it on its next
    poll and writes dev/<context>.out. Returns that output, or None without an answer."""
    dev = os.path.join(MOD_IO, "dev")
    os.makedirs(dev, exist_ok=True)
    out = os.path.join(dev, f"{context}.out")
    if os.path.exists(out):
        os.remove(out)
    tmp = os.path.join(dev, f"{context}.tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(f"-- seq {time.time_ns()}\n{code}")
    os.replace(tmp, os.path.join(dev, f"{context}.lua"))
    end = time.time() + timeout
    while time.time() < end:
        if os.path.exists(out):
            time.sleep(0.05)
            with open(out, encoding="utf-8", errors="replace") as f:
                return f.read()
        time.sleep(0.1)
    return None


def run_lua(code, context="client", timeout=10):
    text = lua_result(code, context, timeout)
    if text is None:
        print("no answer (mod not running, not in a Lua-enabled state, or not a debug build)")
        return 1
    print(text)
    return 0


def back():
    """Escape, only while a screen or mod list is open: with only the HUD in front the game's
    Escape opens the game menu (it happened several times in session 6)."""
    text = lua_result('return tostring(BG3Access.Router.current) .. "|" .. tostring(BG3Access.Router.handler ~= nil and BG3Access.Router.handler.title)')
    if text is None:
        print("no answer")
        return 1
    current, _, title = text.replace("=>", "").strip().partition("|")
    if current == "(hud)" and title in ("nil", "false", ""):
        print("nothing open: Escape not pressed")
        return 0
    print(f"closing {current} {title}")
    return press_keys(["escape"])


def launch(exe="bg3.exe", keep_crash_flag=False):
    if game_pid():
        print("already running")
        return 0
    for p in (SPEECH_LOG, BRIDGE_LOG):
        if os.path.exists(p):
            os.remove(p)  # so wait-log never matches the previous run
    # The game creates this folder at launch and removes it on a clean exit or at the main menu. If
    # it exists at launch (our killed test sessions), the game assumes a mod crash and loads NO mods.
    crash = os.path.join(PROFILE, "ModCrashSanityCheck")
    if keep_crash_flag:
        os.makedirs(crash, exist_ok=True)  # reproduces "no mods loaded" (bridge watchdog test)
    elif os.path.isdir(crash):
        import shutil
        shutil.rmtree(crash, ignore_errors=True)
        print("removed ModCrashSanityCheck (dev harness only)")
    proc = subprocess.Popen([os.path.join(BIN, exe), "--skip-launcher"], cwd=BIN)
    print(f"launched {exe} pid {proc.pid}")
    return 0


SAVE_DIR = os.path.join(PROFILE, "PlayerProfiles", "Public", "Savegames", "Story")
BACKUPS = os.path.join(REPO, "saves")


def backups():
    return sorted(d for d in os.listdir(BACKUPS) if d[:2].isdigit() and os.path.isdir(os.path.join(BACKUPS, d)))


def save_backup(name, note):
    """Quick-saves in game (F5), waits for the new save folder, copies it to saves/NN_name."""
    import shutil
    before = set(os.listdir(SAVE_DIR))
    press_keys(["f5"])
    end = time.time() + 30
    new = None
    while time.time() < end and not new:
        time.sleep(1)
        fresh = [d for d in os.listdir(SAVE_DIR) if d not in before]
        if fresh:
            new = max(fresh, key=lambda d: os.path.getmtime(os.path.join(SAVE_DIR, d)))
    if not new:
        # A quick save can overwrite an existing folder: take the newest one written just now.
        newest = max(os.listdir(SAVE_DIR), key=lambda d: os.path.getmtime(os.path.join(SAVE_DIR, d)))
        if time.time() - os.path.getmtime(os.path.join(SAVE_DIR, newest)) < 30:
            new = newest
    if not new:
        print("no new save appeared")
        return 1
    time.sleep(2)  # let the game finish writing
    n = 1 + max([int(d[:2]) for d in backups()] or [0])
    dest = os.path.join(BACKUPS, f"{n:02d}_{name}")
    shutil.copytree(os.path.join(SAVE_DIR, new), os.path.join(dest, new))
    with open(os.path.join(dest, "README.txt"), "w", encoding="utf-8") as f:
        f.write((note or name) + "\nSaved " + time.strftime("%Y-%m-%d %H:%M") + " (game.py save).\n")
    print("backed up", new, "->", dest)
    return 0


def restore_backup(key):
    """Copies a backup's save folder back into the profile so the game's Load menu lists it."""
    import shutil
    match = [d for d in backups() if d == key or d.startswith(key + "_") or d[:2] == key.zfill(2) or d.endswith("_" + key)]
    if not match:
        print("no backup", key)
        return 1
    src_root = os.path.join(BACKUPS, match[0])
    for d in os.listdir(src_root):
        full = os.path.join(src_root, d)
        if os.path.isdir(full):
            dest = os.path.join(SAVE_DIR, d)
            if os.path.exists(dest):
                shutil.rmtree(dest)
            shutil.copytree(full, dest)
            print("restored", d, "from", match[0])
    return 0


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 0
    c = a[0]
    if c == "launch":
        return launch("bg3_dx11.exe" if "dx11" in a[1:] else "bg3.exe", keep_crash_flag="keep-crash-flag" in a[1:])
    if c == "status":
        pid = game_pid()
        print("pid:", pid, "window:", find_window(pid) if pid else None)
        tail(SPEECH_LOG, 10)
    elif c == "shot":
        shot(a[1] if len(a) > 1 else "shot")
    elif c == "press":
        return press_keys(a[1:])
    elif c == "back":
        return back()
    elif c in ("click", "rclick"):
        return click(int(a[1]), int(a[2]), right=(c == "rclick"))
    elif c == "lua":
        return run_lua(" ".join(a[1:]), "client")
    elif c == "lua-file":
        # lua-file <path> [trailing code]: send a file's source, optionally followed by more code
        with open(a[1], encoding="utf-8") as f:
            src = f.read()
        if len(a) > 2:
            src = f"local M = (function()\n{src}\nend)()\n" + " ".join(a[2:])
        return run_lua(src, "client", timeout=30)
    elif c == "lua-server-file":
        with open(a[1], encoding="utf-8") as f:
            return run_lua(f.read(), "server", timeout=30)
    elif c == "lua-server":
        return run_lua(" ".join(a[1:]), "server")
    elif c == "wait-log":
        return wait_log(a[1], int(a[2]) if len(a) > 2 else 300)
    elif c == "log":
        tail(SPEECH_LOG, int(a[1]) if len(a) > 1 else 30)
    elif c == "blog":
        tail(BRIDGE_LOG, int(a[1]) if len(a) > 1 else 30)
    elif c == "selog":
        p = newest_se_log()
        print(p)
        if p:
            tail(p, int(a[1]) if len(a) > 1 else 40)
    elif c == "save":
        return save_backup(a[1], " ".join(a[2:]) if len(a) > 2 else None)
    elif c == "saves":
        for d in backups():
            readme = os.path.join(BACKUPS, d, "README.txt")
            first = open(readme, encoding="utf-8").readline().strip() if os.path.exists(readme) else ""
            print(d, "-", first[:120])
    elif c == "restore":
        return restore_backup(a[1])
    elif c == "stop":
        pid = game_pid()
        if pid:
            subprocess.run(["taskkill", "/PID", str(pid), "/F"], capture_output=True)
            end = time.time() + 30
            while game_pid() and time.time() < end:
                time.sleep(0.5)
        print("stopped", pid)
    return 0


if __name__ == "__main__":
    sys.exit(main())
