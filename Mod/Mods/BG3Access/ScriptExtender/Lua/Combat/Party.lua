-- Party list (mod menu, a mod screen over the HUD): the party's characters in the order of their
-- portraits, which is the order of the game's F1 to F4 keys, so a blind player learns which key
-- selects whom. Each line: position, name, "controlled" for the one in control, hit points,
-- "acting now" in combat, distance and direction from the controlled character, statuses.
-- Enter takes control of a character the way a click on the portrait does (Game/Player.Select,
-- the portraits' own command; verified for Travel's reselection of its walker); the combat tracker
-- then says "Now Gale" (or the status line in combat) at once. Ctrl+D reads the full status line.
local Player = Ext.Require("Game/Player.lua")
local Characters = Ext.Require("Game/Characters.lua")
local Entities = Ext.Require("Game/Entities.lua")
local Combat = Ext.Require("Game/Combat.lua")
local Words = Ext.Require("Combat/Words.lua")
local Direction = Ext.Require("Exploration/Direction.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local Party = ListScreen.Extend()

function Party.New(onClose)
    local self = setmetatable(ListScreen.New("(party)", L("screen_party")), Party)
    self.onClose = onClose
    return self
end

-- The member at position i, read live (control and hit points change while the list is open).
local function member(i)
    return Player.Party()[i]
end

local function describe(i)
    local m = member(i)
    local s = m and Characters.Snapshot(Player.MemberVm(m.uuid))
    if not s then return L("option_gone") end
    local parts = { L("party_entry", { i = i, name = s.name or "?" }), m.controlled and L("party_controlled"), Words.Hp(s) }
    if Combat.Current() and s.currentTurn then parts[#parts + 1] = L("turn_now") end
    local me, p = Entities.Position(Entities.Controlled()), Entities.Position(m.uuid)
    if me and p and not m.controlled then
        parts[#parts + 1] = L("meters", { n = math.floor(Entities.Distance(me, p) + 0.5) })
        parts[#parts + 1] = Direction.Words(me, p)
    end
    parts[#parts + 1] = Words.Statuses(s)
    return Strings.List(parts)
end

function Party:Control(i)
    local m = member(i)
    if not m then
        Speech.Say(L("option_gone"), { interrupt = true })
        return
    end
    if m.controlled then
        Speech.Say(L("party_already", { name = m.name or "?" }), { interrupt = true })
        return
    end
    if not Player.Select(m.uuid) then
        Speech.Say(L("could_not_activate", { label = m.name or "?", reason = L("reason_unavailable") }), { interrupt = true })
        return
    end
    -- The tracker announces the new character (Player.OnSelect told it to do so at once).
    if self.onClose then self.onClose() end
end

function Party:Build()
    local out = {}
    for i, m in ipairs(Player.Party()) do
        local uuid = m.uuid
        out[#out + 1] = Controls.Item({
            kind = "button",
            describe = function() return describe(i) end,
            details = function()
                local s = Characters.Snapshot(Player.MemberVm(uuid))
                return s and Words.Status(s) or nil
            end,
            activate = function() self:Control(i) end,
        })
    end
    return out
end

function Party:Help()
    return { L("help_party") }
end

return Party
