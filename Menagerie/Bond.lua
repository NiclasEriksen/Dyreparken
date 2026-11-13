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

-- "Venn (level 3)" for a pet's current bond, or nil.
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
    if p > before then
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

-- Points a pet earned today, and the most its day can bring.
function Bond:Today(key)
    key = key or ns.Registry:MyPet()
    if not key then return 0, ns.Config.BOND_DAILY_MAX end
    return Ledger(key).total, self:DailyMax(key)
end

-- What the pet's day still has room for, of points.
local function Grantable(d, points, key)
    return math.max(0, math.min(points, Bond:DailyMax(key) - d.total, Bond:Room(key)))
end

-- Give points within what's left of the pet's day; one line when it's full.
local function Grant(d, points, key)
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

-- One line of flavor a day, for the first thing the pet loved.
local function Flavor(d, key, text)
    if d.flavor or not text then return end
    d.flavor = true
    ns.Bus:Fire("BOND_LINE", key, text, "like")
end

-- The rewards beyond activities, each a line and points (Config names: read
-- when given, so a tunable change applies at once). once: at most one a day
-- per pet. lines: at most that many lines a day per pet (the points go on).
-- cap: at most that many points a day per pet from it (the lines go on).
-- kind: how the pet frame shows its line (PET_SAID, Bonds.lua: "like" unless said; "major" for the big ones).
-- beyond: past the day's limit (BOND_DAILY_MAX), and not counted in it: a feat (2026-11-12, the user:
-- "major feats should not count towards the daily limit, they're supposed to be huge bonuses"; one on a
-- full day was lost for good). Still within the wire's cap (Bond:Add, Registry.LifeCap: the days so far
-- and a spare one, so at least 75 left even after a full day): no protocol change. The wish too
-- (2026-11-13, the user: "Yes, definitely past the cap"): 10 more on a full day, so after a week of
-- full days with every wish done the bond reaches LifeCap, and from then a day brings what the cap
-- has grown by (75), wish and all; Add clamps to it, and the line says what was really given (Room).
-- More room a day for the wish (LifeCap's 75 + 10) waits for the next protocol bump: peers check it.
-- A new one is a row here and a Bond:Reward call where it happens.
Bond.REWARDS = {
    -- today's wish done. once here too: Wish.lua starts a fresh wish when you adopt the
    -- pet again the same day, and it paid twice (code review 2026-11-11).
    wish = { points = "BOND_WISH_POINTS", once = true, beyond = true, kind = "major" },
    first = { points = "BOND_FIRST_POINTS", lines = "FIRST_LINES", cap = "BOND_FIRST_CAP" }, -- a first together
    play = { points = "BOND_PLAY_POINTS", once = true }, -- a playdate (Playdate.lua)
    contest = { points = "BOND_CONTEST_POINTS", once = true }, -- fishing in the Sunday contest (Bond:Contest)
    feat = { points = "BOND_FEAT_POINTS", beyond = true, kind = "major" }, -- a feat (Feats.lua): once per character already, so not once a day
}

-- A pet that likes fishing, out while you fish in Stranglethorn on the fishing contest's day
-- (the calendar's Stranglethorn Fishing Extravaganza, Holidays.lua): a bonus, once that day
-- (the user, 2026-11-11).
function Bond:Contest(key)
    if not (key and ns.Personality:Of(key).fish and ns.Holidays:Has(ns.Now(), "stvfishing")) then return end
    if ns.Plain(GetZoneText()) ~= "Stranglethorn Vale" then return end
    self:Reward("contest", key, Bond.Line("bond.contest", "bond.contest.full", { pet = ns.Registry:NameOf(key) }))
end

-- A reward's line that tells what it really gave (code review 2026-11-13: a full day's wish said
-- "+10" and gave nothing): `textKey` with {n}, or `fullKey`, without the amount, when it gave none.
function Bond.Line(textKey, fullKey, vars)
    return function(n)
        vars.n = n
        return ns.T(n > 0 and textKey or fullKey, vars)
    end
end

-- A reward for a pet: its line, then its points within the day's limit and
-- at the pet's rate. False if a once-a-day one was had today. text false: the
-- points without a line (a new place most of the time); not counted in `lines`.
-- text a function (Bond.Line): called with the points it gives, worked out first.
function Bond:Reward(kind, key, text)
    local def = assert(self.REWARDS[kind], "undeclared reward")
    local d = Ledger(key)
    d.had = d.had or {}
    local n = (d.had[kind] or 0) + 1
    if def.once and n > 1 then return false end
    local points = math.ceil(ns.Config[def.points] * self:Rate(key))
    local capKey = def.cap and "reward:" .. kind
    if capKey then
        points = math.max(0, math.min(points, math.ceil(ns.Config[def.cap] * self:Rate(key)) - (d.got[capKey] or 0)))
    end
    if type(text) == "function" then
        text = text(def.beyond and math.min(points, self:Room(key)) or Grantable(d, points, key))
    end
    if text then
        d.had[kind] = n
        if not def.lines or n <= ns.Config[def.lines] then ns.Bus:Fire("BOND_LINE", key, text, def.kind or "like") end
    end
    ns.Log("Bond", "reward %s for %s", kind, key)
    if def.beyond then self:Add(points, key); return true end
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
        if why and why.dayFlavor then Flavor(d, key, why.dayFlavor(name, now)) end
        return Grant(d, Scaled(C.BOND_DAY_POINTS * n * x), key)
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
    local capKey, per, cap, flavor = id, C.BOND_OTHER_POINTS, C.BOND_OTHER_CAP, nil
    if likes[id] then
        per, cap = C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP
        flavor = P.FLAVOR[id] and ns.Fill(P.FLAVOR[id], { pet = name })
            or ns.T("bond.liked", { pet = name, activity = P.NOUN[id] })
        -- Home by name (2026-11-10): the inn you're bound to (GetBindLocation works on Forever: /dp probe api, 2026-11-11).
        local home = id == "hearth" and type(GetBindLocation) == "function" and ns.Plain(GetBindLocation())
        if type(home) == "string" and home ~= "" then flavor = ns.T("activity.hearth.flavor_home", { pet = name, home = home }) end
    elseif P:WantsContext(key) then
        -- A unit name we can't read mustn't cost the points: no bonus then.
        local ok, ctx = pcall(Bond.Context)
        for _, t in ipairs(ok and P:Fitting(key, ctx) or {}) do
            if (d.got["trait:" .. t.id] or 0) < Scaled(C.BOND_TRAIT_CAP) then -- (at the pet's rate, as the room below)
                capKey, per, cap = "trait:" .. t.id, C.BOND_LIKED_POINTS, C.BOND_TRAIT_CAP
                flavor = ns.Fill(t.flavor, { pet = name })
                break
            end
        end
    end
    -- A minor like, when no trait's moment gave more: fewer points, and its flavor a third as often
    -- (its first time in a day, by chance; the user, 2026-11-12).
    if minor and capKey == id then
        per, cap = C.BOND_MINOR_POINTS, C.BOND_MINOR_CAP
        if not d.got[capKey] and ns.random() < Bond.MINOR_FLAVOR then
            flavor = P.FLAVOR[id] and ns.Fill(P.FLAVOR[id], { pet = name })
                or ns.T("bond.liked", { pet = name, activity = P.NOUN[id] })
        end
    end
    per, cap = Scaled(per), Scaled(cap)
    local room = math.min(cap - (d.got[capKey] or 0), self:DailyMax(key) - d.total)
    -- Everyday activities (not liked, not a trait's moment) share a small pot too.
    local other = capKey == id and not likes[id] and not minor
    if other then room = math.min(room, Scaled(C.BOND_OTHER_TOTAL) - (d.got.other or 0)) end
    if room <= 0 then return nil end
    local points = math.min(per * n, room)
    d.got[capKey] = (d.got[capKey] or 0) + points
    if other then d.got.other = (d.got.other or 0) + points end
    Flavor(d, key, flavor)
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

-- Its line: a family's own now and then (first.place.<family>.N), else a general one (first.place.N).
function Bond:PlaceLine(key, place)
    local family = ns.Scenes:Families(key)[1]
    local own = family and ns.Variants("first.place." .. family) or {}
    local list = (#own > 0 and ns.random() < self.PLACE_OWN) and own or ns.Variants("first.place")
    return ns.T(list[ns.random(#list)], { pet = ns.Registry:NameOf(key), place = place })
end

function Bond:First(id, key, extra)
    local text
    if id == "boss" and type(extra) == "string" and extra ~= "" and extra ~= "?" then
        local firsts = ns.DB.char.firsts
        firsts[key] = firsts[key] or {}
        if firsts[key][extra] then return end
        firsts[key][extra] = true
        Bond.justFirst, Bond.justFirstAt = key .. "\31" .. extra, ns.Now() -- (Quirks' trophy: a boss new to this pet, whoever hears it first)
        text = ns.T("first.boss", { pet = ns.Registry:NameOf(key), boss = extra })
        if Count(firsts[key]) == 1 then ns.Story:Mine(key, "first.boss", extra) end -- (its very first)
    elseif id == "explore" and type(extra) == "string" then
        -- Its very first new place: the second it has seen with you (the first is where it came out).
        if Count(ns.DB.char.places[key]) == 2 then ns.Story:Mine(key, "first.place", extra) end
        -- Its line only now and then (2026-11-12, the user: every new place read like an achievement, as if
        -- the pet should see them all; "we could still award exploration points, just not output it to chat
        -- every time"): by chance, likelier for a curious family and trait. The points come either way.
        text = ns.random() < self:PlaceChance(key) and self:PlaceLine(key, extra) or false
    else
        return
    end
    self:Reward("first", key, text)
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
            local day, rate = ns.Config.BOND_DAY_POINTS, self:Rate(key)
            local more = math.ceil(day * x * rate) - math.ceil(day * p.dayX * rate)
            ns.Log("Bond", "day again for %s: x%d (+%d)", key, x, more)
            p.dayX = x
            if why and why.dayFlavor then Flavor(p, key, why.dayFlavor(ns.Registry:NameOf(key), now)) end
            Grant(p, more, key)
        end
    end
end

function Bond:Init()
    ns.Bus:On("HOLIDAYS", function() Bond:DayAgain() end)
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
