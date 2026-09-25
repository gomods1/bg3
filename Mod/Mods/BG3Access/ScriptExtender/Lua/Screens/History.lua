-- History (mod menu): the review buffers (Core/Buffers), newest line first. Up/Down read the lines,
-- Left/Right switch buffers (empty ones are skipped), Home/End jump, Escape closes. Opens on the
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
    local self = setmetatable(ListScreen.New("(history)", ""), History)
    self.onClose = onClose
    self.buffer = start
    if #Buffers.Lines(start or "") == 0 then self.buffer = self:NextBuffer(0, 1) or Buffers.ORDER[1] end
    self.title = self:BufferTitle()
    return self
end

function History:BufferTitle()
    return L("screen_history", { buffer = L("buffer_" .. self.buffer), n = #Buffers.Lines(self.buffer) })
end

-- The next non-empty buffer after position i in Buffers.ORDER going step (1 or -1), or nil.
function History:NextBuffer(i, step)
    local n = #Buffers.ORDER
    for k = 1, n do
        local j = ((i - 1 + step * k) % n) + 1
        local name = Buffers.ORDER[j]
        if name ~= self.buffer and #Buffers.Lines(name) > 0 then return name end
    end
    return nil
end

function History:Build()
    local out = {}
    for i, text in ipairs(Buffers.Lines(self.buffer)) do
        out[i] = Controls.Text(text)
    end
    return out
end

function History:Switch(step)
    local pos = 1
    for i, name in ipairs(Buffers.ORDER) do
        if name == self.buffer then pos = i end
    end
    local name = self:NextBuffer(pos, step)
    if not name then
        Speech.Say(L("history_no_other"), { interrupt = true })
        return
    end
    self.buffer = name
    self.title = self:BufferTitle()
    self.index = 0
    self:Refresh()
    Speech.Say(self:BufferTitle(), { interrupt = true })
end

function History:Summary()
    return self:BufferTitle()
end

function History:Help()
    return { L("help_history") }
end

function History:OnKey(combo)
    if combo == "LEFT" then self:Switch(-1) return true end
    if combo == "RIGHT" then self:Switch(1) return true end
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
