-- How often each line fires, and how fast a bond grows, outside the game (2026-11-19, review: a 40% chance
-- rolled at every moment landed on nearly every day, found in game by feel, 38fcb0f). Plays days of a scripted
-- session in a harness client with the real addon: activities at the profile's rates (Activity:Emit), fights
-- every few minutes with the class's casts (what the reactions read), a login a day. Run from the addon folder:
--
--   luajit tools/chatter.lua                                 the Panda Cub, a warrior, 14 days, "regular"
--   luajit tools/chatter.lua --pet 70 --class shaman --days 28 --profile casual --chatter few
--   luajit tools/chatter.lua --traits latsabb,kosete --seed 7 --days 60 --quiet
--   luajit tools/chatter.lua --profile max --set boss=1,quest=2 --days 28
--
-- Profiles: casual (1 h, 4 days a week), regular (2 h every day), grinder (5 h every day), and max (2 h every day at
-- level 60, no gathering: no levels, skill-ups or gathering, fewer new places; review 2026-11-24 Q31: the others are a
-- levelling triple gatherer, so a pace read from them was too fast for most). --set id=rate,...: an hour's rate of
-- activities, over the profile's (RATES below). --quiet: the summary
-- only, no day by day. It prints, per day, the points earned and the bond level, then the days to each level, the
-- lines per played hour, and every line group (a key without its number) with how many times it was said and on
-- what share of the played days. The rates are guesses for a levelling character: RATES below, tune them.
package.path = "tools/test/?.lua;" .. package.path
local args = { ... }
local opt = { pet = 5159, class = "warrior", race = "human", days = 14, profile = "regular", chatter = "normal", seed = 1 }
local i = 1
while i <= #args do
    local a = args[i]
    local function Next() i = i + 1; return args[i] end
    if a == "--pet" then opt.pet = tonumber(Next())
    elseif a == "--class" then opt.class = Next():lower()
    elseif a == "--race" then opt.race = Next():lower()
    elseif a == "--days" then opt.days = tonumber(Next())
    elseif a == "--profile" then opt.profile = Next()
    elseif a == "--chatter" then opt.chatter = Next()
    elseif a == "--traits" then opt.traits = Next()
    elseif a == "--seed" then opt.seed = tonumber(Next())
    elseif a == "--set" then opt.set = Next()
    elseif a == "--quiet" then opt.quiet = true
    elseif a == "-h" or a == "--help" then
        for line in io.lines(arg[0]) do
            if not line:find("^%-%-") then break end
            print((line:gsub("^%-%- ?", "")))
        end
        os.exit(0)
    else
        io.stderr:write("unknown option ", a, " (-h for help)\n"); os.exit(2)
    end
    i = i + 1
end

local PROFILES = {
    casual = { hours = 1, week = { true, false, true, false, true, true, false } },
    regular = { hours = 2, week = { true, true, true, true, true, true, true } },
    grinder = { hours = 5, week = { true, true, true, true, true, true, true } },
    max = { hours = 2, week = { true, true, true, true, true, true, true },
        rates = { level = 0, skill = 0, herb = 0, mine = 0, skin = 0, explore = 0.1, newpath = 0, taxi = 1.2, boss = 1 } },
}
local profile = PROFILES[opt.profile]
if not profile then io.stderr:write("profiles: casual, regular, grinder, max\n"); os.exit(2) end

-- Activities an hour, for a character levelling in the open world with a dungeon now and then (guesses). A
-- "jump" is ten jumps (Core/Sources.lua).
local RATES = {
    quest = 6, gold = 25, explore = 0.6, jump = 8, taxi = 0.8, hearth = 0.4, herb = 3, mine = 3, skin = 3,
    boss = 0.3, level = 0.25, skill = 3, rep = 2, dance = 0.2, fun = 0.3, chat = 6, cuddle = 0.1, revive = 0.15,
    dive = 0.3, nap = 0.1, campnear = 2, campwarm = 0.3, camp = 0.3, rested = 0.1, meet = 0.5, guildpet = 0.3,
    roll = 0.05, hundred = 0.05, epic = 0.05, newpath = 0.2, misses = 0.2, wipe = 0.05, fall = 0.1,
}
for id, rate in pairs(profile.rates or {}) do RATES[id] = rate end
for pair in (opt.set or ""):gmatch("[^,]+") do
    local id, rate = pair:match("^([%w_]+)=([%d%.]+)$")
    if not (id and RATES[id]) then io.stderr:write("--set: unknown activity or rate: ", pair, "\n"); os.exit(2) end
    RATES[id] = tonumber(rate)
end
local FIGHT_EVERY, FIGHT_CASTS = 4, 4 -- a fight every 4 minutes, with 4 of the class's casts

local H = require("harness")
math.randomseed(opt.seed)
local RACES = { human = "Human", dwarf = "Dwarf", nightelf = "NightElf", gnome = "Gnome", orc = "Orc",
    scourge = "Scourge", tauren = "Tauren", troll = "Troll" }
-- (the stub journal knows a few species by name; Data/Companions.lua has every name in a comment)
if not H.SPECIES[opt.pet] then
    for line in io.lines("Data/Companions.lua") do
        local sid, n = line:match("^%s*%[(%d+)%] = .-%-%- (.+)$")
        if tonumber(sid) == opt.pet then H.SPECIES[opt.pet] = n end
    end
end
local name = H.SPECIES[opt.pet] or ("Species " .. opt.pet)

local w = H.World()
local c = w:AddClient("Ola Nord", { pets = { opt.pet }, login = false, realVisit = true })
c.state.class, c.state.race = opt.class:upper(), RACES[opt.race] or opt.race
if opt.traits then
    local list = {}
    for t in opt.traits:gmatch("[^,]+") do list[#list + 1] = t end
    c:Traits(list, opt.pet)
end
c:Login()
w:Settle("day")
local key = "s:" .. opt.pet
c:Slash("adopter " .. name)
w:Run(5)
assert(c.ns.Registry:MyPet() == key, "couldn't adopt " .. name)
c.ns.DB.global.settings.chatter = opt.chatter

-- The class's casts, as the reactions know them (by name: Forever's spell ids differ), on made-up ids.
local spells, ids = {}, {}
for _, row in ipairs(c.ns.Reactions.ROWS) do
    if row.class == opt.class:upper() and row.on == "cast" then
        for _, s in ipairs(row.spells or {}) do if not ids[s] then spells[#spells + 1] = s; ids[s] = 900000 + #spells end end
    end
end
c.state.spellNames = {}
for s, id in pairs(ids) do c.state.spellNames[id] = s end

local function Cast()
    if #spells == 0 then return end
    c:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-sim", ids[spells[math.random(#spells)]])
end

-- A line said: its group (the key without its number), or for a line without a key its text with numbers as N.
local groups, said, playedDays = {}, 0, 0
local function Short(text) -- (at a space: a byte cut could split a letter)
    if #text <= 64 then return text end
    return text:sub(1, 64):match("^(.*) ") .. " ..."
end
local function Collect(day)
    for _, line in ipairs(c:Log("\tChat\t")) do
        local msg = line:match("\tChat\t(.*)$")
        local k = msg:match("^([%w%._]+)%.%d+: ") or msg:match("^([%w%._]+): ")
        local g = k or ("(text) " .. Short(msg:gsub("%d+", "N")))
        local e = groups[g] or { n = 0, days = {}, first = day }
        groups[g] = e
        e.n, e.days[day] = e.n + 1, true
        said = said + 1
    end
    c.ns.Debug:Clear()
end

local LEVELS = c.ns.Bond.LEVELS
local reached, lastLevel = {}, 1
if not opt.quiet then print(("%s (%s), a %s %s, %s, chatter %s, seed %d"):format(name, key, opt.race, opt.class,
    opt.profile, opt.chatter, opt.seed)) end
c.ns.Debug:Clear()
for day = 1, opt.days do
    local plays = profile.week[(day - 1) % 7 + 1]
    if day > 1 then
        w:SetHour(3); w:SetHour(19) -- (the next day's evening: past a night first)
        if plays then c:Login(); w:Settle("day") end
    end
    local before = c:Points(key)
    if plays then
        playedDays = playedDays + 1
        for minute = 1, math.floor(profile.hours * 60) do
            for id, rate in pairs(RATES) do
                local n = math.floor(rate / 60) + ((math.random() < (rate / 60) % 1) and 1 or 0)
                for _ = 1, n do c.ns.Activity:Emit(id) end
            end
            if minute % FIGHT_EVERY == 0 then
                c:EnterCombat()
                for _ = 1, FIGHT_CASTS do Cast(); w:Run(5, 1) end
                c:LeaveCombat()
                w:Run(40, 1)
            else
                if math.random() < 0.5 then Cast() end
                w:Run(60, 1)
            end
        end
        Collect(day)
        c:Logout()
    end
    local points = c:Points(key)
    local level = c.ns.Bond:Level(points)
    for l = lastLevel + 1, level do reached[l] = day end
    lastLevel = level
    if not opt.quiet then
        print(("day %3d  %s  +%3d  %5d points  level %d"):format(day, plays and "played" or "      ", points - before,
            points, level))
    end
end
if c.online then c:Logout() end

print(("\n%s, a %s %s, %s (%d of %d days played, %g h each), chatter %s, seed %d"):format(name, opt.race, opt.class,
    opt.profile, playedDays, opt.days, profile.hours, opt.chatter, opt.seed))
local levels = {}
for l = 2, #LEVELS do levels[#levels + 1] = ("%d: %s"):format(l, reached[l] and ("day " .. reached[l]) or "-") end
print("Bond level reached (" .. LEVELS[#LEVELS][1] .. " points at 7): " .. table.concat(levels, ", "))
local hours = playedDays * profile.hours
print(("Lines: %d, %.1f per played hour"):format(said, said / math.max(hours, 1)))
-- (how much is new later on: a group first heard in each week; week 4's few is the long run's freshness)
local weeks = {}
for _, e in pairs(groups) do local wk = math.floor((e.first - 1) / 7) + 1; weeks[wk] = (weeks[wk] or 0) + 1 end
local byWeek = {}
for wk = 1, math.ceil(opt.days / 7) do byWeek[#byWeek + 1] = ("%d: %d"):format(wk, weeks[wk] or 0) end
print("Line groups heard first, by week: " .. table.concat(byWeek, ", "))
local list = {}
for g, e in pairs(groups) do
    local d = 0
    for _ in pairs(e.days) do d = d + 1 end
    list[#list + 1] = { g = g, n = e.n, d = d }
end
table.sort(list, function(a, b) if a.d ~= b.d then return a.d > b.d end return a.n > b.n end)
print(("%6s  %5s  %s"):format("said", "days", "line"))
for _, x in ipairs(list) do
    print(("%6d  %4.0f%%  %s"):format(x.n, x.d * 100 / math.max(playedDays, 1), x.g))
end
