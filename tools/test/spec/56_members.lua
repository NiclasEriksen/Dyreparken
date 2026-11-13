-- X-Protocol 10 (2026-11-13, for 0.6.0): the sync keeps only guild members' data (Q4, B11), lapses
-- have a cap of their own, a bond's room a day holds the wish, wire times are whole seconds, and a
-- claim's or a name's digest line carries what it holds. Registry.lua's header has the rules.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local KITTEN, BOMBAY = "s:46", "s:40"

    -- Entries by authors other than `except`, per store (claims, names, bonds).
    local function Stored(c, except)
        local g = c.ns.DB:Guild()
        local n = { claims = 0, names = 0, life = 0 }
        for owner in pairs(g.claims) do if owner ~= except then n.claims = n.claims + 1 end end
        for _, store in ipairs({ "names", "life" }) do
            for _, byKey in pairs(g[store]) do
                for author in pairs(byKey) do if author ~= except then n[store] = n[store] + 1 end end
            end
        end
        return n
    end
    local function Count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

    test("a relay's flood under made-up names grows nobody's saved data, and honest syncs go on (B11)", function()
        local w = H.World()
        -- The relay: a guild member (only members can send on the guild channel) with a doctored client.
        w:AddMember("Per Hansen", 0)
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46 } })
        local function Small(c)
            c.ns.Config.SYNC_MAX_ENTRIES = 60
            c.ns.Wire.LIMITS.LAPSES_MAX = 40
        end
        Small(ola); Small(kari)
        w:Settle("day")
        kari:Slash("adopter")
        w:Run(2)
        local before = { H.Show(Stored(ola)), H.Show(Stored(kari)) }
        local p, now = ola.ns.PROTOCOL, w:ServerTime()
        -- Six SYNCs, each part under the cap (50 of 60): claims, names, bonds and lapses under made-up
        -- names, dated now (after the roster read: they could be newcomers).
        for m = 1, 6 do
            local r, n, b, l = {}, {}, {}, {}
            for i = 1, 50 do
                local who, key = ("Fake%d Navn%02d"):format(m, i), "s:" .. (3000 + i)
                r[who] = { k = key, at = now - i, ts = now }
                n[key] = { [who] = { n = "Junk", at = now } }
                b[key] = { [who] = { p = 10, f = now - 60, t = now } }
                l[who] = now - m * 100 - i
            end
            w:InjectMessage("Per Hansen", { k = "SYNC", p = p, i = 1, of = 3, r = r, l = l, a = {} })
            w:InjectMessage("Per Hansen", { k = "SYNC", p = p, i = 2, of = 3, n = n })
            w:InjectMessage("Per Hansen", { k = "SYNC", p = p, i = 3, of = 3, b = b, d = 1 })
            w:Run(2)
        end
        eq(H.Show(Stored(ola)), before[1], "Ola stored none of it")
        eq(H.Show(Stored(kari)), before[2], "nor Kari")
        ok(ola.ns.Registry:Held() <= ola.ns.Config.HELD_MAX, "what waits for a roster is bounded")
        -- Lapses are kept for people who left (the header), so they're capped instead: the same ones
        -- on both clients.
        local lo, lk = select(2, ola.ns.Registry:All()), select(2, kari.ns.Registry:All())
        eq(Count(lo), 40); eq(H.Show(lo), H.Show(lk))
        -- The next roster drops what waited: nobody it lists.
        w:Run(ola.ns.Config.ROSTER_INTERVAL + 20)
        eq(ola.ns.Registry:Held(), 0); eq(kari.ns.Registry:Held(), 0)
        eq(H.Show(Stored(ola)), before[1])
        -- Honest syncs go on: a newcomer gets everything, and nobody refuses a SYNC.
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        Small(nina)
        w:Run(60)
        eq(nina.ns.Registry:Holder(KITTEN), "Kari Berg")
        for _, c in ipairs({ ola, kari, nina }) do eq(#c:Log("refused a SYNC"), 0, c.name) end
        H.assertConverged(w)
    end)

    test("a LAPSE with more entries than a SYNC part may carry is refused whole", function()
        local w, ola = H.Setup{ ola = { 5159 }, world = { members = { "Per Hansen" } } }
        ola.ns.Config.SYNC_MAX_ENTRIES = 20
        local l, now = {}, w:ServerTime()
        for i = 1, 21 do l[("Fake Navn%02d"):format(i)] = now end
        w:InjectMessage("Per Hansen", { k = "LAPSE", p = ola.ns.PROTOCOL, l = l })
        w:Run(2)
        eq(next((select(2, ola.ns.Registry:All()))), nil)
        eq(#ola:Log("refused a LAPSE from Per Hansen: too many entries"), 1)
    end)

    test("the lapses' cap keeps the same ones on every client, whatever order they come in", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 46 } }
        ola.ns.Wire.LIMITS.LAPSES_MAX, kari.ns.Wire.LIMITS.LAPSES_MAX = 3, 3
        local now = w:ServerTime()
        local list = {}
        for i = 1, 8 do list[i] = { ("Borte%d Navn"):format(i), now - (i % 4) * 60 } end -- (ties on purpose)
        for i = 1, 8 do ola.ns.Registry:MergeLapse(list[i][1], list[i][2]) end
        for i = 8, 1, -1 do kari.ns.Registry:MergeLapse(list[i][1], list[i][2]) end
        local function Names(c)
            local out = {}
            for owner in pairs(select(2, c.ns.Registry:All())) do out[#out + 1] = owner end
            table.sort(out)
            return table.concat(out, ", ")
        end
        eq(Names(ola), Names(kari))
        eq(Names(ola), "Borte1 Navn, Borte4 Navn, Borte8 Navn", "the newest two, then the lower name of a tie")
        no(ola.ns.Registry:MergeLapse("Borte9 Navn", now - 600), "older than every one kept: refused")
    end)

    test("a roster read before someone joined doesn't lose their data; one who left is dropped", function()
        local w = H.World()
        w:AddMember("Per Hansen", 0) -- a member who relays (the server only passes guild messages from members)
        w:AddMember("Siv Dahl", 0)
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        w:Settle("day") -- Ola's roster: Ola, Per and Siv
        local R, g, p, now = ola.ns.Registry, ola.ns.DB:Guild(), ola.ns.PROTOCOL, w:ServerTime()
        R:MergeName(BOMBAY, "Siv Dahl", { n = "Gammel", at = now - 60 }) -- (from when she was here)
        -- Tor joins (and adopts, then logs off); Siv leaves. Per relays Tor's adoption.
        w:AddMember("Tor Eng", 0)
        w:RemoveMember("Siv Dahl")
        w:InjectMessage("Per Hansen", { k = "SYNC", p = p, i = 1, of = 1, d = 1, l = {}, a = {},
            r = { ["Tor Eng"] = { k = "s:72", at = now, ts = now } },
            n = { ["s:72"] = { ["Tor Eng"] = { n = "Hoppe", at = now } } },
            b = { ["s:72"] = { ["Tor Eng"] = { p = 10, f = now - 60, t = now } } } })
        w:Run(2)
        eq(R:Holder("s:72"), nil, "Tor isn't on Ola's roster yet: his adoption waits for the next")
        eq(R:Held(), 2, "(his name is in: it names the pet, see the inherited names below)")
        -- Liv joins too, and her own client says so: on the guild channel she's a member, roster or not.
        local liv = w:AddClient("Liv Lund", { pets = { 41 } })
        w:Settle("hello")
        liv:Slash("adopter")
        w:Run(2)
        eq(R:Holder("s:41"), "Liv Lund", "her own UPD: let in at once")
        -- The next roster lets Tor's in and drops what Siv wrote; Ola's own stays.
        ola:Slash("adopter")
        w:Run(ola.ns.Config.ROSTER_INTERVAL + 20)
        eq(R:Holder("s:72"), "Tor Eng"); eq(R:Nickname("s:72"), "Hoppe"); eq(R:Life("s:72", "Tor Eng").p, 10)
        eq(R:Held(), 0)
        eq(R:Nickname(BOMBAY), "Gammel", "Siv's name stays with the pet: nobody gave it another")
        eq(R:Holder("s:5159"), "Ola Nord")
        -- Liv logged in before Ola had Tor's adoption, and missed Per's SYNC: like a lost update,
        -- it heals at a login.
        liv:Reload()
        w:Run(60)
        H.assertConverged(w)
    end)

    test("someone who left: their claim, names and bonds go, their lapse stays; coming back doesn't take the pet back", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46, 40 } })
        local per = w:AddClient("Per Hansen", { pets = { 46 } })
        w:Settle("day")
        kari:Slash("adopter kitten")
        w:Run(2)
        w:SkipDays(2)
        w:Befriend()
        ok(kari.ns.Registry:SetNickname("Pus"))
        kari.ns.Bond:Add(20, BOMBAY)
        w:Run(1900) -- (her points go out within 30 minutes)
        ok(ola.ns.Registry:Life(KITTEN, "Kari Berg")); eq(ola.ns.Registry:Nickname(KITTEN), "Pus")
        w:RemoveMember("Kari Berg")
        ola.ns.Guild:Refresh(true)
        w:Run(2)
        local g = ola.ns.DB:Guild()
        eq(g.claims["Kari Berg"], nil, "her claim: lapsed, then pruned")
        ok(g.lapses["Kari Berg"], "her lapse stays")
        eq(ola.ns.Registry:Life(KITTEN, "Kari Berg"), nil); eq(ola.ns.Registry:Life(BOMBAY, "Kari Berg"), nil)
        eq(ola.ns.Registry:Nickname(KITTEN), "Pus", "the name she gave stays with the pet")
        -- Per's roster is older: he keeps hers until his next, which Ola's SYNC brings about.
        ok(per.ns.DB:Guild().lapses["Kari Berg"], "Per heard the LAPSE")
        ok(per.ns.Registry:Claim(KITTEN))
        w:Run(per.ns.Config.ROSTER_INTERVAL + 60)
        -- Kari rejoins with her old record still saved: the lapse voids it.
        w:AddMember("Kari Berg")
        kari.guild = w.guildName
        kari:Reload()
        w:Run(60)
        ok(kari:Printed("White Kitten dro tilbake til parken mens du var lenge borte."))
        for _, c in ipairs({ ola, kari, per }) do eq(c.ns.Registry:Holder(KITTEN), "Per Hansen", c.name) end
        eq(per.ns.Registry:Nickname(KITTEN), "Pus", "Per inherited it")
        H.assertConverged(w)
    end)

    test("a relayed copy with the same time but another pet is corrected (the digest carries the pet)", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 46 }, world = { members = { "Per Hansen" } } }
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

    test("migration 13 drops what peers refuse now: times off a whole second, lapses past the cap", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { login = false })
        local now = w:ServerTime()
        local lapses = {}
        for i = 1, 1005 do lapses[("Borte%04d Navn"):format(i)] = now - i end
        lapses["Siv Dahl"] = now - 3.5
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
        eq(Count(g.lapses), c.ns.Wire.LIMITS.LAPSES_MAX)
        ok(g.lapses["Borte0001 Navn"]); eq(g.lapses["Borte1005 Navn"], nil, "the oldest went")
        eq(g.lapses["Siv Dahl"], nil, "off a whole second")
    end)

    -- Inherited names (2026-11-08: "the name stays when they let go, and the next carer inherits it"),
    -- kept when the namer leaves the guild too (the user, 2026-11-13).
    test("a name stays with the pet when its namer leaves the guild: the next carer and a newcomer have it", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 5159 } })
        local per = w:AddClient("Per Hansen", { pets = { 46 } })
        w:Settle("day")
        local PANDA = "s:5159"
        kari:Slash("adopter panda")
        w:Run(2)
        w:SkipDays(3)
        w:Befriend()
        ok(kari.ns.Registry:SetNickname("Bambus"))
        w:Run(2)
        kari:Slash("gislipp")
        w:Run(2)
        w:RemoveMember("Kari Berg")
        kari:Logout()
        for _, c in ipairs({ ola, per }) do c.ns.Guild:Refresh(true) end
        w:Run(2)
        w:SkipDays(1)
        ola:Slash("adopter panda")
        w:Run(2)
        for _, c in ipairs({ ola, per }) do
            eq(c.ns.DB:Guild().claims["Kari Berg"], nil, c.name .. ": her (released) claim went")
            eq(c.ns.Registry:Nickname(PANDA), "Bambus", c.name)
        end
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:Run(60)
        eq(nina.ns.Registry:Nickname(PANDA), "Bambus", "a newcomer gets it by SYNC")
        H.assertConverged(w)
        -- The story saw no name change.
        for _, e in ipairs(ola.ns.DB:Guild().story[PANDA].e) do
            ok(e.k ~= "unname", "no unname in the story")
        end
        -- Ola renames it once their bond allows: hers names it now, and Kari's goes everywhere.
        w:SkipDays(3)
        w:Befriend()
        ok(ola.ns.Registry:SetNickname("Pepe"))
        w:Run(3)
        for _, c in ipairs({ ola, per, nina }) do
            eq(c.ns.Registry:Nickname(PANDA), "Pepe", c.name)
            eq(c.ns.DB:Guild().names[PANDA]["Kari Berg"], nil, c.name .. ": the old name went")
        end
        H.assertConverged(w)
    end)

    test("names under made-up namers: at most the one naming each journal species is kept, the same on every client", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 46 }, world = { members = { "Per Hansen" } } }
        local PANDA = "s:5159"
        ola:Slash("adopter panda")
        w:Run(2)
        w:SkipDays(3)
        w:Befriend()
        ok(ola.ns.Registry:SetNickname("Pepe"))
        w:Run(2)
        local adopted = ola.ns.Registry:MyRecord().at
        local now = w:ServerTime()
        local KEYS = { "s:40", "s:41", "s:42", "s:43", "s:44", "s:99999", "n:Junk", PANDA }
        local entries = {}
        for _, key in ipairs(KEYS) do
            for i = 1, 5 do
                -- (the panda's: older than Ola's own name, or after her adoption: neither names it)
                local at = key == PANDA and (i % 2 == 0 and adopted - i or now) or now - 100 + (i % 3)
                entries[#entries + 1] = { key, ("Fake%d Navn"):format(i), { n = "Junk" .. i, at = at } }
            end
        end
        for i = 1, #entries do ola.ns.Registry:MergeName(entries[i][1], entries[i][2], entries[i][3]) end
        for i = #entries, 1, -1 do kari.ns.Registry:MergeName(entries[i][1], entries[i][2], entries[i][3]) end
        local function Fakes(c)
            local out = {}
            for key, byKey in pairs(c.ns.DB:Guild().names) do
                for author, e in pairs(byKey) do
                    if author:find("^Fake") then out[#out + 1] = key .. "=" .. author .. ":" .. e.n end
                end
            end
            table.sort(out)
            return table.concat(out, " ")
        end
        -- One per free journal species: the newest (ties: the lower namer); none for the panda Ola
        -- named, none for keys that aren't journal species.
        eq(Fakes(ola), "s:40=Fake2 Navn:Junk2 s:41=Fake2 Navn:Junk2 s:42=Fake2 Navn:Junk2 s:43=Fake2 Navn:Junk2 "
            .. "s:44=Fake2 Navn:Junk2")
        eq(Fakes(kari), Fakes(ola), "the same, whatever order they came in")
        eq(ola.ns.Registry:Nickname(PANDA), "Pepe")
        H.assertConverged(w)
    end)

    ------------------------------------------------------------------------------
    -- Randomized: members join and leave, rosters are read at different times on each client, a
    -- relay forges data under made-up names and under those who left. Afterwards, once every client
    -- has read the roster and one login round has passed, all digests agree, and nobody keeps data
    -- about anyone outside the guild (lapses aside).
    ------------------------------------------------------------------------------
    local NAMES = { "Anne Aas", "Bjorn Berg", "Cato Dahl", "Dina Eik", "Eirik Fjell", "Frida Gran" }
    local POOL = { 5159, 46, 40, 41 }

    local function Fuzz(seed, steps)
        math.randomseed(seed)
        local w = H.World()
        w:AddMember("Rolf Relay", 0) -- a member without the addon whose doctored client relays junk
        local clients = {}
        for i, name in ipairs(NAMES) do
            local pets = {}
            for _, sid in ipairs(POOL) do if math.random() < 0.6 then pets[#pets + 1] = sid end end
            if #pets == 0 then pets[1] = POOL[i % #POOL + 1] end
            clients[i] = w:AddClient(name, { pets = pets, summoned = false, login = math.random() < 0.8 })
        end
        w:Run(15)
        local out, history = {}, {}
        local function Rejoin(c)
            w:AddMember(c.name)
            c.guild = w.guildName
            out[c] = nil
            if c.online then c:Reload() else c:Login() end
        end
        for step = 1, steps do
            local c = clients[math.random(#clients)]
            local roll = math.random()
            w.drop = math.random() < 0.2 and function() return math.random() < 0.3 end or nil
            if out[c] then
                if roll < 0.3 then Rejoin(c); history[#history + 1] = c.name .. " rejoins" end
            elseif not c.online then
                if roll < 0.5 then c:Login(); history[#history + 1] = c.name .. " login" end
            elseif roll < 0.35 then
                c.ns.Registry:Claim("s:" .. c.pets[math.random(#c.pets)].sid)
                history[#history + 1] = c.name .. " claim"
            elseif roll < 0.42 then
                c.ns.Registry:Release()
            elseif roll < 0.5 then
                if c.ns.Registry:MyPet() then c.ns.Bond:Add(math.random(1, 40)) end
            elseif roll < 0.57 then
                c.ns.Guild:Refresh(true) -- (a roster read now and then: the journal opened)
            elseif roll < 0.64 then
                -- The relay: made-up names, and copies of what someone who left wrote.
                local now, who = w:ServerTime(), ("Fake%d Navn"):format(step)
                local gone = NAMES[math.random(#NAMES)]
                w:InjectMessage("Rolf Relay", { k = "SYNC", p = c.ns.PROTOCOL, i = 1, of = 1, d = 1, l = {}, a = {},
                    r = { [who] = { k = "s:" .. POOL[math.random(#POOL)], at = now - 600, ts = now },
                        [gone] = { k = "s:" .. POOL[math.random(#POOL)], at = now - 9000, ts = now - 5 } },
                    n = { ["s:46"] = { [who] = { n = "Junk", at = now } } },
                    b = { ["s:40"] = { [who] = { p = 5, f = now - 60, t = now } } } })
                history[#history + 1] = "relay " .. who
            elseif roll < 0.7 and Count(out) < 2 then
                w:RemoveMember(c.name)
                out[c] = true
                history[#history + 1] = c.name .. " leaves"
            elseif roll < 0.8 then
                c:Logout()
            elseif roll < 0.85 then
                c:Reload()
            end
            if math.random() < 0.04 then w:SkipDays(math.random(1, 2)) end
            w:Run(math.random(1, 30) / 10)
        end
        -- Heal: no more losses; everyone still in the guild online; every client reads the roster,
        -- at slightly different times, twice; then one login round.
        w.drop = nil
        w:Run(30)
        for _, c in ipairs(clients) do if not out[c] and not c.online then c:Login() end end
        w:Run(20)
        for _ = 1, 2 do
            for _, c in ipairs(clients) do
                if c.online and c.guild then
                    c.ns.Guild:Refresh(true)
                    w:Run(math.random(5, 30) / 10)
                end
            end
        end
        for _, c in ipairs(clients) do if c.online and not c.guild then c:Logout() end end
        for _, c in ipairs(clients) do if c.online and c.guild then c:Reload(); break end end
        w:Run(90)
        local okc, why = H.converged(w)
        if not okc then
            error(("seed %d did not converge: %s\n    history: %s"):format(seed, why,
                table.concat(history, ", ", math.max(1, #history - 30))))
        end
        local members = {}
        for _, m in ipairs(w:Roster()) do members[m.name] = true end
        for _, c in ipairs(clients) do
            if c.online then
                local g = c.ns.DB:Guild()
                for owner, r in pairs(g.claims) do
                    ok(members[owner], ("seed %d: %s keeps %s's claim"):format(seed, c.name, owner))
                end
                for _, store in ipairs({ "names", "life" }) do
                    for key, byKey in pairs(g[store]) do
                        -- (a non-member's name only while it names the pet: one per species at most)
                        local naming = store == "names" and c.ns.Registry:Naming(key)
                        for author in pairs(byKey) do
                            ok(members[author] or author == naming,
                                ("seed %d: %s keeps %s's %s"):format(seed, c.name, author, store))
                        end
                    end
                end
                eq(c.ns.Registry:Held(), 0, ("seed %d: %s"):format(seed, c.name))
            end
        end
        return w
    end

    -- (Two seeds of 100 steps: each run costs about five seconds under coverage. Seeds 1-12 passed
    -- at 120 steps and 101-112 at 300 when this was written.)
    for _, seed in ipairs({ 1, 2 }) do
        test("members only: random guild life with comings and goings converges (seed " .. seed .. ")", function()
            Fuzz(seed, 100)
        end)
    end
end
