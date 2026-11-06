local addonName, ns = ...

-- Shared namespace. Every module hangs off ns; nothing is global except the
-- SavedVariables and the slash command. Keeps us clear of the 200-locals limit.
ns.name = addonName

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata

-- The packager replaces @project-version@ with the git tag (e.g. "v0.1.0").
-- Running straight from a git checkout leaves the token in place: that's a
-- dev build, which never claims to be outdated or newer than anyone.
do
    local v = (GetMeta and GetMeta(addonName, "Version")) or ""
    ns.DEV = v == "" or v:find("@", 1, true) ~= nil
    ns.VERSION = ns.DEV and "dev" or v
end
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
--   CHAT_MSG_ADDON sender -> "Hjelp Plask" (same realm) or, presumably,
--     "First Surname-SomeRealm"
-- (probed 2026-11-06, build 70790).
--
-- We ignore realms entirely: on Forever they're an implementation detail
-- (players move between them under the hood; only the ruleset matters),
-- and this is a single-guild addon. A player's key is "First Surname".

-- "Hjelp Plask" (or just "Hjelp" without a surname).
function ns.PlayerName()
    local first, surname = UnitName("player")
    if surname and surname ~= "" then return first .. " " .. surname end
    return first
end

function ns.PlayerKey()
    return ns.PlayerName()
end

-- Is this text after a "-" a realm? Realm names have no spaces; ours look
-- like "CAMWOWEU4Realm1PvE". Checked against the realms we know of first;
-- the pattern is a fallback so a hyphenated surname ("Berg-Hansen") isn't
-- cut off.
local realms
local function IsRealm(suffix)
    if suffix:find(" ", 1, true) then return false end
    if not realms then
        local own = GetNormalizedRealmName()
        if not own then return suffix:find("%d") ~= nil end
        realms = { [own] = true }
        local list = GetAutoCompleteRealms and GetAutoCompleteRealms()
        if type(list) == "table" then
            for _, r in ipairs(list) do realms[r] = true end
        end
    end
    return realms[suffix] or suffix:find("%u%l*%d") ~= nil
end

-- A sender name -> "First Surname" (realm suffix stripped, if any).
function ns.NormalizeName(name)
    if not name or name == "" then return nil end
    local base, suffix = name:match("^(.+)%-([^%-]+)$")
    if base and IsRealm(suffix) then return base end
    return name
end

-- Character count of a UTF-8 string (string.len counts bytes).
function ns.Utf8Len(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

-- Compare release versions like "v0.1.0", "0.1.0-beta2". Returns -1, 0, 1.
-- Numbers before any "-" are compared first; on a tie a release beats a
-- pre-release (0.1.0 > 0.1.0-beta2), and pre-releases compare by their
-- trailing numbers (beta2 > beta1). "dev" equals everything.
local function ParseVersion(v)
    v = tostring(v or "")
    local core, pre = v:match("^v?([%d%.]+)%-?(.*)$")
    local nums = {}
    for n in (core or ""):gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
    local preNums = {}
    for n in (pre or ""):gmatch("%d+") do preNums[#preNums + 1] = tonumber(n) end
    return nums, pre ~= nil and pre ~= "", preNums, core ~= nil
end

local function CompareLists(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

function ns.CompareVersions(a, b)
    local na, preA, pnA, okA = ParseVersion(a)
    local nb, preB, pnB, okB = ParseVersion(b)
    if not okA or not okB then return 0 end -- "dev" or garbage
    local c = CompareLists(na, nb)
    if c ~= 0 then return c end
    if preA ~= preB then return preA and -1 or 1 end
    return CompareLists(pnA, pnB)
end

-- InCombatLockdown only: unit queries can return secret booleans on Forever.
function ns.InCombat()
    return InCombatLockdown()
end
