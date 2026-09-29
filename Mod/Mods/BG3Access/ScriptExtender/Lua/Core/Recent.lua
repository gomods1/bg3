-- "Said this a moment ago": a set of texts that forgets each entry after a while. The game repeats
-- itself (a banner sent twice, a log line logged twice, Volo's song every few seconds), so several
-- readers keep such a set; this is the one implementation. Entries older than the window are
-- dropped as the set is used, so it never grows past what was said within the window.
local Recent = {}
Recent.__index = Recent

-- windowMs: how long an entry is remembered.
function Recent.New(windowMs)
    return setmetatable({ window = windowMs, at = {} }, Recent)
end

local function prune(self, now)
    for text, at in pairs(self.at) do
        if now - at >= self.window then self.at[text] = nil end
    end
end

-- Records text now; returns true when the same text was recorded within the window before (so
-- the caller can drop the repeat). now defaults to the game's monotonic time.
function Recent:Take(text, now)
    now = now or Ext.Timer.MonotonicTime()
    prune(self, now)
    local last = self.at[text]
    self.at[text] = now
    return last ~= nil
end

-- Whether text was recorded within the window (without recording it).
function Recent:Has(text, now)
    now = now or Ext.Timer.MonotonicTime()
    local last = self.at[text]
    return last ~= nil and now - last < self.window
end

function Recent:Clear()
    self.at = {}
end

return Recent
