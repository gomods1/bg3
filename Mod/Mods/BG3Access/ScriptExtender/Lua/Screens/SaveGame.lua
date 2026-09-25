-- Saving (Game/SaveLoad, widget SaveGame): "New save" first (the game's own button, then its
-- popup's Guardar), then this character's saves, newest first: Enter overwrites one (selected,
-- then the game's Enter for "Guardar partida", which asks first). Escape is the game's (closes).
local Game = Ext.Require("Game/SaveLoad.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Timer = Ext.Require("Core/Timer.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local SaveGame = ListScreen.Extend()
SaveGame.Widgets = { Game.SaveWidget }

local SELECT_SETTLE_MS = 300
local NEW_SAVE_LABEL = "hba968e69g5b87g49fdg875dg1f84d53c2b90" -- "Nueva partida guardada"

function SaveGame.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_widget_SaveGame")), SaveGame)
end

local function line(s)
    return Strings.List({ s.title, s.place, s.time, s.playTime ~= "" and L("save_played", { time = s.playTime }) })
end

function SaveGame:Build()
    local out = {
        Controls.Button({
            label = Loca.Text(NEW_SAVE_LABEL) or "?",
            activate = function(done) Activate.Click(Game.SaveWidget, "NewSaveBtn", done) end,
        }),
    }
    for i, s in ipairs(Game.Read(Game.SaveWidget, true)) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return Strings.List({ line(s), L("save_overwrite_hint") }) end,
            activate = function()
                if not Game.Select(i, Game.SaveWidget, true) then
                    Speech.Say(L("cannot_change"), { interrupt = true })
                    return
                end
                Timer.After(SELECT_SETTLE_MS, function() Game.LoadSelected() end)
            end,
        })
    end
    return out
end

return SaveGame
