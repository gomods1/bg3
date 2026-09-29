-- Announces what the HUD shows a sighted player without a screen of its own (Game/Notification):
-- the notification banner (quests updated or done, and the other types as they are met), the side
-- tutorials beside the minimap (read generically: their fields are logged the first time) and the
-- area name when the party enters a new area, the "!" of characters who want to talk, and the
-- party's chain when it splits or joins (the game's G key does it silently).
-- Queued events, recorded in the Events buffer. What is already there when the mod starts or a
-- save loads is not read back, except the "!" (it stays until the talk: a sighted player sees it).
local Notification = Ext.Require("Game/Notification.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Player = Ext.Require("Game/Player.lua")
local TutorialHints = Ext.Require("Screens/TutorialHints.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Poll = Ext.Require("Core/Poll.lua")

local L = Strings.Get

local Notices = {}

local POLL_MS = 250
local REPEAT_MS = 15000
local lastText, lastTextAt = nil, 0
local areaEnteredAt = -1e9
local AREA_BANNER_MS = 30000

local lastKey, lastArea, lastLevelUps = nil, nil, ""
local sideTutorials = {} -- keys of the side tutorials already shown
local started = false
local settleUntil = 0
-- The view model is refilled a moment after a load: the save's last banner ("¡Guardado rápido
-- completado!") appeared after the first poll and was read on every quick load (2026-09-24), and
-- a save loaded from another game brought the old game's banner ("Diario actualizado, Escapa del
-- nautiloide" on loading the Blighted Village, 2026-09-26). Banners during this long after the
-- start, and after every loading screen, only set the baseline.
local SETTLE_MS = 5000
local LOADING_SCREEN = "root"
local TALK_RADIUS = 40      -- meters around the controlled character
local TALK_POLL_MS = 1000
local lastTalkPoll = 0
local wantingToTalk = {}    -- [uuid] = true: announced

-- "Gale wants to talk" once each time the "!" appears.
local function pollTalk()
    local now = Ext.Timer.MonotonicTime()
    if now - lastTalkPoll < TALK_POLL_MS then return end
    lastTalkPoll = now
    local me = Entities.Position(Entities.Controlled())
    if not me then return end
    local current = {}
    for _, uuid in ipairs(Entities.WantingToTalk(me, TALK_RADIUS)) do
        current[uuid] = true
        if not wantingToTalk[uuid] then Speech.Event(L("wants_to_talk", { name = Entities.Name(uuid) or "?" })) end
    end
    wantingToTalk = current
end

-- The party's chains, spoken when they change: "Party together", or each group ("Tav, Gale
-- together. Corazón Sombrío alone").
local lastGroups = nil
local function groupsKey(groups)
    local parts = {}
    for i, g in ipairs(groups) do parts[i] = table.concat(g, ",") end
    table.sort(parts)
    return table.concat(parts, "|")
end

local function pollGroups()
    local groups = Player.PartyGroups()
    if #groups == 0 then return end
    local key = groupsKey(groups)
    if lastGroups and key ~= lastGroups then
        if #groups == 1 then
            Speech.Event(L("party_chained"))
        else
            local parts = {}
            for _, g in ipairs(groups) do
                parts[#parts + 1] = #g == 1 and L("party_group_alone", { name = g[1] }) or L("party_group_together", { names = Strings.List(g) })
            end
            Speech.Event(Strings.Sentences(parts))
        end
    end
    lastGroups = key
end

-- Why the controlled character cannot act (Game/Hotbar.CapabilityMessages), said when it
-- appears or changes.
local lastCapabilities = ""
local function pollCapabilities()
    local texts = Hotbar.CapabilityMessages()
    if not texts then return end
    local key = table.concat(texts, "|")
    if key ~= lastCapabilities and #texts > 0 then Speech.Event(Strings.List(texts)) end
    lastCapabilities = key
end

local function poll()
    local n = Notification.Read()
    local key = n and (tostring(n.type) .. "|" .. table.concat(n.parts, "|")) or nil
    local area = Notification.AreaName()
    local front = Ui.FrontWidget()
    if front and front.name == LOADING_SCREEN then settleUntil = Ext.Timer.MonotonicTime() + SETTLE_MS end
    if not started then
        lastKey, lastArea, started = key, area, true
        settleUntil = Ext.Timer.MonotonicTime() + SETTLE_MS
        lastLevelUps = table.concat(Notification.LevelUps(), ",")
        for _, t in ipairs(Notification.SideTutorials()) do sideTutorials[t.key] = true end
        return
    end
    if key and key ~= lastKey and Ext.Timer.MonotonicTime() < settleUntil then
        lastKey = key
    elseif key and key ~= lastKey and #n.parts > 0 then
        Bridge.Log("notification: " .. key)
        local text = Strings.List(n.parts)
        local now = Ext.Timer.MonotonicTime()
        -- The same banner can come back right after (measured: "Diario actualizado" twice); an
        -- area's banner is its name, said below as the area entered ("Aldea marchita" and "Zona:
        -- Aldea marchita" came together, 2026-09-25).
        -- The region banner can also come seconds after the area changed ("Zona: Campamento",
        -- then the banner 7 s later), and the game sends each banner again with Type None
        -- ("Region|Campamento", then "None|Campamento" 16 s later, 2026-09-25).
        local areaBanner = area and text == area and (area ~= lastArea or now - areaEnteredAt < AREA_BANNER_MS)
        local resent = n.type == "None" and text == lastText
        if not areaBanner and not resent and (text ~= lastText or now - lastTextAt > REPEAT_MS) then Speech.Event(text) end
        lastText, lastTextAt = text, now
    end
    lastKey = key or lastKey
    if area and area ~= lastArea then
        Speech.Event(L("entering_area", { name = area }))
        areaEnteredAt = Ext.Timer.MonotonicTime()
    end
    lastArea = area or lastArea
    local seenNow = {}
    for _, t in ipairs(Notification.SideTutorials()) do
        seenNow[t.key] = true
        if not sideTutorials[t.key] then
            Bridge.Log("side tutorial: " .. t.fields)
            if #t.texts > 0 then
                local parts = { table.unpack(t.texts) }
                parts[#parts + 1] = TutorialHints.For(t.name)
                Speech.Event(Strings.Sentences(parts))
            end
        end
    end
    sideTutorials = seenNow
    local ups = Notification.LevelUps()
    local upsKey = table.concat(ups, ",")
    if upsKey ~= lastLevelUps and #ups > 0 then Speech.Event(L("level_up_for", { names = Strings.List(ups) })) end
    lastLevelUps = upsKey
    pollTalk()
    pollGroups()
    pollCapabilities()
end

-- "Playa arrasada", for the where-am-I command.
function Notices.WhereAmI()
    local area = Notification.AreaName()
    return area and L("you_are_in", { name = area }) or L("area_unknown")
end

function Notices.Start()
    Poll.Every("notices", POLL_MS, poll)
end

return Notices
