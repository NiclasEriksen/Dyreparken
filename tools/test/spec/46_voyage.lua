-- Zeppelins and boats (Menagerie/Voyage.lua, 2026-11-12): a loading screen between two zones a route joins, as
-- /dp probe api transport saw a ride (Grom'gol to Durotar): LOADING_SCREEN_ENABLED, PLAYER_ENTERING_WORLD on the
-- other continent, then ZONE_CHANGED_NEW_AREA with the right zone's name.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    -- (the client's maps, as the probe logged them: zones in their continents)
    local TREE = { [1434] = { 1415, 3 }, [1437] = { 1415, 3 }, [1415] = { 947, 2 },
        [1411] = { 1414, 3 }, [1413] = { 1414, 3 }, [1414] = { 947, 2 }, [1420] = { 1415, 3 },
        [1446] = { 1414, 3 }, [2548] = { 1415, 3 }, [3000] = { 3001, 3 }, [3001] = { 947, 2 }, [1416] = { 1415, 3 } }
    local MAPS = { ["Stranglethorn Vale"] = 1434, ["Wetlands"] = 1437, ["Durotar"] = 1411, ["The Barrens"] = 1413,
        ["Tirisfal Glades"] = 1420, ["Tanaris"] = 1446, ["Riverglades"] = 2548, ["Zephras Isle"] = 3000,
        ["Alterac Mountains"] = 1416 }

    local function Setup(traits)
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        ola:Traits(traits or {})
        local Q = ola.ns.Quirks
        ola:Dice(0)
        ola:QuirksNow()
        ola.state.mapTree = TREE
        ola.state.spellNames = { [8690] = "Hearthstone", [2645] = "Ghost Wolf" }
        return w, ola
    end
    local function At(ola, zone) ola.state.zone, ola.state.map = zone, MAPS[zone] end
    -- A trip through a loading screen, as the client does it.
    local function Trip(w, ola, from, to, opts)
        opts = opts or {}
        At(ola, from)
        if opts.cast then ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", opts.cast) end
        ola.state.mapPos = opts.fromPos
        ola:Fire("LOADING_SCREEN_ENABLED")
        ola.state.map = MAPS[to] -- (the map first; the zone's name a moment later)
        ola.state.mapPos = opts.toPos
        ola:Fire("PLAYER_ENTERING_WORLD", opts.login or false, false)
        ola.state.zone = to
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
    end
    local function N(ola, id) return (ola.ns.Activity:Count(id)) end

    test("a zeppelin: Grom'gol to Durotar; it counts as flying too; the pet's remark by its nature", function()
        local w, ola = Setup({ "skybaren" })
        local taxi = N(ola, "taxi")
        Trip(w, ola, "Stranglethorn Vale", "Durotar")
        eq(N(ola, "zeppelin"), 1)
        eq(N(ola, "taxi") - taxi, 1, "flying: the flight lovers' points, the fearful's grumbles")
        ok(ola:Printed("endelig hjemme i lufta", true), "Skybåren's own line")
        eq(N(ola, "boat"), 0)
    end)

    test("a boat: Booty Bay to Ratchet (Stranglethorn has both: the other end decides); a cat gets seasick", function()
        local w, ola = Setup()
        ola.ns.Scenes.Families = function() return { "cat" } end
        Trip(w, ola, "Stranglethorn Vale", "The Barrens")
        eq(N(ola, "boat"), 1)
        eq(N(ola, "zeppelin"), 0)
        ok(ola:Printed("grønn i fjeset", true))
        Trip(w, ola, "Wetlands", "The Barrens")
        eq(N(ola, "boat"), 1, "no route between those")
        ok(ola:Log("an unknown way between continents: Wetlands at [%d.]+,[%d.]+ %-> The Barrens")[1], "logged, to add")
    end)

    test("Durotar to Stranglethorn is either: Ratchet's boat reads Durotar at sea; the Stranglethorn end decides", function()
        local w, ola = Setup()
        Trip(w, ola, "Durotar", "Stranglethorn Vale", { toPos = { 0.25, 0.85 } })
        eq(N(ola, "boat"), 1, "Ratchet to Booty Bay (the user's ride: a friend's pet said zeppelin lines)")
        eq(N(ola, "zeppelin"), 0)
        ok(ola:Printed("kjenner saltvannet", true) or ola:Printed("baugen og later", true), "a boat's line")
        no(ola:Printed("Så smått alt ser ut", true), "no zeppelin line")
        Trip(w, ola, "Stranglethorn Vale", "Durotar", { fromPos = { 0.2, 0.9 } })
        eq(N(ola, "boat"), 2, "and back from Booty Bay")
        Trip(w, ola, "Durotar", "Stranglethorn Vale", { toPos = { 0.3, 0.3 } })
        eq(N(ola, "zeppelin"), 1, "Orgrimmar to Grom'gol")
        Trip(w, ola, "Stranglethorn Vale", "Durotar", { fromPos = { 0.15, 0.25 } })
        eq(N(ola, "zeppelin"), 2, "and back")
        eq(N(ola, "boat"), 2)
        ok(ola:Log("zeppelin: Stranglethorn Vale at 0.15,0.25 %-> Durotar")[1], "the position is logged")
    end)

    test("no ride: a hearthstone or a portal before, a login or a /reload, the same continent", function()
        local w, ola = Setup()
        Trip(w, ola, "Stranglethorn Vale", "Durotar", { cast = 8690 })
        eq(N(ola, "zeppelin"), 0, "the hearthstone took you there")
        Trip(w, ola, "Stranglethorn Vale", "Durotar", { cast = 2645 })
        eq(N(ola, "zeppelin"), 1, "another spell is no excuse")
        Trip(w, ola, "Durotar", "Stranglethorn Vale", { login = true })
        eq(N(ola, "zeppelin"), 1, "a login")
        Trip(w, ola, "Tirisfal Glades", "Stranglethorn Vale")
        eq(N(ola, "zeppelin"), 2, "Undercity to Grom'gol: one continent, and a loading screen all the same (the user)")
        -- An instance on either side.
        At(ola, "Durotar"); ola.state.instance = "party"
        Trip(w, ola, "Durotar", "Stranglethorn Vale")
        eq(N(ola, "zeppelin"), 2, "an instance: no ride")
        ola.state.instance = "none"
    end)

    test("a pet afraid of flying is afraid on the zeppelin too", function()
        local w, ola = Setup({ "hjemlengsel" }) -- (dislikes flying)
        Trip(w, ola, "Durotar", "Tirisfal Glades")
        ok(ola:Printed("klamrer seg til deg", true))
    end)

    test("Forever's routes: Steamwheedle Port to Riverglades by boat (probed), Zephras Isle's zeppelins either way", function()
        local w, ola = Setup()
        Trip(w, ola, "Tanaris", "Riverglades")
        eq(N(ola, "boat"), 1)
        Trip(w, ola, "Alterac Mountains", "Zephras Isle")
        eq(N(ola, "zeppelin"), 1, "to Zephras Isle, from Dalaran")
        Trip(w, ola, "Zephras Isle", "Durotar")
        eq(N(ola, "zeppelin"), 2, "and back, wherever it lands")
        Trip(w, ola, "Zephras Isle", "Durotar", { cast = 8690 })
        eq(N(ola, "zeppelin"), 2, "a hearthstone off the isle is no ride")
    end)
end
