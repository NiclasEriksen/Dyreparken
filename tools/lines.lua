-- What a pet can say, outside the game (2026-11-19, review: the text side of /dp try, for editing Locale/nb.lua).
-- Runs the real ns.Lines and Moments.ByNature in a harness client, so a pet's traits, families, class and race
-- pick the same texts they would in the game. Run from the addon folder:
--
--   luajit tools/lines.lua egg.trofe --pet 70              every text the egg can be for that species
--   luajit tools/lines.lua react.totemer --class shaman    a reaction (default pet: the Panda Cub, 5159)
--   luajit tools/lines.lua egg.stup --traits latsabb,kosete  as if the pet had these two traits
--   luajit tools/lines.lua voice.cat --race orc            any line group: its own text, variants, class and race
--   luajit tools/lines.lua egg.trofe --all                 the egg's lines for every nature that has some
--
-- An egg (egg.<id>) or a reaction (react.<id>) with lines by nature says those instead of its plain ones when
-- the pet has the first trait (then family) of its row that has lines (Moments.ByNature).
package.path = "tools/test/?.lua;" .. package.path
local args, opt = { ... }, { pet = 5159, class = "warrior", race = "human" }
local i = 1
while i <= #args do
    local a = args[i]
    local function Next() i = i + 1; return args[i] end
    if a == "--pet" then opt.pet = tonumber(Next())
    elseif a == "--class" then opt.class = Next():lower()
    elseif a == "--race" then opt.race = Next():lower()
    elseif a == "--traits" then opt.traits = Next()
    elseif a == "--all" then opt.all = true
    elseif a == "-h" or a == "--help" then
        for line in io.lines(arg[0]) do
            if not line:find("^%-%-") then break end
            print((line:gsub("^%-%- ?", "")))
        end
        os.exit(0)
    elseif a:match("^%-") then
        io.stderr:write("unknown option ", a, " (-h for help)\n"); os.exit(2)
    else
        opt.prefix = a
    end
    i = i + 1
end
if not opt.prefix then io.stderr:write("a line's key: egg.trofe, react.totemer, voice.cat (-h for help)\n"); os.exit(2) end

local H = require("harness")
local RACES = { human = "Human", dwarf = "Dwarf", nightelf = "NightElf", gnome = "Gnome", orc = "Orc",
    scourge = "Scourge", tauren = "Tauren", troll = "Troll" }
local w = H.World()
local c = w:AddClient("Ola Nord", { pets = { opt.pet }, login = false, debug = false })
c.state.class, c.state.race = opt.class:upper(), RACES[opt.race] or opt.race
if opt.traits then
    local list = {}
    for t in opt.traits:gmatch("[^,]+") do list[#list + 1] = t end
    c:Traits(list, opt.pet)
end
c:Login()
local ns, key = c.ns, "s:" .. opt.pet
-- (the stub journal knows a few species by name; Data/Companions.lua has every name in a comment)
local name = H.SPECIES[opt.pet]
if not name then
    for line in io.lines("Data/Companions.lua") do
        local sid, n = line:match("^%s*%[(%d+)%] = .-%-%- (.+)$")
        if tonumber(sid) == opt.pet then name = n end
    end
end
name = name or key

-- The row an egg or a reaction comes from, if the prefix names one.
local kind, id = opt.prefix:match("^(%a+)%.([%w_]+)$")
local row
for _, r in ipairs(kind == "egg" and ns.Quirks.EGGS or kind == "react" and ns.Reactions.ROWS or {}) do
    if r.id == id then row = r end
end

local function Texts(prefix)
    local list = ns.Lines(prefix)
    for n, k in ipairs(list) do
        local text = ns.Strings[k]:gsub("{pet}", name)
        print(("  %-34s %s"):format(k, text))
        list[n] = nil
    end
end

local traits = {}
for _, t in ipairs(ns.Personality:Traits(key)) do traits[#traits + 1] = t.id end
local families = ns.Scenes:Families(key)
print(("%s (%s): traits %s; families %s; a %s %s"):format(name, key, table.concat(traits, ", "),
    table.concat(families, ", "), opt.race, opt.class))
if row and opt.all then
    for _, t in ipairs(row.traits or {}) do
        if ns.Strings[opt.prefix .. "." .. t .. ".1"] then print("-- trait " .. t .. ":"); Texts(opt.prefix .. "." .. t) end
    end
    for _, f in ipairs(row.families or {}) do
        if ns.Strings[opt.prefix .. "." .. f .. ".1"] then print("-- family " .. f .. ":"); Texts(opt.prefix .. "." .. f) end
    end
    print("-- the plain ones:")
    Texts(opt.prefix)
    os.exit(0)
end
local nature = row and ns.Moments.ByNature(kind, row, key)._key
if nature then print("-- by its nature (" .. nature .. "), instead of the plain ones:") end
if #ns.Lines(nature or opt.prefix) == 0 then print("  (no text: " .. (nature or opt.prefix) .. " has no lines for this pet)") end
Texts(nature or opt.prefix)
