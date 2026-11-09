-- Registry: the data model on one client (claims, merge rules, holder
-- derivation, nicknames, lapses). Multi-client behavior is in 04_sync.lua.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN, BOMBAY = "s:5159", "s:46", "s:40"

    local function One(opts)
        local w = H.World()
        local c = w:AddClient("Ola Nord", opts or { pets = { 5159, 46 } })
        w:Run(12)
        return w, c, c.ns.Registry
    end

    test("claim: needs a guild, a known pet you own, and a free pet", function()
        local w = H.World()
        local lone = w:AddClient("Ola Nord", { guild = false })
        local R = lone.ns.Registry
        eq(select(2, R:Claim(PANDA)), "Du er ikke i en guild.")
        eq(select(2, R:Release()), "Du har ikke adoptert noe dyr.")
        eq(R:MyPet(), nil)
        eq(R:MyRecord(), nil)
        local claims, lapses = R:All()
        eq(next(claims), nil); eq(next(lapses), nil)
        eq(R:Count(), 0)
        eq(R:Holder(PANDA), nil)
        no(R:CheckMine())
        eq(R:CheckRoster(), nil)
        no(R:MergeRecord("Kari Berg", { k = PANDA, at = 1, ts = 1 }))
        no(R:MergeLapse("Kari Berg", 1))

        local _, c, R2 = One()
        eq(select(2, R2:Claim(nil)), "Ukjent dyr.")
        eq(select(2, R2:Claim(BOMBAY)), "Du har ikke det dyret.")
        local okc, msg = R2:Claim(PANDA)
        ok(okc); eq(msg, "Du adopterte Panda Cub.")
        eq(select(2, R2:Claim(PANDA)), "Det bor allerede hos deg.")
        R2:MergeRecord("Kari Berg", { k = KITTEN, at = 1, ts = 1 })
        eq(select(2, R2:Claim(KITTEN)), "Det bor allerede hos Kari Berg.")
    end)

    test("claiming another pet releases the first and drops its nickname", function()
        local w, c, R = One()
        R:Claim(PANDA)
        w:SkipDays(7)
        w:Befriend()
        R:SetNickname("Bambus")
        local okc, msg = R:Claim(KITTEN)
        ok(okc)
        eq(msg, "Du adopterte White Kitten (og ga slipp på Panda Cub).")
        eq(R:Holder(PANDA), nil)
        eq(R:MyPet(), KITTEN)
        eq(R:MyRecord().n, nil)
        eq(R:Count(), 1)
    end)

    test("every edit gets a higher ts, even within one second", function()
        local w, c, R = One()
        R:Claim(PANDA)
        local t1 = R:MyRecord().ts
        R:Release()
        local t2 = R:MyRecord().ts
        R:Claim(PANDA)
        local t3 = R:MyRecord().ts
        ok(t2 > t1 and t3 > t2, ("%d %d %d"):format(t1, t2, t3))
    end)

    test("release keeps a record without a pet", function()
        local w, c, R = One()
        R:Claim(PANDA)
        local at = R:MyRecord().at
        local okr, msg = R:Release()
        ok(okr); eq(msg, "Du ga slipp på Panda Cub.")
        eq(R:MyRecord().k, nil)
        eq(R:MyRecord().at, at)
        eq(R:Holder(PANDA), nil)
        eq(select(2, R:Release()), "Du har ikke adoptert noe dyr.")
    end)

    test("the earliest claim holds; ties go to the lower name", function()
        local w, c, R = One()
        R:MergeRecord("Per Hansen", { k = BOMBAY, at = 300, ts = 300 })
        R:MergeRecord("Kari Berg", { k = BOMBAY, at = 200, ts = 200 })
        R:MergeRecord("Liv Lund", { k = BOMBAY, at = 250, ts = 250 })
        eq(R:Holder(BOMBAY), "Kari Berg")
        R:MergeRecord("Bjorn Aas", { k = BOMBAY, at = 200, ts = 201 })
        R:MergeRecord("Anne Aas", { k = BOMBAY, at = 200, ts = 202 })
        local owner, r = R:Holder(BOMBAY)
        eq(owner, "Anne Aas")
        eq(r.ts, 202)
        eq(R:Count(), 1)
        eq(R:Holders()[BOMBAY], "Anne Aas")
    end)

    test("merge: newest ts wins, bad shapes are refused", function()
        local w, c, R = One()
        ok(R:MergeRecord("Kari Berg", { k = KITTEN, at = 100, ts = 100 }))
        no(R:MergeRecord("Kari Berg", { k = BOMBAY, at = 50, ts = 99 }), "older")
        no(R:MergeRecord("Kari Berg", { k = BOMBAY, at = 50, ts = 100 }), "same ts")
        ok(R:MergeRecord("Kari Berg", { at = 100, ts = 101 }), "newer release")
        eq(R:Holder(KITTEN), nil)
        local bad = {
            "not a table",
            { k = KITTEN, at = 1 },                          -- no ts
            { k = KITTEN, at = "1", ts = 200 },              -- at not a number
            { k = 5, at = 1, ts = 200 },                     -- key not a string
            { k = string.rep("x", 65), at = 1, ts = 200 },   -- key too long
        }
        local now = c.world:ServerTime()
        bad[#bad + 1] = { k = KITTEN, at = 1, ts = 1 / 0 }          -- infinite: would win every merge
        bad[#bad + 1] = { k = KITTEN, at = 0 / 0, ts = 300 }        -- NaN: never compares
        bad[#bad + 1] = { k = KITTEN, at = 1, ts = now + 2 * 86400 } -- far future
        bad[#bad + 1] = { k = KITTEN, at = -5, ts = 300 }
        for i, r in ipairs(bad) do no(R:MergeRecord("Per Hansen", r), "bad record " .. i) end
        ok(R:MergeRecord("Siv Dahl", { at = 1, ts = now + 3600 }), "a little ahead is fine (clocks differ)")
        no(R:MergeRecord(string.rep("x", 49), { k = KITTEN, at = 1, ts = 1 }), "owner too long")
        no(R:MergeLapse("Per Hansen", now + 10 * 365 * 86400), "far-future lapse")
        no(R:MergeLapse("Per Hansen", 0 / 0), "NaN lapse")
        no(R:MergeRecord("", { k = KITTEN, at = 1, ts = 1 }), "empty owner")
        no(R:MergeRecord(7, { k = KITTEN, at = 1, ts = 1 }), "owner not a string")
        ok(R:MergeRecord("Per Hansen", { k = KITTEN, at = 1, ts = 200, n = "old field", na = 5 }))
        eq(select(2, R:Holder(KITTEN)).n, nil, "records don't carry names any more")
        -- The stored copy is ours, not the caller's table.
        local r = { k = BOMBAY, at = 5, ts = 300, extra = "dropped" }
        R:MergeRecord("Liv Lund", r)
        r.k = PANDA
        eq(R:Holder(BOMBAY), "Liv Lund")
        eq(select(2, R:Holder(BOMBAY)).extra, nil)
    end)

    test("lapses void older claims for good; newer claims count", function()
        local w, c, R = One()
        R:MergeRecord("Kari Berg", { k = KITTEN, at = 100, ts = 100 })
        ok(R:MergeLapse("Kari Berg", 150))
        no(R:MergeLapse("Kari Berg", 120), "lapses only grow")
        no(R:MergeLapse("Kari Berg", "later"))
        no(R:MergeLapse(nil, 200))
        eq(R:Holder(KITTEN), nil)
        R:MergeRecord("Kari Berg", { k = KITTEN, at = 150, ts = 151 })
        eq(R:Holder(KITTEN), nil, "claimed at the lapse moment: still void")
        R:MergeRecord("Kari Berg", { k = KITTEN, at = 160, ts = 161 })
        eq(R:Holder(KITTEN), "Kari Berg")
    end)

    test("nicknames: locked until the bond is Venn, then 1-20 characters without | or line breaks", function()
        local w, c, R = One()
        eq(select(2, R:SetNickname("Early")), "Du har ikke adoptert noe dyr.")
        R:Claim(PANDA)
        local okn, msg = R:SetNickname("Bambus")
        no(okn)
        eq(msg, "Du kan gi det et kallenavn når båndet deres er Venn (nivå 3).")
        no(R:CanNickname(R:MyRecord()))
        w:SkipDays(7)
        no(R:CanNickname(R:MyRecord()), "days alone don't unlock it any more")
        local B = c.ns.Bond
        B:Add(B.LEVELS[3][1] - 1)
        no(R:CanNickname(R:MyRecord()), "one point short")
        B:Add(1)
        ok(R:CanNickname(R:MyRecord()), "Venn: it may be named")
        okn, msg = R:SetNickname("  Bambus  ")
        ok(okn); eq(msg, 'Kallenavnet er nå «Bambus».')
        eq(R:Nickname(PANDA), "Bambus")
        eq(select(3, R:Nickname(PANDA)), c.world:ServerTime())
        eq(select(2, R:SetNickname("Bambus")), "Det heter allerede «Bambus».")
        eq(select(2, R:SetNickname(string.rep("x", 21))), "Kallenavn kan ha maks 20 tegn.")
        ok(R:SetNickname(string.rep("ø", 20)), "UTF-8 counts characters")
        eq(select(2, R:SetNickname("a|b")), "Kallenavn kan ikke inneholde | eller linjeskift.")
        okn, msg = R:SetNickname("   ")
        ok(okn); eq(msg, "Kallenavnet er fjernet.")
        eq(R:Nickname(PANDA), nil)
        eq(select(2, R:SetNickname("")), "Det har ikke noe kallenavn.")
        R:SetNickname("Igjen")
        ok(R:SetNickname(nil))
        eq(R:Nickname(PANDA), nil)
        no(R:ValidNickname(nil))
        no(R:ValidNickname(""))
        eq(select(2, R:ValidNickname(" Mr. Whiskers ")), "Mr. Whiskers")
    end)

    test("the roster lapses owners who left or stayed away 30 days", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:AddMember("Per Hansen", 31)
        w:AddMember("Liv Lund", 29)
        w:AddMember("Siv Dahl", 400)
        w:Run(12)
        local R = c.ns.Registry
        R:MergeRecord("Kari Berg", { k = "s:46", at = 100, ts = 100 }) -- not in the guild
        R:MergeRecord("Per Hansen", { k = "s:40", at = 100, ts = 100 })
        R:MergeRecord("Liv Lund", { k = "s:41", at = 100, ts = 100 })
        R:MergeRecord("Siv Dahl", { at = 100, ts = 100 }) -- nothing reserved: nothing to lapse
        c.ns.Guild:Refresh(true)
        w:Run(1)
        local _, lapses = R:All()
        ok(lapses["Kari Berg"], "left the guild")
        ok(lapses["Per Hansen"], "31 days")
        no(lapses["Liv Lund"], "29 days is fine")
        no(lapses["Siv Dahl"])
        eq(c.ns.Guild:DaysOffline("Siv Dahl"), 400, "years, months, days add up")
        eq(R:Holder("s:41"), "Liv Lund")
        eq(#c:Log("lapse Kari Berg %(left guild%)"), 1)
        eq(#c:Log("lapse Per Hansen %(31 days offline%)"), 1)
        eq(w:Sent("LAPSE", "Ola Nord"), 1)
        -- Checking again adds nothing new.
        eq(R:CheckRoster(), nil)
    end)

    test("an incomplete roster can't release anyone who's missing from it", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:AddMember("Per Hansen", 0)
        w:AddMember("Liv Lund", 45)
        w:Run(12)
        c.rosterPartial = 2 -- the server sent only part of the rows
        local R = c.ns.Registry
        R:MergeRecord("Kari Berg", { k = "s:46", at = 100, ts = 100 })
        R:MergeRecord("Liv Lund", { k = "s:40", at = 100, ts = 100 })
        c.ns.Guild:Refresh(true)
        w:Run(1)
        no(c.ns.Guild.complete)
        eq(c.ns.Guild:IsMember("Kari Berg"), nil, "unknown, not false")
        eq(R:Holder("s:46"), "Kari Berg")
        eq(R:Holder("s:40"), "Liv Lund", "Liv's row was not read")
    end)

    test("own claim lost or lapsed: withdrawn with a notice", function()
        local w, c, R = One()
        R:Claim(PANDA)
        local mine = R:MyRecord()
        R:MergeRecord("Kari Berg", { k = PANDA, at = mine.at - 10, ts = mine.at - 10 })
        R:Changed()
        ok(R:CheckMine())
        ok(c:Printed("Kari Berg rakk å adoptere Panda Cub rett før deg, så det bor der nå."))
        eq(R:MyRecord().k, nil)
        no(R:CheckMine(), "nothing left to withdraw")

        R:Claim(KITTEN)
        R:MergeLapse("Ola Nord", w:ServerTime())
        R:Changed()
        ok(R:CheckMine())
        ok(c:Printed("White Kitten dro tilbake til parken mens du var lenge borte."))
        eq(R:MyRecord().k, nil)
    end)

    test("names: entries merge by newest time, bad shapes are refused", function()
        local w, c, R = One()
        ok(R:MergeName(KITTEN, "Kari Berg", { n = "Pus", at = 100 }))
        no(R:MergeName(KITTEN, "Kari Berg", { n = "Eldre", at = 99 }), "older")
        no(R:MergeName(KITTEN, "Kari Berg", { n = "Samme", at = 100 }), "same time")
        eq(R:Nickname(KITTEN), "Pus")
        local bad = {
            "not a table",
            { n = "Pus" },                             -- no time
            { n = "Pus", at = "100" },
            { n = 5, at = 200 },
            { n = "", at = 200 },
            { n = string.rep("æ", 21), at = 200 },
            { n = "a|cffff0000red", at = 200 },
            { n = "two\nlines", at = 200 },
            { n = "Pus", at = 200, x = "yes" },
            { n = "a" .. string.rep("\128", 100), at = 200 },  -- one "character" by lead bytes
            { n = "Pus", at = 1 / 0 },
        }
        for i, e in ipairs(bad) do no(R:MergeName(KITTEN, "Per Hansen", e), "bad entry " .. i) end
        no(R:MergeName(5, "Per Hansen", { n = "Pus", at = 1 }), "key not a string")
        no(R:MergeName(string.rep("x", 65), "Per Hansen", { n = "Pus", at = 1 }), "key too long")
        no(R:MergeName(KITTEN, "", { n = "Pus", at = 1 }), "empty namer")
        ok(R:MergeName(KITTEN, "Per Hansen", { n = string.rep("æ", 20), at = 300, extra = 1 }), "20 characters")
        eq(c.env.DyreparkenDB.guilds.Dyreparken.names[KITTEN]["Per Hansen"].extra, nil, "stored copy is ours")
        eq(R:Nickname(nil), nil)
        eq(R:Nickname(PANDA), nil, "never named")
    end)

    test("names: the pet keeps its name; only the holder renames it while caring", function()
        local w, c, R = One()
        -- Kari named the kitten while she cared for it, then let it go.
        R:MergeRecord("Kari Berg", { k = KITTEN, at = 100, ts = 100 })
        R:MergeName(KITTEN, "Kari Berg", { n = "Pus", at = 200 })
        R:MergeRecord("Kari Berg", { at = 100, ts = 300 })
        eq(R:Holder(KITTEN), nil)
        eq(R:Nickname(KITTEN), "Pus", "free pets keep their name")
        local now = c.world:ServerTime()
        ok(R:Claim(KITTEN))
        eq(R:Nickname(KITTEN), "Pus", "the new carer inherits it")
        -- Someone who doesn't hold it can't rename it (forged, or a partition).
        R:MergeName(KITTEN, "Per Hansen", { n = "Feil", at = now + 10 })
        eq(R:Nickname(KITTEN), "Pus")
        no(R:SetNickname("Min"), "locked i 7 dager")
        w:SkipDays(7)
        w:Befriend()
        ok(R:SetNickname("Min"))
        local name, namer = R:Nickname(KITTEN)
        eq(name, "Min"); eq(namer, "Ola Nord")
        ok(R:SetNickname(""))
        eq(R:Nickname(KITTEN), nil, "the holder can clear it")
        -- After Ola lets go, Per's old forged entry is older than any new
        -- adoption, but Ola's clear is newer still.
        R:Release()
        eq(R:Nickname(KITTEN), nil)
    end)

    test("names: a lost adoption race voids the name given meanwhile", function()
        local w, c, R = One()
        local t0 = c.world:ServerTime()
        ok(R:Claim(KITTEN))
        w:SkipDays(7)
        w:Befriend()
        ok(R:SetNickname("Tapt"))
        -- Kari's earlier claim shows up (a partition healing).
        R:MergeRecord("Kari Berg", { k = KITTEN, at = t0 - 5, ts = t0 })
        R:MergeName(KITTEN, "Kari Berg", { n = "Karis", at = t0 - 1 })
        R:Changed()
        ok(R:CheckMine())
        local g = c.env.DyreparkenDB.guilds.Dyreparken
        eq(g.names[KITTEN]["Ola Nord"].x, true)
        eq(R:Holder(KITTEN), "Kari Berg")
        eq(R:Nickname(KITTEN), "Karis")
        -- After Kari lets go, Ola's void entry still doesn't hide Kari's name.
        R:MergeRecord("Kari Berg", { at = t0 - 5, ts = t0 + 999999 })
        eq(R:Nickname(KITTEN), "Karis")
    end)

    test("names: a lapse keeps the name the holder gave", function()
        local w, c, R = One()
        R:MergeRecord("Kari Berg", { k = KITTEN, at = 100, ts = 100 })
        R:MergeName(KITTEN, "Kari Berg", { n = "Pus", at = 200 })
        R:MergeLapse("Kari Berg", 500)
        R:Changed()
        eq(R:Holder(KITTEN), nil)
        eq(R:Nickname(KITTEN), "Pus")
    end)

    test("switching guilds (or leaving) doesn't reuse the old guild's holders", function()
        local w, c, R = One()
        ok(R:Claim(PANDA))
        eq(R:Holder(PANDA), "Ola Nord")
        c.guild = "Annet Laug"
        eq(R:Holder(PANDA), nil, "a fresh guild")
        ok(R:Claim(PANDA), "free to adopt here")
        eq(R:Count(), 1)
        c.guild = nil
        eq(R:Holder(PANDA), nil)
        eq(R:Count(), 0)
        eq(R:Nickname(PANDA), nil)
        eq(#c:Hover({ species = 5159, owner = "Ola Nord" }), 0)
        c.guild = w.guildName
        eq(R:Holder(PANDA), "Ola Nord", "back home")
    end)
end
