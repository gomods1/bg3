# STATUS

## Current state (session 1, 2026-09-24)

Game 4.1.1.7398727, Script Extender v32 (release channel), Prism 0.18.2, NVDA. Game language Spanish.

Verified in the running game:

- Native bridge loads through our `version.dll` proxy in `bg3.exe`; Prism picks NVDA.
- Lua -> bridge channel (hooked SaveFile -> pipe): 32-36 µs per message; hello round trip works.
- "BG3 Access loaded" is spoken during the first loading screen. **Not yet confirmed by ear** (ask the user).
- Mod keys: KeyInput sees real keys on every screen tried; a bound key speaks (Ctrl+Shift+F8).
- Key injection (`Ext.Input.InjectKeyPress`) drives the game without window focus (title screen, difficulty).
- Screen router + generic virtual list (XAML index labels, Up/Down/Home/End/Enter/Space):
  - EULA: announced, text readable item by item, Accept activated by keyboard (verified click).
  - Explicit content: option row read ("…: Sí, list, 2 of 2"), Left/Right change it (restored to Sí), Continue.
  - Gamma: read, Accept activated. Splash: its text is spoken.
  - Main menu: 8 buttons; New Game via command; Options via verified click; Escape back re-announces.
  - Difficulty: selected preset + description announced on open and on each Left/Right.
  - Message boxes (ls.DCMessageBox, e.g. quit confirmation): title, text, buttons; action executed by
    its own command (quit confirmed -> clean exit, no ModCrashSanityCheck left).
  - Options menu: 24 rows read (ComboBox rows with value; TickBox/Button rows only named so far).
- Hot reload of Lua via loose files + `Ext.Debug.Reset()` (DeveloperMode).

Not verified / known gaps:

- bg3_dx11.exe with the mod (proxy should load there too: same imports).
- Options rows of type TickBox/Button/Slider; "Cargar partida" shown as available when there are no saves.
- Mod keys are provisional (Ctrl+Shift+F8 = read screen). Game bindings not dumped yet.
- Click positions are hard-coded fractions measured at 2560x1600 (16:10); other aspect ratios unverified.
- No installer yet; dev deploy only (`tools/deploy.py`).
- Game was left with the dev deploy installed (SE, proxy, bridge, pak, loose Lua in Data\Mods,
  DeveloperMode settings) and closed cleanly.

## Next steps (in order)

1. Ask the user: did NVDA speak "BG3 Access loaded", the EULA and menu lines? Any stutter or cut-offs?
2. Dump the game's key bindings at runtime (`Ext.Input.GetInputManager()`), choose the mod layer key,
   record in CLAUDE.md; replace Ctrl+Shift+F8.
3. Bridge: announce "BG3 Access: mod not loaded" if no Lua hello arrives within ~60 s of launch
   (ModCrashSanityCheck case), and an IMGUI/console message for sighted helpers.
4. Options menu: TickBox/Button/Slider rows, tabs (GameOptions/Audio/Video/Controls/…), apply/cancel.
5. Main menu: unavailable state from the VM (HasSaveGames), Continue when saves exist, profile/account button.
6. Movement spike (gate 8.1) and controller-UI spike (gate 5.4) once in game (needs character creation:
   start New Game -> Balanced -> character creation screen reading).
7. Installer (`install/install.ps1`) + uninstall, README.
