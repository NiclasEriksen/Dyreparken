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
--   Bus "ACTIVITY" (id, n, petKey, mine, extra)   extra: the boss's name, the place...
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

-- EVERY ACTIVITY, declared once (2026-11-09): its id, whether the bond
-- always watches it (always; the rest only for a pet that likes it), whether
-- it can be a pet's wish of the day (wish = false: not on demand), and the
-- icons of its chip on the card (the first the client has; none: no chip).
-- Its words come from Locale/nb.lua by id: activity.<id> (the noun),
-- activity.<id>.flavor (the line the first liked one of a day brings) and
-- effect.activity.<id> (how a trait's effect reads), each when present.
-- Personality, Stats, Bond and Wish read their views from here; a source
-- (below) must use an id from this list.
local ICON = "Interface\\Icons\\"
Activity.KINDS = {
    { "day", always = true, wish = false, icons = { ICON .. "INV_Misc_PocketWatch_01" } },
    { "boss", always = true, icons = { "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" } },
    { "quest", always = true, -- the quest giver's "!" (the "?" read as "unknown", creative review 2026-11-09)
        icons = { "Interface\\GossipFrame\\AvailableQuestIcon", ICON .. "INV_Misc_Book_09",
            ICON .. "INV_Misc_Note_01" } },
    { "taxi", always = true,
        icons = { "Interface\\TaxiFrame\\UI-Taxi-Icon-Green", ICON .. "Ability_Mount_Gryphon_01" } },
    { "pvp", always = true, icons = { ICON .. "Ability_DualWield" } },
    { "herb", always = true, icons = { ICON .. "Trade_Herbalism" } },
    { "mine", always = true, icons = { ICON .. "Trade_Mining" } },
    { "fish", always = true, icons = { ICON .. "Trade_Fishing" } },
    { "skin", always = true, icons = { ICON .. "INV_Misc_Pelt_Wolf_01" } },
    { "explore", always = true, icons = { ICON .. "INV_Misc_Map_01" } },
    { "skill", always = true, icons = { ICON .. "Trade_Engineering" } },
    { "rep", always = true, icons = { ICON .. "INV_Misc_Token_ArgentDawn", ICON .. "INV_Scroll_03" } },
    { "dance" }, { "cuddle" }, { "chat" },
    { "dive", icons = { ICON .. "Spell_Shadow_DemonBreath", ICON .. "Spell_Frost_SummonWaterElemental" } },
    { "level", wish = false }, { "revive", wish = false }, { "nap" },
    { "hearth", icons = { ICON .. "INV_Misc_Rune_01" } },
    { "jump" },
    { "roll", wish = false },     -- a 1 on a 1-100 roll (/roll or a loot roll): only the eggs watch it
    { "hundred", wish = false },  -- a 100 on a 1-100 roll: only the eggs watch it
    { "epic", wish = false },     -- you looted an epic (or better): only the eggs watch it
    { "fishfail", wish = false }, -- the second fish in a row that got away: only the eggs watch it
    { "duelwon", wish = false },  -- you won a duel (extra: who): only the eggs watch it
    { "duellost", wish = false }, -- you lost one (extra: who): only the eggs watch it
    { "newpath", wish = false },  -- a new flight path: only the eggs watch it
    -- Campfires, new on Forever (2026-11-11, the user): the buffs, as they come (Activity: AuraSource).
    { "campnear", wish = false }, -- a campfire nearby (pops up all the time out in the world): eggs only
    { "campwarm", wish = false }, -- sat down at one: Welcoming Campfire, a minute counting down
    { "camp" },                   -- the campfire's buff, after that minute: a wish for any pet (Wish.lua)
    { "rested" },                 -- Well-Rested, a night in a sleeping bag: a wish for cozy pets
    -- For the traits of 2026-11-12 (the user): Sjørøver, Skøyer, Røverdyr, Venneflokk.
    { "gold", icons = { ICON .. "INV_Misc_Coin_02", ICON .. "INV_Misc_Coin_01" } }, -- money looted
    { "fun", icons = { ICON .. "INV_Misc_Toy_10", ICON .. "Spell_Holy_PowerWordShield" } }, -- a silly emote of yours
    { "sneak", wish = false, icons = { ICON .. "Ability_Stealth" } }, -- into stealth (only some can)
    { "meet", icons = { ICON .. "INV_Box_PetCarrier_01", ICON .. "INV_Misc_PetBiscuit_01" } }, -- another player's companion, met
    -- The damage meter after a boss kill in a group (Menagerie/Meter.lua, 2026-11-12): only the eggs watch these.
    { "dmgtop", wish = false },   -- first in damage
    { "healtop", wish = false },  -- first in healing (a raid)
    { "kicktop", wish = false },  -- the most interrupts
    { "fall", wish = false },     -- a big fall (most of your health at once, out of combat): only the eggs watch it
    { "zeppelin", wish = false }, -- a zeppelin ride (Menagerie/Voyage.lua; it counts as flying, "taxi", too): eggs only
    { "boat", wish = false },     -- a boat ride (Menagerie/Voyage.lua): eggs only
    -- A character's big moments (Menagerie/Feats.lua, 2026-11-12, the user).
    { "feat", wish = false },     -- a class quest's reward, riding, level 60 (extra: the feat's id): Feats' points
    { "train", wish = false },    -- a trainer visit (its learned-spell lines as one): only the eggs watch it
    { "specswap", wish = false }, -- a dual-spec switch: only the eggs watch it
    { "respec", wish = false },   -- a talent reset: only the eggs watch it
}
Activity.KIND = {}
for _, k in ipairs(Activity.KINDS) do k.id = k[1]; Activity.KIND[k.id] = k end

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

local Today, Plain = ns.Today, ns.Plain

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
-- How many of an activity today with this pet out.
function Activity:TodayWith(id, petKey)
    local c = ns.DB.char.activity[id]
    return c and c.day == Today() and c.petsToday and c.petsToday[petKey] or 0
end

function Activity:Count(id, petKey)
    local c = ns.DB.char.activity[id]
    if not c then return 0, 0, 0, 0 end
    local today = c.day == Today() and c.today or 0
    return c.total, c.mine, today, petKey and c.pets[petKey] or 0
end

-- The companion out right now: key, and whether it's the adopted one.
local function PetNow()
    local key = ns.Pets:OutKey()
    if not key then return nil, false end
    return key, ns.Registry:MyPet() == key
end

-- Count n of an activity and tell the listeners. Out of combat only.
function Activity:Emit(id, n, extra)
    -- An undeclared id would reach every listener without its KIND row (Bond reads it).
    assert(self.KIND[id], "Activity:Emit: declare " .. tostring(id) .. " in Activity.KINDS")
    if ns.InCombat() then
        return ns.Events:OutOfCombat(function() Activity:Emit(id, n, extra) end)
    end
    n = n or 1
    local key, mine = PetNow()
    -- Past midnight while online, the new day's visit comes with the first
    -- thing done (code review 2026-11-10: it waited for a summon, and a night
    -- player lost the day and its holiday eggs). First, so it counts first.
    if key and id ~= "day" then self:NewDay() end
    local c = Counter(id)
    local today = Today()
    if c.day ~= today or not c.petsToday then c.day, c.today, c.petsToday = today, c.day == today and c.today or 0, {} end
    c.total, c.today = c.total + n, c.today + n
    if mine then c.mine = c.mine + n end
    if key then
        c.pets[key] = (c.pets[key] or 0) + n
        c.petsToday[key] = (c.petsToday[key] or 0) + n
    end
    ns.Log("Activity", "%s +%d pet=%s mine=%s %s", id, n, tostring(key), tostring(mine), tostring(extra or ""))
    ns.Bus:Fire("ACTIVITY", id, n, key, mine, extra)
end

------------------------------------------------------------------------------
-- Sources and registration
------------------------------------------------------------------------------
-- src: { id, events = { ... }, filter = fn(event, ...) -> n (or nil to
-- skip), extra; hook = fn(fire) for sources driven by a function hook;
-- start = fn() when it starts being watched; available = fn() -> bool }
function Activity:Source(src)
    assert(self.KIND[src.id], "Activity:Source: declare " .. tostring(src.id) .. " in Activity.KINDS")
    sources[src.id] = src
end

local function Run(src, event, ...)
    local w = wanted[src.id]
    if broken[src.id] or not (w and next(w)) then return end
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
-- The daily visit: once a calendar day per companion, the first time it's
-- out (checked after login, after any summon, when auto-summon finds it back
-- out, and before any other activity). Every pet of yours has
-- its own day (2026-11-09; before, only the adopted one).
------------------------------------------------------------------------------
function Activity:CheckDay()
    local w = wanted.day
    if not (w and next(w)) then return end
    self.dayChecked = Today() -- (checked, pet or not: a day change after this brings the visit)
    local key = PetNow()
    if not key then return end
    local c = Counter("day")
    c.on = c.on or {}
    local today = Today()
    if c.on[key] == today then return end
    c.on[key] = today
    self:Emit("day", 1, key)
end

-- The day's visit if the date changed since the last check (none yet: the
-- login's check, 30 s in, comes first).
function Activity:NewDay()
    if self.dayChecked and Today() ~= self.dayChecked then self:CheckDay() end
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
    local name = ns.SpellName(id)
    return type(name) == "string" and GATHER_NAMES[name:lower()] or nil
end
for _, kind in ipairs({ "herb", "mine", "fish", "skin" }) do
    Activity:Source({ id = kind, events = { "UNIT_SPELLCAST_SUCCEEDED" }, unit = "player",
        filter = function(_, unit, _, spellID)
            if unit ~= "player" or ns.InCombat() then return nil end
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
-- Silly ones (Skøyer, 2026-11-12): /laugh, /giggle, /joke and /silly, /cheer, /tickle, /flex, /chicken, /train.
local FUN = { "^you laugh", "^you giggle", "^you tell a joke", "^you cheer", "^you tickle", "^you flex",
    "cluck, chicken", "choo choo" }
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
    if Matches(lower, FUN) then return "fun" end
    if Matches(lower, CUDDLE) then
        local _, guid = ns.Pets:OutKey()
        local name = guid and ns.Pets:WorldName(guid)
        if name and text:find(name, 1, true) then return "cuddle" end
    end
    return nil
end
for _, kind in ipairs({ "dance", "cuddle", "fun" }) do
    Activity:Source({ id = kind, events = { "CHAT_MSG_TEXT_EMOTE" }, filter = function(_, text, ...)
        if not Own((select(11, ...))) then return nil end
        if Activity.EmoteKind(text) == kind then return 1 end
    end })
end

-- A big fall (2026-11-12, the user: "taking a lot of fall damage should be an event"): no event says so, but out
-- of combat, FALL_SHARE of your health or more gone in one change is a fall (nothing else hits that hard
-- outside a fight). UNIT_HEALTH for the player only, while the eggs watch it; a value we can't read (secret
-- in combat) is skipped. extra: "dead" when it was the end of you.
Activity.FALL_SHARE = 0.7
local lastHealth
Activity:Source({ id = "fall", events = { "UNIT_HEALTH" }, unit = "player",
    start = function() lastHealth = nil end,
    filter = function()
        local hp, max = Plain(UnitHealth("player")), Plain(UnitHealthMax("player"))
        if type(hp) ~= "number" or type(max) ~= "number" or max <= 0 then lastHealth = nil; return nil end
        local before = lastHealth
        lastHealth = hp
        if not before or InCombatLockdown() then return nil end
        if before - hp >= max * Activity.FALL_SHARE then return 1, hp <= 0 and "dead" or nil end
    end })

-- Money looted (Sjørøver, 2026-11-12): CHAT_MSG_MONEY is only ever about you ("You loot 5 Silver", "Your
-- share of the loot is ..."); the event is in the client (/dp probe api).
Activity:Source({ id = "gold", events = { "CHAT_MSG_MONEY" }, filter = function() return 1 end })

-- Into stealth (Røverdyr, 2026-11-12): Stealth, Prowl, Shadowmeld. IsStealthed is in the client; no stealth
-- event was probed, so the player's aura changes (UNIT_AURA, which works) are when to look.
local stealthed
Activity:Source({ id = "sneak", events = { "UNIT_AURA" }, unit = "player",
    available = function() return type(IsStealthed) == "function" end,
    filter = function()
        local now = Plain(IsStealthed()) and true or false
        local was = stealthed
        stealthed = now
        if now and was == false then return 1 end
    end })

-- Another player's companion met (Venneflokk, 2026-11-12): under the mouse (Tooltip's COMPANION_SEEN, out
-- of combat), each owner's pet once a day.
local met = {}
Activity:Source({ id = "meet", hook = function(fire)
    ns.Bus:On("COMPANION_SEEN", function(species, owner) fire(species, owner) end)
end, filter = function(_, species, owner)
    if type(owner) ~= "string" or owner == ns.PlayerKey() then return nil end
    local id = Today() .. "\31" .. owner .. "\31" .. tostring(species)
    if met[id] then return nil end
    met[id] = true
    return 1, owner
end })

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
        local name = ns.SpellName(id)
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
    -- The place's name for the line it may get (Bond: a first together).
    local name = Plain(GetZoneText())
    name = type(name) == "string" and name ~= "" and name or place
    ns.DB.char.lastPlace[key] = name -- (the explore chip's tooltip names it)
    self:Emit("explore", 1, name)
end
Activity:Source({ id = "explore", events = { "ZONE_CHANGED_NEW_AREA" }, filter = function()
    C_Timer.After(5, function() Activity:CheckPlace() end)
end })

-- Skill-ups and reputation (2026-11-09): the client's own chat lines, read
-- with its format strings (so any locale works): SKILL_RANK_UP ("Your skill
-- in %s has increased to %d."), FACTION_STANDING_INCREASED ("Your %s
-- reputation has increased by %d."). extra: the skill or the faction. Both
-- unverified on Forever (docs/FOREVER_API.md); without the format string the
-- activity is unavailable. Weapon skills count too: the day's caps keep them
-- small.
-- Built once per format string (review 2026-11-12: every CHAT_MSG_LOOT and CHAT_MSG_SYSTEM line,
-- always watched, built up to eight of them anew, three gsubs each; in a raid, every member's loot).
local patterns = {}
function Activity.FormatPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    local pat = patterns[fmt]
    if pat then return pat end
    -- Escape everything, then turn the (now escaped) %s / %d / %1$s back into captures.
    pat = fmt:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
    pat = pat:gsub("%%%%%d?%%?%$?s", "(.+)"):gsub("%%%%%d?%%?%$?d", "(%%d+)")
    pat = "^" .. pat .. "$"
    patterns[fmt] = pat
    return pat
end
-- together: lines within this many seconds of the last one counted are the same gain.
local function ChatSource(id, event, global, together)
    local pattern, last
    Activity:Source({ id = id, events = { event },
        available = function() return Activity.FormatPattern(_G[global]) ~= nil end,
        filter = function(_, text)
            text = Plain(text)
            pattern = pattern or Activity.FormatPattern(_G[global])
            if type(text) ~= "string" or not pattern then return nil end
            local name = text:match(pattern)
            if not name then return nil end
            local now = GetTime()
            if together and last and now - last < together then return nil end
            last = now
            return 1, name
        end })
end
-- Your own roll of 1-100 (2026-11-10, the user: "Hjelp Plask rolls 1 (1-100)"), by
-- /roll (CHAT_MSG_SYSTEM, RANDOM_ROLL_RESULT) or on an item (CHAT_MSG_LOOT: always
-- 1-100). Forever's loot roll lines start with a loot history link (/dp probe api,
-- 2026-11-11: "|HlootHistory:%d|h[Loot]|h: Need Roll - %d for %s by %s"), so the
-- roll is the third capture from the end (roll, item, name), with or without it.
-- A 1 (roll) or a 100 (hundred): the pet laughs at you, or is amazed.
local LOOT_ROLLS = { "LOOT_ROLL_ROLLED_NEED", "LOOT_ROLL_ROLLED_GREED", "LOOT_ROLL_ROLLED_DE" }
local function Me(name)
    name = type(name) == "string" and ns.NormalizeName(name)
    return name and (name == ns.PlayerKey() or name == Plain(UnitName("player")))
end
-- The roll in a loot roll line's captures (the third from the end), if the roller is you.
-- (Captures as arguments: no table for every loot line.)
local function RollOf(...)
    local n = select("#", ...)
    if n < 3 or not Me((select(n, ...))) then return nil end
    return tonumber((select(n - 2, ...)))
end
function Activity.Rolled(event, text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    if event == "CHAT_MSG_SYSTEM" then
        local pattern = Activity.FormatPattern(_G.RANDOM_ROLL_RESULT)
        if not pattern then return nil end
        local name, roll, low, high = text:match(pattern)
        if name and Me(name) and low == "1" and high == "100" then return tonumber(roll) end
        return nil
    end
    for _, global in ipairs(LOOT_ROLLS) do
        local pattern = Activity.FormatPattern(_G[global])
        local roll = pattern and RollOf(text:match(pattern))
        if roll then return roll end
    end
end
local function RollSource(id, value)
    Activity:Source({ id = id, events = { "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT" },
        available = function() return Activity.FormatPattern(_G.RANDOM_ROLL_RESULT) ~= nil end,
        filter = function(event, text) return Activity.Rolled(event, text) == value and 1 or nil end })
end
RollSource("roll", 1)
RollSource("hundred", 100)

-- An epic (or better) you looted (2026-11-11, the user): "You receive loot: [item]"
-- (LOOT_ITEM_SELF, or ..._MULTIPLE for a stack), the item link's color its quality
-- (a335ee epic, ff8000 legendary, e6cc80 artifact). Not items pushed to you (quest
-- rewards, crafting: LOOT_ITEM_PUSHED_SELF), and not someone else's loot.
Activity.EPIC_COLORS = { a335ee = true, ff8000 = true, e6cc80 = true }
function Activity.LootedEpic(text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    for _, global in ipairs({ "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE" }) do
        local pattern = Activity.FormatPattern(_G[global])
        local item = pattern and text:match(pattern)
        local color = item and item:match("^|c%x%x(%x%x%x%x%x%x)")
        if color and Activity.EPIC_COLORS[color:lower()] then return 1 end
    end
end
Activity:Source({ id = "epic", events = { "CHAT_MSG_LOOT" },
    available = function() return Activity.FormatPattern(_G.LOOT_ITEM_SELF) ~= nil end,
    filter = function(_, text) return Activity.LootedEpic(text) end })

-- Two fish in a row that got away (2026-11-10, the user): "Your fish got away!"
-- or "No fish are hooked." (UI_ERROR_MESSAGE: type, text), with no loot window
-- between them. Once at the second; again only after a catch.
local escaped = 0
Activity:Source({ id = "fishfail", events = { "UI_ERROR_MESSAGE", "LOOT_OPENED" },
    filter = function(event, _, text)
        if event == "LOOT_OPENED" then escaped = 0; return nil end
        text = Plain(text)
        if type(text) ~= "string" or not (text == _G.ERR_FISH_ESCAPED or text == _G.ERR_FISH_NOT_HOOKED) then return nil end
        escaped = escaped + 1
        if escaped == 2 then return 1 end
    end })

-- A duel's end (2026-11-11: the strings are in the client, /dp probe api), in system chat:
-- DUEL_WINNER_KNOCKOUT "%1$s has defeated %2$s in a duel" (winner first) and
-- DUEL_WINNER_RETREAT "%2$s has fled from %1$s in a duel" (the one who fled first).
-- Your own duels only; extra: the other one.
function Activity.Duel(text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    local function Read(global, winnerFirst)
        local pattern = Activity.FormatPattern(_G[global])
        if not pattern then return nil end
        local a, b = text:match(pattern)
        if not (a and b) then return nil end
        local winner, loser = a, b
        if not winnerFirst then winner, loser = b, a end
        if Me(winner) then return "duelwon", ns.NormalizeName(loser) end
        if Me(loser) then return "duellost", ns.NormalizeName(winner) end
    end
    local kind, who = Read("DUEL_WINNER_KNOCKOUT", true)
    if not kind then kind, who = Read("DUEL_WINNER_RETREAT", false) end
    return kind, who
end
for _, id in ipairs({ "duelwon", "duellost" }) do
    Activity:Source({ id = id, events = { "CHAT_MSG_SYSTEM" },
        available = function() return Activity.FormatPattern(_G.DUEL_WINNER_KNOCKOUT) ~= nil end,
        filter = function(_, text)
            local kind, who = Activity.Duel(text)
            if kind == id then return 1, who end
        end })
end

-- A new flight path (ERR_NEWTAXIPATH "New flight path discovered!"): a message on screen
-- (UI_INFO_MESSAGE: type, text) or in system chat; which one, unverified on Forever.
Activity:Source({ id = "newpath", events = { "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM" },
    available = function() return type(_G.ERR_NEWTAXIPATH) == "string" end,
    filter = function(event, a, b)
        local text = Plain(event == "UI_INFO_MESSAGE" and b or a)
        if text == _G.ERR_NEWTAXIPATH then return 1 end
    end })

-- A buff of yours appearing (it wasn't there at the last look): campfires and sleeping bags
-- (2026-11-11, the user's ids). Looked up by name (the client's language), like Summon's food,
-- from the spell id (or a given name, for one whose id isn't known); read on UNIT_AURA, out of
-- combat only (camps are), and not while auras are secret. The first look only notes what's
-- there (a /reload by the fire isn't a new fire).
Activity.AURAS = {
    campnear = { id = 1283391 },                       -- a campfire nearby
    campwarm = { id = 1229739 },                       -- Welcoming Campfire, the minute's countdown (seen 2026-11-11)
    camp = { id = 1229741 },                           -- the buff after a minute by the fire
    rested = { id = 429959 },                          -- Well-Rested (a sleeping bag)
}
local auraHad, auraNames = {}, {}
function Activity.AuraName(id)
    if auraNames[id] then return auraNames[id] end -- (UNIT_AURA comes often: looked up once)
    local a = Activity.AURAS[id]
    local name = a and (a.id and ns.SpellName(a.id) or a.name)
    auraNames[id] = name
    return name
end
function Activity.HasAura(name)
    local byName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not (byName and name) then return nil end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return nil end
    local ok, data = pcall(byName, "player", name, "HELPFUL")
    if not ok then return nil end
    return data ~= nil, data
end
-- UNIT_AURA comes often (code review 2026-11-11): a change that only refreshes durations can't
-- add or remove a buff, so it's skipped; otherwise the buffs are looked up once per event, not
-- once per source.
Activity.AURA_NEW = 60 -- seconds: a buff there at the first look that came this recently is new
local auraLook = { at = nil, has = {}, data = {} } -- (at: the event's updateInfo looked at)
local function LookAt(updateInfo)
    -- Secret on Forever now and then (2026-11-12, in a dungeon: "attempt to perform boolean test on field
    -- 'isFullUpdate' (a secret boolean)", and every aura source switched off for the session): a change we
    -- can't read is skipped, not tested.
    if ns.IsSecret(updateInfo) then return false end
    if type(updateInfo) == "table" then
        local full, added, removed = updateInfo.isFullUpdate, updateInfo.addedAuras, updateInfo.removedAuraInstanceIDs
        if ns.IsSecret(full) or ns.IsSecret(added) or ns.IsSecret(removed) then return false end
        if not full and not added and not removed then return false end
    end
    -- (Once per event: the client passes each UNIT_AURA its own updateInfo table.)
    if updateInfo == nil or auraLook.at ~= updateInfo then
        auraLook.at = updateInfo
        for id in pairs(Activity.AURAS) do
            auraLook.has[id], auraLook.data[id] = Activity.HasAura(Activity.AuraName(id))
        end
    end
    return true
end
-- Just applied (a sleeping bag's Well-Rested at login: code review 2026-11-11), by its timer.
local function Fresh(data)
    local d, at = data and Plain(data.duration), data and Plain(data.expirationTime)
    if type(d) ~= "number" or type(at) ~= "number" or d <= 0 then return false end
    return d - (at - GetTime()) <= Activity.AURA_NEW
end
for id in pairs(Activity.AURAS) do
    Activity:Source({ id = id, events = { "UNIT_AURA" }, unit = "player",
        available = function() return Activity.AuraName(id) ~= nil end,
        filter = function(_, _, updateInfo)
            if InCombatLockdown() or not LookAt(updateInfo) then return nil end
            local name = Activity.AuraName(id)
            local has, data = auraLook.has[id], auraLook.data[id]
            if has == nil then return nil end
            local before = auraHad[id]
            auraHad[id] = has
            if has and (before == false or (before == nil and Fresh(data))) then
                if not Activity.AURAS[id].id then
                    ns.Log("Activity", "%s: %s is spell %s", id, tostring(name), tostring(data and Plain(data.spellId)))
                end
                return 1
            end
        end })
end

ChatSource("skill", "CHAT_MSG_SKILL", "SKILL_RANK_UP")
-- One quest can raise several factions at once (2026-11-12: one Steamwheedle turn-in, six lines, Booty Bay to
-- Ratchet): one gain (the user).
Activity.REP_TOGETHER = 2
ChatSource("rep", "CHAT_MSG_COMBAT_FACTION_CHANGE", "FACTION_STANDING_INCREASED", Activity.REP_TOGETHER)

ns.Start("loaded", function() Activity:Init() end)
