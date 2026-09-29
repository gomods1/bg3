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

-- Feats ------------------------------------------------------------------------------------
-- The feat list as Choices shows it: an unavailable feat says why (the game's unmet
-- requirements, or already taken).
local featSource = {
    list = function()
        local out = {}
        for i, c in ipairs(Game.Feat.list()) do
            c.reason = c.taken and L("feat_taken") or (#c.unmet > 0 and Strings.List(c.unmet)) or nil
            out[i] = c
        end
        return out
    end,
    current = function() return Game.Feat.current() end,
    select = function(i)
        local c = Game.Feat.list()[i]
        return c ~= nil and c.available and Game.Feat.select(i)
    end,
}

local function abilityLine(i)
    local a = Game.FeatAbilities()
    local row = a and a.list[i]
    if not row then return L("option_gone") end
    return Strings.List({
        L("level_up_feat_ability", { name = row.name, value = math.floor((row.value or 0) + 0.5) }),
        (row.improvement or 0) > 0 and L("level_up_feat_plus", { n = row.improvement }),
    })
end

local function pointsLine()
    local a = Game.FeatAbilities()
    if not a then return nil end
    return L(a.chosen >= a.max and "spell_choice_done" or "spell_choice", { title = L("level_up_feat_points"), chosen = a.chosen, max = a.max })
end

local function buildFeatAbilities()
    local out = {}
    local a = Game.FeatAbilities()
    for i = 1, a and #a.list or 0 do
        out[#out + 1] = Controls.Item({
            kind = "option",
            describe = function() return abilityLine(i) end,
            change = function(delta)
                if not Game.ChangeFeatAbility(i, delta) then
                    Speech.Say(L("cannot_change"), { interrupt = true })
                    return
                end
                Controls.SayLater(function() return Strings.Sentences({ abilityLine(i), pointsLine() }) end)
            end,
        })
    end
    return out
end

local function skillLine(i)
    local g = Game.FeatSkills()
    local sk = g and g.list[i]
    if not sk then return L("option_gone") end
    -- Selected and disabled: a skill the character already has (Tav's Athletics, verified
    -- 2026-09-26 with Skilled, whose three picks the game preselects).
    local had = sk.proficient or (sk.selected and not sk.enabled)
    local state = had and L("cc_proficient") or (sk.selected and L("selected")) or L("not_selected")
    return Strings.List({ L("cc_skill", { name = sk.name, ability = sk.ability or "?", state = state }), not sk.enabled and not had and L("unavailable") })
end

local function skillsLine()
    local g = Game.FeatSkills()
    if not g then return nil end
    return L(g.chosen >= g.max and "spell_choice_done" or "spell_choice", { title = L("level_up_feat_skills"), chosen = g.chosen, max = g.max })
end

local function buildFeatSkills()
    local out = {}
    local g = Game.FeatSkills()
    for i, sk in ipairs(g and g.list or {}) do
        if sk.enabled or sk.selected then
            out[#out + 1] = Controls.Item({
                kind = "option",
                describe = function() return skillLine(i) end,
                activate = function()
                    if not Game.ToggleFeatSkill(i) then
                        Speech.Say(L("cannot_change"), { interrupt = true })
                        return
                    end
                    Controls.SayLater(function() return Strings.Sentences({ skillLine(i), skillsLine() }) end)
                end,
            })
        end
    end
    return out
end

-- The feat section and, once a feat is chosen, what it asks for: ability points, skills,
-- passives, spells.
local function featControls(self)
    local out = {}
    if #Game.Feat.list() == 0 then return out end
    local section = Choices.Section(self, L("level_up_feat"), featSource)
    local open = section.Activate
    section.Activate = function(...)
        Game.ShowFeatTab() -- the game's own feat panel, as a player opens it
        return open(...)
    end
    out[#out + 1] = section
    if Game.FeatAbilities() then
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = pointsLine,
            activate = function() self:Push(L("level_up_feat_points"), buildFeatAbilities) end,
        })
    end
    if Game.FeatSkills() then
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = skillsLine,
            activate = function() self:Push(L("level_up_feat_skills"), buildFeatSkills) end,
        })
    end
    for i = 1, #PassiveChoices.Read(Game.FeatPassives) do
        out[#out + 1] = PassiveChoiceList.Control(self, Game.FeatPassives, i)
    end
    for i = 1, #SpellChoices.Read(Game.FeatSpells) do
        out[#out + 1] = SpellChoiceList.Control(self, Game.FeatSpells, i)
    end
    return out
end
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
    for _, c in ipairs(featControls(self)) do out[#out + 1] = c end
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
    if #Game.Feat.list() > 0 then lines[#lines + 1] = L("help_level_up_feat") end
    return lines
end

return LevelUp
