# ROADMAP (from gate.md section 14)

Tick only what was verified in the running game. Status detail lives in `STATUS.md`.

## M0 Foundation
- [x] Recon: build, hashes, launch without launcher, profile paths (CLAUDE.md)
- [x] Script Extender v32 installed on the dev game; runtime log; DeveloperMode hot reload
- [x] Native half loads (own version.dll proxy; decision in CLAUDE.md)
- [x] Extraction: GUI XAML from Game.pak (extract/, gitignored); default engine input config
- [ ] Extraction: story header, stats, localization, other paks' XAML (Gustav/GustavX/Patch8)
- [x] Bridge channel chosen by measurement (hooked SaveFile -> pipe, ~35 µs)
- [x] Prism speaks through NVDA (log verified; by-ear confirmation pending)
- [ ] Build/version gate (SE version, game version, bridge hello -> spoken warning)
- [x] Logs: speech.log, bridge.log, SE runtime log
- [ ] Config file
- [ ] Install/uninstall scripts
- [x] Playtest harness (tools/game.py: launch/stop/shot/press/click/lua/logs)
- [ ] Game key bindings dumped; mod key plan
- [ ] Controller-UI spike (gate 5.4)
- [ ] Movement spike (gate 8.1)

## M1 Every text the game shows
- [ ] Dialogue lines/options with tags, dice rolls, notifications, tooltips, combat log, journal, books,
      loading screen tips, cutscene subtitles; buffers

## M2 Menus
- [x] First-run: EULA, explicit content, gamma, splash (readable + operable by keyboard)
- [x] Main menu (buttons; New Game, Options)
- [x] Difficulty selection (announce preset)
- [ ] Options: every tab and row type
- [x] Message boxes (quit confirmation)
- [ ] Load/save, pause, other confirmations, errors, mod manager, profile select, credits

## M3 Character creation
## M4 Exploration
## M5 Combat
## M6 Inventory and progression
## M7 Blindfold playthrough, act by act
## M8 Polish (verbosity, cues, localization of mod strings, co-op decision)
## M9 Release (README, installer, package)
