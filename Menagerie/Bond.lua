local _, ns = ...

-- The bond (bånd) between a member and the companion they care for
-- (docs/PET_LIFE.md). Points grow and never shrink; they pause while you're
-- away. The bond belongs to the pair, so letting a pet go and adopting it
-- again picks up where you left off. Everyone sees everyone's bond.
--
-- Points: Config.BOND_DAY_POINTS for each calendar day with your adopted
-- companion out (the activity engine's "day"). More activities come later.
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

-- Watch the daily visit only while we care for a pet.
function Bond:Watch()
    if ns.Registry:MyPet() then
        ns.Activity:Want("day", Bond)
    else
        ns.Activity:Drop("day", Bond)
    end
end

function Bond:Init()
    ns.Bus:On("ACTIVITY", function(id, n, _, mine)
        if id == "day" and mine then Bond:Add(ns.Config.BOND_DAY_POINTS * (n or 1)) end
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
