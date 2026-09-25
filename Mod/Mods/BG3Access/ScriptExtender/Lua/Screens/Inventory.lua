-- The character panel (the game's I / N keys; Game/Inventory) as three sections:
--   Inventory: every item; Enter uses it as a double click does (equip, drink, read), Ctrl+D its
--     description; the mod menu's first command, "Actions: <item>", opens the game's own context
--     menu on it (a verified right click) as a sub-list: send to camp, send to a companion, drop,
--     split, examine... (Game/ContextMenu; Enter clicks the entry);
--   Equipment: each slot with what is in it; Enter unequips;
--   Character: level and experience, classes, armour class, abilities, notable traits.
-- Escape is the game's (closes the panel) at the top level.
local Game = Ext.Require("Game/Inventory.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local ItemWords = Ext.Require("Screens/ItemWords.lua")
local ContextMenuList = Ext.Require("Screens/ContextMenuList.lua")
local SheetWords = Ext.Require("Screens/SheetWords.lua")

local L = Strings.Get

local Inventory = ListScreen.Extend()
Inventory.Widgets = { Game.Widget }

local READBACK_MS = 400 -- equipping is deferred: read the result on a later frame

function Inventory.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_character_panel")), Inventory)
end

function Inventory:ItemsList()
    local out = {}
    for _, item in ipairs(Game.Items()) do
        local control = Controls.Item({
            kind = "button",
            describe = function() return ItemWords.Line(item) end,
            details = function() return item.description end,
            activate = function()
                if not Game.Use(item.slot) then
                    Speech.Say(L("could_not_activate", { label = item.name, reason = L("reason_unavailable") }), { interrupt = true })
                    return
                end
                Ext.Timer.WaitForRealtime(READBACK_MS, function()
                    self:Refresh()
                    local c = self:Current()
                    Speech.Say(L(item.isEquipment and "item_equipped_now" or "item_used", { name = item.name }), { interrupt = true })
                    if c then Speech.Say(c.Describe()) end
                end)
            end,
        })
        control.item = item
        out[#out + 1] = control
    end
    if #out == 0 then out[1] = Controls.Text(L("container_empty")) end
    return out
end

function Inventory:EquipmentList()
    local out = {}
    for _, slot in ipairs(Game.Equipment()) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                return L("label_value", { label = slot.label, value = slot.item and ItemWords.Line(slot.item) or L("slot_empty") })
            end,
            details = function() return slot.item and slot.item.description end,
            activate = function()
                if not slot.item then
                    Speech.Say(L("slot_empty"), { interrupt = true })
                    return
                end
                if not Game.Unequip(slot.slotType) then
                    Speech.Say(L("could_not_activate", { label = slot.item.name, reason = L("reason_unavailable") }), { interrupt = true })
                    return
                end
                Ext.Timer.WaitForRealtime(READBACK_MS, function()
                    self:Refresh()
                    Speech.Say(L("item_unequipped", { name = slot.item.name }), { interrupt = true })
                end)
            end,
        })
    end
    return out
end

function Inventory:SheetList()
    local out = {}
    for _, text in ipairs(SheetWords.Lines(Game.Sheet(), true)) do out[#out + 1] = Controls.Text(text) end
    return out
end

function Inventory:Build()
    local totals = Game.Totals()
    local nItems = #Game.Items()
    return {
        Controls.Item({
            kind = "button",
            describe = function() return L("section_inventory", { n = nItems, gold = totals.gold }) end,
            activate = function() self:Push(L("section_inventory_title"), self.ItemsList) end,
        }),
        Controls.Item({
            kind = "button",
            describe = function() return L("section_equipment") end,
            activate = function() self:Push(L("section_equipment"), self.EquipmentList) end,
        }),
        Controls.Item({
            kind = "button",
            describe = function() return L("section_character") end,
            activate = function() self:Push(L("section_character"), self.SheetList) end,
        }),
    }
end

-- Opens the game's context menu of item (a verified right click on its cell) as a sub-list.
function Inventory:ItemActions(item)
    Game.OpenMenu(item.uuid, function(ok, reason, fx, fy)
        if not ok then
            Speech.Say(L("could_not_activate", { label = item.name, reason = L(reason or "reason_no_cursor") }), { interrupt = true })
            return
        end
        ContextMenuList.Open(self, Game.Widget, L("item_actions", { name = item.name }), { fx, fy }, item.name,
            function() self:Refresh() end)
    end)
end

-- The mod menu's commands for this screen: the context menu of the item in focus.
function Inventory:Commands()
    local c = self:Current()
    if not (c and c.item) then return {} end
    local item = c.item
    return { { label = L("item_actions", { name = item.name }), run = function() self:ItemActions(item) end } }
end

function Inventory:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_inventory")
    return lines
end

return Inventory
