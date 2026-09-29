-- Level up (widget CharacterLevelUp, gui::DCCharacterLevelUp). Opened with any DC's
-- StartLevelUp(character VM) (the HotBar's level-up button does that). Facts (verified
-- 2026-09-24, Tav barbarian 1 -> 2 on the beach):
--   CurrentCharacterLevel 1, AvailableCharacterLevel 2, LevelUpStep (Started -> IntroComplete),
--   IsLevelUpComplete (true when nothing is left to choose), LevelUpCharacter / DummyCharacter
--   (the character before / after: Stats.Health.Max 14 -> 23),
--   ClassProgressionDetails.Progressions[] (NameCTS, Description: context strings; Level):
--   "Sentir el peligro", "Ataque temerario"; ProgressionActions[].Spell.Name (new actions);
--   choice lists like character creation: SelectableSubClasses, SelectableFeats, PassiveFeatures,
--   ClassProgressionDetails.SpellSelectors / AbilitySelection, AllSkills, SelectableMultiClasses.
--   Finishing: the Accept button (x:Name finishLevelUpButton, IsEnabled = IsLevelUpComplete) runs
--   FinishLevelUp("Overview"): a string parameter, so the button is clicked.
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Selectable = Ext.Require("Game/Selectable.lua")
local PassiveChoices = Ext.Require("Game/PassiveChoices.lua")
local Player = Ext.Require("Game/Player.lua")
local Input = Ext.Require("Game/Input.lua")
local Timer = Ext.Require("Core/Timer.lua")

local LevelUp = {}

-- Display name of an action resource by its name ("ChannelDivinity" -> "Canalizar divinidad"),
-- from the static data (Ext.StaticData "ActionResource": Name, DisplayName; verified).
local resourceNames = nil
local function resourceName(id)
    if not resourceNames then
        resourceNames = {}
        local ok, all = pcall(Ext.StaticData.GetAll, "ActionResource")
        for _, g in ipairs(ok and all or {}) do
            pcall(function()
                local r = Ext.StaticData.Get(g, "ActionResource")
                resourceNames[tostring(r.Name)] = Ext.Loca.GetTranslatedString(r.DisplayName.Handle.Handle)
            end)
        end
    end
    local n = resourceNames[id]
    return (n and n ~= "") and n or id
end

LevelUp.Widget = "CharacterLevelUp"
LevelUp.AcceptLabel = "ha7867654g6f71g41ccgbd0bgba956a682293"

local function dc() return Vm.WidgetDc(LevelUp.Widget) end

local function maxHp(character)
    return Vm.Get(Vm.Get(Vm.Get(character, "Stats"), "Health"), "Max")
end

-- Choice lists that need the player (not handled by the mod yet): { names of what is pending }.
-- (PassiveFeatures is not one: it lists the passives gained, e.g. the chosen Wildheart heart.)
local PENDING = {}

-- After one character's level up the game opens the next one's in the same widget (verified:
-- Tav, then Shadowheart): watch name and step.
-- { name, step, from, to, hpFrom, hpTo, features = { { name, description } }, actions = { name },
--   complete, pending = { keys }, resources = { { name, description?, own } } (own: the game's
--   own line for it, "Espacios de conjuro de nivel 2 desbloqueados"; else a resource name),
--   slots = { { level, from,
--   to } } } or nil.
function LevelUp.Read()
    local d = dc()
    if not d then return nil end
    local out = {
        from = Vm.Get(d, "CurrentCharacterLevel"),
        to = Vm.Get(d, "AvailableCharacterLevel"),
        hpFrom = maxHp(Vm.Get(d, "LevelUpCharacter")),
        hpTo = maxHp(Vm.Get(d, "DummyCharacter")),
        complete = Vm.Get(d, "IsLevelUpComplete") == true,
        name = Vm.Text(Vm.Get(d, "LevelUpCharacter"), "Name"),
        step = Vm.Enum(d, "LevelUpStep"),
        features = {}, actions = {}, pending = {}, resources = {}, slots = {},
    }
    -- Progressions: the class's own entry (named: "Sentir el peligro"; for Shadowheart "Clérigo")
    -- and unnamed sub-entries whose actions are in ProgressionActions (verified). Each has
    -- Features.Boosts[] (TypeId SpellSlot, ChannelDivinity...: new resources) too.
    local after = Vm.Get(d, "DummyCharacter")
    for _, p in ipairs(Vm.List(Vm.Get(d, "ClassProgressionDetails"), "Progressions")) do
        local name = Vm.ContextText(Vm.Get(p, "NameCTS"))
        if name then
            out.features[#out.features + 1] = { name = name, description = Vm.ContextText(Vm.Get(p, "Description")) }
        end
        -- A boost's own NameCTS / Description say what it brings ("Espacios de conjuro de nivel
        -- 2 desbloqueados": Shadowheart 2 -> 3; the after-character's SpellSlots read empty then).
        for _, b in ipairs(Vm.List(Vm.Get(p, "Features"), "Boosts")) do
            local id = tostring(Vm.Get(b, "TypeId") or "")
            local own = Vm.ContextText(Vm.Get(b, "NameCTS"))
            if own then
                out.resources[#out.resources + 1] = { name = own, description = Vm.ContextText(Vm.Get(b, "Description")), own = true }
            elseif id ~= "" and id ~= "None" then
                out.resources[#out.resources + 1] = { name = resourceName(id) }
            end
        end
    end
    -- Spell slots before and after: { level, from, to } where they change.
    local function slots(c)
        local t = {}
        for _, sl in ipairs(Vm.List(Vm.Get(c, "Stats"), "SpellSlots")) do t[Vm.Get(sl, "Level") or 0] = Vm.Get(sl, "MaxValue") or 0 end
        return t
    end
    -- Passives gained by a choice made here (the Wildheart's "Corazón de oso", with its
    -- description; verified 2026-09-24): NameCTS / Description like the progressions.
    for _, p in ipairs(Vm.List(d, "PassiveFeatures")) do
        local name = Vm.ContextText(Vm.Get(p, "NameCTS"))
        if name then
            out.features[#out.features + 1] = { name = name, description = Vm.ContextText(Vm.Get(p, "Description")) }
        end
    end
    local before, now = slots(Vm.Get(d, "LevelUpCharacter")), slots(after)
    for level, max in pairs(now) do
        if max ~= (before[level] or 0) then out.slots[#out.slots + 1] = { level = level, from = before[level] or 0, to = max } end
    end
    table.sort(out.slots, function(a, b) return a.level < b.level end)
    for _, a in ipairs(Vm.List(d, "ProgressionActions")) do
        out.actions[#out.actions + 1] = Vm.Text(Vm.Get(a, "Spell"), "Name")
    end
    for _, p in ipairs(PENDING) do
        if #Vm.List(d, p.list) > 0 then out.pending[#out.pending + 1] = p.key end
    end
    return out
end

-- Spell choices of this level up, for Game/SpellChoices: the class's selectors (subclass ones
-- included: Gale's wizard spells at level 2 are IsSubProgression), then the race's.
LevelUp.Spells = {
    widget = LevelUp.Widget,
    ready = function(onReady, onWait) LevelUp.WhenClickable(onReady, onWait) end,
    selectors = function()
        local d = dc()
        local out = {}
        for _, details in ipairs({ "ClassProgressionDetails", "RaceProgressionDetails" }) do
            for _, s in ipairs(Vm.List(Vm.Get(d, details), "SpellSelectors")) do out[#out + 1] = s end
        end
        return out
    end,
}

-- Passive choices of this level up (the Wildheart's animal heart...), for Game/PassiveChoices.
LevelUp.Passives = {
    dc = dc,
    selectors = function() return PassiveChoices.SelectorsOf(dc(), { "ClassProgressionDetails", "RaceProgressionDetails" }) end,
}

-- Subclass (e.g. the wizard's school at level 2): Game/Selectable choices. Gale comes with
-- Evocation selected; the player may pick another school (verified: 9 schools listed).
local SUBCLASS = { list = "SelectableSubClasses", selected = "SelectedSubClass" }
LevelUp.SubclassLabel = "h1e67bc9cg0f53g4218g8ce8geb6a6636f141" -- "Subclase" (CCLib_k.xaml)
LevelUp.Subclass = {
    list = function() return Selectable.List(dc(), SUBCLASS) end,
    current = function() return Selectable.Current(dc(), SUBCLASS) end,
    select = function(i) return Selectable.Select(dc(), SUBCLASS, i) end,
}

-- Feats (levels 4, 8, 12). From the XAML (CCLib_k.xaml featsList, not yet seen live): the DC's
-- SelectableFeats (ls.VMSelectableFeat: Name, Description, IsRequirementsMet, IsAlreadyTaken,
-- Requirements[] { Requirement, IsMet }) and SelectedFeat, two-way bound to the list: set on
-- the DC like the subclass. The chosen feat's panel reads SelectedFeatDetails: HasFeat,
-- FeatDetails { AbilitySelection[], SelectedAbilityCount, MaxSelectedAbilityCount,
-- SpellSelectors[] }, FeatSkills { Skills[], SelectedSkillCount, MaxSelectedSkillCount },
-- FeatPassives[] (passive selectors). Its buttons: the DC's SelectAbility / DeselectAbility
-- (ability row), ToggleSkill (skill row), TogglePassive (passive), as in character creation.
local FEAT = { list = "SelectableFeats", selected = "SelectedFeat" }
LevelUp.FeatLabel = "hb7180a49g729ag4ec3g9f87gaeadb7d4252c" -- "Seleccionar una dote" (CCLib_k.xaml)
LevelUp.FeatAbilitiesLabel = "h72161eb0g8981g45cfgba63ga76e152e1fe9" -- "Puntos de característica asignados:"
LevelUp.FeatSkillsLabel = "h0bddbaf0g8c93g4ddfgbb52ge3c54b72c3c6" -- "Seleccionar habilidades de la dote"

local function featSnapshot(vm, selectedKey)
    local unmet = {}
    for _, r in ipairs(Vm.List(vm, "Requirements")) do
        if Vm.Get(r, "IsMet") == false then unmet[#unmet + 1] = Vm.Text(r, "Requirement") end
    end
    local taken = Vm.Get(vm, "IsAlreadyTaken") == true
    return {
        label = Vm.Text(vm, "Name") or "?",
        description = Vm.Text(vm, "Description"),
        selected = selectedKey ~= nil and Selectable.Key(vm) == selectedKey,
        available = Vm.Get(vm, "IsRequirementsMet") ~= false and not taken,
        taken = taken,
        unmet = unmet,
    }
end

LevelUp.Feat = {
    list = function()
        local d = dc()
        local sel = Vm.Get(d, FEAT.selected)
        local key = sel and Selectable.Key(sel) or nil
        local out = {}
        for i, vm in ipairs(Vm.List(d, FEAT.list)) do out[i] = featSnapshot(vm, key) end
        return out
    end,
    current = function()
        local sel = Vm.Get(dc(), FEAT.selected)
        return sel and featSnapshot(sel, Selectable.Key(sel)) or nil
    end,
    select = function(i)
        local d = dc()
        local item = Vm.List(d, FEAT.list)[i]
        if not item then return false end
        return pcall(function() d:SetProperty(FEAT.selected, item) end)
    end,
}

local function featDetails() return Vm.Get(dc(), "SelectedFeatDetails") end

-- The chosen feat's ability points (Athlete: +1 to Strength or Dexterity; Ability Improvement:
-- 2 points): { chosen, max, list = { { id, name, value, improvement } } } or nil when it has none.
function LevelUp.FeatAbilities()
    local fd = Vm.Get(featDetails(), "FeatDetails")
    local rows = Vm.List(fd, "AbilitySelection")
    if #rows == 0 then return nil end
    local out = { chosen = Vm.Get(fd, "SelectedAbilityCount") or 0, max = Vm.Get(fd, "MaxSelectedAbilityCount") or 0, list = {} }
    for i, a in ipairs(rows) do
        local id = Vm.Enum(a, "Ability")
        out.list[i] = {
            id = id,
            name = (id and Loca.Enum("AbilityDisplayName", id)) or Vm.Text(a, "Name") or id or "?",
            value = Vm.Get(a, "Value"),
            improvement = Vm.Get(a, "Improvement") or 0,
        }
    end
    return out
end

-- One point more (delta 1) or less (-1) on the chosen feat's ability i. Returns ok.
function LevelUp.ChangeFeatAbility(i, delta)
    local a = Vm.List(Vm.Get(featDetails(), "FeatDetails"), "AbilitySelection")[i]
    if not a then return false end
    return Vm.Run(dc(), delta > 0 and "SelectAbility" or "DeselectAbility", a)
end

-- The chosen feat's skills (Skilled: 3): { chosen, max, list = { { id, name, ability, selected,
-- proficient, enabled } } } or nil.
function LevelUp.FeatSkills()
    local g = Vm.Get(featDetails(), "FeatSkills")
    local rows = Vm.List(g, "Skills")
    if #rows == 0 then return nil end
    local out = { chosen = Vm.Get(g, "SelectedSkillCount") or 0, max = Vm.Get(g, "MaxSelectedSkillCount") or 0, list = {} }
    for i, sk in ipairs(rows) do
        local id, ability = Vm.Enum(sk, "Skill"), Vm.Enum(sk, "Ability")
        out.list[i] = {
            id = id,
            name = (id and Loca.Enum("SkillDisplayName", id)) or Vm.Text(sk, "Name") or id or "?",
            ability = ability and (Loca.Enum("AbilityDisplayName", ability) or ability),
            selected = Vm.Get(sk, "Selected") == true,
            proficient = Vm.Get(sk, "IsProficient") == true,
            enabled = Vm.Get(sk, "Enabled") == true,
        }
    end
    return out
end

function LevelUp.ToggleFeatSkill(i)
    local sk = Vm.List(Vm.Get(featDetails(), "FeatSkills"), "Skills")[i]
    if not sk then return false end
    return Vm.Run(dc(), "ToggleSkill", sk)
end

-- The chosen feat's passive choices (Elemental Adept's element...), for Game/PassiveChoices.
LevelUp.FeatPassives = {
    dc = dc,
    selectors = function() return Vm.List(featDetails(), "FeatPassives") end,
}

-- The chosen feat's spell choices (Magic Initiate), for Game/SpellChoices. The feat panel shows
-- each selector with an edit toggle (editSpellSelectorBtn); checking it shows SpellSelectorGrid
-- with the selector as spellSelectorData's DataContext (CCLib_k.xaml FeatSpellSelector), whose
-- buttons are SelectSpell / DeselectSpell.
local FEAT_TAB_MS = 400
local function featSpellSelectors() return Vm.List(Vm.Get(featDetails(), "FeatDetails"), "SpellSelectors") end
LevelUp.FeatSpells = {
    widget = LevelUp.Widget,
    ready = function(onReady, onWait) LevelUp.WhenClickable(onReady, onWait) end,
    selectors = featSpellSelectors,
    selectButton = "SelectSpell",
    deselectButton = "DeselectSpell",
    isOpen = function(i)
        local data = Ui.FindElement(LevelUp.Widget, "spellSelectorData")
        local grid = Ui.FindElement(LevelUp.Widget, "SpellSelectorGrid")
        return grid ~= nil and Ui.IsShown(grid) and Vm.Same(Vm.Get(data, "DataContext"), featSpellSelectors()[i])
    end,
    open = function(i, onDone)
        -- The feat panel exists only while the game's feat tab is selected (the overview is
        -- shown again whenever the mod's list is back at its top).
        LevelUp.ShowFeatTab()
        -- Checking the toggle with SetProperty did not run its triggers (2026-09-26): the mod
        -- does what they do, showing the grid with the selector as its data (verified: the
        -- 15 SelectSpell buttons of Magic Initiate: Wizard's cantrips appeared).
        Timer.After(FEAT_TAB_MS, function()
            local s = featSpellSelectors()[i]
            local grid = Ui.FindElement(LevelUp.Widget, "SpellSelectorGrid")
            local data = Ui.FindElement(LevelUp.Widget, "spellSelectorData")
            if not (s and grid and data) then onDone(false) return end
            local ok = pcall(function()
                data:SetProperty("DataContext", s)
                grid:SetProperty("Visibility", "Visible")
            end)
            onDone(ok)
        end)
    end,
}

-- The game's feat tab (featTab, a ListBoxItem shown while CanSelectFeat), as a player opens it
-- to choose: its panel shows the chosen feat's details.
function LevelUp.ShowFeatTab()
    local tab = Ui.FindElement(LevelUp.Widget, "featTab")
    if tab then tab:SetProperty("IsSelected", true) end
end

-- Back to the level-up overview (the game's first tab: what the level brings, Accept).
function LevelUp.ShowOverview()
    local tab = Ui.FindElement(LevelUp.Widget, "levelupTab")
    if tab then tab:SetProperty("IsSelected", true) end
end

-- The party members with a level up waiting, the selected one first: { character VMs } (valid
-- this tick).
local function waiting()
    local out = {}
    local selected = Vm.Get(Player.SelectedCharacter(), "EntityUUID")
    for _, c in ipairs(Vm.List(Player.Current(), "AssignedCharacters")) do
        if Vm.Get(Vm.Get(Vm.Get(c, "Stats"), "Level"), "LevelUpAvailable") == true then
            if Vm.Get(c, "EntityUUID") == selected then table.insert(out, 1, c) else out[#out + 1] = c end
        end
    end
    return out
end

function LevelUp.Available()
    return #waiting() > 0
end

-- Opens the level up of the selected character, or of the first one waiting (the HotBar's
-- level-up button command). Returns the name, or nil.
function LevelUp.Start()
    local c = waiting()[1]
    if not c then return nil end
    if not Vm.Run(Vm.WidgetDc("HotBar"), "StartLevelUp", c) then return nil end
    return Vm.Text(c, "Name") or "?"
end

-- The level up's intro ("¡Subes de nivel!", LevelUpStep Started, then each item shown in turn)
-- keeps the panel unclickable until it ends (LevelUpStep IntroComplete: about 9-18 s for Tav's 9
-- items, measured 2026-09-24; levelUp.IsHitTestVisible is no guide: for the next character in
-- the same widget it stays true from the last one). Reading and browsing need nothing; clicks do.
-- Once, for the third character in a row, it never ended (Gale after Tav and Shadowheart; on a
-- replay the same chain ended normally within 50 s); the game's skip binding (UISkipDialog) only
-- moved it to SkipAnimation, still unclickable. Closing the level up (the game's cancel key) and
-- opening it again for the same character played the intro normally.
local CLICKABLE_WAIT_MS = 30000
local REOPEN_MS = 1000
local POLL_MS = 250

function LevelUp.Clickable()
    return Vm.Enum(dc(), "LevelUpStep") == "IntroComplete"
end

-- Calls onDone(ok) once LevelUp.Clickable() or after waitMs.
local function untilClickable(waitMs, onDone)
    local started = Ext.Utils.MonotonicTime()
    local function poll()
        if LevelUp.Clickable() then onDone(true) return end
        if Ext.Utils.MonotonicTime() - started > waitMs then onDone(false) return end
        Timer.After(POLL_MS, poll)
    end
    poll()
end

-- Closes the level up and opens it again for the same character. onDone(ok).
local function reopen(onDone)
    local name = Vm.Text(Vm.Get(dc(), "LevelUpCharacter"), "Name")
    local key = Input.ScancodeFor("UICancel")
    if not name or not key then
        onDone(false)
        return
    end
    Ext.Input.InjectKeyPress(key)
    Timer.After(REOPEN_MS, function()
        for _, c in ipairs(waiting()) do
            if Vm.Text(c, "Name") == name then
                onDone(Vm.Run(Vm.WidgetDc("HotBar"), "StartLevelUp", c))
                return
            end
        end
        onDone(false)
    end)
end

-- Calls onReady(ok) once the panel takes clicks: at once, or after the intro (onWait() is called
-- first when there is a wait), or after opening the level up again when the intro is stuck.
function LevelUp.WhenClickable(onReady, onWait)
    if LevelUp.Clickable() then
        onReady(true)
        return
    end
    if onWait then onWait() end
    untilClickable(CLICKABLE_WAIT_MS, function(ok)
        if ok then
            onReady(true)
            return
        end
        reopen(function(opened)
            if not opened then
                onReady(false)
                return
            end
            untilClickable(CLICKABLE_WAIT_MS, onReady)
        end)
    end)
end

return LevelUp
