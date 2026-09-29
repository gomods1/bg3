-- Stealth: who can see the controlled character (Game/Watchers), what a sighted player reads from
-- the sneak vision cones. "Who can see you" (mod menu) says it at any time; while the character
-- sneaks (status SNEAKING, verified 2026-09-25 after the game's C: "Tav: Esconderse, ha recibido
-- el estado «Ocultación»") the mod says who comes to see it and when nobody does any more, and
-- when sneaking ends (spotted, or the player stopped: "ha perdido el estado: «Ocultación»") who
-- sees it then. Osiris CanSee reads false for a hidden character (the Blighted Village goblins 2 m
-- away saw Tav before the Hide, nobody after it): "seen" here means noticed.
local Watchers = Ext.Require("Game/Watchers.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Poll = Ext.Require("Core/Poll.lua")

local L = Strings.Get

local Stealth = {}

local POLL_MS = 1000
local SNEAKING = "SNEAKING"

local function names(list)
    local out = {}
    for _, w in ipairs(list) do out[#out + 1] = w.name end
    return Strings.List(out)
end

function Stealth.WhoSees()
    Watchers.Of(function(list)
        Speech.Say(#list > 0 and L("seen_by", { names = names(list) }) or L("seen_by_nobody"), { interrupt = true })
    end)
end

local seen = nil      -- uuid -> true: who saw the sneaking character at the last poll (nil: not sneaking)
local asking = false

local function poll()
    if asking then return end
    if not Entities.HasStatus(Entities.Controlled(), SNEAKING) then
        if seen ~= nil then
            -- Only who was not said already (spotted by two goblins, then a third saw the
            -- character once it stood up: all three were said again, 2026-09-25).
            local said = seen
            seen = nil
            asking = true
            Watchers.Of(function(list)
                asking = false
                local new = {}
                for _, w in ipairs(list) do
                    if not said[w.uuid] then new[#new + 1] = w end
                end
                if #new > 0 then Speech.Event(L("seen_by", { names = names(new) })) end
            end)
        end
        return
    end
    asking = true
    Watchers.Of(function(list)
        asking = false
        local now, new = {}, {}
        for _, w in ipairs(list) do
            now[w.uuid] = true
            if seen and not seen[w.uuid] then new[#new + 1] = w end
        end
        if seen and #new > 0 then
            Speech.Event(L("seen_by", { names = names(new) }))
        elseif seen and next(seen) and #list == 0 then
            Speech.Event(L("seen_by_nobody"))
        elseif not seen and #list > 0 then
            -- Sneaking starts in sight: say who sees it at once.
            Speech.Event(L("seen_by", { names = names(list) }))
        end
        seen = now
    end)
end

function Stealth.Start()
    Poll.Every("stealth", POLL_MS, poll)
end

return Stealth
