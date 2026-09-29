-- Core/Text: game text cleanup before speech.
local Text = Ext.Require("Core/Text.lua")

T.case("Markup is stripped and whitespace collapsed", function()
    T.eq(Text.Clean("<b>Hola</b>   mundo<br/>fin"), "Hola mundo\nfin")
    T.eq(Text.Clean("a &amp; b &lt;c&gt; &quot;d&quot;"), 'a & b <c> "d"')
    T.eq(Text.Clean("  \n\n x \n\n\n y \n"), "x\ny")
end)

T.case("Double stops from templates become one, an ellipsis stays", function()
    T.eq(Text.Clean("contra Azotamentes.."), "contra Azotamentes.")
    T.eq(Text.Clean("Espera..."), "Espera...")
    T.eq(Text.Clean("uno.. dos"), "uno. dos")
end)

T.case("Doubled colons from '[1]: [2]' templates", function()
    T.eq(Text.Clean("Tav: : He oído gritos"), "Tav: He oído gritos")
end)

T.case("Empty text is nil", function()
    T.eq(Text.Clean(nil), nil)
    T.eq(Text.Clean("   "), nil)
    T.eq(Text.Clean("<i></i>"), nil)
end)

T.case("StripStop removes one final stop, not an ellipsis", function()
    T.eq(Text.StripStop("Encuentra una cura."), "Encuentra una cura")
    T.eq(Text.StripStop("Espera..."), "Espera...")
    T.eq(Text.StripStop("戦闘。"), "戦闘")
    T.eq(Text.StripStop("plain"), "plain")
    T.eq(Text.StripStop(nil), nil)
end)
