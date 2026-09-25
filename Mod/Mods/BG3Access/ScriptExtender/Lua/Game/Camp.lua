-- Rests (client). Facts (verified 2026-09-24 at the chapel entrance and in camp):
--   Short rest: the HUD DC's ShortRest command (the rest menu's item; enabled when the selected
--     character's PlayerCharacterProperties.IsShortRestAvailable): the party healed 11, 8, 7.
--   Long rest: the HUD DC's CampTravel command (the rest menu's "Long rest" item): the game asks
--     "¿Quieres dar el día por terminado?" (a message box), travels to camp, may ask again
--     ("Alguien del campamento quiere hablar contigo..."), then opens widget MakeCamp:
--     SelectedSuppliesAmount of CurrentPlayer.RequiredPartySupplies (0 / 40),
--     PartyCampSupplies.Slots[] (ls.VMCampInventorySlot: Object = the item VM, SelectedAmount) shown
--     by the ListBox SuppliesView (SelectionMode Multiple): selecting its items (IsSelected) makes
--     the game count them (one "Provisiones" pack = 40). AutoSelectBtn runs AutoSelectCommand with
--     the ListBox's SelectedItems (a collection: clicked, not called); StartRestBtn runs
--     ProcessRestCommand (no parameter): "Descanso parcial" until enough is selected.
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Player = Ext.Require("Game/Player.lua")
local Items = Ext.Require("Game/Items.lua")
local Activate = Ext.Require("Game/Activate.lua")

local Camp = {}

Camp.Widget = "MakeCamp"
Camp.Labels = { -- MakeCamp.xaml
    title = "h54a9edbag9cf2g4f2egb188g1431d56c3159",       -- "Descanso largo"
    description = "hd87d1a54g859cg4384g97bag802a2071e49e", -- "Termina el día y recuperas..."
    supplies = "h3cef439fg92cdg4b5bgb3fdg5fd5db63d33a",    -- "Suministros de campamento"
    autoSelect = "h520e6ffag14aag4d3aga15dg1ed8d9a0b852",  -- "Selección automática"
    partialRest = "h7e75fd8fgc164g436fgbbf7gc0b993f7fee8", -- "Descanso parcial"
    partialNote = "hae826c89g4f7eg4a64g976fgf6cbebab7564", -- "...solo se restaurarán hasta la mitad..."
    fullRest = "h8eb28360g171eg47a7g8915g31d5ebd7198d",    -- "Descanso completo"
    fullNote = "h0400598cg92a9g4a17g9b6agf2a78bb93ab3",    -- "Restaura todos los puntos de golpe..."
}

local function hud() return Vm.WidgetDc("HotBar") end
local function dc() return Vm.WidgetDc(Camp.Widget) end

function Camp.CanShortRest()
    local pcp = Vm.Get(Player.SelectedCharacter(), "PlayerCharacterProperties")
    return Vm.Get(pcp, "IsShortRestAvailable") == true
end

-- Returns ok.
function Camp.ShortRest()
    return Vm.Run(hud(), "ShortRest", nil)
end

-- The game's long rest: to camp, its questions, then the MakeCamp screen. Returns ok.
function Camp.LongRest()
    return Vm.Run(hud(), "CampTravel", nil)
end

-- MakeCamp: { selected, required, supplies = { { name, count, selected (amount taken from it) } } }
-- or nil when the screen is not open.
function Camp.Read()
    local d = dc()
    if not d then return nil end
    local out = {
        selected = Vm.Get(d, "SelectedSuppliesAmount") or 0,
        required = Vm.Get(Vm.Get(d, "CurrentPlayer"), "RequiredPartySupplies") or 0,
        supplies = {},
    }
    for _, slot in ipairs(Vm.List(Vm.Get(d, "PartyCampSupplies"), "Slots")) do
        local item = Items.Read(Vm.Get(slot, "Object"))
        if item then
            out.supplies[#out.supplies + 1] = { name = item.name, count = item.count, selected = Vm.Get(slot, "SelectedAmount") or 0 }
        end
    end
    return out
end

local function supplyItems()
    local out = {}
    local function walk(el, depth)
        if depth > 30 then return end
        if tostring(el.Type):find("ListBoxItem") then out[#out + 1] = el end
        for _, k in ipairs(Ui.Kids(el)) do walk(k, depth + 1) end
    end
    local list = Ui.FindElement(Camp.Widget, "SuppliesView")
    if list then walk(list, 0) end
    return out
end

-- Selects or deselects supply i (as a click on it). Returns ok.
function Camp.ToggleSupply(i)
    local item = supplyItems()[i]
    if not item then return false end
    return pcall(function() item:SetProperty("IsSelected", Ui.Prop(item, "IsSelected") ~= true) end)
end

-- The game's auto selection (a verified click on its button). onDone(ok, reasonKey).
function Camp.AutoSelect(onDone)
    Activate.Click(Camp.Widget, "AutoSelectBtn", onDone)
end

-- Starts the rest with what is selected. Returns ok.
function Camp.Rest()
    return Vm.Run(dc(), "ProcessRestCommand", nil)
end

return Camp
