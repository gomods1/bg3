-- Map markers list (gate.md 8.4, first version, Ctrl+G): quest objectives and the other markers of
-- the world map (Game/Map), objectives first (Map.TypeRank), then nearest first. Enter walks there (Exploration/Travel): to the marked
-- character or object, or to the marked point for objectives.
local Map = Ext.Require("Game/Map.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Log = Ext.Require("Core/Log.lua")
local ListScreen = Ext.Require("Screens/ListScreen.lua")
local PlaceList = Ext.Require("Exploration/PlaceList.lua")

local L = Strings.Get

local Markers = ListScreen.Extend(PlaceList)

local function kindWords(e)
    local key = "marker_" .. tostring(e.type)
    if Strings.Has(key) then return L(key) end
    Log.Info("marker type without a string: " .. tostring(e.type))
    return L("marker_other")
end

local function arrived(e)
    Speech.Say(L("arrived_at", { name = e.name or "?" }))
end

function Markers.New(onClose, open)
    local entries = {}
    for _, m in ipairs(Map.Markers()) do
        entries[#entries + 1] = {
            name = m.name, type = m.type, uuid = m.uuid, position = m.position, rank = Map.TypeRank(m.type),
            describeExtra = kindWords,
            afterUse = not m.uuid and arrived or nil,
        }
    end
    return setmetatable(PlaceList.New("(markers)", L("screen_markers"), entries, onClose, open), Markers)
end

function Markers:Help()
    local lines = ListScreen.Help(self)
    lines[#lines + 1] = L("help_markers")
    return lines
end

return Markers
