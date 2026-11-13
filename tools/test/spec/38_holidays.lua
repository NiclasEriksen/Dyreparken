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
    test("past midnight, the day's visit comes before the calendar answers: a holiday's day gets the rest then", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        ola:Traits({ "festglad", "glupsk" }, 40)
        w:Settle("hello")
        ola:Slash("adopter bombay")
        w:Run(40)
        local B, CAT = ola.ns.Bond, "s:40"
        -- Just past midnight, Hallow's End today: the pet comes back out (or anything is done), the day's visit.
        local d = os.date("*t", w:ServerTime() + 86400)
        w:SetDate(d.year, d.month, d.day, 0, 5)
        ola.state.holidays = { [ola.ns.Today()] = { 324 } }
        local before = B:Of(CAT)
        ola.ns.Bus:Fire("PET_OUT")
        local early = B:Today(CAT)
        ok(early >= 10, "the visit came")
        w:Run(2) -- (the calendar answers)
        eq(B:Today(CAT) - early, 20, "the holiday's day: three times, the rest once it's known")
        eq(B:Of(CAT) - before, B:Today(CAT))
        ok(ola:Said("Bombay Cat feirer Hallow's End med deg!"), "Festglad's line for the day")
        -- Again: nothing more.
        ola.ns.Bus:Fire("HOLIDAYS")
        eq(B:Today(CAT) - early, 20, "once")
        -- Within the day's limit: a nearly full day gets only what's left.
        w:SkipDays(1)
        ola.state.holidays[ola.ns.Today()] = { 324 }
        ola.ns.DB.char.bondToday = { day = ola.ns.Today(), pets = { [CAT] = { got = {}, total = 60 } } }
        ola.ns.Activity:Emit("quest")
        w:Run(2)
        eq(B:Today(CAT), 75, "the day's limit")
    end)
    test("a calendar that never answers, or throws: read what it has after a while, and ask again the next day", function()
        local w, ola = H.Setup{ ola = {} }
        local P, Hol = ola.ns.Personality, ola.ns.Holidays
        local function Listening()
            for _, f in ipairs(ola.frames or {}) do if f.events and f.events.CALENDAR_UPDATE_EVENT_LIST then return true end end
            return false
        end
        -- Silent: no word that it loaded, though its events are there.
        w:SkipDays(1)
        ola.state.calendarSilent = true
        ola.state.holidays = { [ola.ns.Today()] = { 324 } }
        eq(P.Holiday(w:ServerTime()), nil, "asking")
        ok(Listening())
        w:Run(2)
        eq(P.Holiday(w:ServerTime()), nil, "still waiting")
        w:Run(Hol.WAIT)
        no(Hol.asking, "given up waiting")
        no(Listening(), "not listening any more")
        eq(P.Holiday(w:ServerTime()), "Hallow's End", "what the calendar had")
        -- Throws: no holiday today, and the next day asks again.
        w:SkipDays(1)
        ola.state.calendarSilent, ola.state.calendarBroken = nil, true
        local asked = ola.calendarAsked
        eq(P.Holiday(w:ServerTime()), nil)
        no(Hol.asking, "not stuck asking")
        no(Listening())
        eq(P.Holiday(w:ServerTime()), nil); eq(ola.calendarAsked, asked + 1, "once today")
        w:SkipDays(1)
        ola.state.calendarBroken = nil
        ola.state.holidays[ola.ns.Today()] = { 141 }
        P.Holiday(w:ServerTime()); w:Run(1.1)
        eq(ola.calendarAsked, asked + 2, "asked again the next day")
        eq(P.Holiday(w:ServerTime()), "Feast of Winter Veil")
    end)
end
