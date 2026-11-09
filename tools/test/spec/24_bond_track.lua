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
        Points(ola, 300) -- Venn, level 3
        local card = ola:SelectPet(5159)
        local b = card.bond
        ok(b:IsShown())
        eq(b.level.text, 3); eq(b.label.text, "Venn")
        eq(b.next.text, "230 poeng til God venn")
        eq(b.text.text, "300 / 530")
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
        Points(ola, 1000)
        card = ola:SelectPet(5159)
        eq(b.level.text, 5)
        no(b.medal.ring.desaturated); ok(b.medal.glow:IsShown()); ok(b.medal.glow.pulse:IsPlaying())
        -- The top: a full bar, no spark.
        Points(ola, 7000)
        card = ola:SelectPet(5159)
        eq(b.text.text, "7000"); no(b.spark:IsShown())
        -- The level preview shows that level's own name and points (it said "Bekjent (nivå 7)").
        Points(ola, 30)
        ola:Slash("probe level 7")
        eq(b.label.text, "Sjelevenn"); eq(b.level.text, 7); eq(b.next.text, "Det høyeste nivået")
        ola:Slash("probe level 4")
        eq(b.label.text, "God venn"); eq(b.text.text, "530 / 900")
        ola:Slash("probe level off")
        eq(b.label.text, "Bekjent"); eq(b.next.text, "70 poeng til Kamerat")
        -- A pet nobody holds and we don't own: no bond at all.
        card = ola:SelectPet(46)
        no(b:IsShown())
    end)

    test("hovering a star says what that level brings, and whether it's reached", function()
        local w, ola = Setup()
        ola:Slash("adopter panda")
        w:Run(5)
        Points(ola, 300)
        local card = ola:SelectPet(5159)
        local tip = ola.env.GameTooltip
        local p = card.bond.pips[4]
        p.scripts.OnEnter(p)
        eq(table.concat(tip.lines, " / "), "Nivå 4: God venn / Fra 530 poeng. / Kortet får en glød under dyret.")
        p.scripts.OnLeave(p)
        p = card.bond.pips[1]
        p.scripts.OnEnter(p)
        eq(table.concat(tip.lines, " / "), "Nivå 1: Bekjent / Der alle starter. / Nådd!")
        local m = card.bond.medal
        m.scripts.OnEnter(m)
        match(table.concat(tip.lines, " / "), "^Bånd: Venn %(nivå 3%) / 230 poeng til God venn%.")
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
        -- A level-up while the card shows (a day later: a first day can't hold 100).
        w:SkipDays(1)
        ola.ns.Bond:Add(100)
        eq(card.bond.level.text, 2)
        ok(cel.flash:IsShown()); ok(cel.flash.anim:IsPlaying(), "a flash of light")
        local shown = 0
        for _, p in ipairs(cel.parts) do if p:IsShown() and p.anim:IsPlaying() then shown = shown + 1 end end
        eq(shown, #cel.parts, "a burst")
        eq(cel.text.title.text, "Kamerat!")
        eq(cel.text.sub.text, "Panda Cub og du er nå på nivå 2.\nNy pynt: en kant og et hint av familiens farge.")
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
        ok(ola:Printed("Open the pet card first.", true))
        ola:Slash("adopter panda")
        w:Run(5)
        local card = ola:SelectPet(5159)
        ola:Slash("probe celebrate")
        ok(card.celebration.flash:IsShown())
        eq(card.celebration.text.title.text, "Bekjent!")
        eq(#ola.sounds, 1)
    end)

    test("a day brings at most 75 points, and the card shows today's share and when it's full", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        w:Run(5)
        Points(ola, 300)
        ola.ns.Personality.Traits = function() -- plain: a day is 10, herbs are liked (the panda's own)
            return { ola.ns.Personality.ById("glupsk"), ola.ns.Personality.ById("reiseglad") }
        end
        ola:NoBonuses() -- (just the activities)
        local card = ola:SelectPet(5159)
        local b = card.bond
        local function Earned() return ola.ns.Registry:Life(PANDA, "Ola Nord").p end
        eq(b.text.text, "300 / 530", "nothing yet today")
        no(b.text:IsShown(), "the points show only on hover")
        b.scripts.OnEnter(b); ok(b.text:IsShown()); b.scripts.OnLeave(b); no(b.text:IsShown())
        no(b.today:IsShown())
        ola.ns.Activity:CheckDay()
        eq(Earned(), 310)
        eq(b.text.text, "310 / 530  (+10)", "today's points on the bar")
        ok(b.today:IsShown(), "lit up")
        local lo, width = b.today.points[1][4], b.today.size[1]
        ok(math.abs(lo - 128 * 30 / 260) < 1e-6, "from where today began"); ok(math.abs(width - 128 * 10 / 260) < 1e-6)
        eq(b.next.text, "220 poeng til God venn")
        local tip = ola.env.GameTooltip
        b.scripts.OnEnter(b)
        match(table.concat(tip.lines, " / "), "I dag: %+10 av 75 mulige poeng%.")
        -- Herbs (liked, 25 a day), boss-kills, quests: the day's 75 is the limit.
        for _ = 1, 6 do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366) end -- 25
        ola.ns.Personality.Traits = function()
            return { ola.ns.Personality.ById("eventyrlysten"), ola.ns.Personality.ById("reiseglad") }
        end
        for _ = 1, 6 do ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1) end -- 25 (boss, liked now)
        ola.ns.Personality.Traits = function()
            return { ola.ns.Personality.ById("glupsk"), ola.ns.Personality.ById("steinhard") }
        end
        eq(Earned(), 360)
        ok(not ola:Printed("fullt for i dag", true))
        for _ = 1, 6 do ola:Fire("QUEST_TURNED_IN", 1) end -- quests (liked now): 15 of 25 fit
        eq(Earned(), 375, "75 in a day, no more")
        ok(ola:Printed("Båndet med Panda Cub er fullt for i dag. Fortsett i morgen!", true))
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2575)
        eq(Earned(), 375)
        local fulls = 0
        for _, l in ipairs(ola.printed) do if l:find("fullt for i dag", 1, true) then fulls = fulls + 1 end end
        eq(fulls, 1, "said once")
        card = ola:SelectPet(5159)
        match(b.next.text, "Fullt for i dag$")
        eq(b.next.color[2], 1, "in green")
        no(b.spark:IsShown(), "the tip rests")
        b.scripts.OnEnter(b)
        match(table.concat(tip.lines, " / "), "I dag: fullt %(75 av 75%)%. Kom tilbake i morgen!")
        -- Someone else's pet: no "today" (it's their day, not ours).
        ola.ns.Bond:Watch() -- (publish: a level-up would; here, the login sync)
        kari:Reload()
        w:Run(40)
        kari.ns.DB.char.bondToday = { day = os.date("%Y%m%d", kari.ns.Now()), pets = { ["s:40"] = { got = {}, total = 50 } } } -- her own day
        kari:OpenJournal()
        local kb = kari:SelectPet(5159).bond
        eq(kb.text.text, "375 / 530"); no(kb.today:IsShown()); eq(kb.next.text, "Ola Nord sitt bånd")
        -- A new day: room again. The day's own points fit the limit too.
        w:SkipDays(1)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned(), 380)
        ola.ns.DB.char.bondToday.pets[PANDA].total = 70
        ola.ns.Activity:CheckDay()
        eq(Earned(), 385, "the day visit: only the 5 left")
        card = ola:SelectPet(5159)
        match(b.next.text, "Fullt for i dag$")
    end)

    test("naming opens at Venn: said right then, once, and Venn's star tells it", function()
        local w, ola = Setup()
        ola:Slash("adopter panda")
        w:SkipDays(5)
        local card = ola:SelectPet(5159)
        local star = card.bond.pips[3]
        star.scripts.OnEnter(star)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "/ Du kan gi dyret ditt et kallenavn%.")
        no(ola.ns.Registry:CanNickname(select(2, ola.ns.Registry:MyPet())))
        ola.ns.Bond:Add(269)
        ok(not ola:Printed("et kallenavn: /dp navn", true), "one short")
        ola.ns.Bond:Add(1)
        ok(ola:Printed("Nå kan du gi Panda Cub et kallenavn: /dp navn", true), "the moment it's Venn")
        ola.ns.Bonds:TellNameUnlock()
        local n = 0
        for _, l in ipairs(ola.printed) do if l:find("et kallenavn: /dp navn", 1, true) then n = n + 1 end end
        eq(n, 1, "once")
        ola:Slash("navn Pepe")
        eq(ola.ns.Registry:Nickname(PANDA), "Pepe")
    end)
end
