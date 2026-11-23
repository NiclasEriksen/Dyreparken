-- Turnus (Menagerie/Turnus.lua, 2026-11-22, 0.10.0): your pets take turns being out. The small toggle beside
-- "Med deg" on the card, a new pet each calendar day, the next with room when the one out has a full day; never in
-- place of a pet you summoned yourself.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN, CAT = "s:5159", "s:46", "s:40"

    local function Setup()
        local w, ola = H.Setup{ ola = { 5159, 46, 40 }, journal = true }
        ola:Slash("adopter panda"); w:Run(5)
        return w, ola, ola.ns.Turnus
    end
    local function Fill(ola, key)
        local ns = ola.ns
        ns.Bond:Today(key)
        ns.DB.char.bondToday.pets[key].total = ns.Bond:DailyMax(key)
        ns.Bus:Fire("BOND_FULL", key)
    end

    test("the card's toggle: beside Med deg, small, on and off, at most five, only for your own pets", function()
        local w, ola, T = Setup()
        local card = ola:SelectPet(5159)
        local t = card.auto.turnus
        ok(t:IsShown()); eq(t.size[1], ola.ns.OutBadge.TURNUS_SIZE)
        local at = t.points[#t.points]
        eq(at[1] .. " " .. at[3], "CENTER TOPRIGHT", "on Med deg's top-right corner (the user: not among the badges)")
        eq(at[2], card.auto)
        ok(t.ring.desaturated, "not in it: dim")
        local tip = ola:TipOf(t)
        eq(tip[1], "Ta Panda Cub med i turnusen")
        eq(tip[#tip], "Klikk for å ta Panda Cub med.")
        t:Click()
        ok(T:Has(PANDA)); no(t.ring.desaturated)
        tip = ola:TipOf(t)
        eq(tip[1], "Panda Cub er med i turnusen")
        eq(tip[3], "I turnusen: Panda Cub"); eq(tip[4], "Velg minst ett dyr til, så begynner turnusen.")
        no(T:On(), "one pet: not yet")
        t:Click()
        no(T:Has(PANDA), "off again")
        -- At most five.
        ola.ns.DB.char.turnus = { "s:1", "s:2", "s:3", "s:4", "s:5" }
        card = ola:SelectPet(46)
        no(t.enabled, "full: can't add")
        eq(ola:TipOf(t)[#ola:TipOf(t)], "Turnusen er full (5 dyr).")
        no(T:Toggle(KITTEN))
        ola.ns.DB.char.turnus = nil
        -- A pet you don't own: no toggle.
        no(ola:SelectPet(68).auto.turnus:IsShown())
    end)

    test("each day the next pet in the list; full mid-day, the next with room takes over, instead of the nudge", function()
        local w, ola, T = Setup()
        local ns = ola.ns
        T:Toggle(PANDA); T:Toggle(KITTEN); T:Toggle(CAT)
        ok(T:On())
        eq(ns.DB.char.turnusDay.key, PANDA, "started today with the pet out")
        -- The panda's day fills: the kitten takes over, the panda that we put out goes in.
        ola:Summon(5159)
        Fill(ola, PANDA)
        w:Run(2)
        eq(ns.Summon:ActiveKey(), KITTEN); eq(ns.Pets:KeyOf(ola.summoned), KITTEN)
        ok(ola:Printed("Panda Cub er fornøyd for i dag. Nå er det White Kitten sin tur!", true))
        no(ola:Printed("har aldri vært ute", true), "not the nudge too")
        -- A new day: the one after the last pick (the cat).
        w:SkipDays(1); ola:Reload(); w:Settle("hello")
        ns = ola.ns
        eq(ns.Summon:ActiveKey(), CAT)
        ok(ola:Printed("Turnus: Bombay Cat er med deg i dag.", true))
        -- Again the same day: no change.
        ola:Reload(); w:Settle("hello")
        eq(ola.ns.Summon:ActiveKey(), CAT)
        -- The next day: round to the panda.
        w:SkipDays(1); ola:Reload(); w:Settle("hello")
        eq(ola.ns.Summon:ActiveKey(), PANDA)
    end)

    test("the day's swap waits for its moment: mounted at midnight, the next pet comes out once you're down", function()
        local w, ola, T = Setup()
        local ns = ola.ns
        T:Toggle(PANDA); T:Toggle(KITTEN)
        ola:Summon(5159); w:Run(2)
        -- (seen 2026-11-23: the day turned on a mount, and yesterday's pet stayed out all day)
        w:SkipDays(1); ola:Mount()
        T:Day()
        eq(ns.Summon:ActiveKey(), KITTEN)
        eq(ns.Pets:KeyOf(ola.summoned), PANDA, "not on a mount")
        ola:Dismount(); w:Run(3)
        eq(ns.Pets:KeyOf(ola.summoned), KITTEN, "the kitten once down")
        eq(ns.DB.char.swapFrom, nil, "done")
        -- Once out, the panda put out again by hand stays.
        ola:Summon(5159); ola:Mount(); ola:Dismount(); w:Run(3)
        eq(ns.Pets:KeyOf(ola.summoned), PANDA, "yours by hand")
        -- A pet you put out while it waits: yours stays, and the swap is off.
        w:SkipDays(1); ola:Mount()
        T:Day()
        eq(ns.Summon:ActiveKey(), PANDA)
        ok(ns.DB.char.swapFrom == nil, "the kitten wasn't the one out: nothing to swap")
        ola:Summon(46); ns.DB.char.swapFrom = { day = ns.Today(), key = KITTEN }
        ola:Summon(40); ola:Dismount(); w:Run(3)
        eq(ns.Pets:KeyOf(ola.summoned), CAT, "the cat, by hand, stays")
        eq(ns.DB.char.swapFrom, nil)
    end)

    test("never in place of a pet you summoned yourself; nobody with room: it stays; off with auto-summon", function()
        local w, ola, T = Setup()
        local ns = ola.ns
        T:Toggle(PANDA); T:Toggle(KITTEN)
        ola:Summon(40) -- (yours, by hand)
        Fill(ola, PANDA)
        w:Run(2)
        eq(ns.Summon:ActiveKey(), KITTEN, "the kitten is the one kept out now")
        eq(ns.Pets:KeyOf(ola.summoned), CAT, "but your cat stays out")
        -- Everyone full: it stays, and the plain line's place is the nudge's.
        Fill(ola, KITTEN)
        eq(ns.Summon:ActiveKey(), KITTEN)
        -- Auto-summon off: Turnus rests.
        ns.Summon:SetActive(KITTEN, false)
        no(T:On())
        w:SkipDays(1); ola:Reload(); w:Settle("hello")
        eq(ola.ns.DB.char.activePet, KITTEN, "nothing picked while off")
    end)

    test("Flokk lists the Turnus pets: today's in gold, and how each one's day stands", function()
        local w, ola, T = Setup()
        T:Toggle(PANDA); T:Toggle(KITTEN)
        Fill(ola, KITTEN)
        local lines = ola:About(PANDA, "herd")
        eq(lines[1], "Turnus")
        eq(lines[2], "Panda Cub"); eq(lines[3], "Med deg nå")
        eq(lines[4], "White Kitten"); eq(lines[5], "Fornøyd for i dag")
        eq(lines[6], "Sammen med deg")
        ola:SelectPet(46).auto.turnus:Click()
        match(ola:About(PANDA, "herd").text, "^Turnus / Panda Cub / Med deg nå / Velg minst ett dyr til")
    end)
end
