-- The pet on the card moves (Menagerie/Moves.lua), and the research probe
-- (/dp probe anim, in a git checkout).
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    -- Ola with the panda on the card at a given hour (the player's clock).
    local function Setup(hour, traits)
        local w, ola = H.Setup{ ola = { 5159, 46 }, journal = true }
        ola.ns.Personality.Traits = function() return traits or { ola.ns.Personality.ById("glupsk") } end
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = hour }) - w:ServerTime())
        return w, ola, ola.petActor
    end

    test("/dp probe anim: finds the card's pet, lists what it has, plays one by name or id", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola:Slash("probe anim")
        match(ola:Printed("anim probe: actor by tag unwrapped", true),
            "HasAnimation=true .* has 3 of %d+: Stand %(0%), PetBattleCustom0 %(756%), PetBattleDead %(770%)$")
        eq(#ola:Log("Probe\tanim actor by tag unwrapped"), 1, "and in the log")
        ola:Slash("probe anim PetBattleCustom0")
        eq(actor.anim, 756)
        ok(ola:Printed("PetBattleCustom0 (756): SetAnimation ok; has it: true; now 756", true))
        ola:Slash("probe anim 770")
        eq(actor.anim, 770)
        ola:Slash("probe anim 9999")
        eq(actor.anim, 9999, "an id not in the list is tried too")
        ola:Slash("probe anim wiggle")
        ok(ola:Printed('unknown animation "wiggle"', true))
        ola:Slash("probe anim stop")
        eq(actor.anim, 0)
    end)

    test("/dp probe anim all|custom: each one it has, a few seconds apart; stop cancels it", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola:Slash("probe anim all")
        w:Run(0.6)
        ok(ola:Printed("1/3 Stand (0) species 5159: set, then 0, after 0.5 s 0", true))
        w:Run(3)
        eq(actor.anim, 756)
        w:Run(3)
        eq(actor.anim, 770)
        w:Run(3.1)
        eq(actor.anim, 0, "back to standing"); ok(ola:Printed("all: done, 3 tried", true))
        -- The four custom moves only (the client can't say which it has: all four tried).
        actor.HasAnimation = nil
        ola:Slash("probe anim custom")
        for _, id in ipairs({ 756, 758, 760, 762 }) do eq(actor.anim, id); w:Run(3.05) end
        ok(ola:Printed("custom: done, 4 tried", true))
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
        per:SelectPet(5159)
        per.petActor.HasAnimation = nil
        per:Slash("probe anim")
        match(per:Printed("anim probe: actor", true), "HasAnimation=false .* has 0 of")
        per:Slash("probe anim all")
        w3:Run(3.6)
        ok(per:Printed("2/%d+ Death %(1%) species 5159: set, then 1"), "unknown: every one is tried")
        per.petAnims = { [0] = true }
        per:Slash("probe anim PetBattleCustom0")
        ok(per:Printed("PetBattleCustom0 (756): SetAnimation ok; has it: nil; now 0", true))
    end)

    test("by day the pet stands; a click is a happy hop, then it stands again", function()
        local w, ola, actor = Setup(14)
        ola:SelectPet(5159)
        eq(actor.anim, 0)
        local card = ola:Card()
        ola.ns.Cuddle:Pet(card)
        eq(actor.anim, 756, "PetBattleCustom0: the panda's joyful hop")
        w:Run(2.1)
        eq(actor.anim, 0)
        -- A refresh of the same pet doesn't start it over.
        local n = #actor.played
        ola.ns.JournalUI:Refresh()
        eq(#actor.played, n)
    end)

    test("at night it's asleep on the card; a click wakes it, and it stays awake", function()
        local w, ola, actor = Setup(23)
        ola:SelectPet(5159)
        eq(actor.anim, 99, "lying down")
        w:Run(1.3)
        eq(actor.anim, 100, "asleep")
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 101, "waking up")
        w:Run(1.5)
        eq(actor.anim, 756, "glad to see you")
        w:Run(2.1)
        eq(actor.anim, 0, "awake")
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 0, "still awake when you come back to it")
        -- A night owl doesn't sleep at night.
        local w2, kari, actor2 = Setup(23)
        kari.ns.Personality.Traits = function() return { kari.ns.Personality.ById("nattugle") } end
        kari:SelectPet(5159)
        eq(actor2.anim, 0)
    end)

    test("a Latsabb sits down after a while; a click gets it up", function()
        local w, ola, actor = Setup(14)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("latsabb") } end
        ola:SelectPet(5159)
        eq(actor.anim, 0)
        w:Run(6.1)
        eq(actor.anim, 96)
        w:Run(1.3)
        eq(actor.anim, 97, "sitting")
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 98, "getting up")
        -- Another pet before it sits: nothing more for the first.
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 0)
    end)

    test("a level-up casts a little spell; the day of three deaths it plays dead once", function()
        local w, ola, actor = Setup(14)
        ola:SelectPet(5159)
        ola.ns.Moves:Cheer(PANDA)
        eq(actor.anim, 754)
        w:Run(2.6)
        eq(actor.anim, 0)
        ola.ns.Moves:Cheer("s:46")
        eq(actor.anim, 0, "not the pet on the card: nothing")
        -- The egg came up today with the panda out.
        ola.ns.DB.char.eggs.dodsfall = { n = 1, day = ola.ns.Today(), key = PANDA }
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 770, "playing dead")
        w:Run(4.1)
        eq(actor.anim, 0, "and up again")
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 0, "only once")
    end)

    test("closing the journal or opening our pages stops it; the next look starts over", function()
        local w, ola, actor = Setup(14)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("latsabb") } end
        ola:SelectPet(5159)
        ola.ns.Bus:Fire("SIDEPAGE", true)
        w:Run(8)
        eq(actor.anim, 0, "covered: it didn't sit down")
        ola.ns.Bus:Fire("SIDEPAGE", false)
        w:Run(8)
        eq(actor.anim, 97, "back on the card: sitting after a while")
        ola.env.PetJournalPetCard:Hide()
        ola.env.PetJournalPetCard:Show()
        ola:SelectPet(5159)
        eq(actor.anim, 0, "shown again: from the start")
    end)
end
