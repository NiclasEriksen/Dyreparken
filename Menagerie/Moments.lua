---@class Dyreparken
local ns = select(2, ...)

-- Moments (2026-11-14, round 2: docs/ROUND2.md 3.1): what Quirks' eggs and dislikes and the class reactions
-- (Reactions.lua) share, once. A moment is a line your pet says a little after something happened:
--
--   lines by nature  Moments.ByNature(prefix, row, key): the first of the row's traits the pet has with
--                    lines of its own (<prefix>.<id>.<trait>.1), then its families', else the plain lines
--   budgets          a cooldown each, saved in char (Moments.BUDGETS): the quirks' 45 minutes, the
--                    reactions' 20, scaled by "Småting i chatten" (Settings.CHATTER, Moments:Every); a rare reaction or egg spends none (a rare egg did until 2026-11-15,
--                    holding back the day's common ones), every other quirk line the quirks'
--   one at a time    one slot for every common line on its way: an egg and a reaction no longer speak
--                    seconds apart (each module had its own, and neither saw the other's)
--   once a day       Moments.SaidToday(store, id), and Moments.Count(...) as it's said: store[id] (char.eggs,
--                    char.reacts) { n, day, key }; the caller fires its Bus event the first time
--   the day's roll   Moments.Rolled(id, chance): a line's chance rolled once a day, at its first moment
--                    (char.rolls); a miss keeps it quiet until tomorrow (2026-11-19, the user: totems, midnight
--                    and Ghost Wolf "very likely to happen every day for all players ... feels artificial and
--                    repetitive"). Rolled at every moment until said, a 40% only delayed a line that came dozens
--                    of times a day: on 8 or 9 of a shaman's 9 days. Now a chance is the share of days.
--   the delay        Moments.DELAY's spans; `afterFight`: in a fight, the wait starts once it's over
--                    (a fight that ended with your death: unsaid; any other line while you're dead is fine)
--   later            a moment held back only by another line on its way waits its turn (Moments:Later; the
--                    user, 2026-11-14: "queue them instead"), at most LATER_MAX seconds, LATER_SIZE of them
--
-- What a moment uses up (the cooldown, the day, a find) is saved when it's said, not when it's decided: a
-- /reload in the delay used to spend it unsaid (code review 2026-11-10).
---@class Dyreparken.Moments
local Moments = {}
ns.Moments = Moments

-- Seconds, picked at random within (2026-11-10: "scared of flying" the moment you took off read as if it had
-- flown for ages; 2026-11-11, the user: "some remarks feel a little too separated as they come so late"):
-- a reaction to what just happened comes almost at once ("now"), a day's egg a little after ("day"), a
-- dislike takes longer to sink in, the flight's dislike longest ("slow").
Moments.DELAY = { dislike = { 8, 15 }, egg = { 3, 10 }, now = { 1, 3 }, day = { 5, 15 }, slow = { 20, 40 } }
-- name -> { every = seconds, get/set: the char field it's kept in (spelled out: 50_saved reads them) }
Moments.BUDGETS = {
    quirk = { every = 2700, -- (an hour until 2026-11-11: the user, 45 minutes)
        get = function() return ns.DB.char.quirkAt end, set = function(t) ns.DB.char.quirkAt = t end },
    react = { every = 1200, -- (the user: their own budget, about 20 minutes)
        get = function() return ns.DB.char.reactAt end, set = function(t) ns.DB.char.reactAt = t end },
}

Moments.LATER_MAX, Moments.LATER_SIZE = 60, 4

local onTheWay = 0 -- lines decided and not yet said
local why       -- the newest one's reason (/dp state)
local queued = {} -- m.id -> true while that moment is on its way (it isn't decided twice: a rare reaction in a long fight)

function Moments:Pending() return onTheWay > 0 and why or nil end
-- This moment (its id) is on its way already.
function Moments:Queued(id) return id ~= nil and queued[id] == true end

-- Held back by a line on its way: fn() decides again once no line is (each its own checks: the cooldown, the
-- day, the roll). One per id; the oldest go past LATER_SIZE; older than LATER_MAX seconds, it has passed.
local later = {}
function Moments:Later(id, fn)
    for _, q in ipairs(later) do if q.id == id then return end end
    later[#later + 1] = { id = id, fn = fn, t = GetTime() }
    while #later > self.LATER_SIZE do table.remove(later, 1) end
    ns.Log("Moments", "%s waits its turn", tostring(id))
end
local function Drain()
    while onTheWay == 0 and later[1] do
        local q = table.remove(later, 1)
        if GetTime() - q.t <= Moments.LATER_MAX then
            local ok, err = pcall(q.fn)
            if not ok then geterrorhandler()(err) end
        end
    end
end

-- A budget's cooldown is over and no line is on its way. egg: for an egg, which "Mye" never lets through
-- sooner (Moments:Every).
function Moments:Ready(budget, egg)
    if onTheWay > 0 then return false end
    local b = assert(self.BUDGETS[budget], "Moments: no budget " .. tostring(budget))
    local at = b.get()
    return not at or ns.Now() - at >= self:Every(budget, egg)
end
-- A budget's cooldown in seconds, as "Småting i chatten" makes it (Settings.CHATTER: 90 minutes, 15...).
-- For an egg never shorter than the budget's own (2026-11-15, the user: "it shouldn't shorten the egg
-- timer": "Mye" would have found eggs three times as fast); "Litt"'s longer one holds.
function Moments:Every(budget, egg)
    local f = ns.Settings.CHATTER[ns.Settings:Chatter()].every
    if egg then f = math.max(1, f) end
    return self.BUDGETS[budget].every * f
end
-- Seconds until a budget is free (0: free), for /dp state; egg as Ready's.
function Moments:Left(budget, egg)
    local b = self.BUDGETS[budget]
    local at = b.get()
    return at and math.max(0, at + self:Every(budget, egg) - ns.Now()) or 0
end

-- Say text for key after a delay. m: { text, key, why (for the log), id (Queued's), delay (a DELAY name),
-- budget (spent as it's said; nil for a rare one), bubble (the pet frame's: say, dislike...), afterFight,
-- said = fn() }.
function Moments:Say(m)
    -- (a delay name we lack waits as an egg's: a throw here would leave the slot taken all session)
    local span = self.DELAY[m.delay or "egg"] or self.DELAY.egg
    onTheWay, why = onTheWay + 1, m.why
    if m.id then queued[m.id] = true end
    local function Wait()
        local wait = span[1] + ns.random() * (span[2] - span[1])
        ns.Log("Moments", "%s, in %d s", tostring(m.why), wait)
        C_Timer.After(wait, function()
            onTheWay = math.max(0, onTheWay - 1)
            if m.id then queued[m.id] = nil end
            if m.budget then self.BUDGETS[m.budget].set(ns.Now()) end
            -- (chatter "none" hides the line only: what it found still counts)
            ns.PetSays(m.text, m.key, m.bubble or "say")
            if m.said then m.said() end
            Drain()
        end)
    end
    if not (m.afterFight and ns.InCombat()) then return Wait() end
    ns.Events:OutOfCombat(function()
        -- A fight that ended with your death: what was said about it would come as you lie there, too
        -- late (2026-11-15, the user: a totem line "after I died, which is weird timing"). It goes unsaid,
        -- nothing spent. Other lines while you're dead are fine (the user: "it's okay for many lines to
        -- fire when I'm dead").
        if ns.Plain(UnitIsDeadOrGhost("player")) then
            onTheWay = math.max(0, onTheWay - 1)
            if m.id then queued[m.id] = nil end
            ns.Log("Moments", "%s: unsaid, the fight ended with your death", tostring(m.why))
            return Drain()
        end
        Wait()
    end)
end

-- Lines by nature: { _key = "<prefix>.<id>.<trait|family>" } for the first the pet has with lines, else {}.
-- Traits first, then families; the families in a row's `first` come before its traits (seilas' reptiles, both
-- Dykker, 2026-11-19, the user).
function Moments.ByNature(prefix, row, key)
    local has = {}
    for _, f in ipairs(row.families and ns.Scenes:Families(key) or {}) do has[f] = true end
    local function Line(x) return prefix .. "." .. row.id .. "." .. x end
    for _, f in ipairs(row.first or {}) do
        if has[f] and ns.Strings[Line(f) .. ".1"] then return { _key = Line(f) } end
    end
    for _, t in ipairs(row.traits or {}) do
        if ns.Personality:Has(key, t) and ns.Strings[Line(t) .. ".1"] then return { _key = Line(t) } end
    end
    for _, f in ipairs(row.families or {}) do
        if has[f] and ns.Strings[Line(f) .. ".1"] then return { _key = Line(f) } end
    end
    return {}
end

-- The day's roll for a line (id: "egg:midnatt", "react:totemer", "dislike:s:40:jump"): rolled at its first
-- moment of the day, the same answer at every later one; a new day starts a new table (the old ones go).
-- Moments.Spend(id): said, so no more today (for lines without a SaidToday of their own: a known dislike).
local function Rolls()
    local today = ns.Today()
    local r = ns.DB.char.rolls
    if not (r and r.day == today) then r = { day = today }; ns.DB.char.rolls = r end
    return r
end
function Moments.Rolled(id, chance)
    local r = Rolls()
    if r[id] == nil then
        r[id] = chance >= 1 or ns.random() < chance
        ns.Log("Moments", "%s: today's roll %s (%d%%)", id, r[id] and "won" or "lost", math.floor(chance * 100 + 0.5))
    end
    return r[id]
end
function Moments.Spend(id) Rolls()[id] = false end

-- Said today already (store[id].day; store: char.eggs, char.reacts).
function Moments.SaidToday(store, id)
    local had = store[id]
    return had ~= nil and had.day == ns.Today()
end

-- Counted as it's said: store[id] = { n, day, key } (other fields kept); the pet's story keeps the line
-- (once per moment: storyId). Returns the entry (n == 1: found just now).
function Moments.Count(store, id, key, text, storyId, day)
    local got = store[id] or {}
    got.n, got.day, got.key = (got.n or 0) + 1, day or ns.Today(), key
    store[id] = got
    ns.Story:Mine(key, "egg", text, storyId or id)
    return got
end
