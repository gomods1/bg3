-- Screens the mod only announces, without claiming keys: the game's own keys must keep working
-- there (splash: any key continues). The loading screen also reads its hints as they rotate.
local Loca = Ext.Require("Game/Loca.lua")
local Loading = Ext.Require("Game/Loading.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")

local L = Strings.Get

local Passive = {}
Passive.__index = Passive
Passive.Widgets = { "root", "SplashScreen", "Saving", "(none)" }

-- What each widget says: a Strings key, or true for the page's first static text (game language).
-- "(none)" is the router's name for "no visible widget": full-screen videos (intro, cinematics).
-- (The in-game HUD, "(hud)", has its own handler: Screens/Hud.)
local ANNOUNCE = { root = "screen_loading", SplashScreen = true, Saving = "screen_saving", ["(none)"] = "screen_video" }

-- Text that changes while the screen is up, read as it changes (queued).
local CHANGING = { root = Loading.Hint }

function Passive.New(widget, page)
    local what = ANNOUNCE[widget.name]
    local text
    if what == true then text = page and Loca.Text(page.texts[1])
    elseif what == "" then text = ""
    elseif what then text = L(what) end
    text = text or widget.name
    return setmetatable({ widget = widget.name, text = text, changing = CHANGING[widget.name], said = nil }, Passive)
end

function Passive:Open()
    Speech.Say(self.text)
end

function Passive:Tick()
    local now = self.changing and self.changing()
    if now and now ~= self.said then
        self.said = now
        Speech.Say(now)
    end
end

function Passive:ReadAll()
    Speech.Say(Strings.Sentences({ self.text, self.said }), { interrupt = true })
end

function Passive:Help()
    return { L("help_passive") }
end

function Passive:OnKey()
    return false
end

return Passive
