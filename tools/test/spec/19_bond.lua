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
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 40 }, each = Plain }
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
        w.bondsShipped = 2e9 -- (adopted before bonds shipped: seeded at login)
        ola:Slash("adopter panda")
        w:Run(1)
        eq(Points(ola, PANDA), nil, "a new adoption starts empty")
        -- Pretend it's from before bonds: drop the first day's visit, if any.
        w:SkipDays(30)
        ola:Reload(); Plain(ola)
        w:Run(25)
        eq(Points(ola, PANDA), 300, "10 a day for 30 days")
        ok(ola:Printed("Båndet ditt med Panda Cub er nå på level 3: Venn!", true))
        eq(Points(kari, PANDA, "Ola Nord"), 300, "a level-up goes out at once")
        eq(kari.ns.Bond:Label(PANDA), "Venn (level 3)")
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
        w:Settle("day")
        eq(Points(ola, PANDA), 40, "back: today's visit, double after a week away or more (Bond.COMEBACK_DAYS)")
        -- Another companion out: its own bond (half), not the panda's.
        w:SkipDays(1)
        ola:Summon(46)
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 40)
        eq(Points(ola, KITTEN), 5, "a half day for a pet we haven't adopted")
    end)

    -- Back after a while (2026-11-22, the content review §3.3, the user): the account away, not the pet.
    test("back after a week or more away: the first pet out has a double day, once, with a line; less than a week, nothing", function()
        local w, ola = Setup()
        ola:Slash("adopter panda"); w:Run(5)
        ola.ns.Activity:CheckDay()
        local p = Points(ola, PANDA)
        local B = ola.ns.Bond
        w:SkipDays(B.COMEBACK_DAYS - 1)
        ola:Reload(); Plain(ola)
        w:Settle("day")
        eq(Points(ola, PANDA), p + 10, "six days away: a plain day")
        eq(ola:CountPrinted("Velkommen tilbake"), 0)
        w:SkipDays(B.COMEBACK_DAYS)
        ola:Reload(); Plain(ola)
        eq(ola.ns.DB.global.comeback, ola.ns.Today(), "owed")
        w:Settle("day")
        eq(Points(ola, PANDA), p + 30, "a week away: double")
        eq(ola:CountPrinted("Velkommen tilbake! Panda Cub har savnet deg, og dagens besøk teller dobbelt. (+20 båndpoeng)"), 1)
        eq(ola.ns.DB.global.comeback, nil, "taken")
        -- The next pet out the same day: its plain half day.
        ola:Summon(46)
        ola.ns.Activity:CheckDay()
        eq(Points(ola, KITTEN), 5)
        -- Another login the same day (an alt's, or a /reload): nothing owed any more.
        ola:Reload(); Plain(ola)
        w:Settle("day")
        eq(ola:CountPrinted("Velkommen tilbake"), 1)
    end)

    test("adopting a pet again brings the old bond back", function()
        local w, ola, kari = Setup()
        w.bondsShipped = 2e9 -- (adopted before bonds shipped: seeded at login)
        ola:Slash("adopter panda")
        w:SkipDays(30)
        ola:Reload(); Plain(ola)
        w:Run(25)
        eq(Points(ola, PANDA), 300)
        local first = ola.ns.Registry:Life(PANDA, "Ola Nord").f
        ola:Slash("adopter kitten")
        w:Run(25)
        eq(ola.ns.Bond:Of(PANDA), nil, "free now")
        eq(ola.ns.Bond:Of(KITTEN), 20, "a new bond with the kitten: out at once, its first day (double: back after 30 days)")
        w:SkipDays(3)
        ola:Slash("adopter panda")
        w:Run(25)
        -- Where they left off (the kitten was out meanwhile), then today's visit as it comes out.
        eq(ola.ns.Bond:Of(PANDA), 310, "where they left off, and today")
        ola.ns.Activity:CheckDay()
        eq(Points(ola, PANDA), 310, "one visit a day")
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord").f, first, "the first adoption stays the first")
        eq(kari.ns.Bond:Label(PANDA), "Venn (level 3)")
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
        -- The cap (X-Protocol 10): the days so far and three spare, 85 each (the day's 75 and the wish's 10).
        local cap = R.LifeCap(now - 2 * day, now)
        eq(cap, (2 + 3) * 85, "two days in")
        local bad = {
            "no", { p = 10, t = now }, { p = 10, f = now, t = now - 5 }, { p = -1, f = now, t = now },
            { p = 0 / 0, f = now, t = now }, { p = "9", f = now, t = now },
            { p = cap + 1, f = now - 2 * day, t = now }, -- more than the days can bring
            { p = 1, f = now, t = now + 3 * day },   -- from the future
            { p = 1, f = now - 0.5, t = now },       -- not on a whole second
        }
        for i, e in ipairs(bad) do no(R:MergeLife(KITTEN, "Ola Nord", e), "bad " .. i) end
        ok(R:MergeLife(KITTEN, "Ola Nord", { p = cap, f = now - 2 * day, t = now }), "exactly the cap")
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
        w.bondsShipped = 2e9 -- (adopted before bonds shipped: seeded at login)
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
        match(table.concat(tip.lines, " / "), "Har bodd hos Ola Nord i 30 dager / Bånd: Sjelevenn %(level 7%)")
        local added = kari:Hover({ species = 5159, owner = "Ola Nord" })
        match(added[#added - 1], " · Sjelevenn$")
    end)

    -- Named bosses and dungeons (2026-11-22, 0.10.0): a line of their own, a named place always.
    test("a named boss or dungeon, the first time with a pet: its own line; a named place always speaks", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        local ns, B = ola.ns, ola.ns.Bond
        ola:Dice(0.99) -- (a general place line wouldn't come: its chance said no)
        B:First("boss", PANDA, "Ragnaros"); w:RunTimers()
        ok(ola:PrintedLine("first.boss.ragnaros", { pet = "Panda Cub" }), "Ragnaros's own")
        B:First("boss", PANDA, "Hogger"); w:RunTimers()
        ok(ola:PrintedLine("first.boss", { pet = "Panda Cub", boss = "Hogger" }), "anyone else: the general ones")
        ns.DB.char.places[PANDA] = { Durotar = true, ["Molten Core"] = true }
        B:First("explore", PANDA, "Molten Core"); w:RunTimers()
        ok(ola:PrintedLine("first.place.moltencore", { pet = "Panda Cub" }), "a named place: always, its own")
        ns.DB.char.places[PANDA]["Ashenvale"] = true
        ola:ClearPrinted()
        B:First("explore", PANDA, "Ashenvale"); w:RunTimers()
        no(ola:PrintedLine("first.place", { pet = "Panda Cub", place = "Ashenvale" }), "elsewhere: its chance")
        -- Every name resolves to its slug, and every slug has two lines at least.
        for slug in pairs(B.NAMED_BOSSES) do ok(#ns.Variants("first.boss." .. slug) >= 2, slug) end
        for slug in pairs(B.NAMED_PLACES) do ok(#ns.Variants("first.place." .. slug) >= 2, slug) end
        eq(B.PLACE_SLUG["Sunken Temple"], "sunken"); eq(B.PLACE_SLUG["The Temple of Atal'Hakkar"], "sunken")
        -- An iconic zone: by the pet's family where it has lines, else the zone's own (a new day: firsts' lines a day
        -- are Config.FIRST_LINES).
        ola:Companions{ [5159] = { a = true, t = { "frog" } } }
        w:SkipDays(1)
        B:First("explore", PANDA, "Swamp of Sorrows"); w:RunTimers()
        ok(ola:PrintedLine("first.place.swamp.frog", { pet = "Panda Cub" }), "a frog in the swamp")
        B:First("explore", PANDA, "Winterspring"); w:RunTimers()
        ok(ola:PrintedLine("first.place.winterspring", { pet = "Panda Cub" }), "no frog lines there: the zone's")
    end)

    -- Review 2026-11-24 Q1: the trash bosses and the dungeon used up the day's three first lines; the end boss
    -- came last, gave points, said nothing, and was done for good.
    test("a named boss speaks past the day's first lines; an unnamed one doesn't", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        local B = ola.ns.Bond
        for i = 1, ola.ns.Config.FIRST_LINES do B:First("boss", PANDA, "Trash " .. i) end
        w:RunTimers()
        ola:ClearPrinted()
        B:First("boss", PANDA, "Hogger"); w:RunTimers()
        no(ola:PrintedLine("first.boss", { pet = "Panda Cub", boss = "Hogger" }), "the cap holds for the rest")
        B:First("boss", PANDA, "Ragnaros"); w:RunTimers()
        ok(ola:PrintedLine("first.boss.ragnaros", { pet = "Panda Cub" }), "Ragnaros speaks anyway")
    end)

    -- Review 2026-11-24 Q10: a boss kill printed a first's line and the day's liked line in the same second.
    test("a first's line and the day's liked line don't come together: the liked one waits for a later moment", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Traits{ "eventyrlysten", "glupsk" } -- (likes bosses)
        ola:Slash("adopter panda"); w:Run(40)
        local ns = ola.ns
        ns.DB.char.wish = { day = ns.Today(), pet = PANDA, id = "quest", done = false } -- (not a boss wish: its own line)
        local lines = {}
        ns.Bus:On("BOND_LINE", function(key, text) if key == PANDA then lines[#lines + 1] = text end end)
        ns.Activity:Emit("boss", 1, "Hogger")
        eq(#lines, 1, "one line: the first's")
        match(lines[1], "Hogger")
        w:Run(ns.Bond.LINE_GAP + 1)
        ns.Activity:Emit("boss", 1, "Hogger")
        eq(#lines, 2, "the liked line, later")
    end)

    -- Review 2026-11-24 Q23: a leader met on a character with no guild was used up for no points.
    test("a faction leader met with no guild is kept for later: no line, nothing marked", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 }, guild = false })
        w:Settle("day")
        c:Summon(5159); w:Run(5)
        c.state.faction = "Horde"
        c:Dice(0)
        c:Hover{ companion = false, who = { name = "Thrall", type = { "Humanoid", 7 }, guid = "Creature-0-1-2-3-4949-1" } }
        w:RunTimers()
        no(c.ns.DB.char.leaders[PANDA] and c.ns.DB.char.leaders[PANDA].thrall)
        no(c:PrintedLine("first.leader.thrall", { pet = "Panda Cub" }))
    end)

    -- Faction leaders (2026-11-24, the user, batch G): a first together, your own faction's only.
    test("a faction leader under the mouse, your own side's: a first with its own line, once per pet", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        local ns, B = ola.ns, ola.ns.Bond
        ola.state.faction = "Horde"
        local n = 0
        local function Meet(name)
            n = n + 1
            ola:Hover{ companion = false, who = { name = name, type = { "Humanoid", 7 }, guid = "Creature-0-1-2-3-4949-" .. n } }
            w:RunTimers()
        end
        ola:Dice(0)
        local before = ola:Points(PANDA)
        Meet("Thrall")
        ok(ola:PrintedLine("first.leader.thrall", { pet = "Panda Cub" }), "Thrall's own line")
        ok(ola:Points(PANDA) > before, "a first's points")
        ok(ns.DB.char.leaders[PANDA].thrall)
        ola:ClearPrinted(); before = ola:Points(PANDA)
        Meet("Thrall")
        no(ola:PrintedLine("first.leader.thrall", { pet = "Panda Cub" }), "once per pet")
        eq(ola:Points(PANDA), before)
        Meet("King Magni Bronzebeard")
        eq(ola:Points(PANDA), before, "the other side's: nothing")
        no(ns.DB.char.leaders[PANDA].magni)
        ola:Dice(0.99)
        Meet("Cairne Bloodhoof")
        ok(ola:PrintedLine("first.leader", { pet = "Panda Cub" }), "now and then a general line")
        for slug, row in pairs(B.LEADERS) do
            ok(#ns.Variants("first.leader." .. slug) >= 1, slug)
            ok(row[1] == "Horde" or row[1] == "Alliance", slug .. "'s faction")
        end
    end)
end
