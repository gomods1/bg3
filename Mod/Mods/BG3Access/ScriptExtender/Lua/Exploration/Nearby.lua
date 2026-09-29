-- "Nearby" list (gate.md 8.3, mod menu): what the game's own highlight shows (Game/Highlights),
-- plus doors (Game/Doors: the highlight does not show them) with their open/closed/locked state,
-- plus the other things a sighted player could click that the highlight leaves out (scenery,
-- characters: Game/Interactables). Sections (NAVIGATION.md, Tab / Shift+Tab): everything nearest
-- first, then one per kind (characters, containers, loot, doors, traps, other), empty ones left out.
-- Enter walks there and uses it like a click (Exploration/Travel): talk,
-- open, loot, open or close a door. TODO: make sure hidden (secret) doors are not listed before
-- the party found them.
local Entities = Ext.Require("Game/Entities.lua")
local Highlights = Ext.Require("Game/Highlights.lua")
local Doors = Ext.Require("Game/Doors.lua")
local Interactables = Ext.Require("Game/Interactables.lua")
local Traps = Ext.Require("Game/Traps.lua")
local Items = Ext.Require("Game/Items.lua")
local Relations = Ext.Require("Game/Relations.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local PlaceList = Ext.Require("Exploration/PlaceList.lua")

local L = Strings.Get

local Nearby = ListScreen.Extend(PlaceList)

local CONTAINER_STATES = { NotExplored = "state_unexplored", Empty = "state_empty" }
local DOOR_RADIUS = 20   -- meters
local DOOR_MAX_DY = 4    -- meters above/below the character
local DOOR_SETTLE_MS = 2500
local OTHER_RADIUS = 40  -- meters, for things the highlight leaves out
local OTHER_MAX_DY = 8
local CATEGORIES = { "all", "character", "container", "loot", "door", "trap", "other" }

local function stateWords(e)
    local parts = {}
    if e.category == "character" and Entities.IsPartyMember(e.uuid) then parts[#parts + 1] = L("marker_CharacterParty") end
    if e.category == "character" and Entities.IsDead(e.uuid) then parts[#parts + 1] = L("state_dead") end
    if e.category == "character" and Entities.WantsToTalk(e.uuid) then parts[#parts + 1] = L("state_wants_to_talk") end
    local relation = e.category == "character" and not Entities.IsPartyMember(e.uuid) and Relations.Of(e.uuid)
    if relation == "enemy" or relation == "ally" then parts[#parts + 1] = L("relation_" .. relation) end
    if e.door then
        parts[#parts + 1] = L("kind_door")
        if e.door.locked then parts[#parts + 1] = L("state_locked") end
        parts[#parts + 1] = L(e.door.opened and "state_open" or "state_closed")
    end
    if e.category == "trap" then parts[#parts + 1] = L("kind_trap") end
    local info = e.category ~= "door" and e.category ~= "character" and e.uuid and Items.WorldInfo(e.uuid)
    if info and info.locked then parts[#parts + 1] = L("state_locked") end
    if CONTAINER_STATES[e.containerState or ""] then parts[#parts + 1] = L(CONTAINER_STATES[e.containerState]) end
    if e.stealing then parts[#parts + 1] = L("state_stealing") end
    return Strings.List(parts)
end

-- After using a door, say what the click did once it had time to move.
local function announceDoor(e)
    Ext.Timer.WaitForRealtime(DOOR_SETTLE_MS, function()
        Doors.States({ e.uuid }, function(states)
            local st = states[e.uuid]
            if st then Speech.Say(Strings.List({ e.name, L(st.opened and "state_open" or "state_closed") })) end
        end)
    end)
end

local FAR_RADIUS = 150
local FAR_MAX_DY = 30

-- Asks how the characters listed stand toward the party (said as "enemy" / "ally"), then calls
-- onResult(entries).
local function withRelations(entries, onResult)
    local uuids = {}
    for _, e in ipairs(entries) do
        if e.category == "character" and e.uuid and not Entities.IsPartyMember(e.uuid) then uuids[#uuids + 1] = e.uuid end
    end
    Relations.Fetch(uuids, function() onResult(entries) end)
end

-- Leaves out the traps the party has not discovered (a sighted player cannot see them either),
-- asks the characters' relations, then calls onResult(entries) on a later frame.
local function withoutHiddenTraps(entries, onResult)
    local uuids = {}
    for _, e in ipairs(entries) do
        if e.category == "trap" then uuids[#uuids + 1] = e.uuid end
    end
    if #uuids == 0 then
        withRelations(entries, onResult)
        return
    end
    Traps.States(uuids, function(states)
        local out = {}
        for _, e in ipairs(entries) do
            if e.category ~= "trap" or (states[e.uuid] and states[e.uuid].discovered) then out[#out + 1] = e end
        end
        withRelations(out, onResult)
    end)
end

-- Whether a thing at pos is within the nearby list's reach of me (radius, maxDy).
local function withinReach(pos, me, radius, maxDy)
    return Entities.Distance(pos, me) <= radius and math.abs(pos[2] - me[2]) <= maxDy
end

-- Farther things (a separate command): usable things, doors and characters up to FAR_RADIUS
-- meters that the nearby list leaves out, to choose a destination (the game only loads so far:
-- 150 m on the beach). That includes close things far above or below (a sign 28 m away and
-- 8.6 m below a platform in the Blighted Village, 2026-09-25) and doors past DOOR_RADIUS.
function Nearby.GatherFar(onResult)
    local me = Entities.Position(Entities.Controlled())
    local entries = {}
    for _, o in ipairs(me and Interactables.Near(me, FAR_RADIUS, FAR_MAX_DY) or {}) do
        if not withinReach(o.position, me, OTHER_RADIUS, OTHER_MAX_DY) then
            entries[#entries + 1] = { uuid = o.uuid, name = o.name, describeExtra = stateWords, category = o.category }
        end
    end
    for _, d in ipairs(me and Doors.Near(me, FAR_RADIUS) or {}) do
        if not withinReach(d.position, me, DOOR_RADIUS, DOOR_MAX_DY) and math.abs(d.position[2] - me[2]) <= FAR_MAX_DY then
            entries[#entries + 1] = { uuid = d.uuid, name = d.name or L("kind_door"), describeExtra = stateWords, afterUse = announceDoor, category = "door" }
        end
    end
    withoutHiddenTraps(entries, onResult)
end

-- Collects the entries and calls onResult(entries) on a later frame.
function Nearby.Gather(onResult)
    Highlights.Read(function(entries)
        for _, e in ipairs(entries) do
            e.describeExtra = stateWords
            e.category = Interactables.Category(e.uuid)
        end
        local me = Entities.Position(Entities.Controlled())
        local listed, doors, uuids = {}, {}, {}
        for _, e in ipairs(entries) do listed[e.uuid] = true end
        for _, o in ipairs(me and Interactables.Near(me, OTHER_RADIUS, OTHER_MAX_DY) or {}) do
            if not listed[o.uuid] then
                listed[o.uuid] = true
                entries[#entries + 1] = { uuid = o.uuid, name = o.name, describeExtra = stateWords, category = o.category }
            end
        end
        for _, d in ipairs(me and Doors.Near(me, DOOR_RADIUS) or {}) do
            if not listed[d.uuid] and math.abs(d.position[2] - me[2]) <= DOOR_MAX_DY then
                doors[#doors + 1] = { uuid = d.uuid, name = d.name or L("kind_door"), describeExtra = stateWords, afterUse = announceDoor, category = "door" }
                uuids[#uuids + 1] = d.uuid
            end
        end
        if #uuids == 0 then
            withoutHiddenTraps(entries, onResult)
            return
        end
        Doors.States(uuids, function(states)
            for _, d in ipairs(doors) do
                d.door = states[d.uuid] or {}
                entries[#entries + 1] = d
            end
            withoutHiddenTraps(entries, onResult)
        end)
    end)
end

-- far: the "farther things" list (another title).
function Nearby.New(entries, onClose, open, far)
    local self = setmetatable(PlaceList.New("(nearby)", L(far and "screen_farther" or "screen_nearby"), entries, onClose, open), Nearby)
    self.baseTitle = far and "screen_farther" or "screen_nearby"
    self.all = self.entries
    return self
end

-- In the "all" view, scenery that repeats (a dozen candles and braziers in the goblin sanctum,
-- 2026-09-24) is one entry: the nearest, "and 11 more"; the "other" view lists each one.
local GROUP_MIN = 3

local function groupedScenery(entries)
    local counts = {}
    for _, e in ipairs(entries) do
        if e.category == "other" then counts[e.name or ""] = (counts[e.name or ""] or 0) + 1 end
    end
    local out, seen = {}, {}
    for _, e in ipairs(entries) do
        local n = e.category == "other" and counts[e.name or ""] or 1
        if n < GROUP_MIN then
            out[#out + 1] = e
        elseif not seen[e.name or ""] then
            seen[e.name or ""] = true
            local g = setmetatable({}, { __index = e })
            g.describeExtra = function(x)
                return Strings.List({ e.describeExtra and e.describeExtra(e), L("nearby_group_more", { n = n - 1 }) })
            end
            out[#out + 1] = g
        end
    end
    return out
end

-- One section per kind with something in it, "all" first (repeated scenery grouped there).
function Nearby:Build()
    local out = {}
    for _, name in ipairs(CATEGORIES) do
        local shown = {}
        for _, e in ipairs(self.all) do
            if name == "all" or e.category == name then shown[#shown + 1] = e end
        end
        if name == "all" then shown = groupedScenery(shown) end
        if #shown > 0 then
            self.entries = shown
            local section = L("category_" .. name)
            for _, c in ipairs(PlaceList.Build(self)) do
                c.section = section
                out[#out + 1] = c
            end
        end
    end
    self.entries = self.all
    self.title = L(self.baseTitle)
    return out
end

function Nearby:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_nearby")
    return lines
end

return Nearby
