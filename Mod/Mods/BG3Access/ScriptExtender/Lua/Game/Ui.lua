-- Noesis UI access (client). The ONLY place that walks the visual tree or names XAML elements.
-- Facts (SE v32, game 4.1.1.7398727, verified 2026-09-24):
--  * VisualChild/Child indexes are 1-based.
--  * FrameworkElement:Find() does not cross name scopes: search by walking (Ui.FindByName).
--  * GetProperty returns only locally stored values: bound values (Content, Text, Visibility from
--    bindings) read as nil. Read view models instead, or labels from the XAML index.
--  * IsMouseOver reads true while hovered (usable to verify a cursor warp before clicking).
local XamlIndex = Ext.Require("Game/XamlIndex.lua")

local Ui = {}

function Ui.Prop(el, name)
    local ok, v = pcall(function() return el:GetProperty(name) end)
    if ok then return v end
    return nil
end

function Ui.Name(el)
    local n = Ui.Prop(el, "Name")
    if n == nil or n == "" then return nil end
    return tostring(n)
end

function Ui.Kids(el)
    local out, n = {}, 0
    pcall(function() n = el.VisualChildrenCount end)
    if (n or 0) > 0 then
        for i = 1, n do
            local ok, c = pcall(function() return el:VisualChild(i) end)
            if ok and c then out[#out + 1] = c end
        end
    else
        pcall(function() n = el.ChildrenCount end)
        for i = 1, (n or 0) do
            local ok, c = pcall(function() return el:Child(i) end)
            if ok and c then out[#out + 1] = c end
        end
    end
    return out
end

function Ui.FindByName(root, name)
    if root == nil then return nil end
    if Ui.Name(root) == name then return root end
    for _, c in ipairs(Ui.Kids(root)) do
        local f = Ui.FindByName(c, name)
        if f then return f end
    end
    return nil
end

function Ui.Loca(handle)
    if not handle then return nil end
    local ok, s = pcall(Ext.Loca.GetTranslatedString, handle)
    if ok and s and s ~= "" then return s end
    return nil
end

-- Widgets that are always present or never interesting as "the screen in front".
local OVERLAYS = { ScreenFade = true, CrossplayOverlay = true, RightPlayer = true, LeftPlayer = true, ModDownloadingWidget = true } -- Left/RightPlayer: transient during loading (splitscreen slots?)

-- Open top-level widgets in z-order (last = front): { {name=, el=, dcType=} }.
function Ui.Widgets()
    local out = {}
    local root = Ext.UI.GetRoot()
    local contentRoot = Ui.FindByName(root, "ContentRoot")
    if not contentRoot then return out end
    for _, w in ipairs(Ui.Kids(contentRoot)) do
        local name = Ui.Name(w)
        if name and not OVERLAYS[name] then
            local dc = Ui.Prop(w, "DataContext")
            out[#out + 1] = { name = name, el = w, dcType = dc and tostring(dc.Type) or nil }
        end
    end
    return out
end

-- Engine objects expire at the end of the tick: store names, and look elements up again when used.
function Ui.FindWidget(name)
    for _, w in ipairs(Ui.Widgets()) do
        if w.name == name then return w.el end
    end
    return nil
end

function Ui.FindElement(widgetName, elName)
    local w = Ui.FindWidget(widgetName)
    if not w then return nil end
    if elName == nil then return w end
    return Ui.FindByName(w, elName)
end

function Ui.FrontWidget()
    local ws = Ui.Widgets()
    return ws[#ws]
end

-- XAML index entry for a widget (keyboard/mouse page first, then the controller page).
function Ui.Page(widgetName)
    return XamlIndex[widgetName] or XamlIndex[widgetName .. "_c"]
end

Ui.XamlIndex = XamlIndex

return Ui
