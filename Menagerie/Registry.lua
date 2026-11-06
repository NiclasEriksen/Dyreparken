local _, ns = ...

-- The guild's companion reservations.
--
-- DATA MODEL: one record per character, written only by that character.
--   g.claims[owner] = { k = petKey|nil, at = claimTime, ts = editTime, n = nick?, na = nickTime? }
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

local function G()
    return ns.DB:Guild()
end

------------------------------------------------------------------------------
-- Validation and merge
------------------------------------------------------------------------------
local function ValidRecord(r)
    if type(r) ~= "table" or type(r.ts) ~= "number" or type(r.at) ~= "number" then return false end
    if r.k ~= nil and (type(r.k) ~= "string" or #r.k > 64) then return false end
    if r.n ~= nil and (type(r.n) ~= "string" or ns.Utf8Len(r.n) > Config.NICKNAME_MAX_LEN or r.n:find("[|\n\r]")) then
        return false
    end
    if r.na ~= nil and type(r.na) ~= "number" then return false end
    return true
end

local function Copy(r)
    return { k = r.k, at = r.at, ts = r.ts, n = r.n, na = r.na }
end

-- Returns true when our data changed.
function Registry:MergeRecord(owner, r)
    local g = G()
    if not g or type(owner) ~= "string" or owner == "" or not ValidRecord(r) then return false end
    local cur = g.claims[owner]
    if cur and cur.ts >= r.ts then return false end
    g.claims[owner] = Copy(r)
    dirty = true
    return true
end

function Registry:MergeLapse(owner, t)
    local g = G()
    if not g or type(owner) ~= "string" or type(t) ~= "number" then return false end
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
    local g = G()
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

function Registry:Changed()
    dirty = true
    ns.Bus:Fire("REGISTRY")
end

-- owner, record for a pet key, or nil if free.
function Registry:Holder(key)
    if dirty then Rebuild() end
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
    if not g then return {}, {} end
    return g.claims, g.lapses
end

-- Number of distinct pets held.
function Registry:Count()
    if dirty then Rebuild() end
    local n = 0
    for _ in pairs(holders) do n = n + 1 end
    return n
end

function Registry:Holders()
    if dirty then Rebuild() end
    return holders
end

------------------------------------------------------------------------------
-- Nicknames
------------------------------------------------------------------------------
function Registry:NicknameUnlocksAt(r)
    return r.at + Config.NICKNAME_UNLOCK_DAYS * DAY
end

function Registry:CanNickname(r)
    return r and r.k and ns.Now() >= self:NicknameUnlocksAt(r)
end

-- ok, cleaned nickname (or error message)
function Registry:ValidNickname(nick)
    if type(nick) ~= "string" then return false, "No nickname given." end
    nick = strtrim(nick)
    local len = ns.Utf8Len(nick)
    if len == 0 then return false, "No nickname given." end
    if len > Config.NICKNAME_MAX_LEN then
        return false, ("Nicknames can be at most %d characters."):format(Config.NICKNAME_MAX_LEN)
    end
    if nick:find("[|\n\r]") then return false, "Nicknames can't contain | or line breaks." end
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
    if not g then return false, "You're not in a guild." end
    if not key then return false, "Unknown companion." end
    if not ns.Pets:Owned()[key] then return false, "You don't have that companion." end
    local owner = self:Holder(key)
    local me = ns.PlayerKey()
    if owner == me then return false, "It's already yours." end
    if owner then return false, ("%s is already caring for it."):format(owner) end
    local mine = self:MyPet()
    Write({ k = key, at = ns.Now() })
    ns.Log("Registry", "claim %s (was %s)", key, tostring(mine))
    return true, mine and ("You adopted %s (and let %s go)."):format(ns.Pets:NameOfKey(key), ns.Pets:NameOfKey(mine))
        or ("You adopted %s."):format(ns.Pets:NameOfKey(key))
end

function Registry:Release()
    local r = self:MyRecord()
    if not r or not r.k then return false, "You haven't adopted a companion." end
    local key = r.k
    Write({ at = r.at })
    ns.Log("Registry", "release %s", key)
    return true, ("You let %s go."):format(ns.Pets:NameOfKey(key))
end

function Registry:SetNickname(nick)
    local key, r = self:MyPet()
    if not key then return false, "You haven't adopted a companion." end
    if not self:CanNickname(r) then
        return false, ("You can name it from %s."):format(date("%d %b %Y", self:NicknameUnlocksAt(r)))
    end
    local clear = nick == nil or strtrim(nick) == ""
    local ok, clean = true, nil
    if not clear then
        ok, clean = self:ValidNickname(nick)
        if not ok then return false, clean end
    end
    Write({ k = r.k, at = r.at, n = clean, na = clean and ns.Now() or nil })
    return true, clean and ('Nickname set to "%s".'):format(clean) or "Nickname cleared."
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
        ns.Print(("Your %s went back to the park after your long absence. Adopt it again if it's still free."):format(name))
    else
        ns.Print(("%s adopted %s just before you did, so it went home with them."):format(owner or "?", name))
    end
    Write({ at = r.at })
    return true
end
