-- BG3 Access, client half: UI, input, speech requests.
-- Startup order (template_rpg 7): logging, config, speech/bridge, build gate, keys, screens, dev.
local Log = Ext.Require("Core/Log.lua")
local Config = Ext.Require("Core/Config.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Gate = Ext.Require("Core/Gate.lua")
local Keys = Ext.Require("Core/Keys.lua")
local Router = Ext.Require("Screens/Router.lua")
local SetupCommands = Ext.Require("Setup/Commands.lua")
local Highlights = Ext.Require("Game/Highlights.lua")
local Nearby = Ext.Require("Exploration/Nearby.lua")
local CombatTracker = Ext.Require("Combat/Tracker.lua")
local CombatNarrator = Ext.Require("Combat/Narrator.lua")
local Timers = Ext.Require("Exploration/Timers.lua")
local Notices = Ext.Require("Exploration/Notices.lua")
local Stealth = Ext.Require("Exploration/Stealth.lua")

BG3Access = BG3Access or {}
BG3Access.Debug = true -- the release build script sets this to false

Log.Info("client starting")
Config.Load()
Strings.SetLanguage(Config.Get("speech.language"))

Speech.Say(Strings.Get("loaded", { key = Strings.KeyName(Config.KeysFor("menu")[1] or "") }))
Bridge.Check()
if not Gate.Check() then Speech.Say(Strings.Get("untested_version")) end

-- Commands and the mod menu (Setup/Commands), then input and screens.
SetupCommands.Register()
Keys.Router = Router.OnKey
Keys.Start()
Router.Start()
CombatTracker.Start()
CombatNarrator.Start()
Timers.Start()
Notices.Start()
Stealth.Start()

-- Modules reachable from the dev channel (Ext.Require only works from mod files).
BG3Access.Config = Config
BG3Access.Strings = Strings
BG3Access.Speech = Speech
BG3Access.Bridge = Bridge
BG3Access.Keys = Keys
BG3Access.Router = Router
BG3Access.Ui = Ext.Require("Game/Ui.lua")
BG3Access.Vm = Ext.Require("Game/Vm.lua")
BG3Access.Activate = Ext.Require("Game/Activate.lua")
BG3Access.Highlights = Highlights
BG3Access.Combat = Ext.Require("Game/Combat.lua")
BG3Access.Entities = Ext.Require("Game/Entities.lua")
BG3Access.Camera = Ext.Require("Game/Camera.lua")
BG3Access.Nearby = Nearby
BG3Access.Doors = Ext.Require("Game/Doors.lua")
BG3Access.ContextMenu = Ext.Require("Game/ContextMenu.lua")
BG3Access.Notification = Ext.Require("Game/Notification.lua")
BG3Access.Travel = Ext.Require("Exploration/Travel.lua")
BG3Access.Hotbar = Ext.Require("Game/Hotbar.lua")
BG3Access.Items = Ext.Require("Game/Items.lua")
BG3Access.Relations = Ext.Require("Game/Relations.lua")
BG3Access.Watchers = Ext.Require("Game/Watchers.lua")
BG3Access.LogWords = Ext.Require("Combat/LogWords.lua")
BG3Access.Interactables = Ext.Require("Game/Interactables.lua")
BG3Access.Commands = Ext.Require("Core/Commands.lua")
BG3Access.Poll = Ext.Require("Core/Poll.lua") -- Poll.Report(): what each poller costs
BG3Access.Spells = Ext.Require("Game/Spells.lua")
BG3Access.Input = Ext.Require("Game/Input.lua")
BG3Access.Reactions = Ext.Require("Game/Reactions.lua")
BG3Access.LevelUp = Ext.Require("Game/LevelUp.lua")
BG3Access.SpellChoices = Ext.Require("Game/SpellChoices.lua")
BG3Access.Paths = Ext.Require("Game/Paths.lua")
BG3Access.SafeRoute = Ext.Require("Game/SafeRoute.lua")
BG3Access.Journal = Ext.Require("Game/Journal.lua")
BG3Access.Map = Ext.Require("Game/Map.lua")
BG3Access.Player = Ext.Require("Game/Player.lua")
BG3Access.Tutorial = Ext.Require("Game/Tutorial.lua")
BG3Access.Preview = Ext.Require("Game/Preview.lua")
BG3Access.Loca = Ext.Require("Game/Loca.lua")
BG3Access.CombatLog = Ext.Require("Game/CombatLog.lua")
BG3Access.TutorialHints = Ext.Require("Screens/TutorialHints.lua")

if BG3Access.Debug then
    BG3Access.Dev = { UiDump = Ext.Require("Dev/UiDump.lua") }
    Ext.Require("Dev/DevChannel.lua").Start("client")
end
