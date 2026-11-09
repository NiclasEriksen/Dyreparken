-- The bond (Menagerie/Bond.lua): levels, seeding from days together, the
-- daily visit, publishing, re-adopting, the wire bounds, and where it shows.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN = "s:5159", "s:46"

    -- Plain traits, so a day is worth 10 and nothing hangs on the clock or
    -- the group (see 21_personality.lua). Again after each reload: that's a
    -- new client.
    local function Plain(c)
        c.ns.Personality.Traits = function() return { { id = "test", name = "Test", desc = "", like = "quest" } } end
    end

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 46 } })
        local kari = w:AddClient("Kari Berg", { pets = { 40 } })
        Plain(ola); Plain(kari)
        w:Run(40)
        -- These tests are about the adopted pet's bond: forget the half days the
        -- pets out at login earned (any pet of yours bonds, 2026-11-09).
        for _, c in ipairs({ ola, kari }) do
            c:ForgetBonds()
        end
        return w, ola, kari
    end

    local function Points(c, key, carer)
        local e = c.ns.Registry:Life(key, carer or c.name)
        return e and e.p
    end

    test("levels: names, thresholds, the next one", function()
        local w = H.World()
        local B = w:AddClient("Ola Nord").ns.Bond
        local function L(p) return { B:Level(p) } end
        eq(table.concat(L(0), ","), "1,Bekjent,0,100")
        eq(table.concat(L(99), ","), "1,Bekjent,0,100")
        eq(table.concat(L(270), ","), "3,Venn,270,530")
        eq(table.concat(L(1440), ","), "6,Uatskillelig,1440,2250")
        -- A curve: every step longer than the last, the top at 2250 (decided 2026-11-09): 30 days at
        -- the daily limit, at the very least.
        local gap = 0
        for i = 2, #B.LEVELS do
            local g = B.LEVELS[i][1] - B.LEVELS[i - 1][1]
            ok(g > gap, "step " .. i .. " longer"); gap = g
        end
        eq(B.LEVELS[#B.LEVELS][1], 2250)
        eq(B.LEVELS[#B.LEVELS][1] / w.clients[1].ns.Config.BOND_DAILY_MAX, 30)
        local top = L(9999)
        eq(top[1], 7); eq(top[2], "Sjelevenn"); eq(top[4], nil, "nothing after the top")
    end)

    test("an adoption from before bonds is seeded from its days, once, and everyone hears", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        w:Run(1)
        eq(Points(ola, PANDA), nil, "a new adoption starts empty")
        -- Pretend it's from before bonds: drop the first day's visit, if any.
        w:SkipDays(30)
        ola:Reload(); Plain(ola)
        w:Run(25)
        eq(Points(ola, PANDA), 300, "10 a day for 30 days")
        ok(ola:Printed("Båndet ditt med Panda Cub er nå på nivå 3: Venn!", true))
        eq(Points(kari, PANDA, "Ola Nord"), 300, "a level-up goes out at once")
        eq(kari.ns.Bond:Label(PANDA), "Venn (nivå 3)")
        ola:Reload(); Plain(ola)
        w:Run(25)
        eq(Points(ola, PANDA), 300, "not seeded twice")
    end)

    test("a day with the pet out adds points; away, the bond only pauses", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        w:Run(40)
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 10, "the first day")
        w:Run(1)
        eq(Points(kari, PANDA, "Ola Nord"), 10, "a new bond goes out at once")
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 10, "once a day")
        w:SkipDays(1)
        ola:Summon(nil)
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 10, "the pet has to be out")
        ola:Summon(5159)
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 20)
        w:Run(1)
        eq(Points(kari, PANDA, "Ola Nord"), 10, "small gains wait")
        w:Run(1801)
        eq(Points(kari, PANDA, "Ola Nord"), 20, "... up to half an hour")
        -- Ten days away: nothing lost, nothing gained.
        w:SkipDays(10)
        eq(Points(ola, PANDA), 20)
        ola:Reload(); Plain(ola)
        w:Run(40)
        eq(Points(ola, PANDA), 30, "back: today's visit")
        -- Another companion out: its own bond (half), not the panda's.
        w:SkipDays(1)
        ola:Summon(46)
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 30)
        eq(Points(ola, KITTEN), 5, "a half day for a pet we haven't adopted")
    end)

    test("adopting a pet again brings the old bond back", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        w:SkipDays(30)
        ola:Reload(); Plain(ola)
        w:Run(25)
        eq(Points(ola, PANDA), 300)
        local first = ola.ns.Registry:Life(PANDA, "Ola Nord").f
        ola:Slash("adopter kitten")
        w:Run(25)
        eq(ola.ns.Bond:Of(PANDA), nil, "free now")
        eq(ola.ns.Bond:Of(KITTEN), 10, "a new bond with the kitten: out at once, its first day")
        w:SkipDays(3)
        ola:Slash("adopter panda")
        w:Run(25)
        -- Where they left off (the kitten was out meanwhile), then today's visit as it comes out.
        eq(ola.ns.Bond:Of(PANDA), 310, "where they left off, and today")
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 310, "one visit a day")
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord").f, first, "the first adoption stays the first")
        eq(kari.ns.Bond:Label(PANDA), "Venn (nivå 3)")
        eq(ola.ns.Bond:Add(0), nil, "nothing to add")
    end)

    test("the wire: bounds on points, only the highest counts, only the sender's own", function()
        local w, ola, kari = Setup()
        local R = kari.ns.Registry
        local now = w:ServerTime()
        local day = 86400
        ok(R:MergeLife(PANDA, "Ola Nord", { p = 50, f = now - 2 * day, t = now }))
        no(R:MergeLife(PANDA, "Ola Nord", { p = 40, f = now - 2 * day, t = now + 5 }), "fewer points: older news")
        no(R:MergeLife(PANDA, "Ola Nord", { p = 50, f = now - 2 * day, t = now }), "the same")
        ok(R:MergeLife(PANDA, "Ola Nord", { p = 50, f = now - 2 * day, t = now + 1 }), "same points, later")
        local bad = {
            "no", { p = 10, t = now }, { p = 10, f = now, t = now - 5 }, { p = -1, f = now, t = now },
            { p = 0 / 0, f = now, t = now }, { p = "9", f = now, t = now },
            { p = 301, f = now - 2 * day, t = now }, -- more than 3 days and a spare one can bring (75 a day)
            { p = 1, f = now, t = now + 3 * day },   -- from the future
        }
        for i, e in ipairs(bad) do no(R:MergeLife(KITTEN, "Ola Nord", e), "bad " .. i) end
        ok(R:MergeLife(KITTEN, "Ola Nord", { p = 300, f = now - 2 * day, t = now }), "exactly the cap")
        no(R:MergeLife(5, "Ola Nord", { p = 1, f = now, t = now }))
        no(R:MergeLife(KITTEN, "", { p = 1, f = now, t = now }))
        -- BOND writes only the sender's entry.
        local p = kari.ns.PROTOCOL
        w:InjectMessage("Per Hansen", { k = "BOND", p = p, pet = PANDA, e = { p = 5, f = now, t = now } })
        w:InjectMessage("Per Hansen", { k = "BOND", p = p, e = { p = 5, f = now, t = now } })
        w:Run(1)
        eq(R:Life(PANDA, "Per Hansen").p, 5)
        eq(R:Life(PANDA, "Ola Nord").p, 50, "untouched")
        -- The digest holds the holders' bonds only, and by level, not points.
        local d = kari.ns.Sync:Digest()
        R:MergeLife(PANDA, "Ola Nord", { p = 150, f = now - 2 * day, t = now + 2 })
        eq(kari.ns.Sync:Digest(), d, "not Ola's pet: not in the digest at all")
        ola:Slash("adopter panda")
        w:Run(2)
        d = kari.ns.Sync:Digest()
        R:MergeLife(PANDA, "Ola Nord", { p = 160, f = now - 2 * day, t = now + 3 })
        eq(kari.ns.Sync:Digest(), d, "a few points: same digest")
        R:MergeLife(PANDA, "Ola Nord", { p = 300, f = now - 2 * day, t = now + 4 })
        no(kari.ns.Sync:Digest() == d, "a new level of a holder's bond: a new digest")
    end)

    test("the card shows the holder's bond as a bar; tooltips name the level", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        w:SkipDays(30)
        ola:Reload(); Plain(ola)
        w:Run(25)
        kari:OpenJournal()
        local card = kari:SelectPet(5159)
        ok(card.bond:IsShown())
        eq(card.bond.label.text, "Venn"); eq(card.bond.level.text, 3)
        eq(card.bond.next.text, "Ola Nord sitt bånd", "someone else's pet: whose bond it is")
        eq(card.bond.text.text, "300 / 530")
        eq(card.bond.min, 270); eq(card.bond.max, 530); eq(card.bond.value, 300)
        card = kari:SelectPet(46)
        no(card.bond:IsShown(), "a free pet: no bar")
        -- The top level: a full bar.
        local now = w:ServerTime()
        kari.ns.Registry:MergeLife(PANDA, "Ola Nord", { p = 7000, f = now - 100 * 86400, t = now })
        card = kari:SelectPet(5159)
        eq(card.bond.text.text, "7000")
        eq(card.bond.value, card.bond.max)
        -- Tooltips.
        local tip = kari.env.GameTooltip
        tip:ClearLines()
        kari.ns.JournalList:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "Bor hos Ola Nord i 30 dager / Bånd: Sjelevenn %(nivå 7%)")
        local added = kari:Hover({ species = 5159, owner = "Ola Nord" })
        match(added[#added], " · Sjelevenn$")
    end)
end
