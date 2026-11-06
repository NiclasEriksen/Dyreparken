local _, ns = ...

-- Guild roster snapshot, for "has this owner left / gone inactive?".
--
-- The roster is requested only when we need it (login, journal opened),
-- at most once per ROSTER_INTERVAL, and we listen to GUILD_ROSTER_UPDATE only
-- while waiting for the answer: that event fires a lot in busy guilds.
--
-- Guild.members[name] = days offline (0 = online or seen today).
-- Guild.complete: true only when we read as many rows as the server says
-- the guild has. Decisions that hide claims ("left the guild") require
-- a complete roster, so a half-loaded roster can't release anyone.
--
-- (unverified on Forever) roster name format and GetGuildRosterLastOnline;
-- `/dp probe` logs the first rows.
local Guild = { members = {}, complete = false, at = 0 }
ns.Guild = Guild

local ROSTER_INTERVAL = 300 -- seconds
local waiting

local function Read()
    local total = GetNumGuildMembers()
    local members, read = {}, 0
    for i = 1, total do
        local name = GetGuildRosterInfo(i)
        if name then
            local key = ns.NormalizeName(name)
            local years, months, days = GetGuildRosterLastOnline(i)
            -- Months are approximated as 30 days, years as 365: we only
            -- compare against a threshold measured in weeks.
            members[key] = ((years or 0) * 365) + ((months or 0) * 30) + (days or 0)
            read = read + 1
        end
    end
    Guild.members, Guild.at = members, ns.Now()
    Guild.complete = total > 0 and read == total
    ns.Log("Guild", "roster: %d/%d rows", read, total)
    ns.Bus:Fire("ROSTER")
end

function Guild:Refresh(force)
    if not IsInGuild() or waiting then return end
    if not force and ns.Now() - self.at < ROSTER_INTERVAL then return end
    waiting = true
    ns.Events:On("GUILD_ROSTER_UPDATE", Guild, function()
        ns.Events:Off("GUILD_ROSTER_UPDATE", Guild)
        waiting = false
        Read()
    end)
    C_GuildInfo.GuildRoster()
    -- If the server ignores the request (it's throttled), don't wait forever.
    C_Timer.After(15, function()
        if waiting then
            ns.Events:Off("GUILD_ROSTER_UPDATE", Guild)
            waiting = false
            if GetNumGuildMembers() > 0 then Read() end
        end
    end)
end

-- true / false, or nil when we don't know (no complete roster yet).
function Guild:IsMember(name)
    if self.members[name] then return true end
    if self.complete then return false end
    return nil
end

function Guild:DaysOffline(name)
    return self.members[name]
end
