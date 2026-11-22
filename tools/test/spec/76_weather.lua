-- The weather (Menagerie/Weather.lua, 2026-11-22, 0.10.0): read at moments we have (a zone change, a loading screen,
-- an activity), rain, snow or a sandstorm starting is a moment: the activity, and the pet's line by its nature.
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

    test("not under a roof, nor a drizzle; snow and sand are their own; read at an activity, at most every 20 s", function()
        local w, ola, fired = Setup()
        ola:Weather(1, 0.9, true)
        eq(#fired, 0, "indoors: sheltered")
        ola:Weather(1, 0.1)
        eq(#fired, 0, "a drizzle")
        ola:Weather(2, 0.5)
        eq(fired[1], "snow<clear")
        -- No event as it turns: the next activity reads it, not sooner than READ_EVERY after the last read.
        ola.state.weather = { 3, 0.8 }
        ola.ns.Activity:Emit("herb")
        eq(#fired, 1, "read a moment ago")
        w:Run(ola.ns.Weather.READ_EVERY + 1)
        ola.ns.Activity:Emit("herb")
        eq(fired[2], "sand<snow")
        -- WEATHER_CHANGED, should the client fire it: logged, read.
        ola.state.weather = { 0, 0 }
        ola:Fire("WEATHER_CHANGED")
        ok(ola:Log("WEATHER_CHANGED")[1]); eq(ola.ns.Weather:Now(), "clear")
    end)

    test("a cat in the rain minds it, a Solelsker snow: only their own lines", function()
        local w, ola = Setup(nil, "cat")
        ola:Weather(1); w:RunTimers()
        ok(ola:PrintedLine("egg.regn.cat", { pet = "Panda Cub" }), "the cat's")
        local w2, kari = Setup({ "solelsker", "glupsk" })
        kari:Weather(2); w2:RunTimers()
        ok(kari:PrintedLine("egg.snofall.solelsker", { pet = "Panda Cub" }), "a Solelsker in snow: its own")
    end)
end
