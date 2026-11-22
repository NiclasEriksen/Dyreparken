-- Personal achievements: evaluation, quiet first runs, notices to addon users,
-- sharing to guild chat (only on a keypress or click), loyalty.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- A small, known companion list instead of the generated one.
    local CATS = { 40, 41, 42, 46 }
    local function Fix(c) c:Companions(H.COMPANIONS); return c end

    local function Pets(list, extra)
        local t = {}
        for _, s in ipairs(list) do t[#t + 1] = s end
        for _, s in ipairs(extra or {}) do t[#t + 1] = s end
        return t
    end

    -- Ola (with the given pets) and Kari, both past their login check.
    local function Setup(pets, opts)
        opts = opts or {}
        opts.pets = pets
        return H.Setup{ ola = opts, kari = {}, each = Fix, settle = "hello" }
    end

    local function Learn(c, sid)
        c:GivePet(sid)
        c:Fire("NEW_PET_ADDED", c:GuidOf(sid))
    end

    local function Got(c, id) return c.ns.Achievements:Got(id) end

    -- 0.10.0 (2026-11-22, the content review §2.5 and §4.4).
    test("0.10.0: Bestevenn and Sjelevenn; bonds with many pets; a whole family; firsts, playmates, pats, wishes", function()
        local w, ola = Setup(Pets(CATS, { 5159 }))
        local A, ns = ola.ns.Achievements, ola.ns
        local function Def(id) for _, d in ipairs(ns.AchDefs) do if d.id == id then return d end end end
        local function Ev(id) return table.concat({ tostring((A:Evaluate(Def(id)))), select(2, A:Evaluate(Def(id))), select(3, A:Evaluate(Def(id))) }, " ") end
        local L = ns.Bond.LEVELS
        ola:Slash("adopter panda"); w:Run(2)
        ola:SetBond("s:5159", L[5][1])
        eq(Ev("bond:5"), "true 900 900"); eq(Ev("bond:7"), "false 900 2250")
        -- Many pets: your own bonds, adopted or not.
        ola:SetBond("s:40", L[3][1]); ola:SetBond("s:41", L[5][1]); ola:SetBond("s:42", L[7][1])
        eq(Ev("herd:3:5"), "false 4 5"); eq(Ev("herd:5:3"), "true 3 3", "the panda, the 41 and the 42")
        eq(Ev("herd:7:3"), "false 1 3")
        ola:SetBond("s:46", L[3][1]); ola:SetBond("s:7", L[3][1])
        eq(Ev("herd:3:5"), "true 5 5")
        ola:SetBond("s:42", L[3][1], { who = "Kari Berg" }) -- (someone else's bond doesn't count)
        eq(Ev("herd:3:5"), "true 5 5")
        -- A whole family (four cats here) at level 2: the closest family of three or more.
        eq(Ev("wholefamily:2"), "true 4 4")
        ola:SetBond("s:46", 10)
        eq(Ev("wholefamily:2"), "false 3 4")
        -- Firsts, playmates, pats, wish kinds: their own counters.
        ns.DB.char.firsts = { ["s:40"] = { Hogger = true, VanCleef = true }, ["s:41"] = { Hogger = true } }
        eq(Ev("firsts:25"), "false 3 25")
        ns.DB.char.playmates = { ["s:40"] = { ["Kari Berg\31s:5"] = 2, ["Per Hansen\31s:7"] = 1 }, ["s:41"] = { ["Kari Berg\31s:9"] = 1 } }
        eq(Ev("playfriends:5"), "false 2 5")
        ns.DB.char.wishes.kinds = { herb = true, fish = true }
        eq(Ev("wishkinds:10"), "false 2 10")
        ns.DB.char.cuddleDays = 30
        eq(Ev("cuddle:30"), "true 30 30")
        -- Data-driven families: the real data's with three or more, after the written ones; never one under three.
        local fam = {}
        for _, d in ipairs(ns.AchDefs) do if d.kind == "family" then fam[#fam + 1] = d.tag end end
        match(table.concat(fam, " "), "pirate .*rodent"); ok(Def("family:festive")); ok(Def("family:wolf")); ok(Def("family:bug"))
        no(Def("family:murloc"), "one pet: too small")
        local defs = { { id = "family:cat", kind = "family", tag = "cat" }, { id = "x", kind = "bond" } }
        ns.Companions = { species = { [1] = { a = true, t = { "ooze" } }, [2] = { a = true, t = { "ooze" } }, [3] = { a = false, t = { "ooze" } },
            [4] = { a = true, t = { "bear" } }, [5] = { a = true, t = { "bear" } }, [6] = { a = true, t = { "bear" } } } }
        ns.AchFamily.Build(defs)
        eq(defs[2].id, "family:bear", "a family grown to three: after the written ones"); eq(defs[3].id, "x")
        eq(#defs, 3, "two oozes that count: not yet")
    end)

    test("0.10.0: a pat for a guildmate's pet counts once per pet; Turnusvakt: a new pet's visit seven days in a row", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 46, 40, 41, 42, 7, 84, 68 }, kari = { 40 }, each = Fix, settle = "hello" }
        local ns = ola.ns
        local function Def(id) for _, d in ipairs(ns.AchDefs) do if d.id == id then return d end end end
        local function Have(id) return (select(2, ns.Achievements:Evaluate(Def(id)))) end
        -- /dp klapp on Kari's cat (targeted): counted once.
        ola:Target({ species = 40, owner = "Kari Berg" })
        ola:Slash("klapp"); ola:Slash("klapp")
        eq(Have("pats:10"), 1, "a guildmate's cat, once")
        ola:Target({ species = 46, owner = "Per Hansen" }) -- (not in the guild)
        ola:Slash("klapp")
        ola:Target({ species = 5159, owner = "Ola Nord" }) -- (your own)
        ola:Slash("klapp")
        eq(Have("pats:10"), 1)
        -- Turnusvakt.
        local T = ns.Turnus
        local day = "20270301"
        local function Visit(key) T:Visit(key, day) end
        local function Next() day = os.date("%Y%m%d", os.time({ year = tonumber(day:sub(1, 4)),
            month = tonumber(day:sub(5, 6)), day = tonumber(day:sub(7, 8)) + 1, hour = 12 })) end
        for i, sid in ipairs({ 5159, 46, 40, 41, 42, 7 }) do Visit("s:" .. sid); if i < 6 then Next() end end
        eq(Have("turnusvakt:7"), 6)
        Next(); Visit("s:46") -- (out before in this run: the day doesn't count yet)
        eq(ns.DB.char.turnusvakt.n, 6)
        Visit("s:84") -- (a new one the same day: it does)
        eq(Have("turnusvakt:7"), 7)
        Next(); Next(); Visit("s:68") -- (a day missed: a new run)
        eq(ns.DB.char.turnusvakt.n, 1); eq(ns.DB.char.turnusvakt.best, 7)
        -- Through the real day's visit (Activity's "day"): counted.
        w:SkipDays(1); ola:Summon(84); ns.Activity:CheckDay(); w:RunTimers()
        eq(ns.DB.char.turnusvakt.last, ns.Today())
    end)

    test("first run: what you already have is recorded quietly, with one summary line", function()
        local w, ola, kari = Setup(Pets(CATS, { 5159 }))
        local g = Got(ola, "family:cat")
        ok(g)
        eq(g.told, "quiet"); eq(g.ann, "quiet")
        ok(ola:Printed("Du har allerede 1 prestasjoner fra før.", true))
        eq(w:Sent("ACH_EARNED"), 0)
        no(kari:Printed("fikk"))
        -- Reloading doesn't bring it up again.
        ola:Reload()
        ola:ClearPrinted()
        w:Run(12)
        no(ola:Printed("allerede"))
        eq(w:Sent("ACH_EARNED"), 0)
    end)

    test("learning the last cat: one notice, one line for every addon user", function()
        local w, ola, kari = Setup({ 40, 41, 42 })
        no(Got(ola, "family:cat"))
        local m = w:Mark()
        Learn(ola, 46)
        w:Run(2)
        eq(w:Sent("ACH_EARNED", nil, m), 1)
        ok(kari:Printed("Dyreparken: Ola Nord fikk [Kattevræl]!", true))
        ok(ola:Printed("Dyreparken: Ola Nord fikk [Kattevræl]!", true))
        ok(ola:Printed("/dp prestasjoner del", true))
        local g = Got(ola, "family:cat")
        eq(type(g.told), "number")
        eq(g.ann, nil, "not shared until asked")
        eq(#w.chat, 0, "nothing in guild chat by itself")
        -- Opening the journal checks again: nothing new.
        ola:OpenJournal()
        w:Run(2)
        eq(w:Sent("ACH_EARNED", nil, m), 1)
    end)

    test("several at once become one notice and one line", function()
        -- 9 counting pets; the 10th is also the last cat.
        local w, ola, kari = Setup({ 40, 41, 42, 7, 84, 68, 72, 90, 2001 })
        local m = w:Mark()
        Learn(ola, 46)
        Learn(ola, 2002) -- the same moment: one check covers both
        w:Run(2)
        eq(w:Sent("ACH_EARNED", nil, m), 1)
        ok(kari:Printed("Dyreparken: Ola Nord fikk [Ti på taket] og [Kattevræl]!", true))
    end)

    test("pets learned without the addon (the collection jumped) are quiet", function()
        local w, ola = Setup({ 40, 41 })
        ola:Logout()
        ola:GivePet(42); ola:GivePet(46)
        ola:Login()
        w:Settle("hello")
        local g = Got(ola, "family:cat")
        ok(g)
        eq(g.told, "quiet")
        eq(w:Sent("ACH_EARNED"), 0)
    end)

    test("one learned pet doesn't excuse a bigger jump", function()
        local w, ola = Setup({ 40, 41 })
        ola:GivePet(42) -- learned without an event (another client)
        Learn(ola, 46)
        w:Run(2)
        eq(Got(ola, "family:cat").told, "quiet")
        eq(w:Sent("ACH_EARNED"), 0)
    end)

    test("an empty journal is not judged (it may still be loading)", function()
        local w, ola = Setup({})
        eq(next(ola.env.DyreparkenDB.ach.seen), nil, "nothing marked seen")
        ola:GivePet(40); ola:GivePet(41); ola:GivePet(42); ola:GivePet(46)
        ola.ns.Achievements:Check("later")
        eq(Got(ola, "family:cat").told, "quiet", "the first real look is quiet")
    end)

    test("only pets that count: a promo pet doesn't, and a missing family or tier doesn't exist", function()
        local w, ola = Setup({ 5159, 40 })
        local A = ola.ns.Achievements
        local done, have, need = A:Evaluate(A.defsById["count:10"])
        eq(done, false); eq(have, 1, "Panda Cub is promo"); eq(need, 10)
        eq(A:Evaluate(A.defsById["count:25"]), nil, "15 counting pets: no 25 tier")
        eq(A:Evaluate(A.defsById["family:dragon"]), nil, "no dragons in this list")
        done, have, need = A:Evaluate(A.defsById["count:all"])
        eq(need, 15)
        ola:ClearPrinted()
        ola:Slash("prestasjoner alle")
        ok(ola:Printed("[Ti på taket] 1/10", true))
        ok(ola:Printed("[Kattevræl] 1/4", true))
        no(ola:Printed("[Dyrevenn]", true))
        no(ola:Printed("[Dragehulen]", true))
        ok(ola:Printed("Prestasjoner %(0 av %d+%):"))
        eq(A:Evaluate({ kind = "bogus" }), nil)
    end)

    test("share: flavor lines in guild chat, once, only from the command", function()
        local w, ola, kari = Setup({ 40, 41, 42 })
        Learn(ola, 46)
        w:Run(2)
        eq(#w.chat, 0)
        ola:Slash("prestasjoner alle")
        match(ola:Printed("[Kattevræl] ", true), " %*$", "unshared: a star")
        ola:Slash("prestasjoner del")
        eq(#w.chat, 1)
        eq(w.chat[1].chan, "GUILD")
        eq(w.chat[1].text, "Ola Nord har gitt alle kattene et hjem! [Kattevræl]")
        eq(type(Got(ola, "family:cat").ann), "number")
        ola:Slash("prestasjoner del")
        eq(#w.chat, 1)
        ok(ola:Printed("Ingen nye prestasjoner å dele."))
        ola:Slash("prestasjoner alle")
        match(ola:Printed("[Kattevræl] ", true), "%[Kattevræl%] %d%d%.%d%d%.%d%d%d%d$", "shared: no star")
    end)

    test("a family by its aliases: the Mechanical Chicken (chicken, mechanical) is a farm pet too", function()
        local list = H.CopyTable(H.COMPANIONS)
        list[83] = { a = true, t = { "chicken", "mechanical" } }
        local w, ola = H.Setup{ ola = { pets = { 7, 84 } }, kari = {}, settle = "hello",
            each = function(c) c:Companions(list) end }
        no(Got(ola, "family:farm"), "two of the three farm pets")
        Learn(ola, 83); w:Run(2)
        ok(Got(ola, "family:farm"), "the chicken counted (2026-11-19, the user)")
        ok(Got(ola, "family:mechanical"), "and a mechanical pet still")
    end)

    test("share: at most five lines a click, the rest at the next (the server's chat flood limit)", function()
        local w, ola = Setup({ 40 })
        local A, n = ola.ns.Achievements, 0
        for _, d in ipairs(ola.ns.AchDefs) do
            if n < 8 and (d.scope or "account") == "account" and not A:Got(d.id) then
                ola.ns.DB.global.ach.got[d.id] = { at = ola.ns.Now() }
                n = n + 1
            end
        end
        local before = #w.chat
        ola:Slash("prestasjoner del")
        eq(#w.chat - before, A.SHARE_MAX)
        ok(ola:Printed("3 til venter. Del dem med /dp prestasjoner del en gang til.", true))
        ola:Slash("prestasjoner del")
        eq(#w.chat - before, 8)
    end)

    test("share fills placeholders; no flavor: the generic line; quiet ones are never offered", function()
        local w, ola = Setup(Pets(CATS)) -- cats quiet on the first run
        local A = ola.ns.Achievements
        local texts = ola.ns.AchTexts
        texts["family:cat"].flavor = "{player}: {name} {progress} {nope}"
        eq(A:ShareLine("family:cat"), "Ola Nord: [Kattevræl] 4/4 {nope}", "unknown placeholders stay, so typos show")
        texts["family:cat"].flavor = nil
        eq(A:ShareLine("family:cat"), "Ola Nord fikk [Kattevræl]!")
        eq(A:ShareLine("no:such"), "Ola Nord fikk [no:such]!")
        ola:Slash("prestasjoner del")
        eq(#w.chat, 0)
        ok(ola:Printed("Ingen nye prestasjoner å dele."))
    end)

    test("not in a guild: no notice, nothing to share to", function()
        local w, ola = Setup({ 40, 41, 42 }, { guild = false })
        Learn(ola, 46)
        w:Run(2)
        eq(w:Sent("ACH_EARNED"), 0)
        eq(Got(ola, "family:cat").told, "none")
        ola:Slash("prestasjoner del")
        ok(ola:Printed("Du er ikke i en guild."))
    end)

    test("notices can be turned off (per character); you still see your own", function()
        local w, ola, kari = Setup({ 40, 41, 42 })
        ola:Slash("prestasjoner varsel av")
        ok(ola:Printed("får ikke lenger beskjed", true))
        Learn(ola, 46)
        w:Run(2)
        eq(w:Sent("ACH_EARNED"), 0)
        no(kari:Printed("fikk"))
        ok(ola:Printed("Ola Nord fikk [Kattevræl]!", true))
        eq(Got(ola, "family:cat").told, "off")
        ola:Slash("prestasjoner varsel på")
        eq(ola.env.DyreparkenCharDB.achNotify, true)
        ola:Slash("prestasjoner varsel av")
        eq(ola.env.DyreparkenCharDB.achNotify, false, "the Norwegian words work too")
        ola:Slash("prestasjoner varsel på")
        eq(ola.env.DyreparkenCharDB.achNotify, true)
    end)

    test("loyalty: a bond seeded from 30 days together, and a first nickname", function()
        local w, ola, kari = Setup({ 5159 })
        w.bondsShipped = 2e9 -- (adopted before bonds shipped: seeded at login)
        ola:Slash("adopter")
        w:Run(1)
        no(Got(ola, "loyal:30"))
        w:SkipDays(30)
        local m = w:Mark()
        ola:Reload()
        w:Settle("hello")
        no(Got(ola, "loyal:30"), "the bond is seeded a little after login")
        w:Run(10)
        ok(Got(ola, "loyal:30"), "300 points: Venn (from 270)")
        eq(w:Sent("ACH_EARNED", nil, m), 1, "a real moment, not a first look")
        ok(kari:Printed("Ola Nord fikk [Venner i parken]!", true))
        no(Got(ola, "loyal:100"))
        ola:Slash("prestasjoner alle")
        ok(ola:Printed("[Gode kamerater] 300/530 poeng", true))
        ola:Slash("navn Bambus")
        w:Run(1)
        ok(Got(ola, "nick"))
        ok(kari:Printed("Ola Nord fikk [Døpt]!", true))
        eq(ola.env.DyreparkenCharDB.ach.got.nick.told ~= nil, true)
        eq(ola.env.DyreparkenDB.ach.got.nick, nil, "character scope")
        -- The shared lines name the pet.
        local A = ola.ns.Achievements
        eq(A:ShareLine("nick"), "Ola Nord har døpt Panda Cub til «Bambus»! [Døpt]")
        eq(A:ShareLine("loyal:30"), "Ola Nord og Bambus er blitt ordentlige venner! [Venner i parken]")
        ola:Slash("navn")
        eq(A:ShareLine("nick"), "Ola Nord har gitt dyret sitt et navn! [Døpt]", "no nickname now: the plain line")
        eq(A:ShareLine("loyal:30"), "Ola Nord og Panda Cub er blitt ordentlige venner! [Venner i parken]",
            "no nickname: the species")
        ola:Slash("gislipp")
        eq(A:ShareLine("loyal:30"), "Ola Nord og dyret sitt er blitt ordentlige venner! [Venner i parken]")
        ola.ns.AchTexts.nick.plain = nil
        eq(A:ShareLine("nick"), "Ola Nord fikk [Døpt]!", "no plain line: the generic one")
    end)

    test("notices are checked: guild only, known ids only, bounded", function()
        local w, ola, kari = Setup({ 40 })
        local p = kari.ns.PROTOCOL
        w:InjectMessage("Per Hansen", { k = "ACH_EARNED", p = p, a = { "family:cat" } }, "PARTY")
        w:InjectMessage("Per Hansen", { k = "ACH_EARNED", p = p, a = "family:cat" })
        w:InjectMessage("Per Hansen", { k = "ACH_EARNED", p = p, a = { "bogus", 7, {} } })
        w:Run(1)
        no(kari:Printed("Per Hansen"))
        w:InjectMessage("Per Hansen", { k = "ACH_EARNED", p = p, a = { "from:newer", "family:owl" } })
        w:Run(1)
        ok(kari:Printed("Dyreparken: Per Hansen fikk [Ugleredet]!", true))
    end)

    test("the real data: limited pets count toward achievements (never impossible to get), unknown ones don't", function()
        local _, ola = H.Setup{ ola = {} }
        local sp = ola.ns.Companions.species
        for _, sid in ipairs({ 5159, 5160, 5161, 5179, 5138 }) do ok(sp[sid].a, "limited " .. sid .. ": counts (2026-11-12)") end
        for _, sid in ipairs({ 5139, 5069, 5200 }) do no(sp[sid].a, "unknown " .. sid .. ": doesn't") end
        local n = 0
        for _, e in pairs(sp) do if e.a then n = n + 1 end end
        ok(sp[5005].a, "the Musical Gustjumper: /sing to a frog on Zephras Isle")
        ok(sp[5122].a, "the Spectral Bear Cub: the Legacy Track"); no(sp[1563].a); no(sp[5008].a)
        ok(sp[1927].a, "the White Tiger Cub: the Black Market (2026-11-12)")
        ok(n >= 77, "most of them (77 on 2026-11-12; more as companions are added)")
    end)
end
