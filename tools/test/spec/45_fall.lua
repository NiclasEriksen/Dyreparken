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
end
