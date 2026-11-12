local _, ns = ...

-- One frame for every game event. Modules subscribe with ns.Events:On and
-- unsubscribe with :Off; the frame only stays registered for events that
-- somebody is listening to, so idle features cost nothing.
--
-- Registering an event the client doesn't know throws on Forever and would
-- abort the file, so registration is pcall'd and reported once.
local Events = {}
ns.Events = Events

local frame = CreateFrame("Frame")
local handlers = {} -- event -> { [owner] = fn }
-- event -> { owner, fn, owner, fn, ... }: who listens, as an array, rebuilt only when that changes.
-- A handler may add or remove listeners of this very event, and changing a table pairs() is
-- walking can throw ("invalid key to 'next'"), so dispatch walks this instead. It used to copy
-- the listeners on every event: a table of garbage per CHAT_MSG_ADDON (every addon's traffic, in
-- a raid hundreds a second) and per COMPANION_UPDATE (every companion nearby). (Review 2026-11-12.)
local snapshots = {}

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    local snap = snapshots[event]
    if not snap then
        snap = {}
        for owner, fn in pairs(list) do snap[#snap + 1] = owner; snap[#snap + 1] = fn end
        snapshots[event] = snap
    end
    for i = 1, #snap, 2 do
        local owner, fn = snap[i], snap[i + 1]
        if list[owner] == fn then -- (still listening: an earlier handler may have removed it)
            local ok, err = pcall(fn, owner, event, ...)
            if not ok then geterrorhandler()(err) end
        end
    end
end)

-- owner: any table (usually the module); fn(owner, event, ...)
function Events:On(event, owner, fn)
    local list = handlers[event]
    if not list then
        local ok = pcall(frame.RegisterEvent, frame, event)
        if not ok then
            ns.Log("Events", "unknown event %s", event)
            return false
        end
        list = {}
        handlers[event] = list
    end
    if list[owner] ~= fn then list[owner] = fn; snapshots[event] = nil end
    return true
end

function Events:Off(event, owner)
    local list = handlers[event]
    if not list then return end
    if list[owner] ~= nil then list[owner] = nil; snapshots[event] = nil end
    if next(list) == nil then
        handlers[event] = nil
        frame:UnregisterEvent(event)
    end
end

-- Every event this owner listens to, off: a module going dormant needn't list them again.
function Events:OffAll(owner)
    local events = {}
    for event, list in pairs(handlers) do
        if list[owner] ~= nil then events[#events + 1] = event end
    end
    for _, event in ipairs(events) do self:Off(event, owner) end
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
