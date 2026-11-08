-- Sync between several clients: updates, login catch-up, races, partitions,
-- lost messages, lapses, forged input, and a randomized convergence test.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN, BOMBAY, RABBIT = "s:5159", "s:46", "s:40", "s:72"

    -- A guild of clients, logged in and past the login chatter.
    local function Guild(spec)
        local w = H.World()
        local list = {}
        for _, s in ipairs(spec) do
            list[#list + 1] = w:AddClient(s[1], { pets = s[2], login = s.offline ~= true })
        end
        w:Run(20)
        return w, unpack(list)
    end

    test("a claim reaches everyone online right away", function()
        local w, ola, kari, per = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } }, { "Per Hansen", { 40 } } })
        eq(w:Sent("SYNC"), 0, "equal (empty) registries: no SYNC at login")
        local m = w:Mark()
        ola:Slash("claim")
        w:Run(1)
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        eq(per.ns.Registry:Holder(PANDA), "Ola Nord")
        eq(w:Sent("UPD", nil, m), 1)
        eq(w:Sent("SYNC", nil, m), 0)
        H.assertConverged(w)
    end)

    test("switching pets frees the old one for everyone at once", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159, 46 } }, { "Kari Berg", { 5159 } } })
        ola:Slash("claim panda")
        w:Run(1)
        eq(select(2, kari.ns.Registry:Claim(PANDA)), "Det bor allerede hos Ola Nord.")
        ola:Slash("claim kitten")
        w:Run(1)
        eq(kari.ns.Registry:Holder(PANDA), nil)
        eq(kari.ns.Registry:Holder(KITTEN), "Ola Nord")
        ok(kari.ns.Registry:Claim(PANDA))
        w:Run(1)
        eq(ola.ns.Registry:Holder(PANDA), "Kari Berg")
        H.assertConverged(w)
    end)

    test("someone logging in catches up with a single SYNC", function()
        local w, ola, kari, per, liv = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } },
            { "Per Hansen", { 40 } }, { "Liv Lund", { 72 }, offline = true } })
        ola:Slash("claim"); kari:Slash("claim"); per:Slash("claim")
        w:Run(2)
        local m = w:Mark()
        liv:Login()
        w:Run(25)
        eq(liv.ns.Registry:Holder(PANDA), "Ola Nord")
        eq(liv.ns.Registry:Holder(KITTEN), "Kari Berg")
        eq(liv.ns.Registry:Holder(BOMBAY), "Per Hansen")
        eq(w:Sent("SYNC", nil, m), 1, "the other peers held back")
        H.assertConverged(w)
    end)

    test("what the newcomer knew flows back to the others", function()
        local w, liv, ola, kari = Guild({ { "Liv Lund", { 72 } }, { "Ola Nord", { 5159 }, offline = true },
            { "Kari Berg", { 46 }, offline = true } })
        liv:Slash("claim")
        w:Run(2)
        liv:Logout()
        ola:Login(); kari:Login()
        w:Run(20)
        ola:Slash("claim")
        w:Run(2)
        liv:Login()
        w:Run(35) -- past Liv's daily visit (30 s after login), whose BOND is in flight at 30
        eq(ola.ns.Registry:Holder(RABBIT), "Liv Lund")
        eq(kari.ns.Registry:Holder(RABBIT), "Liv Lund")
        eq(liv.ns.Registry:Holder(PANDA), "Ola Nord")
        ok(w:Sent("SYNC") >= 2, "both directions")
        H.assertConverged(w)
    end)

    test("two claims in the same second: the lower name wins, the other is told", function()
        local w, ola, kari, per = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 5159 } }, { "Per Hansen", { 46 } } })
        ola:Slash("claim")
        kari:Slash("claim") -- before either hears the other
        w:Run(3)
        for _, c in ipairs({ ola, kari, per }) do eq(c.ns.Registry:Holder(PANDA), "Kari Berg", c.name) end
        ok(ola:Printed("Kari Berg rakk å adoptere Panda Cub rett før deg, så det bor der nå."))
        eq(ola.ns.Registry:MyRecord().k, nil)
        no(kari:Printed("rett før deg"))
        H.assertConverged(w)
    end)

    test("two claims a second apart: the earlier one wins", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 5159 } } })
        kari:Slash("claim")
        w:Skip(1)
        ola:Slash("claim") -- Kari's UPD is still on its way
        w:Run(3)
        eq(ola.ns.Registry:Holder(PANDA), "Kari Berg")
        ok(ola:Printed("rett før deg"))
        H.assertConverged(w)
    end)

    test("claims made apart (offline) resolve to the earliest when they meet", function()
        local w, ola, kari, per = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 5159 }, offline = true },
            { "Per Hansen", { 46 }, offline = true } })
        ola:Slash("claim")
        w:Run(2)
        ola:Logout()
        w:SkipDays(1)
        kari:Login()
        w:Run(20)
        kari:Slash("claim") -- she doesn't know about Ola's
        w:Run(2)
        eq(kari.ns.Registry:MyPet(), PANDA)
        ola:Login()
        per:Login()
        w:Run(40)
        for _, c in ipairs({ ola, kari, per }) do eq(c.ns.Registry:Holder(PANDA), "Ola Nord", c.name) end
        ok(kari:Printed("Ola Nord rakk å adoptere Panda Cub rett før deg"))
        H.assertConverged(w)
    end)

    test("a lost update heals at the next login", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        w.drop = function(m, r) return r.name == "Kari Berg" end
        ola:Slash("claim")
        w:Run(2)
        eq(kari.ns.Registry:Holder(PANDA), nil, "stale for now")
        w.drop = nil
        kari:Reload()
        w:Run(25)
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        H.assertConverged(w)
    end)

    test("a nickname reaches everyone and stays with the pet when its carer moves on", function()
        local w, ola, kari, per = Guild({ { "Ola Nord", { 5159, 46 } }, { "Kari Berg", { 5159 } },
            { "Per Hansen", { 40 }, offline = true } })
        ola:Slash("claim panda")
        w:SkipDays(7)
        w:Befriend()
        local m = w:Mark()
        ola:Slash("nick Mr Bambus")
        w:Run(1)
        eq(w:Sent("NICK", "Ola Nord", m), 1)
        eq(kari.ns.Registry:Nickname(PANDA), "Mr Bambus")
        ola:Slash("claim kitten")
        w:Run(1)
        eq(kari.ns.Registry:Holder(PANDA), nil)
        eq(kari.ns.Registry:Nickname(PANDA), "Mr Bambus", "free, still named")
        eq(kari.ns.Registry:Nickname(KITTEN), nil)
        ok(kari.ns.Registry:Claim(PANDA))
        w:SkipDays(7)
        w:Befriend()
        kari:Slash("nick Bambi")
        w:Run(1)
        eq(ola.ns.Registry:Nickname(PANDA), "Bambi")
        -- Per was away the whole time and catches up at login.
        per:Login()
        w:Run(30)
        eq(per.ns.Registry:Nickname(PANDA), "Bambi")
        H.assertConverged(w)
    end)

    test("NICK only writes the sender's own entry; junk is ignored", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        ola:Slash("claim")
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("nick Bambus")
        w:Run(1)
        local now = w:ServerTime()
        -- Kari tries to rename Ola's panda: her entry is stored, but she isn't the holder.
        local function Nick(m) m.k, m.p = "NICK", ola.ns.PROTOCOL; w:InjectMessage("Kari Berg", m) end
        Nick({ pet = PANDA, e = { n = "Kapret", at = now + 5 } })
        Nick({ e = { n = "Ingen", at = now } })
        Nick({ pet = PANDA, e = "tekst" })
        Nick({ pet = { 1 }, e = { n = "Tabell", at = now } })
        w:Run(1)
        eq(ola.ns.Registry:Nickname(PANDA), "Bambus")
        eq(ola.env.DyreparkenDB.guilds.Dyreparken.names[PANDA]["Kari Berg"].n, "Kapret", "stored as Kari's")
    end)

    test("leaving the guild frees the pet; coming back doesn't take it back", function()
        local w, ola, kari, per = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } }, { "Per Hansen", { 46 } } })
        kari:Slash("claim")
        w:Run(1)
        w:RemoveMember("Kari Berg")
        ola.ns.Guild:Refresh(true)
        w:Run(2)
        eq(w:Sent("LAPSE", "Ola Nord"), 1)
        eq(per.ns.Registry:Holder(KITTEN), nil, "Per heard the LAPSE")
        ok(per.ns.Registry:Claim(KITTEN))
        w:Run(1)
        -- Kari rejoins with her old record still saved.
        w:AddMember("Kari Berg")
        kari.guild = w.guildName
        kari:Reload()
        w:Run(30)
        ok(kari:Printed("White Kitten gikk tilbake til parken mens du var lenge borte."))
        for _, c in ipairs({ ola, kari, per }) do eq(c.ns.Registry:Holder(KITTEN), "Per Hansen", c.name) end
        H.assertConverged(w)
    end)

    test("30 days away frees the pet for the others", function()
        local w, liv, ola, kari = Guild({ { "Liv Lund", { 72 } }, { "Ola Nord", { 5159 } }, { "Kari Berg", { 72 } } })
        liv:Slash("claim")
        w:Run(1)
        liv:Logout()
        w:SkipDays(29)
        ola:Reload()
        w:Run(20)
        eq(kari.ns.Registry:Holder(RABBIT), "Liv Lund", "29 days: still hers")
        w:SkipDays(2)
        ola:Reload()
        w:Run(20)
        eq(kari.ns.Registry:Holder(RABBIT), nil)
        ok(kari.ns.Registry:Claim(RABBIT))
        w:Run(1)
        liv:Login()
        w:Run(30)
        ok(liv:Printed("gikk tilbake til parken mens du var lenge borte"))
        eq(liv.ns.Registry:Holder(RABBIT), "Kari Berg")
        H.assertConverged(w)
    end)

    test("a big registry syncs in several chunks", function()
        local w, ola, liv = Guild({ { "Ola Nord", { 5159 } }, { "Liv Lund", { 72 }, offline = true } })
        local R = ola.ns.Registry
        for i = 1, 150 do
            local owner = ("Medlem%03d Etternavn"):format(i)
            R:MergeRecord(owner, { k = "s:" .. (1000 + i), at = 100 + i, ts = 200 + i })
            if i % 3 == 0 then R:MergeName("s:" .. (1000 + i), owner, { n = "Kallenavn " .. i, at = 300 + i }) end
        end
        R:MergeLapse("Gammel Kar", 50)
        R:Changed()
        liv:Login()
        w:Run(40)
        local held = 0
        for _ in pairs(liv.ns.Registry:Holders()) do held = held + 1 end
        eq(held, 150)
        eq(liv.ns.Registry:Count(), 0, "made-up species don't count toward x of y")
        eq(liv.ns.Registry:Nickname("s:1150"), "Kallenavn 150")
        local bytes = 0
        for _, m in ipairs(w.wire) do if m.kind == "SYNC" then bytes = math.max(bytes, m.bytes) end end
        ok(bytes > 254 * 3, "SYNC took " .. bytes .. " bytes")
        H.assertConverged(w)
    end)

    test("a registry too big for the server's burst still reaches a newcomer", function()
        local w, ola, liv = Guild({ { "Ola Nord", { 5159 } }, { "Liv Lund", { 72 }, offline = true } })
        local R = ola.ns.Registry
        for i = 1, 200 do
            local owner = ("Medlem%03d Etternavn"):format(i)
            R:MergeRecord(owner, { k = "s:" .. (1000 + i), at = 100 + i, ts = 200 + i })
            R:MergeName("s:" .. (1000 + i), owner, { n = "Navn " .. i, at = 300 + i })
        end
        R:Changed()
        w.throttled = 0
        liv:Login()
        w:Run(90)
        eq(w.throttled, 0, "nothing hit the server throttle")
        local held = 0
        for _ in pairs(liv.ns.Registry:Holders()) do held = held + 1 end
        eq(held, 200)
        eq(liv.ns.Registry:Count(), 0, "made-up species don't count toward x of y")
        H.assertConverged(w)
    end)

    test("two big messages sent back to back don't mix their chunks", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        -- Names that don't compress, so each message takes many chunks.
        local function Name(i) return ("%08x Medlem"):format((i * 2654435761) % 4294967296) end
        local big = {}
        for i = 1, 150 do big[Name(i)] = 1000 + i * 7919 end
        local recs = {}
        for i = 1, 60 do recs[Name(5000 + i)] = { k = "s:" .. (2000 + i), at = 10 + i * 31, ts = 20 + i * 37 } end
        local before = w.chunks or 0
        ola.ns.Comm:Send("LAPSE", { l = big }, "GUILD", nil, "BULK")
        ola.ns.Comm:Send("SYNC", { r = recs, l = {}, n = {}, a = {}, d = 0 }, "GUILD", nil, "NORMAL")
        w:Run(60)
        ok(w.chunks - before > 12, "took " .. (w.chunks - before) .. " chunks")
        local _, lapses = kari.ns.Registry:All()
        eq(lapses[Name(150)], 1000 + 150 * 7919, "the LAPSE arrived")
        eq(kari.ns.Registry:Holder("s:2060"), Name(5060), "the SYNC arrived")
    end)

    test("registry messages count only on the guild channel", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        w:SetGroup({ "Ola Nord", "Kari Berg", "Per Hansen" })
        local p, now = ola.ns.PROTOCOL, w:ServerTime()
        local rec = { k = KITTEN, at = now, ts = now }
        for _, chan in ipairs({ "PARTY", "RAID", "WHISPER" }) do
            w:InjectMessage("Per Hansen", { k = "UPD", p = p, r = rec }, chan, "Ola Nord")
            w:InjectMessage("Per Hansen", { k = "SYNC", p = p, r = { ["Per Hansen"] = rec }, d = 1 }, chan, "Ola Nord")
            w:InjectMessage("Per Hansen", { k = "LAPSE", p = p, l = { ["Kari Berg"] = now } }, chan, "Ola Nord")
            w:InjectMessage("Per Hansen", { k = "NICK", p = p, pet = KITTEN, e = { n = "X", at = now } }, chan, "Ola Nord")
            w:InjectMessage("Per Hansen", { k = "HELLO", p = p, v = "dev", d = 12345 }, chan, "Ola Nord")
        end
        local m = w:Mark()
        w:Run(20)
        eq(ola.ns.Registry:Holder(KITTEN), nil)
        eq(next((select(2, ola.ns.Registry:All()))), nil, "no lapses")
        eq(ola.ns.Registry:Nickname(KITTEN), nil)
        eq(w:Sent("SYNC", nil, m), 0, "a HELLO off the guild channel starts no SYNC")
    end)

    test("a mismatch that never settles costs one SYNC per 30 s, not a storm", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        -- Kari refuses a record Ola keeps, so their digests never agree.
        local R = kari.ns.Registry
        local merge = R.MergeRecord
        R.MergeRecord = function(self, owner, r)
            if owner == "Rar Kar" then return false end
            return merge(self, owner, r)
        end
        local now = w:ServerTime()
        ola.ns.Registry:MergeRecord("Rar Kar", { k = KITTEN, at = now, ts = now })
        local m = w:Mark()
        kari:Reload()
        R = kari.ns.Registry
        merge = R.MergeRecord
        R.MergeRecord = function(self, owner, r)
            if owner == "Rar Kar" then return false end
            return merge(self, owner, r)
        end
        w:Run(300)
        local n = w:Sent("SYNC", nil, m)
        ok(n >= 2 and n <= 2 * (300 / 30) + 2, n .. " SYNCs in 300 s")
    end)

    test("no chatter once everyone agrees", function()
        local w, ola, kari, per = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } }, { "Per Hansen", { 40 } } })
        ola:Slash("claim"); kari:Slash("claim")
        w:Run(2)
        local m = w:Mark()
        per:Reload()
        w:Run(25)
        eq(w:Sent("SYNC", nil, m), 0)
        eq(w:Sent("HELLO", nil, m), 1)
    end)

    test("a SYNC answer is cancelled when someone else's already matches", function()
        local w, ola, kari, liv = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } },
            { "Liv Lund", { 72 }, offline = true } })
        ola:Slash("claim")
        w:Run(2)
        liv:Login()
        w:Run(30)
        eq(#ola:Log("%-> SYNC") + #kari:Log("%-> SYNC"), 1)
    end)

    test("updates only ever touch the sender's own record", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        ola:Slash("claim")
        w:Run(1)
        local p = kari.ns.PROTOCOL
        local mine = ola.ns.Registry:MyRecord()
        -- Mallory says Ola released (UPD carries no owner: it lands on Mallory).
        w:InjectMessage("Mallory Mal", { k = "UPD", p = p, r = { at = mine.at, ts = mine.ts + 100 } })
        -- A relayed old copy of Ola's record changes nothing.
        w:InjectMessage("Mallory Mal", { k = "SYNC", p = p, d = 1,
            r = { ["Ola Nord"] = { at = mine.at, ts = mine.ts - 1 } }, l = {} })
        -- Garbage in every field.
        w:InjectMessage("Mallory Mal", { k = "SYNC", p = p, r = "nope", l = { ["X Y"] = "soon" }, d = {} })
        w:InjectMessage("Mallory Mal", { k = "SYNC", p = p, r = { [5] = { k = PANDA, at = 1, ts = 1 } } })
        w:InjectMessage("Mallory Mal", { k = "UPD", p = p, r = { k = 5, at = "x" } })
        w:InjectMessage("Mallory Mal", { k = "UPD", p = p })
        w:InjectMessage("Mallory Mal", { k = "LAPSE", p = p, l = "nope" })
        w:InjectMessage("Mallory Mal", { k = "LAPSE", p = p })
        w:InjectMessage("Mallory Mal", { k = "HELLO", p = p })
        w:Run(15)
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        eq(ola.ns.Registry:Holder(PANDA), "Ola Nord")
        H.assertConverged(w)
    end)

    test("another protocol's SYNC, UPD and LAPSE are ignored", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        w:InjectMessage("Ny Versjon", { k = "SYNC", p = 99, d = 1, r = { ["Ny Versjon"] = { k = PANDA, at = 1, ts = 1 } } })
        w:InjectMessage("Ny Versjon", { k = "UPD", p = 99, r = { k = PANDA, at = 1, ts = 1 } })
        w:InjectMessage("Ny Versjon", { k = "LAPSE", p = 99, l = { ["Ola Nord"] = 1e10 } })
        w:Run(12)
        eq(ola.ns.Registry:Holder(PANDA), nil)
        ok(ola.ns.Registry:Claim(PANDA))
        -- Handlers check the protocol themselves too, for HELLO (always dispatched).
        local m = w:Mark()
        w:InjectMessage("Ny Versjon", { k = "HELLO", p = 99, v = "v9.0.0", d = 12345 })
        w:Run(12)
        eq(w:Sent("SYNC", nil, m), 0)
    end)

    test("an alt in another guild keeps a separate registry", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord")
        local alt = w:AddClient("Ola Alt", { guild = "Annet Laug" })
        w:Run(20)
        ola:Slash("claim")
        alt:Slash("claim")
        w:Run(2)
        eq(ola.ns.Registry:Holder(PANDA), "Ola Nord")
        eq(alt.ns.Registry:Holder(PANDA), "Ola Alt")
    end)

    ------------------------------------------------------------------------------
    -- Randomized: many clients, contested pets, lost messages, logins and
    -- logouts, days passing. Afterwards one login round must bring everyone
    -- to the same registry, and no one may keep a claim they lost.
    ------------------------------------------------------------------------------
    local NAMES = { "Anne Aas", "Bjorn Berg", "Cato Dahl", "Dina Eik", "Eirik Fjell", "Frida Gran" }
    local POOL = { 5159, 46, 40, 41 }

    local function Fuzz(seed, steps)
        math.randomseed(seed)
        local w = H.World()
        local clients = {}
        for i, name in ipairs(NAMES) do
            local pets = {}
            for _, sid in ipairs(POOL) do if math.random() < 0.6 then pets[#pets + 1] = sid end end
            if #pets == 0 then pets[1] = POOL[i % #POOL + 1] end
            clients[i] = w:AddClient(name, { pets = pets, summoned = false, login = math.random() < 0.7 })
        end
        w:Run(15)
        local history = {}
        for step = 1, steps do
            local c = clients[math.random(#clients)]
            local roll = math.random()
            local lossy = math.random() < 0.25
            w.drop = lossy and function() return math.random() < 0.3 end or nil
            if not c.online then
                if roll < 0.5 then c:Login(); history[#history + 1] = c.name .. " login" end
            elseif roll < 0.45 then
                local sid = c.pets[math.random(#c.pets)].sid
                c.ns.Registry:Claim("s:" .. sid)
                history[#history + 1] = c.name .. " claim " .. sid
            elseif roll < 0.55 then
                c.ns.Registry:Release()
                history[#history + 1] = c.name .. " release"
            elseif roll < 0.62 then
                c.ns.Registry:SetNickname("Nick" .. step)
            elseif roll < 0.75 then
                c:Logout()
                history[#history + 1] = c.name .. " logout"
            elseif roll < 0.8 then
                c:Reload()
            end
            if math.random() < 0.05 then w:SkipDays(math.random(1, 3)) end
            w:Run(math.random(1, 30) / 10)
        end
        -- Heal: no more losses; everyone comes online; one login round.
        w.drop = nil
        w:Run(30)
        for _, c in ipairs(clients) do if not c.online then c:Login() end end
        w:Run(60)
        local okc, why = H.converged(w)
        if not okc then
            error(("seed %d did not converge: %s\n    history: %s"):format(seed, why,
                table.concat(history, ", ", math.max(1, #history - 30))))
        end
        for _, c in ipairs(clients) do
            local r = c.ns.Registry:MyRecord()
            if r and r.k then
                eq(c.ns.Registry:Holder(r.k), c.name, ("seed %d: %s kept a lost claim"):format(seed, c.name))
            end
        end
        return w
    end

    for _, seed in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8 }) do
        test("random guild life converges (seed " .. seed .. ")", function() Fuzz(seed, 120) end)
    end
end
