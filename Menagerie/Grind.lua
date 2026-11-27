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

-- id -> an hour's pace (2026-11-26: the Felwood log had rep 128 and gold 108 an hour).
Grind.KINDS = { rep = 30, gold = 60, herb = 15, mine = 15, skin = 20, fish = 30, quest = 8 }
Grind.SPAN, Grind.GAP = 3600, 1200 -- seconds
Grind.CHANCE = 0.5

local runs, said = {}, {} -- (a session's: id -> { from, last, n, key, extra }; id -> true once decided)

function Grind:OnActivity(id, key, extra)
    local pace = self.KINDS[id]
    if not (pace and key) or said[id] then return end
    local now, run = GetTime(), runs[id]
    if not run or run.key ~= key or now - run.last > self.GAP then
        run = { from = now, n = 0, key = key }
        runs[id] = run
    end
    run.n, run.last = run.n + 1, now
    if type(extra) == "string" and extra ~= "" then run.extra = extra end
    local span = now - run.from
    if span < self.SPAN or run.n < pace * span / 3600 then return end
    -- One farm, one line (2026-11-27, the user: "you don't really grind gold, you grind items ... if there's
    -- reputation rewards, it's probably a reputation farm"): coins looted with rep coming in are the rep farm's.
    local rep = runs.rep
    if id == "gold" and rep and rep.key == key and now - rep.last <= self.GAP then return end
    if ns.Personality:Dislikes(key)[id] then return end
    -- (busy: the next time it happens asks again)
    if ns.Moments:Pending() or not ns.Moments:Ready("quirk") then return end
    said[id] = true
    if id == "rep" then said.gold = true end -- (its coins were the same farm)
    local day = "grind:" .. id
    if not ns.Moments.Rolled(day, ns.Settings:Chance(self.CHANCE, "flavor")) then return end
    local text = ns.PickLine("grind." .. id, { pet = ns.Registry:NameOf(key), faction = run.extra })
    if not text or text:find("{faction}", 1, true) then return end -- (rep with no faction read: unsaid)
    ns.Log("Grind", "%s for %d min, %d times: a line", id, span / 60, run.n)
    ns.Moments:Say({ text = text, key = key, why = "grind " .. id, id = day, delay = "day",
        budget = "quirk", bubble = "say", said = function() ns.Moments.Spend(day) end })
end

-- What this session's runs are (/dp state, tests).
function Grind:Runs() return runs, said end

function Grind:Init()
    local want = {}
    for id in pairs(self.KINDS) do want[id] = true end
    ns.Activity:WantOnly(Grind, want)
    ns.Bus:On("ACTIVITY", function(id, _, key, _, extra) Grind:OnActivity(id, key, extra) end)
end

ns.Start("login", function() Grind:Init() end)
