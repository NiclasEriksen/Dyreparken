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
--     Someone saw this owner inactive for INACTIVE_RELEASE_DAYS, or missing
--     from a complete guild roster. Claims made before the lapse are void for
--     good, so a returning player doesn't take back a pet someone else picked
--     up meanwhile; they have to claim it again. Merges by max.
--
-- WHO HOLDS A PET is derived, never stored: among valid records claiming
-- it, the earliest `at` wins (ties: lower owner name). Every client gets the
-- same answer from the same data, whatever order the messages arrived in.
--
-- NICKNAMES belong to the pet, not to an adoption: the name stays when its
-- carer lets go, and the next carer may rename it once they've cared for it
-- NICKNAME_UNLOCK_DAYS. Each naming is its own entry, written only by the
-- one who named it:
--   g.names[petKey][namer] = { n = nick|nil, at = when, x = true? }
--     n nil: the namer cleared the name. x: void (the namer lost an adoption
--     race and never really held the pet, see CheckMine). Merges by highest at.
-- THE NAME of a pet is derived like the holder: the newest entry that isn't
-- void and was set either by the current holder or before their adoption
-- began. So a name set by someone who didn't hold the pet at the time (a
-- partition, a forged entry) can't override the holder's.
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
local function ValidRecord(r)
    if type(r) ~= "table" or not ns.SaneTime(r.ts) or not ns.SaneTime(r.at) then return false end
    if r.k ~= nil and (type(r.k) ~= "string" or #r.k > 64) then return false end
    return true
end

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
    return type(e) == "table" and ns.SaneTime(e.at)
        and (e.n == nil or ValidName(e.n)) and (e.x == nil or e.x == true)
end

-- Returns true when our data changed.
function Registry:MergeName(key, namer, e)
    local g = G()
    if not g or type(key) ~= "string" or #key > 64 or not ns.SaneName(namer) or not ValidEntry(e) then
        return false
    end
    local byKey = g.names[key]
    local cur = byKey and byKey[namer]
    if cur and cur.at >= e.at then return false end
    if not byKey then byKey = {}; g.names[key] = byKey end
    byKey[namer] = { n = e.n, at = e.at, x = e.x }
    return true
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
    if not g or not ns.SaneName(owner) or not ns.SaneTime(t) then return false end
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
            if member == false or (days and days >= Config.INACTIVE_RELEASE_DAYS) then
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

-- The pet this character holds (won), if any: key, record.
function Registry:MyPet()
    local g = G()
    if not g then return nil end
    local me = ns.PlayerKey()
    local r = g.claims[me]
    if r and r.k and self:Holder(r.k) == me then return r.k, r end
end

function Registry:MyRecord()
    local g = G()
    return g and g.claims[ns.PlayerKey()]
end

-- Snapshot for sync and digests.
function Registry:All()
    local g = G()
    if not g then return {}, {}, {} end
    return g.claims, g.lapses, g.names
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
function Registry:NicknameUnlocksAt(r)
    return r.at + Config.NICKNAME_UNLOCK_DAYS * DAY
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

function Registry:CanNickname(r)
    return r and r.k and ns.Now() >= self:NicknameUnlocksAt(r)
end

-- ok, cleaned nickname (or error message)
function Registry:ValidNickname(nick)
    if type(nick) ~= "string" then return false, "Du har ikke skrevet noe kallenavn." end
    nick = strtrim(nick)
    local len = ns.Utf8Len(nick)
    if len == 0 then return false, "Du har ikke skrevet noe kallenavn." end
    if len > Config.NICKNAME_MAX_LEN then
        return false, ("Kallenavn kan ha maks %d tegn."):format(Config.NICKNAME_MAX_LEN)
    end
    if nick:find("[|\n\r]") then return false, "Kallenavn kan ikke inneholde | eller linjeskift." end
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
    if not g then return false, "Du er ikke i en guild." end
    if not key then return false, "Ukjent kjæledyr." end
    if not ns.Pets:Owned()[key] then return false, "Du har ikke det kjæledyret." end
    local owner = self:Holder(key)
    local me = ns.PlayerKey()
    if owner == me then return false, "Det bor allerede hos deg." end
    if owner then return false, ("Det bor allerede hos %s."):format(owner) end
    local mine = self:MyPet()
    Write({ k = key, at = ns.Now() })
    ns.Log("Registry", "claim %s (was %s)", key, tostring(mine))
    local msg = mine and ("Du adopterte %s (og ga slipp på %s)."):format(ns.Pets:NameOfKey(key), ns.Pets:NameOfKey(mine))
        or ("Du adopterte %s."):format(ns.Pets:NameOfKey(key))
    -- A name it got from an earlier carer comes along: introduce it.
    local nick, namer = self:Nickname(key)
    if nick then
        msg = msg .. (namer == me and (" Det heter fortsatt «%s»."):format(nick)
            or (" Det heter «%s», et navn det fikk av %s. Ta godt vare på det!"):format(nick, namer))
    end
    return true, msg
end

function Registry:Release()
    local r = self:MyRecord()
    if not r or not r.k then return false, "Du har ikke adoptert noe kjæledyr." end
    local key = r.k
    Write({ at = r.at })
    ns.Log("Registry", "release %s", key)
    return true, ("Du ga slipp på %s."):format(ns.Pets:NameOfKey(key))
end

function Registry:SetNickname(nick)
    local key, r = self:MyPet()
    if not key then return false, "Du har ikke adoptert noe kjæledyr." end
    if not self:CanNickname(r) then
        return false, ("Du kan gi det et kallenavn fra %s."):format(date("%d.%m.%Y", self:NicknameUnlocksAt(r)))
    end
    local clear = nick == nil or strtrim(nick) == ""
    local ok, clean = true, nil
    if not clear then
        ok, clean = self:ValidNickname(nick)
        if not ok then return false, clean end
    end
    if self:Nickname(key) == clean then
        return false, clean and ("Det heter allerede «%s»."):format(clean) or "Det har ikke noe kallenavn."
    end
    WriteName(key, { n = clean })
    return true, clean and ("Kallenavnet er nå «%s»."):format(clean) or "Kallenavnet er fjernet."
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
        ns.Print(("%s gikk tilbake til parken mens du var lenge borte. Adopter det igjen hvis det fortsatt er ledig."):format(name))
    else
        ns.Print(("%s rakk å adoptere %s rett før deg, så det bor der nå."):format(owner or "?", name))
        -- We never really held it, so a name we gave it meanwhile doesn't count.
        local mine = g.names[r.k] and g.names[r.k][me]
        if mine and not mine.x and mine.at >= r.at then WriteName(r.k, { x = true }) end
    end
    Write({ at = r.at })
    return true
end
