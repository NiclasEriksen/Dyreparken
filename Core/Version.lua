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

local function NoteVersion(sender, version)
    if type(version) ~= "string" then return end
    Version.seen[sender] = version
    if ns.DEV then return end -- a git checkout: nothing to update to
    if ns.CompareVersions(version, ns.VERSION) > 0 then
        local warned = ns.DB.char.warnedVersion
        if not warned or ns.CompareVersions(version, warned) > 0 then
            ns.DB.char.warnedVersion = version
            ns.Print(("En nyere versjon (%s) er ute; du har %s."):format(version, ns.VERSION))
        end
    end
end

function Version:Init()
    ns.Comm:Register("HELLO", function(msg, sender) NoteVersion(sender, msg.v) end)
    ns.Comm:Register("VER", function(msg, sender)
        NoteVersion(sender, msg.v)
        if Version.collecting then Version.collecting[sender] = msg.v end
    end)
    -- Answer on the channel the request came from. (Whispers would be
    -- quieter, but whisper targets with surnames are unverified on Forever.)
    -- Everyone hearing everyone's version is useful anyway: NoteVersion.
    ns.Comm:Register("VER_REQ", function(_, _, channel)
        if channel == "WHISPER" then return end
        ns.Comm:Send("VER", { v = ns.VERSION }, channel, nil, "BULK")
    end)
    ns.Bus:On("PROTOCOL_MISMATCH", function(sender, theirs, msg)
        if type(msg.v) == "string" then NoteVersion(sender, msg.v) end
    end)
end

function Version:Hello()
    -- d: registry digest, so peers can tell whether we need a sync (Sync.lua).
    if IsInGuild() then ns.Comm:Send("HELLO", { v = ns.VERSION, d = ns.Sync:Digest() }, "GUILD", nil, "BULK") end
end

-- channel: "GUILD" or "RAID"/"PARTY". Prints results after a few seconds.
function Version:Check(channel)
    self.collecting = { [ns.PlayerKey()] = ns.VERSION }
    if not ns.Comm:Send("VER_REQ", {}, channel) then
        ns.Print(channel == "GUILD" and "Du er ikke i en guild." or "Du er ikke i en gruppe.")
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
        local where = { GUILD = "guild", PARTY = "gruppe", RAID = "raid" }
        ns.Print(("Versjonssjekk (%s): %d med addonen"):format(where[channel] or channel, #list))
        for _, r in ipairs(list) do ns.Print("  " .. r.name .. ": " .. r.v) end
        -- TODO: list group/guild members that didn't answer (no addon).
    end)
end
