---@class Dyreparken
local ns = select(2, ...)

-- Achievement definitions: what it takes, not what it's called (Locale/nb.lua, ns.AchTexts).
-- The order here is the order on the page and in lists.
--
-- IDS ARE PERMANENT: saved progress and sync key on them. Rename freely in
-- Locale/nb.lua (ns.AchTexts); never change an id here.
--
-- Kinds (see Achievements.lua for how each is evaluated):
--   count   n         own n pets that count toward achievements (hidden if
--                     fewer than n exist)
--   all               own every pet that counts
--   family  tag       own every counting pet with this tag (skipped while the
--                     tag has no counting pets)
--   bond    level     reach this bond level with your companion (Menagerie/Bond.lua) (char).
--                     Ids loyal:N are from when it counted days; ids are permanent.
--   nick              have given your companion a nickname          (char)
--   dislikes          have found out everything your companion dislikes (Quirks.lua), and its minor like
--                     and dislike (Personality: bond levels 4 and 6; since 2026-11-12, char migration 2) (char)
--   eggs      n       have found n different easter eggs (Quirks.lua, char.eggs)        (char)
--   wishstreak n      today's wish come true n days in a row (Wish.lua, char.wishes.best) (char)
--   wishes    n       n wishes come true in all, a day each (char.wishes.n)            (char)
--   herd   level n    your own bonds at level `level` or more with n different pets, adopted or not (char)
--   wholefamily level every counting pet of one family (one with FAMILY_MIN or more) at that level with you (char)
--   firsts    n       n different bosses seen fall for the first time with a pet, all your pets together (char.firsts)
--   playfriends n     playdates with n different guildmates (char.playmates)                        (char)
--   patsgiven n       a pat (/dp klapp) for n different guildmates' pets (char.patsGiven)            (char)
--   wishkinds n       wishes of n different kinds come true (char.wishes.kinds)                      (char)
--   cuddledays n      the card's cuddle for the pet out on n days (char.cuddleDays; not the /cuddle emote)  (char)
--   turnusvakt n      n days in a row, each with a day's visit from a pet not yet out that run (char.turnusvakt)
--   activity act n    n of an activity (Core/Activity.lua: "boss", "quest", ...); pet = true counts
--                     only with your adopted companion out. Hidden while the client can't produce it.
--                                                                    (char)
--   guildcount  n     the guild cares for n counting pets at once  (guild)
--   guildall          the guild cares for every counting pet       (guild)
--   guildfamily tag   the guild cares for every counting pet with this tag
--                     (one pet per member, so each by a different member)
--
-- secret = true: not on the page, in /dp prestasjoner or the count until it's earned (a surprise).
--
-- scope: "account" (default; the collection is account-wide on Forever),
-- "char" (adoption is per character), or "guild" (shared, synced; ids start
-- with "guild:", which the sync relies on).
--
-- Decided 2026-11-06: nothing rewards adopting often (no "adopted N pets").
-- icon: one candidate or a list, best first. A candidate is an icon name
-- (under Interface\Icons\), a full path, or a file id (a number, from an
-- icon database). The client shows the first one it has (Ach:Icon), so a
-- wrong guess never shows as a blank. Names are guesses at Forever's icons until seen in game.
local CARRIER = "INV_Box_PetCarrier_01"
ns.AchDefs = {
    { id = "count:10", kind = "count", n = 10, cat = "collection", icon = { "INV_Box_Birdcage_01", "INV_Misc_PetBiscuit_01", CARRIER } },
    { id = "count:25", kind = "count", n = 25, cat = "collection", icon = { "Ability_Hunter_BeastTaming", CARRIER } },
    { id = "count:50", kind = "count", n = 50, cat = "collection", icon = { "Ability_Hunter_BeastCall", CARRIER } },
    { id = "count:all", kind = "all", cat = "collection", icon = { "Ability_Hunter_BeastMastery", "Ability_Mount_WhiteTiger" } },

    { id = "family:cat", kind = "family", tag = "cat", cat = "family", icon = { "INV_Pet_Cats_CalicoCat", "Ability_Druid_CatForm" } },
    { id = "family:farm", kind = "family", tag = "farm", cat = "family", icon = "Spell_Magic_PolymorphChicken" },
    { id = "family:owl", kind = "family", tag = "owl", cat = "family", icon = "Ability_Hunter_Pet_Owl" },
    { id = "family:rabbit", kind = "family", tag = "rabbit", cat = "family", icon = { "Spell_Magic_PolymorphRabbit", CARRIER } },
    { id = "family:snake", kind = "family", tag = "snake", cat = "family", icon = { "Ability_Hunter_CobraShot", "Ability_Hunter_SerpentSwiftness", "Ability_Hunter_Quickshot", "Ability_Hunter_Pet_WindSerpent" } },
    { id = "family:frog", kind = "family", tag = "frog", cat = "family", icon = { "Spell_Shaman_Hex", CARRIER } },
    { id = "family:mechanical", kind = "family", tag = "mechanical", cat = "family", icon = { "INV_Misc_Gear_01", "Trade_Engineering" } },
    { id = "family:dragon", kind = "family", tag = "dragon", cat = "family", icon = "INV_Misc_Head_Dragon_01" },
    { id = "family:bird", kind = "family", tag = "bird", cat = "family", icon = "Spell_Nature_RavenForm" },
    { id = "family:pirate", kind = "family", tag = "pirate", cat = "family", icon = { "INV_Helmet_66", "INV_Misc_Bandana_03", CARRIER } },
    -- (the other families with FAMILY_MIN or more counting pets: from the data, below)

    { id = "loyal:30", kind = "bond", level = 3, scope = "char", cat = "loyalty", icon = { "INV_ValentinesCandy", "Spell_Holy_SealOfSacrifice" } },
    { id = "loyal:100", kind = "bond", level = 4, scope = "char", cat = "loyalty", icon = { "INV_ValentinesCard02", "Spell_Holy_SealOfSacrifice" } },
    { id = "loyal:365", kind = "bond", level = 6, scope = "char", cat = "loyalty", icon = { "Achievement_WorldEvent_Valentine", "Spell_Holy_SealOfSacrifice" } },
    -- (2026-11-22, 0.10.0, the content review §2.5: Bestevenn and the summit, Sjelevenn; after Uatskillelig on the page)
    { id = "bond:5", kind = "bond", level = 5, scope = "char", cat = "loyalty", icon = { "INV_ValentinesCard01", "Spell_Holy_SealOfSacrifice" } },
    { id = "bond:7", kind = "bond", level = 7, scope = "char", cat = "loyalty", icon = { "INV_Jewelry_Necklace_27", "Spell_Holy_PrayerOfSpirit", "Spell_Holy_SealOfSacrifice" } },
    { id = "nick", kind = "nick", scope = "char", cat = "loyalty", icon = { "INV_Inscription_Parchment", "INV_Misc_Note_01" } },
    { id = "dislikes", kind = "dislikes", scope = "char", cat = "loyalty", icon = { "Spell_Misc_EmotionSad", "INV_Misc_Book_09", "INV_Misc_Note_01" } },
    -- Together (2026-11-10): with your adopted pet out (numbers set by the user: a dungeon has many bosses).
    { id = "boss:50", kind = "activity", act = "boss", n = 50, pet = true, scope = "char", cat = "together", icon = { "Achievement_Boss_Onyxia", "INV_Misc_Bone_HumanSkull_01" } },
    { id = "boss:250", kind = "activity", act = "boss", n = 250, pet = true, scope = "char", cat = "together", icon = { "Achievement_Boss_Ragnaros", "INV_Misc_Head_Dragon_Black" } },
    { id = "boss:1000", kind = "activity", act = "boss", n = 1000, pet = true, scope = "char", cat = "together", icon = { "Achievement_Boss_KelThuzad_01", "INV_Misc_Head_Dragon_Bronze" } },
    { id = "pvp:50", kind = "activity", act = "pvp", n = 50, pet = true, scope = "char", cat = "together", icon = { "Ability_DualWield", "INV_Sword_04" } },
    { id = "pvp:250", kind = "activity", act = "pvp", n = 250, pet = true, scope = "char", cat = "together", icon = { "Ability_Warrior_BattleShout", "INV_Sword_27" } },
    { id = "pvp:1000", kind = "activity", act = "pvp", n = 1000, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Bandana_03", "Ability_Warrior_WarCry" } },
    { id = "quest:100", kind = "activity", act = "quest", n = 100, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Book_09", "INV_Scroll_03" } },
    { id = "quest:500", kind = "activity", act = "quest", n = 500, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Book_11", "INV_Scroll_03" } },
    { id = "quest:1000", kind = "activity", act = "quest", n = 1000, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Book_07", "INV_Scroll_03" } },
    -- (2026-11-19, the user: ten thousand jumps, "once (hidden achievement?)"; one "jump" is ten)
    { id = "jump:10000", kind = "activity", act = "jump", n = 1000, pet = true, scope = "char", cat = "together", secret = true,
        icon = { "Ability_Rogue_Sprint", "Spell_Nature_FeatherFall" } },
    { id = "eggs:10", kind = "eggs", n = 10, scope = "char", cat = "loyalty", icon = { "INV_Egg_03", "INV_Egg_01", "INV_Misc_Food_57" } },
    { id = "eggs:25", kind = "eggs", n = 25, scope = "char", cat = "loyalty", icon = { "INV_Egg_04", "INV_Egg_03", "INV_Misc_Food_57" } },
    { id = "wish:7", kind = "wishstreak", n = 7, scope = "char", cat = "loyalty", icon = { "INV_Misc_Coin_02", "INV_Misc_Coin_01" } },
    { id = "wish:30", kind = "wishstreak", n = 30, scope = "char", cat = "loyalty", icon = { "INV_Misc_Coin_04", "INV_Misc_Coin_03" } },
    { id = "wish:100", kind = "wishes", n = 100, scope = "char", cat = "loyalty", icon = { "INV_Misc_Coin_17", "INV_Misc_Coin_06", "INV_Misc_Coin_01" } },
    -- More together (2026-11-22, 0.10.0, the content review §2.5): with any of your pets out.
    { id = "wishkinds:10", kind = "wishkinds", n = 10, scope = "char", cat = "together", icon = { "INV_Misc_Coin_05", "INV_Misc_Coin_02" } },
    { id = "playdate:10", kind = "activity", act = "playmate", n = 10, scope = "char", cat = "together", icon = { "INV_Misc_Toy_10", "INV_Misc_Toy_07", CARRIER } },
    { id = "playdate:50", kind = "activity", act = "playmate", n = 50, scope = "char", cat = "together", icon = { "INV_Misc_Toy_07", "INV_Misc_Toy_10", CARRIER } },
    { id = "playfriends:5", kind = "playfriends", n = 5, scope = "char", cat = "together", icon = { "Achievement_GuildPerk_EverybodysFriend", "INV_Misc_Toy_10" } },
    { id = "pats:10", kind = "patsgiven", n = 10, scope = "char", cat = "together", icon = { "Spell_Holy_LayOnHands", "INV_Misc_Bandage_15" } },
    { id = "patted:50", kind = "activity", act = "patted", n = 50, scope = "char", cat = "together", icon = { "Spell_Holy_BlessingOfProtection", "Spell_Holy_LayOnHands" } },
    { id = "cuddle:30", kind = "cuddledays", n = 30, scope = "char", cat = "together", icon = { "INV_ValentinesCandy", "Spell_Holy_LayOnHands" } },
    { id = "places:50", kind = "activity", act = "explore", n = 50, scope = "char", cat = "together", icon = { "INV_Misc_Map_01", "INV_Misc_Map02" } },
    { id = "firsts:25", kind = "firsts", n = 25, scope = "char", cat = "together", icon = { "INV_Misc_Head_Dragon_01", "Achievement_Boss_Onyxia" } },
    -- Many pets (2026-11-22, 0.10.0, the content review §4.4): bonds with several of your pets, adopted or not.
    { id = "herd:3:5", kind = "herd", level = 3, n = 5, scope = "char", cat = "herd", icon = { "Ability_Hunter_BeastCall", CARRIER } },
    { id = "herd:3:15", kind = "herd", level = 3, n = 15, scope = "char", cat = "herd", icon = { "Ability_Hunter_BeastMastery", CARRIER } },
    { id = "herd:3:30", kind = "herd", level = 3, n = 30, scope = "char", cat = "herd", icon = { "Ability_Hunter_BeastTaming", CARRIER } },
    { id = "herd:5:3", kind = "herd", level = 5, n = 3, scope = "char", cat = "herd", icon = { "INV_ValentinesCard02", "Spell_Holy_SealOfSacrifice" } },
    { id = "herd:7:3", kind = "herd", level = 7, n = 3, scope = "char", cat = "herd", icon = { "Spell_Holy_PrayerOfSpirit", "Spell_Holy_SealOfSacrifice" } },
    { id = "wholefamily:2", kind = "wholefamily", level = 2, scope = "char", cat = "herd", icon = { "Ability_Hunter_BeastSoothe", CARRIER } },
    { id = "turnusvakt:7", kind = "turnusvakt", n = 7, scope = "char", cat = "herd", icon = { "INV_Misc_PocketWatch_01", "Spell_Holy_BorrowedTime" } },

    { id = "guild:count:10", kind = "guildcount", n = 10, scope = "guild", cat = "guild",
        icon = { "Achievement_GuildPerk_EverybodysFriend", CARRIER } },
    { id = "guild:count:25", kind = "guildcount", n = 25, scope = "guild", cat = "guild",
        icon = { "Achievement_GuildPerk_MrPopularity", CARRIER } },
    { id = "guild:count:50", kind = "guildcount", n = 50, scope = "guild", cat = "guild",
        icon = { "Achievement_GuildPerk_MrPopularity_Rank2", CARRIER } },
    { id = "guild:all", kind = "guildall", scope = "guild", cat = "guild",
        icon = { "Achievement_GuildPerk_MassResurrection", "Ability_Mount_WhiteTiger" } },
    { id = "guild:family:cat", kind = "guildfamily", tag = "cat", scope = "guild", cat = "guild",
        icon = { "INV_Pet_Cats_SilverTabbyCat", "Ability_Druid_CatForm" } },
    -- Every family (2026-11-11, the user: "guild-specific achievements for those would be fun").
    { id = "guild:family:farm", kind = "guildfamily", tag = "farm", scope = "guild", cat = "guild", icon = "Spell_Magic_PolymorphChicken" },
    { id = "guild:family:owl", kind = "guildfamily", tag = "owl", scope = "guild", cat = "guild", icon = "Ability_Hunter_Pet_Owl" },
    { id = "guild:family:rabbit", kind = "guildfamily", tag = "rabbit", scope = "guild", cat = "guild", icon = { "Spell_Magic_PolymorphRabbit", CARRIER } },
    { id = "guild:family:snake", kind = "guildfamily", tag = "snake", scope = "guild", cat = "guild", icon = { "Ability_Hunter_CobraShot", "Ability_Hunter_SerpentSwiftness", "Ability_Hunter_Quickshot", "Ability_Hunter_Pet_WindSerpent" } },
    { id = "guild:family:frog", kind = "guildfamily", tag = "frog", scope = "guild", cat = "guild", icon = { "Spell_Shaman_Hex", CARRIER } },
    { id = "guild:family:mechanical", kind = "guildfamily", tag = "mechanical", scope = "guild", cat = "guild", icon = { "INV_Misc_Gear_01", "Trade_Engineering" } },
    { id = "guild:family:dragon", kind = "guildfamily", tag = "dragon", scope = "guild", cat = "guild", icon = "INV_Misc_Head_Dragon_01" },
    { id = "guild:family:bird", kind = "guildfamily", tag = "bird", scope = "guild", cat = "guild", icon = "Spell_Nature_RavenForm" },
    { id = "guild:family:pirate", kind = "guildfamily", tag = "pirate", scope = "guild", cat = "guild", icon = { "INV_Helmet_66", "INV_Misc_Bandana_03", CARRIER } },
}

-- A family's "have them all" from the data (2026-11-22, 0.10.0, the user: families grow, "keep in mind once a new
-- family / existing family becomes 3+ large later"): every family in Scenes.ORDER with FAMILY_MIN or more pets that
-- count, and no achievement written above, gets one, after the written ones. Ids family:<tag>, permanent like all;
-- its texts in Locale's ns.AchTexts (49_content fails until they're there).
ns.AchFamily = { MIN = 3, ICONS = {
    rodent = { "INV_Misc_Food_03", "Ability_Hunter_Pet_Rat" }, wolf = { "Ability_Mount_WhiteDireWolf", "Ability_Hunter_Pet_Wolf" },
    bug = { "INV_Misc_AhnQirajTrinket_01", "Ability_Hunter_Pet_Scorpid" }, festive = { "INV_Holiday_Christmas_Present_01", "INV_Misc_Gift_01" },
    plant = { "INV_Misc_Herb_03", "INV_Misc_Flower_01" }, reptile = { "Ability_Hunter_Pet_Crocolisk", "INV_Misc_MonsterScales_15" },
    demon = { "Spell_Shadow_SummonImp", "Spell_Shadow_SummonFelHunter" }, spirit = { "Spell_Nature_SpiritWolf", "Spell_Holy_SpiritHeal" },
    ooze = { "INV_Misc_Slime_01", "Spell_Nature_Acid_01" }, bear = { "Ability_Racial_BearForm", "Ability_Hunter_Pet_Bear" },
    murloc = { "INV_Misc_Head_Murloc_01", CARRIER },
} }
function ns.AchFamily.Build(defs)
    local alias, species = ns.Scenes.ALIAS, ns.Companions and ns.Companions.species or {}
    local counts, has, last = {}, {}, 0
    for _, e in pairs(species) do
        if type(e) == "table" and e.a then
            local seen = {}
            for _, t in ipairs(e.t or {}) do
                t = alias[t] or t
                if not seen[t] then seen[t] = true; counts[t] = (counts[t] or 0) + 1 end
            end
        end
    end
    for i, d in ipairs(defs) do
        if d.kind == "family" then has[d.tag] = true; last = i end
    end
    for _, family in ipairs(ns.Scenes.ORDER) do
        if not has[family] and (counts[family] or 0) >= ns.AchFamily.MIN then
            last = last + 1
            table.insert(defs, last, { id = "family:" .. family, kind = "family", tag = family, cat = "family",
                icon = ns.AchFamily.ICONS[family] or CARRIER })
        end
    end
end
ns.AchFamily.Build(ns.AchDefs)
