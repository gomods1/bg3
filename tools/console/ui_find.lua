-- Helpers for dev snippets: UI tree search by element Name (Find() does not cross name scopes).
function UiKids(el)
  local out, n = {}, 0
  pcall(function() n = el.VisualChildrenCount end)
  if n > 0 then for i = 1, n do local c = el:VisualChild(i) if c then out[#out + 1] = c end end
  else pcall(function() n = el.ChildrenCount end) for i = 1, (n or 0) do local c = el:Child(i) if c then out[#out + 1] = c end end end
  return out
end
function UiFind(el, name)
  el = el or Ext.UI.GetRoot()
  local ok, nm = pcall(function() return el:GetProperty("Name") end)
  if ok and nm == name then return el end
  for _, c in ipairs(UiKids(el)) do local f = UiFind(c, name) if f then return f end end
end
