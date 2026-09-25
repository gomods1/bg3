-- Waypoints (mod menu): the places the party can travel to at once (Game/Map.Waypoints), as the
-- world map offers them; in camp the first is "Abandonar el campamento". Enter travels there.
local Map = Ext.Require("Game/Map.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Waypoints = ListScreen.Extend()

function Waypoints.New(onClose)
    local self = setmetatable(ListScreen.New("(waypoints)", L("screen_waypoints")), Waypoints)
    self.onClose = onClose
    return self
end

function Waypoints:Build()
    local out = {}
    for i, w in ipairs(Map.Waypoints()) do
        out[#out + 1] = Controls.Button({
            label = w.name,
            activate = function(done)
                if Map.GoToWaypoint(i) then
                    Speech.Say(L("travelling_to", { name = w.name }), { interrupt = true })
                    if self.onClose then self.onClose() end
                else
                    done(false, "reason_unavailable")
                end
            end,
        })
    end
    if #out == 0 then out[1] = Controls.Text(L("waypoints_none")) end
    return out
end

return Waypoints
