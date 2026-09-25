-- Picks the handler for the widget in front, ~10 times a second, and routes keys to it.
-- Screen modules register what they handle (Module.Widgets = widget names, Module.DcTypes = data
-- context types); anything else gets the generic list. Screen interface: Screens/ListScreen.
local Ui = Ext.Require("Game/Ui.lua")
local Log = Ext.Require("Core/Log.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Generic = Ext.Require("Screens/Generic.lua")

local Router = {}

local SCREENS = {
    Ext.Require("Screens/Passive.lua"),
    Ext.Require("Screens/Hud.lua"),
    Ext.Require("Screens/MainMenu.lua"),
    Ext.Require("Screens/Difficulty.lua"),
    Ext.Require("Screens/MessageBox.lua"),
    Ext.Require("Screens/Options.lua"),
    Ext.Require("Screens/CharacterCreation.lua"),
    Ext.Require("Screens/Container.lua"),
    Ext.Require("Screens/Tutorial.lua"),
    Ext.Require("Screens/Dialogue.lua"),
    Ext.Require("Screens/ActiveRoll.lua"),
    Ext.Require("Screens/Inventory.lua"),
    Ext.Require("Screens/LevelUp.lua"),
    Ext.Require("Screens/Reactions.lua"),
    Ext.Require("Screens/Camp.lua"),
    Ext.Require("Screens/LoadGame.lua"),
    Ext.Require("Screens/Trade.lua"),
    Ext.Require("Screens/Book.lua"),
    Ext.Require("Screens/Credits.lua"),
    Ext.Require("Screens/Examine.lua"),
    Ext.Require("Screens/SaveGame.lua"),
    Ext.Require("Screens/SaveName.lua"),
    Ext.Require("Screens/WorldMap.lua"),
}

local byWidget, byDcType = {}, {}
for _, m in ipairs(SCREENS) do
    for _, w in ipairs(m.Widgets or {}) do byWidget[w] = m end
    for _, t in ipairs(m.DcTypes or {}) do byDcType[t] = m end
end

Router.current = nil -- widget name in front
Router.handler = nil
local below = {} -- handlers under a pushed mod screen (the mod menu), restored by PopModScreen

local function open(widget)
    -- A mod screen the game's own screen replaces (a quick save's "Guardando" over targeting) is
    -- told, so what it needs can start again afterwards (Combat/Targeting: the armed action).
    local replaced = Router.handler
    if replaced and replaced.OnReplaced then Log.Guard("replaced screen", function() replaced:OnReplaced() end) end
    Router.current = widget and widget.name or nil
    Router.handler = nil
    below = {}
    if not widget then return end
    Bridge.Log("screen: " .. widget.name .. " (" .. tostring(widget.dcType) .. ")")
    local module = byWidget[widget.name] or byDcType[widget.dcType or ""] or Generic
    local ok, h = pcall(module.New, widget, Ui.Page(widget.name))
    if not ok then
        Log.Error("handler for " .. widget.name .. ": " .. tostring(h))
        Speech.Say(widget.name)
        return
    end
    Router.handler = h
    Log.Guard("open " .. widget.name, function() h:Open() end)
end

-- A screen's view model often fills a frame or two after the widget appears: open the handler
-- only once the same widget has been in front for SETTLE_TICKS router ticks.
local SETTLE_TICKS = 2
local NO_WIDGET_SETTLE_TICKS = 15
local TICK_MS = 100
local pendingName, pendingTicks = nil, 0

-- No visible widget at all: a full-screen video is playing (verified: the intro and the cinematic
-- after character creation hide every widget). Only the HUD: playing, no screen open.
local NO_WIDGET = { name = "(none)" }
local HUD_ONLY = { name = "(hud)" }

local function tick()
    local front, hud = Ui.FrontWidget()
    front = front or (hud and HUD_ONLY) or NO_WIDGET
    local name = front and front.name or nil
    if name ~= Router.current then
        if name ~= pendingName then
            pendingName, pendingTicks = name, 0
        end
        pendingTicks = pendingTicks + 1
        -- "No widget" also happens for a moment during fades: only a lasting one is a video.
        local needed = (front == NO_WIDGET) and NO_WIDGET_SETTLE_TICKS or SETTLE_TICKS
        if pendingTicks >= needed then
            pendingName = nil
            open(front)
        end
    elseif Router.handler and Router.handler.Tick then
        Router.handler:Tick()
    end
end

function Router.Start()
    local last = 0
    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Timer.MonotonicTime()
        if now - last < TICK_MS then return end
        last = now
        Log.Guard("router tick", tick)
    end)
end

-- Called by Keys for every press not bound to a global action; true = the game must not see it.
function Router.OnKey(combo)
    local h = Router.handler
    if not (h and h.OnKey) then return false end
    local ok, handled = pcall(h.OnKey, h, combo)
    if not ok then
        Log.Error("key " .. combo .. " in " .. tostring(Router.current) .. ": " .. tostring(handled))
        return false
    end
    return handled == true
end

-- Mod screens: lists the mod opens itself over the in-game HUD (e.g. Exploration/Nearby). They
-- stay the handler until they close themselves or the game opens a screen of its own (the next
-- widget change replaces them).
function Router.InGame()
    return Router.current == HUD_ONLY.name
end

function Router.OpenModScreen(handler)
    Router.handler = handler
    below = {}
    Log.Guard("open mod screen", function() handler:Open() end)
end

-- Back to the plain in-game state (the next tick reopens the HUD handler).
function Router.CloseModScreen()
    Router.current = nil
    Router.handler = nil
    below = {}
end

-- A mod screen over the current handler (a game screen or another mod screen), which gets the keys
-- back, without a new announcement, on PopModScreen (the mod menu: its commands then act on the
-- screen the player was on).
function Router.PushModScreen(handler)
    below[#below + 1] = Router.handler or false
    Router.handler = handler
    Log.Guard("open mod screen", function() handler:Open() end)
end

function Router.PopModScreen()
    if #below == 0 then
        Router.CloseModScreen()
        return
    end
    Router.handler = table.remove(below) or nil
end

function Router.ReadScreen()
    if Router.handler and Router.handler.ReadAll then
        Router.handler:ReadAll()
    else
        Speech.Say(Router.current or Strings.Get("no_screen"), { interrupt = true })
    end
end

function Router.Details()
    if Router.handler and Router.handler.Details then
        Router.handler:Details()
    else
        Speech.Say(Strings.Get("no_details"), { interrupt = true })
    end
end

-- Help lines of the screen in front (the global part is added by Core/Help).
function Router.HelpLines()
    if Router.handler and Router.handler.Help then return Router.handler:Help() end
    return {}
end

return Router
