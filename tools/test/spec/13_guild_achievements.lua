-- Guild achievements: worked out by every client from the shared registry,
-- synced, one broadcast for the whole guild, shared by officers only.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- Same small list as 12_achievements: 4 cats, 15 counting pets.
    local function Fixture()
        local species = {
            [40] = { a = true, t = { "cat" } }, [41] = { a = true, t = { "cat" } },
            [42] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat" } },
            [7] = { a = true, t = { "farm" } }, [84] = { a = true, t = { "farm" } },
            [68] = { a = true }, [72] = { a = true }, [90] = { a = true },
            [5159] = { a = false },
        }
        for sid = 2001, 2006 do species[sid] = { a = true } end
        return { build = 1, species = species }
    end
    local function Fix(c) c.ns.Companions = Fixture(); return c end

    -- name -> the cat they own; Ola is an officer, Per the guild master.
    local MEMBERS = {
        { "Ola Nord", 40, 1 }, { "Kari Berg", 41, 3 }, { "Per Hansen", 42, 0 }, { "Liv Lund", 46, 3 },
    }

    local function World(skip)
        local w, cs = H.World(), {}
        for i, m in ipairs(MEMBERS) do
            if not (skip and skip[m[1]]) then
                cs[m[1]] = Fix(w:AddClient(m[1], { pets = { m[2] }, rank = m[3] }))
            end
        end
        w:Run(12)
        return w, cs
    end

    local function AdoptAll(w, cs)
        for _, m in ipairs(MEMBERS) do
            local c = cs[m[1]]
            if c then c:Slash("adopt") end
        end
        w:Run(20) -- the 5 s debounce, then the 2-8 s broadcast
    end

    local LINE = "Dyreparken: Dyreparken fikk [Kattehuset]!"

    test("every cat cared for: everyone prints one line, about one broadcast", function()
        local w, cs = World()
        local m = w:Mark()
        AdoptAll(w, cs)
        local sent = w:Sent("ACH", nil, m)
        ok(sent >= 1 and sent <= 2, "one client says it for the guild, got " .. sent)
        for name, c in pairs(cs) do
            local n = 0
            for _, line in ipairs(c.printed) do if line == LINE then n = n + 1 end end
            eq(n, 1, name .. " prints it once")
            ok(c.ns.Achievements:Got("guild:family:cat"), name)
        end
        ok(cs["Ola Nord"]:Printed("Som offiser kan du dele", true), "officers get the hint")
        no(cs["Kari Berg"]:Printed("Som offiser", true))
        H.assertConverged(w)
        local at = cs["Ola Nord"].ns.Achievements:Got("guild:family:cat").at
        for _, c in pairs(cs) do eq(c.ns.Achievements:Got("guild:family:cat").at, at, "earliest wins") end
        eq(#w.chat, 0, "nothing posted by itself")
        -- Letting a cat go later doesn't take it back.
        cs["Liv Lund"]:Slash("letgo")
        w:Run(10)
        ok(cs["Ola Nord"].ns.Achievements:Got("guild:family:cat"))
    end)

    test("only officers and the guild master share it, once for the whole guild", function()
        local w, cs = World()
        AdoptAll(w, cs)
        local kari, ola, per = cs["Kari Berg"], cs["Ola Nord"], cs["Per Hansen"]
        kari:Slash("ach share")
        eq(#w.chat, 0)
        ok(kari:Printed("Ingen nye prestasjoner å dele."))
        kari:Slash("ach")
        match(kari:Printed("[Kattehuset] ", true), "%d%d%d%d$", "no star for members")
        ola:Slash("ach")
        match(ola:Printed("[Kattehuset] ", true), " %*$", "a star for officers")
        ola:Slash("ach share")
        eq(#w.chat, 1)
        eq(w.chat[1].text, "Hver eneste katt har fått sitt eget hjem i Dyreparken! [Kattehuset]")
        w:Run(1)
        per:Slash("ach share")
        eq(#w.chat, 1, "the guild master's client knows it's shared")
        ok(per:Printed("Ingen nye prestasjoner å dele."))
        H.assertConverged(w)
    end)

    test("a member who was away hears about it once, at the next sync", function()
        local w, cs = World({ ["Siv Dahl"] = true })
        AdoptAll(w, cs)
        local siv = w:AddClient("Siv Dahl", { pets = { 5159 }, login = false })
        siv:Login(); Fix(siv)
        w:Run(30)
        H.assertConverged(w)
        ok(siv.ns.Achievements:Got("guild:family:cat"))
        local n = 0
        for _, line in ipairs(siv.printed) do if line == LINE then n = n + 1 end end
        eq(n, 1, "once")
        siv:Reload(); Fix(siv)
        siv:ClearPrinted()
        w:Run(30)
        no(siv:Printed(LINE, true), "not again after a reload")
    end)

    test("a first look that finds it met is quiet, but officers can still share it", function()
        local w, cs = World()
        -- Everyone adopts before anyone's client has checked the guild ones.
        local olaG = cs["Ola Nord"].ns.DB:Guild()
        for _, c in pairs(cs) do
            local g = c.ns.DB:Guild()
            g.achSeen = {}
        end
        AdoptAll(w, cs)
        for name, c in pairs(cs) do no(c:Printed(LINE, true), name .. " stays quiet") end
        local rec = cs["Kari Berg"].ns.Achievements:Got("guild:family:cat")
        eq(rec.q, true)
        cs["Ola Nord"]:Slash("ach share")
        eq(#w.chat, 1)
        ok(olaG.ach["guild:family:cat"].ann)
    end)

    test("lost messages and partitions still converge", function()
        local w, cs = World()
        w.drop = function(m) return m.prefix and math.random() < 0.5 end
        math.randomseed(7)
        AdoptAll(w, cs)
        w.drop = nil
        -- A login sends HELLO; digests differ where messages were lost.
        cs["Kari Berg"]:Reload(); Fix(cs["Kari Berg"])
        w:Run(60)
        H.assertConverged(w)
        for name, c in pairs(cs) do ok(c.ns.Achievements:Got("guild:family:cat"), name) end
    end)

    test("records from peers are checked; ids from newer versions are kept, not shown", function()
        local w, cs = World()
        local kari = cs["Kari Berg"]
        local p = kari.ns.PROTOCOL
        local A = kari.ns.Achievements
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = {
            ["guild:family:cat"] = { at = "soon" },
            ["family:cat"] = { at = 5 },            -- not a guild id
            ["guild:x"] = { at = 5, ann = -1 },
            ["guild:y"] = { at = 5, q = "yes" },
            ["guild:" .. ("z"):rep(70)] = { at = 5 },
            ["guild:bad id"] = { at = 5 },
        } })
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = "nope" })
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = { ["guild:future:thing"] = { at = 5 } } }, "PARTY")
        w:InjectMessage("Per Hansen", { k = "ACH", p = 99, a = { ["guild:future:thing"] = { at = 5 } } })
        w:Run(1)
        eq(next(kari.ns.DB:Guild().ach), nil, "all rejected")
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = { ["guild:future:thing"] = { at = 5, ann = 6 } } })
        w:Run(1)
        ok(kari.ns.DB:Guild().ach["guild:future:thing"], "kept for the sync")
        no(kari:Printed("future", true), "not shown")
        -- Earlier dates and shares win; later ones don't.
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = { ["guild:future:thing"] = { at = 9, ann = 9 } } })
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = { ["guild:future:thing"] = { at = 3, ann = 4 } } })
        w:Run(1)
        local rec = kari.ns.DB:Guild().ach["guild:future:thing"]
        eq(rec.at, 3); eq(rec.ann, 4)
        -- Too many records in one message: only the first 64 are read.
        local many = {}
        for i = 1, 100 do many["guild:n" .. i] = { at = 5 } end
        w:InjectMessage("Per Hansen", { k = "ACH", p = p, a = many })
        w:Run(1)
        local n = 0
        for id in pairs(kari.ns.DB:Guild().ach) do if id:find("^guild:n") then n = n + 1 end end
        eq(n, 64)
        eq(A:MergeGuild(nil), false)
    end)

    test("guild tiers above what exists are hidden; no guild, no guild achievements", function()
        local w, cs = World()
        local ola = cs["Ola Nord"]
        ola:Slash("ach")
        ok(ola:Printed("[Dyreparken åpner] 0/10", true))
        no(ola:Printed("[Full drift]", true), "25 > 15 counting pets")
        ok(ola:Printed("[Hele parken] 0/15", true))
        local lone = Fix(w:AddClient("Ensom Ulv", { guild = false, pets = { 40 } }))
        w:Run(12)
        eq(lone.ns.Achievements:Got("guild:family:cat"), nil)
        eq(next(lone.ns.Achievements:GuildRecords()), nil)
        lone.ns.Achievements:Check("test", "guild")
    end)
end
