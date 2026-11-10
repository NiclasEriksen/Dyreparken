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
        -- The seasons are the faintest touch: one particle, half seen, last (the first to go).
        local w, ola = Card(10, 12, 14, { "glupsk" })
        local list = ola.ns.Decor:Specs(PANDA, 1, ola.ns.Now())
        eq(list[#list].kind, "leaf"); eq(list[#list].n, 1); ok(list[#list].alpha < 0.5)
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

    -- Ola with her Bombay Cat adopted and out, its traits given; the dice say yes, at once.
    local function Eggs(traits)
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        ola.ns.Companions = { build = 1, species = { [40] = { a = true, t = { "cat" } } } }
        ola.ns.Personality.PINNED = { [40] = traits or { "glupsk", "rampete" } }
        w:Settle("hello")
        ola:Slash("debug off")
        ola:Slash("adopter bombay")
        w:Run(40)
        local Q = ola.ns.Quirks
        Q.random = function(n) return n and 1 or 0 end
        Q.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } }
        local function At(y, m, d, h, min)
            w:Skip(os.time({ year = y, month = m, day = d, hour = h, min = min or 0 }) - w:ServerTime())
            ola.ns.DB.char.quirkAt = nil
        end
        local function Said(text) w:RunTimers(); return ola:Printed(text, true) end
        return w, ola, At, Said
    end

    test("Easter Sunday, the clocks changing", function()
        local Q = H.Setup{ ola = { 40 } }
        local w, ola, At, Said = Eggs()
        eq(ola.ns.Quirks.Easter(2026), "0405"); eq(ola.ns.Quirks.Easter(2027), "0328"); eq(ola.ns.Quirks.Easter(2028), "0416")
        At(2027, 3, 28, 12)
        ola.ns.Activity:Emit("day")
        ok(Said("påske"), "Easter")
        -- The clocks: a day whose DST differs from the day before (none in a time zone without it).
        local t = os.time({ year = 2027, month = 1, day = 1, hour = 12 })
        for _ = 1, 365 do
            if os.date("*t", t).isdst ~= os.date("*t", t - 86400).isdst then break end
            t = t + 86400
        end
        if os.date("*t", t).isdst ~= os.date("*t", t - 86400).isdst then
            w:Skip(t - w:ServerTime())
            ola.ns.Activity:Emit("day")
            ok(Said("Klokka ble stilt i natt"))
        end
    end)

    test("Fredagstaco for a Glupsk or a cat, Lørdagsgodt and Monday blues for a Helgetroll, 13:37", function()
        local w, ola, At, Said = Eggs({ "glupsk", "rampete" })
        At(2027, 3, 5, 18) -- a Friday evening
        ola.ns.Activity:Emit("herb")
        ok(Said("lukter taco"))
        At(2027, 3, 9, 13, 37)
        ola.ns.Activity:Emit("herb")
        ok(Said("13:37"))
        w, ola, At, Said = Eggs({ "helgedyr", "rampete" })
        At(2027, 3, 6, 15) -- Saturday
        ola.ns.Activity:Emit("herb")
        ok(Said("lørdagsgodt"))
        At(2027, 3, 8, 12) -- Monday
        ola.ns.Activity:Emit("day")
        ok(Said("Det er mandag"))
    end)

    test("a hundred jumps, a long nap, an early morning (a Nattugle's own line)", function()
        local w, ola, At, Said = Eggs({ "hoppetass", "nattugle" })
        At(2027, 3, 9, 6)
        ola.ns.Activity:Emit("day")
        ok(Said("har ikke lagt seg ennå"), "a Nattugle at six")
        ola.ns.DB.char.activity.jump = { total = 9, mine = 9, today = 9, day = ola.ns.Today(), pets = {} }
        ola.ns.Activity:Emit("jump")
        ok(Said("vil ha mer"), "a Hoppetass: a hundred jumps and more")
        ola.ns.DB.char.quirkAt = nil
        ola.ns.DB.char.activity.nap = { total = 4, mine = 4, today = 4, day = ola.ns.Today(), pets = {} }
        ola.ns.Activity:Emit("nap")
        ok(Said("flyttet inn i vertshuset"))
    end)

    test("named after you, or after another pet in the park", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        ola.ns.Quirks.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } }
        ola:Slash("adopter panda"); kari:Slash("adopter bombay")
        w:Run(5)
        local now = ola.ns.Now()
        ola.ns.DB:Guild().life["s:5159"] = { ["Ola Nord"] = { p = 300, f = now - 30 * 86400, t = now } }
        ola:Slash("navn Ola")
        w:RunTimers()
        ok(ola:Printed("heter det samme som deg", true))
        ola.ns.DB:Guild().names["s:40"] = { ["Kari Berg"] = { n = "Pus", at = now } }
        ola.ns.Registry:Changed()
        ola:Slash("navn Pus")
        w:RunTimers()
        ok(ola:Printed("to «Pus» i parken", true))
    end)

    test("a chip reaching a round number today wears a gold ring, with a line in its tooltip", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        ola.ns.DB.char.activity.quest = { total = 48, mine = 48, today = 0, day = ola.ns.Today(), pets = { [PANDA] = 48 } }
        local function Chip()
            local card = ola:SelectPet(5159)
            for _, c in ipairs(card.stats.chips) do if c:IsShown() and c.id == "quest" then return c end end
        end
        no(Chip().ring:IsShown(), "48: nothing round, and old counts never light up")
        ola:Fire("QUEST_TURNED_IN", 1)
        no(Chip().ring:IsShown())
        ola:Fire("QUEST_TURNED_IN", 1)
        local chip = Chip()
        ok(chip.ring:IsShown(), "50")
        chip.scripts.OnEnter(chip)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "Rundt tall i dag: 50!")
        w:SkipDays(1)
        no(Chip().ring:IsShown(), "for the day")
    end)

    test("Kjenner deg ut og inn: every dislike of your adopted pet found out", function()
        local w, ola, At, Said = Eggs({ "glupsk", "rampete" }) -- a cat: dislikes the water
        local A = ola.ns.Achievements
        local _, list = ola.ns.Personality:Dislikes("s:40")
        eq(#list, 1)
        no(A:Got("dislikes"))
        local m = w:Mark()
        ola:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
        w:RunTimers()
        ok(A:Got("dislikes"), "found it")
        eq(ola.ns.DB.char.sulk.key, "s:40", "and it sulks on its card (Moves)")
        eq(w:Sent("ACH_EARNED", nil, m), 1, "news")
    end)

    test("the park's birthday: a year after the guild's first adoption, a line and confetti on every card", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        kari:Slash("adopter bombay")
        w:Run(5)
        local born = select(3, kari.ns.Registry:Status("s:40")).at
        no(ola.ns.Bonds:ParkBirthday(), "not before its first birthday")
        w:SkipDays(365)
        ola:Reload()
        w:Settle("day")
        eq(ola.ns.DB:Guild().born, born)
        ok(ola:Printed("Dyreparken fyller 1 år i dag!", true))
        local confetti
        for _, s in ipairs(ola.ns.Decor:Specs(PANDA, 1, ola.ns.Now())) do if s.kind == "confetti" then confetti = s end end
        ok(confetti, "confetti")
        w:SkipDays(1)
        no(ola.ns.Bonds:ParkBirthday())
    end)

    test("playdates: a best friend in the bond's tooltip, inseparable at five; three friends at once is a party", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 }, journal = true }
        w:AddMember("Per Hansen", 0); w:AddMember("Liv Lund", 0)
        ola.ns.Guild:Refresh(true)
        w:Run(1)
        ola:Slash("adopter panda")
        w:Run(5)
        ola.ns.Quirks.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } }
        local P = ola.ns.Playdate
        for day = 1, 5 do
            P:Heard("Kari Berg", "s:40")
            if day < 5 then w:SkipDays(1) end
        end
        ok(ola:Printed("Panda Cub og Bombay Cat er uatskillelige på lekeplassen.", true))
        P:Heard("Per Hansen", "s:46")
        local owner, theirs, n = P:BestFriend(PANDA)
        eq(owner, "Kari Berg"); eq(theirs, "s:40"); eq(n, 5)
        local card = ola:SelectPet(5159)
        card.bond.scripts.OnEnter(card.bond)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "Bestevenn i parken: Bombay Cat %(Kari Berg%), 5 lekedater")
        -- Kari, Per and Liv within ten minutes: a party, once a day.
        P:Heard("Liv Lund", "s:72")
        w:RunTimers()
        ok(ola:Printed("Full fest: 3 dyr fra parken på samme sted!", true))
    end)

    test("home by name: the hearth line names where you're bound; pets feel at home in their family's places", function()
        local w, ola, At, Said = Eggs({ "hjemlengsel", "rampete" }) -- likes going home
        ola:Set("home", "Goldshire")
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 8690)
        ok(ola:Printed("Bombay Cat er glad for å være hjemme i Goldshire!", true))
        ola:Set("home", nil)
        w:SkipDays(1)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 8690)
        ok(ola:Printed("Bombay Cat er glad for å være hjemme!", true), "no bind location: the plain line")
        -- A cat, the first time in Winterspring.
        ola.ns.Activity:Emit("explore", 1, "Winterspring")
        ok(Said("Bombay Cat føler seg hjemme i Winterspring!"))
        ola.ns.Activity:Emit("explore", 1, "Westfall")
        no(Said("hjemme i Westfall"), "not a cat's place")
    end)

    test("a guildmate's /dp klapp on your pet: hearts and a line, at most once every few minutes", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        local function Listening(e)
            for _, f in ipairs(ola.frames) do if f.events[e] then return true end end
        end
        no(Listening("CHAT_MSG_EMOTE"), "no adopted pet: not listening")
        ola:Slash("adopter panda")
        w:Run(5)
        ok(Listening("CHAT_MSG_EMOTE"))
        ola:Summon(5159)
        kari:Target({ species = 5159, owner = "Ola Nord" })
        kari:Slash("klapp")
        local said
        for _, m in ipairs(w.chat) do if m.from == "Kari Berg" and m.chan == "EMOTE" then said = m.text end end
        ola:Fire("CHAT_MSG_EMOTE", said, "Kari Berg")
        ok(ola:Printed("Panda Cub logrer fornøyd etter klappen fra Kari Berg.", true))
        ola:ClearPrinted()
        ola:Fire("CHAT_MSG_EMOTE", said, "Kari Berg")
        eq(#ola.printed, 0, "not again so soon")
        ola:Fire("CHAT_MSG_EMOTE", "klapper Kari Berg sin Bombay Cat.", "Per Hansen")
        eq(#ola.printed, 0, "someone else's pet, and not a guildmate")
        ola:Slash("gislipp")
        w:Run(1)
        no(Listening("CHAT_MSG_EMOTE"), "let go: not listening")
    end)
end
