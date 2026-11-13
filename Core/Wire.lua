local _, ns = ...

-- What peers accept from the wire, in one place (2026-11-12; until then the
-- limits sat in five files, and "bump X-Protocol when one changes" was a rule
-- in memory). Everything here decides whether a message or an entry from
-- another client is kept, so changing a limit changes what peers agree on:
-- bump X-Protocol (the TOC) and the snapshot in tools/test/spec/52_protocol.lua,
-- which fails until both are done. The Config values that feed validation
-- (BOND_DAILY_MAX, BOND_EPOCH, CLOCK_SLACK, SYNC_MAX_ENTRIES, NICKNAME_MAX_LEN,
-- the per-member caps) stay in ns.Config, where the tunables are; the
-- snapshot covers them too.
--
-- Primitive checks only. A store's entries (a claim, a naming, a bond) are
-- checked in Registry, built from these.
local Wire = {}
ns.Wire = Wire

Wire.LIMITS = {
    KEY_LEN = 64,               -- a pet key's bytes ("s:<id>", "n:<name>"; Wire.Key)
    NAME_LEN = 48,              -- a player key's bytes ("First Surname"; Wire.Name)
    VERSION_LEN = 32,           -- a version from HELLO/VER (Wire.Version)
    NICK_BYTES_PER_CHAR = 4,    -- a nickname's byte cap: NICKNAME_MAX_LEN characters of UTF-8 at most (Wire.Nick)
    ACH_ID_LEN = 64,            -- a guild achievement id's bytes ...
    ACH_ID_PATTERN = "^guild:[%w:_]+$", -- ... and its shape
    GUILD_UNKNOWN_MAX = 64,     -- guild achievement ids we don't know, kept at most (Achievements)
    MAX_PARTS = 64,             -- chunks per incoming message (16 KB); more is junk (Comm)
    MAX_RAW = 512 * 1024,       -- bytes an incoming message may unpack to (Comm)
    DAY = 86400,                -- a bond's cap counts 24-hour steps (Wire.LifeCap)
    LIFE_SPARE_DAYS = 3,        -- ... plus the day it began and spare ones (2 until X-Protocol 10: a feat's 25 on a
                                --     full day didn't always fit)
    LAPSES_MAX = 1000,          -- lapses kept at most, the oldest going first (Registry: TrimLapses; X-Protocol 10)
}
local L = Wire.LIMITS
local Config = ns.Config

-- A time from the wire we can trust the shape of: a real number, not NaN or
-- infinite, and not more than a few minutes ahead of us (a far-future time
-- would win every merge and lock the record for good). Every client reads
-- the same server clock (GetServerTime); a day of slack let a forged lapse
-- block someone's claims for a day (code review 2026-11-10). A whole number
-- (X-Protocol 10): every honest time is GetServerTime's, and a copy of a
-- record a fraction of a second off could change who holds a pet.
function Wire.Time(t)
    return type(t) == "number" and t == t and t > 0 and t <= ns.Now() + Config.CLOCK_SLACK and math.floor(t) == t
end

-- ... and not older than the addon (BOND_EPOCH): nothing in the registry is,
-- and a time backdated to the dawn of time won every merge by "earliest"
-- (code review 2026-11-10).
function Wire.Since(t) return Wire.Time(t) and t >= Config.BOND_EPOCH end

-- Player keys from the wire: "First Surname", within reason.
function Wire.Name(s)
    return type(s) == "string" and s ~= "" and #s <= L.NAME_LEN
end

-- A pet key as Pets.lua makes them: "s:<species id>", or "n:<name>" for a
-- pet without a species id. No "|": a name key can reach the chat (the
-- playdate line), where it would be an escape code (code review 2026-11-09).
function Wire.Key(key)
    return type(key) == "string" and #key <= L.KEY_LEN and (key:find("^s:%d+$") ~= nil or key:find("^n:[^|]+$") ~= nil)
end

-- A version, as the packager makes them ("0.2.1", "0.2.1-beta2", "dev").
-- Anything else may not reach the chat: a "|" there is an escape code
-- (icons, links), and a table would throw on printing (code review 2026-11-09).
function Wire.Version(v)
    return type(v) == "string" and #v <= L.VERSION_LEN and v:find("^[%w%.%-]+$") ~= nil
end

-- A nickname: nil if fine, else why not ("empty", "too_long", "bad_chars").
-- The same check for a name from the wire and one typed here (Registry:
-- ValidNickname trims it first; until 2026-11-12 the two were separate, and
-- the typed one had no byte cap). The byte cap: Utf8Len counts only lead
-- bytes, so a string of stray continuation bytes would pass as short.
function Wire.Nick(n)
    if type(n) ~= "string" or n == "" then return "empty" end
    if #n > L.NICK_BYTES_PER_CHAR * Config.NICKNAME_MAX_LEN or ns.Utf8Len(n) > Config.NICKNAME_MAX_LEN then
        return "too_long"
    end
    if n:find("[|\n\r]") then return "bad_chars" end
end

-- A guild achievement's id (Achievements: ValidGuildRecord).
function Wire.AchId(id)
    return type(id) == "string" and #id <= L.ACH_ID_LEN and id:find(L.ACH_ID_PATTERN) ~= nil
end

-- The most points a day can bring a bond: BOND_DAILY_MAX, and the rewards
-- that go past it once a day (Bond.REWARDS: `beyond` and `once`, the wish's
-- 10). Since X-Protocol 10: until then a run of full days with every wish
-- done reached the cap after a week and was clamped from then on. A feat
-- (beyond, but once per character) fits in the spare days.
function Wire.DayRoom()
    local room = Config.BOND_DAILY_MAX
    for _, def in pairs(ns.Bond and ns.Bond.REWARDS or {}) do
        if def.beyond and def.once then room = room + Config[def.points] end
    end
    return room
end

-- The most points a bond can hold at time t, begun at f: a day's room
-- (DayRoom) a day, with days to spare (the daily limit follows the calendar,
-- this follows 24-hour steps from f: without a spare day, points earned early
-- on a calendar day could be clamped away; the third holds a feat). Bond:Add
-- and the migrations use it too, so every copy agrees.
function Wire.LifeCap(f, t)
    return (math.floor((t - f) / L.DAY) + L.LIFE_SPARE_DAYS) * Wire.DayRoom()
end

-- Field checks for Comm:Register's field specs, by name (names, not
-- functions, so the protocol snapshot can list them). Each takes the field's value.
Wire.CHECKS = {
    key = Wire.Key,
    version = Wire.Version,
    table = function(v) return type(v) == "table" end,
}
