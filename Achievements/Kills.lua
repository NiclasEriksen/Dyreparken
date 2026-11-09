local _, ns = ...

-- Research for "boss kills / PvP kills with your companion out"
-- (docs/ACHIEVEMENTS.md). Not a feature yet: a probe that only runs while
-- the debug log is on, and only writes to it.
--
-- Unknown on Forever (2026-11-08): whether these events fire for its bosses
-- and honorable kills, what they carry (secret values?), and whether the
-- summoned companion can be read at that moment (in combat) or only after.
-- So each event logs its payload, combat state and the companion; after a
-- boss event the companion is logged again when combat ends.
--
--   ENCOUNTER_START  (encounterID, name, difficultyID, groupSize)
--   ENCOUNTER_END    (encounterID, name, difficultyID, groupSize, success)
--   BOSS_KILL        (encounterID, name)
--   PLAYER_PVP_KILLS_CHANGED, PARTY_KILL (Classic: attackerGUID, targetGUID)
--   plus GetPVPSessionStats / GetPVPLifetimeStats at each PvP event.
--
-- `/dp probe kills` logs which of these the client knows, and the PvP stats.
local Kills = {}
ns.Kills = Kills

-- Settled 2026-11-08 (docs/FOREVER_API.md): bosses and quests work, and
-- PARTY_KILL is all secret (dropped). Still open: honorable kills.
local EVENTS = { "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_PVP_KILLS_CHANGED", "QUEST_TURNED_IN" }
local PVP = { PLAYER_PVP_KILLS_CHANGED = true }

local function Show(v)
    if issecretvalue and issecretvalue(v) then return "<secret>" end
    return tostring(v)
end

local function Args(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = Show((select(i, ...))) end
    return table.concat(parts, ", ")
end

-- The summoned companion as the client reports it right now.
function Kills:PetState()
    local ok, guid = pcall(C_PetJournal.GetSummonedPetGUID)
    if not ok then return "error: " .. tostring(guid) end
    if guid == nil then return "none" end
    if issecretvalue and issecretvalue(guid) then return "<secret>" end
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
    ns.Log("Kills", "%s (%s) combat=%s pet=%s", event, Args(...), tostring(InCombatLockdown()), Kills:PetState())
    if PVP[event] then ns.Log("Kills", "%s pvp %s", event, Stats()) end
    if event == "ENCOUNTER_END" or event == "BOSS_KILL" then
        ns.Events:OutOfCombat(function()
            ns.Log("Kills", "after %s, out of combat: pet=%s", event, Kills:PetState())
        end)
    end
end

-- Listen while the debug log is on; idle otherwise.
function Kills:Sync(on)
    for _, e in ipairs(EVENTS) do
        if on then ns.Events:On(e, KILLS, OnEvent) else ns.Events:Off(e, KILLS) end
    end
end

-- /dp probe kills
function Kills:Probe()
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    local parts = {}
    for _, e in ipairs(EVENTS) do parts[#parts + 1] = e .. "=" .. (valid and tostring(valid(e)) or "?") end
    parts[#parts + 1] = "TakeTaxiNode=" .. tostring(type(TakeTaxiNode) == "function")
    local msg = ("kills probe: %s | %s | pet=%s | debug log %s"):format(table.concat(parts, " "), Stats(),
        self:PetState(), ns.Debug.enabled and "on (listening)" or "OFF: /dp debug on to listen")
    ns.Print(msg)
    ns.Log("Probe", "%s", msg)
end

ns.Bus:On("DEBUG", function(on) Kills:Sync(on) end)

------------------------------------------------------------------------------
-- The traits probe (2026-11-08, docs/PET_LIFE.md): the events and state the
-- new personality traits would read, logged the same way (debug log only).
--   Trofast      PLAYER_DEAD, PLAYER_ALIVE, PLAYER_UNGHOST
--   Oppdager     ZONE_CHANGED_NEW_AREA + C_Map.GetBestMapForUnit / GetZoneText
--   Dykker       MIRROR_TIMER_START (timer name: "BREATH" under water)
--   Ambisiøs     PLAYER_LEVEL_UP
--   Latsabb      PLAYER_FLAGS_CHANGED (player) + UnitIsAFK + IsResting
--   Pratsom      CHAT_MSG_GUILD: only the sender is logged, never the text
--   Dansefot/Kjælen  DoEmote (hook) + CHAT_MSG_TEXT_EMOTE (our own only)
--   Hoppetass    JumpOrAscendStart (hook; one line per 5 s with the count)
--   Hjemlengsel  your own casts (UNIT_SPELLCAST_SUCCEEDED, player): id and name
--   Flokkdyr     GROUP_ROSTER_UPDATE: group size and guildmates in it
--   skill, rep   CHAT_MSG_SKILL, CHAT_MSG_COMBAT_FACTION_CHANGE, and the formats they're read with
-- Each line ends with the context: zone, map, instance, resting, AFK, group,
-- level and the companion.
------------------------------------------------------------------------------
local LIFE = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST", "ZONE_CHANGED_NEW_AREA", "MIRROR_TIMER_START",
    "PLAYER_LEVEL_UP", "CHAT_MSG_GUILD", "CHAT_MSG_TEXT_EMOTE", "GROUP_ROSTER_UPDATE", "CHAT_MSG_SKILL",
    "CHAT_MSG_COMBAT_FACTION_CHANGE" }
local UNIT_LIFE = { "PLAYER_FLAGS_CHANGED", "UNIT_SPELLCAST_SUCCEEDED" }
local FUNCS = { "GetZoneText", "IsResting", "UnitIsAFK", "UnitLevel", "DoEmote", "JumpOrAscendStart" }
local lifeOwner, lifeOn, hooked = {}, false, false
local unitFrame = CreateFrame("Frame")
Kills._unitFrame = unitFrame
local jumps, jumpAt = 0, 0

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

local function OnLife(_, event, ...)
    if event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_TEXT_EMOTE" then
        local text, sender = ...
        local guid = select(12, ...)
        local own = not (issecretvalue and issecretvalue(guid)) and guid == UnitGUID("player")
        if event == "CHAT_MSG_GUILD" then
            ns.Log("Life", "%s sender=%s own=%s", event, Show(sender), tostring(own))
        elseif own then
            ns.Log("Life", "%s (%s) | %s", event, Show(text), Kills:Context())
        end
        return
    end
    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local id = select(3, ...)
        local name = C_Spell and C_Spell.GetSpellName and not (issecretvalue and issecretvalue(id))
            and C_Spell.GetSpellName(id)
        ns.Log("Life", "cast %s %s combat=%s", Show(id), Show(name), tostring(InCombatLockdown()))
        return
    end
    ns.Log("Life", "%s (%s) | %s", event, Args(...), Kills:Context())
end
unitFrame:SetScript("OnEvent", OnLife)

local function Hook()
    if hooked then return end
    hooked = true
    if type(DoEmote) == "function" then
        hooksecurefunc("DoEmote", function(token, target)
            if lifeOn then ns.Log("Life", "DoEmote (%s, %s) | %s", Show(token), Show(target), Kills:Context()) end
        end)
    end
    if type(JumpOrAscendStart) == "function" then
        hooksecurefunc("JumpOrAscendStart", function()
            if not lifeOn then return end
            jumps = jumps + 1
            if GetTime() - jumpAt >= 5 then
                jumpAt = GetTime()
                ns.Log("Life", "jump #%d swimming=%s flying=%s", jumps, Try(IsSwimming), Try(IsFlying))
            end
        end)
    end
end

function Kills:SyncLife(on)
    lifeOn = on
    for _, e in ipairs(LIFE) do
        if on then ns.Events:On(e, lifeOwner, OnLife) else ns.Events:Off(e, lifeOwner) end
    end
    for _, e in ipairs(UNIT_LIFE) do
        if on then pcall(unitFrame.RegisterUnitEvent, unitFrame, e, "player") else unitFrame:UnregisterEvent(e) end
    end
    if on then Hook() end
end

-- /dp probe life
function Kills:ProbeLife()
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    local parts = {}
    for _, list in ipairs({ LIFE, UNIT_LIFE }) do
        for _, e in ipairs(list) do parts[#parts + 1] = e .. "=" .. (valid and tostring(valid(e)) or "?") end
    end
    for _, f in ipairs(FUNCS) do parts[#parts + 1] = f .. "=" .. tostring(type(_G[f]) == "function") end
    for _, g in ipairs({ "SKILL_RANK_UP", "FACTION_STANDING_INCREASED" }) do parts[#parts + 1] = g .. "=" .. Show(_G[g]) end
    local msg = ("life probe: %s | %s | debug log %s"):format(table.concat(parts, " "), self:Context(),
        ns.Debug.enabled and "on (listening)" or "OFF: /dp debug on to listen")
    ns.Print(msg)
    ns.Log("Probe", "%s", msg)
end

ns.Bus:On("DEBUG", function(on) Kills:SyncLife(on) end)
