-- Your story with a pet, on its card (2026-11-08): what you've done together
-- (Stats.lua), today's wish (Wish.lua), and petting it on the card.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Setup()
        local w, ola, kari = H.Setup{ ola = { 5159, 40 }, kari = { 40 }, settle = "bond" }
        ola:Slash("adopter panda")
        w:Run(5)
        ola:OpenJournal()
        return w, ola, kari
    end

    local function Shown(row)
        local list = {}
        for _, chip in ipairs(row.chips) do if chip:IsShown() then list[#list + 1] = chip end end
        return list
    end

    test("the chips: days out together first, then the biggest counts, yours only", function()
        local w, ola, kari = Setup()
        local card = ola:SelectPet(5159)
        no(card.stats:IsShown(), "nothing done together yet")
        ola.ns.Activity:CheckDay()
        for _ = 1, 3 do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366) end
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
        card = ola:SelectPet(5159)
        ok(card.stats:IsShown())
        local chips = Shown(card.stats)
        eq(#chips, 3)
        eq(chips[1].id, "day"); eq(chips[1].count.text, 1)
        eq(chips[2].id, "herb"); eq(chips[2].count.text, 3)
        eq(chips[3].id, "boss")
        eq(chips[2].icon.tex, "Interface\\Icons\\Trade_Herbalism")
        eq(ola:TipOf(chips[2])[1], "3 herbs sammen med Panda Cub")
        eq(ola:TipOf(chips[1])[1], "1 dag ute sammen med Panda Cub")
        -- At the top; under the ribbon when there is one.
        eq(card.stats.points[1][3], "TOP"); eq(card.stats.points[1][5], -14)
        ola:Slash("probe level 6")
        eq(card.stats.points[1][2], card.decor.ribbon, "under the ribbon")
        ola:Slash("probe level off")
        -- At most five, the biggest.
        for _, id in ipairs({ 2575, 7620, 8613 }) do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", id) end
        ola:Fire("QUEST_TURNED_IN", 1); ola:Fire("QUEST_TURNED_IN", 2)
        card = ola:SelectPet(5159)
        chips = Shown(card.stats)
        eq(#chips, 5)
        eq(#ola.ns.Stats:For(PANDA), 5, "the list itself stops at five (seven kinds were done)")
        eq(chips[1].id, "day"); eq(chips[2].id, "herb"); eq(chips[3].id, "quest")
        -- A missing icon: a question mark, not a hole.
        ola.missingFiles = { ["Interface\\Icons\\Trade_Herbalism"] = true }
        card = ola:SelectPet(5159)
        eq(Shown(card.stats)[2].icon.tex, "Interface\\Icons\\INV_Misc_QuestionMark")
        -- Kari has done nothing with the panda: no chips for her.
        kari:OpenJournal()
        kari:GivePet(5159)
        no(kari:SelectPet(5159).stats:IsShown())
        -- No pet selected: hidden.
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        no(card.stats:IsShown())
    end)

    test("today's wish: one of its likes, the same all day; doing it brings 10 points once", function()
        local w, ola, kari = Setup()
        local W, P = ola.ns.Wish, ola.ns.Personality
        -- A wish is something the pet likes and you can do: never dying, a level or the day itself.
        ola:Traits{ "trofast", "ambisios" } -- likes revive, level (+ herbs)
        P.BY_FAMILY.bear = nil -- (the panda's own herbs only, not a bear's fishing)
        for d = 1, 30 do eq(W:For(PANDA, ("202611%02d"):format(d)), "herb", "the one doable like") end
        P.BY_SPECIES = {}
        P.BY_FAMILY, P.DEFAULT = {}, {}
        eq(W:For(PANDA, "20261109"), "quest", "nothing doable liked: a quest")
        P.BY_SPECIES = { [5159] = { "herb", "fish", "mine" } }
        local seen = {}
        for d = 1, 30 do seen[W:For(PANDA, ("202611%02d"):format(d))] = true end
        ok(seen.herb and seen.fish and seen.mine, "it varies from day to day")
        eq(W:For(PANDA, "20261109"), W:For(PANDA, "20261109"), "the same all day")
        -- Today's: a herb, say.
        W.For = function() return "herb" end
        ola.ns.DB.char.wish = nil
        local wish = W:Today()
        eq(wish.id, "herb"); eq(wish.pet, PANDA); no(wish.done)
        local card = ola:SelectPet(5159)
        ok(card.wish:IsShown())
        -- In one of its own words, the same all day (2026-11-14, the user: "a little more flavor").
        local said = card.wish.text.text
        local own = {}
        for _, k in ipairs(ola.ns.Variants("wish.say.herb")) do own[ola.ns.T(k, { pet = "Panda Cub" })] = true end
        ok(own[said], said)
        eq(ola:SelectPet(5159).wish.text.text, said, "the same line when it shows again")
        eq(card.wish.icon.tex, "Interface\\Icons\\Trade_Herbalism")
        eq(ola:TipOf(card.wish).text, "Dagens ønske / Gjør det med Panda Cub ute i dag, så får dere 10 ekstra båndpoeng.")
        local function Earned() local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); return e and e.p or 0 end
        local before = Earned()
        ola:Fire("QUEST_TURNED_IN", 1)
        no(W:Today().done, "not what it wished for")
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        ok(W:Today().done)
        ok(ola:Printed("Panda Cub fikk ønsket sitt oppfylt: herbs! (+10 båndpoeng)", true))
        local after = Earned()
        eq(after - before, 1 + 5 + 10, "the quest, the herb, and the wish")
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned(), after + 5, "once a day: the next herb is just a herb")
        card = ola:SelectPet(5159)
        eq(card.wish.text.text, "Ønsket er oppfylt!"); eq(card.wish.text.color[2], 1)
        -- A new day, a new wish: past the day's limit, like a feat (2026-11-13, the user).
        w:SkipDays(1)
        no(W:Today().done, "a new wish")
        ola.ns.DB.char.bondToday = { day = os.date("%Y%m%d", ola.ns.Now()), pets = { [PANDA] = { got = {}, total = 72 } } }
        before = Earned()
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned() - before, 3 + 10, "the herb: what's left of the day; the wish: all of it")
        eq(ola.ns.DB.char.bondToday.pets[PANDA].total, 75, "the wish not counted in the day")
        -- Not with another companion out.
        w:SkipDays(1)
        ola:Summon(40)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        no(W:Today().done)
        -- Only on your own pet's card; none without a pet.
        no(ola:SelectPet(40).wish:IsShown())
        kari:OpenJournal()
        no(kari:SelectPet(40).wish:IsShown())
        eq(kari.ns.Wish:Today(), nil)
    end)

    test("wishes in a row: counted once a day, a missed day starts over; on the line and in achievements", function()
        local w, ola = Setup()
        local W = ola.ns.Wish
        W.For = function() return "herb" end
        ola.ns.DB.char.wish = nil
        local s = ola.ns.DB.char.wishes
        local function Herb() ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366) end
        Herb()
        eq(s.n, 1); eq(s.streak, 1)
        eq(ola:SelectPet(5159).wish.text.text, "Ønsket er oppfylt!", "one day: no run yet")
        -- The same day again (another pet's wish after a swap): still one day.
        W:Count(ola.ns.Today())
        eq(s.n, 1); eq(s.streak, 1)
        -- The next day: the tooltip says what keeps the run; done, two in a row.
        w:SkipDays(1)
        local card = ola:SelectPet(5159)
        ok(ola:TipOf(card.wish).text:find("Oppfyll det i dag, så blir det 2 dager på rad.", 1, true))
        Herb()
        eq(s.streak, 2)
        card = ola:SelectPet(5159)
        eq(card.wish.text.text, "Ønsket er oppfylt! 2 dager på rad")
        ok(ola:TipOf(card.wish).text:find("2 oppfylte ønsker på rad.", 1, true))
        -- A day missed: the run is over (the best stays), and starts again at one.
        w:SkipDays(2)
        eq((W:Streak()), 0)
        Herb()
        eq(s.streak, 1); eq(s.best, 2); eq(s.n, 3)
        -- Seven in a row: Ønskeuke.
        for _ = 1, 6 do w:SkipDays(1); Herb() end
        eq(s.streak, 7)
        ok(ola.ns.Achievements:Got("wish:7"), "seven days in a row")
        no(ola.ns.Achievements:Got("wish:30"))
        s.n = 99
        w:SkipDays(1); Herb()
        ok(ola.ns.Achievements:Got("wish:100"), "a hundred in all")
    end)

    test("today's wish pays once a day per pet, even after letting it go and adopting it again", function()
        local w, ola = Setup()
        local W = ola.ns.Wish
        W.For = function() return "herb" end
        ola.ns.DB.char.wish = nil
        local function Earned() local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); return e and e.p or 0 end
        ola:Summon(5159)
        local before = Earned()
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned() - before, 5 + 10, "the herb and the wish")
        -- Over to the cat and back: a fresh wish for the panda, the same day (review 2026-11-11).
        ola:Slash("adopter bombay"); w:Run(5)
        ola:Slash("adopter panda"); w:Run(5)
        ola:Summon(5159)
        before = Earned()
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned() - before, 5, "just a herb")
        local lines = 0
        for _, line in ipairs(ola.printed) do
            if line:find("fikk ønsket sitt oppfylt", 1, true) then lines = lines + 1 end
        end
        eq(lines, 1, "one wish line")
    end)

    test("a wish on a full day still gives its 10; near the wire's cap it says what it gave, or no amount at all", function()
        local w, ola = Setup()
        local W = ola.ns.Wish
        W.For = function() return "herb" end
        ola.ns.DB.char.wish = nil
        ola:Summon(5159)
        local function Earned() local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); return e and e.p or 0 end
        local function Today(total)
            ola.ns.DB.char.bondToday = { day = ola.ns.Today(), pets = { [PANDA] = { got = { herb = 25 }, total = total } } }
        end
        -- A full day: all ten, past the day's 75 (2026-11-13, the user).
        Today(75)
        local before = Earned()
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned() - before, 10)
        ok(ola:Printed("Panda Cub fikk ønsket sitt oppfylt: herbs! (+10 båndpoeng)", true))
        -- Two points short of what the wire accepts (Registry.LifeCap): the line says two.
        local B = ola.ns.Bond
        local function Room(n) local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); e.p = e.p + B:Room(PANDA) - n end
        w:SkipDays(1)
        ola.ns.DB.char.wish = nil
        Today(75); Room(2)
        before = Earned()
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        eq(Earned() - before, 2)
        ok(ola:Printed("Panda Cub fikk ønsket sitt oppfylt: herbs! (+2 båndpoeng)", true))
        -- At the cap: the wish comes true, with no promise of points.
        w:SkipDays(1)
        ola.ns.DB.char.wish = nil
        Today(75); Room(0)
        before = Earned()
        ola:ClearPrinted()
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
        ok(W:Today().done)
        eq(Earned() - before, 0)
        match(ola:Printed("fikk ønsket sitt oppfylt", true) or "", "Panda Cub fikk ønsket sitt oppfylt: herbs!$")
        no(ola:Printed("båndpoeng", true), "no points promised")
    end)

    -- Wishes past the day's 75 (2026-11-13, the user: "Ensure this doesn't mess with antitampering"): peers
    -- refuse a bond above Wire.LifeCap. Since X-Protocol 10 its room a day is the day's 75 and the wish's 10
    -- (Wire.DayRoom), so a run of full days with every wish done is never clamped (until then it reached the
    -- cap after about two weeks and the wish gave nothing from then on).
    test("twenty full days with every wish done: 85 every day, never at the wire's cap, and the guild keeps taking it", function()
        local w, ola, kari = Setup()
        local W, B, R = ola.ns.Wish, ola.ns.Bond, ola.ns.Registry
        W.For = function() return "herb" end
        local function Mine() return R:Life(PANDA, "Ola Nord") end
        -- (The guild's copy checked every fifth day: half an hour run each time cost two minutes under
        -- coverage over forty days.)
        for day = 1, 20 do
            w:SkipDays(1)
            ola.ns.DB.char.wish = nil
            local before = Mine() and Mine().p or 0
            -- The day filled to its 75 (what it already had, and the rest), then the wish.
            local d = ola.ns.DB.char.bondToday
            local today = (d and d.day == ola.ns.Today() and d.pets[PANDA] and d.pets[PANDA].total) or 0
            B:Add(75 - today, PANDA)
            ola.ns.DB.char.bondToday = { day = ola.ns.Today(), pets = { [PANDA] = { got = { herb = 25 }, total = 75 } } }
            ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366)
            ok(W:Today().done)
            local e = Mine()
            ok(e.p < R.LifeCap(e.f, e.t), "below the wire's cap, day " .. day)
            eq(e.p - before, 85, "the day's 75 and the wish's 10, day " .. day)
            if day % 5 == 0 then
                w:Run(1801) -- (our points go out within 30 minutes)
                local theirs = kari.ns.Registry:Life(PANDA, "Ola Nord")
                eq(theirs and theirs.p, e.p, "Kari took our bond, day " .. day)
            end
        end
        -- A newcomer's SYNC carries it too.
        local per = w:AddClient("Per Hansen", { pets = { 40 } })
        w:Run(40)
        local theirs = per.ns.Registry:Life(PANDA, "Ola Nord")
        eq(theirs and theirs.p, Mine().p, "Per took it from a SYNC")
    end)

    test("petting the pet on the card: a ripple, a few hearts, a glow, a sound; once a day a cuddle", function()
        local w, ola, kari = Setup()
        local card = ola:SelectPet(5159)
        local m, d = card.model, card.cuddle
        ok(m and d)
        local function Click(dx, hold)
            ola.cursor = { 100, 100 }
            m.scripts.OnMouseDown(m)
            if hold then w:Run(hold) end
            ola.cursor = { 100 + (dx or 0), 100 }
            m.scripts.OnMouseUp(m)
        end
        local A = ola.ns.Activity
        Click()
        ok(d.ripple:IsShown()); ok(d.ripple.anim:IsPlaying(), "a ripple")
        local shown = 0
        for _, p in ipairs(d.hearts) do if p:IsShown() and p.anim:IsPlaying() then shown = shown + 1 end end
        eq(shown, 4, "a few hearts")
        ok(d.glow.anim:IsPlaying(), "a glow under the pet")
        eq(d.bubble, nil, "no text")
        eq(ola.sounds[#ola.sounds], 841)
        eq(A:Count("cuddle"), 1, "a cuddle: our adopted pet, out with us")
        Click()
        eq(A:Count("cuddle"), 1, "once a day")
        -- Where you clicked: the card at 300,200 on the screen, scale 1.25.
        local c = ola.env.PetJournalPetCard
        c.geo, c.scale = { l = 300, r = 700, t = 700, b = 200 }, 1.25
        ola.cursor = { 500, 500 }
        m.scripts.OnMouseDown(m); m.scripts.OnMouseUp(m)
        local at = d.ripple.points[#d.ripple.points]
        eq(at[2], c); eq(at[3], "BOTTOMLEFT"); eq(at[4], 500 / 1.25 - 300); eq(at[5], 500 / 1.25 - 200)
        eq(d.hearts[1].points[#d.hearts[1].points][4], 100, "the hearts rise from there too")
        c.geo = nil
        -- Turning the model (a drag) or holding the button isn't petting.
        local sounds = #ola.sounds
        Click(30)
        Click(0, 1)
        eq(#ola.sounds, sounds)
        -- Another pet's card: no cuddle; nor with the pet put away.
        w:SkipDays(1)
        card = ola:SelectPet(40)
        Click()
        eq(A:Count("cuddle"), 1)
        card = ola:SelectPet(5159)
        ola.summoned = nil
        Click()
        eq(A:Count("cuddle"), 1)
        ola:Summon(5159)
        Click()
        eq(A:Count("cuddle"), 2, "a new day")
        -- Closing the journal ends it.
        ola.env.PetJournalPetCard:Hide()
        no(d.ripple:IsShown()); no(d.hearts[1]:IsShown()); no(d.glow:IsShown())
    end)

    test("the list: an adopted pet's bond level in a ring, and its nickname under the name", function()
        local w, ola, kari = Setup()
        local B = ola.ns.JournalList._badges
        local panda, bombay = B[ola:Button(5159)], B[ola:Button(40)]
        ok(panda.ring:IsShown()); eq(panda.level.text, 1)
        eq(panda.ring.atlas, "communities-ring-gold")
        no(bombay.ring:IsShown(), "nobody's pet: no ring")
        no(panda.nick:IsShown(), "no nickname yet")
        -- A level up, and a name: the list follows.
        local now = ola.ns.Now()
        ola.ns.DB:Guild().life[PANDA] = { ["Ola Nord"] = { p = 600, f = now - 100 * 86400, t = now } }
        ola.ns.DB:Guild().names[PANDA] = { ["Ola Nord"] = { n = "Pepe", at = now } }
        ola:Button(5159).name:SetText("Panda Cub") -- (as Blizzard's list does)
        ola.ns.JournalUI:Refresh()
        eq(panda.level.text, 4)
        ok(panda.nick:IsShown()); eq(panda.nick.text, "«Pepe»")
        local at = panda.nick.points[#panda.nick.points]
        eq(at[2], ola:Button(5159).name); eq(at[1], "LEFT"); eq(at[4], #"Panda Cub" * 7 + 5, "right after the name, on its row")
        -- Someone else's pet shows its level too.
        kari:Slash("adopter bombay")
        w:Run(5)
        ola.ns.JournalUI:Refresh()
        ok(bombay.ring:IsShown()); eq(bombay.level.text, 1)
        ok(bombay.ring.desaturated, "someone else's bond: grey")
        no(panda.ring.desaturated, "ours: gold")
        -- Our own bond with a pet we haven't adopted: ours, in gold.
        ola.ns.Bond:Add(150, "s:40")
        ola.ns.JournalUI:Refresh()
        eq(bombay.level.text, 2); no(bombay.ring.desaturated)
    end)
end
