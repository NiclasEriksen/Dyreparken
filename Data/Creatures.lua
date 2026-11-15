---@class Dyreparken
local ns = select(2, ...)

-- Creatures in the world, as our families (docs/CLASS_INTERACTIONS.md, part 1.4), EDITED BY HAND: what a
-- hunter's pet, a warlock's demon or a beast under the mouse is to our pets (kin, prey, a hunter: Quirks.PREY).
-- By UnitCreatureFamily's id, the same in every locale (Forever's, from /dp probe api glance 2026-11-14:
-- Wolf 1, Cat 2, Crocolisk 6, Tallstrider 12, Voidwalker 16, Turtle 21, Imp 23, Bat 24; the rest are the
-- classic ids, unverified). A family with no row here is nothing of ours.
ns.Creatures = {
    families = {
        [1] = { "wolf" },          -- Wolf
        [2] = { "cat" },           -- Cat
        [3] = { "bug" },           -- Spider
        [4] = { "bear" },          -- Bear
        [5] = { "farm" },          -- Boar
        [6] = { "reptile" },       -- Crocolisk
        [7] = { "bird" },          -- Carrion Bird
        [8] = { "murloc" },        -- Crab (the coast's: the murlocs' neighbours)
        [11] = { "reptile" },      -- Raptor
        [12] = { "bird" },         -- Tallstrider
        [15] = { "demon" },        -- Felhunter
        [16] = { "demon" },        -- Voidwalker
        [17] = { "demon" },        -- Succubus
        [19] = { "demon" },        -- Doomguard
        [20] = { "bug" },          -- Scorpid
        [21] = { "reptile" },      -- Turtle
        [23] = { "demon" },        -- Imp
        [24] = { "bird" },         -- Bat (it flies)
        [25] = { "wolf" },         -- Hyena
        [26] = { "owl", "bird" },  -- Owl
        [27] = { "snake" },        -- Wind Serpent
        [29] = { "demon" },        -- Felguard
    },
    -- A beast or critter with no family by its name's words (2026-11-15, /dp probe sense: Forever's own
    -- creatures, npc ids 255000 and up, come with none even when beasts: a Hawk, a Jumbo Crawfish typed
    -- humanoid; the client's Creature table has only companions, so the name is all there is). Whole words,
    -- any case; the first word found wins. English names only (a client in another language finds none).
    names = {
        hawk = { "bird" }, eagle = { "bird" }, buzzard = { "bird" }, vulture = { "bird" }, condor = { "bird" },
        crow = { "bird" }, raven = { "bird" }, parrot = { "bird" }, strider = { "bird" }, owl = { "owl", "bird" },
        bat = { "bird" }, chicken = { "farm", "bird" }, hen = { "farm", "bird" },
        boar = { "farm" }, pig = { "farm" }, cow = { "farm" }, sheep = { "farm" }, goat = { "farm" }, kodo = { "farm" },
        wolf = { "wolf" }, worg = { "wolf" }, coyote = { "wolf" }, jackal = { "wolf" }, hyena = { "wolf" },
        cat = { "cat" }, lion = { "cat" }, tiger = { "cat" }, panther = { "cat" }, lynx = { "cat" },
        cougar = { "cat" }, prowler = { "cat" },
        bear = { "bear" }, grizzly = { "bear" },
        spider = { "bug" }, scorpid = { "bug" }, scorpion = { "bug" }, beetle = { "bug" }, roach = { "bug" },
        wasp = { "bug" }, moth = { "bug" }, silithid = { "bug" },
        crab = { "murloc" }, crawfish = { "murloc" }, crawler = { "murloc" }, lobster = { "murloc" },
        crocolisk = { "reptile" }, raptor = { "reptile" }, turtle = { "reptile" }, tortoise = { "reptile" },
        lizard = { "reptile" }, basilisk = { "reptile" },
        snake = { "snake" }, serpent = { "snake" }, python = { "snake" }, cobra = { "snake" },
        frog = { "frog" }, toad = { "frog" },
        rabbit = { "rabbit" }, hare = { "rabbit" },
        rat = { "rodent" }, squirrel = { "rodent" }, prairie = { "rodent" }, mouse = { "rodent" },
        ooze = { "ooze" }, slime = { "ooze" },
    },
}

-- Our families for a beast or critter with no family of its own, by its name (ns.Creatures.names), or nil.
function ns.Creatures.ByName(name)
    if type(name) ~= "string" then return nil end
    for word in name:lower():gmatch("%a+") do
        local got = ns.Creatures.names[word]
        if got then return got end
    end
end
