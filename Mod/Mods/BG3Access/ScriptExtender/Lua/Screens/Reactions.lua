-- Reaction prompt (Game/Reactions): what happened ("the goblin attacks Gale"), then one button per
-- reaction and character ("Escudo, Gale, reaction, level 1 spell slot"): Enter uses it (chooses it
-- in the game's popup and confirms), and "Don't react" lets the moment pass.
local Game = Ext.Require("Game/Reactions.lua")
local Loca = Ext.Require("Game/Loca.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Reactions = ListScreen.Extend()
Reactions.Widgets = { Game.Widget }

function Reactions.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_reaction")), Reactions)
end

local function costText(cost)
    if cost.type == "SpellSlot" and cost.level and cost.level > 0 then return L("spell_slot_cost", { n = cost.level }) end
    return cost.name and (cost.name:gsub("%s*%[%d+%]", "")) or nil
end

local function choiceLabel(c)
    local costs = {}
    for _, cost in ipairs(c.costs) do costs[#costs + 1] = costText(cost) end
    return Strings.List({ c.name, c.who, Strings.List(costs), c.chosen and L("spell_chosen") })
end

function Reactions:Build()
    local r = Game.Read()
    if not r then return {} end
    self.title = r.description and L("reaction_title", { event = r.description }) or L("screen_reaction")
    local out = {}
    for _, c in ipairs(r.choices) do
        local ci, di = c.interruptor, c.decision
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return choiceLabel(c) end,
            details = function() return c.description end,
            activate = function()
                Game.Use(ci, di, function(ok, reason)
                    if not ok then
                        Speech.Say(L("could_not_activate", { label = c.name, reason = L(reason or "reason_unavailable") }), { interrupt = true })
                    end
                end)
            end,
        })
    end
    out[#out + 1] = Controls.Button({
        label = Loca.Text(Game.DontReactLabel) or L("reaction_dont"),
        activate = function(done) done(Game.DontReact(), "reason_unavailable") end,
    })
    return out
end

-- Escape lets the moment pass: the game's own Escape over this popup opened the game menu
-- (twice in the Sanctum, 2026-09-25) and left the question waiting.
function Reactions:OnKey(combo)
    if combo == "ESCAPE" then
        local ok = Game.DontReact()
        Speech.Say(ok and (Loca.Text(Game.DontReactLabel) or L("reaction_dont"))
            or L("could_not_activate", { label = L("reaction_dont"), reason = L("reason_unavailable") }), { interrupt = true })
        return true
    end
    return ListScreen.OnKey(self, combo)
end

function Reactions:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_reaction")
    return lines
end

return Reactions
