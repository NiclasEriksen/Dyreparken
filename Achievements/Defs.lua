local _, ns = ...

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
--   dislikes          have found out everything your companion dislikes (Quirks.lua) (char)
--   eggs      n       have found n different easter eggs (Quirks.lua, char.eggs)        (char)
--   activity act n    n of an activity (Core/Activity.lua: "boss", "quest", ...); pet = true counts
--                     only with your adopted companion out. Hidden while the client can't produce it.
--                                                                    (char)
--   guildcount  n     the guild cares for n counting pets at once  (guild)
--   guildall          the guild cares for every counting pet       (guild)
--   guildfamily tag   the guild cares for every counting pet with this tag
--                     (one pet per member, so each by a different member)
--
-- scope: "account" (default; the collection is account-wide on Forever),
-- "char" (adoption is per character), or "guild" (shared, synced; ids start
-- with "guild:", which the sync relies on).
--
-- Decided 2026-11-06: nothing rewards adopting often (no "adopted N pets").
-- icon: one candidate or a list, best first. A candidate is an icon name
-- (under Interface\Icons\), a full path, or a file id (a number, from an
-- icon database). The client shows the first one it has (Ach:Icon), so a
-- wrong guess never shows as a blank. `/dp ach icons` previews every
-- candidate in chat. Names are guesses at Forever's icons until previewed.
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

    { id = "loyal:30", kind = "bond", level = 3, scope = "char", cat = "loyalty", icon = { "INV_ValentinesCandy", "Spell_Holy_SealOfSacrifice" } },
    { id = "loyal:100", kind = "bond", level = 4, scope = "char", cat = "loyalty", icon = { "INV_ValentinesCard02", "Spell_Holy_SealOfSacrifice" } },
    { id = "loyal:365", kind = "bond", level = 6, scope = "char", cat = "loyalty", icon = { "Achievement_WorldEvent_Valentine", "Spell_Holy_SealOfSacrifice" } },
    { id = "nick", kind = "nick", scope = "char", cat = "loyalty", icon = { "INV_Inscription_Parchment", "INV_Misc_Note_01" } },
    { id = "dislikes", kind = "dislikes", scope = "char", cat = "loyalty", icon = { "Spell_Misc_EmotionSad", "INV_Misc_Book_09", "INV_Misc_Note_01" } },
    -- Together (2026-11-10): with your adopted pet out. High: a dungeon has many bosses, and quests come quick.
    { id = "boss:100", kind = "activity", act = "boss", n = 100, pet = true, scope = "char", cat = "together", icon = { "Achievement_Boss_Onyxia", "INV_Misc_Bone_HumanSkull_01" } },
    { id = "boss:500", kind = "activity", act = "boss", n = 500, pet = true, scope = "char", cat = "together", icon = { "Achievement_Boss_Ragnaros", "INV_Misc_Head_Dragon_Black" } },
    { id = "boss:2000", kind = "activity", act = "boss", n = 2000, pet = true, scope = "char", cat = "together", icon = { "Achievement_Boss_KelThuzad_01", "INV_Misc_Head_Dragon_Bronze" } },
    { id = "pvp:250", kind = "activity", act = "pvp", n = 250, pet = true, scope = "char", cat = "together", icon = { "Ability_DualWield", "INV_Sword_04" } },
    { id = "pvp:1000", kind = "activity", act = "pvp", n = 1000, pet = true, scope = "char", cat = "together", icon = { "Ability_Warrior_BattleShout", "INV_Sword_27" } },
    { id = "pvp:5000", kind = "activity", act = "pvp", n = 5000, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Bandana_03", "Ability_Warrior_WarCry" } },
    { id = "quest:500", kind = "activity", act = "quest", n = 500, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Book_09", "INV_Scroll_03" } },
    { id = "quest:2500", kind = "activity", act = "quest", n = 2500, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Book_11", "INV_Scroll_03" } },
    { id = "quest:10000", kind = "activity", act = "quest", n = 10000, pet = true, scope = "char", cat = "together", icon = { "INV_Misc_Book_07", "INV_Scroll_03" } },
    { id = "eggs:10", kind = "eggs", n = 10, scope = "char", cat = "loyalty", icon = { "INV_Egg_03", "INV_Egg_01", "INV_Misc_Food_57" } },
    { id = "eggs:25", kind = "eggs", n = 25, scope = "char", cat = "loyalty", icon = { "INV_Egg_04", "INV_Egg_03", "INV_Misc_Food_57" } },

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
}
