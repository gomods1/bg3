-- BG3 Access, server half: answers read-only queries from the client half (Server/Queries).
-- It never moves characters or acts for the player (CLAUDE.md, no magic movement).
local Log = Ext.Require("Core/Log.lua")
local Queries = Ext.Require("Server/Queries.lua")
local Places = Ext.Require("Server/Places.lua")
local Signposts = Ext.Require("Server/Signposts.lua")
local Marks = Ext.Require("Server/Marks.lua")

BG3Access = BG3Access or {}
BG3Access.Debug = true -- the release build script sets this to false

Log.Info("server starting")
Queries.Start()
Places.Register()
Places.Start()
Signposts.Register()
Signposts.Start()
Marks.Register()
Marks.Start()

if BG3Access.Debug then
    Ext.Require("Dev/DevChannel.lua").Start("server")
end
