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
    { "wake", wish = false },     -- back from AFK, the pet frame's pet woken (PetFrame.lua emits it): the eggs only
    -- Company from the guild (2026-11-14, the user): wishes for social pets (Wish.SOCIAL), no chips, liked by none.
    { "guildgroup" },             -- in a group with a guildmate (once a day)
    { "guildpet" },               -- a guildmate's companion met under the mouse (the meet activity's, guild owners)
    { "playmate" },               -- a playdate happened (Playdate.lua emits it; extra: who)
    -- Bad luck in a fight (2026-11-14, the user): eggs only, said after the fight.
    { "misses", wish = false },   -- your weapon swings missed (missed, dodged, parried) MISS_STREAK times in a row
    { "resisted", wish = false }, -- your spells resisted RESIST_STREAK times in a row
}
Activity.KIND = {}
for _, k in ipairs(Activity.KINDS) do k.id = k[1]; Activity.KIND[k.id] = k end

local sources = {}      -- id -> source
local wanted = {}       -- id -> { [owner] = true }
local listening = {}    -- event (or "event@unit") -> { source, ... } currently registered
local broken = {}       -- id -> true (switched off for this session)
local unavailable = {}  -- id -> true (an event the client lacks)
local ENGINE = { name = "Activity" } -- our owner key for ns.Events (its name for /dp probe perf)
-- Unit events (a source with `unit`) are registered for that unit only (ns.Events' unit hubs):
-- UNIT_SPELLCAST_SUCCEEDED for every unit in a raid would be thousands of calls for nothing. Sources of
-- one event for different units (the target's UNIT_COMBAT, yours) are apart: "event@unit".
local function Slot(e, unit) return unit and (e .. "@" .. unit) or e end

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
function Activity.PetNow()
    local key = ns.Pets:OutKey()
    if not key then return nil, false end
    return key, ns.Registry:MyPet() == key
end
local PetNow = Activity.PetNow

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
-- start = fn() when it starts being watched; available = fn() -> bool;
-- when = "fight" (registered only in a fight, solo) or "peace" (only out of one) }
function Activity:Source(src)
    assert(self.KIND[src.id], "Activity:Source: declare " .. tostring(src.id) .. " in Activity.KINDS")
    sources[src.id] = src
end

local function Run(src, event, ...)
    local w = wanted[src.id]
    if broken[src.id] or not (w and next(w)) then return end
    local prof = ns.profile -- (Dev/Perf.lua)
    local t0 = prof and debugprofilestop()
    local ok, n, extra = pcall(src.filter, event, ...)
    if prof then prof("Activity " .. src.id, debugprofilestop() - t0) end
    if not ok then
        broken[src.id] = true
        ns.Log("Activity", "%s switched off: %s", src.id, tostring(n))
        return
    end
    if n then Activity:Emit(src.id, n, extra) end
end

local handlers = {} -- slot -> its ns.Events handler
local function Handler(slot)
    local fn = handlers[slot]
    if not fn then
        fn = function(_, event, ...)
            for _, src in ipairs(listening[slot] or {}) do Run(src, event, ...) end
        end
        handlers[slot] = fn
    end
    return fn
end

local function Register(slot, list)
    local src = list[1]
    return ns.Events:On(slot:match("^[^@]+"), ENGINE, Handler(slot), src.unit)
end

local function Unregister(slot, list)
    ns.Events:Off(slot:match("^[^@]+"), ENGINE, list[1].unit)
end

-- A source's `when` (2026-11-14, the performance review): UNIT_COMBAT on your target is every hit on it from
-- anyone, dozens a second on a raid boss, and the bad-luck eggs want it only in a fight of your own; UNIT_HEALTH
-- is every hit or heal in a fight, and a fall counts only out of one. Our own fight state, from the events
-- themselves (the client's may lag the event by a frame), registered while some wanted source has a `when`.
local fighting = false
local WHEN = {
    fight = function() return fighting and Plain(IsInGroup()) ~= true end,
    peace = function() return not fighting end,
}
local STATE = { name = "Activity when" } -- our owner key for the state's events
local Update
local function State(on)
    if not on then
        for _, e in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "GROUP_ROSTER_UPDATE" }) do ns.Events:Off(e, STATE) end
        return
    end
    if ns.Events:Has("PLAYER_REGEN_DISABLED", STATE) then return end
    fighting = ns.InCombat() == true
    ns.Events:On("PLAYER_REGEN_DISABLED", STATE, function() fighting = true; Update() end)
    ns.Events:On("PLAYER_REGEN_ENABLED", STATE, function() fighting = false; Update() end)
    ns.Events:On("GROUP_ROSTER_UPDATE", STATE, function() Update() end)
end

-- Register the game events the wanted sources need, and only those.
function Update()
    local need = {}
    local conditional = false
    for id, owners in pairs(wanted) do
        local src = sources[id]
        if src and next(owners) and not broken[id] and src.when then
            conditional = true
            State(true)
        end
        if src and next(owners) and not broken[id] and (not src.when or WHEN[src.when]()) then
            for _, e in ipairs(src.events or {}) do
                local slot = Slot(e, src.unit)
                need[slot] = need[slot] or {}
                table.insert(need[slot], src)
            end
            if src.hook and not src.hooked then
                src.hooked = true
                src.hook(function(...) Run(src, "hook", ...) end)
            end
        end
    end
    if not conditional then State(false) end
    for slot, list in pairs(listening) do
        if not need[slot] then Unregister(slot, list) end
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

-- Exactly these activities for this owner (a set: id -> true): the rest it wanted are dropped.
function Activity:WantOnly(owner, set)
    for id, owners in pairs(wanted) do
        if owners[owner] and not set[id] then owners[owner] = nil end
    end
    for id in pairs(set) do
        wanted[id] = wanted[id] or {}
        wanted[id][owner] = true
    end
    Update()
end

-- Can this client produce the activity at all?
function Activity:Available(id)
    local src = sources[id]
    if not src or unavailable[id] or broken[id] then return false end
    if src.available then return src.available() end
    return true
end

-- Listening to the event (for any unit, or this one).
function Activity:IsListening(event, unit)
    if unit then return listening[Slot(event, unit)] ~= nil end
    for slot in pairs(listening) do
        if slot == event or slot:sub(1, #event + 1) == event .. "@" then return true end
    end
    return false
end

-- Which activities are wanted, by how many owners (/dp state).
function Activity:Wanted()
    local out = {}
    for id, owners in pairs(wanted) do
        local n = 0
        for _ in pairs(owners) do n = n + 1 end
        if n > 0 then out[id] = n end
    end
    return out
end

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
local apart = {} -- key -> the day ("YYYYMMDD") of its visit before today's, until Activity:Apart asks
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
    apart[key] = c.on[key]
    c.on[key] = today
    self:Emit("day", 1, key)
end

-- Calendar days since the visit before today's with this pet, once (the reunion egg asks at the day's
-- visit; asking again gives nil, so the calendar's second run of the day eggs doesn't ask anew), or nil
-- if it has none. This session only: the visit's day was the one thing that knew it.
function Activity:Apart(key)
    local before = apart[key]
    apart[key] = nil
    if type(before) ~= "string" then return nil end
    local y, m, d = before:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    if not y then return nil end
    local DayNumber = ns.Bonds.DayNumber
    return DayNumber(ns.Now()) - DayNumber(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
end

-- The day's visit if the date changed since the last check (none yet: the
-- login's check, 30 s in, comes first).
function Activity:NewDay()
    if self.dayChecked and Today() ~= self.dayChecked then self:CheckDay() end
end
-- Our pet came back out on its own (a loading screen, landing), with no summon
-- call for the hook in Init to see: its day's visit may be due (Summon fires this).
ns.Bus:On("PET_OUT", function() Activity:NewDay() end)

Activity:Source({ id = "day", events = {} })

function Activity:Init()
    if ns.Debug.enabled then self:SetDebug(true) end
    C_Timer.After(30, function() Activity:CheckDay() end)
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function()
        -- The summon lands a moment later.
        C_Timer.After(2, function() Activity:CheckDay() end)
    end)
end

ns.Start("loaded", function() Activity:Init() end)
