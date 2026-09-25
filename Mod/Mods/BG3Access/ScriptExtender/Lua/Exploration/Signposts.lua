-- Signposts (mod menu): the signs the party has read in this area (Game/Signposts), each named by
-- what it said ("Oeste: Puerta de Baldur. Este: Elturel, 28 metros, detrás"), nearest first.
-- Enter walks there and reads it again (Exploration/PlaceList). A sighted player remembers the
-- signs seen on the way; this is a blind player's way back to them and to their directions.
local Game = Ext.Require("Game/Signposts.lua")
local PlaceList = Ext.Require("Exploration/PlaceList.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Signposts = {}

function Signposts.Show(open, onClose)
    Game.Read(function(list)
        if #list == 0 then
            Speech.Say(L("signposts_none"), { interrupt = true })
            return
        end
        local entries = {}
        for _, s in ipairs(list) do
            entries[#entries + 1] = { uuid = s.uuid, name = s.text, position = s.position }
        end
        open(PlaceList.New("(signposts)", L("screen_signposts"), entries, onClose, open))
    end)
end

return Signposts
