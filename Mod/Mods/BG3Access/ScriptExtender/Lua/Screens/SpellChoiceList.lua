-- Spell choices in list screens (Game/SpellChoices), shared by the level up and character
-- creation: a section per selector ("Conjuros, 1 of 2 chosen": Enter opens the game's spell panel
-- and the spells as a sub-list), and in it one item per spell ("Proyectil mágico, Conjuro de
-- evocación niv. 1, chosen": Enter chooses it or takes it back, checked on the game's state;
-- Ctrl+D describes it).
local SpellChoices = Ext.Require("Game/SpellChoices.lua")
local SpellWords = Ext.Require("Screens/SpellWords.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local SpellChoiceList = {}

local function choiceLine(c)
    return L(c.complete and "spell_choice_done" or "spell_choice", {
        title = c.title or L(c.cantrips and "spell_choice_cantrips" or "spell_choice_spells"),
        chosen = c.chosen, max = c.max,
    })
end

local function isChosen(source, i, key)
    local now = SpellChoices.Read(source)[i]
    for _, x in ipairs(now and now.spells or {}) do
        if x.key == key then return x.selected end
    end
    return false
end

-- Chooses spell sp of selector i or takes it back, once the widget takes clicks (the level up's
-- intro: source.ready says "waiting" meanwhile), and says the result.
local function toggle(source, i, sp)
    local ready = source.ready or function(onReady) onReady(true) end
    ready(function(clickable)
        if not clickable then
            Speech.Say(L("could_not_activate", { label = sp.name, reason = L("reason_unavailable") }), { interrupt = true })
            return
        end
        SpellChoices.Toggle(source, i, sp.key, function(ok, reason)
            if not ok then
                Speech.Say(L("could_not_activate", { label = sp.name, reason = L(reason or "reason_unavailable") }), { interrupt = true })
                return
            end
            local now = SpellChoices.Read(source)[i]
            if not now then return end
            Speech.Say(Strings.Sentences({
                L(isChosen(source, i, sp.key) and "spell_now_chosen" or "spell_now_removed", { name = sp.name }),
                choiceLine(now),
            }), { interrupt = true })
        end)
    end, function() Speech.Say(L("level_up_waiting"), { interrupt = true }) end)
end

-- The spells of selector i of source.
local function build(source, i)
    local c = SpellChoices.Read(source)[i]
    local out = {}
    for _, sp in ipairs(c and c.spells or {}) do
        local key = sp.key
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return SpellWords.Line(sp, isChosen(source, i, key) and L("spell_chosen")) end,
            details = function() return sp.id and SpellWords.Details(sp.id) end,
            activate = function() toggle(source, i, sp) end,
        })
    end
    return out
end

-- The section control of selector i for screen (a ListScreen).
function SpellChoiceList.Control(screen, source, i)
    return Controls.Item({
        kind = "button",
        describe = function()
            local now = SpellChoices.Read(source)[i]
            return now and choiceLine(now) or L("option_gone")
        end,
        details = function()
            local now = SpellChoices.Read(source)[i]
            return now and now.description
        end,
        activate = function()
            local c = SpellChoices.Read(source)[i]
            if not c then return end
            SpellChoices.Open(source, i)
            screen:Push(choiceLine(c), function() return build(source, i) end)
        end,
    })
end

return SpellChoiceList
