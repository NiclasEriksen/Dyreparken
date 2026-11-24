-- /dp probe watch (Dev/Watch.lua, 2026-11-24): the review's in-game questions as session watches, to the debug log.
-- Listening only: nothing summoned or sent; off leaves nothing registered.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Watching(c)
        local n = 0
        for _, w in pairs(c.ns.Watch.W) do
            for _, e in ipairs(w.events) do if c.ns.Events:Has(e[1], w, e[3]) then n = n + 1 end end
        end
        return n
    end

    test("every watch starts, logs its moments, and off leaves nothing listening", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 40 }, kari = { 46 } }
        ola:Summon(5159)
        ola:Slash("probe watch")
        match(ola:Printed("watch: sit: ok", true), "for 60 min")
        ok(ola.env.DyreparkenDebugDB.enabled, "the log turned on")
        local m = w:Mark()

        -- sit: the key toggles our guess, moving stands up; a refused summon's error and the pet after it
        ola.env.SitStandOrDescendStart()
        ok(ola:Log("Watch\tsit sit key: seated now true")[1])
        ola:Fire("UI_ERROR_MESSAGE", 50, ola.env.SPELL_FAILED_NOT_STANDING)
        match(ola:Log("Watch\tsit ui error")[1], "matches SPELL_FAILED_NOT_STANDING.*pet s:5159.*seated 1")
        w:Run(1)
        ok(ola:Log("Watch\tsit ui error %+0.5s: pet s:5159")[1])
        ola:Move()
        ok(ola:Log("Watch\tsit moved: stood up")[1])
        eq(ola.env.DyreparkenDebugDB.watch.errors[ola.env.SPELL_FAILED_NOT_STANDING], 1)
        ola.env.DoEmote("SIT")
        ok(ola:Log("Watch\tsit emote SIT: seated true")[1])

        -- pet: a change after a call is the call's; mounting is logged, and the pet again later
        ola.env.C_PetJournal.SummonPetByGUID(ola:GuidOf(40))
        ola:Summon(40)
        ola:Fire("COMPANION_UPDATE", "CRITTER")
        match(ola:Log("Watch\tpet out s:5159 %-> s:40")[1], "a call's")
        ola:Mount()
        ok(ola:Log("Watch\tpet PLAYER_MOUNT_DISPLAY_CHANGED")[1])
        w:Run(7)
        ok(ola:Log("Watch\tpet PLAYER_MOUNT_DISPLAY_CHANGED %+6s: pet s:40")[1])

        -- craft: only while the window is open
        ola:Fire("UNIT_SPELLCAST_START", "player", "cast-1", 2259)
        no(ola:Log("Watch\tcraft UNIT_SPELLCAST_START")[1], "no window: a cast isn't crafting")
        ola:Fire("TRADE_SKILL_SHOW")
        ola:Fire("UNIT_SPELLCAST_START", "player", "cast-2", 2259)
        ok(ola:Log("Watch\tcraft UNIT_SPELLCAST_START .- %(2259%) window true")[1], "with the spell")

        -- group: a roster change reads every member's range
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        match(ola:Log("Watch\tgroup range %(GROUP_ROSTER_UPDATE%) Kari")[1], "distance² 100, true")

        -- spot: subzones collected per zone
        ola.state.subzone = "Valley of Strength"
        ola:Fire("ZONE_CHANGED")
        ok(ola:Log("Watch\tspot ZONE_CHANGED")[1])
        local subs = ola.env.DyreparkenDebugDB.watch.subzones
        local any
        for _, list in pairs(subs) do if list["Valley of Strength"] then any = true end end
        ok(any, "the subzone kept")

        -- jump: three reads of IsFalling in one line
        ola.env.JumpOrAscendStart()
        w:Run(3)
        match(ola:Log("Watch\tjump falling at")[1], "0.3s 0, 1s 0, 2s 0")

        -- scene: a cutscene, and the pet after it
        ola:Fire("CINEMATIC_START")
        ok(ola:Log("Watch\tscene CINEMATIC_START")[1])

        eq(w:Sent("PLAY", "Ola Nord", m) <= 1, true) -- (Playdate's own, not the watch's)
        ok(Watching(ola) > 0)
        ola:Slash("probe watch off")
        eq(Watching(ola), 0, "every watch's events off")
        ok(ola:Printed("watch: all off", true))
        ola.env.SitStandOrDescendStart()
        no(ola:Log("Watch\tsit sit key: seated now false")[1], "the hooks are quiet once off")
    end)

    test("one watch by name, an unknown one refused, events the client lacks listed, and the hour's end", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("probe watch nonsense")
        match(ola:Printed("watch: no watch", true), "sit craft group")
        eq(Watching(ola), 0)
        ola:Slash("probe watch group")
        match(ola:Printed("watch: group: refused", true), "READY_CHECK")
        ok(ola.ns.Watch.on.group)
        no(ola.ns.Watch.on.sit)
        ola:Slash("probe watch status")
        ok(ola:Printed("watch: on group;", true))
        ola:Slash("probe watch range")
        ok(ola:Log("Watch\tgroup range %(now%): not in a group")[1])
        w:Run(ola.ns.Watch.FOR + 1)
        no(ola.ns.Watch.on.group, "off after the hour")
        eq(Watching(ola), 0)
    end)
end
