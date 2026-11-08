local _, ns = ...

-- The activity engine: game events become activities ("boss", "quest",
-- "day", ...) that the bond score, achievements and pet stories all listen
-- to (docs/PET_LIFE.md). Nobody else registers these game events.
--
-- A SOURCE is declared once (Activity:Source): the game events it reads, a
-- filter that turns one event into a count (or nothing), and its id. The
-- engine does the shared work: it reads the summoned companion, waits until
-- combat is over before doing so (the companion can be unreadable in
-- combat, and nothing here is urgent), counts, and fires
--   Bus "ACTIVITY" (id, n, petKey, mine)
-- petKey: the summoned companion (or nil), mine: it's the one you adopted.
--
-- ON DEMAND: a game event is registered only while some consumer wants an
-- activity that reads it (Activity:Want / :Drop, keyed by owner). With no
-- consumers the engine costs nothing. The debug log wants everything, so
-- `/dp debug on` shows every activity with its payload.
--
-- DEGRADES, NEVER BREAKS: an event the client lacks makes its sources
-- unavailable (Activity:Available; achievements on them stay hidden). A
-- filter that throws is logged once and switched off for the session.
--
-- COUNTERS (per character, saved): char.activity[id] =
--   { total, mine, day = "YYYYMMDD", today, pets = { [petKey] = n } }
-- `mine` counts only what happened with your adopted companion out; `pets`
-- counts per companion. Counted only while someone listens: an activity
-- nobody wants isn't watched.
local Activity = {}
ns.Activity = Activity

local sources = {}      -- id -> source
local wanted = {}       -- id -> { [owner] = true }
local listening = {}    -- event -> { source, ... } currently registered
local broken = {}       -- id -> true (switched off for this session)
local unavailable = {}  -- id -> true (an event the client lacks)
local ENGINE = {}       -- our owner key for ns.Events
-- Unit events (a source with `unit`) go on a frame of their own, registered
-- for that unit only: UNIT_SPELLCAST_SUCCEEDED for every unit in a raid
-- would be thousands of calls for nothing.
local unitFrame = CreateFrame("Frame")
local unitEvents = {}   -- event -> true while registered on unitFrame

local function Today(now) return date("%Y%m%d", now or ns.Now()) end

local function Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end
Activity.Plain = Plain

------------------------------------------------------------------------------
-- Counting
------------------------------------------------------------------------------
local function Counter(id)
    local all = ns.DB.char.activity
    local c = all[id]
    if not c then
        c = { total = 0, mine = 0, today = 0, pets = {} }
        all[id] = c
    end
    return c
end

-- total, mine, today (for the current day), and the count for petKey.
function Activity:Count(id, petKey)
    local c = ns.DB.char.activity[id]
    if not c then return 0, 0, 0, 0 end
    local today = c.day == Today() and c.today or 0
    return c.total, c.mine, today, petKey and c.pets[petKey] or 0
end

-- The companion out right now: key, and whether it's the adopted one.
local function PetNow()
    local guid = Plain(ns.Pets:Summoned())
    local key = guid and ns.Pets:KeyOf(guid)
    if not key then return nil, false end
    return key, ns.Registry:MyPet() == key
end

-- Count n of an activity and tell the listeners. Out of combat only.
function Activity:Emit(id, n, extra)
    if ns.InCombat() then
        return ns.Events:OutOfCombat(function() Activity:Emit(id, n, extra) end)
    end
    n = n or 1
    local key, mine = PetNow()
    local c = Counter(id)
    local today = Today()
    if c.day ~= today then c.day, c.today = today, 0 end
    c.total, c.today = c.total + n, c.today + n
    if mine then c.mine = c.mine + n end
    if key then c.pets[key] = (c.pets[key] or 0) + n end
    ns.Log("Activity", "%s +%d pet=%s mine=%s %s", id, n, tostring(key), tostring(mine), tostring(extra or ""))
    ns.Bus:Fire("ACTIVITY", id, n, key, mine)
end

------------------------------------------------------------------------------
-- Sources and registration
------------------------------------------------------------------------------
-- src: { id, events = { ... }, filter = fn(event, ...) -> n (or nil to
-- skip), extra; hook = fn(fire) for sources driven by a function hook;
-- start = fn() when it starts being watched; available = fn() -> bool }
function Activity:Source(src)
    sources[src.id] = src
end

local function Run(src, event, ...)
    if broken[src.id] or not next(wanted[src.id] or {}) then return end
    local ok, n, extra = pcall(src.filter, event, ...)
    if not ok then
        broken[src.id] = true
        ns.Log("Activity", "%s switched off: %s", src.id, tostring(n))
        return
    end
    if n then Activity:Emit(src.id, n, extra) end
end

local function OnEvent(_, event, ...)
    for _, src in ipairs(listening[event] or {}) do Run(src, event, ...) end
end
unitFrame:SetScript("OnEvent", function(_, event, ...) OnEvent(nil, event, ...) end)

local function Register(e, list)
    local unit = list[1].unit
    if unit then
        local ok = pcall(unitFrame.RegisterUnitEvent, unitFrame, e, unit)
        if ok then unitEvents[e] = true end
        return ok
    end
    return ns.Events:On(e, ENGINE, OnEvent)
end

local function Unregister(e)
    if unitEvents[e] then
        unitFrame:UnregisterEvent(e)
        unitEvents[e] = nil
    else
        ns.Events:Off(e, ENGINE)
    end
end

-- Register the game events the wanted sources need, and only those.
local function Update()
    local need = {}
    for id, owners in pairs(wanted) do
        local src = sources[id]
        if src and next(owners) and not broken[id] then
            for _, e in ipairs(src.events or {}) do
                need[e] = need[e] or {}
                table.insert(need[e], src)
            end
            if src.hook and not src.hooked then
                src.hooked = true
                src.hook(function(...) Run(src, "hook", ...) end)
            end
        end
    end
    for e in pairs(listening) do
        if not need[e] then Unregister(e) end
    end
    for e, list in pairs(need) do
        if not listening[e] then
            for _, src in ipairs(list) do if src.start then src.start() end end
            if not Register(e, list) then
                for _, src in ipairs(list) do unavailable[src.id] = true end
                need[e] = nil
            end
        end
    end
    listening = need
end

function Activity:Want(id, owner)
    wanted[id] = wanted[id] or {}
    wanted[id][owner] = true
    Update()
end

function Activity:Drop(id, owner)
    if wanted[id] then wanted[id][owner] = nil end
    Update()
end

-- Can this client produce the activity at all?
function Activity:Available(id)
    local src = sources[id]
    if not src or unavailable[id] or broken[id] then return false end
    if src.available then return src.available() end
    return true
end

function Activity:IsListening(event) return listening[event] ~= nil end

-- The debug log wants every activity, so it shows what this client fires.
local DEBUG = {}
function Activity:SetDebug(on)
    for id in pairs(sources) do
        if on then self:Want(id, DEBUG) else self:Drop(id, DEBUG) end
    end
end
ns.Bus:On("DEBUG", function(on) if ns.DB.char then Activity:SetDebug(on) end end)

------------------------------------------------------------------------------
-- The daily visit: once a calendar day, the first time your adopted
-- companion is out (checked after login and after any summon).
------------------------------------------------------------------------------
function Activity:CheckDay()
    if not next(wanted.day or {}) then return end
    local key, mine = PetNow()
    local c = ns.DB.char.activity.day
    if mine and not (c and c.day == Today()) then self:Emit("day", 1, key) end
end

Activity:Source({ id = "day", events = {} })

function Activity:Init()
    if ns.Debug.enabled then self:SetDebug(true) end
    C_Timer.After(30, function() Activity:CheckDay() end)
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function()
        -- The summon lands a moment later.
        C_Timer.After(2, function() Activity:CheckDay() end)
    end)
end

------------------------------------------------------------------------------
-- The first sources. Each event is unverified on Forever until a probe says
-- otherwise (docs/FOREVER_API.md); a missing one only hides its activity.
------------------------------------------------------------------------------
-- A boss died (any difficulty). ENCOUNTER_END: id, name, difficulty, size, success.
Activity:Source({ id = "boss", events = { "ENCOUNTER_END" }, filter = function(_, id, name, _, _, success)
    if Plain(success) ~= 1 then return nil end
    return 1, tostring(Plain(name) or Plain(id) or "?")
end })

-- A quest handed in.
Activity:Source({ id = "quest", events = { "QUEST_TURNED_IN" }, filter = function(_, questID)
    return 1, tostring(Plain(questID) or "?")
end })

-- Honorable kills: the session counter went up (by how much).
local lastHK
local function SessionHK()
    if type(GetPVPSessionStats) ~= "function" then return nil end
    return Plain((GetPVPSessionStats()))
end
Activity:Source({
    id = "pvp",
    events = { "PLAYER_PVP_KILLS_CHANGED" },
    available = function() return type(GetPVPSessionStats) == "function" end,
    start = function() lastHK = SessionHK() end,
    filter = function()
        local hk = SessionHK()
        if type(hk) ~= "number" then return nil end
        local before = lastHK
        lastHK = hk
        if not before or hk <= before then return nil end
        return hk - before
    end,
})

-- Gathering: your own successful casts of Herb Gathering, Mining, Fishing
-- or Skinning, out of combat. Known spell ids first (the classic ranks),
-- else the spell's name. Unverified on Forever.
local GATHER_IDS = {
    [2366] = "herb", [2368] = "herb", [3570] = "herb", [11993] = "herb",
    [2575] = "mine", [2576] = "mine", [3564] = "mine", [10248] = "mine",
    [7620] = "fish", [7731] = "fish", [7732] = "fish", [18248] = "fish",
    [8613] = "skin", [8617] = "skin", [8618] = "skin", [10768] = "skin",
}
local GATHER_NAMES = { ["herb gathering"] = "herb", mining = "mine", fishing = "fish", skinning = "skin" }
function Activity.GatherKind(spellID)
    local id = Plain(spellID)
    if type(id) ~= "number" then return nil end
    if GATHER_IDS[id] then return GATHER_IDS[id] end
    local name = C_Spell and C_Spell.GetSpellName and Plain(C_Spell.GetSpellName(id))
    return type(name) == "string" and GATHER_NAMES[name:lower()] or nil
end
for _, kind in ipairs({ "herb", "mine", "fish", "skin" }) do
    Activity:Source({ id = kind, events = { "UNIT_SPELLCAST_SUCCEEDED" }, unit = "player",
        filter = function(_, unit, _, spellID)
            if unit ~= "player" or InCombatLockdown() then return nil end
            if Activity.GatherKind(spellID) == kind then return 1 end
        end })
end

-- A flight path taken (a function hook: it can't be unregistered, so it
-- does nothing while nobody wants "taxi").
Activity:Source({
    id = "taxi",
    available = function() return type(TakeTaxiNode) == "function" end,
    hook = function(fire)
        if type(TakeTaxiNode) == "function" then hooksecurefunc("TakeTaxiNode", fire) end
    end,
    filter = function() return 1 end,
})

------------------------------------------------------------------------------
-- The traits' activities (probed 2026-11-08, build 70862, docs/FOREVER_API.md).
------------------------------------------------------------------------------
local function Own(guid)
    return type(Plain(guid)) == "string" and guid == UnitGUID("player")
end

-- Emotes: CHAT_MSG_TEXT_EMOTE carries our own emote as text ("You dance
-- with Panda Cub."); the DoEmote hook never fires for typed emotes. English
-- text: the client is enUS. "cuddle" needs the companion out to be named in
-- it: "/pet" alone ("You need to be petted.") isn't petting it.
local DANCE = { "danc" }
local CUDDLE = { "^you pet ", "^you hug ", "^you cuddle ", "^you love ", "^you snuggle " }
local function Matches(text, list)
    for _, pat in ipairs(list) do if text:find(pat) then return true end end
    return false
end
function Activity.EmoteKind(text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    local lower = text:lower()
    if Matches(lower, DANCE) then return "dance" end
    if Matches(lower, CUDDLE) then
        local guid = Plain(ns.Pets:Summoned())
        local name = guid and ns.Pets:WorldName(guid)
        if name and text:find(name, 1, true) then return "cuddle" end
    end
    return nil
end
for _, kind in ipairs({ "dance", "cuddle" }) do
    Activity:Source({ id = kind, events = { "CHAT_MSG_TEXT_EMOTE" }, filter = function(_, text, ...)
        if not Own((select(11, ...))) then return nil end
        if Activity.EmoteKind(text) == kind then return 1 end
    end })
end

-- A line of our own in guild chat (only the sender is read, never the text).
Activity:Source({ id = "chat", events = { "CHAT_MSG_GUILD" }, filter = function(_, _, ...)
    if Own((select(11, ...))) then return 1 end
end })

-- Under water: the breath timer starts draining (scale -1). It also fires
-- when it refreshes, so one dive a minute at most.
local lastDive = 0
Activity:Source({ id = "dive", events = { "MIRROR_TIMER_START" }, filter = function(_, timer, _, _, scale)
    if Plain(timer) ~= "BREATH" or Plain(scale) ~= -1 or GetTime() - lastDive < 60 then return nil end
    lastDive = GetTime()
    return 1
end })

-- A level gained (the payload's first value; UnitLevel lags behind it).
Activity:Source({ id = "level", events = { "PLAYER_LEVEL_UP" }, filter = function(_, level)
    return 1, tostring(Plain(level) or "?")
end })

-- Back on your feet after dying. PLAYER_ALIVE also fires at every loading
-- screen, so only after a PLAYER_DEAD; the companion is counted a little
-- later, once it's back out.
local died = false
Activity:Source({ id = "revive", events = { "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" },
    filter = function(event)
        if event == "PLAYER_DEAD" then died = true; return nil end
        if not died or UnitIsDeadOrGhost("player") then return nil end
        died = false
        C_Timer.After(10, function() Activity:Emit("revive", 1) end)
    end })

-- AFK in a city or an inn: a nap.
Activity:Source({ id = "nap", events = { "PLAYER_FLAGS_CHANGED" }, unit = "player", filter = function(_, unit)
    if unit ~= "player" then return nil end
    if Plain(UnitIsAFK("player")) and Plain(IsResting()) then return 1 end
end })

-- Going home: your own Hearthstone (8690, seen on Forever 2026-11-08), or a
-- class's own way home: the shaman's Astral Recall (556) and the druid's
-- Teleport: Moonglade (18960), by id or by name (those two unverified).
local HOME_IDS = { [8690] = true, [556] = true, [18960] = true }
local HOME_NAMES = { ["Hearthstone"] = true, ["Astral Recall"] = true, ["Teleport: Moonglade"] = true }
Activity:Source({ id = "hearth", events = { "UNIT_SPELLCAST_SUCCEEDED" }, unit = "player",
    filter = function(_, unit, _, spellID)
        if unit ~= "player" then return nil end
        local id = Plain(spellID)
        if HOME_IDS[id] then return 1, tostring(id) end
        local name = type(id) == "number" and C_Spell and C_Spell.GetSpellName and Plain(C_Spell.GetSpellName(id))
        if HOME_NAMES[name] then return 1, name end
    end })

-- Jumping: one "jump" per 10 jumps (a function hook: idle when unwanted).
local jumps = 0
Activity:Source({
    id = "jump",
    available = function() return type(JumpOrAscendStart) == "function" end,
    hook = function(fire)
        if type(JumpOrAscendStart) == "function" then hooksecurefunc("JumpOrAscendStart", fire) end
    end,
    filter = function()
        jumps = jumps + 1
        if jumps % 10 == 0 then return 1 end
    end,
})

-- A place this companion has never been: the map id, or the zone's name
-- inside instances (C_Map has no map there). Read a few seconds after the
-- loading screen, when the companion is back out.
function Activity.Place()
    local map = C_Map and C_Map.GetBestMapForUnit and Plain(C_Map.GetBestMapForUnit("player"))
    if type(map) == "number" then return "m" .. map end
    local zone = Plain(GetZoneText())
    if type(zone) == "string" and zone ~= "" then return "z" .. zone end
end
function Activity:CheckPlace()
    local key = PetNow()
    local place = Activity.Place()
    if not key or not place then return end
    local all = ns.DB.char.places
    all[key] = all[key] or {}
    if all[key][place] then return end
    all[key][place] = true
    self:Emit("explore", 1, place)
end
Activity:Source({ id = "explore", events = { "ZONE_CHANGED_NEW_AREA" }, filter = function()
    C_Timer.After(5, function() Activity:CheckPlace() end)
end })
