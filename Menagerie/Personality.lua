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
-- Picking: two traits per species from its id, never a pair that contradicts
-- itself (Flokkdyr and Einstøing). The pick moves when traits are added, so
-- the plan (2026-11-08) is to pin every species' traits in a list once the
-- probed traits are in, and never reshuffle after that.
local Personality = {}
ns.Personality = Personality

-- Activities (Core/Activity.lua) as players read them: the guild's own
-- words (herbs, kills, quests, mining, skinning), decided 2026-11-08.
Personality.NOUN = {
    boss = "boss-kills", quest = "quests", taxi = "flyturer", pvp = "PvP", herb = "herbs",
    mine = "mining", fish = "fisking", skin = "skinning", day = "dager sammen",
    dance = "dansing", cuddle = "kos", chat = "guildprat", dive = "dykking", level = "nye levels",
    revive = "å vente på deg", nap = "lur i byen", hearth = "å dra hjem", jump = "hopping", explore = "nye steder",
}

-- The first liked thing each day gets a line; these read better than
-- "koste seg med ..." ("%s" is the pet's name).
Personality.FLAVOR = {
    dance = "%s danset med deg!", cuddle = "%s elsker å bli kost med!", chat = "%s lytter fornøyd til guildpraten.",
    dive = "%s plasket rundt med deg!", level = "%s er så stolt av deg!", revive = "%s ventet tålmodig på deg.",
    nap = "%s tok en lur sammen med deg.", hearth = "%s er glad for å være hjemme!", jump = "%s hopper av glede!",
    explore = "%s snuser på et nytt sted!",
}

Personality.BY_FAMILY = {
    cat = { "fish" }, bird = { "taxi" }, owl = { "taxi" }, farm = { "herb", "quest" }, rabbit = { "herb" },
    frog = { "fish" }, snake = { "herb" }, mechanical = { "mine" }, dragon = { "boss", "taxi" },
    pirate = { "fish", "pvp" },
}
Personality.DEFAULT = { "quest" } -- a pet with no family we know

-- Species with likes of their own (species id -> activities).
Personality.BY_SPECIES = {
    [5159] = { "herb" }, -- Panda Cub: bamboo
}

-- Norwegian holidays the Festglad pets celebrate ("MMDD" -> name).
Personality.HOLIDAYS = {
    ["0101"] = "1. nyttårsdag", ["0517"] = "17. mai", ["0623"] = "St. Hans", ["1224"] = "julaften",
    ["1225"] = "1. juledag", ["1231"] = "nyttårsaften",
}

local function Hour(t) return tonumber(date("%H", t)) end

-- ids are permanent (they'll key the pinned list); names and texts can change.
Personality.TRAITS = {
    { id = "glupsk", name = "Glupsk", desc = "Spiser alt, og elsker belønningen etter en quest.", like = "quest" },
    { id = "eventyrlysten", name = "Eventyrlysten", desc = "Vil alltid være med på boss-kills.", like = "boss" },
    { id = "reiseglad", name = "Reiseglad", desc = "Elsker å fly.", like = "taxi" },
    { id = "rampete", name = "Rampete", desc = "Liker litt bråk.", like = "pvp" },
    { id = "gronnfinger", name = "Grønnfinger", desc = "Snuser på hver eneste herb.", like = "herb" },
    { id = "vannhund", name = "Vannhund", desc = "Elsker vann og fisk.", like = "fish" },
    { id = "steinhard", name = "Steinhard", desc = "Graver gjerne etter malm.", like = "mine" },
    { id = "dansefot", name = "Dansefot", desc = "Kan ikke sitte stille når du danser.", like = "dance" },
    { id = "kjaelen", name = "Kjælen", desc = "Elsker /pet, /hug og /cuddle.", like = "cuddle" },
    { id = "oppdager", name = "Oppdager", desc = "Vil se hele verden, ett sted om gangen.", like = "explore" },
    { id = "trofast", name = "Trofast", desc = "Venter på deg, uansett hva som skjer.", like = "revive" },
    { id = "hoppetass", name = "Hoppetass", desc = "Hopper når du hopper.", like = "jump" },
    { id = "dykker", name = "Dykker", desc = "Holder pusten lenger enn deg.", like = "dive" },
    { id = "hjemlengsel", name = "Hjemlengsel", desc = "Borte bra, men hjemme best.", like = "hearth" },
    { id = "ambisios", name = "Ambisiøs", desc = "Vil se deg bli sterkere.", like = "level" },
    { id = "latsabb", name = "Latsabb", desc = "En lur i byen er det beste som finnes.", like = "nap" },
    { id = "pratsom", name = "Pratsom", desc = "Elsker når du prater med guilden.", like = "chat" },
    { id = "kosete", name = "Kosete", desc = "Det er nok å være sammen.",
        day = function() return 2 end, dayX = 2, dayText = "Hver dag sammen" },
    { id = "nattugle", name = "Nattugle", desc = "Våkner til liv når det blir mørkt.",
        when = function(ctx) local h = Hour(ctx.t); return h >= 22 or h < 4 end,
        whenText = "mellom kl. 22 og 04", flavor = "%s elsker nattlige eventyr!" },
    { id = "festglad", name = "Festglad", desc = "Elsker 17. mai, St. Hans, jul og nyttår.",
        day = function(t) return Personality.HOLIDAYS[date("%m%d", t)] and 3 or 1 end, dayX = 3,
        dayFlavor = function(name, t) return ("%s feirer %s med deg!"):format(name, Personality.HOLIDAYS[date("%m%d", t)]) end,
        dayText = "En høytidsdag sammen (17. mai, St. Hans, julaften, 1. juledag, nyttårsaften, 1. nyttårsdag)" },
    { id = "helgedyr", name = "Helgedyr", desc = "Lever for helgene.",
        day = function(t) local w = tonumber(date("%w", t)); return (w == 0 or w == 6) and 2 or 1 end, dayX = 2,
        dayFlavor = function(name) return ("%s elsker helg!"):format(name) end,
        dayText = "En lørdag eller søndag sammen" },
    { id = "flokkdyr", name = "Flokkdyr", desc = "Trives best i flokk.", against = "einstoing",
        when = function(ctx) return ctx.guildmates > 0 end,
        whenText = "med en fra guilden i gruppen", flavor = "%s koste seg i flokken!" },
    { id = "einstoing", name = "Einstøing", desc = "Vil helst ha deg for seg selv.", against = "flokkdyr",
        when = function(ctx) return not ctx.group end,
        whenText = "uten noen gruppe", flavor = "%s nøt å ha deg for seg selv!" },
    { id = "huleboer", name = "Huleboer", desc = "Føler seg hjemme i mørke ganger.", against = "friluftsdyr",
        when = function(ctx) return ctx.instance end,
        whenText = "i dungeons og raids", flavor = "%s trives i mørket!" },
    { id = "friluftsdyr", name = "Friluftsdyr", desc = "Elsker frisk luft.", against = "huleboer",
        when = function(ctx) return not ctx.instance end,
        whenText = "ute i verden (ikke i dungeons)", flavor = "%s nøt den friske luften!" },
}

function Personality.ById(id)
    for _, t in ipairs(Personality.TRAITS) do if t.id == id then return t end end
end

-- Species whose traits are pinned (species id -> two trait ids). Every
-- species goes in here once the probed traits are in (see the header).
Personality.PINNED = {
    [5159] = { "kosete", "gronnfinger" }, -- Panda Cub (chosen 2026-11-08)
}

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
-- doesn't say enough.
Personality.EFFECT = {
    dance = "/dance med kjæledyret ute", cuddle = "/pet, /hug eller /cuddle på kjæledyret",
    chat = "Hver linje du skriver i guildchatten", dive = "Hver gang du dykker under vann med kjæledyret ute",
    level = "Hvert level du går opp med kjæledyret ute", revive = "Hver gang du står opp igjen etter å ha dødd",
    nap = "/afk i en by eller et vertshus med kjæledyret ute", hearth = "Hearthstone med kjæledyret ute",
    jump = "Hvert tiende hopp med kjæledyret ute", explore = "Hvert nytt sted kjæledyret ser sammen med deg",
}

-- What a trait does, in numbers (from ns.Config, so it can't go stale).
function Personality:Effect(trait)
    local C = ns.Config
    if trait.day then
        return ("%s gir %s så mange bånd-poeng (%d i stedet for %d)."):format(trait.dayText,
            trait.dayX == 3 and "tre ganger" or "dobbelt", C.BOND_DAY_POINTS * trait.dayX, C.BOND_DAY_POINTS)
    end
    local what
    if trait.when then
        what = ("Alt dere gjør sammen %s"):format(trait.whenText)
    else
        what = self.EFFECT[trait.like]
        if not what then
            local noun = self.NOUN[trait.like]
            what = ("%s med kjæledyret ute"):format(noun:sub(1, 1):upper() .. noun:sub(2))
        end
    end
    return ("%s gir %d bånd-poeng (opptil %d om dagen), mot %d ellers."):format(what, C.BOND_LIKED_POINTS,
        C.BOND_LIKED_CAP, C.BOND_OTHER_POINTS)
end

-- "herbs, quests og flyturer"
local function Join(words)
    if #words <= 1 then return words[1] or "" end
    return table.concat(words, ", ", 1, #words - 1) .. " og " .. words[#words]
end

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
    return ("%s · liker %s"):format(self:Names(key), Join(words))
end

-- Both traits explained, for a tooltip: name, what it means, what it does.
function Personality:Describe(tooltip, key)
    for _, t in ipairs(self:Traits(key)) do
        tooltip:AddLine(t.name, 1, 0.82, 0)
        tooltip:AddLine(t.desc, 1, 1, 1, true)
        tooltip:AddLine(self:Effect(t), 0.9, 0.75, 0.3, true)
    end
end
