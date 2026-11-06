local _, ns = ...

-- The guild's companion reservations.
--
-- Rules (from the design doc and decisions so far):
--  * A reservation claims one pet key (species) guild-wide for one character.
--  * Each character holds at most one; picking another releases the old one.
--  * First come, first served by server timestamp `at` (GetServerTime), not
--    by who synced first. Ties break on owner name, so everyone agrees.
--  * Released when the owner leaves the guild roster, or hasn't been seen
--    for Config.INACTIVE_RELEASE_DAYS.
--  * Nicknames unlock after Config.NICKNAME_UNLOCK_DAYS of ownership, max
--    Config.NICKNAME_MAX_LEN characters.
--
-- record = { owner = "Name-Realm", at = t, rev = n, nick = s?, nickAt = t? }
-- `rev` counts edits by the owner (nickname changes, release) so a newer
-- edit of the same claim wins over an older copy.
--
-- Sync (TODO, protocol sketch):
--   HELLO already announces us. Then:
--   DIGEST { h = hash of registry }  -> on mismatch peers exchange
--   CLAIMS { list of records }       (chunked by Comm)
--   CLAIM / RELEASE / NICK           single-record updates, sent to GUILD
-- Merge is deterministic (Registry:Merge), so the order messages arrive in
-- doesn't matter.
local Registry = {}
ns.Registry = Registry

local function Better(a, b)
    -- Does record a beat record b for the same pet key?
    if a.owner == b.owner then return (a.rev or 0) > (b.rev or 0) end
    if a.at ~= b.at then return a.at < b.at end
    return a.owner < b.owner
end
Registry.Better = Better

-- Merge one incoming record. Returns true if our view changed.
function Registry:Merge(key, incoming)
    local g = ns.DB:Guild()
    if not g or type(incoming) ~= "table" or type(incoming.owner) ~= "string" or type(incoming.at) ~= "number" then
        return false
    end
    local current = g.pets[key]
    if current and not Better(incoming, current) then return false end
    g.pets[key] = incoming
    ns.Bus:Fire("REGISTRY", key)
    return true
end

function Registry:Get(key)
    local g = ns.DB:Guild()
    return g and g.pets[key]
end

-- The pet key this character has reserved, if any.
function Registry:Mine()
    local g = ns.DB:Guild()
    if not g then return nil end
    local me = ns.PlayerKey()
    for key, rec in pairs(g.pets) do
        if rec.owner == me then return key, rec end
    end
end

function Registry:CanNickname(rec)
    return rec and (ns.Now() - rec.at) >= ns.Config.NICKNAME_UNLOCK_DAYS * 86400
end

function Registry:ValidNickname(nick)
    if type(nick) ~= "string" then return false end
    nick = strtrim(nick)
    local len = ns.Utf8Len(nick)
    return len > 0 and len <= ns.Config.NICKNAME_MAX_LEN and not nick:find("[|\n\r]"), nick
end

function Registry:Claim(key)    -- TODO
end
function Registry:Release()     -- TODO
end
function Registry:SetNickname(nick) -- TODO
end
-- Drop records whose owner left the guild or went inactive. Needs the guild
-- roster (GUILD_ROSTER_UPDATE after C_GuildInfo.GuildRoster()); run rarely.
function Registry:Prune()       -- TODO
end
