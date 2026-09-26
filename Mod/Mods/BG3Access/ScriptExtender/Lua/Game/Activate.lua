-- Activation ladder for UI elements (gate.md 5.5):
--  1. the element's bound ICommand, executed with nil or with its CommandParameter binding resolved
--     (XAML index paramPath/paramElement: "{Binding SelectedItem, ElementName=PresetList}");
--  2. the game's own key for the element's BoundEvent (e.g. UIAccept -> Enter), injected;
--  3. a cursor warp + click by the native bridge at a measured position, verified with IsMouseOver
--     before clicking. Needed for CustomEvent buttons: SE v32 cannot pass a string parameter to a
--     command (boxed values are converted to Lua strings both ways), and has no PointToScreen yet
--     (added upstream after v32), so positions come from ClickHints (fractions of the window).
-- Failure reasons are Strings keys (reason_*), spoken by the caller.
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")
local Input = Ext.Require("Game/Input.lua")
local Highlights = Ext.Require("Game/Highlights.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Camera = Ext.Require("Game/Camera.lua")
local Picking = Ext.Require("Game/Picking.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Config = Ext.Require("Core/Config.lua")
local Timer = Ext.Require("Core/Timer.lua")

local Activate = {}

-- [widget][element] = { fx, fy }: centre of the element as a fraction of the client area, measured
-- on 2560x1600 (16:10). Wrong or stale hints fail safely: the hover check refuses the click.
local ClickHints = {
    Eula = { AcceptBtn = { 0.500, 0.931 }, ToSButton = { 0.097, 0.931 }, PrivacyButton = { 0.220, 0.931 } },
    SensitiveSettings = { NextButton = { 0.500, 0.931 } },
    GammaCalibration = { AcceptButton = { 0.500, 0.931 }, ResetButton = { 0.903, 0.931 } },
    MainMenu = { ModsButton = { 0.222, 0.655 }, OptionsButton = { 0.222, 0.715 }, CreditsButton = { 0.222, 0.759 } },
    CharacterLevelUp = { finishLevelUpButton = { 0.566, 0.930 } }, -- "Aceptar" (screenshot, barbarian 2)
    MakeCamp = { AutoSelectBtn = { 0.500, 0.795 } }, -- "Selección automática" (screenshot, camp)
    -- The mod manager's first page (mod.io's terms): Close (screenshot 2026-09-24). Accepting is
    -- the player's decision about an online service: the mod only reads it.
    ModBrowserSplashScreen = { CloseButton = { 0.434, 0.804 } },
    -- The game menu (Escape), buttons whose CustomEvent takes a string (screenshot 2026-09-24,
    -- opened during character creation; all eight buttons shown).
    SaveGame = { NewSaveBtn = { 0.296, 0.185 } }, -- "Nueva partida guardada" (screenshot 2026-09-24)
    GameMenu = {
        ResumeButton = { 0.500, 0.434 }, LoadGameButton = { 0.500, 0.526 }, ConnectivityButton = { 0.500, 0.579 },
        CurrentGameSettingsButton = { 0.500, 0.619 }, OptionsButton = { 0.500, 0.660 },
    },
    -- Options menu tab bar (verified by hover on every tab, controller tab hidden).
    GameOptions = {
        gameplayButton = { 0.202, 0.040 }, keybindingButton = { 0.322, 0.040 }, videoButton = { 0.441, 0.040 },
        audioButton = { 0.560, 0.040 }, interfaceButton = { 0.680, 0.040 }, accessibilityButton = { 0.799, 0.040 },
    },
}
-- Widgets sharing another widget's layout use its hints.
local HintAliases = {
    KeybindingOptions = "GameOptions", ControllerOptions = "GameOptions", VideoOptions = "GameOptions",
    AudioOptions = "GameOptions", InterfaceOptions = "GameOptions", AccessibilityOptions = "GameOptions",
}

local function trace(fmt, ...)
    if Config.Get("debug.traceClicks") then Bridge.Log(string.format(fmt, ...)) end
end

-- Small search around the hint, nearest first.
local OFFSETS = { { 0, 0 }, { 0, -0.012 }, { 0, 0.012 }, { -0.03, 0 }, { 0.03, 0 }, { 0, -0.025 }, { 0, 0.025 } }

local HOVER_WAIT_MS = 250 -- hover state follows a cursor warp within a few frames (measured: <600 ms)
local HOVER_TRIES = 4

local function clickVerified(widget, elName, onDone)
    local hints = ClickHints[widget] or ClickHints[HintAliases[widget] or ""]
    local hint = hints and hints[elName]
    if not hint then
        onDone(false, "reason_no_position")
        return
    end
    local i = 0
    local function try()
        i = i + 1
        if i > #OFFSETS then
            onDone(false, "reason_no_cursor")
            return
        end
        local fx, fy = hint[1] + OFFSETS[i][1], hint[2] + OFFSETS[i][2]
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        local checks = 0
        local function check()
            checks = checks + 1
            local el = Ui.FindElement(widget, elName)
            if not el then
                onDone(false, "reason_gone")
            elseif Vm.Get(el, "IsMouseOver") == true then
                Bridge.Send("mouse click left")
                onDone(true)
            elseif checks < HOVER_TRIES then
                Timer.After(HOVER_WAIT_MS, check)
            else
                try()
            end
        end
        Timer.After(HOVER_WAIT_MS, check)
    end
    try()
end

local function walk(obj, path)
    for part in path:gmatch("[^.]+") do
        if obj == nil then return nil end
        obj = Vm.Get(obj, part)
    end
    return obj
end

-- The command parameter an index entry needs: ok=false when it cannot be resolved (a binding the
-- mod does not understand, or a literal string, which Lua cannot pass).
local function resolveParam(widget, el, entry)
    if entry.param then return false end
    if not entry.paramPath then return true, nil end
    if entry.paramPath == "?" or entry.paramPath:find("^FocusedElement") then return false end
    local source = entry.paramElement and Ui.FindElement(widget, entry.paramElement) or Vm.Get(el, "DataContext")
    if entry.paramPath == "." then return (source and true or false), source end
    local v = walk(source, entry.paramPath)
    return type(v) == "userdata", v
end

-- false when the element's own command says it cannot run now; true otherwise (also when unknown).
function Activate.Available(widget, elName, entry)
    if not (entry and entry.command) then return true end
    local el = Ui.FindElement(widget, elName)
    local ok, param = resolveParam(widget, el, entry)
    if not ok then return true end
    return Vm.CanExecute(el and Vm.Get(el, "Command"), param) ~= false
end

-- entry: XAML index item { name=, command=, param= }. onDone(ok, reasonKey) may run later.
function Activate.Element(widget, elName, entry, onDone)
    onDone = onDone or function() end
    local el = Ui.FindElement(widget, elName)
    if not el then
        onDone(false, "reason_gone")
        return
    end
    if entry and entry.command then
        local cmd = Vm.Get(el, "Command")
        local ok, param = resolveParam(widget, el, entry)
        if cmd and ok then
            if Vm.CanExecute(cmd, param) == false then
                onDone(false, "reason_unavailable")
                return
            end
            if Vm.Execute(cmd, param, widget .. "." .. elName) then
                onDone(true)
                return
            end
        end
    end
    local key = entry and entry.boundEvent and Input.ScancodeFor(entry.boundEvent)
    if key then
        Activate.Key(key)
        onDone(true)
        return
    end
    clickVerified(widget, elName, onDone)
end

-- Rung 3 alone: verified click on a named element of a widget. onDone(ok, reasonKey).
function Activate.Click(widget, elName, onDone)
    clickVerified(widget, elName, onDone or function() end)
end

-- Verified click on one item of a list or grid of item buttons (spells to learn, ...). Needed where
-- the button's command parameter is a MultiBinding (e.g. SelectSpell [selector, spell]): Lua can
-- neither read nor build it (SE v32 passes collections only as Lua arrays), so the button itself
-- must be pressed. Tried and failed (2026-09-24): SelectSpell with the spell alone, with a Lua-built
-- collection, with an ItemCollection; IsDefault + Enter.
-- The item's screen position is predicted from the grid: the first cell's centre (learned from an
-- earlier hover in this session, else GridHints) plus the item's column and row times the cell
-- size (UI units, scaled by Ui.Scale). Each probe reads which item the cursor is actually over,
-- so a wrong guess corrects itself: over item h, the first cell is h's cells away. The click
-- happens only while the target reports IsMouseOver.
-- IsMouseOver lags a cursor warp by more than 230 ms (measured 2026-09-24: after a move from item
-- 14 to item 13, item 14 still read hovered; trusting it moved the cursor onto item 12 and the
-- wrong spell was chosen). A reading counts only once it differs from the reading taken just
-- before the move, or after GRID_SETTLE_MS.
-- grid = { name = key for hints and learned positions, cells = function() -> { elements } in
-- layout order (shown ones only; valid this tick), isTarget = function(el) -> bool, button =
-- "left" (default) or "right" }. onDone(ok, reasonKey, fx, fy) with where it clicked.
local GridHints = {
    -- First "available" spell of the level-up spell panel (Gale, wizard 2; screenshot 2026-09-24).
    CharacterLevelUp = { SelectAvailableSpell = { 0.1883, 0.4400 }, DeselectAddedSpell = { 0.2648, 0.3600 } },
    -- The first reaction of the reaction prompt (Tav, one reaction; screenshot 2026-09-24).
    ReactionDecisionPopup = { ReactButton = { 0.5172, 0.6788 } },
    -- The first cell of the character panel's inventory grid (Tav, Blighted Village; screenshot
    -- 2026-09-24).
    CharacterPanel = { invCellBase = { 0.4922, 0.2225 } },
    -- The first bonus of the dice roll's bonus list (Shadowheart's Guidance alone; screenshot
    -- 2026-09-24, Kagha's check).
    ActiveRoll = { boostmodlist = { 0.5000, 0.9569 } },
}
-- Widgets laid out like another one's grids (the same CCLib_k spell panel in the same left
-- panel; verified for character creation 2026-09-24: a wizard's cantrips and level 1 spells,
-- item 21 of 23 hit on the first probe).
local GridHintAliases = { CharacterCreation = "CharacterLevelUp" }
local learnedGrids = {} -- [widget .. "/" .. name] = { fx, fy } of the first cell
-- Probe offsets from the predicted point, in cells: vertical first (text above a grid wraps
-- differently from one character or language to another), then sideways.
local GRID_OFFSETS = {
    { 0, 0 }, { 0, -0.5 }, { 0, 0.5 }, { 0, -1 }, { 0, 1 }, { 0, -1.5 }, { 0, 1.5 }, { 0, -2 }, { 0, 2 },
    { 0, -3 }, { 0, 3 }, { -0.5, 0 }, { 0.5, 0 },
}
local GRID_WAIT_MS = 60
local GRID_SETTLE_MS = 700
local GRID_CORRECTIONS = 3

-- Column/row geometry of cell i: { col, row } (0-based), and the cell size as client fractions.
local function gridGeometry(cells)
    local first = cells[1]
    local cell, panel = Ui.ItemCell(first)
    local cw, ch = Ui.Prop(cell, "ActualWidth") or 0, Ui.Prop(cell, "ActualHeight") or 0
    if cw <= 0 or ch <= 0 then return nil end
    local pw = Ui.Prop(panel, "ActualWidth") or cw
    local cols = math.max(1, math.floor(pw / cw + 0.01))
    local scale, w, h = Ui.Scale()
    return { cols = cols, px = cw * scale / w, py = ch * scale / h }
end

local function cellOf(geo, i)
    return (i - 1) % geo.cols, math.floor((i - 1) / geo.cols)
end

function Activate.ClickGridItem(widget, grid, onDone)
    onDone = onDone or function() end
    local key = widget .. "/" .. grid.name
    local hints = GridHints[widget] or GridHints[GridHintAliases[widget] or ""]
    local hint = hints and hints[grid.name]
    local origin = learnedGrids[key] or (hint and { hint[1], hint[2] })
    if not origin then
        onDone(false, "reason_no_position")
        return
    end
    local step, corrections = 0, 0
    local function target(cells)
        for i, el in ipairs(cells) do
            if grid.isTarget(el) then return i end
        end
        return nil
    end
    local function hoveredIn(cells)
        for i, el in ipairs(cells) do
            if Ui.Prop(el, "IsMouseOver") == true then return i end
        end
        return nil
    end
    local function try()
        step = step + 1
        local off = GRID_OFFSETS[step]
        if not off then
            onDone(false, "reason_no_cursor")
            return
        end
        local cells = grid.cells()
        local t = target(cells)
        local geo = #cells > 0 and gridGeometry(cells)
        if not (t and geo) then
            onDone(false, "reason_gone")
            return
        end
        local col, row = cellOf(geo, t)
        local fx = origin[1] + (col + off[1]) * geo.px
        local fy = origin[2] + (row + off[2]) * geo.py
        if fx < 0.01 or fx > 0.99 or fy < 0.01 or fy > 0.99 then
            try()
            return
        end
        local before = hoveredIn(cells)
        local movedAt = Ext.Utils.MonotonicTime()
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        trace("grid %s: target %d at %.4f %.4f (step %d, hovered before %s)", grid.name, t, fx, fy, step, tostring(before))
        local function check()
            local now = grid.cells()
            local hovered = hoveredIn(now)
            local waited = Ext.Utils.MonotonicTime() - movedAt
            trace("grid %s: %d ms hovered %s", grid.name, waited, tostring(hovered))
            if hovered == before and waited < GRID_SETTLE_MS then
                Timer.After(GRID_WAIT_MS, check) -- maybe the old position's state
                return
            end
            local tNow = target(now)
            if hovered and hovered == tNow then
                learnedGrids[key] = { fx - col * geo.px, fy - row * geo.py }
                Bridge.Send("mouse click " .. (grid.button or "left"))
                onDone(true, nil, fx, fy)
            elseif hovered and corrections < GRID_CORRECTIONS then
                -- Over another item: the first cell is that item's cells away from here.
                corrections = corrections + 1
                local hc, hr = cellOf(geo, hovered)
                origin = { fx - hc * geo.px, fy - hr * geo.py }
                step = 0
                try()
            else
                try()
            end
        end
        Timer.After(GRID_WAIT_MS, check)
    end
    try()
end

-- World click on an entity (gate.md 5.5 rung 4): project the entity to the screen, warp the cursor
-- there, and click only when the game's picking reports that very entity under the cursor and no
-- UI (HUD) is under it. Aim
-- points go up the body (a lying creature is picked near the floor). Points near the window edges
-- (camera edge-scroll) or behind the HUD are refused. onDone(ok, reasonKey).
local AIM_HEIGHTS = { 0.9, 0.5, 1.4, 0.2 } -- chest first; a lying creature is picked low
-- The world picking follows a cursor warp faster than UI hover: poll it more often.
local WORLD_WAIT_MS = 100
local WORLD_TRIES = 5
local REFRESH_MS = 120 -- cursor re-sent this long before a confirm click
local lastHover = nil  -- where Hover last found its target: { uuid, fx, fy }
local NUDGE = 0.002    -- fraction of the width (about 5 pixels at 2560); sign alternates
local SAFE = { left = 0.04, right = 0.96, top = 0.06, bottom = 0.84 }

-- Puts the cursor over entity uuid, verified (picking reports it, no UI under the cursor), without
-- clicking. onDone(ok, reasonKey). Used by targeting, which reads the game's preview first.
-- heights: aim points above the entity's origin, tried in order (default AIM_HEIGHTS, for
-- creatures; tall objects such as ladders pass their own: the character stands in front of the
-- ladder's foot, measured).
-- Aim points for entity uuid: its origin raised by each height, then points across its visual's
-- world box (Entities.WorldBound): an object's origin can lie under the character's feet while
-- its visible body is elsewhere (measured: Gale's rune on the beach was pickable on the rock,
-- its origin under Tav). Each point { x, y, z, quick = true for the box points }.
local BOX_FRACTIONS = {
    { 0.5, 0.5, 0.5 }, { 0.5, 0.8, 0.5 }, { 0.25, 0.5, 0.25 }, { 0.75, 0.5, 0.75 },
    { 0.25, 0.5, 0.75 }, { 0.75, 0.5, 0.25 }, { 0.5, 0.2, 0.5 },
}
local function aimPoints(uuid, heights)
    local p = Entities.Position(uuid)
    if not p then return nil end
    local out = {}
    for _, h in ipairs(heights) do out[#out + 1] = { p[1], p[2] + h, p[3] } end
    local b = Entities.WorldBound(uuid)
    if b then
        for _, f in ipairs(BOX_FRACTIONS) do
            out[#out + 1] = {
                b.min[1] + (b.max[1] - b.min[1]) * f[1],
                b.min[2] + (b.max[2] - b.min[2]) * f[2],
                b.min[3] + (b.max[3] - b.min[3]) * f[3],
                quick = true,
            }
        end
    end
    return out
end

local QUICK_TRIES = 2 -- checks per box point (they are many)

-- Only the latest Hover moves the cursor: an earlier one still searching stops silently (its
-- onDone is never called). Two searches at once fought over the cursor in targeting: the
-- preview took a minute and Sacred Flame went to the target passed on the way (Roah instead of
-- Azak, 2026-09-25).
local hoverGen = 0
function Activate.Hover(uuid, onDone, heights)
    onDone = onDone or function() end
    hoverGen = hoverGen + 1
    local gen = hoverGen
    local points = aimPoints(uuid, heights or AIM_HEIGHTS)
    if not points then
        onDone(false, "reason_gone")
        return
    end
    local i, anyOnScreen = 0, false
    local function try()
        if gen ~= hoverGen then return end
        i = i + 1
        local point = points[i]
        if not point then
            onDone(false, anyOnScreen and "reason_no_cursor" or "reason_offscreen")
            return
        end
        local fx, fy = Activate.SafeProjection(point)
        if not fx then
            try()
            return
        end
        anyOnScreen = true
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        local checks, tries = 0, point.quick and QUICK_TRIES or WORLD_TRIES
        local function check()
            if gen ~= hoverGen then return end
            checks = checks + 1
            if Activate.IsHovering(uuid) then
                lastHover = { uuid = uuid, fx = fx, fy = fy }
                onDone(true)
            elseif checks < tries then
                Timer.After(WORLD_WAIT_MS, check)
            else
                try()
            end
        end
        Timer.After(WORLD_WAIT_MS, check)
    end
    try()
end

-- A right click on entity uuid where it is verified under the cursor (Hover), as a player opens
-- its context menu. onDone(ok, reasonKey, fx, fy) with the click point. The highlight's names
-- (Game/Highlights) are hidden first: while they showed, the menu did not stay open (the Nearby
-- list had left three on, 2026-09-24).
local HIGHLIGHT_HIDE_MS = 250
function Activate.ContextClick(uuid, onDone)
    if Highlights.Hide() then
        Timer.After(HIGHLIGHT_HIDE_MS, function() Activate.ContextClick(uuid, onDone) end)
        return
    end
    Activate.Hover(uuid, function(ok, reason)
        if not ok or not lastHover then
            onDone(false, reason or "reason_no_cursor")
            return
        end
        local at = lastHover
        trace("context click on %s at %.4f %.4f", tostring(Entities.Name(uuid)), at.fx, at.fy)
        Bridge.Send("mouse click right")
        onDone(true, nil, at.fx, at.fy)
    end)
end

-- Moves the cursor off the world, onto the minimap. With nothing armed, the cursor resting on an
-- enemy in combat makes the game preview the main-hand attack: UIData.ActiveSlot is set as for an
-- armed action and the cursor text says why it cannot be used ("No tienes suficientes recursos:
-- Acción" after the action was spent), until the cursor leaves (verified 2026-09-25, worg pens;
-- Escape then opened the game menu, and the hotbar's CancelTaskCommand / ActionCancelCommand
-- changed nothing). The minimap is anchored top right: its centre measured 351 x 311 UI units
-- from that corner (2560x1600); IsMouseOver confirms it. onDone(ok) after the hover settled.
local PARK_FROM_RIGHT, PARK_FROM_TOP = 351, 311
local CLICK_LANDS_MS = 600
function Activate.Park(onDone)
    onDone = onDone or function() end
    local scale, w, h = Ui.Scale()
    if not (w > 0 and h > 0) then
        onDone(false)
        return
    end
    local fx, fy = 1 - PARK_FROM_RIGHT * scale / w, PARK_FROM_TOP * scale / h
    local function move()
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        lastHover = nil
        Timer.After(3 * HOVER_WAIT_MS, function()
            local under = Ui.WidgetUnderPointer()
            trace("cursor parked at %.4f %.4f over %s", fx, fy, tostring(under))
            onDone(under ~= nil)
        end)
    end
    -- A click just sent lands ~220 ms later where the cursor is then.
    local wait = Bridge.LastClickAt + CLICK_LANDS_MS - Ext.Timer.MonotonicTime()
    if wait > 0 then Timer.After(wait, move) else move() end
end

-- true while the cursor is over entity uuid and not over the UI.
function Activate.IsHovering(uuid)
    return Picking.IsHovered(uuid) and not Ui.WidgetUnderPointer()
end

-- Clicks on uuid where Hover found it: the cursor is moved there again first, then the hover is
-- verified again. onDone(ok, reasonKey).
-- History: clicks after keyboard use were ignored at first, which this nudge worked around. The real
-- cause (found later, 2026-09-24) is that the game swallows the first mouse button press after
-- keyboard input; the bridge now sends an unbound X1 press before every click (Native/bridge
-- mouse.rs), so the nudge is probably redundant: kept until Travel's door clicks are re-verified.
function Activate.ClickHovered(uuid, onDone)
    onDone = onDone or function() end
    if not (lastHover and lastHover.uuid == uuid) then
        onDone(false, "reason_no_cursor")
        return
    end
    -- Click a few pixels off the verified spot (sides alternate): a warp to the very same pixel
    -- produces no mouse-move event, and moving off and back again was ignored too (measured
    -- 2026-09-24); a single 5-pixel move followed by the click works. The hover is re-verified
    -- at the new spot.
    NUDGE = -NUDGE
    local fx, fy = lastHover.fx + NUDGE, lastHover.fy
    Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
    Timer.After(REFRESH_MS, function()
        if Activate.IsHovering(uuid) then
            lastHover = { uuid = uuid, fx = fx, fy = fy }
            trace("world click %s at %.4f %.4f", tostring(Entities.Name(uuid)), fx, fy)
            Bridge.Send("mouse click left")
            onDone(true)
        else
            trace("world click %s: hover lost at %.4f %.4f", tostring(Entities.Name(uuid)), fx, fy)
            onDone(false, "reason_no_cursor")
        end
    end)
end

function Activate.WorldClick(uuid, onDone, heights)
    onDone = onDone or function() end
    Activate.Hover(uuid, function(ok, reason)
        if not ok then
            onDone(false, reason or "reason_no_cursor")
            return
        end
        Activate.ClickHovered(uuid, onDone)
    end, heights)
end

-- Screen position of a world point when it is safe to click there, else nil.
function Activate.SafeProjection(p)
    local fx, fy = Camera.Project(p)
    if not fx or fx < SAFE.left or fx > SAFE.right or fy < SAFE.top or fy > SAFE.bottom then return nil end
    return fx, fy
end

-- Click on the ground at a world point (the player's click-to-move), verified: the picking ground
-- point under the cursor must satisfy accept(ground) (default: within GROUND_TOLERANCE meters of the
-- intended point). Measured: picking lands within 0.6 m of a projected ground point.
-- onDone(ok, reasonKey, blockerUuid): when a character or item is under the cursor the click is
-- refused with "reason_on_object" and that entity's UUID (e.g. a closed door on the way).
local GROUND_TOLERANCE = 1.5
local STEADY_METERS = 0.3 -- two picks this close: the view under the cursor is still

-- Party members walk after the leader all the time: one that steps under the cursor in the
-- ~0.2 s between the check and the click gets the click, and a click on a companion selects them
-- (Gale, on the road west of the Risen Road waypoint, 2026-09-24: "Ahora Gale" mid-walk). Ground
-- clicks keep this margin (client fractions) around each companion's body on screen.
local COMPANION_MARGIN_X = 0.025
local COMPANION_MARGIN_Y = 0.02
local BODY_HEIGHT = 1.9

-- UUID of a party member (other than the controlled character) whose body is near screen point
-- (fx, fy), or nil.
local function companionNear(fx, fy)
    local me = Entities.Controlled()
    for _, e in ipairs(Ext.Entity.GetAllEntitiesWithComponent("PartyMember")) do
        local ok, uuid = pcall(function() return e.Uuid.EntityUuid end)
        local pos = ok and uuid ~= me and Entities.Position(uuid)
        if pos then
            local x1, y1 = Camera.Project(pos)
            local x2, y2 = Camera.Project({ pos[1], pos[2] + BODY_HEIGHT, pos[3] })
            if x1 and x2 then
                local left, right = math.min(x1, x2) - COMPANION_MARGIN_X, math.max(x1, x2) + COMPANION_MARGIN_X
                local top, bottom = math.min(y1, y2) - COMPANION_MARGIN_Y, math.max(y1, y2) + COMPANION_MARGIN_Y
                if fx >= left and fx <= right and fy >= top and fy <= bottom then return uuid end
            end
        end
    end
    return nil
end

function Activate.GroundClick(p, onDone, accept)
    onDone = onDone or function() end
    local fx, fy = Activate.SafeProjection(p)
    if not fx then
        onDone(false, "reason_offscreen")
        return
    end
    local companion = companionNear(fx, fy)
    if companion then
        onDone(false, "reason_on_object", companion)
        return
    end
    Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
    local checks = 0
    local lastPick = nil
    local function check()
        checks = checks + 1
        local g = Picking.Ground()
        -- The same ground twice in a row: the camera has settled. A click while it still moved
        -- after the character stopped landed on a body beside the way and opened its loot
        -- (the road west of the Risen Road, 2026-09-24).
        local steady = g and lastPick and Entities.Distance(g, lastPick) <= STEADY_METERS and math.abs(g[2] - lastPick[2]) <= STEADY_METERS
        lastPick = g
        -- Never click when a character or item is under the cursor: that click would act on it.
        local blocker = Picking.HoveredObjectUuid()
        local overUi = Ui.WidgetUnderPointer()
        if blocker and not overUi then
            onDone(false, "reason_on_object", blocker)
            return
        end
        local ok = steady and not overUi and (accept and accept(g) or (not accept and Entities.Distance(g, p) <= GROUND_TOLERANCE and math.abs(g[2] - p[2]) <= 2))
        -- Again at click time: a companion may have walked in while the hover settled.
        if ok and companionNear(fx, fy) then ok = false end
        if ok then
            trace("ground click: aimed %.1f,%.1f,%.1f, picked %.1f,%.1f,%.1f", p[1], p[2], p[3], g[1], g[2], g[3])
            Bridge.Send("mouse click left")
            onDone(true)
        elseif checks < WORLD_TRIES then
            Timer.After(WORLD_WAIT_MS, check)
        else
            if g then trace("ground click refused: aimed %.1f,%.1f,%.1f, picked %.1f,%.1f,%.1f%s", p[1], p[2], p[3],
                g[1], g[2], g[3], overUi and " (over the UI)" or "") end
            onDone(false, "reason_no_cursor")
        end
    end
    Timer.After(WORLD_WAIT_MS, check)
end

-- Click at the screen position of a world point, but only when the entity uuid is under the cursor
-- there (e.g. a door found on a route: its origin can project away from its visible body).
function Activate.ObjectClickAt(p, uuid, onDone)
    onDone = onDone or function() end
    local fx, fy = Activate.SafeProjection(p)
    if not fx then
        onDone(false, "reason_offscreen")
        return
    end
    Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
    local checks = 0
    local function check()
        checks = checks + 1
        if Picking.IsHovered(uuid) and not Ui.WidgetUnderPointer() then
            trace("object click at %.4f %.4f on %s", fx, fy, tostring(uuid))
            Bridge.Send("mouse click left")
            onDone(true)
        elseif checks < WORLD_TRIES then
            Timer.After(WORLD_WAIT_MS, check)
        else
            trace("object click refused at %.4f %.4f: %s not under the cursor (UI: %s)", fx, fy, tostring(uuid), tostring(Ui.WidgetUnderPointer() ~= nil))
            onDone(false, "reason_no_cursor")
        end
    end
    Timer.After(WORLD_WAIT_MS, check)
end

-- Verified click on entry index of a vertical list that opened where the cursor was (a context
-- menu): cells() -> the entries' elements top-down (valid this tick); first = { fx, fy }, the
-- predicted centre of the first entry. Each probe reads which entry is under the cursor and
-- corrects the prediction from it, as ClickGridItem does. onDone(ok, reasonKey).
local LIST_TRIES = 6
function Activate.ClickListItem(cells, index, first, onDone)
    local tries = 0
    local origin = { first[1], first[2] }
    local function rowHeight(list)
        local scale, _, h = Ui.Scale()
        local eh = Ui.Prop(list[1], "ActualHeight") or 0
        return eh > 0 and eh * scale / h or 0.025
    end
    local function hoveredIn(list)
        for i, el in ipairs(list) do
            if Ui.Prop(el, "IsMouseOver") == true then return i end
        end
        return nil
    end
    local function try()
        tries = tries + 1
        local list = cells()
        if not list[index] then
            onDone(false, "reason_gone")
            return
        end
        if tries > LIST_TRIES then
            onDone(false, "reason_no_cursor")
            return
        end
        local rh = rowHeight(list)
        local fx, fy = origin[1], origin[2] + (index - 1) * rh
        local before = hoveredIn(list)
        local movedAt = Ext.Utils.MonotonicTime()
        Bridge.Send(string.format("mouse move %.4f %.4f", fx, fy))
        local function check()
            local now = cells()
            local hovered = hoveredIn(now)
            if hovered == before and hovered ~= index and Ext.Utils.MonotonicTime() - movedAt < GRID_SETTLE_MS then
                Timer.After(GRID_WAIT_MS, check)
                return
            end
            if hovered == index then
                trace("list item %d clicked at %.4f %.4f", index, fx, fy)
                Bridge.Send("mouse click left")
                onDone(true)
            elseif hovered then
                origin = { fx, fy - (hovered - 1) * rh }
                try()
            else
                -- Over none: the entries lie to the side of the guess; step right.
                origin = { origin[1] + 0.02, origin[2] }
                try()
            end
        end
        Timer.After(GRID_WAIT_MS, check)
    end
    try()
end

-- Rung 2: the game's own binding for an action on the current screen (SDL scancode name, e.g.
-- "ESCAPE"). Injected keys do not pass through the mod's KeyInput handler.
function Activate.Key(scancode)
    Ext.Input.InjectKeyPress(scancode)
end

-- Cancels the armed action with the game's cancel key, checked: one Escape left Scorching Ray and
-- a Reckless Attack armed (worg pens and torture room, 2026-09-25), so a second one is sent when
-- the action is still armed CANCEL_CHECK_MS later (never with nothing armed: that Escape would
-- open the game menu).
local CANCEL_CHECK_MS = 600
function Activate.CancelArmed()
    Activate.Key("ESCAPE")
    Timer.After(CANCEL_CHECK_MS, function()
        if Hotbar.Armed() then
            trace("armed action still armed after Escape: cancelling again")
            Activate.Key("ESCAPE")
        end
    end)
end

return Activate
