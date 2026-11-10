local _, ns = ...

-- Quirks (2026-11-09): flavor with no effect on anything. The more little
-- surprises, the better, but quietly: at most one quirk line an hour
-- (char.quirkAt), and most only by chance.
--
-- Dislikes (Personality:Dislikes): something your pet doesn't like happened
-- with it out (a cat and the water). A line, by chance; the first one tells
-- you, and from then on the card shows it (char.dislikes). Until then it's
-- a secret.
--
-- Easter eggs (Quirks.EGGS): rare lines at certain moments: holidays, an
-- anniversary of the adoption, meeting its own kind, midnight. Each at most
-- once a day; they're counted (char.eggs) for an achievement some day.
--
-- Lines: Locale/nb.lua, dislike.<activity>.N and egg.<id>.N (one is picked).
-- The activities they need are watched like the bond's (Activity:Want).
local Quirks = {}
ns.Quirks = Quirks

Quirks.EVERY = 3600          -- seconds between quirk lines
Quirks.DISLIKE_CHANCE = 0.35 -- per disliked activity (with the hour free)
Quirks.random = math.random  -- (tests pin it)

local T = ns.T

-- Every variant of a line: prefix.1, prefix.2, ...
local variants = {}
local function Variants(prefix)
    local list = variants[prefix]
    if not list then
        list = {}
        while ns.Strings[prefix .. "." .. (#list + 1)] do list[#list + 1] = prefix .. "." .. (#list + 1) end
        variants[prefix] = list
    end
    return list
end

local function Pick(prefix, vars)
    local list = Variants(prefix)
    if #list == 0 then return nil end
    return T(list[Quirks.random(#list)], vars)
end

function Quirks:Ready()
    local at = ns.DB.char.quirkAt
    return not at or ns.Now() - at >= self.EVERY
end

function Quirks:Say(text, why)
    ns.DB.char.quirkAt = ns.Now()
    ns.Print("|cffd9b3ff" .. text .. "|r")
    ns.Log("Quirks", "%s", why)
end

------------------------------------------------------------------------------
-- Dislikes
------------------------------------------------------------------------------
function Quirks:Dislike(key, id)
    if not self:Ready() or self.random() >= self.DISLIKE_CHANCE then return end
    local name = ns.Registry:NameOf(key)
    local text = Pick("dislike." .. id, { pet = name })
    if not text then return end
    self:Say(text, ("dislike %s %s"):format(key, id))
    local seen = ns.DB.char.dislikes
    seen[key] = seen[key] or {}
    if not seen[key][id] then
        seen[key][id] = true
        ns.Print("|cffd9b3ff" .. T("dislike.found", { pet = name, what = ns.Personality.NOUN[id] }) .. "|r")
        if ns.JournalUI then ns.JournalUI:Refresh() end
    end
end

------------------------------------------------------------------------------
-- Easter eggs: { id, on = activity (or "seen": a companion under the mouse),
-- chance (default 1), test = fn(ctx) -> vars or nil }. ctx: key, name (the
-- pet's), id, extra, t, family (set), today (the activity's count today).
-- `always`: not held back by the hour (rare by nature, and a day late is lost).
------------------------------------------------------------------------------
local function On(md) return function(ctx) return date("%m%d", ctx.t) == md and {} end end

local MILESTONES = { [200] = true, [500] = true, [1000] = true }

Quirks.EGGS = {
    { id = "mai17", on = "day", always = true, test = On("0517") },
    { id = "jul", on = "day", always = true, test = On("1224") },
    { id = "nyttar", on = "day", always = true, test = On("1231") },
    { id = "april", on = "day", always = true, test = On("0401") },
    { id = "halloween", on = "day", always = true, test = On("1031") },
    { id = "fredag13", on = "day", always = true,
        test = function(ctx) return date("%d%w", ctx.t) == "135" and {} end },
    -- Round days since you adopted it, on the day (calendar days, as the
    -- milestone lines count them; those have 30, 100 and the years).
    { id = "dager", on = "day", always = true, test = function(ctx)
        if ns.Registry:MyPet() ~= ctx.key then return end
        local _, _, r = ns.Registry:Status(ctx.key)
        if not (r and r.at) then return end
        local days = ns.Bonds.DayNumber(ctx.t) - ns.Bonds.DayNumber(r.at)
        return MILESTONES[days] and { n = days }
    end },
    { id = "midnatt", on = "*", chance = 0.5,
        test = function(ctx) return date("%H", ctx.t) == "00" and tonumber(date("%M", ctx.t)) < 10 and {} end },
    { id = "speil", on = "seen", test = function(ctx) return { owner = ctx.extra } end },
    { id = "kattefisk", on = "fish", chance = 0.3, test = function(ctx) return ctx.family.cat and {} end },
    { id = "vinger", on = "taxi", chance = 0.3,
        test = function(ctx) return (ctx.family.bird or ctx.family.owl or ctx.family.dragon) and {} end },
    { id = "trofe", on = "boss", chance = 0.15, test = function(ctx)
        return type(ctx.extra) == "string" and ctx.extra ~= "" and ctx.extra ~= "?" and { boss = ctx.extra }
    end },
    { id = "dodsfall", on = "revive", test = function(ctx) return ctx.today >= 3 and {} end },
    { id = "kake", on = "level", test = function(ctx)
        local level = tonumber(ctx.extra)
        return level and level % 10 == 0 and { level = level }
    end },
    -- Every hundredth quest with this pet out (the hour doesn't hold it back:
    -- the next chance is a hundred quests away).
    { id = "oppdrag", on = "quest", always = true, test = function(ctx)
        local n = select(4, ns.Activity:Count("quest", ctx.key))
        return n > 0 and n % 100 == 0 and { n = n }
    end },
}
local eggsOn = {} -- activity -> its eggs
for _, e in ipairs(Quirks.EGGS) do
    eggsOn[e.on] = eggsOn[e.on] or {}
    table.insert(eggsOn[e.on], e)
end

local function Families(key)
    local set = {}
    for _, f in ipairs(ns.Scenes:Families(key)) do set[f] = true end
    return set
end

function Quirks:Egg(on, key, extra)
    local list = {}
    for _, e in ipairs(eggsOn[on] or {}) do list[#list + 1] = e end
    if on ~= "seen" then for _, e in ipairs(eggsOn["*"]) do list[#list + 1] = e end end
    if #list == 0 then return false end
    local ctx = { key = key, name = ns.Registry:NameOf(key), id = on, extra = extra, t = ns.Now(),
        family = Families(key), today = select(3, ns.Activity:Count(on)) or 0 }
    local today = ns.Today(ctx.t)
    for _, e in ipairs(list) do
        local had = ns.DB.char.eggs[e.id]
        if (e.always or self:Ready()) and not (had and had.day == today)
            and (not e.chance or self.random() < e.chance) then
            local vars = e.test(ctx)
            local text = vars and Pick("egg." .. e.id, setmetatable({ pet = ctx.name }, { __index = vars }))
            if text then
                had = ns.DB.char.eggs[e.id] or {}
                had.n, had.day, had.key, had.played = (had.n or 0) + 1, today, key, nil -- (Moves: playing dead)
                ns.DB.char.eggs[e.id] = had
                self:Say(text, ("egg %s %s"):format(e.id, key))
                return true
            end
        end
    end
    return false
end

function Quirks:OnActivity(id, key, extra)
    if not key then return end
    if ns.Personality:Dislikes(key)[id] then return self:Dislike(key, id) end
    self:Egg(id, key, extra)
end

-- A companion under the mouse (Tooltip.lua): your pet meets its own kind.
function Quirks:Seen(species, owner)
    local key = ns.Pets:OutKey()
    if not (key and owner and owner ~= ns.PlayerKey()) or ns.Pets:SpeciesOfKey(key) ~= species then return end
    self:Egg("seen", key, owner)
end

------------------------------------------------------------------------------
-- Watching: the dislikes of the pets we'd have out (the adopted one and the
-- active one), and what the eggs read that the bond may not.
------------------------------------------------------------------------------
Quirks.WATCH = { "level", "revive" }
local watching = {}

function Quirks:Watch()
    local want = {}
    for _, id in ipairs(self.WATCH) do want[id] = true end
    for _, key in ipairs({ ns.Registry:MyPet() or false, ns.Summon:ActiveKey() or false }) do
        if key then for id in pairs((ns.Personality:Dislikes(key))) do want[id] = true end end
    end
    for id in pairs(watching) do
        if not want[id] then ns.Activity:Drop(id, Quirks) end
    end
    for id in pairs(want) do
        if not watching[id] then ns.Activity:Want(id, Quirks) end
    end
    watching = want
end

function Quirks:Init()
    ns.Bus:On("ACTIVITY", function(id, _, key, _, extra) Quirks:OnActivity(id, key, extra) end)
    ns.Bus:On("COMPANION_SEEN", function(species, owner) Quirks:Seen(species, owner) end)
    ns.Bus:On("MY_RECORD", function() Quirks:Watch() end)
    ns.Bus:On("ACTIVE_PET", function() Quirks:Watch() end)
    Quirks:Watch()
    -- Again once the login SYNC is in, like Bond: the guild (so our adopted
    -- pet) may not be known at login yet, and our own record can come back
    -- from a peer without a MY_RECORD of ours (code review 2026-11-09).
    C_Timer.After(20, function() Quirks:Watch() end)
end

ns.Start("login", function() Quirks:Init() end)
