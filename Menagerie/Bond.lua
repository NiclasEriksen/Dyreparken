local _, ns = ...

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
-- thing each day gets one line of flavor.
-- A pet adopted before bonds existed starts with that many points per day
-- already together, so nobody starts over.
--
-- Data: g.life[petKey][carer] (Registry.lua), written only by the carer.
-- Publishing: a level-up goes out at once (BOND); smaller gains wait up to
-- PUBLISH_AFTER, one timer at most. The login SYNC carries everything anyway.
local Bond = {}
ns.Bond = Bond

local PUBLISH_AFTER = 1800 -- seconds

-- Levels: { points needed, name }. A curve to 2250 for the top, each step
-- longer than the last, with at most Config.BOND_DAILY_MAX (75) a day: 30
-- days to Sjelevenn at the very least (decided 2026-11-09). At 10 a day
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

-- "Venn (nivå 3)" for a pet's current bond, or nil.
function Bond:Label(key)
    local p, level, name = self:Of(key)
    if not p then return nil end
    return ns.T("bond.label", { level = name, n = level })
end

------------------------------------------------------------------------------
-- Our own bond
------------------------------------------------------------------------------
local pending -- the scheduled publish, if any
local pendingKeys = {} -- pets with gains waiting for it (a pet swap within the wait keeps both)

local function Publish(key)
    pendingKeys[key] = nil
    local e = ns.Registry:Life(key, ns.PlayerKey())
    if e then ns.Bus:Fire("MY_BOND", key, e) end
end

local function Schedule(key)
    pendingKeys[key] = true
    if pending then return end
    local token = {}
    pending = token
    C_Timer.After(PUBLISH_AFTER, function()
        if pending ~= token then return end
        pending = nil
        for k in pairs(pendingKeys) do Publish(k) end
    end)
end

-- How many more points our bond with the pet we hold can take now, under
-- the wire's cap (Registry.LifeCap); 0 without a pet.
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
function Bond:Add(points, key)
    key = key or ns.Registry:MyPet()
    if not key or points <= 0 then return nil end
    local me, now = ns.PlayerKey(), ns.Now()
    local g = ns.DB:Guild()
    if not g then return nil end
    local e = ns.Registry:Life(key, me)
    local before = e and e.p or 0
    local f = Start(key, e)
    -- Within what the wire accepts (Registry.LifeCap), so every copy merges;
    -- never below what we had (a copy that was valid stays ours).
    local p = math.max(before, math.min(before + points, ns.Registry.LifeCap(f, now)))
    g.life[key] = g.life[key] or {}
    g.life[key][me] = { p = p, f = f, t = math.max(now, e and e.t or 0) }
    local oldLevel = self:Level(before)
    local level, name = self:Level(p)
    ns.Log("Bond", "%s +%d -> %d (level %d)", key, points, p, level)
    if level > oldLevel then
        ns.Print(ns.T("bond.levelup", { pet = ns.Bonds:NameOf(key), n = level, level = name }))
        if key == ns.Registry:MyPet() then ns.Bonds:TellNameUnlock() end
        Publish(key)
    elseif not e then
        Publish(key) -- a new bond: everyone should know of it
    else
        Schedule(key)
    end
    ns.Bus:Fire("BOND", key)
    return p
end

-- Our bond with a pet, as the card shows it: points, level, name, start of
-- the level, next level's points; and whether it's ours. Ours when we have
-- one or own the pet (possibly 0 points); else its holder's, if any.
function Bond:Shown(key)
    local e = key and ns.Registry:Life(key, ns.PlayerKey())
    if e or (key and ns.Pets:IsOwned(key)) then
        local p = e and e.p or 0
        local level, name, from, nextAt = self:Level(p)
        return p, level, name, from, nextAt, true
    end
    local p, level, name, from, nextAt = self:Of(key)
    if p then return p, level, name, from, nextAt, false end
end

-- A pet adopted before bonds existed, or re-adopted: make sure there's an
-- entry, seeded from the days together (never lowering what's there).
function Bond:Seed()
    local key, r = ns.Registry:MyPet()
    if not key then return end
    local me = ns.PlayerKey()
    local e = ns.Registry:Life(key, me)
    if e then return end
    local days = math.max(0, math.floor((ns.Now() - r.at) / 86400))
    if days == 0 then return end -- a new adoption starts empty; the first day's visit creates it
    self:Add(days * ns.Config.BOND_DAY_POINTS)
    ns.Log("Bond", "seeded %s with %d (%d days)", key, days * ns.Config.BOND_DAY_POINTS, days)
end

-- Always watched (any pet of ours can bond); the traits' own activities
-- (dance, chat, dive...) only for the pets we'd have out that like them, so
-- nobody else pays for those events.
Bond.ACTIVITIES = { "day", "boss", "quest", "taxi", "pvp", "herb", "mine", "fish", "skin", "explore", "skill", "rep" }
local watching = {}

function Bond:Watch()
    local want = {}
    for _, id in ipairs(self.ACTIVITIES) do want[id] = true end
    -- The traits' activities of the pets we'd have out: the adopted one and
    -- the active one (Summon.lua).
    for _, key in ipairs({ ns.Registry:MyPet() or false, ns.Summon:ActiveKey() or false }) do
        if key then for id in pairs((ns.Personality:Of(key))) do want[id] = true end end
    end
    for id in pairs(watching) do
        if not want[id] then ns.Activity:Drop(id, Bond) end
    end
    for id in pairs(want) do
        if not watching[id] then ns.Activity:Want(id, Bond) end
    end
    watching = want
end

-- What the "when" traits read (Personality.lua): the time, the group and
-- its guildmates, and whether we're in a dungeon or raid (not a
-- battleground). Built only for a pet that has such a trait.
function Bond.Context()
    local ctx = { t = ns.Now(), group = IsInGroup() == true, guildmates = 0 }
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

-- Points a pet earned today, and the most its day can bring.
function Bond:Today(key)
    key = key or ns.Registry:MyPet()
    if not key then return 0, ns.Config.BOND_DAILY_MAX end
    return Ledger(key).total, self:DailyMax(key)
end

-- Give points within what's left of the pet's day; one line when it's full.
local function Grant(d, points, key)
    local max = Bond:DailyMax(key)
    points = math.min(points, max - d.total, Bond:Room(key))
    if points <= 0 then return nil end
    -- Counted before Add: Add refreshes the card, which shows today's points.
    d.total = d.total + points
    if d.total >= max then -- (once: a full day stops before this)
        ns.Print(ns.T("bond.full", { pet = ns.Bonds:NameOf(key) }))
    end
    return Bond:Add(points, key)
end

-- One line of flavor a day, for the first thing the pet loved.
local function Flavor(d, text)
    if d.flavor or not text then return end
    d.flavor = true
    ns.Print(("|cffffd100%s|r"):format(text))
end

-- A playdate for a pet today: true the first time (Playdate), nil after.
function Bond:Playdate(key)
    local d = Ledger(key)
    if d.played then return nil end
    d.played = true
    return true
end

-- Extra points (today's wish, a first, a playdate), within the day's limit
-- and at the pet's rate.
function Bond:Bonus(points, key)
    return Grant(Ledger(key), math.ceil(points * self:Rate(key)), key)
end

-- Points for an activity done with a pet of ours out (half for one we
-- haven't adopted: Bond:Rate).
function Bond:OnActivity(id, n, key)
    local C, P = ns.Config, ns.Personality
    local name = ns.Bonds:NameOf(key)
    local rate = self:Rate(key)
    local function Scaled(v) return math.ceil(v * rate) end
    n = n or 1
    if id == "day" then
        local now = ns.Now()
        local x, why = P:DayFactor(key, now)
        local d = Ledger(key)
        if why and why.dayFlavor then Flavor(d, why.dayFlavor(name, now)) end
        return Grant(d, Scaled(C.BOND_DAY_POINTS * n * x), key)
    end
    local d = Ledger(key)
    local likes = P:Of(key)
    local capKey, per, cap, flavor = id, C.BOND_OTHER_POINTS, C.BOND_OTHER_CAP, nil
    if likes[id] then
        per, cap = C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
        flavor = P.FLAVOR[id] and ns.Fill(P.FLAVOR[id], { pet = name })
            or ns.T("bond.liked", { pet = name, activity = P.NOUN[id] })
    elseif P:WantsContext(key) then
        -- A unit name we can't read mustn't cost the points: no bonus then.
        local ok, ctx = pcall(Bond.Context)
        for _, t in ipairs(ok and P:Fitting(key, ctx) or {}) do
            if (d.got["trait:" .. t.id] or 0) < C.BOND_LIKED_CAP then
                capKey, per, cap = "trait:" .. t.id, C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
                flavor = ns.Fill(t.flavor, { pet = name })
                break
            end
        end
    end
    per, cap = Scaled(per), Scaled(cap)
    local room = math.min(cap - (d.got[capKey] or 0), self:DailyMax(key) - d.total)
    if room <= 0 then return nil end
    local points = math.min(per * n, room)
    d.got[capKey] = (d.got[capKey] or 0) + points
    Flavor(d, flavor)
    return Grant(d, points, key)
end

-- Firsts together (2026-11-09): the first time a pet is along when a given
-- boss falls, or sees a given place (Activity: "explore" fires only for a
-- place new to that pet), it gets BOND_FIRST_POINTS and a line, at most
-- FIRST_LINES lines a day per pet (the points go on).
function Bond:First(id, key, extra)
    local text
    if id == "boss" and type(extra) == "string" and extra ~= "" and extra ~= "?" then
        local firsts = ns.DB.char.firsts
        firsts[key] = firsts[key] or {}
        if firsts[key][extra] then return end
        firsts[key][extra] = true
        text = ns.T("first.boss", { pet = ns.Bonds:NameOf(key), boss = extra })
    elseif id == "explore" and type(extra) == "string" then
        text = ns.T("first.place", { pet = ns.Bonds:NameOf(key), place = extra })
    else
        return
    end
    local d = Ledger(key)
    d.firsts = (d.firsts or 0) + 1
    if d.firsts <= ns.Config.FIRST_LINES then ns.Print(("|cffffd100%s|r"):format(text)) end
    self:Bonus(ns.Config.BOND_FIRST_POINTS, key)
end

function Bond:Init()
    -- Any pet of ours that's out: its own bond (the summoned pet is always ours).
    ns.Bus:On("ACTIVITY", function(id, n, key, _, extra)
        if not key then return end
        Bond:OnActivity(id, n, key)
        Bond:First(id, key, extra)
    end)
    ns.Bus:On("MY_RECORD", function()
        Bond:Seed()
        Bond:Watch()
    end)
    ns.Bus:On("ACTIVE_PET", function() Bond:Watch() end)
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
