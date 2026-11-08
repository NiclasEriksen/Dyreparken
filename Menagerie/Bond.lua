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

-- Levels: { points needed, name }. 300 points (30 days) is "Venn", 1000
-- (100 days) "God venn", 3650 (a year) "Uatskillelig": the old loyalty
-- achievements keep their pace (Defs.lua).
Bond.LEVELS = {
    { 0, "Bekjent" },
    { 100, "Kamerat" },
    { 300, "Venn" },
    { 1000, "God venn" },
    { 2000, "Bestevenn" },
    { 3650, "Uatskillelig" },
    { 6000, "Sjelevenn" },
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
    return ("%s (nivå %d)"):format(name, level)
end

------------------------------------------------------------------------------
-- Our own bond
------------------------------------------------------------------------------
local pending -- the scheduled publish, if any

local function Publish(key)
    pending = nil
    local e = ns.Registry:Life(key, ns.PlayerKey())
    if e then ns.Bus:Fire("MY_BOND", key, e) end
end

local function Schedule(key)
    if pending then return end
    local token = {}
    pending = token
    C_Timer.After(PUBLISH_AFTER, function()
        if pending == token then Publish(key) end
    end)
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
    -- Within what the wire accepts (Registry ValidLife), so every copy merges.
    local cap = (math.floor((now - f) / 86400) + 1) * ns.Config.BOND_DAILY_MAX
    local p = math.min(before + points, cap)
    g.life[key] = g.life[key] or {}
    g.life[key][me] = { p = p, f = f, t = math.max(now, e and e.t or 0) }
    local oldLevel = self:Level(before)
    local level, name = self:Level(p)
    ns.Log("Bond", "%s +%d -> %d (level %d)", key, points, p, level)
    if level > oldLevel then
        ns.Print(("|cffffd100Båndet ditt med %s er nå på nivå %d: %s!|r"):format(ns.Bonds:NameOf(key), level, name))
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

Bond.ACTIVITIES = { "day", "boss", "quest", "taxi", "pvp", "herb", "mine", "fish", "skin" }

-- Watch the activities only while we care for a pet.
function Bond:Watch()
    local have = ns.Registry:MyPet() ~= nil
    for _, id in ipairs(self.ACTIVITIES) do
        if have then ns.Activity:Want(id, Bond) else ns.Activity:Drop(id, Bond) end
    end
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

-- Today's points so far, per cap key (an activity, or "trait:<id>").
local function Today()
    local today = date("%Y%m%d", ns.Now())
    local d = ns.DB.char.bondToday
    if not d or d.day ~= today then
        d = { day = today, got = {} }
        ns.DB.char.bondToday = d
    end
    return d
end

-- One line of flavor a day, for the first thing the pet loved.
local function Flavor(d, text)
    if d.flavor or not text then return end
    d.flavor = true
    ns.Print(("|cffffd100%s|r"):format(text))
end

-- Points for an activity done with our adopted pet out.
function Bond:OnActivity(id, n, key)
    local C, P = ns.Config, ns.Personality
    local name = ns.Bonds:NameOf(key)
    n = n or 1
    if id == "day" then
        local now = ns.Now()
        local x, why = P:DayFactor(key, now)
        if why and why.dayFlavor then Flavor(Today(), why.dayFlavor(name, now)) end
        return self:Add(C.BOND_DAY_POINTS * n * x)
    end
    local d = Today()
    local likes = P:Of(key)
    local capKey, per, cap, flavor = id, C.BOND_OTHER_POINTS, C.BOND_OTHER_CAP, nil
    if likes[id] then
        per, cap = C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
        flavor = ("%s koste seg med %s!"):format(name, P.NOUN[id])
    elseif P:WantsContext(key) then
        -- A unit name we can't read mustn't cost the points: no bonus then.
        local ok, ctx = pcall(Bond.Context)
        for _, t in ipairs(ok and P:Fitting(key, ctx) or {}) do
            if (d.got["trait:" .. t.id] or 0) < C.BOND_LIKED_CAP then
                capKey, per, cap = "trait:" .. t.id, C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
                flavor = t.flavor:format(name)
                break
            end
        end
    end
    local room = cap - (d.got[capKey] or 0)
    if room <= 0 then return nil end
    local points = math.min(per * n, room)
    d.got[capKey] = (d.got[capKey] or 0) + points
    Flavor(d, flavor)
    return self:Add(points)
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
    C_Timer.After(20, function()
        Bond:Seed()
        Bond:Watch()
    end)
end
