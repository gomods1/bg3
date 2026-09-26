-- The game's context menu on items (a right click on an inventory slot: Beber (Tav), Dividir
-- objeto, Soltar objeto, Lanzar, Añadir al acceso rápido, Enviar al campamento, Enviar a
-- <companion>, Examinar...). Facts (verified 2026-09-24, Tav's healing potion in the character
-- panel): each slot element (invCellBase) carries a ContextMenu whose IsOpen is true while it is
-- open (false after, even though it keeps its size); its entries are elements whose Header is a
-- view model { Header (text), ActionId (0...), IsTitle ("Enviar a"), IsIndented, IsEnabled,
-- TargetActionType }. The DC's ContextActionPressed(ActionId) takes a number, which Lua cannot
-- pass, so an entry is chosen with a verified click; the menu opens at the cursor, entries
-- top-down. Escape closes it.
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Timer = Ext.Require("Core/Timer.lua")
local Input = Ext.Require("Game/Input.lua")

local ContextMenu = {}

-- Where the first entry's centre lies from the menu's top left corner, which is the right-click
-- point unless the menu was flipped (fractions of the client area; measured at 2560 x 1600).
ContextMenu.FIRST_OFFSET = { 0.039, 0.0275 }

-- The open context menu element under widget widgetName, or nil (valid this tick).
local function openMenu(widgetName)
    local found = nil
    local function walk(el, depth)
        if found or depth > 80 then return end
        local cm = Ui.Prop(el, "ContextMenu")
        if cm and Ui.Prop(cm, "IsOpen") == true then
            found = cm
            return
        end
        for _, k in ipairs(Ui.Kids(el)) do walk(k, depth + 1) end
    end
    walk(Ui.FindWidget(widgetName), 0)
    return found
end

-- The entry elements of menu, top-down.
local function entryElements(menu)
    local out = {}
    local function walk(el, depth)
        if depth > 30 then return end
        local h = Ui.Prop(el, "Header")
        if h and Vm.Get(h, "Header") ~= nil then out[#out + 1] = el end
        for _, k in ipairs(Ui.Kids(el)) do walk(k, depth + 1) end
    end
    if menu then walk(menu, 0) end
    return out
end

function ContextMenu.IsOpen(widgetName)
    return openMenu(widgetName) ~= nil
end

-- { { text, title, indented, enabled } } of the open menu (empty when none is open).
function ContextMenu.Read(widgetName)
    local out = {}
    for _, el in ipairs(entryElements(openMenu(widgetName))) do
        local h = Ui.Prop(el, "Header")
        out[#out + 1] = {
            text = tostring(Vm.Get(h, "Header") or "?"),
            title = Vm.Get(h, "IsTitle") == true,
            indented = Vm.Get(h, "IsIndented") == true,
            enabled = Vm.Get(h, "IsEnabled") ~= false,
        }
    end
    return out
end

-- The first entry's centre of menu, opened by a right click at at = { fx, fy }. The menu opens
-- below and to the right of the click, flipped to its left where it would leave the screen
-- (verified 2026-09-25: Chock's menu, clicked at x 0.92, had its right edge at the click);
-- flipped above near the bottom edge (hypothesis, not seen yet). Its size is ActualWidth/Height.
local function firstEntry(menu, at)
    local scale, w, h = Ui.Scale()
    local mw = (Ui.Prop(menu, "ActualWidth") or 0) * scale / w
    local mh = (Ui.Prop(menu, "ActualHeight") or 0) * scale / h
    local left = at[1] + mw > 1 and at[1] - mw or at[1]
    local top = at[2] + mh > 1 and at[2] - mh or at[2]
    return { left + ContextMenu.FIRST_OFFSET[1], top + ContextMenu.FIRST_OFFSET[2] }
end

-- Clicks entry index of the open menu, which opened at point at = { fx, fy } (the right click).
-- onDone(ok, reasonKey).
function ContextMenu.Click(widgetName, index, at, onDone)
    local menu = openMenu(widgetName)
    if not menu then
        onDone(false, "reason_gone")
        return
    end
    Activate.ClickListItem(function() return entryElements(openMenu(widgetName)) end, index, firstEntry(menu, at), onDone)
end

-- The world context menu's first usable entry on thing uuid, chosen as a player does (a verified
-- right click, then a verified click on the entry). The entries arrive a few frames after the menu
-- opens. onDone(ok, reasonKey, entryText). Used where the game's plain click fails: the worg
-- pens' entrance from inside the Shattered Sanctum answered a left click with "No puedes llegar",
-- while its menu's "Usar (Tav)" walked Tav 120 m round and went in (2026-09-25).
local WORLD_MENU = "WorldContextMenu"
local ENTRIES_WAIT_MS, ENTRIES_POLL_MS = 2000, 100
function ContextMenu.UseFirst(uuid, onDone)
    Activate.ContextClick(uuid, function(ok, reason, fx, fy)
        if not ok then
            onDone(false, reason)
            return
        end
        local waited = 0
        local function pick()
            for i, entry in ipairs(ContextMenu.Read(WORLD_MENU)) do
                if entry.enabled and not entry.title then
                    ContextMenu.Click(WORLD_MENU, i, { fx, fy }, function(clicked, why) onDone(clicked, why, entry.text) end)
                    return
                end
            end
            waited = waited + ENTRIES_POLL_MS
            if waited >= ENTRIES_WAIT_MS then
                ContextMenu.Close(WORLD_MENU)
                onDone(false, "reason_unavailable")
                return
            end
            Timer.After(ENTRIES_POLL_MS, pick)
        end
        Timer.After(ENTRIES_POLL_MS, pick)
    end)
end

-- Closes the open menu with the game's cancel key.
function ContextMenu.Close(widgetName)
    if not ContextMenu.IsOpen(widgetName) then return end
    local key = Input.ScancodeFor("UICancel")
    if key then Ext.Input.InjectKeyPress(key) end
end

return ContextMenu
