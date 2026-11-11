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
--          wakes it. Played for sleepAt seconds (it lies down), then paused there (SetPaused;
--          0.7 s caught most pets lying down, 2026-11-10: at 0.8 the cats were getting up again).
--          Try one with /dp probe anim sleep <id> <seconds>. To see the
--          card at night by day: /dp probe anim night
--   sleepHold  (optional) a looping animation to hold instead of pausing the lie-down: the pet is
--              then asleep in it as its card opens (sleep and sleepAt only show in /dp probe moves)
--   sleepUp    (optional) played when it's woken, before the happy move
--   canSit false: the pet never sits (it has no sitting animation that looks right)
--   sit    held by a Latsabb after a few seconds on the card (it sits down
--          with sitDown first, and gets up with sitUp), and by any pet of yours once its day's bond is full
--   All of these, per pet, are easiest to pick with /dp probe moves (a window: step through the
--   pets and the parts, "Prøv" plays it from a clean start; picks saved in DyreparkenDB.movePicks)
--   happy  a click on the pet (on the Panda Cub, PetBattleCustom0 is a hop)
--   happyToo  played instead of happy now and then (Moves.HAPPY_TOO_CHANCE), for variation: the
--             pet battle wounds have some neat moves (the user, 2026-11-11). false: always happy
--   cheer  a bond level-up, during the celebration
--   dead   the day of the "is it safe to live with you?" egg, once
--   walk   the pet you keep out (auto-summon), while you move on foot and it would just stand
--   run    ... while you're mounted and moving (on a taxi it stands)
--   lift   (not an animation) how much higher (or lower, negative) the pet stands on its card than
--          Blizzard puts it: some models float, some sink. Found by eye: /dp probe lift steps through
--          every pet with a slider and saves the changes in DyreparkenDB.liftPicks, to copy in here
--          (every pet set by eye 2026-11-10).
ns.PetMoves = {
    default = { sleep = 6, sleepAt = 0.7, sleepHold = false, sleepUp = false, canSit = true, sitDown = 96, sit = 97, sitUp = 98, happy = 756, happyToo = 748, cheer = 754, dead = 1, walk = 4, run = 5 },
    species = {
        [39] = { lift = -0.1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Mechanical Squirrel
        [40] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Bombay
        [41] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Cornish Rex
        [42] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Black Tabby
        [43] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Orange Tabby
        [44] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Siamese: the cats lie down, sleep and get up with their own sleep animations (/dp probe moves, the user 2026-11-11; all cats share the model)
        [45] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Silver Tabby
        [46] = { lift = -0.1, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- White Kitten
        [47] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Cockatiel
        [49] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Hyacinth Macaw
        [50] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Green Wing Macaw
        [51] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Senegal
        [52] = { sleepHold = 6, sleepUp = 0, canSit = false },  -- Ancona Chicken
        [55] = { lift = -0.05 },  -- Cockroach
        [56] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Dark Whelpling
        [57] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Azure Whelpling
        [58] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Crimson Whelpling
        [59] = { sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Emerald Whelpling
        [64] = { lift = -0.1, sleepHold = 6, sleepUp = 0 },  -- Wood Frog
        [65] = { lift = -0.1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Tree Frog
        [67] = { lift = 0.2, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Hawk Owl
        [68] = { lift = 0.2, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Great Horned Owl
        [70] = { lift = -0.2, sleep = 1, sleepAt = 0.6, sleepHold = 6, sleepUp = 0, canSit = false },  -- Brown Prairie Dog: floated over its shadow
        [72] = { sleepHold = 6, sleepUp = 0, canSit = false },  -- Snowshoe Rabbit
        [74] = { lift = -0.05, sleepHold = 6, sleepUp = 0, canSit = false },  -- Albino Snake
        [75] = { lift = -0.05, sleepHold = 6, sleepUp = 0, canSit = false },  -- Black Kingsnake
        [77] = { lift = -0.05, sleepHold = 6, sleepUp = 0, canSit = false },  -- Brown Snake
        [78] = { lift = -0.05, sleepHold = 6, sleepUp = 0, canSit = false },  -- Crimson Snake
        [83] = { sleepHold = 6, sleepUp = 0, canSit = false },  -- Mechanical Chicken
        [85] = { lift = 0.4, sleep = 99, sleepHold = 100, sleepUp = 101 },  -- Tiny Walking Bomb
        [87] = { sleep = 744, sleepHold = 6, sleepUp = 101, canSit = false },  -- Sprite Darter Hatchling
        [89] = { lift = 0.3, sleepHold = 6, sleepUp = 0, canSit = false },  -- Worg Pup
        [90] = { lift = 1, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Smolderweb Hatchling
        [95] = { lift = -0.1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Lifelike Toad
        [106] = { lift = -0.1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Jubling
        [114] = { lift = -0.8, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Disgusting Oozeling
        [116] = { lift = 0.4, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Tranquil Mechanical Yeti
        [117] = { lift = 0.2, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Tiny Snowman
        [118] = { lift = 0.4, sleepHold = 6, sleepUp = 0, canSit = false },  -- Winter Reindeer
        [119] = { lift = 0.35, sleep = 99, sleepHold = 100, sleepUp = 101 },  -- Father Winter's Helper
        [120] = { lift = 0.25, sleep = 99, sleepHold = 100, sleepUp = 101 },  -- Winter's Little Helper
        [122] = { sleepHold = 6, sleepUp = 0, canSit = false },  -- Peddlefeet
        [125] = { lift = 0.2, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Speedy
        [126] = { lift = 0.05, sleepHold = 6, sleepUp = 0, canSit = false },  -- Mr. Wiggles
        [127] = { lift = -0.3, sleepHold = 6, sleepUp = 0, canSit = false },  -- Whiskers the Rat
        [128] = { sleep = 99, sleepHold = 100, sleepUp = 101, canSit = false },  -- Spirit of Summer
        [162] = { lift = 0.6, sleep = 1, sleepHold = 6, sleepUp = 0, canSit = false },  -- Sinister Squashling
        [5005] = { lift = -0.1 },  -- Musical Gustjumper
        [5006] = { lift = -0.05, sleep = 99, sleepAt = 1.4, sleepHold = 100, sleepUp = 101, happy = 758 },  -- Corrupted Kitten
        [5018] = { lift = 1.9 },  -- Snowy Wolf Pup
        [5075] = { lift = -0.5 },  -- Excitable Slime
        [5094] = { lift = 0.7 },  -- Bitter Baitling
        [5121] = { lift = 0.15 },  -- Prairie Wolf Pup
        [5136] = { lift = -0.5 },  -- Weevil K. Neevil
        [5138] = { lift = 0.1 },  -- Pachimari
        [5139] = { lift = -0.15 },  -- Galestrider Chick
        [5153] = { lift = -0.1 },  -- Jungle Boa
        [5154] = { lift = -0.15 },  -- Brown Ground Squirrel
        [5155] = { lift = -0.15 },  -- Red Ground Squirrel
        [5158] = { lift = 0.25 },  -- Eagle Owl
        [5160] = { happy = false, lift = 0.4 },  -- Zergling: PetBattleCustom0 is an attack
        [5161] = { sleep = false, lift = 0.2 },  -- Mini Diablo: Dead (6) makes him vanish (Death bursts into flames)
        [5162] = { lift = 0.8 },  -- Baby Crocolisk
        [5163] = { lift = -0.75 },  -- Shen'dorei Wisp
        [5167] = { lift = -0.25 },  -- Condor Hatchling
        [5172] = { lift = 0.25 },  -- Tallstrider Hatchling
        [5174] = { lift = 1.5 },  -- Minfernal
        [5176] = { lift = 0.6 },  -- Minimule
        [5179] = { lift = -1 },  -- Azurky
        [5183] = { lift = 0.5 },  -- Spawn of Grubthor
        [5200] = { lift = 0.2 },  -- Viridian Lashling
        [5201] = { lift = 0.2 },  -- Frosty Lashling
        [5202] = { lift = 0.2 },  -- Wilted Lashling
        [5203] = { lift = 0.2 },  -- Flowery Lashling
    },
}
