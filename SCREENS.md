# SCREENS

Status: not started / announced / navigable / verified (verified = tested with a screen reader,
edge cases included). XAML inventory: `extract/Game/Mods/MainUI/GUI/Pages/` (168 files, `_c` =
controller variant); more XAML in Gustav (19), GustavX (10), Patch8_HotFix9 (53) paks, not extracted yet.

| Screen | Widget / file | Entry signal (verified) | Game keys | Mod handling | Status |
|---|---|---|---|---|---|
| Larian launcher | CefSharp web view | skipped (`--skip-launcher`, SE `DisableLauncher`) | | | n/a |
| Loading screen | `root` (ls.LoadingScreen) | front widget | | "Loading" | announced |
| EULA | `Eula` / Eula.xaml | front widget | none | generic list; Accept by verified click | navigable |
| Explicit content | `SensitiveSettings` | front widget | none | option row (Left/Right), Continue click | navigable |
| Gamma | `GammaCalibration` | front widget | none | generic; Accept click | navigable |
| Splash | `SplashScreen` | front widget | any key | speaks its text, no key claims | navigable |
| Main menu | `MainMenu` | front widget | none | buttons-only list; commands or clicks | navigable |
| Difficulty | `DMSettings` | front widget | Left/Right | announces preset; generic list for buttons | announced |
| Options | `GameOptions` (DCOptions) | front widget | Escape | option rows (ComboBox operable) | announced |
| Message box / confirmation | any widget with dc `ls.DCMessageBox` (e.g. `Dialog_box`) | front widget + dc type | Enter/Escape bound (UIAccept/UICancel), untested | title, text, buttons; Execute ActionCommand | navigable |
| Everything else | see XAML list | | | generic fallback | not started |

## Play modes

Not started (no game session yet).
