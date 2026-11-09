-- The research probes (Achievements/Kills.lua): honorable kills, logged
-- while the debug log is on; /dp probe kills and life.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Listening(c, event)
        for _, f in ipairs(c.frames) do if f.events[event] then return true end end
        return false
    end

    test("PvP kills: logged with the counters while the debug log is on, idle otherwise", function()
        local w, c = H.Setup{ ola = { 5159 }, settle = "hello" }
        ok(c.ns.Debug.enabled, "the harness logs by default")
        c.state.hk, c.state.honor, c.state.lifetimeHK = 3, 45, 120
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(#c:Log("PLAYER_PVP_KILLS_CHANGED %(%) combat=false pet=s:5159 %(Panda Cub%) pvp session=%[3, 45, nil%] "
            .. "lifetime=%[120, 0, nil%]"), 1)
        c.env.GetPVPLifetimeStats = nil
        c.env.GetPVPSessionStats = function() error("nope") end
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(#c:Log("session=%[error%] lifetime=%[missing%]"), 1)
        c:Slash("debug off")
        -- (the activity engine's pvp source may still want it for the bond)
        c.ns.Kills:Sync(false)
        local before = #c:Log("PLAYER_PVP_KILLS_CHANGED %(")
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(#c:Log("PLAYER_PVP_KILLS_CHANGED %("), before, "idle with the log off")
    end)

    test("the companion as the client reports it", function()
        local w, c = H.Setup{ ola = { 5159 }, settle = "hello" }
        match(c.ns.Kills:PetState(), "^s:5159 %(Panda Cub%)")
        c.summoned = nil
        eq(c.ns.Kills:PetState(), "none")
        c.summoned = H.SECRET
        eq(c.ns.Kills:PetState(), "<secret>")
        c.env.C_PetJournal.GetSummonedPetGUID = function() error("locked") end
        match(c.ns.Kills:PetState(), "^error: ")
    end)

    test("/dp probe kills: which events exist, the stats, the companion", function()
        local w, c = H.Setup{ ola = {}, settle = "hello" }
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

    test("/dp probe life: which events, functions and formats exist, and the context", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 } })
        w:AddClient("Kari Berg")
        w:Settle("hello")
        c:Slash("probe life")
        ok(c:Printed("PLAYER_DEAD=true", true)); ok(c:Printed("CHAT_MSG_SKILL=true", true))
        ok(c:Printed("JumpOrAscendStart=true", true))
        ok(c:Printed("SKILL_RANK_UP=Your skill in %s has increased to %d.", true))
        ok(c:Printed("zone=Elwynn Forest", true)); ok(c:Printed("debug log on (listening)", true))
        -- The context: guildmates in the group are counted.
        c.state.zone, c.state.resting, c.state.afk = "Stormwind City", true, true
        w:SetGroup({ "Ola Nord", "Kari Berg", "Per Ukjent" })
        match(c.ns.Kills:Context(), "^zone=Stormwind City map=1429 instance=%[false, none%] resting=true afk=true "
            .. "group=3 %(guildmates 1%) level=10 time=%d%d:%d%d pet=s:5159")
        -- Missing and failing APIs are named, not fatal.
        c:Slash("debug off")
        c.env.C_EventUtils, c.env.GetNumGroupMembers = nil, nil
        c.env.IsResting, c.env.UnitIsAFK, c.env.C_Map = nil, function() error("nope") end, nil
        c:Slash("probe life")
        ok(c:Printed("PLAYER_DEAD=?", true)); ok(c:Printed("group=missing", true))
        ok(c:Printed("OFF: /dp debug on", true))
        match(c.ns.Kills:Context(), "map=missing .* resting=missing afk=error")
    end)

    local function MarkOf(c, plate)
        for _, f in ipairs(c.frames) do if f.parent == plate then return f end end
    end

    test("/dp probe world: nameplate settings read, companions' plates listed and marked", function()
        local w, c = H.Setup{ ola = { 5159 }, settle = "hello" }
        c.cvars = { nameplateShowFriendlyNPCs = "0" }
        local pet, plate = c:Nameplate{ species = 40, owner = "Kari Berg" }
        local npc, npcPlate = c:Nameplate{ name = "Guard Thomas", companion = false }
        local hidden = c:Nameplate{ species = 70, forbidden = true }
        c:Slash("probe world")
        ok(c:Printed("NAME_PLATE_UNIT_ADDED=true", true))
        ok(c:Printed("nameplateShowFriendlyNPCs=0", true))
        ok(c:Printed("plates=3", true))
        eq(c.cvars.nameplateShowFriendlyNPCs, "0", "read, never changed")
        match(c:Printed("world 1:", true), "nameplate1 name=Bombay Cat companion=true species=40 owner=Kari Berg "
            .. "plate=yes shown=true marked")
        no(c:Printed("Guard Thomas", true), "only the companions in the chat")
        eq(#c:Log("world 2: nameplate2 name=Guard Thomas companion=false"), 1, "... all in the log")
        local mark = MarkOf(c, plate)
        ok(mark and mark:IsShown(), "a heart over the companion")
        no(MarkOf(c, npcPlate), "none over a guard")
        w:Run(9)
        no(mark:IsShown(), "gone again")
        c:Slash("probe world")
        local n = 0
        for _, f in ipairs(c.frames) do if f.parent == plate then n = n + 1 end end
        eq(n, 1, "the heart is reused")
        ok(mark:IsShown())
        -- No nameplate API at all: said, not fatal.
        c.env.C_NamePlate = nil
        c:Slash("probe world")
        ok(c:Printed("plates=missing", true))
    end)

    test("the world while the debug log is on: plates coming up, companions under the mouse", function()
        local w, c = H.Setup{ ola = { 5159 }, settle = "hello" }
        local unit = c:Nameplate{ species = 40, owner = "Kari Berg" }
        eq(#c:Log("NAME_PLATE_UNIT_ADDED " .. unit .. " name=Bombay Cat companion=true species=40 owner=Kari Berg "
            .. "plate=yes shown=true marked instance=%[false, none%]"), 1)
        c:Nameplate{ species = 70, forbidden = true }
        eq(#c:Log("FORBIDDEN_NAME_PLATE_UNIT_ADDED nameplate2 .* plate=forbidden instance"), 1)
        c:Fire("NAME_PLATE_UNIT_REMOVED", unit)
        eq(#c:Log("NAME_PLATE_UNIT_REMOVED " .. unit), 1)
        c.cursor = { 640, 360 }
        c:Hover{ species = 40, owner = "Kari Berg" }
        c:Fire("UPDATE_MOUSEOVER_UNIT")
        eq(#c:Log("UPDATE_MOUSEOVER_UNIT mouseover name=Bombay Cat .* plate=nil cursor=640,360"), 1)
        c:Hover{ species = 40, companion = false }
        c:Fire("UPDATE_MOUSEOVER_UNIT")
        eq(#c:Log("UPDATE_MOUSEOVER_UNIT"), 1, "only companions")
        c:Slash("debug off")
        c:Nameplate{ species = 40 }
        eq(#c:Log("NAME_PLATE_UNIT_ADDED nameplate3"), 0, "idle with the log off")
    end)
end
