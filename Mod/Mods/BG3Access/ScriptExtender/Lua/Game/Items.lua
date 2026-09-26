-- Item view models (ls.VMItem), the same in loot windows, the inventory and equipment slots
-- (verified 2026-09-24): Name/Description handles, Count, Gold (value), Rarity, IsStolen,
-- EntityUUID, ItemType (Consumable, Scroll, ...), UseType (Potion, Scroll, ...), Equipped
-- (NotEquipped / Equipped), IsEquipment, IsNew.
local Vm = Ext.Require("Game/Vm.lua")
local Channels = Ext.Require("Net/Channels.lua")
local Text = Ext.Require("Core/Text.lua")

local Items = {}

-- { name, description, count, value, weight? (kg, Stats.Weight.Value), campSupplies? (per unit),
--   rarity, stolen, uuid,
--   itemType, useType, equipped, isEquipment, isNew } or nil.
function Items.Read(item)
    if not item then return nil end
    return {
        name = Vm.Text(item, "Name") or "?",
        description = Vm.Text(item, "Description"),
        count = Vm.Get(item, "Count") or 1,
        value = Vm.Get(item, "Gold"),
        weight = Vm.Get(Vm.Get(Vm.Get(item, "Stats"), "Weight"), "Value"),
        campSupplies = Vm.Get(item, "CampSupplies"), -- per unit: Provisiones 40, Sandía 10, Pescado 4
        rarity = Vm.Enum(item, "Rarity"),
        stolen = Vm.Get(item, "IsStolen") == true,
        uuid = Vm.Get(item, "EntityUUID"),
        itemType = Vm.Enum(item, "ItemType"),
        useType = Vm.Enum(item, "UseType"),
        equipped = Vm.Enum(item, "Equipped") == "Equipped",
        isEquipment = Vm.Get(item, "IsEquipment") == true,
        isNew = Vm.Get(item, "IsNew") == true,
    }
end

-- Items lying in the world (no view model): what the server knows of them, fetched ahead
-- (Items.Fetch) and kept: { description?, value?, rarity?, weight?, locked, movable } by uuid.
local worldInfo = {}

-- Asks the server about the items with these uuids (asked again each time: a lock can be picked);
-- what was known stays readable until the answer comes. onDone() when known.
function Items.Fetch(uuids, onDone)
    if #uuids == 0 then
        if onDone then onDone() end
        return
    end
    Channels.ItemInfo:RequestToServer({ uuids = uuids }, function(reply)
        for u, info in pairs(reply or {}) do
            if info.description then info.description = Text.Clean(info.description) end
            worldInfo[u] = info
        end
        if onDone then onDone() end
    end)
end

-- What is known of a world item (Items.Fetch), or nil.
function Items.WorldInfo(uuid)
    return worldInfo[uuid]
end

return Items
