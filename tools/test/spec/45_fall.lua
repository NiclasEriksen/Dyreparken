-- A fall (Activity "fall", 2026-11-12, the user): damage out of combat, as the client tells it (UNIT_COMBAT
-- "WOUND", physical; its amount secret: 2026-11-19). The pet reacts by its traits (Quirks' egg "stup"): a
-- Hoppetass is impressed, a Latsabb knew it, a worried one otherwise.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Setup(traits)
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        ola:Traits(traits or {})
        local Q = ola.ns.Quirks
        ola:Dice(0)
        ola:QuirksNow()
        return w, ola
    end
    -- A landing that hurt, as the client reports it (/dp probe api fall); dead: it was the end of you.
    local function Fall(w, ola, dead)
        ola.state.dead = dead
        ola:Fire("UNIT_COMBAT", "player", "WOUND", "", H.SECRET, 1)
        w:Run(1)
    end

    test("a fall: physical damage out of a fight, still out of one a moment later; nothing else", function()
        local w, ola = Setup()
        local A = ola.ns.Activity
        ok(A:IsListening("UNIT_COMBAT", "player"), "your own hits, out of a fight")
        Fall(w, ola)
        eq((A:Count("fall")), 1)
        ok(ola:Printed("Gikk det bra?", true) or ola:Printed("Var det virkelig", true) or ola:Printed("bekymret", true),
            "a worried line, with no trait of its own")
        -- Not physical (fire, lava), not a wound, not you: not a fall.
        ola:Fire("UNIT_COMBAT", "player", "WOUND", "", H.SECRET, 4)
        ola:Fire("UNIT_COMBAT", "player", "HEAL", "", H.SECRET, 1)
        w:Run(1)
        eq((A:Count("fall")), 1)
        -- A mob's first hit: the fight starts within the moment it waits.
        ola:Fire("UNIT_COMBAT", "player", "WOUND", "", H.SECRET, 1)
        ola:EnterCombat()
        w:Run(1)
        eq((A:Count("fall")), 1, "the start of a fight")
        no(A:IsListening("UNIT_COMBAT", "player"), "and in one, not heard at all")
        ola:LeaveCombat()
        w:Run(2)
        -- A mob that hit first, killed at once: the fight began and ended within the moment (the user, 2026-11-19).
        ola:Fire("UNIT_COMBAT", "player", "WOUND", "", H.SECRET, 1)
        ola:EnterCombat(); w:Run(0.1); ola:LeaveCombat()
        w:Run(1)
        eq((A:Count("fall")), 1, "a fight begun and over within the moment: not a fall")
        w:Run(A.FALL_AFTER_FIGHT)
        Fall(w, ola)
        eq((A:Count("fall")), 2, "a real one after it still counts")
    end)

    test("its traits decide what it says: a Hoppetass is impressed, a Latsabb knew it; a fatal one its own", function()
        local w, ola = Setup({ "latsabb", "hoppetass" })
        Fall(w, ola)
        ok(ola:Printed("Det hoppet skal det prøve selv", true), "Hoppetass comes first in the egg's traits")
        local w2, kari = Setup({ "latsabb" })
        Fall(w2, kari)
        ok(kari:Printed("tryggest å holde seg på bakken", true))
        local w3, per = Setup({ "hoppetass" })
        Fall(w3, per, true)
        ok(per:Printed("Det var visst litt for høyt", true), "the end of you: its own line")
        for _, id in ipairs(ola.ns.Quirks.EggById("stup").traits) do ok(ola.ns.Strings["egg.stup." .. id .. ".1"], id) end
    end)
    -- Its nature's lines mix with the general ones (Moments.NATURE_SHARE, 2026-11-22, the user); a nature in the
    -- row's `apart` says the opposite of them, so it always replaces them.
    test("its nature's lines come most of the time, the general ones the rest; an apart nature always its own", function()
        local w, ola = Setup({ "hoppetass" })
        local M = ola.ns.Moments
        ola:Dice(M.NATURE_SHARE + 0.01)
        Fall(w, ola)
        no(ola:Printed("Det hoppet skal det prøve selv", true), "a roll past the share: not its nature's line")
        ok(ola:Printed("Gikk det bra?", true) or ola:Printed("Var det virkelig", true) or ola:Printed("bekymret", true)
            or ola:Printed("Neste gang tar dere trappa", true), "one of the general lines instead")
        local row = { id = "stup", traits = { "hoppetass" } }
        eq(M.Nature("egg", row, "s:5159"), "egg.stup.hoppetass", "the nature, never rolled")
        eq(M.ByNature("egg", row, "s:5159")._key, nil, "rolled past the share: the general lines")
        row.apart = { "hoppetass" }
        eq(M.ByNature("egg", row, "s:5159")._key, "egg.stup.hoppetass", "apart: its own, whatever the roll")
        ola:Dice(M.NATURE_SHARE - 0.01)
        row.apart = nil
        eq(M.ByNature("egg", row, "s:5159")._key, "egg.stup.hoppetass", "within the share: its own")
        -- A row with no general lines at all (the demon's summons): always the nature's.
        eq(M.ByNature("react", { id = "demonen", families = { "bear" } }, "s:5159")._key, nil, "no such nature: none")
    end)
    -- From the log (review 2026-11-21): 12 of 26 falls came 0.5-1.1 s after a fight's end (a mob's last swing
    -- landing as it ended), the three fatal ones a wipe at a boss, and two hits were two falls.
    test("no fall: a fight's last swings, hits on you already dead, a second hit right after", function()
        local w, ola = Setup()
        local A = ola.ns.Activity
        local function Hit() ola:Fire("UNIT_COMBAT", "player", "WOUND", "", H.SECRET, 1) end
        ola:EnterCombat(); w:Run(20); ola:LeaveCombat()
        w:Run(0.2); Hit(); w:Run(0.5); Hit(); w:Run(2)
        eq((A:Count("fall")), 0, "the fight's last swings")
        -- Dead in a fight (it ends at your death), hit after it: still the fight's.
        ola.state.dead = true
        ola:EnterCombat(); w:Run(20); ola:LeaveCombat()
        w:Run(0.3); Hit(); w:Run(2)
        eq((A:Count("fall")), 0, "dead at a boss")
        -- Long dead, hit (a corpse out of any fight): no fall either.
        ola:Fire("PLAYER_DEAD"); w:Run(10)
        Hit(); w:Run(2)
        eq((A:Count("fall")), 0, "already dead at the hit")
        ola.state.dead = false; ola:Fire("PLAYER_ALIVE"); w:Run(10)
        -- A fall's two hits (the landing, a bounce): one fall.
        Hit(); w:Run(0.2); Hit(); w:Run(2)
        eq((A:Count("fall")), 1, "one fall, not two")
        w:Run(A.FALL_AGAIN)
        Hit(); w:Run(2)
        eq((A:Count("fall")), 2, "a new one later")
        -- A fatal fall: dead as it hits (its PLAYER_DEAD with it) still counts, as the end of you.
        w:Run(A.FALL_AGAIN)
        ola.state.dead = true; Hit(); ola:Fire("PLAYER_DEAD"); w:Run(2)
        eq((A:Count("fall")), 3, "the fatal one")
        ok(ola:Log("fall %+1 .*dead")[1], "as the end of you")
    end)
end
