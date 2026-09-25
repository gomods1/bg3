-- Generic handler for screens with no dedicated handler: a list built from the XAML index (static
-- texts and buttons in document order), filtered by what exists and is shown in the live tree, plus
-- the widget's option rows if its data context has any. A screen with no handler is clumsy, never
-- dead (template_rpg 10.4).
local Ui = Ext.Require("Game/Ui.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Options = Ext.Require("Game/Options.lua")
local Activate = Ext.Require("Game/Activate.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Strings = Ext.Require("Core/Strings.lua")

local Generic = ListScreen.Extend()

local function isButton(item)
    return item.command ~= nil or (item.type or ""):find("Button") ~= nil
end

-- availability(elName) -> true/false/nil: screen-specific knowledge of bound IsEnabled values
-- (they read as nil); nil falls back to the element's command CanExecute.
local function buttonControl(widgetName, item, label, availability)
    local function available()
        local known = availability and availability(item.name)
        if known ~= nil then return known end
        return Activate.Available(widgetName, item.name, item)
    end
    return Controls.Button({
        label = label,
        available = available,
        activate = function(done)
            if not available() then
                done(false, "reason_unavailable")
                return
            end
            Activate.Element(widgetName, item.name, item, done)
        end,
    })
end

-- XAML index items that are present: named elements must exist and be shown; unnamed static texts
-- are kept (they cannot be checked). Duplicates (same text, command and parameter) are dropped.
local function pageControls(widgetName, page, buttonsOnly, availability)
    local out = {}
    local root = Ui.FindWidget(widgetName)
    if not root then return out end
    local seen = {}
    for _, item in ipairs(page.items) do
        local text = Loca.Text(item.label)
        local button = isButton(item)
        local key = (text or "") .. "|" .. (item.command or "") .. "|" .. (item.param or "")
        if text and item.label ~= page.title and not seen[key] and (button or not buttonsOnly) then
            local el = item.name and Ui.FindByName(root, item.name) or nil
            if (item.name == nil and not button) or (el and Ui.IsShown(el)) then
                seen[key] = true
                out[#out + 1] = button and buttonControl(widgetName, item, text, availability) or Controls.Text(text)
            end
        end
    end
    return out
end

-- opts: { title = string, buttonsOnly = bool, availability = function(elName) -> bool|nil }
-- (buttonsOnly drops static texts, for screens whose hidden panels carry labels that cannot be
-- visibility-checked, e.g. the main menu).
function Generic.New(widget, page, opts)
    opts = opts or {}
    -- A page without a title of its own takes the mod's name for its widget ("screen_widget_GameMenu"),
    -- else the widget's internal name.
    local titleKey = "screen_widget_" .. tostring(widget.name)
    local title = opts.title or (page and Loca.Text(page.title))
        or (Strings.Has(titleKey) and Strings.Get(titleKey)) or widget.name
    local self = setmetatable(ListScreen.New(widget.name, title), Generic)
    self.page = page
    self.buttonsOnly = opts.buttonsOnly
    self.availability = opts.availability
    return self
end

function Generic:Build()
    local controls = self.page and pageControls(self.widget, self.page, self.buttonsOnly, self.availability) or {}
    -- Option rows go before the first button.
    local at = #controls + 1
    for i, c in ipairs(controls) do
        if c.kind == "button" then at = i break end
    end
    for r = Options.Count(self.widget), 1, -1 do
        table.insert(controls, at, Controls.OptionRow(self.widget, r))
    end
    return controls
end

return Generic
