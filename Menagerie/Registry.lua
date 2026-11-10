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
local DAY = 86400

local holders, dirty = {}, true -- holders[petKey] = owner (cache)
local builtFor -- the guild the cache was built for: joining another one (or none) rebuilds it

local function G()
    return ns.DB:Guild()
end

------------------------------------------------------------------------------
-- Validation and merge
------------------------------------------------------------------------------
-- A pet key as Pets.lua makes them: "s:<species id>", or "n:<name>" for a
-- pet without a species id. No "|": a name key can reach the chat (the
-- playdate line), where it would be an escape code (code review 2026-11-09).
local function ValidKey(key)
    return type(key) == "string" and #key <= 64 and (key:find("^s:%d+$") ~= nil or key:find("^n:[^|]+$") ~= nil)
end
Registry.ValidKey = ValidKey

-- Nothing in the registry is older than the addon (BOND_EPOCH), and a claim
-- comes before its record's write: a claim backdated to the dawn of time won
-- every pet it named (code review 2026-11-10). Honest data passes the old and
-- the new rules alike, so this came without a protocol bump (decided
-- 2026-11-10, like the per-member caps); migration 10 drops stored entries
-- outside them.
local function After(t) return ns.SaneTime(t) and t >= Config.BOND_EPOCH end

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

-- The byte cap: Utf8Len counts only lead bytes, so a string of stray
-- continuation bytes would pass as short.
local function ValidName(n)
    return type(n) == "string" and n ~= "" and #n <= 4 * Config.NICKNAME_MAX_LEN
        and ns.Utf8Len(n) <= Config.NICKNAME_MAX_LEN and not n:find("[|\n\r]")
end

local function ValidEntry(e)
    return type(e) == "table" and After(e.at)
        and (e.n == nil or ValidName(e.n)) and (e.x == nil or e.x == true)
end
Registry.ValidEntry = ValidEntry

-- The most points a bond can hold at time t, begun at f: BOND_DAILY_MAX a
-- day, with a day to spare (the daily limit follows the calendar, this
-- follows 24-hour steps from f: without the spare day, points earned early
-- on a calendar day could be clamped away). Bond:Add and the migration use it
-- too, so every copy agrees. Changing BOND_DAILY_MAX or this changes what
-- peers accept: bump X-Protocol.
function Registry.LifeCap(f, t)
    return (math.floor((t - f) / DAY) + 2) * Config.BOND_DAILY_MAX
end

local function ValidLife(e)
    if type(e) ~= "table" or not ns.SaneTime(e.f) or not ns.SaneTime(e.t) or e.t < e.f then return false end
    if e.f < Config.BOND_EPOCH then return false end -- older than the addon: forged
    local p = e.p
    if type(p) ~= "number" or p ~= p or p < 0 then return false end
    return p <= Registry.LifeCap(e.f, e.t)
end
Registry.ValidLife = ValidLife

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
    if not g or not ValidKey(key) or not ns.SaneName(carer) or not ValidLife(e) then
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
function Registry:MergeName(key, namer, e)
    local g = G()
    if not g or not ValidKey(key) or not ns.SaneName(namer) or not ValidEntry(e) then
        return false
    end
    local byKey = g.names[key]
    local cur = byKey and byKey[namer]
    if cur and cur.at >= e.at then return false end
    if not byKey then byKey = {}; g.names[key] = byKey end
    byKey[namer] = { n = e.n, at = e.at, x = e.x }
    return Trim(g.names, namer, "at", Config.NAMES_PER_MEMBER, key)
end

-- Returns true when our data changed.
function Registry:MergeRecord(owner, r)
    local g = G()
    if not g or not ns.SaneName(owner) or not ValidRecord(r) then return false end
    local cur = g.claims[owner]
    if cur and cur.ts >= r.ts then return false end
    g.claims[owner] = Copy(r)
    dirty = true
    return true
end

function Registry:MergeLapse(owner, t)
    local g = G()
    if not g or not ns.SaneName(owner) or not After(t) then return false end
    if (g.lapses[owner] or 0) >= t then return false end
    g.lapses[owner] = t
    dirty = true
    return true
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
function Registry:CheckRoster()
    local g = G()
    if not g then return nil end
    local added
    for owner, r in pairs(g.claims) do
        if r.k and Active(g, owner, r) then
            local member = ns.Guild:IsMember(owner)
            local days = ns.Guild:DaysOffline(owner)
            -- Days offline only from a roster the server just sent (a cached one can be from
            -- before they came back), and not for an owner whose own record is newer than
            -- that: they've been here since (code review 2026-11-10).
            local away = days and days >= Config.INACTIVE_RELEASE_DAYS and not ns.Guild.stale
                and ns.Now() - r.ts >= Config.INACTIVE_RELEASE_DAYS * 86400
            if member == false or away then
                local t = ns.Now()
                if self:MergeLapse(owner, t) then
                    added = added or {}
                    added[owner] = t
                    ns.Log("Registry", "lapse %s (%s)", owner, member == false and "left guild" or (days .. " days offline"))
                end
            end
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

function Registry:Changed()
    dirty = true
    ns.Bus:Fire("REGISTRY")
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
local function WriteName(key, e)
    local g = G()
    local me = ns.PlayerKey()
    local prev = g.names[key] and g.names[key][me]
    -- at must grow even if two edits land in the same second.
    e.at = math.max(ns.Now(), (prev and prev.at or 0) + 1)
    g.names[key] = g.names[key] or {}
    g.names[key][me] = e
    Registry:Changed()
    ns.Bus:Fire("MY_NAME", key, e)
end

-- May the holder of r name the pet? Once their bond reaches NICKNAME_LEVEL.
function Registry:CanNickname(r)
    if not (r and r.k) then return false end
    local _, level = ns.Bond:Of(r.k)
    return (level or 0) >= Config.NICKNAME_LEVEL
end

-- ok, cleaned nickname (or error message)
function Registry:ValidNickname(nick)
    if type(nick) ~= "string" then return false, ns.L["nick.empty"] end
    nick = strtrim(nick)
    local len = ns.Utf8Len(nick)
    if len == 0 then return false, ns.L["nick.empty"] end
    if len > Config.NICKNAME_MAX_LEN then
        return false, ns.T("nick.too_long", { n = Config.NICKNAME_MAX_LEN })
    end
    if nick:find("[|\n\r]") then return false, ns.L["nick.bad_chars"] end
    return true, nick
end

------------------------------------------------------------------------------
-- Actions by this character. Each returns ok, message.
------------------------------------------------------------------------------
local function Write(r)
    local g = G()
    local me = ns.PlayerKey()
    -- ts must grow even if two edits land in the same second.
    local prev = g.claims[me]
    r.ts = math.max(ns.Now(), (prev and prev.ts or 0) + 1)
    g.claims[me] = r
    Registry:Changed()
    ns.Bus:Fire("MY_RECORD", me, r)
    return r
end

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
