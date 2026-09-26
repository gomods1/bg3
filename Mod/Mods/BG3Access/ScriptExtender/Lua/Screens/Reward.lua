-- The quest reward window (Game/Reward): it waits until accepted, so it is read like a list:
-- the quest and what was done, what is received and by whom, the items to choose from (Enter
-- chooses or unchooses one), then Accept. Ctrl+D describes an item.
local Game = Ext.Require("Game/Reward.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Timer = Ext.Require("Core/Timer.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")
local ItemWords = Ext.Require("Screens/ItemWords.lua")

local L = Strings.Get

local TOGGLE_SETTLE_MS = 300

local Reward = ListScreen.Extend()
Reward.Widgets = { Game.Widget }

function Reward.New(widget)
    return setmetatable(ListScreen.New(widget.name, L("screen_reward")), Reward)
end

local function itemControl(item)
    item.isNew = false
    return Controls.Item({
        kind = "text",
        describe = function() return ItemWords.Line(item) end,
        details = function() return ItemWords.Details(item) end,
    })
end

function Reward:Build()
    local r = Game.Read()
    if not r then return {} end
    self.title = r.quest and L("label_value", { label = L("screen_reward"), value = r.quest }) or L("screen_reward")
    local out = {}
    if r.description then out[#out + 1] = Controls.Text(r.description) end
    if #r.items > 0 then
        out[#out + 1] = Controls.Text(L("reward_receives", { name = r.receiver or "?" }))
        for _, item in ipairs(r.items) do out[#out + 1] = itemControl(item) end
    end
    if #r.optional > 0 then
        out[#out + 1] = Controls.Text(L("reward_choose", { n = r.maxChoices, chosen = r.chosen }))
        for _, item in ipairs(r.optional) do
            out[#out + 1] = Controls.Item({
                kind = "button",
                describe = function() return Strings.List({ ItemWords.Line(item), item.selected and L("spell_chosen") }) end,
                details = function() return ItemWords.Details(item) end,
                activate = function()
                    if not Game.Toggle(item.index) then
                        Speech.Say(L("could_not_activate", { label = item.name or "?", reason = L("reason_unavailable") }), { interrupt = true })
                        return
                    end
                    Timer.After(TOGGLE_SETTLE_MS, function()
                        self:Refresh()
                        local c = self:Current()
                        if c then Speech.Say(c.Describe(), { interrupt = true }) end
                    end)
                end,
            })
        end
    end
    out[#out + 1] = Controls.Button({
        label = L("reward_accept"),
        activate = function(done) done(Game.Accept(), "reason_unavailable") end,
    })
    return out
end

-- Everything at once: it is short, and the window waits for Accept.
function Reward:Open()
    ListScreen.Open(self)
    local lines = {}
    for _, c in ipairs(self.controls) do lines[#lines + 1] = c.Describe() end
    Speech.Say(Strings.Sentences(lines))
end

return Reward
