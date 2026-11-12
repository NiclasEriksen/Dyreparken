-- Pins every species' two traits in Data/Traits.lua (luajit tools/pin_traits.lua).
--
-- A species keeps its traits forever once pinned (decided 2026-11-08): this
-- keeps every line already in Data/Traits.lua as it is, and only adds the
-- species from Data/Companions.lua that aren't pinned yet, with the traits
-- used least so far. Run it after
-- regenerating Data/Companions.lua. To change a species' traits, edit its
-- line by hand.
local ROOT = arg and arg[0]:match("^(.*)/tools/") or "."

local function Load(path, ns)
    local chunk = assert(loadfile(ROOT .. "/" .. path))
    setfenv(chunk, setmetatable({}, { __index = _G }))
    chunk("Dyreparken", ns)
end

local ns = {}
Load("Data/Companions.lua", ns)
local old = {}
if io.open(ROOT .. "/Data/Traits.lua") then
    Load("Data/Traits.lua", old)
end
local pins = old.TraitPins or {}

-- Names, from the comments in Data/Companions.lua.
local names = {}
for line in io.lines(ROOT .. "/Data/Companions.lua") do
    local sid, name = line:match("^%s*%[(%d+)%] = .*%-%- (.+)$")
    if sid then names[tonumber(sid)] = name end
end

-- Personality, for its unpinned pick.
ns.Pets = { SpeciesOfKey = function(_, key) return tonumber(key:match("^s:(%d+)$")) end }
ns.TraitPins = {}
-- (what Personality.lua reads at load: the activity kinds and the strings; their text doesn't matter here)
ns.Activity = { KINDS = {} }
ns.Strings = {}
ns.L = setmetatable({}, { __index = function(_, k) return k end })
ns.T = function(k) return k end
Load("Menagerie/Personality.lua", ns)
local P = ns.Personality

-- New species get the traits used least so far (ties: a hash of the species
-- and the trait), so every trait shows up about as often; never a pair that
-- contradicts itself.
local used = {}
for _, t in ipairs(P.TRAITS) do used[t.id] = 0 end
for _, pin in pairs(pins) do used[pin[1]] = used[pin[1]] + 1; used[pin[2]] = used[pin[2]] + 1 end
local function Tie(sid, id)
    local h = sid * 2654435761
    for i = 1, #id do h = (h * 31 + id:byte(i)) % 4294967296 end
    return h
end
local fresh = {}
for sid in pairs(ns.Companions.species) do if not pins[sid] then fresh[#fresh + 1] = sid end end
table.sort(fresh)
local added = 0
for _, sid in ipairs(fresh) do
    local order = {}
    for _, t in ipairs(P.TRAITS) do order[#order + 1] = t end
    table.sort(order, function(a, b)
        if used[a.id] ~= used[b.id] then return used[a.id] < used[b.id] end
        return Tie(sid, a.id) < Tie(sid, b.id)
    end)
    local first, second = order[1], nil
    for i = 2, #order do
        if order[i].id ~= first.against then second = order[i]; break end
    end
    pins[sid] = { first.id, second.id }
    used[first.id], used[second.id] = used[first.id] + 1, used[second.id] + 1
    added = added + 1
end
for sid, pin in pairs(pins) do
    assert(P.ById(pin[1]) and P.ById(pin[2]) and pin[1] ~= pin[2], "bad pin for " .. sid)
end

local ids = {}
for sid in pairs(pins) do ids[#ids + 1] = sid end
table.sort(ids)
local out = { [[local _, ns = ...

-- Every species' two personality traits (Menagerie/Personality.lua), pinned:
-- a species keeps them for good, whatever traits are added later (decided
-- 2026-11-08). Reworked once, 2026-11-12 (the user), with the new traits, for
-- every species nobody in the guild had adopted. New species are added by
-- tools/pin_traits.lua, which never changes a line that's here. Edit a line by
-- hand to change a species.
ns.TraitPins = {
]] }
for _, sid in ipairs(ids) do
    local pin = pins[sid]
    out[#out + 1] = ('    [%d] = { "%s", "%s" },%s\n'):format(sid, pin[1], pin[2],
        names[sid] and (" -- " .. names[sid]) or "")
end
out[#out + 1] = "}\n"
local f = assert(io.open(ROOT .. "/Data/Traits.lua", "w"))
f:write(table.concat(out))
f:close()
print(("Data/Traits.lua: %d species, %d added"):format(#ids, added))
