-- The traits' activities (Core/Activity.lua, probed 2026-11-08): emotes,
-- guild chat, diving, levels, dying, naps, the hearthstone, jumping and new
-- places; and how the bond watches them only for a pet that likes them.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        w:Run(40)
        return w, ola, ola.ns.Activity
    end

    -- Chat events: (text, sender, ... 10 more, guid).
    local function Chat(c, event, text, guid)
        c:Fire(event, text, "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, guid)
    end

    test("emotes: dancing counts, petting counts only when it names the companion out; only our own", function()
        local w, ola, A = Setup()
        local me = ola.env.UnitGUID("player")
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You burst into dance.", me)
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You dance with Panda Cub.", me)
        eq(A:Count("dance"), 2)
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "Kari dances with you.", "Player-0000-00000099")
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You dance.", H.SECRET)
        eq(A:Count("dance"), 2, "someone else's, or one we can't read")
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You pet Panda Cub.", me)
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You hug Panda Cub.", me)
        eq(A:Count("cuddle"), 2)
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You need to be petted.", me)
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You hug Kari.", me)
        eq(A:Count("cuddle"), 2, "not the companion")
        ola.summoned = nil
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You pet Panda Cub.", me)
        eq(A:Count("cuddle"), 2, "no companion out")
        eq(A.EmoteKind(H.SECRET), nil)
        eq(A.EmoteKind("You wave."), nil)
    end)

    test("guild chat: our own lines, never the text", function()
        local w, ola, A = Setup()
        Chat(ola, "CHAT_MSG_GUILD", "hei", ola.env.UnitGUID("player"))
        Chat(ola, "CHAT_MSG_GUILD", "hei", "Player-0000-00000099")
        eq(A:Count("chat"), 1)
        eq(#ola:Log("Activity\tchat.*hei"), 0)
    end)

    test("diving, levels, the hearthstone and jumping", function()
        local w, ola, A = Setup()
        ola:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
        ola:Fire("MIRROR_TIMER_START", "BREATH", 52506, 60000, 10, 0, "Breath")
        ola:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
        eq(A:Count("dive"), 1, "refills and new breaths within a minute are the same dive")
        w:Run(61)
        ola:Fire("MIRROR_TIMER_START", "BREATH", 52506, 60000, 10, 0, "Breath")
        eq(A:Count("dive"), 1, "the breath filling back up isn't a dive")
        ola:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
        ola:Fire("MIRROR_TIMER_START", "EXHAUSTION", 60000, 60000, -1, 0, "Fatigue")
        eq(A:Count("dive"), 2)
        ola:Fire("PLAYER_LEVEL_UP", 28, 29, 47, 1, 0)
        eq(A:Count("level"), 1)
        eq(#ola:Log("level %+1 pet=s:5159 mine=false 28"), 1)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 8690)
        ola.state.spellNames = { [99001] = "Hearthstone", [99002] = "Frostbolt" }
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 99001)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 99002)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", H.SECRET)
        eq(A:Count("hearth"), 2)
        for _ = 1, 25 do ola.env.JumpOrAscendStart() end
        eq(A:Count("jump"), 2, "one per ten jumps")
    end)

    test("back on your feet after dying, not after every loading screen", function()
        local w, ola, A = Setup()
        ola:Fire("PLAYER_ALIVE")
        w:Run(12)
        eq(A:Count("revive"), 0, "a loading screen")
        ola:Fire("PLAYER_DEAD")
        ola.state.dead = true
        ola:Fire("PLAYER_ALIVE") -- released: a ghost, still dead
        w:Run(12)
        eq(A:Count("revive"), 0)
        ola.state.dead = false
        ola:Fire("PLAYER_UNGHOST")
        eq(A:Count("revive"), 0, "counted once the companion is back")
        w:Run(12)
        eq(A:Count("revive"), 1)
        ola:Fire("PLAYER_ALIVE")
        w:Run(12)
        eq(A:Count("revive"), 1, "once per death")
    end)

    test("a nap: AFK in a city or an inn", function()
        local w, ola, A = Setup()
        ola.state.afk = true
        ola:Fire("PLAYER_FLAGS_CHANGED", "player")
        eq(A:Count("nap"), 0, "AFK in the wild")
        ola.state.resting = true
        ola:Fire("PLAYER_FLAGS_CHANGED", "party1")
        eq(A:Count("nap"), 0, "someone else's flags never reach us")
        ola:Fire("PLAYER_FLAGS_CHANGED", "player")
        eq(A:Count("nap"), 1)
        ola.state.afk = false
        ola:Fire("PLAYER_FLAGS_CHANGED", "player")
        eq(A:Count("nap"), 1, "coming back isn't another")
    end)

    test("new places: per companion, by map, or by zone name inside instances", function()
        local w, ola, A = Setup()
        local function Zone(map, zone)
            ola.state.map, ola.state.zone = map, zone
            ola:Fire("ZONE_CHANGED_NEW_AREA")
            w:Run(6)
        end
        Zone(1454, "Orgrimmar")
        eq(A:Count("explore"), 1)
        Zone(1437, "Wetlands")
        Zone(1454, "Orgrimmar")
        eq(A:Count("explore"), 2, "been there")
        ok(ola.ns.DB.char.places[PANDA].m1454)
        -- Inside an instance C_Map has no map: the zone's name it is.
        ola.env.C_Map.GetBestMapForUnit = function() return nil end
        Zone(nil, "Excavation Site: Wetlands")
        ok(ola.ns.DB.char.places[PANDA]["zExcavation Site: Wetlands"])
        eq(A:Count("explore"), 3)
        -- Another companion hasn't been anywhere yet.
        ola:Summon(40)
        Zone(nil, "Excavation Site: Wetlands")
        eq(A:Count("explore"), 4)
        -- No companion out, or nowhere we can name: nothing.
        ola.summoned = nil
        Zone(nil, "Durotar")
        ola:Summon(40)
        Zone(nil, H.SECRET)
        eq(A:Count("explore"), 4)
        -- Kept across a reload.
        ola:Reload()
        w:Run(40)
        ok(ola.ns.DB.char.places[PANDA].m1454)
    end)

    test("the bond watches a trait's activity only for a pet that likes it, and says so", function()
        local w, ola, A = Setup()
        ola:Slash("debug off") -- the debug log wants everything
        ola:Slash("adopter panda")
        w:Run(40)
        local P = ola.ns.Personality
        eq(P:Names(PANDA), "Kosete og Grønnfinger")
        ok(A:IsListening("QUEST_TURNED_IN"))
        no(A:IsListening("CHAT_MSG_TEXT_EMOTE"), "nobody here likes dancing")
        no(A:IsListening("MIRROR_TIMER_START"))
        P.PINNED[5159] = { "dansefot", "kjaelen" }
        ola.ns.Bond:Watch()
        ok(A:IsListening("CHAT_MSG_TEXT_EMOTE"))
        local function Points() local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); return e and e.p or 0 end
        local start = Points()
        Chat(ola, "CHAT_MSG_TEXT_EMOTE", "You dance with Panda Cub.", ola.env.UnitGUID("player"))
        eq(Points(), start + 5)
        ok(ola:Printed("Panda Cub danset med deg!", true))
        eq(P:Line(PANDA), "Dansefot og Kjælen · liker herbs, dansing og kos")
        eq(P:Effect(P.ById("kjaelen")), "/pet, /hug eller /cuddle på kjæledyret gir 5 bånd-poeng (opptil 25 om dagen), mot 1 ellers.")
        -- Letting it go drops them all.
        ola:Slash("gislipp")
        w:Run(5)
        no(A:IsListening("CHAT_MSG_TEXT_EMOTE")); no(A:IsListening("QUEST_TURNED_IN"))
    end)

    test("every trait's activity has a source, a word, and an effect text", function()
        local w, ola, A = Setup()
        local P = ola.ns.Personality
        for _, t in ipairs(P.TRAITS) do
            if t.like then
                ok(A:Available(t.like), t.id .. ": " .. t.like)
                ok(P.NOUN[t.like], t.id)
            end
            match(P:Effect(t), "bånd%-poeng")
        end
    end)
end
