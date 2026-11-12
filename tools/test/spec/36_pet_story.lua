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

    test("the button shows on a pet with a story; it opens the panel beside the window, newest first", function()
        local w, ola = H.Setup{ ola = { 5159, 40 }, journal = true }
        ola.ns.Bonds.PetOfTheDay = function() end -- (here and below, but in the last: the pet of the day)
        local card = ola:SelectPet(5159)
        no(card.story:IsShown(), "no story yet")
        ola:Slash("adopter panda")
        w:Run(5)
        ok(card.story:IsShown(), "adopted: its story begins")
        ola:SelectPet(40)
        no(card.story:IsShown(), "a pet with no story: no button")
        ola:SelectPet(5159)
        eq(ola:TipOf(card.story)[1], "Historien om Panda Cub")
        card.story:Click()
        local p = ola.ns.Story.panel
        ok(p:IsShown())
        eq(p.points[1][2], ola.env.CollectionsJournal, "right of the window")
        eq(p.points[1][3], "TOPRIGHT"); eq(p.points[2][3], "BOTTOMRIGHT", "as tall as it")
        eq(p.points[1][4], 64, "past where the side tabs would be")
        eq(p.template, "ButtonFrameTemplate", "styled like the window")
        ok(p.portraitHidden)
        eq(p.titleText, "Historien om Panda Cub")
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
        eq(p.title.text, "Historien om Panda Cub")
        ok(p.close and p.close:IsShown())
        p.close:Click()
        no(p:IsShown())
    end)
end
