-- The bond on the pet card (Menagerie/BondTrack.lua): the medallion, the
-- track of levels, the bar, and the celebration when your pet levels up.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        local kari = w:AddClient("Kari Berg", { pets = { 40 } })
        w:Run(20)
        ola:OpenJournal()
        return w, ola, kari
    end

    -- Give Ola's panda this many points (its bond, as if earned long ago).
    local function Points(ola, p)
        local now = ola.ns.Now()
        local g = ola.ns.DB:Guild()
        g.life[PANDA] = { ["Ola Nord"] = { p = p, f = now - 400 * 86400, t = now } }
    end

    test("the medallion, the track of stars and the bar show the holder's bond in its tier", function()
        local w, ola = Setup()
        ola:Slash("adopter panda")
        w:Run(5)
        Points(ola, 450) -- Venn, level 3
        local card = ola:SelectPet(5159)
        local b = card.bond
        ok(b:IsShown())
        eq(b.level.text, 3); eq(b.label.text, "Bånd: Venn (nivå 3)")
        eq(b.text.text, "450 / 1000")
        ok(b.spark:IsShown(), "a spark at the tip")
        -- Silver: the ring greyed and tinted, the fill from dark to bright silver.
        ok(b.medal.ring.desaturated); eq(b.medal.ring.vertexColor[3], 1)
        eq(b.medal.ring.atlas, "communities-ring-gold")
        local grad = b:GetStatusBarTexture().gradient
        eq(grad[1], "HORIZONTAL"); ok(grad[2].b < grad[3].b, "dark to bright")
        no(b.medal.glow:IsShown())
        -- The stars: reached gold, the current one pulsing, the rest dark.
        for i, p in ipairs(b.pips) do
            if i < 3 then eq(p.star.vertexColor[3], 0.25, "reached: gold"); no(p.halo:IsShown())
            elseif i == 3 then ok(p.halo:IsShown()); ok(p.halo.pulse:IsPlaying(), "the current one pulses")
            else eq(p.star.vertexColor[1], 0.3, "ahead: dark"); no(p.halo.pulse:IsPlaying()) end
        end
        eq(#b.pips, 7)
        -- Gold from 5: the ring's own gold, glowing.
        Points(ola, 2500)
        card = ola:SelectPet(5159)
        eq(b.level.text, 5)
        no(b.medal.ring.desaturated); ok(b.medal.glow:IsShown()); ok(b.medal.glow.pulse:IsPlaying())
        -- The top: a full bar, no spark.
        Points(ola, 7000)
        card = ola:SelectPet(5159)
        eq(b.text.text, "7000"); no(b.spark:IsShown())
        -- A pet nobody holds: no bond at all.
        card = ola:SelectPet(40)
        no(b:IsShown())
    end)

    test("hovering a star says what that level brings, and whether it's reached", function()
        local w, ola = Setup()
        ola:Slash("adopter panda")
        w:Run(5)
        Points(ola, 450)
        local card = ola:SelectPet(5159)
        local tip = ola.env.GameTooltip
        local p = card.bond.pips[4]
        p.scripts.OnEnter(p)
        eq(table.concat(tip.lines, " / "), "Nivå 4: God venn / Fra 1000 poeng. / Kortet får en glød under kjæledyret.")
        p.scripts.OnLeave(p)
        p = card.bond.pips[1]
        p.scripts.OnEnter(p)
        eq(table.concat(tip.lines, " / "), "Nivå 1: Bekjent / Der alle starter. / Nådd!")
        local m = card.bond.medal
        m.scripts.OnEnter(m)
        match(table.concat(tip.lines, " / "), "^Bånd: Venn %(nivå 3%) / 550 poeng til God venn%.")
        m.scripts.OnLeave(m)
    end)

    test("your pet's new level is celebrated once, the next time its card shows", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        w:Run(5)
        local card = ola:SelectPet(5159)
        local cel = card.celebration
        eq(ola.ns.DB.char.bondSeen[PANDA], 1, "the first look: remembered, nothing to celebrate")
        no(cel.flash:IsShown())
        eq(#(ola.sounds or {}), 0)
        -- A level-up while the card shows.
        ola.ns.Bond:Add(100)
        eq(card.bond.level.text, 2)
        ok(cel.flash:IsShown()); ok(cel.flash.anim:IsPlaying(), "a flash of light")
        local shown = 0
        for _, p in ipairs(cel.parts) do if p:IsShown() and p.anim:IsPlaying() then shown = shown + 1 end end
        eq(shown, #cel.parts, "a burst")
        eq(cel.text.title.text, "Kamerat!")
        eq(cel.text.sub.text, "Panda Cub og du er nå på nivå 2.\nNy pynt: en kant og et skjær i familiens farge.")
        eq(ola.sounds[1], ola.env.SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_GOLD_TRAIT)
        eq(ola.ns.DB.char.bondSeen[PANDA], 2)
        -- Seen: not again.
        ola:SelectPet(40); ola:SelectPet(5159)
        eq(#ola.sounds, 1)
        -- A one-shot ends hidden; closing the journal ends it all.
        cel.parts[1].anim:Finish()
        no(cel.parts[1]:IsShown())
        ola.ns.Bond:Add(0) -- (nothing)
        ola.env.PetJournalPetCard:Hide()
        no(cel.flash:IsShown()); no(cel.text.anim:IsPlaying())
        -- Not for someone else's pet, nor in the level preview.
        ola.env.PetJournalPetCard:Show()
        ola:Slash("probe level 6")
        eq(#ola.sounds, 1, "the preview never celebrates")
        ola:Slash("probe level off")
        eq(ola.ns.DB.char.bondSeen[PANDA], 2)
        -- Without the sound names, still the rest (and no error).
        ola.env.SOUNDKIT = nil
        ola.ns.BondTrack:Celebrate(card, PANDA, 3)
        eq(#ola.sounds, 1); eq(cel.text.title.text, "Venn!")
    end)

    test("/dp probe celebrate plays it on the open card", function()
        local w, ola = Setup()
        ola:Slash("probe celebrate")
        ok(ola:Printed("Åpne kjæledyrkortet først.", true))
        ola:Slash("adopter panda")
        w:Run(5)
        local card = ola:SelectPet(5159)
        ola:Slash("probe celebrate")
        ok(card.celebration.flash:IsShown())
        eq(card.celebration.text.title.text, "Bekjent!")
        eq(#ola.sounds, 1)
    end)
end
