-- Trading (widget Trade). Facts (verified 2026-09-24 with Arron in the grove, Trade.xaml):
--   Mode "Trade" (quick trading, the default) or "Barter" (offers, balance: not read yet);
--   TradePartyGold, TraderInventoryGold; Trader (character VM); HasWares, WaresValue, SellWares;
--   TraderInventory.Slots[] and PartyCharacterInventories[] (OwnerObject = character VM,
--   TradeInventories[1].Slots[]) hold { Index, Object = ls.VMItem } where the item also has
--   TradePrice (what it costs or brings now) and ItemType "Gold" for the coins themselves.
--   TradeItemCommand(item) buys or sells at once in Trade mode, as a double click on the item
--   does (Trade.xaml): a handaxe sold for 6 (party gold 4 -> 10), a shovel bought for 3 (10 -> 7).
local Vm = Ext.Require("Game/Vm.lua")
local Items = Ext.Require("Game/Items.lua")
local Entities = Ext.Require("Game/Entities.lua")

local Trade = {}

Trade.Widget = "Trade"

local function dc() return Vm.WidgetDc(Trade.Widget) end

-- Items.Read + price, without the coins.
local function goods(slots)
    local out = {}
    for _, slot in ipairs(slots) do
        local object = Vm.Get(slot, "Object")
        if object and Vm.Enum(object, "ItemType") ~= "Gold" then
            local item = Items.Read(object)
            item.price = Vm.Get(object, "TradePrice") or item.value
            out[#out + 1] = item
        end
    end
    return out
end

local function nameOf(characterVm)
    return Entities.Name(Vm.Get(characterVm, "EntityUUID")) or Vm.Text(characterVm, "Name") or "?"
end

-- { trader, mode, partyGold, traderGold, hasWares, waresValue, buy = { item }, sell = { { owner,
--   items } } } or nil when the trade screen is not open.
function Trade.Read()
    local d = dc()
    if not d then return nil end
    local sell = {}
    for _, inv in ipairs(Vm.List(d, "PartyCharacterInventories")) do
        local items = {}
        for _, ti in ipairs(Vm.List(inv, "TradeInventories")) do
            for _, item in ipairs(goods(Vm.List(ti, "Slots"))) do items[#items + 1] = item end
        end
        sell[#sell + 1] = { owner = nameOf(Vm.Get(inv, "OwnerObject")), items = items }
    end
    return {
        trader = nameOf(Vm.Get(d, "Trader")),
        mode = Vm.Enum(d, "Mode"),
        partyGold = Vm.Get(d, "TradePartyGold") or 0,
        traderGold = Vm.Get(d, "TraderInventoryGold") or 0,
        hasWares = Vm.Get(d, "HasWares") == true,
        waresValue = Vm.Get(d, "WaresValue") or 0,
        buy = goods(Vm.List(Vm.Get(d, "TraderInventory"), "Slots")),
        sell = sell,
    }
end

-- The item VM with entity uuid, on the trader's side or the party's.
local function findItem(d, uuid)
    local function inSlots(slots)
        for _, slot in ipairs(slots) do
            local object = Vm.Get(slot, "Object")
            if object and Vm.Get(object, "EntityUUID") == uuid then return object end
        end
    end
    local found = inSlots(Vm.List(Vm.Get(d, "TraderInventory"), "Slots"))
    if found then return found end
    for _, inv in ipairs(Vm.List(d, "PartyCharacterInventories")) do
        for _, ti in ipairs(Vm.List(inv, "TradeInventories")) do
            found = inSlots(Vm.List(ti, "Slots"))
            if found then return found end
        end
    end
end

-- Buys or sells the item with entity uuid at once (the game's TradeItemCommand). True when the
-- game took the command; the gold changes on a later frame.
function Trade.Exchange(uuid)
    local d = dc()
    local item = d and findItem(d, uuid)
    if not item then return false end
    return Vm.Run(d, "TradeItemCommand", item)
end

-- Sells every item marked as wares (the game's "Vender mercancía").
function Trade.SellWares()
    local d = dc()
    return d ~= nil and Vm.Run(d, "SellWares")
end

return Trade
