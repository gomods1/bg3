-- One-of-many choices held by a view model as a collection plus a selected item (character
-- creation's race, class, subclass...; the level up's subclass): SelectableSubClasses +
-- SelectedSubClass. Selecting sets the selected property on the DC (verified in character
-- creation: the game reacts as to a click).
local Vm = Ext.Require("Game/Vm.lua")

local Selectable = {}

-- Identity of a selectable view model (Guid is empty for origins and classes).
function Selectable.Key(vm)
    return tostring(Vm.Get(vm, "Guid") or "") .. "|" .. tostring(Vm.Get(vm, "IDString") or "") .. "|" .. tostring(Vm.Get(vm, "Name") or "")
end

-- { label, description, selected, available, reason } of one choice.
function Selectable.Snapshot(vm, selectedKey)
    return {
        label = Vm.Text(vm, "Name") or "?",
        description = Vm.Text(vm, "Description"),
        selected = selectedKey ~= nil and Selectable.Key(vm) == selectedKey,
        available = Vm.Get(vm, "IsSelectable") ~= false,
        reason = Vm.Text(vm, "DisableReason"),
    }
end

-- spec = { list = collection property, selected = selected-item property }.
-- The choices of dc as snapshots (empty when there are none).
function Selectable.List(dc, spec)
    local sel = Vm.Get(dc, spec.selected)
    local selectedKey = sel and Selectable.Key(sel) or nil
    local out = {}
    for i, vm in ipairs(Vm.List(dc, spec.list)) do out[i] = Selectable.Snapshot(vm, selectedKey) end
    return out
end

-- The selected choice's snapshot, or nil.
function Selectable.Current(dc, spec)
    local sel = Vm.Get(dc, spec.selected)
    if not sel then return nil end
    return Selectable.Snapshot(sel, Selectable.Key(sel))
end

-- Selects choice i. Returns ok.
function Selectable.Select(dc, spec, i)
    local item = Vm.List(dc, spec.list)[i]
    if not item or Vm.Get(item, "IsSelectable") == false then return false end
    return pcall(function() dc:SetProperty(spec.selected, item) end)
end

return Selectable
