-- The calendar, as on Forever: events load a second after OpenCalendar (S.holidays).
local H, P = ...

return function(c, env, S)
    local w = c.world
    -- The calendar (as on Forever, /dp probe api 2026-11-11): its events load a second after
    -- OpenCalendar. S.holidays: "YYYYMMDD" -> { event ids }; S.calendarMonth: the month it shows
    -- ({ month, year }; default this one).
    local function CalendarNow() local d = os.date("*t", w:ServerTime()); return d end
    env.C_DateAndTime = { GetCurrentCalendarTime = function()
        local d = CalendarNow()
        return { year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = d.hour, minute = d.min }
    end }
    local function Shown(offset)
        local d = CalendarNow()
        local m = S.calendarMonth or { month = d.month, year = d.year }
        local n = m.year * 12 + (m.month - 1) + offset
        return math.floor(n / 12), n % 12 + 1
    end
    local function DayEvents(offset, day)
        local y, m = Shown(offset)
        return S.holidays and S.holidays[("%04d%02d%02d"):format(y, m, day)] or {}
    end
    env.C_Calendar = {
        OpenCalendar = function()
            c.calendarAsked = (c.calendarAsked or 0) + 1
            w:Timer(c, 1, function() c:Fire("CALENDAR_UPDATE_EVENT_LIST") end)
        end,
        GetMonthInfo = function(offset) local y, m = Shown(offset or 0); return { month = m, year = y } end,
        GetNumDayEvents = function(offset, day) return #DayEvents(offset, day) end,
        GetDayEvent = function(offset, day, i)
            local id = DayEvents(offset, day)[i]
            return id and { eventID = id, eventType = 4, title = "holiday " .. id } or nil
        end,
    }
end
