local _, ns = ...

-- Debug log. When debug mode is on, lines go to a capped ring buffer in
-- DyreparkenDebugDB, which the client writes to
--   WTF/Account/<ACCOUNT>/SavedVariables/Dyreparken.lua
-- on /reload or logout. Each entry is one tab-separated string,
--   "<serverTime>\t<GetTime>\t<module>\t<message>"
-- so it's easy to parse outside the game. When debug is off, Log is a no-op
-- that doesn't even format its arguments.
local Debug = { enabled = false }
ns.Debug = Debug

local buf -- DyreparkenDebugDB.lines, bound by Debug:Init

local function noop() end
ns.Log = noop

local function Write(module, fmt, ...)
    local ok, msg = pcall(string.format, fmt, ...)
    if not ok then msg = tostring(fmt) end
    local line = ns.Now() .. "\t" .. string.format("%.3f", GetTime()) .. "\t" .. tostring(module) .. "\t" .. msg
    local i = (buf.head % ns.Config.DEBUG_RING_SIZE) + 1
    buf.head = i
    buf[i] = line
    if Debug.echo then ns.Print("|cff999999[" .. module .. "]|r " .. msg) end
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
    ns.Bus:Fire("DEBUG", self.enabled) -- probes that only listen while logging (Achievements/Kills.lua)
end

function Debug:Clear()
    DyreparkenDebugDB.lines = { head = 0 }
    buf = DyreparkenDebugDB.lines
end

ns.Start("loaded", function() Debug:Init() end) -- (first: everything after may log)
