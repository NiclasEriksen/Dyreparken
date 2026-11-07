local _, ns = ...

-- Achievement definitions: what it takes, not what it's called (Texts.lua).
-- The order here is the order on the page and in lists.
--
-- IDS ARE PERMANENT: saved progress and sync key on them. Rename freely in
-- Texts.lua; never change an id here.
--
-- Kinds (see Achievements.lua for how each is evaluated):
--   count   n         own n pets that count toward achievements (hidden if
--                     fewer than n exist)
--   all               own every pet that counts
--   family  tag       own every counting pet with this tag (skipped while the
--                     tag has no counting pets)
--   loyal   days      care for the same companion this many days  (char)
--   nick              have given your companion a nickname          (char)
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
-- Icons: classic icon paths, (unverified) on Forever; a missing one shows as
-- a question mark. The pet carrier stands in where nothing fits better yet.
ns.AchDefs = {
    { id = "count:10", kind = "count", n = 10, cat = "collection", icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "count:25", kind = "count", n = 25, cat = "collection", icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "count:50", kind = "count", n = 50, cat = "collection", icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "count:all", kind = "all", cat = "collection", icon = "Interface\\Icons\\Ability_Mount_WhiteTiger" },

    { id = "family:cat", kind = "family", tag = "cat", cat = "family", icon = "Interface\\Icons\\Ability_Druid_CatForm" },
    { id = "family:farm", kind = "family", tag = "farm", cat = "family", icon = "Interface\\Icons\\Spell_Magic_PolymorphChicken" },
    { id = "family:owl", kind = "family", tag = "owl", cat = "family", icon = "Interface\\Icons\\Ability_Hunter_Pet_Owl" },
    { id = "family:rabbit", kind = "family", tag = "rabbit", cat = "family", icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "family:snake", kind = "family", tag = "snake", cat = "family", icon = "Interface\\Icons\\Ability_Hunter_Pet_WindSerpent" },
    { id = "family:frog", kind = "family", tag = "frog", cat = "family", icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "family:mechanical", kind = "family", tag = "mechanical", cat = "family", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
    { id = "family:dragon", kind = "family", tag = "dragon", cat = "family", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
    { id = "family:bird", kind = "family", tag = "bird", cat = "family", icon = "Interface\\Icons\\Spell_Nature_RavenForm" },
    { id = "family:pirate", kind = "family", tag = "pirate", cat = "family", icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },

    { id = "loyal:30", kind = "loyal", days = 30, scope = "char", cat = "loyalty", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { id = "loyal:100", kind = "loyal", days = 100, scope = "char", cat = "loyalty", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { id = "loyal:365", kind = "loyal", days = 365, scope = "char", cat = "loyalty", icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { id = "nick", kind = "nick", scope = "char", cat = "loyalty", icon = "Interface\\Icons\\INV_Misc_Note_01" },

    { id = "guild:count:10", kind = "guildcount", n = 10, scope = "guild", cat = "guild",
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "guild:count:25", kind = "guildcount", n = 25, scope = "guild", cat = "guild",
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "guild:count:50", kind = "guildcount", n = 50, scope = "guild", cat = "guild",
        icon = "Interface\\Icons\\INV_Box_PetCarrier_01" },
    { id = "guild:all", kind = "guildall", scope = "guild", cat = "guild",
        icon = "Interface\\Icons\\Ability_Mount_WhiteTiger" },
    { id = "guild:family:cat", kind = "guildfamily", tag = "cat", scope = "guild", cat = "guild",
        icon = "Interface\\Icons\\Ability_Druid_CatForm" },
}
