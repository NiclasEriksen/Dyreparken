-- X-Protocol 10 (2026-11-13, for 0.6.0): a bond's room a day holds the wish, wire times are whole
-- seconds, and a claim's or a name's digest line carries what it holds.
return function(test, H)
    local eq, ok = H.eq, H.ok
    local KITTEN, BOMBAY = "s:46", "s:40"

    test("a relayed copy with the same time but another pet is corrected (the digest carries the pet)", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 46 } }
        w:AddMember("Per Hansen", 0)
        local now = w:ServerTime()
        -- Two copies of Per's record, the same ts: one says kitten, the other bombay.
        ola.ns.Registry:MergeRecord("Per Hansen", { k = KITTEN, at = now - 10, ts = now - 5 })
        kari.ns.Registry:MergeRecord("Per Hansen", { k = BOMBAY, at = now - 10, ts = now - 5 })
        ola.ns.Registry:Changed(); kari.ns.Registry:Changed()
        ok(ola.ns.Sync:Digest() ~= kari.ns.Sync:Digest(), "the digests see it")
        kari:Reload()
        w:Run(60)
        -- The greater line wins on both (the pet's key, "s:46" > "s:40").
        for _, c in ipairs({ ola, kari }) do eq(c.ns.Registry:Holder(KITTEN), "Per Hansen", c.name) end
        H.assertConverged(w)
    end)

    test("a bond's room holds every full day with its wish, and a feat on top across midnight", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local B, R = ola.ns.Bond, ola.ns.Registry
        -- Adopted just before midnight: the calendar's first day full, then the next one full with a
        -- feat, within 24 hours of the start. Two spare days of 75 clamped this at 150.
        w:SetDate(2026, 12, 1, 23, 50)
        ola:Slash("adopter")
        w:Run(1)
        local start = (R:Life("s:5159", "Ola Nord") or { p = 0 }).p
        B:Add(85 - start)
        w:SetDate(2026, 12, 2, 0, 10)
        B:Add(85)
        B:Add(25)
        eq(R:Life("s:5159", "Ola Nord").p, 195)
        eq(ola.ns.Wire.DayRoom(), 85, "the day's 75 and the wish's 10 (Bond.REWARDS: beyond, once)")
    end)

    test("migration 13 drops what peers refuse now: times off a whole second", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { login = false })
        local now = w:ServerTime()
        local lapses = { ["Bo Berg"] = now - 3, ["Siv Dahl"] = now - 3.5 }
        c.saved.DyreparkenDB = { schema = 12, guilds = { Dyreparken = {
            claims = { ["Kari Berg"] = { k = KITTEN, at = now - 10, ts = now - 5 },
                ["Per Hansen"] = { k = BOMBAY, at = now - 10.5, ts = now - 5 } },
            lapses = lapses,
            names = { [KITTEN] = { ["Kari Berg"] = { n = "Pus", at = now - 7 }, ["Per Hansen"] = { n = "X", at = now - 0.25 } } },
            life = { [KITTEN] = { ["Kari Berg"] = { p = 5, f = now - 60, t = now }, ["Per Hansen"] = { p = 5, f = now - 60.5, t = now } } },
            ach = { ["guild:family:cat"] = { at = now - 100 }, ["guild:family:dog"] = { at = now - 99.5 } },
        } } }
        c:Login()
        local g = c.env.DyreparkenDB.guilds.Dyreparken
        eq(c.env.DyreparkenDB.schema, c.ns.DB.SCHEMA)
        ok(g.claims["Kari Berg"]); eq(g.claims["Per Hansen"], nil)
        ok(g.names[KITTEN]["Kari Berg"]); eq(g.names[KITTEN]["Per Hansen"], nil)
        ok(g.life[KITTEN]["Kari Berg"]); eq(g.life[KITTEN]["Per Hansen"], nil)
        ok(g.ach["guild:family:cat"]); eq(g.ach["guild:family:dog"], nil)
        ok(g.lapses["Bo Berg"]); eq(g.lapses["Siv Dahl"], nil)
    end)
end
