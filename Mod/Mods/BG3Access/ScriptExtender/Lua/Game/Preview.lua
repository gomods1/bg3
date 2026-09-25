-- The game's targeting preview for the hovered target while an action is armed (client), from
-- CurrentPlayer.UIData (verified 2026-09-24, main-hand attack on an imp):
--   HitChanceDesc (gui::VMHitChanceDescription: TotalHitChance, Advantages[], Disadvantages[],
--     Modifiers[], ShowDescription), DamagePreviewWithResistances (ls.VMMinMaxPair: Min, Max),
--   MovementResourceCostPreview (Cost, ValueAfterUse: meters walked first),
--   ActiveTask (gui::VMActiveTaskInfo: CanExecute, AoOWarning, LethalOutcome, SurfaceMessage
--     handle, unknown when there is no surface; Info[] = the lines under the cursor: Text handle,
--     TextContext "HitChance" (the percentage, a ResStr) or "SoftWarning" ("¡Un obstáculo bloquea
--     el paso!", verified 2026-09-24 on Gimblebock behind a wall)).
-- With nothing armed, hovering the ground in combat previews the walk there (Cost, ValueAfterUse,
-- CanExecute; verified 2026-09-24).
-- These are previews: they must never be announced as events (gate.md 9, PreviewGuard).
local Vm = Ext.Require("Game/Vm.lua")
local Player = Ext.Require("Game/Player.lua")

local Preview = {}

-- { hitChance?, damageMin?, damageMax?, moveCost?, moveLeft?, canExecute, opportunityAttack,
--   lethal, advantages = n, disadvantages = n, surface? (game text), messages = { game texts:
--   why an action is not possible, warnings } }
function Preview.Read()
    local ui = Vm.Get(Player.Current(), "UIData")
    local hit = Vm.Get(ui, "HitChanceDesc")
    local dmg = Vm.Get(ui, "DamagePreviewWithResistances")
    local move = Vm.Get(ui, "MovementResourceCostPreview")
    local task = Vm.Get(ui, "ActiveTask")
    local out = {
        canExecute = Vm.Get(task, "CanExecute") == true,
        opportunityAttack = Vm.Get(task, "AoOWarning") == true,
        lethal = Vm.Get(task, "LethalOutcome") == true,
        advantages = #Vm.List(hit, "Advantages"),
        disadvantages = #Vm.List(hit, "Disadvantages"),
        surface = Vm.Text(task, "SurfaceMessage"),
        messages = {},
    }
    for _, info in ipairs(Vm.List(task, "Info")) do
        local text = Vm.Enum(info, "TextContext") ~= "HitChance" and Vm.Text(info, "Text")
        if text then out.messages[#out.messages + 1] = text end
    end
    if Vm.Get(hit, "ShowDescription") == true then out.hitChance = Vm.Get(hit, "TotalHitChance") end
    local mn, mx = Vm.Get(dmg, "Min"), Vm.Get(dmg, "Max")
    if mx and mx > 0 then out.damageMin, out.damageMax = mn, mx end
    local cost = Vm.Get(move, "Cost")
    if cost and cost > 0.05 then out.moveCost, out.moveLeft = cost, Vm.Get(move, "ValueAfterUse") end
    return out
end

-- Actions that take several targets (Magic Missile: 3 darts; verified 2026-09-24): the armed
-- task's ActiveTask.TargetValues { MaxValue 3, Remaining: the hotbar's "Proyectiles" counter
-- shows Remaining + 1 (HotBar.xaml AddConverter): 2 after the first dart (Remaining 1), 1 after
-- the second (Remaining 0) }; each target confirmed adds one, the last one casts; ActiveTask.CanForceCast allows casting with fewer
-- (the HotBar's ForceCastButton: ForceCastCommand, no parameter). { chosen, max, canCast } or nil
-- for single-target actions.
function Preview.Targets()
    local task = Vm.Get(Vm.Get(Player.Current(), "UIData"), "ActiveTask")
    local tv = Vm.Get(task, "TargetValues")
    local max = Vm.Get(tv, "MaxValue") or 0
    if max <= 1 then return nil end
    local left = (Vm.Get(tv, "Remaining") or (max - 1)) + 1
    return { chosen = max - left, max = max, canCast = Vm.Get(task, "CanForceCast") == true }
end

-- Casts a several-target action with the targets chosen so far. Returns ok.
function Preview.CastNow()
    return Vm.Run(Vm.WidgetDc("HotBar"), "ForceCastCommand", nil)
end

return Preview
