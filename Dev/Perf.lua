---@class Dyreparken
local ns = select(2, ...)

-- /dp probe perf (2026-11-14, the user: better tools in game; the review that found 0.6.2's sensors hearing
-- every unit's casts): calls and time per event handler (by event and the module listening), Bus event and
-- activity source, from /dp probe perf on until off. ns.profile is the one hook (Events, Bus, Activity check
-- it per call); a release never sets it. With C_AddOnProfiler (the client's own numbers, as AddonProfiler
-- shows them), the addon's average and peak frame time too. A handler's time includes what it calls: the
-- Bus's and the sources' rows are inside their events' rows.
if not ns.DEV then return end
---@class Dyreparken.Perf
local Perf = { rows = {} }
ns.Perf = Perf

-- A module's name by its table (ns.Quirks -> "Quirks"), for an event's owner.
local names
local function NameOf(owner)
    if owner == nil then return nil end
    if not names then
        names = {}
        for k, v in pairs(ns) do if type(v) == "table" then names[v] = k end end
    end
    return names[owner] or (type(owner) == "table" and type(owner.name) == "string" and owner.name) or "?"
end

local function Record(name, ms, owner)
    local who = NameOf(owner)
    local key = who and (name .. " " .. who) or name
    local r = Perf.rows[key]
    if not r then r = { n = 0, ms = 0, max = 0 }; Perf.rows[key] = r end
    r.n, r.ms = r.n + 1, r.ms + ms
    if ms > r.max then r.max = ms end
end

function Perf:Start()
    self.rows, self.since = {}, GetTime()
    names = nil
    ns.profile = Record
end
function Perf:Stop() ns.profile = nil end

-- The rows, the costliest first: { key, n, ms, max }.
function Perf:Top()
    local list = {}
    for k, r in pairs(self.rows) do list[#list + 1] = { key = k, n = r.n, ms = r.ms, max = r.max } end
    table.sort(list, function(a, b) return a.ms > b.ms end)
    return list
end

local function Client()
    local P, M = C_AddOnProfiler, Enum and Enum.AddOnProfilerMetric
    if not (P and P.GetAddOnMetric and M) then return nil end
    local function Get(metric)
        local ok, v = pcall(P.GetAddOnMetric, "Dyreparken", metric)
        return ok and ns.Plain(v) or nil
    end
    local avg, peak, recent = Get(M.SessionAverageTime), Get(M.PeakTime), Get(M.RecentAverageTime)
    if not (avg or peak or recent) then return nil end
    return ("the client's: session average %.3f ms a frame, recent %.3f, peak %.1f"):format(avg or 0, recent or 0, peak or 0)
end

function Perf:Show()
    local list = self:Top()
    local span = GetTime() - (self.since or GetTime())
    local total = 0
    for _, r in ipairs(list) do total = total + r.n end
    ns.Print(("Perf: %d calls in %d s, %d rows%s."):format(total, span, #list, ns.profile and "" or " (stopped)"))
    for i, r in ipairs(list) do
        local line = ("%-40s %6d calls  %8.2f ms  %6.1f us each  max %.2f ms"):format(r.key, r.n, r.ms,
            r.ms * 1000 / r.n, r.max)
        if i <= 8 then ns.Print(line) end
        ns.Log("Perf", "%s", line)
    end
    local client = Client()
    if client then ns.Print(client); ns.Log("Perf", "%s", client) end
end

-- /dp probe perf [on|off|show]: on starts (and clears), off stops and shows, show shows; bare: on, or show.
function Perf:Command(arg)
    if arg == "on" or (not arg and not ns.profile) then
        self:Start()
        return ns.Print("Perf on: every handler timed until /dp probe perf off.")
    end
    if arg == "off" then self:Stop() end
    self:Show()
end
