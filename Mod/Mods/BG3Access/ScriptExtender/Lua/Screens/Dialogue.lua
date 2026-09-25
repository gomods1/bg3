-- Dialogue reader (template_rpg 15, Game/Dialogue). Every line is spoken when the game says it
-- (its current line), in the words of the dialogue's history ("Speaker: text"); history lines
-- that are never the current one, such as the player's own answer (LineType Avatar), are spoken
-- before the next line said, or when the options come up: they confirm which answer was taken,
-- also when it was chosen with the number keys. When the
-- options come up: "N options", then Up/Down read them, Enter answers by pressing the game's own
-- key for that answer (its BoundEvent: the number keys, which also work directly). Space is left
-- to the game (skip line). Lines are queued, never interrupting (rule 4).
local Game = Ext.Require("Game/Dialogue.lua")
local Input = Ext.Require("Game/Input.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Buffers = Ext.Require("Core/Buffers.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Dialogue = ListScreen.Extend()
Dialogue.Widgets = { Game.Widget }

-- The conversation being read, kept across handler instances: the dialogue widget is left and
-- entered again when another screen comes in front (the dice roll, a tutorial), and its lines
-- must not be read again then (measured after a skill check).
local conversation = { first = nil, spoken = 0 }

function Dialogue.New(widget)
    local self = setmetatable(ListScreen.New(widget.name, L("screen_dialogue")), Dialogue)
    self.spoken = 0
    self.answersUp = false
    self.answersKey = nil
    return self
end

-- A tag as the game shows it before the answer: "Bárbaro", or for a roll "Atletismo check,
-- advantage".
local function tagWords(t)
    if not t.roll then return t.text end
    return Strings.List({ L("tag_roll", { name = t.text }),
        t.advantage == "Advantage" and L("advantage"), t.advantage == "Disadvantage" and L("disadvantage") })
end

local function answerText(i, a)
    local line
    if #a.tags > 0 then
        local words = {}
        for _, t in ipairs(a.tags) do words[#words + 1] = tagWords(t) end
        line = L("dialogue_option_tagged", { n = i, tags = Strings.List(words), text = a.text })
    else
        line = L("dialogue_option", { n = i, text = a.text })
    end
    return Strings.List({ line, not a.enabled and L("unavailable") })
end

-- Details key on an answer: what its tags mean (the game's tooltips).
local function answerDetails(a)
    local parts = {}
    for _, t in ipairs(a.tags) do
        parts[#parts + 1] = t.tooltip and L("label_value", { label = t.category or t.text, value = t.tooltip })
    end
    if #parts == 0 then return nil end
    return Strings.Sentences(parts)
end

function Dialogue:Build()
    local out = {}
    for i, a in ipairs(Game.Answers()) do
        out[i] = Controls.Item({
            kind = "button",
            describe = function() return answerText(i, a) end,
            details = function() return answerDetails(a) end,
            activate = function()
                if not a.enabled then
                    Speech.Say(L("could_not_activate", { label = a.text, reason = L("reason_unavailable") }), { interrupt = true })
                    return
                end
                if Game.Choose(i) then return end
                local key = a.event and Input.ScancodeFor(a.event)
                if key then Activate.Key(key) end
            end,
        })
    end
    return out
end

local function endsWith(s, tail)
    return tail ~= "" and #s >= #tail and s:sub(-#tail) == tail
end

-- Speaks the history lines up to the one being said now (Game.Current); flush: all of them (the
-- options are up: nothing more will be said before the player answers).
function Dialogue:SpeakNewLines(flush)
    local history = Game.History()
    local first = history[1] and history[1].text
    if first ~= conversation.first or #history < conversation.spoken then
        -- Another conversation (or the history restarted).
        if conversation.first ~= nil or first ~= nil then Buffers.Clear("dialogue") end
        conversation.first, conversation.spoken = first, 0
    end
    local upTo = conversation.spoken
    local current = Game.Current()
    if current then
        for k = conversation.spoken + 1, #history do
            if endsWith(history[k].text or "", current) then
                upTo = k
                break
            end
        end
    end
    if flush then upTo = #history end
    for i = conversation.spoken + 1, upTo do
        if history[i].text then Speech.Event(history[i].text, "dialogue") end
    end
    conversation.spoken = math.max(conversation.spoken, upTo)
    self.spoken = conversation.spoken
end

function Dialogue:Open()
    self:SpeakNewLines()
    self:Refresh()
end

-- Identity of an answer set: one set can replace another with no line in between ("Cambiar de
-- tema" with a companion goes straight to the topics: nothing was said and a number key then
-- chose from a list the player had not heard, 2026-09-24).
local function answersKey(answers)
    local texts = {}
    for i, a in ipairs(answers) do texts[i] = a.text or "" end
    return table.concat(texts, "|")
end

function Dialogue:Tick()
    local answers = Game.Answers()
    self:SpeakNewLines(#answers > 0)
    local up = #answers > 0
    local key = up and answersKey(answers) or nil
    if key ~= self.answersKey then
        self.answersKey = key
        self.answersUp = up
        self.index = 0
        self:Refresh()
        if up then Speech.Say(L("dialogue_options", { n = #answers })) end
    end
end

function Dialogue:ReadAll()
    local history = Game.History()
    local parts = { history[#history] and history[#history].text }
    for i, a in ipairs(Game.Answers()) do parts[#parts + 1] = answerText(i, a) end
    Speech.Say(Strings.Sentences(parts), { interrupt = true })
end

function Dialogue:Help()
    return { L("help_dialogue") }
end

function Dialogue:OnKey(combo)
    if combo == "SPACE" then return false end -- the game's skip-line key
    if not self.answersUp then return false end
    -- Number keys answer through the answer's command: the game's own number keys skip answers
    -- scrolled out of its list.
    local n = tonumber(combo:match("^NUM_(%d)$") or combo:match("^KP_(%d)$") or "")
    if n and n >= 1 and self.controls[n] then
        self.index = n
        self.controls[n].Activate()
        return true
    elseif n and n >= 1 then
        Speech.Say(L("dialogue_no_option", { n = n }), { interrupt = true })
        return true
    end
    return ListScreen.OnKey(self, combo)
end

return Dialogue
