-- Every Lua file of the mod compiles (a syntax error in a module the game loads lazily would
-- otherwise only show in the running game). Uses the Windows dir listing through io.popen.
local root = Test.luaRoot

local function files()
    local out = {}
    local p = io.popen('dir /s /b "' .. root:gsub("/", "\\") .. '\\*.lua"')
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end

T.case("every module compiles", function()
    local list = files()
    T.truthy(#list > 100, "expected the mod's modules, found " .. #list)
    local bad = {}
    for _, path in ipairs(list) do
        local chunk, err = loadfile(path)
        if not chunk then bad[#bad + 1] = tostring(err) end
    end
    T.eq(bad, {})
end)
