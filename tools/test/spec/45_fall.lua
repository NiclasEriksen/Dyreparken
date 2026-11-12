-- A big fall (Activity "fall", 2026-11-12, the user): most of your health at once, out of combat. The pet reacts
-- by its traits (Quirks' egg "stup"): a Hoppetass is impressed, a Latsabb knew it, a worried one otherwise.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Setup(traits)
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        local P = ola.ns.Personality
        local list = {}
        for _, id in ipairs(traits or {}) do list[#list + 1] = P.ById(id) end
        P.Traits = function() return list end
        local Q = ola.ns.Quirks
        Q.random = function(n) return n and 1 or 0 end
        Q.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 }, now = { 0, 0 }, day = { 0, 0 } }
        ola.state.health, ola.state.healthMax = 1000, 1000
        ola:Fire("UNIT_HEALTH", "player") -- (the first look)
        return w, ola
    end
    local function Hp(w, ola, hp) ola.state.health = hp; ola:Fire("UNIT_HEALTH", "player"); w:Run(1) end

    test("a big fall: 70% of your health or more in one go, out of combat; small hits and fights don't count", function()
        local w, ola = Setup()
        local A = ola.ns.Activity
        Hp(w, ola, 800); Hp(w, ola, 500)
        eq((A:Count("fall")), 0, "a little at a time")
        Hp(w, ola, 1000)
        Hp(w, ola, 250)
        eq((A:Count("fall")), 1)
        ok(ola:Printed("Gikk det bra?", true) or ola:Printed("Var det virkelig", true) or ola:Printed("bekymret", true),
            "a worried line, with no trait of its own")
        Hp(w, ola, 1000)
        ola:EnterCombat()
        Hp(w, ola, 100)
        eq((A:Count("fall")), 0 + 1, "in a fight: not a fall")
        ola:LeaveCombat()
        -- A value it can't read: skipped, and the next one starts over.
        ola.state.health = H.SECRET; ola:Fire("UNIT_HEALTH", "player")
        ola.state.health = 50; ola:Fire("UNIT_HEALTH", "player"); w:Run(1)
        eq((A:Count("fall")), 1)
    end)

    test("its traits decide what it says: a Hoppetass is impressed, a Latsabb knew it; a fatal one its own", function()
        local w, ola = Setup({ "latsabb", "hoppetass" })
        Hp(w, ola, 200)
        ok(ola:Printed("Det hoppet skal det prøve selv", true), "Hoppetass comes first in FALL_TRAITS")
        local w2, kari = Setup({ "latsabb" })
        Hp(w2, kari, 100)
        ok(kari:Printed("tryggest å holde seg på bakken", true))
        local w3, per = Setup({ "hoppetass" })
        Hp(w3, per, 0)
        ok(per:Printed("Det var visst litt for høyt", true), "the end of you: its own line")
        for _, id in ipairs(ola.ns.Quirks.FALL_TRAITS) do ok(ola.ns.Strings["egg.stup." .. id .. ".1"], id) end
    end)
end
