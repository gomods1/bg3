-- What an item's tooltip says about it as a weapon or armour, from its stats entry (client):
-- the item entity's Data.StatsId, then Ext.Stats.Get. Facts (verified 2026-09-25, Tav's gear in
-- the goblin camp): WPN_Greataxe { Damage "1d12", "Damage Type" Slashing, VersatileDamage "",
-- "Weapon Properties" {Twohanded, Melee, Heavy, Dippable}, "Proficiency Group" {Greataxes,
-- MartialWeapons}, BoostsOnEquipMainHand "UnlockSpell(Zone_Cleave);UnlockSpell(Target_Slash_New);
-- UnlockSpell(Shout_FullSwing)" (the weapon actions), DefaultBoosts "" (magic weapons:
-- "WeaponEnchantment(1)"...), PassivesOnEquip }; ARM_Leather { ArmorClass 11, ArmorType Leather,
-- "Proficiency Group" {LightArmor}, Shield "No" }. The character's proficiencies: its entity's
-- Proficiency.Flags (ProficiencyGroupFlags(Shields, SimpleWeapons, LightArmor, ...)).
-- Names come from the game's own tooltip strings (Game/EnumNames): "Cortante", "A dos manos",
-- "Hachas a dos manos". Words are the caller's.
local Entities = Ext.Require("Game/Entities.lua")
local Loca = Ext.Require("Game/Loca.lua")

local ItemStats = {}

local function field(stat, name)
    local ok, v = pcall(function() return stat[name] end)
    if ok then return v end
    return nil
end

local function list(v)
    local out = {}
    pcall(function() for _, x in pairs(v or {}) do out[#out + 1] = tostring(x) end end)
    return out
end

-- The stats' spelling differs from the tooltip enum's in case only ("Twohanded" / "TwoHanded").
local function propertyName(p)
    local camel = p:gsub("hand", "Hand")
    for _, key in ipairs({ p, camel }) do
        local name = Loca.Enum("Tooltips.TypeId", key)
        if name then return name end
    end
    return nil -- Melee and other unshown properties
end

local function spellName(id)
    local ok, stat = pcall(Ext.Stats.Get, id)
    return ok and stat and Loca.Text(field(stat, "DisplayName")) or nil
end

-- The general groups (simple, martial) name no weapon kind: the specific one comes first.
local GENERAL = { SimpleWeapons = true, MartialWeapons = true }

-- The character's proficiency groups as a set, or nil when unknown.
local function proficiencies(characterUuid)
    local e = characterUuid and Entities.Get(characterUuid)
    local ok, flags = pcall(function() return tostring(e.Proficiency.Flags) end)
    if not ok or not flags then return nil end
    local set = {}
    for name in flags:gmatch("[%a]+") do set[name] = true end
    return set
end

-- { damage?, damageType?, versatile?, properties = {}, kind?, proficient? (true/false, with a
--   character), enchantment?, armorClass?, shield, actions = { spell names it unlocks },
--   passives = { { name, description? } } } or nil when the item has no weapon or armour stats
-- and grants nothing.
function ItemStats.Of(itemUuid, characterUuid)
    local e = itemUuid and Entities.Get(itemUuid)
    local ok, id = pcall(function() return e.Data.StatsId end)
    if not ok or not id or id == "" then return nil end
    local sok, stat = pcall(Ext.Stats.Get, id)
    if not sok or not stat then return nil end
    local damage = tostring(field(stat, "Damage") or "")
    local ac = tonumber(field(stat, "ArmorClass")) or 0
    local extras = tostring(field(stat, "Boosts") or "") .. tostring(field(stat, "PassivesOnEquip") or "")
    -- Amulets, rings, clothes: only what they grant (the goblin priestess's talisman unlocks a
    -- spell and a passive, 2026-09-25).
    if damage == "" and ac <= 0 and extras == "" then return nil end
    local out = { properties = {}, actions = {}, passives = {}, shield = tostring(field(stat, "Shield")) == "Yes" }
    if damage ~= "" then
        out.damage = damage
        local t = tostring(field(stat, "Damage Type") or "")
        out.damageType = Loca.Enum("DamageTypeNameTemplate", t) or (t ~= "" and t or nil)
        local v = tostring(field(stat, "VersatileDamage") or "")
        if v ~= "" then out.versatile = v end
        for _, p in ipairs(list(field(stat, "Weapon Properties"))) do
            out.properties[#out.properties + 1] = propertyName(p)
        end
    end
    if ac > 0 then out.armorClass = ac end
    local groups = list(field(stat, "Proficiency Group"))
    table.sort(groups, function(a, b) return not GENERAL[a] and GENERAL[b] or false end)
    if groups[1] then out.kind = Loca.Enum("EquipmentProficiencyNameStyle", groups[1]) end
    local has = proficiencies(characterUuid)
    if has and #groups > 0 then
        out.proficient = false
        for _, g in ipairs(groups) do
            if has[g] then out.proficient = true end
        end
    end
    local boosts = table.concat({ tostring(field(stat, "DefaultBoosts") or ""), tostring(field(stat, "Boosts") or ""),
        tostring(field(stat, "BoostsOnEquipMainHand") or "") }, ";")
    out.enchantment = tonumber(boosts:match("WeaponEnchantment%((%d+)%)"))
    local seen = {}
    for spell in boosts:gmatch("UnlockSpell%(([%w_]+)") do
        local name = spellName(spell)
        if name and not seen[name] then
            seen[name] = true
            out.actions[#out.actions + 1] = name
        end
    end
    for passive in tostring(field(stat, "PassivesOnEquip") or ""):gmatch("[^;]+") do
        local name = spellName(passive)
        if name then
            local ok, pstat = pcall(Ext.Stats.Get, passive)
            local text = ok and pstat and Loca.Text(field(pstat, "Description")) or nil
            -- Descriptions with "[1]" need the passive's parameters: the name alone then.
            if text and text:find("%[%d+%]") then text = nil end
            out.passives[#out.passives + 1] = { name = name, description = text }
        end
    end
    return out
end

return ItemStats
