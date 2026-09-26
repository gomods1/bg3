-- How an item (Game/Items) is spoken in lists: "Poción de curación, 2, poco común, value 50,
-- equipped, stolen". Only what the game shows on the item's slot and tooltip header.
local Loca = Ext.Require("Game/Loca.lua")
local ItemStats = Ext.Require("Game/ItemStats.lua")
local Player = Ext.Require("Game/Player.lua")
local Vm = Ext.Require("Game/Vm.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local ItemWords = {}

function ItemWords.Line(item)
    local s = item.name
    if item.count and item.count > 1 then s = L("item_count", { name = s, count = item.count }) end
    local rarity = item.rarity and item.rarity ~= "Common" and Loca.Enum("RarityNameStyle", item.rarity)
    -- Food's camp supplies, per unit (a full long rest needs 40): what a blind player buys by.
    local supplies = item.campSupplies and item.campSupplies > 0 and L("item_supplies", { n = item.campSupplies })
    return Strings.List({ s, rarity, supplies, item.value and item.value > 0 and L("item_value", { gold = item.value }),
        item.equipped and L("item_equipped"), item.stolen and L("item_stolen"), item.isNew and L("item_new") })
end

-- Details of an item lying in the world (Game/Items.WorldInfo): "poco común, value 50. <the
-- game's description>", or nil when nothing is known.
function ItemWords.WorldDetails(info)
    if not info then return nil end
    local rarity = info.rarity and info.rarity ~= "Common" and Loca.Enum("RarityNameStyle", info.rarity)
    return Strings.Sentences({
        Strings.List({ rarity, info.value and info.value > 0 and L("item_value", { gold = info.value }),
            info.weight and info.weight > 0 and L("item_weight", { kg = info.weight }) }),
        info.description,
    })
end

-- A weapon's or armour's numbers as the tooltip gives them, for the controlled character:
-- "daño 1d12, Cortante, A dos manos, Pesado, Empapable. Hachas a dos manos, competente. Acciones
-- del arma: Hendedura, Tajo, Golpe completo." nil for other items.
function ItemWords.Stats(uuid)
    local me = Vm.Get(Player.SelectedCharacter(), "EntityUUID")
    local s = ItemStats.Of(uuid, me)
    if not s then return nil end
    local head = {}
    if s.damage then head[#head + 1] = L("item_damage", { dice = s.damage, type = s.damageType or "?" }) end
    if s.versatile then head[#head + 1] = L("item_versatile", { dice = s.versatile }) end
    if s.enchantment then head[#head + 1] = L("item_enchantment", { bonus = tostring(s.enchantment) }) end
    if s.armorClass then head[#head + 1] = L("item_armor_class", { ac = s.armorClass }) end
    for _, p in ipairs(s.properties) do head[#head + 1] = p end
    local proficiency = s.proficient ~= nil and L(s.proficient and "item_proficient" or "item_not_proficient") or nil
    local passives = {}
    for _, p in ipairs(s.passives) do
        passives[#passives + 1] = p.description and L("label_value", { label = p.name, value = p.description }) or p.name
    end
    return Strings.Sentences({
        Strings.List(head),
        Strings.List({ s.kind, proficiency }),
        #s.actions > 0 and L(s.damage and "item_weapon_actions" or "item_grants", { actions = Strings.List(s.actions) }) or nil,
        #passives > 0 and L("item_on_equip", { passives = Strings.Sentences(passives) }) or nil,
    })
end

-- Ctrl+D on an item with a view model (inventory, equipment, loot, trade): its weapon or armour
-- numbers, weight, and the game's description.
function ItemWords.Details(item)
    if not item then return nil end
    return Strings.Sentences({
        item.uuid and ItemWords.Stats(item.uuid) or nil,
        item.weight and item.weight > 0 and L("item_weight", { kg = item.weight }) or nil,
        item.description,
    })
end

return ItemWords
