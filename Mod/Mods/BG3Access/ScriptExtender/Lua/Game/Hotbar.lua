-- The controlled character's hotbar (client). Facts (verified 2026-09-24, first nautiloid fight):
-- CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.KeyboardHotBars[] (ls.VMHotBar:
-- HotBarType CommonHotBar/ClassHotBar/ItemHotBar/PassivesHotBar/..., SlotList[] of ls.VMHotBarSlot:
-- HotKey, CanUse, SlotType, Content = ls.VMCharacterAction { Name handle, MainCost (Action,
-- BonusAction, ...), TargetingType (Target, Projectile, Shout, ...), PrototypeID }).
-- The HotBar widget's DC.UseSlotCommand(slot) arms the action like a click on the slot (verified:
-- the game enters targeting and previews the attack on the hovered enemy).
-- Item slots (SlotType Item) hold the item VM instead (Name, MainCost, UseType Potion/Scroll/...,
-- Count, EntityUUID): no TargetingType. Using a potion drinks it at once (verified: "Tav ha usado
-- Poción de curación."); a scroll arms its spell (Game/Spells.OfItem gives its type).
-- While an action is armed CurrentPlayer.UIData.ActiveSlot is set (nil otherwise; verified with
-- the main-hand attack and the scroll of revivify). It is also set while a potion is being drunk
-- (measured 400 ms after the use), so it does not tell "armed" from "being used".
-- Upcasting: a levelled spell's Content.SpellUpcast[] lists one ls.VMUpcast per slot level it can
-- be cast with (Gale at level 3: Proyectil mágico lvl1 Projectile_MagicMissile, lvl2
-- Projectile_MagicMissile_2; SlotLevel, IsUpcasted, CanUse, PrototypeID). The game's upcast
-- buttons run UseSlotCommand with that VM: it arms the spell at that level directly (verified
-- 2026-09-24: UIData.ActiveTask.Upcast.SlotLevel 2, RootCastSpell Projectile_MagicMissile).
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Player = Ext.Require("Game/Player.lua")
local Spells = Ext.Require("Game/Spells.lua")

local Hotbar = {}

local WIDGET = "HotBar"
-- Bars listed to the player, in this order (passives cannot be used).
local BARS = { CommonHotBar = 1, ClassHotBar = 2, ItemHotBar = 3, CustomHotBar = 4 }

-- The slot levels of a levelled spell (Content VM), when there is more than one.
local function upcastLevels(content)
    local list = Vm.List(content, "SpellUpcast")
    if #list < 2 then return nil end
    local out = {}
    for _, u in ipairs(list) do
        out[#out + 1] = { level = Vm.Get(u, "SlotLevel") or 0, canUse = Vm.Get(u, "CanUse") == true, id = Vm.Get(u, "PrototypeID") }
    end
    return out
end

local function bars()
    return Vm.List(Vm.Get(Player.SelectedCharacter(), "PlayerCharacterProperties"), "KeyboardHotBars")
end

-- A slot's action: id (the spell; for items the spell the item casts, nil for potions),
-- targeting (the game's TargetingType, or the item spell's type), item (bool). Items (ls.VMItem)
-- have no TargetingType / PrototypeID.
local function slotAction(slot, content)
    if Vm.Enum(slot, "SlotType") == "Item" then
        local id = Spells.OfItem(Vm.Get(content, "EntityUUID"))
        local info = id and Spells.Info(id)
        return id, info and info.type, true
    end
    return Vm.Get(content, "PrototypeID"), Vm.Enum(content, "TargetingType"), false
end

-- { { bar, slot (indexes), name, cost, targeting, canUse, hotKey, id, item, count, useType,
--   spellLevel (0 = cantrip or not a spell), levels = { { level, canUse, id } } (the slot levels it
--   can be cast with, when more than one) } } in bar order. id is the spell (for items: the spell the item casts, nil for potions); item is true for
-- item slots.
function Hotbar.Actions()
    local out = {}
    for b, bar in ipairs(bars()) do
        local kind = Vm.Enum(bar, "HotBarType")
        if BARS[kind or ""] then
            for s, slot in ipairs(Vm.List(bar, "SlotList")) do
                local c = Vm.Get(slot, "Content")
                if c then
                    local id, targeting, isItem = slotAction(slot, c)
                    out[#out + 1] = {
                        bar = b, slot = s, barOrder = BARS[kind],
                        name = Vm.Text(c, "Name"),
                        cost = Vm.Enum(c, "MainCost"),
                        targeting = targeting,
                        canUse = Vm.Get(slot, "CanUse") == true,
                        hotKey = Vm.Get(slot, "HotKey"),
                        id = id,
                        item = isItem,
                        count = isItem and Vm.Get(c, "Count") or nil,
                        useType = isItem and Vm.Enum(c, "UseType") or nil,
                        spellLevel = (not isItem) and (Vm.Get(c, "SpellSlotLevel") or 0) or 0,
                        levels = (not isItem) and upcastLevels(c) or nil,
                    }
                end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.barOrder ~= b.barOrder then return a.barOrder < b.barOrder end
        return a.slot < b.slot
    end)
    return out
end

-- Whether the action in bar b, slot s can be used right now (read live: while Rage's animation
-- plays every action reads unusable, and a list built then kept Reckless Attack "unavailable",
-- 2026-09-25).
function Hotbar.CanUse(b, s)
    local bar = bars()[b]
    local slot = bar and Vm.List(bar, "SlotList")[s]
    return Vm.Get(slot, "CanUse") == true
end

-- Why the controlled character cannot act, as the hotbar shows it ("No se puede controlar:
-- derribado" while Tav lay prone on ice, 2026-09-25): the shown texts of the HotBar's
-- CapabilitiesErrors (PlayerCharacterProperties.ModifiedCapabilities, the first one shown).
-- nil while the hotbar is hidden (a menu over it).
function Hotbar.CapabilityMessages()
    local panel = Ui.FindElement("HotBar", "CapabilitiesErrors")
    if not panel then return nil end
    local out = {}
    for _, el in ipairs(panel and Ui.FindAllByName(panel, "Message") or {}) do
        local text = Ui.IsShown(el) and Ui.InlineText(el)
        if text then out[#out + 1] = text end
    end
    return out
end

-- Arms the action in bar b, slot s (as a click on it). Returns ok.
function Hotbar.Use(b, s)
    local slot = Vm.List(bars()[b], "SlotList")[s]
    if not slot then return false end
    return Vm.Run(Vm.WidgetDc(WIDGET), "UseSlotCommand", slot)
end

-- Arms the spell in bar b, slot s at slot level (its SpellUpcast variant). Returns ok.
function Hotbar.UseAt(b, s, level)
    local slot = Vm.List(bars()[b], "SlotList")[s]
    for _, u in ipairs(Vm.List(Vm.Get(slot, "Content"), "SpellUpcast")) do
        if Vm.Get(u, "SlotLevel") == level then return Vm.Run(Vm.WidgetDc(WIDGET), "UseSlotCommand", u) end
    end
    return false
end

-- Spell slots of the controlled character: { [level] = { value, max } }.
function Hotbar.SpellSlots()
    local out = {}
    for _, sl in ipairs(Vm.List(Vm.Get(Player.SelectedCharacter(), "Stats"), "SpellSlots")) do
        local level = Vm.Get(sl, "Level")
        if level then out[level] = { value = Vm.Get(sl, "Value") or 0, max = Vm.Get(sl, "MaxValue") or 0 } end
    end
    return out
end

-- true while an action is armed (the game is waiting for a target or a place).
function Hotbar.Armed()
    if Vm.Get(Vm.Get(Player.Current(), "UIData"), "ActiveSlot") then return true end -- not "~= nil": __eq
    return false
end

-- The armed action, whoever armed it (the mod, the game's number keys, an item's "Lanzar"):
-- { name, id, targeting, useType (items), canUse, object = { name, uuid } } or nil. object is what a
-- throw throws once chosen: ActiveTask.TaskObject (verified 2026-09-25: "Lanzar" on a fork in the
-- inventory arms the common bar's Throw slot, HotKey X, with the fork as TaskObject).
function Hotbar.ArmedAction()
    local ui = Vm.Get(Player.Current(), "UIData")
    local slot = Vm.Get(ui, "ActiveSlot")
    if not slot then return nil end
    local c = Vm.Get(slot, "Content")
    local id, targeting, isItem = slotAction(slot, c)
    local out = { name = Vm.Text(c, "Name"), id = id, targeting = targeting, useType = isItem and Vm.Enum(c, "UseType") or nil,
        canUse = Vm.Get(slot, "CanUse") == true }
    local object = Vm.Get(Vm.Get(ui, "ActiveTask"), "TaskObject")
    if object then out.object = { name = Vm.Text(object, "Name"), uuid = Vm.Get(object, "EntityUUID") } end
    return out
end

return Hotbar
