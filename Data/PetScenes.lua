---@class Dyreparken
local ns = select(2, ...)

-- Where pets stand in each model scene, and how tall (Menagerie/Moves.lua, Moves.FRAMING). EDITED BY HAND,
-- from /dp probe place (picks saved in DyreparkenDB.placePicks and modelPicks). Per stage (card, park, frame), by the scene
-- id Blizzard gives a species (C_PetJournal.GetPetModelSceneInfoBySpeciesID): floor, the height its feet
-- stand at; size, how tall a pet stands (Moves.WIDE times that at most across). A stage without a scene's
-- row uses the card's; a scene with none at all: as Blizzard has it, with the old lifts (Data/PetMoves.lua).
ns.PetScenes = {
    -- (the user, 2026-11-16, /dp probe place: 1268, 1273 and 1705 right for their pets; 1271 and 1272 too
    -- many models for one value: those that differ have a row in ns.PetModels)
    card = {
        [6] = { floor = 0.45, size = 4.2 },     -- the Bronze Whelpling's
        [1267] = { floor = -1, size = 5.35 },
        [1268] = { floor = 0.45, size = 5.15 },
        [1269] = { floor = 0.9, size = 3 },
        [1270] = { floor = 0.45, size = 2 },
        [1271] = { floor = 0.45, size = 2.55 },
        [1272] = { floor = 1.25, size = 7.2 },
        [1273] = { floor = 0.8, size = 4.85 },
        [1705] = { floor = 1.15, size = 4.2 },
    },
    park = {},
    frame = {},
}

-- The same per model, where its scene's row doesn't fit it (the user, 2026-11-16: "automatically group those
-- that share a model ... they always want the same values"). A model is known by its standing box in
-- Data/PetBoxes.lua ("low high wide", Moves.ModelOf): pets that share one (the cats, the parrots, the whelps,
-- even the Bronze Whelpling in another scene) share a row. A stage's model row goes before its scene row.
ns.PetModels = {
    -- (the user, 2026-11-16, a model at a time: "for the most part good ... some of them a bit small, but that's
    -- realistic based on their actual size"; by scene: the scene, then the pets)
    card = {
        ["0.374 6.304 6.043"] = { floor = -0.45, size = 3.2 },  -- 1267: Condor Hatchling
        ["-0.010 3.735 4.899"] = { floor = 0.8, size = 3.85 },  -- 1268: Galestrider Chick
        ["-0.011 2.639 5.163"] = { floor = 0.55, size = 3 },  -- 1268: Weevil K. Neevil
        ["-0.216 2.657 6.973"] = { floor = 1.6, size = 3 },  -- 1268: Shadowgale Squirrel
        ["-0.003 0.448 1.338"] = { floor = 0.7, size = 3 },  -- 1269: Whiskers the Rat
        ["0.000 1.044 1.681"] = { floor = 1, size = 2.65 },  -- 1269: Mr. Wiggles
        ["-0.006 0.511 0.767"] = { floor = 0.6, size = 2 },  -- 1270: Arctic Hare, Brown Rabbit, Snowshoe Rabbit
        ["-0.002 0.272 0.518"] = { floor = 0.4, size = 3 },  -- 1271: Jubling, Lifelike Toad, Musical Gustjumper, Tree Frog, Wood Frog
        ["-0.014 0.361 0.359"] = { floor = 0.35, size = 3 },  -- 1271: Brown Ground Squirrel, Brown Prairie Dog, Red Ground Squirrel
        ["0.000 0.442 0.531"] = { floor = 0.55, size = 3 },  -- 1271: Ancona Chicken, Mechanical Chicken, Prairie Chicken, Wild Chicken
        ["-0.014 2.720 3.639"] = { floor = 2.85, size = 3.3 },  -- 1272: Zergling
        ["-0.015 1.258 1.939"] = { floor = 1.25, size = 3.2 },  -- 1272: Azurky
        ["-0.018 2.039 6.088"] = { floor = 4, size = 3.3 },  -- 1272: Smolderweb Hatchling
        ["-0.018 2.774 3.833"] = { floor = 2.2, size = 4.2 },  -- 1272: Winter Reindeer
        ["-0.022 3.533 3.362"] = { floor = 2.5, size = 4.2 },  -- 1272: Minimule
        ["-0.029 3.252 3.102"] = { floor = 1.95, size = 4.85 },  -- 1272: Tallstrider Hatchling
        ["-0.029 3.288 4.191"] = { floor = 2.95, size = 3.2 },  -- 1272: Bitter Baitling, Spawn of Grubthor
        ["-0.037 3.554 3.393"] = { floor = 2.5, size = 4.6 },  -- 1272: Tranquil Mechanical Yeti
        ["-0.039 1.662 5.376"] = { floor = 2.95, size = 3.55 },  -- 1272: Baby Crocolisk
        ["-0.087 3.739 3.784"] = { floor = 2.3, size = 5.15 },  -- 1272: Sinister Squashling
        ["-0.136 1.386 2.792"] = { floor = 1.4, size = 3.3 },  -- 1272: Disgusting Oozeling, Excitable Slime
        ["-0.141 1.879 3.742"] = { floor = 1.85, size = 3.55 },  -- 1272: Worg Pup
        ["-0.148 2.822 3.784"] = { floor = 2.3, size = 3.75 },  -- 1272: Flowery Lashling, Frosty Lashling, Viridian Lashling, Wilted Lashling
        ["-0.155 1.953 3.860"] = { floor = 2.2, size = 3.3 },  -- 1272: Spectral Bear Cub
        ["-0.168 2.254 4.022"] = { floor = 2.2, size = 3.3 },  -- 1272: Panda Cub
        ["0.000 2.110 4.412"] = { floor = 2.85, size = 3 },  -- 1272: Speedy
        ["0.000 3.910 2.777"] = { floor = 3.75, size = 3.65 },  -- 1272: Tiny Walking Bomb
        ["0.002 1.703 3.843"] = { floor = 1.95, size = 4.7 },  -- 1272: Prairie Wolf Pup, Snowy Wolf Pup
        ["0.014 3.115 3.172"] = { floor = 2.4, size = 4 },  -- 1272: Mini Diablo, Mini Uber Diablo
        ["0.031 4.129 5.478"] = { floor = 2.35, size = 4.05 },  -- 1272: Minfernal
        ["0.992 3.191 2.394"] = { floor = 1.85, size = 4 },  -- 1272: Azure Whelpling, Bronze Whelpling, Crimson Whelpling, Dark Whelpling, Emerald Whelpling
        ["1.103 2.470 1.541"] = { floor = 0.6, size = 3.2 },  -- 1272: Shen'dorei Wisp
        ["1.897 4.661 2.376"] = { floor = 2.4, size = 3.2 },  -- 1272: Peddlefeet
        ["-0.011 1.518 0.922"] = { floor = 0.9, size = 4.85 },  -- 1273: Father Winter's Helper
        ["-0.034 1.828 1.816"] = { floor = 1.15, size = 4.2 },  -- 1705: Pachimari
    },
    park = {},
    frame = {},
}
