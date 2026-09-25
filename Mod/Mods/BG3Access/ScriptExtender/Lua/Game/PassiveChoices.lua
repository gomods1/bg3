-- Passive choices (ls.VMPassiveSelector): what a level up (and character creation) asks for
-- besides spells: the Wildheart barbarian's animal heart, a fighting style, maneuvers,
-- metamagic... Facts (verified 2026-09-24, Tav barbarian 2 -> 3 as a Wildheart, widget
-- CharacterLevelUp):
--   selectors: ClassProgressionDetails.SubPassiveSelectors / NotSubPassiveSelectors (and the
--     same under RaceProgressionDetails): Name (handle, "Corazón bestial"), Description (context
--     string: "Escoge tu Corazón Bestial..."), MaxSelectedPassiveCount, SelectedPassiveCount,
--     IsComplete, Passives[].
--   passive (ls.VMCharacterCreationPassive): Name (handle, "Corazón de oso"), IconName, Value
--     (1.0 when chosen: the XAML's SelectableEnhancement trigger), Enabled, Blocked.
--   Choosing: the DC's TogglePassive(passive), what a click on it does (CCLib_k.xaml).
--   No description on the passive: it is the PassiveData stat with the same icon and name
--     (TotemSpirit_Bear: Icon Action_Barbarian_Rage_BearTotem).
local Vm = Ext.Require("Game/Vm.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Spells = Ext.Require("Game/Spells.lua")

local PassiveChoices = {}

-- A source is { dc = function() -> the widget's DC, selectors = function() -> { selector VMs } }
-- (valid this tick).

local SELECTOR_LISTS = { "SubPassiveSelectors", "NotSubPassiveSelectors" }

-- The selectors under the given progression details properties of dc, in the game's order.
function PassiveChoices.SelectorsOf(dc, detailsNames)
    local out = {}
    for _, details in ipairs(detailsNames) do
        for _, list in ipairs(SELECTOR_LISTS) do
            for _, s in ipairs(Vm.List(Vm.Get(dc, details), list)) do out[#out + 1] = s end
        end
    end
    return out
end

-- Description of a passive by its icon and display name, from the PassiveData stats (cached):
-- { description = the template with "[1]"..., params = Spells.ParseParams } or nil.
local descriptions = {}
local function describe(icon, name)
    local key = tostring(icon) .. "|" .. tostring(name)
    if descriptions[key] ~= nil then return descriptions[key] or nil end
    local found = false
    for _, id in ipairs(Ext.Stats.GetStats("PassiveData")) do
        local ok, d = pcall(function()
            local s = Ext.Stats.Get(id)
            if s.Icon == icon and Loca.Get(s.DisplayName) == name then
                return { description = Loca.Get(s.Description), params = Spells.ParseParams(s.DescriptionParams) }
            end
            return nil
        end)
        if ok and d then
            found = d
            break
        end
    end
    descriptions[key] = found
    return found or nil
end

-- { { name, description, max, chosen, complete, passives = { { name, icon, selected, enabled } } } }.
function PassiveChoices.Read(source)
    local out = {}
    for _, s in ipairs(source.selectors()) do
        local c = {
            name = Vm.Text(s, "Name"),
            description = Vm.ContextText(Vm.Get(s, "Description")),
            max = Vm.Get(s, "MaxSelectedPassiveCount") or 0,
            chosen = Vm.Get(s, "SelectedPassiveCount") or 0,
            complete = Vm.Get(s, "IsComplete") == true,
            passives = {},
        }
        for _, p in ipairs(Vm.List(s, "Passives")) do
            local name = Vm.Text(p, "Name") or "?"
            c.passives[#c.passives + 1] = {
                name = name,
                icon = Vm.Get(p, "IconName"),
                selected = (Vm.Get(p, "Value") or 0) >= 1,
                enabled = Vm.Get(p, "Enabled") ~= false and Vm.Get(p, "Blocked") ~= true,
            }
        end
        out[#out + 1] = c
    end
    return out
end

-- The description of passive j of selector i ({ description, params }, as for a spell), or nil.
function PassiveChoices.Description(source, i, j)
    local c = PassiveChoices.Read(source)[i]
    local p = c and c.passives[j]
    return p and describe(p.icon, p.name)
end

-- Chooses passive j of selector i, or takes it back when chosen. Returns ok (the command ran).
function PassiveChoices.Toggle(source, i, j)
    local s = source.selectors()[i]
    local p = s and Vm.List(s, "Passives")[j]
    if not p then return false end
    return Vm.Run(source.dc(), "TogglePassive", p)
end

return PassiveChoices
