-- Character creation (widget CharacterCreation, gui::DCCharacterCreation). Everything is driven
-- through the view model, independent of the step the game shows (verified 2026-09-24):
--  * Choices: the DC's Selectable* collections; the UI's ListBoxes bind SelectedItem two-way to the
--    DC's Selected* properties (CCLib_k.xaml), and SetProperty("SelectedRace", item) does the same
--    (the character model, subrace list and summary update).
--  * Abilities: DummyCharacter.Stats.Abilities (ls.VMAbility: Ability enum, Value, BaseValue,
--    Modifier, CanIncrease, CanDecrease); DC IncreaseAbility/DecreaseAbility(ability);
--    UnusedAbilityPoints / TotalAbilityPoints.
--  * Racial bonuses: RaceProgressionDetails.AbilityBonusSelection (ls.VMAbilityBonusSelection:
--    AbilityBonus, BonusAbilities, SelectedIndex 0-based); DC SelectNext/PrevAbilityBonus(selection)
--    (the controller UI's commands; the mouse UI's SelectAbilityBonus takes a multi-binding pair).
--  * Skills: AllSkills.{Class,Race}ProficientSkills / ExpertiseSkills (gui::VMCharacterCreationSkills:
--    MaxSelectedSkillCount, SelectedSkillCount, Skills of ls.VMCharacterCreationSkill: Skill and
--    Ability enums, Selected, IsProficient, Enabled, SkillSourceLabel); DC ToggleSkill(skill).
--  * FinishCreating (enabled by IsCharacterComplete), RandomCharacter.
-- CharacterCreationStep is read-only; SetCharacterCreationStep takes a string (not passable).
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")
local Selectable = Ext.Require("Game/Selectable.lua")
local Loca = Ext.Require("Game/Loca.lua")

local CC = {}

CC.Widget = "CharacterCreation"

local function dc() return Vm.WidgetDc(CC.Widget) end

-- The game's own labels for the parts of character creation (Public/Game/GUI/Library/CCLib_k.xaml).
CC.Labels = {
    origin = "hd0d4922ag7581g43eag9142g44e22c131fa8",
    race = "hadf27237ge191g4922ga84cg055b984c9b1f",
    subrace = "hf4977710g272bg4334g84aegf749a3b18205",
    class = "h4d0d00cfg4edeg42c3gaa4agcc3908351b8d",
    subclass = "h1e67bc9cg0f53g4218g8ce8geb6a6636f141",
    deity = "h5238a9c6gb90fg40bbg9335gfb37d6e91b94",
    background = "hebf1e383g9a70g42d6gb3e2g3906281a90b8",
    abilities = "h6406727cg0668g4fdag9ca1g72c679c0aeab",
    ClassProficientSkills = "h5cab4ab6g7b46g46cegb82fg3ea721099318",
    RaceProficientSkills = "h12abe296ga0fbg44feg9451gb10a0bf92acb",
    ExpertiseSkills = "h601ff4c6g67b8g4f32gaaf7g8b29d6daa426",
    summary = "h7d444943g0ae5g4beagbfcag7e07b4e7f154",
    finish = "h06b74424gf3bdg4b6cgbe63g84b32198e162",
    random = "h6b184ec1gc364g4467g9617g3ab1a3959d10", -- "random values" (CharacterCreation.xaml)
    randomDescription = "h039ed18bge1e8g4aaeg9c14g7d6c5a78d84a",
}

-- Choice kinds in creation order: DC collection and selected-item property.
CC.ChoiceKinds = { "origin", "race", "subrace", "class", "subclass", "background", "deity" }
local CHOICES = {
    origin = { list = "SelectableOrigins", selected = "SelectedOrigin" },
    race = { list = "SelectableRaces", selected = "SelectedRace" },
    subrace = { list = "SelectableSubRaces", selected = "SelectedSubRace" },
    class = { list = "SelectableClasses", selected = "SelectedClass" },
    subclass = { list = "SelectableSubClasses", selected = "SelectedSubClass" },
    background = { list = "SelectableBackgrounds", selected = "SelectedBackground" },
    deity = { list = "SelectableDeities", selected = "SelectedDeity" },
}

-- { { label, description, selected, available, reason }, ... } (empty when the kind has no choices,
-- e.g. no subclasses at level 1 for most classes, no deities unless the class needs one).
function CC.Choices(kind)
    return Selectable.List(dc(), CHOICES[kind])
end

-- The selected choice's snapshot, or nil.
function CC.Current(kind)
    return Selectable.Current(dc(), CHOICES[kind])
end

-- Selects choice i of kind. Returns ok.
function CC.Select(kind, i)
    return Selectable.Select(dc(), CHOICES[kind], i)
end

-- Spell and cantrip choices (Game/SpellChoices): the class's selectors, then the race's (the high
-- elf's cantrip). Same view models and panel template as the level up (CCLib_k.xaml); not yet run
-- in character creation.
CC.Spells = {
    widget = CC.Widget,
    selectors = function()
        local d = dc()
        local out = {}
        for _, details in ipairs({ "ClassProgressionDetails", "RaceProgressionDetails" }) do
            for _, s in ipairs(Vm.List(Vm.Get(d, details), "SpellSelectors")) do out[#out + 1] = s end
        end
        return out
    end,
}

-- What the selected origin locks (premade origins fix race, class, body, appearance).
function CC.Locks()
    local o = Vm.Get(dc(), "SelectedOrigin")
    return {
        race = Vm.Get(o, "IsLockedRace") == true,
        class = Vm.Get(o, "IsLockedClass") == true,
        body = Vm.Get(o, "IsLockedBody") == true,
        appearance = Vm.Get(o, "IsLockedAppearance") == true,
    }
end

local function abilities(d)
    return Vm.List(Vm.Get(Vm.Get(d, "DummyCharacter"), "Stats"), "Abilities")
end

-- { points = { unused, total }, list = { { id, name, value, base, modifier, canIncrease, canDecrease } } }
function CC.Abilities()
    local d = dc()
    local out = { points = { unused = Vm.Get(d, "UnusedAbilityPoints"), total = Vm.Get(d, "TotalAbilityPoints") }, list = {} }
    for i, a in ipairs(abilities(d)) do
        local id = Vm.Enum(a, "Ability")
        out.list[i] = {
            id = id,
            name = Loca.Enum("AbilityDisplayName", id) or id,
            value = Vm.Get(a, "Value"),
            base = Vm.Get(a, "BaseValue"),
            modifier = Vm.Get(a, "Modifier"),
            canIncrease = Vm.Get(a, "CanIncrease") == true,
            canDecrease = Vm.Get(a, "CanDecrease") == true,
        }
    end
    return out
end

-- Point-buy step on ability i (delta 1 or -1). Returns ok.
function CC.ChangeAbility(i, delta)
    local d = dc()
    local a = abilities(d)[i]
    if not a then return false end
    return Vm.Run(d, delta > 0 and "IncreaseAbility" or "DecreaseAbility", a)
end

local function bonusSelections(d)
    return Vm.List(Vm.Get(d, "RaceProgressionDetails"), "AbilityBonusSelection")
end

-- Racial bonuses: { { bonus = 2, ability = display name, id = enum }, ... }
function CC.Bonuses()
    local out = {}
    for i, s in ipairs(bonusSelections(dc())) do
        local list = Vm.List(s, "BonusAbilities")
        local cur = list[(Vm.Get(s, "SelectedIndex") or 0) + 1]
        local id = cur and Vm.Enum(cur, "Ability")
        out[i] = { bonus = Vm.Get(s, "AbilityBonus"), id = id, ability = id and (Loca.Enum("AbilityDisplayName", id) or id) }
    end
    return out
end

-- Moves racial bonus i to the next/previous ability. Returns ok.
function CC.CycleBonus(i, delta)
    local d = dc()
    local s = bonusSelections(d)[i]
    if not s then return false end
    return Vm.Run(d, delta > 0 and "SelectNextAbilityBonus" or "SelectPrevAbilityBonus", s)
end

-- Skill groups the player chooses from: class, race (e.g. half-elf), expertise (e.g. rogue).
CC.SkillGroups = { "ClassProficientSkills", "RaceProficientSkills", "ExpertiseSkills" }

local function skillGroup(d, group)
    return Vm.Get(Vm.Get(d, "AllSkills"), group)
end

-- { max, chosen, list = { { id, name, ability, selected, proficient, enabled, source } } } or nil
-- when the group offers no choice.
function CC.Skills(group)
    local g = skillGroup(dc(), group)
    local max = Vm.Get(g, "MaxSelectedSkillCount") or 0
    if max <= 0 then return nil end
    local out = { max = max, chosen = Vm.Get(g, "SelectedSkillCount") or 0, list = {} }
    for i, s in ipairs(Vm.List(g, "Skills")) do
        local id, ability = Vm.Enum(s, "Skill"), Vm.Enum(s, "Ability")
        out.list[i] = {
            id = id,
            name = Loca.Enum("SkillDisplayName", id) or id,
            ability = ability and (Loca.Enum("AbilityDisplayName", ability) or ability),
            selected = Vm.Get(s, "Selected") == true,
            proficient = Vm.Get(s, "IsProficient") == true,
            enabled = Vm.Get(s, "Enabled") == true,
        }
    end
    return out
end

-- Toggles skill i of a group. Returns ok.
function CC.ToggleSkill(group, i)
    local d = dc()
    local s = Vm.List(skillGroup(d, group), "Skills")[i]
    if not s then return false end
    return Vm.Run(d, "ToggleSkill", s)
end

function CC.IsComplete()
    return Vm.Get(dc(), "IsCharacterComplete") == true
end

-- Rolls a random character (the game's "random values" button). Returns ok.
function CC.Randomize()
    return Vm.Run(dc(), "RandomCharacter", nil)
end

-- The character's name (custom characters: CanEditName). The name box (characterName, an
-- LSTextBox bound two-way to the DC's CharacterName) takes a Lua string through
-- SetProperty("Text", ...) even while its page is hidden (verified 2026-09-24: "Elara" shown on
-- the Naming page afterwards); neither the box nor the DC reads back (CharacterName reads
-- "ResStr_..."), so the name typed here is remembered for speech.
local typedName = nil
CC.NAME_MAX = 20 -- the box's MaxLength

function CC.CanEditName()
    return Vm.Get(dc(), "CanEditName") == true
end

-- The name set through the mod in this creation, or nil (the game's default).
function CC.TypedName()
    return typedName
end

function CC.SetName(name)
    local box = Ui.FindAllByName(Ui.FindWidget(CC.Widget), "characterName")[1]
    if not box then return false end
    local ok = pcall(function() box:SetProperty("Text", name) end)
    if ok then typedName = name end
    return ok
end

-- Ends character creation ("Venture forth"). Returns ok.
function CC.Finish()
    return Vm.Run(dc(), "FinishCreating", nil)
end

return CC
