"""Drive Baldur's Gate 3 for testing.

    python tools/game.py launch [dx11]   # start bin\\bg3.exe (or bg3_dx11.exe) directly, skipping the Larian launcher
    python tools/game.py status          # game process, window, last lines of the mod's speech log
    python tools/game.py shot [name]     # capture the game window -> shots/<name>.png
    python tools/game.py press <key>...  # focus the game, SendInput scancodes (enter, ctrl+f5, hold:w:1500)
    python tools/game.py click <x> <y>   # left click at full-resolution client coordinates (rclick: right)
    python tools/game.py lua <code>     # run Lua in the client state through the dev channel (debug builds)
    python tools/game.py lua-server <code>
    python tools/game.py wait-log <text> [timeout_s]   # wait until the speech log contains text
    python tools/game.py log [n]         # last n lines of the speech log
    python tools/game.py selog [n]       # last n lines of the newest Script Extender log
    python tools/game.py stop            # kill the game by PID
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
      "insert": 0x2D, "delete": 0x2E, "lalt": 0xA4, "ralt": 0xA5,
      **{f"f{i}": 0x6F + i for i in range(1, 13)}}
EXTENDED = {0x25, 0x26, 0x27, 0x28, 0x24, 0x23, 0x21, 0x22, 0x2D, 0x2E, 0xA5}
MODS = {"ctrl": 0x1D, "shift": 0x2A, "alt": 0x38}


def press_keys(keys, hold_ms=90):
    """Focus the game and press keys with SendInput scancodes (SDL reads these).
    A key can carry modifiers: ctrl+f5, shift+tab. 'hold:w:1500' holds W for 1.5 s."""
    if not focus_game():
        print("no game window")
        return 1
    for k in keys:
        hold = hold_ms
        if k.startswith("hold:"):
            _, k, ms = k.split(":")
            hold = int(ms)
        parts = k.lower().split("+")
        held = [MODS[p] for p in parts[:-1]]
        vk = VK.get(parts[-1]) or ord(parts[-1].upper()[0])
        sc = user32.MapVirtualKeyW(vk, 0)
        for m in held:
            send_scan(m, False, True)
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


def run_lua(code, context="client", timeout=10):
    """The mod's dev channel (debug builds): write dev/<context>.lua, the mod runs it on its next
    poll and writes dev/<context>.out."""
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
                print(f.read())
            return 0
        time.sleep(0.1)
    print("no answer (mod not running, not in a Lua-enabled state, or not a debug build)")
    return 1


def launch(exe="bg3.exe"):
    if game_pid():
        print("already running")
        return 0
    for p in (SPEECH_LOG, BRIDGE_LOG):
        if os.path.exists(p):
            os.remove(p)  # so wait-log never matches the previous run
    # The game creates this folder at launch and removes it on a clean exit or at the main menu. If
    # it exists at launch (our killed test sessions), the game assumes a mod crash and loads NO mods.
    crash = os.path.join(PROFILE, "ModCrashSanityCheck")
    if os.path.isdir(crash):
        import shutil
        shutil.rmtree(crash, ignore_errors=True)
        print("removed ModCrashSanityCheck (dev harness only)")
    proc = subprocess.Popen([os.path.join(BIN, exe), "--skip-launcher"], cwd=BIN)
    print(f"launched {exe} pid {proc.pid}")
    return 0


def main():
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return 0
    c = a[0]
    if c == "launch":
        return launch("bg3_dx11.exe" if len(a) > 1 and a[1] == "dx11" else "bg3.exe")
    if c == "status":
        pid = game_pid()
        print("pid:", pid, "window:", find_window(pid) if pid else None)
        tail(SPEECH_LOG, 10)
    elif c == "shot":
        shot(a[1] if len(a) > 1 else "shot")
    elif c == "press":
        return press_keys(a[1:])
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
