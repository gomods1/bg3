"""Runs the mod's offline Lua tests: tests/lua/*_test.lua, each in a fresh Lua 5.4 state.

    python tools/test_lua.py            # every test file
    python tools/test_lua.py strings    # files whose name contains "strings"

Lua comes from lupa (pip install lupa; PyPI, chosen 2026-09-26: no Lua interpreter on the machine,
lupa bundles Lua 5.4 = the Script Extender's version). The Script Extender API is stubbed just
enough for the pure modules (Core/Strings, Core/Text, Core/Keys, Core/Poll, Core/Recent,
Combat/Words...): Ext.Require resolves against the mod's Lua folder, Ext.Events.Tick / KeyInput
record their subscribers, Ext.Timer.MonotonicTime reads a clock the test moves, Ext.IO keeps files
in memory. Engine objects (UI, view models, entities) are not stubbed: what needs them is tested in
the running game (PLAYTEST.md).

A test file gets two globals:
    T.case(name, fn)             one test; fn raises on failure
    T.eq(got, want, msg?)        equality (tables compared by content)
    T.truthy(v, msg?) / T.falsy(v, msg?)
    T.errors(fn, msg?)           fn must raise
    Test.clock                   the stub's monotonic time, ms (Test.advance(ms) moves it and fires
                                 due WaitForRealtime callbacks, then one Tick)
    Test.tick()                  runs every Tick subscriber once
    Test.key(table)              sends a KeyInput event { Key=, Modifiers=, Pressed=, Repeat= };
                                 returns true when a handler called PreventAction
    Test.language                the game language the stub reports ("English" by default)
    Test.errors                  lines passed to Ext.Utils.PrintError
    Test.files                   the in-memory file table of Ext.IO
Exit code 1 when any case fails.
"""
import os
import sys

try:
    from lupa import lua54
except ImportError:  # pragma: no cover
    sys.exit("lupa is missing: python -m pip install lupa")

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LUA = os.path.join(REPO, "Mod", "Mods", "BG3Access", "ScriptExtender", "Lua")
TESTS = os.path.join(REPO, "tests", "lua")

STUB = r"""
local LUA_ROOT = ...
Test = { clock = 100000, language = "English", errors = {}, files = {}, timers = {}, ticks = {}, keys = {}, luaRoot = LUA_ROOT }
local loaded = {}

_P = function(...) end -- the SE console; tests read Test.errors instead

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local s = f:read("a")
    f:close()
    return s
end

Ext = {}
function Ext.Require(path)
    if loaded[path] ~= nil then return loaded[path] end
    local full = LUA_ROOT .. "/" .. path
    local chunk, err = loadfile(full)
    if not chunk then error("Ext.Require(" .. path .. "): " .. tostring(err), 2) end
    local result = chunk()
    if result == nil then result = true end
    loaded[path] = result
    return result
end

Ext.Utils = {
    PrintError = function(s) Test.errors[#Test.errors + 1] = tostring(s) end,
    GetGlobalSwitches = function() return { Language = Test.language } end,
    MonotonicTime = function() return Test.clock end,
    Version = function() return 32 end,
    GameVersion = function() return "v4.73.98.727" end,
}
Ext.Timer = {
    MonotonicTime = function() return Test.clock end,
    MicrosecTime = function() return Test.clock * 1000 end,
    WaitForRealtime = function(ms, fn) Test.timers[#Test.timers + 1] = { at = Test.clock + ms, fn = fn } end,
}
local function event(list)
    return { Subscribe = function(_, fn) list[#list + 1] = fn end }
end
Ext.Events = { Tick = event(Test.ticks), KeyInput = event(Test.keys) }
Ext.IO = {
    LoadFile = function(path) return Test.files[path] end,
    SaveFile = function(path, text) Test.files[path] = text end,
}
-- Minimal JSON for Core/Config (objects, arrays, strings, numbers, booleans).
local function encode(v, indent)
    local t = type(v)
    if t == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        if #keys > 0 and #keys == #v then
            local parts = {}
            for _, x in ipairs(v) do parts[#parts + 1] = encode(x, indent) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = string.format("%q:%s", tostring(k), encode(v[k], indent)) end
        return "{" .. table.concat(parts, ",") .. "}"
    elseif t == "string" then
        return string.format("%q", v)
    end
    return tostring(v)
end
Ext.Json = {
    Stringify = function(v) return encode(v) end,
    Parse = function() error("Ext.Json.Parse is not stubbed") end,
}
Ext.Input = { InjectKeyPress = function(code) Test.injected = Test.injected or {}; Test.injected[#Test.injected + 1] = code end }

function Test.tick()
    for _, fn in ipairs(Test.ticks) do fn() end
end

function Test.advance(ms)
    Test.clock = Test.clock + ms
    local due = {}
    for i = #Test.timers, 1, -1 do
        if Test.timers[i].at <= Test.clock then
            due[#due + 1] = Test.timers[i].fn
            table.remove(Test.timers, i)
        end
    end
    for i = #due, 1, -1 do due[i]() end
    Test.tick()
end

function Test.key(e)
    local prevented = false
    e.Pressed = e.Pressed ~= false
    e.Repeat = e.Repeat == true
    e.Modifiers = e.Modifiers or ""
    e.PreventAction = function() prevented = true end
    for _, fn in ipairs(Test.keys) do fn(e) end
    return prevented
end

-- Assertions
T = { passed = 0, failed = 0, failures = {} }
local function show(v)
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. show(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end
local function same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function T.eq(got, want, msg)
    if not same(got, want) then error((msg and msg .. ": " or "") .. "got " .. show(got) .. ", want " .. show(want), 2) end
end
function T.truthy(v, msg) if not v then error((msg or "expected a true value") .. " (got " .. show(v) .. ")", 2) end end
function T.falsy(v, msg) if v then error((msg or "expected a false value") .. " (got " .. show(v) .. ")", 2) end end
function T.errors(fn, msg) if pcall(fn) then error(msg or "expected an error", 2) end end
function T.case(name, fn)
    local ok, err = xpcall(fn, debug.traceback)
    if ok then
        T.passed = T.passed + 1
    else
        T.failed = T.failed + 1
        T.failures[#T.failures + 1] = name .. "\n    " .. tostring(err):gsub("\n", "\n    ")
    end
end
"""


def run_file(path):
    lua = lua54.LuaRuntime(unpack_returned_tuples=True, encoding="utf-8")
    lua.execute("package.path = ''")
    lua.compile(STUB)(LUA.replace("\\", "/"))
    with open(path, encoding="utf-8") as f:
        source = f.read()
    ok = True
    try:
        lua.execute(source)
    except Exception as e:  # a failure outside any case (a syntax error, a missing module)
        print(f"  ERROR loading {os.path.basename(path)}: {e}")
        ok = False
    g = lua.globals()
    t = g.T
    passed, failed = int(t.passed), int(t.failed)
    for i in range(1, failed + 1):
        print(f"  FAIL {t.failures[i]}")
    return passed, failed, ok


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    pattern = sys.argv[1] if len(sys.argv) > 1 else ""
    files = sorted(n for n in os.listdir(TESTS) if n.endswith("_test.lua") and pattern in n)
    if not files:
        sys.exit(f"no test files matching '{pattern}' in {TESTS}")
    total_passed, total_failed, broken = 0, 0, 0
    for name in files:
        passed, failed, ok = run_file(os.path.join(TESTS, name))
        status = "ok" if failed == 0 and ok else "FAILED"
        print(f"{name}: {passed} passed, {failed} failed  {status}")
        total_passed += passed
        total_failed += failed
        broken += 0 if ok else 1
    print(f"total: {total_passed} passed, {total_failed} failed, {broken} files broken")
    sys.exit(1 if total_failed or broken else 0)


if __name__ == "__main__":
    main()
