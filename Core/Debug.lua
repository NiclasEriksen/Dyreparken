---@class Dyreparken
local ns = select(2, ...)

-- Debug log. When debug mode is on, lines go to a capped ring buffer in
-- DyreparkenDebugDB, which the client writes to
--   WTF/Account/<ACCOUNT>/SavedVariables/Dyreparken.lua
-- on /reload or logout. Each entry is one tab-separated string,
--   "<serverTime>\t<GetTime>\t<module>\t<message>"
-- so it's easy to parse outside the game (tools/log.lua reads it). When debug is
-- off, Log is a no-op that doesn't even format its arguments.
--
-- 2026-11-14 (the user: "we both need better tools to log / test in game"): a line
-- like the one before it adds " (xN)" to it instead of a new line (Moves logged
-- 2500 animation plays a session, pushing out the rest); a muted module
-- (/dp debug mute Moves, DyreparkenDebugDB.mute) logs nothing; and every login
-- starts with a "Session" line, where tools/log.lua splits the log.
---@class Dyreparken.Debug
local Debug = { enabled = false }
ns.Debug = Debug

local buf -- DyreparkenDebugDB.lines, bound by Debug:Init
local mute = {} -- DyreparkenDebugDB.mute: module -> true
local last, again, first -- the last line's module and message, how many times since, and its line as written

local function noop() end
ns.Log = noop

local function Write(module, fmt, ...)
    module = tostring(module)
    if mute[module] then return end
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    local key = module .. "\t" .. msg
    if key == last and buf[buf.head] then
        again = again + 1
        buf[buf.head] = first .. " (x" .. again .. ")"
        return
    end
    last, again = key, 1
    first = ns.Now() .. "\t" .. string.format("%.3f", GetTime()) .. "\t" .. key
    local i = (buf.head % ns.Config.DEBUG_RING_SIZE) + 1
    buf.head = i
    buf[i] = first
    if Debug.echo then ns.Print("|cff999999[" .. module .. "]|r " .. msg) end
end

-- Muted modules log nothing: on (true) or off (false), or nil to list them.
function Debug:Mute(module, on)
    if module ~= nil then
        mute[module] = on and true or nil
        DyreparkenDebugDB.mute = mute
    end
    local list = {}
    for m in pairs(mute) do list[#list + 1] = m end
    table.sort(list)
    return list
end

-- Where a session starts in the log: who, where, which build (tools/log.lua splits here).
function Debug:Session()
    if not self.enabled then return end
    local function Plain(fn, ...) local ok, a, b, c, d = pcall(fn, ...); if ok then return ns.Plain(a), ns.Plain(b), ns.Plain(c), ns.Plain(d) end end
    local _, class = Plain(UnitClass, "player")
    local version, build, _, interface = Plain(GetBuildInfo)
    ns.Log("Session", "start %s, %s %s level %s, in %s, client %s (%s, %s), protocol %s",
        tostring(ns.VERSION), tostring(ns.PlayerKey()), tostring(class), tostring(Plain(UnitLevel, "player")),
        tostring(Plain(GetZoneText)), tostring(version), tostring(build), tostring(interface), tostring(ns.PROTOCOL))
end

function Debug:Init()
    -- A release keeps nothing of a log (review 2026-11-12): players who had /dp debug before
    -- 0.2 (or ran a git checkout) carried its lines and the probes' dumps (api, animLengths:
    -- a megabyte or more), read in at every login and written out at every logout.
    if not ns.DEV then DyreparkenDebugDB = nil end
    DyreparkenDebugDB = DyreparkenDebugDB or {}
    local db = DyreparkenDebugDB
    db.lines = db.lines or { head = 0 }
    buf = db.lines
    mute = type(db.mute) == "table" and db.mute or {}
    last = nil
    -- Only a git checkout logs (2026-11-09: /dp debug is a developer command
    -- now). A release turns off a log left on from before, which nothing
    -- could turn off any more.
    self:SetEnabled(ns.DEV and db.enabled, db.echo)
end

-- ns.Log("Comm", "sent %s to %s", kind, channel)
function Debug:SetEnabled(on, echo)
    self.enabled, self.echo = not not on, not not echo
    DyreparkenDebugDB.enabled, DyreparkenDebugDB.echo = self.enabled, self.echo
    ns.Log = self.enabled and Write or noop
    ns.Log("Debug", "enabled %s, echo=%s", ns.VERSION, tostring(self.echo))
    ns.Bus:Fire("DEBUG", self.enabled) -- probes that only listen while logging (Dev/Kills.lua)
end

function Debug:Clear()
    DyreparkenDebugDB.lines = { head = 0 }
    buf = DyreparkenDebugDB.lines
    last = nil
end

ns.Start("loaded", function() Debug:Init() end) -- (first: everything after may log)
ns.Start("login", function() Debug:Session() end)
