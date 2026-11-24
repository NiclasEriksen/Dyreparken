---@class Dyreparken
local ns = select(2, ...)

-- Zones and what they are to our pets, one row each (2026-11-14, round 2: docs/ROUND2.md 3.3; they were six
-- lists in five files, a capital's faction in two). EDITED BY HAND. Names are GetZoneText's (enUS, the classic
-- world's: Forever is the classic world, the user 2026-11-10); a name that never comes only means no moment.
-- Zephras Isle and Mount Hyjal are Forever's own (from its news): their level, faction and name unverified.
--
--   level    the lowest level that goes there (classic's ranges): a wish can be a trip there (Wish)
--   faction  whose own land it is: the other faction's never comes up as a trip; a capital's is its faction's
--   capital  a faction's capital: Ordensdyr's cities (Personality), home or enemy ground (Sense's zone)
--   climate  "cold" (Vinterpels) or "warm" (Solelsker)
--   high     high up (Skybåren)
--   neutral  a goblin town (a subzone), neutral ground (Sense)
--   home     the families that feel at home there (Quirks' eggs, a trip for Wish)
-- Instances and battlegrounds have no level: never a trip.
ns.Zones = { rows = {
    ["Darnassus"] = { level = 1, faction = "Alliance", capital = true, high = true, home = { "owl" } },
    ["Dun Morogh"] = { level = 1, faction = "Alliance", climate = "cold", home = { "mechanical", "rabbit" } },
    ["Durotar"] = { level = 1, faction = "Horde", climate = "warm" },
    ["Elwynn Forest"] = { level = 1, faction = "Alliance", home = { "rabbit", "festive", "farm" } },
    ["Ironforge"] = { level = 1, faction = "Alliance", capital = true, climate = "cold", home = { "mechanical", "festive" } },
    ["Mulgore"] = { level = 1, faction = "Horde", home = { "rabbit", "rodent", "festive", "farm" } },
    ["Orgrimmar"] = { level = 1, faction = "Horde", capital = true, climate = "warm", home = { "festive" } },
    ["Stormwind City"] = { level = 1, faction = "Alliance", capital = true, home = { "rodent" } },
    ["Teldrassil"] = { level = 1, faction = "Alliance", high = true, home = { "owl", "cat" } },
    ["Thunder Bluff"] = { level = 1, faction = "Horde", capital = true, high = true },
    ["Tirisfal Glades"] = { level = 1, faction = "Horde", home = { "farm" } },
    ["Undercity"] = { level = 1, faction = "Horde", capital = true, home = { "rodent", "bug" } },
    ["Zephras Isle"] = { high = true }, -- (no level: never a trip until its name is seen in game; the user, 2026-11-14)
    ["Darkshore"] = { level = 10, faction = "Alliance", home = { "murloc" } },
    ["Silverpine Forest"] = { level = 10, faction = "Horde", home = { "wolf" } },
    ["The Barrens"] = { level = 10, faction = "Horde", climate = "warm", home = { "rodent", "snake", "pirate" } },
    ["Westfall"] = { level = 10, faction = "Alliance", home = { "farm", "murloc" } },
    ["Loch Modan"] = { level = 10, faction = "Alliance", home = { "bear" } },
    ["Redridge Mountains"] = { level = 15, faction = "Alliance", home = { "murloc" } },
    ["Stonetalon Mountains"] = { level = 15, high = true, home = { "bird" } },
    ["Ashenvale"] = { level = 18, home = { "bear", "plant" } },
    ["Duskwood"] = { level = 18, faction = "Alliance", home = { "spirit", "wolf" } },
    ["Wetlands"] = { level = 20, home = { "dragon", "murloc" } },
    ["Hillsbrad Foothills"] = { level = 20, home = { "farm", "cat", "rabbit" } },
    ["Thousand Needles"] = { level = 25, climate = "warm", home = { "mechanical" } },
    ["Alterac Mountains"] = { level = 30, climate = "cold", home = { "wolf" } },
    ["Arathi Highlands"] = { level = 30, home = { "reptile" } },
    -- Forever's own (its name seen in game, 2026-11-21), entered from Alterac Mountains: its level as Alterac's,
    -- unverified. The mages' city, neutral ground; not a capital (that needs a faction: Ordensdyr's cities).
    ["Dalaran"] = { level = 30, neutral = true, home = { "owl" } },
    ["Desolace"] = { level = 30, climate = "warm", home = { "demon" } },
    -- Forever's own (2026-11-20, the user; its name seen in game): Desolace's mountains, druids and a moon temple,
    -- more arcane than the rest; 30-40 but very late Desolace with quests of 40 and more at times (so 38), no
    -- faction's, Desolace's climate. Home to the moon's families, as Moonglade.
    ["Shen'dralas"] = { level = 38, climate = "warm", high = true, home = { "owl", "spirit" } },
    ["Stranglethorn Vale"] = { level = 30, climate = "warm", home = { "pirate", "snake", "cat" } },
    ["Badlands"] = { level = 35, climate = "warm", home = { "dragon" } },
    ["Dustwallow Marsh"] = { level = 35, home = { "reptile", "ooze" } },
    ["Swamp of Sorrows"] = { level = 35, home = { "frog", "reptile" } },
    -- Forever's own (its name seen in game), by boat from Steamwheedle Port: a river country, level 35 (the
    -- user, 2026-11-22).
    ["Riverglades"] = { level = 35, climate = "warm", home = { "frog", "murloc" } },
    ["Feralas"] = { level = 40, home = { "bear", "plant" } },
    ["Tanaris"] = { level = 40, climate = "warm", home = { "pirate", "snake" } },
    ["The Hinterlands"] = { level = 40, high = true, home = { "bird" } },
    ["Searing Gorge"] = { level = 43, climate = "warm", home = { "mechanical" } },
    ["Blasted Lands"] = { level = 45, home = { "demon" } },
    ["Azshara"] = { level = 45, home = { "murloc" } },
    ["Felwood"] = { level = 48, home = { "demon", "ooze" } },
    ["Moonglade"] = { level = 48, home = { "owl", "spirit" } },
    ["Un'Goro Crater"] = { level = 48, climate = "warm", home = { "plant", "ooze", "bug" } },
    ["Burning Steppes"] = { level = 50, climate = "warm", home = { "dragon" } },
    ["Western Plaguelands"] = { level = 51, home = { "ooze" } },
    ["Eastern Plaguelands"] = { level = 53, home = { "spirit" } },
    ["Silithus"] = { level = 55, climate = "warm", home = { "bug" } },
    ["Deadwind Pass"] = { level = 55, high = true, home = { "spirit" } },
    ["Winterspring"] = { level = 55, climate = "cold", home = { "cat" } },
    ["Ahn'Qiraj"] = { home = { "bug" } },
    ["Alterac Valley"] = { climate = "cold", home = { "wolf" } },
    ["Blackrock Depths"] = { home = { "ooze" } },
    ["Blackwing Lair"] = { home = { "dragon" } },
    ["Booty Bay"] = { neutral = true },
    ["Everlook"] = { neutral = true },
    ["Gadgetzan"] = { neutral = true },
    ["Gnomeregan"] = { home = { "mechanical" } },
    ["Mount Hyjal"] = { high = true },
    ["Naxxramas"] = { home = { "ooze" } },
    ["Onyxia's Lair"] = { home = { "dragon" } },
    ["Ratchet"] = { neutral = true },
    ["Powderfuse Port"] = { neutral = true }, -- (Riverglades' goblin port; its name as GetSubZoneText gives it, the user 2026-11-22)
    ["Ruins of Ahn'Qiraj"] = { home = { "bug" } },
    ["Steamwheedle Port"] = { neutral = true },
    ["The Temple of Atal'Hakkar"] = { home = { "reptile" } },
    ["Wailing Caverns"] = { home = { "frog", "snake" } },
} }
local Zones = ns.Zones

-- The zones whose field is this value (true: any): a set, name -> true.
function Zones.Where(field, value)
    local out = {}
    for name, r in pairs(Zones.rows) do
        if r[field] ~= nil and (value == true or r[field] == value) then out[name] = true end
    end
    return out
end

-- family -> its home zones (sorted names).
function Zones.Homes()
    local out = {}
    for name, r in pairs(Zones.rows) do
        for _, f in ipairs(r.home or {}) do out[f] = out[f] or {}; table.insert(out[f], name) end
    end
    for _, list in pairs(out) do table.sort(list) end
    return out
end
