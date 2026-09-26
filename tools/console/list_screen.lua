-- The current mod screen's controls as spoken, numbered (index marked with *).
-- python tools/game.py lua-file tools/console/list_screen.lua
local h = BG3Access.Router.handler
if not h then return "no screen: " .. tostring(BG3Access.Router.current) end
local out = { tostring(BG3Access.Router.current) .. " | " .. tostring(h.title) }
for i, c in ipairs(h.controls or {}) do
    local ok, text = pcall(c.Describe)
    out[#out + 1] = (i == h.index and "*" or " ") .. i .. " " .. tostring(ok and text or ("error " .. tostring(text)))
end
return table.concat(out, "\n")
