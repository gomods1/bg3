-- Combat state (client), from the turn order bar (widget CombatantsOverlay, gui::DCCombatants;
-- verified 2026-09-24 in the first nautiloid fight): DC.Combatants[] (ls.Combatant: Order,
-- CurrentCombatant = the character VM), DC.CurrentCombat (ls.VMCombat: CombatGuid). The party acts
-- together: several combatants can have IsCurrentTurn at once.
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")
local Characters = Ext.Require("Game/Characters.lua")

local Combat = {}

local WIDGET = "CombatantsOverlay"

local function dc()
    local root = Ui.FindByName(Ext.UI.GetRoot(), "ContentRoot")
    for _, w in ipairs(Ui.Kids(root)) do
        if Ui.WidgetName(w) == WIDGET and Ui.Prop(w, "IsVisible") ~= false then return Vm.Get(w, "DataContext") end
    end
    return nil
end

-- Whether the HUD is showing (the hotbar is visible). The game menu, the map and other screens
-- hide the whole HUD, the turn order bar included, in the middle of a fight: Current() then reads
-- nil although the fight goes on ("Fin del combate" was said on opening the game menu, and
-- "Combate" again on closing it, 2026-09-25).
function Combat.HudShown()
    return Ui.FindWidget("HotBar") ~= nil
end

-- Combat id (string) while a combat is running, else nil.
function Combat.Current()
    local d = dc()
    local c = Vm.Get(d, "CurrentCombat")
    if not c or #Vm.List(d, "Combatants") == 0 then return nil end
    return tostring(Vm.Get(c, "CombatGuid"))
end

-- Combatants in turn order: Game/Characters snapshots with .order. Empty outside combat.
function Combat.Combatants()
    local out = {}
    for _, c in ipairs(Vm.List(dc(), "Combatants")) do
        local s = Characters.Snapshot(Vm.Get(c, "CurrentCombatant"))
        if s then
            s.order = Vm.Get(c, "Order")
            out[#out + 1] = s
        end
    end
    table.sort(out, function(a, b) return (a.order or 0) < (b.order or 0) end)
    return out
end

local function combatantVm(uuid)
    for _, c in ipairs(Vm.List(dc(), "Combatants")) do
        local ch = Vm.Get(c, "CurrentCombatant")
        if Vm.Get(ch, "EntityUUID") == uuid then return ch end
    end
    return nil
end

-- Centres the camera on the combatant with this UUID (the HotBar DC's SetCameraOnGameObject, as
-- the game does for a portrait; verified 2026-09-24: Taman, 19 m away and off screen, came to the
-- screen centre and the cursor there showed the attack preview). Returns ok.
function Combat.CenterCameraOn(uuid)
    local ch = combatantVm(uuid)
    if not ch then return false end
    return Vm.Run(Vm.WidgetDc("HotBar"), "SetCameraOnGameObject", ch)
end

-- Uses the armed action (Game/Hotbar.Use) on the combatant with this UUID through the game's own
-- command: the HotBar DC's TargetGameobjectCommand(character VM), which is what a click on a
-- portrait does with an action armed. Verified 2026-09-24: with the main-hand attack armed, the
-- character walked to the imp and attacked it (action spent, imp killed); no mouse involved.
-- Returns ok.
function Combat.TargetArmedAction(uuid)
    local ch = combatantVm(uuid)
    if not ch then return false end
    return Vm.Run(Vm.WidgetDc("HotBar"), "TargetGameobjectCommand", ch)
end

return Combat
