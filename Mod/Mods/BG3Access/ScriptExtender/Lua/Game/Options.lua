-- Option rows: the data context's "Options" collection on first-time setup (gui::DCFirstTimeSetup)
-- and the options menu (gui::DCOptions, one widget per tab). Each row is a view model with Text and
-- Description (handles), ListItemType, Enabled, and per type (Public/Game/GUI/Library/OptionTemplates.xaml):
--   ComboBox (ls.VMComboBoxSetting): SelectedItem.Name (handle), ComboItems; changed with the DC's
--             Next/PrevComboItemCommand executed with the row as parameter (SetProperty("SelectedItem")
--             does nothing).
--   TickBox  (ls.VMTickBoxSetting): Value (bool).
--   Slider   (gui::VMSliderSetting): Value, Min, Max (floats).
--   Button   (ls.VMListButton): ButtonCommand.ActionCommand.
--   String   (ls.VMListItem): a section header.
--   KeyBinding (gui::VMKeybindingOption, key binding tab): Bindings[] of gui::VMKeybinding whose
--             BindingString reads as an unresolvable "ResStr_…" in Lua; the keys come from the input
--             scheme instead (Game/Input), matched through the row's Text handle.
--   EditBox: Value (text), MaxLength, HideValue (not met yet).
-- TickBox and Slider change like the UI does it: SetProperty("Value") on the row, then the DC's
-- ValueChanged(row) (verified 2026-09-24: tutorials tick box, autosave slider).
-- Commands are deferred: read the row again on a later frame to hear the result.
local Vm = Ext.Require("Game/Vm.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Input = Ext.Require("Game/Input.lua")

local Options = {}

-- Options menu tabs in on-screen order: widget name (= TabId), tab button element, label handle
-- (Public/Game/GUI/Library/UIData.xaml, LSPanelData *OptionInfo). The controller tab is hidden
-- (width 0) without a controller.
Options.Tabs = {
    { widget = "GameOptions", button = "gameplayButton", label = "h403a278dg5a07g4880g8cbfg8f7a32371774" },
    { widget = "KeybindingOptions", button = "keybindingButton", label = "hfeda2eecg2914g43b5g8c40gf631955c6fc7" },
    { widget = "ControllerOptions", button = "controllerButton", label = "h8477d7d0gd300g4038g900cg9fba6ea3f776" },
    { widget = "VideoOptions", button = "videoButton", label = "h6fe88b68g3107g428bga892g9c9e8de97b26" },
    { widget = "AudioOptions", button = "audioButton", label = "hfbb6060fge7cbg43a8gbc3egf7d866372ee5" },
    { widget = "InterfaceOptions", button = "interfaceButton", label = "h38048018g83c3g4319g97b6g45d78b408e01" },
    { widget = "AccessibilityOptions", button = "accessibilityButton", label = "hd2ec56c4gbd50g4f0cg9735g684c580461ae" },
}

Options.TabWidgets = {}
for i, t in ipairs(Options.Tabs) do Options.TabWidgets[#Options.TabWidgets + 1] = t.widget; t.index = i end

-- Labels of the bottom buttons of every options tab (OptionTemplates.xaml OptionBottomButtons):
-- Back (CustomEvent CloseWidget, the same as the game's Escape) and Reset (ResetOptionsToDefaultCommand).
Options.BackLabel = "hfe928c0dgb014g4eb2g8c52g6ed43b026e20"
Options.ResetLabel = "h25d571f7g0b5fg4c8agb2f9g6b3aab5225ce"

function Options.Tab(widgetName)
    for _, t in ipairs(Options.Tabs) do
        if t.widget == widgetName then return t end
    end
    return nil
end

function Options.TabLabel(tab)
    return Loca.Text(tab.label) or tab.widget
end

local function rows(widgetName)
    local dc = Vm.WidgetDc(widgetName)
    return dc, Vm.List(dc, "Options")
end

-- Number of rows (0 when the widget has no option rows).
function Options.Count(widgetName)
    local _, list = rows(widgetName)
    return #list
end

local function comboState(row)
    local sel = Vm.Get(row, "SelectedItem")
    local selName = sel and Vm.Get(sel, "Name")
    local items = Vm.List(row, "ComboItems")
    local pos = nil
    for i, item in ipairs(items) do
        if selName ~= nil and Vm.Get(item, "Name") == selName then pos = i end
    end
    return Loca.Text(selName), pos, #items
end

-- Snapshot of one row as plain Lua data (safe to keep), or nil when it is gone:
-- { label, description, kind, enabled, value, checked, position, count, min, max, bindings }
-- (bindings: Game/Input binding list, KeyBinding rows only)
function Options.Row(widgetName, index)
    local _, list = rows(widgetName)
    local row = list[index]
    if row == nil then return nil end
    local s = {
        label = Vm.Text(row, "Text"),
        description = Vm.Text(row, "Description"),
        kind = Vm.Enum(row, "ListItemType") or "?",
        enabled = Vm.Get(row, "Enabled") ~= false,
    }
    if s.kind == "ComboBox" then
        s.value, s.position, s.count = comboState(row)
    elseif s.kind == "TickBox" then
        s.checked = Vm.Get(row, "Value") == true
    elseif s.kind == "Slider" then
        s.value = Vm.Get(row, "Value")
        s.min, s.max = Vm.Get(row, "Min"), Vm.Get(row, "Max")
    elseif s.kind == "EditBox" then
        if Vm.Get(row, "HideValue") ~= true then s.value = Vm.Get(row, "Value") end
    elseif s.kind == "KeyBinding" then
        local eventId = Input.EventForLabel(Vm.Get(row, "Text"))
        s.bindings = eventId and Input.Bindings(eventId) or {}
    end
    return s
end

local function setValue(dc, row, value)
    local ok = pcall(function() row:SetProperty("Value", value) end)
    return ok and Vm.Run(dc, "ValueChanged", row)
end

-- Slider step: 1 on small ranges, 5% of the range on large ones (fine = always 1).
local function sliderStep(min, max, fine)
    local range = (max or 1) - (min or 0)
    if fine or range <= 20 then return 1 end
    return math.floor(range / 20 + 0.5)
end

-- Changes a row by one step (delta = 1 or -1): next/previous list item, slider step, tick box on
-- (delta > 0) or off. Returns ok.
function Options.Step(widgetName, index, delta, fine)
    local dc, list = rows(widgetName)
    local row = list[index]
    if row == nil or Vm.Get(row, "Enabled") == false then return false end
    local kind = Vm.Enum(row, "ListItemType")
    if kind == "ComboBox" then
        return Vm.Run(dc, delta > 0 and "NextComboItemCommand" or "PrevComboItemCommand", row)
    elseif kind == "TickBox" then
        return setValue(dc, row, delta > 0)
    elseif kind == "Slider" then
        local v, min, max = Vm.Get(row, "Value") or 0, Vm.Get(row, "Min") or 0, Vm.Get(row, "Max") or 0
        local nv = math.max(min, math.min(max, v + delta * sliderStep(min, max, fine)))
        if nv == v then return true end
        return setValue(dc, row, nv)
    end
    return false
end

-- Activates a row: toggles a tick box, runs a list button. Returns ok.
function Options.Press(widgetName, index)
    local dc, list = rows(widgetName)
    local row = list[index]
    if row == nil or Vm.Get(row, "Enabled") == false then return false end
    local kind = Vm.Enum(row, "ListItemType")
    if kind == "TickBox" then
        return setValue(dc, row, Vm.Get(row, "Value") ~= true)
    elseif kind == "Button" then
        return Vm.Run(Vm.Get(row, "ButtonCommand"), "ActionCommand", nil)
    end
    return false
end

-- Restores the tab's defaults (the game may ask for confirmation in a message box).
function Options.Reset(widgetName)
    return Vm.Run(Vm.WidgetDc(widgetName), "ResetOptionsToDefaultCommand", nil)
end

return Options
