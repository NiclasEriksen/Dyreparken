local _, ns = ...

-- Research probes (debug log only). What's settled lives in Core/Activity.lua
-- now, which logs every activity with its pet while the debug log is on:
-- bosses, quests, the traits' events (2026-11-08, docs/FOREVER_API.md).
-- Still open: honorable kills. While the debug log is on, each
-- PLAYER_PVP_KILLS_CHANGED logs its payload, the companion and the PvP stats.
--
-- `/dp probe kills`: which kill events the client knows, the PvP stats.
-- `/dp probe life`: which events, functions and chat formats the traits
-- read exist, and the context a trait's moment sees.
local Kills = {}
ns.Kills = Kills

local EVENTS = { "ENCOUNTER_END", "PLAYER_PVP_KILLS_CHANGED", "QUEST_TURNED_IN" } -- (probe kills lists them)
local LISTEN = { "PLAYER_PVP_KILLS_CHANGED" } -- (only this one is still open)

local function Show(v)
    if ns.IsSecret(v) then return "<secret>" end
    return tostring(v)
end

local function Args(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = Show((select(i, ...))) end
    return table.concat(parts, ", ")
end

local function Valid(list, parts)
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    for _, e in ipairs(list) do parts[#parts + 1] = e .. "=" .. (valid and tostring(valid(e)) or "?") end
    return parts
end

local function Report(name, parts, tail)
    local msg = ("%s probe: %s | %s | debug log %s"):format(name, table.concat(parts, " "), tail,
        ns.Debug.enabled and "on (listening)" or "OFF: /dp debug on to listen")
    ns.Print(msg)
    ns.Log("Probe", "%s", msg)
end

-- The summoned companion as the client reports it right now.
function Kills:PetState()
    local ok, guid = pcall(C_PetJournal.GetSummonedPetGUID)
    if not ok then return "error: " .. tostring(guid) end
    if guid == nil then return "none" end
    if ns.IsSecret(guid) then return "<secret>" end
    local key = ns.Pets:KeyOf(guid)
    return ("%s (%s)"):format(tostring(key), key and ns.Pets:NameOfKey(key) or "?")
end

local function Stats()
    local function Call(fn)
        if type(fn) ~= "function" then return "missing" end
        local ok, a, b, c = pcall(fn)
        if not ok then return "error" end
        return Args(a, b, c)
    end
    return ("session=[%s] lifetime=[%s]"):format(Call(GetPVPSessionStats), Call(GetPVPLifetimeStats))
end

local KILLS = {} -- our owner key for ns.Events

local function OnEvent(_, event, ...)
    ns.Log("Kills", "%s (%s) combat=%s pet=%s pvp %s", event, Args(...), tostring(ns.InCombat()),
        Kills:PetState(), Stats())
end

-- Listen while the debug log is on; idle otherwise.
function Kills:Sync(on)
    for _, e in ipairs(LISTEN) do
        if on then ns.Events:On(e, KILLS, OnEvent) else ns.Events:Off(e, KILLS) end
    end
end
ns.Bus:On("DEBUG", function(on) Kills:Sync(on) end)

-- /dp probe kills
function Kills:Probe()
    local parts = Valid(EVENTS, {})
    parts[#parts + 1] = "TakeTaxiNode=" .. tostring(type(TakeTaxiNode) == "function")
    Report("kills", parts, ("%s | pet=%s"):format(Stats(), self:PetState()))
end

------------------------------------------------------------------------------
-- The traits' sources (Core/Activity.lua): what they read, and the context
-- the "when" traits see (zone, instance, resting, AFK, group, level, pet).
------------------------------------------------------------------------------
local LIFE = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "ZONE_CHANGED_NEW_AREA", "MIRROR_TIMER_START",
    "PLAYER_LEVEL_UP", "CHAT_MSG_GUILD", "CHAT_MSG_TEXT_EMOTE", "GROUP_ROSTER_UPDATE", "CHAT_MSG_SKILL",
    "CHAT_MSG_COMBAT_FACTION_CHANGE", "PLAYER_FLAGS_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }
local FUNCS = { "GetZoneText", "IsResting", "UnitIsAFK", "UnitLevel", "JumpOrAscendStart" }
local FORMATS = { "SKILL_RANK_UP", "FACTION_STANDING_INCREASED" }

local function Try(fn, ...)
    if type(fn) ~= "function" then return "missing" end
    local ok, a, b = pcall(fn, ...)
    if not ok then return "error" end
    return b ~= nil and Args(a, b) or Show(a)
end

-- Guildmates (addon users or not) in our group, by the roster snapshot. A
-- unit name that can't be read is an "error" here, which is the finding.
local function GroupInfo()
    if type(GetNumGroupMembers) ~= "function" then return "missing" end
    local n = GetNumGroupMembers()
    if n == 0 then return "solo" end
    local ok, keys = pcall(ns.GroupKeys)
    if not ok then return n .. " (names: error)" end
    local mates = 0
    for _, key in ipairs(keys) do
        if key ~= ns.PlayerKey() and ns.Guild:IsMember(key) then mates = mates + 1 end
    end
    return ("%d (guildmates %d)"):format(n, mates)
end

function Kills:Context()
    local map = C_Map and C_Map.GetBestMapForUnit and Try(C_Map.GetBestMapForUnit, "player") or "missing"
    return ("zone=%s map=%s instance=[%s] resting=%s afk=%s group=%s level=%s time=%s pet=%s"):format(
        Try(GetZoneText), map, Try(IsInInstance), Try(IsResting), Try(UnitIsAFK, "player"), GroupInfo(),
        Try(UnitLevel, "player"), date("%H:%M"), self:PetState())
end

-- /dp probe life
function Kills:ProbeLife()
    local parts = Valid(LIFE, {})
    for _, f in ipairs(FUNCS) do parts[#parts + 1] = f .. "=" .. tostring(type(_G[f]) == "function") end
    for _, g in ipairs(FORMATS) do parts[#parts + 1] = g .. "=" .. Show(_G[g]) end
    Report("life", parts, self:Context())
end
