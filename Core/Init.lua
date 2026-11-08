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

------------------------------------------------------------------------------
-- Strings players read: Locale/nb.lua (loaded right after this file) fills
-- ns.L with every one of them, keyed like "card.home.today", so they can be
-- edited in one place and translated (decided 2026-11-08). Developer output
-- (/dp probe, /dp debug, the log) stays English, in the code.
--   ns.L[key]         the text as it is
--   ns.T(key, vars)   with its {named} placeholders filled from vars; a
--                     placeholder without a value is left as it is
-- A missing key shows as the key itself (and is logged), never an error.
------------------------------------------------------------------------------
local strings = {} -- the texts themselves; ns.L reads and writes through to them
ns.Strings = strings -- (for the tests: every key)
ns.L = setmetatable({}, {
    __newindex = strings,
    __index = function(_, key)
        local s = strings[key]
        if s ~= nil then return s end
        if ns.Log then ns.Log("Locale", "missing string %s", tostring(key)) end
        return key
    end,
})

-- A text with its {named} placeholders filled from vars.
function ns.Fill(s, vars)
    if vars and type(s) == "string" then
        s = s:gsub("{([%w_]+)}", function(k)
            local v = vars[k]
            if v ~= nil then return tostring(v) end
        end)
    end
    return s
end

function ns.T(key, vars) return ns.Fill(ns.L[key], vars) end

-- Tunables. Keep them here so they're easy to find and change.
ns.Config = {
    INACTIVE_RELEASE_DAYS = 30,   -- reservation released after this long unseen
    NICKNAME_UNLOCK_DAYS = 7,     -- days a pet must be yours before you can name it
    NICKNAME_MAX_LEN = 20,
    BOND_DAY_POINTS = 10,         -- bond points for a day with your adopted companion out
    BOND_LIKED_POINTS = 5,        -- an activity your companion likes (Personality.lua), with it out
    BOND_LIKED_CAP = 25,          -- ... at most this many points a day per activity
    BOND_OTHER_POINTS = 1,        -- any other activity with it out
    BOND_OTHER_CAP = 5,           -- ... at most this many a day per activity
    BOND_DAILY_MAX = 100,         -- the most bond points a day can bring (days + activities); bounds the wire        -- characters (UTF-8 aware, see ns.Utf8Len)
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
-- How long a companion has lived with someone, to follow "Bor hos X":
-- "siden i dag", "siden i går", "i 5 dager", "i 3 måneder", "i 2 år".
-- Today/yesterday go by calendar date; the rest by whole days.
-- How long ago t was, by the calendar: "today", "yesterday", or "days",
-- "months", "years" with a count.
local function Ago(t, now)
    if date("%Y%m%d", t) == date("%Y%m%d", now) or t > now then return "today" end
    -- Yesterday by the calendar: noon of the day before. now - 86400 lands
    -- is wrong around DST: just after midnight following a 23-hour day it
    -- lands two calendar days back.
    local d = date("*t", now)
    local yesterday = time({ year = d.year, month = d.month, day = d.day - 1, hour = 12 })
    if date("%Y%m%d", t) == date("%Y%m%d", yesterday) then return "yesterday" end
    local days = math.max(2, math.floor((now - t) / 86400))
    if days < 60 then return "days", days end
    -- Rounded, so it never says "1 måneder": 60 days is already "2 måneder".
    if days < 730 then return "months", math.floor(days / 30.44 + 0.5) end
    return "years", math.floor(days / 365.25)
end

function ns.CaredFor(t, now)
    local kind, n = Ago(t, now or ns.Now())
    return ns.T("time." .. kind, { n = n })
end

-- Where a pet lives, and since when, as a phrase: "Flyttet inn hos deg i
-- dag", "... i går", else "Bor hos Kari Berg i 3 dager" (2026-11-08: "bor
-- hos deg siden i dag" read badly). who: a name, or ns.L["home.you"].
function ns.Home(who, t, now)
    local kind = Ago(t, now or ns.Now())
    if kind == "today" or kind == "yesterday" then return ns.T("home." .. kind, { who = who }) end
    return ns.T("home.since", { who = who, how = ns.CaredFor(t, now) })
end

-- A time from the wire we can trust the shape of: a real number, not NaN or
-- infinite, and not more than a day ahead of us (clocks differ a little;
-- a far-future time would win every merge and lock the record for good).
function ns.SaneTime(t)
    return type(t) == "number" and t == t and t > 0 and t <= ns.Now() + 86400
end

-- Player keys from the wire: "First Surname", within reason.
function ns.SaneName(s)
    return type(s) == "string" and s ~= "" and #s <= 48
end

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

-- "First Surname" for a group unit (UnitName's second value is the surname).
function ns.UnitKey(unit)
    local first, surname = UnitName(unit)
    if not first then return nil end
    if surname and surname ~= "" then return ns.NormalizeName(first .. " " .. surname) end
    return first
end

-- Everyone in our group as "First Surname", us included (empty when solo).
function ns.GroupKeys()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local key = ns.UnitKey("raid" .. i)
            if key then list[#list + 1] = key end
        end
    elseif IsInGroup() then
        list[1] = ns.PlayerKey()
        for i = 1, GetNumSubgroupMembers() do
            local key = ns.UnitKey("party" .. i)
            if key then list[#list + 1] = key end
        end
    end
    return list
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
