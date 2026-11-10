-- Small touches from the creative review of 2026-11-10 (docs/IDEAS.md):
-- details on the card, in the world and in chat. Flavor only.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    -- Ola with the panda (Glupsk) on the card, at a date and hour (the player's clock).
    local function Card(month, day, hour, traits)
        local w, ola = H.Setup{ ola = { 5159, 40 }, journal = true }
        local P = ola.ns.Personality
        P.Traits = function()
            local list = {}
            for _, id in ipairs(traits or { "glupsk" }) do list[#list + 1] = P.ById(id) end
            return list
        end
        ola.ns.PetMoves.species[5159] = nil
        local t = os.date("*t", ola.ns.Now())
        t.month, t.day, t.hour, t.min, t.isdst = month, day, hour, 0, nil
        w:Skip(os.time(t) - ola.ns.Now())
        return w, ola
    end

    local function Count(c, card, tex)
        local n = 0
        for _, p in ipairs(card.decor.parts) do
            if p:IsShown() and p.icon.tex == c.ns.Decor.MEDIA .. tex then n = n + 1 end
        end
        return n
    end

    test("asleep on the card: a few Zzz rise; woken by a click, they go", function()
        local w, ola = Card(3, 2, 23)
        local card = ola:SelectPet(5159)
        eq(Count(ola, card, "zee"), 3)
        ola.ns.Cuddle:Pet(card)
        eq(Count(ola, card, "zee"), 0, "awake")
        eq(ola.petActor.anim, 756, "and the hop plays on")
    end)

    test("a cuddle's hearts come with the pet's own particle", function()
        local w, ola = Card(3, 2, 14, { "dykker" })
        local card = ola:SelectPet(5159)
        ola.ns.Cuddle:Pet(card)
        local h = card.cuddle.hearts
        eq(h[1].icon.tex, ola.ns.Decor.MEDIA .. "heart")
        eq(h[2].icon.tex, ola.ns.Decor.MEDIA .. "bubble", "a Dykker: bubbles")
        -- Its personality still a surprise: the family's.
        ola.ns.Personality.Known = function() return false end
        ola.ns.Cuddle:Pet(card)
        no(h[2].icon.tex == ola.ns.Decor.MEDIA .. "bubble")
    end)

    test("a trait's particles double on a day its liked activity happened", function()
        local w, ola = Card(3, 2, 14, { "glupsk" })
        local card = ola:SelectPet(5159)
        local before = Count(ola, card, "crumb")
        ok(before > 0)
        ola:Fire("QUEST_TURNED_IN", 1)
        card = ola:SelectPet(40); card = ola:SelectPet(5159)
        eq(Count(ola, card, "crumb"), before * 2)
    end)

    test("the seasons and a few days of the year on every card", function()
        local function Kinds(month, day, hour, min)
            local w, ola = Card(month, day, hour, {})
            if min then w:Skip(min * 60) end
            local seen = {}
            for _, s in ipairs(ola.ns.Decor:Specs(PANDA, 1, ola.ns.Now())) do seen[s.kind] = s end
            return seen
        end
        ok(Kinds(10, 12, 14).leaf, "autumn leaves"); ok(Kinds(4, 20, 14).clover, "spring"); ok(Kinds(7, 1, 14).butterfly)
        ok(Kinds(12, 3, 14).snow)
        local may = Kinds(5, 17, 14).confetti
        ok(may and type(may.color[1]) == "table", "17. mai: red, white and blue")
        ok(Kinds(6, 23, 20).ember, "sankthans")
        ok(Kinds(12, 31, 23, 55).spark, "the turn of the year"); no(Kinds(12, 31, 22).spark)
        no(Kinds(3, 2, 14).leaf)
    end)

    test("a full day's bond: your pet sits on the card, content", function()
        local w, ola = Card(3, 2, 14)
        ola:Slash("adopter panda")
        w:Run(5)
        local today, max = ola.ns.Bond:Today(PANDA)
        ola.ns.DB.char.bondToday.pets[PANDA].total = max
        ola:SelectPet(5159)
        w:Run(ola.ns.Moves.SIT_AFTER + 2)
        eq(ola.petActor.anim, 97, "sitting")
    end)

    test("a wish come true: a happy hop the first time the card shows it", function()
        local w, ola = Card(3, 2, 14)
        ola:Slash("adopter panda")
        w:Run(5)
        ola.ns.DB.char.wish = { day = ola.ns.Today(), pet = PANDA, id = "herb", done = true }
        ola:SelectPet(40)
        ola:SelectPet(5159)
        w:Run(ola.ns.Moves.SETTLE + 0.1)
        eq(ola.petActor.anim, 756, "hop")
        w:Run(3)
        eq(ola.petActor.anim, 0)
        ola:SelectPet(40); ola:SelectPet(5159)
        w:Run(1)
        eq(ola.petActor.anim, 0, "once")
    end)

    -- Ola with her Bombay Cat out (a cat), Kari in the guild; the dice say yes.
    local function Cat()
        local w, ola, kari = H.Setup{ ola = { 40, 5159 }, kari = { 46, 5159 }, journal = true }
        ola:Summon(40)
        ola.ns.Quirks.random = function(n) return n and 1 or 0 end
        ola.ns.Quirks.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } }
        return w, ola, kari
    end

    test("/dp klapp: the pet answers in its family's voice, for you only", function()
        local w, ola = Cat()
        ola:Slash("klapp")
        ok(ola:Printed("Bombay Cat maler: «mrrr ... mjau».", true))
        ola:Target({ species = 5159, owner = "Kari Berg" })
        ola.ns.Scenes.Families = function() return {} end
        ola:ClearPrinted()
        ola:Slash("klapp")
        eq(#ola.printed, 0, "a family without a voice says nothing")
    end)

    test("hovering a companion: hearts in its holder's bond tier", function()
        local w, ola, kari = Cat()
        local Fx = ola.ns.Fx
        eq(Fx:HeartColor(46, "Kari Berg"), Fx.PINK, "nobody's: pink")
        kari:Slash("adopter kitten")
        w:Run(5)
        local now = ola.ns.Now()
        ola.ns.DB:Guild().life["s:46"] = { ["Kari Berg"] = { p = 600, f = now - 100 * 86400, t = now } }
        eq(Fx:HeartColor(46, "Kari Berg"), ola.ns.Scenes.SILVER, "level 4: silver")
        ola.ns.DB:Guild().life["s:46"]["Kari Berg"].p = 1500
        eq(Fx:HeartColor(46, "Kari Berg"), ola.ns.Scenes.GOLD)
        eq(Fx:HeartColor(46, "Per Hansen"), Fx.PINK, "someone else's kitten")
    end)

    test("meeting a cousin, or someone who once cared for your pet", function()
        local w, ola, kari = Cat()
        ola:Hover({ species = 46, owner = "Kari Berg" })
        w:RunTimers()
        ok(ola:Printed("Bombay Cat og Kari Berg sitt dyr snuser forsiktig", true), "two cats: cousins")
        -- Kari cared for the Bombay Cat once.
        local now = ola.ns.Now()
        ola.ns.DB:Guild().life["s:40"] = { ["Kari Berg"] = { p = 120, f = now - 30 * 86400, t = now - 86400 } }
        ola.ns.DB.char.quirkAt = nil
        ola:Hover({ species = 5159, owner = "Kari Berg" })
        w:RunTimers()
        ok(ola:Printed("Bombay Cat kjenner igjen Kari Berg!", true))
    end)

    test("your pet is the guild's pet of the day: a line after login, a golden halo on its card", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        ola:Reload()
        w:Settle("day")
        ok(ola:Printed("Panda Cub er dagens dyr i guilden i dag!", true))
        local halo
        for _, s in ipairs(ola.ns.Decor:Specs(PANDA, 1, ola.ns.Now())) do if s.kind == "halo" then halo = s end end
        ok(halo and halo.color == ola.ns.Scenes.GOLD)
    end)

    test("the explore chip names the last place you discovered together", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        ola:Set("zone", "Westfall"):Set("map", 1436)
        ola.ns.Activity:CheckPlace()
        eq(ola.ns.DB.char.lastPlace[PANDA], "Westfall")
        local card, found = ola:SelectPet(5159), false
        for _, chip in ipairs(card.stats.chips) do
            if chip:IsShown() and chip.id == "explore" then
                found = true
                chip.scripts.OnEnter(chip)
                match(table.concat(ola.env.GameTooltip.lines, " / "), "Sist oppdaget sammen: Westfall")
            end
        end
        ok(found, "the chip is there")
    end)
end
