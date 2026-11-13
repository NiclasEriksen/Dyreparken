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
    [263] = "darkmoon",    -- the Darkmoon Faire (seen in the calendar, 2026-11-11): Tivolidyr's double days
}

-- Seconds to wait for the calendar's answer (about one on Forever, 2026-11-11). Past this, or if
-- OpenCalendar throws, read what it has: else a calendar that never answered kept us asking, and
-- listening, all session (code review 2026-11-13).
Holidays.WAIT = 10

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
    local n = (self.asks or 0) + 1
    self.asks, self.asking = n, true
    ns.Events:On("CALENDAR_UPDATE_EVENT_LIST", Holidays, function() Holidays:Read() end)
    if not pcall(C.OpenCalendar) then return self:Read() end
    C_Timer.After(self.WAIT, function()
        if Holidays.asking and Holidays.asks == n then Holidays:Read() end
    end)
end

-- Today's events, in the month the calendar has open (the player may have paged it). Today is
-- the player's day (ns.Today, what everything else counts by), not the calendar's: the calendar
-- runs on the realm's clock (GetCurrentCalendarTime), and near midnight with the two apart it
-- read the realm's day and kept it as ours (code review 2026-11-13).
function Holidays:Read()
    ns.Events:Off("CALENDAR_UPDATE_EVENT_LIST", Holidays)
    self.asking = nil
    local word, events = false, {}
    local day = ns.Today()
    local ok = pcall(function()
        local mine = date("*t", ns.Now())
        local shown = C_Calendar.GetMonthInfo and C_Calendar.GetMonthInfo(0)
            or C_DateAndTime.GetCurrentCalendarTime()
        local offset = (mine.year - shown.year) * 12 + mine.month - shown.month
        for i = 1, C_Calendar.GetNumDayEvents(offset, mine.day) or 0 do
            local e = C_Calendar.GetDayEvent(offset, mine.day, i)
            local id = e and ns.Plain(e.eventID)
            if id and self.IDS[id] then word = self.IDS[id] end
            if id and self.EVENTS[id] then events[self.EVENTS[id]] = true end
        end
    end)
    today = { day = day, word = word, events = events }
    ns.Log("Holidays", "today: %s%s", tostring(word), ok and "" or " (calendar failed)")
    ns.Bus:Fire("HOLIDAYS")
end

ns.Start("settled", function() Holidays:Ask() end)
