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
        no(c:Printed("PARTY_KILL", true), "dropped: its GUIDs are secret")
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

    test("the traits probe: events, emotes, jumps and casts with their context, only while debugging", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg")
        w:Run(12)
        ok(Listening(c, "PLAYER_DEAD")); ok(Listening(c, "MIRROR_TIMER_START"))
        c.state.zone, c.state.resting, c.state.afk = "Stormwind City", true, true
        c:Fire("PLAYER_DEAD")
        eq(#c:Log("PLAYER_DEAD %(%) | zone=Stormwind City map=1429 instance=%[false, none%] resting=true afk=true "
            .. "group=solo level=10 time=%d%d:%d%d pet=s:5159"), 1)
        c:Fire("MIRROR_TIMER_START", "BREATH", 60, 60, -1, false, "Breath")
        eq(#c:Log("MIRROR_TIMER_START %(BREATH, 60"), 1)
        -- Guildmates in the group are counted.
        w:SetGroup({ "Ola Nord", "Kari Berg", "Per Ukjent" })
        c:Fire("GROUP_ROSTER_UPDATE")
        eq(#c:Log("GROUP_ROSTER_UPDATE %(%) | .* group=3 %(guildmates 1%)"), 1)
        -- Chat: the sender, never the text; emotes only our own.
        c:Fire("CHAT_MSG_GUILD", "hemmelig", "Kari Berg", "", "", "", "", 0, 0, "", 0, 1, "Player-0000-00000002")
        eq(#c:Log("CHAT_MSG_GUILD sender=Kari Berg own=false"), 1)
        eq(#c:Log("hemmelig"), 0)
        c:Fire("CHAT_MSG_TEXT_EMOTE", "You dance.", "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, c.env.UnitGUID("player"))
        c:Fire("CHAT_MSG_TEXT_EMOTE", "Kari dances.", "Kari Berg", "", "", "", "", 0, 0, "", 0, 1, H.SECRET)
        eq(#c:Log("CHAT_MSG_TEXT_EMOTE %(You dance.%)"), 1)
        eq(#c:Log("Kari dances"), 0)
        c.env.DoEmote("DANCE")
        eq(#c:Log("DoEmote %(DANCE, nil%) | zone="), 1)
        for _ = 1, 3 do c.env.JumpOrAscendStart() end
        eq(#c:Log("jump #1 swimming=false"), 1)
        eq(#c:Log("jump #"), 1, "one line per 5 s")
        w:Run(6)
        c.env.JumpOrAscendStart()
        eq(#c:Log("jump #4"), 1)
        c.state.spellNames = { [8690] = "Hearthstone" }
        c:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 8690)
        eq(#c:Log("cast 8690 Hearthstone combat=false"), 1)
        -- Off: the events are let go.
        c:Slash("debug off")
        no(Listening(c, "PLAYER_DEAD"))
        no(c.ns.Kills._unitFrame.events.UNIT_SPELLCAST_SUCCEEDED)
        -- Missing and failing APIs are named, not fatal.
        c.env.IsResting, c.env.UnitIsAFK = nil, function() error("nope") end
        c.env.C_Map = nil
        match(c.ns.Kills:Context(), "map=missing .* resting=missing afk=error")
    end)

    test("/dp probe life: which events and functions exist, and the context", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(12)
        c:Slash("probe life")
        ok(c:Printed("PLAYER_DEAD=true", true)); ok(c:Printed("DoEmote=true", true))
        ok(c:Printed("zone=Elwynn Forest", true)); ok(c:Printed("debug log on (listening)", true))
        c:Slash("debug off")
        c.env.C_EventUtils, c.env.GetNumGroupMembers = nil, nil
        c:Slash("probe life")
        ok(c:Printed("PLAYER_DEAD=?", true)); ok(c:Printed("group=missing", true))
        ok(c:Printed("OFF: /dp debug on", true))
    end)
end
