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

-- A value the client may hand us as a secret (docs/FOREVER_API.md): nil
-- then, so nothing compares, indexes or prints it.
function ns.Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- A calendar day as "YYYYMMDD" (the local clock, from server time): the
-- day the daily limit, the wish, the cuddle and the counters belong to.
function ns.Today(t) return date("%Y%m%d", t or ns.Now()) end

-- A date as players read it: 08.11.2026.
function ns.Date(t) return date("%d.%m.%Y", t) end

-- Play the first of these SOUNDKIT names the client knows; returns its name.
function ns.PlayFirstSound(names)
    for _, s in ipairs(names) do
        local id = SOUNDKIT and SOUNDKIT[s]
        if id then PlaySound(id); return s end
    end
    return nil
end

-- OnLeave for anything that shows a tooltip.
function ns.HideTip(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end

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

-- "herbs, quests og flyturer" (Locale: list.sep, list.and)
function ns.Join(words)
    if #words <= 1 then return words[1] or "" end
    return table.concat(words, ns.L["list.sep"], 1, #words - 1) .. ns.L["list.and"] .. words[#words]
end

-- Gold text, and a gold line in chat (the pet's moments: wishes, firsts, playdates).
function ns.Gold(text) return "|cffffd100" .. text .. "|r" end
function ns.PrintGold(text) ns.Print(ns.Gold(text)) end

function ns.IsSecret(v) return issecretvalue ~= nil and issecretvalue(v) == true end

-- A spell's name by id (nil for a secret or missing id, or without C_Spell).
function ns.SpellName(id)
    id = ns.Plain(id)
    if type(id) ~= "number" or not (C_Spell and C_Spell.GetSpellName) then return nil end
    return ns.Plain(C_Spell.GetSpellName(id))
end

-- The channel to reach our group on, or nil when solo.
function ns.GroupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

-- Tunables. Keep them here so they're easy to find and change.
ns.Config = {
    INACTIVE_RELEASE_DAYS = 30,   -- reservation released after this long unseen
    NICKNAME_LEVEL = 3,           -- the bond level (Venn) at which a pet's carer may name it (Bond.lua)
    NICKNAME_MAX_LEN = 20,        -- characters (UTF-8 aware, see ns.Utf8Len)
    BOND_DAY_POINTS = 10,         -- bond points for a day with your adopted companion out
    BOND_LIKED_POINTS = 5,        -- an activity your companion likes (Personality.lua), with it out
    BOND_LIKED_CAP = 25,          -- ... at most this many points a day per activity
    BOND_OTHER_POINTS = 1,        -- any other activity with it out
    BOND_OTHER_CAP = 5,           -- ... at most this many a day per activity
    BOND_OTHER_RATE = 0.5,        -- a pet you own but haven't adopted earns this share (points rounded up, its day 37)
    BOND_WISH_POINTS = 10,        -- today's wish done (Wish.lua), within the daily limit
    BOND_FIRST_POINTS = 10,       -- a first together: a boss this pet hasn't seen fall, a place it hasn't seen
    FIRST_LINES = 3,              -- ... lines about firsts in chat, per pet a day (the points don't stop)
    BOND_PLAY_POINTS = 15,        -- a playdate: in a group with a guildmate whose pet is out, once a day per pet
    BOND_DAILY_MAX = 75,          -- the most bond points a calendar day can bring (the day + activities); bounds the wire
    BOND_EPOCH = 1793487600,      -- 2026-10-31 23:00 UTC: no bond (or adoption it grew from) is older; bounds forgeries
    SYNC_MAX_ENTRIES = 2000,      -- entries per incoming SYNC part (records, names or bonds); more is junk, refused whole
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
-- and this is a single-guild addon. A player's key is "First Surname"
-- ("Hjelp Plask", or just "Hjelp" without a surname): ns.PlayerKey below.

-- How long ago t was: "today" and "yesterday" by the calendar date, else
-- "days", "months" or "years" by whole days, with the count.
local function Ago(t, now)
    if date("%Y%m%d", t) == date("%Y%m%d", now) or t > now then return "today" end
    -- Yesterday by the calendar: noon of the day before. (now - 86400 is
    -- wrong around DST: just after midnight following a 23-hour day it
    -- lands two calendar days back.)
    local d = date("*t", now)
    local yesterday = time({ year = d.year, month = d.month, day = d.day - 1, hour = 12 })
    if date("%Y%m%d", t) == date("%Y%m%d", yesterday) then return "yesterday" end
    local days = math.max(2, math.floor((now - t) / 86400))
    if days < 60 then return "days", days end
    -- Rounded, so it never says "1 måneder": 60 days is already "2 måneder".
    if days < 730 then return "months", math.floor(days / 30.44 + 0.5) end
    return "years", math.floor(days / 365.25)
end

-- How long, as a phrase to follow "Bor hos X": "siden i dag", "i 5 dager",
-- "i 3 måneder" (Locale/nb.lua, time.*).
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

function ns.PlayerKey()
    local first, surname = UnitName("player")
    if surname and surname ~= "" then return first .. " " .. surname end
    return first
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
    -- Unit names can be secret values (docs/FOREVER_API.md): unreadable is unknown.
    if ns.IsSecret(first) or ns.IsSecret(surname) then return nil end
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
