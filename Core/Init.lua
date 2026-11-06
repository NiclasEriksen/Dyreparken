local addonName, ns = ...

-- Shared namespace. Every module hangs off ns; nothing is global except the
-- SavedVariables and the slash command. Keeps us clear of the 200-locals limit.
ns.name = addonName

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

ns.VERSION = (GetMeta and GetMeta(addonName, "Version")) or "0.0.0"
-- Wire protocol version. Bump on breaking message format changes; peers with
-- a different protocol are ignored (and told to update, once).
ns.PROTOCOL = tonumber(GetMeta and GetMeta(addonName, "X-Protocol")) or 1

-- Tunables. Keep them here so they're easy to find and change.
ns.Config = {
    INACTIVE_RELEASE_DAYS = 30,   -- reservation released after this long unseen
    NICKNAME_UNLOCK_DAYS = 7,     -- days a pet must be yours before you can name it
    NICKNAME_MAX_LEN = 20,        -- characters (UTF-8 aware, see ns.Utf8Len)
    DEBUG_RING_SIZE = 2000,       -- lines kept in DyreparkenDebugDB
    COMM_PREFIX = "Dyreparken",   -- max 16 characters
}

------------------------------------------------------------------------------
-- Tiny event bus between modules (not game events, see Events.lua).
------------------------------------------------------------------------------
local listeners = {}
ns.Bus = {}
function ns.Bus:On(event, fn)
    local list = listeners[event]
    if not list then list = {}; listeners[event] = list end
    list[#list + 1] = fn
end
function ns.Bus:Fire(event, ...)
    local list = listeners[event]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], ...)
        if not ok then geterrorhandler()(err) end
    end
end

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------
function ns.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fd47fDyreparken:|r " .. tostring(msg))
end

-- Server time: the same clock for everyone, so "first come first served" does
-- not depend on players' PC clocks.
function ns.Now()
    return GetServerTime()
end

-- Player identity. Forever has surnames, which changes the usual APIs:
--   UnitName("player") / UnitFullName("player") -> "Hjelp", "Plask"
--     (the second value is the SURNAME, not the realm)
--   CHAT_MSG_ADDON sender -> "Hjelp Plask" (same realm) or
--     "First Surname-OtherRealm" (connected realm, presumably)
--   GetNormalizedRealmName() -> "CAMWOWEU4Realm1PvE"
-- (probed 2026-11-06, build 70790). Our key is "First Surname-Realm", the
-- form the sender takes once the realm is added.

-- "Hjelp Plask" (or just "Hjelp" without a surname).
function ns.PlayerName()
    local first, surname = UnitName("player")
    if surname and surname ~= "" then return first .. " " .. surname end
    return first
end

local playerKey
function ns.PlayerKey()
    if not playerKey then
        local realm = GetNormalizedRealmName()
        -- Realm can be nil very early in loading: don't cache a bad key.
        if not realm or realm == "" then return ns.PlayerName() .. "-?" end
        playerKey = ns.PlayerName() .. "-" .. realm
    end
    return playerKey
end

-- Realm names a sender suffix can be: ours plus connected realms
-- (GetAutoCompleteRealms returns normalized names). Built lazily, once.
local realms
local function KnownRealms()
    if not realms then
        local own = GetNormalizedRealmName()
        if not own then return {} end
        realms = { [own] = true }
        local list = GetAutoCompleteRealms and GetAutoCompleteRealms()
        if type(list) == "table" then
            for _, r in ipairs(list) do realms[r] = true end
        end
    end
    return realms
end

-- A sender name -> "First Surname-Realm". The suffix after the last "-" only
-- counts as a realm if it is one we know, so a hyphen in a surname doesn't
-- get mistaken for a realm separator.
function ns.NormalizeName(name)
    if not name or name == "" then return nil end
    local base, suffix = name:match("^(.+)%-([^%-]+)$")
    if suffix and KnownRealms()[suffix] then return name end
    if suffix and not suffix:find(" ", 1, true) and suffix:find("%u%l*%d") then
        -- Looks like a realm we don't know (CAMWOW... has digits): keep it.
        return name
    end
    return name .. "-" .. (GetNormalizedRealmName() or "?")
end

-- For display: drop our own realm, keep others.
function ns.DisplayName(key)
    if not key then return "?" end
    local own = GetNormalizedRealmName()
    local base, realm = key:match("^(.+)%-([^%-]+)$")
    if base and realm == own then return base end
    return key
end

-- Character count of a UTF-8 string (string.len counts bytes).
function ns.Utf8Len(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

-- "1.2.3" -> comparable numbers. Returns -1, 0, 1 like a comparator.
function ns.CompareVersions(a, b)
    local pa, pb = {}, {}
    for n in tostring(a):gmatch("%d+") do pa[#pa + 1] = tonumber(n) end
    for n in tostring(b):gmatch("%d+") do pb[#pb + 1] = tonumber(n) end
    for i = 1, math.max(#pa, #pb) do
        local x, y = pa[i] or 0, pb[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

-- InCombatLockdown only: unit queries can return secret booleans on Forever.
function ns.InCombat()
    return InCombatLockdown()
end
