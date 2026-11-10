-- Quirks (Menagerie/Quirks.lua): dislikes, secret until they happen, and
-- easter eggs. No effect on anything; at most one line an hour.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local CAT = "s:40"

    -- Ola with a Bombay Cat (a cat: dislikes the water), adopted and out.
    -- The dice always say yes, and pick the first line.
    local function Setup(traits)
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        ola.ns.Companions = { build = 1, species = { [40] = { a = true, t = { "cat" } } } }
        ola.ns.Personality.PINNED = { [40] = traits or { "glupsk", "rampete" } }
        w:Settle("hello")
        ola:Slash("debug off") -- (the debug log wants every activity)
        ola:Slash("adopter bombay")
        w:Run(40)
        local Q = ola.ns.Quirks
        Q.random = function(n) return n and 1 or 0 end
        Q.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } } -- (said at once; the delay has its own test)
        return w, ola, Q
    end
    local function Said(c, text) c.world:RunTimers(); return c:Printed(text, true) end
    local function Count(c, text)
        c.world:RunTimers()
        local n = 0
        for _, l in ipairs(c.printed) do if l:find(text, 1, true) then n = n + 1 end end
        return n
    end
    local function Dive(c) c:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath") end
    local function Points(c) local e = c.ns.Registry:Life(CAT, "Ola Nord"); return e and e.p or 0 end

    test("dislikes: from families and traits, never something the pet likes", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        local set, list = P:Dislikes(CAT)
        ok(set.dive, "cats and the water"); eq(#list, 1)
        P.PINNED[40] = { "dykker", "latsabb" }
        set, list = P:Dislikes(CAT)
        no(set.dive, "a Dykker cat doesn't mind"); ok(set.jump, "Latsabb: jumping"); eq(#list, 1)
        P.PINNED[40] = { "reiseglad", "einstoing" }
        set = P:Dislikes(CAT)
        ok(set.hearth); ok(set.chat); ok(set.dive)
        for family, acts in pairs(P.DISLIKE_BY_FAMILY) do
            for _, a in ipairs(acts) do ok(ola.ns.Activity.KIND[a], family .. ": " .. a) end
        end
    end)

    test("a disliked dive: a line, no points, and from then on it's on the card", function()
        local w, ola, Q = Setup()
        ola:OpenJournal()
        local card = ola:SelectPet(40)
        eq(card.likes.text, "Liker fisking, quests og PvP", "a secret until it happens")
        ok(ola.ns.Activity:IsListening("MIRROR_TIMER_START"), "watched for the cat")
        local before = Points(ola)
        Dive(ola)
        ok(Said(ola, "Bombay Cat rister vannet av seg og ser fornærmet på deg."))
        ok(Said(ola, "Nå vet du det: Bombay Cat liker ikke dykking."))
        eq(Points(ola), before, "no effect on the bond")
        ok(ola.ns.DB.char.dislikes[CAT].dive)
        eq(card.likes.text, "Liker fisking, quests og PvP · liker ikke dykking")
        card.personalityHit.scripts.OnEnter(card.personalityHit)
        local lines = table.concat(ola.env.GameTooltip.lines, "\n")
        match(lines, "Liker ikke: dykking")
        -- At most one an hour.
        Dive(ola)
        eq(Count(ola, "Bombay Cat rister"), 1)
        w:Run(3601) -- (a dive counts once a minute, by the client's clock)
        Q.random = function(n) return n and 2 or 0.9 end -- the dice say no
        Dive(ola)
        eq(Count(ola, "dukkert"), 0)
        w:Run(61)
        Q.random = function(n) return n and 2 or 0 end
        Dive(ola)
        ok(Said(ola, "Bombay Cat nekter å se på deg etter den dukkerten."), "another line")
        eq(Count(ola, "Nå vet du det"), 1, "found once")
        -- Alone on the card: capitalized. And it's kept across a reload.
        ola.ns.Personality.PINNED[40] = { "kosete", "festglad" }
        ola.ns.Personality.BY_FAMILY = {}
        ola.ns.Personality.DEFAULT = {}
        ola:SelectPet(40)
        eq(card.likes.text, "Liker ikke dykking")
        ola:Reload()
        ok(ola.ns.DB.char.dislikes[CAT].dive)
    end)

    test("a line comes a while after what caused it, not the moment it happens", function()
        local w, ola, Q = Setup()
        Q.DELAY = { dislike = { 20, 60 }, egg = { 5, 20 } }
        Q.random = function(n) return n and 1 or 0.25 end -- yes, and halfway-ish: 20 + 0.25 * 40 = 30 s
        Dive(ola)
        eq(Count(ola, "Bombay Cat rister"), 0, "not at once")
        w:Run(29)
        eq(Count(ola, "Bombay Cat rister"), 0)
        no(ola:Printed("Nå vet du det", true))
        no(Q:Ready(), "nothing else slips in meanwhile")
        eq(ola.ns.DB.char.quirkAt, nil, "the hour is saved only once it's said (a /reload here spends nothing)")
        ola.ns.Activity:Emit("fish")
        w:Run(1.1)
        eq(Count(ola, "Bombay Cat rister"), 1, "about half a minute later")
        ok(ola:Printed("Nå vet du det: Bombay Cat liker ikke dykking.", true), "and then that it's found out")
        w:Run(30)
        eq(Count(ola, "fangsten"), 0, "the catch came in the dislike's hour")
        -- An egg's line: sooner (5 + 0.25 * 15 s).
        w:Skip(3601)
        ola.ns.Activity:Emit("fish")
        w:Run(8.6)
        eq(Count(ola, "fangsten"), 0)
        w:Run(0.3)
        eq(Count(ola, "fangsten"), 1)
    end)

    test("what Quirks watches gives no bond points: level-ups, deaths, dislikes, even with a moment trait", function()
        local w, ola, Q = Setup({ "glupsk", "friluftsdyr" })
        Q.random = function(n) return n and 1 or 0.99 end -- (no lines in the way)
        ok(ola.ns.Activity:IsListening("PLAYER_LEVEL_UP"), "the eggs want level-ups")
        local before = Points(ola)
        ola:Fire("PLAYER_LEVEL_UP", 29)
        Dive(ola)
        eq(Points(ola), before, "not the bond's to count (friluftsdyr outdoors would make it 5)")
        ola:Fire("QUEST_TURNED_IN", 1)
        ok(Points(ola) > before, "what the bond watches still counts")
    end)

    test("dislikes are watched only for the pets we'd have out", function()
        local w, ola = Setup({ "glupsk", "latsabb" })
        local A = ola.ns.Activity
        ok(A:IsListening("MIRROR_TIMER_START")); ok(ola.ns.Personality:Dislikes(CAT).jump)
        ola:Slash("gislipp")
        w:Run(5)
        ola.ns.Summon:SetActive(CAT, false)
        no(A:IsListening("MIRROR_TIMER_START"), "nobody here minds the water now")
        ok(A:IsListening("PLAYER_LEVEL_UP"), "the eggs' own")
    end)

    test("the guild unknown at login: the adopted pet's dislikes are watched once it's known", function()
        local w, ola = Setup()
        ola.ns.DB.char.activePet = nil -- (adopted before 0.2: no active pet saved)
        ola:Logout()
        local guild = ola.guild
        ola.guild = nil -- GetGuildInfo is nil for the first moments of a login
        ola:Login()
        w:Run(3)
        no(ola.ns.Activity:IsListening("MIRROR_TIMER_START"), "nothing known yet")
        ola.guild = guild
        w:Run(30)
        ok(ola.ns.Activity:IsListening("MIRROR_TIMER_START"), "the cat's dislike, watched after all")
    end)

    test("easter eggs: holidays and anniversaries, once a day, not held back by the hour", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        -- The adoption's round days, each once (the hour doesn't hold them back).
        -- On the day itself, in calendar days (the milestone lines have 30, 100 and the
        -- years); not days later, as the first version did.
        local at = select(3, ola.ns.Registry:Status(CAT)).at
        local Day = ola.ns.Bonds.DayNumber
        w:Skip(at + 100 * 86400 - w:ServerTime())
        while Day(w:ServerTime()) - Day(at) < 100 do w:Skip(3600) end
        A:Emit("day")
        eq(Count(ola, "bodd sammen"), 0, "100: the milestone line's")
        while Day(w:ServerTime()) - Day(at) < 200 do w:Skip(3600) end
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("day")
        ok(Said(ola, "Bombay Cat og du har bodd sammen i 200 dager!"))
        w:SkipDays(1)
        A:Emit("day")
        eq(Count(ola, "bodd sammen"), 1, "only on the day")
        -- A holiday, once a day.
        w:Skip(os.time({ year = 2027, month = 5, day = 17, hour = 12 }) - w:ServerTime())
        A:Emit("day")
        ok(Said(ola, "Bombay Cat har fått sløyfe i rødt, hvitt og blått. Hipp hurra!"))
        A:Emit("day"); A:Emit("day")
        eq(Count(ola, "sløyfe"), 1, "once a day")
        eq(ola.ns.DB.char.eggs.mai17.n, 1)
        -- Not for a pet you haven't adopted.
        no(Q.EGGS[7].test({ key = "s:5159", t = ola.ns.Now() }))
        -- Friday the 13th.
        w:Skip(os.time({ year = 2027, month = 8, day = 13, hour = 12 }) - w:ServerTime())
        A:Emit("day")
        ok(Said(ola, "Bombay Cat går i en stor bue rundt alle svarte katter i dag."))
    end)

    test("easter eggs by chance and by the hour: fish, bosses, levels, deaths, midnight", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        A:Emit("fish")
        ok(Said(ola, "Bombay Cat har allerede spist halve fangsten."), "a cat and the catch")
        A:Emit("boss", 1, "Hogger")
        no(Said(ola, "som minne"), "the hour isn't up")
        w:Skip(3601)
        Q.random = function(n) return n and 1 or 0.5 end
        A:Emit("boss", 1, "Hogger")
        no(Said(ola, "som minne"), "the dice said no (15%)")
        Q.random = function(n) return n and 1 or 0 end
        A:Emit("boss", 1, "?")
        no(Said(ola, "som minne"), "no name, no trophy")
        A:Emit("boss", 1, "Hogger")
        ok(Said(ola, "Bombay Cat tok med seg en liten bit av Hogger som minne."))
        w:Skip(3601)
        A:Emit("level", 1, "29")
        no(Said(ola, "kake"))
        A:Emit("level", 1, "30")
        ok(Said(ola, "Bombay Cat har bakt kake til nivå 30!"))
        w:Skip(3601)
        A:Emit("revive"); A:Emit("revive")
        no(Said(ola, "trygt"))
        A:Emit("revive")
        ok(Said(ola, "Bombay Cat lurer på om det er trygt å bo hos deg."), "the third death today")
        eq(ola.ns.DB.char.eggs.dodsfall.key, CAT, "which pet: it plays dead on its card (Moves.lua)")
        w:Skip(3601)
        ola.ns.DB.char.activity.quest = { total = 499, mine = 0, today = 0, pets = { [CAT] = 98 } }
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("quest")
        no(Said(ola, "quests. Det"), "500 quests in all, but 99 with this pet")
        A:Emit("quest")
        ok(Said(ola, "Bombay Cat har hjulpet deg med 100 quests. Det fortjener en godbit!"),
            "its own hundredth, not held back by the hour")
        -- Midnight: any activity in its first ten minutes.
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 0, min = 5 }) - w:ServerTime())
        A:Emit("herb")
        ok(Said(ola, "Bombay Cat gjesper. Det er midnatt, vet du."))
    end)

    test("your pet meets its own kind under the mouse", function()
        local w, ola, Q = Setup()
        ola:Hover{ species = 40, owner = "Kari Berg" }
        ok(Said(ola, "Bombay Cat stirrer på Kari Berg sitt dyr. Er det et speil?"))
        w:Skip(3601)
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(Count(ola, "speil"), 1, "once a day")
        w:SkipDays(1)
        ola:Hover{ species = 46, owner = "Kari Berg" }
        ola:Hover{ species = 40, owner = "Ola Nord" }
        ola:Hover{ species = 40 }
        eq(Count(ola, "speil"), 1, "not another species, not your own, not one without an owner")
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(Count(ola, "speil"), 2)
    end)
end
