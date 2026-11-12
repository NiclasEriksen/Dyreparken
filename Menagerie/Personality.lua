local _, ns = ...

-- A companion's personality (docs/PET_LIFE.md): what it likes doing with you,
-- and two traits. It belongs to the species, so every client agrees without
-- sending anything, and it's the same for every carer.
--
-- Likes come from the pet's families (our tags in Data/Companions.lua), a
-- few species of their own (the Panda Cub and its bamboo), and its traits.
-- A liked activity done with your adopted companion out is worth more bond
-- points (Bond.lua).
--
-- A trait does one of three things:
--   like = activity     that activity is liked;
--   when = fn(ctx)      anything done while it holds (at night, in a group
--                       with a guildmate, in a dungeon...) counts as liked,
--                       with one daily cap for the trait (ctx: Bond.lua);
--   day = fn(t) -> x    the day together is worth x times as much.
--
-- Picking: every species' two traits are pinned in Data/Traits.lua and never
-- change (decided 2026-11-08). For a species not in there, two from its id,
-- never a pair that contradicts itself (Flokkdyr and Einstøing); that pick
-- moves when traits are added, which is why it's pinned.
local Personality = {}
ns.Personality = Personality

local L = ns.L

-- Activities (Activity.KINDS) as players read them: the noun, the line for
-- the first liked one of the day, and how it reads in a trait's effect,
-- where "X med kjæledyret ute" doesn't say enough (Locale/nb.lua: activity.*,
-- effect.activity.*; each only where it's written).
Personality.NOUN, Personality.FLAVOR, Personality.EFFECT = {}, {}, {}
for _, k in ipairs(ns.Activity.KINDS) do
    local id, S = k.id, ns.Strings
    Personality.NOUN[id] = L["activity." .. id]
    if S["activity." .. id .. ".flavor"] then Personality.FLAVOR[id] = L["activity." .. id .. ".flavor"] end
    if S["effect.activity." .. id] then Personality.EFFECT[id] = L["effect.activity." .. id] end
end

Personality.BY_FAMILY = {
    cat = { "fish" }, bird = { "taxi" }, owl = { "taxi" }, farm = { "herb", "quest", "skill" }, rabbit = { "herb" },
    frog = { "fish", "dive" }, snake = { "herb" }, mechanical = { "mine", "skill" }, dragon = { "boss", "taxi", "rep" },
    pirate = { "fish", "pvp", "dive" }, bug = { "herb" }, rodent = { "mine" }, wolf = { "boss" }, plant = { "herb" },
    festive = { "quest", "rep" }, demon = { "boss" }, ooze = { "boss" }, spirit = { "taxi", "rep" },
    bear = { "fish", "herb" }, reptile = { "fish", "dive" }, murloc = { "fish", "dive" }, -- (2026-11-10)
}
Personality.DEFAULT = { "quest" } -- a pet with no family we know

-- Species with likes of their own (species id -> activities), from their
-- story (the data pass, 2026-11-10). Added to the family's.
Personality.BY_SPECIES = {
    [5159] = { "herb" },  -- Panda Cub: bamboo
    [90] = { "boss" },    -- Smolderweb Hatchling: from Mother Smolderweb's nest in Blackrock Spire
    [85] = { "pvp" },     -- Tiny Walking Bomb: boom
    [116] = { "nap" },    -- Tranquil Mechanical Yeti: tranquil
    [118] = { "taxi" },   -- Winter Reindeer: it flies with Greatfather Winter
    [119] = { "skill" },  -- Father Winter's Helper: makes the toys
    [120] = { "skill" },  -- Winter's Little Helper: likewise
    [122] = { "cuddle" }, -- Peddlefeet: Love is in the Air
    [125] = { "nap" },    -- Speedy: a turtle, whatever its name says
    [126] = { "nap" },    -- Mr. Wiggles: a pig in the sun
    [128] = { "dance" },  -- Spirit of Summer: the Midsummer bonfires
    [106] = { "jump" },   -- Jubling: the Darkmoon Faire
    [5005] = { "dance" }, -- Musical Gustjumper: musical
    [5075] = { "jump" },  -- Excitable Slime: excitable
    [5094] = { "fish" },  -- Bitter Baitling: bait
    [5160] = { "pvp" },   -- Zergling: the rush
    [5183] = { "mine" },  -- Spawn of Grubthor: a burrowing worm
}

-- Dislikes (2026-11-09): no effect on the bond, only a line now and then
-- (Menagerie/Quirks.lua), and secret until one happens: the card shows those
-- you've seen (char.dislikes). From the families and a few traits (the
-- trait's `dislike`); never anything the pet likes, so a Dykker cat doesn't
-- mind the water.
Personality.DISLIKE_BY_FAMILY = {
    cat = { "dive" }, bird = { "pvp" }, owl = { "chat" }, farm = { "taxi" }, rabbit = { "boss" }, frog = { "taxi" },
    snake = { "jump" }, mechanical = { "dive" }, dragon = { "dive" }, pirate = { "hearth" }, bug = { "jump" },
    rodent = { "taxi" }, wolf = { "nap" }, plant = { "hearth" }, festive = { "pvp" }, demon = { "cuddle" },
    ooze = { "jump" }, spirit = { "dive" }, bear = { "boss" }, reptile = { "taxi" }, murloc = { "taxi" },
}

-- The holidays the Festglad pets celebrate ("MMDD" -> name, Locale/nb.lua: holiday.*).
Personality.HOLIDAYS = {}
for _, day in ipairs({ "0101", "0517", "0623", "1224", "1225", "1231" }) do
    Personality.HOLIDAYS[day] = L["holiday." .. day]
end

local function Hour(t) return tonumber(date("%H", t)) end

-- The moments some traits care about, by the player's clock. Decor shows
-- the matching particles by the same rules.
function Personality.IsNight(t) local h = Hour(t); return h >= 22 or h < 4 end
-- Its name, or nil: ours by date, else the game's (Holidays.lua: from the calendar, today only).
function Personality.Holiday(t)
    local game = ns.Holidays:On(t) -- (asked even on our own: its egg comes that day too)
    return Personality.HOLIDAYS[date("%m%d", t)] or game and L["holiday.game." .. game] or nil
end
function Personality.IsWeekend(t) local w = tonumber(date("%w", t)); return w == 0 or w == 6 end

-- ids are permanent (they key the pinned list). What players read about a
-- trait is in Locale/nb.lua (trait.<id>.name, .desc, and for some .when,
-- .day, .flavor, .dayflavor), filled in below.
Personality.TRAITS = {
    { id = "glupsk", like = "quest" },
    { id = "eventyrlysten", like = "boss" },
    { id = "reiseglad", like = "taxi", dislike = "hearth" },
    { id = "rampete", like = "pvp" },
    { id = "gronnfinger", like = "herb" },
    { id = "vannhund", like = "fish" },
    { id = "steinhard", like = "mine" },
    { id = "dansefot", like = "dance" },
    { id = "kjaelen", like = "cuddle" },
    { id = "oppdager", like = "explore" },
    { id = "trofast", like = "revive" },
    { id = "hoppetass", like = "jump" },
    { id = "dykker", like = "dive" },
    { id = "hjemlengsel", like = "hearth", dislike = "taxi" },
    { id = "ambisios", like = "level" },
    { id = "latsabb", like = "nap", dislike = "jump" },
    { id = "pratsom", like = "chat" },
    { id = "kosete", day = function() return 2 end, dayX = 2 },
    { id = "nattugle", when = function(ctx) return Personality.IsNight(ctx.t) end },
    { id = "festglad", day = function(t) return Personality.Holiday(t) and 3 or 1 end, dayX = 3,
        dayFlavor = function(name, t)
            return ns.T("trait.festglad.dayflavor", { pet = name, holiday = Personality.Holiday(t) })
        end },
    { id = "helgedyr", day = function(t) return Personality.IsWeekend(t) and 2 or 1 end,
        dayX = 2, dayFlavor = function(name) return ns.T("trait.helgedyr.dayflavor", { pet = name }) end },
    { id = "flokkdyr", against = "einstoing", when = function(ctx) return ctx.guildmates > 0 end },
    { id = "einstoing", against = "flokkdyr", dislike = "chat", when = function(ctx) return not ctx.group end },
    { id = "huleboer", against = "friluftsdyr", when = function(ctx) return ctx.instance end },
    { id = "friluftsdyr", against = "huleboer", when = function(ctx) return not ctx.instance end },
    -- 2026-11-12 (the user, for 0.5): from Dyreparken in Kristiansand (Kaptein Sabeltann, Julius, Kardemomme
    -- by, Hakkebakkeskogen, the Nordic wilds and the savanna, the rides), Forever, and the likes no trait had.
    { id = "sjorover", like = "gold" },                       -- Kaptein Sabeltann: gold!
    { id = "skoyer", like = "fun" },                          -- Julius: silly emotes
    { id = "roverdyr", against = "ordensdyr", like = "sneak" }, -- Kasper, Jesper og Jonatan
    { id = "ordensdyr", against = "roverdyr", dislike = "pvp", when = function(ctx) return ctx.city end }, -- Politimester Bastian
    { id = "venneflokk", like = "meet", dislike = "pvp" },    -- Hakkebakkeskogen: all animals are friends
    { id = "vinterpels", against = "solelsker", when = function(ctx) return Personality.COLD[ctx.zone] end },
    { id = "solelsker", against = "vinterpels", when = function(ctx) return Personality.WARM[ctx.zone] end },
    { id = "tivolidyr", day = function(t) return ns.Holidays:Has(t, "darkmoon") and 2 or 1 end, dayX = 2,
        dayFlavor = function(name) return ns.T("trait.tivolidyr.dayflavor", { pet = name }) end },
    { id = "balkos", like = "camp" },
    { id = "skybaren", when = function(ctx) return Personality.HIGH[ctx.zone] end }, -- the Skyborne, Zephras Isle
    { id = "jeger", like = "skin" },
    { id = "handverker", like = "skill" },
    { id = "diplomat", like = "rep" },
}

-- Where the zone traits feel at home: GetZoneText's names (enUS; Classic's, and Forever's own: Zephras
-- Isle and Mount Hyjal from Forever's news, unverified in the client; a name that never comes only means
-- no moment).
local function Set(list) local t = {} for _, v in ipairs(list) do t[v] = true end return t end
Personality.COLD = Set({ "Winterspring", "Dun Morogh", "Alterac Mountains", "Alterac Valley", "Ironforge" })
Personality.WARM = Set({ "Tanaris", "The Barrens", "Durotar", "Desolace", "Silithus", "Badlands", "Searing Gorge",
    "Burning Steppes", "Thousand Needles", "Stranglethorn Vale", "Un'Goro Crater", "Orgrimmar" })
Personality.HIGH = Set({ "Zephras Isle", "Mount Hyjal", "Thunder Bluff", "Teldrassil", "Darnassus" })
Personality.CITIES = Set({ "Stormwind City", "Ironforge", "Darnassus", "Orgrimmar", "Thunder Bluff", "Undercity" })
local byId = {}
for _, t in ipairs(Personality.TRAITS) do
    byId[t.id] = t
    local k = "trait." .. t.id
    t.name, t.desc = L[k .. ".name"], L[k .. ".desc"]
    if t.when then t.whenText, t.flavor = L[k .. ".when"], L[k .. ".flavor"] end
    if t.day then t.dayText = L[k .. ".day"] end
end

function Personality.ById(id) return byId[id] end

-- Every species' traits, pinned for good (Data/Traits.lua). A species that
-- isn't in there yet (new in the journal) gets the pick below until
-- tools/pin_traits.lua adds it.
Personality.PINNED = ns.TraitPins or {}

-- The species' two traits: the same on every client.
function Personality:Traits(key)
    local sid = ns.Pets:SpeciesOfKey(key) or 0
    local pin = self.PINNED[sid]
    if pin then return { self.ById(pin[1]), self.ById(pin[2]) } end
    local list, n = self.TRAITS, #self.TRAITS
    local first = list[math.fmod(sid * 2654435761, 4294967296) % n + 1]
    local i = math.fmod(sid * 40503 + 12345, 4294967296) % n + 1
    for _ = 1, n do
        local t = list[i]
        if t ~= first and t.id ~= first.against then return { first, t } end
        i = i % n + 1
    end
    return { first }
end

-- likes: { activity = true }, the ordered list, and the traits.
function Personality:Of(key)
    local likes, list = {}, {}
    local function Add(act)
        if act and not likes[act] then likes[act] = true; list[#list + 1] = act end
    end
    local sid = ns.Pets:SpeciesOfKey(key)
    for _, act in ipairs(sid and self.BY_SPECIES[sid] or {}) do Add(act) end
    local families = ns.Scenes:Families(key)
    for _, f in ipairs(families) do
        for _, act in ipairs(self.BY_FAMILY[f] or {}) do Add(act) end
    end
    if #list == 0 then for _, act in ipairs(self.DEFAULT) do Add(act) end end
    local traits = self:Traits(key)
    for _, t in ipairs(traits) do Add(t.like) end
    return likes, list, traits
end

-- How many times a day together counts at time t (the traits multiply), and
-- the trait that made it count more, if any.
function Personality:DayFactor(key, t)
    local x, why = 1, nil
    for _, trait in ipairs(self:Traits(key)) do
        local f = trait.day and trait.day(t) or 1
        if f > 1 then x, why = x * f, why or trait end
    end
    return x, why
end

-- The traits that make anything done right now liked (ctx: Bond.lua), in
-- order. The caller takes the first with room left today.
function Personality:Fitting(key, ctx)
    local fit = {}
    for _, t in ipairs(self:Traits(key)) do
        if t.when and t.when(ctx) then fit[#fit + 1] = t end
    end
    return fit
end

-- Does any of the pet's traits read the context (so it's worth building)?
function Personality:WantsContext(key)
    for _, t in ipairs(self:Traits(key)) do if t.when then return true end end
    return false
end


-- What a trait does, in numbers (from ns.Config, so it can't go stale).
function Personality:Effect(trait)
    local C = ns.Config
    if trait.day then
        return ns.T("effect.day", { when = trait.dayText, times = L["effect.times." .. trait.dayX],
            n = C.BOND_DAY_POINTS * trait.dayX, base = C.BOND_DAY_POINTS })
    end
    local what
    if trait.when then
        what = ns.T("effect.when", { when = trait.whenText })
    else
        what = self.EFFECT[trait.like]
        if not what then
            local noun = self.NOUN[trait.like]
            what = ns.T("effect.activity", { activity = noun:sub(1, 1):upper() .. noun:sub(2) })
        end
    end
    return ns.T("effect.liked", { what = what, n = C.BOND_LIKED_POINTS,
        cap = trait.when and C.BOND_TRAIT_CAP or C.BOND_LIKED_CAP, other = C.BOND_OTHER_POINTS })
end

local Join = ns.Join

-- "Kosete og Nattugle"
function Personality:Names(key)
    local names = {}
    for _, t in ipairs(self:Traits(key)) do names[#names + 1] = t.name end
    return Join(names)
end

-- The liked activities, as words.
function Personality:LikedWords(key)
    local _, list = self:Of(key)
    local words = {}
    for _, act in ipairs(list) do words[#words + 1] = self.NOUN[act] end
    return words
end

-- What it dislikes: { activity = true, or "minor" }, and the ordered list. Never a like. The minor one
-- once your bond has unlocked it (all: unlocked or not, for the achievement that counts them all).
function Personality:Dislikes(key, all)
    local likes, _, traits = self:Of(key)
    local set, list = {}, {}
    local function Add(act, how)
        if act and not likes[act] and not set[act] then set[act] = how or true; list[#list + 1] = act end
    end
    for _, t in ipairs(traits) do Add(t.dislike) end
    for _, f in ipairs(ns.Scenes:Families(key)) do
        for _, act in ipairs(self.DISLIKE_BY_FAMILY[f] or {}) do Add(act) end
    end
    local _, minor = self:Minor(key)
    if minor and (all or self.YourLevel(key) >= ns.Config.MINOR_DISLIKE_LEVEL) then Add(minor, "minor") end
    return set, list
end

-- The dislikes you've seen happen, as players read them (the rest stay secret): the major ones, and
-- the minor one (once unlocked and seen) apart, to be shown dimmed.
function Personality:DislikedWords(key)
    local seen = ns.DB.char.dislikes[key] or {}
    local set, list = self:Dislikes(key)
    local words, minor = {}, {}
    for _, act in ipairs(list) do
        if seen[act] then table.insert(set[act] == "minor" and minor or words, self.NOUN[act]) end
    end
    return words, minor
end

------------------------------------------------------------------------------
-- Minor likes and dislikes (2026-11-12, the user): one more like your bond with the pet unlocks at
-- MINOR_LIKE_LEVEL (4), one more dislike at MINOR_DISLIKE_LEVEL (6). Lesser than the major ones (the
-- family's, the species', the traits'): fewer points (BOND_MINOR_POINTS, BOND_MINOR_CAP), flavor a third
-- as often, dimmed on the card. Your own bond decides (the pet opens up to you); per species, pinned in
-- Data/Unlocks.lua (tools/pin_unlocks.lua). The dislike stays a secret until it happens, as all do.
------------------------------------------------------------------------------
Personality.MINOR_PINS = ns.UnlockPins or {}

-- The species' minor like and dislike, unlocked or not (nil: none, or one that a change since has
-- made a major like or dislike).
function Personality:Minor(key)
    local pin = self.MINOR_PINS[ns.Pets:SpeciesOfKey(key) or 0]
    if not pin then return nil, nil end
    local likes = self:Of(key)
    local like, dislike = pin[1] or nil, pin[2] or nil
    if like and likes[like] then like = nil end
    if dislike and (likes[dislike] or dislike == like) then dislike = nil end
    return like, dislike
end

-- Your own bond level with it (0: none).
function Personality.YourLevel(key)
    local e = key and ns.Registry:Life(key, ns.PlayerKey())
    return e and ns.Bond:Level(e.p) or 0
end

-- The minor like, if your bond has unlocked it.
function Personality:MinorLike(key)
    local like = self:Minor(key)
    if like and self.YourLevel(key) >= ns.Config.MINOR_LIKE_LEVEL then return like end
end

-- The next minor one your bond will unlock: "like" or "dislike" and its level, or nil.
function Personality:NextUnlock(key)
    local like, dislike = self:Minor(key)
    local level, C = self.YourLevel(key), ns.Config
    if like and level < C.MINOR_LIKE_LEVEL then return "like", C.MINOR_LIKE_LEVEL end
    if dislike and level < C.MINOR_DISLIKE_LEVEL then return "dislike", C.MINOR_DISLIKE_LEVEL end
end

-- A pet's personality is a surprise (decided 2026-11-09): shown only once
-- you've collected it, or someone in the guild has adopted it.
function Personality:Known(key)
    if not key then return false end
    return ns.Pets:IsOwned(key) or ns.Registry:Holder(key) ~= nil
end

-- "Kosete og Nattugle · liker herbs og quests" (or that it's unknown yet)
function Personality:Line(key)
    if not self:Known(key) then return ns.L["personality.unknown"] end
    local words = self:LikedWords(key)
    if #words == 0 then return self:Names(key) end
    return ns.T("personality.line", { traits = self:Names(key), likes = Join(words) })
end

-- Both traits explained, for a tooltip: name, what it means, what it does.
function Personality:Describe(tooltip, key)
    for _, t in ipairs(self:Traits(key)) do
        tooltip:AddLine(t.name, 1, 0.82, 0)
        tooltip:AddLine(t.desc, 1, 1, 1, true)
        tooltip:AddLine(self:Effect(t), 0.9, 0.75, 0.3, true)
    end
end
