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

-- Activities (Core/Activity.lua) as players read them, and the line for the
-- first liked one of the day (Locale/nb.lua: activity.*).
Personality.NOUN, Personality.FLAVOR = {}, {}
for _, id in ipairs({ "boss", "quest", "taxi", "pvp", "herb", "mine", "fish", "skin", "day", "dance", "cuddle", "chat",
    "dive", "level", "revive", "nap", "hearth", "jump", "explore" }) do
    Personality.NOUN[id] = L["activity." .. id]
    if ns.Strings["activity." .. id .. ".flavor"] then Personality.FLAVOR[id] = L["activity." .. id .. ".flavor"] end
end

Personality.BY_FAMILY = {
    cat = { "fish" }, bird = { "taxi" }, owl = { "taxi" }, farm = { "herb", "quest" }, rabbit = { "herb" },
    frog = { "fish", "dive" }, snake = { "herb" }, mechanical = { "mine" }, dragon = { "boss", "taxi" },
    pirate = { "fish", "pvp", "dive" }, bug = { "herb" }, rodent = { "mine" }, wolf = { "boss" }, plant = { "herb" },
    festive = { "quest" }, demon = { "boss" }, ooze = { "boss" }, spirit = { "taxi" },
}
Personality.DEFAULT = { "quest" } -- a pet with no family we know

-- Species with likes of their own (species id -> activities).
Personality.BY_SPECIES = {
    [5159] = { "herb" }, -- Panda Cub: bamboo
}

-- The holidays the Festglad pets celebrate ("MMDD" -> name, Locale/nb.lua: holiday.*).
Personality.HOLIDAYS = {}
for _, day in ipairs({ "0101", "0517", "0623", "1224", "1225", "1231" }) do
    Personality.HOLIDAYS[day] = L["holiday." .. day]
end

local function Hour(t) return tonumber(date("%H", t)) end

-- ids are permanent (they key the pinned list). What players read about a
-- trait is in Locale/nb.lua (trait.<id>.name, .desc, and for some .when,
-- .day, .flavor, .dayflavor), filled in below.
Personality.TRAITS = {
    { id = "glupsk", like = "quest" },
    { id = "eventyrlysten", like = "boss" },
    { id = "reiseglad", like = "taxi" },
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
    { id = "hjemlengsel", like = "hearth" },
    { id = "ambisios", like = "level" },
    { id = "latsabb", like = "nap" },
    { id = "pratsom", like = "chat" },
    { id = "kosete", day = function() return 2 end, dayX = 2 },
    { id = "nattugle", when = function(ctx) local h = Hour(ctx.t); return h >= 22 or h < 4 end },
    { id = "festglad", day = function(t) return Personality.HOLIDAYS[date("%m%d", t)] and 3 or 1 end, dayX = 3,
        dayFlavor = function(name, t)
            return ns.T("trait.festglad.dayflavor", { pet = name, holiday = Personality.HOLIDAYS[date("%m%d", t)] })
        end },
    { id = "helgedyr", day = function(t) local w = tonumber(date("%w", t)); return (w == 0 or w == 6) and 2 or 1 end,
        dayX = 2, dayFlavor = function(name) return ns.T("trait.helgedyr.dayflavor", { pet = name }) end },
    { id = "flokkdyr", against = "einstoing", when = function(ctx) return ctx.guildmates > 0 end },
    { id = "einstoing", against = "flokkdyr", when = function(ctx) return not ctx.group end },
    { id = "huleboer", against = "friluftsdyr", when = function(ctx) return ctx.instance end },
    { id = "friluftsdyr", against = "huleboer", when = function(ctx) return not ctx.instance end },
}
for _, t in ipairs(Personality.TRAITS) do
    local k = "trait." .. t.id
    t.name, t.desc = L[k .. ".name"], L[k .. ".desc"]
    if t.when then t.whenText, t.flavor = L[k .. ".when"], L[k .. ".flavor"] end
    if t.day then t.dayText = L[k .. ".day"] end
end

function Personality.ById(id)
    for _, t in ipairs(Personality.TRAITS) do if t.id == id then return t end end
end

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

-- How an activity reads in a trait's effect, where "X med kjæledyret ute"
-- doesn't say enough (Locale/nb.lua: effect.activity.*).
Personality.EFFECT = {}
for _, id in ipairs({ "dance", "cuddle", "chat", "dive", "level", "revive", "nap", "hearth", "jump", "explore" }) do
    Personality.EFFECT[id] = L["effect.activity." .. id]
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
    return ns.T("effect.liked", { what = what, n = C.BOND_LIKED_POINTS, cap = C.BOND_LIKED_CAP,
        other = C.BOND_OTHER_POINTS })
end

-- "herbs, quests og flyturer"
local function Join(words)
    if #words <= 1 then return words[1] or "" end
    return table.concat(words, L["list.sep"], 1, #words - 1) .. L["list.and"] .. words[#words]
end

Personality.Join = Join

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

-- "Kosete og Nattugle · liker herbs og quests"
function Personality:Line(key)
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
