-- Level up (Game/LevelUp): what the new level brings (hit points, class features with their
-- descriptions on Ctrl+D, new actions), the subclass, passive choices (the Wildheart's animal
-- heart, fighting styles...: a sub-list per selector), spell choices (a sub-list per selector:
-- Enter chooses or takes back a spell, Ctrl+D describes it; the game's spell panel is opened meanwhile, as a sighted
-- player would), what is left to choose that the mod cannot do yet (named so the player knows), and
-- Accept (a verified click on the game's button, enabled only when nothing is left to choose).
-- Escape is the game's (closes without levelling) except inside a sub-list.
local Game = Ext.Require("Game/LevelUp.lua")
local SpellChoices = Ext.Require("Game/SpellChoices.lua")
local SpellChoiceList = Ext.Require("Screens/SpellChoiceList.lua")
local PassiveChoices = Ext.Require("Game/PassiveChoices.lua")
local PassiveChoiceList = Ext.Require("Screens/PassiveChoiceList.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Choices = Ext.Require("Screens/Choices.lua")

local L = Strings.Get

local LevelUp = ListScreen.Extend()
LevelUp.Widgets = { Game.Widget }

function LevelUp.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_level_up")), LevelUp)
end

function LevelUp:Build()
    local r = Game.Read()
    if not r then return {} end
    self.title = L("level_up_title", { name = r.name or "?", from = r.from or 0, to = r.to or 0 })
    self.shownKey = tostring(r.name) .. "|" .. tostring(r.to)
    local out = {}
    if r.hpFrom and r.hpTo then out[#out + 1] = Controls.Text(L("level_up_hp", { from = r.hpFrom, to = r.hpTo })) end
    for _, f in ipairs(r.features) do
        out[#out + 1] = Controls.Item({
            kind = "text",
            describe = function() return L("level_up_feature", { name = f.name or "?" }) end,
            details = function() return f.description end,
        })
    end
    for _, sl in ipairs(r.slots) do
        out[#out + 1] = Controls.Text(L("level_up_slots", { level = sl.level, from = sl.from, to = sl.to }))
    end
    for _, res in ipairs(r.resources) do
        out[#out + 1] = Controls.Item({
            kind = "text",
            describe = function() return res.own and res.name or L("level_up_resource", { name = res.name }) end,
            details = function() return res.description end,
        })
    end
    for _, a in ipairs(r.actions) do
        if a then out[#out + 1] = Controls.Text(L("level_up_action", { name = a })) end
    end
    if #Game.Subclass.list() > 0 then
        out[#out + 1] = Choices.Section(self, Loca.Text(Game.SubclassLabel) or L("level_up_choice_subclass"), Game.Subclass)
    end
    for i = 1, #PassiveChoices.Read(Game.Passives) do
        out[#out + 1] = PassiveChoiceList.Control(self, Game.Passives, i)
    end
    for i = 1, #SpellChoices.Read(Game.Spells) do
        out[#out + 1] = SpellChoiceList.Control(self, Game.Spells, i)
    end
    if #r.pending > 0 then
        local names = {}
        for _, k in ipairs(r.pending) do names[#names + 1] = L("level_up_choice_" .. k) end
        out[#out + 1] = Controls.Text(L("level_up_pending", { choices = Strings.List(names) }))
    end
    out[#out + 1] = Controls.Button({
        label = Loca.Text(Game.AcceptLabel) or "Accept",
        available = function() local now = Game.Read() return now and now.complete end,
        activate = function(done)
            Game.WhenClickable(function(ready)
                if ready then Activate.Click(self.widget, "finishLevelUpButton", done) else done(false, "reason_unavailable") end
            end, function() Speech.Say(L("level_up_waiting"), { interrupt = true }) end)
        end,
    })
    return out
end

-- Leaving a spell list shows the game's overview again (Accept is there).
function LevelUp:Pop()
    local popped = ListScreen.Pop(self)
    if popped and #self.levels == 0 then Game.ShowOverview() end
    return popped
end

-- The next character's level up in the same widget: read it anew.
function LevelUp:Tick()
    ListScreen.Tick(self)
    local r = Game.Read()
    -- (Between two characters the DC is empty for a moment: name nil, levels 0.)
    if r and r.name and self.shownKey and tostring(r.name) .. "|" .. tostring(r.to) ~= self.shownKey then
        self.index = 0
        self.levels = {}
        self:Refresh()
        self:Announce()
    end
end

function LevelUp:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_level_up")
    if #SpellChoices.Read(Game.Spells) > 0 then lines[#lines + 1] = L("help_level_up_spells") end
    return lines
end

return LevelUp
