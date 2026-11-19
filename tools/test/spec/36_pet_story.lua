-- A pet's story (Menagerie/Story.lua): a local timeline of its life in the
-- guild, from a book button on its card to a panel beside the window.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN = "s:5159", "s:46"

    local function Kinds(ola, key)
        local list = {}
        for _, e in ipairs(ola.ns.Story:Of(key) or {}) do list[#list + 1] = e.k end
        return table.concat(list, " ")
    end
    local function Lines(ola)
        local p, list = ola.ns.Story.panel, {}
        for _, r in ipairs(p.rows) do if r.text:IsShown() then list[#list + 1] = r.text.text end end
        return list
    end

    test("the panel stands beside the window SidePage knows; before the journal has loaded, nothing opens", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda")
        w:Run(5)
        no(ola.ns.SidePage:Host(), "the journal isn't loaded")
        ola.ns.Story:Show(PANDA)
        no(ola.ns.Story.panel, "no panel without its window")
        ola:OpenJournal()
        ola.ns.Story:Show(PANDA)
        eq(ola.ns.Story.panel.points[1][2], ola.ns.SidePage:Host())
    end)

    -- (2026-11-19: on every pet, as the panel has more than the story now: AboutPet.lua's tabs)
    test("the button shows on every pet; it opens the panel beside the window, newest first", function()
        local w, ola = H.Setup{ ola = { 5159, 40 }, journal = true }
        ola.ns.Bonds.PetOfTheDay = function() end -- (here and below, but in the last: the pet of the day)
        local card = ola:SelectPet(5159)
        ok(card.story:IsShown(), "no story yet: still the button")
        ola:Slash("adopter panda")
        w:Run(5)
        ola:SelectPet(5159)
        eq(ola:TipOf(card.story).text, "Om Panda Cub / Historien, personligheten og båndene. / Klikk for å åpne")
        eq(card.story.arrow.rotation, -math.pi / 2, "an arrow out to the side")
        card.story:Click()
        eq(card.story.arrow.rotation, math.pi / 2, "and back while it's open")
        eq(ola:TipOf(card.story)[3], "Klikk for å lukke")
        local p = ola.ns.Story.panel
        ok(p:IsShown())
        eq(p.points[1][2], ola.env.CollectionsJournal, "right of the window")
        eq(p.points[1][3], "TOPRIGHT"); eq(p.points[2][3], "BOTTOMRIGHT", "as tall as it")
        eq(p.points[1][4], 64, "past where the side tabs would be")
        eq(p.template, "ButtonFrameTemplate", "styled like the window")
        ok(p.portraitHidden)
        eq(p.titleText, "Om Panda Cub")
        eq(Lines(ola)[1], "Første hjem: flyttet inn hos deg")
        -- Thirty days on, and a name: newest at the top.
        w:SkipDays(31)
        ola.ns.Story:Scan()
        local g = ola.ns.DB:Guild()
        g.names[PANDA] = { ["Ola Nord"] = { n = "Pepe", at = w:ServerTime() } }
        ola.ns.Registry:Changed()
        w:Run(3)
        local lines = Lines(ola)
        eq(lines[1], "Fikk navnet «Pepe» av deg")
        eq(lines[2], "1 måned hos deg")
        eq(lines[3], "Første hjem: flyttet inn hos deg")
        -- Dense (2026-11-14, the user: "more dense"): the small font, no button bar, entries close together
        -- (a 12 px date, 1 px, a 14 px line in the harness, a 4 px gap).
        ok(p.buttonBarHidden, "the inset takes the button bar's strip")
        eq(p.rows[1].text.font, "GameFontHighlightSmall"); eq(p.rows[1].date.font, "GameFontDisableSmall")
        eq(p.rows[2].date.points[1][5], -31, "the next entry starts right below")
        -- The close button; the button again toggles it.
        p.close:Click()
        no(p:IsShown())
        card.story:Click(); ok(p:IsShown())
        card.story:Click(); no(p:IsShown())
        -- It follows the card, and closes with the window or under our pages.
        card.story:Click()
        ola:SelectPet(40)
        eq(p.key, "s:40")
        eq(Lines(ola)[1], "Historien har ikke begynt ennå.")
        ola.ns.Bus:Fire("SIDEPAGE", true)
        no(p:IsShown(), "our page covers the card")
        ola:SelectPet(5159); card.story:Click()
        ola:CloseJournal()
        no(p:IsShown())
    end)

    -- Like the cake, the crown and the paw badge, the book is over the model's level: hidden under our
    -- pages, and a new entry meanwhile mustn't bring it back there. A card with no pet closes the panel.
    test("the book hides under our pages and stays hidden through a new entry; a card with no pet closes the panel", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola.ns.Bonds.PetOfTheDay = function() end
        ola:Slash("adopter panda")
        w:Run(5)
        local card = ola:SelectPet(5159)
        ok(card.story:IsShown())
        ola.ns.ParkPage:Open()
        no(card.story:IsShown(), "hidden under the page")
        ola.ns.Story:Mine(PANDA, "egg", "Pandaen gjesper.")
        no(card.story:IsShown(), "a new entry under the page: still hidden")
        ola.ns.SidePage:CloseAll()
        ok(card.story:IsShown(), "back on the card")
        card.story:Click()
        ok(ola.ns.Story:IsOpen())
        ola.ns.Card:Update(card, nil, {}) -- (the card with no pet on it)
        no(card.story:IsShown())
        no(ola.ns.Story:IsOpen(), "no panel of the last pet beside an empty card")
    end)

    -- The panel's tabs (AboutPet.lua, 2026-11-19): the story, the personality in full, everyone's bonds.
    test("the panel's tabs: the story, its personality, everyone's bonds; the last one chosen opens next time", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 40 }, kari = { 5159 }, journal = true }
        ola.ns.Bonds.PetOfTheDay = function() end
        ola:Slash("adopter panda"); w:Run(5)
        local card = ola:SelectPet(5159)
        card.story:Click()
        local p, S = ola.ns.Story.panel, ola.ns.Story
        local titles = {}
        for _, b in ipairs(p.tabs) do titles[#titles + 1] = b.text.text end
        eq(table.concat(titles, " "), "Historie Personlighet Bånd")
        ok(p.tabs[1].line:IsShown(), "the story first"); no(p.tabs[2].line:IsShown())
        ok(p.pages.story:IsShown())
        p.tabs[2]:Click()
        ok(p.tabs[2].line:IsShown()); no(p.tabs[1].line:IsShown())
        no(p.pages.story:IsShown(), "one page at a time")
        eq(p.scroll.scrollChild, p.pages.personality)
        local text = ola:About(PANDA, "personality").text
        match(text, "^Egenskaper / ")
        match(text, " / Liker / ")
        -- Bånd: strongest first, the holder's home said, you as "Du".
        local now = w:ServerTime()
        ola.ns.Registry:MergeLife(PANDA, "Kari Berg", { p = 600, f = now - 40 * 86400, t = now })
        local lines = ola:About(PANDA, "bonds")
        eq(lines[1], "Alle i guilden som har et bånd med Panda Cub, sterkest først.")
        eq(lines[2], "Kari Berg"); eq(lines[3], "God venn (level 4), 600 poeng")
        eq(lines[4], "Du"); match(lines[5], "^Bekjent %(level 1%), %d+ poeng · Panda Cub bor her$")
        -- Closed and opened again: on Bånd, the last chosen; another pet keeps the tab.
        p.close:Click()
        card.story:Click()
        ok(p.tabs[3].line:IsShown(), "the tab last chosen")
        ola:SelectPet(40)
        eq(p.key, "s:40"); ok(p.tabs[3].line:IsShown())
        eq(ola:About("s:40", "bonds")[1], "Ingen i guilden har et bånd med Bombay Cat ennå.")
        -- A pet whose personality is a surprise says so.
        eq(ola:About("s:84", "personality").text, "Ukjent personlighet / Personligheten er en overraskelse. "
            .. "Den blir kjent når du eller noen i guilden har dyret.")
    end)

    test("the guild's part: homes, moves, names, levels, as this client sees them", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 46 } }
        ola.ns.Bonds.PetOfTheDay = function() end
        kari:Slash("adopter white")
        w:Run(10)
        eq(Kinds(ola, KITTEN), "adopt", "Kari's kitten: in Ola's story too")
        -- Kari's bond grows two levels: both in the story.
        local g = ola.ns.DB:Guild()
        g.life[KITTEN] = g.life[KITTEN] or {}
        g.life[KITTEN]["Kari Berg"] = { p = 50, f = w:ServerTime(), t = w:ServerTime() }
        ola.ns.Story:Scan()
        g.life[KITTEN]["Kari Berg"] = { p = 300, f = w:ServerTime(), t = w:ServerTime() }
        ola.ns.Story:Scan()
        eq(Kinds(ola, KITTEN), "adopt level level")
        eq(ola.ns.Story:Text(KITTEN, ola.ns.Story:Of(KITTEN)[3]), "Ble Venn med Kari Berg (level 3)")
        -- She lets it go after three days; Ola adopts it.
        w:SkipDays(3)
        kari:Slash("gislipp")
        w:Run(10)
        ola.ns.Story:Scan()
        local list = ola.ns.Story:Of(KITTEN)
        eq(list[#list].k, "letgo")
        eq(ola.ns.Story:Text(KITTEN, list[#list]), "Flyttet fra Kari Berg etter 3 dager")
        ola:GivePet(46); ola:Slash("adopter white"); w:Run(10)
        list = ola.ns.Story:Of(KITTEN)
        eq(ola.ns.Story:Text(KITTEN, list[#list]), "Flyttet inn hos deg", "not the first home")
        eq(ola.ns.Story:Text(KITTEN, list[1], true), "Første hjem: flyttet inn hos Kari Berg")
        -- Scanning again adds nothing.
        local n = #list
        ola.ns.Story:Scan(); ola.ns.Story:Scan()
        eq(#ola.ns.Story:Of(KITTEN), n)
    end)

    test("it starts with what's known: homes, names and passed milestones with their dates; levels left out", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda")
        w:Run(5)
        local g = ola.ns.DB:Guild()
        local at = select(2, ola.ns.Registry:Holder(PANDA)).at
        g.story = {} -- (as before the story existed)
        g.life[PANDA]["Ola Nord"].p = 1000
        w:SkipDays(400)
        ola.ns.Story:Scan()
        eq(Kinds(ola, PANDA), "adopt milestone milestone milestone day", "and today: the pet of the day (the only one)")
        ola.ns.Story:Scan()
        eq(Kinds(ola, PANDA), "adopt milestone milestone milestone day", "once a day")
        w:SkipDays(1); ola.ns.Story:Scan()
        eq(Kinds(ola, PANDA), "adopt milestone milestone milestone day day")
        local list = ola.ns.Story:Of(PANDA)
        eq(list[1].t, at, "the adoption's own date")
        eq(ola.ns.Story:Text(PANDA, list[4]), "1 år hos deg")
        eq(ola.ns.Date(list[4].t), ola.ns.Date(at + 365 * 86400))
    end)

    test("your part: the very first boss, place and playdate, eggs once each, achievements with the pet out", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola.ns.Bonds.PetOfTheDay = function() end
        ola:Slash("adopter panda")
        w:Run(5)
        local S = ola.ns.Story
        ola.ns.Bond:First("boss", PANDA, "Hogger")
        ola.ns.Bond:First("boss", PANDA, "Van Cleef")
        local function Count(k)
            local n = 0
            for _, e in ipairs(S:Of(PANDA)) do if e.k == k then n = n + 1 end end
            return n
        end
        eq(Count("first.boss"), 1, "only the very first")
        match(S:Text(PANDA, S:Of(PANDA)[#S:Of(PANDA)]), "Første boss sammen med deg: Hogger")
        S:Mine(PANDA, "egg", "Panda Cub synes klokka er kul.", "leet")
        S:Mine(PANDA, "egg", "Panda Cub synes noe annet.", "leet")
        eq(Count("egg"), 1, "each egg once")
        eq(S:Text(PANDA, S:Of(PANDA)[#S:Of(PANDA)]), "«Panda Cub synes klokka er kul.»", "the line it said")
        ola.ns.Pets.OutKey = function() return PANDA end
        S:Achievements({ "loyal:2" })
        eq(Count("ach"), 1)
        match(S:Text(PANDA, S:Of(PANDA)[#S:Of(PANDA)]), "^Var med da du fikk")
        ola.ns.Playdate:Count(PANDA, "Kari Berg", "s:46")
        ola.ns.Playdate:Count(PANDA, "Kari Berg", "s:46")
        eq(Count("first.play"), 1)
        eq(S:Text(PANDA, S:Of(PANDA)[#S:Of(PANDA)]), "Første lekedate: med Kari Berg sin White Kitten")
    end)

    test("old flavor folds into one grey line a run; milestones stay; a folded egg isn't new again; carers who left go", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola.ns.Bonds.PetOfTheDay = function() end
        ola:Slash("adopter panda")
        w:Run(5)
        local S = ola.ns.Story
        S:Mine(PANDA, "egg", "En.", "a")
        S:Mine(PANDA, "egg", "To.", "b")
        ola.ns.Bond:First("boss", PANDA, "Hogger")
        S:Mine(PANDA, "egg", "Tre.", "c")
        w:SkipDays(S.FLAVOR_DAYS + 1)
        S:Mine(PANDA, "egg", "Fire.", "d")
        local g = ola.ns.DB:Guild()
        g.story[PANDA].lv["Gammel Bekjent"] = 3
        S:Scan()
        local kinds = {}
        for _, e in ipairs(S:Of(PANDA)) do kinds[#kinds + 1] = e.k .. (e.k == "many" and e.v or "") end
        eq(table.concat(kinds, " "), "adopt many2 first.boss many1 milestone egg", "runs folded, the boss and the month kept, the new one too")
        eq(S:Text(PANDA, S:Of(PANDA)[2]), "2 interaksjoner")
        S:Mine(PANDA, "egg", "En igjen.", "a")
        eq(#S:Of(PANDA), 6, "a folded egg isn't added again")
        eq(g.story[PANDA].lv["Gammel Bekjent"], nil, "not in the guild: pruned with the roster")
        -- Runs don't merge across what stays (the month), and a new fold joins the run before it.
        S:Mine(PANDA, "egg", "Fem.", "e")
        w:SkipDays(S.FLAVOR_DAYS + 1); S:Scan()
        kinds = {}
        for _, e in ipairs(S:Of(PANDA)) do kinds[#kinds + 1] = e.k .. (e.k == "many" and e.v or "") end
        eq(table.concat(kinds, " "), "adopt many2 first.boss many1 milestone many2")
        -- In the panel: grey, with its dates.
        ola:OpenJournal()
        ola:SelectPet(5159)
        S:Show(PANDA)
        local row
        for _, r in ipairs(S.panel.rows) do if r.text.text == "2 interaksjoner" then row = r end end
        ok(row and row.text.color and row.text.color[1] == 0.6, "grey")
        match(row.date.text, "^%d%d%.%d%d%.%d%d%d%d$", "(both on one day: one date)")
        -- A run over several days: its first and last.
        local g2 = { e = { { t = 1790000000, k = "many", v = 1, u = 1790000000 }, { t = 1790000000 + 5 * 86400, k = "day", v = "x" } } }
        S.Compact(g2, 1790000000 + 400 * 86400)
        eq(#g2.e, 1); eq(g2.e[1].v, 2); eq(g2.e[1].u, 1790000000 + 5 * 86400)
        g.story[PANDA].e[#g.story[PANDA].e].u = g.story[PANDA].e[#g.story[PANDA].e].t + 3 * 86400
        S:Redraw()
        match(S.panel.rows[1].date.text, "^%d%d%.%d%d%.%d%d%d%d – %d%d%.%d%d%.%d%d%d%d$")
    end)

    test("the panel starts past the side tabs, ours too; without the window's template, a frame of its own", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola.ns.Bonds.PetOfTheDay = function() end
        ola:OpenJournal({ sideTabs = 3 })
        ola:Slash("adopter panda"); w:Run(5)
        local card = ola:SelectPet(5159)
        card.story:Click()
        local p = ola.ns.Story.panel
        local right = ola.ns.SidePage:TabsRight()
        ok(right >= 755, "Blizzard's tabs reach 755")
        eq(p.points[1][4], right - 700 + 2)
        -- Shown again and again (another pet each time), laid out: it stays put.
        p.geo = { l = right + 2, r = right + 302, t = 600, b = 0 }
        p.close.geo = { l = right + 280, r = right + 300, t = 600, b = 580 }
        ola:SelectPet(5159); ola.ns.Story:Show("s:5159"); ola.ns.Story:Show("s:5159")
        eq(p.points[1][4], right - 700 + 2, "not pushed right by its own buttons")
        -- An older client: no ButtonFrameTemplate.
        local w2, kari = H.Setup{ ola = { 5159 } }
        kari.oldTemplates = true
        kari:OpenJournal()
        kari.ns.Bonds.PetOfTheDay = function() end
        kari:Slash("adopter panda"); w2:Run(5)
        card = kari:SelectPet(5159)
        card.story:Click()
        p = kari.ns.Story.panel
        eq(p.template, nil)
        eq(p.title.text, "Om Panda Cub")
        ok(p.close and p.close:IsShown())
        p.close:Click()
        no(p:IsShown())
    end)
end
