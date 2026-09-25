-- Options menu (Game/Options): one widget per tab. The tab's rows, then Back and Reset.
-- Tab/Shift+Tab switch tabs with a verified click on the tab button (tab buttons send a CustomEvent
-- with a string parameter, which Lua cannot pass). Back is the game's own Escape.
local Game = Ext.Require("Game/Options.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Options = ListScreen.Extend()
Options.Widgets = Game.TabWidgets

function Options.New(widget)
    local tab = Game.Tab(widget.name)
    return setmetatable(ListScreen.New(widget.name, L("screen_options_tab", { tab = Game.TabLabel(tab) })), Options)
end

function Options:Build()
    local widget = self.widget
    local controls = {}
    for i = 1, Game.Count(widget) do controls[#controls + 1] = Controls.OptionRow(widget, i) end
    controls[#controls + 1] = Controls.Button({
        label = Loca.Text(Game.BackLabel) or "Back",
        activate = function(done)
            Activate.Key("ESCAPE")
            done(true)
        end,
    })
    controls[#controls + 1] = Controls.Button({
        label = Loca.Text(Game.ResetLabel) or "Reset",
        activate = function(done) done(Game.Reset(widget), "reason_unavailable") end,
    })
    return controls
end

-- Tabs whose button is shown on this widget, in on-screen order.
local function visibleTabs(widget)
    local out = {}
    for _, t in ipairs(Game.Tabs) do
        local el = Ui.FindElement(widget, t.button)
        if el and Ui.IsShown(el) then out[#out + 1] = t end
    end
    return out
end

function Options:SwitchTab(delta)
    local tabs = visibleTabs(self.widget)
    local at = nil
    for i, t in ipairs(tabs) do
        if t.widget == self.widget then at = i end
    end
    if not at or #tabs < 2 then return end
    local target = tabs[(at - 1 + delta) % #tabs + 1]
    Activate.Click(self.widget, target.button, function(ok, reasonKey)
        if not ok then
            Speech.Say(L("could_not_activate", { label = Game.TabLabel(target), reason = L(reasonKey) }), { interrupt = true })
        end
    end)
end

function Options:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_tabs")
    return lines
end

function Options:OnKey(combo)
    if combo == "TAB" then self:SwitchTab(1) return true end
    if combo == "SHIFT+TAB" then self:SwitchTab(-1) return true end
    return ListScreen.OnKey(self, combo)
end

return Options
