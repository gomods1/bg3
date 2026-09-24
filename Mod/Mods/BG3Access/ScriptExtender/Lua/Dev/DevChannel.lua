-- Development command channel (debug builds only): the test harness (tools/game.py lua ...) writes
-- BG3Access/dev/<context>.lua whose first line is "-- seq <n>"; we run each new sequence once and
-- write the printed output and return value to BG3Access/dev/<context>.out.
local Log = Ext.Require("Core/Log.lua")

local DevChannel = {}

local function serialize(v)
    if type(v) == "table" or type(v) == "userdata" then
        local ok, s = pcall(Ext.DumpExport, v)
        if ok and s then return s end
    end
    return tostring(v)
end

function DevChannel.Start(context)
    local inPath = "BG3Access/dev/" .. context .. ".lua"
    local outPath = "BG3Access/dev/" .. context .. ".out"
    local function readSeq()
        local code = Ext.IO.LoadFile(inPath)
        if not code then return nil end
        return code:match("^%-%- seq (%d+)"), code
    end
    -- A file left over from an earlier session is marked as already run.
    local lastSeq = readSeq()
    local lastPoll = 0

    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Timer.MonotonicTime()
        if now - lastPoll < 200 then return end
        lastPoll = now
        local seq, code = readSeq()
        if not seq or seq == lastSeq then return end
        lastSeq = seq

        local out = {}
        local env = setmetatable({
            P = function(...)
                local parts = {}
                for i = 1, select("#", ...) do parts[#parts + 1] = serialize(select(i, ...)) end
                out[#out + 1] = table.concat(parts, "\t")
            end,
        }, { __index = _G, __newindex = _G })
        local fn, err = Ext.Utils.LoadString(code, env)
        if not fn then
            out[#out + 1] = "compile error: " .. tostring(err)
        else
            local res = table.pack(pcall(fn))
            if not res[1] then
                out[#out + 1] = "runtime error: " .. tostring(res[2])
            else
                for i = 2, res.n do out[#out + 1] = "=> " .. serialize(res[i]) end
            end
        end
        Ext.IO.SaveFile(outPath, table.concat(out, "\n") .. "\n")
    end)
    Log.Info("dev channel listening: " .. inPath)
end

return DevChannel
