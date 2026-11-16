---@class Dyreparken
local ns = select(2, ...)

-- A pet's own sound when you click it on its card (2026-11-16, the user: "click-reactions to trigger a random
-- sound suitable for that companion"; on the Sound Effects channel, a setting of its own, on by default:
-- Settings "petSounds"). EDITED BY HAND: by ear in game (/dp probe sound).
--
-- SETS: sound files by id, one played at random (the first that plays from a random place: ns.PlaySoundFiles).
-- Only files in Forever's own SoundKitEntry table (wago.tools, build 70938), so the client has them; names from
-- the community listfile (wowdev/wow-listfile). Files, not sound kits: a kit plays at its own volume, and some
-- of the friendliest (the frogs', the pet store's) are ambience kits at a tenth.
-- Classic critters only have fight sounds (aggro, attack, wound), so their calm "preaggro" is used, or a newer
-- pet's "clickable"/"greetings" set of the same kind of animal.
-- SPECIES: [species id] = a set's name, or false: quiet (the card's soft click instead). EVERY species in
-- Data/Companions.lua has a row (34_touches fails until a new one does: the user, 2026-11-16, "a bunch new ones
-- added over the next few months"): pick a set by ear, or make one from the listfile and Forever's SoundKitEntry
-- (tools/companions/README.md, "Adding a companion").
ns.PetSounds = {}

ns.PetSounds.SETS = {
    -- cat_greetings (7)
    cat = { 8533429, 8533431, 8533433, 8533435, 8533437, 8533439, 8533441 },
    -- parrotaggro, parrotpreaggro (2)
    parrot = { 558085, 558086 },
    -- silkiechicken_greetings (8)
    chicken = { 5852001, 5852003, 5852005, 5852007, 5852009, 5852011, 5852013, 5852015 },
    -- mdragonwhelpstandfidgeta, mdragonwhelpaggrob (2)
    whelp = { 547630, 547644 },
    -- mon_frog_clickable (10)
    frog = { 1068065, 1068066, 1068067, 1068068, 1068069, 1068070, 1068071, 1068072, 1068073, 1068074 },
    -- owlpreaggro, owlaggro (2)
    owl = { 557971, 557977 },
    -- pet_squirrel_clickable (10)
    squirrel = { 595196, 595199, 595202, 595205, 595208, 595211, 595214, 595217, 595220, 595223 },
    -- rat_greetings (7)
    rat = { 7498408, 7498410, 7498412, 7498414, 7498416, 7498418, 7498420 },
    -- rabbit2_greetings (6)
    rabbit = { 5563297, 5563299, 5563305, 5563307, 5563309, 5563311 },
    -- mon_snake_large_preaggro (3)
    snake = { 2032705, 2032706, 2032707 },
    -- larvapreaggro (1)
    larva = { 553631 },
    -- mon_mechanicalhandpet_clickables (10)
    robot = { 1970575, 1970576, 1970577, 1970578, 1970579, 1970580, 1970581, 1970582, 1970583, 1970584 },
    -- faeriedragonaggroa, faeriedragonpreaggroa (2)
    faerie = { 548556, 548560 },
    -- pet_draenorwolfpup_clickable (10)
    wolfpup = { 977113, 977115, 977117, 977119, 977121, 977123, 977125, 977127, 977129, 977131 },
    -- slime_fidget (4)
    slime = { 5770676, 5770678, 5770680, 5770682 },
    -- wendigopreaggroa (1)
    yeti = { 564115 },
    -- pet_littlefawn_clickable (8)
    fawn = { 554220, 554221, 554222, 554223, 554224, 554225, 554226, 554227 },
    -- gnomemalehello, cheer, laugh (7)
    gnome_m = { 540267, 540463, 540469, 540485, 540490, 540493, 540505 },
    -- gnomefemalehello, cheer, laugh (6)
    gnome_f = { 540268, 540421, 540428, 540434, 540436, 540445 },
    -- turtle_fidget (1)
    turtle = { 4699085 },
    -- emitter_dalaran_petstore_pig (8)
    pig = { 597713, 597716, 597722, 597779, 597839, 597845, 597857, 597929 },
    -- pet_sinistersquashling_clickable (10)
    squashling = { 560378, 560379, 560380, 560381, 560382, 560383, 560384, 560385, 560386, 560387 },
    -- pet_magiclamp_clickable (10)
    lantern = { 554540, 554541, 554542, 554543, 554544, 554545, 554546, 554547, 554548, 554549 },
    -- mtigerstand2a, mon_siberiantiger_preaggro (6)
    tiger = { 562388, 609566, 609568, 609570, 609572, 609574 },
    -- diablofunsized (3)
    diablo = { 547214, 547215, 547216 },
    -- pet_guardiancub_clickable (2)
    bearcub = { 551365, 551372 },
    -- crabpreaggro (1)
    crab = { 546432 },
    -- mon_sandpiper_standidle (3)
    sandpiper = { 1489129, 1489130, 1489131 },
    -- mbasiliskstand2a, 3a (2)
    crocolisk = { 544935, 544948 },
    -- wispyes, wispready, wispwhat (7)
    wisp = { 567286, 567288, 567289, 567290, 567291, 567292, 567293 },
    -- tallstriderpreaggroa (1)
    tallstrider = { 561393 },
    -- minfernalaggroa (1)
    minfernal = { 552542 },
    -- babymurloc_clickable (7)
    murloc = { 657586, 657588, 657590, 657592, 657594, 657596, 657598 },
    -- pet_ammenvalelashling_clickable (10)
    lashling = { 543660, 543661, 543662, 543663, 543664, 543665, 543666, 543667, 543668, 543669 },
    -- petpandacubgreeting (4)
    panda = { 558048, 558049, 558050, 558051 },
    -- zerglingpet (4)
    zergling = { 565102, 565103, 565104, 565105 },
    snow = { 1025155, 1025156, 1025157, 1025158, 1025159, 1025160, 1025161, 1025162, 1025163, 1025164, 1025165, 1025166,
        1025167, 1025168, 1025169, 1025170, 1025171, 1025172, 1025173, 1025174 }, -- mon_footstep_bipedal_foot_small_snow (the user: the snowman)
}

ns.PetSounds.SPECIES = {
    [39] = "squirrel",     -- Mechanical Squirrel
    [40] = "cat", [41] = "cat", [42] = "cat", [43] = "cat", [44] = "cat", [45] = "cat", [46] = "cat", -- the cats
    [5006] = "cat",        -- Corrupted Kitten
    [47] = "parrot", [49] = "parrot", [50] = "parrot", [51] = "parrot", -- Cockatiel, the macaws, Senegal
    [52] = "chicken",      -- Ancona Chicken
    [83] = "chicken",      -- Mechanical Chicken
    [5004] = "chicken",    -- Prairie Chicken
    [5069] = "chicken",    -- Wild Chicken
    [56] = "whelp", [57] = "whelp", [58] = "whelp", [59] = "whelp", [1563] = "whelp", -- the whelplings
    [64] = "frog", [65] = "frog", [95] = "frog", [106] = "frog", [5005] = "frog", -- Wood, Tree Frog, Lifelike Toad, Jubling, Musical Gustjumper
    [67] = "owl", [68] = "owl", [5158] = "owl", -- Hawk, Great Horned, Eagle Owl
    [70] = "squirrel",     -- Brown Prairie Dog
    [5135] = "squirrel",   -- Shadowgale Squirrel
    [5154] = "squirrel", [5155] = "squirrel", -- the ground squirrels
    [127] = "rat",         -- Whiskers the Rat
    [72] = "rabbit", [4180] = "rabbit", [5157] = "rabbit", -- Snowshoe Rabbit, Arctic Hare, Brown Rabbit
    [74] = "snake", [75] = "snake", [77] = "snake", [78] = "snake", [5153] = "snake", -- the snakes, Jungle Boa
    [5094] = "larva",      -- Bitter Baitling
    [5183] = "larva",      -- Spawn of Grubthor
    [85] = "robot",        -- Tiny Walking Bomb
    [87] = "faerie",       -- Sprite Darter Hatchling
    [89] = "wolfpup", [5018] = "wolfpup", [5121] = "wolfpup", -- Worg, Snowy Wolf, Prairie Wolf Pup
    [114] = "slime",       -- Disgusting Oozeling
    [5075] = "slime",      -- Excitable Slime
    [116] = "yeti",        -- Tranquil Mechanical Yeti
    [117] = "snow",        -- Tiny Snowman
    [118] = "fawn",        -- Winter Reindeer
    [119] = "gnome_m",     -- Father Winter's Helper
    [120] = "gnome_f",     -- Winter's Little Helper
    [125] = "turtle",      -- Speedy
    [126] = "pig",         -- Mr. Wiggles
    [162] = "squashling",  -- Sinister Squashling
    [341] = "lantern", [342] = "lantern", -- Lunar, Festival Lantern
    [1927] = "tiger",      -- White Tiger Cub
    [5008] = "diablo", [5161] = "diablo", -- Mini Uber Diablo, Mini Diablo
    [5122] = "bearcub",    -- Spectral Bear Cub
    [5136] = "crab",       -- Weevil K. Neevil (its own creature's sounds are a crab's)
    [5139] = "sandpiper",  -- Galestrider Chick (its own)
    [5162] = "crocolisk",  -- Baby Crocolisk (its own)
    [5163] = "wisp",       -- Shen'dorei Wisp
    [5172] = "tallstrider", -- Tallstrider Hatchling
    [5174] = "minfernal",  -- Minfernal
    [5179] = "murloc",     -- Azurky
    [5200] = "lashling", [5201] = "lashling", [5202] = "lashling", [5203] = "lashling", -- the Lashlings
    [5159] = "panda",      -- Panda Cub
    [5160] = "zergling",   -- Zergling
    -- Quiet for now (nothing fitting found yet): the card's soft click.
    [55] = false, [5151] = false, [5152] = false, -- the Cockroaches
    [90] = false,          -- Smolderweb Hatchling
    [122] = false,         -- Peddlefeet
    [128] = false,         -- Spirit of Summer
    [5138] = false,        -- Pachimari
    [5167] = false,        -- Condor Hatchling
    [5176] = false,        -- Minimule
}
