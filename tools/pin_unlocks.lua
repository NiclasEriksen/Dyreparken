-- Pins every species' minor like and minor dislike, and its third trait, in Data/Unlocks.lua (luajit
-- tools/pin_unlocks.lua, from the addon's folder).
--
-- The third trait (2026-11-19, the user): opened up by your bond at level 7. Picked for a species that has none
-- yet: one whose like is new to it (not liked, not its minor like, not disliked), that keeps it at 6 likes and 3
-- dislikes at most (all unlocked), never one against its two (Flokkdyr and Einstøing) or a loner among social ones;
-- from its families' fitting traits first (TRAIT_FIT, a sub-family before its broad one), else any, the least
-- picked so far. It's added to the line already here (the line's other values never change).
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

-- Traits that suit a family, for the third (in no order: picked by a hash among those that fit the rules).
local TRAIT_FIT = {
    cat = { "latsabb", "nattugle", "kjaelen", "roverdyr", "skoyer", "solelsker", "jeger" },
    bird = { "skybaren", "reiseglad", "pratsom", "oppdager", "friluftsdyr", "flokkdyr" },
    parrot = { "pratsom", "skoyer", "sjorover", "dansefot" },
    pirate = { "sjorover", "vannhund", "eventyrlysten" },
    owl = { "nattugle", "einstoing", "jeger", "skybaren" },
    chicken = { "glupsk", "hjemlengsel", "flokkdyr", "friluftsdyr" },
    farm = { "glupsk", "hjemlengsel", "flokkdyr", "friluftsdyr", "latsabb" },
    bug = { "huleboer", "glupsk", "steinhard", "roverdyr" },
    dragon = { "eventyrlysten", "ambisios", "sjorover", "skybaren", "balkos" },
    whelp = { "eventyrlysten", "hoppetass", "skoyer", "oppdager" },
    frog = { "hoppetass", "dykker", "dansefot", "vannhund" },
    mechanical = { "handverker", "ambisios", "rampete", "ordensdyr" },
    rodent = { "glupsk", "roverdyr", "gronnfinger", "oppdager", "steinhard" },
    rabbit = { "hoppetass", "gronnfinger", "kjaelen", "venneflokk" },
    snake = { "latsabb", "solelsker", "roverdyr", "huleboer", "einstoing" },
    wolf = { "jeger", "flokkdyr", "vinterpels", "eventyrlysten" },
    bear = { "kosete", "latsabb", "gronnfinger", "vannhund", "vinterpels" },
    demon = { "rampete", "roverdyr", "eventyrlysten", "balkos", "ambisios" },
    ooze = { "glupsk", "huleboer", "hoppetass", "dykker" },
    spirit = { "nattugle", "einstoing", "skybaren", "festglad" },
    plant = { "gronnfinger", "solelsker", "latsabb", "friluftsdyr" },
    reptile = { "solelsker", "dykker", "latsabb", "vannhund" },
    murloc = { "vannhund", "dykker", "pratsom", "venneflokk" },
    festive = { "festglad", "tivolidyr", "kosete", "dansefot", "helgedyr" },
}
local MAX_LIKES, MAX_DISLIKES = 6, 3

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

-- The third traits.
local ids = {}
for sid in pairs(pins) do ids[#ids + 1] = sid end
table.sort(ids)
local used, thirds = {}, 0
for _, sid in ipairs(ids) do if pins[sid][3] then used[pins[sid][3]] = (used[pins[sid][3]] or 0) + 1 end end
local function Social(t, tag) for _, x in ipairs(t.is or {}) do if x == tag then return true end end end
for _, sid in ipairs(ids) do
    local pin = pins[sid]
    if not pin[3] then
        local key = "s:" .. sid
        local two = P:Traits(key) -- (no third yet: level 0, and none pinned)
        local likes, likeList = P:Of(key)
        local ml, md = pin[1] or nil, pin[2] or nil
        if ml and likes[ml] then ml = nil end
        if md and (likes[md] or md == ml) then md = nil end
        local dis, disList = P:Dislikes(key) -- (the major ones)
        local disAll = {}
        for _, a in ipairs(disList) do disAll[a] = true end
        if md then disAll[md] = true end
        local nl = #likeList + (ml and 1 or 0)
        local nd = 0
        for _ in pairs(disAll) do nd = nd + 1 end
        local function Fits(t)
            if not t.like or likes[t.like] or t.like == ml or disAll[t.like] then return false end
            if nl + 1 > MAX_LIKES then return false end
            for _, o in ipairs(two) do
                if o.id == t.id or o.against == t.id or t.against == o.id then return false end
                if (Social(o, "social") and Social(t, "loner")) or (Social(o, "loner") and Social(t, "social")) then return false end
            end
            local d = t.dislike
            if d and not disAll[d] and not likes[d] and d ~= ml and d ~= t.like and nd + 1 > MAX_DISLIKES then return false end
            return true
        end
        -- Its families' fitting traits first (a sub-family before the broad one), else any.
        local lists, sub = {}, {}
        local data = ns.Companions.species[sid]
        for _, tag in ipairs(type(data) == "table" and data.t or {}) do
            local broad = ns.Scenes.ALIAS[tag]
            if broad and TRAIT_FIT[tag] then sub[broad] = sub[broad] or {}; table.insert(sub[broad], tag) end
        end
        for _, f in ipairs(ns.Scenes:Families(key)) do
            for _, tag in ipairs(sub[f] or {}) do lists[#lists + 1] = TRAIT_FIT[tag] end
            lists[#lists + 1] = TRAIT_FIT[f] or {}
        end
        local pick
        for _, list in ipairs(lists) do
            local fit = {}
            for _, id in ipairs(list) do if Fits(P.ById(id)) then fit[#fit + 1] = id end end
            if #fit > 0 then pick = fit[Hash(sid, 3) % #fit + 1]; break end
        end
        if not pick then -- (any trait that fits, the least picked so far)
            local best
            for _, t in ipairs(P.TRAITS) do
                if Fits(t) and (not best or (used[t.id] or 0) < (used[best] or 0)) then best = t.id end
            end
            pick = best
        end
        if pick then
            pin[3] = pick
            used[pick] = (used[pick] or 0) + 1
            thirds = thirds + 1
        else
            print(("no third trait fits %d %s"):format(sid, names[sid] or "?"))
        end
    end
end

local out = { [[---@class Dyreparken
local ns = select(2, ...)

-- Every species' minor like and minor dislike (Menagerie/Personality.lua: unlocked by your own bond with
-- the pet, the like at level 4, the dislike at level 6), pinned: a species keeps them for good (decided
-- 2026-11-12, like Data/Traits.lua). The third value: its third trait, opened up at level 7 (2026-11-19).
-- New species and missing third traits are added by tools/pin_unlocks.lua, which never changes a value
-- that's here. Edit a line by hand to change a species. false: none.
ns.UnlockPins = {]] }
for _, sid in ipairs(ids) do
    local p = pins[sid]
    local function Q(v) return v and ('"' .. v .. '"') or "false" end
    local third = p[3] and (", " .. Q(p[3])) or ""
    out[#out + 1] = ("    [%d] = { %s, %s%s }, -- %s"):format(sid, Q(p[1]), Q(p[2]), third, names[sid] or "?")
end
out[#out + 1] = "}\n"
local f = assert(io.open("Data/Unlocks.lua", "w"))
f:write(table.concat(out, "\n"))
f:close()
print(("Data/Unlocks.lua: %d species, %d added, %d third traits picked"):format(#ids, added, thirds))
