local _, ns = ...

-- Guild roster snapshot, for "has this owner left / gone inactive?".
--
-- The roster is requested only when we need it (login, journal opened),
-- at most once per Config.ROSTER_INTERVAL, and we listen to GUILD_ROSTER_UPDATE only
-- while waiting for the answer: that event fires a lot in busy guilds.
--
-- Guild.members[name] = days offline (0 = online or seen today).
-- Guild.complete: true only when we read as many rows as the server says
-- the guild has. Decisions that hide claims ("left the guild") require
-- a complete roster, so a half-loaded (or stale) roster can't release anyone.
--
-- Guild.known, Guild.knownAt: the members of the last complete roster the
-- server sent, and when it was read. The sync keeps only members' data
-- (Registry: Admit, Prune), and a stale or partial read later must not turn
-- that off.
--
-- (unverified on Forever) roster name format and GetGuildRosterLastOnline;
-- `/dp probe` logs the first rows.
local Guild = { members = {}, complete = false, at = 0 }
ns.Guild = Guild

local waiting

-- stale: the server didn't answer our request, so this is whatever the
-- client had cached. Someone who joined since would be missing, so it never
-- counts as complete, and days offline from it lapse nobody (Registry).
local function Read(stale)
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
    Guild.members, Guild.at, Guild.stale = members, ns.Now(), stale or false
    Guild.complete = not stale and total > 0 and read == total
    if Guild.complete then Guild.known, Guild.knownAt = members, Guild.at end
    ns.Log("Guild", "roster: %d/%d rows", read, total)
    ns.Bus:Fire("ROSTER")
end

function Guild:Refresh(force)
    if not IsInGuild() or waiting then return end
    if not force and ns.Now() - self.at < ns.Config.ROSTER_INTERVAL then return end
    waiting = true
    ns.Events:On("GUILD_ROSTER_UPDATE", Guild, function()
        ns.Events:Off("GUILD_ROSTER_UPDATE", Guild)
        waiting = false
        Read()
    end)
    C_GuildInfo.GuildRoster()
    -- If the server ignores the request (it's throttled), don't wait forever.
    C_Timer.After(ns.Config.ROSTER_TIMEOUT, function()
        if waiting then
            ns.Events:Off("GUILD_ROSTER_UPDATE", Guild)
            waiting = false
            if GetNumGuildMembers() > 0 then Read(true) end
        end
    end)
end

-- A roster read soon, but no sooner than Config.ROSTER_INTERVAL after the
-- last: for data about someone the last complete roster doesn't list (a new
-- member, or one who left; Registry holds it until then), and for a SYNC
-- that leaves us differing (our roster may be the older one). One at a time.
local soon
function Guild:Soon()
    if soon or not IsInGuild() then return end
    soon = true
    C_Timer.After(math.max(1, self.at + ns.Config.ROSTER_INTERVAL - ns.Now()), function()
        soon = false
        Guild:Refresh(true)
    end)
end

-- true / false, or nil when we don't know (no complete roster yet).
function Guild:IsMember(name)
    if self.members[name] then return true end
    if self.complete then return false end
    return nil
end

-- An officer or the guild leader (C_GuildInfo.IsGuildOfficer works on
-- Forever, docs/FOREVER_API.md).
function Guild:IsOfficer()
    local GI = C_GuildInfo
    return (GI and GI.IsGuildOfficer and GI.IsGuildOfficer()) or (IsGuildLeader and IsGuildLeader()) or false
end

function Guild:DaysOffline(name)
    return self.members[name]
end

-- Roster first: an answer arrives before peers' SYNCs need it.
ns.Start("settled", function() Guild:Refresh(true) end)
