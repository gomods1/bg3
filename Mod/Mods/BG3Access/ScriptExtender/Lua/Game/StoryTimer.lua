-- Story timers: the countdown the minimap shows under the objective (verified 2026-09-24, the
-- nautiloid's helm fight: "¡Alcanza el transpondedor antes de que el nautiloide se estrelle!
-- 15 turnos restantes"). Source: CurrentPlayer.SelectedCharacter.PlayerCharacterProperties
-- .StoryTimer (nil when there is none): Description (handle), TimerID (TUT_Helm_Timer),
-- TotalTime 90 and CurrentTime 0 (seconds; a turn is 6 s, so 15 turns), CurrentCount/TotalCount
-- (-1 here: counters instead of time for other timers), CountDescription.
local Vm = Ext.Require("Game/Vm.lua")
local Player = Ext.Require("Game/Player.lua")

local StoryTimer = {}

local SECONDS_PER_TURN = 6

-- { id, text, turnsLeft?, count?, total?, countText? } or nil.
function StoryTimer.Read()
    local t = Vm.Get(Vm.Get(Player.SelectedCharacter(), "PlayerCharacterProperties"), "StoryTimer")
    if not t then return nil end
    local out = { id = tostring(Vm.Get(t, "TimerID") or ""), text = Vm.Text(t, "Description") }
    local total, count = Vm.Get(t, "TotalCount") or -1, Vm.Get(t, "CurrentCount") or -1
    if total > 0 then
        out.count, out.total = math.max(count, 0), total
        out.countText = Vm.Text(t, "CountDescription")
    else
        local left = (Vm.Get(t, "TotalTime") or 0) - (Vm.Get(t, "CurrentTime") or 0)
        out.turnsLeft = math.max(0, math.ceil(left / SECONDS_PER_TURN - 0.001))
    end
    return out
end

return StoryTimer
