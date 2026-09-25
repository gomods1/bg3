-- Dump the game's input bindings (client) through the input scheme's raw-input -> binding map.
-- (InputBindings[player] is a LegacyArray whose elements after the first read as garbage on SE v32.)
-- Output: BG3Access/dev/bindings.txt, one line per keyboard/mouse binding: input, modifiers, event.
-- Run with: python tools/game.py lua-file tools/console/dump_bindings.lua
local im = Ext.Input.GetInputManager()
local defs = im.InputDefinitions
local lines = {}
local raw = im.InputScheme.RawToBinding
for i = 1, #raw do
    local mapping = raw[i]
    for _, desc in ipairs(mapping.Bindings) do
        local b = desc.Binding
        local def = defs[desc.InputIndex]
        local name = def and tostring(def.EventName) or ("#" .. tostring(desc.InputIndex))
        local mods = {}
        for k, v in pairs(b.Modifiers) do
            if v == true then mods[#mods + 1] = tostring(k) end
            if type(k) == "number" then mods[#mods + 1] = tostring(v) end
        end
        table.sort(mods)
        lines[#lines + 1] = string.format("%-8s %-22s %-18s %s", tostring(b.DeviceId), tostring(b.InputId),
            table.concat(mods, "+"), name)
    end
end
table.sort(lines)
Ext.IO.SaveFile("BG3Access/dev/bindings.txt", table.concat(lines, "\n") .. "\n")
return #lines .. " bindings"
