-- The Examine window (widget Examine; opened by an item's context menu "Examinar", or on a
-- character). Facts (verified 2026-09-24, a healing potion): it shows
-- CurrentPlayer.UIData.ExamineTarget, a view model like the inventory's items (Name, Description
-- handles, ShortDescription context string "Cura y elimina el estado «en llamas».", Count, Gold,
-- Rarity, ItemType, UseType, MainCost, Type "Item" or a character's) with Stats { Health { Value,
-- Max }, TemporaryHealth, ArmorClass { Value }, Weight { Value, kg }, Range { Value },
-- Resistances[] { DamageType, Full: None / Resistant / Immune / Vulnerable } } and StatusEffects[].
local Vm = Ext.Require("Game/Vm.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Player = Ext.Require("Game/Player.lua")
local Spells = Ext.Require("Game/Spells.lua")
local Characters = Ext.Require("Game/Characters.lua")

local Examine = {}

Examine.Widget = "Examine"

local function target()
    return Vm.Get(Vm.Get(Player.Current(), "UIData"), "ExamineTarget")
end

local function number(obj, name)
    local v = Vm.Get(Vm.Get(obj, name), "Value")
    return type(v) == "number" and v or nil
end

-- { name, count, item (bool), short, description, rarity, value, weight, spell (stat id cast by
-- the item), sheet (a character's: Game/Characters.Sheet), tempHp, resistances = { Resistant = { names }, Immune = ..., Vulnerable
-- = ... }, statuses = { names } } or nil.
function Examine.Read()
    local t = target()
    if not t then return nil end
    local stats = Vm.Get(t, "Stats")
    local item = Vm.Get(t, "Type") == "Item"
    local out = {
        name = Vm.Text(t, "Name") or "?",
        count = Vm.Get(t, "Count"),
        item = item,
        short = Vm.ContextText(Vm.Get(t, "ShortDescription")),
        description = Vm.Text(t, "Description"),
        rarity = Vm.Enum(t, "Rarity"),
        value = Vm.Get(t, "Gold"),
        resistances = {},
        statuses = {},
    }
    if item then
        out.weight = number(stats, "Weight")
        out.spell = Spells.OfItem(Vm.Get(t, "EntityUUID"))
    else
        out.sheet = Characters.Sheet(t)
        out.tempHp = number(stats, "TemporaryHealth")
        for _, r in ipairs(Vm.List(stats, "Resistances")) do
            local full = Vm.Enum(r, "Full")
            if full and full ~= "None" then
                local list = out.resistances[full] or {}
                local damage = Vm.Enum(r, "DamageType")
                list[#list + 1] = Loca.Enum("DamageTypeNameTemplate", damage) or damage
                out.resistances[full] = list
            end
        end
    end
    for _, s in ipairs(Vm.List(t, "StatusEffects")) do
        local name = Vm.Text(s, "Name")
        if name then out.statuses[#out.statuses + 1] = name end
    end
    return out
end

return Examine
