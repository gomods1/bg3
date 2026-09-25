-- Character creation (Game/CharacterCreation), gameplay part: a list of sections, each opening a
-- sub-list. The mod drives the view model directly, so the game's own step and camera do not
-- matter. Appearance, name and the guardian are not handled here yet.
--   Origin / Race / Subrace / Class / Subclass / Background / Deity: choices, Enter selects.
--   Abilities: point buy with Left/Right, then the racial bonuses (+2, +1) with Left/Right.
--   Skill groups (class, race, expertise): Enter toggles.
--   Spells and cantrips (Screens/SpellChoiceList): the game's spell panel, verified grid clicks.
--   Summary, Random character, Finish ("venture forth").
local CC = Ext.Require("Game/CharacterCreation.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local TextEntry = Ext.Require("Screens/TextEntry.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local Choices = Ext.Require("Screens/Choices.lua")
local SpellChoices = Ext.Require("Game/SpellChoices.lua")
local SpellChoiceList = Ext.Require("Screens/SpellChoiceList.lua")

local L = Strings.Get

local CharacterCreation = ListScreen.Extend()
CharacterCreation.Widgets = { CC.Widget }

local function label(key)
    return Loca.Text(CC.Labels[key]) or key
end

local function signed(n)
    n = math.floor((n or 0) + 0.5)
    return (n >= 0 and "+" or "") .. tostring(n)
end

function CharacterCreation.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_character_creation")), CharacterCreation)
end

-- Choices ------------------------------------------------------------------------------------

local function choiceSource(kind)
    return {
        list = function() return CC.Choices(kind) end,
        current = function() return CC.Current(kind) end,
        select = function(i) return CC.Select(kind, i) end,
    }
end

local function choiceSection(self, kind)
    local locks = CC.Locks()
    local locked = (kind == "race" or kind == "subrace") and locks.race or (kind == "class" or kind == "subclass") and locks.class
    return Choices.Section(self, label(kind), choiceSource(kind), locked and L("cc_locked"))
end

-- Abilities ----------------------------------------------------------------------------------

local function pointsText()
    local a = CC.Abilities()
    return L("cc_points", { n = a.points.unused or 0, total = a.points.total or 0 })
end

local function abilityText(i)
    local a = CC.Abilities().list[i]
    if not a then return L("option_gone") end
    return L("cc_ability", { name = a.name, value = math.floor((a.value or 0) + 0.5), modifier = signed(a.modifier) })
end

local function bonusText(i)
    local b = CC.Bonuses()[i]
    if not b then return L("option_gone") end
    return L("cc_bonus", { bonus = signed(b.bonus), ability = b.ability or "?" })
end

local function buildAbilities()
    local out = {}
    for i = 1, #CC.Abilities().list do
        out[#out + 1] = Controls.Item({
            kind = "option",
            describe = function() return abilityText(i) end,
            change = function(delta)
                if not CC.ChangeAbility(i, delta) then
                    Speech.Say(L("cannot_change"), { interrupt = true })
                    return
                end
                Controls.SayLater(function() return Strings.Sentences({ abilityText(i), pointsText() }) end)
            end,
        })
    end
    for i = 1, #CC.Bonuses() do
        out[#out + 1] = Controls.Item({
            kind = "option",
            describe = function() return bonusText(i) end,
            change = function(delta)
                if not CC.CycleBonus(i, delta) then
                    Speech.Say(L("cannot_change"), { interrupt = true })
                    return
                end
                Controls.SayLater(function() return bonusText(i) end)
            end,
        })
    end
    return out
end

-- Skills -------------------------------------------------------------------------------------

local function skillText(group, i)
    local g = CC.Skills(group)
    local s = g and g.list[i]
    if not s then return L("option_gone") end
    local state
    if s.selected then state = L("selected")
    elseif s.proficient then state = L("cc_proficient")
    else state = L("not_selected") end
    local text = L("cc_skill", { name = s.name, ability = s.ability or "?", state = state })
    return Strings.List({ text, not s.enabled and not s.selected and L("unavailable") })
end

local function chosenText(group)
    local g = CC.Skills(group)
    return g and L("cc_chosen", { n = g.chosen, max = g.max }) or ""
end

-- Only skills the player can act on or already has: the other skills of the 18 are noise here.
local function buildSkills(group)
    return function()
        local g = CC.Skills(group)
        local out = {}
        for i, s in ipairs(g and g.list or {}) do
            if s.enabled or s.selected or s.proficient then
            out[#out + 1] = Controls.Item({
                kind = "option",
                describe = function() return skillText(group, i) end,
                activate = function()
                    if not CC.ToggleSkill(group, i) then
                        Speech.Say(L("cannot_change"), { interrupt = true })
                        return
                    end
                    Controls.SayLater(function() return Strings.Sentences({ skillText(group, i), chosenText(group) }) end)
                end,
            })
            end
        end
        return out
    end
end

-- Summary ------------------------------------------------------------------------------------

local function summaryText()
    local parts = {}
    for _, kind in ipairs(CC.ChoiceKinds) do
        local cur = CC.Current(kind)
        if cur and #CC.Choices(kind) > 0 then parts[#parts + 1] = L("cc_section", { section = label(kind), value = cur.label }) end
    end
    local abilities = {}
    for i = 1, #CC.Abilities().list do abilities[#abilities + 1] = abilityText(i) end
    parts[#parts + 1] = Strings.List(abilities)
    parts[#parts + 1] = pointsText()
    for _, group in ipairs(CC.SkillGroups) do
        local g = CC.Skills(group)
        if g then
            local chosen = {}
            for _, s in ipairs(g.list) do
                if s.selected then chosen[#chosen + 1] = s.name end
            end
            parts[#parts + 1] = L("cc_section", { section = label(group), value = #chosen > 0 and Strings.List(chosen) or L("none") })
        end
    end
    return Strings.Sentences(parts)
end

-- Root list ----------------------------------------------------------------------------------

function CharacterCreation:Build()
    local out = {}
    for _, kind in ipairs(CC.ChoiceKinds) do
        if #CC.Choices(kind) > 0 then out[#out + 1] = choiceSection(self, kind) end
    end
    out[#out + 1] = Controls.Item({
        kind = "button",
        describe = function() return L("cc_section", { section = label("abilities"), value = pointsText() }) end,
        activate = function() self:Push(label("abilities"), buildAbilities) end,
    })
    for _, group in ipairs(CC.SkillGroups) do
        if CC.Skills(group) then
            out[#out + 1] = Controls.Item({
                kind = "button",
                describe = function() return L("cc_section", { section = label(group), value = chosenText(group) }) end,
                activate = function() self:Push(label(group), buildSkills(group)) end,
            })
        end
    end
    for i = 1, #SpellChoices.Read(CC.Spells) do
        out[#out + 1] = SpellChoiceList.Control(self, CC.Spells, i)
    end
    if CC.CanEditName() then
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return L("cc_section", { section = L("cc_name"), value = CC.TypedName() or L("cc_name_default") }) end,
            activate = function()
                self:BeginEntry(TextEntry.New({
                    label = L("cc_name"),
                    text = CC.TypedName() or "",
                    maxLength = CC.NAME_MAX,
                    onDone = function(text)
                        if not text then return end
                        if text == "" or not CC.SetName(text) then
                            Speech.Say(L("could_not_activate", { label = L("cc_name"), reason = L("reason_unavailable") }), { interrupt = true })
                            return
                        end
                        Speech.Say(L("cc_section", { section = L("cc_name"), value = text }), { interrupt = true })
                    end,
                }))
            end,
        })
    end
    out[#out + 1] = Controls.Item({
        kind = "button",
        describe = function() return Strings.List({ label("summary"), L("role_button") }) end,
        activate = function() Speech.Say(summaryText(), { interrupt = true }) end,
        details = summaryText,
    })
    out[#out + 1] = Controls.Button({
        label = label("random"),
        activate = function(done)
            local ok = CC.Randomize()
            done(ok, "reason_unavailable")
            if ok then Controls.SayLater(summaryText) end
        end,
    })
    out[#out + 1] = Controls.Button({
        label = label("finish"),
        available = CC.IsComplete,
        activate = function(done)
            if not CC.IsComplete() then
                done(false, "reason_unavailable")
                return
            end
            done(CC.Finish(), "reason_unavailable")
        end,
    })
    return out
end

function CharacterCreation:Help()
    local lines = ListScreen.Help(self)
    if #self.levels == 0 then lines[#lines + 1] = L("help_cc") end
    return lines
end

return CharacterCreation
