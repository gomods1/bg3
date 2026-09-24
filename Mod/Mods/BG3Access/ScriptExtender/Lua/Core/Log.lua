-- Logging: the SE console/log via _P, and (client only) the bridge log for timing-sensitive lines.
local Log = {}

function Log.Info(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    _P("[BG3Access] " .. table.concat(parts, " "))
end

function Log.Error(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring(select(i, ...)) end
    Ext.Utils.PrintError("[BG3Access] " .. table.concat(parts, " "))
end

-- Runs fn with pcall; logs the error with a label instead of letting it escape into an SE event.
function Log.Guard(label, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then Log.Error(label .. ": " .. tostring(err)) end
    return ok, err
end

return Log
