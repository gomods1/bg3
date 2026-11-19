"""Download the third-party tools the dev scripts need, from their official GitHub releases.

    python tools/fetch_tools.py

What it gets (pinned versions, SHA-256 checked):
    downloads/ExportTool-v1.20.4.zip    LSLib (Norbyte/lslib, MIT): Divine.exe packs the mod and
                                        extracts game paks (tools/xaml_index.py, enum_names.py);
                                        unzipped into vendor/lslib/
    downloads/BG3SE-Updater-20260621.zip  BG3 Script Extender v32 updater (Norbyte/bg3se),
                                        copied into the game by tools/deploy.py

Game files are never downloaded or tracked: extract them yourself from your own game with Divine
(see tools/xaml_index.py).
"""
import hashlib
import os
import sys
import urllib.request
import zipfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOWNLOADS = os.path.join(REPO, "downloads")
VENDOR = os.path.join(REPO, "vendor")

TOOLS = [
    {
        "file": "ExportTool-v1.20.4.zip",
        "url": "https://github.com/Norbyte/lslib/releases/download/v1.20.4/ExportTool-v1.20.4.zip",
        "sha256": "5e02368fb8acafda9b45acba37a3f3bf507fc3d65a083a159abbeab06337190e",
        "unzip_to": os.path.join(VENDOR, "lslib"),
    },
    {
        "file": "BG3SE-Updater-20260621.zip",
        "url": "https://github.com/Norbyte/bg3se/releases/download/v32/BG3SE-Updater-20260621.zip",
        "sha256": "2b451d044feb9d50bc0ced4a64abf9c076d613436644945bdb2fba31dc9ac25a",
        "unzip_to": None,
    },
]


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def fetch(tool):
    path = os.path.join(DOWNLOADS, tool["file"])
    if os.path.exists(path) and sha256(path) == tool["sha256"]:
        print("ok      ", tool["file"])
    else:
        print("download", tool["url"])
        tmp = path + ".part"
        urllib.request.urlretrieve(tool["url"], tmp)
        got = sha256(tmp)
        if got != tool["sha256"]:
            os.remove(tmp)
            sys.exit(f"SHA-256 mismatch for {tool['file']}: got {got}, expected {tool['sha256']}")
        os.replace(tmp, path)
    if tool["unzip_to"]:
        with zipfile.ZipFile(path) as z:
            z.extractall(tool["unzip_to"])
        print("unzipped", os.path.relpath(tool["unzip_to"], REPO))


def main():
    os.makedirs(DOWNLOADS, exist_ok=True)
    for tool in TOOLS:
        fetch(tool)


if __name__ == "__main__":
    main()
