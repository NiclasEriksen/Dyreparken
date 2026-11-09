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

frame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    -- A copy: a handler may add or remove listeners of this very event, and
    -- changing a table pairs() is walking can throw ("invalid key to 'next'").
    local copy = {}
    for owner, fn in pairs(list) do copy[owner] = fn end
    for owner, fn in pairs(copy) do
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
    list[owner] = fn
    return true
end

function Events:Off(event, owner)
    local list = handlers[event]
    if not list then return end
    list[owner] = nil
    if next(list) == nil then
        handlers[event] = nil
        frame:UnregisterEvent(event)
    end
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
