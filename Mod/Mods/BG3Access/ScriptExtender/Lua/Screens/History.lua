-- History (mod menu): the review buffers (Core/Buffers), one section each (NAVIGATION.md): Tab /
-- Shift+Tab switch between events, combat log and dialogue (empty ones are left out), Up/Down read
-- the lines newest first, Home/End jump, Enter reads the line again, Escape closes. Opens on the
-- buffer that fits what the player is doing (dialogue in a conversation, combat in a fight).
local Buffers = Ext.Require("Core/Buffers.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local History = ListScreen.Extend()

-- start: the buffer to open on (falls back to the first non-empty one); onClose: gives the keys back.
function History.New(start, onClose)
    local self = setmetatable(ListScreen.New("(history)", L("screen_history_title")), History)
    self.onClose = onClose
    self.start = start
    return self
end

function History:Build()
    local out = {}
    for _, name in ipairs(Buffers.ORDER) do
        local section = L("buffer_" .. name)
        for _, text in ipairs(Buffers.Lines(name)) do
            local c = Controls.Text(text)
            c.section = section
            c.buffer = name
            out[#out + 1] = c
        end
    end
    return out
end

-- The first line of the start buffer (else of the first buffer with lines), with its section.
function History:Open()
    self:Refresh()
    if #self.controls == 0 then
        Speech.Say(L("screen_empty", { title = self.title }))
        return
    end
    self.index = 1
    for i, c in ipairs(self.controls) do
        if c.buffer == self.start then
            self.index = i
            break
        end
    end
    Speech.Say(Strings.Sentences({ self.title, self:SectionIntro(self.index), self.controls[self.index].Describe() }))
end

function History:Help()
    return { L("help_history") }
end

function History:OnKey(combo)
    if combo == "ESCAPE" then
        Speech.Say(L("closed"), { interrupt = true })
        if self.onClose then self.onClose() end
        return true
    end
    if combo == "RETURN" or combo == "SPACE" or combo == "KP_ENTER" then
        local c = self:Current()
        if c then self:Speak(c) end
        return true
    end
    return ListScreen.OnKey(self, combo)
end

return History
