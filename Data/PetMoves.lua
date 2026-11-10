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
--          every pet with a slider and saves the changes in DyreparkenDB.liftPicks, to copy in here.
ns.PetMoves = {
    default = { sleep = 6, sleepAt = 1.2, sit = 97, happy = 756, cheer = 754, dead = 1, walk = 4, run = 5 },
    species = {
        [70] = { lift = -0.2 },  -- Brown Prairie Dog: floated over its shadow
        [89] = { lift = 0.3 },  -- Worg Pup
        [5018] = { lift = 1.5 },  -- Snowy Wolf Pup
        [5121] = { lift = 0.3 },  -- Prairie Wolf Pup
        [5159] = { sleepAt = 1.5 },  -- Panda Cub: its fall ends later
        [5160] = { happy = false, sleep = false, lift = 0.3 },  -- Zergling: PetBattleCustom0 is an attack; asleep too messy for now (6 or 770 held at 2.7 were the best)
        [5161] = { sleep = false },  -- Mini Diablo: Dead (6) makes him vanish (Death bursts into flames)
    },
}
