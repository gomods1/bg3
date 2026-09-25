# BG3 Access

A screen reader accessibility mod for Baldur's Gate 3: the game's menus, dialogue, combat,
exploration, inventory, trading and level ups spoken through your screen reader (NVDA, JAWS...)
or Windows' own voice, played with the keyboard.

Tested with game version 4.1.1.7398727 (Patch 8 hotfix 9), Script Extender v32, NVDA, on Windows 11.
The game can be in any language. The mod's own words follow the game's language (all 15 of the
game's languages; Spanish and English are reviewed, the others are first translations: reports of
wrong terms are welcome); `speech.language` in the configuration file overrides it.

## Install

1. Quit the game. Extract the whole download to a folder.
2. Run `install.bat`. It finds the game (Steam or GOG; otherwise it asks for the folder), installs
   the Script Extender from its official GitHub releases if it is missing, copies the mod's files,
   adds BG3 Access to the game's mod list and puts a shortcut on the desktop. Everything it says is plain text for your screen reader; it ends with
   "BG3 Access is installed", or with the reason it stopped. The game does not need to have been
   started before: the first-run screens (licence, content, brightness) are read by the mod.
3. Start the game with the desktop shortcut "Baldur's Gate 3 (BG3 Access)" (for a Steam copy,
   Steam must be running). It starts the game without Larian's launcher, which screen readers
   cannot use well. About 20 seconds later you hear
   "BG3 Access loaded. Control M opens the mod menu."
   Starting from Steam also works, but then the launcher opens first: its Play button must be
   pressed.

If you use BG3 Mod Manager, BG3 Access is a normal mod there; it must stay enabled.

## Keys

- **Control M**: the mod menu. Everything the mod can do, listed for what is possible right now
  (combat and exploration first). Up and Down choose, Enter runs, Escape closes.
- **Control R**: read the whole screen or list. **Control D**: details of the current item.
- In the mod's lists: Up and Down move, Home and End jump, Enter or Space activate, Left and Right
  change a value, Escape goes back.
- The game's own keys work as usual (Space ends the turn, I inventory, M map, F5 quick save...).
- Every command in the menu can get a key of its own in the configuration file (below).

The full key list, including the game's keys, is in `KEYS.md` in the source repository.

## Configuration

`%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\BG3Access\config.json`, created on
the first start: keys (`keys.<command>`), how the combat log is read (`combat.log`: "grouped" or
"full"), speech options.

## If the game is silent

- **After a crash**, the game starts once without any mods (its own crash check). Quit at the main
  menu and start again: the mod is back. After 90 seconds without the mod, the speech bridge says so.
- **After a game update** the Script Extender may need a moment to update itself, or BG3 Access may
  need a new version.
- Antivirus programs can block `bin\version.dll` or `bin\BG3Access\BG3AccessBridge.dll` (the part
  that speaks). Run `install.bat` again: its check lists missing files.

## Logs (for bug reports)

In `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\BG3Access\logs\`:
`speech.log` (every spoken line), `bridge.log`, and the Script Extender's log.

## What the mod changes

Nothing in your saves except a list of the named places you have visited (for the Places command).
Characters move only the way a player moves them: clicks the mod makes on your behalf, checked
before each click, and the game's own commands. No cheats, no teleporting. The game may turn
achievements off while mods are active.

## Uninstall

Run `uninstall.bat`: it removes exactly the files it installed and the mod-list entry. The Script
Extender stays (other mods use it); `uninstall.bat -RemoveScriptExtender` removes it too if the
installer had installed it.
