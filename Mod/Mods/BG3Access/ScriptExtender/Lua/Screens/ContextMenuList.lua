-- A game context menu (Game/ContextMenu: an inventory item's, or a thing's in the world) shown
-- as a sub-list of a list screen: its titles ("Enviar a") as text, its entries as buttons; Enter
-- clicks one (verified); leaving the sub-list without choosing closes the game's menu.
local ContextMenu = Ext.Require("Game/ContextMenu.lua")
local Ui = Ext.Require("Game/Ui.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Timer = Ext.Require("Core/Timer.lua")
local Controls = Ext.Require("Screens/Controls.lua")

local L = Strings.Get

local ContextMenuList = {}

local READBACK_MS = 1000 -- the action is deferred (Examine opened ~0.6 s after the click): the
                         -- lists are read again after it, unless it opened a window
local MENU_WAIT_MS = 1500 -- the menu gets its entries a few frames after it opens
local MENU_POLL_MS = 100

-- The name of the game window in front (nil: only the HUD).
local function frontName()
    local w = Ui.FrontWidget()
    return w and w.name
end

-- state = { chosen }: set once an entry was clicked (the game closes its menu itself then; a
-- cancel key sent after it reached the game menu instead, verified 2026-09-25).
local function build(screen, widgetName, at, afterAction, state)
    local out = {}
    for i, e in ipairs(ContextMenu.Read(widgetName)) do
        if e.title then
            out[#out + 1] = Controls.Text(e.text)
        else
            out[#out + 1] = Controls.Item({
                kind = "button",
                describe = function() return Strings.List({ e.text, not e.enabled and L("unavailable") }) end,
                activate = function()
                    if not e.enabled then
                        Speech.Say(L("could_not_activate", { label = e.text, reason = L("reason_unavailable") }), { interrupt = true })
                        return
                    end
                    local before = frontName()
                    ContextMenu.Click(widgetName, i, at, function(ok, reason)
                        if not ok then
                            Speech.Say(L("could_not_activate", { label = e.text, reason = L(reason) }), { interrupt = true })
                            return
                        end
                        state.chosen = true
                        -- The game says what happened (its log); the parent list is read again,
                        -- unless the action opened a game window (Examinar), which speaks for itself.
                        Timer.After(READBACK_MS, function()
                            local opened = frontName() ~= before
                            if #screen.levels > 0 then screen:Pop(opened) end
                            if afterAction and not opened then afterAction() end
                        end)
                    end)
                end,
            })
        end
    end
    return out
end

-- Once the menu of widget widgetName (opened by a right click at at = { fx, fy }) has entries,
-- pushes it on screen as a sub-list titled title; says why when it never does (label names the
-- thing). afterAction() runs after an entry was clicked.
function ContextMenuList.Open(screen, widgetName, title, at, label, afterAction)
    local started = Ext.Utils.MonotonicTime()
    local function whenFilled()
        if #ContextMenu.Read(widgetName) > 0 then
            local state = { chosen = false }
            screen:Push(title, function() return build(screen, widgetName, at, afterAction, state) end, nil,
                function() if not state.chosen then ContextMenu.Close(widgetName) end end)
        elseif Ext.Utils.MonotonicTime() - started > MENU_WAIT_MS then
            Speech.Say(L("could_not_activate", { label = label, reason = L("reason_menu_not_open") }), { interrupt = true })
        else
            Timer.After(MENU_POLL_MS, whenFilled)
        end
    end
    Timer.After(MENU_POLL_MS, whenFilled)
end

return ContextMenuList
