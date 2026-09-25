-- Loot and container window (widget ContainerWidget, gui::DCContainerInventory; Container.xaml).
-- Facts (verified 2026-09-24, looting the nautiloid mind flayer):
--  * DC.CurrentPlayer.ContainerInventoryList[] = the open containers (ls.Character or item VMs:
--    Name handle, EntityUUID), each with LootInventory.Slots[] (ls.VMInventorySlot: Index, Object).
--  * Object = ls.VMItem: Name/Description handles, Count, Gold (value), Rarity, IsStolen, EntityUUID.
--  * DC.TakeAllAndCloseCommand.ActionCommand(nil) takes everything (BoundEvent UITakeAll = Space).
--  * DC.TakeItemCommand.ActionCommand(item VM) takes one item: what a double click on its slot
--    does (DataTemplates.xaml, the slot style's MouseDoubleClick; the parameter is the slot's
--    Object).
local Vm = Ext.Require("Game/Vm.lua")
local Items = Ext.Require("Game/Items.lua")

local Container = {}

Container.Widget = "ContainerWidget"
Container.TakeAllLabel = "h1cc89290gfa2eg406cg9e5bg75a612b65633"

local function dc() return Vm.WidgetDc(Container.Widget) end

-- { { name, uuid, items = { Game/Items.Read results } } }
function Container.Read()
    local out = {}
    for _, c in ipairs(Vm.List(Vm.Get(dc(), "CurrentPlayer"), "ContainerInventoryList")) do
        local entry = { name = Vm.Text(c, "Name"), uuid = Vm.Get(c, "EntityUUID"), items = {} }
        for _, slot in ipairs(Vm.List(Vm.Get(c, "LootInventory"), "Slots")) do
            local item = Items.Read(Vm.Get(slot, "Object"))
            if item then entry.items[#entry.items + 1] = item end
        end
        out[#out + 1] = entry
    end
    return out
end

-- Takes item i (in reading order across the open containers, as Container.Read lists them).
-- Returns ok.
function Container.TakeItem(i)
    local n = 0
    for _, c in ipairs(Vm.List(Vm.Get(dc(), "CurrentPlayer"), "ContainerInventoryList")) do
        for _, slot in ipairs(Vm.List(Vm.Get(c, "LootInventory"), "Slots")) do
            local object = Vm.Get(slot, "Object")
            if object then
                n = n + 1
                if n == i then return Vm.Run(Vm.Get(dc(), "TakeItemCommand"), "ActionCommand", object) end
            end
        end
    end
    return false
end

-- Takes everything and closes the window. Returns ok.
function Container.TakeAll()
    return Vm.Run(Vm.Get(dc(), "TakeAllAndCloseCommand"), "ActionCommand", nil)
end

return Container
