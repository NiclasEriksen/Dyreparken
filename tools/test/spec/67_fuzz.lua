-- A wire fuzzer (2026-11-19), driven by Comm's own registrations (Comm.registered: kind, from, fields):
-- every kind any module listens to gets a few hundred mutated messages, from a guild member and from
-- someone outside the guild, on GUILD, PARTY and WHISPER. Each message starts from a real one of its kind
-- (the honest traffic of the login, w.wire) or, for a kind nobody sent, from its declared fields, and
-- then has a few things broken: wrong types, missing fields, huge, negative and fractional numbers, NaN,
-- infinities, empty, long and multibyte strings, chat escapes, deep nesting, extra keys, keys of the
-- wrong type, another kind's `k`, and a missing or out-of-window protocol stamp.
-- What must hold: no client errs (the runner fails the test on a thrown or a logged handler error),
-- what's stored stays within every cap peers enforce, and the honest clients still agree afterwards.
-- Deterministic: its own generator with a fixed seed (not math.random, which the runner seeds anyway).
-- H.SECRET can't cross the wire as a secret (LibSerialize sends a table's contents, not its
-- metatable): on the wire it is an empty table, which is what a field would hold if one were sent.
return function(test, H)
    local eq, ok = H.eq, H.ok
    local PER, MALLORY = "Per Hansen", "Mallory Utenfor" -- a member without the addon, and a stranger
    local PER_KIND = 150

    -- Park-Miller: exact in doubles (s * 16807 < 2^53), the same sequence on every host.
    local function Rng(seed)
        local s = seed
        local r = {}
        function r.int(n) s = (s * 16807) % 2147483647; return s % n + 1 end
        function r.chance(p) return r.int(10000) <= p * 10000 end
        function r.pick(list) return list[r.int(#list)] end
        return r
    end

    local function Copy(v)
        if type(v) ~= "table" or v == H.SECRET then return v end
        local out = {}
        for k, x in pairs(v) do out[Copy(k)] = Copy(x) end
        return out
    end

    -- Values and keys a forger might send. `now` is the server's clock at the fuzz.
    local function Atoms(now, epoch)
        local deep = {}
        local t = deep
        for _ = 1, 60 do t.x = {}; t = t.x end
        local wide = {}
        for i = 1, 40 do wide[("Navn%03d Fals"):format(i)] = { at = now, ts = now, k = "s:46", p = 1e9 } end
        local long = ("x"):rep(255)
        return {
            true, false, 0, -1, 1, 0.5, now + 0.5, -now, 0 / 0, math.huge, -math.huge, 1e308, -1e308,
            2 ^ 53, 2 ^ 63, now, now + 3600, now - 60, epoch - 1, epoch, 1, 2147483647,
            "", " ", long, ("æøå"):rep(30), "Ærlig Åse", "漢字 🐾", "\0", "\n", "|cffff0000rød|r", "|Hitem:1|h",
            "{pet}", "%s%d", "s:", "s:-1", "s:46", "s:5159", "s:99999999999999999999", "n:", "n:|x", "n:Pus",
            "guild:family:cat", "guild:" .. long, PER, MALLORY, "Ola Nord", "Kari Berg", "dev", "999.0.0",
            "0.8.0", "1,2,3", "3,2,1", "0,1", ("1,"):rep(40) .. "1",
            {}, { 1, 2, 3 }, { [1] = "s:46", [3] = "s:40" }, { k = "s:46" }, { at = now, ts = now },
            { p = 10, f = now - 60, t = now }, { n = "Pus", at = now }, { at = now, s = "40,46" },
            H.SECRET, deep, wide,
        }
    end
    -- Keys a store would trip on: names and pet keys no client makes (too long, a chat escape, a line
    -- break, empty, the wrong type), and real ones a forger has no right to.
    local BAD_KEYS = { "", ("N"):rep(49), "|cffff0000Mal|r", "Navn\nNy", "Ny\rLinje", "s:46|h", "s:4x", "n:", "n:|x",
        ("s:" .. ("9"):rep(70)), "guild:", "guild:a b", 0, -1, 1.5, true, false, "Ola Nord", "Kari Berg", MALLORY }
    local KEYS = { "k", "p", "d", "i", "of", "v", "o", "r", "l", "a", "n", "b", "e", "pet", "g",
        "at", "ts", "f", "t", "s", "x", "q", "ann", "zz", 1, 2, 0, -1, 1.5, true, PER, MALLORY, "Ola Nord",
        "Kari Berg", "s:46", "s:5159", "guild:family:cat", ("k"):rep(255), "漢字" }

    -- A table's keys in a fixed order (pairs' order changes from run to run: the seed alone must
    -- decide every mutant).
    local function Sorted(t)
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return type(a) < type(b) end
            if type(a) == "boolean" then return not a and b end
            return a < b
        end)
        return keys
    end

    -- The nodes of a message: { parent, key } for every field, at any depth (a walk with a bound).
    local function Nodes(msg)
        local out, n = {}, 0
        local function Walk(t, depth)
            for _, k in ipairs(Sorted(t)) do
                local v = t[k]
                n = n + 1
                if n > 400 then return end
                out[#out + 1] = { t, k }
                if type(v) == "table" and depth < 6 then Walk(v, depth + 1) end
            end
        end
        Walk(msg, 0)
        return out
    end
    local function Tables(msg)
        local out = { msg }
        for _, node in ipairs(Nodes(msg)) do
            local v = node[1][node[2]]
            if type(v) == "table" then out[#out + 1] = v end
        end
        return out
    end

    -- One mutant of a seed: one to three changes inside, and now and then its kind or stamp.
    local function Mutate(rng, seed, atoms, kinds, ns)
        local msg = Copy(seed)
        local function Atom() return Copy(rng.pick(atoms)) end -- (a copy: the next change may go inside it)
        for _ = 1, rng.int(3) do
            local nodes = Nodes(msg)
            local op = rng.int(6)
            local node = #nodes > 0 and rng.pick(nodes)
            if node and node[2] ~= "k" and node[2] ~= "p" and op == 1 then
                node[1][node[2]] = Atom()                                   -- another value
            elseif node and node[2] ~= "k" and node[2] ~= "p" and op == 2 then
                node[1][node[2]] = nil                                      -- gone
            elseif node and node[2] ~= "k" and node[2] ~= "p" and op == 3 then
                local v = node[1][node[2]]                                  -- under another key
                node[1][node[2]] = nil
                local k = rng.chance(0.5) and rng.pick(KEYS) or Atom()
                if type(k) ~= "table" and k == k then node[1][k] = v end
            elseif node and op == 5 and node[1] ~= msg then
                local k = rng.pick(BAD_KEYS)                                -- a sound entry under a bad key
                node[1][k] = Copy(node[1][node[2]])
            else
                local t = rng.pick(Tables(msg))                             -- an extra key
                local k = rng.pick(KEYS)
                if t ~= msg or (k ~= "k" and k ~= "p") then t[k] = Atom() end
            end
        end
        if rng.chance(0.08) then msg.k = rng.pick(kinds) end
        if rng.chance(0.02) then msg.k = Atom() end
        if rng.chance(0.08) then
            local p = rng.pick({ "none", ns.PROTOCOL_FLOOR - 1, ns.PROTOCOL + 1, 0 / 0, math.huge, -1,
                ns.PROTOCOL_FLOOR + 0.5, tostring(ns.PROTOCOL), {} })
            if p == "none" then msg.p = nil else msg.p = p end
        end
        return msg
    end

    -- A seed for a kind nobody sent during the login: its declared fields, each a plausible value
    -- for its check (a table: one of the stores' shapes).
    local function FromFields(kind, fields, rng, ns)
        local msg = { k = kind, p = ns.Wire.Stamp(kind) }
        local now = ns.Now()
        local plausible = { key = "s:46", version = "0.8.0" }
        local shapes = { { [PER] = now }, { "guild:family:cat" }, { k = "s:46", at = now, ts = now },
            { p = 10, f = now - 60, t = now }, { n = "Pus", at = now }, { at = now, s = "40,46" },
            { ["guild:family:cat"] = { at = now }, ["guild:x"] = { at = now, ann = now } } }
        fields = fields or {}
        for _, name in ipairs(Sorted(fields)) do
            msg[name] = plausible[fields[name]] or Copy(rng.pick(shapes))
        end
        return msg
    end

    -- Every check a peer makes on what it stores, over one client's saved data.
    local function Caps(c, why)
        local ns = c.ns
        local C, L = ns.Config, ns.Wire.LIMITS
        local g = ns.DB:Guild()
        local where = c.name .. " (" .. why .. ")"
        for _, row in ipairs(ns.Sync.TABLES) do
            for k, v in pairs(row.source()) do
                if row.nested then
                    for author, e in pairs(v) do
                        ok(row.valid(k, author, e), ("%s: %s entry %s/%s passes its check"):format(where, row.wire,
                            H.Show(k), H.Show(author)))
                    end
                else
                    ok(row.valid(k, v), ("%s: %s entry %s passes its check"):format(where, row.wire, H.Show(k)))
                end
            end
        end
        -- ... and the same shapes again, written out here (a check loosened in Wire would pass its own test).
        local function Name(s) return type(s) == "string" and s ~= "" and #s <= L.NAME_LEN and not s:find("[|\n\r]") end
        local function Key(s)
            return type(s) == "string" and #s <= L.KEY_LEN and (s:find("^s:%d+$") or s:find("^n:[^|]+$")) ~= nil
        end
        local function Time(t) return type(t) == "number" and t >= C.BOND_EPOCH and t == math.floor(t) end
        for owner, r in pairs(g.claims) do
            ok(Name(owner) and Time(r.at) and Time(r.ts) and (r.k == nil or Key(r.k)), where .. ": claim of " .. H.Show(owner))
        end
        for owner, t in pairs(g.lapses) do ok(Name(owner) and Time(t), where .. ": lapse of " .. H.Show(owner)) end
        for key, byKey in pairs(g.names) do
            for namer, e in pairs(byKey) do
                ok(Key(key) and Name(namer) and Time(e.at), where .. ": name " .. H.Show(key) .. " by " .. H.Show(namer))
                ok(e.n == nil or (type(e.n) == "string" and #e.n <= 4 * C.NICKNAME_MAX_LEN and not e.n:find("[|\n\r]")),
                    where .. ": nickname " .. H.Show(e.n))
            end
        end
        for key, byKey in pairs(g.life) do
            for carer, e in pairs(byKey) do
                ok(Key(key) and Name(carer) and Time(e.f) and type(e.p) == "number" and e.p >= 0
                    and e.p <= ns.Wire.LifeCap(e.f, e.t), where .. ": bond " .. H.Show(key) .. " of " .. H.Show(carer))
            end
        end
        local per = {}
        for _, store in ipairs({ "names", "life" }) do
            per[store] = {}
            for _, byKey in pairs(g[store]) do
                for author in pairs(byKey) do per[store][author] = (per[store][author] or 0) + 1 end
            end
        end
        for author, n in pairs(per.names) do ok(n <= C.NAMES_PER_MEMBER, where .. ": names by " .. author) end
        for author, n in pairs(per.life) do ok(n <= C.LIFE_PER_MEMBER, where .. ": bonds of " .. author) end
        local lapses = 0
        for _ in pairs(g.lapses) do lapses = lapses + 1 end
        ok(lapses <= L.LAPSES_MAX, where .. ": lapses")
        ok(ns.Registry:Held() <= C.HELD_MAX, where .. ": held")
        local unknown = 0
        for id in pairs(g.ach) do if not ns.Achievements.defsById[id] then unknown = unknown + 1 end end
        ok(unknown <= L.GUILD_UNKNOWN_MAX, where .. ": unknown guild achievements")
        for owner, e in pairs(g.owns) do
            ok(ns.Owners.Valid(owner, e), where .. ": owned pets of " .. H.Show(owner))
        end
        -- Nothing a peer sent leaves a NaN, an infinity or a key of the wrong type in the saved data.
        local function Walk(t, path, depth)
            ok(depth < 12, where .. ": nesting at " .. path)
            for k, v in pairs(t) do
                local at = path .. "." .. tostring(k)
                ok(type(k) == "string" or type(k) == "number", where .. ": a key's type at " .. at)
                if type(v) == "number" then ok(v == v and v > -math.huge and v < math.huge, where .. ": " .. at) end
                if type(v) == "table" then Walk(v, at, depth + 1) end
            end
        end
        Walk(g, "guild", 0)
    end

    -- Every online client agrees on who owns what too (65_owners' Converged).
    local function OwnersAgree(w)
        local ref, who
        for _, c in ipairs(w.clients) do
            if c.online and c.guild then
                local d = c.ns.Owners:Digest()
                if not ref then ref, who = d, c.name else eq(d, ref, c.name .. " and " .. who .. " on who owns what") end
            end
        end
    end

    local function Collect(w)
        for _, c in ipairs(w.clients) do
            if c.online then c.seenLog = c.seenLog or {}; c:CollectLogErrors() end
        end
    end

    test("fuzzed messages of every registered kind break no client, stay within the caps, and the guild converges", function()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46 } })
        w:SetGroup({ "Ola Nord", "Kari Berg", "Liv Lund", PER, MALLORY })
        w:Settle("day")
        ola:Slash("adopter"); kari:Slash("adopter")
        w:Run(5)
        w:SkipDays(7)
        w:Befriend()
        kari:Slash("navn Pus")
        w:Run(5)
        local liv = w:AddClient("Liv Lund", { pets = { 41 } }) -- (a newcomer: a SYNC of everything, a seed)
        w:Run(40)
        H.assertConverged(w, "before the fuzz")

        local ns = ola.ns
        -- The kinds, from the registrations (several modules may listen to one: their fields together).
        local kinds, fieldsOf, order = {}, {}, {}
        for _, r in ipairs(ns.Comm.registered) do
            if not fieldsOf[r.kind] then fieldsOf[r.kind] = {}; order[#order + 1] = r.kind end
            for name, check in pairs(r.fields or {}) do fieldsOf[r.kind][name] = check end
        end
        table.sort(order)
        for _, k in ipairs(order) do kinds[#kinds + 1] = k end
        ok(#kinds >= 10, "the registrations are there: " .. table.concat(kinds, " "))
        -- Seeds: the honest messages of each kind the login sent.
        local seeds = {}
        for _, m in ipairs(w.wire) do
            if m.kind and m.msg and fieldsOf[m.kind] then
                seeds[m.kind] = seeds[m.kind] or {}
                if #seeds[m.kind] < 4 then seeds[m.kind][#seeds[m.kind] + 1] = m.msg end
            end
        end

        local rng = Rng(66)
        local now = w:ServerTime()
        local atoms = Atoms(now, ns.Config.BOND_EPOCH)
        local chans = { "GUILD", "GUILD", "GUILD", "PARTY", "PARTY", "WHISPER" }
        local sent, fromSeeds = 0, {}
        for _, kind in ipairs(kinds) do
            local list = seeds[kind] or {}
            fromSeeds[#fromSeeds + 1] = kind .. "=" .. (#list > 0 and #list or "fields")
            for i = 1, PER_KIND do
                local seed = #list > 0 and rng.chance(0.8) and rng.pick(list)
                    or FromFields(kind, fieldsOf[kind], rng, ns)
                -- One in ten goes as it is (fresh), so the handlers past the field checks run too.
                local msg = (i % 10 == 0) and Copy(seed) or Mutate(rng, seed, atoms, kinds, ns)
                local chan = rng.pick(chans)
                local sender = rng.chance(0.7) and PER or MALLORY
                -- (stored, not compressed: the same stream to read, a fraction of the cost under coverage)
                w:InjectMessage(sender, msg, chan, chan == "WHISPER" and rng.pick({ "Ola Nord", "Kari Berg", "Liv Lund" }) or nil, 0)
                sent = sent + 1
                if i % 40 == 0 then w:Run(0.3) end
            end
            w:Run(1)
            Collect(w) -- (before the debug log's ring wraps)
            for _, c in ipairs({ ola, kari, liv }) do Caps(c, "after the " .. kind .. " fuzz") end
        end
        -- The fuzz reached the handlers (decoded, in the protocol window), not only the decoder.
        for _, kind in ipairs(kinds) do
            ok(#ola:Log("<%- " .. kind .. " from") >= PER_KIND / 2, kind .. " messages reached Ola's handlers")
        end
        ok(sent >= #kinds * PER_KIND, "sent " .. sent .. " (" .. table.concat(fromSeeds, " ") .. ")")

        -- Let the answers go out, then a roster judges what non-members left (members only).
        w:Run(60)
        for _, c in ipairs({ ola, kari, liv }) do c.ns.Guild:Refresh(true) end
        w:Run(5)
        for _, c in ipairs({ ola, kari, liv }) do
            Caps(c, "after the roster")
            for owner in pairs(c.ns.DB:Guild().owns) do
                ok(owner == c.name or c.ns.Guild.known[owner], c.name .. ": a non-member's owned pets went: " .. owner)
            end
        end
        H.assertConverged(w, "after the fuzz")
        OwnersAgree(w)

        -- Honest traffic goes on: a release, a newcomer's login, a reload with the saved data.
        kari:Slash("gislipp")
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:Run(60)
        nina:Slash("adopter")
        ola:Reload()
        w:Run(60)
        eq(nina.ns.Registry:Holder("s:72"), "Nina Ny")
        eq(ola.ns.Registry:Holder("s:72"), "Nina Ny")
        for _, c in ipairs({ ola, kari, liv, nina }) do
            Caps(c, "at the end")
            eq(#c:Log("refused a SYNC"), 0, c.name .. " refused no honest SYNC")
        end
        H.assertConverged(w, "at the end")
        OwnersAgree(w)
    end)
end
