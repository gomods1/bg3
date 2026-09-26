-- Short-lived texts the game shows on screen outside any window, gathered for the "what is on
-- screen" command (the user heard of "a message about resources" and could not tell what it was
-- or whether it had to be dismissed, 2026-09-25). None of these needs dismissing: they go away by
-- themselves or when their cause does.
--   the cursor's lines (CursorText > CursorTextList: why an action cannot be used here);
--   the hotbar's "cannot act" line (Game/Hotbar.CapabilityMessages: "No se puede controlar: ...");
--   the banner (NotificationWidget: the lines built from runs, as shown);
--   the side tutorials beside the minimap (Game/Notification.SideTutorials).
local Ui = Ext.Require("Game/Ui.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Notification = Ext.Require("Game/Notification.lua")

local OnScreen = {}

-- Shown run-built texts under the named element of a top-level widget (any widget, overlays
-- included), in visual order.
local function shownTexts(widgetName, elementName)
    local root = Ui.FindByName(Ext.UI.GetRoot(), "ContentRoot")
    local widget = root and Ui.FindByName(root, widgetName)
    if not widget or Ui.Prop(widget, "IsVisible") == false then return {} end
    local start = elementName and Ui.FindByName(widget, elementName) or widget
    local out = {}
    local function walk(el, depth)
        if not el or depth > 60 or not Ui.IsShown(el) then return end
        -- A collapsed element keeps its last size ("Turno medioambiental" read out of combat):
        -- its Visibility, stored on the element, says it is gone.
        local vis = tostring(Ui.Prop(el, "Visibility") or "")
        if vis == "Collapsed" or vis == "Hidden" then return end
        if tostring(el.Type) == "TextBlock" then
            local t = Ui.InlineText(el)
            if t then out[#out + 1] = t end
        end
        for _, k in ipairs(Ui.Kids(el)) do walk(k, depth + 1) end
    end
    walk(start, 0)
    return out
end

-- { texts } in the order above; empty when nothing is shown.
function OnScreen.Messages()
    local out = {}
    for _, t in ipairs(shownTexts("CursorText", "CursorTextList")) do out[#out + 1] = t end
    for _, t in ipairs(Hotbar.CapabilityMessages() or {}) do out[#out + 1] = t end
    for _, t in ipairs(shownTexts("NotificationWidget")) do out[#out + 1] = t end
    for _, tut in ipairs(Notification.SideTutorials()) do
        for _, t in ipairs(tut.texts) do out[#out + 1] = t end
    end
    return out
end

return OnScreen
