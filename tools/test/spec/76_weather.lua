-- The weather (Menagerie/Weather.lua, 2026-11-22, 0.10.0): read as it turns (WEATHER_CHANGED), at a zone change and a
-- loading screen; rain, snow or a sandstorm starting is a moment: the activity, and the pet's line by its nature.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    local function Setup(traits, family)
        local w, ola = H.Setup{ ola = { 5159 } }
        if family then ola:Companions{ [5159] = { a = true, t = { family } } } end
        ola:Traits(traits or { "glupsk", "rampete" })
        ola:Slash("adopter panda"); w:Run(5)
        ola:Dice(0); ola:QuirksNow()
        local fired = {}
        ola.ns.Bus:On("WEATHER", function(kind, old) fired[#fired + 1] = kind .. "<" .. tostring(old) end)
        return w, ola, fired
    end

    test("rain starting: the moment once, its activity, a line by nature; the same rain again is nothing new", function()
        local w, ola, fired = Setup()
        local W, A = ola.ns.Weather, ola.ns.Activity
        eq(W:Now(), "clear")
        ola:Weather(1, 0.94); w:RunTimers()
        eq(table.concat(fired, " "), "rain<clear")
        eq((A:Count("rain")), 1)
        ok(ola:PrintedLine("egg.regn", { pet = "Panda Cub" }), "a line")
        -- Out of it and back in (another subzone, a reload): not new for half an hour.
        ola:Weather(0); ola:Weather(1)
        eq(#fired, 1)
        ola:Reload(); w:Settle("hello")
        eq(ola.ns.Weather:Now(), "rain", "read at login")
        ola:Weather(0)
        w:Run(ola.ns.Weather.AGAIN + 1)
        ola:Weather(1)
        eq((ola.ns.Activity:Count("rain")), 2, "half an hour on: new again")
    end)

    test("not under a roof, nor a drizzle; snow and sand are their own; WEATHER_CHANGED reads it; nothing polls", function()
        local w, ola, fired = Setup()
        ola:Weather(1, 0.9, true)
        eq(#fired, 0, "indoors: sheltered")
        ola:Weather(1, 0.1)
        eq(#fired, 0, "a drizzle")
        ola:Weather(2, 0.5)
        eq(fired[1], "snow<clear")
        -- Turned with no event: unseen until one comes (no timer, no read at an activity).
        ola.state.weather = { 3, 0.8 }
        ola.ns.Activity:Emit("herb"); w:Run(600)
        eq(#fired, 1, "nothing polls")
        ola:Fire("WEATHER_CHANGED") -- (as the client does when it turns: no payload)
        eq(fired[2], "sand<snow")
        ola.state.weather = { 0, 0 }
        ola:Fire("WEATHER_CHANGED")
        eq(ola.ns.Weather:Now(), "clear")
    end)

    test("no pet out (a flight path, a mount): nothing noted; a pet out again reads it, so landing in rain counts", function()
        local w, ola, fired = Setup()
        ola:Summon(nil)
        ola:Weather(3, 0.6) -- (Tanaris from the flight path)
        eq(#fired, 0); eq(ola.ns.Weather:Now(), "clear", "not even noted")
        ola:Weather(1, 0.8) -- (and the Barrens)
        eq(#fired, 0)
        ola:Summon(5159); ola.ns.Bus:Fire("PET_OUT", "s:5159") -- (landed: the pet back)
        eq(table.concat(fired, " "), "rain<clear")
        -- A summon by hand reads it too.
        ola:Summon(nil); ola:Weather(2, 0.5)
        eq(#fired, 1)
        ola.env.C_PetJournal.SummonPetByGUID(ola:GuidOf(5159)); w:Run(3) -- (it toggles: none out, so out)
        eq(fired[2], "snow<rain")
    end)

    test("a cat in the rain minds it, a Solelsker snow: only their own lines", function()
        local w, ola = Setup(nil, "cat")
        ola:Weather(1); w:RunTimers()
        ok(ola:PrintedLine("egg.regn.cat", { pet = "Panda Cub" }), "the cat's")
        local w2, kari = Setup({ "solelsker", "glupsk" })
        kari:Weather(2); w2:RunTimers()
        ok(kari:PrintedLine("egg.snofall.solelsker", { pet = "Panda Cub" }), "a Solelsker in snow: its own")
    end)
    test("logging in to rain is no moment: noted, so its end and the next rain are", function()
        local w, ola = Setup()
        local function Rains() return (ola.ns.Activity:Count("rain")) end
        ola:Weather(1, 0.9)
        eq(Rains(), 1)
        ola:Logout(); w:Skip(ola.ns.Weather.AGAIN + 60); ola:Login(); w:Settle("hello")
        eq(ola.ns.Weather:Now(), "rain", "read at login")
        eq(Rains(), 1, "already raining: not starting")
        ola:Weather(0); w:Run(ola.ns.Weather.AGAIN + 1); ola:Weather(1)
        eq(Rains(), 2, "a new rain after it")
    end)
end
