---@class Dyreparken
local ns = select(2, ...)

-- A mage's familiars (2026-11-17, the user: "Mages should bond to temporary summons"): Forever's Scrolls of
-- Rat, Frog and Cat Familiar put out a companion that isn't a journal pet, with a buff (an hour, +Intellect)
-- that goes if the familiar is replaced. From the client's tables (wago.tools, 1.60.1.70938): the scroll's
-- spell is the buff itself (ItemEffect), which summons the npc (SpellEffect 28) and raises Intellect (aura 29).
--   key      its bond's key: a name key ("n:<name>", Wire.Key), so bonds sync as any pet's, no protocol bump.
--            Permanent: bonds are stored under it.
--   name     the English name (the buff's and the npc's); the client's own comes from the spell (ns.SpellName)
--   item     the scroll; spell: the buff; npc, display: the creature and its model (Creature.csv)
--   family   one of Scenes.ORDER, from its name
ns.Familiars = {
    { id = "rat", key = "n:Rat Familiar", name = "Rat Familiar", item = 275069, spell = 1296202, npc = 266025,
        display = 148790, family = "rodent" },
    { id = "frog", key = "n:Frog Familiar", name = "Frog Familiar", item = 277483, spell = 1302285, npc = 268744,
        display = 148792, family = "frog" },
    { id = "cat", key = "n:Cat Familiar", name = "Cat Familiar", item = 277493, spell = 1302303, npc = 272012,
        display = 11709, family = "cat" },
}
