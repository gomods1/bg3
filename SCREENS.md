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
| Main menu | `MainMenu` | front widget | none | buttons-only list; commands or clicks; Load unavailable without saves (VM `ExistingSaves`) | navigable |
| Difficulty | `DMSettings` | front widget | Left/Right | announces preset; generic list for buttons | announced |
| Options | one widget per tab: `GameOptions`, `KeybindingOptions` (no x:Name: ContextName), `VideoOptions`, `AudioOptions`, `InterfaceOptions`, `AccessibilityOptions`, `ControllerOptions` (hidden) | front widget | Escape closes | every row type operable (ComboBox, TickBox, Slider, list Button, headers); key bindings read (rebinding todo); Tab/Shift+Tab switch tabs (verified click); Back (Escape), Reset | navigable |
| Message box / confirmation | any widget with dc `ls.DCMessageBox` (e.g. `Dialog_box`) | front widget + dc type | Enter/Escape bound (UIAccept/UICancel), untested | title, text, buttons; Execute ActionCommand | navigable |
| Character creation | `CharacterCreation` (gui::DCCharacterCreation) | front widget (HUD hidden by the state machine) | CC Accept = Space | sections + sub-lists driven by the VM (choices, abilities, bonuses, skills, summary, random, finish) | navigable (gameplay part) |
| Tutorials prompt | `Dialog_box` (ls.DCMessageBox) with check box | front widget | | message box + check box | navigable |
| Saving | `Saving` | front widget | | "Saving" | announced |
| Videos (intro, cinematics) | no visible widget | router: nothing visible | Escape skips | "Video. Escape skips it." | announced |
| In game, HUD only | HUD widgets (Minimap, HotBar, ...) | router: only HUD visible | all game keys | silent, no key claims | n/a (play modes todo) |
| Loot / container | `ContainerWidget` (gui::DCContainerInventory) | front widget | Escape closes, Space takes all | container name, items (Ctrl+D description), Take all | navigable |
| Tutorial popup | `ModalTutorial` (Tutorial.xaml, gui::DCTutorial) | front widget | Escape finishes | title + text on open, Continue/Finish | navigable |
| Mod menu (mod screen) | anywhere, Ctrl+M | mod key | | commands available now; opens over the current handler and gives it back | navigable |
| Nearby (mod screen) | over the HUD, from the menu | mod menu | | highlight list + doors, Enter = travel and use | navigable |
| Dialogue | `Dialogue` (gui::DCDialogue) | front widget | number keys answer, Space skips | lines from History as they come, options list, Enter answers via the option's BoundEvent key | navigable |
| Actions (mod screen) | over the HUD, from the menu | mod menu | Space = end turn stays the game's | hotbar as a list; Enter arms; then targeting, self (shouts) or the place cursor by targeting type | navigable |
| Targeting (mod screen) | after arming a Target/Projectile/Throw action | | | targets with the game's preview (+ "A place on the ground" for Projectile/Throw); Enter = TargetGameobjectCommand; Escape = game cancel | navigable (melee) |
| Place cursor (mod screen) | after arming a place action (Jump, Zone, ...) | | Space stays the game's | arrows move a ground point relative to the camera; offset + the game's preview spoken; Enter clicks when the preview allows | navigable (Jump, Fire Bolt) |
| Turn order (mod screen) | in combat, from the menu | mod menu | | combatants with relation, HP, distance, acting now | navigable |
| Map markers (mod screen) | over the HUD, from the menu | mod menu | | objectives and marked characters, Enter walks there | navigable |
| Everything else | see XAML list | | | generic fallback | not started |

## Play modes

Not started (no game session yet).
