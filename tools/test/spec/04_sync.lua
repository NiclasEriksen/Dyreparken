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
        eq(select(2, kari.ns.Registry:Claim(PANDA)), "Ola Nord has already reserved it.")
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
        w:Run(30)
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
        ok(ola:Printed("Kari Berg reserved Panda Cub before you did, so your claim was withdrawn."))
        eq(ola.ns.Registry:MyRecord().k, nil)
        no(kari:Printed("before you did"))
        H.assertConverged(w)
    end)

    test("two claims a second apart: the earlier one wins", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 5159 } } })
        kari:Slash("claim")
        w:Skip(1)
        ola:Slash("claim") -- Kari's UPD is still on its way
        w:Run(3)
        eq(ola.ns.Registry:Holder(PANDA), "Kari Berg")
        ok(ola:Printed("before you did"))
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
        ok(kari:Printed("Ola Nord reserved Panda Cub before you did"))
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

    test("nicknames travel with the record and vanish when switching", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159, 46 } }, { "Kari Berg", { 40 } } })
        ola:Slash("claim panda")
        w:SkipDays(7)
        ola:Slash("nick Mr Bambus")
        w:Run(1)
        eq(select(2, kari.ns.Registry:Holder(PANDA)).n, "Mr Bambus")
        ola:Slash("claim kitten")
        w:Run(1)
        eq(select(2, kari.ns.Registry:Holder(KITTEN)).n, nil)
        eq(kari.ns.Registry:Holder(PANDA), nil)
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
        ok(kari:Printed("Your reservation of White Kitten lapsed after a long absence."))
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
        ok(liv:Printed("lapsed after a long absence"))
        eq(liv.ns.Registry:Holder(RABBIT), "Kari Berg")
        H.assertConverged(w)
    end)

    test("a big registry syncs in several chunks", function()
        local w, ola, liv = Guild({ { "Ola Nord", { 5159 } }, { "Liv Lund", { 72 }, offline = true } })
        local R = ola.ns.Registry
        for i = 1, 150 do
            R:MergeRecord(("Medlem%03d Etternavn"):format(i), { k = "s:" .. (1000 + i), at = 100 + i, ts = 200 + i,
                n = i % 3 == 0 and ("Kallenavn " .. i) or nil, na = i % 3 == 0 and 300 or nil })
        end
        R:MergeLapse("Gammel Kar", 50)
        R:Changed()
        liv:Login()
        w:Run(40)
        eq(liv.ns.Registry:Count(), 150)
        eq(select(2, liv.ns.Registry:Holder("s:1150")).n, "Kallenavn 150")
        local bytes = 0
        for _, m in ipairs(w.wire) do if m.kind == "SYNC" then bytes = math.max(bytes, m.bytes) end end
        ok(bytes > 254 * 3, "SYNC took " .. bytes .. " bytes")
        H.assertConverged(w)
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
