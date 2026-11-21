---@class Dyreparken
local ns = select(2, ...)

-- Version awareness.
--  * On login we send HELLO to the guild with our version and protocol.
--    Peers on a newer version reply nothing; we learn from theirs.
--  * Seeing a newer version from the guild prints ONE line, once per version, remembered in
--    DyreparkenCharDB.warnedVersion. Only the guild channel counts (code review 2026-11-15: a stranger's
--    whisper or a party's message could print a forged notice and, remembered, silence the real ones).
--  * An older client's messages on another protocol (Comm's PROTOCOL_MISMATCH) carry its version too: a 0.5
--    client's VER, say. (Answering 0.2.x clients' VER_REQ went at X-Protocol 12, 2026-11-17: their protocol,
--    9, has been under the floor since 0.6.0, so none of it reached us.)
---@class Dyreparken.Version
local Version = { seen = {} } -- seen[player] = version
ns.Version = Version

-- A version from the wire (Wire.Version): junk never reaches the chat.
local Sane = ns.Wire.Version
Version.Sane = Sane

-- A version a release could be: at most one major ahead of ours. Remembered as warned, a forged "999.0" would make every real
-- release compare lower and silence the notice for good (code review 2026-11-13). No cap on the
-- minors: a player many releases behind must still hear of the newest (only the guild's HELLO
-- counts, so a forger would have to be a guildmate).
local function MajorMinor(v)
    local a, b = tostring(v):match("^v?(%d+)%.(%d+)")
    return tonumber(a), tonumber(b)
end
function Version.Plausible(version)
    local ma = MajorMinor(version)
    local oa = MajorMinor(ns.VERSION)
    if not (ma and oa) then return true end -- "dev" compares equal to everything anyway
    return ma <= oa + 1
end

local function NoteVersion(sender, version)
    if not Sane(version) then return end
    if not Version.Plausible(version) then
        ns.Log("Version", "%s says %s: too far ahead of ours, ignored", sender, version)
        return
    end
    Version.seen[sender] = version
    if ns.DEV then return end -- a git checkout: nothing to update to
    if ns.CompareVersions(version, ns.VERSION) > 0 then
        local warned = ns.DB.char.warnedVersion
        if not warned or ns.CompareVersions(version, warned) > 0 then
            ns.DB.char.warnedVersion = version
            ns.Print(ns.T("version.newer", { theirs = version, mine = ns.VERSION }))
        end
    end
end

function Version:Init()
    -- HELLO is only ever sent to the guild (Hello below): one by party or whisper is someone else's doing.
    ns.Comm:Register("HELLO", function(msg, sender) NoteVersion(sender, msg.v) end, "GUILD")
    ns.Bus:On("PROTOCOL_MISMATCH", function(sender, theirs, msg, channel)
        if channel ~= "GUILD" then return end -- (any kind: a forger outside the guild can't reach the notice)
        NoteVersion(sender, msg.v)
    end)
end

local said -- the guild our HELLO went to (nil: none, or its name wasn't known yet)
function Version:Hello()
    -- d: registry digest, so peers can tell whether we need a sync (Sync.lua); o: who owns what (Owners.lua,
    -- X-Protocol 11; a 0.7 client reads the rest as before).
    if not IsInGuild() then return end
    said = select(2, ns.DB:Guild())
    ns.Comm:Send("HELLO", { v = ns.VERSION, d = ns.Sync:Digest(), o = ns.Owners:Digest() }, "GUILD")
end

-- A guild that comes after the login's HELLO (review 2026-11-19): its name not yet known then (the HELLO carried
-- an empty digest, and the SYNCs that answered had nowhere to go), or joined in the middle of a session. The
-- roster, our owned pets and the HELLO again, for it. PLAYER_GUILD_UPDATE is rare (membership, ranks), and a
-- guild we already said hello to is let be.
function Version:Rejoin()
    local _, name = ns.DB:Guild()
    if not IsInGuild() or not name or name == said then return end
    ns.Log("Version", "guild %s, after the login's hello: its start again", name)
    ns.Guild:Refresh(true)
    ns.Owners:Update()
    ns.Registry:CheckMine()
    self:Hello()
end

ns.Start("loaded", function() Version:Init() end)
ns.Start("hello", function()
    Version:Hello()
    ns.Events:On("PLAYER_GUILD_UPDATE", Version, ns.Debounce(2, function() Version:Rejoin() end))
    -- A roster read too (review 2026-11-21): whether the client fires PLAYER_GUILD_UPDATE when a late name comes
    -- is unverified, and opening the journal reads the roster. Nothing to do once the HELLO went to this guild.
    ns.Bus:On("ROSTER", function() Version:Rejoin() end)
end)
