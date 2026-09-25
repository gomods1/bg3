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
| `Ext.Input.InjectKeyPress(scancodeName)` | harness / key injection; Back in options (ESCAPE) |
| `Ext.Input.GetInputManager()`: `InputScheme.RawToBinding[i].Bindings[]` (InputIndex, Binding.InputId/DeviceId/Modifiers, BindingIndex), `InputDefinitions[id]` (EventName, EventDesc handle) | Game/Input: key binding rows, binding dump. Not `InputScheme.InputBindings` (garbage after element 1) |
| `Ext.Json.Parse` / `Ext.Json.Stringify(v, {Beautify=true})` | config.json |
| `Ext.Utils.GameVersion()` = "v4.73.98.727", `Ext.Utils.Version()` = 32 | build gate |
| element `SetProperty(name, value)` on view-model rows | option values |
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
| `MainMenu` | gui::DCMainMenu | `NewGameButton` (StartGameCommand), `LoadGameButton` (OpenLoadGameDialog; enabled iff DC `ExistingSaves.Count > 0`), `ContinueButton` (shown iff DC `HasSaveGames`, enabled iff `SelectedSave`), `OptionsButton`/`CreditsButton`/`ModsButton` (CustomEvent), `QuitGameButton` (QuitGameCommand) |
| `DMSettings` | gui::DCDMSettings | `PresetList.SelectedItem` (gui::VMPreset: Title, Description handles, IsHonour) |
| `GameOptions` and the other option tabs | gui::DCOptions (`KeybindingOptions`: gui::DCKeybindingOptions) | DC `Options` rows: ls.VMComboBoxSetting, ls.VMTickBoxSetting (`Value` bool), gui::VMSliderSetting (`Value`/`Min`/`Max`), ls.VMListButton (`ButtonCommand.ActionCommand`), ls.VMListItem (header), gui::VMKeybindingOption (`Bindings`); `Text`/`Description` handles; DC `ValueChanged(row)`, `Next/PrevComboItemCommand(row)`, `ResetOptionsToDefaultCommand`; tab buttons `gameplayButton`, `keybindingButton`, `controllerButton`, `videoButton`, `audioButton`, `interfaceButton`, `accessibilityButton`; tab labels from `UIData.xaml` LSPanelData |
| `root` | ls.LoadingScreen | loading screen |
| `DMSettings` | gui::DCDMSettings | `ConfirmBtn` = StartNewGame(PresetList.SelectedItem), BoundEvent UIAccept |
| `Dialog_box` | ls.DCMessageBox | + `CheckBoxProperty`, `CheckBoxLabelProperty`, `CheckBoxValueProperty` (SetProperty works), `InputBoxProperty`, `InputTextProperty` |
| `CharacterCreation` | gui::DCCharacterCreation | `Selectable{Origins,Races,SubRaces,Classes,SubClasses,Backgrounds,Deities}` + `Selected*` (SetProperty selects); `DummyCharacter.Stats.Abilities` (ls.VMAbility), `IncreaseAbility`/`DecreaseAbility(ability)`, `UnusedAbilityPoints`/`TotalAbilityPoints`; `RaceProgressionDetails.AbilityBonusSelection` + `SelectNext/PrevAbilityBonus(selection)`; `AllSkills.*ProficientSkills/ExpertiseSkills` + `ToggleSkill(skill)`; `IsCharacterComplete`, `FinishCreating`, `RandomCharacter`; `SelectedOrigin.IsLocked*`. Read-only: `CharacterCreationStep` |
| `Dialogue` | gui::DCDialogue | `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ActiveDialogue` (gui::VMDialogue): `SpeakerName`, `BodyText`, `ShowAnswers`, `Answers[]` (BodyText, Enabled, BoundEvent UISelectSlotN, `AnswerTags[]`: Name/Category/ToolTip handles, IsRoll, RollAdvantageType, AbilityValue, AdditionalValue), `History.Items[]` (BodyText "Speaker: text", LineType NPC/Avatar) |
| `ActiveRoll` | gui::DCActiveRoll | `SkillOrAbility` handle, `RollState` (WaitForStart -> StartRoll -> ResultReady), `TargetNumber`, `Min/MaxBonusValue`, `FinalResult` (die), `ResultNumber` (total), `RolledNumber2`, `Success`, `SkillOrAbilityResultText`, `InspirationPoints`, `HasBoostsToAdd`; `Roll.DifficultyCheck`, `Roll.RollAdvantageType`, `Roll.Modifiers[]`; `UserTriggeredNextPhaseCommand(nil)` rolls / continues, `RollAgainCommand` |
| `ReactionDecisionPopup` (ContextName ReactionDecision) | ls:DCReactionDecision | from XAML only, never seen: `Data.InterruptEvents[]` (VMInterruptEvent: Interruptors[] VMInterruptor {Character, InterruptDecisions[] VMInterruptDecision {Interrupt, Decision}}), `InterruptReactCommand` (multi-binding parameter: not usable from Lua), `InterruptAcceptPlayerCommand(event)`, `InterruptDontReactPlayerCommand(event)` |
| `ModalTutorial` | gui::DCTutorial | `Tutorial.Title/Description` handles, `CurrentStep`, `FinishTutorial`, `NextStep` (CanExecute true on the last step too), `PreviousStep` |
| `HotBar` | | DC `UseSlotCommand(slot)`, `TargetGameobjectCommand(characterVM)`; slots `SlotType` Item: `Content` = item VM (`UseType` Potion/Scroll, `Count`, `EntityUUID`, `MainCost`) |
| (via CurrentPlayer) | | `SelectedCharacter.PlayerCharacterProperties.StoryTimer` (Description, TimerID, TotalTime, CurrentTime, CurrentCount, TotalCount, CountDescription), `...CurrentSubregionName`, `UIData.Notification` (Type, TitlePrefix, Title, Message.Text, ExtendedMessage, ExpGain, Amount), `SelectedCharacter.Stats.SpellSlots[]` (Level, Value, MaxValue, IsHidden); hotbar action `SpellSlotLevel`, `SpellUpcast[]` |
| (via CurrentPlayer) | | `UIData.ActiveSlot` (set while an action is armed, and while a potion is being drunk), `UIData.MovementResourceCostPreview` (also for a plain ground hover in combat), `UIData.ActiveTask.SurfaceMessage`, `IsCurrentTurn`, `CanEndTurn`; character VM `StatusEffects[]` (Name handle, StatusId, Duration, DurationType) |
| (any, via Minimap DC) | | `CurrentPlayer.WorldMap.Markers[]` (ls.MapMarker: Type, Name, WorldPos {x,z}, Height, GameObject.EntityUUID); `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.CurrentSubregionName` (where am I, todo) |
| `ContainerWidget` | gui::DCContainerInventory | `CurrentPlayer.ContainerInventoryList[].LootInventory.Slots[].Object` (ls.VMItem: Name, Description, Count, Gold, Rarity, IsStolen, EntityUUID); `TakeAllAndCloseCommand.ActionCommand(nil)`; `TakeItemCommand` needs a multi-binding (not usable) |
| any widget | | `IsVisible` (false for widgets of states hidden by the UI state machine), `ContextName` |

Generated from XAML (tools/): `Game/XamlIndex.lua` (pages: root x:Name, ContextName, labels,
commands, parameter bindings, BoundEvent) and `Game/EnumNames.lua` (enum -> label handle maps from
templates such as AbilityDisplayName, SkillDisplayName, DamageTypeNameTemplate).

## World (client)

| API | Use |
|---|---|
| `Ext.Entity.GetAllEntitiesWithComponent("Camera")`, `.Camera.Active`, `.Camera.Controller.Camera.ViewMatrix/ProjectionMatrix` (16 floats, column-major) | Game/Camera world -> screen (verified against a screenshot) |
| `Ext.UI.GetPickingHelper(1).Inner.Inner[1].GameObject`, `.Inner.Position` | Game/Picking: hovered entity, ground point |
| `Ext.Entity.Get(uuid)`, `.Transform.Transform.Translate`, `.DisplayName.NameKey.Handle.Handle`; component `ClientCharacter` | Game/Entities |

| `Ext.Level.BeginPathfindingImmediate(entity, pos)`, `FindPath`, `ReleasePath`, `path.Checkpoints[].Position/Portal/Flags`; writable `path.CanUseLadders`, `path.CanUsePortals` (false by default); portal entity component `Ladder` | Game/Paths (where to click next) |
| `Ext.Stats.Get(spell)`: `SpellType`, `TargetRadius`, `AreaRadius`, `Shape`, `Range`, `Base`, `Angle`, `TooltipDamageList`, `SpellRoll.Default` | Game/Spells, Combat/Area |
| components `UseAction`, `InventoryMember`, `PartyMember`, `ClientCharacter`, `IsDoor` | Game/Interactables (Nearby beyond the highlight) |
| item entity `SpellBook.Spells[1].Id.Prototype` (scrolls), `Use.ItemUseType` | Game/Spells |
| `WorldTooltips` widget DC `CurrentPlayer.WorldTooltips[]` (Name, IsItem, ContainerState, IsStealing, GameObject.EntityUUID), `SetShowWorldTooltipsCommand(nil)`; hide = injected LALT | Game/Highlights |
| components `IsDoor` (tag), `ClientCharacter`, `UseAction` (usable items: many more than the highlight lists) | Game/Entities, Game/Doors. `ClientControl` is NOT the selected character (stays on the first); the controlled character is `CurrentPlayer.SelectedCharacter.EntityUUID` |
| picking `Inner.Inner[1].Item/Character/DeadCharacter` | never ground-click on an object |
| `Ext.Net.CreateChannel(ModuleUUID, name)`, `SetRequestHandler`, `RequestToServer` (present in v32) | Net/Channels |

## Combat (client)

| Target | Use |
|---|---|
| `CombatantsOverlay` DC `Combatants[]` (ls.Combatant: Order, CurrentCombatant = ls.Character), `CurrentCombat.CombatGuid` | Game/Combat |
| ls.Character: `Name`, `EntityUUID`, `IsCurrentTurn`, `PlayerRelation`, `CharacterType`, `Stats.Health` (Value/Max), `Stats.ActionResources[]` (Name, TypeId, Value, MaxValue, IsHidden), `Stats.MovementResource` | Game/Characters |
| `CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[].SlotList[]` (HotKey, CanUse, Content = ls.VMCharacterAction: Name, MainCost, TargetingType, PrototypeID) | Game/Hotbar |
| HotBar DC `UseSlotCommand(slot)` (arm), `TargetGameobjectCommand(characterVM)` (use on target) | Game/Hotbar, Game/Combat |
| `CurrentPlayer.UIData.HitChanceDesc` (TotalHitChance, Advantages, Disadvantages), `DamagePreviewWithResistances` (Min/Max), `MovementResourceCostPreview` (Cost, ValueAfterUse), `ActiveTask` (CanExecute, AoOWarning, LethalOutcome) | Game/Preview |
| `Data.CombatLog.EntryGroups[]` (ChildDepth, CtxTransText.Text "[1] ha usado [2] con [3].", Params[].Text) | Game/CombatLog |

## Osiris (server)

`ref/osiris/OsiIdeHelpers.lua` (generated 2026-09-24 with `Ext.Debug.GenerateIdeHelpers()`; needs the
folder `Data/Mods/GustavX/Story/RawFiles/Lua/` to exist, created and removed again).

| Function | Use |
|---|---|
| `Osi.GetHostCharacter()`, `Osi.GetPosition(uuid)`, `Osi.GetDisplayName`, `Osi.ResolveTranslatedString` | dev probes |
| `Osi.CharacterMoveToPosition(char, x, y, z, "Walk", event)` (6 args; a 7-arg form exists) | dev probe only (no magic movement in the mod) |
| `Osi.IsOpened(item)`, `Osi.IsLocked(item)` -> 1/0 | door states (Server/Queries) |

## Click hints (fractions of client area, 2560x1600)

See `Game/Activate.lua` `ClickHints`: Eula AcceptBtn (0.5, 0.931), SensitiveSettings NextButton
(0.5, 0.931), GammaCalibration AcceptButton (0.5, 0.931), MainMenu OptionsButton (0.222, 0.715).
Options tab bar at y 0.040: gameplay 0.202, keybinding 0.322, video 0.441, audio 0.560, interface
0.680, accessibility 0.799 (shared by every tab widget through `HintAliases`).
Verified: Eula Accept, SensitiveSettings Next, Gamma Accept, MainMenu Options, every options tab.
