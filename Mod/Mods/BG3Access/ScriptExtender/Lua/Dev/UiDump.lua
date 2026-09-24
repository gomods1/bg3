-- Development: dump the Noesis visual tree (client). Used to map screens (SCREENS.md) and to find the
-- elements and view-model properties each screen handler must read.
local UiDump = {}

local function prop(el, name)
    local ok, v = pcall(function() return el:GetProperty(name) end)
    if ok then return v end
    return nil
end

local function typeName(el)
    local ok, t = pcall(function() return el.Type end)
    if ok and t ~= nil then return tostring(t) end
    return "?"
end

local function short(v)
    if v == nil then return nil end
    local s = tostring(v)
    s = s:gsub("[\r\n]+", " ")
    if #s > 120 then s = s:sub(1, 117) .. "..." end
    return s
end

-- Text-bearing properties worth showing, in order.
local TEXT_PROPS = { "Text", "Content", "Header", "ToolTip", "Title" }

local function describe(el)
    local parts = { typeName(el) }
    local name = prop(el, "Name")
    if name and tostring(name) ~= "" then parts[#parts + 1] = "#" .. tostring(name) end
    local vis = prop(el, "Visibility")
    if vis ~= nil and tostring(vis) ~= "Visible" then parts[#parts + 1] = "vis=" .. tostring(vis) end
    if prop(el, "IsKeyboardFocused") == true then parts[#parts + 1] = "KBFOCUS" end
    if prop(el, "IsFocused") == true then parts[#parts + 1] = "FOCUS" end
    if prop(el, "IsEnabled") == false then parts[#parts + 1] = "disabled" end
    for _, p in ipairs(TEXT_PROPS) do
        local v = prop(el, p)
        if v ~= nil and type(v) ~= "userdata" and tostring(v) ~= "" then
            parts[#parts + 1] = p .. "=" .. short(v)
        end
    end
    local dc = prop(el, "DataContext")
    if dc ~= nil then parts[#parts + 1] = "dc=" .. typeName(dc) end
    return table.concat(parts, " ")
end

-- opts: { depth = 40, visibleOnly = true, path = "BG3Access/dev/ui.txt" }
function UiDump.Dump(opts)
    opts = opts or {}
    local maxDepth = opts.depth or 40
    local lines = {}
    local count = 0
    local function walk(el, depth)
        if el == nil or depth > maxDepth then return end
        count = count + 1
        if opts.visibleOnly ~= false then
            local vis = prop(el, "Visibility")
            if vis ~= nil and tostring(vis) ~= "Visible" then return end
        end
        lines[#lines + 1] = string.rep(" ", depth) .. describe(el)
        -- Child indexes are 1-based in the SE binding. Visual children when the element has them, else logical children (the root canvas and
        -- some panels report no visual children).
        local n = 0
        pcall(function() n = el.VisualChildrenCount end)
        if (n or 0) > 0 then
            for i = 1, n do
                local ok, child = pcall(function() return el:VisualChild(i) end)
                if ok and child then walk(child, depth + 1) end
            end
        else
            pcall(function() n = el.ChildrenCount end)
            for i = 1, (n or 0) do
                local ok, child = pcall(function() return el:Child(i) end)
                if ok and child then walk(child, depth + 1) end
            end
        end
    end
    walk(Ext.UI.GetRoot(), 0)
    local path = opts.path or "BG3Access/dev/ui.txt"
    Ext.IO.SaveFile(path, table.concat(lines, "\n") .. "\n")
    return string.format("%d elements visited, %d lines -> %s", count, #lines, path)
end

UiDump.Prop = prop
UiDump.TypeName = typeName

return UiDump
