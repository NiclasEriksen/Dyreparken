---@class Dyreparken
local ns = select(2, ...)

-- Turnus (2026-11-22, 0.10.0, the content review §4.2, the user: "a toggle on each, small one. Also the flokk
-- tab"): your pets take turns. Pick MIN to MAX pets with the small toggle beside "Med deg" on their cards (OutBadge);
-- each calendar day the next of them in the list becomes the one kept out (Summon:Rotate), and when its day is full
-- the next with room takes over, with a line instead of the full day's nudge (Bonds). Everything auto-summon
-- respects still holds: it's the "Med deg" pet that changes, and Summon decides when it comes out (never in place of
-- one you summoned yourself). Off while auto-summon is. The list: char.turnus; the day's pick: char.turnusDay.
---@class Dyreparken.Turnus
local Turnus = {}
ns.Turnus = Turnus

Turnus.MIN, Turnus.MAX = 2, 5

-- The list, pets you no longer own left out (not dropped: one may come back from a cage).
function Turnus:List()
    local out = {}
    for _, key in ipairs(ns.DB.char.turnus or {}) do
        if ns.Pets:IsOwned(key) then out[#out + 1] = key end
    end
    return out
end

function Turnus:Has(key)
    for _, k in ipairs(ns.DB.char.turnus or {}) do if k == key then return true end end
    return false
end

function Turnus:Full() return #(ns.DB.char.turnus or {}) >= self.MAX end

-- Adds or removes a pet. False when the list is full.
function Turnus:Toggle(key)
    local char = ns.DB.char
    local list = char.turnus or {}
    for i, k in ipairs(list) do
        if k == key then
            table.remove(list, i)
            char.turnus = #list > 0 and list or nil
            ns.Log("Turnus", "out: %s (%d left)", key, #list)
            return true
        end
    end
    if #list >= self.MAX then return false end
    list[#list + 1] = key
    char.turnus = list
    ns.Log("Turnus", "in: %s (%d)", key, #list)
    -- (the second pet starts it: today's pet is the one out, the next takes over tomorrow)
    if #self:List() == self.MIN and not char.turnusDay then
        char.turnusDay = { day = ns.Today(), key = ns.Summon:ActiveKey() }
    end
    return true
end

function Turnus:On()
    return #self:List() >= self.MIN and ns.Summon:Enabled()
end

-- The next pet after `after` in the list (from the start if it isn't in it) whose day has room; nil if none.
function Turnus:Next(after)
    local list = self:List()
    local at = 0
    for i, k in ipairs(list) do if k == after then at = i end end
    for step = 1, #list do
        local key = list[(at + step - 1) % #list + 1]
        if key ~= after and ns.Bond:Open(key) then return key end
    end
end

-- A new calendar day: the next pet's turn (once a day).
function Turnus:Day()
    if not self:On() then return end
    local char, today = ns.DB.char, ns.Today()
    local d = char.turnusDay
    if d and d.day == today then return end
    local key = self:Next(d and d.key or ns.Summon:ActiveKey()) or ns.Summon:ActiveKey()
    char.turnusDay = { day = today, key = key }
    if key and key ~= ns.Summon:ActiveKey() then
        ns.Summon:Rotate(key)
        ns.PrintGold(ns.T("turnus.day", { pet = ns.Registry:NameOf(key) }))
    end
end

-- The pet kept out is full for today: the next with room takes over. Returns true when it did (Bonds says nothing
-- of its own then).
function Turnus:TakeOver(key)
    if not (self:On() and key == ns.Summon:ActiveKey() and self:Has(key)) then return false end
    local nextKey = self:Next(key)
    if not nextKey then return false end
    ns.DB.char.turnusDay = { day = ns.Today(), key = nextKey }
    ns.Summon:Rotate(nextKey)
    ns.PrintGold(ns.T("turnus.next", { pet = ns.Registry:NameOf(nextKey), old = ns.Registry:NameOf(key) }))
    return true
end

-- Turnusvakt (2026-11-22, 0.10.0, the content review §4.4): days in a row, each with a day's visit from a pet not
-- yet out in that run (any of yours, Turnus or not). A day counts at its first such visit; a day without one
-- doesn't break the run until it's over (the run holds while its last day is today or yesterday).
function Turnus:Visit(key, today)
    local t = ns.DB.char.turnusvakt or { n = 0, best = 0, pets = {} }
    ns.DB.char.turnusvakt = t
    if t.last == today then return end
    if t.last ~= ns.DayBefore(today) then t.n, t.pets = 0, {} end
    if t.pets[key] then return end
    t.pets[key], t.n, t.last = true, t.n + 1, today
    t.best = math.max(t.best or 0, t.n)
end

ns.Start("settled", function()
    Turnus:Day()
    -- (past midnight: the new day's first visit)
    ns.Bus:On("ACTIVITY", function(id, _, key)
        if id ~= "day" then return end
        if key then Turnus:Visit(key, ns.Today()) end
        Turnus:Day()
    end)
end)
