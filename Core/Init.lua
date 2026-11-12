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

-- Every chance the addon rolls (a line's variant, an egg's odds, a move) goes through
-- ns.random, math.random's signature: one seam for the tests to pin (c:Dice).
-- Timing jitter (Sync, Achievements) and cosmetic scatter (Fx) use math.random.
ns.random = math.random

-- A value the client may hand us as a secret (docs/FOREVER_API.md): nil
-- then, so nothing compares, indexes or prints it.
function ns.Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- A calendar day as "YYYYMMDD" (the local clock, from server time): the
-- day the daily limit, the wish, the cuddle and the counters belong to.
function ns.Today(t) return date("%Y%m%d", t or ns.Now()) end

-- lower() leaves Æ, Ø and Å alone (bytes, not letters): "/dp KUNNGJØR PÅ".
function ns.Lower(s)
    return (s:lower():gsub("Æ", "æ"):gsub("Ø", "ø"):gsub("Å", "å"))
end

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

-- A one-text tooltip on a frame (anchor: "ANCHOR_TOP"...); text is a string
-- or fn(frame) -> string (nil: no tooltip). White, wrapped.
function ns.SetTip(frame, anchor, text)
    frame:SetScript("OnEnter", function(self)
        local s = text
        if type(s) == "function" then s = s(self) end
        if not s then return end
        GameTooltip:SetOwner(self, anchor)
        GameTooltip:SetText(s, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", ns.HideTip)
end

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

-- Every variant of a line: prefix.1, prefix.2, ... (Locale/nb.lua), as keys; {} for none.
-- Kept once found (the strings don't change while playing).
local variants = {}
function ns.Variants(prefix)
    local list = variants[prefix]
    if not list then
        list = {}
        while strings[prefix .. "." .. (#list + 1)] do list[#list + 1] = prefix .. "." .. (#list + 1) end
        variants[prefix] = list
    end
    return list
end

-- One variant of a line at random (ns.random), filled; nil when it has none.
function ns.PickLine(prefix, vars)
    local list = ns.Variants(prefix)
    if #list == 0 then return nil end
    return ns.T(list[ns.random(#list)], vars)
end

-- A pet's own line: purple in chat (unless Settings' chatLines is off; `always`: said anyway, for
-- lines that answer something you did or reached, not the random ones chatLines is about:
-- the user, 2026-11-12)
-- and, with a key and a kind, on the pet frame (PET_SAID: "say", "like", "dislike", "major").
function ns.PetSays(text, key, kind, always)
    if always or ns.Settings:On("chatLines") then ns.Print("|cffd9b3ff" .. text .. "|r") end
    if key and kind then ns.Bus:Fire("PET_SAID", key, kind, text) end
end

-- Start-up: each module says in its own file when it starts
-- (ns.Start(phase, fn)); Main.lua runs the phases. Within a phase, modules
-- start in load order (the TOC), so a module starts after the ones it uses.
--   loaded   SavedVariables are there (ADDON_LOADED): data, handlers, hooks
--   login    the character is in the world (PLAYER_LOGIN)
--   settled  10 s on, the login burst is over: the roster, our own record
--   hello    last: tell the guild where we stand (the digest is current now)
ns.PHASES = { "loaded", "login", "settled", "hello" }
local starts = {}
for _, phase in ipairs(ns.PHASES) do starts[phase] = {} end

function ns.Start(phase, fn)
    local list = assert(starts[phase], "unknown start-up phase")
    list[#list + 1] = fn
end

-- One module's error (a new client build without an API it uses, say) is reported
-- and the rest of the phase still starts: Sync and Achievements shouldn't stop
-- for a card decoration.
function ns.RunPhase(phase)
    for _, fn in ipairs(starts[phase]) do
        local ok, err = pcall(fn)
        if not ok then geterrorhandler()(err) end
    end
end

-- fn once, delay seconds after the first call of a burst: the calls that
-- follow within the delay are folded into it (fn gets the first call's arguments).
function ns.Debounce(delay, fn)
    local pending = false
    return function(...)
        if pending then return end
        pending = true
        local n, args = select("#", ...), { ... }
        C_Timer.After(delay, function()
            pending = false
            fn(unpack(args, 1, n))
        end)
    end
end

-- The channel to reach our group on, or nil when solo.
function ns.GroupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

-- Tunables. Keep them here so they're easy to find and change.
ns.Config = {
    INACTIVE_RELEASE_DAYS = 30,   -- reservation released after this long unseen
    ROSTER_LAPSE_SHARE = 1 / 3,   -- one roster read lapsing more than this share of adoptions at once is held back (Registry:CheckRoster) ...
    ROSTER_LAPSE_FLOOR = 3,       -- ... unless it's at most this many
    NICKNAME_LEVEL = 3,           -- the bond level (Venn) at which a pet's carer may name it (Bond.lua)
    NICKNAME_MAX_LEN = 20,        -- characters (UTF-8 aware, see ns.Utf8Len)
    NICKNAME_FIX = 600,           -- seconds after the day's first new name when changes are free (a typo); then tomorrow
    NAME_LINES = 3,               -- name lines in guild chat a day, at most (Bonds:Announce)
    BOND_DAY_POINTS = 10,         -- bond points for a day with your adopted companion out
    BOND_LIKED_POINTS = 5,        -- an activity your companion likes (Personality.lua), with it out
    BOND_LIKED_CAP = 25,          -- ... at most this many points a day per activity
    BOND_MINOR_POINTS = 2,        -- a minor like (Personality: unlocked by your bond at MINOR_LIKE_LEVEL) ...
    BOND_MINOR_CAP = 10,          -- ... at most this many points a day (the user, 2026-11-12)
    MINOR_LIKE_LEVEL = 4,         -- your bond level with a pet that unlocks its minor like ...
    MINOR_DISLIKE_LEVEL = 6,      -- ... and its minor dislike (a secret until it happens, as dislikes are)
    BOND_OTHER_POINTS = 1,        -- any other activity with it out
    BOND_OTHER_CAP = 3,           -- ... at most this many a day per activity (5 until 2026-11-10)
    BOND_OTHER_TOTAL = 10,        -- ... and all of them together (2026-11-10: likes are what fill a day)
    BOND_TRAIT_CAP = 10,          -- a trait's moment (Friluftsdyr outdoors...): this many a day per trait (25 until 2026-11-10)
    BOND_OTHER_RATE = 0.5,        -- a pet you own but haven't adopted earns this share (points rounded up, its day 37)
    BOND_WISH_POINTS = 10,        -- today's wish done (Wish.lua), within the daily limit
    BOND_FIRST_POINTS = 5,        -- a first together: a boss this pet hasn't seen fall, a place it hasn't seen (10 until 2026-11-10)
    BOND_FIRST_CAP = 15,          -- ... at most this many a day (2026-11-10: one dungeon of firsts filled the day)
    FIRST_LINES = 3,              -- ... lines about firsts in chat, per pet a day (the points don't stop)
    BOND_CONTEST_POINTS = 10,     -- fishing in the Sunday fishing contest, a pet that likes fishing, once a day
    BOND_PLAY_POINTS = 15,        -- a playdate: in a group with a guildmate whose pet is out, once a day per pet
    BOND_FEAT_POINTS = 25,        -- a feat (Feats.lua): a class quest's reward, riding, level 60; once per character, past the day's limit
    BOND_DAILY_MAX = 75,          -- the most bond points a calendar day can bring (the day + activities); bounds the wire
    BOND_EPOCH = 1793487600,      -- 2026-10-31 23:00 UTC: no bond (or adoption it grew from) is older; bounds forgeries
    CLOCK_SLACK = 300,            -- seconds a time from the wire may be ahead of ours (Wire.Time)
    BONDS_SHIPPED = 1794178800,   -- 2026-11-08 23:00 UTC (0.1.0-alpha4): adoptions before it are seeded (Bond:Seed)
    SYNC_MAX_ENTRIES = 2000,      -- entries per incoming SYNC part (records, names or bonds); more is junk, refused whole
    NAMES_PER_MEMBER = 50,        -- nickname entries kept per namer, and ...
    LIFE_PER_MEMBER = 400,        -- ... bond entries per carer: past that the oldest go (Registry: Trim)
    -- Sync's timings (Sync.lua says why each is what it is). Local: peers don't need to agree on them.
    SYNC_GAP = 30,                -- seconds between two SYNCs of ours, at least
    SYNC_HOLD = 30,               -- seconds ours waits for someone else's SYNC that started arriving
    SYNC_MAX_HOLD = 120,          -- ... and however often it's held, it goes this long after it was scheduled
    BOND_ASK_GAP = 1.5,           -- seconds between two BOND_REQs of ours (flicking through cards)
    BOND_ANSWERS = 10,            -- BOND answers one asker gets from us ...
    BOND_ANSWER_WINDOW = 60,      -- ... per this many seconds ...
    BOND_ANSWER_BACKLOG = 2,      -- ... and none while our outbox has more chunks than this
    COMM_BURST = 8,               -- chunks the outbox sends at once, of the server's 10 (Comm.lua)
    REPLY_GAP = 5,                -- seconds between two answers to a request anyone can send, per channel
    ROSTER_INTERVAL = 300,        -- seconds between two roster requests (Guild.lua), unless forced
    ROSTER_TIMEOUT = 15,          -- seconds to wait for the server's roster before reading the cached one
    ACH_NOTICE_MAX = 20,          -- achievement ids read from one ACH_EARNED; more than any real batch
    ACH_HEARD_MAX = 500,          -- others' achievements remembered as told (the oldest go first)
    DEBUG_RING_SIZE = 8000,       -- lines kept in DyreparkenDebugDB (a long play session's worth: 2026-11-11)
    COMM_PREFIX = "Dyreparken",   -- max 16 characters
}

------------------------------------------------------------------------------
-- Tiny event bus between modules (not game events, see Events.lua).
------------------------------------------------------------------------------
local listeners = {}
ns.Bus = {}
-- Every event, with what it carries. The test harness fails a test that fires
-- or listens to one not listed here (a typo would otherwise just never
-- arrive); the addon itself doesn't check, so it costs nothing in the game.
ns.Bus.EVENTS = {
    -- Core
    DEBUG = "on: the debug log was turned on or off (Debug)",
    ROSTER = "(none): the guild roster snapshot was refreshed (Guild)",
    COMM_INCOMING = "sender, channel: an addon message of ours arrived and was decoded (Comm)",
    PROTOCOL_MISMATCH = "sender, theirProtocol, msg: a message from another X-Protocol (Comm)",
    ACTIVITY = "id, n, key, mine, extra: an activity counted; key the pet out (or nil), mine whether it's yours adopted (Activity)",
    SIDEPAGE = "open: one of our Collections pages opened (true) or closed (false) (SidePage)",
    -- The registry and the pet that's out
    REGISTRY = "keys: the guild registry changed, ours or a peer's; keys { [petKey] = true } if only those pets' bonds did, else nil (Registry)",
    MY_RECORD = "me, record: this character's adoption record was written (Registry)",
    MY_NAME = "key, entry: this character named or renamed a pet (Registry)",
    ADOPTED = "key: this character adopted a pet (Registry)",
    ACTIVE_PET = "key: the pet auto-summon keeps out changed (Summon)",
    PET_OUT = "key: auto-summon found its pet already out (Summon:Check); Activity starts the day's visit if due, before Check goes on",
    COMPANION_SEEN = "speciesID, owner: a companion's tooltip showed in the world (Tooltip)",
    HOLIDAYS = "(none): today's holidays were read from the calendar (Holidays)",
    -- Bonds
    BOND = "key: a pet's bond points changed (Bond:Add)",
    MY_BOND = "key, entry: this character's bond entry to publish to the guild (Bond)",
    BOND_LEVEL = "key, level, levelName: a bond of yours reached a new level (Bond)",
    BOND_FULL = "key: a pet's day is full (Bond)",
    BOND_LINE = "key, text, kind: a bond reward's line to show (Bond: a like, a wish, a first, a playdate ...)",
    PET_SAID = "key, bubble, text: a pet's line, for the pet frame's bubble (say, dislike, like, major, or an egg's own)",
    WISH_DONE = "(none): a wish came true, counted for the day (Wish)",
    FEAT = "featID, key: a feat's reward went to the pet out (Feats); nothing listens yet",
    -- Quirks and achievements
    DISLIKE_FOUND = "key, activity: a dislike happened for the first time (Quirks)",
    EGG_FOUND = "eggID: an easter egg found for the first time (Quirks)",
    ACH = "(none): achievements changed: earned, seen or shared (Achievements)",
}
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

-- How long, as a phrase to follow "Har bodd hos X": "siden i dag", "i 5 dager",
-- "i 3 måneder" (Locale/nb.lua, time.*).
function ns.CaredFor(t, now)
    local kind, n = Ago(t, now or ns.Now())
    return ns.T("time." .. kind, { n = n })
end

-- Where a pet lives, and since when, as a phrase: "Flyttet inn hos deg i
-- dag", "... i går", else "Har bodd hos Kari Berg i 3 dager" (2026-11-10: past tense; 2026-11-08: "bor
-- hos deg siden i dag" read badly). who: a name, or ns.L["home.you"].
function ns.Home(who, t, now)
    local kind = Ago(t, now or ns.Now())
    if kind == "today" or kind == "yesterday" then return ns.T("home." .. kind, { who = who }) end
    return ns.T("home.since", { who = who, how = ns.CaredFor(t, now) })
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
-- Numbers before any "-" are compared first; on a tie the label decides
-- (alpha < beta < any other label < release: 0.1.0-alpha3 < 0.1.0-beta1 <
-- 0.1.0), then its trailing numbers (beta2 > beta1). "dev" equals everything.
-- (Labels were ignored until 2026-11-11: alpha3 came out ahead of beta1.)
local LABEL_RANK = { alpha = 1, beta = 2 }
local OTHER_RANK, RELEASE_RANK = 3, 4
local function ParseVersion(v)
    v = tostring(v or "")
    local core, pre = v:match("^v?([%d%.]+)%-?(.*)$")
    local nums = {}
    for n in (core or ""):gmatch("%d+") do nums[#nums + 1] = tonumber(n) end
    local preNums = {}
    for n in (pre or ""):gmatch("%d+") do preNums[#preNums + 1] = tonumber(n) end
    local rank = RELEASE_RANK
    if pre and pre ~= "" then rank = LABEL_RANK[(pre:match("^%a+") or ""):lower()] or OTHER_RANK end
    return nums, rank, preNums, core ~= nil
end

local function CompareLists(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x < y and -1 or 1 end
    end
    return 0
end

function ns.CompareVersions(a, b)
    local na, rankA, pnA, okA = ParseVersion(a)
    local nb, rankB, pnB, okB = ParseVersion(b)
    if not okA or not okB then return 0 end -- "dev" or garbage
    local c = CompareLists(na, nb)
    if c ~= 0 then return c end
    if rankA ~= rankB then return rankA < rankB and -1 or 1 end
    return CompareLists(pnA, pnB)
end

-- InCombatLockdown only: unit queries can return secret booleans on Forever.
function ns.InCombat()
    return InCombatLockdown()
end
