-- The dice roll screen of skill checks (widget ActiveRoll, gui::DCActiveRoll). Facts (verified
-- 2026-09-24, Shadowheart's pod, "[FUERZA]" check, Tav STR 17):
--   DC: SkillOrAbility (handle "Fuerza"), RollState (WaitForStart before the roll), RollContext
--   (DialogCheck), SelectedDialogueLine (text), TargetNumber 7 (what the die must show),
--   MinBonusValue / MaxBonusValue 3, ResultNumber, RolledNumber1/2, Success, SkippedRoll,
--   InspirationPoints, HasBoostsToAdd; commands UserTriggeredNextPhaseCommand (bound to UIAccept
--   in the XAML, but a real Enter did nothing here; executed with nil it rolled: RollState
--   WaitForStart -> StartRoll with FinalResult 14 (the die), ResultNumber 17, Success at once,
--   then ResultReady after the animation, with SkillOrAbilityResultText "¡Prueba de Fuerza
--   superada!"), RollAgainCommand (inspiration),
--   TryAgainCommand, ContinueCommand, CancelCommand, AddModifierCommand/RemoveModifierCommand.
--   DC.Roll: DifficultyCheck 10, AbilityValue 17, RollAdvantageType None, Modifiers[],
--   Advantages[], Finished, Success, RolledNumber (these stayed false/0 after the roll: use the
--   DC's fields).
-- Bonuses (verified 2026-09-24, Kagha's Intimidation check, Shadowheart's Guidance):
--   NearbyPartyCharacters[] (Owner = character VM, BoostModifierList[] = { BoostModifier (spell VM:
--   Name "Guía"), DiceTypeSet.Str "1d4", IsSelected }); SelectedBoostModifierList = the added ones.
--   The "Añadir bonificador" button only makes the grid BoostList visible (no command); adding a
--   bonus is AddModifierCommand with a MultiBinding [BonusTxt element, "Top", command] that Lua
--   cannot build, so the bonus is pressed with a verified click (Activate.ClickGridItem, cells =
--   the items' bgImg images). RemoveModifierCommand takes the added bonus itself.
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Timer = Ext.Require("Core/Timer.lua")
local Text = Ext.Require("Core/Text.lua")

local ActiveRoll = {}

ActiveRoll.Widget = "ActiveRoll"

local function dc() return Vm.WidgetDc(ActiveRoll.Widget) end

-- { skill, difficulty, bonusMin, bonusMax, need, state, advantage?, line, rolled, rolled2, result,
--   success, finished, resultText?, inspiration, canBoost, modifiers = { { name, value } } } or nil.
function ActiveRoll.Read()
    local d = dc()
    if not d then return nil end
    local roll = Vm.Get(d, "Roll")
    local adv = Vm.Enum(roll, "RollAdvantageType")
    local out = {
        skill = Vm.Text(d, "SkillOrAbility"),
        difficulty = Vm.Get(roll, "DifficultyCheck"),
        bonusMin = Vm.Get(d, "MinBonusValue"),
        bonusMax = Vm.Get(d, "MaxBonusValue"),
        need = Vm.Get(d, "TargetNumber"),
        state = Vm.Enum(d, "RollState"),
        advantage = (adv and adv ~= "None") and adv or nil,
        line = Text.Clean(tostring(Vm.Get(d, "SelectedDialogueLine") or "")),
        rolled = Vm.Get(d, "FinalResult"),
        rolled2 = Vm.Get(d, "RolledNumber2"),
        result = Vm.Get(d, "ResultNumber"),
        success = Vm.Get(d, "Success") == true,
        -- Known once the dice are thrown (StartRoll with a result) or later; when the bonus holds
        -- dice (an added bonus, or Guidance already on the character: the bonus is a range), they
        -- are rolled after the d20 and ResultNumber grows then (18, then 24 with +2 and
        -- Guidance's 4): only ResultReady has the total. With a fixed bonus, ResultNumber can
        -- also lag the die for a moment (14 with +2 at the goblin camp gate, 2026-09-24): the
        -- total counts once it is the die plus the bonus.
        finished = (Vm.Get(d, "FinalResult") or 0) > 0 and (Vm.Get(d, "ResultNumber") or 0) > 0
            and ((#Vm.List(d, "SelectedBoostModifierList") == 0 and Vm.Get(d, "MinBonusValue") == Vm.Get(d, "MaxBonusValue")
                    and Vm.Get(d, "ResultNumber") == Vm.Get(d, "FinalResult") + (Vm.Get(d, "MinBonusValue") or 0))
                or Vm.Enum(d, "RollState") == "ResultReady"),
        resultText = Vm.Text(d, "SkillOrAbilityResultText"),
        inspiration = Vm.Get(d, "InspirationPoints") or 0,
        canBoost = Vm.Get(d, "HasBoostsToAdd") == true,
        modifiers = {},
    }
    for _, m in ipairs(Vm.List(roll, "Modifiers")) do
        out.modifiers[#out.modifiers + 1] = { name = Vm.Text(m, "Name") or Vm.Text(m, "Description"), value = Vm.Get(m, "Value") }
    end
    return out
end

-- Bonuses the party can add: { { owner, name, dice, key } } (key: "owner/name").
function ActiveRoll.Boosts()
    local out = {}
    for _, c in ipairs(Vm.List(dc(), "NearbyPartyCharacters")) do
        local owner = Entities.Name(Vm.Get(Vm.Get(c, "Owner"), "EntityUUID")) or "?"
        for _, b in ipairs(Vm.List(c, "BoostModifierList")) do
            if Vm.Get(b, "IsSelected") ~= true then
                local name = Vm.Text(Vm.Get(b, "BoostModifier"), "Name") or "?"
                out[#out + 1] = { owner = owner, name = name, dice = Vm.Get(Vm.Get(b, "DiceTypeSet"), "Str"), key = owner .. "/" .. name }
            end
        end
    end
    return out
end

-- Added bonuses: { { name, dice, index, rolled } }; rolled is the bonus die's value once the roll
-- is over (the bonus's Min and MaxBonusValue then both hold it).
function ActiveRoll.AddedBoosts()
    local out = {}
    local ready = Vm.Enum(dc(), "RollState") == "ResultReady"
    for i, b in ipairs(Vm.List(dc(), "SelectedBoostModifierList")) do
        local lo, hi = Vm.Get(b, "MinBonusValue"), Vm.Get(b, "MaxBonusValue")
        out[#out + 1] = {
            name = Vm.Text(Vm.Get(b, "BoostModifier"), "Name") or "?",
            dice = Vm.Get(Vm.Get(b, "DiceTypeSet"), "Str"),
            index = i,
            rolled = ready and lo == hi and lo or nil,
        }
    end
    return out
end

local BOOST_LIST_OPEN_MS = 300 -- the list's items are laid out a few frames after it is shown
local BOOST_ADDED_MS = 1500

local function boostKeyOf(b)
    local owner = Entities.Name(Vm.Get(Vm.Get(b, "Owner"), "EntityUUID")) or "?"
    return owner .. "/" .. (Vm.Text(Vm.Get(b, "BoostModifier"), "Name") or "?")
end

local function boostCells()
    local out = {}
    for _, list in ipairs(Ui.FindAllByName(Ui.FindWidget(ActiveRoll.Widget), "boostmodlist")) do
        for _, el in ipairs(Ui.FindAllByName(list, "bgImg")) do
            if Ui.IsShown(el) then out[#out + 1] = el end
        end
    end
    return out
end

-- Adds the bonus with this key (ActiveRoll.Boosts): shows the list as the game's button does,
-- clicks the bonus, and waits until the game lists it as added. onDone(ok, reasonKey).
function ActiveRoll.AddBoost(key, onDone)
    local widget = Ui.FindWidget(ActiveRoll.Widget)
    for _, el in ipairs(Ui.FindAllByName(widget, "BoostList")) do
        pcall(function() el:SetProperty("Visibility", "Visible") end)
    end
    for _, el in ipairs(Ui.FindAllByName(widget, "BoostListButtonHolder")) do
        pcall(function() el:SetProperty("Visibility", "Collapsed") end)
    end
    local before = #ActiveRoll.AddedBoosts()
    Timer.After(BOOST_LIST_OPEN_MS, function()
        Activate.ClickGridItem(ActiveRoll.Widget, {
            name = "boostmodlist",
            cells = boostCells,
            isTarget = function(el)
                local b = Ui.TemplateItem(el)
                return b ~= nil and boostKeyOf(b) == key
            end,
        }, function(ok, reason)
            if not ok then
                onDone(false, reason)
                return
            end
            local started = Ext.Utils.MonotonicTime()
            local function poll()
                if #ActiveRoll.AddedBoosts() > before then
                    onDone(true)
                elseif Ext.Utils.MonotonicTime() - started > BOOST_ADDED_MS then
                    onDone(false, "reason_no_effect")
                else
                    Timer.After(100, poll)
                end
            end
            poll()
        end)
    end)
end

-- Takes an added bonus back (the game's RemoveModifierCommand with the bonus itself).
function ActiveRoll.RemoveBoost(index)
    local b = Vm.List(dc(), "SelectedBoostModifierList")[index]
    return b ~= nil and Vm.Run(dc(), "RemoveModifierCommand", b)
end

-- Rolls the dice, or goes on after the result: the game's own Enter action.
function ActiveRoll.Next() return Vm.Run(dc(), "UserTriggeredNextPhaseCommand", nil) end
function ActiveRoll.RollAgain() return Vm.Run(dc(), "RollAgainCommand", nil) end
-- The game's reroll button is enabled only with inspiration left and while the roll takes
-- commands (ActiveRoll.xaml); the command's own CanExecute was true with 0 points (a failed
-- Intimidation check in the goblin sanctum, 2026-09-24: "roll again" offered, nothing happened).
function ActiveRoll.CanRollAgain()
    local d = dc()
    return (Vm.Get(d, "InspirationPoints") or 0) > 0 and Vm.Get(d, "CanRespondToCommands") == true
        and Vm.CanExecute(Vm.Get(d, "RollAgainCommand"), nil) == true
end

return ActiveRoll
