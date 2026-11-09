local _, ns = ...

-- Version awareness.
--  * On login we send HELLO to the guild with our version and protocol.
--    Peers on a newer version reply nothing; we learn from theirs.
--  * Seeing a newer version (or a different protocol) prints ONE line,
--    once per version, remembered in DyreparkenCharDB.warnedVersion.
--  * /dp version: anyone may ask the guild/group for versions (VER_REQ);
--    everyone answers VER on the same channel (BULK priority).
local Version = { seen = {} } -- seen[player] = version
ns.Version = Version

-- A version from the wire, as the packager makes them ("0.2.1", "0.2.1-beta2",
-- "dev"). Anything else is junk, and may not reach the chat: a "|" there
-- is an escape code (icons, links), and a table would throw on printing
-- (code review 2026-11-09).
local function Sane(v)
    return type(v) == "string" and #v <= 32 and v:find("^[%w%.%-]+$") ~= nil
end
Version.Sane = Sane

local function NoteVersion(sender, version)
    if not Sane(version) then return end
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
    ns.Comm:Register("HELLO", function(msg, sender) NoteVersion(sender, msg.v) end)
    ns.Comm:Register("VER", function(msg, sender)
        NoteVersion(sender, msg.v)
        if Version.collecting then Version.collecting[sender] = Sane(msg.v) and msg.v or "?" end
    end)
    -- Answer on the channel the request came from. (Whispers would be
    -- quieter, but whisper targets with surnames are unverified on Forever.)
    -- Everyone hearing everyone's version is useful anyway: NoteVersion.
    ns.Comm:Register("VER_REQ", function(_, _, channel)
        if channel == "WHISPER" or not ns.Comm:MayReply("VER", channel) then return end
        ns.Comm:Send("VER", { v = ns.VERSION }, channel)
    end)
    ns.Bus:On("PROTOCOL_MISMATCH", function(sender, theirs, msg)
        NoteVersion(sender, msg.v)
    end)
end

function Version:Hello()
    -- d: registry digest, so peers can tell whether we need a sync (Sync.lua).
    if IsInGuild() then ns.Comm:Send("HELLO", { v = ns.VERSION, d = ns.Sync:Digest() }, "GUILD") end
end

-- channel: "GUILD" or "RAID"/"PARTY". Prints results after a few seconds.
function Version:Check(channel)
    self.collecting = { [ns.PlayerKey()] = ns.VERSION }
    if not ns.Comm:Send("VER_REQ", {}, channel) then
        ns.Print(ns.L[channel == "GUILD" and "version.no_guild" or "version.no_group"])
        self.collecting = nil
        return
    end
    C_Timer.After(5, function()
        local results = self.collecting
        self.collecting = nil
        local list = {}
        for name, v in pairs(results) do list[#list + 1] = { name = name, v = v } end
        table.sort(list, function(a, b)
            local c = ns.CompareVersions(a.v, b.v)
            if c ~= 0 then return c > 0 end
            return a.name < b.name
        end)
        ns.Print(ns.T("version.head", { where = ns.L["version.where." .. channel], n = #list }))
        for _, r in ipairs(list) do ns.Print("  " .. r.name .. ": " .. r.v) end
        -- TODO: list group/guild members that didn't answer (no addon).
    end)
end

ns.Start("loaded", function() Version:Init() end)
ns.Start("hello", function() Version:Hello() end)
