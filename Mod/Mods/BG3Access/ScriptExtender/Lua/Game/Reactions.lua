-- Reaction prompt (widget ReactionDecisionPopup, DC ls.DCReactionDecision): when a reaction set to
-- "ask" can be used (Shield when hit, an attack of opportunity...), the game pauses and asks.
-- Seen in play 2026-09-24 (Tav's attack on Quelenna missed: "Ataque temerario" offered to reroll),
-- after setting the party's attack of opportunity to "ask" (InterruptChangeAskCommand).
--   DC.Data.InterruptEvents[]: Description (context string "[1]<newline>[2]" whose params read empty:
--     the text shown is read from the runs of the popup's first TextBlock, Ui.FirstInlineText),
--     SourceCharacter, TargetCharacter, SourceSpell, Interruptors[] (Character,
--     InterruptDecisions[]: Interrupt { Name, Costs }, Decision ("Use" once chosen)).
--   Choosing a reaction: toggle button ReactButton, command InterruptReactCommand with a
--     MultiBinding [decision, interruptor] (not buildable from Lua: pressed by grid click); a chosen
--     one runs InterruptUndecidedCommand(interruptor) to take it back.
--   Confirm: AcceptReactButton = InterruptAcceptPlayerCommand(InterruptEvents[1]) (enabled once a
--     reaction is chosen); DoNotReactButton = InterruptDontReactPlayerCommand(InterruptEvents[1]).
local Vm = Ext.Require("Game/Vm.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Player = Ext.Require("Game/Player.lua")
local Timer = Ext.Require("Core/Timer.lua")

local Reactions = {}

Reactions.Widget = "ReactionDecisionPopup"
Reactions.DontReactLabel = "ha13dce2cgf0cfg4b73g9fb7gc12b29c68a6b"

local REACT_BUTTON = "ReactButton"
local RESULT_POLL_MS = 100
local RESULT_WAIT_MS = 1500

local function dc() return Vm.WidgetDc(Reactions.Widget) end

local function firstEvent()
    return Vm.List(Vm.Get(dc(), "Data"), "InterruptEvents")[1]
end

-- The first pending event: { description, choices = { { who, name, costs = { { type, name, level } },
-- chosen } } }
-- (one choice per character and reaction, in the game's order), or nil.
function Reactions.Read()
    local ev = firstEvent()
    if not ev then return nil end
    local root = Ui.FindElement(Reactions.Widget, "InterruptEventRoot") or Ui.FindWidget(Reactions.Widget)
    local out = { description = Ui.FirstInlineText(root), choices = {} }
    for ci, who in ipairs(Vm.List(ev, "Interruptors")) do
        local name = Vm.Text(Vm.Get(who, "Character"), "Name")
        for di, d in ipairs(Vm.List(who, "InterruptDecisions")) do
            local interrupt = Vm.Get(d, "Interrupt")
            -- Costs[]: TypeId (ReactionActionPoint, SpellSlot...), Name handle, Level (the spell
            -- slot's; the SpellSlot name is a template "Nivel [1] [2]"), IsHidden.
            local costs = {}
            for _, c in ipairs(Vm.List(interrupt, "Costs")) do
                if Vm.Get(c, "IsHidden") ~= true then
                    costs[#costs + 1] = { type = Vm.Enum(c, "TypeId"), name = Vm.Text(c, "Name"), level = Vm.Get(c, "Level") }
                end
            end
            out.choices[#out.choices + 1] = {
                interruptor = ci, decision = di, who = name,
                name = Vm.Text(interrupt, "Name") or "?",
                description = Vm.ContextText(Vm.Get(interrupt, "Description")),
                costs = costs,
                chosen = Vm.Enum(d, "Decision") == "Use",
            }
        end
    end
    return out
end

local function decisionVm(ci, di)
    local ev = firstEvent()
    local who = Vm.List(ev, "Interruptors")[ci]
    return Vm.List(who, "InterruptDecisions")[di], who
end

local function isChosen(ci, di)
    return Vm.Enum((decisionVm(ci, di)), "Decision") == "Use"
end

-- The ReactButtons of one character's panel, in layout order.
local function reactButtons(ci)
    local who = select(2, decisionVm(ci, 1))
    local out = {}
    for _, el in ipairs(Ui.FindAllByName(Ui.FindWidget(Reactions.Widget), REACT_BUTTON)) do
        if Ui.IsShown(el) and Vm.Same(Vm.Get(Ui.FindAncestorByName(el, "InterruptorRoot"), "DataContext"), who) then
            out[#out + 1] = el
        end
    end
    return out
end

-- Chooses reaction (ci, di) and confirms it (the game's Accept, when the popup stays open; with
-- one player the choice resolves the prompt by itself). onDone(ok, reasonKey).
function Reactions.Use(ci, di, onDone)
    onDone = onDone or function() end
    local function accept()
        if Vm.Run(dc(), "InterruptAcceptPlayerCommand", firstEvent()) then onDone(true) else onDone(false, "reason_unavailable") end
    end
    if isChosen(ci, di) then
        accept()
        return
    end
    local target = decisionVm(ci, di)
    Activate.ClickGridItem(Reactions.Widget, {
        name = REACT_BUTTON,
        cells = function() return reactButtons(ci) end,
        isTarget = function(el) return Vm.Same(Ui.TemplateItem(el), target) end,
    }, function(ok, reason)
        if not ok then
            onDone(false, reason)
            return
        end
        local started = Ext.Utils.MonotonicTime()
        local function poll()
            if not firstEvent() then
                onDone(true) -- resolved at once: one player, one reaction (verified 2026-09-24)
            elseif isChosen(ci, di) then
                accept()
            elseif Ext.Utils.MonotonicTime() - started > RESULT_WAIT_MS then
                onDone(false, "reason_no_effect")
            else
                Timer.After(RESULT_POLL_MS, poll)
            end
        end
        Timer.After(RESULT_POLL_MS, poll)
    end)
end

-- Reaction settings (the game's reactions panel, key L): each party member's
-- PlayerCharacterProperties.Interrupts[] (Name, Description, Enabled, Ask, Available, CanUse).
-- Modes: "always" (Enabled, not Ask: used without asking), "ask" (Enabled and Ask: the prompt
-- above), "never" (not Enabled). Changed with any DC's InterruptChangeAskCommand(interrupt)
-- (verified 2026-09-24: Ask flipped for the whole party) and InterruptToggleDisableCommand
-- (interrupt) for Enabled.
Reactions.Modes = { "always", "ask", "never" }

local function modeOf(it)
    if Vm.Get(it, "Enabled") ~= true then return "never" end
    return Vm.Get(it, "Ask") == true and "ask" or "always"
end

local function party()
    return Vm.List(Player.Current(), "AssignedCharacters")
end

local function interruptsOf(c)
    return Vm.List(Vm.Get(c, "PlayerCharacterProperties"), "Interrupts")
end

-- { { name, reactions = { { name, description, mode, available } } } } per party member.
function Reactions.Settings()
    local out = {}
    for _, c in ipairs(party()) do
        local entry = { name = Vm.Text(c, "Name") or "?", reactions = {} }
        for _, it in ipairs(interruptsOf(c)) do
            entry.reactions[#entry.reactions + 1] = {
                name = Vm.Text(it, "Name") or "?",
                description = Vm.ContextText(Vm.Get(it, "Description")),
                mode = modeOf(it),
                available = Vm.Get(it, "Available") == true,
            }
        end
        out[#out + 1] = entry
    end
    return out
end

-- Sets reaction ri of party member ci to mode. Returns ok (the change shows on a later frame).
function Reactions.SetMode(ci, ri, mode)
    local it = interruptsOf(party()[ci])[ri]
    if not it then return false end
    local cmdDc = Vm.WidgetDc("HotBar")
    local enabled, ask = Vm.Get(it, "Enabled") == true, Vm.Get(it, "Ask") == true
    local ok = true
    if (mode ~= "never") ~= enabled then ok = Vm.Run(cmdDc, "InterruptToggleDisableCommand", it) and ok end
    if mode ~= "never" and (mode == "ask") ~= ask then ok = Vm.Run(cmdDc, "InterruptChangeAskCommand", it) and ok end
    return ok
end

-- Lets the moment pass without reacting. Returns ok.
function Reactions.DontReact()
    return Vm.Run(dc(), "InterruptDontReactPlayerCommand", firstEvent())
end

return Reactions
