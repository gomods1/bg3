# GATE.md: Baldur's Gate 3 blind accessibility mod

A playbook for an AI coding agent building a **screen reader accessibility mod for Baldur's Gate 3** (Larian Studios, PC). It specializes `template_rpg.md` (same folder): read that first. Everything in it applies here unless this file says otherwise, and where the two disagree, this file wins. Techniques borrowed from the other templates are named where they are used: the **roguelike** template for turn-based combat (targeting mode, board review, phantom-event guard) and the **shooter** template for 3D navigation (spatial foundations, path guidance, scan, audio cues).

There is **no existing blind-accessibility mod for BG3** (checked with the user, 2026-09-24). Existing accessibility mods are visual (font size, contrast). This project starts from zero; nothing here has been proven in the running game yet.

The goal: **a blind player installs the mod, starts BG3, creates a character, and plays the whole story (all acts, every companion, every fight) to the epilogue and credits, without sighted help.**

---

## 0. How to read the facts in this file

BG3 is patched regularly and the community tools follow it. Every game-specific statement below carries a confidence tag:

- **[doc]**: read in the tool's own documentation or source on 2026-09-24 (the Script Extender's `Docs/API.md` and source tree, Nexus mod pages). Still re-verify against the installed versions: APIs are renamed between releases.
- **[lead]**: common community knowledge or the author's recollection. A hypothesis until checked in the running game (template rule 16).

**First task of the project**: turn every [lead] you depend on into a verified fact or a correction, and record it in `CLAUDE.md` with the game build and extender version.

---

## 1. The game, in modding terms

| Topic | What is known | Tag |
|---|---|---|
| Engine | Larian's proprietary engine (Divinity Engine 4.0 lineage), native C++, x64. No managed runtime to decompile. | [doc] |
| Executables | `bin\bg3.exe` (Vulkan) and `bin\bg3_dx11.exe` (DirectX 11). The mod must work under both. | [lead] |
| Launcher | Larian Launcher runs before the game; typically a web-view UI, likely inaccessible. A command-line switch to skip it is widely used (`--skip-launcher`). | [lead] |
| Client/server | The game runs a server (game logic, Osiris story scripts) and a client (UI, camera, input, rendering) even in single player. The Script Extender (SE) exposes a separate Lua state for each. | [doc] |
| Entity system | ECS: entities with named components (health, transform, stats, inventory, combat participation, …). SE exposes it through `Ext.Entity`. | [doc] |
| Story scripting | **Osiris**: goal scripts compiled into the story; events, queries, calls and databases. SE lets Lua call Osiris (`Osi.<Name>(...)`) and listen to it (`Ext.Osiris.RegisterListener`). The extracted story header lists every Osiris function with its signature. | [doc] for SE access, [lead] for the header's location |
| Rules data | Stats text files (spells, statuses, passives, weapons, armor, characters), plus binary/XML resources (`.lsf`/`.lsx`), root templates, dialogue files, localization `.loca` files with string handles. | [lead] |
| UI | **NoesisGUI** (XAML, WPF-like, MVVM). Screens are XAML files bound to view models (data contexts). SE exposes the Noesis tree and view models through `Ext.UI`. | [doc] for SE access |
| Two UIs | A keyboard/mouse UI and a **controller UI** (radial menus, focus navigation, target cycling). How the game switches between them, and whether the switch can be forced, is unknown. | [lead] |
| Input | SE's input API uses **SDL scancodes** (`Ext.Input.InjectKeyPress(SDLScanCode, …)`; `KeyInput` events carry SDL key and modifiers), which strongly suggests the game reads input through SDL. | [doc] |
| Movement | Click-to-move with pathfinding for keyboard/mouse; direct movement with the stick in controller mode. A community native "WASD Movement" mod exists, which suggests vanilla keyboard play lacks direct character movement (verify on the current build). | [doc] for the mod's existence, [lead] otherwise |
| Audio | Wwise. SE exposes `Ext.Audio` (load banks, post events on objects, RTPCs, switches, states, `PlayExternalSound`). | [doc] |
| Anti-cheat | None known. Co-op multiplayer (up to 4) exists; the mod is single-player first (section 2). | [lead] |
| Official mod support | Since Patch 7 (2024): an in-game mod manager (mod.io) and an official toolkit/editor. Script Extender mods are distributed outside the in-game manager (Nexus). | [lead] |
| Achievements | Loading mods has been reported to disable achievements; community "achievement enabler" native mods exist. Tell the player in the README; do not ship an enabler. | [lead] |
| User data | `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\`: `Mods\` (`.pak` mods), `PlayerProfiles\Public\` (`modsettings.lsx` load order, `Savegames\Story\`), SE data under a `Script Extender\` folder. Key bindings are stored in a per-profile input config file. | [lead] |
| Game rules | D&D 5e: d20 checks with advantage/disadvantage, action / bonus action / movement / reaction economy, spell slots, concentration, saving throws, surfaces (fire, grease, water, acid, ice, …), height advantage, stealth with vision cones, short and long rests, camp, companion approval, party of four. | general knowledge |

### 1.1 Community tools

| Tool | Role | Tag |
|---|---|---|
| **BG3 Script Extender** (Norbyte, `github.com/Norbyte/bg3se`) | Loaded through a `DWrite.dll` proxy in `bin\`. Lua in server and client contexts, console, `Ext.Entity`, `Ext.Osiris`, `Ext.UI` (Noesis), `Ext.IMGUI` (debug windows drawn by SE), `Ext.Level` (raycasts, sweeps, pathfinding, tile info, heights), `Ext.Input`, `Ext.Audio`, `Ext.Loca`, `Ext.Stats`, `Ext.Net` (client↔server channels), `Ext.IO` (files under the SE folder), `Ext.Timer`, `Ext.Vars`. License: source available with a "Commons Clause" condition: read it freely as documentation; do not copy code into the mod without checking the license. | [doc] |
| SE `Docs/API.md` and generated IDE helpers (`ExtIdeHelpers`) | The API reference; the IDE helpers are the most complete list of types, components and functions. Generate them from the installed SE and commit to `tools/` (they are generated, not game content; check the SE license before committing). | [doc] |
| SE source tree | Doubles as the best available **symbol file for the engine**: component layouts, Noesis bindings, input manager, picking helper, binary signatures. Read it when the Lua API is not enough. | [doc] |
| **Native Mod Loader** (Nexus mod 944) | Loads native DLLs from `bin\NativeMods\` through a `bink2w64.dll` proxy (the original is kept alongside). Alternative: "Yet Another BG3 Native Mod Loader" (MolotovCherry, GitHub). The native half of this mod (Prism, audio, mouse) loads through one of these. | [doc] |
| LSLib / Divine (Norbyte) | Extract `.pak` archives, convert `.lsf`↔`.lsx`, `.loca`↔XML. CLI usable from scripts. | [lead] |
| BG3 Mod Manager (LaughingLeader) | Load order and `modsettings.lsx`; players commonly use it. The mod must also install correctly without it. | [lead] |
| bg3.wiki / BG3 community wiki | Game content (spells, statuses, quests) and modding tutorials. Leads only. | [lead] |

---

## 2. Scope and boundaries

- **Single player first.** In a multiplayer session, the mod speaks "multiplayer: accessibility limited to your own characters" and only reads and acts on characters the local player controls; features that act (move, cast) are disabled for other players' characters. Co-op support is a later milestone, decided with the user. Detect multiplayer through SE (`Ext.Net.IsHost()` and the session's player count) [doc for IsHost].
- **Honour Mode**: one save that the game deletes on a party wipe. Screens must be accessible (the mode selection, the warnings), but test in Balanced/Explorer. Never auto-load or overwrite an Honour save.
- **Saves are disposable** on the dev machine (user's statement). Build a milestone library (template 23.3). The shipped mod must not write stats, items or story state that make saves depend on it: the SE mod contains **no** new stats, root templates or Osiris goals; only Lua scripts, and mod variables only if strictly needed.
- **No redistribution** of SE, the native loaders, game files, extracted data or decompiled code. The installer downloads or points to SE and the loader from their official sources.
- **Allowed on this machine** without asking: install SE and a native loader into the dev game, enable the SE console, extract `.pak` files to a gitignored folder, inject Frida, read and write process memory, synthesize input, take screenshots. Ask first: anything requiring admin (including virtual-gamepad drivers, section 5.4), running the Larian launcher's account sign-in, anything involving crossplay/online services.

---

## 3. Phase 1: reconnaissance checklist (BG3)

Do all of it in the first sessions; record in `CLAUDE.md`.

1. Game build (version string on the main menu and the exe version resource), SHA-256 of `bg3.exe`, `bg3_dx11.exe`; which one the user launches.
2. Install SE; record its version; enable its console window for development (SE settings file `ScriptExtenderSettings.json` next to the exe, option names from the SE README) [lead]. In the release, the console stays off.
3. Install a native loader into the dev game; confirm it loads a hello-world DLL that writes a log line.
4. Extract with LSLib: `Gustav.pak` / `Shared.pak` (rules, templates, story), the GUI archive (XAML), the English localization pak (and at least one other language for later). Convert everything to text. Gitignored `extract/` folder.
5. From the extraction:
   - **Story header** (all Osiris events/queries/calls with signatures) → `PATCH_TARGETS.md` candidates.
   - **XAML**: list every page/widget file → first draft of `SCREENS.md`. Note which folders are keyboard/mouse and which are controller.
   - **Input config defaults** → the game's default bindings, into `CLAUDE.md`, before choosing any mod key.
   - Stats files → the names the mod needs (statuses, spells, passives, damage types, conditions) with their display-name handles.
   - Localization → `TryLocalize(handle)` via `Ext.Loca.GetTranslatedString(handle)` [doc].
6. In the running game with the SE console: dump the host character's components (`_C():GetAllComponentNames()` [doc]); walk `Ext.UI.GetRoot()` and dump names and data-context types for the main menu, the HUD, the inventory; log every Osiris event name for five minutes of play, one fight and one conversation.
7. Controller-UI spike (section 5.4): can the controller UI be shown and driven with the keyboard alone?
8. Movement spike (section 8.1): which way of moving the character from code works, in exploration and in turn-based combat?
9. Bridge spike (section 4.3): measure message latency from Lua to the native half.

---

## 4. Architecture

### 4.1 Two halves

SE Lua is sandboxed [doc]: `dofile`/`loadfile` disabled, `debug` reduced; no way to load native code or play arbitrary audio from Lua (confirm in the console that `package.loadlib` is unavailable; if it happens to be present, do not depend on it). So the mod has two halves:

```
BG3Access/
├── Mod/                                   # the SE mod, packed as a .pak (Lua only, no stats/templates/goals)
│   └── Mods/BG3Access/
│       ├── meta.lsx                       # module info (UUID, version); generated by the build
│       └── ScriptExtender/
│           ├── Config.json                # {"RequiredVersion": N, "ModTable": "BG3Access", "FeatureFlags": ["Lua"]}
│           └── Lua/
│               ├── BootstrapClient.lua    # UI, input, speech requests, cursor/camera, most of the mod
│               ├── BootstrapServer.lua    # Osiris listeners, rules queries, commands that must run on the server
│               ├── Core/                  # Speech client (bridge writer), scheduler, buffers, config, help, glossary
│               ├── Game/                  # the ONLY place that names components, Osiris functions, XAML names, VM props
│               ├── State/                 # StateCache, play-mode tracker, party, PreviewGuard
│               ├── Screens/               # per-screen handlers + generic fallback; Readers/ per UI domain
│               ├── Dialogue/  Exploration/  Combat/  Inventory/
│               └── Net/                   # Ext.Net channel between client and server halves
├── Native/                                # BG3AccessBridge.dll, loaded by the native loader from bin\NativeMods\
│   ├── Speech/                            # Prism wrapper (template_rpg 8)
│   ├── Audio/                             # miniaudio cue engine (optional, section 12)
│   ├── Mouse/                             # cursor warp + clicks for the activation ladder (section 5.5)
│   ├── Channel/                           # receives messages from Lua (section 4.3)
│   └── Crash/                             # exception filter, minidumps
├── tools/                                 # console snippets, extraction scripts, playtest harness, Frida scripts
└── install/                               # install.ps1 / uninstall.ps1 (+ .bat): SE, loader, pak, bridge, modsettings entry
```

Most logic lives in **client Lua**: that is where UI, input, the camera and the picking helper are. The server half exists for what only the server knows or can do (Osiris events such as combat and dialogue flow, story flags, some commands). Client and server talk through `Ext.Net.CreateChannel` [doc]; in single player the round trip is local but still asynchronous: design for it.

### 4.2 Game layer

`Game/` wraps every engine name behind functions: `Game.HostCharacter()`, `Game.Party()`, `Game.Hp(entity)`, `Game.DisplayName(entity)`, `Game.Position(entity)`, `Game.ActionResources(entity)`, `Game.UiRoot()`, `Game.FindPage(name)`, `Game.PickedEntity()`, and so on. Component names, Osiris function names, XAML element names and view-model property names appear **only** there, each verified and listed in `PATCH_TARGETS.md` with the game build and SE version. When a patch renames something, one file changes and the log names the broken accessor ("Game.Hp: component 'Health' missing").

SE rule: engine objects returned to Lua expire at the end of the game-loop tick [doc]. Never store them; store entity UUIDs or handles and re-fetch.

### 4.3 The Lua → native channel

The mod's speech and cues depend on this; build and measure it first. Candidates, in order of preference; pick by measurement (latency, ordering, behavior when the native half is missing):

1. **Intercepted mailbox file**: Lua writes a line batch with `Ext.IO.SaveFile("BG3Access/out/<seq>.msg", text)` [doc: writes under the SE folder]. The native bridge hooks the file-creation and write APIs used for that path (find which with Frida: `frida-trace -i "CreateFile*" -i "WriteFile"` while the Lua calls `SaveFile`) and consumes the content in memory, reporting success without touching the disk. Synchronous, same thread, no disk I/O. Fragile only if SE changes its file API.
2. **Real mailbox files** watched by the bridge (`ReadDirectoryChangesW`), deleted after reading. No hooks; tens of milliseconds of latency; fine for speech, marginal for continuous cues.
3. **Console/log sink**: the bridge hooks the function SE uses to print (`_P`) and filters lines with a reserved prefix. Last resort; interferes with debugging.

Protocol (one message per line, UTF-8): `say <interrupt 0|1> <channel> <ttlMs> <text>`, `stop`, `cue <name> <x> <y> <z>`, `listener <x> <y> <z> <yaw>`, `mouse warp <x> <y>`, `mouse click <left|right>`, `hello <modVersion>`. The bridge answers through a small status file Lua can read with `Ext.IO.LoadFile` (backend name, errors, bridge version). If the bridge is missing, Lua logs it and prints a clear error with `_P` and shows an IMGUI message for sighted helpers; the player hears nothing, so the installer must verify the bridge (section 16).

The bridge keeps Prism on one thread (its own worker) fed by a queue; the speech scheduler (template_rpg 8) runs on the Lua side, where the game state is.

### 4.4 Build gate

At startup, Lua checks the SE version (`Ext.Utils.Version()` or equivalent [lead]) and the game version against the tested list, and the bridge checks its own hello round trip. Unknown versions: speak "BG3 Access: untested game version, some features may not work", keep running (Lua fails soft by design), and log every missing accessor. The native bridge hooks **only** OS APIs (file writes, nothing game-specific), so it has no game-build dependency; keep it that way.

---

## 5. UI: Noesis

### 5.1 Reading

- `Ext.UI.GetRoot()` [doc] gives the Noesis visual tree. Walk it to find the open pages (the XAML file names from the extraction tell you what to look for), their visibility, and the **data context** of each element.
- **Read view models, not visuals.** BG3's XAML binds to view-model properties; the view model has the item/spell/character handle, availability flags, tooltip data, counts. Map each screen's bindings from its XAML (`{Binding Path=…}`) to the properties you read. The visual tree tells you what is visible and in which order.
- Tooltips are view models too (built on hover); find what triggers them and whether they can be built without hovering. If not, the mod hovers deliberately (5.5) and reads the result.
- List controls virtualize and recycle containers: a container's data context changes as the list scrolls. Always read the data context at the moment of speaking.
- Record in `SCREENS.md`, per screen: XAML file, root element name, the view-model type and the properties used, how the mod detects it is open and on top.

### 5.2 Which screen is in front

Build `Game.ActiveScreens()` from the Noesis tree (visible pages in z-order) plus the game's UI state machine if SE exposes it (`Ext.UI.GetStateMachine` exists in the SE source [doc]; what it returns must be explored). The router (template_rpg 10.4) picks the handler from that every tick. Test the "in front" answer against every modal, including the ones that open over combat and dialogue.

### 5.3 Tiers per screen

For each screen, decide: **tier A** (Noesis keyboard focus moves with keys; read `FocusedElement`), **tier B** (the controller UI's focus navigation can be driven), or **tier C** (mouse only; the mod builds the navigation from the view model's collections and activates through 5.5). Expect the keyboard/mouse UI to be mostly tier C and the controller UI mostly tier B.

### 5.4 The controller-UI question (decide early)

The controller UI was designed for play without a pointer: radial menus, focus navigation in every panel, target cycling in combat, direct character movement. If the keyboard can drive it, much of this mod becomes *reading* rather than *building*. Spike, in this order:

1. Does the game switch to the controller UI when a gamepad sends input, and back on mouse movement? Is there a setting to lock it?
2. Can SE's `ControllerButton`/`ControllerAxis` events be observed (yes [doc]); can controller input be **injected**? SE injects keys only [doc]. Options: the native bridge feeds SDL's game-controller layer (find how the game polls SDL; hook the poll and add synthetic state; SDL may be statically linked: check exports and strings), or a virtual gamepad driver (ViGEmBus is unmaintained and needs admin: **ask first**, and it is a burden on every player).
3. Does the controller UI keep working with a keyboard and mouse also present (the game may flip back on every key press)?

Record the result in `CLAUDE.md` and choose per screen. A hybrid is likely: controller UI for combat targeting and radial menus, keyboard/mouse UI plus mod navigation for inventory-heavy screens, or the reverse. Do not commit to building tier-C navigation for a screen before this spike is answered.

### 5.5 Activation and "focus is hover"

BG3 acts on what the cursor is over. The mod's activation ladder (template_rpg 10.4), adapted:

1. **The game's own command** through SE/Osiris when one exists and behaves like the player's action (validated per command: resource costs, turn-based rules, sounds, party follow).
2. **View-model commands**: Noesis buttons are usually bound to `ICommand`s on the view model; invoking the command is the same as clicking (find out whether SE lets Lua execute a bound command; the SE source's Noesis helpers will tell).
3. **Key injection** of the game's own bindings (`Ext.Input.InjectKeyPress` [doc]): hotbar slots, end turn, panels.
4. **Cursor warp + click** by the native bridge, **verified by the picking helper**: before clicking in the world, Lua reads `Ext.UI.GetPickingHelper(playerId)` [doc: `Selection`, `Inner.WorldPosition`, `WindowCursorPos`] and clicks only if the picked entity or position is the one the player heard. If not, speak "could not target" and do not click. For UI elements, click the element's screen rectangle center after confirming it is visible and hit-testable.

Cursor warping needs world-to-screen projection (camera matrices; find them in SE's camera components or the SE source) and window client coordinates; clamp away from the window edges so the camera does not edge-scroll.

---

## 6. Input

- Mod keys are read in **client Lua** with `Ext.Events.KeyInput` [doc] (fields `Key`, `Modifiers`, `Pressed`, `Repeat`). SE events support `PreventAction()` / `StopPropagation()` [doc]; **verify that preventing a KeyInput stops the game's binding** for each claimed key, in each mode (UI focused, world, dialogue, combat). If it does not for some path, the native bridge suppresses at the OS/SDL level.
- Mouse events are also observable (`MouseButton`, `MouseWheel`) [doc]: use them to detect a sighted helper moving the mouse and invalidate the armed target.
- **Default bindings first**: extract them (section 3) and list them in `CLAUDE.md`. BG3 binds many letters to panels, number keys to the hotbar, F-keys to party portraits/quick save/load, Space/Enter/Escape/Tab to common actions [lead: verify every one]. Do not assume F1 is free for help.
- A **mod layer key** (held) plus letters avoids most conflicts; choose it from keys the game leaves unbound. All mod keys rebindable in the config.
- The SE console window must not be focused during play testing of keys (it captures input when focused).

Baseline mod keys (names, not bindings; bind after the conflict check):

| Function | Notes |
|---|---|
| help | Context help list |
| re-read / read screen | template_rpg 12.1 |
| character status | Controlled character: HP, conditions, action/bonus/reaction/movement left in combat, spell slots, concentration |
| party overview | Each member: HP, conditions, downed, distance, linked/unlinked |
| where am I | Region and sub-area name, surface underfoot, nearest exit, party positions |
| objective | Tracked quest's current objective and marker distance/direction |
| scan / browser | Section 8.3 |
| world cursor | Section 8.2 |
| combat: turn order, whose turn, battlefield review, target cycle, end-turn confirm | Section 9 |
| buffers | Review buffers |
| verbosity, mute cues | |

---

## 7. Text and speech specifics

- **Localization**: display names and descriptions are handles; resolve with `Ext.Loca.GetTranslatedString` [doc]. Descriptions contain **parameters** (damage dice, DCs, durations computed from stats) and **inline markup** (keyword links, icons, color spans). Find how the UI resolves them (the tooltip view model usually has the final text); never speak unresolved parameters.
- **Keywords**: BG3 tooltips nest keyword explanations (conditions, mechanics). Build the glossary from those descriptions at runtime; keyword explanations go only into buffers.
- **Dice**: "1d8 plus 3", "d20", "advantage", "DC 15".
- **Numbers the game hides**: enemy HP is shown as a bar with a number (on hover); attack/hit chance as a percentage in the targeting tooltip. Speak what the game shows, no more (an unexposed exact enemy AC, for example, is not spoken unless the game shows it).
- **Voiced lines**: BG3 voices every dialogue line (including a narrator). Speak the text anyway by default (speaker name + line), with a config option to only name the speaker for voiced lines; the Dialogue buffer always holds the full text.

---

## 8. Exploration (shooter-template techniques)

### 8.1 Moving the character

Spike these in the first weeks; each has different rule consequences:

1. **The client's own move request** (what a click on the ground does): find it through the picking helper and the SE source (input manager, player movement request); if Lua can issue it, this is the best path: party follow, stealth, turn-based costs and path previews all behave as for a sighted player.
2. **Osiris scripted movement** (a move-to-position call in the story header) [lead]: simple, server-side, but scripted movement may not consume combat movement, may not respect sneaking, and may break party follow. Test all three before using it anywhere; never use it in combat unless proven identical to player movement.
3. **Cursor warp + click** on the projected destination, verified by the picking helper (5.5). Works for anything a sighted player can click; depends on the destination being on screen, so the camera must follow the character (it does by default [lead]) and the destination must be within the view (walk in segments).
4. Community **WASD movement** (native mod): if the player uses it, support it with shooter-style guidance and sensing; do not require it.

Announce: departure ("walking to the chest"), arrival, interruption and why (blocked, combat started, detected, dialogue triggered), and party members left behind.

### 8.2 World cursor

Template_rpg 16.2 on BG3's ground: step in meters (BG3's unit) along screen-relative directions (camera yaw), large step with a modifier. At each point: walkable or not and why (use `Ext.Level.GetTileDebugInfo`, `GetHeightsAt`, `GetEntitiesOnTile` [doc]: record which fields mean walkable, surface type, height), surfaces (fire, grease, water, difficult terrain), height relative to the controlled character, entities there, path distance (`Ext.Level.BeginPathfinding` → `FindPath` [doc]: learn the asynchronous pattern in the console, and release paths). "Go here" and "interact here" are explicit keys.

### 8.3 Scan, entity browser, where am I

- **Entity sources**: SE entity queries by component (characters, items, containers, doors, interactables), filtered by distance and **by what the party can perceive**. BG3 hides things behind perception checks (traps, hidden levers, secret doors); only list what the game currently reveals. The game's own "highlight interactables" key [lead: Left Alt] shows exactly what a sighted player could see; find the query behind it and use it as the visibility reference.
- **Categories**: hostile / neutral / companions and party / traders / quest givers; containers and loot (with "already looted"); doors and exits (locked, trapped, destination for area transitions); interactables (levers, books, shrines, waypoints, crafting); detected traps and hazards; bodies to loot; quest markers.
- **Actions** per entity from the game's own context menu (the right-click menu's view model: talk, attack, pickpocket, lockpick, disarm, examine, throw, move, …) with unavailable actions and reasons.
- **Where am I**: region and sub-area (map UI and level data), indoors/outdoors, surface underfoot, nearest exit/waypoint, party positions.

### 8.4 Guidance and cues

- **Guidance target**: tracked quest marker (from the map/journal view model), a custom map marker, a browser choice, nearest of a category.
- **Path, not straight line**: `Ext.Level` pathfinding from the controlled character; turn-by-turn speech ("ladder ahead", "doorway left", "stairs down", "jump needed"); recompute on stray; announce arrival and what is there.
- **Jumps and climbs**: BG3 routes include jumps and ladders; announce them before the character reaches them, and for jump-only gaps say so ("reachable only by jumping, 4 meters; use jump").
- **Cues** (optional, shooter template 14 mapping): scan sweep, path beacon, discovery one-shot. Decide with the user between (a) the bridge's miniaudio stream (independent of the game's mix, needs `listener` updates at 20–30 Hz over the channel: measure channel cost) and (b) Wwise via `Ext.Audio.PostEvent`/`PlayExternalSound` on entities [doc] (the game's own 3D positioning, but ducked in dialogue and paused with the game). Reference frame: camera yaw (what the player's "left" means on screen).

### 8.5 Stealth, traps, hazards

- Sneaking state, "you are seen", enemy vision (the game shows cones when sneaking: find the data behind them), detection meter changes: urgent events.
- Trap detected (passive perception success): announce with direction and distance; disarm/avoid actions in the browser.
- Before any move, check the game's own path preview (the line with its warnings) for hazards and speak them.

### 8.6 Map, waypoints, camp

- Map screen: marker browser (waypoints, quests, traders, custom markers), review cursor with region names, fast travel to a waypoint, custom marker placement.
- Camp: travel to camp, long rest (supplies required and owned), camp events and night conversations, the camp chest, companions present, returning.

---

## 9. Combat (roguelike-template techniques)

BG3 combat is turn-based (5e rules). Turn-based mode can also be toggled outside combat [lead: verify the control]; mention it in help as a tool for careful exploration.

- **Signals**: Osiris combat events (combat started/ended, turn started/ended, round, attacks, damage, statuses, deaths, downed) from the story header; SE components for turn order, initiative, action resources. Log a whole fight first (section 3) and build from the log.
- **Combat start**: "combat: 4 enemies; you act second of 7". Turn order into its buffer.
- **Your turn**: character, HP, action / bonus action / reaction / movement remaining, spell slots, concentration, conditions, threats in melee range, standing on a surface.
- **Enemy turns**: coalesced per actor, urgent first (a party member downed, concentration lost); rolls into the Combat log buffer. The game's own combat log (a UI panel with rolls) is a source: read its view model.
- **Battlefield review cursor**: combatants in turn order or by proximity: name, HP, conditions, distance, direction (screen-relative), height difference, line of sight from the controlled character, whether it threatens anyone.
- **Actions**: the hotbar as a list (template_rpg 18) with cost, availability and reason. Choosing one enters targeting.
- **Targeting mode**: cycle valid targets (the game's validity check), each with the game's preview: hit chance %, damage range, save type and DC, advantage/disadvantage and why (height, obscurement, prone, …), in range, line of sight. **Phantom events**: hovering targets computes previews; `PreviewGuard` suppresses any event fired during targeting until the action is confirmed. Enter confirms (via 5.5, or the controller UI's own target cycling if 5.4 says it is drivable), Escape cancels.
- **Area placement**: placement cursor on the ground listing who would be hit (friend and foe), center in range and line of sight, "center on target X" shortcuts.
- **Movement in combat**: movement cursor with path cost vs remaining movement, reachable this turn or not, attacks of opportunity, hazards, falls, jumps (jump costs movement), dash/disengage shortcuts.
- **Reactions**: BG3 asks about reactions in a popup or by settings [lead]; announce with urgent priority, make every option reachable, and point to the game's per-reaction "always/ask/never" settings.
- **Dice in combat**: attack and save rolls are in the log; only checks with player choices (inspiration reroll, bonuses) need interaction.
- **End turn** with resources left: confirm.
- **Downed, death saves, revive, party wipe**: urgent; the game-over flow (and Honour mode's permanent end) announced clearly.

---

## 10. Dialogue, checks and story

- **Dialogue UI**: find its page and view model: speaker, line text, option list with each option's tags (skill check type and DC, class/race/background/deity/origin tags, "[Leave]", hostile outcomes), and history. Speak speaker + line as each appears; options as "N options" then each on focus with number and tags. Number keys likely choose options directly [lead].
- **Dice roll screen**: the check type, DC, your bonus, advantage/disadvantage, bonuses you may add (Guidance, Bardic Inspiration, …), inspiration reroll; the roll result, total, success or failure, critical. Every pre-roll choice keyboard-reachable; "click to roll" mapped to Enter.
- **Companion reactions** ("approves", "disapproves"): events at normal priority, also in the Dialogue buffer.
- **Cinematic dialogue with no options**: auto-advance or key to continue: announce which.
- **Cutscenes**: start, skip key, lines, control returned.
- **Books, letters, notes**: the reading view → Story buffer by sentence.
- **Journal**: quests (active/completed/failed, entries in order, tracked quest), the tutorial/glossary sections the game has, and the dialogue history if the game keeps one.

---

## 11. Inventory, characters, progression

Template_rpg 14 and 18, with BG3 specifics:

- Per-character inventories plus containers, the camp chest, "send to camp", weight and encumbrance, stacks and split, gold, keys, the "wares" marking for selling.
- **Equipment** slots incl. ranged and melee weapon sets, and camp clothes; comparison against equipped.
- **Character sheet**: abilities, skills, saves, resistances, proficiencies, notable features, conditions.
- **Spellbook**: prepared vs known spells, preparation limits, cantrips, class resources.
- **Level up**: class/multiclass choice, subclass, feats or ability improvements, new spells, every choice with full description; summary before confirm.
- **Character creation**: origin vs custom vs special origins, race/subrace, class/subclass, background, point-buy abilities, skills, cantrips/spells, appearance (presets and randomize first; per-option access for those who want it), voice, deity where relevant, and the second creation screen for the dream companion [lead]; "confirm" summary.
- **Respec** (a character in the game offers it [lead]), **mirror** (appearance change), **hireling** screens.
- **Trading**: two lists, barter balance, trader gold, attitude/price effects, buyback.
- **Alchemy/crafting**, **illithid powers** tree, **party management** (add/remove companions at camp).

---

## 12. Audio cue decision

Speech carries menus, dialogue and combat. Cues are for exploration (section 8.4). Before building the cue engine, do a listening session with the user comparing: no cues (speech + browser + walk-there), beacon only, beacon + scan sweep. Build what helps. If built: `CUES.md`, glossary with previews, per-family toggles, instant mute, and the shooter template's mapping (pan = direction, pitch = height, rate = closeness, timbre = category, muffled = behind).

---

## 13. Screen inventory prompts (BG3)

Questions, not the inventory; the inventory comes from the XAML extraction and runtime logging. Every item needs a `SCREENS.md` row.

Launcher; intro videos; main menu; any account/crossplay prompts; the in-game mod manager; load game (per-save details: character, location, playtime); new game: difficulty (including custom settings and Honour mode warnings); character creation (every step, both creation screens); opening cinematic and the tutorial area; exploration HUD (portraits, hotbar and its tabs, action resources, minimap, notifications, tracked quest); context (right-click) menu; radial menus (controller UI); inventory; container and loot windows; equipment/character sheet tabs; spellbook; level up; dialogue; dice roll; combat HUD (turn order, reactions prompt, end turn, combat log); downed/death/game over; party management and chain/unchain groups; stealth; lockpicking and trap disarm; reading; trading; map and waypoints; camp and long rest; short rest; journal (quests and other tabs); alchemy; illithid powers; mirror and respec; hirelings; photo mode (announce and offer to exit); options (every tab: gameplay, audio, video, controls/rebinding, interface, accessibility, controller); pause menu; save dialog; quit confirmations; error dialogs; epilogue; credits.

Play modes: exploration (single / group, linked/unlinked), sneaking, turn-based exploration, dialogue, dice roll, combat (own turn / others' turn / targeting / area placement / movement / reaction prompt / downed), trading, looting, camp, map, cutscene, loading, photo mode, multiplayer (limited).

---

## 14. Roadmap template (copy into `ROADMAP.md`)

Status per item lives in `STATUS.md` (template_rpg rule 15). Tick only what was verified in the running game.

- **M0 Foundation**: recon (section 3) complete; SE + native loader installed on the dev game; extraction done; bridge channel chosen by measurement; Prism speaks "BG3 Access loaded" in game; build/version gate; log files; config file; install/uninstall scripts; playtest harness (template_rpg 23.1) with BG3 state probes; controller-UI spike and movement spike answered.
- **M1 Every text the game shows**: dialogue lines and options with tags, dice rolls, notifications, tooltips, combat log, journal updates, books, loading screens, cutscene subtitles; buffers.
- **M2 Menus**: main menu, load/save, options (every tab), pause, confirmations, errors, mod manager, difficulty selection.
- **M3 Character creation** to the opening, fully.
- **M4 Exploration**: status keys, where am I, entity browser, world cursor, walk-there, guidance to quest markers, doors/exits/transitions, traps/stealth warnings, map and waypoints, camp.
- **M5 Combat**: turn tracking, battlefield review, hotbar list, targeting with previews, area placement, movement in combat, reactions, end turn, downed/death.
- **M6 Inventory and progression**: inventory, loot, equipment, trading, level up, spellbook, alchemy, rests, party management.
- **M7 Blindfold playthrough, act by act** (template_rpg 23.5): tutorial area, then each act in milestone chunks, to the epilogue and credits.
- **M8 Polish**: verbosity, cues (if chosen), localization of mod strings, co-op decision, performance.
- **M9 Release**: player README (install, keys, config, assists, known issues, achievements note), installer, package, Nexus page text.

---

## 15. Playtesting BG3 (extends template_rpg 23)

Blind players must be able to play from the main menu to the credits; you prove it by doing it. Saves are disposable.

### 15.1 Harness specifics

- **Launch**: start the executable directly (skipping the launcher) with the working directory set to `bin\`; record the PID; windowed or borderless-windowed at a fixed resolution set in the game's options (record it). Test both `bg3.exe` and `bg3_dx11.exe`: window capture of Vulkan swapchains can fail with `PrintWindow`; use desktop duplication (`mss`) on the foreground window, and keep the window unobscured.
- **State probe**: a client-Lua debug module (debug builds only) that answers the harness through the bridge's status file or a debug file under the SE folder: active screens, play mode, controlled character UUID/position/HP, combat state and current turn, dialogue state and options, picked entity, last 50 spoken lines. The harness asserts against it.
- **Hands**: `Ext.Input.InjectKeyPress` from debug Lua for keys (no window focus needed), `SendInput` scancodes for OS-level tests (to prove real key presses behave the same), the bridge's mouse commands for sighted-pass clicks.
- **Console**: the SE console accepts Lua in client and server contexts [doc]; keep a library of snippets in `tools/console/` (dump components, list Osiris events, dump the UI tree, find entities near the host).
- **Development helpers** (debug builds only, via Osiris calls from the server: verify each name in the story header): teleport the party, add gold/items, set HP, apply a status, start a fight with a spawned group, set a quest flag, grant XP for level-ups. Every manufactured state is also reached naturally at least once (template_rpg 23.3).
- **Hang and crash detection**: no SE log activity or no new frame for N seconds → screenshot, dump, kill by PID, record; crash dumps from the game and from the bridge's exception filter.

### 15.2 BG3 edge cases to add to the matrix

- Dialogue started by an NPC walking up during exploration; dialogue in the middle of combat; dialogue where a companion interrupts; group dialogues where another party member is the speaker; options that start combat; dialogues ending in a cutscene.
- Dice: natural 1 and 20, advantage/disadvantage, adding Guidance/Bardic Inspiration, inspiration reroll, passive checks with no roll shown.
- Surfaces changing during a turn (fire spreading, grease ignited), height advantage, darkness/obscurement, invisible enemies, enemies that become allies, summons, wild shape/polymorph (the controlled "character" changes form and hotbar), mounts or other special control states if the game has them.
- Party split across levels or areas; unlinked characters in different fights; a companion leaving the party; the host character downed while others fight on.
- Area transitions with confirmation; the underground/overland transitions; elevators and ladders; jump-only gaps; water.
- Trading with not enough gold; overweight; camp chest; sending items to camp mid-dungeon.
- Long rest with insufficient supplies; camp night events; companion romance/recruitment scenes (cinematic dialogue).
- Save/load in dialogue, in combat, during a dice roll; quick save/quick load keys; autosave; loading a save from before the mod was installed.
- Game patch or SE update: the gate announces it; missing accessors are logged by name.
- Controller plugged in mid-session (UI switch), alt-tab, resolution change, UI scale change, language change.

### 15.3 The blindfold campaign

Sighted pass per area → fixes → blindfold pass of the same area → fixes → next. The blindfold chunks, in story order, each from a milestone save and each logged in `PLAYTEST.md`: main menu and character creation; the tutorial area to the first beach; each major area of act 1 (every waypoint reached with guidance only; every trader; every companion recruited; every boss fight); act 2; act 3; the ending sequence and epilogue; credits. The project is not done until the chain is unbroken.

---

## 16. Installation and release

- `install.ps1` / `install.bat`: find the game (Steam and GOG library locations, registry, or ask), check the game version, install or verify SE (download from its official source; do not bundle), install or verify the native loader (same), copy `BG3AccessBridge.dll` (+ `prism.dll`, Prism `LICENSES`/`NOTICE`) into `bin\NativeMods\` (or wherever the chosen loader expects), copy `BG3Access.pak` into the user `Mods\` folder, add it to `modsettings.lsx` (back it up first) or explain how to enable it in BG3 Mod Manager, and finally **run a self-test**: launch-free check that every file is in place, plus instructions for the first launch ("you should hear: BG3 Access loaded"). Uninstall removes exactly what was installed, from a manifest.
- The installer speaks through the console (plain text output, no GUI) so a screen reader reads it.
- README: prerequisites, install, first launch, launcher skipping, full key list, config file, what the mod changes (nothing in saves; no assists unless enabled), achievements note, multiplayer limits, known issues, how to send logs (the SE log, the mod's spoken-line log and event log, the bridge log).

---

## 17. BG3 pitfalls

- Storing SE engine objects across ticks (they expire [doc]); store UUIDs/handles.
- Client vs server confusion: calling a server-only function from client Lua (or vice versa) fails, sometimes silently; every `Game/` accessor documents its context.
- `Ext.Net` round trips assumed synchronous.
- Reading the Noesis visual tree instead of the view model; recycled list containers read for the wrong entry.
- Previews (hit chance, path, area) firing announcements during targeting.
- Scripted (Osiris) movement or spell use that bypasses the rules a player's action follows: free movement in combat, no resource cost, broken party follow. Verify before use; prefer the player's own command path.
- Clicking the world without checking the picking helper: Enter acts on the wrong target.
- Cursor warps near the window edge scrolling the camera.
- `KeyInput` prevented in one UI state but still reaching the game in another.
- Mod keys colliding with the hotbar, party portraits, quick save/load, end turn.
- Announcing hidden traps, invisible creatures or unrevealed objects (spoilers and an unintended assist).
- Screen-relative directions computed from the character's facing instead of the camera yaw (or the reverse) in one feature only.
- Honour-mode saves touched by test scripts.
- The bridge missing or blocked by antivirus → total silence. The installer self-test and an IMGUI warning for sighted helpers are mandatory.
- SE or loader updates changing file paths, event names or APIs; the loader's proxy DLL replaced by a game update.
- Achievements silently disabled; players surprised. Say it in the README.
- Everything in template_rpg 24.

---

## 18. Definition of done (BG3 additions to template_rpg 25)

- [ ] The blindfold campaign (15.3) is complete from the main menu to the credits.
- [ ] Every XAML page the game can show is either verified in `SCREENS.md` or recorded as unreachable in normal play with evidence.
- [ ] Every Osiris event and SE component the mod depends on is listed in `PATCH_TARGETS.md` with the game build and SE version it was verified on, and the gate announces untested versions.
- [ ] Install and uninstall work from a clean game, with a screen reader, without sighted help.
- [ ] Removing the mod leaves every save loadable.
- [ ] `STATUS.md` says so, with the date.

---

## Sources (research on 2026-09-24)

- Script Extender API reference: https://github.com/Norbyte/bg3se/blob/main/Docs/API.md
- Script Extender repository and source: https://github.com/Norbyte/bg3se
- Native Mod Loader: https://www.nexusmods.com/baldursgate3/mods/944
- Yet Another BG3 Native Mod Loader: https://github.com/MolotovCherry/Yet-Another-BG3-Native-Mod-Loader
- Existing visual accessibility mod (Easier Text): https://www.nexusmods.com/baldursgate3/mods/1037
- Divinity Engine: https://en.wikipedia.org/wiki/Divinity_Engine
