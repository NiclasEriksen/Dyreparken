local _, ns = ...

-- How the pet on the journal card moves (Menagerie/Moves.lua). EDIT BY HAND.
--
-- Each reaction plays one animation id. `default` is what every pet uses; a
-- species can override any reaction with another id, or with false (that pet
-- doesn't do it: it just stands). Models differ a lot, and the client can't
-- tell us which animations a model has, so this is found by eye.
--
-- To try ids on a pet: open its card in the pet journal, then
--   /dp probe anim <id>     (in a git checkout; /dp probe anim stop in between)
--   /dp probe anim custom   (the four pet battle custom moves, 3 s each)
-- Ids and names: Moves.ANIMS in Menagerie/Moves.lua. The species id is the
-- [number] on the pet's line in Data/Companions.lua.
--
-- Reactions:
--   sleep  held at night while you look at the card (not for a Nattugle); a click
--          wakes it. Played for sleepAt seconds (it lies down), then frozen there,
--          cut to without a blend, so it stays down: try one with /dp probe anim blend none, then
--          /dp probe anim <id> 0 <seconds> (blend anim afterwards). To see the
--          card at night by day: /dp probe anim night
--   sit    held by a Latsabb after a few seconds on the card (it sits down
--          with 96 first), and by any pet of yours once its day's bond is full
--   happy  a click on the pet (on the Panda Cub, PetBattleCustom0 is a hop)
--   cheer  a bond level-up, during the celebration
--   dead   the day of the "is it safe to live with you?" egg, once
--   walk   the pet you keep out (auto-summon), while you move on foot and it would just stand
--   run    ... while you're mounted and moving (on a taxi it stands)
--   lift   (not an animation) how much higher (or lower, negative) the pet stands on its card than
--          Blizzard puts it: some models float, some sink. Found by eye: /dp probe lift steps through
--          every pet with a slider and saves the changes in DyreparkenDB.liftPicks, to copy in here
--          (every pet set by eye 2026-11-10).
ns.PetMoves = {
    default = { sleep = 6, sleepAt = 1.2, sit = 97, happy = 756, cheer = 754, dead = 1, walk = 4, run = 5 },
    species = {
        [39] = { lift = -0.1 },  -- Mechanical Squirrel
        [40] = { lift = -0.1 },  -- Bombay
        [41] = { lift = -0.1 },  -- Cornish Rex
        [42] = { lift = -0.1 },  -- Black Tabby
        [43] = { lift = -0.1 },  -- Orange Tabby
        [44] = { lift = -0.1 },  -- Siamese
        [45] = { lift = -0.1 },  -- Silver Tabby
        [46] = { lift = -0.1 },  -- White Kitten
        [55] = { lift = -0.05 },  -- Cockroach
        [64] = { lift = -0.1 },  -- Wood Frog
        [65] = { lift = -0.1 },  -- Tree Frog
        [67] = { lift = 0.2 },  -- Hawk Owl
        [68] = { lift = 0.2 },  -- Great Horned Owl
        [70] = { lift = -0.2 },  -- Brown Prairie Dog: floated over its shadow
        [74] = { lift = -0.05 },  -- Albino Snake
        [75] = { lift = -0.05 },  -- Black Kingsnake
        [77] = { lift = -0.05 },  -- Brown Snake
        [78] = { lift = -0.05 },  -- Crimson Snake
        [85] = { lift = 0.4 },  -- Tiny Walking Bomb
        [89] = { lift = 0.3 },  -- Worg Pup
        [90] = { lift = 0.8 },  -- Smolderweb Hatchling
        [95] = { lift = -0.1 },  -- Lifelike Toad
        [106] = { lift = -0.1 },  -- Jubling
        [114] = { lift = -0.4 },  -- Disgusting Oozeling
        [116] = { lift = 0.4 },  -- Tranquil Mechanical Yeti
        [117] = { lift = 0.2 },  -- Tiny Snowman
        [118] = { lift = 0.4 },  -- Winter Reindeer
        [119] = { lift = 0.35 },  -- Father Winter's Helper
        [120] = { lift = 0.25 },  -- Winter's Little Helper
        [125] = { lift = 0.2 },  -- Speedy
        [126] = { lift = 0.05 },  -- Mr. Wiggles
        [127] = { lift = -0.3 },  -- Whiskers the Rat
        [162] = { lift = 0.6 },  -- Sinister Squashling
        [5005] = { lift = -0.1 },  -- Musical Gustjumper
        [5006] = { lift = -0.05 },  -- Corrupted Kitten
        [5018] = { lift = 1.5 },  -- Snowy Wolf Pup
        [5075] = { lift = -0.5 },  -- Excitable Slime
        [5094] = { lift = 0.5 },  -- Bitter Baitling
        [5121] = { lift = 0.3 },  -- Prairie Wolf Pup
        [5136] = { lift = -0.5 },  -- Weevil K. Neevil
        [5153] = { lift = -0.1 },  -- Jungle Boa
        [5154] = { lift = -0.15 },  -- Brown Ground Squirrel
        [5155] = { lift = -0.15 },  -- Red Ground Squirrel
        [5158] = { lift = 0.25 },  -- Eagle Owl
        [5159] = { sleepAt = 1.5 },  -- Panda Cub: its fall ends later
        [5160] = { sleep = false, happy = false, lift = 0.4 },  -- Zergling: PetBattleCustom0 is an attack; asleep too messy for now (6 or 770 held at 2.7 were the best)
        [5161] = { sleep = false, lift = 0.2 },  -- Mini Diablo: Dead (6) makes him vanish (Death bursts into flames)
        [5162] = { lift = 0.3 },  -- Baby Crocolisk
        [5163] = { lift = -0.5 },  -- Shen'dorei Wisp
        [5172] = { lift = 0.25 },  -- Tallstrider Hatchling
        [5174] = { lift = 1.2 },  -- Minfernal
        [5176] = { lift = 0.6 },  -- Minimule
        [5179] = { lift = -1 },  -- Azurky
        [5183] = { lift = 0.5 },  -- Spawn of Grubthor
        [5200] = { lift = 0.2 },  -- Viridian Lashling
        [5201] = { lift = 0.2 },  -- Frosty Lashling
        [5202] = { lift = 0.2 },  -- Wilted Lashling
        [5203] = { lift = 0.2 },  -- Flowery Lashling
    },
}
