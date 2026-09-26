-- The quest reward window (widget RewardPanel, RewardPanel.xaml): it stays until accepted.
-- Facts (verified 2026-09-25, "Salva a Arabella"): DC QuestName / QuestDescription (handles),
-- MandatoryItems (an inventory VM: Slots[] of { Object = ls.VMItem }: "Colgante de Komira"),
-- OptionalItems[] (items to choose from, up to MaxSelectedItems; SelectedItems[],
-- SelectedItemsCount; a choice is toggled by ToggleOptionalItemCommand(item)), ReceiverCharacter
-- (the character VM who gets them), GetRewardsAndClose.ActionCommand (the Accept button).
local Vm = Ext.Require("Game/Vm.lua")
local Items = Ext.Require("Game/Items.lua")
local Loca = Ext.Require("Game/Loca.lua")

local Reward = {}

Reward.Widget = "RewardPanel"

local function dc() return Vm.WidgetDc(Reward.Widget) end

-- { quest, description, receiver, items = { Items.Read }, optional = { Items.Read + selected },
--   maxChoices, chosen } or nil.
function Reward.Read()
    local d = dc()
    if not d then return nil end
    local out = {
        quest = Loca.Text(Vm.Get(d, "QuestName")),
        description = Loca.Text(Vm.Get(d, "QuestDescription")),
        receiver = Vm.Text(Vm.Get(d, "ReceiverCharacter"), "Name"),
        items = {}, optional = {},
        maxChoices = Vm.Get(d, "MaxSelectedItems") or 0,
        chosen = Vm.Get(d, "SelectedItemsCount") or 0,
    }
    for _, slot in ipairs(Vm.List(Vm.Get(d, "MandatoryItems"), "Slots")) do
        local item = Items.Read(Vm.Get(slot, "Object"))
        if item then out.items[#out.items + 1] = item end
    end
    local selected = Vm.List(d, "SelectedItems")
    for i, object in ipairs(Vm.List(d, "OptionalItems")) do
        local item = Items.Read(object)
        if item then
            item.index = i
            item.selected = false
            for _, s in ipairs(selected) do
                if Vm.Same(s, object) then item.selected = true end
            end
            out.optional[#out.optional + 1] = item
        end
    end
    return out
end

-- Chooses or unchooses optional item i. Returns ok.
function Reward.Toggle(i)
    local d = dc()
    local object = Vm.List(d, "OptionalItems")[i]
    return object ~= nil and Vm.Run(d, "ToggleOptionalItemCommand", object)
end

-- The Accept button. Returns ok.
function Reward.Accept()
    return Vm.Run(Vm.Get(dc(), "GetRewardsAndClose"), "ActionCommand", nil)
end

return Reward
