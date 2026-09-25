-- Reactions (mod menu): the game's reactions panel (key L) as lists. Each party member, then
-- their reactions: "Ataque de oportunidad, ask" (Game/Reactions modes: always, ask, never).
-- Left/Right or Enter change the mode; Ctrl+D reads the reaction's description. A reaction set
-- to "ask" brings up the reaction prompt (Screens/Reactions) when it can be used.
local Game = Ext.Require("Game/Reactions.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local ReactionSettings = ListScreen.Extend()

function ReactionSettings.New(onClose)
    local self = setmetatable(ListScreen.New("(reactions)", L("screen_reaction_settings")), ReactionSettings)
    self.onClose = onClose
    return self
end

local function reaction(ci, ri)
    local c = Game.Settings()[ci]
    return c and c.reactions[ri]
end

local function line(r)
    return Strings.List({ r.name, L("reaction_mode_" .. r.mode), not r.available and L("reaction_not_ready") })
end

local function reactionControl(ci, ri)
    local function change(delta)
        local r = reaction(ci, ri)
        if not r then return end
        local modes, at = Game.Modes, 1
        for i, m in ipairs(modes) do
            if m == r.mode then at = i end
        end
        local mode = modes[(at - 1 + delta) % #modes + 1]
        if not Game.SetMode(ci, ri, mode) then
            Speech.Say(L("cannot_change"), { interrupt = true })
            return
        end
        Controls.SayWhenChanged(function()
            local now = reaction(ci, ri)
            return now and L("reaction_mode_" .. now.mode)
        end, L("reaction_mode_" .. r.mode))
    end
    return Controls.Item({
        kind = "option",
        describe = function()
            local r = reaction(ci, ri)
            return r and line(r) or L("option_gone")
        end,
        details = function()
            local r = reaction(ci, ri)
            return r and r.description
        end,
        activate = function() change(1) end,
        change = function(delta) change(delta) end,
    })
end

function ReactionSettings:Build()
    local out = {}
    for ci, c in ipairs(Game.Settings()) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return L("reaction_character", { name = c.name, n = #c.reactions }) end,
            activate = function()
                self:Push(c.name, function()
                    local list = {}
                    for ri = 1, #c.reactions do list[ri] = reactionControl(ci, ri) end
                    return list
                end)
            end,
        })
    end
    return out
end

function ReactionSettings:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_reaction_settings")
    return lines
end

return ReactionSettings
