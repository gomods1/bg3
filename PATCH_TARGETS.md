# PATCH_TARGETS

Every engine name the mod depends on, with where it is used and the build it was verified on.
Game 4.1.1.7398727, SE v32 (release), verified 2026-09-24 unless noted.

## OS / native (bridge)

| Target | Use | Notes |
|---|---|---|
| `KernelBase!CreateFileW` (inline hook, retour) | Lua->native channel | matches path suffix `Script Extender/BG3Access/bridge/out.msg`, GENERIC_WRITE |
| `version.dll` exports (17, forwarded to `\\.\GLOBALROOT\SystemRoot\System32\version.dll`) | proxy load | bg3.exe imports GetFileVersionInfoW, GetFileVersionInfoSizeW, VerQueryValueA |

## Script Extender API (client unless noted)

| API | Use |
|---|---|
| `Ext.IO.SaveFile` / `LoadFile` (UserProfile root = `<profile>\Script Extender\`) | channel, status, dev channel |
| `Ext.Events.KeyInput` (Key, Modifiers, Pressed, Repeat; `PreventAction`) | mod keys |
| `Ext.Events.Tick`, `Ext.Timer.WaitForRealtime`, `Ext.Timer.MonotonicTime/MicrosecTime` | router, timers |
| `Ext.Input.InjectKeyPress(scancodeName)` | harness / key injection |
| `Ext.UI.GetRoot`, element `VisualChildrenCount/VisualChild(i)`, `ChildrenCount/Child(i)` (1-based), `GetProperty`, `GetAllProperties`, `Type` | UI reading |
| ICommand `CanExecute(param)` / `Execute(param)` | activation |
| `Ext.Loca.GetTranslatedString(handle)` | labels |
| `Ext.Utils.LoadString(code, env)`, `Ext.DumpExport` | dev channel |
| `Ext.Debug.Reset()` (DeveloperMode) | dev hot reload |

## Noesis widgets / elements / view models

| Widget (x:Name) | DC type | Elements / properties used |
|---|---|---|
| `ContentRoot` (Grid) | | children = open widgets |
| `Eula` | ls.Widget | `AcceptBtn` (CustomEvent OpenSensitiveSettings), `ToSButton`, `PrivacyButton`, `Message` |
| `SensitiveSettings` | gui::DCFirstTimeSetup | DC `Options[i]` rows; `NextButton` (CustomEvent OpenGammaCalibration); DC `Next/PrevComboItemCommand(row)` |
| `GammaCalibration` | gui::DCGammaCalibration | `AcceptButton` (CustomEvent CloseWidget), `ResetButton` (ResetToDefaultCommand) |
| `SplashScreen` | ls.Widget | first static text |
| `MainMenu` | gui::DCMainMenu | `NewGameButton` (StartGameCommand), `LoadGameButton` (OpenLoadGameDialog), `OptionsButton`/`CreditsButton`/`ModsButton` (CustomEvent), `QuitGameButton` (QuitGameCommand); DC `HasSaveGames` |
| `DMSettings` | gui::DCDMSettings | `PresetList.SelectedItem` (gui::VMPreset: Title, Description handles, IsHonour) |
| `GameOptions` | gui::DCOptions | DC `Options` (24 rows), `ActiveOptionsID` |
| `root` | ls.LoadingScreen | loading screen |

## Click hints (fractions of client area, 2560x1600)

See `Game/Activate.lua` `ClickHints`: Eula AcceptBtn (0.5, 0.931), SensitiveSettings NextButton
(0.5, 0.931), GammaCalibration AcceptButton (0.5, 0.931), MainMenu OptionsButton (0.222, 0.715).
Verified: Eula Accept, SensitiveSettings Next, Gamma Accept, MainMenu Options.
