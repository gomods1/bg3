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

-- Every element named name under root, in visual order (for item templates: one per item, in the
-- order their panel lays them out).
function Ui.FindAllByName(root, name, out)
    out = out or {}
    if root == nil then return out end
    if Ui.Name(root) == name then out[#out + 1] = root end
    for _, c in ipairs(Ui.Kids(root)) do Ui.FindAllByName(c, name, out) end
    return out
end

-- The text a TextBlock shows when it is built from runs (ls:CtxTransStringRunGeneratorBehavior
-- fills Inlines with Span / LSSpan / Run / LSRun elements whose Text is stored locally, so it
-- reads, unlike a bound Text; verified 2026-09-24 on the reaction prompt: "Tav ha usado Ataque con
-- la mano hábil con Quelenna. Tav necesita 13 para superar la tirada. Ha sacado 9."). nil if empty.
function Ui.InlineText(textBlock)
    local parts = {}
    local function walk(coll, depth)
        if not coll or depth > 8 then return end
        local ok, n = pcall(function() return #coll end)
        for i = 1, (ok and n or 0) do
            local inline = coll[i]
            local text = Ui.Prop(inline, "Text")
            if text then parts[#parts + 1] = tostring(text) end
            walk(Ui.Prop(inline, "Inlines"), depth + 1)
        end
    end
    walk(Ui.Prop(textBlock, "Inlines"), 0)
    local s = table.concat(parts):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return s ~= "" and s or nil
end

-- The first TextBlock under root (visual tree order) that shows run-built text, as text.
function Ui.FirstInlineText(root)
    if root == nil then return nil end
    if tostring(root.Type) == "TextBlock" then
        local t = Ui.InlineText(root)
        if t then return t end
    end
    for _, c in ipairs(Ui.Kids(root)) do
        local t = Ui.FirstInlineText(c)
        if t then return t end
    end
    return nil
end

-- The nearest ancestor of el (visual parents) named name, or nil.
function Ui.FindAncestorByName(el, name)
    local p = el
    for _ = 1, 60 do
        local ok, parent = pcall(function() return p.VisualParent end)
        if not (ok and parent) then return nil end
        if Ui.Name(parent) == name then return parent end
        p = parent
    end
    return nil
end

-- The item an element of an item template shows: the generated container's Content (stored
-- locally by the item generator, so readable, unlike the element's bound DataContext; verified
-- on the level-up spell buttons).
function Ui.TemplateItem(el)
    return Ui.Prop(Ui.Prop(el, "TemplatedParent"), "Content")
end

-- The layout cell of an item-template element: its generated container (the element's templated
-- parent) and the panel that lays the containers out.
function Ui.ItemCell(el)
    local cell = Ui.Prop(el, "TemplatedParent")
    local panel = nil
    pcall(function() panel = cell.VisualParent end)
    return cell, panel
end

-- Screen pixels per UI unit, and the client size in pixels. The UI is laid out at a height of
-- 2160 units and scaled uniformly: CanvasRoot 2560x1600 > Viewbox 2560x1600 > Decorator
-- 3456x2160 (verified).
function Ui.Scale()
    local root = Ext.UI.GetRoot()
    local w, h = Ui.Prop(root, "ActualWidth") or 0, Ui.Prop(root, "ActualHeight") or 0
    local viewbox = Ui.Kids(root)[1]
    local inner = viewbox and Ui.Kids(viewbox)[1]
    local ih = inner and Ui.Prop(inner, "ActualHeight") or 0
    return (ih > 0) and (h / ih) or 1, w, h
end

-- Collapsed elements measure 0; an element whose size cannot be read counts as shown.
function Ui.IsShown(el)
    local w = Ui.Prop(el, "ActualWidth")
    return w == nil or w > 0
end

-- Widgets that are never "the screen in front": fades, overlays, drag previews, and toasts
-- (NotificationWidget: notifications get their own reader, M1). Left/RightPlayer are transient
-- during loading.
local OVERLAYS = {
    ScreenFade = true, CrossplayOverlay = true, RightPlayer = true, LeftPlayer = true, ModDownloadingWidget = true,
    AlwaysOnTopOverlay = true, NotificationWidget = true, DragAndDropPreview = true, Overlay = true,
}

-- The in-game HUD (Running state, StateMachines/Keyboard.xaml): always open while playing, never
-- "the screen in front". The play-mode tracker, not the screen router, handles exploration.
local HUD = {
    OverheadInfo = true, HudIndicator = true, Minimap = true, TargetInfo = true, CombatantsOverlay = true,
    CombatLog = true, TurnModeInfo = true, WorldTooltips = true, HotBar = true, PlayerPortraits = true,
    CursorText = true, PassiveRoll = true, WorldContextMenu = true,
}

-- A top-level widget's identity: its x:Name, else its ls:UIWidget.ContextName (some pages, e.g.
-- KeybindingOptions.xaml, have no x:Name).
function Ui.WidgetName(w)
    local name = Ui.Name(w)
    if name then return name end
    local ctx = Ui.Prop(w, "ContextName")
    if ctx ~= nil and tostring(ctx) ~= "" then return tostring(ctx) end
    return nil
end

-- Open, visible top-level widgets in z-order (last = front): { {name=, el=, dcType=, hud=} }.
-- The UI state machine hides the widgets of lower states (e.g. the HUD under character creation,
-- HideStatesBelow in StateMachines/Keyboard.xaml): their IsVisible reads false.
function Ui.Widgets()
    local out = {}
    local root = Ext.UI.GetRoot()
    local contentRoot = Ui.FindByName(root, "ContentRoot")
    if not contentRoot then return out end
    for _, w in ipairs(Ui.Kids(contentRoot)) do
        local name = Ui.WidgetName(w)
        if name and not OVERLAYS[name] and Ui.Prop(w, "IsVisible") ~= false then
            local dc = Ui.Prop(w, "DataContext")
            out[#out + 1] = { name = name, el = w, dcType = dc and tostring(dc.Type) or nil, hud = HUD[name] == true }
        end
    end
    return out
end

-- Name of the visible top-level widget under the mouse pointer (HUD included), or nil when the
-- pointer is over the world. Verified: HotBar reports IsMouseOver over the hotbar, no widget at
-- the screen center. A world click must never land on the UI.
function Ui.WidgetUnderPointer()
    local root = Ui.FindByName(Ext.UI.GetRoot(), "ContentRoot")
    for _, w in ipairs(Ui.Kids(root)) do
        if Ui.Prop(w, "IsVisible") ~= false and Ui.Prop(w, "IsMouseOver") == true then return Ui.WidgetName(w) or "?" end
    end
    return nil
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

-- The front non-HUD widget, or nil; second result: whether the HUD is showing.
function Ui.FrontWidget()
    local ws = Ui.Widgets()
    local hud = false
    for i = #ws, 1, -1 do
        if not ws[i].hud then return ws[i], hud end
        hud = true
    end
    return nil, hud
end

-- The front widget when it needs the player (a dialogue, a loot window...), else nil: transient
-- overlays such as the save indicator do not count (an autosave on the way into the grove stopped
-- a walk, 2026-09-24).
local TRANSIENT = { Saving = true }
function Ui.FrontBlockingWidget()
    local w = Ui.FrontWidget()
    if w and TRANSIENT[w.name] then return nil end
    return w
end

-- Widget name (x:Name or ContextName) -> XAML index entry; keyboard/mouse pages win over the
-- controller variants ("_c" files).
local pagesByWidget = nil
local function indexPages()
    pagesByWidget = {}
    for stem, page in pairs(XamlIndex) do
        local controller = stem:sub(-2) == "_c"
        for _, key in ipairs({ page.root, page.context }) do
            if key and (pagesByWidget[key] == nil or not controller) then pagesByWidget[key] = page end
        end
    end
end

-- XAML index entry for a widget: by file stem (keyboard/mouse page first, then the controller
-- page), else by the page's root x:Name or ContextName (e.g. widget DMSettings = NewGameSettings.xaml).
function Ui.Page(widgetName)
    local page = XamlIndex[widgetName] or XamlIndex[widgetName .. "_c"]
    if page then return page end
    if not pagesByWidget then indexPages() end
    return pagesByWidget[widgetName]
end

Ui.XamlIndex = XamlIndex

return Ui
