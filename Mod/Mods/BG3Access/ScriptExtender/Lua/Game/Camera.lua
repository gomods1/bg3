-- The active game camera and world-to-screen projection (client).
-- Facts (SE v32, verified 2026-09-24): entities with the "Camera" component; the one with
-- Camera.Active has Controller.Camera.ViewMatrix / ProjectionMatrix as 16-number column-major
-- arrays (glm). clip = P * V * (x, y, z, 1); NDC maps onto the whole client area (projection aspect
-- 1.6 = 2560x1600). Checked: the controlled character's feet projected to (0.500, 0.621), where the
-- screenshot shows them.
local Input = Ext.Require("Game/Input.lua")

local Camera = {}

local function active()
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("Camera")) do
        local ok, cam = pcall(function() return e.Camera.Active and e.Camera.Controller.Camera end)
        if ok and cam then return cam end
    end
    return nil
end

local function mul(M, v)
    local r = {}
    for row = 1, 4 do
        r[row] = M[row] * v[1] + M[4 + row] * v[2] + M[8 + row] * v[3] + M[12 + row] * v[4]
    end
    return r
end

-- World point { x, y, z } -> fx, fy (fractions of the client area, y down), or nil when the point
-- is behind the camera or there is no active camera.
function Camera.Project(p)
    local cam = active()
    if not cam then return nil end
    local c = mul(cam.ProjectionMatrix, mul(cam.ViewMatrix, { p[1], p[2], p[3], 1 }))
    if c[4] <= 0 then return nil end
    return (c[1] / c[4] + 1) / 2, (1 - c[2] / c[4]) / 2
end

-- Camera forward on the ground plane, as a yaw in degrees (atan2(z, x)), from the view matrix's
-- third row (V[3], V[11] in column-major order). Checked 2026-09-24: after turning to this yaw
-- toward a target, the target sits in the upper half of the screen (with the opposite sign it was
-- below the screen).
function Camera.Yaw()
    local cam = active()
    if not cam then return nil end
    local V = cam.ViewMatrix
    return math.deg(math.atan(V[11], V[3]))
end

-- How steeply the camera looks down, in degrees (the y part of the view matrix's third row).
function Camera.Pitch()
    local cam = active()
    if not cam then return nil end
    local V = cam.ViewMatrix
    return math.deg(math.asin(math.max(-1, math.min(1, V[7]))))
end

-- The camera's position in the world (from the view matrix: -R^T t).
function Camera.Position()
    local cam = active()
    if not cam then return nil end
    local V = cam.ViewMatrix
    local t1, t2, t3 = V[13], V[14], V[15]
    return { -(V[1] * t1 + V[2] * t2 + V[3] * t3), -(V[5] * t1 + V[6] * t2 + V[7] * t3),
        -(V[9] * t1 + V[10] * t2 + V[11] * t3) }
end

-- Meters from the camera to p, or nil. Against a rock or a wall the game pulls the camera in:
-- 2.4 m from Tav beside a boulder in the Blighted Village (2026-09-26), where the usual view is
-- 13 m; the screen then showed the rock and nothing of the way (every ground click refused). The
-- zoom keys (PgUp/PgDn) did nothing there; a turn with E freed it.
function Camera.Distance(p)
    local c = Camera.Position()
    if not c or not p then return nil end
    return math.sqrt((c[1] - p[1]) ^ 2 + (c[2] - p[2]) ^ 2 + (c[3] - p[3]) ^ 2)
end

-- The game's tactical camera (its O key, ToggleTacticalCamera) looks nearly straight down:
-- pitch -82 degrees against -52 to -56 for the usual view (measured 2026-09-25, worg pens).
-- In tight interiors it shows what the usual view hides behind pillars and beams.
local TACTICAL_PITCH = -70
local TACTICAL_SETTLE_MS = 1200

function Camera.IsTactical()
    local p = Camera.Pitch()
    return p ~= nil and p < TACTICAL_PITCH
end

-- Switches the tactical camera on or off with the game's key; onDone(changed) once it settled.
function Camera.SetTactical(on, onDone)
    local key = Input.ScancodeFor("ToggleTacticalCamera")
    if Camera.IsTactical() == on or not key then
        onDone(false)
        return
    end
    Ext.Input.InjectKeyPress(key)
    Ext.Timer.WaitForRealtime(TACTICAL_SETTLE_MS, function() onDone(true) end)
end

-- The camera's ground axes as unit vectors { x, z }: right (screen right) and forward (screen up),
-- from the view matrix's first and third rows. Checked 2026-09-24: 3 m along right projected
-- straight right of the character, 3 m along forward straight above it.
function Camera.GroundAxes()
    local cam = active()
    if not cam then return nil end
    local V = cam.ViewMatrix
    local function unit(x, z)
        local l = math.sqrt(x * x + z * z)
        if l < 1e-6 then return nil end
        return { x / l, z / l }
    end
    local right, forward = unit(V[1], V[9]), unit(V[3], V[11])
    if not (right and forward) then return nil end
    return right, forward
end

local function wrap(a)
    while a > 180 do a = a - 360 end
    while a < -180 do a = a + 360 end
    return a
end

-- Turning with the game's own camera keys (CameraRotateLeft Q / CameraRotateRight E; camera only,
-- no effect on the game): measured about 100 degrees per second, E increasing Camera.Yaw.
local DEGREES_PER_MS = 0.1
local TURN_TOLERANCE = 20 -- degrees
local TURN_TRIES = 3

-- Centers the camera on the controlled character with the game's own key (Home: CameraCenter in
-- the default bindings). The camera can stay behind while the character walks (measured on the
-- beach: the character at the top edge of the screen, the route ahead off screen).
local CENTER_SETTLE_MS = 400
function Camera.Center(onDone)
    Ext.Input.InjectKeyPress("HOME")
    if onDone then Ext.Timer.WaitForRealtime(CENTER_SETTLE_MS, onDone) end
end

-- Center, checked: p (the character's position) must end up on screen. Home alone can do nothing:
-- in the grove (2026-09-24, after the strange ox's scene) the camera stayed 20 m from the party
-- through Home and F1 until a camera move key (W) was pressed once; then Home worked. So when
-- Home did not bring p on screen, the camera is nudged with the game's own move key and centered
-- again. onDone(centered).
local NUDGE_KEY = "W"   -- CameraForward in the default bindings
local NUDGE_MS = 150
local function onScreen(p)
    local fx, fy = Camera.Project(p)
    return fx ~= nil and fx > 0.1 and fx < 0.9 and fy > 0.1 and fy < 0.9
end

function Camera.CenterOn(p, onDone)
    Camera.Center(function()
        if onScreen(p) then onDone(true) return end
        Ext.Input.InjectKeyDown(NUDGE_KEY)
        Ext.Timer.WaitForRealtime(NUDGE_MS, function()
            Ext.Input.InjectKeyUp(NUDGE_KEY)
            Camera.Center(function() onDone(onScreen(p)) end)
        end)
    end)
end

-- A camera closer than this to the character shows too little ground to aim at (fully zoomed
-- out it was 13.1 m in the Blighted Village, 2026-09-26).
Camera.CLOSE_METERS = 6
local ZOOM_OUT_MS = 800      -- PgDn held: 600 ms took the zoom from 4.3 m back to 13.1 m
local UNBLOCK_TURNS = 3

-- When the camera is closer than CLOSE_METERS to p (the player zoomed in, or scenery pressed it
-- in): zoom out with the game's key, then turn it a quarter at a time until it stands back.
-- onDone(tried).
function Camera.Unblock(p, onDone)
    local d = Camera.Distance(p)
    if not d or d >= Camera.CLOSE_METERS then onDone(false) return end
    local key = Input.ScancodeFor("CameraZoomOut") or "PAGEDOWN"
    Ext.Input.InjectKeyDown(key)
    Ext.Timer.WaitForRealtime(ZOOM_OUT_MS, function()
        Ext.Input.InjectKeyUp(key)
        local turns = 0
        local function check()
            local now, yaw = Camera.Distance(p), Camera.Yaw()
            if not now or not yaw or now >= Camera.CLOSE_METERS or turns >= UNBLOCK_TURNS then onDone(true) return end
            turns = turns + 1
            local a = math.rad(yaw + 90)
            Camera.TurnToward(math.cos(a), math.sin(a), check)
        end
        Ext.Timer.WaitForRealtime(300, check)
    end)
end

-- Turns the camera until it looks along the ground direction (dx, dz); onDone() afterwards.
function Camera.TurnToward(dx, dz, onDone)
    local tries = 0
    local function step()
        tries = tries + 1
        local yaw = Camera.Yaw()
        if not yaw then onDone() return end
        local delta = wrap(math.deg(math.atan(dz, dx)) - yaw)
        if math.abs(delta) <= TURN_TOLERANCE or tries > TURN_TRIES then onDone() return end
        local key = delta > 0 and "E" or "Q"
        Ext.Input.InjectKeyDown(key)
        Ext.Timer.WaitForRealtime(math.floor(math.abs(delta) / DEGREES_PER_MS), function()
            Ext.Input.InjectKeyUp(key)
            Ext.Timer.WaitForRealtime(300, step) -- the camera eases out
        end)
    end
    step()
end

return Camera
