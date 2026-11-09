-- The pet animation probe (Menagerie/Moves.lua): /dp probe anim, in a git checkout.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    test("/dp probe anim: finds the card's pet, lists what it has, plays one by name or id", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola:Slash("probe anim")
        match(ola:Printed("anim probe: actor by tag unwrapped", true),
            "HasAnimation=true .* has 3 of %d+: Stand %(0%), EmoteDance %(69%), PetBattleVictory %(764%)$")
        eq(#ola:Log("Probe\tanim actor by tag unwrapped"), 1, "and in the log")
        ola:Slash("probe anim EmoteDance")
        eq(actor.anim, 69)
        ok(ola:Printed("EmoteDance (69): SetAnimation ok; has it: true", true))
        ola:Slash("probe anim 764")
        eq(actor.anim, 764)
        ok(ola:Printed("PetBattleVictory (764)", true))
        ola:Slash("probe anim 9999")
        eq(actor.anim, 9999, "an id not in the list is tried too")
        ola:Slash("probe anim wiggle")
        ok(ola:Printed('unknown animation "wiggle"', true))
        ola:Slash("probe anim stop")
        eq(actor.anim, 0)
    end)

    test("/dp probe anim all: each one it has, a few seconds apart; stop cancels it", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        local actor = ola.petActor
        ola:Slash("probe anim all")
        eq(actor.played[#actor.played], 0, "the first it has: Stand")
        ok(ola:Printed("1/3 Stand (0): playing", true))
        w:Run(3.1)
        eq(actor.anim, 69)
        w:Run(3.1)
        eq(actor.anim, 764)
        w:Run(3.1)
        eq(actor.anim, 0, "back to standing"); ok(ola:Printed("all: done, 3 tried", true))
        -- Stopped halfway: nothing more plays.
        ola:Slash("probe anim all")
        w:Run(3.1)
        ola:Slash("probe anim stop")
        local n = #actor.played
        w:Run(10)
        eq(#actor.played, n)
    end)

    test("/dp probe anim without a pet model, or without HasAnimation: says so, tries anyway", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("probe anim")
        ok(ola:Printed("no PetJournalPetCard.modelScene", true))
        local w2, kari = H.Setup{ ola = { 5159 }, journal = { noActor = true } }
        kari:Slash("probe anim")
        ok(kari:Printed("anim probe: no actor in the scene", true))
        local w3, per = H.Setup{ ola = { 5159 }, journal = true }
        per.petActor.HasAnimation = nil
        per:Slash("probe anim")
        match(per:Printed("anim probe: actor", true), "HasAnimation=false .* has 0 of")
        per:Slash("probe anim all")
        ok(per:Printed("1/%d+ Stand %(0%): playing"), "unknown: every one is tried")
    end)
end
