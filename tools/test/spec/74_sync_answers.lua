-- Answers and traffic (review 2026-11-21, part B): a card's bonds that went unheard, a forged BONDS that silenced
-- everyone, a login that brought an OWN_SYNC from nearly every peer, a SYNC part that only just didn't fit, and
-- strangers' whispers.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local KITTEN = "s:46"

    test("a BONDS without our bond doesn't hold ours back: the card hears every carer", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 46 } })
        w:Run(20)
        ola:Summon(46); ola.ns.Bond:Add(20, KITTEN) -- (Kari isn't online to hear it, and no SYNC carries it)
        w:Run(5)
        local kari = w:AddClient("Kari Berg", { pets = { 46 } })
        w:Run(40)
        kari:Summon(46); kari.ns.Bond:Add(10, KITTEN)
        w:Run(5)
        no(kari.ns.Registry:Life(KITTEN, "Ola Nord"))
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:Run(40)
        kari.ns.Sync.BONDS_WAIT = { 0, 0.1 } -- (Kari answers first, with hers only)
        ola.ns.Sync.BONDS_WAIT = { 2, 2.4 }
        local m = w:Mark()
        nina:OpenJournal(); nina:SelectPet(46)
        w:Run(10)
        eq(w:Sent("BONDS", "Ola Nord", m), 1)
        eq(nina:Points(KITTEN, "Ola Nord"), ola:Points(KITTEN, "Ola Nord"))
        ok(nina:Points(KITTEN, "Kari Berg") > 0)
    end)

    test("a forged BONDS with impossible points holds no honest answer back", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 46 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46 } })
        w:Run(20)
        ola:Summon(46); ola.ns.Bond:Add(20, KITTEN)
        kari:Summon(46); kari.ns.Bond:Add(10, KITTEN)
        w:Run(5)
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:Run(40)
        local m = w:Mark()
        nina:OpenJournal(); nina:SelectPet(46)
        w:Run(0.2)
        w:InjectMessage("Per Hansen", { k = "BONDS", p = nina.ns.PROTOCOL, pet = KITTEN,
            b = { ["Ola Nord"] = { p = math.huge }, ["Kari Berg"] = { p = 0 / 0 } } }, "GUILD")
        w:Run(10)
        eq(w:Sent("BONDS", "Ola Nord", m) + w:Sent("BONDS", "Kari Berg", m), 1)
        ok(nina:Points(KITTEN, "Ola Nord") > 0)
        ok(nina:Points(KITTEN, "Kari Berg") > 0)
    end)

    test("a card's question nobody answered is asked once more a minute later", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 46 } })
        w:Run(20)
        ola:Summon(46); ola.ns.Bond:Add(20, KITTEN)
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:Run(40)
        local m = w:Mark()
        w.drop = function(m) return tostring(m.sender):find("Nina", 1, true) ~= nil end -- (her question is lost)
        nina:OpenJournal(); nina:SelectPet(46)
        w:Run(5)
        w.drop = nil
        eq(w:Sent("BONDS", nil, m), 0)
        nina:SelectPet(72); w:Run(nina.ns.Sync.REASK); nina:SelectPet(46)
        w:Run(5)
        eq(w:Sent("BONDS_REQ", "Nina Ny", m), 2)
        eq(w:Sent("BONDS", "Ola Nord", m), 1)
        -- Answered now: not asked again.
        nina:SelectPet(72); w:Run(nina.ns.Sync.REASK * 2); nina:SelectPet(46)
        w:Run(5)
        eq(w:Sent("BONDS_REQ", "Nina Ny", m), 2)
    end)

    test("one login brings one OWN_SYNC, however many peers know more", function()
        local w = H.World({ members = H.FOLK })
        local peers = {}
        for i = 1, 10 do
            local name = ("Peer Nr%02d"):format(i)
            w:AddMember(name, 0)
            peers[i] = w:AddClient(name, { pets = { 40 } })
        end
        w:Run(30)
        local now = w:ServerTime()
        for i = 1, 24 do
            local name = ("Medlem Nr%02d"):format(i)
            w:AddMember(name, 0)
            local ids = {}
            for s = 1, 80 do ids[#ids + 1] = 1000 + i * 100 + s * 7 end
            w:InjectMessage(name, { k = "OWN", p = 11, e = { at = now, s = table.concat(ids, ",") } })
        end
        w:Run(120)
        w:AddMember("Ny Kommer", 0)
        local m = w:Mark()
        local newbie = w:AddClient("Ny Kommer", { pets = { 46 } })
        w:Run(300)
        local firsts = 0
        for i = m + 1, #w.wire do
            local x = w.wire[i]
            if x.kind == "OWN_SYNC" and x.msg.i == 1 then firsts = firsts + 1 end
        end
        ok(firsts <= 2, ("%d OWN_SYNCs answered one login"):format(firsts))
        eq(newbie.ns.Owners:Digest(), peers[1].ns.Owners:Digest())
    end)

    test("a SYNC part is sized with what it carries when sent, so none is left out", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        w:Run(5)
        -- (a limit of 4 chunks: the edge is the same at any size, and compressing thousands of lapses again and
        -- again took 8 minutes under coverage)
        ola.ns.Wire.LIMITS.MAX_PARTS = 4
        local Fits, LIM = ola.ns.Comm.Fits, 254 * ola.ns.Wire.LIMITS.MAX_PARTS
        local with = { i = 999, of = 999, d = 4294967295, k = "SYNC", p = 999 }
        local seed, names, times = 12345, {}, {}
        local function rnd() seed = (seed * 1103515245 + 12345) % 2147483648; return seed end
        for n = 1, 400 do names[n], times[n] = ("M%08x Nr%05d"):format(rnd(), n), 1700000000 + rnd() % 90000000 end
        local function Lapses(n)
            local l = {}
            for j = 1, n do l[names[j]] = times[j] end
            return l
        end
        -- The most lapses that fit, by halving; the parts nearest the limit are the ones a missing field pushed over it.
        local lo, hi = 1, 400
        ok(not Fits({ l = Lapses(hi) }, with))
        while hi - lo > 1 do
            local mid = math.floor((lo + hi) / 2)
            if Fits({ l = Lapses(mid) }, with) then lo = mid else hi = mid end
        end
        ok(lo > 20, "the edge is somewhere real")
        for n = lo - 7, lo do
            local full = { l = Lapses(n), k = "SYNC", p = 12, i = 2, of = 3, d = 123456789 }
            local size = #H.Encode(full)
            ok(size <= LIM, ("%d lapses fit, but sent it's %d bytes"):format(n, size))
        end
    end)

    test("addon messages on a whisper or a custom channel aren't even unpacked", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        w:Run(20)
        w:InjectMessage("Fremmed Person", { k = "SYNC", p = ola.ns.PROTOCOL, l = {} }, "WHISPER", "Ola Nord")
        w:Run(1)
        no(ola:Log("SYNC from Fremmed Person")[1])
    end)

    test("our owned list written again past a forged copy stays within what peers accept", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46 } })
        w:Run(60.45) -- (the copy arrives within the second it's stamped from: at the slack's very edge)
        local now = w:ServerTime()
        w:InjectMessage("Per Hansen", { k = "OWN_SYNC", p = 11, i = 1, of = 1, d = 1,
            o = { ["Ola Nord"] = { at = now + ola.ns.Config.CLOCK_SLACK, s = "40,41,42" } } }, "GUILD")
        w:Run(5)
        eq(kari.ns.DB:Guild().owns["Ola Nord"].s, "5159")
        eq(ola.ns.DB:Guild().owns["Ola Nord"].s, "5159")
    end)
end
