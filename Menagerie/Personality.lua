local _, ns = ...

-- A companion's personality (docs/PET_LIFE.md): what it likes doing with you,
-- and one quirk. It belongs to the species, so every client agrees without
-- sending anything, and it's the same for every carer.
--
-- Likes come from the pet's families (our tags in Data/Companions.lua), a
-- few species of their own (the Panda Cub and its bamboo), and the quirk.
-- The quirk is picked from the species id. A liked activity done with your
-- adopted companion out is worth more bond points (Bond.lua).
local Personality = {}
ns.Personality = Personality

-- Activities (Core/Activity.lua) as players read them: the guild's own
-- words (herbs, kills, quests), decided 2026-11-08.
Personality.NOUN = {
    boss = "boss-kills", quest = "quests", taxi = "flyturer", pvp = "PvP", herb = "herbs",
    mine = "gruvedrift", fish = "fisking", skin = "flåing", day = "dager sammen",
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

Personality.QUIRKS = {
    { name = "Glupsk", desc = "Spiser alt, og elsker belønningen etter en quest.", like = "quest" },
    { name = "Eventyrlysten", desc = "Vil alltid være med på boss-kills.", like = "boss" },
    { name = "Reiseglad", desc = "Elsker å fly.", like = "taxi" },
    { name = "Rampete", desc = "Liker litt bråk.", like = "pvp" },
    { name = "Grønnfinger", desc = "Snuser på hver eneste herb.", like = "herb" },
    { name = "Vannhund", desc = "Elsker vann og fisk.", like = "fish" },
    { name = "Steinhard", desc = "Graver gjerne etter malm.", like = "mine" },
    { name = "Kosete", desc = "Det er nok å være sammen: hver dag teller dobbelt.", like = "day" },
}

-- The quirk for a species: the same on every client.
function Personality:Quirk(key)
    local sid = ns.Pets:SpeciesOfKey(key) or 0
    local n = #self.QUIRKS
    return self.QUIRKS[math.fmod(sid * 2654435761, 4294967296) % n + 1]
end

-- likes: { activity = true }, the ordered list, and the quirk.
function Personality:Of(key)
    local likes, list = {}, {}
    local function Add(act)
        if not likes[act] then likes[act] = true; list[#list + 1] = act end
    end
    local sid = ns.Pets:SpeciesOfKey(key)
    for _, act in ipairs(sid and self.BY_SPECIES[sid] or {}) do Add(act) end
    local families = ns.Scenes:Families(key)
    for _, f in ipairs(families) do
        for _, act in ipairs(self.BY_FAMILY[f] or {}) do Add(act) end
    end
    if #list == 0 then for _, act in ipairs(self.DEFAULT) do Add(act) end end
    local quirk = self:Quirk(key)
    Add(quirk.like)
    return likes, list, quirk
end

-- What a quirk does, in numbers (from ns.Config, so it can't go stale).
function Personality:Effect(quirk)
    local C = ns.Config
    if quirk.like == "day" then
        return ("Hver dag sammen gir dobbelt så mange bånd-poeng (%d i stedet for %d)."):format(
            C.BOND_DAY_POINTS * 2, C.BOND_DAY_POINTS)
    end
    local noun = self.NOUN[quirk.like]
    return ("%s med kjæledyret ute gir %d bånd-poeng (opptil %d om dagen), mot %d ellers."):format(
        noun:sub(1, 1):upper() .. noun:sub(2), C.BOND_LIKED_POINTS, C.BOND_LIKED_CAP, C.BOND_OTHER_POINTS)
end

-- "herbs, quests og flyturer"
local function Join(words)
    if #words <= 1 then return words[1] or "" end
    return table.concat(words, ", ", 1, #words - 1) .. " og " .. words[#words]
end

-- "Glupsk · liker herbs og quests" (the quirk's own like included;
-- "dager sammen" reads oddly as a like, so Kosete just says so in its desc).
function Personality:Line(key)
    local _, list, quirk = self:Of(key)
    local words = {}
    for _, act in ipairs(list) do
        if act ~= "day" then words[#words + 1] = self.NOUN[act] end
    end
    if #words == 0 then return quirk.name end
    return ("%s · liker %s"):format(quirk.name, Join(words))
end
