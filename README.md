# BG3 Access

**Very, very early work in progress.** This is an experimental screen reader accessibility mod
for Baldur's Gate 3. It is not ready for players: expect missing screens, silence, bugs and
breaking changes at any time. Do not install it on a save you care about.

## What it is

A mod that lets blind players play Baldur's Gate 3 with a screen reader (developed with NVDA).
It reads the game's menus and screens, combat, dialogue and dice rolls through the screen reader,
and adds keyboard ways to do what the game expects the mouse for: lists of what is nearby,
travel to places, targeting in combat, and a mod menu (Ctrl+M) with the commands usable at the
moment.

## How it is built

- `Mod/`: the Lua mod, run by [BG3 Script Extender](https://github.com/Norbyte/bg3se) (v32).
- `Native/`: a Rust `version.dll` proxy that loads a small bridge DLL for speech
  (via the Prism library) and mouse input.
- `install/`: player install and uninstall scripts.
- `tools/`: development harness, deploy and packaging scripts.

Tested only on game build 4.1.1.7398727 (Patch 8 hotfix 9), Windows, with the game in Spanish.

## Status

See `STATUS.md`, `ROADMAP.md` and `PLAYTEST.md` for progress notes. No release yet.
