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
--   sleep  held at night while you look at the card (not for a Nattugle); a
--          click wakes it
--   sit    held by a Latsabb after a few seconds on the card (it sits down
--          with 96 first)
--   happy  a click on the pet (on the Panda Cub, PetBattleCustom0 is a hop)
--   cheer  a bond level-up, during the celebration
--   dead   the day of the "is it safe to live with you?" egg, once
ns.PetMoves = {
    default = { sleep = 6, sit = 97, happy = 756, cheer = 754, dead = 1 },
    species = {
        [5160] = { happy = false },  -- Zergling: PetBattleCustom0 is an attack
        [5161] = { sleep = false },  -- Mini Diablo: Dead (6) makes him vanish (Death bursts into flames)
    },
}
