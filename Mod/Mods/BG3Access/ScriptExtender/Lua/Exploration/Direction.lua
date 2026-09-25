-- Where something is from the controlled character, in the camera's frame (template_rpg 16:
-- directions a blind player can act on): one of eight directions, "ahead" being away from the
-- camera (the arrow keys of the place cursor use the same frame), and the height when it differs
-- a lot ("up", "down"). Game/Camera gives the frame; the camera turns with Q/E.
local Camera = Ext.Require("Game/Camera.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Direction = {}

local HEIGHT_METERS = 2 -- less height difference than this is "on the same level"
local SECTORS = { "dir_ahead", "dir_ahead_right", "dir_right", "dir_behind_right", "dir_behind", "dir_behind_left", "dir_left", "dir_ahead_left" }

-- Direction words from point a to point b ({x, y, z}), e.g. "ahead left" or "behind, 5 up";
-- nil when the camera frame is unknown or the points are the same.
function Direction.Words(a, b)
    local right, forward = Camera.GroundAxes()
    if not (right and a and b) then return nil end
    local dx, dz = b[1] - a[1], b[3] - a[3]
    if dx * dx + dz * dz < 0.25 then return nil end
    local ahead = dx * forward[1] + dz * forward[2]
    local side = dx * right[1] + dz * right[2]
    -- 0 degrees = ahead, clockwise (to the right).
    local angle = math.deg(math.atan(side, ahead)) % 360
    local sector = math.floor((angle + 22.5) / 45) % 8 + 1
    local parts = { L(SECTORS[sector]) }
    local dy = b[2] - a[2]
    if dy >= HEIGHT_METERS then parts[#parts + 1] = L("place_up", { n = math.floor(dy + 0.5) }) end
    if dy <= -HEIGHT_METERS then parts[#parts + 1] = L("place_down", { n = math.floor(-dy + 0.5) }) end
    return Strings.List(parts)
end

-- Compass direction from a to b as the world map shows it (north = +z up the map, east = +x;
-- checked 2026-09-24), e.g. "North-west"; nil when the points are the same.
local COMPASS = { "compass_north", "compass_north_east", "compass_east", "compass_south_east", "compass_south", "compass_south_west", "compass_west", "compass_north_west" }
function Direction.Compass(a, b)
    if not (a and b) then return nil end
    local dx, dz = b[1] - a[1], b[3] - a[3]
    if dx * dx + dz * dz < 0.25 then return nil end
    local angle = math.deg(math.atan(dx, dz)) % 360 -- 0 = north, clockwise
    return L(COMPASS[math.floor((angle + 22.5) / 45) % 8 + 1])
end

return Direction
