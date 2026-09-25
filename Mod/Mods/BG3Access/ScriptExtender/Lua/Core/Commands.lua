-- The mod's commands: everything the player can ask the mod to do. They are reached through one
-- key, the mod menu (Screens/ModMenu), which lists the commands available right now; a command
-- gets a direct key only when the config binds one (keys.<id>; most are unbound by default).
-- This is a design rule (CLAUDE.md "Mod menu"): new features register here instead of taking a
-- key of their own.
--
-- Commands.Register({
--     id = "nearby",               -- config key name, and the label string "action_<id>"
--     group = "exploration",       -- menu section, see GROUPS
--     available = function() ... end, -- optional: shown and runnable only when it returns true
--     run = function() ... end,
--     label = function() ... end,  -- optional: a label that changes (a setting's current value)
-- })
local Keys = Ext.Require("Core/Keys.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Log = Ext.Require("Core/Log.lua")

local L = Strings.Get

local Commands = {}

-- Menu order: stopping what is under way (a walk) first, then what the player is doing, the mod's
-- own housekeeping last.
local GROUPS = { urgent = 0, combat = 1, exploration = 2, screen = 3, speech = 4 }

local list = {} -- in registration order

function Commands.IsAvailable(c)
    if not c.available then return true end
    local ok, yes = pcall(c.available)
    if not ok then Log.Error("command " .. c.id .. " available(): " .. tostring(yes)) end
    return ok and yes == true
end

-- Runs a command the way the menu or a direct key does: refused with a spoken reason when it is
-- not available here.
function Commands.Run(c)
    if not Commands.IsAvailable(c) then
        Speech.Say(L("not_available_here"), { interrupt = true })
        return
    end
    Log.Guard("command " .. c.id, c.run)
end

function Commands.Register(c)
    assert(c.id and c.run, "command needs id and run")
    c.group = c.group or "screen"
    list[#list + 1] = c
    Keys.Action(c.id, function() Commands.Run(c) end)
end

function Commands.Label(c)
    if c.label then return c.label() end
    return L("action_" .. c.id)
end

-- Commands available right now, in menu order (group, then registration order).
function Commands.Available()
    local out = {}
    for i, c in ipairs(list) do
        if Commands.IsAvailable(c) then out[#out + 1] = { c = c, i = i } end
    end
    table.sort(out, function(a, b)
        local ga, gb = GROUPS[a.c.group] or 99, GROUPS[b.c.group] or 99
        if ga ~= gb then return ga < gb end
        return a.i < b.i
    end)
    for k, e in ipairs(out) do out[k] = e.c end
    return out
end

return Commands
