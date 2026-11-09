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
        return w, ola, Q
    end
    local function Count(c, text)
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
        ok(ola:Printed("Bombay Cat rister vannet av seg og ser fornærmet på deg.", true))
        ok(ola:Printed("Nå vet du det: Bombay Cat liker ikke dykking.", true))
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
        ok(ola:Printed("Bombay Cat nekter å se på deg etter den dukkerten.", true), "another line")
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

    test("easter eggs: holidays and anniversaries, once a day, not held back by the hour", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        -- The adoption's round days, each once (the hour doesn't hold them back).
        local at = select(3, ola.ns.Registry:Status(CAT)).at
        w:Skip(at + 100 * 86400 + 3600 - w:ServerTime())
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("day")
        ok(ola:Printed("Bombay Cat og du har bodd sammen i 100 dager!", true))
        w:SkipDays(1)
        A:Emit("day")
        eq(Count(ola, "bodd sammen"), 1, "100 is done")
        -- A holiday, once a day.
        w:Skip(os.time({ year = 2027, month = 5, day = 17, hour = 12 }) - w:ServerTime())
        A:Emit("day")
        ok(ola:Printed("Bombay Cat har fått sløyfe i rødt, hvitt og blått. Hipp hurra!", true))
        A:Emit("day"); A:Emit("day")
        eq(Count(ola, "sløyfe"), 1, "once a day")
        eq(ola.ns.DB.char.eggs.mai17.n, 1)
        -- Not for a pet you haven't adopted.
        no(Q.EGGS[7].test({ key = "s:5159", t = ola.ns.Now() }))
        -- Friday the 13th.
        w:Skip(os.time({ year = 2027, month = 8, day = 13, hour = 12 }) - w:ServerTime())
        A:Emit("day")
        ok(ola:Printed("Bombay Cat går i en stor bue rundt alle svarte katter i dag.", true))
    end)

    test("easter eggs by chance and by the hour: fish, bosses, levels, deaths, midnight", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        A:Emit("fish")
        ok(ola:Printed("Bombay Cat har allerede spist halve fangsten.", true), "a cat and the catch")
        A:Emit("boss", 1, "Hogger")
        no(ola:Printed("som minne", true), "the hour isn't up")
        w:Skip(3601)
        Q.random = function(n) return n and 1 or 0.5 end
        A:Emit("boss", 1, "Hogger")
        no(ola:Printed("som minne", true), "the dice said no (15%)")
        Q.random = function(n) return n and 1 or 0 end
        A:Emit("boss", 1, "?")
        no(ola:Printed("som minne", true), "no name, no trophy")
        A:Emit("boss", 1, "Hogger")
        ok(ola:Printed("Bombay Cat tok med seg en liten bit av Hogger som minne.", true))
        w:Skip(3601)
        A:Emit("level", 1, "29")
        no(ola:Printed("kake", true))
        A:Emit("level", 1, "30")
        ok(ola:Printed("Bombay Cat har bakt kake til nivå 30!", true))
        w:Skip(3601)
        A:Emit("revive"); A:Emit("revive")
        no(ola:Printed("trygt", true))
        A:Emit("revive")
        ok(ola:Printed("Bombay Cat lurer på om det er trygt å bo hos deg.", true), "the third death today")
        w:Skip(3601)
        ola.ns.DB.char.activity.quest = { total = 99, mine = 0, today = 0, pets = {} }
        A:Emit("quest")
        ok(ola:Printed("Bombay Cat har hjulpet deg med 100 quests. Det fortjener en godbit!", true))
        -- Midnight: any activity in its first ten minutes.
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 0, min = 5 }) - w:ServerTime())
        A:Emit("herb")
        ok(ola:Printed("Bombay Cat gjesper. Det er midnatt, vet du.", true))
    end)

    test("your pet meets its own kind under the mouse", function()
        local w, ola, Q = Setup()
        ola:Hover{ species = 40, owner = "Kari Berg" }
        ok(ola:Printed("Bombay Cat stirrer på Kari Berg sitt dyr. Er det et speil?", true))
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
