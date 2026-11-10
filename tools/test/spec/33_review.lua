-- The code review of 2026-11-10: the card's dormancy, crash recovery, the day
-- after midnight. Each test names the problem it guards against.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, DAY = "s:5159", 86400

    -- Every animation group playing in a client, on any frame or texture.
    local function Playing(c)
        local n = 0
        local function Scan(r)
            for _, g in ipairs(r.animGroups or {}) do if g.playing then n = n + 1 end end
        end
        for _, f in ipairs(c.frames) do
            Scan(f)
            for _, t in ipairs(f.textures or {}) do Scan(t) end
        end
        return n
    end

    -- Ola with her panda adopted at Sjelevenn: every decoration and pulse there is.
    local function Loved()
        local w, ola = H.Setup{ ola = { 5159, 40 }, settle = "bond" }
        ola:Slash("adopter panda")
        w:Run(5)
        local now = ola.ns.Now()
        ola.ns.DB:Guild().life[PANDA] = { ["Ola Nord"] = { p = 2300, f = now - 400 * DAY, t = now } }
        return w, ola
    end

    test("Blizzard updating the card with the journal closed starts nothing there", function()
        local w, ola = Loved()
        ola:OpenJournal()
        ola:SelectPet(5159)
        ok(Playing(ola) > 0)
        ola:CloseJournal()
        eq(Playing(ola), 0, "closed: all stopped, the badge's glow too")
        local timers, sent = #w.timers, #w.wire
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard) -- (PET_JOURNAL_LIST_UPDATE)
        eq(Playing(ola), 0, "no particles or pulses on a hidden card")
        eq(#w.timers, timers, "no pose timers")
        eq(#w.wire, sent, "no bond request")
        ola:OpenJournal()
        ok(Playing(ola) > 0, "shown again: drawn")
    end)

    test("a pet with no bond to show leaves no pulse playing on the hidden track", function()
        local w, ola = Loved()
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        ok(card.bond.medal.glow.pulse.playing)
        ola:SelectPet(46) -- (not owned, nobody's: no bond)
        no(card.bond:IsShown())
        no(card.bond.medal.glow.pulse.playing)
        for _, p in ipairs(card.bond.pips) do no(p.halo.pulse.playing) end
    end)

    test("a level-up celebration stops when another pet is picked", function()
        local w, ola = Loved()
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        ola.ns.BondTrack:Celebrate(card, PANDA, 7)
        ok(card.celebration.text:IsShown())
        ola:SelectPet(40)
        no(card.celebration.text:IsShown(), "the old pet's name isn't left over the new card")
        no(card.celebration.text.anim.playing)
    end)

    test("a guildmate's BOND message doesn't start the pet's hop over", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 14 }) - w:ServerTime())
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 756)
        local n = #actor.played
        ola.ns.Bus:Fire("BOND", "s:40")
        eq(#actor.played, n, "the hop plays on")
        w:Run(2.1)
        eq(actor.anim, 0, "and ends standing")
        ola.ns.Bus:Fire("BOND", "s:40")
        eq(actor.anim, 0)
    end)

    test("a closed card holds no pose: a model loading there isn't laid down again", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola.ns.PetMoves.species[5159] = nil
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 23 }) - w:ServerTime())
        ola:SelectPet(5159)
        local actor = ola.petActor
        w:Run(1.81)
        eq(actor.anim, 6, "asleep")
        ola:CloseJournal()
        actor:SetAnimation(0) -- (the client resets the model on the closed card)
        w:Run(1)
        eq(actor.anim, 0)
    end)

    test("online past midnight: the new day's visit comes with the first thing done, or the pet found out", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda")
        w:Run(5)
        local function Visits() return select(3, ola.ns.Activity:Count("day")) end -- (today's)
        eq(Visits(), 1, "the login's visit")
        local d = os.date("*t", w:ServerTime())
        w:Skip((23 - d.hour) * 3600 + (59 - d.min) * 60 + (60 - d.sec) + 60) -- 00:01, still online
        eq(Visits(), 0, "nothing yet")
        ola:Fire("QUEST_TURNED_IN", 1)
        eq(Visits(), 1, "the visit came with the quest")
        ok(ola.ns.Bond:Today(PANDA) > 1, "and its points")
        -- Another night: auto-summon finding the pet back out (a loading screen) brings it too.
        w:SkipDays(1)
        eq(Visits(), 0)
        ola:Fire("PLAYER_ENTERING_WORLD")
        w:Run(4)
        eq(Visits(), 1)
    end)

    test("a corpse run longer than a minute: the pet comes back once you're alive", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda")
        w:Run(5)
        ola:Set("dead", true); ola:Summon(nil); ola:Fire("PLAYER_DEAD")
        ola:Fire("PLAYER_ALIVE") -- (released: a ghost, still dead)
        w:Run(90)
        eq(ola.summoned, nil, "the retries gave up")
        ola:Set("dead", false); ola:Fire("PLAYER_UNGHOST")
        w:Run(3)
        ok(ola.summoned, "back out")
    end)
end
