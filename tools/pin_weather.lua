-- Pins every species' weather likes and dislikes in Data/WeatherPins.lua (luajit tools/pin_weather.lua, from the
-- addon's folder).
--
-- The weather (2026-11-22, the user): rain, snow and sandstorms as likes and dislikes, from traits and families
-- (Personality.WEATHER), only where a species has room at level 7 (6 likes, 3 dislikes). That room depends on the
-- species' other likes and dislikes, so it's worked out once and pinned, as the traits and Data/Unlocks.lua are: a
-- like seen on a card never goes away when something else is added later (the side agent's review, the same day).
-- This keeps every line already in the file and only adds species that aren't pinned yet (Personality:WeatherRoom,
-- in the harness, as the game reads it). Edit a line by hand to change a species. {}: none.
--
-- A value is "act" (a family's) or "act:trait" (a trait's: only while the pet has that trait, the third from level
-- 7); "+" a like, "-" a dislike.
package.path = "tools/test/?.lua;" .. package.path
local H = dofile("tools/test/harness.lua")

local w = H.World()
local c = w:AddClient("Pin Weather", { pets = { 40 }, debug = false })
local ns = c.ns
local P = ns.Personality

local pins = {}
if io.open("Data/WeatherPins.lua") then
    local chunk = assert(loadfile("Data/WeatherPins.lua"))
    local old = {}
    chunk("Dyreparken", old)
    pins = old.WeatherPins or {}
end
P.WEATHER_PINS = {} -- (every species from the rules: the new ones' picks)

local names = {}
for line in io.lines("Data/Companions.lua") do
    local sid, name = line:match("^%s*%[(%d+)%] = .*%-%- (.+)$")
    if sid then names[tonumber(sid)] = name end
end

local ids, added = {}, 0
for sid in pairs(ns.Companions.species) do ids[#ids + 1] = sid end
table.sort(ids)
for _, sid in ipairs(ids) do
    if not pins[sid] then
        local likes, dislikes = P:WeatherRoom("s:" .. sid)
        local pin = {}
        for _, x in ipairs(likes) do pin[#pin + 1] = "+" .. x[1] .. (x[2] and (":" .. x[2]) or "") end
        for _, x in ipairs(dislikes) do pin[#pin + 1] = "-" .. x[1] .. (x[2] and (":" .. x[2]) or "") end
        pins[sid] = pin
        added = added + 1
    end
end

local out = { [[---@class Dyreparken
local ns = select(2, ...)

-- Every species' weather likes and dislikes (Menagerie/Personality.lua's WEATHER, Menagerie/Weather.lua's rain, snow
-- and sand), pinned: only where the species had room at level 7 when it was pinned, and kept for good, like
-- Data/Traits.lua and Data/Unlocks.lua (2026-11-22). New species are added by tools/pin_weather.lua, which never
-- changes a line that's here. Edit a line by hand to change a species. "+" a like, "-" a dislike; "act:trait" only
-- while the pet has that trait. {}: none.
ns.WeatherPins = {]] }
for _, sid in ipairs(ids) do
    local q = {}
    for _, v in ipairs(pins[sid]) do q[#q + 1] = '"' .. v .. '"' end
    out[#out + 1] = ("    [%d] = { %s }, -- %s"):format(sid, table.concat(q, ", "), names[sid] or "?"):gsub("{  }", "{}")
end
out[#out + 1] = "}\n"
local f = assert(io.open("Data/WeatherPins.lua", "w"))
f:write(table.concat(out, "\n"))
f:close()
print(("Data/WeatherPins.lua: %d species, %d added"):format(#ids, added))
