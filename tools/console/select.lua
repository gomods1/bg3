-- Puts the current mod list's cursor on the first control whose spoken text contains PATTERN
-- (plain text), and returns it. Usage: python tools/game.py lua-file tools/console/select.lua "PATTERN='Puertas'"
local h = BG3Access.Router.handler
if not h then return "no screen" end
for i, c in ipairs(h.controls or {}) do
    local ok, text = pcall(c.Describe)
    if ok and text and text:find(PATTERN, 1, true) then
        h.index = i
        return i .. " " .. text
    end
end
return "not found: " .. tostring(PATTERN)
