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

local EVENTS = { "ENCOUNTER_START", "ENCOUNTER_END", "BOSS_KILL", "PLAYER_PVP_KILLS_CHANGED", "PARTY_KILL" }
local PVP = { PLAYER_PVP_KILLS_CHANGED = true, PARTY_KILL = true }

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

local afterCombat = {}

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
        if on then ns.Events:On(e, afterCombat, OnEvent) else ns.Events:Off(e, afterCombat) end
    end
end

-- /dp probe kills
function Kills:Probe()
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    local parts = {}
    for _, e in ipairs(EVENTS) do parts[#parts + 1] = e .. "=" .. (valid and tostring(valid(e)) or "?") end
    local msg = ("kills probe: %s | %s | pet=%s | debug log %s"):format(table.concat(parts, " "), Stats(),
        self:PetState(), ns.Debug.enabled and "on (listening)" or "OFF: /dp debug on to listen")
    ns.Print(msg)
    ns.Log("Probe", "%s", msg)
end

ns.Bus:On("DEBUG", function(on) Kills:Sync(on) end)
