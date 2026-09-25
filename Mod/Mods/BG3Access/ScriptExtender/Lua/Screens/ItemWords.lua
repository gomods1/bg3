-- How an item (Game/Items) is spoken in lists: "Poción de curación, 2, poco común, value 50,
-- equipped, stolen". Only what the game shows on the item's slot and tooltip header.
local Loca = Ext.Require("Game/Loca.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local ItemWords = {}

function ItemWords.Line(item)
    local s = item.name
    if item.count and item.count > 1 then s = L("item_count", { name = s, count = item.count }) end
    local rarity = item.rarity and item.rarity ~= "Common" and Loca.Enum("RarityNameStyle", item.rarity)
    return Strings.List({ s, rarity, item.value and item.value > 0 and L("item_value", { gold = item.value }),
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

return ItemWords
