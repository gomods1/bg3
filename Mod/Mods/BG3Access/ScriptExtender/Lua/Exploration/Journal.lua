-- Journal (mod menu): the quest journal (Game/Journal) as nested lists: categories, their
-- quests ("Encuentra una cura, 1 objective"), and a quest's objectives with the story steps
-- (Enter on an objective reads its steps; Ctrl+D too). A mod screen over the HUD.
local Game = Ext.Require("Game/Journal.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Text = Ext.Require("Core/Text.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Journal = ListScreen.Extend()

function Journal.New(onClose)
    local self = setmetatable(ListScreen.New("(journal)", L("screen_journal")), Journal)
    self.onClose = onClose
    return self
end

local function questLine(q)
    return Strings.List({ Text.StripStop(q.title), L("journal_objectives", { n = #q.objectives }) })
end

-- Objectives and subquests of quest q.
local function questBuild(self, q)
    local out = {}
    for _, o in ipairs(q.objectives) do
        local steps = Strings.Sentences(o.steps)
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return o.text or "?" end,
            details = function() return steps end,
            activate = function() Speech.Say(steps ~= "" and steps or L("no_details"), { interrupt = true }) end,
        })
    end
    for _, sub in ipairs(q.subquests) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return questLine(sub) end,
            activate = function() self:Push(sub.title, function(s) return questBuild(s, sub) end) end,
        })
    end
    if #out == 0 then out[1] = Controls.Text(L("journal_nothing")) end
    return out
end

function Journal:Build()
    local out = {}
    for _, cat in ipairs(Game.Read()) do
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function()
                return Strings.List({ cat.name, L("journal_quests", { n = #cat.quests }), cat.updated and L("journal_updated") })
            end,
            activate = function()
                self:Push(cat.name, function(s)
                    local list = {}
                    for _, q in ipairs(cat.quests) do
                        list[#list + 1] = Controls.Item({
                            kind = "button",
                            describe = function() return questLine(q) end,
                            activate = function() s:Push(q.title, function(s2) return questBuild(s2, q) end) end,
                        })
                    end
                    return list
                end)
            end,
        })
    end
    return out
end

function Journal:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_journal")
    return lines
end

return Journal
