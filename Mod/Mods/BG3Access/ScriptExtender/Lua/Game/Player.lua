-- The local player's UI view model (client): CurrentPlayer, shared by every in-game widget's data
-- context. Read through the Minimap widget, which is open whenever the game is (verified
-- 2026-09-24). CurrentPlayer.SelectedCharacter is the controlled character's ls.Character VM.
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")

local Player = {}

local SOURCE_WIDGET = "Minimap"

local function sourceDc()
    local root = Ui.FindByName(Ext.UI.GetRoot(), "ContentRoot")
    for _, w in ipairs(Ui.Kids(root)) do
        if Ui.WidgetName(w) == SOURCE_WIDGET then return Vm.Get(w, "DataContext") end
    end
    return nil
end

-- CurrentPlayer (valid this tick), or nil outside the game.
function Player.Current()
    return Vm.Get(sourceDc(), "CurrentPlayer")
end

-- The shared game data view model (DC.Data: combat log, sort comparers, ...), or nil.
function Player.Data()
    return Vm.Get(sourceDc(), "Data")
end

-- The controlled character's VM (valid this tick), or nil.
function Player.SelectedCharacter()
    return Vm.Get(Player.Current(), "SelectedCharacter")
end

-- Names of the party members (AssignedCharacters), as a set: { [name] = true }.
-- The party's chains as the portraits show them: { { names } }, one list per group of characters
-- who move together (CurrentPlayer.PartyGroups[].Characters; one group while all are chained;
-- the game's G key splits the selected character off, verified 2026-09-24).
function Player.PartyGroups()
    local out = {}
    for _, g in ipairs(Vm.List(Player.Current(), "PartyGroups")) do
        local names = {}
        for _, c in ipairs(Vm.List(g, "Characters")) do names[#names + 1] = Vm.Text(c, "Name") or "?" end
        if #names > 0 then out[#out + 1] = names end
    end
    return out
end

-- Entity uuids of the party members (the portraits' characters).
function Player.PartyUuids()
    local out = {}
    for _, c in ipairs(Vm.List(Player.Current(), "AssignedCharacters")) do
        local uuid = Vm.Get(c, "EntityUUID")
        if uuid and uuid ~= "" then out[#out + 1] = tostring(uuid) end
    end
    return out
end

function Player.PartyNames()
    local out = {}
    for _, c in ipairs(Vm.List(Player.Current(), "AssignedCharacters")) do
        local name = Vm.Text(c, "Name")
        if name then out[name] = true end
    end
    return out
end

-- The party's characters in the order of their portraits (AssignedCharacters; the game's F1-F4
-- select them by that position): { { uuid, name, controlled } }.
function Player.Party()
    local out = {}
    local selected = Vm.Get(Player.SelectedCharacter(), "EntityUUID")
    for _, c in ipairs(Vm.List(Player.Current(), "AssignedCharacters")) do
        local uuid = Vm.Get(c, "EntityUUID")
        if uuid and uuid ~= "" then
            out[#out + 1] = { uuid = tostring(uuid), name = Vm.Text(c, "Name"), controlled = uuid == selected }
        end
    end
    return out
end

-- The character VM (valid this tick) of the party member with entity uuid, or nil.
function Player.MemberVm(uuid)
    for _, c in ipairs(Vm.List(Player.Current(), "AssignedCharacters")) do
        if Vm.Get(c, "EntityUUID") == uuid then return c end
    end
    return nil
end

-- function(uuid), called before the mod itself selects a party member (set by Setup/Commands: the
-- combat tracker then announces the switch at once).
Player.OnSelect = nil

-- Selects the party member with entity uuid, as a click on their portrait does (the DC's
-- SelectCharacter with the character's VM, CharacterSelectArea in the portraits' XAML). Returns ok.
function Player.Select(uuid)
    local c = Player.MemberVm(uuid)
    if not c then return false end
    if Player.OnSelect then Player.OnSelect(uuid) end
    return Vm.Run(sourceDc(), "SelectCharacter", c)
end

-- true while it is the local player's turn in combat (CurrentPlayer.IsCurrentTurn).
function Player.IsCurrentTurn()
    return Vm.Get(Player.Current(), "IsCurrentTurn") == true
end

return Player
