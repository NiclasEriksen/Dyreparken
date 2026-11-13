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
-- Three tiers (2026-11-12, the user, from the log: 79% of what could speak was held back, and the
-- midnight egg's ten minutes lost to a campfire line):
--   rare       never held back by the 45 minutes: `always` eggs (holidays, milestones, a roll, a duel,
--              a new flight path) and the clock's (midnight, 13:37, the early morning, Friday taco,
--              Saturday sweets, Monday): once a day each, and their window is the rarity.
--   discovery  a dislike's first time (DISLIKE_CHANCE): finding it is a goal with an achievement.
--   common     the 45 minutes: a known dislike again (DISLIKE_AGAIN), the campfire (its stages are one
--              fire, so one line; the countdown less likely, so the warmth after it gets its turn), the
--              boss trophy (more likely for a boss new to the pet), wings, the cat and the fish, the chatter.
-- Lines: Locale/nb.lua, dislike.<activity>.N and egg.<id>.N (one is picked).
-- The activities they need are watched like the bond's (Activity:Want).
local Quirks = {}
ns.Quirks = Quirks

Quirks.EVERY = 2700          -- seconds between quirk lines (an hour until 2026-11-11: the user, 45 minutes)
Quirks.DISLIKE_CHANCE = 0.35 -- a dislike not yet found: per time it happens (the cooldown doesn't hold it back)
Quirks.DISLIKE_AGAIN = 0.15  -- one already found: per time, with the 45 minutes free
-- A minor dislike (Personality: unlocked by your bond at level 6), a third as often (the user, 2026-11-12).
Quirks.MINOR_CHANCE, Quirks.MINOR_AGAIN = 0.15, 0.05
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

local Pick = ns.PickLine

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
function Quirks:Say(text, why, kind, said, delay, key, bubble)
    pending.line = true
    local span = self.DELAY[delay or kind]
    local wait = span[1] + ns.random() * (span[2] - span[1])
    ns.Log("Quirks", "%s, in %d s", why, wait)
    C_Timer.After(wait, function()
        pending.line = nil
        ns.DB.char.quirkAt = ns.Now()
        -- (chatLines off hides the line only, what it found still counts; on the pet frame a dislike
        -- its own way, an egg a plain remark)
        ns.PetSays(text, key, bubble or (kind == "dislike" and "dislike" or "say"))
        if said then said() end
    end)
end

------------------------------------------------------------------------------
-- Dislikes
------------------------------------------------------------------------------
-- The card turned the pet's back for today's sulk (Moves): once a day, so not again.
function Quirks:SulkShown(key)
    local s = ns.DB.char.sulk
    if s and s.key == key then s.shown = true end
end

-- The card played today's egg (Moves: playing dead for dodsfall): not again until it comes up anew.
function Quirks:EggPlayed(id)
    local e = ns.DB.char.eggs[id]
    if e then e.played = true end
end

function Quirks:Dislike(key, id, minor)
    local seen = ns.DB.char.dislikes
    local first = not (seen[key] and seen[key][id])
    -- (found: common, the 45 minutes; not yet: a discovery, only another line on its way holds it)
    if first then
        if pending.line then return end
    elseif not self:Ready() then
        return
    end
    local chance = minor and (first and self.MINOR_CHANCE or self.MINOR_AGAIN)
        or (first and self.DISLIKE_CHANCE or self.DISLIKE_AGAIN)
    if ns.random() >= chance then return end
    local name = ns.Registry:NameOf(key)
    local text = Pick("dislike." .. id, { pet = name })
    if not text then return end
    self:Say(text, ("dislike %s %s"):format(key, id), "dislike", function()
        seen[key] = seen[key] or {}
        seen[key][id] = true
        ns.DB.char.sulk = { key = key, day = ns.Today() } -- (Moves: its back turned on the card, once)
        if not first then return end
        ns.Bus:Fire("DISLIKE_FOUND", key, id)
        ns.PetSays(T("dislike.found", { pet = name, what = ns.Personality.NOUN[id] }))
        if ns.JournalUI then ns.JournalUI:Refresh() end
    end, self.DISLIKE_DELAY[id], key)
end

------------------------------------------------------------------------------
-- Easter eggs: { id, on = activity (or "seen": a companion under the mouse),
-- chance (default 1), test = fn(ctx) -> vars or nil }. ctx: key, name (the
-- pet's), id, extra, t, family (set), today (the activity's count today), egg.
-- `always`: not held back by the hour (rare by nature, and a day late is lost).
-- `traits`, `families`: an egg that speaks by the pet's nature (Quirks.ByNature),
-- in this order, first match wins. `watch = false`: its activity isn't watched for it
-- (the rest are: Quirks.WATCH is built from the eggs). `on` must be an activity in
-- Activity.KINDS, a moment (MOMENTS) or "*": checked at load.
-- Egg ids are permanent: char.eggs, a pet's story and the eggs:N achievements count them.
------------------------------------------------------------------------------
local function On(md) return function(ctx) return date("%m%d", ctx.t) == md and {} end end
local function Game(word) return function(ctx) return ns.Holidays:On(ctx.t) == word and {} end end

local MILESTONES = { [200] = true, [500] = true, [1000] = true }

local function HasTrait(key, id) return ns.Personality:Has(key, id) end
-- Cozy or adventurous (for the campfire eggs; Personality.TRAITS' `is`), or nil: cozy wins if it's both.
local function Kind(key)
    if ns.Personality:Tagged(key, "cozy") then return "cozy" end
    if ns.Personality:Tagged(key, "adventurous") then return "adventurous" end
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

-- Who hunts whom (Hakkebakkeloven, 2026-11-13, the user's: "Alle dyrene i skogen skal være venner"):
-- a family -> the families it would chase in the wild, for the playdate egg "hakkebakke". Only the
-- obvious ones; the murlocs are the bear's fish, the farm's sheep the dragon's.
Quirks.PREY = {
    cat = { "rodent", "bird", "rabbit", "frog" },
    wolf = { "rabbit", "farm", "rodent" },
    snake = { "rodent", "frog", "bird" },
    owl = { "rodent", "rabbit", "frog" },
    reptile = { "bird", "farm", "frog" },
    bear = { "murloc" },
    dragon = { "farm" },
}
-- "hunter" (a family of mine chases one of theirs), "prey" (the other way round), or nil. Hunter
-- first: two that could chase each other's kin (a cat and an owl don't: neither is in the other's list).
function Quirks.Hunt(mine, theirs)
    local function Chases(a, b)
        for _, f in ipairs(a) do
            for _, p in ipairs(Quirks.PREY[f] or {}) do
                for _, g in ipairs(b) do if g == p then return true end end
            end
        end
    end
    if Chases(mine, theirs) then return "hunter" end
    if Chases(theirs, mine) then return "prey" end
end

-- Politimester Bastian's evening round (the egg "bastian"): 22:00-22:14 on the player's clock.
function Quirks.Bastian(t) return Hour(t) == 22 and tonumber(date("%M", t)) < 15 end

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
    { id = "mandag", on = "day", always = true, test = function(ctx) return Weekday(ctx.t) == 1 and HasTrait(ctx.key, "helgedyr") and {} end },
    { id = "morgen", on = "day", always = true, test = function(ctx)
        local h = Hour(ctx.t)
        if h < 5 or h >= 7 then return nil end -- (before five it's still night: midnight's own)
        return HasTrait(ctx.key, "nattugle") and { _key = "egg.morgen.nattugle" } or {}
    end },
    { id = "hopp", on = "jump", always = true, test = function(ctx) -- a hundred jumps (one "jump" is ten)
        if ctx.today ~= 10 then return nil end
        return HasTrait(ctx.key, "hoppetass") and { _key = "egg.hopp.hoppetass" } or {}
    end },
    { id = "lur", on = "nap", test = function(ctx) return ctx.today == 5 and {} end },
    { id = "midnattsdans", on = "dance", always = true, watch = false, test = function(ctx) return Hour(ctx.t) == 0 and tonumber(date("%M", ctx.t)) < 30 and {} end },
    { id = "fredagstaco", on = "*", always = true, chance = 0.5, test = function(ctx)
        return Weekday(ctx.t) == 5 and Hour(ctx.t) >= 17 and (HasTrait(ctx.key, "glupsk") or ctx.family.cat) and {}
    end },
    { id = "lordagsgodt", on = "*", always = true, chance = 0.5,
        test = function(ctx) return Weekday(ctx.t) == 6 and HasTrait(ctx.key, "helgedyr") and {} end },
    { id = "leet", on = "*", always = true, test = function(ctx) return date("%H%M", ctx.t) == "1337" and {} end },
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
    -- A playdate (Playdate:Heard: a guildmate's pet near yours) between a hunter and its prey: the forest's
    -- law. `always` with a chance: a playdate is rare (a group, a guildmate near, both pets out), a pair like
    -- this rarer, and every PLAY heard that day rolls again. A Venneflokk beams, a Røverdyr hunter licks its
    -- lips; else by the side yours is on.
    { id = "hakkebakke", on = "playdate", always = true, chance = 0.5, traits = { "venneflokk", "roverdyr" },
        test = function(ctx)
            local other = type(ctx.extra) == "table" and ctx.extra
            local side = other and Quirks.Hunt(ns.Scenes:Families(ctx.key), ns.Scenes:Families(other.key))
            if not side then return nil end
            local vars = { friend = ns.Registry:NameFor(other.key, other.owner) }
            if HasTrait(ctx.key, "venneflokk") then vars._key = "egg.hakkebakke.venneflokk"
            elseif side == "hunter" and HasTrait(ctx.key, "roverdyr") then vars._key = "egg.hakkebakke.roverdyr"
            elseif side == "prey" then vars._key = "egg.hakkebakke.bytte" end
            return vars
        end },
    -- Bastians runde (Kardemomme by, 2026-11-13, the user's): "Klokken er ti, og alt er vel" in the evening's
    -- first quarter hour, like midnight's: an Ordensdyr says it, a Røverdyr knows the robbers are out now;
    -- the rest say nothing. (No dice outside it: a "*" egg is asked on every activity, and a roll there
    -- would shift every other chance after it.)
    { id = "bastian", on = "*", always = true, chance = function(ctx) return Quirks.Bastian(ctx.t) and 0.5 end,
        test = function(ctx)
            if not Quirks.Bastian(ctx.t) then return nil end
            if HasTrait(ctx.key, "ordensdyr") then return {} end
            return HasTrait(ctx.key, "roverdyr") and { _key = "egg.bastian.roverdyr" } or nil
        end },
    { id = "midnatt", on = "*", always = true, chance = 0.5,
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
    -- Campfires and sleeping bags (2026-11-11, the user): cozy pets love them, adventurous ones get
    -- restless; a fire passed by only now and then catches a cozy pet's eye.
    { id = "baalnaer", on = "campnear", chance = 0.03, test = function(ctx)
        return Kind(ctx.key) == "cozy" and {} end },
    -- (the countdown less likely, 2026-11-12: at 50% it came first and won, and the warmth never spoke)
    { id = "baalvarm", on = "campwarm", chance = 0.25, test = function(ctx)
        local kind = Kind(ctx.key)
        return kind and (kind == "cozy" and {} or { _key = "egg.baalvarm.eventyr" }) end },
    { id = "baal", on = "camp", chance = 0.6, test = function(ctx)
        local kind = Kind(ctx.key)
        return kind and (kind == "cozy" and {} or { _key = "egg.baal.eventyr" }) end },
    { id = "sovepose", on = "rested", chance = 0.6, test = function(ctx)
        local kind = Kind(ctx.key)
        return kind and (kind == "cozy" and {} or { _key = "egg.sovepose.eventyr" }) end },
    -- A lot of guild chat at once, for a pet that isn't a Pratsom (it would join in) (the user, 2026-11-11).
    { id = "skravle", delay = "now", on = "chat", chance = 0.4, test = function(ctx)
        return not HasTrait(ctx.key, "pratsom") and Quirks:Chatty() and {} end },
    -- Gjensynsglede (2026-11-13, the user's: "again only a chance for it to happen"): the day's visit after
    -- REUNION_DAYS calendar days or more apart (Activity:Apart), by a chance, the pet greets you by its
    -- nature, with a cheer on its card and the pet frame; a Latsabb barely looks up, so no cheer there.
    -- `always`: a few days apart is rare by nature, and the visit comes once a day.
    { id = "gjensyn", on = "day", always = true, traits = { "hjemlengsel", "trofast", "kjaelen", "latsabb" },
        cheer = function(vars) return vars._key ~= "egg.gjensyn.latsabb" end,
        test = function(ctx)
            local days = ns.Activity:Apart(ctx.key)
            if not (days and days >= Quirks.REUNION_DAYS) or ns.random() >= Quirks.REUNION_CHANCE then return nil end
            local vars = Quirks.ByNature(ctx)
            vars.n = days
            return vars
        end },
    -- The Sunday fishing contest, for a pet that likes fishing: excited about the day (the bonus for
    -- fishing there is Bond's, Bond:Contest).
    { id = "fiskedag", on = "day", always = true, test = function(ctx)
        return ns.Personality:Known(ctx.key) and ns.Personality:Of(ctx.key).fish
            and ns.Holidays:Has(ctx.t, "stvfishing") and {} end },
    { id = "kattefisk", delay = "now", on = "fish", chance = 0.3, test = function(ctx) return ctx.family.cat and {} end },
    { id = "vinger", on = "taxi", chance = 0.3,
        test = function(ctx) return (ctx.family.bird or ctx.family.owl or ctx.family.dragon) and {} end },
    -- More likely for a boss this pet hasn't seen fall (Bond:First notes those; either may hear it first).
    { id = "trofe", on = "boss", chance = function(ctx)
        local seen = ns.DB.char.firsts[ctx.key]
        local new = not (seen and seen[ctx.extra]) or (ns.Bond.justFirst == ctx.key .. "\31" .. tostring(ctx.extra)
            and ns.Now() - (ns.Bond.justFirstAt or 0) <= 1) -- (this very kill)
        return new and Quirks.TROPHY_NEW or Quirks.TROPHY
    end, test = function(ctx)
        return type(ctx.extra) == "string" and ctx.extra ~= "" and ctx.extra ~= "?" and { boss = ctx.extra }
    end },
    { id = "dodsfall", on = "revive", test = function(ctx) return ctx.today >= 3 and {} end },
    -- Every tenth level, likelier the higher it is (the user, 2026-11-12); 60 is a feat (Feats.lua), with its own.
    { id = "kake", on = "level", always = true, chance = function(ctx)
        return Quirks.CAKE_CHANCE[tonumber(ctx.extra) or 0] or 0
    end, test = function(ctx)
        local level = tonumber(ctx.extra)
        return Quirks.CAKE_CHANCE[level or 0] and { level = level }
    end },
    -- Feats (Feats.lua: the points and their line are Bond's): riding by a good chance, level 60 always.
    { id = "ridning", on = "feat", always = true, chance = 0.6, test = function(ctx) return ctx.extra == "riding" and {} end },
    { id = "maks", on = "feat", always = true, test = function(ctx) return ctx.extra == "level60" and {} end },
    -- Flavor only (the user, 2026-11-12): a trainer visit, a dual-spec switch, a talent reset.
    { id = "trener", on = "train", chance = 0.35, test = function() return {} end },
    { id = "talentbytte", delay = "now", on = "specswap", always = true, chance = 0.5, test = function() return {} end },
    { id = "glemsel", on = "respec", always = true, chance = 0.8, test = function() return {} end },
    -- The damage meter after a boss kill in a group (Meter.lua, 2026-11-12, the user): first in damage, or in
    -- healing in a raid; likelier in a raid and well ahead of the next. A gold bubble and a cheer: a big one.
    { id = "toppen", delay = "now", on = "dmgtop", always = true, bubble = "major", cheer = true,
        chance = function() return Quirks.MeterChance() end, test = function() return {} end },
    { id = "helter", delay = "now", on = "healtop", always = true, bubble = "major", cheer = true,
        chance = function() return Quirks.MeterChance() end, test = function() return {} end },
    { id = "sparket", delay = "now", on = "kicktop", chance = 0.3, test = function() return {} end },
    -- A big fall (2026-11-12, the user: pets react "according to traits"): the first of its traits with a line
    -- of its own (Quirks.FALL_TRAITS), else a worried one; the end of you, its own.
    { id = "stup", delay = "now", on = "fall", always = true,
        traits = { "hoppetass", "skybaren", "rampete", "skoyer", "eventyrlysten", "latsabb", "hjemlengsel", "kjaelen",
            "kosete", "trofast" },
        test = function(ctx)
            if ctx.extra == "dead" then return { _key = "egg.stup.dod" } end
            return Quirks.ByNature(ctx)
        end },
    -- Zeppelins and boats (Voyage.lua, 2026-11-12, the user): by trait, then family, else a plain one. A pet
    -- afraid of flying is afraid up there too.
    { id = "luftskip", on = "zeppelin", always = true, chance = 0.6,
        traits = { "skybaren", "reiseglad", "eventyrlysten", "hjemlengsel", "latsabb" },
        families = { "bird", "owl", "dragon", "mechanical" },
        test = function(ctx)
            if ns.Personality:Known(ctx.key) and ns.Personality:Dislikes(ctx.key).taxi then return { _key = "egg.luftskip.redd" } end
            return Quirks.ByNature(ctx)
        end },
    { id = "seilas", on = "boat", always = true, chance = 0.6,
        traits = { "sjorover", "vannhund", "dykker", "hjemlengsel", "eventyrlysten" },
        families = { "pirate", "cat", "frog", "murloc", "reptile", "bird" },
        test = function(ctx) return Quirks.ByNature(ctx) end },
    -- Every hundredth quest with this pet out (the hour doesn't hold it back:
    -- the next chance is a hundred quests away).
    { id = "oppdrag", on = "quest", always = true, test = function(ctx)
        local n = select(4, ns.Activity:Count("quest", ctx.key))
        return n > 0 and n % 100 == 0 and { n = n }
    end },
}
-- Eggs on moments that aren't activities: "*" eggs don't ride on them.
local MOMENTS = { seen = true, name = true, party = true, playdate = true }

local eggsOn, eggById = {}, {} -- activity -> its eggs; id -> egg
for _, e in ipairs(Quirks.EGGS) do
    assert(ns.Activity.KIND[e.on] or MOMENTS[e.on] or e.on == "*", "Quirks.EGGS: " .. e.id .. " on " .. tostring(e.on))
    assert(not eggById[e.id], "Quirks.EGGS: two eggs " .. e.id)
    for _, t in ipairs(e.traits or {}) do assert(ns.Personality.ById(t), "Quirks.EGGS: " .. e.id .. ": no trait " .. t) end
    eggsOn[e.on] = eggsOn[e.on] or {}
    table.insert(eggsOn[e.on], e)
    eggById[e.id] = e
end
function Quirks.EggById(id) return eggById[id] end

local function Families(key)
    local set = {}
    for _, f in ipairs(ns.Scenes:Families(key)) do set[f] = true end
    return set
end

Quirks.TROPHY, Quirks.TROPHY_NEW = 0.15, 0.5
Quirks.REUNION_DAYS, Quirks.REUNION_CHANCE = 3, 0.35 -- (gjensyn: Monday's pet back on Thursday)
-- Lines by nature, from the egg's own lists (EGGS: traits, families): the first of its
-- traits the pet has (egg.<id>.<trait>.N), then its families' (egg.<id>.<family>.N), else
-- the plain ones (egg.<id>.N). A test holds every listed one to its lines.
function Quirks.ByNature(ctx)
    local e = ctx.egg
    for _, t in ipairs(e.traits or {}) do
        if HasTrait(ctx.key, t) and ns.Strings["egg." .. e.id .. "." .. t .. ".1"] then return { _key = "egg." .. e.id .. "." .. t } end
    end
    for _, f in ipairs(e.families or {}) do
        if ctx.family[f] and ns.Strings["egg." .. e.id .. "." .. f .. ".1"] then return { _key = "egg." .. e.id .. "." .. f } end
    end
    return {}
end

-- The meter's eggs (Meter.lua): a dungeon boss, a raid boss, and more when well ahead of the next.
Quirks.METER_DUNGEON, Quirks.METER_RAID, Quirks.METER_FAR = 0.35, 0.7, 0.25
function Quirks.MeterChance()
    local last = ns.Meter and ns.Meter.last or {}
    return math.min(1, (last.raid and Quirks.METER_RAID or Quirks.METER_DUNGEON) + (last.far and Quirks.METER_FAR or 0))
end
Quirks.CAKE_CHANCE = { [10] = 0.2, [20] = 0.35, [30] = 0.5, [40] = 0.65, [50] = 0.8 }

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
        local chance = e.chance
        if type(chance) == "function" then chance = chance(ctx) end -- (false or nil: no roll, the test decides)
        if (e.always or self:Ready()) and not done
            and (not chance or ns.random() < chance) then
            ctx.egg = e
            local vars = e.test(ctx)
            local text = vars and Pick(vars._key or ("egg." .. e.id), setmetatable({ pet = ctx.name }, { __index = vars }))
            if text then
                pending.eggs[e.id] = today
                local cheer = e.cheer
                if type(cheer) == "function" then cheer = cheer(vars) end -- (by the line it says)
                self:Say(text, ("egg %s %s"):format(e.id, key), "egg", function()
                    local got = ns.DB.char.eggs[e.id] or {}
                    got.n, got.day, got.key, got.played = (got.n or 0) + 1, today, key, nil -- (Moves: playing dead)
                    ns.DB.char.eggs[e.id] = got
                    if got.n == 1 then ns.Bus:Fire("EGG_FOUND", e.id) end
                    ns.Story:Mine(key, "egg", text, e.id) -- (its story keeps the line, once per egg)
                    if cheer and ns.Moves then ns.Moves:Cheer(key) end -- (on its card and the pet frame)
                end, e.delay or (e.on == "day" and "day" or nil), key, e.bubble)
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
    -- A dislike doesn't stop the eggs (2026-11-12, the user: "why not?"): a wolf that minds naps
    -- still has its fifth nap's egg. The dislike speaks first; the hour it takes holds back the
    -- common eggs, not the `always` ones.
    local dislike = ns.Personality:Dislikes(key)[id]
    if dislike then self:Dislike(key, id, dislike == "minor") end
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
-- What the eggs read that the bond doesn't always watch: every egg's activity, but the
-- moments, "*", the bond's `always` ones, and an egg's `watch = false` (not dance: every
-- emote nearby would wake it; the midnight dance comes only when a Dansefot's like
-- already watches it).
Quirks.WATCH = {}
do
    local seen = {}
    for _, e in ipairs(Quirks.EGGS) do
        local k = ns.Activity.KIND[e.on]
        if k and not k.always and e.watch ~= false and not seen[e.on] then
            seen[e.on] = true
            Quirks.WATCH[#Quirks.WATCH + 1] = e.on
        end
    end
end

function Quirks:Watch()
    local want = {}
    for _, id in ipairs(self.WATCH) do want[id] = true end
    for _, key in ipairs({ ns.Registry:MyPet() or false, ns.Summon:ActiveKey() or false }) do
        if key then for id in pairs((ns.Personality:Dislikes(key))) do want[id] = true end end
    end
    ns.Activity:WantOnly(Quirks, want)
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
    ns.Bus:On("BOND_LEVEL", function() Quirks:Watch() end) -- (a minor dislike unlocked: Personality)
    Quirks:Watch()
    -- Again once the login SYNC is in, like Bond: the guild (so our adopted
    -- pet) may not be known at login yet, and our own record can come back
    -- from a peer without a MY_RECORD of ours (code review 2026-11-09).
    C_Timer.After(20, function() Quirks:Watch() end)
end

ns.Start("login", function() Quirks:Init() end)
