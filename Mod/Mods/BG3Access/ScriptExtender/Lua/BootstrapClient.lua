-- BG3 Access, client half: UI, input, speech requests.
local Log = Ext.Require("Core/Log.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Keys = Ext.Require("Core/Keys.lua")
local DevChannel = Ext.Require("Dev/DevChannel.lua")
local UiDump = Ext.Require("Dev/UiDump.lua")
local Router = Ext.Require("Screens/Router.lua")

BG3Access = BG3Access or {}
BG3Access.Speech = Speech
BG3Access.Bridge = Bridge
BG3Access.Keys = Keys
BG3Access.Debug = true -- the release build script sets this to false
BG3Access.Dev = { UiDump = UiDump }
BG3Access.Ui = Ext.Require("Game/Ui.lua")
BG3Access.Router = Router

Log.Info("client starting, SE API v" .. tostring(Ext.Utils.Version()) .. ", game " .. tostring(Ext.Utils.GameVersion()))

Keys.LogAllKeys = BG3Access.Debug
Keys.Start()

Keys.Router = Router.OnKey
Router.Start()

-- Provisional binding until the game's default bindings are dumped (CLAUDE.md, key plan).
Keys.Bind("CTRL+SHIFT+F8", "read screen", Router.ReadScreen)

if BG3Access.Debug then
    DevChannel.Start("client")
end

Speech.Say("BG3 Access loaded")
Bridge.Check()
