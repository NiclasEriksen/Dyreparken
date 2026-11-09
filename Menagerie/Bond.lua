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
function Bond:Room()
    local key, r = ns.Registry:MyPet()
    if not key then return 0 end
    local e = ns.Registry:Life(key, ns.PlayerKey())
    local f = e and math.min(e.f, r.at) or r.at
    return math.max(0, ns.Registry.LifeCap(f, ns.Now()) - (e and e.p or 0))
end

-- Add points to our bond with the pet we hold. Returns the new points.
function Bond:Add(points)
    local key, r = ns.Registry:MyPet()
    if not key or points <= 0 then return nil end
    local me, now = ns.PlayerKey(), ns.Now()
    local g = ns.DB:Guild()
    local e = ns.Registry:Life(key, me)
    local before = e and e.p or 0
    local f = e and math.min(e.f, r.at) or r.at
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
        ns.Bonds:TellNameUnlock()
        Publish(key)
    elseif not e then
        Publish(key) -- a new bond: everyone should know of it
    else
        Schedule(key)
    end
    ns.Bus:Fire("BOND", key)
    return p
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

-- Always watched while we care for a pet; the traits' own activities
-- (dance, chat, dive...) only for a pet that likes them, so nobody else
-- pays for those events.
Bond.ACTIVITIES = { "day", "boss", "quest", "taxi", "pvp", "herb", "mine", "fish", "skin" }
local watching = {}

function Bond:Watch()
    local key = ns.Registry:MyPet()
    local want = {}
    if key then
        for _, id in ipairs(self.ACTIVITIES) do want[id] = true end
        for id in pairs((ns.Personality:Of(key))) do want[id] = true end
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

-- Today's points so far: per cap key (an activity, or "trait:<id>") and in
-- all (total), for a calendar day.
local function Ledger()
    local today = ns.Today()
    local d = ns.DB.char.bondToday
    if not d or d.day ~= today then
        d = { day = today, got = {}, total = 0 }
        ns.DB.char.bondToday = d
    end
    d.total = d.total or 0 -- (a day saved before the daily limit)
    return d
end

-- Points earned today, and the most a day can bring (Config.BOND_DAILY_MAX:
-- the day itself and every activity together, decided 2026-11-08).
function Bond:Today()
    return Ledger().total, ns.Config.BOND_DAILY_MAX
end

-- Give points within what's left of today's limit; one line when it's full.
local function Grant(d, points, key)
    points = math.min(points, ns.Config.BOND_DAILY_MAX - d.total, Bond:Room())
    if points <= 0 then return nil end
    -- Counted before Add: Add refreshes the card, which shows today's points.
    d.total = d.total + points
    if d.total >= ns.Config.BOND_DAILY_MAX then -- (once: a full day stops before this)
        ns.Print(ns.T("bond.full", { pet = ns.Bonds:NameOf(key) }))
    end
    return Bond:Add(points)
end

-- One line of flavor a day, for the first thing the pet loved.
local function Flavor(d, text)
    if d.flavor or not text then return end
    d.flavor = true
    ns.Print(("|cffffd100%s|r"):format(text))
end

-- Extra points (today's wish), within the day's limit.
function Bond:Bonus(points, key)
    return Grant(Ledger(), points, key)
end

-- Points for an activity done with our adopted pet out.
function Bond:OnActivity(id, n, key)
    local C, P = ns.Config, ns.Personality
    local name = ns.Bonds:NameOf(key)
    n = n or 1
    if id == "day" then
        local now = ns.Now()
        local x, why = P:DayFactor(key, now)
        local d = Ledger()
        if why and why.dayFlavor then Flavor(d, why.dayFlavor(name, now)) end
        return Grant(d, C.BOND_DAY_POINTS * n * x, key)
    end
    local d = Ledger()
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
    local room = math.min(cap - (d.got[capKey] or 0), C.BOND_DAILY_MAX - d.total)
    if room <= 0 then return nil end
    local points = math.min(per * n, room)
    d.got[capKey] = (d.got[capKey] or 0) + points
    Flavor(d, flavor)
    return Grant(d, points, key)
end

function Bond:Init()
    ns.Bus:On("ACTIVITY", function(id, n, key, mine)
        if mine then Bond:OnActivity(id, n, key) end
    end)
    ns.Bus:On("MY_RECORD", function()
        Bond:Seed()
        Bond:Watch()
    end)
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
