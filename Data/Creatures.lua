local _, ns = ...

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
}
