local _, ns = ...

-- Quirks (2026-11-09): flavor with no effect on anything. The more little
-- surprises, the better, but quietly: at most one quirk line every 45 minutes
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

Quirks.EVERY = 2700          -- seconds between quirk lines (an hour until 2026-11-11: the user, 45 minutes)
Quirks.DISLIKE_CHANCE = 0.35 -- per disliked activity (with the hour free)
Quirks.random = math.random  -- (tests pin it)
-- A line comes a while after what caused it, not the instant it happens
-- (2026-11-10: "scared of flying" the moment you took off read as if it had
-- flown for ages). Seconds, picked at random within; a dislike takes longer
-- to sink in than an egg's moment.
-- 2026-11-11, the user: "some remarks feel a little too separated as they come so late": by the
-- line now. A reaction to something that just happened (a roll, a duel, a lost fish) comes almost at
-- once ("now"); a day's egg (a holiday) a little after; the flight's dislike still waits ("slow").
-- An egg names its own (delay = ...), day eggs are "day"; Quirks.DISLIKE_DELAY per activity.
Quirks.DELAY = { dislike = { 8, 15 }, egg = { 3, 10 }, now = { 1, 3 }, day = { 5, 15 }, slow = { 20, 40 } }
Quirks.DISLIKE_DELAY = { taxi = "slow" }
-- Talking a lot (2026-11-11, the user): this many of your guild chat lines within CHAT_SPAN seconds.
Quirks.CHAT_BURST, Quirks.CHAT_SPAN = 5, 120

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
function Quirks:Say(text, why, kind, said, delay)
    pending.line = true
    local span = self.DELAY[delay] or self.DELAY[kind] -- (tests set DELAY to dislike and egg only)
    local wait = span[1] + self.random() * (span[2] - span[1])
    ns.Log("Quirks", "%s, in %d s", why, wait)
    C_Timer.After(wait, function()
        pending.line = nil
        ns.DB.char.quirkAt = ns.Now()
        -- (Settings: chatLines off hides the line only; what it found still counts)
        if ns.Settings:On("chatLines") then ns.Print("|cffd9b3ff" .. text .. "|r") end
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
        if ns.Settings:On("chatLines") then
            ns.Print("|cffd9b3ff" .. T("dislike.found", { pet = name, what = ns.Personality.NOUN[id] }) .. "|r")
        end
        if ns.JournalUI then ns.JournalUI:Refresh() end
    end, self.DISLIKE_DELAY[id])
end

------------------------------------------------------------------------------
-- Easter eggs: { id, on = activity (or "seen": a companion under the mouse),
-- chance (default 1), test = fn(ctx) -> vars or nil }. ctx: key, name (the
-- pet's), id, extra, t, family (set), today (the activity's count today).
-- `always`: not held back by the hour (rare by nature, and a day late is lost).
------------------------------------------------------------------------------
local function On(md) return function(ctx) return date("%m%d", ctx.t) == md and {} end end
local function Game(word) return function(ctx) return ns.Holidays:On(ctx.t) == word and {} end end

local MILESTONES = { [200] = true, [500] = true, [1000] = true }

local function HasTrait(key, id)
    if not ns.Personality:Known(key) then return false end
    for _, t in ipairs(ns.Personality:Traits(key)) do if t.id == id then return true end end
    return false
end
local function Weekday(t) return tonumber(date("%w", t)) end -- 0 = Sunday
local function Hour(t) return tonumber(date("%H", t)) end

-- Places a family feels at home in (2026-11-10): the zone's name as the
-- client says it (enUS; GetZoneText, as "explore" carries it). Hand-made, to
-- check in game: a name that never comes up only means no line.
Quirks.HOME_ZONES = { -- (classic zone names: Forever is the classic world, the user 2026-11-10)
    pirate = { "Stranglethorn Vale", "Tanaris" },
    frog = { "Wailing Caverns", "Swamp of Sorrows" },
    owl = { "Moonglade", "Teldrassil", "Darnassus" },
    mechanical = { "Gnomeregan", "Ironforge" },
    dragon = { "Blackwing Lair", "Onyxia's Lair", "Burning Steppes", "Wetlands" },
    snake = { "Wailing Caverns", "Tanaris" },
    reptile = { "Swamp of Sorrows", "Dustwallow Marsh", "The Temple of Atal'Hakkar" },
    murloc = { "Westfall", "Wetlands", "Darkshore" },
    wolf = { "Alterac Mountains", "Alterac Valley", "Silverpine Forest" },
    bear = { "Ashenvale", "Feralas" },
    demon = { "Felwood", "Blasted Lands", "Desolace" },
    bug = { "Silithus", "Ruins of Ahn'Qiraj", "Ahn'Qiraj" },
    plant = { "Un'Goro Crater", "Feralas" },
    spirit = { "Eastern Plaguelands", "Moonglade" },
    ooze = { "Naxxramas", "Blackrock Depths" },
    farm = { "Westfall" },
    rabbit = { "Elwynn Forest", "Mulgore" },
    cat = { "Winterspring" },
}
local homeOf = {} -- zone -> { families }
for family, zones in pairs(Quirks.HOME_ZONES) do
    for _, z in ipairs(zones) do homeOf[z] = homeOf[z] or {}; table.insert(homeOf[z], family) end
end

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
    -- The game's holidays (Holidays.lua, 2026-11-11), while they last.
    { id = "lunar", on = "day", always = true, test = Game("lunar") },
    { id = "love", on = "day", always = true, test = Game("love") },
    { id = "noblegarden", on = "day", always = true, test = Game("noblegarden") },
    { id = "midsummer", on = "day", always = true, test = Game("midsummer") },
    { id = "harvest", on = "day", always = true, test = Game("harvest") },
    { id = "hallowsend", on = "day", always = true, test = Game("hallowsend") },
    { id = "winterveil", on = "day", always = true, test = Game("winterveil") },
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
        -- (noon today against noon yesterday: the change is at night, whenever the day's visit comes)
        local d = date("*t", ctx.t)
        local noon = time({ year = d.year, month = d.month, day = d.day, hour = 12 })
        local yesterday = time({ year = d.year, month = d.month, day = d.day - 1, hour = 12 })
        return date("*t", noon).isdst ~= date("*t", yesterday).isdst and {}
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
        return ns.Lower(ctx.extra) == ns.Lower(ns.PlayerKey():match("^(%S+)")) and {}
    end },
    { id = "tvilling", on = "name", always = true, test = function(ctx)
        for key in pairs(ns.Registry:Holders()) do
            local other = key ~= ctx.key and ns.Registry:Nickname(key)
            if other and ns.Lower(other) == ns.Lower(ctx.extra) then return { nick = ctx.extra } end
        end
    end },
    -- The first time here with this pet, and it's a place its family feels at home in.
    { id = "hjemme", on = "explore", always = true, test = function(ctx)
        for _, family in ipairs(type(ctx.extra) == "string" and homeOf[ctx.extra] or {}) do
            if ctx.family[family] then
                local own = "egg.hjemme." .. family
                return { zone = ctx.extra, _key = ns.Strings[own .. ".1"] and own or nil }
            end
        end
    end },
    -- Three or more guildmates' pets out with yours (Playdate).
    { id = "fullfest", on = "party", always = true, test = function(ctx)
        return { n = ctx.extra, _key = HasTrait(ctx.key, "flokkdyr") and "egg.fullfest.flokkdyr" or nil }
    end },
    { id = "midnatt", on = "*", chance = 0.5,
        test = function(ctx) return date("%H", ctx.t) == "00" and tonumber(date("%M", ctx.t)) < 10 and {} end },
    { id = "speil", delay = "now", on = "seen", test = function(ctx)
        return ns.Pets:SpeciesOfKey(ctx.key) == ctx.seen and { owner = ctx.extra }
    end },
    -- (2026-11-10) Your adopted pet meets someone with a bond with its kind (a carer
    -- before you, or their own copy: bonds don't tell which).
    { id = "kjenner", delay = "now", on = "seen", test = function(ctx)
        if ns.Registry:MyPet() ~= ctx.key then return nil end
        local e = ns.Registry:Life(ctx.key, ctx.extra)
        return e and e.p > 0 and { owner = ctx.extra }
    end },
    -- Another species of the same family: cousins.
    { id = "fetter", delay = "now", on = "seen", chance = 0.25, test = function(ctx)
        if ns.Pets:SpeciesOfKey(ctx.key) == ctx.seen then return nil end
        local theirs = ns.Scenes:Families(ns.Pets:KeyOfSpecies(ctx.seen))[1]
        return theirs and ctx.family[theirs] and { owner = ctx.extra }
    end },
    -- The pet makes fun of you (2026-11-10, the user's): a 1 of 100, two fish lost in a row.
    { id = "ener", delay = "now", on = "roll", always = true, chance = 0.5, test = function() return {} end },
    { id = "fiskeflaks", delay = "now", on = "fishfail", chance = 0.5, test = function() return {} end },
    -- ... and is amazed (2026-11-11, the user's): a 100 of 100, an epic looted. Rare enough to come every time.
    { id = "hundre", delay = "now", on = "hundred", always = true, test = function() return {} end },
    { id = "lilla", delay = "now", on = "epic", always = true, test = function() return {} end },
    -- A duel won or lost, a new flight path, fishing in the Sunday contest (2026-11-11, from
    -- what /dp probe api found in the client).
    { id = "duellvinner", delay = "now", on = "duelwon", always = true, test = function(ctx)
        return type(ctx.extra) == "string" and { who = ctx.extra } end },
    { id = "duelltaper", delay = "now", on = "duellost", always = true, test = function(ctx)
        return type(ctx.extra) == "string" and { who = ctx.extra } end },
    -- A new flight path matters only to a pet that likes flying (it's thrilled) or dislikes it (it
    -- shivers at the thought); the others don't care (the user, 2026-11-11).
    { id = "nyrute", delay = "now", on = "newpath", always = true, test = function(ctx)
        if not ns.Personality:Known(ctx.key) then return nil end
        if ns.Personality:Of(ctx.key).taxi then return {} end
        if ns.Personality:Dislikes(ctx.key).taxi then return { _key = "egg.nyrute.redd" } end
    end },
    -- A lot of guild chat at once, for a pet that isn't a Pratsom (it would join in) (the user, 2026-11-11).
    { id = "skravle", delay = "now", on = "chat", chance = 0.4, test = function(ctx)
        return not HasTrait(ctx.key, "pratsom") and Quirks:Chatty() and {} end },
    -- The Sunday fishing contest, for a pet that likes fishing: excited about the day (the bonus for
    -- fishing there is Bond's, Bond:Contest).
    { id = "fiskedag", on = "day", always = true, test = function(ctx)
        return ns.Personality:Known(ctx.key) and ns.Personality:Of(ctx.key).fish
            and ns.Holidays:Has(ctx.t, "stvfishing") and {} end },
    { id = "kattefisk", delay = "now", on = "fish", chance = 0.3, test = function(ctx) return ctx.family.cat and {} end },
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
                    if got.n == 1 then ns.Bus:Fire("EGG_FOUND", e.id) end
                    ns.Story:Mine(key, "egg", text, e.id) -- (its story keeps the line, once per egg)
                end, e.delay or (e.on == "day" and "day" or nil))
                any = true
            end
        end
    end
    return any
end

-- Your guild chat lines' times (this session), for the talking-a-lot egg.
local chatTimes = {}
function Quirks:Chatty()
    local now, n = GetTime(), 0
    for _, t in ipairs(chatTimes) do if now - t <= self.CHAT_SPAN then n = n + 1 end end
    return n >= self.CHAT_BURST
end

function Quirks:OnActivity(id, key, extra)
    if id == "chat" then
        table.insert(chatTimes, GetTime())
        if #chatTimes > self.CHAT_BURST then table.remove(chatTimes, 1) end
    end
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
Quirks.WATCH = { "level", "revive", "jump", "nap", "roll", "fishfail", "hundred", "epic", "duelwon", "duellost",
    "newpath", "fish", "chat" }
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
    -- The calendar answered after the day's visit (past midnight, or just after login): the day's
    -- eggs again, for the game's holidays (each egg still once a day).
    ns.Bus:On("HOLIDAYS", function()
        local key = ns.Pets:OutKey()
        if key and select(3, ns.Activity:Count("day")) > 0 then Quirks:Egg("day", key) end
    end)
    -- Named it (Registry's MY_NAME): a name's own eggs.
    ns.Bus:On("MY_NAME", function(key, e)
        if type(e) == "table" and e.n then Quirks:Egg("name", key, e.n) end
    end)
    ns.Bus:On("MY_RECORD", function() Quirks:Watch() end)
    ns.Bus:On("ACTIVE_PET", function() Quirks:Watch() end)
    Quirks:Watch()
    -- Again once the login SYNC is in, like Bond: the guild (so our adopted
    -- pet) may not be known at login yet, and our own record can come back
    -- from a peer without a MY_RECORD of ours (code review 2026-11-09).
    C_Timer.After(20, function() Quirks:Watch() end)
end

ns.Start("login", function() Quirks:Init() end)
