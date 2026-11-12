-- Pins every species' minor like and minor dislike in Data/Unlocks.lua (luajit tools/pin_unlocks.lua, from
-- the addon's folder).
--
-- The minor ones (2026-11-12, the user): a like your bond with the pet unlocks at level 4, a dislike at
-- level 6 (Menagerie/Personality.lua). Like the traits, a species keeps them for good: this keeps every
-- line already in Data/Unlocks.lua and only adds species that aren't pinned yet. To change one, edit its
-- line by hand.
--
-- A new species gets the first fitting activity from its own list (SPECIES), else its families' (FAMILY,
-- in the order Scenes reads them, a sub-family such as parrot before its bird), picked among those by a hash of its id, never one of its major likes
-- or dislikes, and the dislike never its minor like. The addon is booted in the test harness to read
-- each species' families and majors exactly as the game does.
package.path = "tools/test/?.lua;" .. package.path
local H = dofile("tools/test/harness.lua")

-- What suits a family: { likes }, { dislikes }. Only activities a pet can like (Activity.KINDS with a
-- source the bond watches); campfires as a dislike for those that burn or melt.
local FAMILY = {
    cat = { { "nap", "cuddle", "jump", "hearth", "sneak" }, { "taxi", "chat", "pvp", "boss" } },
    bird = { { "explore", "chat", "dance" }, { "mine", "dive", "nap" } },
    parrot = { { "chat", "dance", "explore", "fun" }, { "mine", "dive", "nap" } },
    pirate = { { "gold", "dive", "explore", "chat" }, { "hearth", "mine" } },
    owl = { { "explore", "nap", "quest" }, { "dance", "pvp" } },
    chicken = { { "herb", "nap", "hearth" }, { "pvp", "boss", "dive" } },
    farm = { { "herb", "nap", "hearth", "quest" }, { "pvp", "boss", "dive" } },
    bug = { { "mine", "skin", "explore" }, { "dive", "cuddle", "fish" } },
    dragon = { { "gold", "mine", "explore", "pvp" }, { "nap", "fish", "chat" } },
    whelp = { { "mine", "explore", "jump" }, { "nap", "fish" } },
    frog = { { "jump", "dance", "herb", "fun" }, { "mine", "boss" } },
    mechanical = { { "skill", "pvp", "explore" }, { "fish", "herb", "nap" } },
    rodent = { { "herb", "explore", "jump", "gold" }, { "boss", "dive", "pvp" } },
    rabbit = { { "jump", "nap", "explore", "meet" }, { "pvp", "taxi", "skin" } },
    snake = { { "nap", "dive", "explore", "sneak" }, { "dance", "chat", "cuddle", "fun" } },
    wolf = { { "skin", "explore", "pvp" }, { "hearth", "chat", "fish" } },
    bear = { { "nap", "cuddle", "explore", "meet" }, { "pvp", "taxi", "chat" } },
    demon = { { "pvp", "skin", "mine", "sneak" }, { "hearth", "dance", "chat", "meet" } },
    ooze = { { "dive", "fish", "mine" }, { "taxi", "dance", "hearth" } },
    spirit = { { "explore", "nap", "dance" }, { "pvp", "mine", "skin" } },
    plant = { { "fish", "nap", "explore" }, { "camp", "skin", "mine" } },
    reptile = { { "nap", "herb", "explore" }, { "chat", "dance", "jump" } },
    murloc = { { "chat", "explore", "quest", "meet" }, { "mine", "herb", "hearth" } },
    festive = { { "dance", "chat", "rested", "fun", "meet" }, { "pvp", "boss", "skin" } },
}
-- A species' own, first (by its story or nature).
local SPECIES = {
    [5159] = { { "nap" }, {} },               -- Panda Cub: bamboo is its like; a nap after
    [125] = { { "dive" }, {} },               -- Speedy: a turtle swims
    [85] = { { "mine" }, { "dive" } },        -- Tiny Walking Bomb: blasting; a wet fuse
    [90] = { { "camp" }, { "dive" } },        -- Smolderweb Hatchling: fire
    [117] = { { "rested" }, { "camp" } },     -- Tiny Snowman: melts by the fire
    [5201] = { {}, { "camp" } },              -- Frosty Lashling
    [128] = { { "camp" }, { "dive" } },       -- Spirit of Summer: the bonfires
    [118] = { { "rested" }, {} },             -- Winter Reindeer
    [126] = { { "herb" }, {} },               -- Mr. Wiggles: truffles
    [5005] = { { "chat" }, {} },              -- Musical Gustjumper: it sings
    [122] = { { "dance" }, {} },              -- Peddlefeet
    [5160] = { { "skin" }, {} },              -- Zergling
    [5094] = { { "dive" }, {} },              -- Bitter Baitling
    [127] = { { "mine" }, {} },               -- Whiskers the Rat
    [5179] = { { "fish" }, {} },              -- Azurky: a murloc
    [341] = { { "camp" }, { "dive" } },       -- Lunar Lantern: a light, and water puts it out
    [342] = { { "camp" }, { "dive" } },       -- Festival Lantern
}

local w = H.World()
local c = w:AddClient("Pin Unlocks", { pets = { 40 }, debug = false })
local ns = c.ns
local P = ns.Personality

local pins = {}
if io.open("Data/Unlocks.lua") then
    local chunk = assert(loadfile("Data/Unlocks.lua"))
    local old = {}
    chunk("Dyreparken", old)
    pins = old.UnlockPins or {}
end

local names = {}
for line in io.lines("Data/Companions.lua") do
    local sid, name = line:match("^%s*%[(%d+)%] = .*%-%- (.+)$")
    if sid then names[tonumber(sid)] = name end
end

local function Hash(sid, salt)
    local h = (sid * 2654435761 + salt * 40503) % 4294967296
    return h
end

local function Pick(sid, lists, avoid, salt)
    local fitting = {}
    for _, list in ipairs(lists) do
        for _, act in ipairs(list) do
            if not avoid[act] and ns.Activity.KIND[act] then fitting[#fitting + 1] = act end
        end
        if #fitting > 0 then break end -- (the first list with a fit: the species' own before its families')
    end
    if #fitting == 0 then return false end
    return fitting[Hash(sid, salt) % #fitting + 1]
end

local added = 0
for sid in pairs(ns.Companions.species) do
    if not pins[sid] then
        local key = "s:" .. sid
        local likes = P:Of(key)
        local dislikes = P:Dislikes(key)
        local avoid = {}
        for a in pairs(likes) do avoid[a] = true end
        for a in pairs(dislikes) do avoid[a] = true end
        local own = SPECIES[sid]
        local likeLists, dislikeLists = {}, {}
        if own then likeLists[1], dislikeLists[1] = own[1], own[2] end
        -- (each family's list in turn: its first family with a fit decides, an owl's before a bird's)
        -- A tag the addon folds into a broader family (Scenes.ALIAS: parrot -> bird, chicken -> farm,
        -- whelp -> dragon) has its own, more specific row here: it goes first, before the broad one's
        -- (the user, 2026-11-13: "making them real"; until then those rows never ran).
        local sub = {}
        local data = ns.Companions.species[sid]
        for _, tag in ipairs(type(data) == "table" and data.t or {}) do
            local broad = ns.Scenes.ALIAS[tag]
            if broad and FAMILY[tag] then sub[broad] = sub[broad] or {}; table.insert(sub[broad], tag) end
        end
        for _, f in ipairs(ns.Scenes:Families(key)) do
            for _, tag in ipairs(sub[f] or {}) do
                likeLists[#likeLists + 1] = FAMILY[tag][1] or {}
                dislikeLists[#dislikeLists + 1] = FAMILY[tag][2] or {}
            end
            likeLists[#likeLists + 1] = (FAMILY[f] or {})[1] or {}
            dislikeLists[#dislikeLists + 1] = (FAMILY[f] or {})[2] or {}
        end
        local like = Pick(sid, likeLists, avoid, 1)
        if like then avoid[like] = true end
        local dislike = Pick(sid, dislikeLists, avoid, 2)
        pins[sid] = { like, dislike }
        added = added + 1
    end
end

local ids = {}
for sid in pairs(pins) do ids[#ids + 1] = sid end
table.sort(ids)
local out = { [[local _, ns = ...

-- Every species' minor like and minor dislike (Menagerie/Personality.lua: unlocked by your own bond with
-- the pet, the like at level 4, the dislike at level 6), pinned: a species keeps them for good (decided
-- 2026-11-12, like Data/Traits.lua). New species are added by tools/pin_unlocks.lua, which never changes a
-- line that's here. Edit a line by hand to change a species. false: none.
ns.UnlockPins = {]] }
for _, sid in ipairs(ids) do
    local p = pins[sid]
    local function Q(v) return v and ('"' .. v .. '"') or "false" end
    out[#out + 1] = ("    [%d] = { %s, %s }, -- %s"):format(sid, Q(p[1]), Q(p[2]), names[sid] or "?")
end
out[#out + 1] = "}\n"
local f = assert(io.open("Data/Unlocks.lua", "w"))
f:write(table.concat(out, "\n"))
f:close()
print(("Data/Unlocks.lua: %d species, %d added"):format(#ids, added))
