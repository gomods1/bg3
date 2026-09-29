# BG3 Access: screen reader accessibility mod for Baldur's Gate 3

Playbook: `gate.md` (read it; it specializes `C:\Users\Nitropc\code\mods\starting_points\template_rpg.md`).
This file holds what has been learned about *this* game. Anything marked **hypothesis** is not verified.
Progress: `STATUS.md` (read first). Coverage and what each path tested: `PLAYTEST.md`.
Every keyboard shortcut (mod and game), confirmed or not: `KEYS.md` (keep it current).
Plan: `ROADMAP.md`. Verified engine names: `PATCH_TARGETS.md`.
Screens/modes: `SCREENS.md`.

## User's standing instructions

- Make decisions yourself; do not stop to ask about things you can decide (EULA, tool choices, keys).
  Record decisions here instead. (Stop only for admin rights/drivers or prohibited actions.)
- First-run screens (EULA, explicit content, gamma, splash) must be accessible too.
- Explicit content setting stays "Sí" (the user's choice).
- The user runs NVDA; the game runs in **Spanish**. Game text reaches speech in Spanish; the mod's
  own strings follow the game's language (`Ext.Utils.GetGlobalSwitches().Language`, config
  `speech.language` "auto" or a code): a table for each of the game's 15 languages; es is the
  reviewed one, the others were machine-translated (game terms unverified). New strings go into
  every `Strings/<code>.lua`; `tools/check_strings.py` lists what a language lacks.
  `python tools/check_strings.py` (also run by deploy.py) catches duplicate, missing and
  mismatched keys.
- Download tools only from official sources; record the source. Players install with scripts.

## Machine and game facts (verified 2026-09-24)

| Fact | Value / evidence |
|---|---|
| Game folder | `S:\steam\steamapps\common\Baldurs Gate 3` (Steam app 1086940) |
| Build | 4.1.1.7398727 (exe version resource; SE reports it as "v4.73.98.727"). Data has `Patch8_HotFix9.pak`. |
| bg3.exe | SHA-256 `d8cfc0d6d568a2e7c4b1f7b34687c4aaed5506118bb458679b24a926231b85a0` (Vulkan) |
| bg3_dx11.exe | SHA-256 `e899c67cb90b9c6b0f052e3f758ba8615bc2012e52561c2af2e6a1e06ef61a2f` |
| SDL2.dll | dynamic, `bin\SDL2.dll`, SHA-256 `a93b1657...c34f0`. Both exes import it, and VERSION.dll, DWrite.dll. |
| Launch | `bin\bg3.exe --skip-launcher` (cwd `bin`) starts the game without the Larian launcher. On the very first (vanilla) run it relaunched itself as `bg3_dx11.exe`; later runs stayed `bg3.exe`. **Correction (2026-09-24, session 5): a Steam launch (`steam://rungameid/1086940`) opened LariLauncher.exe even with SE's `DisableLauncher` set**; the player installer makes a desktop shortcut to `bing3.exe --skip-launcher` instead (Steam running; that start worked on a fresh profile). |
| Window | 2560x1600 client, borderless. Screenshots via desktop duplication (`mss`), window brought to front. |
| Profile | `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\` (`PlayerProfiles\Public\modsettings.lsx`, `config.lsf`, `Mods\`). Backup of the post-first-run profile: `saves/profile-backups/2026-09-24-after-first-run`. |
| First run | EULA -> "Contenido explícito" -> gamma -> splash ("Pulsa cualquier tecla") -> main menu. Deleting `PlayerProfiles\Public\config.lsf` (`ShowFirstTimeSetup`) brings the flow back (used for testing). |
| **ModCrashSanityCheck** | The game creates `<profile>\ModCrashSanityCheck\` at launch and removes it on a clean exit or once the main menu is reached. **If it exists at launch, the game loads no mods at all** (SE runs, our Lua never loads, silence). Killed test sessions trigger it. `tools/game.py launch` deletes it (dev only). Players: after a crash the mod is silent until the next clean start; the bridge watchdog says so after 90 s without a Lua hello (verified). The flag is cleared at the main menu, so one restart fixes it. |
| Default keys | `Engine.pak: PlayerProfiles/Default/inputconfig.json` holds engine/debug/widget bindings only. The game's action bindings are not in any pak file; they were dumped at runtime (see "Game key bindings" below). SE uses **Ctrl+F12** (opens its console). |

## Game key bindings (defaults, dumped at runtime 2026-09-24 with `tools/console/dump_bindings.lua`)

Source: `Ext.Input.GetInputManager().InputScheme.RawToBinding` (the per-player `InputBindings`
LegacyArray reads garbage after its first element in SE v32). Keyboard, unmodified unless noted:

| Keys | Game action |
|---|---|
| W A S D, arrows, Q E, Delete/End, PgUp/PgDn, Home | camera move / rotate / zoom / center (arrows are also UI up/down/left/right) |
| Space | end turn, skip dialogue, take all, CC accept; Shift+Space: enter/leave turn-based, flee |
| Escape | cancel action, skip video, in-game menu, UI cancel. Enter / keypad Enter: UI accept |
| Tab | party character view / UI tab; Ctrl+Shift+Tab camera capture |
| 1-0, -, =, keypad 0-9 | hotbar slots. F1-F4 select character 1-4. [ ] cycle characters |
| F5 quick save, F8 quick load, F9 photo mode, F10 presentation | Ctrl+Shift+F1..F12: debug widgets |
| B tadpole powers, C sneak (Shift+C group stealth), F weapon set, G group mode, H alchemy, I inventory, J journal, K spells, L reactions, M map, N character, O tactical camera, P inspiration, R dual wield, T pin tooltip, U combat mode / UI tab next, V shove, X throw, Y short rest / UI tab prev, Z jump | |
| Left Alt | show world tooltips (highlight), Left Ctrl held: slow camera / attack objects / drag single; Left Shift held: climb, sneak cones, split stack, mark wares | |
| Backtick | highlight characters. Pause: pause | |
| Ctrl+C/V/X/Y/Z | copy, paste, cut, redo, undo (text widgets) |

Unbound: F6, F7, F11, F12 (SE console on Ctrl+F12), Insert, `;` `'` `,` `.` `/` `\`, keypad operators,
and **Ctrl + every letter except C V X Y Z**.

**Mod menu, not a key per feature (user rule, 2026-09-24)**: one key, **Ctrl+M**, opens the mod menu
(Screens/ModMenu): the commands usable right now (Core/Commands: id, group, `available()`, `run`),
combat and exploration first, then the screen's and speech commands; the screen in front can add its
own with `handler:Commands()`. Direct keys by default: only Ctrl+M, Ctrl+R (read screen) and Ctrl+D
(details), which act on the focused item. Any command can get a key in
`<profile>\Script Extender\BG3Access\config.json` (keys.<id>, "" = menu only); config v1's
Ctrl+letters are migrated out. New features register a command; they do not take a new key.
Screen handlers claim plain navigation keys (arrows, Enter, Space, Home/End, Tab) only while their
screen is in front. Never take Insert/Caps Lock (NVDA modifiers).

**Navigation follows meaning, not the screen's layout (user rule, 2026-09-29): read
`NAVIGATION.md`.** Lists are sections (Tab / Shift+Tab, `control.section` in Screens/ListScreen)
holding items (Up/Down; Left/Right a value, else the same as Up/Down), levels on Enter and
Escape/Backspace; one key grammar for every screen and list (History's buffers, Nearby's kinds,
the mod menu's groups, the hotbars, spell levels are sections since 2026-09-29, no longer
Left/Right); only the place cursor uses the arrows for space.

**Localizable code (user rule, 2026-09-24)**: the mod's words live only in Core/Strings (whole
phrases, `{named}` placeholders). Code never glues words: lists through `Strings.List`, sentences
through `Strings.Sentences`, numbers are passed as numbers (the language's decimal separator), a
numeric `{n}` picks the plural form (`key_one` / `_few` / `_many`, CLDR rules for the game's 15
languages), no case changes in code. Key names are strings too (`input_*`). Every new string gets
its Spanish line in `Strings/es.lua` at the same time (the user plays in Spanish; the checker lists
untranslated keys).

## Architecture (as built)

```
Native/                 Rust workspace (cargo build --release)
  proxy/  -> version.dll         bin\version.dll: forwards all 17 exports to System32 (linker forwarders),
                                 loads bin\BG3Access\BG3AccessBridge.dll on a thread. Only in bg3*.exe.
  bridge/ -> BG3AccessBridge.dll Prism speech worker (speech.rs), Lua->native channel (channel.rs),
                                 mouse warp/click (mouse.rs: every click starts with an X1 press, see
                                 "Mouse input"), logs (log.rs), watchdog (no Lua hello in
                                 90 s -> spoken). Speech re-checks for a screen reader every 5 s while
                                 on a TTS engine; `speech reset` message. Hooks only KernelBase!CreateFileW.
Mod/Mods/BG3Access/     the SE mod (packed to BG3Access.pak by tools/deploy.py with LSLib Divine)
  ScriptExtender/Lua/
    BootstrapClient.lua / BootstrapServer.lua   startup order: log, config, speech, gate, commands, keys, screens, dev
    Setup/  Commands (wires every feature to Core/Commands: the mod menu and optional direct keys)
    Core/   Log, Config (config.json, versioned with migrations), Strings (every mod string, keyed;
            List/Sentences/Number/plurals), Bridge (channel writer), Speech (Say; Event = say + record
            in Buffers), Buffers (review buffers: events, combat, dialogue), Keys (named actions from
            config + router), Commands (registry behind the mod menu), Help, Gate (tested versions),
            Text (game text cleanup), Timer (tick-driven short waits: SE timers step by ~233 ms)
    Game/   the ONLY layer that names engine things: Ui (visual tree, widgets), Vm (view-model
            reading, commands), Loca, Activate (activation ladder, click hints, verified grid
            clicks), Input (game key bindings), Spells (stats: type, range, area, details, title),
            Selectable (one-of-many choices), Paths (engine routes, dangerous tiles), SafeRoute
            (ways round them), SpellChoices (spell selectors), Reactions, per-screen accessors (Options, MessageBox, Difficulty, ActiveRoll, Dialogue, Tutorial...),
            XamlIndex / EnumNames (generated)
    Screens/ Router (registry: Module.Widgets / Module.DcTypes -> handler), ListScreen (base: list of
            controls, Build/Refresh, keys, help), Controls (Text, Button, OptionRow), Generic
            (fallback from the XAML index), ModMenu, Passive, Hud (in game: end-turn confirmation),
            History (buffers), ActiveRoll (dice), MainMenu, Difficulty, MessageBox, Options,
            LevelUp, Reactions, Choices (section + choice list), SpellWords, ItemWords, ...
    Exploration/ Nearby, Markers (mod screens), Travel (trips: the loop), TravelClicks (route ->
            points to click, verified ground clicks), TravelWaits (until stopped / door open /
            remark over), WhereAmI
    Combat/ Tracker (combat start/end, turns, party switch), Narrator (log, grouped per actor),
            LogWords (compact log wording), TurnOrder, Actions (hotbar
            list, items), Targeting (creatures), Place (ground cursor; also the Move command),
            Area (who an area catches), Words (combat phrases)
    Net/    Channels (client <-> server NetChannels, shared)
    Server/ Queries (read-only Osiris answers for the client)
    Dev/    DevChannel (harness Lua), UiDump
tools/  game.py (harness), deploy.py (dev deploy), xaml_index.py (Game/XamlIndex.lua), enum_names.py
        (Game/EnumNames.lua), console/ (dump_bindings.lua, ...)
```

Decision (2026-09-24, gate 5.4 controller UI): not used. The keyboard/mouse UI read through its
view models, driven by their commands and verified clicks, covered every screen met so far
(menus, character creation, dialogue, rolls, combat targeting with previews, level up, trade);
the controller UI would need controller input injected (SE injects keys only: an SDL hook in the
bridge or an admin-installed virtual gamepad for every player). Movement (gate 8.1): verified
ground clicks along the engine's routes (Exploration/Travel), never scripted movement.

Decision (2026-09-24): own `version.dll` proxy instead of a third-party native loader. The Nexus
Native Mod Loader needs a logged-in browser download; Yet-Another-BG3-NML needs admin (IFEO) or an
extra launcher exe. version.dll is imported by both exes, is not a KnownDLL, and does not collide
with SE (DWrite.dll) or the Nexus loader (bink2w64.dll). The bridge also works under any loader.

### Lua -> native channel (measured)

Lua `Ext.IO.SaveFile("BG3Access/bridge/out.msg", line.."\n")`. SE implements SaveFile with
`std::ofstream` -> `CreateFileW`. The bridge's KernelBase!CreateFileW hook returns a duplicate of the
write end of one long-lived pipe for exactly that path; a reader thread gets the bytes in order.
SaveFile takes **32-36 µs**; the bridge sees the message in the same millisecond. No disk I/O.
Bridge -> Lua: `BG3Access/bridge_status.txt` (read with `Ext.IO.LoadFile`). Hello round trip on
startup ("bridge answered after 1-2 polls" of 100 ms). SE's `Ext.IO.AppendFile` truncates (opens with
`ios::out` without `app`), so it is the same as SaveFile.

### Mouse input (measured 2026-09-24)

After keyboard input the game **swallows the first mouse button press**; the second always counts.
Cursor motion, even over several frames, does not help. So `mouse.rs` presses the X1 side button
(bound to nothing: the dumped mouse bindings are only left2, right2, middle, motion), waits 100 ms,
then clicks (buttons held 60 ms, on a worker thread). In-process SendInput is fine: an earlier
belief that the game ignores input injected from its own process was this same effect.

Protocol: `say <interrupt> <channel> <ttlMs> <text>` (text escaped: `\\` and `\n`), `stop`,
`hello <token>`, `log <text>`, `mouse move <fx> <fy>` (fractions of client area; refused unless the
game window is foreground), `mouse click <left|right>`.

### Speech

Prism 0.18.2 from `C:\Users\Nitropc\code\libs\prism\prism-windows-x64` (copied to `bin\BG3Access\`).
Backend chosen: **NVDA** (features 0xf5). Text arrives as valid UTF-8 (verified bytes `c3 a1` for á).
Spoken-line log: `<profile>\Script Extender\BG3Access\logs\speech.log`; bridge log next to it.
Note: printing these logs through Python in Git Bash needs `sys.stdout.reconfigure(encoding="utf-8")`
(done in game.py), otherwise accents look broken although the bytes are fine.

## Script Extender facts (v32 release channel, API v32, verified 2026-09-24)

- Installed from GitHub release v32 (`BG3SE-Updater-20260621.zip` -> `bin\DWrite.dll`, SHA-256 of the
  zip `2b451d04...ac25a`). The updater downloads the real DLL to
  `%LOCALAPPDATA%\BG3ScriptExtender\ScriptExtender\32.0.0.0_...\`. Devel channel has v33 (2026-07-04).
- Settings `bin\ScriptExtenderSettings.json` (dev): `LogRuntime` (needed for the runtime log; `EnableLogging`
  alone is the Osiris log), `LogDirectory`, `DeveloperMode` (needed for `Ext.Debug.Reset()`),
  `DisableLauncher`. Runtime log: `<profile>\Script Extender\BG3Access\logs\se\`.
- **Hot reload**: with `DeveloperMode`, loose scripts in `<game>\Data\Mods\BG3Access\ScriptExtender\`
  override the .pak, and `Ext.Debug.Reset()` reloads them without restarting (`deploy.py` syncs them;
  never put a `meta.lsx` there).
- Client Lua starts during the first loading screen (~21 s after launch), **before** the EULA, so every
  first-run screen can be handled from Lua.
- `Ext.Events.KeyInput` fires for real key presses on every screen tried (EULA, menus). `e:PreventAction()`
  makes SE's SDL_PollEvent hook return 0 for that event. Keys injected with `Ext.Input.InjectKeyPress`
  skip KeyInput (no loops) and do reach the game (title screen, difficulty carousel).
- `Ext.Require` only works from mod files, not from dev-channel code: modules are exposed on the
  `BG3Access` global for debugging. It also fails when called lazily at runtime (from an event or
  timer: "called without a mod"): require everything at the top of each module.
- Comparing an expired engine object with `== nil` throws (SE's `__eq`): test with `not obj`.
- Engine objects (UI elements, view models) expire at the end of the tick: never keep them in closures,
  timers or handler state; keep names and re-find (bit us once: all hover checks failed silently).
- `Ext.Utils.LoadString(code, env)` works (dev channel). `Ext.Debug.GenerateIdeHelpers` needs Osiris
  (in a loaded game). The repo's `ref/bg3se` is HEAD (2026-09-23), newer than v32: check before using.

## Noesis UI facts (verified 2026-09-24)

- Root: `Ext.UI.GetRoot()` = `ls.UICanvas#CanvasRoot` > Viewbox > Decorator > `Grid#ContentRoot` whose
  children are the open widgets (`ls.UIWidget`, z-order = child order). Overlays always present:
  `ScreenFade`, `CrossplayOverlay`, `ModDownloadingWidget`; transient `LeftPlayer`/`RightPlayer`;
  loading screen = widget `root` (dc `ls.LoadingScreen`).
- `VisualChild(i)` / `Child(i)` are **1-based**. `el:Find(name)` does not cross name scopes.
- `GetProperty(name)` returns only locally stored values: bound values (Content, Text, IsEnabled,
  Visibility from bindings) read as **nil**. `ActualWidth`/`ActualHeight` read fine (0 = collapsed).
  `IsMouseOver` reads true while hovered (latency after a cursor warp: < 600 ms).
- Static labels are loca handles in the XAML bindings:
  `Content="{Binding Source='h…', Converter={StaticResource TranslatedStringConverter}}"`. The mod gets
  them from `Game/XamlIndex.lua` (generated from `extract/<pak>/**/Pages/*.xaml` of Game, Gustav,
  GustavX and Patch8_HotFix9, later paks replacing earlier pages; Divine needs an absolute -d) and resolves them with
  `Ext.Loca.GetTranslatedString` in the game language.
- View models (`DataContext`) are fully readable (`GetAllProperties`), including ~200 commands on every
  gui DC (StartGameCommand, EndTurn, ToggleTurnBasedMode, UseGameObject, QuickSaveCommand, …).
- Commands: `cmd:CanExecute(param)` / `cmd:Execute(param)`; param must be a Noesis object or nil.
  **String parameters cannot be passed** (SE converts boxed values to Lua strings both ways and cannot
  box a Lua string), so `CustomEvent` buttons (`CommandParameter="OpenOptions"`) need a click.
  Many commands are deferred: effects appear on a later frame.
- Option rows (first-time setup, options menu): DC property `Options` (collection, 1-based) of VMs with
  `Text` (handle), `ListItemType` (ComboBox/TickBox/Button/…), `SelectedItem.Name` (handle),
  `ComboItems`, `Enabled`. Change with the DC's `NextComboItemCommand`/`PrevComboItemCommand`
  executed with the row as parameter (verified); `SetProperty("SelectedItem")` does nothing.
- Widgets are identified by `x:Name`, else by `ls:UIWidget.ContextName` (readable with GetProperty;
  e.g. `KeybindingOptions.xaml` has no x:Name).
- View-model rows accept `SetProperty("Value", v)` (bool tick boxes, float sliders); follow with the
  DC's `ValueChanged(row)` as the XAML does (verified on options rows). Read-only properties raise
  "Property X of T is read-only" (e.g. DCOptions.ActiveOptionsID).
- Options tab buttons (`gameplayButton` ...) send `CustomEvent` with a string: switched by verified
  click. No game key switches option tabs (U/Y/Tab tried).
- Key binding rows (`gui::VMKeybinding.BindingString`) read as `ResStr_…` in Lua; the row's Text handle
  equals `InputDefinitions[id].EventDesc` handle, so keys come from the input scheme (Game/Input).
- SE v32 has **no** `PointToScreen`/`HitTest` (added upstream 2026-07-27, not in any published build),
  so click positions come from measured `ClickHints` (fractions of the client area) and every click
  is verified with `IsMouseOver` first.
- **MultiBinding command parameters** (`SelectSpell` [selector, spell]) cannot be read (not stored)
  nor built: SE passes Noesis collections to Lua only as arrays, and refuses arrays as command or
  property arguments. Tried: the spell alone, a `Ext.UI.RegisterType` Collection, an
  `ItemCollection` (all accepted, no effect); `IsDefault` + Enter (no effect). The button itself
  must be pressed: `Activate.ClickGridItem` (grid position predicted from cell sizes x `Ui.Scale`,
  corrected by which item reports IsMouseOver; verified on Gale's spells).
- **IsMouseOver lags a cursor warp by 230-470 ms**: a reading right after a move can describe the
  previous position. Grid clicks only trust a reading that differs from the pre-move one (or after
  700 ms). The bridge's click lands ~220 ms after the request (X1 press first): check effects on the
  VM afterwards, not immediately.
- Item-template elements: their bound `DataContext` reads nil, but the generated container's
  `Content` (`el.TemplatedParent`) is the item (`Ui.TemplateItem`). Layout: `ActualWidth/Height`
  of the container and its panel (`VisualParent`); UI units are 2160 high (`Ui.Scale`).
- Tabs that are ListBoxItems (level-up spell tab, `levelupTab`) switch with
  `SetProperty("IsSelected", true)`: the game's triggers run as for a click.
- SE's `__eq` on engine objects throws when the other side is nil (`x == s` with x nil): use
  `Vm.Same(a, b)`. The same live object compares equal across reads.

## World interaction (verified 2026-09-24 on the nautiloid)

- World -> screen: the active camera's view and projection matrices (Game/Camera) put the character
  exactly where the screenshot shows it (2560x1600).
- Verified world click (Game/Activate.WorldClick): project the entity, warp the cursor, click only
  when the picking helper's `GameObject` is that entity. Clicking the mind flayer corpse opened its
  loot, exactly as a mouse click does. This is the player's own action (rules, stealth, party
  behave as for a sighted player); prefer it to scripted Osiris calls.
- Osiris `CharacterMoveToPosition` moves the host in exploration. **Dev probe only.**
- **Rule (user, 2026-09-24): no magic movement.** Characters travel only the way a player makes them:
  verified clicks on the ground or on targets (click-to-move with the game's own pathfinding, party
  follow, stealth, turn-based costs), and the character's own actions where a route needs them
  (Jump, climbing, ladders, doors). No teleports, no scripted Osiris movement or scripted
  interactions in the shipped mod. Engine pathfinding (`Ext.Level`) is only used to choose where
  to click next and to describe routes.

## Combat by keyboard (verified 2026-09-24, first nautiloid fight)

- Arm an action: HotBar DC `UseSlotCommand(slot)` (slots from
  `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[].SlotList`).
- Use it on a character: HotBar DC `TargetGameobjectCommand(characterVM)` (what a portrait click
  does): the character walks, attacks, spends the action, by the game's rules. **No mouse.**
- Preview (hit %, damage range, walk first, attack of opportunity) exists only for the hovered
  target: `CurrentPlayer.UIData.HitChanceDesc` etc., read after a verified cursor hover.
- Mouse confirm clicks after keyboard use were ignored by the game (instant or held clicks, nudged
  or not, with or without a raw relative move first); ground clicks and clicks on objects in
  exploration work. Prefer game commands to clicks whenever one exists (ladder rung 1).
- Camera: `Game/Camera.Yaw` = atan2(V[11], V[3]) of the view matrix (sign verified: turning toward a
  target puts it in the upper half of the screen). Q/E turn it about 100°/s.
- Items on the hotbar: a potion is drunk at once by `UseSlotCommand`; a scroll arms its spell (type
  from the item's SpellBook). `UIData.ActiveSlot` is set while armed (and during a potion use).
- Movement in combat: with nothing armed, a ground hover gives the walk cost preview
  (`MovementResourceCostPreview`); a verified ground click walks there and spends it (verified).
- The controlled character is `CurrentPlayer.SelectedCharacter` (the `ClientControl` component
  stays on the first party member).
- **The cursor resting on an enemy is a hover, not an armed action** (verified 2026-09-25, worg
  pens): with nothing armed, in combat, the game previews the main-hand attack on the hovered
  enemy: `UIData.ActiveSlot` is set exactly as for an armed action (the hotbar frames the slot),
  and when it cannot be used the cursor text says why ("No tienes suficientes recursos: Acción").
  That label is what players saw "stuck" on screen: it stays until the cursor leaves the enemy.
  Escape then opens the game menu; the hotbar DC's `CancelTaskCommand` / `ActionCancelCommand`
  change nothing. Moving the cursor off the world clears it: the mod parks it on the minimap
  (Activate.Park: 351 x 311 UI units from the top right corner, checked with IsMouseOver), and
  the HUD parks before following any armed action, so only an action still armed afterwards
  counts as the player's.
- Cursor text (`CursorText` widget, `CursorTextList` > "txt" TextBlocks, one per
  `ActiveTask.Info` entry): the Info handle keeps its "[1]"; only the shown text is filled
  (read with Ui.InlineText).
- **Picking**: `GameObject` of the picking helper is what a click acts on; its `Character` /
  `Item` fields can name someone else (the cursor "on" Camorrista Gurd sent Magic Missile's darts
  to Zami Ojo Avizor on a ledge behind him). Picking.IsHovered trusts GameObject when present.
- **Several fights at once** (verified 2026-09-25, the Sanctum): the game said "Varios encuentros
  de combate"; Tav fought Gut's goblins while Shadowheart and Gale fought three others. The turn
  order bar and the tracker follow the selected character's fight ("Combate: 5 enemigos" on F1).
- Hotbar `CanUse` is false for every slot while an animation plays (Rage): read it when the
  player acts, not when a list is built.
- Combat log damage templates: "[2] ha recibido un impacto de [3]", "[1] ha impactado a [2] e
  inflige [3]" (a thrown weapon is [1]); the damaged one is the reference just before the
  Damage-typed parameter. Multi-hit spells log identical lines that are real (two rays of 6).
- Equipping in combat costs the action; Acciones > "Equipar (Tav)" works on a weapon on the floor.
- The game menu, the map and other screens hide the whole HUD, the turn order bar
  (CombatantsOverlay) included, in the middle of a fight: the combat tracker waits while the
  hotbar is hidden (it said "Fin del combate" / "Combate" around every game menu).

## Exploration facts (verified 2026-09-24, session 3)

- Path requests need `CanUseLadders`/`CanUsePortals` set to true, or routes over ladders are not
  found at all. Ladders (portal entities with a `Ladder` component, e.g. "Malla arterial") are
  climbed by a verified click on the ladder, aimed 1-5 m above its foot (the character's body
  covers the foot); the character pauses at the foot before climbing (wait 2.5 s of stillness).
- **Engine pathfinding is complete and fast** (verified 2026-09-24, grove): 323 m route (1350
  checkpoints) grove -> ruins in a few ms; the whole level's AI grid is on the client. Failures seen:
  a target off walkable ground fails at once (`ErrorCause` 1, no search nodes: the map's area label
  "Arboleda Esmeralda" sits 29 m under the grove) -> `Ext.Level.GetHeightsAt(x, z)` gives the AI
  grid's walkable heights in that column (Paths.Snap). A closed door the character cannot open
  (the grove's portcullis) fails the search; with `CheckLockedDoors = false` it is found through
  the door (Paths.ClosedDoorOnWay names it). **Correction (2026-09-26): `SearchHorizon` (32000 nodes by default) IS a limit** on long winding routes: the Riverside Teahouse, the goblin camp and Halsin's marker failed from the Blighted Village with ErrorCause 1 and were found at 64000+ (teahouse: 1088 checkpoints, a 270 m detour east and down the hill, 47 ms); a search that cannot succeed stops when the reachable ground runs out (48-59 ms at 128000 or 512000). Paths.Find uses 256000. The teahouse was never a jump.
  `ErrorCause` 3 = found. So the mod needs no pathfinding of its own; what a blind player lacks
  is **destinations** (places with no marker and nothing clickable) and a way to see the map.
- Picked ground can be a ledge next to the route (grove stairs: within 3 m height of a route
  point, the click did not move Tav): Travel accepts a click only when the engine's own route to
  the picked ground ends on it (within 1 m height).
- Story scenes hold the party (druids on the grove stairs: dialogue starts on the way, the camera
  moves before the Dialogue widget shows): a trip that fails while a blocking widget is up counts
  as interrupted.
- World map regions (`WorldMap.RegionsContainer.Regions[]`: Guid, WorldPos, WorldSize) are region
  triggers with internal names only (`RegionTrigger_WLD_Main_001`): no display names.
- **Sub-area names** ("El Hueco", "Estanque sagrado"): the story declares
  `DB_Subregion(trigger, key, showMarker, level)` / `DB_SubregionMarker(trigger, key, marker, level)`
  (goals `_GLOBAL_Subregions`, `Act1_Subregions`...); `DB_Subregion_Current(character, trigger)` is
  the one each party member is in; `Ext.Loca.GetTranslatedStringKey(key)` returns the name's handle
  (11095 string keys; also `WAYP_*` for waypoints). Triggers are area triggers, many irregular
  polygons (El Hueco = `DEN_Cave_SUB`, 130 m across). No visited history in the story: the mod
  keeps one in a savegame mod variable (`Ext.Vars.RegisterModVariable`, server; survives F5/F8,
  verified) with the entry point of each place (Server/Places).
- Party members walk after the leader; a ground click can land on one who steps under the cursor
  (or on their overhead tag) and select them. `Player.Select(uuid)` = the DC's `SelectCharacter`
  with the character VM (the portrait's command, verified). Ground clicks keep a screen margin
  around companions; Travel reselects its walker.
- Osiris DB listeners work: `Ext.Osiris.RegisterListener("DB_Subregion_Current", 2, "after", fn)`.
- **Stuck camera**: after the strange ox's scene the game camera stayed 20 m from the party; Home
  and F1 F1 did nothing until a camera move key (W) was pressed once (Camera.CenterOn nudges).
- A click checked on the ground can still land on a creature walking into the cursor during the
  ~0.2 s before the click (the strange ox: its scene started). Known risk, not handled.
- The game's highlight (Left Alt) covers a radius (off-screen things included) but leaves out
  scenery: 23 `UseAction` items within 30 m of the brain-tank room, none highlighted.
- **Rule (user, 2026-09-24)**: nothing a sighted player can click may be left out of the mod's lists
  because the highlight skips it (Game/Interactables adds UseAction items and characters). How
  the game hides objects until found (perception, secret doors) is to be researched.
- Hidden objects, what is known (2026-09-24, session 5): Gale's passive Perception found a hole
  ("Agujero", an ItemPortal with TeleportOnUse) in El Hueco; the server item's `Known` flag was
  false before (save 18) and true after; it was never `Invisible` and no component differs. Many
  ordinary items are `Known = false` too, so Known alone does not mark hidden things. Also on the
  server: `IsSecretDoor` flag, Osiris `IsTrapDiscovered` / `SetTrapDiscovered`, `IsInvisible`,
  story-scripted checks (`DB_PerceptionSkillCheck`, `PROC_HiddenPerceptionCheckSucceeded`). The
  generic "hidden until Perception" marker is **still not found** (next: the item's stats or
  passives, the client's highlight of such items after discovery).
- Traps (2026-09-24, Risen Road): items with the `Disarmable` component (also `Invisibility`,
  field_0 1; names can be innocent: "Conducto", "Roca granítica"). Server: all 15 spike traps
  around read `IsTrapDiscovered` 1 and `IsInvisible` 1. The mod lists a trap only while it is not
  invisible (**hypothesis**: detecting one makes it visible; not yet seen), names it as a trap, and
  Enter never walks onto one. Whether routes avoid traps is untested.
- **Dangerous surfaces** (2026-09-24): engine routes go straight through fire (a trip to a dirt
  mound crossed the burning nautiloid wreck and killed Tav at 1 HP; save 29 restored).
  `path:UsePlayerWeighting()` exists in v32 but with the character's influences copied into
  `path.SurfacePathInfluences` the route still crossed the same fire (SE's weight function adds
  no surface cost). The mod checks route tiles itself (`Ext.Level.GetTileDebugInfo`
  GroundSurface / CloudSurface) against the walker's `SurfacePathInfluences.PathInfluences` with
  influence >= ExtraData `DamagingSurfacesThreshold` (35): Travel clicks stop before the first
  such tile and the trip ends with "hay fuego en el camino" (verified on the same trip). Fire
  tiles carry no AiBaseFlags (no mask trick), and the engine plans only from the walker.
  **Way round (Game/SafeRoute)**: the mod plans round a dangerous stretch itself, A* on a 1 m
  grid of the AI grid: `GetTileDebugInfo(p).Flags` (a list of strings) marks unwalkable tiles
  (`WalkBlock` walls/rocks/cliffs, `SlopeBlock`, `WalkBlockItem`; `WalkBlockCharacter` on the
  tile a character stands on), neighbouring heights may differ up to 1.5 m (stairs measured
  17.3 -> 16.0 -> 14.9 per meter), 1 m kept off dangerous tiles. The plan starts at the walker
  and rejoins the engine's route 4 m past the danger. Verified: Tav in a dead-end gully on the
  Risen Road whose exit was a fire patch from wall to wall; the engine routed through it, the
  plan went 105 m round (249 m instead of 146 m, 60-100 ms), and the walk reached the signpost
  unburnt (save 36).
  **Also the way to each click**: Tav died a second time (Risen Road, save 31 restored) walking
  from one safe click to the next straight across a burning patch the engine's route bent round:
  the game walks its own, nearly straight path to a click. A click is now accepted only when the
  engine's route to it is safe and the straight line to it keeps 1 m from any dangerous tile
  (Paths.DangerNearLine; skipped while standing in the fire); refused clicks lead to a step aside
  or "hay fuego en el camino".
- Doors take a moment to open: a second click during the opening shuts them. Travel waits for
  the server's "opened" after using a door on the way. A route may leave a dangerous surface the
  character stands on; a route that merely starts through one beside the character still counts
  (allowing that set Mira on fire on the nautiloid).
- **Unreachable targets**: `FindPath` fails with ErrorCause 1 both off the grid and when no route
  exists (a closed gate: the goblin camp from the Risen Road, the grove behind its gate); failed
  requests keep no closest point (ClosestFullTileIndex -1) and cost about 26 ms each (horizon
  32000 nodes). Paths.NearestReachable probes rings round the target over several frames.
- Signposts ("Señal"): a click on one makes the character read it aloud as an overhead line,
  e.g. Tav: «Oeste: Puerta de Baldur. Este: Elturel» (Risen Road, verified 2026-09-24).
- Dirt mounds ("Montón de tierra"): a click without a shovel: "No quiero ensuciarme las manos.
  Necesito una pala." (Survival checks roll on approach).
- **Routes from any point** (verified 2026-09-25): `Ext.Level.BeginPathfindingImmediate(entity, to)`
  then `path.SourceAdjusted = p; path.SourceOriginal = p` before FindPath plans from p (a route
  from (179,19,538) to Auntie Ethel's marker was found that way). WorldClimbType/WorldDropType
  (defaults 1/1) and WorldClimbingHeight (2.1) up to 15 found no way where none existed. Base for
  a jump search (a point reachable from the character, a landing within jump range from which the
  target is reachable). Ethel's marker from the forest below the Blighted Village: the nearest
  sampled points of the two sides lie 72 m apart (no jump); many samples belong to neither side.
- The engine's pathfinder plans ladders and teleport portals, not free jumps (no non-ladder
  portal on any route within 70 m of El Hueco): a gap it cannot route is "no way found".

## HUD facts (verified 2026-09-24, session 3)

- Story timer: `PlayerCharacterProperties.StoryTimer` (Description handle, TotalTime/CurrentTime in
  seconds, 6 s = 1 turn; CurrentCount/TotalCount for counter timers).
- Notification banner: `UIData.Notification` (Type, TitlePrefix/Title handles, Message.Text handle,
  ExtendedMessage template+Params); the VM keeps the last one. Area name:
  `PlayerCharacterProperties.CurrentSubregionName`.
- Spell slots: `Stats.SpellSlots[]` (Level, Value, MaxValue), not in ActionResources. Spells on the
  hotbar: `SpellSlotLevel`, `SpellUpcast[]`. Stats: `TooltipDamageList` RegainHitPoints = a heal,
  `SpellRoll.Default` Attack(...) / SavingThrow(Ability.X).
- After a level change (loading screen) the game refills the combat log with old entries.
- With nothing armed, hovering a corpse previews an attack; a Move click there would act on it.

- **World context menus** (widget WorldContextMenu, verified 2026-09-25): a verified right click on
  a thing or character opens the game's menu (pick up, "Usar (Tav)" digs a mound with a shovel,
  talk, attack, throw, examine...). It opens below-right of the click, **flipped to the left** of
  it near the right edge (menu size = the ContextMenu element's ActualWidth/Height). After an
  entry is clicked the game closes the menu itself: a cancel key sent then opens the game menu.
- **Throw** (verified 2026-09-25): the game's X key arms the common bar's Throw (Content
  PrototypeID Throw_Throw, TargetingType Throw); the hotbar then shows a "Lanzar" bar of inventory
  items. The object chosen (from the world, or an item's context menu "Lanzar") is
  `UIData.ActiveTask.TaskObject`; the action stays armed for step 2 (where). The game refuses
  heavy things ("Pesa demasiado, no se puede lanzar": characters of 75 kg for Strength 17) and
  static ones ("El objetivo no puede moverse por la fuerza": server `Osi.IsMovable` 0).
  Character weight/Strength on the client: `Data.Weight` (g), `Stats.Abilities[2]`.
- A place click (Place) can be lost like a target click: checked (armed state, log) and repeated.
- Tactical camera: input event `ToggleTacticalCamera` (O); view pitch about -82 degrees against
  -52..-56 for the usual camera (Camera.Pitch/IsTactical). In the dark worg pens it made targets
  aimable that the usual view hid.
- In combat the game arms the main-hand attack by itself after a spell, even with no action left
  (ActiveSlot.CanUse false). Some log lines are written twice with another line between.
- Key combos arrive with SDL scancode names: the Delete key is `DEL` (logged with debug.logKeys).
- Stealth: status SNEAKING (+ SNEAKING_CLEAR) on the client StatusContainer; server
  `Osi.CanSee(observer, target)` is false for a hidden character (it means noticed, not line of
  sight); `CanSpotSneakers(npc)` exists too.
- Relations out of combat: server `Osi.IsEnemy(a, b)` / `Osi.IsAlly(a, b)` (Blighted Village gate
  goblins and the ogres read neutral to Tav, companions ally). Signposts: `Data.StatsId`
  "OBJ_Signpost", UseAction `StoryUse`.
- The Examine window's `ExamineTarget` for a character is a full character VM (Stats.Race,
  Background, ClassList[] with SubclassDisplayName, PlayerCharacterProperties.ApprovalRatings[]
  { Character, Rating, Description }); NPCs have no ClassList (level only).
- Level up: any DC's `StartLevelUp(characterVM)` opens it; widget CharacterLevelUp; finishing
  is `FinishLevelUp("Overview")` (string: click `finishLevelUpButton`, hint 0.566/0.930).
  `SelectSpell` takes a multi-binding [selector, spell] (pressed by grid click, see Noesis facts);
  subclass: DC `SelectedSubClass` (SetProperty, as in character creation). Resource display names:
  `Ext.StaticData.GetAll("ActionResource")` -> Name, DisplayName.
  Clicks on the level-up panel work only after its intro (`LevelUpStep` IntroComplete, 9-18 s;
  `levelUp.IsHitTestVisible` stays true from the previous character in a chain, no guide); once
  the third chained level up stayed in the intro for minutes: closing and reopening it fixed it.
  Passive choices (Wildheart hearts, fighting styles...): `ClassProgressionDetails.
  SubPassiveSelectors`/`NotSubPassiveSelectors`, chosen with the DC's `TogglePassive(passive)`
  (a command, no click); a passive's description is the PassiveData stat with its icon and name.
  Boosts carry their own line (`NameCTS`: "Espacios de conjuro de nivel 2 desbloqueados").
- SE's Lua has no `utf8` library.
- Objects: `Visual.Visual.WorldBound` (world AABB) for aiming at an object whose origin is covered.
- The camera does not always follow the walking character: the game's Home key centers it.
- Route point heights (Ext.Level paths) do not always follow the terrain: downhill toward the
  windmill a point 1.9 m above the ground was picked 4.5 m further along the path. Travel accepts
  a click whose picked ground lies within 2 m of any route point. Ground just behind a character
  (as the camera sees it) is covered by the body: step toward the camera, not away from it.
- SE refuses every command of `gui::DCSavegames` (load screen): choose with `SelectedSave`
  (SetProperty) and load with the game's Enter (the Load button's BoundEvent UIAccept). The game
  menu's buttons are CustomEvents; `OpenLoadGameDialog` on any DC opens the load screen.
- World map axes: north (up on the map) = +z, east = +x (checked against two markers).
- Out-of-combat targets without a combatant VM (other characters, destructible objects with a
  Health component such as the "Base debilitada" under Lae'zel's cage) are confirmed by a verified
  click; the portrait command only knows combatants.

## Dice roll bonuses (verified 2026-09-24, Kagha's check)

- `NearbyPartyCharacters[].BoostModifierList[]` (BoostModifier = spell VM "Guía", DiceTypeSet.Str
  "1d4"); `SelectedBoostModifierList` = added. The "Añadir bonificador" button only shows the
  `BoostList` grid (SetProperty Visibility works); AddModifierCommand has a MultiBinding param:
  verified click on the item (`bgImg` cells). With bonuses, ResultNumber grows after the bonus
  dice: wait for RollState ResultReady; each added bonus then has Min = MaxBonusValue = its roll.
- A character's "!" (wants to talk): the story's `PROC_ExclamationMark_Show` (Shared
  `_GLOBAL_Shared_RelationshipDialogs`) plays VFX_UI_ExclamationMark and sets the tag
  HAS_EXCLAMATION_DIALOG (e45ea222-a86f-4e00-a1ca-98d8b258b1ce), which the client sees
  (`Entities.WantsToTalk`). `ecl CharacterFlags3.HasDialog` is on everyone (not it).

## Strings into the game (2026-09-24)

- A Lua string cannot be a command parameter, and `SetProperty` on a VM string property does
  nothing, but a UI **LSTextBox**'s `SetProperty("Text", s)` works and its two-way binding updates
  the VM (character creation's name box, even while its page is hidden). VM strings read back as
  "ResStr_..." ids: the mod remembers what it typed. No text-input event in SE: Screens/TextEntry
  maps scancodes (A-Z, digits, space, - and ') to characters.
- Game texts carry "[IE_<InputEvent>]" placeholders: Input.FillPlaceholders gives the key's name.
- Tutorials: static data `TutorialUnifiedEntry` (144): TutorialName (stable English id),
  DisplayTitle / KeyboardDescription handles; a shown tutorial's Title handle finds its name
  (Game/Tutorial.NameForTitle); Screens/TutorialHints adds the mod's keyboard way.

## Trade facts (verified 2026-09-24, Arron)

- Widget `Trade`: `TraderInventory.Slots[]`, `PartyCharacterInventories[]` (OwnerObject,
  TradeInventories[].Slots[]), items are ls.VMItem plus `TradePrice`; coins have ItemType "Gold".
  `TradeItemCommand(item)` buys or sells at once in Mode "Trade" (the double click); gold in
  `TradePartyGold` / `TraderInventoryGold` changes a few frames later.
- A marker's entity can be unloaded on the client until the party is close (Arron 55 m away):
  Travel.Interact walks to the marker's position and waits for it to load.

## Items (verified 2026-09-25, goblin camp)

- An item's stats: the item entity's `Data.StatsId` (WPN_Greataxe, ARM_Leather) then
  `Ext.Stats.Get`: Damage "1d12", "Damage Type", VersatileDamage, "Weapon Properties"
  {Twohanded, Melee, Heavy, Dippable}, "Proficiency Group" {Greataxes, MartialWeapons},
  BoostsOnEquipMainHand "UnlockSpell(...)" (the weapon actions), DefaultBoosts
  (WeaponEnchantment(n)), PassivesOnEquip; armour: ArmorClass, ArmorType, Shield. Names in the
  game's language from the tooltip templates (Game/EnumNames: DamageTypeNameTemplate,
  Tooltips.TypeId, EquipmentProficiencyNameStyle). The item VM has Stats.Weight.Value (kg) and
  Stats.Range.Value. A character's proficiencies: entity `Proficiency.Flags`.
- The character panel follows the selected character: the game's `[` `]` (scancodes 0x1A/0x1B,
  US positions) and F1-F4 switch with the panel open.
- The equipment's LightSource slot has no name in any game template (the panel does not show it).
- A wizard learns a scroll from its context menu: "Aprender conjuro (Necesitas 50 de oro para
  aprenderlo)", disabled without the gold. "Enviar a > Gale" moves an item to Gale at once.
- Passages (items with `ItemPortal`: the Sanctum's "Puertas pesadas de roble", "Entrada al cubil
  de huargos") move the party when used. A plain left click on one can be lost (the Sanctum
  doors after a walk) or refused with "No puedes llegar" (the worg pens' entrance from inside the
  Sanctum), while the thing's context menu "Usar (Tav)" makes the game walk its own way round
  (120 m) and go in. The mod checks that a used passage moved the party and falls back to the
  menu's first entry (ContextMenu.UseFirst).
- Doors on a trip: an **open** door's leaf can stand on the ground the next click aims at; the
  trip took it for a closed door and clicked it shut. Doors are now clicked only when the server
  says they are closed.
- A target 2 m in front of the character is hidden by its body both from the usual view and from
  a view turned toward it: Travel.Interact looks from the side for targets under 3 m.
- Priestess Gut (story, verified): "Sí. Adelante" twice; she wants no onlookers (companions
  within ~12 m of her chapel keep the ritual from starting; 30-40 m away works; unchain them with
  G first or the leader drags them along); at the ritual she locks her chapel door, "Atacar"
  starts a fight in which she calls for help: the goblins outside cannot enter but hit through
  it with spells and arrows (Tav, left idle, died). Her key opens "Entrada a los aposentos de la
  sacerdotisa", a passage down to the "Templo profanado" that ends the fight.

## Party split and regroup (verified 2026-09-25)

- With the party split into groups (the game's G), fast travel and "Abandonar el campamento" move
  only the leader's group; leaving camp puts each character back where it was before camp.
  A long rest (even a partial one) gathers everyone in camp; G there joins the groups (it says
  "¡El grupo objetivo está demasiado lejos!" when the others are far); a fast travel by the
  joined party then takes everyone.
- Camp supplies: item VM `CampSupplies` per unit (Provisiones 40, Sandía and Filete crudo 10,
  Pescado 4, Uvas 2); a full long rest needs 40; food selected on the rest screen is used even
  when it cannot reach 40 (Enter on a selected food deselects it). Trade prices of stacks are
  for the whole stack (Provisiones x3: 300).

## Dialogue facts (verified 2026-09-24, Shadowheart's pod)

- Answer tags: `Name`/`Category` handles ("Bárbaro"/"Clase"), `IsRoll` for checks ("Fuerza").
- Dice roll widget `ActiveRoll`: a real Enter did nothing; `UserTriggeredNextPhaseCommand(nil)`
  rolls and later continues. The result (`FinalResult`, `ResultNumber`, `Success`) is known right
  after the command, before the animation ends (`RollState` ResultReady).
- The dialogue widget is left and re-entered around the roll screen and tutorials: reading state
  must survive handler instances.
- History gets a whole exchange at once (lines voiced 11 s apart arrive together); `ActiveDialogue.
  BodyText` is the line being said now: the reader follows it (the player's own answer only shows
  in History).
- Rolls: the reroll button needs `InspirationPoints > 0` and `CanRespondToCommands` (the command's
  CanExecute is true regardless); `UserTriggeredNextPhaseCommand` does nothing while the dice still
  roll (StartRoll); a fixed-bonus ResultNumber can lag the die for a moment.

## Keyboard reach of the game's own UI (keyboard/mouse UI, verified)

| Screen | Game's own keys |
|---|---|
| EULA, explicit content, gamma | none (Enter, Tab: nothing). Mouse only. |
| Splash ("press any key") | any key |
| Main menu | arrows do nothing visible; mouse only |
| Difficulty (DMSettings) | Left/Right change the preset (real and injected keys) |
| Options | Escape closes |

## Offline tests (`tools/test_lua.py`, 2026-09-26)

`python tools/test_lua.py [pattern]` runs `tests/lua/*_test.lua` in Lua 5.4 through **lupa**
(PyPI `pip install lupa`; decision: no Lua on the machine, lupa bundles the SE's Lua version) with
a stub of the SE API (Ext.Require against the mod's Lua folder, Tick/KeyInput subscribers, a
movable clock, in-memory Ext.IO). Pure modules are tested there (Strings, Text, Keys, Poll,
Recent, Words); `syntax_test.lua` compiles every module. Engine objects are not stubbed: what
reads the UI or entities is verified in the game (PLAYTEST.md). Add a test with each pure change.

Polling: every reader of game state registers with `Core/Poll.Every(name, ms, fn)` (one Tick
subscriber, cost statistics: `game.py lua 'return BG3Access.Poll.Report()'`). Measured 2026-09-26:
the six pollers together cost about 5 ms per second on the HUD.

## Test harness (`tools/game.py`)

`launch` (removes ModCrashSanityCheck, starts bg3.exe --skip-launcher), `stop` (kill by PID, waits),
`shot <name>`, `press <keys>` (focus + SendInput scancodes), `click x y` (full-res client coords),
`lua <code>` / `lua-file <path> [trailing code]` (dev channel, client state), `log`, `blog`, `selog`,
`wait-log <text>`, `back` (Escape only while a screen or mod list is open: a stray Escape on the
HUD opens the game menu), `lua-server <code>`, `save <name> "<note>"` (quick-save + backup to `saves/NN_name` with a README),
`saves` (list), `restore <name|NN>` (back into the profile, then load it in game). **Back up before
every risky test and at every new place/branch (user rule, 2026-09-24)** so bugged branches can be
retested. Dev deploy: `python tools/deploy.py` (all) or `--lua`; hot reload:
`deploy.sync_loose()` then `lua 'Ext.Debug.Reset()'`.
`press` also takes US-position keys as raw scancodes: `lbracket`, `rbracket`, `backtick`...
Lua `print` output does not come back: `return` a string. `source tools/mod.sh` gives
`modcmd <id>` (run a mod command), `modsel <text>` (cursor to the entry containing text) and
`modlist` (the open list as spoken).

## Player installer (verified 2026-09-24, session 5)

`install/` (install.bat/.ps1, uninstall.bat/.ps1, README.md), packaged by `python tools/package.py`
into `dist/BG3Access-<version>/` + .zip (release pak with `BG3Access.Debug = false`: no dev channel).
Verified: fake game folder round trips (fresh profile, existing SE settings, foreign version.dll
refused, uninstall leaves files and modsettings.lsx exactly as before, SE downloaded from GitHub
v32); the real game with a deleted profile (no modsettings.lsx, no config.lsf): the installer's
default modsettings.lsx was kept by the game's first start, and the release build read the EULA.
Facts: the exe's version string is `ProductVersion` (FileVersion reads 1.0.0.0);
`Get-FileHash` is missing when the Utility module does not autoload (use .NET SHA256); `$matches`
and `$Profile` are PowerShell automatic variables.

## Pitfalls met

- The player profile can be reset between sessions (2026-09-24 session 2: no `Mods\` folder,
  modsettings.lsx without BG3Access, first-run flow again). Symptom: silence, SE log shows no
  BG3Access bootstrap. Fix: `python tools/deploy.py`.
- `game.py press ctrl` presses C (bare modifiers are not keys in the harness).
- The Bash tool can run sandboxed (2026-09-26): the game window is invisible to it (`press`,
  `click`, `shot` say "no game window"). Run those through the PowerShell tool; `lua`, `log`,
  `wait-log` work from either (file based).
- The main menu's "Continuar" loads the newest save by time, which may be another game's
  (2026-09-26: a fresh nautiloid autosave instead of the Blighted Village): load by name instead
  (`restore NN`, then the mod's `loadGame` list).

- Git Bash heredocs ate backslashes in Rust sources: write source files with the Write tool.
- `cp` onto the .pak fails while the game is still exiting ("Device or resource busy"): `stop` waits now.
- A second `meta.lsx` in `Data\Mods\BG3Access` must be avoided (hypothesis that it breaks loading was
  never isolated; the real culprit that day was ModCrashSanityCheck).
