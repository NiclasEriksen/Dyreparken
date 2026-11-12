-- The guild: membership, rank, the roster (from the World), honor, C_GuildInfo.
local H, P = ...
local KNOWN_EVENTS = P.KNOWN_EVENTS

return function(c, env, S)
    local w = c.world
    -- Guild
    env.IsInGuild = function() return c.guild ~= nil end
    local RANKS = { [0] = "Guild Master", [1] = "Officer" }
    env.GetGuildInfo = function(u) if c.guild then return c.guild, RANKS[c.rank] or "Member", c.rank, nil end end
    env.IsGuildLeader = function() return c.guild ~= nil and c.rank == 0 end
    local function Rows() return c.guild and w:Roster(c.guild) or {} end
    env.GetNumGuildMembers = function()
        local rows, online = Rows(), 0
        for _, r in ipairs(rows) do if r.online then online = online + 1 end end
        return #rows, online, online
    end
    env.GetGuildRosterInfo = function(i)
        if c.rosterPartial and i > c.rosterPartial then return nil end
        local r = Rows()[i]
        if r then return r.name, "Member", 3, 60, "Warrior", "Elwynn Forest", "", "", r.online end
    end
    -- (years, months, days, hours) for offline members, nil when online.
    env.GetGuildRosterLastOnline = function(i)
        local r = Rows()[i]
        if not r or r.online then return nil end
        local d = r.days
        return math.floor(d / 365), math.floor((d % 365) / 30), (d % 365) % 30, 0
    end
    -- Honorable kills, honor (S.hk, S.honor); lifetime: kills, highest rank.
    env.TakeTaxiNode = function(i) S.taxi = i end
    env.GetPVPSessionStats = function() return S.hk or 0, S.honor or 0 end
    env.GetPVPLifetimeStats = function() return S.lifetimeHK or 0, 0 end
    env.C_EventUtils = { IsEventValid = function(e) return KNOWN_EVENTS[e] == true end }
    env.C_GuildInfo = { IsGuildOfficer = function() return c.guild ~= nil and c.rank <= 1 end,
        GuildRoster = function()
        c.rosterRequests = (c.rosterRequests or 0) + 1
        if c.rosterIgnored then return end
        w:Timer(c, 0.3, function() c:Fire("GUILD_ROSTER_UPDATE", false) end)
    end }

end
