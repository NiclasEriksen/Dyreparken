---@class Dyreparken
local ns = select(2, ...)

-- The weather (2026-11-22, 0.10.0, the content review §2.3, the user: "the weather system was reworked in Forever and
-- is now much more dramatic, so it makes sense that the pets react to it"). C_Weather.GetCurrentWeather() returns
-- { type, intensity } (Enum.WeatherType: 0 clear, 1 rain, 2 snow, 3 sandstorm, 4 misc; intensity a fraction, rain
-- read 0.94; docs/FOREVER_API.md). Whether WEATHER_CHANGED fires when it turns isn't known yet (an hour of clear
-- weather never fired it), so it's read at moments we have anyway (the user, the same day: "start building it that
-- way, but keep an eye out for probe data later"): a zone or subzone change, a loading screen, and any activity, at
-- most every READ_EVERY seconds; and at WEATHER_CHANGED too, logged ("WEATHER_CHANGED"), so the log tells if it
-- does fire. No polling.
--
-- Rain, snow or a sandstorm starting (not under a roof: IsIndoors, nor too light: MIN_INTENSITY) is a moment: Bus
-- WEATHER (kind, old, intensity), the activity of the same name (a pet can like or dislike it) and Quirks' weather
-- eggs. The same kind again within AGAIN seconds isn't new (in and out of a rainy zone, a reload): char.weather.
---@class Dyreparken.Weather
local Weather = {}
ns.Weather = Weather

Weather.KINDS = { [1] = "rain", [2] = "snow", [3] = "sand" }
Weather.MIN_INTENSITY = 0.2 -- (a guess: a drizzle isn't rain to a pet; rain read 0.94)
Weather.READ_EVERY = 20
Weather.AGAIN = 1800

local now -- the kind read last: "clear", "rain", "snow", "sand" (nil before the first read)
local lastRead = -math.huge

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
    lastRead = GetTime()
    if not kind or kind == now then return end
    local old = now
    now = kind
    ns.Log("Weather", "%s -> %s (%.2f, %s)", tostring(old), kind, intensity, why)
    if kind == "clear" then return end
    local seen = ns.DB.char.weather or {}
    ns.DB.char.weather = seen
    local t = ns.Now()
    if seen[kind] and t - seen[kind] < self.AGAIN then return end
    seen[kind] = t
    ns.Bus:Fire("WEATHER", kind, old, intensity)
    ns.Activity:Emit(kind, 1)
end

function Weather:Init()
    local function On(event) ns.Events:On(event, Weather, function(_, e, ...)
        if e == "WEATHER_CHANGED" then ns.Log("Weather", "WEATHER_CHANGED (%s)", table.concat({ tostring((...)) }, ", ")) end
        Weather:Check(e)
    end) end
    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "PLAYER_ENTERING_WORLD", "WEATHER_CHANGED" }) do On(e) end
    ns.Bus:On("ACTIVITY", function()
        if GetTime() - lastRead >= Weather.READ_EVERY then Weather:Check("activity") end
    end)
    self:Check("login")
end

ns.Start("settled", function() Weather:Init() end)
