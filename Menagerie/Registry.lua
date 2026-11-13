local _, ns = ...

-- The guild's companion reservations.
--
-- DATA MODEL: one record per character, written only by that character.
--   g.claims[owner] = { k = petKey|nil, at = claimTime, ts = editTime }
--     k nil: no reservation (released). The record is kept so the release
--     wins over older copies still floating around.
--     at: when this pet was claimed (server time). First come, first served.
--     ts: when the owner last changed the record. Copies merge by highest ts,
--     which works because the owner is the only writer.
--   g.lapses[owner] = serverTime
--     Someone saw this owner inactive for INACTIVE_RELEASE_DAYS (in a roster
--     the server just sent, with the owner's own record at least as old), or
--     missing from a complete guild roster. Claims made before the lapse are void for
--     good, so a returning player doesn't take back a pet someone else picked
--     up meanwhile; they have to claim it again. Merges by max.
--
-- WHO HOLDS A PET is derived, never stored: among valid records claiming
-- it, the earliest `at` wins (ties: lower owner name). Every client gets the
-- same answer from the same data, whatever order the messages arrived in.
--
-- NICKNAMES belong to the pet, not to an adoption: the name stays when its
-- carer lets go, and the next carer may rename it once their bond with it
-- reaches Config.NICKNAME_LEVEL (Venn; it was 7 days of care until
-- 2026-11-09); clearing it needs no level (2026-11-10). Only checked by the carer's own client. Each naming is its own entry, written only by the
-- one who named it:
--   g.names[petKey][namer] = { n = nick|nil, at = when, x = true? }
--     n nil: the namer cleared the name. x: void (the namer lost an adoption
--     race and never really held the pet, see CheckMine). Merges by highest at.
-- THE NAME of a pet is derived like the holder: the newest entry that isn't
-- void and was set either by the current holder or before their adoption
-- began. So a name set by someone who didn't hold the pet at the time (a
-- partition, a forged entry) can't override the holder's.
--
-- BONDS (Menagerie/Bond.lua) live per pet and carer, so a pet you adopt
-- again picks up where you left off:
--   g.life[petKey][carer] = { p = points, f = first adopted, t = last change }
--     Written only by that carer. Points never go down, so copies merge by
--     the highest p (then t). A copy can't claim more points than are
--     possible since f (Config.BOND_DAILY_MAX a day), which bounds forgeries.
--
-- The owner's client watches its own record. If it lost a race (someone
-- claimed earlier) or lapsed, it releases and tells the player.
--
-- Trust: records are relayed by other clients during sync, so they can't be
-- verified. Fine for one friendly guild; validate shapes, not intent.
local Registry = {}
ns.Registry = Registry

local Config = ns.Config

local holders, dirty = {}, true -- holders[petKey] = owner (cache)
local builtFor -- the guild the cache was built for: joining another one (or none) rebuilds it

local function G()
    return ns.DB:Guild()
end

------------------------------------------------------------------------------
-- Validation and merge
------------------------------------------------------------------------------
-- The primitive checks (keys, names, times, a nickname, a bond's cap) are
-- Core/Wire.lua's, with every limit peers enforce; here they make up the
-- checks on a store's entries.
local Wire = ns.Wire
local ValidKey, After = Wire.Key, Wire.Since
Registry.ValidKey = ValidKey
Registry.LifeCap = Wire.LifeCap

-- Nothing in the registry is older than the addon (BOND_EPOCH, Wire.Since),
-- and a claim comes before its record's write: a claim backdated to the dawn
-- of time won every pet it named (code review 2026-11-10). Honest data passes
-- the old and the new rules alike, so this came without a protocol bump
-- (decided 2026-11-10, like the per-member caps); migration 10 drops stored
-- entries outside them.
local function ValidRecord(r)
    if type(r) ~= "table" or not After(r.ts) or not After(r.at) or r.at > r.ts then return false end
    if r.k ~= nil and not ValidKey(r.k) then return false end
    return true
end
Registry.ValidRecord = ValidRecord
Registry.ValidLapse = After

local function Copy(r)
    return { k = r.k, at = r.at, ts = r.ts }
end

local function ValidEntry(e)
    return type(e) == "table" and After(e.at)
        and (e.n == nil or Wire.Nick(e.n) == nil) and (e.x == nil or e.x == true)
end
Registry.ValidEntry = ValidEntry

local function ValidLife(e)
    if type(e) ~= "table" or not Wire.Time(e.f) or not Wire.Time(e.t) or e.t < e.f then return false end
    if e.f < Config.BOND_EPOCH then return false end -- older than the addon: forged
    local p = e.p
    if type(p) ~= "number" or p ~= p or p < 0 then return false end
    return p <= Wire.LifeCap(e.f, e.t)
end
Registry.ValidLife = ValidLife

-- A whole entry as it sits in its store, author and keys included: what a
-- merge checks before taking a peer's copy, and WriteOwn before keeping our
-- own (Sync.TABLES names them per store).
local SaneName = Wire.Name
function Registry.ValidClaim(owner, r) return SaneName(owner) and ValidRecord(r) end
function Registry.ValidLapseOf(owner, t) return SaneName(owner) and After(t) end
function Registry.ValidNaming(key, namer, e) return ValidKey(key) and SaneName(namer) and ValidEntry(e) end
function Registry.ValidBond(key, carer, e) return ValidKey(key) and SaneName(carer) and ValidLife(e) end

-- Returns true when our data changed.
-- At most `max` entries by one author in t[key][author] (code review
-- 2026-11-09): one member sending names or bonds under made-up pet keys
-- grew everyone's saved data, until every honest SYNC was over
-- SYNC_MAX_ENTRIES and refused, and digests never agreed again. Past the
-- cap the oldest entry goes (by `field`, ties: the greater pet key): the
-- same choice on every client whatever order entries arrived in, so the
-- digests still agree. No real member comes near the caps. Returns false if
-- the entry just added (key `added`) was the one to go.
local function Trim(t, author, field, max, added)
    local n, worstKey, worst = 0, nil, nil
    for key, byKey in pairs(t) do
        local e = byKey[author]
        if e then
            n = n + 1
            if not worst or e[field] < worst or (e[field] == worst and key > worstKey) then
                worst, worstKey = e[field], key
            end
        end
    end
    if n <= max then return true end
    t[worstKey][author] = nil
    if not next(t[worstKey]) then t[worstKey] = nil end
    return worstKey ~= added
end

-- The same over a whole table (migration 9): every author within the cap.
function Registry.TrimAll(t, field, max)
    local count = {}
    for _, byKey in pairs(t) do
        for author in pairs(byKey) do count[author] = (count[author] or 0) + 1 end
    end
    for author, n in pairs(count) do
        for _ = max + 1, n do Trim(t, author, field, max) end
    end
end

function Registry:MergeLife(key, carer, e)
    local g = G()
    if not g or not Registry.ValidBond(key, carer, e) then
        return false
    end
    local byKey = g.life[key]
    local cur = byKey and byKey[carer]
    if cur and (cur.p > e.p or (cur.p == e.p and cur.t >= e.t)) then return false end
    if not byKey then byKey = {}; g.life[key] = byKey end
    byKey[carer] = { p = e.p, f = e.f, t = e.t }
    return Trim(g.life, carer, "t", Config.LIFE_PER_MEMBER, key)
end

-- The bonds the full sync carries: each pet's current holder's (one per
-- member at most). Bonds with pets you haven't adopted (any pet of yours
-- bonds, 2026-11-09) aren't in the SYNC or the digest: with 100 members and
-- several pets each they'd outgrow what a SYNC can carry. They travel as
-- their owner's BOND messages and on request (BOND_REQ, when a card shows
-- the pet); it's fine for those to be a little behind.
function Registry:AdoptedLife()
    local g = G()
    local out = {}
    if not g then return out end
    for key, byKey in pairs(g.life) do
        local holder = self:Holder(key)
        local e = holder and byKey[holder]
        if e then out[key] = { [holder] = e } end
    end
    return out
end

-- A carer's bond entry with a pet, or nil.
function Registry:Life(key, carer)
    local g = G()
    local byKey = g and key and g.life[key]
    return byKey and byKey[carer]
end

-- Returns true when our data changed.
-- Two copies with the same stamp (a forgery: the author writes one a second) are told apart
-- by what the digest carries (Sync.TABLES), the greater line winning, so every client keeps
-- the same one and the digests agree (X-Protocol 10; before, the first one seen stayed).
local function NameLine(e) return (e.n or "") .. "\31" .. (e.x and "x" or "") end
local function ClaimLine(r) return r.at .. "\31" .. (r.k or "") end
Registry.NameLine, Registry.ClaimLine = NameLine, ClaimLine

function Registry:MergeName(key, namer, e)
    local g = G()
    if not g or not Registry.ValidNaming(key, namer, e) then
        return false
    end
    local byKey = g.names[key]
    local cur = byKey and byKey[namer]
    if cur and (cur.at > e.at or (cur.at == e.at and NameLine(cur) >= NameLine(e))) then return false end
    if not byKey then byKey = {}; g.names[key] = byKey end
    byKey[namer] = { n = e.n, at = e.at, x = e.x }
    return Trim(g.names, namer, "at", Config.NAMES_PER_MEMBER, key)
end

-- Returns true when our data changed.
function Registry:MergeRecord(owner, r)
    local g = G()
    if not g or not Registry.ValidClaim(owner, r) then return false end
    local cur = g.claims[owner]
    if cur and (cur.ts > r.ts or (cur.ts == r.ts and ClaimLine(cur) >= ClaimLine(r))) then return false end
    g.claims[owner] = Copy(r)
    dirty = true
    return true
end

function Registry:MergeLapse(owner, t)
    local g = G()
    if not g or not Registry.ValidLapseOf(owner, t) then return false end
    if (g.lapses[owner] or 0) >= t then return false end
    g.lapses[owner] = t
    dirty = true
    return true
end

-- Our own entries, the stores only we write our part of. One path for every
-- such write (2026-11-12; until then claims, names and bonds each had their
-- own, and bonds skipped the per-member cap):
--   stamp  the field copies merge by; it grows by `step` at least, so two
--          edits in the same second still order (bonds merge by points first,
--          so their time only mustn't go back)
--   valid  the very check peers run on our copy (a merge's): an entry they'd
--          refuse would keep us apart from them for good, so it's an error here
--   cap    the per-member cap peers keep (Trim), so our store matches theirs
--   (then MY_RECORD or MY_NAME tells Sync to send it; bonds go out lazily: Bond.lua publishes them)
--   changed  it can change who holds or what a pet is called (Registry:Changed)
local OWN = {
    claims = { stamp = "ts", step = 1, valid = function(_, me, r) return Registry.ValidClaim(me, r) end,
        changed = true },
    names = { nested = true, stamp = "at", step = 1, valid = Registry.ValidNaming, cap = "NAMES_PER_MEMBER",
        changed = true },
    life = { nested = true, stamp = "t", step = 0, valid = Registry.ValidBond, cap = "LIFE_PER_MEMBER" },
}

-- Write our own entry: store "claims" (key: unused, the record is ours),
-- "names" or "life" (key: the pet). Returns the entry as stored.
function Registry:WriteOwn(store, key, e)
    local spec = assert(OWN[store], "WriteOwn: not a store of our own")
    local g, me = G(), ns.PlayerKey()
    local t = g[store]
    local prev
    if spec.nested then prev = t[key] and t[key][me] else prev = t[me] end
    e[spec.stamp] = math.max(ns.Now(), (prev and prev[spec.stamp] or 0) + spec.step)
    -- An entry peers would refuse is our bug. The tests fail on it (ns.STRICT, the harness); in the
    -- game it's logged and kept as before, never a Lua error in the middle of adopting a pet (2026-11-12).
    if not spec.valid(key, me, e) then
        if ns.STRICT then error("WriteOwn: peers would refuse this " .. store .. " entry", 2) end
        ns.Log("Registry", "WriteOwn: peers would refuse our %s entry for %s; kept", store, tostring(key))
    end
    if spec.nested then
        t[key] = t[key] or {}
        t[key][me] = e
        Trim(t, me, spec.stamp, Config[spec.cap], key)
    else
        t[me] = e
    end
    if spec.changed then self:Changed() end
    if store == "claims" then ns.Bus:Fire("MY_RECORD", me, e)
    elseif store == "names" then ns.Bus:Fire("MY_NAME", key, e) end
    return e
end

------------------------------------------------------------------------------
-- Derivation
------------------------------------------------------------------------------
-- Is this claim currently valid (not released, not lapsed)?
local function Active(g, owner, r)
    if not r.k then return false end
    local lapse = g.lapses[owner]
    if lapse and lapse >= r.at then return false end
    return true
end

-- Look at the roster and record lapses for owners who left or went quiet.
-- Returns the lapses it added, so Sync can share them.
--
-- A lapse is for good and goes guild-wide, so one client's odd roster read
-- (a name format with a realm suffix we don't strip, say) would free every
-- pet it can't match (B10, refactoring review 2026-11-12). So a roster is
-- trusted only if it lists us (a name format we can't match misses us too),
-- and a batch is held back whole when it would lapse more than
-- Config.ROSTER_LAPSE_SHARE of the adoptions at once (Config.ROSTER_LAPSE_FLOOR
-- always may: a small guild losing one of three members is no oddity). The
-- batch isn't cut down to fit: a partial read would still free some pets
-- wrongly, and no piece of it is more trustworthy than the rest.
function Registry:CheckRoster()
    local g = G()
    if not g then return nil end
    local me = ns.PlayerKey()
    if not ns.Guild:IsMember(me) then
        if ns.Guild.at > 0 then ns.Log("Registry", "roster doesn't list %s: no lapses from it", tostring(me)) end
        return nil
    end
    local batch, active = {}, 0
    for owner, r in pairs(g.claims) do
        if r.k and Active(g, owner, r) then
            active = active + 1
            local member = ns.Guild:IsMember(owner)
            local days = ns.Guild:DaysOffline(owner)
            -- Days offline only from a roster the server just sent (a cached one can be from
            -- before they came back), and not for an owner whose own record is newer than
            -- that: they've been here since (code review 2026-11-10).
            local away = days and days >= Config.INACTIVE_RELEASE_DAYS and not ns.Guild.stale
                and ns.Now() - r.ts >= Config.INACTIVE_RELEASE_DAYS * 86400
            if member == false or away then
                batch[#batch + 1] = { owner, member == false and "left guild" or (days .. " days offline") }
            end
        end
    end
    -- Only a complete roster the server just sent can judge a held batch: a stale or partial one
    -- misses nobody (IsMember is nil), so its batch is small or empty and would drop the held
    -- set, and a real wave of departures would be held again, dated anew, for good (code review
    -- 2026-11-13). Such a read still lapses what it can see (days offline from a partial read).
    local judges = ns.Guild.complete and not ns.Guild.stale
    local most = math.max(Config.ROSTER_LAPSE_FLOOR, math.floor(active * Config.ROSTER_LAPSE_SHARE))
    if #batch > most and not judges then
        ns.Log("Registry", "roster would lapse %d of %d adoptions at once (at most %d), from a read that can't judge: none lapsed", #batch, active, most)
        return nil
    elseif #batch > most then
        -- Too many at once: one odd read, or a real wave of departures. Held back; a roster on a
        -- later day that still misses the same owners confirms it (the user, 2026-11-12: "hell
        -- yeah"), and those go, however many. Remembered per guild, across logins.
        -- "A later day" is Config.ROSTER_CONFIRM_AFTER later, not another date: two reads minutes
        -- apart across midnight aren't two days (code review 2026-11-13). A held batch older than
        -- Config.ROSTER_HELD_MAX is no fair comparison any more: held again from this read. One
        -- held before it had a time (`day` only) counts as just held.
        local now, held = ns.Now(), g.rosterHeld
        if held and not held.at then held.at, held.day = now, nil end
        if held and now - held.at > Config.ROSTER_HELD_MAX then held = nil end
        if not held or now - held.at < Config.ROSTER_CONFIRM_AFTER then
            if not held then
                local owners = {}
                for _, b in ipairs(batch) do owners[b[1]] = true end
                g.rosterHeld = { at = now, owners = owners }
            end
            ns.Log("Registry", "roster would lapse %d of %d adoptions at once (at most %d): none lapsed", #batch, active, most)
            return nil
        end
        -- Owners missing now who weren't held are held anew (dropping them would put them two
        -- reads further off); they go when a later read confirms them.
        local confirmed, fresh = {}, nil
        for _, b in ipairs(batch) do
            if held.owners[b[1]] then
                confirmed[#confirmed + 1] = b
            else
                fresh = fresh or {}
                fresh[b[1]] = true
            end
        end
        ns.Log("Registry", "roster batch of %d confirmed on a second day: %d lapse", #batch, #confirmed)
        batch = confirmed
        g.rosterHeld = fresh and { at = now, owners = fresh } or nil
    elseif judges then
        g.rosterHeld = nil
    end
    local added
    for _, b in ipairs(batch) do
        local t = ns.Now()
        if self:MergeLapse(b[1], t) then
            added = added or {}
            added[b[1]] = t
            ns.Log("Registry", "lapse %s (%s)", b[1], b[2])
        end
    end
    return added
end

local function Rebuild()
    wipe(holders)
    local g, name = G()
    builtFor = name
    if not g then dirty = false; return end
    local best = {} -- petKey -> record
    for owner, r in pairs(g.claims) do
        if Active(g, owner, r) then
            local b = best[r.k]
            if not b or r.at < b.at or (r.at == b.at and owner < holders[r.k]) then
                best[r.k] = r
                holders[r.k] = owner
            end
        end
    end
    dirty = false
end

local function Fresh()
    if dirty or select(2, G()) ~= builtFor then Rebuild() end
end

-- keys: { [petKey] = true } when only those pets' bonds changed (Sync: a guildmate's BOND), so
-- what shows other pets needn't be redrawn; nil when anything may have (who holds what, names).
function Registry:Changed(keys)
    dirty = true
    ns.Bus:Fire("REGISTRY", keys)
end

-- owner, record for a pet key, or nil if free.
function Registry:Holder(key)
    Fresh()
    local owner = holders[key]
    if not owner then return nil end
    return owner, G().claims[owner]
end

-- "mine", "taken" or "free", and the owner and record: for markers and text.
function Registry:Status(key)
    local owner, r = self:Holder(key)
    if not owner then return "free" end
    return owner == ns.PlayerKey() and "mine" or "taken", owner, r
end

-- The pet a member holds (won), if any: key, record.
function Registry:PetOf(carer)
    local g = G()
    local r = g and carer and g.claims[carer]
    if r and r.k and self:Holder(r.k) == carer then return r.k, r end
end

-- The pet this character holds, if any: key, record.
function Registry:MyPet() return self:PetOf(ns.PlayerKey()) end

function Registry:MyRecord()
    local g = G()
    return g and g.claims[ns.PlayerKey()]
end

-- Snapshot for sync and digests.
function Registry:All()
    local g = G()
    if not g then return {}, {}, {}, {} end
    return g.claims, g.lapses, g.names, g.life
end

-- Number of distinct pets held. Only species in Forever's journal count
-- (Data/Companions.lua), so a junk or hidden key from the wire can't push
-- "x of y" past y.
function Registry:Count()
    Fresh()
    local known = ns.Companions and ns.Companions.species
    local n = 0
    for key in pairs(holders) do
        if not known or known[ns.Pets:SpeciesOfKey(key) or false] then n = n + 1 end
    end
    return n
end

function Registry:Holders()
    Fresh()
    return holders
end

------------------------------------------------------------------------------
-- Nicknames
------------------------------------------------------------------------------
-- What a pet is called: its nickname, or the species name.
function Registry:NameOf(key)
    return self:Nickname(key) or ns.Pets:NameOfKey(key)
end

-- A pet as someone's: its nickname only if it lives with them (the name is
-- its holder's), else the species.
function Registry:NameFor(key, carer)
    if carer and self:Holder(key) == carer then return self:NameOf(key) end
    return ns.Pets:NameOfKey(key)
end

-- The pet's nickname (nil if it has none), and who named it, when.
function Registry:Nickname(key)
    local g = G()
    local byKey = g and key and g.names[key]
    if not byKey then return nil end
    local holder, hr = self:Holder(key)
    local best, bestBy
    for namer, e in pairs(byKey) do
        if not e.x and (namer == holder or not hr or e.at <= hr.at)
            and (not best or e.at > best.at or (e.at == best.at and namer < bestBy)) then
            best, bestBy = e, namer
        end
    end
    if best and best.n then return best.n, bestBy, best.at end
end

-- This character's naming entry for a pet; MY_NAME sends it (Sync).
local function WriteName(key, e) return Registry:WriteOwn("names", key, e) end

-- May the holder of r name the pet? Once their bond reaches NICKNAME_LEVEL.
function Registry:CanNickname(r)
    if not (r and r.k) then return false end
    local _, level = ns.Bond:Of(r.k)
    return (level or 0) >= Config.NICKNAME_LEVEL
end

-- ok, cleaned nickname (or error message)
-- The check peers run on a name (Wire.Nick), on what was typed, trimmed.
local WHY = { empty = "nick.empty", too_long = "nick.too_long", bad_chars = "nick.bad_chars" }
function Registry:ValidNickname(nick)
    if type(nick) == "string" then nick = strtrim(nick) end
    local why = ns.Wire.Nick(nick)
    if why then return false, ns.T(WHY[why], { n = Config.NICKNAME_MAX_LEN }) end
    return true, nick
end

------------------------------------------------------------------------------
-- Actions by this character. Each returns ok, message.
------------------------------------------------------------------------------
local function Write(r) return Registry:WriteOwn("claims", nil, r) end

function Registry:Claim(key)
    local g = G()
    if not g then return false, ns.L["adopt.no_guild"] end
    if not key then return false, ns.L["adopt.unknown"] end
    if not ns.Pets:Owned()[key] then return false, ns.L["adopt.not_owned"] end
    local owner = self:Holder(key)
    local me = ns.PlayerKey()
    if owner == me then return false, ns.L["adopt.yours"] end
    if owner then return false, ns.T("adopt.taken", { owner = owner }) end
    local mine = self:MyPet()
    Write({ k = key, at = ns.Now() })
    ns.Log("Registry", "claim %s (was %s)", key, tostring(mine))
    ns.Bus:Fire("ADOPTED", key)
    local msg = ns.T(mine and "adopt.done_swap" or "adopt.done", { pet = ns.Pets:NameOfKey(key),
        old = mine and ns.Pets:NameOfKey(mine) })
    -- A name it got from an earlier carer comes along: introduce it.
    local nick, namer = self:Nickname(key)
    if nick then
        msg = msg .. (namer == me and ns.T("adopt.keeps_own_name", { nick = nick })
            or ns.T("adopt.inherits_name", { nick = nick, namer = namer }))
    end
    return true, msg
end

function Registry:Release()
    local r = self:MyRecord()
    if not r or not r.k then return false, ns.L["release.none"] end
    local key = r.k
    Write({ at = r.at })
    ns.Log("Registry", "release %s", key)
    return true, ns.T("release.done", { pet = ns.Pets:NameOfKey(key) })
end

function Registry:SetNickname(nick)
    local key, r = self:MyPet()
    if not key then return false, ns.L["nick.no_pet"] end
    local clear = nick == nil or strtrim(nick) == ""
    -- Naming waits for the bond; clearing doesn't: a name the pet came with
    -- (or one forged onto it) can go at once (code review 2026-11-10).
    if not clear and not self:CanNickname(r) then
        return false, ns.T("nick.locked", { level = ns.Bond.LEVELS[Config.NICKNAME_LEVEL][2], n = Config.NICKNAME_LEVEL })
    end
    local ok, clean = true, nil
    if not clear then
        ok, clean = self:ValidNickname(nick)
        if not ok then return false, clean end
    end
    if self:Nickname(key) == clean then
        return false, clean and ns.T("nick.same", { nick = clean }) or ns.L["nick.none"]
    end
    -- One new name a day per pet, with Config.NICKNAME_FIX seconds after the day's
    -- first to fix a typo; clearing is always allowed (the user, 2026-11-10).
    local today, named = ns.Today(), ns.DB.char.named
    if not named or named.day ~= today then named = { day = today, at = {} }; ns.DB.char.named = named end
    if not clear then
        local first = named.at[key]
        if first and ns.Now() - first > Config.NICKNAME_FIX then
            return false, ns.T("nick.tomorrow", { pet = self:NameOf(key) })
        end
        named.at[key] = first or ns.Now()
    end
    WriteName(key, { n = clean })
    return true, clean and ns.T("nick.set", { nick = clean }) or ns.L["nick.cleared"]
end

-- Our own record lost a race or lapsed: release it and say why. Called after
-- merges. Returns true if it released.
function Registry:CheckMine()
    local g = G()
    if not g then return false end
    local me = ns.PlayerKey()
    local r = g.claims[me]
    if not r or not r.k then return false end
    local owner = self:Holder(r.k)
    if owner == me then return false end
    local name = ns.Pets:NameOfKey(r.k)
    if not Active(g, me, r) then
        ns.Print(ns.T("lapse.away", { pet = name }))
    else
        ns.Print(ns.T("lapse.beaten", { owner = owner or ns.L["lapse.unknown_owner"], pet = name }))
        -- We never really held it, so a name we gave it meanwhile doesn't count.
        local mine = g.names[r.k] and g.names[r.k][me]
        if mine and not mine.x and mine.at >= r.at then WriteName(r.k, { x = true }) end
    end
    Write({ at = r.at })
    return true
end

-- Our own record may have lost a race or lapsed while we were away.
ns.Start("settled", function() Registry:CheckMine() end)
