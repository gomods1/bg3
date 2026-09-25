"""Checks the mod's strings (Core/Strings.lua and Strings/<code>.lua).

    python tools/check_strings.py

Errors (exit 1): a key defined twice in one table (Lua keeps the last one silently: "place_here"
once shadowed the place cursor's string), a key used in code with L("...") / Strings.Get("...")
that English lacks, a translated key that English lacks, a translation whose {placeholders}
differ from English. Info: English keys a translation does not have yet (English is spoken).
Keys built at runtime ("marker_" .. type, "action_" .. id, "input_" .. name) are not checked.
"""
import os
import re
import sys
from collections import Counter

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = os.path.join(REPO, "Mod", "Mods", "BG3Access", "ScriptExtender", "Lua")
ENTRY = re.compile(r'^\s*([A-Za-z0-9_]+)\s*=\s*"((?:[^"\\]|\\.)*)"', re.M)
INLINE = re.compile(r'([A-Za-z0-9_]+)\s*=\s*"((?:[^"\\]|\\.)*)"')
# A literal key only: L("x") or L("x", {...}); L("action_" .. id) is built at runtime.
USE = re.compile(r'(?:\bL|Strings\.Get)\(\s*"([A-Za-z0-9_]+)"\s*[,)]')
PLACEHOLDER = re.compile(r"\{([A-Za-z0-9_]+)\}")


def entries(text):
    """(key, value) pairs of a Lua string table, several per line allowed."""
    out = []
    for line in text.splitlines():
        line = line.split("--", 1)[0] if not line.strip().startswith('"') else line
        out.extend(INLINE.findall(line))
    return out


def english():
    with open(os.path.join(LUA, "Core", "Strings.lua"), encoding="utf-8") as f:
        text = f.read()
    start = text.index("local EN = {")
    end = text.index("\n}\n", start)
    return entries(text[start:end])


def main():
    errors, infos = [], []
    en_pairs = english()
    for key, n in Counter(k for k, _ in en_pairs).items():
        if n > 1:
            errors.append(f"English: '{key}' defined {n} times")
    en = dict(en_pairs)

    for root, _, names in os.walk(LUA):
        for name in names:
            if not name.endswith(".lua") or root.endswith("Strings") or name == "Strings.lua":
                continue
            path = os.path.join(root, name)
            with open(path, encoding="utf-8") as f:
                for key in USE.findall(f.read()):
                    if key not in en:
                        errors.append(f"{os.path.relpath(path, LUA)}: uses missing key '{key}'")

    strings_dir = os.path.join(LUA, "Strings")
    for name in sorted(os.listdir(strings_dir)):
        if not name.endswith(".lua"):
            continue
        with open(os.path.join(strings_dir, name), encoding="utf-8") as f:
            pairs = entries(f.read())
        code = name[:-4]
        for key, n in Counter(k for k, _ in pairs).items():
            if n > 1:
                errors.append(f"{code}: '{key}' defined {n} times")
        table = dict(pairs)
        for key, value in table.items():
            base = re.sub(r"_(one|few|many)$", "", key)
            if key not in en and base not in en:
                errors.append(f"{code}: '{key}' is not an English key")
                continue
            want = set(PLACEHOLDER.findall(en.get(key, en.get(base, ""))))
            got = set(PLACEHOLDER.findall(value))
            if want != got:
                errors.append(f"{code}: '{key}' placeholders {sorted(got)}, English has {sorted(want)}")
        missing = [k for k in en if k not in table]
        if missing:
            infos.append(f"{code}: {len(missing)} keys not translated (English is used): {', '.join(missing[:12])}{' ...' if len(missing) > 12 else ''}")

    for line in infos:
        print("info:", line)
    for line in errors:
        print("error:", line)
    print(f"{len(en)} English keys, {len(errors)} errors")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
