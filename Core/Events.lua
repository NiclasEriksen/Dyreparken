local _, ns = ...

-- One frame for every game event (and one per unit, for a unit's events only). Modules
-- subscribe with ns.Events:On and unsubscribe with :Off; a frame only stays registered for
-- events that somebody is listening to, so idle features cost nothing.
--
-- Registering an event the client doesn't know throws on Forever and would
-- abort the file, so registration is pcall'd and reported once.
local Events = {}
ns.Events = Events

-- A hub is one frame and who listens on it. The main hub hears an event from every unit; a unit's
-- hub (Events:On(event, owner, fn, "player")) registers it with RegisterUnitEvent for that unit only:
-- UNIT_SPELLCAST_SUCCEEDED or UNIT_AURA for every unit nearby is hundreds of calls a second in a raid,
-- each bailing on its first line (2026-11-14: the class reactions shipped in 0.6.2 so).
local hubs = {} -- unit (or true: every unit) -> { frame, handlers, snapshots }

local function Dispatch(hub, event, ...)
    local list = hub.handlers[event]
    if not list then return end
    -- event -> { owner, fn, owner, fn, ... }: who listens, as an array, rebuilt only when that changes.
    -- A handler may add or remove listeners of this very event, and changing a table pairs() is
    -- walking can throw ("invalid key to 'next'"), so dispatch walks this instead. It used to copy
    -- the listeners on every event: a table of garbage per CHAT_MSG_ADDON (every addon's traffic, in
    -- a raid hundreds a second) and per COMPANION_UPDATE (every companion nearby). (Review 2026-11-12.)
    local snap = hub.snapshots[event]
    if not snap then
        snap = {}
        for owner, fn in pairs(list) do snap[#snap + 1] = owner; snap[#snap + 1] = fn end
        hub.snapshots[event] = snap
    end
    for i = 1, #snap, 2 do
        local owner, fn = snap[i], snap[i + 1]
        if list[owner] == fn then -- (still listening: an earlier handler may have removed it)
            local ok, err = pcall(fn, owner, event, ...)
            if not ok then geterrorhandler()(err) end
        end
    end
end

local function Hub(unit)
    local id = unit or true
    local hub = hubs[id]
    if not hub then
        hub = { frame = CreateFrame("Frame"), handlers = {}, snapshots = {}, unit = unit }
        hub.frame:SetScript("OnEvent", function(_, event, ...) Dispatch(hub, event, ...) end)
        hubs[id] = hub
    end
    return hub
end
Hub(nil) -- (the main one first)

-- owner: any table (usually the module); fn(owner, event, ...); unit: only that unit's (a UNIT_ event)
function Events:On(event, owner, fn, unit)
    local hub = Hub(unit)
    local list = hub.handlers[event]
    if not list then
        local ok
        if unit then
            ok = pcall(hub.frame.RegisterUnitEvent, hub.frame, event, unit)
        else
            ok = pcall(hub.frame.RegisterEvent, hub.frame, event)
        end
        if not ok then
            ns.Log("Events", "unknown event %s", event)
            return false
        end
        list = {}
        hub.handlers[event] = list
    end
    if list[owner] ~= fn then list[owner] = fn; hub.snapshots[event] = nil end
    return true
end

function Events:Off(event, owner, unit)
    local hub = hubs[unit or true]
    local list = hub and hub.handlers[event]
    if not list then return end
    if list[owner] ~= nil then list[owner] = nil; hub.snapshots[event] = nil end
    if next(list) == nil then
        hub.handlers[event] = nil
        hub.frame:UnregisterEvent(event)
    end
end

function Events:Has(event, owner, unit)
    local hub = hubs[unit or true]
    return hub ~= nil and hub.handlers[event] ~= nil and hub.handlers[event][owner] ~= nil
end

-- Every event this owner listens to, off, on every hub: a module going dormant needn't list them again.
function Events:OffAll(owner)
    for _, hub in pairs(hubs) do
        local events = {}
        for event, list in pairs(hub.handlers) do
            if list[owner] ~= nil then events[#events + 1] = event end
        end
        for _, event in ipairs(events) do self:Off(event, owner, hub.unit) end
    end
end

-- What's registered now, for /dp state and the tests: { "EVENT" or "EVENT@unit" = listeners }.
function Events:Registered()
    local out = {}
    for _, hub in pairs(hubs) do
        for event, list in pairs(hub.handlers) do
            local n = 0
            for _ in pairs(list) do n = n + 1 end
            out[hub.unit and (event .. "@" .. hub.unit) or event] = n
        end
    end
    return out
end

-- Run fn once, now if out of combat, else right after combat ends.
local afterCombat = {}
function Events:OutOfCombat(fn)
    if not ns.InCombat() then return fn() end
    afterCombat[#afterCombat + 1] = fn
    Events:On("PLAYER_REGEN_ENABLED", afterCombat, function()
        Events:Off("PLAYER_REGEN_ENABLED", afterCombat)
        local queue = { unpack(afterCombat) }
        wipe(afterCombat)
        for i = 1, #queue do
            local ok, err = pcall(queue[i])
            if not ok then geterrorhandler()(err) end
        end
    end)
end
