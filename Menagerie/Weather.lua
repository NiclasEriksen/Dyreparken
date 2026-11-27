---@class Dyreparken
local ns = select(2, ...)

-- The weather (2026-11-22, 0.10.0, the content review §2.3, the user: "the weather system was reworked in Forever and
-- is now much more dramatic, so it makes sense that the pets react to it"). C_Weather.GetCurrentWeather() returns
-- { type, intensity } (Enum.WeatherType: 0 clear, 1 rain, 2 snow, 3 sandstorm, 4 misc; intensity a fraction, rain
-- read 0.94; docs/FOREVER_API.md). Read at WEATHER_CHANGED (it fires as the weather turns, with no payload: the
-- probe, 2026-11-22, rain ending in Un'Goro), at a zone or subzone change and a loading screen (another zone's
-- weather; whether the event comes with those too isn't known). No polling. (Built first with a read at every
-- activity as well, while the event was unknown: gone once the probe saw it fire.) It fires a moment after you
-- enter a zone with other weather too, sometimes twice (the probe, the same day, a flight across Tanaris and the
-- Barrens): sand read 0.59, rain 0.81.
--
-- Only with a pet out (2026-11-22, the probe: a flight path's zones read with no pet out, and their sandstorm and
-- rain spent the half hour for nothing): without one, nothing is noted, and it's read again when one comes out
-- (a summon, Bus PET_OUT: after a flight or a loading screen), so landing in the rain is still a moment.
--
-- Rain, snow or a sandstorm starting (not under a roof: IsIndoors, nor too light: MIN_INTENSITY) is a moment: Bus
-- WEATHER (kind, old, intensity), the activity of the same name (a pet can like or dislike it) and Quirks' weather
-- eggs. The same kind again within AGAIN seconds isn't new (in and out of a rainy zone, a reload): char.weather.
-- The weather you log in to is only noted (no moment: it didn't start).
---@class Dyreparken.Weather
local Weather = {}
ns.Weather = Weather

Weather.KINDS = { [1] = "rain", [2] = "snow", [3] = "sand" }
Weather.MIN_INTENSITY = 0.2 -- (a guess: a drizzle isn't rain to a pet; rain read 0.94, steady for most of an hour)
Weather.AGAIN = 1800

local now -- the kind read last: "clear", "rain", "snow", "sand" (nil before the first read)

-- The weather here and now: its kind ("clear" for none, misc, a drizzle or a roof) and intensity; nil if unreadable.
function Weather.Read()
    local W = rawget(_G, "C_Weather")
    if not (W and type(W.GetCurrentWeather) == "function") then return nil end
    local ok, r = pcall(W.GetCurrentWeather)
    if not ok or type(r) ~= "table" then return nil end
    local kind, intensity = ns.Plain(r.type), ns.Plain(r.intensity)
    if type(kind) ~= "number" then return nil end
    intensity = type(intensity) == "number" and intensity or 0
    kind = Weather.KINDS[kind]
    if not kind or intensity < Weather.MIN_INTENSITY or ns.Plain(IsIndoors and IsIndoors()) == true then
        return "clear", intensity
    end
    return kind, intensity
end

function Weather:Now() return now end

function Weather:Check(why)
    local kind, intensity = self.Read()
    if not kind or kind == now then return end
    if not ns.Pets:OutKey() then return end -- (read again once one is: Init)
    local old = now
    now = kind
    ns.Log("Weather", "%s -> %s (%.2f, %s)", tostring(old), kind, intensity, why)
    -- Already falling when you log in isn't starting (2026-11-27, the user): the session's first read (at login,
    -- or a pet's first time out after it) is noted, so it ending and another starting are seen, but no moment
    -- ("Det begynner å regne" as you log in read wrong).
    if kind == "clear" or old == nil then return end
    local seen = ns.DB.char.weather or {}
    ns.DB.char.weather = seen
    local t = ns.Now()
    if seen[kind] and t - seen[kind] < self.AGAIN then return end
    seen[kind] = t
    ns.Bus:Fire("WEATHER", kind, old, intensity)
    ns.Activity:Emit(kind, 1)
end

function Weather:Init()
    for _, e in ipairs({ "WEATHER_CHANGED", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD" }) do
        ns.Events:On(e, Weather, function(_, event) Weather:Check(event) end)
    end
    -- A pet out again: a summon (it lands a moment later, as Activity's day check waits too), or back on its own.
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function() C_Timer.After(2, function() Weather:Check("summon") end) end)
    ns.Bus:On("PET_OUT", function() Weather:Check("pet out") end)
    self:Check("login")
end

ns.Start("settled", function() Weather:Init() end)
