-- The game's holidays (Menagerie/Holidays.lua): today's from the calendar, by event id;
-- they count like our own (Festglad's day, an easter egg each).
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    local function Egg(ola, id)
        for _, e in ipairs(ola.ns.Quirks.EGGS) do if e.id == id then return e end end
    end

    test("a holiday in the calendar today: Festglad celebrates it and its egg can come; the next day asks again", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local today = ola.ns.Today()
        ola.state.holidays = { [today] = { 263, 324 } } -- (the Darkmoon Faire, and Hallow's End)
        local P = ola.ns.Personality
        eq(P.Holiday(w:ServerTime()), nil, "read at login, before it was in the calendar")
        -- Tomorrow: asked again, and once it has answered.
        w:SkipDays(1)
        local tomorrow = ola.ns.Today()
        ola.state.holidays[tomorrow] = { 263, 324 }
        local asked = ola.calendarAsked
        eq(P.Holiday(w:ServerTime()), nil, "not until the calendar answers")
        eq(ola.calendarAsked, asked + 1, "asked once")
        P.Holiday(w:ServerTime())
        eq(ola.calendarAsked, asked + 1, "not again while asking")
        w:Run(1.1)
        eq(P.Holiday(w:ServerTime()), "Hallow's End")
        eq(P.Holiday(w:ServerTime() - 86400), nil, "only today's is known")
        eq(P.ById("festglad").day(w:ServerTime()), 3, "Festglad's day")
        ok(Egg(ola, "hallowsend").test({ t = w:ServerTime() }), "its egg")
        no(Egg(ola, "winterveil").test({ t = w:ServerTime() }))
        ok(ola.ns.Strings["egg.hallowsend.1"] and ola.ns.Strings["egg.hallowsend.2"])
        -- Our own holiday on the same day wins.
        w:SetDate(2027, 12, 24, 12)
        ola.state.holidays[ola.ns.Today()] = { 141 }
        P.Holiday(w:ServerTime()); w:Run(1.1)
        eq(P.Holiday(w:ServerTime()), "julaften")
        ok(Egg(ola, "winterveil").test({ t = w:ServerTime() }), "the game's egg too")
    end)

    test("only the holidays we know; the month the calendar shows; no calendar, no holiday", function()
        local w, ola = H.Setup{ ola = {} }
        local P = ola.ns.Personality
        w:SkipDays(1)
        ola.state.holidays = { [ola.ns.Today()] = { 263, 1842, 301 } } -- (Darkmoon, Call to Arms, the fishing contest)
        P.Holiday(w:ServerTime()); w:Run(1.1)
        eq(P.Holiday(w:ServerTime()), nil, "left out")
        -- The player has paged the calendar to next month: today's events are one month back.
        w:SkipDays(1)
        local d = os.date("*t", w:ServerTime())
        ola.state.calendarMonth = { month = d.month % 12 + 1, year = d.year + (d.month == 12 and 1 or 0) }
        ola.state.holidays = { [ola.ns.Today()] = { 141 } }
        P.Holiday(w:ServerTime()); w:Run(1.1)
        eq(P.Holiday(w:ServerTime()), "Feast of Winter Veil")
        -- A client without the calendar.
        w:SkipDays(1)
        rawset(ola.env, "C_Calendar", nil)
        eq(P.Holiday(w:ServerTime()), nil)
        eq(P.Holiday(w:ServerTime()), nil, "and doesn't ask again today")
    end)
end
