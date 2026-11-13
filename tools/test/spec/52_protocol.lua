-- The protocol's fingerprint: everything that decides what peers accept, written out and kept here
-- per X-Protocol. CLAUDE.md's rule ("a wire change bumps X-Protocol") was in memory until
-- 2026-11-12, and went wrong more than once; now it's this test.
--
-- What counts: every registered message kind (channel and field specs), Wire.LIMITS, the
-- Config values that feed validation (as they ship), the bond levels (the digest carries
-- levels), the sync's stores (Sync.TABLES: wire key, part, layout, what TooBig counts, and since
-- X-Protocol 10 each one's digest line for a fixed entry) and a bond's room a day (Wire.DayRoom).
-- The per-member caps (NAMES_PER_MEMBER, LIFE_PER_MEMBER) aren't in it: they only bite under
-- a flood and came without a bump by decision (2026-11-09).
--
-- A kind that's only new passes (older clients drop kinds they don't know); a changed one doesn't.
-- When it fails: if the change is meant, bump `## X-Protocol` in Dyreparken.toc and add the
-- printed fingerprint below under the new number (keep the old ones: they're the history). A
-- bump means older clients ignore every message from newer ones (Comm), so a guild on mixed
-- versions syncs in two halves until everyone updates. If it isn't meant, undo the change.
return function(test, H)
    local eq, ok = H.eq, H.ok

    local SNAPSHOTS = {
        [9] = [[
kind ACH from=GUILD fields=a:table
kind ACH_EARNED from=GUILD fields=a:table
kind BOND from=GUILD fields=e:table,pet:key
kind BOND_REQ from=GUILD fields=pet:key
kind HELLO from=GUILD fields=
kind HELLO from=nil fields=
kind LAPSE from=GUILD fields=l:table
kind NICK from=GUILD fields=e:table,pet:key
kind PET_REQ from=GROUP fields=
kind PLAY from=GROUP fields=pet:key
kind SYNC from=GUILD fields=
kind UPD from=GUILD fields=r:table
kind VER from=nil fields=v:version
kind VER_REQ from=nil fields=
limit ACH_ID_LEN=64
limit ACH_ID_PATTERN=^guild:[%w:_]+$
limit DAY=86400
limit GUILD_UNKNOWN_MAX=64
limit KEY_LEN=64
limit LIFE_SPARE_DAYS=2
limit MAX_PARTS=64
limit MAX_RAW=524288
limit NAME_LEN=48
limit NICK_BYTES_PER_CHAR=4
limit VERSION_LEN=32
config BOND_DAILY_MAX=75
config BOND_EPOCH=1793487600
config CLOCK_SLACK=300
config NICKNAME_MAX_LEN=20
config SYNC_MAX_ENTRIES=2000
level 1=0
level 2=100
level 3=270
level 4=530
level 5=900
level 6=1440
level 7=2250
store r part=1 nested=false count=true
store l part=1 nested=false count=true
store a part=1 nested=false count=false
store n part=2 nested=true count=true
store b part=3 nested=true count=true
]],
        -- 10 (2026-11-13, 0.6.0): members-only sync (Registry: Admit, Prune; not in the fingerprint,
        -- it's behavior), LIFE_SPARE_DAYS 3, LAPSES_MAX, a day's room 75 + the wish's 10, whole-number
        -- times, a claim's and a name's digest line carrying what they hold. The digest and day room
        -- lines are new with it.
        [10] = [[
kind ACH from=GUILD fields=a:table
kind ACH_EARNED from=GUILD fields=a:table
kind BOND from=GUILD fields=e:table,pet:key
kind BOND_REQ from=GUILD fields=pet:key
kind HELLO from=GUILD fields=
kind HELLO from=nil fields=
kind LAPSE from=GUILD fields=l:table
kind NICK from=GUILD fields=e:table,pet:key
kind PET_REQ from=GROUP fields=
kind PLAY from=GROUP fields=pet:key
kind SYNC from=GUILD fields=
kind UPD from=GUILD fields=r:table
kind VER from=nil fields=v:version
kind VER_REQ from=nil fields=
limit ACH_ID_LEN=64
limit ACH_ID_PATTERN=^guild:[%w:_]+$
limit DAY=86400
limit GUILD_UNKNOWN_MAX=64
limit KEY_LEN=64
limit LAPSES_MAX=1000
limit LIFE_SPARE_DAYS=3
limit MAX_PARTS=64
limit MAX_RAW=524288
limit NAME_LEN=48
limit NICK_BYTES_PER_CHAR=4
limit VERSION_LEN=32
config BOND_DAILY_MAX=75
config BOND_EPOCH=1793487600
config CLOCK_SLACK=300
config NICKNAME_MAX_LEN=20
config SYNC_MAX_ENTRIES=2000
level 1=0
level 2=100
level 3=270
level 4=530
level 5=900
level 6=1440
level 7=2250
store r part=1 nested=false count=true
store l part=1 nested=false count=true
store a part=1 nested=false count=false
store n part=2 nested=true count=true
store b part=3 nested=true count=true
digest r=cOla Nord<31>1793500010<31>1793500000<31>s:5159
digest l=lOla Nord<31>1793500020
digest a=aguild:family:cat<31>1793500030<31>1793500040
digest n=ns:5159<31>Ola Nord<31>1793500050<31>Bambus<31>
digest b=bs:5159<31>Ola Nord<31>3
bond dayroom=85
]],
    }

    local CONFIG = { "BOND_DAILY_MAX", "BOND_EPOCH", "CLOCK_SLACK", "NICKNAME_MAX_LEN", "SYNC_MAX_ENTRIES" }
    -- One fixed entry per store, for its digest line (a store missing here fails: add one).
    local SAMPLE = {
        r = { "Ola Nord", { k = "s:5159", at = 1793500000, ts = 1793500010 } },
        l = { "Ola Nord", 1793500020 },
        a = { "guild:family:cat", { at = 1793500030, ann = 1793500040 } },
        n = { "s:5159", "Ola Nord", { n = "Bambus", at = 1793500050 } },
        b = { "s:5159", "Ola Nord", { p = 300, f = 1793500000, t = 1793500060 } },
    }

    local function Fingerprint(c)
        local ns, lines = c.ns, {}
        local regs = {}
        for _, r in ipairs(ns.Comm.registered) do
            local fields = {}
            for name, check in pairs(r.fields or {}) do fields[#fields + 1] = name .. ":" .. check end
            table.sort(fields)
            regs[#regs + 1] = ("kind %s from=%s fields=%s"):format(r.kind, tostring(r.from), table.concat(fields, ","))
        end
        table.sort(regs)
        for _, l in ipairs(regs) do lines[#lines + 1] = l end
        local limits = {}
        for k, v in pairs(ns.Wire.LIMITS) do limits[#limits + 1] = ("limit %s=%s"):format(k, tostring(v)) end
        table.sort(limits)
        for _, l in ipairs(limits) do lines[#lines + 1] = l end
        for _, k in ipairs(CONFIG) do lines[#lines + 1] = ("config %s=%s"):format(k, tostring(c.shippedConfig[k])) end
        for i, lv in ipairs(ns.Bond.LEVELS) do lines[#lines + 1] = ("level %d=%d"):format(i, lv[1]) end
        for _, row in ipairs(ns.Sync.TABLES) do
            lines[#lines + 1] = ("store %s part=%d nested=%s count=%s"):format(row.wire, row.part, tostring(row.nested == true),
                tostring(row.count == true))
        end
        for _, row in ipairs(ns.Sync.TABLES) do
            local e = SAMPLE[row.wire]
            local line = row.nested and row.digest(e[1], e[2], e[3]) or row.digest(e[1], e[2])
            lines[#lines + 1] = ("digest %s=%s"):format(row.wire, (line:gsub("[%z\1-\31]", function(ch) return ("<%d>"):format(ch:byte()) end)))
        end
        lines[#lines + 1] = ("bond dayroom=%d"):format(ns.Wire.DayRoom())
        return table.concat(lines, "\n") .. "\n"
    end

    -- A message kind that's only new needs no bump (the user, 2026-11-12): older clients drop
    -- kinds they don't know. Everything else must match the snapshot line for line.
    local function Lines(text)
        local set, kinds = {}, {}
        for l in text:gmatch("[^\n]+") do
            set[l] = true
            local kind = l:match("^kind (%S+)")
            if kind then kinds[kind] = true end
        end
        return set, kinds
    end
    local function Changed(snap, now)
        if not snap then return true end
        if now == snap then return false end
        local was, wasKinds = Lines(snap)
        local is = Lines(now)
        for l in pairs(was) do if not is[l] then return true end end
        for l in pairs(is) do
            local kind = l:match("^kind (%S+)")
            if not was[l] and not (kind and not wasKinds[kind]) then return true end
        end
        return false
    end

    test("what peers accept changes only with an X-Protocol bump", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Settle("hello")
        local proto = tonumber(H.TOC.meta["X-Protocol"])
        eq(c.ns.PROTOCOL, proto)
        local now, snap = Fingerprint(c), SNAPSHOTS[proto]
        local changed = Changed(snap, now)
        if changed then
            print(("-- the fingerprint now (X-Protocol %d in the TOC):\n%s"):format(proto, now))
            error(snap and ("what peers accept changed, but X-Protocol is still %d: bump it in Dyreparken.toc and add "
                .. "the fingerprint printed above as SNAPSHOTS[%d] in this file (or undo the change)"):format(proto, proto + 1)
                or ("X-Protocol is %d and there's no snapshot for it: add the fingerprint printed above as "
                .. "SNAPSHOTS[%d] in this file"):format(proto, proto), 0)
        end
        -- The fingerprint sees what it should: a limit, a field spec, a Config value.
        local before = Fingerprint(c)
        c.ns.Wire.LIMITS.KEY_LEN = c.ns.Wire.LIMITS.KEY_LEN + 1
        ok(Fingerprint(c) ~= before, "a limit")
        c.ns.Wire.LIMITS.KEY_LEN = c.ns.Wire.LIMITS.KEY_LEN - 1
        c.shippedConfig.BOND_DAILY_MAX = 76
        ok(Fingerprint(c) ~= before, "a Config value")
        c.ns.Comm:Register("NICK", function() end, "GUILD", { pet = "table" })
        ok(Fingerprint(c) ~= before, "a field spec")
        -- A new kind alone needs no bump; a changed one does.
        local base = "kind NICK from=GUILD fields=pet:key\nlimit KEY_LEN=64\n"
        ok(not Changed(base, base .. "kind HUG from=GUILD fields=pet:key\n"), "a new kind")
        ok(Changed(base, "kind NICK from=GUILD fields=pet:table\nlimit KEY_LEN=64\n"), "a kind's fields")
        ok(Changed(base, "kind NICK from=GUILD fields=pet:key\n"), "a limit gone")
        ok(Changed(base, base .. "kind NICK from=GROUP fields=pet:key\n"), "a known kind on another channel")
        ok(Changed(base, base .. "limit NEW=1\n"), "a new limit")
    end)
end
