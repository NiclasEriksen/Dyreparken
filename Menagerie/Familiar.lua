---@class Dyreparken
local ns = select(2, ...)

-- Which of a mage's familiars is out (Data/Familiars.lua), if any. The game gives a familiar no pet id we
-- can read (it isn't a journal pet): it's out while its buff is on you.
--
-- Careful (2026-11-17, the user: "especially careful with flightpaths (and maybe mounts), when we get off and
-- resummon we seem to not always respect the buff"): replacing the familiar takes its buff, so a wrong "gone"
-- costs the mage an hour's buff, and a wrong "still out" only holds our pet back until the buff's last
-- minute. So a familiar once seen is remembered until its buff's end (char.familiar, through a /reload):
--   * an answer we can't read (secret auras, a secret value, an error) keeps it;
--   * a plain "no buff" is believed only when a second read CONFIRM seconds later agrees (a loading screen
--     or a landing may read the auras before they're back).
-- Read by spell id (C_UnitAuras.GetPlayerAuraBySpellID, in the API probe's list) and by name, the client's
-- and the English one (by name until 2026-11-17: a guild mage lost the buff after a flight path on 0.7.1).
--
-- Dormant: a mage only watches their own casts for the scrolls (and reads once after login); UNIT_AURA on
-- you only while one is out. Bus "FAMILIAR" (its key, or nil) when one comes out or goes.
---@class Dyreparken.Familiar
local Familiar = {}
ns.Familiar = Familiar

Familiar.CONFIRM = 3   -- seconds between a plain "gone" and the read that believes it
Familiar.LASTS = 3600  -- the buff's length, when its own end can't be read
Familiar.AFTER_CAST = 1 -- seconds after the scroll's cast before the buff is read

local BY_KEY, BY_SPELL = {}, {}
for _, row in ipairs(ns.Familiars) do BY_KEY[row.key], BY_SPELL[row.spell] = row, row end

function Familiar:Row(key) return BY_KEY[key] end

-- One familiar's buff: true (on, with its aura data), false (plainly off), nil (can't tell).
local function Read(row)
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return nil end
    local auras = C_UnitAuras
    if not auras then return false end
    local unsure = false
    local function Try(fn, ...)
        if not fn then return nil end
        local ok, data = pcall(fn, ...)
        if not ok or ns.IsSecret(data) then unsure = true; return nil end
        return data
    end
    local data = Try(auras.GetPlayerAuraBySpellID, row.spell)
    if data then return true, data end
    local names = { [row.name] = true }
    local own = ns.SpellName(row.spell)
    if own then names[own] = true end
    for name in pairs(names) do
        data = Try(auras.GetAuraDataBySpellName, "player", name, "HELPFUL")
        if data then return true, data end
    end
    if unsure then return nil end
    return false
end

local confirmT, endT = ns.Timers(), ns.Timers() -- the second read of a "gone"; the buff's end
local doubt -- GetTime() of the first plain "gone" while one is remembered
local AURA = { name = "Familiar" }

local function Saved() return ns.DB.char.familiar end

local function Watch(on)
    if on then
        if not ns.Events:Has("UNIT_AURA", AURA, "player") then
            ns.Events:On("UNIT_AURA", AURA, function() Familiar:Out() end, "player")
        end
    else
        ns.Events:Off("UNIT_AURA", AURA, "player")
    end
end

-- Its end, read again then (a buff that ends while nothing else happens still brings our pet back).
local function AtEnd(ends)
    endT:Cancel()
    endT:After(math.max(1, ends - ns.Now() + 1), function() Familiar:Out() end)
end

local function Remember(row, data)
    doubt = nil
    confirmT:Cancel()
    local left = Familiar.LASTS
    local at = data and ns.Plain(data.expirationTime)
    if type(at) == "number" and at > 0 then left = math.max(0, at - GetTime()) end
    local ends = ns.Now() + math.floor(left + 0.5)
    local was = Saved()
    ns.DB.char.familiar = { key = row.key, ends = ends }
    Watch(true)
    if not (was and was.key == row.key and math.abs((tonumber(was.ends) or 0) - ends) <= 5) then AtEnd(ends) end
    if not (was and was.key == row.key) then
        ns.Log("Familiar", "out: %s (%d s left)", row.key, left)
        ns.Bus:Fire("FAMILIAR", row.key)
    end
end

local function Forget(why)
    local was = Saved()
    doubt = nil
    confirmT:Cancel(); endT:Cancel()
    ns.DB.char.familiar = nil
    Watch(false)
    if was then
        ns.Log("Familiar", "gone: %s (%s)", tostring(was.key), why)
        ns.Bus:Fire("FAMILIAR", nil)
    end
end

-- The familiar out now (its row), else nil. Every read goes through here (Summon's checks, UNIT_AURA).
function Familiar:Out()
    local unsure = false
    for _, row in ipairs(ns.Familiars) do
        local on, data = Read(row)
        if on then
            Remember(row, data)
            return row
        elseif on == nil then
            unsure = true
        end
    end
    local was = Saved()
    if not was then return nil end
    local row = BY_KEY[was.key]
    if not row or ns.Now() >= (tonumber(was.ends) or 0) then
        Forget("its time is up")
        return nil
    end
    -- (remembered through a /reload: watched again)
    if not ns.Events:Has("UNIT_AURA", AURA, "player") then Watch(true); AtEnd(tonumber(was.ends)) end
    if unsure then
        doubt = nil
        return row
    end
    local now = GetTime()
    if not doubt then
        doubt = now
        ns.Log("Familiar", "%s: no buff read; again in %d s", row.key, Familiar.CONFIRM)
        confirmT:After(Familiar.CONFIRM, function() Familiar:Out() end)
        return row
    end
    if now - doubt < Familiar.CONFIRM - 0.5 then return row end -- (the confirming timer, give or take a frame)
    Forget("no buff, twice")
    return nil
end

-- The key of the familiar out, or nil.
function Familiar:Key()
    local row = self:Out()
    return row and row.key
end

-- A mage reads a scroll: its buff a moment later.
local CAST = { name = "FamiliarCast" }
function Familiar:Init()
    local _, class = UnitClass("player")
    if ns.Plain(class) ~= "MAGE" then
        if Saved() then Forget("not a mage") end
        return
    end
    ns.Events:On("UNIT_SPELLCAST_SUCCEEDED", CAST, function(_, _, unit, _, spellID)
        if unit ~= "player" or not BY_SPELL[ns.Plain(spellID)] then return end
        C_Timer.After(Familiar.AFTER_CAST, function() Familiar:Out() end)
    end, "player")
    self:Out()
end

ns.Start("login", function() Familiar:Init() end)
