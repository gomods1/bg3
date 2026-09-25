-- Trading (Game/Trade): the gold on both sides, then "Buy from Arron" (the trader's goods with their
-- prices) and one "Sell" list per party member. Enter on an item buys or sells it at once, as the
-- game's quick trade does on a double click; the new gold is said once the game has done it.
-- Ctrl+D describes an item. "Vender mercancía" sells the items marked as wares. Escape is the
-- game's (closes the trade). Barter mode (offers, balance) is not read yet.
local Game = Ext.Require("Game/Trade.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Timer = Ext.Require("Core/Timer.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local ItemWords = Ext.Require("Screens/ItemWords.lua")

local L = Strings.Get

local Trade = ListScreen.Extend()
Trade.Widgets = { Game.Widget }

local SETTLE_MS = 600 -- the gold changes a few frames after the trade command
local SELL_WARES_LABEL = "h592bb99bg5f52g4042ga35eg5382daa71bdb" -- "Vender mercancía" (Trade.xaml)

function Trade.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_trade")), Trade)
end

local function priceLine(item)
    item.isNew = false
    item.value = nil -- the trade price replaces the item's base value
    return Strings.List({ ItemWords.Line(item), L("trade_price", { gold = item.price or 0 }) })
end

-- Buys or sells item, then says what came of it (the party's gold before and after).
function Trade:Exchange(item, buying)
    local before = Game.Read()
    if not before then return end
    if buying and (item.price or 0) > before.partyGold then
        Speech.Say(L("trade_too_expensive", { name = item.name, price = item.price or 0, gold = before.partyGold }), { interrupt = true })
        return
    end
    if not buying and (item.price or 0) > before.traderGold then
        Speech.Say(L("trade_trader_poor", { trader = before.trader, gold = before.traderGold }), { interrupt = true })
        return
    end
    if not Game.Exchange(item.uuid) then
        Speech.Say(L("could_not_activate", { label = item.name, reason = L("reason_unavailable") }), { interrupt = true })
        return
    end
    Timer.After(SETTLE_MS, function()
        local after = Game.Read()
        if not after or after.partyGold == before.partyGold then
            Speech.Say(L("could_not_activate", { label = item.name, reason = L("reason_unavailable") }), { interrupt = true })
            return
        end
        Speech.Say(L(buying and "trade_bought" or "trade_sold", { name = item.name, gold = after.partyGold }), { interrupt = true })
        self:Refresh()
    end)
end

local function itemControls(self, items, buying)
    local out = {}
    for _, item in ipairs(items) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return priceLine(item) end,
            details = function() return item.description end,
            activate = function() self:Exchange(item, buying) end,
        })
    end
    if #out == 0 then out[1] = Controls.Text(L("container_empty")) end
    return out
end

function Trade:Build()
    local t = Game.Read()
    if not t then return {} end
    local out = { Controls.Text(L("trade_gold", { gold = t.partyGold, trader = t.trader, traderGold = t.traderGold })) }
    out[#out + 1] = Controls.Item({
        kind = "button",
        describe = function() return L("trade_buy_from", { trader = t.trader, n = #t.buy }) end,
        activate = function()
            self:Push(L("trade_buy_from", { trader = t.trader, n = #t.buy }), function()
                local now = Game.Read()
                return itemControls(self, now and now.buy or {}, true)
            end)
        end,
    })
    for i, side in ipairs(t.sell) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return L("trade_sell_from", { owner = side.owner, n = #side.items }) end,
            activate = function()
                self:Push(L("trade_sell_from", { owner = side.owner, n = #side.items }), function()
                    local now = Game.Read()
                    return itemControls(self, now and now.sell[i] and now.sell[i].items or {}, false)
                end)
            end,
        })
    end
    if t.hasWares then
        out[#out + 1] = Controls.Button({
            label = Strings.List({ Loca.Text(SELL_WARES_LABEL) or "?", L("trade_price", { gold = t.waresValue }) }),
            activate = function(done) done(Game.SellWares(), "reason_unavailable") end,
        })
    end
    return out
end

function Trade:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_trade")
    return lines
end

return Trade
