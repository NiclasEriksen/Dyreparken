---@class Dyreparken
local ns = select(2, ...)

-- The activity engine's sources (Core/Activity.lua), by area: what in the game counts as each activity in
-- Activity.KINDS. Split from the engine 2026-11-14 (round 2: docs/ROUND2.md 3.4). A source:
-- Activity:Source({ id, events, unit, when, filter, hook, start, available }), read the engine's header.
---@class Dyreparken.Activity
local Activity = ns.Activity
local Today, Plain = ns.Today, ns.Plain
local PetNow = Activity.PetNow -- (the companion out: key, and whether it's the adopted one)

------------------------------------------------------------------------------
-- The sources. What each relies on, and whether a probe has seen it on Forever, is in docs/FOREVER_API.md
-- (or said by the source); a missing event or string only hides its activity.
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
-- else the spell's name. Herbs seen on Forever (2026-11-08); the other three by the same path.
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
-- does nothing while nobody wants "taxi"). Counted as you land, not as you take off (2026-11-18, the user: the
-- pet "kissed the ground after landing" a few seconds into the flight; its lines speak of the whole flight):
-- the take-off arms it, and the landing is the first dismount or control gained off the taxi (seen 2026-11-18:
-- PLAYER_MOUNT_DISPLAY_CHANGED at take-off and again at the landing), watched only during the flight.
-- A landing counts only after the taxi was seen (review 2026-11-19): mounted at the flight master, picking a node
-- dismounts you before the taxi starts, and a TakeTaxiNode that fails (no money) starts nothing. So the taxi is
-- read at each event and a few seconds after the take-off, and the watch ends unused if none saw it by
-- TAKEOFF_WITHIN.
Activity.LANDED_AFTER = 2 -- seconds after landing: on your feet first
Activity.TAKEOFF_WITHIN = 10
local FLIGHT = { name = "TaxiFlight" }
local flightT = ns.Timers()
local flying = false
local function Landed()
    local on = Plain(UnitOnTaxi("player"))
    if on == true then flying = true; return end
    if on ~= false or not flying then return end
    flying = false
    flightT:Cancel()
    ns.Events:OffAll(FLIGHT)
    C_Timer.After(Activity.LANDED_AFTER, function() Activity:Emit("taxi", 1) end)
end
Activity:Source({
    id = "taxi",
    available = function() return type(TakeTaxiNode) == "function" end,
    hook = function(fire)
        if type(TakeTaxiNode) == "function" then hooksecurefunc("TakeTaxiNode", fire) end
    end,
    filter = function()
        if not ns.Events:Has("PLAYER_MOUNT_DISPLAY_CHANGED", FLIGHT) then
            ns.Events:On("PLAYER_MOUNT_DISPLAY_CHANGED", FLIGHT, Landed)
            ns.Events:On("PLAYER_CONTROL_GAINED", FLIGHT, Landed)
        end
        flying = false
        flightT:Cancel()
        flightT:Every(2, Activity.TAKEOFF_WITHIN / 2, function(n)
            if Plain(UnitOnTaxi("player")) == true then flying = true; return flightT:Cancel() end
            if n * 2 >= Activity.TAKEOFF_WITHIN then ns.Events:OffAll(FLIGHT) end -- (no take-off: it failed)
        end)
        return nil
    end,
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
-- Each kind counts once per EMOTE_EVERY, like a dive (review 2026-11-19, the user: five /dance filled a 25-point
-- like in seconds; a like you live with, not a macro).
Activity.EMOTE_EVERY = 300
local lastEmote = {}
for _, kind in ipairs({ "dance", "cuddle", "fun" }) do
    Activity:Source({ id = kind, events = { "CHAT_MSG_TEXT_EMOTE" }, filter = function(_, text, ...)
        if not Own((select(11, ...))) then return nil end
        if Activity.EmoteKind(text) ~= kind then return nil end
        if lastEmote[kind] and GetTime() - lastEmote[kind] < Activity.EMOTE_EVERY - 0.01 then return nil end
        lastEmote[kind] = GetTime()
        return 1
    end })
end

-- A fall (2026-11-12, the user: "taking a lot of fall damage should be an event"). Read from health until
-- 2026-11-19, when the log showed UnitHealth("player") is secret out of combat too: it never fired. What a fall
-- looks like (/dp probe api fall, the user's jumps, build 70959): out of combat, at the landing, UNIT_COMBAT on you,
-- "WOUND", physical (school 1), its amount secret; nothing for a hop that doesn't hurt. So a fall is that: damage
-- out of a fight, still out of one FALL_CHECK later (a mob's first hit starts a fight). How big is unknown (the
-- amount is secret): any fall that hurts. A fight begun in that moment, even one over already (a mob that hit
-- first, killed at once: the user asked, 2026-11-19), makes it not a fall. extra: "dead" when it was the end of you.
Activity.FALL_CHECK = 0.5
Activity:Source({ id = "fall", events = { "UNIT_COMBAT" }, unit = "player", when = "peace",
    filter = function(_, unit, action, _, _, school)
        if Plain(unit) ~= "player" or Plain(action) ~= "WOUND" or Plain(school) ~= 1 then return nil end
        local at = GetTime()
        C_Timer.After(Activity.FALL_CHECK, function()
            if ns.InCombat() or (Activity.fightAt and Activity.fightAt >= at - 0.05) then return end
            Activity:Emit("fall", 1, Plain(UnitIsDeadOrGhost("player")) == true and "dead" or nil)
        end)
        return nil
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

-- A guildmate's companion met (2026-11-14, a wish for social pets): as "meet", the owner in the guild.
local metGuild = {}
Activity:Source({ id = "guildpet", hook = function(fire)
    ns.Bus:On("COMPANION_SEEN", function(species, owner) fire(species, owner) end)
end, filter = function(_, species, owner)
    if type(owner) ~= "string" or owner == ns.PlayerKey() or ns.Guild:IsMember(owner) ~= true then return nil end
    local id = Today() .. "\31" .. owner .. "\31" .. tostring(species)
    if metGuild[id] then return nil end
    metGuild[id] = true
    return 1, owner
end })

-- In a group with a guildmate (2026-11-14, a wish for social pets): when the first one is there (a raid's
-- every roster change would count again otherwise). Already together with the wish made: Wish:Auto.
local withGuild = false
function Activity.Guildmate()
    if not IsInGroup() then return nil end
    local me = ns.PlayerKey()
    for _, key in ipairs(ns.GroupKeys()) do
        if key ~= me and ns.Guild:IsMember(key) == true then return key end
    end
end
Activity:Source({ id = "guildgroup", events = { "GROUP_ROSTER_UPDATE" }, filter = function()
    local who = Activity.Guildmate()
    local was = withGuild
    withGuild = who ~= nil
    if who and not was then return 1, who end
end })

-- Bad luck in a fight (2026-11-14, the user: "missing 5 weapon swings in a row, or 3 spells resisted by enemy in a
-- row"). No combat log on Forever: UNIT_COMBAT on the target says each hit's action (WOUND, MISS, DODGE, PARRY,
-- RESIST...) and school, not who hit (docs/FOREVER_API.md). So only when it can be no one else's: solo, no
-- combat pet of yours out (a hunter's or a warlock's would miss and be resisted too), and for swings with
-- your auto-attack on. A hit of the same kind between them breaks the run. RESIST on Forever is unverified.
Activity.MISS_STREAK, Activity.RESIST_STREAK = 5, 3
local AVOIDED = { MISS = true, DODGE = true, PARRY = true }
local streak = { misses = 0, resisted = 0 }
-- (a pet we can't tell is there, its read secret, counts as there: its misses would be ours otherwise)
local function Alone()
    local pet = UnitExists("pet")
    return not (Plain(IsInGroup()) == true or ns.IsSecret(pet) or Plain(pet) == true)
end
-- One more in the run: 1 (the activity) when it reaches n, and the run starts over.
local function Streak(id, n)
    streak[id] = streak[id] + 1
    if streak[id] < n then return nil end
    streak[id] = 0
    return 1
end
Activity:Source({ id = "misses", events = { "UNIT_COMBAT" }, unit = "target", when = "fight",
    start = function() streak.misses = 0 end, filter = function(_, unit, action, _, _, school)
    action, school = Plain(action), Plain(school)
    if unit ~= "target" or type(action) ~= "string" or not Alone() then return nil end
    if AVOIDED[action] then
        if not ns.AutoAttacking() then return nil end
        return Streak("misses", Activity.MISS_STREAK)
    end
    if action == "WOUND" and school == 1 then streak.misses = 0 end
end })
Activity:Source({ id = "resisted", events = { "UNIT_COMBAT" }, unit = "target", when = "fight",
    start = function() streak.resisted = 0 end, filter = function(_, unit, action, _, _, school)
    action, school = Plain(action), Plain(school)
    if unit ~= "target" or type(action) ~= "string" or not Alone() then return nil end
    if action == "RESIST" then return Streak("resisted", Activity.RESIST_STREAK) end
    if action == "WOUND" and type(school) == "number" and school ~= 1 then streak.resisted = 0 end
end })

-- A playdate (2026-11-14, a wish for social pets): Playdate.lua emits it, as it happens.
Activity:Source({ id = "playmate", events = {} })
-- A guildmate's /klapp on a pet of yours (2026-11-19, the user: a rare wish): Bonds:Patted emits it.
Activity:Source({ id = "patted", events = {} })

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
        -- (Plain: a secret would throw here, and the source would be off for the session, review 2026-11-19)
        if not died or Plain(UnitIsDeadOrGhost("player")) ~= false then return nil end
        died = false
        C_Timer.After(10, function() Activity:Emit("revive", 1) end)
    end })

-- A wipe (2026-11-17, the user: "only count full group wipes"): you died in a group of WIPE_GROUP or more,
-- party or raid, and so did everyone else. Looked at as you fall (you were the last), as you release (they
-- fell after you; a ghost is dead too) and when a boss fight fails while you're dead (the game's own word
-- for it, whatever we can read of the others). Told, like revive, once you're back on your feet and your pet
-- is out again (dead, you have none), with the boss you fell to if one was up (ENCOUNTER_START's name).
-- In a battleground it's "routed": you died with more than ROUTED_SHARE of your team dead, looked at as you
-- fall. Teammates' UnitIsDeadOrGhost is unprobed (party, raid, battleground): only plain answers count, at
-- least WIPE_GROUP of them, and each count is logged.
Activity.WIPE_GROUP, Activity.ROUTED_SHARE = 5, 0.75
local down, encounter = nil, nil -- down: { boss, wiped, routed } since you fell in a big group; encounter: the boss up now
-- How many of the group are dead, of how many we can read (you included).
local function Fallen(why)
    local n, read, dead = Plain(GetNumGroupMembers()) or 0, 0, 0
    local raid = Plain(IsInRaid()) == true
    for i = 1, raid and n or math.min(n, 5) do
        local unit = raid and ("raid" .. i) or (i == 1 and "player" or ("party" .. (i - 1)))
        local d = Plain(UnitIsDeadOrGhost(unit))
        if d ~= nil then
            read = read + 1
            if d then dead = dead + 1 end
        end
    end
    ns.Log("Activity", "%s? %d of %d read dead, of %d", why, dead, read, n)
    return dead, read
end
local function Wiped()
    local dead, read = Fallen("wipe")
    return read >= Activity.WIPE_GROUP and dead == read
end
Activity:Source({ id = "wipe", events = { "ENCOUNTER_START", "ENCOUNTER_END", "PLAYER_DEAD", "PLAYER_ALIVE", "PLAYER_UNGHOST" },
    filter = function(event, ...)
        if event == "ENCOUNTER_START" then
            local name = Plain((select(2, ...)))
            encounter = type(name) == "string" and name or nil
            return nil
        elseif event == "ENCOUNTER_END" then
            if down and not down.routed and Plain((select(5, ...))) == 0 then down.wiped = true end
            encounter = nil
            return nil
        elseif event == "PLAYER_DEAD" then
            down = nil
            if not (Plain(IsInGroup()) and (Plain(GetNumGroupMembers()) or 0) >= Activity.WIPE_GROUP) then return nil end
            local kind = select(2, IsInInstance())
            if kind == "pvp" then
                local dead, read = Fallen("routed")
                if read >= Activity.WIPE_GROUP and dead > read * Activity.ROUTED_SHARE then down = { routed = true } end
            elseif kind ~= "arena" then
                down = { boss = encounter, wiped = Wiped() }
            end
            return nil
        end
        if not down then return nil end
        if Plain(UnitIsDeadOrGhost("player")) then -- (released: a ghost now)
            if not (down.wiped or down.routed) and Wiped() then down.wiped = true end
            return nil
        end
        local d = down
        down = nil
        if not (d.wiped or d.routed) then return nil end
        local id, boss = d.routed and "routed" or "wipe", not d.routed and d.boss or nil
        C_Timer.After(10, function() Activity:Emit(id, 1, boss) end)
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
-- reputation has increased by %d."; Forever's: "Reputation with %s increased by %d."). extra: the skill or
-- the faction. Both verified on Forever (2026-11-09, 2026-11-11); without the format string the
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
Activity.gained = {} -- id -> the biggest number in its last gain's chat lines (rep: how much)
local function ChatSource(id, event, global, together)
    local pattern, last
    Activity:Source({ id = id, events = { event },
        available = function() return Activity.FormatPattern(_G[global]) ~= nil end,
        filter = function(_, text)
            text = Plain(text)
            pattern = pattern or Activity.FormatPattern(_G[global])
            if type(text) ~= "string" or not pattern then return nil end
            local name, amount = text:match(pattern)
            if not name then return nil end
            if not together then return 1, name end
            -- One gain's lines (a quest's several factions) are one activity, said once they're all in, with
            -- the biggest of them (Activity.gained: Bond says nothing of a small rep gain, 2026-11-17).
            amount = tonumber(amount) or 0
            local now = GetTime()
            if last and now - last < together then
                Activity.gained[id] = math.max(Activity.gained[id] or 0, amount)
                return nil
            end
            last, Activity.gained[id] = now, amount
            C_Timer.After(together, function() Activity:Emit(id, 1, name) end)
            return nil
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
-- (The roll and the hundred both ask of the same line: read once, 2026-11-14.)
local lastRoll = {}
function Activity.Rolled(event, text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    if lastRoll.event == event and lastRoll.text == text then return lastRoll.roll end
    local roll = Activity.ReadRoll(event, text)
    lastRoll.event, lastRoll.text, lastRoll.roll = event, text, roll
    return roll
end
function Activity.ReadRoll(event, text)
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
for _, id in ipairs({ "duelwon", "duellost", "duel" }) do
    Activity:Source({ id = id, events = { "CHAT_MSG_SYSTEM" },
        available = function() return Activity.FormatPattern(_G.DUEL_WINNER_KNOCKOUT) ~= nil end,
        filter = function(_, text)
            local kind, who = Activity.Duel(text)
            if kind and (kind == id or id == "duel") then return 1, who end -- (a duel, won or lost: a like)
        end })
end

-- Errands (2026-11-19, the user: Ordensdyr's like): the bank, a mailbox or the auction house opened. The same
-- event as the trainer's window (Feats.lua, seen on Forever with Trainer 7); these three types read by name from
-- Enum.PlayerInteractionType (MailInfo 17 and Auctioneer 21 seen on Forever, 2026-11-20). The bank: a visit with
-- items deposited came as no Banker (8); Forever's enum also has CharacterBanker (67), retail's bank since the
-- warband bank, so that's taken too (unverified). One a minute at most: a mailbox closed and opened again isn't
-- another errand.
Activity.ERRAND_TYPES = { "Banker", "CharacterBanker", "MailInfo", "Auctioneer" }
Activity.ERRAND_AGAIN = 60
local lastErrand
Activity:Source({ id = "errand", events = { "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" },
    available = function()
        local E = rawget(_G, "Enum")
        return E ~= nil and E.PlayerInteractionType ~= nil and E.PlayerInteractionType.MailInfo ~= nil
    end,
    filter = function(_, kind)
        kind = Plain(kind)
        local types = Enum.PlayerInteractionType
        for _, name in ipairs(Activity.ERRAND_TYPES) do
            if types[name] ~= nil and kind == types[name] then
                local now = GetTime()
                if lastErrand and now - lastErrand < Activity.ERRAND_AGAIN then return nil end
                lastErrand = now
                return 1, name
            end
        end
        -- (2026-11-20: the bank's never came; the window types that aren't errands, to find its number)
        ns.Log("Activity", "errand: not one, interaction type %s", tostring(kind))
    end })

-- Into a dungeon or a raid (2026-11-19, the user: Huleboer's like): its loading screen's end inside one, once
-- per visit (a /reload or a login inside isn't a new one). extra: its name.
local inside
Activity:Source({ id = "dungeon", events = { "PLAYER_ENTERING_WORLD" },
    filter = function(_, login, reload)
        local yes, kind = IsInInstance()
        yes, kind = Plain(yes), Plain(kind)
        local now = yes == true and (kind == "party" or kind == "raid")
        local was = inside
        inside = now
        if not now or was or login or reload then return nil end
        local name = Plain(GetZoneText())
        return 1, type(name) == "string" and name or nil
    end })

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
    -- A meal (2026-11-19, the user: Vinterpels' and Solelsker's like): eating or drinking, by the buffs' names
    -- (Forever's English client; unverified there: the first one seen logs its spell id).
    eat = { names = { "Food", "Drink", "Food & Drink", "Refreshment" } },
    campnear = { id = 1283391 },                       -- a campfire nearby
    campwarm = { id = 1229739 },                       -- Welcoming Campfire, the minute's countdown (seen 2026-11-11)
    camp = { id = 1229741 },                           -- the buff after a minute by the fire
    rested = { id = 429959 },                          -- Well-Rested (a sleeping bag)
}
local auraHad, auraNames = {}, {}
function Activity.AuraName(id)
    if auraNames[id] then return auraNames[id] end -- (UNIT_AURA comes often: looked up once)
    local a = Activity.AURAS[id]
    local name = a and (a.id and ns.SpellName(a.id) or a.name or (a.names and a.names[1]))
    auraNames[id] = name
    return name
end
-- Any of an aura's names (a meal's Food or Drink): whether one is on, and its data.
local function HasAny(id)
    local names = Activity.AURAS[id].names
    if not names then return Activity.HasAura(Activity.AuraName(id)) end
    local seen
    for _, name in ipairs(names) do
        local has, data = Activity.HasAura(name)
        if has then return true, data end
        if has ~= nil then seen = false end
    end
    return seen
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
            auraLook.has[id], auraLook.data[id] = HasAny(id)
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
                if not Activity.AURAS[id].id then -- (the buff found: one of the names, not always the first)
                    local found = data and Plain(data.name)
                    ns.Log("Activity", "%s: %s is spell %s", id, tostring(type(found) == "string" and found or name),
                        tostring(data and Plain(data.spellId)))
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
