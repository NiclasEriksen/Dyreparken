---@class Dyreparken
local ns = select(2, ...)

-- Still at it (2026-11-26, the user, from the log: 2 h 46 min of Timbermaw rep in Felwood, 355 rep gains and 299
-- coins looted, and the pet said two lines, both eggs. Nothing it did was a like, and the everyday pot was full).
-- An hour of farming one activity with a pet of ours out, liked or not, gets one line about it (grind.<id>.N, with
-- the class, race and moment variants ns.Lines mixes in). A common line: the quirks' 45 minutes (Moments), on
-- CHANCE of days (the day's roll, Moments.Rolled: the chatter.lua run said grind.gold on 28 of 28 days at a plain
-- 30 coins), once a day per activity. Not an egg: nothing counts it, no achievement waits.
-- A run is the activity with no gap longer than GAP, for SPAN seconds at least, at KINDS[id] an hour or more over
-- all of it: a farm, not the everyday pace (chatter.lua's guesses: 25 coins, 6 quests, 3 herbs an hour). Another
-- pet out starts it over. A disliked one is the dislike's to speak of (Quirks).
---@class Dyreparken.Grind
local Grind = {}
ns.Grind = Grind

-- id -> an hour's pace (2026-11-26: the Felwood log had rep 128 and gold 108 an hour). mobs: kills (Grind.Killed).
Grind.KINDS = { rep = 30, gold = 60, herb = 15, mine = 15, skin = 20, fish = 30, quest = 8, mobs = 30 }
Grind.SPAN, Grind.GAP = 3600, 1200 -- seconds
Grind.CHANCE = 0.5

-- The same mobs over and over (2026-11-27, the user: "very very rarely the same mob type, but a collection of similar
-- mobs: Timbermaw Shaman, Timbermaw Ursa etc. They usually share the same first or last name, and it's that common
-- word that should be used in the lines"). No combat log on Forever, and a unit's name can be secret in a fight:
-- a kill is the fight's end (PLAYER_REGEN_ENABLED) with a dead NPC still targeted, read then, out of combat. A run of
-- them stays in one zone (a camp's subzones flip as you walk: the probe, 2026-11-26). Its word: the one in the most
-- kills' names, in at least COMMON of them, a first word before a last at a tie (clans come first: Deadwood,
-- Defias, Bloodscalp), never a size, a look (SIZE, LOOK) nor an adjective's ending (ADJ). None that common: no mobs line, and the coins may speak.
-- What it says: grind.mobs.N ({mobs}); a rep farm's line names them too, half the time (grind.repmobs.N).
-- A fight's other kills are the same kind as the one targeted at its end (2026-11-27, the user: "if we kill 5
-- Deadwood mobs in a single fight, it should count as 5 Deadwood"): PARTY_KILL fires for each, its GUIDs secret
-- (FOREVER_API.md), so it's only counted, heard while a fight is on (at most FIGHT_MAX; none heard: one, the
-- target's: whether it fires solo isn't known yet).
Grind.COMMON = 0.5
Grind.FIGHT_MAX = 10
-- (sizes, ages: never the word, nor a two-word clan's first)
Grind.SIZE = { the = true, ["of"] = true, elder = true, young = true, greater = true, lesser = true, large = true,
    small = true, giant = true, dire = true, ancient = true, old = true, mature = true }
-- (a look, not a kind: the probe, 2026-11-27, Andorhal's Skeletal Acolytes and Executioners would have been
-- "så mange Skeletal". Scarlet stays: a crusade's name. A list the user would rather not grow: the probes decide)
Grind.LOOK = { dark = true, black = true, red = true, green = true, blue = true, white = true, grey = true,
    gray = true, rabid = true, feral = true, savage = true, mangy = true, wild = true, vile = true, foul = true,
    frenzied = true }
-- An adjective by its ending (Skeletal, Rotting, Diseased, Soulless, Venomous): never the word. -ling is a noun
-- (Hatchling, Darkling).
Grind.ADJ = { "ed$", "al$", "less$", "ous$", "ful$", "[^l]ing$" }
local function Adjective(l)
    for _, e in ipairs(Grind.ADJ) do if l:find(e) then return true end end
    return false
end

local runs, said = {}, {} -- (a session's: id -> { from, last, n, key, extra, zone, words }; id -> true once decided)

-- The word most of a run's kills share, or nil. Two words a clan's (2026-11-27, the user: "Dark Iron dwarves, where
-- there's the combination of two names that makes up their clan"): a pair with a word after it (Dark Iron Dwarf,
-- Burning Blade Acolyte) in as many kills as the best one word wins, as the game spells it. A word that ends most
-- names is a kind of creature, in lower case ("så mange ghoul", the user: "so it reads less artificial"); one
-- that starts them is a clan's name and keeps its capital (Deadwood).
function Grind.Common(run)
    local best, bn, bpos
    for word, c in pairs(run.words or {}) do
        local pos = c.pos / c.n
        if not best or c.n > bn or (c.n == bn and (pos < bpos or (pos == bpos and word < best))) then
            best, bn, bpos = word, c.n, pos
        end
    end
    if not best or bn < Grind.COMMON * run.n then return nil end
    local pair, pn
    for words, c in pairs(run.pairs or {}) do
        if c.n >= bn and (not pair or c.n > pn or (c.n == pn and words < pair)) then pair, pn = words, c.n end
    end
    if pair then return run.pairs[pair].as end
    local c = run.words[best]
    return c.last * 2 >= c.n and best or c.as
end

local function Count(run, name, n)
    run.words, run.pairs = run.words or {}, run.pairs or {}
    local ws = {}
    for w in name:gmatch("[%a']+") do ws[#ws + 1] = w end
    local seen = {}
    for i, w in ipairs(ws) do
        local l = w:lower()
        if #w >= 3 and not Grind.SIZE[l] and not Grind.LOOK[l] and not Adjective(l) and not seen[l] then
            seen[l] = true
            local c = run.words[l] or { n = 0, pos = 0, last = 0, as = w }
            c.n, c.pos = c.n + n, c.pos + i * n
            if i == #ws then c.last = c.last + n end
            run.words[l] = c
        end
        local w2 = ws[i + 1]
        if w2 and ws[i + 2] and #w >= 3 and #w2 >= 3 and not Grind.SIZE[l] and not Adjective(w2:lower()) then
            local k = l .. " " .. w2:lower()
            if not seen[k] then
                seen[k] = true
                local c = run.pairs[k] or { n = 0, as = w .. " " .. w2 }
                c.n = c.n + n
                run.pairs[k] = c
            end
        end
    end
end

-- A live run of this kind for this pet (a gap under GAP since its last).
local function Live(id, key, now)
    local r = runs[id]
    return r and r.key == key and now - r.last <= Grind.GAP and r or nil
end

function Grind:OnActivity(id, key, extra, n)
    n = n or 1
    local pace = self.KINDS[id]
    if not (pace and key) or said[id] then return end
    local now, run = GetTime(), runs[id]
    local zone = id == "mobs" and ns.Plain(GetZoneText()) or nil
    if not run or run.key ~= key or now - run.last > self.GAP or run.zone ~= zone then
        run = { from = now, n = 0, key = key, zone = zone }
        runs[id] = run
    end
    run.n, run.last = run.n + n, now
    if id == "mobs" then
        Count(run, extra, n)
    elseif type(extra) == "string" and extra ~= "" then
        run.extra = extra
    end
    local span = now - run.from
    if span < self.SPAN or run.n < pace * span / 3600 then return end
    -- One farm, one line (2026-11-27, the user: "you don't really grind gold, you grind items ... if there's
    -- reputation rewards, it's probably a reputation farm"): rep first, then the mobs, then the coins.
    local mobs = Live("mobs", key, now)
    if (id == "gold" or id == "mobs") and Live("rep", key, now) and not said.rep then return end
    local word = mobs and Grind.Common(mobs)
    if id == "gold" and word and not said.mobs then return end -- (mobs with no word in common: the coins speak)
    if id == "mobs" and not word then return end -- (no word they share: the coins' then)
    if ns.Personality:Dislikes(key)[id] then return end
    -- (busy: the next time it happens asks again)
    if ns.Moments:Pending() or not ns.Moments:Ready("quirk") then return end
    said[id] = true
    if id == "rep" or id == "mobs" then said.gold = true end -- (its coins were the same farm)
    if id == "rep" and word then said.mobs = true end
    local day = "grind:" .. id
    if not ns.Moments.Rolled(day, ns.Settings:Chance(self.CHANCE, "flavor")) then return end
    local prefix = "grind." .. id
    -- (a rep farm's mobs, half the time: not when they're the faction's own name, "Timbermaw" for Timbermaw Hold)
    if id == "rep" and word and type(run.extra) == "string" and not run.extra:find(word, 1, true) and ns.random() < 0.5 then
        prefix = "grind.repmobs"
    end
    local text = ns.PickLine(prefix, { pet = ns.Registry:NameOf(key), faction = run.extra, mobs = word })
    if not text or text:find("{faction}", 1, true) then return end -- (rep with no faction read: unsaid)
    ns.Log("Grind", "%s for %d min, %d times: a line", id, span / 60, run.n)
    ns.Moments:Say({ text = text, key = key, why = "grind " .. id, id = day, delay = "day",
        budget = "quirk", bubble = "say", said = function() ns.Moments.Spend(day) end })
end

-- What this session's runs are (/dp state, tests).
function Grind:Runs() return runs, said end

-- The mob a fight just over killed: a dead NPC still targeted, not friendly, not anyone's pet; its name, or nil.
local unreadable
function Grind.Killed()
    if ns.Plain(UnitExists("target")) ~= true or ns.Plain(UnitIsDead("target")) ~= true then return nil end
    if ns.Plain(UnitIsPlayer("target")) == true or ns.Plain(UnitPlayerControlled("target")) == true then return nil end
    local reaction = ns.Plain(UnitReaction("player", "target"))
    if type(reaction) == "number" and reaction > 4 then return nil end
    local name = ns.Plain(UnitName("target"))
    if type(name) ~= "string" or name == "" then
        if not unreadable then unreadable = true; ns.Log("Grind", "kill: the name can't be read (once a session)") end
        return nil
    end
    return name
end

function Grind:Init()
    local want = {}
    for id in pairs(self.KINDS) do if ns.Activity.KIND[id] then want[id] = true end end
    ns.Activity:WantOnly(Grind, want)
    ns.Bus:On("ACTIVITY", function(id, _, key, _, extra) Grind:OnActivity(id, key, extra) end)
    local kills = 0 -- (PARTY_KILL in this fight)
    ns.Events:On("PLAYER_REGEN_DISABLED", Grind, function()
        kills = 0
        if ns.Pets:OutKey() then ns.Events:On("PARTY_KILL", Grind, function() kills = kills + 1 end) end
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", Grind, function()
        ns.Events:Off("PARTY_KILL", Grind)
        local key, heard = ns.Pets:OutKey(), kills
        kills = 0
        if not key then return end
        local name = Grind.Killed()
        if not name then return end
        local n = math.min(math.max(heard, 1), Grind.FIGHT_MAX)
        ns.Log("Grind", "kill %s x%d in %s (PARTY_KILL %d)", name, n, tostring(ns.Plain(GetZoneText())), heard)
        Grind:OnActivity("mobs", key, name, n)
    end)
end

ns.Start("login", function() Grind:Init() end)
