-- Dialogue (widget Dialogue, gui::DCDialogue). Facts (verified 2026-09-24, Lae'zel on the
-- nautiloid): the data is DC.CurrentPlayer.SelectedCharacter.PlayerCharacterProperties
-- .ActiveDialogue (gui::VMDialogue):
--   SpeakerName (handle), BodyText (text), ShowAnswers (bool: the options are up),
--   Answers[] (gui::VMDialogueAnswer: BodyText, AnswerIdx, AnswerTags[], Enabled,
--     BoundEvent = UISelectSlot1.. : the game's number keys choose answers),
--   History.Items[] (gui::VMDialogueHistoryItem: BodyText "Speaker: text", LineType NPC/...).
-- Answer tags (verified 2026-09-24, Shadowheart's pod, the barbarian's "[BÁRBARO]" answer):
--   Name (handle: "Bárbaro"), Category (handle: "Clase"), ToolTip (handle: the class text),
--   IsRoll (false here), RollAdvantageType (None), AbilityValue, AdditionalValue, Modifiers[],
--   Advantages[], DiceTypeSet.
-- History gets a whole exchange at once (verified 2026-09-24, Guerrera Trinzas in the goblin
-- sanctum: two lines added together, voiced 11 s apart; the Dream Visitor's last five at once),
-- while BodyText is the line being said now, following the voice: the reader follows BodyText and
-- takes the words (speaker included) from History.
local Vm = Ext.Require("Game/Vm.lua")
local Text = Ext.Require("Core/Text.lua")

local Dialogue = {}

Dialogue.Widget = "Dialogue"

local function active()
    local d = Vm.WidgetDc(Dialogue.Widget)
    local o = d
    for part in ("CurrentPlayer.SelectedCharacter.PlayerCharacterProperties.ActiveDialogue"):gmatch("[^.]+") do
        o = Vm.Get(o, part)
    end
    return o
end

-- History lines so far: { { text, lineType } }.
function Dialogue.History()
    local out = {}
    for i, item in ipairs(Vm.List(Vm.Get(active(), "History"), "Items")) do
        out[i] = { text = Text.Clean(tostring(Vm.Get(item, "BodyText") or "")), lineType = Vm.Enum(item, "LineType") }
    end
    return out
end

-- The options when they are up: { { text, enabled, event, tags = { { text, category?, roll,
-- advantage? ("Advantage"/"Disadvantage"), tooltip? } } } }, else {}.
function Dialogue.Answers()
    local ad = active()
    local out = {}
    if Vm.Get(ad, "ShowAnswers") ~= true then return out end
    for i, a in ipairs(Vm.List(ad, "Answers")) do
        local tags = {}
        for _, t in ipairs(Vm.List(a, "AnswerTags")) do
            local name = Vm.Text(t, "Name")
            if name then
                local adv = Vm.Enum(t, "RollAdvantageType")
                tags[#tags + 1] = {
                    text = name,
                    category = Vm.Text(t, "Category"),
                    roll = Vm.Get(t, "IsRoll") == true,
                    advantage = (adv and adv ~= "None") and adv or nil,
                    tooltip = Vm.Text(t, "ToolTip"),
                }
            end
        end
        out[i] = {
            text = Text.Clean(tostring(Vm.Get(a, "BodyText") or "")),
            enabled = Vm.Get(a, "Enabled") ~= false,
            event = Vm.Get(a, "BoundEvent") and tostring(Vm.Get(a, "BoundEvent")) or nil,
            tags = tags,
        }
    end
    return out
end

-- Chooses answer i with the answer button's own command (SelectAnswerCommand(answer), one plain
-- parameter; DialogueTemplates.xaml). Unlike the answer's number key it works for answers
-- scrolled out of the game's list (the 6th of Lae'zel's answers, 2026-09-24). Returns ok.
function Dialogue.Choose(i)
    local a = Vm.List(active(), "Answers")[i]
    if not a then return false end
    return Vm.Run(Vm.WidgetDc(Dialogue.Widget), "SelectAnswerCommand", a)
end

-- The text of the line being said now (cleaned), or nil between lines.
function Dialogue.Current()
    local body = Text.Clean(tostring(Vm.Get(active(), "BodyText") or ""))
    if body == "" then return nil end
    return body
end

-- Speaker of the current line, as text.
function Dialogue.Speaker()
    return Vm.Text(active(), "SpeakerName")
end

return Dialogue
