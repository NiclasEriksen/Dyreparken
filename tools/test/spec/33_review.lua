-- The code review of 2026-11-10: the card's dormancy, crash recovery, the day
-- after midnight. Each test names the problem it guards against.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, DAY = "s:5159", 86400

    -- Every animation group playing in a client, on any frame or texture.
    local function Playing(c)
        local n = 0
        local function Scan(r)
            for _, g in ipairs(r.animGroups or {}) do if g.playing then n = n + 1 end end
        end
        for _, f in ipairs(c.frames) do
            Scan(f)
            for _, t in ipairs(f.textures or {}) do Scan(t) end
        end
        return n
    end

    -- Ola with her panda adopted at Sjelevenn: every decoration and pulse there is.
    local function Loved()
        local w, ola = H.Setup{ ola = { 5159, 40 }, settle = "bond" }
        ola:Slash("adopter panda")
        w:Run(5)
        local now = ola.ns.Now()
        ola.ns.DB:Guild().life[PANDA] = { ["Ola Nord"] = { p = 2300, f = now - 400 * DAY, t = now } }
        return w, ola
    end

    test("Blizzard updating the card with the journal closed starts nothing there", function()
        local w, ola = Loved()
        ola:OpenJournal()
        ola:SelectPet(5159)
        ok(Playing(ola) > 0)
        ola:CloseJournal()
        eq(Playing(ola), 0, "closed: all stopped, the badge's glow too")
        local timers, sent = #w.timers, #w.wire
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard) -- (PET_JOURNAL_LIST_UPDATE)
        eq(Playing(ola), 0, "no particles or pulses on a hidden card")
        eq(#w.timers, timers, "no pose timers")
        eq(#w.wire, sent, "no bond request")
        ola:OpenJournal()
        ok(Playing(ola) > 0, "shown again: drawn")
    end)

    test("a pet with no bond to show leaves no pulse playing on the hidden track", function()
        local w, ola = Loved()
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        ok(card.bond.medal.glow.pulse.playing)
        ola:SelectPet(46) -- (not owned, nobody's: no bond)
        no(card.bond:IsShown())
        no(card.bond.medal.glow.pulse.playing)
        for _, p in ipairs(card.bond.pips) do no(p.halo.pulse.playing) end
    end)

    test("a level-up celebration stops when another pet is picked", function()
        local w, ola = Loved()
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        ola.ns.BondTrack:Celebrate(card, PANDA, 7)
        ok(card.celebration.text:IsShown())
        ola:SelectPet(40)
        no(card.celebration.text:IsShown(), "the old pet's name isn't left over the new card")
        no(card.celebration.text.anim.playing)
    end)

    test("a guildmate's BOND message doesn't start the pet's hop over", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 14 }) - w:ServerTime())
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 756)
        local n = #actor.played
        ola.ns.Bus:Fire("BOND", "s:40")
        eq(#actor.played, n, "the hop plays on")
        w:Run(2.1)
        eq(actor.anim, 0, "and ends standing")
        ola.ns.Bus:Fire("BOND", "s:40")
        eq(actor.anim, 0)
    end)

    test("a closed card holds no pose: a model loading there isn't laid down again", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola.ns.PetMoves.species[5159] = nil
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 23 }) - w:ServerTime())
        ola:SelectPet(5159)
        local actor = ola.petActor
        w:Run(1.81)
        eq(actor.anim, 6, "asleep")
        ola:CloseJournal()
        actor:SetAnimation(0) -- (the client resets the model on the closed card)
        w:Run(1)
        eq(actor.anim, 0)
    end)

    test("online past midnight: the new day's visit comes with the first thing done, or the pet found out", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda")
        w:Run(5)
        local function Visits() return select(3, ola.ns.Activity:Count("day")) end -- (today's)
        eq(Visits(), 1, "the login's visit")
        local d = os.date("*t", w:ServerTime())
        w:Skip((23 - d.hour) * 3600 + (59 - d.min) * 60 + (60 - d.sec) + 60) -- 00:01, still online
        eq(Visits(), 0, "nothing yet")
        ola:Fire("QUEST_TURNED_IN", 1)
        eq(Visits(), 1, "the visit came with the quest")
        ok(ola.ns.Bond:Today(PANDA) > 1, "and its points")
        -- Another night: auto-summon finding the pet back out (a loading screen) brings it too.
        w:SkipDays(1)
        eq(Visits(), 0)
        ola:Fire("PLAYER_ENTERING_WORLD")
        w:Run(4)
        eq(Visits(), 1)
    end)

    test("a corpse run longer than a minute: the pet comes back once you're alive", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda")
        w:Run(5)
        ola:Set("dead", true); ola:Summon(nil); ola:Fire("PLAYER_DEAD")
        ola:Fire("PLAYER_ALIVE") -- (released: a ghost, still dead)
        w:Run(90)
        eq(ola.summoned, nil, "the retries gave up")
        ola:Set("dead", false); ola:Fire("PLAYER_UNGHOST")
        w:Run(3)
        ok(ola.summoned, "back out")
    end)

    -- Quirks with a Bombay Cat (dislikes the water) adopted and out; the dice say yes.
    local function Quirky()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        ola.ns.Companions = { build = 1, species = { [40] = { a = true, t = { "cat" } } } }
        ola.ns.Personality.PINNED = { [40] = { "glupsk", "rampete" } }
        w:Settle("hello")
        ola:Slash("debug off")
        ola:Slash("adopter bombay")
        w:Run(40)
        ola.ns.Quirks.random = function(n) return n and 1 or 0 end
        return w, ola
    end

    test("a /reload before an easter egg's line is said spends nothing: it comes again", function()
        local w, ola = Quirky()
        w:Skip(os.time({ year = 2027, month = 12, day = 24, hour = 12 }) - w:ServerTime())
        ola.ns.Activity:Emit("day")
        eq(ola.ns.DB.char.eggs.jul, nil, "decided, not said yet")
        ola:Reload()
        ola.ns.Quirks.random = function(n) return n and 1 or 0 end
        ola.ns.Activity:Emit("day")
        w:Run(25)
        ok(ola:Printed("jul", true) or ola:Printed("Jul", true), "said this time")
        eq(ola.ns.DB.char.eggs.jul.n, 1)
        -- A dislike likewise: found only once its line is said.
        ola.ns.DB.char.quirkAt = nil
        ola:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
        eq(ola.ns.DB.char.dislikes["s:40"], nil)
        w:Run(61)
        ok(ola.ns.DB.char.dislikes["s:40"].dive)
    end)

    test("a round day on a holiday: both eggs say their line", function()
        local w, ola = Quirky()
        local r = select(3, ola.ns.Registry:Status("s:40"))
        -- Adopted 200 days before Christmas Eve.
        local eve = os.time({ year = 2027, month = 12, day = 24, hour = 12 })
        local Day = ola.ns.Bonds.DayNumber
        r.at = eve - 200 * DAY
        while Day(eve) - Day(r.at) > 200 do r.at = r.at + 3600 end
        while Day(eve) - Day(r.at) < 200 do r.at = r.at - 3600 end
        w:Skip(eve - w:ServerTime())
        ola.ns.Activity:Emit("day")
        w:Run(25)
        ok(ola.ns.DB.char.eggs.jul, "Christmas")
        ok(ola:Printed("200 dager", true), "and the round day")
    end)

    test("adopted on 29 February: its yearly day is the 28th in the years without one", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local B = ola.ns.Bonds
        local at = os.time({ year = 2028, month = 2, day = 29, hour = 12 })
        ok(B:Milestone(at, os.time({ year = 2029, month = 2, day = 28, hour = 12 })), "2029: the 28th")
        no(B:Milestone(at, os.time({ year = 2029, month = 3, day = 1, hour = 12 })))
        ok(B:Milestone(at, os.time({ year = 2032, month = 2, day = 29, hour = 12 })), "a leap year: the 29th")
        no(B:Milestone(at, os.time({ year = 2032, month = 2, day = 28, hour = 12 })))
    end)

    test("commands in capitals, Æ Ø Å too, and on/off as well as på/av", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("KUNNGJØR AV")
        eq(ola.ns.DB.char.announce, false)
        ola:Slash("kunngjør PÅ")
        eq(ola.ns.DB.char.announce, true)
        ola:Slash("kunngjør PÅ")
        eq(ola.ns.DB.char.announce, true, "on stays on")
        ola:Slash("lyd off")
        eq(ola.ns.DB.char.muteSummonSound, true, "the sound off: muted")
        ola:Slash("LYD ON")
        eq(ola.ns.DB.char.muteSummonSound, false)
    end)

    test("a wish is never for something this client can't see happen", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local W, A = ola.ns.Wish, ola.ns.Activity
        ola.ns.Personality.Of = function() return {}, { "herb", "fish" } end
        local seen = {}
        for d = 1, 30 do seen[W:For(PANDA, ("202611%02d"):format(d))] = true end
        ok(seen.herb and seen.fish)
        local Available = A.Available
        A.Available = function(self, id) return id ~= "fish" and Available(self, id) end
        for d = 1, 30 do eq(W:For(PANDA, ("202611%02d"):format(d)), "herb") end
    end)

    test("an old bond coming back after a reinstall isn't news; after a crash the guild isn't told twice", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        ola:Slash("adopter panda")
        w:Run(5)
        w:SkipDays(10)
        local g = ola.ns.DB:Guild()
        g.life[PANDA] = g.life[PANDA] or {}
        g.life[PANDA]["Ola Nord"] = { p = 200, f = select(3, ola.ns.Registry:Status(PANDA)).at, t = ola.ns.Now() }
        ola:Reload()
        w:Run(30)
        local snap = H.CopyTable(ola.saved)
        local m = w:Mark()
        no(ola.ns.Achievements:Got("loyal:30"), "(the day's visit left it short of Venn)")
        ola.ns.Bond:Add(60) -- Venn
        w:Run(15)
        eq(w:Sent("ACH_EARNED", nil, m), 1, "a real moment")
        ok(kari:Printed("Ola Nord fikk [Bestevenner]!", true))
        -- A crash: Ola's saved files are from before it, and she earns it again.
        ola:Logout(); ola.saved = H.CopyTable(snap)
        ola:Login()
        w:Run(30)
        kari:ClearPrinted()
        ola.ns.Bond:Add(60)
        w:Run(15)
        no(kari:Printed("fikk", true), "Kari was told already")
        -- A reinstall: her bond and achievement come back from the guild, quietly.
        ola:Logout(); ola.saved = {}
        m = w:Mark()
        ola:Login()
        w:Run(120)
        ok(ola.ns.Achievements:Got("loyal:30"), "known again")
        eq(w:Sent("ACH_EARNED", nil, m), 0, "and not news")
    end)

    test("only adoptions from before bonds shipped are seeded: not a later pet with no bond yet", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 40 } }
        ola:Slash("adopter panda")
        w:Run(5)
        ola.ns.DB.char.autoSummon = false
        ola:Summon(46) -- (another pet out: no day's visit for the panda)
        ola.ns.DB:Guild().life[PANDA] = nil
        kari.ns.DB:Guild().life[PANDA] = nil
        ola:Logout()
        w:SkipDays(20)
        ola:Login()
        w:Settle("day")
        w:Run(30)
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord"), nil, "no points nobody earned")
        eq(kari.ns.Registry:Life(PANDA, "Ola Nord"), nil)
    end)

    test("a pet learned before the journal lists it is still news when it shows up", function()
        local function Fix(c)
            local species = { [40] = { a = true, t = { "cat" } }, [41] = { a = true, t = { "cat" } },
                [42] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat" } }, [5159] = { a = false } }
            for sid = 2001, 2011 do species[sid] = { a = true } end
            c.ns.Companions = { build = 1, species = species }
            return c
        end
        local w, ola = H.Setup{ ola = { pets = { 40, 41, 42 } }, kari = {}, each = Fix, settle = "hello" }
        local m = w:Mark()
        ola:Fire("NEW_PET_ADDED", "BattlePet-0-xyz")
        w:Run(1.5) -- (the check comes before the pet is in the collection)
        ola:GivePet(46)
        ola:OpenJournal()
        w:Run(5)
        local got = ola.ns.Achievements:Got("family:cat")
        ok(got and got.ann ~= "quiet", "every cat: told, not quiet")
        eq(w:Sent("ACH_EARNED", nil, m), 1)
    end)

    test("a cached roster or a returning owner's new record doesn't lapse them", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:AddMember("Per Hansen", 31)
        w:AddMember("Liv Lund", 31)
        w:Run(12)
        local R, now = c.ns.Registry, w:ServerTime()
        R:MergeRecord("Per Hansen", { k = "s:40", at = now - 40 * DAY, ts = now - 40 * DAY })
        R:MergeRecord("Liv Lund", { k = "s:41", at = now - 60, ts = now - 60 }) -- back, and adopted just now
        c.rosterIgnored = true -- (the server ignores the request: the client's cached roster)
        c.ns.Guild:Refresh(true)
        w:Run(16)
        ok(c.ns.Guild.stale)
        local _, lapses = R:All()
        no(lapses["Per Hansen"], "not from a cached roster")
        c.rosterIgnored = false
        w:Run(301)
        c.ns.Guild:Refresh(true)
        w:Run(1)
        _, lapses = R:All()
        ok(lapses["Per Hansen"], "from the server's: 31 days")
        no(lapses["Liv Lund"], "her own record says she's been here since")
        eq(R:Holder("s:41"), "Liv Lund")
    end)

    test("a SYNC that starts and never finishes holds ours back once, not forever", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        local t0 = w:ServerTime() - DAY
        kari.ns.DB:Guild().claims["Zed Nobody"] = { at = t0, ts = t0 } -- (Kari knows something Ola doesn't)
        local m = w:Mark()
        w:InjectMessage("Ola Nord", { k = "HELLO", p = kari.ns.PROTOCOL, v = "x", d = 1 })
        for _ = 1, 6 do
            w:Inject("Per Hansen", "GUILD", "F" .. ("x"):rep(200)) -- a first chunk, and nothing after it
            w:Run(25)
        end
        ok(w:Sent("SYNC", "Kari Berg", m) > 0, "Kari's SYNC went out after one hold")
    end)

    test("backdated claims, lapses and names are refused, and migration 10 drops stored ones", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 }, login = false })
        local now = w:ServerTime()
        local epoch = 1790000000 - 1000 * DAY -- (the harness's, tools/test/harness.lua)
        ola.saved.DyreparkenDB = { schema = 9, guilds = { Dyreparken = {
            claims = {
                ["Kari Berg"] = { k = "s:46", at = now - DAY, ts = now - DAY },   -- fine
                ["Zed Nobody"] = { k = PANDA, at = 1, ts = now },                 -- the dawn of time
                ["Per Hansen"] = { k = "s:40", at = now - 10, ts = now - 20 },     -- claimed after its write
            },
            lapses = { ["Kari Berg"] = epoch - DAY, ["Bo Berg"] = now - DAY },
            names = { [PANDA] = { ["Zed Nobody"] = { n = "Stinky", at = 1 }, ["Kari Berg"] = { n = "Bambus", at = now - DAY } } },
            life = {}, ach = {}, achSeen = {},
        } } }
        ola:Login()
        local g = ola.env.DyreparkenDB.guilds.Dyreparken
        ok(g.claims["Kari Berg"]); eq(g.claims["Zed Nobody"], nil); eq(g.claims["Per Hansen"], nil)
        eq(g.lapses["Kari Berg"], nil); ok(g.lapses["Bo Berg"])
        eq(g.names[PANDA]["Zed Nobody"], nil); ok(g.names[PANDA]["Kari Berg"])
        -- From the wire: the same rules. A forged claim can't take Ola's pet; a lapse from the
        -- future can't block her.
        w:Settle("hello")
        ola:Slash("adopter panda")
        w:Run(5)
        w:InjectMessage("Zed Nobody", { k = "SYNC", p = ola.ns.PROTOCOL, i = 1, of = 1,
            r = { ["Zed Nobody"] = { k = PANDA, at = 1, ts = w:ServerTime() } },
            l = { ["Ola Nord"] = w:ServerTime() + 86000 } })
        w:Run(5)
        eq(ola.ns.Registry:Holder(PANDA), "Ola Nord")
        no(ola:Printed("rett før deg", true))
    end)

    test("a holder below Venn can clear the name the pet came with, not give it a new one", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        local R = ola.ns.Registry
        R:MergeName(PANDA, "Kari Berg", { n = "Stinky", at = select(3, R:Status(PANDA)).at - 60 })
        R:Changed()
        eq(R:Nickname(PANDA), "Stinky", "inherited")
        -- On the card: the button opens to clear it, and says so.
        local card = ola:SelectPet(5159)
        ok(card.nick:IsEnabled())
        card.nick.scripts.OnEnter(card.nick)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "fjerne")
        local okName, msg = R:SetNickname("Bambus")
        no(okName); match(msg, "Venn")
        ok(R:SetNickname(""), "cleared")
        eq(R:Nickname(PANDA), nil)
        card = ola:SelectPet(5159)
        no(card.nick:IsEnabled(), "nothing to clear: locked again")
    end)

    test("a client keeping what we refuse (an older version's forgery) doesn't make SYNCs forever", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        kari.ns.DB:Guild().claims["Zed Nobody"] = { k = "s:46", at = 100, ts = 100 } -- (before the epoch: Ola refuses it)
        kari.ns.Registry:Changed()
        local m = w:Mark()
        w:InjectMessage("Ola Nord", { k = "HELLO", p = kari.ns.PROTOCOL, v = "x", d = 1 })
        w:Run(600)
        ok(w:Sent("SYNC", nil, m) <= 3 * 2, "a round or two, then quiet (it was 40 in ten minutes)")
    end)
end
