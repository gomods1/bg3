-- Loot and containers (Game/Container): the container's name, its items (Enter takes one, Ctrl+D
-- describes it), then Take all. Escape (the game's) closes; Space is the game's take-all (it said "nothing
-- selected" when the list took it, a barrel in the Blighted Village, 2026-09-24).
local Game = Ext.Require("Game/Container.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Timer = Ext.Require("Core/Timer.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local TAKE_SETTLE_MS = 300 -- the command is deferred: the slots change a few frames later

local Container = ListScreen.Extend()
Container.Widgets = { Game.Widget }

function Container.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_container")), Container)
end

local ItemWords = Ext.Require("Screens/ItemWords.lua")

local function itemText(item)
    item.isNew = false -- loot is all new; the word would repeat on every line
    return ItemWords.Line(item)
end

function Container:Build()
    local out = {}
    local containers = Game.Read()
    if containers[1] and containers[1].name then self.title = containers[1].name end
    local n = 0
    for _, c in ipairs(containers) do
        if #containers > 1 then out[#out + 1] = Controls.Text(c.name or "?") end
        for _, item in ipairs(c.items) do
            n = n + 1
            local index = n
            out[#out + 1] = Controls.Item({
                kind = "button",
                describe = function() return itemText(item) end,
                details = function() return item.description end,
                -- The game's log says what was taken ("Tav: ha recogido 1 Olla"); the list is read
                -- again without it.
                activate = function()
                    if not Game.TakeItem(index) then
                        Speech.Say(L("could_not_activate", { label = item.name or "?", reason = L("reason_unavailable") }), { interrupt = true })
                        return
                    end
                    Timer.After(TAKE_SETTLE_MS, function() self:Refresh() end)
                end,
            })
        end
    end
    if #out == 0 then out[#out + 1] = Controls.Text(L("container_empty")) end
    out[#out + 1] = Controls.Button({
        label = Loca.Text(Game.TakeAllLabel) or "Take all",
        activate = function(done) done(Game.TakeAll(), "reason_unavailable") end,
    })
    return out
end

function Container:OnKey(combo)
    if combo == "SPACE" then return false end
    return ListScreen.OnKey(self, combo)
end

return Container
