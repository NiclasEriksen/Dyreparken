local _, ns = ...

-- Quirks (2026-11-09): flavor with no effect on anything. The more little
-- surprises, the better, but quietly: at most one quirk line an hour
-- (char.quirkAt), and most only by chance.
--
-- Dislikes (Personality:Dislikes): something your pet doesn't like happened
-- with it out (a cat and the water). A line, by chance; the first one tells
-- you, and from then on the card shows it (char.dislikes). Until then it's
-- a secret.
--
-- Easter eggs (Quirks.EGGS): rare lines at certain moments: holidays, an
-- anniversary of the adoption, meeting its own kind, midnight. Each at most
-- once a day; they're counted (char.eggs) for an achievement some day.
--
-- Lines: Locale/nb.lua, dislike.<activity>.N and egg.<id>.N (one is picked).
-- The activities they need are watched like the bond's (Activity:Want).
local Quirks = {}
ns.Quirks = Quirks

Quirks.EVERY = 3600          -- seconds between quirk lines
Quirks.DISLIKE_CHANCE = 0.35 -- per disliked activity (with the hour free)
Quirks.random = math.random  -- (tests pin it)
-- A line comes a while after what caused it, not the instant it happens
-- (2026-11-10: "scared of flying" the moment you took off read as if it had
-- flown for ages). Seconds, picked at random within; a dislike takes longer
-- to sink in than an egg's moment.
Quirks.DELAY = { dislike = { 20, 60 }, egg = { 5, 20 } }

local T = ns.T

-- Every variant of a line: prefix.1, prefix.2, ...
local variants = {}
local function Variants(prefix)
    local list = variants[prefix]
    if not list then
        list = {}
        while ns.Strings[prefix .. "." .. (#list + 1)] do list[#list + 1] = prefix .. "." .. (#list + 1) end
        variants[prefix] = list
    end
    return list
end

local function Pick(prefix, vars)
    local list = Variants(prefix)
    if #list == 0 then return nil end
    return T(list[Quirks.random(#list)], vars)
end

-- A line decided and not yet said: nothing else is decided meanwhile.
local pending = { eggs = {} }

function Quirks:Ready()
    if pending.line then return false end
    local at = ns.DB.char.quirkAt
    return not at or ns.Now() - at >= self.EVERY
end

-- Decided now, said after the delay. What it uses up (the hour, an egg's
-- day, a dislike found) is saved only when it's said: a /reload in the
-- delay used to spend it unsaid (code review 2026-11-10). said(): saves
-- that, and what follows the line.
function Quirks:Say(text, why, kind, said)
    pending.line = true
    local span = self.DELAY[kind]
    local wait = span[1] + self.random() * (span[2] - span[1])
    ns.Log("Quirks", "%s, in %d s", why, wait)
    C_Timer.After(wait, function()
        pending.line = nil
        ns.DB.char.quirkAt = ns.Now()
        ns.Print("|cffd9b3ff" .. text .. "|r")
        if said then said() end
    end)
end

------------------------------------------------------------------------------
-- Dislikes
------------------------------------------------------------------------------
function Quirks:Dislike(key, id)
    if not self:Ready() or self.random() >= self.DISLIKE_CHANCE then return end
    local name = ns.Registry:NameOf(key)
    local text = Pick("dislike." .. id, { pet = name })
    if not text then return end
    local seen = ns.DB.char.dislikes
    local first = not (seen[key] and seen[key][id])
    self:Say(text, ("dislike %s %s"):format(key, id), "dislike", function()
        seen[key] = seen[key] or {}
        seen[key][id] = true
        ns.DB.char.sulk = { key = key, day = ns.Today() } -- (Moves: its back turned on the card, once)
        if not first then return end
        ns.Bus:Fire("DISLIKE_FOUND", key, id)
        ns.Print("|cffd9b3ff" .. T("dislike.found", { pet = name, what = ns.Personality.NOUN[id] }) .. "|r")
        if ns.JournalUI then ns.JournalUI:Refresh() end
    end)
end

------------------------------------------------------------------------------
-- Easter eggs: { id, on = activity (or "seen": a companion under the mouse),
-- chance (default 1), test = fn(ctx) -> vars or nil }. ctx: key, name (the
-- pet's), id, extra, t, family (set), today (the activity's count today).
-- `always`: not held back by the hour (rare by nature, and a day late is lost).
------------------------------------------------------------------------------
local function On(md) return function(ctx) return date("%m%d", ctx.t) == md and {} end end

local MILESTONES = { [200] = true, [500] = true, [1000] = true }

local function HasTrait(key, id)
    if not ns.Personality:Known(key) then return false end
    for _, t in ipairs(ns.Personality:Traits(key)) do if t.id == id then return true end end
    return false
end
local function Weekday(t) return tonumber(date("%w", t)) end -- 0 = Sunday
local function Hour(t) return tonumber(date("%H", t)) end

-- Easter Sunday of a year (the anonymous Gregorian algorithm): "MMDD".
function Quirks.Easter(y)
    local a, b, c = y % 19, math.floor(y / 100), y % 100
    local d, e = math.floor(b / 4), b % 4
    local f = math.floor((b + 8) / 25)
    local g = math.floor((b - f + 1) / 3)
    local h = (19 * a + b - d - g + 15) % 30
    local i, k = math.floor(c / 4), c % 4
    local l = (32 + 2 * e + 2 * i - h - k) % 7
    local m = math.floor((a + 11 * h + 22 * l) / 451)
    local n = h + l - 7 * m + 114
    return ("%02d%02d"):format(math.floor(n / 31), n % 31 + 1)
end

Quirks.EGGS = {
    { id = "mai17", on = "day", always = true, test = On("0517") },
    { id = "jul", on = "day", always = true, test = On("1224") },
    { id = "nyttar", on = "day", always = true, test = On("1231") },
    { id = "april", on = "day", always = true, test = On("0401") },
    { id = "halloween", on = "day", always = true, test = On("1031") },
    { id = "fredag13", on = "day", always = true,
        test = function(ctx) return date("%d%w", ctx.t) == "135" and {} end },
    -- Round days since you adopted it, on the day (calendar days, as the
    -- milestone lines count them; those have 30, 100 and the years).
    { id = "dager", on = "day", always = true, test = function(ctx)
        if ns.Registry:MyPet() ~= ctx.key then return end
        local _, _, r = ns.Registry:Status(ctx.key)
        if not (r and r.at) then return end
        local days = ns.Bonds.DayNumber(ctx.t) - ns.Bonds.DayNumber(r.at)
        return MILESTONES[days] and { n = days }
    end },
    -- (2026-11-10) Little ones. A test may name its own line (_key): a trait's variant.
    { id = "paske", on = "day", always = true,
        test = function(ctx) return date("%m%d", ctx.t) == Quirks.Easter(tonumber(date("%Y", ctx.t))) and {} end },
    { id = "klokka", on = "day", always = true, test = function(ctx) -- the clocks changed last night
        return date("*t", ctx.t).isdst ~= date("*t", ctx.t - 86400).isdst and {}
    end },
    { id = "mandag", on = "day", test = function(ctx) return Weekday(ctx.t) == 1 and HasTrait(ctx.key, "helgedyr") and {} end },
    { id = "morgen", on = "day", test = function(ctx)
        local h = Hour(ctx.t)
        if h < 5 or h >= 7 then return nil end -- (before five it's still night: midnight's own)
        return HasTrait(ctx.key, "nattugle") and { _key = "egg.morgen.nattugle" } or {}
    end },
    { id = "hopp", on = "jump", always = true, test = function(ctx) -- a hundred jumps (one "jump" is ten)
        if ctx.today ~= 10 then return nil end
        return HasTrait(ctx.key, "hoppetass") and { _key = "egg.hopp.hoppetass" } or {}
    end },
    { id = "lur", on = "nap", test = function(ctx) return ctx.today == 5 and {} end },
    { id = "midnattsdans", on = "dance", test = function(ctx) return Hour(ctx.t) == 0 and tonumber(date("%M", ctx.t)) < 30 and {} end },
    { id = "fredagstaco", on = "*", chance = 0.5, test = function(ctx)
        return Weekday(ctx.t) == 5 and Hour(ctx.t) >= 17 and (HasTrait(ctx.key, "glupsk") or ctx.family.cat) and {}
    end },
    { id = "lordagsgodt", on = "*", chance = 0.5,
        test = function(ctx) return Weekday(ctx.t) == 6 and HasTrait(ctx.key, "helgedyr") and {} end },
    { id = "leet", on = "*", test = function(ctx) return date("%H%M", ctx.t) == "1337" and {} end },
    -- Named: your own first name, or a name another pet in the park has.
    { id = "navnebror", on = "name", always = true, test = function(ctx)
        return ctx.extra == ns.PlayerKey():match("^(%S+)") and {}
    end },
    { id = "tvilling", on = "name", always = true, test = function(ctx)
        for key in pairs(ns.Registry:Holders()) do
            if key ~= ctx.key and ns.Registry:Nickname(key) == ctx.extra then return { nick = ctx.extra } end
        end
    end },
    -- Three or more guildmates' pets out with yours (Playdate).
    { id = "fullfest", on = "party", always = true, test = function(ctx)
        return { n = ctx.extra, _key = HasTrait(ctx.key, "flokkdyr") and "egg.fullfest.flokkdyr" or nil }
    end },
    { id = "midnatt", on = "*", chance = 0.5,
        test = function(ctx) return date("%H", ctx.t) == "00" and tonumber(date("%M", ctx.t)) < 10 and {} end },
    { id = "speil", on = "seen", test = function(ctx)
        return ns.Pets:SpeciesOfKey(ctx.key) == ctx.seen and { owner = ctx.extra }
    end },
    -- (2026-11-10) Someone who once cared for your pet walks by with theirs.
    { id = "kjenner", on = "seen", test = function(ctx)
        local e = ns.Registry:Life(ctx.key, ctx.extra)
        return e and e.p > 0 and { owner = ctx.extra }
    end },
    -- Another species of the same family: cousins.
    { id = "fetter", on = "seen", chance = 0.25, test = function(ctx)
        if ns.Pets:SpeciesOfKey(ctx.key) == ctx.seen then return nil end
        local theirs = ns.Scenes:Families(ns.Pets:KeyOfSpecies(ctx.seen))[1]
        return theirs and ctx.family[theirs] and { owner = ctx.extra }
    end },
    { id = "kattefisk", on = "fish", chance = 0.3, test = function(ctx) return ctx.family.cat and {} end },
    { id = "vinger", on = "taxi", chance = 0.3,
        test = function(ctx) return (ctx.family.bird or ctx.family.owl or ctx.family.dragon) and {} end },
    { id = "trofe", on = "boss", chance = 0.15, test = function(ctx)
        return type(ctx.extra) == "string" and ctx.extra ~= "" and ctx.extra ~= "?" and { boss = ctx.extra }
    end },
    { id = "dodsfall", on = "revive", test = function(ctx) return ctx.today >= 3 and {} end },
    { id = "kake", on = "level", test = function(ctx)
        local level = tonumber(ctx.extra)
        return level and level % 10 == 0 and { level = level }
    end },
    -- Every hundredth quest with this pet out (the hour doesn't hold it back:
    -- the next chance is a hundred quests away).
    { id = "oppdrag", on = "quest", always = true, test = function(ctx)
        local n = select(4, ns.Activity:Count("quest", ctx.key))
        return n > 0 and n % 100 == 0 and { n = n }
    end },
}
local eggsOn = {} -- activity -> its eggs
for _, e in ipairs(Quirks.EGGS) do
    eggsOn[e.on] = eggsOn[e.on] or {}
    table.insert(eggsOn[e.on], e)
end

local function Families(key)
    local set = {}
    for _, f in ipairs(ns.Scenes:Families(key)) do set[f] = true end
    return set
end

-- Eggs on moments that aren't activities: "*" eggs don't ride on them.
local MOMENTS = { seen = true, name = true, party = true }

function Quirks:Egg(on, key, extra, seen)
    local list = {}
    for _, e in ipairs(eggsOn[on] or {}) do list[#list + 1] = e end
    if not MOMENTS[on] then for _, e in ipairs(eggsOn["*"]) do list[#list + 1] = e end end
    if #list == 0 then return false end
    local ctx = { key = key, name = ns.Registry:NameOf(key), id = on, extra = extra, t = ns.Now(),
        family = Families(key), today = select(3, ns.Activity:Count(on)) or 0, seen = seen }
    local today = ns.Today(ctx.t)
    -- Every `always` egg that's due says its line (one a day each: a round
    -- day on Christmas Eve isn't lost to the Christmas egg); the others only
    -- with the hour free, so at most one of those.
    local any = false
    for _, e in ipairs(list) do
        local had = ns.DB.char.eggs[e.id]
        local done = (had and had.day == today) or pending.eggs[e.id] == today
        if (e.always or self:Ready()) and not done
            and (not e.chance or self.random() < e.chance) then
            local vars = e.test(ctx)
            local text = vars and Pick(vars._key or ("egg." .. e.id), setmetatable({ pet = ctx.name }, { __index = vars }))
            if text then
                pending.eggs[e.id] = today
                self:Say(text, ("egg %s %s"):format(e.id, key), "egg", function()
                    local got = ns.DB.char.eggs[e.id] or {}
                    got.n, got.day, got.key, got.played = (got.n or 0) + 1, today, key, nil -- (Moves: playing dead)
                    ns.DB.char.eggs[e.id] = got
                end)
                any = true
            end
        end
    end
    return any
end

function Quirks:OnActivity(id, key, extra)
    if not key then return end
    if ns.Personality:Dislikes(key)[id] then return self:Dislike(key, id) end
    self:Egg(id, key, extra)
end

-- A companion under the mouse (Tooltip.lua): your pet meets its own kind,
-- a cousin, or someone who once cared for it.
function Quirks:Seen(species, owner)
    local key = ns.Pets:OutKey()
    if not (key and owner and owner ~= ns.PlayerKey()) or type(species) ~= "number" then return end
    self:Egg("seen", key, owner, species)
end

------------------------------------------------------------------------------
-- Watching: the dislikes of the pets we'd have out (the adopted one and the
-- active one), and what the eggs read that the bond may not.
------------------------------------------------------------------------------
-- (Not dance: every emote nearby would wake it. The midnight dance comes only
-- when a Dansefot's like already watches it.)
Quirks.WATCH = { "level", "revive", "jump", "nap" }
local watching = {}

function Quirks:Watch()
    local want = {}
    for _, id in ipairs(self.WATCH) do want[id] = true end
    for _, key in ipairs({ ns.Registry:MyPet() or false, ns.Summon:ActiveKey() or false }) do
        if key then for id in pairs((ns.Personality:Dislikes(key))) do want[id] = true end end
    end
    for id in pairs(watching) do
        if not want[id] then ns.Activity:Drop(id, Quirks) end
    end
    for id in pairs(want) do
        if not watching[id] then ns.Activity:Want(id, Quirks) end
    end
    watching = want
end

function Quirks:Init()
    ns.Bus:On("ACTIVITY", function(id, _, key, _, extra) Quirks:OnActivity(id, key, extra) end)
    ns.Bus:On("COMPANION_SEEN", function(species, owner) Quirks:Seen(species, owner) end)
    -- Named it (Registry's MY_NAME): a name's own eggs.
    ns.Bus:On("MY_NAME", function(key, e) if type(e) == "table" and e.n then Quirks:Egg("name", key, e.n) end end)
    ns.Bus:On("MY_RECORD", function() Quirks:Watch() end)
    ns.Bus:On("ACTIVE_PET", function() Quirks:Watch() end)
    Quirks:Watch()
    -- Again once the login SYNC is in, like Bond: the guild (so our adopted
    -- pet) may not be known at login yet, and our own record can come back
    -- from a peer without a MY_RECORD of ours (code review 2026-11-09).
    C_Timer.After(20, function() Quirks:Watch() end)
end

ns.Start("login", function() Quirks:Init() end)
