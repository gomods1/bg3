-- Review buffers (template_rpg 11.2): named lists of what the mod announced, newest first, read
-- back on demand through the History screen (Screens/History, from the mod menu). Event-fed:
--   events    everything the mod announced unasked (turns, combat start/end, switches...), and
--             every line of the other buffers;
--   combat    the game's combat log lines;
--   dialogue  the conversation so far (cleared when a new one starts).
-- Speech.Event(text, buffer) speaks a line and records it.
local Buffers = {}

local MAX_LINES = 300

Buffers.ORDER = { "events", "combat", "dialogue" }

local lines = {}  -- name -> { newest first }
local serial = {} -- name -> number of lines ever added (screens notice new content)

for _, name in ipairs(Buffers.ORDER) do
    lines[name], serial[name] = {}, 0
end

function Buffers.Add(name, text)
    if not lines[name] or not text or text == "" then return end
    table.insert(lines[name], 1, text)
    if #lines[name] > MAX_LINES then table.remove(lines[name]) end
    serial[name] = serial[name] + 1
end

function Buffers.Clear(name)
    if not lines[name] then return end
    lines[name] = {}
    serial[name] = serial[name] + 1
end

-- The lines of buffer name, newest first (do not modify).
function Buffers.Lines(name)
    return lines[name] or {}
end

function Buffers.Serial(name)
    return serial[name] or 0
end

return Buffers
