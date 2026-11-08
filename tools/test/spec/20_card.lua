-- The pet card: the bottom panel (name, home, bond, guild footer) and the
-- background scene by family (Menagerie/Scenes.lua, /dp probe bg).
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Fixture()
        return { build = 1, species = {
            [40] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat", "bird" } },
            [68] = { a = true, t = { "owl", "bird" } }, [5159] = { a = false },
            [84] = { a = true, t = { "bird", "dragon" } },
        } }
    end

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        ola.ns.Companions = Fixture()
        w:Run(20)
        ola:OpenJournal()
        return w, ola
    end

    test("the panel: big name, small home, the bond on the right, the guild below", function()
        local w, ola = Setup()
        local card = ola:SelectPet(68)
        eq(card.nickname.text, "Great Horned Owl", "not named: the species, big")
        eq(card.status.plain, "Trenger et hjem")
        no(card.bond:IsShown())
        ola:Slash("adopter panda")
        w:SkipDays(45)
        ola:Reload(); ola.ns.Companions = Fixture()
        w:Run(25)
        ola:Slash("navn Pepe")
        ola:OpenJournal()
        card = ola:SelectPet(5159)
        eq(card.nickname.text, "Pepe")
        eq(card.status.plain, "Panda Cub · Bor hos deg i 45 dager")
        ok(card.bond:IsShown())
        eq(card.bond.level.text, 3, "the level in the badge")
        eq(card.bond.label.text, "Bånd: Venn (nivå 3)")
        eq(card.bond.text.text, "450 / 1000")
        -- Everything sits on the panel, which stays under the model's buttons.
        local panel = card.panel
        eq(panel.level, ola.env.PetJournalPetCard:GetFrameLevel(), "below the model and its rotate buttons")
        eq(card.counter.points[1][2], panel); eq(card.today.points[1][2], panel)
        eq(card.nickname.points[1][2], panel)
        match(card.counter.text, "^Guilden: 1 av 5 har et hjem")
        match(card.today.text, "^Dagens dyr: Pepe %(Ola Nord%)$")
        -- No pet selected: everything clears.
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        eq(card.nickname.text, ""); no(card.scene:IsShown()); no(card.bond:IsShown())
    end)

    test("scenes: by family, the first one the client has, else the default", function()
        local w, ola = Setup()
        local S = ola.ns.Scenes
        local BY = S.BY_FAMILY
        eq(S:For("s:40"), BY.cat[1])
        eq(S:For("s:84"), BY.dragon[1], "dragon before bird")
        eq(S:For("s:68"), BY.owl[1], "owl before bird")
        eq(S:For("s:5159"), BY.default[1], "no family: the default")
        eq(S:For("s:999"), BY.default[1], "not in the data")
        local card = ola:SelectPet(40)
        ok(card.scene:IsShown()); eq(card.scene.tex, BY.cat[1])
        -- A client without the first cat scene uses the next; with none at all, Blizzard's stays.
        local w2 = H.World()
        local kari = w2:AddClient("Kari Berg", { pets = { 40 } })
        kari.ns.Companions = Fixture()
        local missing = { [BY.cat[1]] = true }
        for _, p in ipairs(BY.default) do missing[p] = true end
        kari.missingFiles = missing
        w2:Run(20)
        eq(kari.ns.Scenes:For("s:40"), BY.cat[2])
        eq(kari.ns.Scenes:For("s:5159"), nil)
        kari:OpenJournal()
        no(kari:SelectPet(5159).scene:IsShown())
        kari.ns.Companions.species[46] = true -- the stub's shape: no table, no tags
        eq(kari.ns.Scenes:For("s:46"), nil)
    end)

    test("/dp probe bg lists what exists and previews one on the card", function()
        local w, ola = Setup()
        local list = ola.ns.Scenes:Candidates()
        ola.missingFiles = { [list[2].path] = true }
        ola:Slash("probe bg")
        ok(ola:Printed(("bg 1 YES default: %s"):format(list[1].path), true))
        no(ola:Printed(("bg 2 "), true), "only the ones that exist are printed")
        ok(ola:Printed(("%d av %d bakgrunner finnes."):format(#list - 1, #list), true))
        eq(#ola:Log("bg 2 no "), 1, "all of them are logged")
        ola:Slash("probe bg 5")
        eq(ola:SelectPet(68).scene.tex, list[5].path, "previewed on any pet")
        ok(ola:Printed("/dp probe bg off", true))
        ola:Slash("probe bg 999")
        ok(ola:Printed("Ingen bakgrunn nr. 999", true))
        ola:Slash("probe bg off")
        eq(ola:SelectPet(68).scene.tex, ola.ns.Scenes.BY_FAMILY.owl[1])
        local seen = {}
        for _, c in ipairs(list) do no(seen[c.path], "listed once"); seen[c.path] = true end
    end)
end
