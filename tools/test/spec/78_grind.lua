-- Still at it (Menagerie/Grind.lua, 2026-11-26): an hour of one activity with a pet out gets one line, liked or
-- not; and a long break starts the day's liked line over (Bond:Rested). From the log: 2 h 46 min of Timbermaw
-- rep said two lines, both eggs.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    local function Setup(traits)
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Traits(traits or { "glupsk", "rampete" })
        ola:Slash("adopter panda"); w:Run(5)
        ola:Dice(0); ola:QuirksNow()
        ola.ns.DB.char.wish = { done = true, pet = ola.ns.Registry:MyPet(), day = ola.ns.Today() }
        return w, ola
    end
    -- n of an activity, one every `every` seconds.
    local function Grind(w, ola, id, n, every, extra)
        for _ = 1, n do
            ola.ns.Activity:Emit(id, 1, extra)
            w:Run(every)
        end
        w:RunTimers()
    end

    test("an hour of rep: one line naming the faction, once a session; under the hour, or too few, nothing", function()
        local w, ola = Setup()
        Grind(w, ola, "rep", 20, 100, "Timbermaw Hold")
        no(ola:Printed("Timbermaw Hold", true), "33 minutes: not yet")
        Grind(w, ola, "rep", 20, 100, "Timbermaw Hold")
        ok(ola:PrintedLine("grind.rep", { pet = "Panda Cub", faction = "Timbermaw Hold" }), "an hour on: its line")
        eq(ola:CountPrinted("Timbermaw Hold"), 1)
        ola.ns.DB.char.quirkAt = nil
        Grind(w, ola, "rep", 40, 100, "Timbermaw Hold")
        eq(ola:CountPrinted("Timbermaw Hold"), 1, "once a session")
        ola:Reload(); w:Settle("hello"); ola:QuirksNow()
        Grind(w, ola, "rep", 40, 100, "Timbermaw Hold")
        eq(ola:CountPrinted("Timbermaw Hold"), 1, "and once a day")
        -- Herbs, a few an hour, is the everyday pace: no farm.
        Grind(w, ola, "herb", 16, 300)
        no(ola:PrintedLine("grind.herb", { pet = "Panda Cub" }), "twelve herbs an hour, for 80 minutes")
        -- The day's roll: lost, a farm says nothing all day.
        ola:Dice(0.9)
        Grind(w, ola, "mine", 20, 200)
        no(ola:PrintedLine("grind.mine", { pet = "Panda Cub" }), "today's roll lost")
    end)

    test("a gap over twenty minutes starts the run over; the quirks' 45 minutes hold it to the next time", function()
        local w, ola = Setup()
        Grind(w, ola, "gold", 40, 60)
        w:Run(ola.ns.Grind.GAP + 1)
        Grind(w, ola, "gold", 30, 60)
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "70 minutes, a break in them")
        ola.ns.DB.char.quirkAt = ola.ns.Now() -- (an egg just now)
        Grind(w, ola, "gold", 32, 60)
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "an hour now, the 45 minutes not over")
        ola.ns.DB.char.quirkAt = ola.ns.Now() - 2700
        Grind(w, ola, "gold", 1, 1)
        ok(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "the next coin")
    end)

    test("a disliked one is the dislike's; Litt halves the day's chance", function()
        local w, ola = Setup()
        ola.ns.Personality.Dislikes = function() return { fish = true }, { "fish" } end
        Grind(w, ola, "fish", 40, 100)
        no(ola:PrintedLine("grind.fish", { pet = "Panda Cub" }), "it minds fishing")
        local w2, kari = Setup()
        kari.ns.DB.global.settings.chatter = "few"
        kari:Dice(0.6)
        Grind(w2, kari, "quest", 11, 400)
        no(kari:PrintedLine("grind.quest", { pet = "Panda Cub" }), "few: a 25% roll, lost")
        eq(#kari:Log("grind:quest: today's roll lost %(25%%%)"), 1)
        local _, said = kari.ns.Grind:Runs()
        ok(said.quest, "decided for the session")
    end)

    test("a long break starts the day's liked line over; a short one doesn't, and points stay the day's", function()
        local w, ola = Setup()
        w:SetHour(1) -- (six hours on is the same day)
        local d = function() return ola.ns.DB.char.bondToday.pets[PANDA] end
        ola.ns.Bond:OnActivity("day", 1, PANDA)
        d().flavor = true
        ola:Logout(); w:Skip(3600); ola:Login(); w:Settle("hello")
        ok(d().flavor, "an hour away: the same evening")
        ola:Logout(); w:Skip(ola.ns.Bond.BREAK + 60); ola:Login(); w:Settle("hello")
        no(d().flavor, "six hours away: the day's line again")
        eq(#ola:Log("back after"), 1)
    end)
end
