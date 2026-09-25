-- Passive choices in list screens (Game/PassiveChoices): a section per selector ("Corazón
-- bestial, 0 of 1 chosen": Enter opens its passives as a sub-list), and in it one item per
-- passive ("Corazón de oso, chosen": Enter chooses it or takes it back, read back from the game;
-- Ctrl+D describes it).
local PassiveChoices = Ext.Require("Game/PassiveChoices.lua")
local SpellWords = Ext.Require("Screens/SpellWords.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local PassiveChoiceList = {}

local function choiceLine(c)
    return L(c.complete and "spell_choice_done" or "spell_choice", {
        title = c.name or L("level_up_choice_passive"), chosen = c.chosen, max = c.max,
    })
end

local function build(source, i)
    local c = PassiveChoices.Read(source)[i]
    local out = {}
    for j, p in ipairs(c and c.passives or {}) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                local now = PassiveChoices.Read(source)[i]
                local q = now and now.passives[j]
                if not q then return L("option_gone") end
                return Strings.List({ q.name, q.selected and L("spell_chosen"), not q.enabled and L("unavailable") })
            end,
            details = function()
                local d = PassiveChoices.Description(source, i, j)
                return d and SpellWords.Description(d)
            end,
            activate = function()
                if not PassiveChoices.Toggle(source, i, j) then
                    Speech.Say(L("could_not_activate", { label = p.name, reason = L("reason_unavailable") }), { interrupt = true })
                    return
                end
                Controls.SayLater(function()
                    local now = PassiveChoices.Read(source)[i]
                    local q = now and now.passives[j]
                    if not q then return nil end
                    return Strings.Sentences({
                        L(q.selected and "spell_now_chosen" or "spell_now_removed", { name = q.name }),
                        choiceLine(now),
                    })
                end)
            end,
        })
    end
    return out
end

-- The section control of selector i for screen (a ListScreen).
function PassiveChoiceList.Control(screen, source, i)
    return Controls.Item({
        kind = "button",
        describe = function()
            local now = PassiveChoices.Read(source)[i]
            return now and choiceLine(now) or L("option_gone")
        end,
        details = function()
            local now = PassiveChoices.Read(source)[i]
            return now and now.description
        end,
        activate = function()
            local c = PassiveChoices.Read(source)[i]
            if not c then return end
            local selectedAt = nil
            for j, p in ipairs(c.passives) do
                if p.selected and not selectedAt then selectedAt = j end
            end
            screen:Push(choiceLine(c), function() return build(source, i) end, selectedAt)
        end,
    })
end

return PassiveChoiceList
