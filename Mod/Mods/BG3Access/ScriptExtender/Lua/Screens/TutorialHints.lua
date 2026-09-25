-- The mod's keyboard way for the game's tutorials that speak of the mouse ("pulsa el botón que está
-- a la derecha del acceso rápido"), said right after the tutorial. Keyed by the tutorial's stable
-- name (Game/Tutorial.NameForTitle); only tutorials whose keyboard way is verified have one.
local Strings = Ext.Require("Core/Strings.lua")

local TutorialHints = {}

local HINTS = {
    ["Ending your Turn"] = "tutorial_hint_end_turn",
    ["Equipment"] = "tutorial_hint_equipment",
    ["Hotbar Assignment (Spellbook)"] = "tutorial_hint_hotbar",
    ["Hotbar Assignment (Items)"] = "tutorial_hint_hotbar",
    ["Items Deck"] = "tutorial_hint_hotbar",
}

-- The hint sentence for tutorial name, or nil.
function TutorialHints.For(name)
    local key = name and HINTS[name]
    return key and Strings.Get(key) or nil
end

return TutorialHints
