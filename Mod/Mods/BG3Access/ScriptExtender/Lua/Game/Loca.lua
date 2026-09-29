-- Game localization: string handles ("h…g…") resolved in the game's language.
local Text = Ext.Require("Core/Text.lua")
local EnumNames = Ext.Require("Game/EnumNames.lua")
local Input = Ext.Require("Game/Input.lua")

local Loca = {}

-- Raw translated string, or nil for a missing/unknown handle.
function Loca.Get(handle)
    if handle == nil or handle == "" then return nil end
    local ok, s = pcall(Ext.Loca.GetTranslatedString, tostring(handle))
    if ok and s and s ~= "" then return s end
    return nil
end

-- Translated and cleaned for speech (markup stripped, "[IE_QuickSave]" as the key's name), or nil.
function Loca.Text(handle)
    return Text.Clean(Input.FillPlaceholders(Loca.Get(handle)))
end

-- Display name of an enum value as the UI shows it, from the XAML templates collected in
-- Game/EnumNames (e.g. Loca.Enum("AbilityDisplayName", "Strength") -> "Fuerza"), or nil.
function Loca.Enum(template, value)
    local map = EnumNames[template]
    local handle = map and map.values[tostring(value)]
    return handle and Loca.Text(handle) or nil
end

-- A stat's DisplayName (a status, a passive, a spell: "RAGE_TOTEM_BEAR" -> "Furia: corazón de oso"),
-- or nil.
function Loca.StatName(id)
    local ok, stat = pcall(Ext.Stats.Get, id)
    if not ok or not stat then return nil end
    local handle = nil
    pcall(function() handle = stat.DisplayName end)
    return Loca.Text(handle)
end

return Loca
