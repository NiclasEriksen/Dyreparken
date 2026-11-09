-- Auto-summon: triggers, idle checks, retries, and staying out of the way.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- A client with Panda Cub reserved and no pet out. opts go to AddClient.
    local function Reserved(opts)
        opts = opts or {}
        opts.pets = opts.pets or { 5159, 46 }
        opts.summoned = false
        local w = H.World()
        local c = w:AddClient("Ola Nord", opts)
        w:Run(26) -- past the login timers (hello, roster fallback)
        return w, c
    end

    local function Claimed(opts)
        local w, c = Reserved(opts)
        c:Slash("adopter panda")
        return w, c
    end

    local PANDA_GUID = function(c) return c:GuidOf(5159) end

    test("claiming brings the pet out", function()
        local w, c = Claimed()
        eq(c.summonCalls, 1)
        eq(c.summoned, PANDA_GUID(c))
        w:Run(10)
        eq(c.summonCalls, 1, "verified, no more calls")
    end)

    test("triggers: loading screen, leaving combat, dismounting", function()
        local w, c = Claimed()
        w:Run(4) -- past the check 3 s after summoning
        c:Summon(nil) -- dismissed (by hand or by the game)
        w:Run(30)
        eq(c.summoned, nil, "a dismissed pet isn't noticed on its own (no COMPANION_UPDATE)")
        c:Zone()
        w:Run(2.9)
        eq(c.summoned, nil, "waits for the world to settle")
        w:Run(0.2)
        eq(c.summoned, PANDA_GUID(c), "after a loading screen")
        c:Summon(nil)
        c:EnterCombat()
        c:LeaveCombat()
        eq(c.summoned, PANDA_GUID(c), "after combat")
        c:Summon(nil)
        c:Mount()
        w:Run(2)
        eq(c.summoned, nil, "not while mounted")
        c:Dismount()
        w:Run(1.6)
        eq(c.summoned, PANDA_GUID(c), "after dismounting")
    end)

    test("each busy state blocks the summon, and it follows once idle", function()
        local cases = {
            { "combat", true, "combat" }, { "dead", true, "dead" }, { "mounted", true, "mounted" },
            { "taxi", true, "taxi" }, { "flying", true, "flying" }, { "stealthed", true, "stealthed" },
            { "casting", "Fishing", "casting" }, { "channeling", "Drain Life", "casting" },
            { "stand", 1, "sitting" }, { "stand", 3, "sitting" },
        }
        for _, case in ipairs(cases) do
            local key, value, reason = case[1], case[2], case[3]
            local w, c = Reserved()
            c:Set(key, value)
            eq(c.ns.Summon.Busy(), reason, key)
            c:Slash("adopter panda")
            eq(c.summonCalls, 0, key .. " blocks")
            c:Set(key, key == "stand" and 0 or nil)
            w:Run(3.1)
            eq(c.summoned, PANDA_GUID(c), key .. " then idle")
        end
    end)

    test("standing (0) and kneeling-up (7) count as standing", function()
        local w, c = Reserved()
        c:Set("stand", 7)
        eq(c.ns.Summon.Busy(), nil)
    end)

    test("eating or drinking blocks, in the client's language too", function()
        local w, c = Reserved()
        c.state.spellNames = { [433] = "Essen", [430] = "" }
        c.state.auras.Essen = true
        eq(c.ns.Summon.Busy(), "eating", "localized name")
        c.state.auras = { Drink = true }
        eq(c.ns.Summon.Busy(), "eating", "English fallback")
        c.state.auras = {}
        eq(c.ns.Summon.Busy(), nil)
        c.state.aurasError = true
        eq(c.ns.Summon.Busy(), "eating", "an unreadable answer counts as busy")
        c.state.aurasError = nil
        c.state.secretAuras = true
        eq(c.ns.Summon.Busy(), "eating", "secret auras count as busy")
    end)

    test("secret values count as busy", function()
        local w, c = Reserved()
        c:Set("mounted", H.SECRET)
        eq(c.ns.Summon.Busy(), "mounted")
    end)

    test("without aura, flying, stealth or stand APIs, those checks are skipped", function()
        local w, c = Reserved({ patch = function(env)
            env.C_UnitAuras, env.IsFlying, env.IsStealthed, env.UnitStandState = nil, nil, nil, nil
        end })
        c:Set("flying", true); c:Set("stealthed", true); c:Set("stand", 1)
        eq(c.ns.Summon.Busy(), nil)
        c:Slash("adopter panda")
        eq(c.summoned, PANDA_GUID(c))
    end)

    test("a stand state that isn't a number is ignored", function()
        local w, c = Reserved({ patch = function(env) env.UnitStandState = function() error("no unit") end end })
        eq(c.ns.Summon.Busy(), nil)
    end)

    test("battlegrounds and arenas: no summon and no polling", function()
        for _, kind in ipairs({ "pvp", "arena" }) do
            local w, c = Reserved()
            c:Set("instance", kind)
            c:Slash("adopter panda")
            c:Set("instance", "none")
            w:Run(10)
            eq(c.summonCalls, 0, kind)
        end
    end)

    test("busy for over a minute: stops retrying until the next trigger", function()
        local w, c = Reserved()
        c:Set("casting", "Fishing")
        c:Slash("adopter panda")
        w:Run(61)
        c:Set("casting", nil)
        w:Run(10)
        eq(c.summonCalls, 0)
        c:LeaveCombat()
        eq(c.summonCalls, 1)
    end)

    test("several triggers while busy share one retry", function()
        local w, c = Reserved()
        c:Set("casting", "Fishing")
        c:Slash("adopter panda")
        c:Zone(); c:LeaveCombat(); c:Dismount()
        w:Run(5.5) -- past the guild achievements' 5 s debounce after claiming (not a summon timer)
        local pending = 0
        for _, t in ipairs(w.timers) do if t.client == c then pending = pending + 1 end end
        ok(pending <= 1, "at most one timer, got " .. pending)
        c:Set("casting", nil)
        w:Run(4)
        eq(c.summonCalls, 1)
    end)

    test("the companion cooldown: a failed call is retried", function()
        local w, c = Reserved()
        c.summonFails = 1
        c:Slash("adopter panda")
        eq(c.summoned, nil)
        w:Run(3.1)
        eq(c.summonCalls, 2)
        eq(c.summoned, PANDA_GUID(c))
    end)

    test("gives up after 3 calls per trigger", function()
        local w, c = Reserved()
        c.summonFails = 99
        c:Slash("adopter panda")
        w:Run(70)
        eq(c.summonCalls, 3)
        eq(#c:Log("giving up on s:5159 after 3 attempts"), 1)
        c:LeaveCombat()
        w:Run(10)
        eq(c.summonCalls, 6, "a new trigger tries again")
    end)

    test("a pet you summoned yourself is left alone", function()
        local w, c = Claimed()
        c:Summon(46)
        c:Zone(); c:LeaveCombat()
        w:Run(10)
        eq(c.summoned, c:GuidOf(46))
        eq(c.summonCalls, 1)
    end)

    test("nothing to summon without a reservation, or without the pet", function()
        local w, c = Reserved()
        c:Zone()
        w:Run(5)
        eq(c.summonCalls, 0, "no reservation")
        c:Slash("adopter panda")
        c:Summon(nil)
        table.remove(c.pets, 1) -- the pet is gone from the journal
        c:Zone()
        w:Run(5)
        eq(c.summonCalls, 1)
    end)

    test("the checkbox turns it off and on (on summons right away)", function()
        local w, c = Claimed()
        c:Summon(nil)
        c.ns.Summon:SetEnabled(false)
        no(c.ns.Summon:Enabled())
        c:Zone()
        w:Run(5)
        eq(c.summoned, nil)
        c.ns.Summon:SetEnabled(true)
        eq(c.summoned, PANDA_GUID(c))
    end)

    test("AutoCompanion takes over: no summoning, one notice", function()
        local w, c = Reserved({ addons = { "AutoCompanion" } })
        ok(c.ns.Summon:Deferring())
        no(c.ns.Summon:Enabled())
        ok(c:Printed("AutoCompanion er lastet, så Dyreparken tilkaller ikke automatisk."))
        c:Slash("adopter panda")
        c:Zone()
        w:Run(5)
        eq(c.summonCalls, 0)
        c.env.DyreparkenCharDB.autoSummon = false
        c:ClearPrinted()
        c:Reload()
        w:Run(26)
        no(c:Printed("AutoCompanion is loaded"), "no notice when it's off anyway")
    end)

    test("summoning mutes the summon sounds for a moment", function()
        local w, c = Reserved()
        no(next(c.muted), "nothing muted before a summon")
        c:Slash("adopter panda")
        ok(c.muted[567569] and c.muted[568424])
        w:Run(2)
        ok(c.muted[567569], "still muted while the answer arrives")
        w:Run(1)
        no(next(c.muted), "unmuted after the window")
        -- A summon from the journal (or another addon) is quiet too, and a
        -- second call extends the window.
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(46))
        w:Run(2)
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(46))
        w:Run(2)
        ok(c.muted[567569], "extended by the second call")
        w:Run(1)
        no(next(c.muted))
        c:Reload()
        no(next(c.muted), "the client forgets mutes on reload")
    end)

    test("/dp sound turns the mute off and on (per character)", function()
        local w, c = Reserved()
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(46))
        ok(c.muted[567569])
        c:Slash("lyd")
        ok(c:Printed("Summonlyden er på."))
        eq(c.env.DyreparkenCharDB.muteSummonSound, false)
        no(next(c.muted), "unmuted right away")
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(46))
        no(next(c.muted))
        w:Run(3)
        c:Slash("lyd av")
        ok(c:Printed("Summonlyden er dempet."))
        c:Slash("lyd av")
        eq(c.env.DyreparkenCharDB.muteSummonSound, true)
        c:Slash("lyd på")
        eq(c.env.DyreparkenCharDB.muteSummonSound, false)
        c:Slash("lyd av")
        eq(c.env.DyreparkenCharDB.muteSummonSound, true, "the Norwegian words work too")
        c:Slash("lyd på")
        eq(c.env.DyreparkenCharDB.muteSummonSound, false)
        c:Reload()
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(46))
        no(next(c.muted), "the setting is saved")
    end)

    test("with AutoCompanion loaded, its own mute option is used", function()
        local w, c = Reserved({ addons = { "AutoCompanion" } })
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(46))
        no(next(c.muted))
        c:Slash("lyd av")
        ok(c:Printed("Mute summoning sounds", true))
    end)
end
