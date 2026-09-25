-- The quest journal (client), readable any time through CurrentPlayer, without opening the J
-- screen. Facts (verified 2026-09-24 on the beach):
--   CurrentPlayer.JournalItemContainers[] = categories: QuestCategory.Description (handle:
--   "Misión principal", "Compañeros", "Misiones completadas"), IsUpdated, QuestViews[] of
--   { QuestIsInProgress, Quest = { Title handle "Encuentra una cura.", IsMainQuest,
--   Objectives[] = { Description handle, ObjectivePriority, Steps[] = { Description handle:
--   the story so far } } }, SubQuestViews[] (same shape) }.
local Vm = Ext.Require("Game/Vm.lua")
local Player = Ext.Require("Game/Player.lua")

local Journal = {}

local function readQuest(view)
    local q = Vm.Get(view, "Quest")
    local out = {
        title = Vm.Text(q, "Title") or "?",
        inProgress = Vm.Get(view, "QuestIsInProgress") == true,
        objectives = {},
        subquests = {},
    }
    for _, o in ipairs(Vm.List(q, "Objectives")) do
        local steps = {}
        for _, s in ipairs(Vm.List(o, "Steps")) do steps[#steps + 1] = Vm.Text(s, "Description") end
        out.objectives[#out.objectives + 1] = { text = Vm.Text(o, "Description"), steps = steps }
    end
    for _, sub in ipairs(Vm.List(view, "SubQuestViews")) do out.subquests[#out.subquests + 1] = readQuest(sub) end
    return out
end

-- { { name, updated, quests = { { title, inProgress, objectives = { { text, steps = { text } } },
--   subquests = { same } } } } }
function Journal.Read()
    local out = {}
    for _, c in ipairs(Vm.List(Player.Current(), "JournalItemContainers")) do
        local cat = { name = Vm.Text(Vm.Get(c, "QuestCategory"), "Description") or "?", updated = Vm.Get(c, "IsUpdated") == true, quests = {} }
        for _, v in ipairs(Vm.List(c, "QuestViews")) do cat.quests[#cat.quests + 1] = readQuest(v) end
        out[#out + 1] = cat
    end
    return out
end

return Journal
