-- BG3 Access, server half: Osiris listeners and commands that must run on the server.
local Log = Ext.Require("Core/Log.lua")
local DevChannel = Ext.Require("Dev/DevChannel.lua")

BG3Access = BG3Access or {}
BG3Access.Debug = true -- the release build script sets this to false

Log.Info("server starting")

if BG3Access.Debug then
    DevChannel.Start("server")
end
