-- World tooltips on companions: only the holder's own copy gets the lines.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Setup(kariOpts)
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 46 } })
        local kari = w:AddClient("Kari Berg", kariOpts or { pets = { 5159 } })
        w:Run(20)
        ola:Slash("claim")
        w:SkipDays(7)
        ola:Slash("nick Pus")
        w:Run(1)
        return w, ola, kari
    end

    test("the holder's companion shows its nickname and reservation", function()
        local w, ola, kari = Setup()
        local lines = kari:Hover({ species = 46, owner = "Ola Nord" })
        eq(lines[1], '"Pus"')
        match(lines[2], "^Dyreparken: Ola Nord's reserved companion since %d%d %a+ %d%d%d%d$")
        local own = ola:Hover({ species = 46, owner = "Ola Nord" })
        match(own[2], "^Dyreparken: your reserved companion")
    end)

    test("no nickname: just the reservation line", function()
        local w, ola, kari = Setup()
        ola:Slash("nick")
        w:Run(1)
        local lines = kari:Hover({ species = 46, owner = "Ola Nord" })
        eq(#lines, 1)
        match(lines[1], "reserved companion")
    end)

    test("nothing for other copies, free pets, non-companions or no owner", function()
        local w, ola, kari = Setup()
        eq(#kari:Hover({ species = 46, owner = "Fikle Faen" }), 0, "someone else's copy")
        eq(#kari:Hover({ species = 5159, owner = "Kari Berg" }), 0, "not reserved")
        eq(#kari:Hover({ species = 46, owner = "Ola Nord", companion = false }), 0, "not a companion")
        eq(#kari:Hover({ species = 46 }), 0, "no owner line")
        eq(#kari:Hover({ species = H.SECRET, owner = "Ola Nord" }), 0, "secret species")
        eq(#kari:Hover({ species = 46, owner = "Ola Nord", unit = false }), 0, "tooltip without a unit")
        eq(#kari:Hover({ species = 46, owner = "Ola Nord", tooltip = { lines = {} } }), 0, "another tooltip")
        eq(#kari:Hover({ species = 46, lines = { { leftText = "Kitten" }, { leftText = H.SECRET } } }), 0,
            "secret text")
    end)

    test("nothing in combat", function()
        local w, ola, kari = Setup()
        kari:EnterCombat()
        eq(#kari:Hover({ species = 46, owner = "Ola Nord" }), 0)
    end)

    test("without tooltip data, the owner comes from C_TooltipInfo", function()
        local w, ola, kari = Setup()
        eq(#kari:Hover({ species = 46, owner = "Ola Nord", noData = true }), 2)
        eq(kari.ns.Tooltip:OwnerOf("nobody"), nil)
    end)

    test("hovered species count as known", function()
        local w, ola, kari = Setup()
        kari:Hover({ species = 90, owner = "Per Hansen" })
        ok(kari.env.DyreparkenDB.known[90])
    end)

    test("the owner pattern comes from the client's own format string", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { patch = function(env)
            env.UNITNAME_TITLE_COMPANION = "Begleiter (%s)."
        end })
        eq(c.ns.Tooltip:OwnerOf("x", { {}, { leftText = "Begleiter (Kari Berg)." } }), "Kari Berg")
        eq(c.ns.Tooltip:OwnerOf("x", { {}, { leftText = "Begleiter (Kari Berg)" } }), nil)
        local d = w:AddClient("Kari Berg", { patch = function(env) env.UNITNAME_TITLE_COMPANION = nil end })
        eq(d.ns.Tooltip:OwnerOf("x", { {}, { leftText = "Ola Nord's Companion" } }), "Ola Nord", "English fallback")
        eq(d.ns.Tooltip:OwnerOf("x", { {}, {}, {}, {}, { leftText = "Ola Nord's Companion" } }), nil,
            "only lines 2-4")
        eq(d.ns.Tooltip:OwnerOf("x", "not a table"), nil)
    end)

    test("errors are caught and logged", function()
        local w, ola, kari = Setup()
        kari.env.UnitIsBattlePetCompanion = function() error("broken unit") end
        eq(#kari:Hover({ species = 46, owner = "Ola Nord" }), 0)
        local errs = kari:TakeErrors()
        eq(#errs, 1)
        match(errs[1], "broken unit")
    end)

    test("no TooltipDataProcessor: world tooltips stay off", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { patch = function(env) env.TooltipDataProcessor = nil end })
        eq(#c:Log("no TooltipDataProcessor"), 1)
        eq(#c.tooltipCalls, 0)
    end)
end
