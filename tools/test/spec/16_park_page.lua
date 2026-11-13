-- "Parken": the park map page, its tab next to the achievements tab, the
-- records, and switching between our two pages.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- A small journal: 4 cats, a farm bird, a rabbit, the panda.
    local function Fixture()
        return { build = 1, species = {
            [40] = { a = true, t = { "cat" } }, [41] = { a = true, t = { "cat" } },
            [42] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat" } },
            [84] = { a = true, t = { "farm", "bird" } }, [72] = { a = true, t = { "rabbit" } },
            [5159] = { a = false },
        } }
    end

    local function Setup()
        local w = H.World()
        local cs = {}
        for _, m in ipairs({ { "Ola Nord", { 5159, 40, 72 } }, { "Kari Berg", { 41 } }, { "Per Hansen", { 42 } } }) do
            local c = w:AddClient(m[1], { pets = m[2] })
            c:Companions(Fixture().species)
            cs[#cs + 1] = c
        end
        w:Run(20)
        return w, unpack(cs)
    end

    -- The park's icons as the player sees them: shown on the page, each with a species' journal
    -- icon (the harness's GetPetInfoBySpeciesID gives species sid the icon 1000 + sid).
    local function SpeciesOf(f)
        for _, t in ipairs(f.textures) do
            if t.shown and type(t.tex) == "number" and H.SPECIES[t.tex - 1000] then return t.tex - 1000 end
        end
    end
    local function Cells(c) return c:Page("Parken"):Frames(SpeciesOf) end
    local function Cell(c, sid)
        for _, cell in ipairs(Cells(c)) do if SpeciesOf(cell) == sid then return cell end end
    end

    local function Tip(c, cell)
        return c:TipOf(cell).text
    end

    test("its tab comes under ours; our two pages take turns", function()
        local w, ola = Setup()
        ola:OpenJournal({ sideTabs = 4 })
        local env, A, P = ola.env, ola.ns.AchPage, ola.ns.ParkPage
        local park, achTab = ola:Page("Parken").tab, ola:Page("Prestasjoner").tab
        ok(park:IsShown())
        eq(park.points[1][2], achTab, "right under the achievements tab")
        eq(park.points[1][5], -2)
        eq(ola:TipOf(park)[1], "Parken")
        park:Click()
        ok(P:IsOpen())
        eq(env.CollectionsJournal.titleFS.text, "Parken")
        ok(park.selected:IsShown())
        -- Over to the achievements: the park closes.
        achTab:Click()
        ok(A:IsOpen()); no(P:IsOpen())
        no(park.selected:IsShown())
        eq(env.CollectionsJournal.titleFS.text, "Prestasjoner")
        park:Click()
        no(A:IsOpen()); ok(P:IsOpen())
        eq(env.CollectionsJournal.titleFS.text, "Parken")
        -- Blizzard's tab: back to Pets, everything put back.
        ola:ClickTab(2)
        no(P:IsOpen())
        eq(env.CollectionsJournal.titleFS.text, "Pet Journal")
        eq(env.CollectionsJournal.NineSlice.level, 3)
    end)

    test("without side tabs, two buttons left of Auto-summon", function()
        local w, ola = Setup()
        ola:OpenJournal({ sideTabs = 0 })
        local P = ola.ns.ParkPage
        local b, achButton = ola:Page("Parken").button, ola:Page("Prestasjoner").button
        ok(b:IsShown(), "the button reads Parken"); ok(achButton:IsShown())
        eq(b.points[1][2], achButton, "left of the achievements button")
        b:Click()
        ok(P:IsOpen())
    end)

    test("the map: homes in color, free ones grey, yours glows, ones you could adopt ticked", function()
        local w, ola, kari, per = Setup()
        ola:Slash("adopter panda")
        kari:Slash("adopter")
        w:Run(5)
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken"):Open()
        eq(page.frame.summary.text, "2/7")
        eq(#Cells(ola), 7, "every journal companion")
        local panda, kitty, tabby, rabbit = Cell(ola, 5159), Cell(ola, 41), Cell(ola, 42), Cell(ola, 72)
        no(panda.icon.desaturated); ok(panda.mine:IsShown(), "yours")
        no(kitty.icon.desaturated); no(kitty.mine:IsShown())
        ok(tabby.icon.desaturated, "free: grey"); eq(tabby.icon.alpha, 0.55)
        no(tabby.free:IsShown(), "Ola doesn't own it")
        ok(rabbit.free:IsShown(), "free, and Ola owns it: he could adopt it")
        -- Sorted by name; laid out in rows.
        eq(SpeciesOf(Cells(ola)[1]), 42, "Black Tabby Cat first")
        match(Tip(ola, kitty), "^Cornish Rex Cat / Flyttet inn hos Kari Berg i dag / Bånd: Bekjent %(level 1%) / %S+ og %S+ · liker [^/]* / Klikk for å se kortet%.$", "the traits by name; no effect paragraphs")
        match(Tip(ola, rabbit), "Trenger et hjem / .* / Du har dette dyret, og kan adoptere det%.")
        match(Tip(ola, panda), "Flyttet inn hos deg i dag")
        no(Tip(ola, panda):find("Du har", 1, true), "no \"you have it too\" on your own")
        -- Per adopts the tabby while the page is open: it lights up.
        per:Slash("adopter")
        w:Run(5)
        no(Cell(ola, 42).icon.desaturated)
        eq(page.frame.summary.text, "3/7")
        -- Nicknames lead the tooltip.
        w:SkipDays(7)
        w:Befriend()
        kari:Slash("navn Mjau")
        w:Run(5)
        match(Tip(ola, Cell(ola, 41)), "^Mjau / Cornish Rex Cat / Har bodd hos Kari Berg i 7 dager / Bånd: Venn %(level 3%) / Navngitt av Kari Berg, ")
        ola:Slash("navn Pepe")
        w:Run(5)
        match(Tip(ola, Cell(ola, 5159)), "Navngitt av deg")
        match(Tip(ola, Cell(ola, 40)), "Du har dette dyret, og kan adoptere det")
        kari:GivePet(40)
        kari:OpenJournal({ sideTabs = 4 })
        kari:Page("Parken"):Open()
        match(Tip(kari, Cell(kari, 5159)), "^Pepe / Panda Cub / Har bodd hos Ola Nord")
        no(Tip(kari, Cell(kari, 5159)):find("Du har", 1, true))
    end)

    test("records: longest friendship, most popular family, newest arrival", function()
        local w, ola, kari, per = Setup()
        local P = ola.ns.ParkPage
        eq(P:Records()[1], "Ingen har adoptert et dyr ennå. Bli den første!")
        kari:Slash("adopter")
        w:Run(5)
        local one = P:Records()
        eq(#one, 2, "one pet: no separate newest line")
        match(one[1], "Lengste vennskap")
        match(one[2], "Mest populære familie")
        kari:Slash("gislipp")
        w:Run(5)
        kari:Slash("adopter")
        w:SkipDays(10)
        per:Slash("adopter")
        w:SkipDays(2)
        ola:Slash("adopter rabbit")
        w:Run(5)
        local lines = P:Records()
        eq(#lines, 3)
        eq(lines[1]:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""),
            "Lengste vennskap: Cornish Rex Cat hos Kari Berg, i 12 dager")
        match(lines[2], "Mest populære familie:|r katter %(2 har et hjem%)")
        match(lines[3], "Nyeste beboer:|r .*, flyttet inn hos Ola Nord i dag$")
        -- A nickname is used; ties in family counts go by name.
        w:SkipDays(7)
        w:Befriend()
        kari:Slash("navn Mjau")
        w:Run(5)
        match(P:Records()[1], "Mjau hos Kari Berg")
        ola.ns.Registry:MergeRecord("Liv Lund", { k = "s:84", at = w:ServerTime(), ts = w:ServerTime() })
        ola.ns.Registry:Changed()
        match(P:Records()[2], "katter %(2")
        -- Shown on the page.
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken"):Open()
        ok(page:Text("Lengste vennskap"))
        ok(page:Text("Du kan adoptere det"))
    end)

    test("no companion data: an empty map, no errors", function()
        local w, ola = Setup()
        ola.ns.Companions = nil
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken"):Open()
        eq(page.frame.summary.text, "0/0")
        eq(#Cells(ola), 0)
    end)

    test("most popular family: only our families count; a tie goes by name", function()
        local w, ola = Setup()
        local species = ola.ns.Companions.species
        for sid = 2001, 2003 do species[sid] = { a = true, t = { "ukjent" } } end
        local R, now = ola.ns.Registry, w:ServerTime()
        local function Adopt(owner, sid) R:MergeRecord(owner, { k = "s:" .. sid, at = now, ts = now }) end
        Adopt("Liv Lund", 84)     -- farm, bird
        Adopt("Siv Dahl", 72)     -- rabbit
        Adopt("Tor Eng", 2001); Adopt("Anne Aas", 2002); Adopt("Bo Berg", 2003)
        for _, n in ipairs({ "Liv Lund", "Siv Dahl", "Tor Eng", "Anne Aas", "Bo Berg" }) do w:AddMember(n) end
        R:Changed()
        match(ola.ns.ParkPage:Records()[2], "Mest populære familie:|r fugler %(1 har et hjem%)")
    end)

    test("a click on an icon opens that pet's card on the Pets page, also one you don't own", function()
        local w, ola, kari = Setup()
        kari:Slash("adopter cornish")
        w:Run(10)
        ola:OpenJournal({ sideTabs = 4 })
        local P, park = ola.ns.ParkPage, ola:Page("Parken")
        park.tab:Click()
        ok(P:IsOpen())
        local cell = Cell(ola, 41)
        match(Tip(ola, cell), "Klikk for å se kortet%.")
        cell:Click()
        no(P:IsOpen(), "back on the Pets page")
        eq(ola.selectedSpecies, nil, "not in the list: Forever's selection does nothing")
        eq(ola.shownSpecies, 41, "so the species' card")
        eq(#ola:Log("PetJournal_ShowPetCardBySpeciesID%(41%): ok, card species 41"), 1)
        local card = ola:Card()
        eq(card.species, "Cornish Rex Cat")
        match(card.status.text, "Kari Berg")
        -- From another page (Mounts here) we can't switch tabs ourselves: a hint, and nothing happens.
        ola:ClickTab(1)
        park.tab:Click()
        ok(P:IsOpen())
        match(Tip(ola, Cell(ola, 72)), "Åpne Pets%-fanen")
        Cell(ola, 72):Click()
        ok(P:IsOpen()); eq(ola.shownSpecies, 41)
    end)

    -- In combat the card can't show (2026-11-13, the user): the click is remembered, with a hint, and the
    -- card shows once the fight is over if the Pets page is still up (JournalUI:AfterCombat).
    test("a click in combat: a hint, and the card once the fight is over; with the window closed by then, the next time", function()
        local w, ola = Setup()
        ola.ns.Config.CLICK_HINTS = true -- (muted by default since 2026-11-13)
        ola:OpenJournal({ sideTabs = 4 })
        local P, park = ola.ns.ParkPage, ola:Page("Parken")
        park.tab:Click()
        ola:EnterCombat()
        for _ = 1, 3 do Cell(ola, 72):Click() end
        ok(P:IsOpen(), "still in the park")
        eq(ola.selectedSpecies, nil, "no card in combat")
        eq(ola:CountPrinted("Kortet til " .. ola.ns.Pets:NameOfKey("s:72") .. " kommer når kampen er over."), 1,
            "a hint, once a burst")
        ola:LeaveCombat(); w:Run(0.1)
        no(P:IsOpen(), "back on the Pets page ...")
        eq(ola.selectedSpecies, 72, "... on its card")
        -- The window closed before the fight ends: the card when the player opens the Pets page.
        park.tab:Click()
        ola:EnterCombat()
        Cell(ola, 40):Click()
        ola:CloseJournal()
        ola:LeaveCombat(); w:Run(0.1)
        eq(ola.selectedSpecies, 72, "closed: not yet")
        ola:OpenJournal(); w:Run(0.1)
        eq(ola.selectedSpecies, 40, "opened: the card")
    end)
end
