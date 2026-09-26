-- Client-side writer for the Lua -> native channel (gate.md 4.3).
-- Each Send is one Ext.IO.SaveFile to BG3Access/bridge/out.msg; the native bridge hooks that path and
-- turns the write into a pipe message (no disk I/O). Without the bridge the file lands on disk and
-- nothing is spoken, so Bridge.Check() reports it.
local Log = Ext.Require("Core/Log.lua")
local Strings = Ext.Require("Core/Strings.lua")

local Bridge = {}

local CHANNEL_PATH = "BG3Access/bridge/out.msg"
local STATUS_PATH = "BG3Access/bridge_status.txt"

Bridge.Version = "0.1.0"
Bridge.Ok = nil -- nil = unknown, true/false after Check
-- When the last "mouse click" was sent (MonotonicTime ms): the bridge presses the button ~220 ms
-- later at wherever the cursor is then, so nothing may move the cursor away before that.
Bridge.LastClickAt = 0

function Bridge.Escape(text)
    return (tostring(text):gsub("\\", "\\\\"):gsub("\r?\n", "\\n"))
end

function Bridge.Send(line)
    if line:sub(1, 11) == "mouse click" then Bridge.LastClickAt = Ext.Timer.MonotonicTime() end
    local ok = Ext.IO.SaveFile(CHANNEL_PATH, line .. "\n")
    if not ok then Log.Error("bridge write failed: " .. line) end
    return ok
end

function Bridge.Log(text)
    Bridge.Send("log " .. Bridge.Escape(text))
end

-- Hello round trip: send "hello <version>", then look for the bridge's answer in its status file.
function Bridge.Check(onResult)
    local token = Bridge.Version .. "-" .. tostring(Ext.Timer.MonotonicTime())
    local t0 = Ext.Timer.MicrosecTime()
    Bridge.Send("hello " .. token)
    local sendUs = Ext.Timer.MicrosecTime() - t0
    local tries = 0
    local function poll()
        tries = tries + 1
        local status = Ext.IO.LoadFile(STATUS_PATH)
        if status and status:find("hello " .. token, 1, true) then
            Bridge.Ok = true
            Log.Info(string.format("bridge answered after %d polls; SaveFile took %.0f us", tries, sendUs))
            if onResult then onResult(true, status) end
        elseif tries < 20 then
            Ext.Timer.WaitForRealtime(100, poll)
        else
            Bridge.Ok = false
            Log.Error(Strings.Get("bridge_missing"))
            if onResult then onResult(false, status) end
        end
    end
    Ext.Timer.WaitForRealtime(100, poll)
end

return Bridge
