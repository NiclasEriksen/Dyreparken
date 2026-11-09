-- The code review of 2026-11-09: sync and saved-data hardening. Each test
-- names the problem it guards against.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN, DAY = "s:5159", "s:46", 86400

    local function Guild(spec)
        local w = H.World()
        local list = {}
        for _, s in ipairs(spec) do
            list[#list + 1] = w:AddClient(s[1], { pets = s[2], login = s.offline ~= true })
        end
        w:Run(20)
        return w, unpack(list)
    end

    test("migration 8 clamps bond entries to the new bound and drops what peers would refuse", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { login = false })
        local now = w:ServerTime()
        local epoch = 1790000000 - 1000 * DAY -- (the harness sets this, tools/test/harness.lua)
        c.saved.DyreparkenDB = { schema = 7, guilds = { Dyreparken = {
            claims = {}, lapses = {}, names = { ["junk"] = { ["Ola Nord"] = { n = "X", at = now } } },
            life = {
                [PANDA] = {
                    ["Ola Nord"] = { p = 90, f = now - 3600, t = now },        -- 100 a day allowed it
                    ["Kari Berg"] = { p = 20, f = now - 5 * DAY, t = now },     -- fine as it is
                    ["Per Hansen"] = { p = 5, f = epoch - DAY, t = now },       -- older than the addon
                },
                ["junk"] = { ["Ola Nord"] = { p = 1, f = now, t = now } },
            },
        } } }
        c:Login()
        local g = c.env.DyreparkenDB.guilds.Dyreparken
        eq(c.env.DyreparkenDB.schema, 8)
        eq(g.life[PANDA]["Ola Nord"].p, 90, "within today and a spare day (150): kept")
        eq(g.life[PANDA]["Kari Berg"].p, 20)
        eq(g.life[PANDA]["Per Hansen"], nil, "older than the addon: gone")
        eq(g.life.junk, nil); eq(g.names.junk, nil, "not a pet key")
        -- Over the bound: clamped, the same on every client.
        local d = w:AddClient("Kari Berg", { login = false })
        d.saved.DyreparkenDB = { schema = 7, guilds = { Dyreparken = { claims = {}, lapses = {}, names = {},
            life = { [PANDA] = { ["Kari Berg"] = { p = 400, f = now - 3600, t = now } } } } } }
        d:Login()
        eq(d.env.DyreparkenDB.guilds.Dyreparken.life[PANDA]["Kari Berg"].p, 150)
    end)

    test("an entry one side keeps and the other refuses no longer makes SYNCs forever", function()
        -- The review's case: Ola's store holds a bond peers refuse. Before the fix: a SYNC every 30 s.
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 }, offline = true } })
        local now = w:ServerTime()
        ola.ns.DB:Guild().life[PANDA] = { ["Ola Nord"] = { p = 40, f = now - 3600, t = now } }
        kari:Login()
        local m = w:Mark()
        w:Run(600)
        ok(w:Sent("SYNC", nil, m) <= 2, ("%d SYNCs in 10 minutes"):format(w:Sent("SYNC", nil, m)))
        H.assertConverged(w)
    end)

    test("forged bonds and keys are refused: a start before the addon, keys that aren't pets", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        local R = kari.ns.Registry
        local now = w:ServerTime()
        no(R:MergeLife(KITTEN, "Ola Nord", { p = 2250, f = 1, t = now }), "f = 1: everlasting Sjelevenn")
        no(R:MergeLife("junk", "Ola Nord", { p = 1, f = now, t = now }))
        no(R:MergeName("s:abc", "Ola Nord", { n = "X", at = now }))
        no(R:MergeRecord("Per Hansen", { k = "nope", at = now, ts = now }))
        ok(R:MergeRecord("Per Hansen", { k = "s:40", at = now, ts = now }))
        ok(R:MergeRecord("Liv Lund", { k = "n:Some Pet", at = now, ts = now }), "a pet without a species id")
        ok(R:MergeRecord("Bo Berg", { at = now, ts = now }), "released: no key")
    end)

    test("a SYNC with more entries than any guild has is refused whole", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        local now = w:ServerTime()
        local b = {}
        for i = 1, kari.ns.Config.SYNC_MAX_ENTRIES + 1 do b["s:" .. (10000 + i)] = { ["Ola Nord"] = { p = 1, f = now, t = now } } end
        w:InjectMessage("Per Hansen", { k = "SYNC", p = kari.ns.PROTOCOL, b = b, i = 3, of = 3, d = 1 })
        w:Run(5)
        eq(next(kari.ns.DB:Guild().life), nil, "none of it stored")
        eq(#kari:Log("refused a SYNC from Per Hansen: too many entries"), 1)
    end)

    test("a SYNC goes in three parts, the digest on the last; peers hold back when one starts", function()
        local names = { "Ola Nord", "Kari Berg", "Per Hansen", "Liv Lund", "Bo Berg" }
        local spec = {}
        for _, n in ipairs(names) do spec[#spec + 1] = { n, { 5159 } } end
        spec[#spec + 1] = { "Nina Ny", { 46 }, offline = true }
        local w = H.World()
        local list = {}
        for _, s in ipairs(spec) do list[#list + 1] = w:AddClient(s[1], { pets = s[2], login = s.offline ~= true }) end
        w:Run(20)
        -- Plenty of records (released, of members long gone), so even the first part is several
        -- chunks: only the hold on its first chunk ("F") can stop the others.
        local now = w:ServerTime()
        for i = 1, 5 do
            for j = 1, 400 do -- names that don't compress away: longer than the outbox's burst of 8 chunks
                local name = ("%08x %08x"):format(j * 2654435761 % 4294967296, j * 40503 % 4294967296)
                list[i].ns.Registry:MergeRecord(name, { at = now - j, ts = now - j })
            end
        end
        for i = 1, 5 do
            for j = 1, 5 do
                for key, byKey in pairs(list[j].ns.DB:Guild().life) do
                    for carer, e in pairs(byKey) do list[i].ns.Registry:MergeLife(key, carer, e) end
                end
            end
        end
        local m = w:Mark()
        list[6]:Login()
        w:Run(60)
        eq(w:Sent("SYNC", nil, m), 1, "one answer: the others held back")
        local parts = {}
        for i = m + 1, #w.wire do
            local x = w.wire[i]
            if x.kind == "SYNC" then parts[#parts + 1] = x.msg end
        end
        eq(#parts, 3)
        eq(parts[1].i, 1); eq(parts[3].of, 3)
        ok(parts[1].r and parts[2].n and parts[3].b, "records, names, bonds")
        no(parts[1].d); ok(parts[3].d, "the digest only on the last")
        H.assertConverged(w)
    end)

    test("Comm: a message receivers would drop isn't sent; a throttled chunk waits and goes", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        local big = {}
        for i = 1, 40000 do big[i] = ("x%d"):format(i * 7919 % 100003) end
        ok(ola.ns.Comm:Send("SYNC", { junk = big }, "GUILD") == false)
        eq(#ola:Log("not sent: SYNC is too big"), 1)
        -- The server says throttled: the chunk stays first in line and goes once a token is back.
        local m = w:Mark()
        ola.throttle = { [ola.ns.Config.COMM_PREFIX] = { tokens = 0, at = w.t } }
        ola.ns.Comm:Send("VER", { v = "x" }, "GUILD")
        eq(w:Sent("VER", nil, m), 0)
        ok(#ola:Log("throttled by the server") >= 1)
        w:Run(3)
        eq(w:Sent("VER", nil, m), 1, "sent after the wait")
        ok(#ola:Log("throttled by the server") <= 2, "a wait for a token, not a retry every frame")
    end)

    test("bond points never go down, and the day counts only what fit under the cap", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        ola:Slash("adopter panda")
        w:Run(5)
        local now = w:ServerTime()
        local g = ola.ns.DB:Guild()
        -- An entry above what Add would allow now (as alpha4 could leave): kept, not lowered.
        g.life[PANDA] = { ["Ola Nord"] = { p = 200, f = now - 600, t = now } }
        ola.ns.Bond:Add(5)
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord").p, 200)
        eq(ola.ns.Bond:Room(), 0)
        -- At the cap, a granted activity adds nothing to today's tally.
        local before = ola.ns.Bond:Today()
        ola:Fire("QUEST_TURNED_IN", 1)
        eq(ola.ns.Bond:Today(), before)
    end)

    test("bond gains wait for the lazy publish per pet, and go out at login", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159, 46 } }, { "Kari Berg", { 40 } } })
        ola:Slash("adopter panda")
        w:Run(5)
        ola.ns.Bond:Add(10) -- a new bond: out at once
        w:Run(2)
        ola.ns.Bond:Add(3)  -- waits (up to 30 minutes)
        ola:Slash("adopter white kitten")
        w:Run(5)
        ola.ns.Bond:Add(10); w:Run(2)
        ola.ns.Bond:Add(2)  -- the kitten's, waiting too
        w:Run(1801)
        eq(kari.ns.Registry:Life(PANDA, "Ola Nord").p, 13, "the panda's gain wasn't lost to the swap")
        eq(kari.ns.Registry:Life(KITTEN, "Ola Nord").p, 12)
        -- A gain still waiting at logout goes out at the next login.
        ola.ns.Bond:Add(4)
        ola:Reload()
        w:Run(30)
        eq(kari.ns.Registry:Life(KITTEN, "Ola Nord").p, 16)
    end)

    test("requests anyone can send are answered at most once per channel every few seconds", function()
        local w, ola, kari = Guild({ { "Ola Nord", { 5159 } }, { "Kari Berg", { 46 } } })
        local m = w:Mark()
        for _ = 1, 5 do w:InjectMessage("Per Hansen", { k = "VER_REQ", p = ola.ns.PROTOCOL }, "GUILD") end
        w:Run(3)
        eq(w:Sent("VER", "Ola Nord", m), 1)
        w:Run(6)
        w:InjectMessage("Per Hansen", { k = "VER_REQ", p = ola.ns.PROTOCOL }, "GUILD")
        w:Run(2)
        eq(w:Sent("VER", "Ola Nord", m), 2, "after the gap, again")
    end)

    test("under our pages the card rests: no updates, no animations, no celebration spent unseen", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        ola:Slash("adopter panda")
        w:Run(5)
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        eq(ola.ns.DB.char.bondSeen[PANDA], 1)
        local park = ola.ns.ParkPage._sp
        park:Open()
        ok(ola.ns.SidePage:AnyOpen())
        local playing = 0
        for _, p in ipairs(card.decor.parts) do if p.anim:IsPlaying() then playing = playing + 1 end end
        eq(playing, 0, "the decorations stop under the page")
        no(card.bond.pips[1].halo.pulse:IsPlaying())
        -- A level-up while the page is up: not celebrated there, nor remembered as seen.
        w:SkipDays(2)
        ola.ns.Bond:Add(100)
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard) -- Blizzard's own update, under the page
        eq(#(ola.sounds or {}), 0)
        eq(ola.ns.DB.char.bondSeen[PANDA], 1)
        -- Back on the card: now it's celebrated.
        park:Close()
        eq(ola.ns.DB.char.bondSeen[PANDA], 2)
        ok(card.celebration.flash:IsShown())
        eq(#ola.sounds, 1)
        -- The card hidden (the window closed), and Blizzard updates it anyway: not spent either.
        ola.env.PetJournalPetCard:Hide()
        ola.ns.Bond:Add(170) -- Venn
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard)
        eq(ola.ns.DB.char.bondSeen[PANDA], 2)
        ola.env.PetJournalPetCard:Show()
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard)
        eq(ola.ns.DB.char.bondSeen[PANDA], 3, "seen when it's shown")
    end)

    test("a refresh that changes nothing leaves the decorations playing", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        ola:Slash("adopter panda")
        w:Run(5)
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        local d = card.decor
        ola.ns.Decor:Apply(card, PANDA, 5)
        local first = d.parts[1].anim
        local plays = first.plays
        ok(first:IsPlaying())
        ola.ns.Decor:Apply(card, PANDA, 5)
        eq(first.plays, plays, "not restarted")
        ola.ns.Decor:Apply(card, PANDA, 6)
        ok(d.parts[1].anim.plays > plays or d.parts[1].anim ~= first, "a new level: relaunched")
        -- Hidden and shown again: they start again.
        ola.env.PetJournalPetCard:Hide()
        no(d.parts[1].anim:IsPlaying())
        ola.env.PetJournalPetCard:Show()
        ola.ns.Decor:Apply(card, PANDA, 6)
        ok(d.parts[1].anim:IsPlaying())
    end)

    test("names that are secret values are unknown, not errors; the event dispatcher survives changes mid-event", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        ola.env.UnitName = function() return H.SECRET, "Nord" end
        eq(ola.ns.UnitKey("party1"), nil)
        ola.env.UnitName = function() return "Kari", H.SECRET end
        eq(ola.ns.UnitKey("party1"), nil)
        -- A handler removing itself and adding another, for the same event, while it's dispatched.
        local E, a, b = ola.ns.Events, {}, {}
        local ran = {}
        E:On("BAG_UPDATE_DELAYED", a, function()
            ran[#ran + 1] = "a"
            E:Off("BAG_UPDATE_DELAYED", a)
            E:On("BAG_UPDATE_DELAYED", b, function() ran[#ran + 1] = "b" end)
        end)
        ola:Fire("BAG_UPDATE_DELAYED")
        ola:Fire("BAG_UPDATE_DELAYED")
        eq(table.concat(ran, ","), "a,b")
        -- And one removing another before its turn: that one isn't called.
        local x, y = {}, {}
        local calls = 0
        local function Count() calls = calls + 1 end
        E:Off("BAG_UPDATE_DELAYED", b)
        E:On("BAG_UPDATE_DELAYED", x, function() calls = calls + 1; E:Off("BAG_UPDATE_DELAYED", y) end)
        E:On("BAG_UPDATE_DELAYED", y, function() calls = calls + 1; E:Off("BAG_UPDATE_DELAYED", x) end)
        ola:Fire("BAG_UPDATE_DELAYED")
        eq(calls, 1, "whichever ran first removed the other")
    end)

    test("the level preview keeps the bar within the level it shows", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        ola:Slash("adopter panda")
        w:Run(5)
        local now = w:ServerTime()
        ola.ns.DB:Guild().life[PANDA] = { ["Ola Nord"] = { p = 2000, f = now - 100 * DAY, t = now } }
        ola:OpenJournal()
        ola:SelectPet(5159)
        ola:Slash("probe level 2")
        local b = ola:Card().bond
        eq(b.text.text, "269 / 270"); eq(b.next.text, "1 poeng til Venn", "not a negative count")
        ola:Slash("probe level off")
    end)

    test("achievements: no check for an activity none of them counts; one check for an activity and its points", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        ola:Slash("adopter panda")
        w:Run(5)
        ola:Slash("debug on")
        for _ = 1, 10 do ola.env.JumpOrAscendStart() end -- a "jump": no achievement counts it (its bond point does)
        w:Run(1)
        local before = #ola:Log("Ach\tcheck")
        ola:Fire("QUEST_TURNED_IN", 1) -- points (BOND), and an activity
        ola:Fire("QUEST_TURNED_IN", 2)
        w:Run(1)
        eq(#ola:Log("Ach\tcheck") - before, 1, "one check for two quests and their points")
        eq(#ola:Log("Ach\tcheck %(activity%)"), 0)
    end)

    test("auto-summon listens to the game only while it can do something: on, with an adopted pet", function()
        local w, ola = Guild({ { "Ola Nord", { 5159 } } })
        local function Listening(e)
            for _, f in ipairs(ola.frames) do if f.events[e] then return true end end
        end
        no(Listening("PLAYER_MOUNT_DISPLAY_CHANGED"), "no pet yet")
        ola:Slash("adopter panda")
        w:Run(2)
        ok(Listening("PLAYER_MOUNT_DISPLAY_CHANGED")); ok(Listening("PLAYER_REGEN_ENABLED"))
        ola.ns.Summon:SetEnabled(false)
        no(Listening("PLAYER_MOUNT_DISPLAY_CHANGED"), "turned off")
        ola.ns.Summon:SetEnabled(true)
        ok(Listening("PLAYER_MOUNT_DISPLAY_CHANGED"))
        ola:Slash("gislipp")
        w:Run(2)
        no(Listening("PLAYER_MOUNT_DISPLAY_CHANGED"), "let go")
    end)
end
