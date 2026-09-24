-- Generic handler for screens with no dedicated handler: a virtual list built from the XAML index
-- (static texts and buttons in document order), filtered by what exists in the live tree.
-- Up/Down move, Enter/Space activate, Home/End jump. A screen with no handler is clumsy, never dead.
local Ui = Ext.Require("Game/Ui.lua")
local Activate = Ext.Require("Game/Activate.lua")
local Speech = Ext.Require("Core/Speech.lua")
local Text = Ext.Require("Core/Text.lua")

local Generic = {}
Generic.__index = Generic

local function isShown(el)
    local w = Ui.Prop(el, "ActualWidth")
    return w == nil or w > 0 -- collapsed elements measure 0
end

local function isButton(item)
    return item.command ~= nil or (item.type or ""):find("Button") ~= nil
end

-- Option rows (view models with Text/ListItemType/SelectedItem/ComboItems, in the widget data
-- context's "Options" collection: first-time setup, and likely the options menu). Values change
-- through the context's Prev/NextComboItemCommand with the row as parameter; they apply on a later
-- frame (deferred commands).
local function optionRows(widgetName)
    local w = Ui.FindWidget(widgetName)
    local dc = w and Ui.Prop(w, "DataContext")
    local rows = dc and Ui.Prop(dc, "Options")
    return dc, rows
end

local function describeRow(row)
    local label = Text.Clean(Ui.Loca(Ui.Prop(row, "Text"))) or "Option"
    local kind = tostring(Ui.Prop(row, "ListItemType") or "")
    if kind == "ComboBox" then
        local sel = Ui.Prop(row, "SelectedItem")
        local value = sel and Text.Clean(Ui.Loca(Ui.Prop(sel, "Name"))) or "?"
        local items = Ui.Prop(row, "ComboItems")
        local pos = ""
        if items and sel then
            for i = 1, #items do
                if Ui.Prop(items[i], "Name") == Ui.Prop(sel, "Name") then pos = string.format(", %d of %d", i, #items) end
            end
        end
        local s = string.format("%s: %s, list%s", label, value, pos)
        if Ui.Prop(row, "Enabled") == false then s = s .. ", unavailable" end
        return s
    end
    return label .. ", " .. kind
end

-- opts: { buttonsOnly = true } drops static texts (for screens whose hidden panels carry labels
-- that cannot be visibility-checked, e.g. the main menu).
function Generic.New(widget, page, friendlyName, opts)
    opts = opts or {}
    local self = setmetatable({}, Generic)
    self.widget = widget.name
    self.page = page
    self.title = (page and Ui.Loca(page.title)) or friendlyName or widget.name
    self.items = {}
    self.index = 0
    local seen = {}
    if page then
        for _, item in ipairs(page.items) do
            local text = Text.Clean(Ui.Loca(item.label))
            local key = (text or "") .. "|" .. (item.command or "") .. "|" .. (item.param or "")
            if text and item.label ~= page.title and not seen[key] and (isButton(item) or not opts.buttonsOnly) then
                local el = item.name and Ui.FindByName(widget.el, item.name) or nil
                -- Named elements must exist and be shown; unnamed static texts are kept.
                if (item.name == nil and not isButton(item)) or (el and isShown(el)) then
                    seen[key] = true
                    self.items[#self.items + 1] = { item = item, text = text, button = isButton(item) }
                end
            end
        end
    end
    -- Option rows go before the first button.
    local _, rows = optionRows(widget.name)
    if rows and #rows > 0 then
        local at = #self.items + 1
        for i, e in ipairs(self.items) do
            if e.button then at = i break end
        end
        for r = #rows, 1, -1 do
            table.insert(self.items, at, { option = r, text = "option " .. r })
        end
    end
    return self
end

function Generic:Describe(entry)
    if entry.option then
        local _, rows = optionRows(self.widget)
        local row = rows and rows[entry.option]
        return row and describeRow(row) or "option gone"
    end
    if not entry.button then return entry.text end
    local s = entry.text .. ", button"
    local el = entry.item.name and Ui.FindElement(self.widget, entry.item.name)
    if el and entry.item.command and not entry.item.param then
        local cmd = Ui.Prop(el, "Command")
        local ok, can = pcall(function() return cmd and cmd:CanExecute(nil) end)
        if ok and can == false then s = s .. ", unavailable" end
    end
    return s
end

function Generic:Open()
    local n = #self.items
    if n == 0 then
        Speech.Say(self.title)
        return
    end
    local buttons = 0
    for _, e in ipairs(self.items) do if e.button then buttons = buttons + 1 end end
    local options = 0
    for _, e in ipairs(self.items) do if e.option then options = options + 1 end end
    Speech.Say(string.format("%s. %d items, %d buttons%s. Up and down arrows to read, Enter to activate%s.",
        self.title, n, buttons, options > 0 and string.format(", %d options", options) or "",
        options > 0 and ", left and right to change an option" or ""))
end

function Generic:Move(delta)
    local n = #self.items
    if n == 0 then Speech.Say(self.title .. ", nothing to read") return end
    local i = self.index + delta
    if i < 1 then i = 1 elseif i > n then i = n end
    self.index = i
    Speech.Say(self:Describe(self.items[i]), { interrupt = true })
end

function Generic:Jump(i)
    if #self.items == 0 then return end
    self.index = (i < 0) and #self.items or 1
    Speech.Say(self:Describe(self.items[self.index]), { interrupt = true })
end

function Generic:ActivateCurrent()
    local e = self.items[self.index]
    if not e then Speech.Say("Nothing selected") return end
    if not e.button then Speech.Say(e.text) return end
    Activate.Element(self.widget, e.item.name, e.item, function(ok, reason)
        if not ok then Speech.Say(e.text .. ": could not activate, " .. tostring(reason)) end
    end)
end

function Generic:ReadAll()
    local parts = { self.title }
    for _, e in ipairs(self.items) do parts[#parts + 1] = self:Describe(e) end
    Speech.Say(table.concat(parts, ". "))
end

function Generic:ChangeOption(entry, delta)
    local dc, rows = optionRows(self.widget)
    local row = rows and rows[entry.option]
    if not row then return end
    local cmd = Ui.Prop(dc, delta > 0 and "NextComboItemCommand" or "PrevComboItemCommand")
    if not cmd then Speech.Say("cannot change this option") return end
    cmd:Execute(row)
    local index, widget = entry.option, self.widget
    Ext.Timer.WaitForRealtime(150, function()
        local _, rows2 = optionRows(widget)
        local r = rows2 and rows2[index]
        local sel = r and Ui.Prop(r, "SelectedItem")
        if sel then Speech.Say(Text.Clean(Ui.Loca(Ui.Prop(sel, "Name"))) or "?", { interrupt = true }) end
    end)
end

-- combo -> handled
function Generic:OnKey(combo)
    local cur = self.items[self.index]
    if cur and cur.option and (combo == "LEFT" or combo == "RIGHT") then
        self:ChangeOption(cur, combo == "RIGHT" and 1 or -1)
        return true
    end
    if combo == "DOWN" then self:Move(1) return true end
    if combo == "UP" then self:Move(-1) return true end
    if combo == "HOME" then self:Jump(1) return true end
    if combo == "END" then self:Jump(-1) return true end
    if combo == "RETURN" or combo == "SPACE" or combo == "KP_ENTER" then self:ActivateCurrent() return true end
    return false
end

return Generic
