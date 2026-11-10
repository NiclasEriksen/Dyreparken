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
--
-- Bond is data: it prints nothing. What players read about it is Bonds.lua's,
-- from the Bus: BOND_LEVEL (key, level, name), BOND_FULL (key), BOND_LINE
-- (key, text: a liked thing's flavor, a wish, a first, a playdate).
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
        ns.Bus:Fire("BOND_FULL", key)
    end
    return Bond:Add(points, key)
end

-- One line of flavor a day, for the first thing the pet loved.
local function Flavor(d, key, text)
    if d.flavor or not text then return end
    d.flavor = true
    ns.Bus:Fire("BOND_LINE", key, text)
end

-- The rewards beyond activities, each a line and points (Config names: read
-- when given, so a tunable change applies at once). once: at most one a day
-- per pet. lines: at most that many lines a day per pet (the points go on).
-- A new one is a row here and a Bond:Reward call where it happens.
Bond.REWARDS = {
    wish = { points = "BOND_WISH_POINTS" },  -- today's wish done (Wish.lua: once a day already)
    first = { points = "BOND_FIRST_POINTS", lines = "FIRST_LINES" }, -- a first together
    play = { points = "BOND_PLAY_POINTS", once = true }, -- a playdate (Playdate.lua)
}

-- A reward for a pet: its line, then its points within the day's limit and
-- at the pet's rate. False if a once-a-day one was had today.
function Bond:Reward(kind, key, text)
    local def = assert(self.REWARDS[kind], "undeclared reward")
    local d = Ledger(key)
    d.had = d.had or {}
    local n = (d.had[kind] or 0) + 1
    if def.once and n > 1 then return false end
    d.had[kind] = n
    if not def.lines or n <= ns.Config[def.lines] then ns.Bus:Fire("BOND_LINE", key, text) end
    ns.Log("Bond", "reward %s for %s", kind, key)
    Grant(d, math.ceil(ns.Config[def.points] * self:Rate(key)), key)
    return true
end

-- Points for an activity done with a pet of ours out (half for one we
-- haven't adopted: Bond:Rate).
function Bond:OnActivity(id, n, key)
    local C, P = ns.Config, ns.Personality
    local name = ns.Registry:NameOf(key)
    local rate = self:Rate(key)
    local function Scaled(v) return math.ceil(v * rate) end
    n = n or 1
    if id == "day" then
        local now = ns.Now()
        local x, why = P:DayFactor(key, now)
        local d = Ledger(key)
        if why and why.dayFlavor then Flavor(d, key, why.dayFlavor(name, now)) end
        return Grant(d, Scaled(C.BOND_DAY_POINTS * n * x), key)
    end
    local likes = P:Of(key)
    -- The bond counts what it watches itself (Bond:Watch): the activities
    -- every pet bonds over, and this pet's likes. Others watch more (the
    -- debug log, Quirks' dislikes and eggs, another pet's likes); those
    -- mustn't give points.
    if not likes[id] and not ns.Activity.KIND[id].always then return end
    local d = Ledger(key)
    local capKey, per, cap, flavor = id, C.BOND_OTHER_POINTS, C.BOND_OTHER_CAP, nil
    if likes[id] then
        per, cap = C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
        flavor = P.FLAVOR[id] and ns.Fill(P.FLAVOR[id], { pet = name })
            or ns.T("bond.liked", { pet = name, activity = P.NOUN[id] })
        -- Home by name (2026-11-10): the inn you're bound to. GetBindLocation is unverified on Forever.
        local home = id == "hearth" and type(GetBindLocation) == "function" and ns.Plain(GetBindLocation())
        if type(home) == "string" and home ~= "" then flavor = ns.T("activity.hearth.flavor_home", { pet = name, home = home }) end
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
    Flavor(d, key, flavor)
    return Grant(d, points, key)
end

-- Firsts together (2026-11-09): the first time a pet is along when a given
-- boss falls, or sees a given place (Activity: "explore" fires only for a
-- place new to that pet), it gets BOND_FIRST_POINTS and a line, at most
-- FIRST_LINES lines a day per pet (the points go on: REWARDS.first).
function Bond:First(id, key, extra)
    local text
    if id == "boss" and type(extra) == "string" and extra ~= "" and extra ~= "?" then
        local firsts = ns.DB.char.firsts
        firsts[key] = firsts[key] or {}
        if firsts[key][extra] then return end
        firsts[key][extra] = true
        text = ns.T("first.boss", { pet = ns.Registry:NameOf(key), boss = extra })
    elseif id == "explore" and type(extra) == "string" then
        text = ns.T("first.place", { pet = ns.Registry:NameOf(key), place = extra })
    else
        return
    end
    self:Reward("first", key, text)
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

ns.Start("login", function() Bond:Init() end)
