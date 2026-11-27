---@class Dyreparken
local ns = select(2, ...)

-- The bond (bånd) between a member and the companion they care for
-- (docs/PET_LIFE.md). Points grow and never shrink; they pause while you're
-- away. The bond belongs to the pair, so letting a pet go and adopting it
-- again picks up where you left off. Everyone sees everyone's bond.
--
-- Points: Config.BOND_DAY_POINTS for each calendar day with your adopted
-- companion out (the activity engine's "day"; double for a "Kosete" pet).
-- Activities done with it out (boss kills, quests, flights, gathering...)
-- add more: a lot for what it likes (Personality.lua), a little for the
-- rest, each with a daily cap so nothing can be farmed. The first liked
-- thing each day gets one line of flavor (again after a long break: Bond:Rested).
-- A pet adopted before bonds existed starts with that many points per day
-- already together, so nobody starts over.
--
-- Data: g.life[petKey][carer] (Registry.lua), written only by the carer.
-- Publishing: a level-up goes out at once (BOND); smaller gains wait up to
-- PUBLISH_AFTER, one timer at most. The login SYNC carries everything anyway.
--
-- Bond is data: it prints nothing. What players read about it is Bonds.lua's,
-- from the Bus: BOND_LEVEL (key, level, name), BOND_FULL (key), BOND_LINE
-- (key, text: a liked thing's flavor, a wish, a first, a playdate).
---@class Dyreparken.Bond
local Bond = {}
ns.Bond = Bond

local PUBLISH_AFTER = 1800 -- seconds

-- Levels: { points needed, name }. A curve to 2250 for the top, each step
-- longer than the last, with at most Config.BOND_DAILY_MAX (75) a day: 30
-- days to Sjelevenn at the very least (decided 2026-11-09; about 27 since the wish's 10 go past the
-- day's 75, 2026-11-13, and fewer with feats). At 10 a day
-- (the pet out, nothing else): Kamerat in 10 days, Venn 27, God venn 53,
-- Bestevenn 90, Uatskillelig 144, Sjelevenn 225. A casual player (~45 a
-- day): 3, 6, 12, 20, 32 and 50 days. Venn unlocks nicknames
-- (Config.NICKNAME_LEVEL). The loyalty achievements are levels (Defs.lua).
Bond.LEVELS = {
    { 0, ns.L["bond.level.1"] },
    { 100, ns.L["bond.level.2"] },
    { 270, ns.L["bond.level.3"] },
    { 530, ns.L["bond.level.4"] },
    { 900, ns.L["bond.level.5"] },
    { 1440, ns.L["bond.level.6"] },
    { 2250, ns.L["bond.level.7"] },
}
local LEVELS = Bond.LEVELS

-- level, name, points at this level's start, points for the next (nil at the top).
function Bond:Level(points)
    local level = 1
    for i, l in ipairs(LEVELS) do
        if points >= l[1] then level = i end
    end
    local nextAt = LEVELS[level + 1] and LEVELS[level + 1][1]
    return level, LEVELS[level][2], LEVELS[level][1], nextAt
end

-- The holder's bond with a pet: points, level, name, start, next. nil if free.
function Bond:Of(key)
    local owner = ns.Registry:Holder(key)
    if not owner then return nil end
    local e = ns.Registry:Life(key, owner)
    local p = e and e.p or 0
    return p, self:Level(p)
end

-- "Venn (level 3)" for a pet's current bond, or nil.
function Bond:Label(key)
    local p, level, name = self:Of(key)
    if not p then return nil end
    return ns.T("bond.label", { level = name, n = level })
end

------------------------------------------------------------------------------
-- Our own bond
------------------------------------------------------------------------------
local pendingKeys = {} -- pets with gains waiting for it (a pet swap within the wait keeps both)

local function Publish(key)
    pendingKeys[key] = nil
    local e = ns.Registry:Life(key, ns.PlayerKey())
    if e then ns.Bus:Fire("MY_BOND", key, e) end
end

local PublishSoon = ns.Debounce(PUBLISH_AFTER, function()
    for k in pairs(pendingKeys) do Publish(k) end
end)
local function Schedule(key)
    pendingKeys[key] = true
    PublishSoon()
end

-- How much of the full rate a pet earns: your adopted pet all of it, any
-- other pet of yours half (decided 2026-11-09: bond with several, but the
-- adopted one needs the most attention).
function Bond:Rate(key)
    return key == ns.Registry:MyPet() and 1 or ns.Config.BOND_OTHER_RATE
end

-- The most points a calendar day can bring this pet.
function Bond:DailyMax(key)
    return math.floor(ns.Config.BOND_DAILY_MAX * self:Rate(key))
end

-- When our bond with a pet began: the entry's start, or the adoption's for
-- the pet we hold, or now for a first point.
local function Start(key, e)
    local mine, r = ns.Registry:MyPet()
    local adopted = mine == key and r and r.at
    if e then return adopted and math.min(e.f, adopted) or e.f end
    return adopted or ns.Now()
end

-- How many more points our bond with a pet can take now, under the wire's
-- cap (Registry.LifeCap).
function Bond:Room(key)
    key = key or ns.Registry:MyPet()
    if not key then return 0 end
    local e = ns.Registry:Life(key, ns.PlayerKey())
    return math.max(0, ns.Registry.LifeCap(Start(key, e), ns.Now()) - (e and e.p or 0))
end

-- Add points to our bond with a pet (the one we hold, by default). Returns
-- the new points.
Bond.GAINS_KEPT = 8
-- The gains not yet shown on a pet's card, handed over once (BondTrack: the rising numbers).
function Bond:TakeGains(key)
    local all = ns.DB.char.bondGains
    local list = all[key]
    all[key] = nil
    return list
end

function Bond:Add(points, key)
    key = key or ns.Registry:MyPet()
    if not key or points <= 0 then return nil end
    local me, now = ns.PlayerKey(), ns.Now()
    local g = ns.DB:Guild()
    if not g then return nil end
    local e = ns.Registry:Life(key, me)
    local before = e and e.p or 0
    local loyal = before >= LEVELS[#LEVELS][1] -- (its gains are the loyalty points' now: AddLoyalty)
    local f = Start(key, e)
    -- Within what the wire accepts (Registry.LifeCap), so every copy merges;
    -- never below what we had (a copy that was valid stays ours).
    local p = math.max(before, math.min(before + points, ns.Registry.LifeCap(f, now)))
    ns.Registry:WriteOwn("life", key, { p = p, f = f })
    local oldLevel = self:Level(before)
    local level, name = self:Level(p)
    ns.Log("Bond", "%s +%d -> %d (level %d)", key, points, p, level)
    -- Each gain, for the card to show as it next sees this pet (BondTrack: the numbers
    -- rising from the bar). At most GAINS_KEPT; older ones are added into the oldest kept.
    if p > before and not loyal then
        local all = ns.DB.char.bondGains
        local list = all[key] or {}
        all[key] = list
        list[#list + 1] = p - before
        while #list > self.GAINS_KEPT do list[2] = list[1] + list[2]; table.remove(list, 1) end
    end
    if level > oldLevel then
        ns.Bus:Fire("BOND_LEVEL", key, level, name)
        Publish(key)
    elseif not e then
        Publish(key) -- a new bond: everyone should know of it
    else
        Schedule(key)
    end
    ns.Bus:Fire("BOND", key)
    return p
end

------------------------------------------------------------------------------
-- Loyalty points (lojalitetspoeng, 2026-11-19, the user): from the top level on, everything a pet earns with
-- you counts on without the day's limit (the per-activity caps stay), as how much time you've spent with it;
-- a character's total is meant for a leaderboard later. They continue from the bond's points as it reached
-- the top. The bond's own points (`p`) go on as before, within the day's limit and the wire's cap
-- (Registry.LifeCap), so peers see nothing new: the loyalty points are kept here only (g.loyal[carer]), not
-- sent yet. At the pet's rate, as every point is.
------------------------------------------------------------------------------
-- Your own bond with the pet has reached the top level.
function Bond:Loyal(key)
    local e = key and ns.Registry:Life(key, ns.PlayerKey())
    return e ~= nil and e.p >= LEVELS[#LEVELS][1]
end

local function LoyalStore(make)
    local g = ns.DB:Guild()
    if not g then return nil end
    local me = ns.PlayerKey()
    local t = g.loyal[me]
    if not t and make then t = {}; g.loyal[me] = t end
    return t
end

-- Your loyalty points with a pet: nil below the top level.
function Bond:Loyalty(key)
    if not self:Loyal(key) then return nil end
    local t = LoyalStore()
    return math.max(t and t[key] or 0, ns.Registry:Life(key, ns.PlayerKey()).p)
end

-- Your loyalty points with every pet: the character's total (the leaderboard's, later).
function Bond:LoyaltyTotal()
    local total = 0
    for key in pairs(LoyalStore() or {}) do total = total + (self:Loyalty(key) or 0) end
    return total
end

-- Loyalty points for a pet at the top level (a gain for its card's rising numbers). The new total, or nil.
-- base: the loyalty points before this gain, read before the bond's own share was added (until the first is kept,
-- they're the bond's points, and the share would count twice).
function Bond:AddLoyalty(points, key, base)
    local lp = points > 0 and (base or self:Loyalty(key))
    if not lp then return nil end
    lp = lp + points
    LoyalStore(true)[key] = lp
    local all = ns.DB.char.bondGains
    local list = all[key] or {}
    all[key] = list
    list[#list + 1] = points
    while #list > self.GAINS_KEPT do list[2] = list[1] + list[2]; table.remove(list, 1) end
    ns.Log("Bond", "%s loyalty +%d -> %d", key, points, lp)
    ns.Bus:Fire("BOND", key)
    return lp
end

-- The bond the card shows: points, level, name, start of the level, next
-- level's points; and whether it's ours. An adopted pet shows its holder's
-- (2026-11-09: the card is about the pet and its home; your own bond with
-- someone else's pet is a small line under it, Bond:Yours). A pet without a
-- home shows ours (Bond:Own).
function Bond:Shown(key)
    if not key then return end
    local holder = ns.Registry:Holder(key)
    if holder and holder ~= ns.PlayerKey() then
        local p, level, name, from, nextAt = self:Of(key)
        return p, level, name, from, nextAt, false
    end
    return self:Own(key)
end

-- Your bond with someone else's adopted pet, when you have one or own the
-- pet: points, level, name. Else nil.
function Bond:Yours(key)
    local holder = key and ns.Registry:Holder(key)
    if not holder or holder == ns.PlayerKey() then return nil end
    local e = ns.Registry:Life(key, ns.PlayerKey())
    if not (e or ns.Pets:IsOwned(key)) then return nil end
    local p = e and e.p or 0
    local level, name = self:Level(p)
    return p, level, name
end

-- Our bond with a pet as the journal's list rings show it (the list only has
-- pets you own, so it's your progress): ours when we have one or own the pet
-- (possibly 0 points); else its holder's, if any.
function Bond:Own(key)
    local e = key and ns.Registry:Life(key, ns.PlayerKey())
    if e or (key and ns.Pets:IsOwned(key)) then
        local p = e and e.p or 0
        local level, name, from, nextAt = self:Level(p)
        return p, level, name, from, nextAt, true
    end
    local p, level, name, from, nextAt = self:Of(key)
    if p then return p, level, name, from, nextAt, false end
end

-- A pet adopted before bonds existed: an entry seeded from its days together
-- until then (never lowering what's there). Only those: a later adoption with
-- no entry yet (never out, or a new PC whose SYNC hasn't brought it) seeded
-- from every day since gave points nobody earned (code review 2026-11-10).
function Bond:Seed()
    local key, r = ns.Registry:MyPet()
    if not key or r.at >= ns.Config.BONDS_SHIPPED then return end
    local me = ns.PlayerKey()
    local e = ns.Registry:Life(key, me)
    if e then return end
    local days = math.max(0, math.floor((math.min(ns.Now(), ns.Config.BONDS_SHIPPED) - r.at) / 86400))
    if days == 0 then return end -- a new adoption starts empty; the first day's visit creates it
    self:Add(days * ns.Config.BOND_DAY_POINTS)
    ns.Log("Bond", "seeded %s with %d (%d days)", key, days * ns.Config.BOND_DAY_POINTS, days)
end

-- Always watched (any pet of ours can bond); the traits' own activities
-- (dance, chat, dive...) only for the pets we'd have out that like them, so
-- nobody else pays for those events.
Bond.ACTIVITIES = {}
for _, k in ipairs(ns.Activity.KINDS) do
    if k.always then Bond.ACTIVITIES[#Bond.ACTIVITIES + 1] = k.id end
end

function Bond:Watch()
    local want = {}
    for _, id in ipairs(self.ACTIVITIES) do want[id] = true end
    -- The traits' activities of the pets we'd have out: the adopted one and
    -- the active one (Summon.lua).
    for _, key in ipairs({ ns.Registry:MyPet() or false, ns.Summon:ActiveKey() or false }) do
        if key then
            for id in pairs((ns.Personality:Of(key))) do want[id] = true end
            local minor = ns.Personality:MinorLike(key)
            if minor then want[minor] = true end
        end
    end
    ns.Activity:WantOnly(Bond, want)
end

-- What the "when" traits read (Personality.lua): the time, the group and
-- its guildmates, and whether we're in a dungeon or raid (not a
-- battleground). Built only for a pet that has such a trait.
function Bond.Context()
    local zone = ns.Plain(GetZoneText())
    local ctx = { t = ns.Now(), group = IsInGroup() == true, guildmates = 0, zone = zone,
        city = ns.Personality.CITIES[zone] or false }
    local inside, kind = IsInInstance()
    ctx.instance = inside == true and (kind == "party" or kind == "raid")
    if ctx.group then
        local me = ns.PlayerKey()
        for _, key in ipairs(ns.GroupKeys()) do
            if key ~= me and ns.Guild:IsMember(key) then ctx.guildmates = ctx.guildmates + 1 end
        end
    end
    return ctx
end

-- Today's points so far for a pet: per cap key (an activity, or
-- "trait:<id>") and in all (total), for a calendar day. Each pet has its own
-- day (decided 2026-11-09).
local function Ledger(key)
    local today = ns.Today()
    local d = ns.DB.char.bondToday
    if not d or d.day ~= today or not d.pets then
        d = { day = today, pets = {} }
        ns.DB.char.bondToday = d
    end
    local p = d.pets[key]
    if not p then p = { got = {}, total = 0 }; d.pets[key] = p end
    return p
end

-- Loyalty points a pet earned today (0 below the top level).
function Bond:LoyalToday(key)
    return Ledger(key).loyal or 0
end

-- Points a pet earned today, and the most its day can bring.
function Bond:Today(key)
    key = key or ns.Registry:MyPet()
    if not key then return 0, ns.Config.BOND_DAILY_MAX end
    return Ledger(key).total, self:DailyMax(key)
end

-- A "YYYYMMDD" as a day number (Bonds.DayNumber at noon).
local function DayNumberOf(s)
    local y, m, d = s:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    return ns.Bonds.DayNumber(time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }))
end

-- Whether a pet's day still has room (read only: Bond:Today makes the pet's entry for the day).
function Bond:Open(key)
    local d = ns.DB.char.bondToday
    local p = d and d.day == ns.Today() and d.pets and d.pets[key]
    return (p and p.total or 0) < self:DailyMax(key)
end

-- The pet to suggest when the one out has a full day (2026-11-22, the content review §4.2, the user: the full
-- day's line a nudge toward another pet): one of yours with room today, the one longest since its last day
-- out with you, else one that has never been out with you (the first by name), else one out earlier today. Returns
-- key and the days since (nil for never, 0 for today), or nil when there's none. Your Turnus pets first, in their turn after the one out (2026-11-22, the
-- user: the pet frame named a pet outside it).
function Bond:NextOpen(except)
    local today = DayNumberOf(ns.Today())
    local best, bestDays, fresh, freshName, again
    local fits = {} -- key -> days since (false: never out)
    for key in pairs(ns.Pets:Owned()) do
        if key ~= except and self:Open(key) then
            local last = ns.Activity:LastVisit(key)
            if last then
                local days = today - DayNumberOf(last)
                if days > 0 then
                    fits[key] = days
                    if not bestDays or days > bestDays or (days == bestDays and key < best) then best, bestDays = key, days end
                elseif not again or key < again then
                    -- (out earlier today, room left: the last resort, review 2026-11-24 Q8; it said nobody had room)
                    again = key
                end
            else
                fits[key] = false
                local name = ns.Pets:NameOfKey(key) or key
                if not freshName or name < freshName then fresh, freshName = key, name end
            end
        end
    end
    -- (whose turn it is after your adopted pet first: the one Turnus:TakeOver goes to)
    local d = ns.DB.char.turnusDay
    local turn = d and d.day == ns.Today() and d.turn
    if turn and fits[turn] ~= nil and ns.Turnus and ns.Turnus:Listed(turn) then return turn, fits[turn] or nil end
    local list = ns.Turnus and ns.Turnus:List() or {}
    local at = 0
    for i, k in ipairs(list) do if k == except then at = i end end
    for step = 1, #list do
        local key = list[(at + step - 1) % #list + 1]
        if fits[key] ~= nil then return key, fits[key] or nil end
    end
    if best then return best, bestDays end
    if fresh then return fresh, nil end
    if again then return again, 0 end
end

-- What the pet's day still has room for, of points.
local function Grantable(d, points, key)
    return math.max(0, math.min(points, Bond:DailyMax(key) - d.total, Bond:Room(key)))
end

-- Give points within what's left of the pet's day; one line when it's full. At the top level: all of them as
-- loyalty points, no day's limit (and no full day to tell of), the bond's own share within it as before.
local function Grant(d, points, key)
    if points > 0 and Bond:Loyal(key) then
        d.loyal = (d.loyal or 0) + points
        local base = Bond:Loyalty(key)
        local share = Grantable(d, points, key)
        if share > 0 then d.total = d.total + share; Bond:Add(share, key) end
        return Bond:AddLoyalty(points, key, base)
    end
    local max = Bond:DailyMax(key)
    points = Grantable(d, points, key)
    if points <= 0 then return nil end
    -- Counted before Add: Add refreshes the card, which shows today's points.
    d.total = d.total + points
    if d.total >= max then -- (once: a full day stops before this)
        ns.Bus:Fire("BOND_FULL", key)
    end
    return Bond:Add(points, key)
end

-- One line of flavor a day, for the first thing the pet loved, at the chatter step's chance (review 2026-11-24 Q9:
-- "Litt" promised fewer things it loves, and this day's line never asked: one roll a day, not one a moment).
-- Not right after another line of this pet's (review 2026-11-24 Q10: a boss kill printed the first's line and this one
-- in the same second): kept for a later moment that day.
Bond.LINE_GAP = 5
local lineAt = {} -- key -> GetTime() of its last bond line
local function Flavor(d, key, text)
    if d.flavor or not text then return end
    if lineAt[key] and GetTime() - lineAt[key] < Bond.LINE_GAP then return end
    d.flavor = true
    local chance = ns.Settings:Chance(1, "flavor")
    if chance < 1 and ns.random() >= chance then return end
    ns.Bus:Fire("BOND_LINE", key, text, "like")
end

-- The line for a liked activity: one of its own (activity.<id>.flavor and its variants, ns.Lines), else
-- the plain "koste seg med ...". {count}: how many times the pet has done it with you (its .remember lines).
function Bond.LikedLine(id, name, key)
    local count = key and select(4, ns.Activity:Count(id, key)) or nil
    return ns.PickLine("activity." .. id .. ".flavor", { pet = name, count = count })
        or ns.T("bond.liked", { pet = name, activity = ns.Personality.NOUN[id] })
end

-- The rewards beyond activities, each a line and points (Config names: read
-- when given, so a tunable change applies at once). once: at most one a day
-- per pet. lines: at most that many lines a day per pet (the points go on).
-- cap: at most that many points a day per pet from it (the lines go on).
-- kind: how the pet frame shows its line (PET_SAID, Bonds.lua: "like" unless said; "major" for the big ones).
-- beyond: past the day's limit (BOND_DAILY_MAX), and not counted in it: a feat (2026-11-12, the user:
-- "major feats should not count towards the daily limit, they're supposed to be huge bonuses"; one on a
-- full day was lost for good). Still within the wire's cap (Bond:Add, Registry.LifeCap: the days so far
-- and three spare ones, so a feat's 25 fits even after full days). The wish too (2026-11-13, the user:
-- "Yes, definitely past the cap"): 10 more on a full day. A row that's `beyond` and `once` adds its
-- points to the cap's room a day (Wire.DayRoom, X-Protocol 10: 75 + the wish's 10), so full days with
-- every wish done are never clamped; a new such row changes what peers accept (a protocol bump). Add
-- still clamps to the cap, and the line says what was really given (Room).
-- A new one is a row here and a Bond:Reward call where it happens.
-- (Balance is wire, review 2026-11-19: Wire.DayRoom is BOND_DAILY_MAX plus every `beyond` + `once` reward, and
-- LifeCap is days x DayRoom, what peers accept. Lowering an earning is free. Raising BOND_DAILY_MAX or such a
-- reward, or adding one, is an X-Protocol bump, and since older clients at the floor still check the old cap,
-- a fast player's bond would soon pass it there: it means raising X-Protocol-Floor too. A `beyond` reward that
-- isn't `once` eats LifeCap's spare days instead.)
Bond.REWARDS = {
    -- today's wish done. once here too: Wish.lua starts a fresh wish when you adopt the
    -- pet again the same day, and it paid twice (code review 2026-11-11).
    wish = { points = "BOND_WISH_POINTS", once = true, beyond = true, kind = "major" },
    first = { points = "BOND_FIRST_POINTS", lines = "FIRST_LINES", cap = "BOND_FIRST_CAP" }, -- a first together
    play = { points = "BOND_PLAY_POINTS", once = true }, -- a playdate (Playdate.lua)
    pat = { points = "BOND_PAT_POINTS" }, -- a guildmate's /klapp (Bonds:Patted: once every PAT_AGAIN from each)
    contest = { points = "BOND_CONTEST_POINTS", once = true }, -- fishing in the Sunday contest (Bond:Contest)
    feat = { points = "BOND_FEAT_POINTS", beyond = true, kind = "major" }, -- a feat (Feats.lua): once per character already, so not once a day
}

-- A pet that likes fishing, out while you fish in Stranglethorn on the fishing contest's day
-- (the calendar's Stranglethorn Fishing Extravaganza, Holidays.lua): a bonus, once that day
-- (the user, 2026-11-11), until the contest ends (16:00 by the calendar, Holidays:Running).
function Bond:Contest(key)
    if not (key and ns.Personality:Of(key).fish and ns.Holidays:Running("stvfishing")) then return end
    if ns.Plain(GetZoneText()) ~= "Stranglethorn Vale" then return end
    self:Reward("contest", key, Bond.Line("bond.contest", "bond.contest.full", { pet = ns.Registry:NameOf(key) }))
end

-- A reward's line that tells what it really gave (code review 2026-11-13: a full day's wish said
-- "+10" and gave nothing): `textKey` with {n}, or `fullKey`, without the amount, when it gave none. Either
-- one's variants too (ns.PickLine, 2026-11-19: the wish's line came daily and always read the same).
function Bond.Line(textKey, fullKey, vars)
    return function(n)
        vars.n = n
        local key = n > 0 and textKey or fullKey
        return ns.PickLine(key, vars) or ns.T(key, vars)
    end
end

-- A reward for a pet: its line, then its points within the day's limit and
-- at the pet's rate. False if a once-a-day one was had today. text false: the
-- points without a line (a new place most of the time); not counted in `lines`.
-- text a function (Bond.Line): called with the points it gives, worked out first.
-- named: a line that always speaks, past the kind's lines a day (review 2026-11-24 Q1: a dungeon's trash bosses and
-- its place used up the firsts' three, so its named end boss, which comes last, never spoke, and was done for good).
function Bond:Reward(kind, key, text, named)
    local def = assert(self.REWARDS[kind], "undeclared reward")
    local d = Ledger(key)
    d.had = d.had or {}
    local n = (d.had[kind] or 0) + 1
    if def.once and n > 1 then return false end
    local points = math.ceil(ns.Config[def.points] * self:Rate(key))
    local loyal = self:Loyal(key) -- (no day's limit: it gives all of it)
    local capKey = def.cap and "reward:" .. kind
    if capKey then
        points = math.max(0, math.min(points, math.ceil(ns.Config[def.cap] * self:Rate(key)) - (d.got[capKey] or 0)))
    end
    if type(text) == "function" then
        text = text(loyal and points or def.beyond and math.min(points, self:Room(key)) or Grantable(d, points, key))
    end
    if text then
        d.had[kind] = n
        if named or not def.lines or n <= ns.Config[def.lines] then
            lineAt[key] = GetTime()
            ns.Bus:Fire("BOND_LINE", key, text, def.kind or "like")
        end
    end
    ns.Log("Bond", "reward %s for %s", kind, key)
    if def.beyond then
        local base = loyal and self:Loyalty(key)
        self:Add(points, key)
        if loyal then d.loyal = (d.loyal or 0) + points; self:AddLoyalty(points, key, base) end
        return true
    end
    if capKey then
        if points <= 0 then return true end
        d.got[capKey] = (d.got[capKey] or 0) + points
    end
    Grant(d, points, key)
    return true
end

Bond.MINOR_FLAVOR = 0.3   -- a minor like's first time in a day: the chance of its line

-- Points for an activity done with a pet of ours out (half for one we
-- haven't adopted: Bond:Rate).
-- Seconds between two activities of a kind that give points (2026-11-22, the content review §3.2, the user: "more
-- like each minute"): the free ones, a keypress each. The activity still counts (the eggs' jumps, the stats); only
-- the points wait. Dance, cuddle and the silly emotes are spaced where they're heard (Activity.EMOTE_EVERY).
Bond.SPACED = { jump = 60, chat = 60 }

-- Back after a while (2026-11-22, the content review §3.3, the user: "you" away, not since you last saw that
-- pet, so a rotation of pets never brings it): no character of the account played for COMEBACK_DAYS or more,
-- and the first pet out on the day you're back has its day's points COMEBACK_X times, within the day's limit.
-- account.played: the last day a character logged in or had a visit; account.comeback: the day one is owed.
Bond.COMEBACK_DAYS, Bond.COMEBACK_X = 7, 2
local function DayOf(s) return s:match("^%d%d%d%d%d%d%d%d$") and DayNumberOf(s) end
function Bond:CheckComeback()
    local account, today = ns.DB.global, ns.Today()
    local last = type(account.played) == "string" and DayOf(account.played)
    if last and DayOf(today) - last >= self.COMEBACK_DAYS then
        account.comeback = today
        ns.Log("Bond", "back after %d days: the first pet out today has a double day", DayOf(today) - last)
    end
    account.played = today
end

function Bond:OnActivity(id, n, key)
    if id == "fish" then self:Contest(key) end
    local C, P = ns.Config, ns.Personality
    local name = ns.Registry:NameOf(key)
    local rate = self:Rate(key)
    local function Scaled(v) return math.ceil(v * rate) end
    n = n or 1
    if id == "day" then
        local now = ns.Now()
        local x, why = P:DayFactor(key, now)
        local d = Ledger(key)
        d.dayX = x -- (Bond:DayAgain: the calendar may answer later)
        local account = ns.DB.global
        account.played = ns.Today() -- (a session that runs past midnight plays the new day too)
        local back = account.comeback == ns.Today()
        if back then account.comeback, d.comeback = nil, true end
        if why and why.dayFlavor then Flavor(d, key, why.dayFlavor(name, now)) end
        local before = d.total
        local result = Grant(d, Scaled(C.BOND_DAY_POINTS * n * x * (d.comeback and Bond.COMEBACK_X or 1)), key)
        if back then ns.Bus:Fire("COMEBACK", key, d.total > before and d.total - before or nil) end
        return result
    end
    local likes = P:Of(key)
    -- The bond counts what it watches itself (Bond:Watch): the activities
    -- every pet bonds over, and this pet's likes. Others watch more (the
    -- debug log, Quirks' dislikes and eggs, another pet's likes); those
    -- mustn't give points.
    -- (and its minor like, once your bond has unlocked it: Personality:MinorLike)
    local minor = not likes[id] and P:MinorLike(key) == id
    if not likes[id] and not minor and not ns.Activity.KIND[id].always then return end
    local d = Ledger(key)
    -- Likes that cost nothing count once a minute at most (Bond.SPACED; the emotes are spaced at their source).
    local gap = Bond.SPACED[id]
    if gap then
        d.spaced = d.spaced or {}
        local now = ns.Now()
        if d.spaced[id] and now - d.spaced[id] < gap then return end
        d.spaced[id] = now
    end
    local capKey, per, cap, flavor = id, C.BOND_OTHER_POINTS, C.BOND_OTHER_CAP, nil
    if likes[id] then
        per, cap = C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
        flavor = Bond.LikedLine(id, name, key)
        -- Home by name (2026-11-10): the inn you're bound to (GetBindLocation works on Forever: /dp probe api, 2026-11-11).
        local home = id == "hearth" and type(GetBindLocation) == "function" and ns.Plain(GetBindLocation())
        if type(home) == "string" and home ~= "" then flavor = ns.PickLine("activity.hearth.flavor_home", { pet = name, home = home }) end
    elseif P:WantsContext(key) then
        -- A unit name we can't read mustn't cost the points: no bonus then.
        local ok, ctx = pcall(Bond.Context)
        for _, t in ipairs(ok and P:Fitting(key, ctx) or {}) do
            if (d.got["trait:" .. t.id] or 0) < Scaled(C.BOND_TRAIT_CAP) then -- (at the pet's rate, as the room below)
                capKey, per, cap = "trait:" .. t.id, C.BOND_LIKED_POINTS, C.BOND_TRAIT_CAP
                flavor = ns.PickLine("trait." .. t.id .. ".flavor", { pet = name })
                break
            end
        end
    end
    -- A minor like, when no trait's moment gave more: fewer points, and its flavor a third as often
    -- (its first time in a day, by chance; the user, 2026-11-12).
    if minor and capKey == id then
        per, cap = C.BOND_MINOR_POINTS, C.BOND_MINOR_CAP
        if not d.got[capKey] and ns.random() < ns.Settings:Chance(Bond.MINOR_FLAVOR, "flavor") then
            flavor = Bond.LikedLine(id, name, key)
        end
    end
    per, cap = Scaled(per), Scaled(cap)
    local dayLeft = self:Loyal(key) and math.huge or (self:DailyMax(key) - d.total) -- (the top level: none)
    local room = math.min(cap - (d.got[capKey] or 0), dayLeft)
    -- Everyday activities (not liked, not a trait's moment) share a small pot too.
    local other = capKey == id and not likes[id] and not minor
    if other then room = math.min(room, Scaled(C.BOND_OTHER_TOTAL) - (d.got.other or 0)) end
    -- A small rep gain (a kill's few points) gives its points quietly; the day's line waits for a big one.
    if id == "rep" and (ns.Activity.gained.rep or 0) < C.REP_LINE_MIN then flavor = nil end
    -- The line before the room (2026-11-26): a like's line is about the pet's day, not the points, so one with
    -- its cap reached, or the day's 75, still says it (after a break, Bond:Rested, its cap is often reached).
    Flavor(d, key, flavor)
    if room <= 0 then return nil end
    local points = math.min(per * n, room)
    d.got[capKey] = (d.got[capKey] or 0) + points
    if other then d.got.other = (d.got.other or 0) + points end
    return Grant(d, points, key)
end

local function Count(t)
    local n = 0
    for _ in pairs(t or {}) do n = n + 1 end
    return n
end

-- Firsts together (2026-11-09): the first time a pet is along when a given
-- boss falls, or sees a given place (Activity: "explore" fires only for a
-- place new to that pet), it gets BOND_FIRST_POINTS and a line, at most
-- FIRST_LINES lines a day per pet (the points go on: REWARDS.first).
-- A new place becomes a moment by chance: the pet's first family's (else DEFAULT), times its traits'.
Bond.PLACE_CHANCE = {
    DEFAULT = 0.3,
    bird = 0.5, owl = 0.45, dragon = 0.45, wolf = 0.45, pirate = 0.45, rodent = 0.4, spirit = 0.4,
    rabbit = 0.35, murloc = 0.35, bear = 0.35, frog = 0.3, bug = 0.3, mechanical = 0.3, demon = 0.3, festive = 0.3,
    farm = 0.25, cat = 0.25, reptile = 0.25, snake = 0.2, ooze = 0.2, plant = 0.2,
}
Bond.PLACE_MAX = 0.9
Bond.PLACE_OWN = 0.5 -- the chance a family's own line is picked (when it has some), else a general one

function Bond:PlaceChance(key)
    local family = ns.Scenes:Families(key)[1]
    local p = self.PLACE_CHANCE[family] or self.PLACE_CHANCE.DEFAULT
    for _, t in ipairs(ns.Personality:Traits(key)) do p = p * (t.place or 1) end -- (Personality.TRAITS' `place`)
    return math.min(p, self.PLACE_MAX)
end

-- Named bosses and dungeons (2026-11-22, 0.10.0, the content review §2.3: "{boss} falt!" read the same for Hogger
-- and Ragnaros): the first time with a pet, a line of their own (first.boss.<slug>.N, first.place.<slug>.N), and
-- a named place always speaks. Names as Forever gives them: the encounter's (ENCOUNTER_END, the classic names: the
-- log has "Avatar of Hakkar"), a dungeon's GetZoneText ("The Temple of Atal'Hakkar"; its instance is "Sunken
-- Temple", so both). Unverified ones are on Verify's list ("named").
Bond.NAMED_BOSSES = {
    vancleef = { "Edwin VanCleef" }, arugal = { "Archmage Arugal" }, mutanus = { "Mutanus the Devourer" },
    thermaplugg = { "Mekgineer Thermaplugg" }, whitemane = { "High Inquisitor Whitemane" }, archaedas = { "Archaedas" },
    hakkar = { "Avatar of Hakkar", "Hakkar", "Hakkar the Soulflayer" }, eranikus = { "Shade of Eranikus" },
    thaurissan = { "Emperor Dagran Thaurissan" }, rivendare = { "Baron Rivendare" }, gandling = { "Darkmaster Gandling" },
    ragnaros = { "Ragnaros" }, onyxia = { "Onyxia" }, nefarian = { "Nefarian" }, cthun = { "C'Thun" },
    kelthuzad = { "Kel'Thuzad" },
}
Bond.NAMED_PLACES = {
    deadmines = { "The Deadmines", "Deadmines" }, wailing = { "Wailing Caverns" }, shadowfang = { "Shadowfang Keep" },
    stockade = { "The Stockade", "Stormwind Stockade" }, scarlet = { "Scarlet Monastery" }, uldaman = { "Uldaman" },
    zulfarrak = { "Zul'Farrak" }, maraudon = { "Maraudon" }, sunken = { "The Temple of Atal'Hakkar", "Sunken Temple" },
    brd = { "Blackrock Depths" }, stratholme = { "Stratholme" }, scholomance = { "Scholomance" },
    moltencore = { "Molten Core" }, onyxialair = { "Onyxia's Lair" }, gnomeregan = { "Gnomeregan" },
    -- Forever's own nine (2026-11-23, the user; names from the saved data where visited, the rest as the user or
    -- Blizzard's article gave them: Verify's "named" ticks each when its line is said)
    hallofthanes = { "Hall of Thanes", "The Hall of Thanes" }, lordaeron = { "Ruins of Lordaeron" },
    excavation = { "Excavation Site: Wetlands", "Excavation Site" }, dalaran = { "City of Dalaran" },
    drowned = { "The Drowned City" }, kroldok = { "Krol'dok Stronghold" }, alcaz = { "Alcaz Prison" },
    blackmaw = { "Blackmaw Hold" }, shaper = { "The Shaper's Terrace", "Shaper's Terrace" },
    -- Iconic zones (the content review §2.3: "a frog in Swamp of Sorrows, a mechanical pet in Gnomeregan"): a line
    -- by the pet's family where it has one (first.place.<slug>.<family>.N), else the zone's own.
    swamp = { "Swamp of Sorrows" }, winterspring = { "Winterspring" }, ungoro = { "Un'Goro Crater" },
    stranglethorn = { "Stranglethorn Vale" }, tanaris = { "Tanaris" }, felwood = { "Felwood" }, moonglade = { "Moonglade" },
    silithus = { "Silithus" }, steppes = { "Burning Steppes" }, duskwood = { "Duskwood" }, elwynn = { "Elwynn Forest" },
    ashenvale = { "Ashenvale" },
}
local function Slugs(t)
    local out = {}
    for slug, names in pairs(t) do for _, n in ipairs(names) do out[n] = slug end end
    return out
end
Bond.BOSS_SLUG, Bond.PLACE_SLUG = Slugs(Bond.NAMED_BOSSES), Slugs(Bond.NAMED_PLACES)

-- Faction leaders (2026-11-24, the user, batch G; an idea from the log: Thrall under the mouse): the first time a pet
-- meets one of your own faction's (under the mouse: the glance), a first together, points and a line of its own
-- (first.leader.<slug>.N) or now and then a general one (first.leader.N). The other side's don't count (the user).
-- The Skyborne have no single ruler (the user). Names unverified: Verify's "named" list.
Bond.LEADERS = {
    thrall = { "Horde", "Thrall", "Warchief Thrall" }, cairne = { "Horde", "Cairne Bloodhoof" },
    sylvanas = { "Horde", "Lady Sylvanas Windrunner", "Sylvanas Windrunner" }, voljin = { "Horde", "Vol'jin" },
    magni = { "Alliance", "King Magni Bronzebeard", "Magni Bronzebeard" },
    tyrande = { "Alliance", "Tyrande Whisperwind", "High Priestess Tyrande Whisperwind" },
    stormwind = { "Alliance", "Highlord Bolvar Fordragon", "Bolvar Fordragon", "King Anduin Wrynn", "Anduin Wrynn" },
    mekkatorque = { "Alliance", "High Tinker Mekkatorque", "Gelbin Mekkatorque" },
}
Bond.LEADER_SLUG = {}
for slug, row in pairs(Bond.LEADERS) do
    for i = 2, #row do Bond.LEADER_SLUG[row[i]] = slug end
end
Bond.LEADER_OWN = 0.7 -- the chance of the leader's own line, else a general one

function Bond:Leader(s)
    if s.kind ~= "npc" or type(s.name) ~= "string" then return end
    local slug = self.LEADER_SLUG[s.name]
    if not slug or self.LEADERS[slug][1] ~= ns.Plain(UnitFactionGroup("player")) then return end
    local key = ns.Pets:OutKey()
    -- (no guild, no bond: kept for when there is one, review 2026-11-24 Q23)
    if not key or not ns.DB:Guild() then return end
    local met = ns.DB.char.leaders
    met[key] = met[key] or {}
    if met[key][slug] then return end
    met[key][slug] = true
    local own = #ns.Lines("first.leader." .. slug) > 0 and ns.random() < self.LEADER_OWN
    ns.Log("Bond", "leader %s: %s meets %s", slug, key, s.name)
    self:Reward("first", key, ns.PickLine(own and "first.leader." .. slug or "first.leader",
        { pet = ns.Registry:NameOf(key), leader = s.name }), true)
end

-- Its line: a named place's own (always), else a family's own now and then (first.place.<family>.N), else a general
-- one (first.place.N); each with the player's class's and race's mixed in (ns.Lines).
function Bond:PlaceLine(key, place)
    local slug = self.PLACE_SLUG[place]
    if slug and #ns.Lines("first.place." .. slug) > 0 then
        local prefix = "first.place." .. slug
        for _, f in ipairs(ns.Scenes:Families(key)) do
            if #ns.Variants(prefix .. "." .. f) > 0 then prefix = prefix .. "." .. f; break end
        end
        return ns.PickLine(prefix, { pet = ns.Registry:NameOf(key), place = place })
    end
    local family = ns.Scenes:Families(key)[1]
    local own = family and #ns.Lines("first.place." .. family) > 0 and ns.random() < self.PLACE_OWN
    local places = ns.DB.char.places[key]
    return ns.PickLine(own and "first.place." .. family or "first.place",
        { pet = ns.Registry:NameOf(key), place = place, count = places and Count(places) or nil })
end

function Bond:First(id, key, extra)
    local text, named
    if id == "boss" and type(extra) == "string" and extra ~= "" and extra ~= "?" then
        local firsts = ns.DB.char.firsts
        firsts[key] = firsts[key] or {}
        if firsts[key][extra] then return end
        firsts[key][extra] = true
        Bond.justFirst, Bond.justFirstAt = key .. "\31" .. extra, ns.Now() -- (Quirks' trophy: a boss new to this pet, whoever hears it first)
        local slug = self.BOSS_SLUG[extra]
        local prefix = slug and #ns.Lines("first.boss." .. slug) > 0 and "first.boss." .. slug or "first.boss"
        named = prefix ~= "first.boss"
        text = ns.PickLine(prefix, { pet = ns.Registry:NameOf(key), boss = extra, count = Count(firsts[key]) })
        if Count(firsts[key]) == 1 then ns.Story:Mine(key, "first.boss", extra) end -- (its very first)
    elseif id == "explore" and type(extra) == "string" then
        -- Its very first new place: the second it has seen with you (the first is where it came out).
        if Count(ns.DB.char.places[key]) == 2 then ns.Story:Mine(key, "first.place", extra) end
        -- Its line only now and then (2026-11-12, the user: every new place read like an achievement, as if
        -- the pet should see them all; "we could still award exploration points, just not output it to chat
        -- every time"): by chance, likelier for a curious family and trait. The points come either way.
        local slug = self.PLACE_SLUG[extra]
        named = slug ~= nil and #ns.Lines("first.place." .. slug) > 0 -- (its own words: past the cap)
        text = (slug or ns.random() < self:PlaceChance(key)) and self:PlaceLine(key, extra) or false
    else
        return
    end
    self:Reward("first", key, text, named)
end

-- Past midnight the day's visit comes with the first thing done, and asks the calendar for the
-- new day's holidays, which answers a second later (Holidays:On is nil until then): a game
-- holiday's day (Festglad, Tivolidyr's Darkmoon days) counted once (code review 2026-11-13). When
-- it answers, the visits made today get the rest, within the day's limit. (At login the calendar
-- answers well before the visit, 30 s in.)
function Bond:DayAgain()
    local d = ns.DB.char.bondToday
    if not (d and d.day == ns.Today() and d.pets) then return end
    local now = ns.Now()
    for key, p in pairs(d.pets) do
        local x, why = 1, nil
        if p.dayX then x, why = ns.Personality:DayFactor(key, now) end
        if x > (p.dayX or x) then
            local day, rate = ns.Config.BOND_DAY_POINTS * (p.comeback and Bond.COMEBACK_X or 1), self:Rate(key)
            local more = math.ceil(day * x * rate) - math.ceil(day * p.dayX * rate)
            ns.Log("Bond", "day again for %s: x%d (+%d)", key, x, more)
            p.dayX = x
            if why and why.dayFlavor then Flavor(p, key, why.dayFlavor(ns.Registry:NameOf(key), now)) end
            Grant(p, more, key)
        end
    end
end

-- A long break (BREAK) starts the day's line over (2026-11-26, the user, from the log: the day's line went to a hearth at
-- 01:43, after a dungeon, and the 10:51 session of nearly three hours had none). The server's day is one; a
-- player's evening and next morning are two. The line only: points and caps stay the day's. Logged out at
-- PLAYER_LOGOUT (a /reload too, seconds apart; a crash leaves the last one, so no line again).
Bond.BREAK = 5 * 3600 -- (6 until 2026-11-27, the user: 5 "for now", not to cause too much spam; 3.4 h apart kept it)
function Bond:Rested()
    local left, d = ns.DB.char.leftAt, ns.DB.char.bondToday
    if not (left and d and d.day == ns.Today() and d.pets) or ns.Now() - left < self.BREAK then return end
    for _, p in pairs(d.pets) do p.flavor = nil end
    ns.Log("Bond", "back after %.1f h: the day's line again", (ns.Now() - left) / 3600)
end

function Bond:Init()
    self:CheckComeback() -- (first: the day's visit 30 s in takes what it owes)
    self:Rested()
    ns.Events:On("PLAYER_LOGOUT", Bond, function() ns.DB.char.leftAt = ns.Now() end)
    ns.Bus:On("HOLIDAYS", function() Bond:DayAgain() end)
    ns.Bus:On("SENSE", function(kind, s) if kind == "glance" then Bond:Leader(s) end end)
    ns.Sense:Want("glance", Bond)
    -- Any pet of ours that's out: its own bond (the summoned pet is always ours).
    ns.Bus:On("ACTIVITY", function(id, n, key, _, extra)
        if not key then return end
        Bond:First(id, key, extra) -- (first: its line goes out, and the day's flavor waits, Flavor)
        Bond:OnActivity(id, n, key)
    end)
    ns.Bus:On("MY_RECORD", function()
        Bond:Seed()
        Bond:Watch()
    end)
    ns.Bus:On("ACTIVE_PET", function() Bond:Watch() end)
    ns.Bus:On("BOND_LEVEL", function() Bond:Watch() end) -- (a minor like unlocked: Personality)
    -- After the login SYNC: our own entry may have come back from a peer.
    -- Then publish it once: gains that waited for the lazy publish when we
    -- logged out would otherwise wait for the next level (the digest holds
    -- levels, not points).
    C_Timer.After(20, function()
        Bond:Seed()
        Bond:Watch()
        local key = ns.Registry:MyPet()
        if key and ns.Registry:Life(key, ns.PlayerKey()) then Publish(key) end
    end)
end

ns.Start("login", function() Bond:Init() end)
