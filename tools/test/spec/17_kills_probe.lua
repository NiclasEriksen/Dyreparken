-- The boss/PvP kill probe (Achievements/Kills.lua): research only, it
-- listens while the debug log is on and writes what it sees there.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Listening(c, event)
        for _, f in ipairs(c.frames) do if f.events[event] then return true end end
        return false
    end

    test("listens only while the debug log is on", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(12)
        ok(c.ns.Debug.enabled, "the harness logs by default")
        ok(Listening(c, "ENCOUNTER_END")); ok(Listening(c, "PLAYER_PVP_KILLS_CHANGED"))
        eq(#c:Log("unknown event PARTY_KILL"), 1, "an event this client lacks is skipped")
        c:Slash("debug off")
        no(Listening(c, "ENCOUNTER_END"), "idle with the log off")
        no(Listening(c, "BOSS_KILL"))
        c:Slash("debug on")
        ok(Listening(c, "BOSS_KILL"))
    end)

    test("a boss kill logs its payload, the combat state and the companion, and again after combat", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 } })
        w:Run(12)
        c:EnterCombat()
        c:Fire("ENCOUNTER_END", 1084, "Hogger", 1, 5, 1)
        eq(#c:Log("ENCOUNTER_END %(1084, Hogger, 1, 5, 1%) combat=true pet=s:5159 %(Panda Cub%)"), 1)
        c:Fire("BOSS_KILL", 1084, H.SECRET)
        eq(#c:Log("BOSS_KILL %(1084, <secret>%)"), 1, "secret values are named, not touched")
        c:LeaveCombat()
        eq(#c:Log("after ENCOUNTER_END, out of combat: pet=s:5159"), 1)
        eq(#c:Log("after BOSS_KILL, out of combat"), 1)
        c:Fire("ENCOUNTER_START", 1084, "Hogger", 1, 5)
        eq(#c:Log("ENCOUNTER_START"), 1)
        eq(#c:Log("after ENCOUNTER_START"), 0)
        -- The companion as the client reports it.
        c.summoned = nil
        eq(c.ns.Kills:PetState(), "none")
        c.summoned = H.SECRET
        eq(c.ns.Kills:PetState(), "<secret>")
        c.env.C_PetJournal.GetSummonedPetGUID = function() error("locked") end
        match(c.ns.Kills:PetState(), "^error: ")
    end)

    test("PvP kills log the honorable kill counters", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(12)
        c.state.hk, c.state.honor, c.state.lifetimeHK = 3, 45, 120
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(#c:Log("PLAYER_PVP_KILLS_CHANGED pvp session=%[3, 45, nil%] lifetime=%[120, 0, nil%]"), 1)
        c.env.GetPVPLifetimeStats = nil
        c.env.GetPVPSessionStats = function() error("nope") end
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(#c:Log("session=%[error%] lifetime=%[missing%]"), 1)
    end)

    test("/dp probe kills: which events exist, the stats, the companion", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(12)
        c:Slash("probe kills")
        ok(c:Printed("ENCOUNTER_END=true", true))
        ok(c:Printed("PARTY_KILL=false", true))
        ok(c:Printed("QUEST_TURNED_IN=true", true))
        ok(c:Printed("TakeTaxiNode=true", true))
        ok(c:Printed("debug log on (listening)", true))
        c:Slash("debug off")
        c:Slash("probe kills")
        ok(c:Printed("OFF: /dp debug on to listen", true))
        c.env.C_EventUtils = nil
        c:Slash("probe kills")
        ok(c:Printed("ENCOUNTER_END=?", true))
    end)
end
