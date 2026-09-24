-- Picks the handler for the widget in front, ~10 times a second, and routes mod keys to it.
local Ui = Ext.Require("Game/Ui.lua")
local Log = Ext.Require("Core/Log.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Bridge = Ext.Require("Core/Bridge.lua")
local Generic = Ext.Require("Screens/Generic.lua")
local Difficulty = Ext.Require("Screens/Difficulty.lua")
local MessageBox = Ext.Require("Screens/MessageBox.lua")

local Router = {}

-- Widgets the mod only announces (no key claims): the game's own keys must keep working there.
-- true = speak the page's first static text (in the game's language).
local PASSIVE = { root = "Loading", SplashScreen = true }
local FRIENDLY = { MainMenu = "Main menu" }
local HANDLERS = {
    DMSettings = Difficulty,
    MainMenu = { New = function(widget, page) return Generic.New(widget, page, "Main menu", { buttonsOnly = true }) end },
}
-- Handlers chosen by data context type when the widget name has none.
local DC_HANDLERS = { ["ls.DCMessageBox"] = MessageBox }

Router.current = nil     -- widget name in front
Router.handler = nil

local function open(widget)
    Router.current = widget and widget.name or nil
    Router.handler = nil
    if not widget then return end
    Bridge.Log("screen: " .. widget.name .. " (" .. tostring(widget.dcType) .. ")")
    local page = Ui.Page(widget.name)
    local passive = PASSIVE[widget.name]
    if passive then
        local text = passive == true and page and Ui.Loca(page.texts[1]) or passive
        Speech.Say(tostring(text or widget.name))
        return
    end
    local ctor = HANDLERS[widget.name] or DC_HANDLERS[widget.dcType or ""]
    local ok, h = pcall(function()
        if ctor then return ctor.New(widget, page) end
        return Generic.New(widget, page, FRIENDLY[widget.name])
    end)
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
local pendingName, pendingTicks = nil, 0

function Router.Start()
    local last = 0
    Ext.Events.Tick:Subscribe(function()
        local now = Ext.Timer.MonotonicTime()
        if now - last < 100 then return end
        last = now
        Log.Guard("router tick", function()
            local front = Ui.FrontWidget()
            local name = front and front.name or nil
            if name ~= Router.current then
                if name ~= pendingName then
                    pendingName, pendingTicks = name, 0
                end
                pendingTicks = pendingTicks + 1
                if pendingTicks >= SETTLE_TICKS then
                    pendingName = nil
                    open(front)
                end
            elseif Router.handler and Router.handler.Tick then
                Router.handler:Tick()
            end
        end)
    end)
end

-- Called by Keys for every press; returns true when the key was used (the game must not see it).
function Router.OnKey(combo)
    local h = Router.handler
    if not h or not h.OnKey then return false end
    local ok, handled = pcall(function() return h:OnKey(combo) end)
    if not ok then
        Log.Error("key " .. combo .. " in " .. tostring(Router.current) .. ": " .. tostring(handled))
        return false
    end
    return handled == true
end

function Router.ReadScreen()
    if Router.handler and Router.handler.ReadAll then
        Router.handler:ReadAll()
    else
        Speech.Say(Router.current or "No screen")
    end
end

return Router
