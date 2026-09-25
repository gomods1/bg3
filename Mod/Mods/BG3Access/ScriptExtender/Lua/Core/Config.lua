-- Player configuration (template_rpg 22): BG3Access/config.json under the Script Extender folder
-- (%LOCALAPPDATA%\Larian Studios\Baldur's Gate 3\Script Extender\BG3Access\config.json).
-- Missing file: written with the defaults so the player can edit it. Bad or unknown values: logged
-- and replaced by the default, never fatal. Keys are SDL scancode names joined with "+", modifiers
-- first ("CTRL+R"); an action can take one combo or a list of combos; "" unbinds it.
local Log = Ext.Require("Core/Log.lua")

local Config = {}

local PATH = "BG3Access/config.json"

-- Mod key layer: Ctrl + letter. The game binds Ctrl only on C, V, X, Y, Z (text editing) and uses
-- Ctrl alone as a hold modifier (slow camera, attack objects); see CLAUDE.md, game key bindings.
-- Design rule: one menu key (Screens/ModMenu) reaches every command; direct keys by default only
-- for the menu and the two that act on the focused item. Every other command can be bound here
-- ("" = only in the menu).
local DEFAULTS = {
    configVersion = 2,
    keys = {
        menu = "CTRL+M",
        readScreen = "CTRL+R",
        details = "CTRL+D",
        help = "",
        nearby = "",
        markers = "",
        status = "",
        turnOrder = "",
        actions = "",
        move = "",
        history = "",
        whereAmI = "",
        journal = "",
        farther = "",
        levelUp = "",
        reactions = "",
        spellbook = "",
        shortRest = "",
        longRest = "",
        waypoints = "",
        explore = "",
        places = "",
        signposts = "",
        whoSeesMe = "",
        markHere = "",
        marks = "",
        stopWalking = "",
        loadGame = "",
        ["repeat"] = "",
        stopSpeech = "",
        resetSpeech = "",
        barks = "",
    },
    combat = {
        -- Space in combat asks again while an action or bonus action is left.
        confirmEndTurn = true,
        -- How the combat log is spoken: "grouped" (one line per actor's turn, results by target;
        -- the party's own actions at once) or "full" (every line of the game's log).
        log = "grouped",
    },
    speech = {
        -- Speak a hint at the end of each screen's opening announcement.
        screenHints = true,
        -- The mod's own words: "auto" (the game's language) or a language code ("en", "es", ...).
        language = "auto",
        -- Barks (the lines characters say around the party, from the combat log): "all",
        -- "party" (only the party's own) or "none" (kept in the events history either way).
        barks = "all",
    },
    debug = {
        -- Log every key event to the bridge log (development).
        logKeys = false,
        -- Log every probe of the verified UI clicks (Game/Activate) to the bridge log.
        traceClicks = false,
    },
}

Config.values = nil

-- Version 1 bound a Ctrl+letter to every command. Moving to version 2 drops those bindings where
-- the player's file still has the version 1 default (bindings the player chose are kept).
local V1_KEYS = {
    help = "CTRL+H", nearby = "CTRL+E", markers = "CTRL+G", status = "CTRL+S", turnOrder = "CTRL+T",
    actions = "CTRL+A", ["repeat"] = "CTRL+L", stopSpeech = "CTRL+SHIFT+S", resetSpeech = "CTRL+SHIFT+R",
}

-- Brings an older file up to DEFAULTS.configVersion. Returns true when something changed.
local function migrate(user)
    local version = tonumber(user.configVersion) or 1
    if version >= DEFAULTS.configVersion then return false end
    if version < 2 and type(user.keys) == "table" then
        for id, old in pairs(V1_KEYS) do
            if user.keys[id] == old then user.keys[id] = nil end
        end
    end
    user.configVersion = DEFAULTS.configVersion
    Log.Info("config.json migrated from version " .. version)
    return true
end

-- Defaults filled in where the player's file has nothing; a key action may be a string or a list.
-- Sets state.added when a default had to be filled in (the file is then rewritten with it).
local function merge(defaults, user, path, state)
    local out = {}
    for k, def in pairs(defaults) do
        local v = user[k]
        local p = path .. k
        local isKeyList = path == "keys." and type(v) == "table"
        if v == nil then
            out[k] = def
            state.added = true
        elseif type(def) == "table" and type(v) == "table" then
            out[k] = merge(def, v, p .. ".", state)
        elseif type(v) == type(def) or isKeyList then
            out[k] = v
        else
            Log.Error(string.format("config %s: expected %s, got %s; using the default", p, type(def), type(v)))
            out[k] = def
        end
    end
    for k in pairs(user) do
        if defaults[k] == nil then Log.Error("config: unknown setting " .. path .. tostring(k) .. " (ignored)") end
    end
    return out
end

function Config.Load()
    local text = Ext.IO.LoadFile(PATH)
    local user = nil
    if text then
        local ok, parsed = pcall(Ext.Json.Parse, text)
        if ok and type(parsed) == "table" then
            user = parsed
        else
            Log.Error("config.json could not be read (" .. tostring(parsed) .. "); using defaults")
        end
    end
    local state = {}
    if user and migrate(user) then state.added = true end
    Config.values = merge(DEFAULTS, user or {}, "", state)
    -- New file, or new settings added by a mod update: write the merged values (the player's own
    -- values are kept). A file that could not be parsed is left alone for the player to fix.
    if not text or (user and state.added) then
        Ext.IO.SaveFile(PATH, Ext.Json.Stringify(Config.values, { Beautify = true }))
        Log.Info("wrote " .. PATH)
    end
    return Config.values
end

-- Config.Get("speech.screenHints")
function Config.Get(path)
    local v = Config.values or Config.Load()
    for part in path:gmatch("[^.]+") do
        if type(v) ~= "table" then return nil end
        v = v[part]
    end
    return v
end

-- Sets a value (Config.Set("speech.barks", "party")) and saves the file. Returns ok.
function Config.Set(path, value)
    local v = Config.values or Config.Load()
    local parts = {}
    for part in path:gmatch("[^.]+") do parts[#parts + 1] = part end
    for i = 1, #parts - 1 do
        if type(v[parts[i]]) ~= "table" then return false end
        v = v[parts[i]]
    end
    v[parts[#parts]] = value
    Ext.IO.SaveFile(PATH, Ext.Json.Stringify(Config.values, { Beautify = true }))
    return true
end

-- Combos bound to an action, as a list.
function Config.KeysFor(action)
    local v = Config.Get("keys." .. action)
    if type(v) == "string" then
        if v == "" then return {} end
        return { v }
    end
    if type(v) == "table" then return v end
    return {}
end

return Config
