-- Personal achievements: evaluation, quiet first runs, notices to addon users,
-- sharing to guild chat (only on a keypress or click), loyalty.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- A small, known companion list instead of the generated one.
    local CATS = { 40, 41, 42, 46 }
    local function Fixture()
        local species = {
            [40] = { a = true, t = { "cat" } }, [41] = { a = true, t = { "cat" } },
            [42] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat" } },
            [7] = { a = true, t = { "farm", "bird" } }, [84] = { a = true, t = { "farm", "bird" } },
            [68] = { a = true, t = { "owl", "bird" } }, [72] = { a = true, t = { "rabbit" } },
            [90] = { a = true, t = { "bird", "pirate" } },
            [5159] = { a = false }, -- promo: in the total, not in achievements
        }
        for sid = 2001, 2006 do species[sid] = { a = true } end -- filler: 15 counting pets
        return { build = 1, species = species }
    end
    local function Fix(c) c.ns.Companions = Fixture(); return c end

    local function Pets(list, extra)
        local t = {}
        for _, s in ipairs(list) do t[#t + 1] = s end
        for _, s in ipairs(extra or {}) do t[#t + 1] = s end
        return t
    end

    -- Ola (with the given pets) and Kari, both past their login check.
    local function Setup(pets, opts)
        local w = H.World()
        opts = opts or {}
        opts.pets = pets
        local ola = Fix(w:AddClient("Ola Nord", opts))
        local kari = Fix(w:AddClient("Kari Berg"))
        w:Run(12)
        return w, ola, kari
    end

    local function Learn(c, sid)
        c:GivePet(sid)
        c:Fire("NEW_PET_ADDED", c:GuidOf(sid))
    end

    local function Got(c, id) return c.ns.Achievements:Got(id) end

    test("first run: what you already have is recorded quietly, with one summary line", function()
        local w, ola, kari = Setup(Pets(CATS, { 5159 }))
        local g = Got(ola, "family:cat")
        ok(g)
        eq(g.told, "quiet"); eq(g.ann, "quiet")
        ok(ola:Printed("Du har allerede 1 prestasjoner fra før.", true))
        eq(w:Sent("ACH_EARNED"), 0)
        no(kari:Printed("fikk"))
        -- Reloading doesn't bring it up again.
        ola:Reload(); Fix(ola)
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
        ok(kari:Printed("Dyreparken: Ola Nord fikk [Ti små indianere] og [Kattevræl]!", true))
    end)

    test("pets learned without the addon (the collection jumped) are quiet", function()
        local w, ola = Setup({ 40, 41 })
        ola:Logout()
        ola:GivePet(42); ola:GivePet(46)
        ola:Login(); Fix(ola)
        w:Run(12)
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
        ola:Slash("ach")
        ok(ola:Printed("[Ti små indianere] 1/10", true))
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
        ola:Slash("ach")
        match(ola:Printed("[Kattevræl] ", true), " %*$", "unshared: a star")
        ola:Slash("ach share")
        eq(#w.chat, 1)
        eq(w.chat[1].chan, "GUILD")
        eq(w.chat[1].text, "Ola Nord har gitt alle kattene et hjem! [Kattevræl]")
        eq(type(Got(ola, "family:cat").ann), "number")
        ola:Slash("ach share")
        eq(#w.chat, 1)
        ok(ola:Printed("Ingen nye prestasjoner å dele."))
        ola:Slash("ach")
        match(ola:Printed("[Kattevræl] ", true), "%[Kattevræl%] %d%d%.%d%d%.%d%d%d%d$", "shared: no star")
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
        ola:Slash("ach share")
        eq(#w.chat, 0)
        ok(ola:Printed("Ingen nye prestasjoner å dele."))
    end)

    test("not in a guild: no notice, nothing to share to", function()
        local w, ola = Setup({ 40, 41, 42 }, { guild = false })
        Learn(ola, 46)
        w:Run(2)
        eq(w:Sent("ACH_EARNED"), 0)
        eq(Got(ola, "family:cat").told, "none")
        ola:Slash("ach share")
        ok(ola:Printed("Du er ikke i en guild."))
    end)

    test("notices can be turned off (per character); you still see your own", function()
        local w, ola, kari = Setup({ 40, 41, 42 })
        ola:Slash("ach notify off")
        ok(ola:Printed("får ikke lenger beskjed", true))
        Learn(ola, 46)
        w:Run(2)
        eq(w:Sent("ACH_EARNED"), 0)
        no(kari:Printed("fikk"))
        ok(ola:Printed("Ola Nord fikk [Kattevræl]!", true))
        eq(Got(ola, "family:cat").told, "off")
        ola:Slash("ach notify on")
        eq(ola.env.DyreparkenCharDB.achNotify, true)
        ola:Slash("prestasjoner varsel av")
        eq(ola.env.DyreparkenCharDB.achNotify, false, "the Norwegian words work too")
        ola:Slash("prestasjoner varsel på")
        eq(ola.env.DyreparkenCharDB.achNotify, true)
    end)

    test("loyalty: a bond seeded from 30 days together, and a first nickname", function()
        local w, ola, kari = Setup({ 5159 })
        ola:Slash("adopt")
        w:Run(1)
        no(Got(ola, "loyal:30"))
        w:SkipDays(30)
        local m = w:Mark()
        ola:Reload(); Fix(ola)
        w:Run(12)
        no(Got(ola, "loyal:30"), "the bond is seeded a little after login")
        w:Run(10)
        ok(Got(ola, "loyal:30"), "300 points: Venn (from 270)")
        eq(w:Sent("ACH_EARNED", nil, m), 1, "a real moment, not a first look")
        ok(kari:Printed("Ola Nord fikk [Bestevenner]!", true))
        no(Got(ola, "loyal:100"))
        ola:Slash("ach")
        ok(ola:Printed("[Uatskillelige] 300/530 poeng", true))
        ola:Slash("nick Bambus")
        w:Run(1)
        ok(Got(ola, "nick"))
        ok(kari:Printed("Ola Nord fikk [Døpt]!", true))
        eq(ola.env.DyreparkenCharDB.ach.got.nick.told ~= nil, true)
        eq(ola.env.DyreparkenDB.ach.got.nick, nil, "character scope")
        -- The shared lines name the pet.
        local A = ola.ns.Achievements
        eq(A:ShareLine("nick"), "Ola Nord har døpt Panda Cub til «Bambus»! [Døpt]")
        eq(A:ShareLine("loyal:30"), "Ola Nord og Bambus er blitt ordentlige venner! [Bestevenner]")
        ola:Slash("nick")
        eq(A:ShareLine("nick"), "Ola Nord har gitt dyret sitt et navn! [Døpt]", "no nickname now: the plain line")
        eq(A:ShareLine("loyal:30"), "Ola Nord og Panda Cub er blitt ordentlige venner! [Bestevenner]",
            "no nickname: the species")
        ola:Slash("letgo")
        eq(A:ShareLine("loyal:30"), "Ola Nord og dyret sitt er blitt ordentlige venner! [Bestevenner]")
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
end
