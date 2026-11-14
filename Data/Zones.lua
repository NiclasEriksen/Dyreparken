local _, ns = ...

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
    ["Dun Morogh"] = { level = 1, faction = "Alliance", climate = "cold" },
    ["Durotar"] = { level = 1, faction = "Horde", climate = "warm" },
    ["Elwynn Forest"] = { level = 1, faction = "Alliance", home = { "rabbit" } },
    ["Ironforge"] = { level = 1, faction = "Alliance", capital = true, climate = "cold", home = { "mechanical" } },
    ["Mulgore"] = { level = 1, faction = "Horde", home = { "rabbit" } },
    ["Orgrimmar"] = { level = 1, faction = "Horde", capital = true, climate = "warm" },
    ["Stormwind City"] = { level = 1, faction = "Alliance", capital = true },
    ["Teldrassil"] = { level = 1, faction = "Alliance", high = true, home = { "owl" } },
    ["Thunder Bluff"] = { level = 1, faction = "Horde", capital = true, high = true },
    ["Tirisfal Glades"] = { level = 1, faction = "Horde" },
    ["Undercity"] = { level = 1, faction = "Horde", capital = true },
    ["Zephras Isle"] = { level = 1, high = true },
    ["Darkshore"] = { level = 10, faction = "Alliance", home = { "murloc" } },
    ["Silverpine Forest"] = { level = 10, faction = "Horde", home = { "wolf" } },
    ["The Barrens"] = { level = 10, faction = "Horde", climate = "warm" },
    ["Westfall"] = { level = 10, faction = "Alliance", home = { "farm", "murloc" } },
    ["Ashenvale"] = { level = 18, home = { "bear" } },
    ["Wetlands"] = { level = 20, home = { "dragon", "murloc" } },
    ["Thousand Needles"] = { level = 25, climate = "warm" },
    ["Alterac Mountains"] = { level = 30, climate = "cold", home = { "wolf" } },
    ["Desolace"] = { level = 30, climate = "warm", home = { "demon" } },
    ["Stranglethorn Vale"] = { level = 30, climate = "warm", home = { "pirate" } },
    ["Badlands"] = { level = 35, climate = "warm" },
    ["Dustwallow Marsh"] = { level = 35, home = { "reptile" } },
    ["Swamp of Sorrows"] = { level = 35, home = { "frog", "reptile" } },
    ["Feralas"] = { level = 40, home = { "bear", "plant" } },
    ["Tanaris"] = { level = 40, climate = "warm", home = { "pirate", "snake" } },
    ["Searing Gorge"] = { level = 43, climate = "warm" },
    ["Blasted Lands"] = { level = 45, home = { "demon" } },
    ["Felwood"] = { level = 48, home = { "demon" } },
    ["Moonglade"] = { level = 48, home = { "owl", "spirit" } },
    ["Un'Goro Crater"] = { level = 48, climate = "warm", home = { "plant" } },
    ["Burning Steppes"] = { level = 50, climate = "warm", home = { "dragon" } },
    ["Eastern Plaguelands"] = { level = 53, home = { "spirit" } },
    ["Silithus"] = { level = 55, climate = "warm", home = { "bug" } },
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
