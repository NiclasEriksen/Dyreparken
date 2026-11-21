---@class Dyreparken
local ns = select(2, ...)

-- /dp state (2026-11-14, the user: "we both need better tools to log / test in game"): why nothing is said
-- right now, at a glance. The pet out and its day of points, the cooldowns of the quirk lines and the
-- reactions and what's on its way, what was said today, today's wish, and what the addon listens to.
-- A few lines in chat; the whole of it in the debug log too (/dp state, then /reload, tools/log.lua -m State).
if not ns.DEV then return end
---@class Dyreparken.State
local State = {}
ns.State = State

local function Left(seconds) return seconds <= 0 and "free" or ("in %dm"):format(math.ceil(seconds / 60)) end
local function Today(store)
    local out, today = {}, ns.Today()
    for id, e in pairs(store or {}) do
        if type(e) == "table" and e.day == today then out[#out + 1] = id end
    end
    table.sort(out)
    return #out > 0 and table.concat(out, " ") or "none"
end
local function Keys(t, fmt)
    local out = {}
    for k, v in pairs(t) do out[#out + 1] = fmt and fmt(k, v) or tostring(k) end
    table.sort(out)
    return out
end

-- Lines: { short (chat), ... }, and the long ones only for the log.
function State.Lines()
    local char = ns.DB.char
    local key, mine = ns.Pets:OutKey(), ns.Registry:MyPet()
    local lines, long = {}, {}
    local points, level = 0, 0
    if key then points, level = ns.Bond:Own(key) end
    local got, max = ns.Bond:Today(key)
    lines[#lines + 1] = ("pet out %s%s, bond %s (level %s), today %d/%d"):format(tostring(key),
        key and key == mine and " (adopted)" or (mine and (", adopted " .. mine) or ""), tostring(points), tostring(level),
        got or 0, max or 0)
    local M = ns.Moments
    lines[#lines + 1] = ("quirks: %s; eggs today: %s"):format(Left(M:Left("quirk")), Today(char.eggs))
    local rows = ns.Reactions.mine and #ns.Reactions.mine or 0
    lines[#lines + 1] = ("reactions (%d rows of your class): %s; said today: %s%s"):format(rows,
        Left(M:Left("react")), Today(char.reacts), M:Pending() and ("; on its way: " .. M:Pending()) or "")
    local w = char.wish
    lines[#lines + 1] = w and w.day == ns.Today() and ("wish: %s%s, %s, watching %s"):format(w.id, w.zone and (" (" .. w.zone .. ")") or "",
        w.done and "done" or "not yet", tostring(ns.Wish:Armed())) or "wish: none made yet today (it is, the first time your adopted pet is out or its card shows)"
    local events = ns.Events:Registered()
    local wanted = ns.Activity:Wanted()
    local sensing = {}
    for _, kind in ipairs(ns.Sense.KINDS) do if ns.Sense:Wants(kind) then sensing[#sensing + 1] = kind end end
    lines[#lines + 1] = ("listening: %d events, %d activities wanted, sensors: %s; log %s%s"):format(#Keys(events),
        #Keys(wanted), #sensing > 0 and table.concat(sensing, " ") or "none", ns.Debug.enabled and "on" or "off",
        ns.Errors and ns.Errors.count > 0 and (", " .. ns.Errors.count .. " errors of ours") or "")
    long[#long + 1] = "events: " .. table.concat(Keys(events, function(k, n) return n > 1 and (k .. "x" .. n) or k end), " ")
    long[#long + 1] = "activities: " .. table.concat(Keys(wanted), " ")
    local muted = ns.Debug:Mute()
    if #muted > 0 then long[#long + 1] = "muted: " .. table.concat(muted, " ") end
    return lines, long
end

function State:Show()
    local lines, long = self.Lines()
    for _, line in ipairs(lines) do
        ns.Print(line)
        ns.Log("State", "%s", line)
    end
    for _, line in ipairs(long) do ns.Log("State", "%s", line) end
end

ns.Commands.Add("state", "state - why nothing is said now: cooldowns, today's lines, the wish, events (development)",
    function() State:Show() end)

-- The session's context, once the login is over (2026-11-19): the Session line at loaded can't say where the
-- player is (the zone is blank then), and every read of the log starts with who, where and with which pet.
function State.Context()
    local function Plain(fn, ...) local ok, v = pcall(fn, ...); if ok then return ns.Plain(v) end end
    local members, owned = Plain(GetNumGuildMembers) or 0, 0
    for _ in pairs(ns.Pets:Owned()) do owned = owned + 1 end
    local sub = Plain(GetSubZoneText)
    return ("settled in %s%s, guild %s (%d members), %d pets owned, adopted %s, out %s"):format(
        tostring(Plain(GetZoneText)), (sub and sub ~= "") and (" (" .. sub .. ")") or "", tostring((GetGuildInfo("player"))),
        members, owned, tostring((ns.Registry:MyPet())), tostring((ns.Pets:OutKey())))
end
ns.Start("settled", function()
    if ns.Debug.enabled then ns.Log("Session", "%s", State.Context()) end
    ns.Debug.context = State.Context -- (a log turned on later says it with its Session line)
end)
