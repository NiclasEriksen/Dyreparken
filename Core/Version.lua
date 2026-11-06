local _, ns = ...

-- Version awareness.
--  * On login we send HELLO to the guild with our version and protocol.
--    Peers on a newer version reply nothing; we learn from theirs.
--  * Seeing a newer version (or a different protocol) prints ONE line,
--    once per version, remembered in DyreparkenCharDB.warnedVersion.
--  * /dp version: anyone may ask the guild/group for versions (VER_REQ);
--    everyone whispers back VER (BULK priority, so it doesn't block traffic).
local Version = { seen = {} } -- seen[player] = version
ns.Version = Version

local function NoteVersion(sender, version)
    if type(version) ~= "string" then return end
    Version.seen[sender] = version
    if ns.CompareVersions(version, ns.VERSION) > 0 then
        local warned = ns.DB.char.warnedVersion
        if not warned or ns.CompareVersions(version, warned) > 0 then
            ns.DB.char.warnedVersion = version
            ns.Print(("A newer version (%s) is available; you have %s."):format(version, ns.VERSION))
        end
    end
end

function Version:Init()
    ns.Comm:Register("HELLO", function(msg, sender) NoteVersion(sender, msg.v) end)
    ns.Comm:Register("VER", function(msg, sender)
        NoteVersion(sender, msg.v)
        if Version.collecting then Version.collecting[sender] = msg.v end
    end)
    -- Answer by whisper, so a guild-wide check doesn't make everyone receive
    -- everyone's reply.
    ns.Comm:Register("VER_REQ", function(_, sender)
        ns.Comm:Send("VER", { v = ns.VERSION }, "WHISPER", sender, "BULK")
    end)
    ns.Bus:On("PROTOCOL_MISMATCH", function(sender, theirs, msg)
        if type(msg.v) == "string" then NoteVersion(sender, msg.v) end
    end)
end

function Version:Hello()
    if IsInGuild() then ns.Comm:Send("HELLO", { v = ns.VERSION }, "GUILD", nil, "BULK") end
end

-- channel: "GUILD" or "RAID"/"PARTY". Prints results after a few seconds.
function Version:Check(channel)
    self.collecting = { [ns.PlayerKey()] = ns.VERSION }
    if not ns.Comm:Send("VER_REQ", {}, channel) then
        ns.Print("Not in a " .. channel:lower() .. ".")
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
        ns.Print(("Version check (%s): %d with the addon"):format(channel, #list))
        for _, r in ipairs(list) do ns.Print("  " .. r.name .. ": " .. r.v) end
        -- TODO: list group/guild members that didn't answer (no addon).
    end)
end
