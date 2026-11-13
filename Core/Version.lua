local _, ns = ...

-- Version awareness.
--  * On login we send HELLO to the guild with our version and protocol.
--    Peers on a newer version reply nothing; we learn from theirs.
--  * Seeing a newer version (or a different protocol) prints ONE line,
--    once per version, remembered in DyreparkenCharDB.warnedVersion.
--  * VER_REQ: clients on 0.2.x can ask the guild/group for versions (the
--    command was removed 2026-11-09); we still answer VER on that channel.
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
    -- HELLO is only ever sent to the guild (Hello below). One by party or whisper is someone
    -- else's doing, and isn't heeded. Checked here, not with Register's `from`: that's part of
    -- the protocol fingerprint (spec 52) and would need an X-Protocol bump.
    ns.Comm:Register("HELLO", function(msg, sender, channel)
        if channel == "GUILD" then NoteVersion(sender, msg.v) end
    end)
    ns.Comm:Register("VER", function(msg, sender)
        NoteVersion(sender, msg.v)
    end, nil, { v = "version" })
    -- Answer on the channel the request came from. (Whispers would be
    -- quieter, but whisper targets with surnames are unverified on Forever.)
    -- Everyone hearing everyone's version is useful anyway: NoteVersion.
    ns.Comm:Register("VER_REQ", function(_, _, channel)
        if channel == "WHISPER" or not ns.Comm:MayReply("VER", channel) then return end
        ns.Comm:Send("VER", { v = ns.VERSION }, channel)
    end)
    ns.Bus:On("PROTOCOL_MISMATCH", function(sender, theirs, msg, channel)
        if msg.k == "HELLO" and channel ~= "GUILD" then return end
        NoteVersion(sender, msg.v)
    end)
end

function Version:Hello()
    -- d: registry digest, so peers can tell whether we need a sync (Sync.lua).
    if IsInGuild() then ns.Comm:Send("HELLO", { v = ns.VERSION, d = ns.Sync:Digest() }, "GUILD") end
end

ns.Start("loaded", function() Version:Init() end)
ns.Start("hello", function() Version:Hello() end)
