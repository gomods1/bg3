-- The game's own "highlight interactables" (Left Alt, input event ShowWorldTooltips): the names a
-- sighted player sees over every interactable object and character on screen. Used as the
-- reference for what the player can perceive (gate.md 8.3): the mod lists exactly these.
-- Facts (verified 2026-09-24): widget WorldTooltips, list DC.CurrentPlayer.WorldTooltips of
-- ls.VMWorldTooltip { Name (text), IsItem, ContainerState (NotExplored/Empty/...), IsStealing,
-- GameObject (VM with EntityUUID), Position (screen) }. Empty unless the highlight is on. DC
-- SetShowWorldTooltipsCommand(nil) shows it; hiding needs a boxed false (not passable from Lua), so
-- a Left Alt press is injected instead (the game hides on release).
local Ui = Ext.Require("Game/Ui.lua")
local Vm = Ext.Require("Game/Vm.lua")

local Highlights = {}

local WIDGET = "WorldTooltips"
local SETTLE_MS = 100 -- the list fills on a later frame

local function dc()
    -- The widget belongs to the HUD, so Ui.FindWidget (which skips HUD widgets for screens) is not
    -- used; hidden or not, it stays a child of ContentRoot.
    local root = Ui.FindByName(Ext.UI.GetRoot(), "ContentRoot")
    for _, w in ipairs(Ui.Kids(root)) do
        if Ui.WidgetName(w) == WIDGET then return Vm.Get(w, "DataContext") end
    end
    return nil
end

local function read()
    local out = {}
    for _, t in ipairs(Vm.List(Vm.Get(dc(), "CurrentPlayer"), "WorldTooltips")) do
        local go = Vm.Get(t, "GameObject")
        local uuid = go and Vm.Get(go, "EntityUUID")
        if uuid and uuid ~= "" then
            out[#out + 1] = {
                uuid = uuid,
                name = tostring(Vm.Get(t, "Name") or "?"),
                isItem = Vm.Get(t, "IsItem") == true,
                containerState = Vm.Enum(t, "ContainerState"),
                stealing = Vm.Get(t, "IsStealing") == true,
            }
        end
    end
    return out
end

-- Calls onResult(list) on a later frame with what the highlight shows:
-- { { uuid, name, isItem, containerState, stealing } }. Turns the highlight on and off again.
function Highlights.Read(onResult)
    local ok = Vm.Run(dc(), "SetShowWorldTooltipsCommand", nil)
    Ext.Timer.WaitForRealtime(SETTLE_MS, function()
        local list = ok and read() or {}
        Ext.Input.InjectKeyPress("LALT")
        onResult(list)
    end)
end

-- true while the highlight's names show (some stayed on after Read: three labels over books in
-- the Blighted Village, 2026-09-24).
function Highlights.Showing()
    return #Vm.List(Vm.Get(dc(), "CurrentPlayer"), "WorldTooltips") > 0
end

-- Hides the highlight when it shows (the game's Left Alt: it hides on release). Returns true when
-- it had to.
function Highlights.Hide()
    if not Highlights.Showing() then return false end
    Ext.Input.InjectKeyPress("LALT")
    return true
end

return Highlights
