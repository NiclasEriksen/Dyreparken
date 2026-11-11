local _, ns = ...

-- The game's own holidays (2026-11-11, the user: "go by ingame events as well"): from the
-- calendar, today's events read once a day. The calendar loads them a moment after
-- OpenCalendar (CALENDAR_UPDATE_EVENT_LIST, listened to only while asking). Known by event
-- id, since their names come in the client's language; the ids are Forever's, found with
-- /dp probe api holidays (docs/FOREVER_API.md). Left out: the Darkmoon Faire (every month:
-- too often, the user), the weekly Stranglethorn fishing contest, and the Call to Arms
-- battleground weekends. They count like our own holidays (Personality.Holiday): Festglad's
-- day, its confetti, and an easter egg each (Quirks).
local Holidays = {}
ns.Holidays = Holidays

-- event id -> our word for it (Locale holiday.game.<word>, egg.<word>.N)
Holidays.IDS = {
    [327] = "lunar",       -- Lunar Festival
    [335] = "love",        -- Love is in the Air
    [181] = "noblegarden", -- Noblegarden
    [341] = "midsummer",   -- Midsummer Fire Festival
    [321] = "harvest",     -- Harvest Festival
    [324] = "hallowsend",  -- Hallow's End
    [141] = "winterveil",  -- Feast of Winter Veil
}

-- Other calendar events that aren't holidays (Festglad doesn't celebrate them), for eggs.
Holidays.EVENTS = {
    [301] = "stvfishing",  -- Stranglethorn Fishing Extravaganza (Sundays)
}

local today -- { day = "YYYYMMDD", word = the holiday's or false, events = { word = true } }

-- The game holiday on the day of t (our word), or nil. Only today's is known: other days,
-- nil. A new day asks the calendar again (until it answers, nil).
function Holidays:On(t)
    local day = ns.Today(t)
    if today and today.day == day then return today.word or nil end
    if day == ns.Today() then self:Ask() end
    return nil
end

-- Is that other event (Holidays.EVENTS' word) on today?
function Holidays:Has(t, word)
    self:On(t)
    local day = ns.Today(t)
    return today and today.day == day and today.events and today.events[word] or false
end

function Holidays:Ask()
    if self.asking then return end
    local C = C_Calendar
    if not (C and C.OpenCalendar and C.GetNumDayEvents and C.GetDayEvent and C_DateAndTime) then
        today = { day = ns.Today(), word = false, events = {} }
        return
    end
    self.asking = true
    ns.Events:On("CALENDAR_UPDATE_EVENT_LIST", Holidays, function() Holidays:Read() end)
    pcall(C.OpenCalendar)
end

-- Today's events, in the month the calendar has open (the player may have paged it).
function Holidays:Read()
    ns.Events:Off("CALENDAR_UPDATE_EVENT_LIST", Holidays)
    self.asking = nil
    local word, events = false, {}
    local ok = pcall(function()
        local now = C_DateAndTime.GetCurrentCalendarTime()
        local shown = C_Calendar.GetMonthInfo and C_Calendar.GetMonthInfo(0)
        local offset = shown and ((now.year - shown.year) * 12 + now.month - shown.month) or 0
        for i = 1, C_Calendar.GetNumDayEvents(offset, now.monthDay) or 0 do
            local e = C_Calendar.GetDayEvent(offset, now.monthDay, i)
            local id = e and ns.Plain(e.eventID)
            if id and self.IDS[id] then word = self.IDS[id] end
            if id and self.EVENTS[id] then events[self.EVENTS[id]] = true end
        end
    end)
    today = { day = ns.Today(), word = word, events = events }
    ns.Log("Holidays", "today: %s%s", tostring(word), ok and "" or " (calendar failed)")
    ns.Bus:Fire("HOLIDAYS")
end

ns.Start("settled", function() Holidays:Ask() end)
