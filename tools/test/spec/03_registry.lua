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
        eq(select(2, R:Claim(PANDA)), "You're not in a guild.")
        eq(select(2, R:Release()), "You haven't adopted a companion.")
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
        eq(select(2, R2:Claim(nil)), "Unknown companion.")
        eq(select(2, R2:Claim(BOMBAY)), "You don't have that companion.")
        local okc, msg = R2:Claim(PANDA)
        ok(okc); eq(msg, "You adopted Panda Cub.")
        eq(select(2, R2:Claim(PANDA)), "It's already yours.")
        R2:MergeRecord("Kari Berg", { k = KITTEN, at = 1, ts = 1 })
        eq(select(2, R2:Claim(KITTEN)), "Kari Berg is already caring for it.")
    end)

    test("claiming another pet releases the first and drops its nickname", function()
        local w, c, R = One()
        R:Claim(PANDA)
        w:SkipDays(7)
        R:SetNickname("Bambus")
        local okc, msg = R:Claim(KITTEN)
        ok(okc)
        eq(msg, "You adopted White Kitten (and let Panda Cub go).")
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
        ok(okr); eq(msg, "You let Panda Cub go.")
        eq(R:MyRecord().k, nil)
        eq(R:MyRecord().at, at)
        eq(R:Holder(PANDA), nil)
        eq(select(2, R:Release()), "You haven't adopted a companion.")
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
            { k = KITTEN, at = 1, ts = 200, n = 5 },         -- nickname not a string
            { k = KITTEN, at = 1, ts = 200, n = string.rep("æ", 21) },
            { k = KITTEN, at = 1, ts = 200, n = "a|cffff0000red" },
            { k = KITTEN, at = 1, ts = 200, n = "two\nlines" },
            { k = KITTEN, at = 1, ts = 200, na = "soon" },
        }
        for i, r in ipairs(bad) do no(R:MergeRecord("Per Hansen", r), "bad record " .. i) end
        no(R:MergeRecord("", { k = KITTEN, at = 1, ts = 1 }), "empty owner")
        no(R:MergeRecord(7, { k = KITTEN, at = 1, ts = 1 }), "owner not a string")
        ok(R:MergeRecord("Per Hansen", { k = KITTEN, at = 1, ts = 200, n = string.rep("æ", 20), na = 5 }),
            "20 characters is fine")
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

    test("nicknames: locked for 7 days, then 1-20 characters without | or line breaks", function()
        local w, c, R = One()
        eq(select(2, R:SetNickname("Early")), "You haven't adopted a companion.")
        R:Claim(PANDA)
        local okn, msg = R:SetNickname("Bambus")
        no(okn)
        match(msg, "^You can name it from %d%d %a+ %d%d%d%d%.$")
        no(R:CanNickname(R:MyRecord()))
        w:SkipDays(7)
        ok(R:CanNickname(R:MyRecord()))
        okn, msg = R:SetNickname("  Bambus  ")
        ok(okn); eq(msg, 'Nickname set to "Bambus".')
        eq(R:MyRecord().n, "Bambus")
        eq(R:MyRecord().na, c.world:ServerTime())
        eq(select(2, R:SetNickname(string.rep("x", 21))), "Nicknames can be at most 20 characters.")
        ok(R:SetNickname(string.rep("ø", 20)), "UTF-8 counts characters")
        eq(select(2, R:SetNickname("a|b")), "Nicknames can't contain | or line breaks.")
        okn, msg = R:SetNickname("   ")
        ok(okn); eq(msg, "Nickname cleared.")
        eq(R:MyRecord().n, nil)
        eq(R:MyRecord().na, nil)
        R:SetNickname("Igjen")
        ok(R:SetNickname(nil))
        eq(R:MyRecord().n, nil)
        no(R:ValidNickname(nil))
        no(R:ValidNickname(""))
        eq(select(2, R:ValidNickname(" Mr. Whiskers ")), "Mr. Whiskers")
        eq(R:MyRecord().at + 7 * 86400, R:NicknameUnlocksAt(R:MyRecord()))
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
        ok(c:Printed("Kari Berg adopted Panda Cub just before you did, so it went home with them."))
        eq(R:MyRecord().k, nil)
        no(R:CheckMine(), "nothing left to withdraw")

        R:Claim(KITTEN)
        R:MergeLapse("Ola Nord", w:ServerTime())
        R:Changed()
        ok(R:CheckMine())
        ok(c:Printed("Your White Kitten went back to the park after your long absence."))
        eq(R:MyRecord().k, nil)
    end)
end
