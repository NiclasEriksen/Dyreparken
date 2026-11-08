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

    -- Test lists, so the tests check the rules, not today's picks.
    local function Lists()
        return { cat = { "Interface\\T\\Cat1", "Interface\\T\\Cat2" }, dragon = { "Interface\\T\\Dragon" },
            owl = { "Interface\\T\\Owl" }, bird = { "Interface\\T\\Bird", "Interface\\T\\Cat1" },
            default = { "Interface\\T\\Default" } }
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
        eq(card.nickname.points[1][2], panel)
        -- The guild's numbers: boxes on the "Total Pets" row, right of it.
        local PJ = ola.env.PetJournal
        eq(card.guildBox.points[1][2], PJ.PetCount, "next to Total Pets")
        eq(card.todayBox.points[1][2], card.guildBox)
        eq(card.guildBox.label.text, "Guilden"); eq(card.counter.text, "1 av 5 (20%)")
        eq(card.todayBox.label.text, "Dagens dyr"); eq(card.today.text, "Pepe")
        card.todayBox.scripts.OnEnter(card.todayBox)
        eq(ola.env.GameTooltip.lines[1], "Dagens dyr: Pepe, som bor hos Ola Nord.")
        card.todayBox.scripts.OnLeave(card.todayBox)
        card.guildBox.scripts.OnEnter(card.guildBox)
        eq(ola.env.GameTooltip.lines[1], "Guilden: 1 av 5 kjæledyr har et hjem (20%).")
        -- Laid out: "Dagens dyr" ends at the card's right edge, never past it.
        ola.env.PetJournalPetCard.geo = { l = 300, r = 700, t = 500, b = 0 }
        card.guildBox.geo = { l = 400, r = 540, t = 530, b = 510 }
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard)
        eq(card.todayBox.size[1], 154)
        card.guildBox.geo = { l = 560, r = 690, t = 530, b = 510 }
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard)
        eq(card.todayBox.size[1], 80, "a cramped row still leaves room for the label")
        -- No pet selected: everything clears.
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        eq(card.nickname.text, ""); no(card.scene:IsShown()); no(card.bond:IsShown())
    end)

    test("scenes: by family, the first one the client has, else the default", function()
        local w, ola = Setup()
        local S = ola.ns.Scenes
        S.BY_FAMILY = Lists()
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
        kari.ns.Scenes.BY_FAMILY = Lists()
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

    test("/dp probe bg opens a gallery of what exists; picks become the family's background", function()
        local w, ola = Setup()
        ola.ns.Scenes.BY_FAMILY = Lists()
        local list = ola.ns.Scenes:Candidates()
        ola.missingFiles = { [list[2].path] = true }
        ola:Slash("probe bg")
        ok(ola:Printed(("%d av %d bakgrunner finnes; galleriet viser dem."):format(#list - 1, #list), true))
        eq(#ola:Log("bg 2 no "), 1, "all of them are logged")
        eq(#ola:Log("bg 1 YES default: "), 1)
        local G = ola.ns.SceneGallery
        ok(G._frame:IsShown())
        local shown = {}
        for _, t in ipairs(G._thumbs) do if t:IsShown() then shown[#shown + 1] = t end end
        eq(#shown, #list - 1, "a thumbnail for each one that exists")
        eq(shown[1].image.tex, list[1].path)
        match(shown[2].label.text, "^3 ", "numbered as in the list")
        -- Pick for owls: choose the family, click the picture.
        local owlButton
        for _, b in ipairs(G._frame.families) do if b.family == "owl" then owlButton = b end end
        owlButton:Click()
        ok(owlButton.highlightLocked)
        local pick = shown[3] -- a cat picture, for the owl
        pick.scripts.OnClick(pick, "LeftButton")
        eq(ola.env.DyreparkenDB.scenePicks.owl, pick.path, "saved")
        eq(pick.used.text, "owl"); ok(pick.border:IsShown())
        match(owlButton.text, "%*$")
        eq(ola.ns.Scenes:For("s:68"), pick.path, "the owl uses it now")
        eq(ola:SelectPet(68).scene.tex, pick.path)
        eq(#ola:Log("bg pick owl = "), 1)
        -- Kept after a reload.
        ola:Reload(); ola.ns.Companions = Fixture()
        ola.ns.Scenes.BY_FAMILY = Lists()
        w:Run(20)
        ola:OpenJournal()
        eq(ola.ns.Scenes:For("s:68"), pick.path)
        -- Right-click clears it.
        ola:Slash("probe bg")
        local again = ola.ns.SceneGallery._thumbs[3]
        eq(again.path, pick.path)
        again.scripts.OnClick(again, "RightButton")
        eq(ola.env.DyreparkenDB.scenePicks.owl, nil)
        no(ola.ns.Scenes:For("s:68") == again.path, "back to the built-in choice")
        -- Preview one by number, as before.
        ola:Slash("probe bg 3")
        eq(ola:SelectPet(40).scene.tex, list[3].path)
        ola:Slash("probe bg 999")
        ok(ola:Printed("Ingen bakgrunn nr. 999", true))
        ola:Slash("probe bg off")
        local seen = {}
        for _, c in ipairs(list) do no(seen[c.path], "listed once"); seen[c.path] = true end
    end)

    test("Blizzard's turn buttons move above the panel; without them the text stays clear of the middle", function()
        local w, ola = Setup()
        local card = ola:SelectPet(40)
        local model = ola.env.PetJournalPetCard.modelScene
        eq(model.RotateLeftButton.points[1][2], card.panel)
        eq(model.RotateLeftButton.points[1][3], "TOP")
        eq(model.RotateRightButton.points[1][1], "BOTTOMLEFT")
        -- The model itself ends above the buttons, so the pet stands clear of them.
        local bottom = model.points[#model.points]
        eq(bottom[1], "BOTTOMRIGHT"); eq(bottom[2], card.panel); eq(bottom[5], 34)
        eq(card.model, model)
        local last = card.status.points[#card.status.points]
        eq(last[4], 30, "rows run past the middle, up to the bond column")
        eq(#ola:Log("rotate buttons moved above the panel"), 1)
        local w2 = H.World()
        local kari = w2:AddClient("Kari Berg", { pets = { 40 } })
        w2:Run(20)
        kari:OpenJournal({ noRotate = true })
        card = kari:SelectPet(40)
        last = card.status.points[#card.status.points]
        eq(last[4], -52, "narrow")
        eq(#kari:Log("rotate buttons not found"), 1)
    end)

    test("without a Total Pets box, the guild boxes sit above the card", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 40 } })
        w:Run(20)
        c:OpenJournal({ noPetCount = true })
        local card = c:SelectPet(40)
        eq(card.guildBox.points[1][2], c.env.PetJournalPetCard)
        eq(card.today.text, "-", "nobody adopted: no pet of the day")
        match(card.todayBox.tip, "ingen har adoptert")
    end)

    test("layers: a gradient tinted by family, dark edges, a floor shadow; cleared with no pet", function()
        local w, ola = Setup()
        local S = ola.ns.Scenes
        local card = ola:SelectPet(84) -- bird and dragon: the dragon sets the look
        eq(card.family, "dragon")
        local g = card.tint.gradient
        eq(g[1], "VERTICAL")
        eq(g[3].r, S.TINT.dragon[1], "the family's color at the top")
        ok(g[2].r < g[3].r, "darker toward the panel")
        ok(card.tint:IsShown()); ok(card.floor:IsShown())
        eq(#card.edges, 3)
        for _, e in ipairs(card.edges) do ok(e:IsShown()); ok(e.gradient, e.side) end
        eq(card.edges[2].gradient[2].a, 0.7, "left edge: dark at the edge")
        eq(card.edges[3].gradient[3].a, 0.7, "right edge: dark at the edge")
        eq(ola:SelectPet(5159).family, "default")
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        no(card.tint:IsShown()); no(card.floor:IsShown()); no(card.edges[1]:IsShown())
        -- Without gradients (an older client), a flat tint.
        ola.env.CreateColor = nil
        card = ola:SelectPet(40)
        ok(card.tint:IsShown())
    end)

    test("the probe also looks for every classic dungeon's art", function()
        local w, ola = Setup()
        local list = ola.ns.Scenes:Candidates()
        -- Every name twice (background and lore), each listed once even if a family uses it.
        ok(#list >= 66, #list .. " candidates")
        ola:Slash("probe bg")
        eq(#ola:Log("bg %d+ YES probe: Interface\\EncounterJournal\\UI%-EJ%-LOREBG%-Naxxramas"), 1)
    end)

    test("hovering the personality and the bond explains them", function()
        local w, ola = Setup()
        ola:Slash("adopter panda")
        w:Run(40)
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        local tip = ola.env.GameTooltip
        local hit = card.personalityHit
        hit.scripts.OnEnter(hit)
        local text = table.concat(tip.lines, " / ")
        local traits = ola.ns.Personality:Traits("s:5159")
        eq(#traits, 2)
        match(text, "^" .. traits[1].name .. " / ")
        for _, q in ipairs(traits) do
            ok(text:find(q.name .. " / " .. q.desc, 1, true), "what each trait means")
            ok(text:find(ola.ns.Personality:Effect(q), 1, true), "and what it does")
        end
        match(text, "Liker: herbs")
        match(text, "vokser båndet raskere%.$")
        hit.scripts.OnLeave(hit)
        card.bond.scripts.OnEnter(card.bond)
        text = table.concat(tip.lines, " / ")
        match(text, "^Bånd: Bekjent %(nivå 1%) / %d+ poeng til Kamerat%. / Vokser for hver dag")
        card.bond.scripts.OnLeave(card.bond)
        -- At the top level.
        local now = w:ServerTime()
        ola.ns.Registry:MergeLife("s:5159", "Ola Nord", { p = 9000, f = now - 200 * 86400, t = now })
        card = ola:SelectPet(5159)
        card.bond.scripts.OnEnter(card.bond)
        match(table.concat(tip.lines, " / "), "Det høyeste nivået%.")
        -- A free pet: nothing to explain on the bond; the personality still tells.
        card = ola:SelectPet(40)
        tip:ClearLines()
        card.bond.scripts.OnEnter(card.bond)
        eq(#tip.lines, 0)
        card.personalityHit.scripts.OnEnter(card.personalityHit)
        ok(#tip.lines >= 2)
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        tip:ClearLines()
        card.personalityHit.scripts.OnEnter(card.personalityHit)
        eq(#tip.lines, 0, "no pet: no tooltip")
    end)
end
