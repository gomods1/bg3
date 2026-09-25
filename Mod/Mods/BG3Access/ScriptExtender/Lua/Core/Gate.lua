-- Build gate (gate.md 4.4): the game build and Script Extender API versions this mod was tested on.
-- Anything else keeps running (every accessor fails soft) but the player is told once.
local Log = Ext.Require("Core/Log.lua")

local Gate = {}

local TESTED = {
    -- Ext.Utils.GameVersion() for game 4.1.1.7398727 (Patch 8 hotfix 9)
    game = { ["v4.73.98.727"] = true },
    -- Ext.Utils.Version()
    se = { [32] = true },
}

-- Returns true when both versions are tested; logs what was found either way.
function Gate.Check()
    local game = tostring(Ext.Utils.GameVersion())
    local se = Ext.Utils.Version()
    local ok = TESTED.game[game] == true and TESTED.se[se] == true
    Log.Info(string.format("game %s, SE API v%s: %s", game, tostring(se), ok and "tested" or "UNTESTED"))
    return ok
end

return Gate
