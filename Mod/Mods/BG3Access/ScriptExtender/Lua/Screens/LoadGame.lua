-- Load game (Game/SaveLoad): the saves, newest first ("QuickSave_8, Entrada a la capilla, 24/9/2026
-- 12:00, played 3 h 10 min"). Enter loads the save (selected, then the game's own Load key); the
-- game's warnings come as message boxes. Escape is the game's (closes).
local Game = Ext.Require("Game/SaveLoad.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Timer = Ext.Require("Core/Timer.lua")

local L = Strings.Get

local LoadGame = ListScreen.Extend()
LoadGame.Widgets = { Game.Widget }

local SELECT_SETTLE_MS = 300 -- the selection reaches the Load button on a later frame

function LoadGame.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_load_game")), LoadGame)
end

local function line(s)
    return Strings.List({ s.title, s.place, s.time, s.playTime ~= "" and L("save_played", { time = s.playTime }),
        not s.valid and L("unavailable") })
end

function LoadGame:Build()
    local out = {}
    for i, s in ipairs(Game.Read()) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return line(s) end,
            activate = function()
                if not Game.Select(i) then
                    Speech.Say(L("cannot_change"), { interrupt = true })
                    return
                end
                Speech.Say(L("loading_save", { name = s.title }), { interrupt = true })
                Timer.After(SELECT_SETTLE_MS, function() Game.LoadSelected() end)
            end,
        })
    end
    return out
end

return LoadGame
