# BG3 Access: screen reader accessibility mod for Baldur's Gate 3

Playbook: `gate.md` (read it; it specializes `C:\Users\Nitropc\code\mods\starting_points\template_rpg.md`).
This file holds what has been learned about *this* game. Anything marked **hypothesis** is not verified.
Progress: `STATUS.md` (read first). Plan: `ROADMAP.md`. Verified engine names: `PATCH_TARGETS.md`.
Screens/modes: `SCREENS.md`.

## User's standing instructions

- Make decisions yourself; do not stop to ask about things you can decide (EULA, tool choices, keys).
  Record decisions here instead. (Stop only for admin rights/drivers or prohibited actions.)
- First-run screens (EULA, explicit content, gamma, splash) must be accessible too.
- Explicit content setting stays "Sí" (the user's choice).
- The user runs NVDA; the game runs in **Spanish**. Game text reaches speech in Spanish; the mod's
  own strings are English for now (localize later, M8).
- Download tools only from official sources; record the source. Players install with scripts.

## Machine and game facts (verified 2026-09-24)

| Fact | Value / evidence |
|---|---|
| Game folder | `S:\steam\steamapps\common\Baldurs Gate 3` (Steam app 1086940) |
| Build | 4.1.1.7398727 (exe version resource; SE reports it as "v4.73.98.727"). Data has `Patch8_HotFix9.pak`. |
| bg3.exe | SHA-256 `d8cfc0d6d568a2e7c4b1f7b34687c4aaed5506118bb458679b24a926231b85a0` (Vulkan) |
| bg3_dx11.exe | SHA-256 `e899c67cb90b9c6b0f052e3f758ba8615bc2012e52561c2af2e6a1e06ef61a2f` |
| SDL2.dll | dynamic, `bin\SDL2.dll`, SHA-256 `a93b1657...c34f0`. Both exes import it, and VERSION.dll, DWrite.dll. |
| Launch | `bin\bg3.exe --skip-launcher` (cwd `bin`) starts the game without the Larian launcher. On the very first (vanilla) run it relaunched itself as `bg3_dx11.exe`; later runs stayed `bg3.exe`. SE setting `DisableLauncher` also skips the launcher for Steam launches. |
| Window | 2560x1600 client, borderless. Screenshots via desktop duplication (`mss`), window brought to front. |
| Profile | `%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\` (`PlayerProfiles\Public\modsettings.lsx`, `config.lsf`, `Mods\`). Backup of the post-first-run profile: `saves/profile-backups/2026-09-24-after-first-run`. |
| First run | EULA -> "Contenido explícito" -> gamma -> splash ("Pulsa cualquier tecla") -> main menu. Deleting `PlayerProfiles\Public\config.lsf` (`ShowFirstTimeSetup`) brings the flow back (used for testing). |
| **ModCrashSanityCheck** | The game creates `<profile>\ModCrashSanityCheck\` at launch and removes it on a clean exit or once the main menu is reached. **If it exists at launch, the game loads no mods at all** (SE runs, our Lua never loads, silence). Killed test sessions trigger it. `tools/game.py launch` deletes it (dev only). Players: after a crash the mod is silent until the next clean start: the bridge should detect "no Lua hello" and say so (todo). |
| Default keys | `Engine.pak: PlayerProfiles/Default/inputconfig.json` holds engine/debug/widget bindings only (arrows, Enter, Escape, Tab, Home/End, ctrl+shift+F-keys for debug widgets). The game's own action bindings are not in that file: dump them at runtime (`Ext.Input.GetInputManager()`) before choosing mod keys. SE uses **Ctrl+F12** (opens its console). |

## Architecture (as built)

```
Native/                 Rust workspace (cargo build --release)
  proxy/  -> version.dll         bin\version.dll: forwards all 17 exports to System32 (linker forwarders),
                                 loads bin\BG3Access\BG3AccessBridge.dll on a thread. Only in bg3*.exe.
  bridge/ -> BG3AccessBridge.dll Prism speech worker (speech.rs), Lua->native channel (channel.rs),
                                 mouse warp/click (mouse.rs), logs (log.rs). Hooks only KernelBase!CreateFileW.
Mod/Mods/BG3Access/     the SE mod (packed to BG3Access.pak by tools/deploy.py with LSLib Divine)
  ScriptExtender/Lua/
    BootstrapClient.lua / BootstrapServer.lua
    Core/   Log, Bridge (channel writer), Speech, Keys (KeyInput + router), Text (cleanup)
    Game/   Ui (Noesis access, the only tree walker), Activate (activation ladder), XamlIndex (generated)
    Screens/ Router (front widget -> handler), Generic (virtual list), Difficulty
    Dev/    DevChannel (harness Lua), UiDump
tools/  game.py (harness), deploy.py (dev deploy), xaml_index.py (generates Game/XamlIndex.lua), console/
```

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
  `BG3Access` global for debugging.
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
  them from `Game/XamlIndex.lua` (generated from `extract/Game/**/Pages/*.xaml`) and resolves them with
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
- SE v32 has **no** `PointToScreen`/`HitTest` (added upstream 2026-07-27, not in any published build),
  so click positions come from measured `ClickHints` (fractions of the client area) and every click
  is verified with `IsMouseOver` first.

## Keyboard reach of the game's own UI (keyboard/mouse UI, verified)

| Screen | Game's own keys |
|---|---|
| EULA, explicit content, gamma | none (Enter, Tab: nothing). Mouse only. |
| Splash ("press any key") | any key |
| Main menu | arrows do nothing visible; mouse only |
| Difficulty (DMSettings) | Left/Right change the preset (real and injected keys) |
| Options | Escape closes |

## Test harness (`tools/game.py`)

`launch` (removes ModCrashSanityCheck, starts bg3.exe --skip-launcher), `stop` (kill by PID, waits),
`shot <name>`, `press <keys>` (focus + SendInput scancodes), `click x y` (full-res client coords),
`lua <code>` / `lua-file <path> [trailing code]` (dev channel, client state), `log`, `blog`, `selog`,
`wait-log <text>`. Dev deploy: `python tools/deploy.py` (all) or `--lua`; hot reload:
`deploy.sync_loose()` then `lua 'Ext.Debug.Reset()'`.

## Pitfalls met

- Git Bash heredocs ate backslashes in Rust sources: write source files with the Write tool.
- `cp` onto the .pak fails while the game is still exiting ("Device or resource busy"): `stop` waits now.
- A second `meta.lsx` in `Data\Mods\BG3Access` must be avoided (hypothesis that it breaks loading was
  never isolated; the real culprit that day was ModCrashSanityCheck).
