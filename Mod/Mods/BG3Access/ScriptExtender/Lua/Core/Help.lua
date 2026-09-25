-- Context help (template_rpg 21): the screen's own lines, then the mod's global keys.
local Keys = Ext.Require("Core/Keys.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Help = {}

function Help.GlobalLine()
    local keys = {}
    for _, a in ipairs(Keys.List()) do
        keys[#keys + 1] = L("help_key", { key = Strings.KeyName(a.combos[1]), action = L("action_" .. a.id) })
    end
    return L("help_global", { keys = Strings.List(keys) })
end

-- lines: the context's own help lines (may be empty).
function Help.Speak(lines)
    local all = {}
    for _, l in ipairs(lines or {}) do all[#all + 1] = l end
    all[#all + 1] = Help.GlobalLine()
    Speech.Say(Strings.Sentences(all), { interrupt = true })
end

return Help
