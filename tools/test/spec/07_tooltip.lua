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
        local _, _, all = kari:Hover({ species = 46, owner = "Ola Nord" })
        eq(table.concat(all, " / "), "Pus / White Kitten / Ola Nord's Companion / Pet Level 1 Critter"
            .. " / Dyreparken: bor hos Ola Nord i 7 dager", "the nickname takes the title")
        local tip = kari.env.GameTooltip
        eq(tip.colors[2][1], 0.7, "the species line is grey")
        -- The data gets the same shift, for addons that draw from it (PrettyTooltip).
        local data = kari.lastTooltipData.lines
        local texts, indices = {}, {}
        for i, l in ipairs(data) do texts[i], indices[i] = l.leftText, l.lineIndex end
        eq(table.concat(texts, " / "), "Pus / White Kitten / Ola Nord's Companion / Pet Level 1 Critter")
        eq(table.concat(indices, ","), "1,2,3,4", "lineIndex matches the native lines")
        eq(data[2].leftColor.r, 0.7)
        ok(tip.shown, "resized")
        local _, _, own = ola:Hover({ species = 46, owner = "Ola Nord" })
        eq(own[5], "Dyreparken: bor hos deg i 7 dager")
    end)

    test("the nickname shift moves right-side text and colors down with their line", function()
        local w, ola, kari = Setup()
        local env, T = kari.env, kari.ns.Tooltip
        local tip = env.GameTooltip
        tip:ClearLines()
        tip:AddLine("White Kitten", 0, 1, 0)
        tip:AddLine("Ola Nord's Companion")
        env.GameTooltipTextRight2:SetText("høyre"); env.GameTooltipTextRight2:Show()
        tip:AddLine("Pet Level 1 Critter", 0.5, 0.5, 0.5)
        T:ShowNickname(tip, "Pus")
        eq(table.concat(tip.lines, " / "), "Pus / White Kitten / Ola Nord's Companion / Pet Level 1 Critter")
        eq(tip.colors[1][2], 1, "the title keeps its color")
        eq(tip.right[3], "høyre"); ok(env.GameTooltipTextRight3:IsShown())
        no(env.GameTooltipTextRight2:IsShown(), "the species line has no right text")
        eq(tip.colors[4][1], 0.5)
        -- Already shown (a second post-call): nothing changes.
        T:ShowNickname(tip, "Pus")
        eq(#tip.lines, 4)
        -- Data whose title isn't the species (another addon changed it) is left alone.
        tip:ClearLines(); tip:AddLine("White Kitten")
        local data = { lines = { { leftText = "Noe annet", lineIndex = 1 } } }
        T:ShowNickname(tip, "Pus", data)
        eq(#data.lines, 1); eq(data.lines[1].leftText, "Noe annet")
        -- Data lines without lineIndex get none.
        tip:ClearLines(); tip:AddLine("White Kitten")
        data = { lines = { { leftText = "White Kitten" }, { leftText = "Pet Level 1 Critter" } } }
        T:ShowNickname(tip, "Pus", data)
        eq(data.lines[2].leftText, "White Kitten"); eq(data.lines[2].lineIndex, nil)
    end)

    test("no nickname: just the reservation line", function()
        local w, ola, kari = Setup()
        ola:Slash("nick")
        w:Run(1)
        local lines = kari:Hover({ species = 46, owner = "Ola Nord" })
        eq(#lines, 1)
        match(lines[1], "^Dyreparken: bor hos Ola Nord")
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
