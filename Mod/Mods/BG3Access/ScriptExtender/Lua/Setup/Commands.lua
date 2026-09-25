-- The mod's command set: wires each feature to Core/Commands (the mod menu, and a direct key when
-- the config binds one). The only direct keys bound by default are the menu itself and the two
-- that act on the focused item (read screen, details): see Core/Config.
local Commands = Ext.Require("Core/Commands.lua")
local Keys = Ext.Require("Core/Keys.lua")
local Help = Ext.Require("Core/Help.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Strings = Ext.Require("Core/Strings.lua")
local Config = Ext.Require("Core/Config.lua")
local Router = Ext.Require("Screens/Router.lua")
local ModMenu = Ext.Require("Screens/ModMenu.lua")
local History = Ext.Require("Screens/History.lua")
local DialogueGame = Ext.Require("Game/Dialogue.lua")
local Nearby = Ext.Require("Exploration/Nearby.lua")
local Markers = Ext.Require("Exploration/Markers.lua")
local TurnOrder = Ext.Require("Combat/TurnOrder.lua")
local ReactionSettings = Ext.Require("Combat/ReactionSettings.lua")
local Actions = Ext.Require("Combat/Actions.lua")
local Place = Ext.Require("Combat/Place.lua")
local Hotbar = Ext.Require("Game/Hotbar.lua")
local Hud = Ext.Require("Screens/Hud.lua")
local Words = Ext.Require("Combat/Words.lua")
local Characters = Ext.Require("Game/Characters.lua")
local Player = Ext.Require("Game/Player.lua")
local Combat = Ext.Require("Game/Combat.lua")
local Timers = Ext.Require("Exploration/Timers.lua")
local Notices = Ext.Require("Exploration/Notices.lua")
local Journal = Ext.Require("Exploration/Journal.lua")
local Waypoints = Ext.Require("Exploration/Waypoints.lua")
local Explore = Ext.Require("Exploration/Explore.lua")
local WhereAmI = Ext.Require("Exploration/WhereAmI.lua")
local Places = Ext.Require("Exploration/Places.lua")
local Signposts = Ext.Require("Exploration/Signposts.lua")
local Marks = Ext.Require("Exploration/Marks.lua")
local Stealth = Ext.Require("Exploration/Stealth.lua")
local Travel = Ext.Require("Exploration/Travel.lua")
local LevelUpGame = Ext.Require("Game/LevelUp.lua")
local SpellbookGame = Ext.Require("Game/Spellbook.lua")
local Camp = Ext.Require("Game/Camp.lua")
local SaveLoad = Ext.Require("Game/SaveLoad.lua")
local Spellbook = Ext.Require("Screens/Spellbook.lua")

local Setup = {}

-- Read after the menu or mod key is released: with Ctrl held the game's highlights list nothing
-- (measured).
local HIGHLIGHT_DELAY_MS = 300

local function inCombat()
    return Router.InGame() and Combat.Current() ~= nil
end

function Setup.Register()
    Keys.Action("menu", function()
        local screen = Router.handler
        Router.PushModScreen(ModMenu.New(screen, Router.PopModScreen))
    end)

    -- Combat
    Commands.Register({
        id = "actions", group = "combat", available = Router.InGame,
        run = function() Router.OpenModScreen(Actions.New(Router.OpenModScreen, Router.CloseModScreen)) end,
    })
    -- An action the game armed by itself (its keys, an item's "Lanzar") gets the mod's targeting.
    Hud.OnArmed = function(a) Actions.FollowArmed(Router.OpenModScreen, Router.CloseModScreen, a) end
    -- Walk to a place chosen with the place cursor (a click on the ground, the game's pathfinding
    -- and movement rules); in combat the game's preview says the meters it costs.
    Commands.Register({
        id = "move", group = "combat",
        available = function() return Router.InGame() and not Hotbar.Armed() end,
        run = function()
            Router.OpenModScreen(Place.New(Strings.Get("action_move"), Router.CloseModScreen, { title = Strings.Get("screen_move"), move = true }))
        end,
    })
    Commands.Register({
        id = "levelUp", group = "combat",
        available = function() return Router.InGame() and LevelUpGame.Available() end,
        run = function()
            if not LevelUpGame.Start() then Speech.Say(Strings.Get("not_available_here"), { interrupt = true }) end
        end,
    })
    Commands.Register({
        id = "turnOrder", group = "combat", available = inCombat,
        run = function() Router.OpenModScreen(TurnOrder.New(Router.CloseModScreen)) end,
    })
    Commands.Register({
        id = "reactions", group = "combat", available = Router.InGame,
        run = function() Router.OpenModScreen(ReactionSettings.New(Router.CloseModScreen)) end,
    })
    Commands.Register({
        id = "status", group = "combat",
        available = function() return Player.SelectedCharacter() ~= nil end,
        run = function()
            local me = Characters.Snapshot(Player.SelectedCharacter())
            local text = me and Strings.Sentences({ Words.Status(me), Timers.Words() }) or Strings.Get("not_available_here")
            Speech.Say(text, { interrupt = true })
        end,
    })

    -- Exploration
    Commands.Register({
        id = "nearby", group = "exploration", available = Router.InGame,
        run = function()
            Ext.Timer.WaitForRealtime(HIGHLIGHT_DELAY_MS, function()
                Nearby.Gather(function(list) Router.OpenModScreen(Nearby.New(list, Router.CloseModScreen, Router.OpenModScreen)) end)
            end)
        end,
    })
    Commands.Register({
        id = "farther", group = "exploration", available = Router.InGame,
        run = function()
            Nearby.GatherFar(function(list) Router.OpenModScreen(Nearby.New(list, Router.CloseModScreen, Router.OpenModScreen, true)) end)
        end,
    })
    Commands.Register({
        id = "journal", group = "exploration", available = Router.InGame,
        run = function() Router.OpenModScreen(Journal.New(Router.CloseModScreen)) end,
    })
    Commands.Register({
        id = "spellbook", group = "exploration",
        available = function() return Router.InGame() and #SpellbookGame.Read() > 0 end,
        run = function() Router.OpenModScreen(Spellbook.New(Router.CloseModScreen)) end,
    })
    Commands.Register({
        id = "shortRest", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() and Camp.CanShortRest() end,
        run = function()
            if not Camp.ShortRest() then Speech.Say(Strings.Get("not_available_here"), { interrupt = true }) end
        end,
    })
    Commands.Register({
        id = "longRest", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() end,
        run = function()
            if not Camp.LongRest() then Speech.Say(Strings.Get("not_available_here"), { interrupt = true }) end
        end,
    })
    Commands.Register({
        id = "stopWalking", group = "urgent", available = Travel.IsActive,
        run = function()
            Travel.Cancel()
            Speech.Say(Strings.Get("walking_stopped"), { interrupt = true })
        end,
    })
    Commands.Register({
        id = "explore", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() end,
        run = function() Router.OpenModScreen(Explore.New(Router.CloseModScreen)) end,
    })
    Commands.Register({
        id = "places", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() end,
        run = function() Places.Show(Router.OpenModScreen, Router.CloseModScreen) end,
    })
    Commands.Register({
        id = "signposts", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() end,
        run = function() Signposts.Show(Router.OpenModScreen, Router.CloseModScreen) end,
    })
    Commands.Register({
        id = "whoSeesMe", group = "exploration", available = Router.InGame,
        run = Stealth.WhoSees,
    })
    Commands.Register({
        id = "markHere", group = "exploration", available = Router.InGame,
        run = Marks.MarkHere,
    })
    Commands.Register({
        id = "marks", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() end,
        run = function() Marks.Show(Router.OpenModScreen, Router.CloseModScreen) end,
    })
    Commands.Register({
        id = "waypoints", group = "exploration",
        available = function() return Router.InGame() and not Combat.Current() end,
        run = function() Router.OpenModScreen(Waypoints.New(Router.CloseModScreen)) end,
    })
    Commands.Register({
        id = "loadGame", group = "screen", available = Router.InGame,
        run = function()
            if not SaveLoad.Open() then Speech.Say(Strings.Get("not_available_here"), { interrupt = true }) end
        end,
    })
    Commands.Register({
        id = "whereAmI", group = "exploration", available = Router.InGame,
        run = function() Speech.Say(WhereAmI.Text(), { interrupt = true }) end,
    })
    Commands.Register({
        id = "markers", group = "exploration", available = Router.InGame,
        run = function() Router.OpenModScreen(Markers.New(Router.CloseModScreen, Router.OpenModScreen)) end,
    })

    -- The screen in front
    Commands.Register({ id = "readScreen", group = "screen", run = Router.ReadScreen })
    Commands.Register({ id = "details", group = "screen", run = Router.Details })
    Commands.Register({ id = "help", group = "screen", run = function() Help.Speak(Router.HelpLines()) end })
    Commands.Register({
        id = "history", group = "screen",
        run = function()
            local start = (Router.current == DialogueGame.Widget and "dialogue") or (Combat.Current() and "combat") or "events"
            Router.PushModScreen(History.New(start, Router.PopModScreen))
        end,
    })

    -- Speech
    Commands.Register({ id = "repeat", group = "speech", run = Speech.Repeat })
    Commands.Register({ id = "stopSpeech", group = "speech", run = Speech.Stop })
    -- Barks: all -> the party's only -> none -> all (Combat/Narrator).
    local BARK_MODES = { all = "party", party = "none", none = "all" }
    Commands.Register({
        id = "barks", group = "speech",
        label = function() return Strings.Get("action_barks_" .. (Config.Get("speech.barks") or "all")) end,
        run = function()
            local mode = BARK_MODES[Config.Get("speech.barks") or "all"] or "all"
            Config.Set("speech.barks", mode)
            Speech.Say(Strings.Get("action_barks_" .. mode), { interrupt = true })
        end,
    })
    Commands.Register({
        id = "resetSpeech", group = "speech",
        run = function()
            Speech.ResetBackend()
            Speech.Say(Strings.Get("speech_reset"))
        end,
    })
end

return Setup
