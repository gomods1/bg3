-- The character panel (widget CharacterPanel; its DC reads as gui::DCAlchemy): the selected
-- character's inventory, equipment and sheet. Facts (verified 2026-09-24, Tav on the beach):
--   SelectedCharacter.Inventory (Gold, Weight, Slots[] of { Index, Object = ls.VMItem });
--   SelectedCharacter.Equipment: one property per slot (MeleeMainHand, Breast, Boots, ... ;
--     each { SlotType, Item = ls.VMItem or empty, EquippedType, IsEnabled });
--   Stats: Abilities[] (Ability "Strength", Value 17, Modifier 3, HasSavingThrowProficiency),
--     ArmorClass.Value, Level (Value, XPForNextLevel, LevelUpAvailable), Experience.Value,
--     ClassList[] (ClassDisplayName handle), Passives[] (Name handle: "notable traits").
--   Using an item as a double click does: the DC's UseGameObject(item VM) (DataTemplates.xaml:
--   equips equipment, uses consumables); unequipping: UnequipItemCommand(slot VM)
--   (CharacterSheetTemplates_k.xaml).
local Vm = Ext.Require("Game/Vm.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Player = Ext.Require("Game/Player.lua")
local Items = Ext.Require("Game/Items.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Characters = Ext.Require("Game/Characters.lua")

local Inventory = {}

Inventory.Widget = "CharacterPanel"

-- Equipment slots in the order the panel shows them (left column, right column, weapons).
local SLOTS = { "Helmet", "Cloak", "Breast", "Gloves", "Boots", "Amulet", "Ring", "Ring2",
    "MeleeMainHand", "MeleeOffHand", "RangedMainHand", "RangedOffHand", "LightSource", "MusicalInstrument" }

local function me() return Player.SelectedCharacter() end

local function slotObjects()
    return Vm.List(Vm.Get(me(), "Inventory"), "Slots")
end

-- The inventory's items in the panel's order: { Items.Read(...) + slot = index }.
function Inventory.Items()
    local out = {}
    for i, slot in ipairs(slotObjects()) do
        local item = Items.Read(Vm.Get(slot, "Object"))
        if item then
            item.slot = i
            out[#out + 1] = item
        end
    end
    return out
end

-- { gold, weight }
function Inventory.Totals()
    local inv = Vm.Get(me(), "Inventory")
    return { gold = Vm.Get(inv, "Gold") or 0, weight = Vm.Get(inv, "Weight") or 0 }
end

-- { { slotType, label, item = Items.Read(...) or nil } } in SLOTS order.
function Inventory.Equipment()
    local eq = Vm.Get(me(), "Equipment")
    local out = {}
    for _, name in ipairs(SLOTS) do
        local slot = Vm.Get(eq, name)
        local item = slot and Items.Read(Vm.Get(slot, "Item"))
        -- The game's panel has no light source slot (no name for it in its templates): listed only
        -- when something is in it.
        if slot and (item or name ~= "LightSource") then
            out[#out + 1] = {
                slotType = name,
                label = Loca.Enum("SelectedEquipmentSlotTextBlockStyle", name) or (name == "LightSource" and Strings.Get("slot_light_source")) or name,
                item = item,
            }
        end
    end
    return out
end

-- The selected character's sheet (Game/Characters.Sheet).
function Inventory.Sheet()
    return Characters.Sheet(me())
end

local function dc() return Vm.WidgetDc(Inventory.Widget) end

-- Uses the item in inventory slot i as a double click does (equip, drink, read...). Returns ok.
function Inventory.Use(i)
    local slot = slotObjects()[i]
    local item = slot and Vm.Get(slot, "Object")
    if not item then return false end
    return Vm.Run(dc(), "UseGameObject", item)
end

-- The inventory grid's cells (invCellBase: each cell's TemplatedParent.Content is the slot view
-- model, its Object the item; verified 2026-09-24), in layout order, shown ones only.
local function cells()
    local out = {}
    for _, el in ipairs(Ui.FindAllByName(Ui.FindWidget(Inventory.Widget), "invCellBase")) do
        if Ui.IsShown(el) then out[#out + 1] = el end
    end
    return out
end

-- Opens the game's context menu on the inventory item with entity uuid: a verified right click on
-- its cell (Game/ContextMenu reads the menu). onDone(ok, reasonKey, fx, fy) with the click point.
function Inventory.OpenMenu(uuid, onDone)
    Activate.ClickGridItem(Inventory.Widget, {
        name = "invCellBase",
        button = "right",
        cells = cells,
        isTarget = function(el)
            local object = Vm.Get(Ui.TemplateItem(el), "Object")
            return object ~= nil and tostring(Vm.Get(object, "EntityUUID")) == tostring(uuid)
        end,
    }, onDone)
end

-- Unequips the item in equipment slot slotType. Returns ok.
function Inventory.Unequip(slotType)
    local slot = Vm.Get(Vm.Get(me(), "Equipment"), slotType)
    if not slot then return false end
    return Vm.Run(dc(), "UnequipItemCommand", slot)
end

return Inventory
