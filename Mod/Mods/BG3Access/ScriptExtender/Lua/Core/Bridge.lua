-- Client-side writer for the Lua -> native channel (gate.md 4.3).
-- Each Send is one Ext.IO.SaveFile to BG3Access/bridge/out.msg; the native bridge hooks that path and
-- turns the write into a pipe message (no disk I/O). Without the bridge the file lands on disk and
-- nothing is spoken, so Bridge.Check() reports it.
local Log = Ext.Require("Core/Log.lua")

local Bridge = {}

local CHANNEL_PATH = "BG3Access/bridge/out.msg"
local STATUS_PATH = "BG3Access/bridge_status.txt"

Bridge.Version = "0.1.0"
Bridge.Ok = nil -- nil = unknown, true/false after Check

function Bridge.Escape(text)
    return (tostring(text):gsub("\\", "\\\\"):gsub("\r?\n", "\\n"))
end

function Bridge.Send(line)
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
            Log.Error("BG3 Access native bridge did not answer. Speech will not work. "
                .. "Check bin\\version.dll and bin\\BG3Access\\ (install.ps1 self-test).")
            if onResult then onResult(false, status) end
        end
    end
    Ext.Timer.WaitForRealtime(100, poll)
end

return Bridge
