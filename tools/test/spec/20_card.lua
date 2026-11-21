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
        return H.Setup{ ola = { 5159, 40 }, each = function(c)
            c:Companions(Fixture().species)
            c.ns.Decor.FAMILY_ART = {} -- the rules, not today's picks
        end, settle = "bond", journal = true }
    end

    test("the panel: big name, small home, the bond on the right, the guild below", function()
        local w, ola = Setup()
        w.bondsShipped = 2e9 -- (adopted before bonds shipped: seeded at login)
        local card = ola:SelectPet(68)
        eq(card.nickname.text, "Great Horned Owl", "not named: the species, big")
        eq(card.status.plain, "Trenger et hjem")
        eq(ola:TipOf(card.nameHit).text, "Great Horned Owl / |cff80cc80Trenger et hjem|r", "no nickname: the species once")
        no(card.bond:IsShown())
        ola:Slash("adopter panda")
        w:SkipDays(30)
        ola:Reload()
        w:Run(25)
        ola:Slash("navn Pepe")
        ola:OpenJournal()
        card = ola:SelectPet(5159)
        eq(card.nickname.text, "Pepe")
        eq(card.status.plain, "Panda Cub · Hos deg i 30 dager", "short on the card (2026-11-19, the user)")
        -- Hover the name or the home line: everything in full, even if cut short on the card.
        eq(ola:TipOf(card.nameHit).text, "Pepe / Panda Cub / |cffffd100Har bodd hos deg i 30 dager|r")
        ok(card.bond:IsShown())
        eq(card.bond.level.text, 3, "the level in the badge")
        eq(card.bond.label.text, "Venn", "the name; the number is on the medallion")
        eq(card.bond.text.text, "300 / 530")
        -- Everything sits on the panel, which stays under the model's buttons.
        local panel = card.panel
        eq(panel.level, ola.env.PetJournalPetCard:GetFrameLevel(), "below the model and its rotate buttons")
        eq(card.nickname.points[1][2], panel)
        -- The guild's numbers: boxes on the "Total Pets" row, right of it.
        local PJ = ola.env.PetJournal
        eq(card.guildBox.points[1][2], PJ.PetCount, "next to Total Pets")
        eq(card.todayBox.points[1][2], card.guildBox)
        eq(card.guildBox.label.text, "Guilden"); eq(card.counter.text, "1 av 5 (20%)")
        -- "Dagens dyr": a gold star instead of the label (the name was cut short), the name right after it.
        eq(card.todayBox.label.text, nil); eq(card.today.text, "Pepe")
        match(card.todayBox.icon.tex, "Particles\\star$"); eq(card.today.points[2][2], card.todayBox.icon)
        eq(ola:TipOf(card.todayBox)[1], "Dagens dyr: Pepe, som bor hos Ola Nord.\n|cffa0a0a0Klikk for å se det.|r")
        eq(ola:TipOf(card.guildBox)[1], "Guilden: 1 av 5 dyr har et hjem (20%).")
        -- Laid out: "Dagens dyr" ends at the card's right edge, never past it.
        ola.env.PetJournalPetCard.geo = { l = 300, r = 700, t = 500, b = 0 }
        card.guildBox.geo = { l = 400, r = 540, t = 530, b = 510 }
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard)
        eq(card.todayBox.size[1], 154)
        card.guildBox.geo = { l = 560, r = 690, t = 530, b = 510 }
        ola.env.PetJournal_UpdatePetCard(ola.env.PetJournalPetCard)
        eq(card.todayBox.size[1], 80, "a cramped row still leaves room for the name")
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
        eq(S:For("s:5159"), "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-ZulGurub", "the panda has its own")
        S.BY_SPECIES = { [5159] = { "Interface\\T\\Gone" } }
        ola.missingFiles = { ["Interface\\T\\Gone"] = true }
        eq(S:For("s:5159"), BY.default[1], "its own missing, and no family: the default")
        -- Tags that belong to a family.
        ola.ns.Companions.species[341] = { a = true, t = { "event", "lantern" } }
        ola.ns.Companions.species[83] = { a = true, t = { "chicken", "mechanical" } }
        eq(S:Families("s:341")[1], "festive")
        eq(S:Families("s:83")[1], "mechanical"); eq(S:Families("s:83")[2], "farm")
        ok(ola.ns.Personality:Of("s:341").quest, "festive pets like quests")
        eq(S:For("s:999"), BY.default[1], "not in the data")
        local card = ola:SelectPet(40)
        ok(card.scene:IsShown()); eq(card.scene.tex, BY.cat[1])
        eq(table.concat(card.scene.texCoord, ","), "0,1,0,1", "a whole picture")
        -- A dungeon background: only the part of the file with the art.
        S.BY_SPECIES = { [5159] = { "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-ZulGurub" } }
        card = ola:SelectPet(5159)
        eq(card.scene.tex, "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-ZulGurub")
        local half = 0.830078125 * 394 / 425 / 2 -- (art 394 x 425 on a square card: a little off the top and bottom)
        eq(table.concat(card.scene.texCoord, ","), table.concat({ 0, 0.76953125, 0.4150390625 - half, 0.4150390625 + half }, ","))
        -- A client without the first cat scene uses the next; with none at all, Blizzard's stays.
        local w2 = H.World()
        local kari = w2:AddClient("Kari Berg", { pets = { 40 } })
        kari:Companions(Fixture().species)
        kari.ns.Scenes.BY_FAMILY, kari.ns.Scenes.BY_SPECIES = Lists(), {}
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

    test("the light follows the clock: morning, day, evening, dusk and night", function()
        local w, ola = Setup()
        local function At(h)
            w:SetHour(h, 30)
            local card = ola:SelectPet(40)
            return card.skyName, card.sky:IsShown(), card.sky.gradient
        end
        local S = ola.ns.Scenes
        eq(S:Sky(0)[2], "natt"); eq(S:Sky(4)[2], "natt"); eq(S:Sky(5)[2], "morgen"); eq(S:Sky(12)[2], "dag")
        eq(S:Sky(17)[2], "kveld"); eq(S:Sky(20)[2], "skumring"); eq(S:Sky(22)[2], "natt"); eq(S:Sky(23)[2], "natt")
        local name, shown = At(12)
        eq(name, "dag"); no(shown, "the day is the scene as it is")
        name, shown = At(23)
        eq(name, "natt"); ok(shown)
        name, shown = At(18)
        eq(name, "kveld"); ok(shown)
        -- No pet: no sky.
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        no(ola:Card().sky:IsShown())
    end)

    test("/dp probe decor: decoration art that exists, one slot at a time, picked per slot", function()
        local w, ola = Setup()
        local D = ola.ns.Decor
        local list = D:Candidates()
        local slots = {}
        for _, c in ipairs(list) do slots[c.slot] = (slots[c.slot] or 0) + 1 end
        for _, slot in ipairs(D.SLOTS) do ok(slot == "paw" or slots[slot], slot .. " has candidates") end
        ok(#list > 300, "the generated atlas lists are in")
        -- The client has the file paths and two atlases.
        ola.atlases = { ["bags-glow-orange"] = true, ["AftLevelup-WhiteStarBurst"] = true }
        ola:Slash("probe decor")
        local files = 0
        for _, c in ipairs(list) do if not c.path:find("^atlas:") then files = files + 1 end end
        ok(ola:Printed(("%d of %d decoration pictures exist; the gallery shows them."):format(files + 2, #list), true))
        eq(#ola:Log("decor %d+ no glow: atlas:"), slots.glow - 1 - 6 - 1, "every glow but the one, the files, our own")
        -- Our own particles: always there, first in their slots, and shipped.
        local own = 0
        for _, c in ipairs(list) do
            if c.path:find(D.MEDIA, 1, true) == 1 then
                own = own + 1
                ok(D.Exists(c.path), c.path)
                local file = io.open(c.path:gsub("^Interface\\AddOns\\Dyreparken\\", ""):gsub("\\", "/") .. ".tga", "rb")
                ok(file, c.path .. ".tga is in Media/")
                if file then file:close() end
            end
        end
        eq(own, 11, "eleven drawn (the dot is listed once)")
        local G = ola.ns.SceneGallery
        local function Shown()
            local shown = {}
            for _, t in ipairs(G._thumbs) do if t:IsShown() then shown[#shown + 1] = t end end
            return shown
        end
        -- The first slot: corners (files only).
        for _, t in ipairs(Shown()) do ok(not t.path:find("^atlas:"), t.path) end
        match(G._frame.hint.text, "^Slot: corner %(2 pictures%)")
        -- The glow slot: its files and the one atlas.
        local glowButton
        for _, b in ipairs(G._frame.families) do if b.family == "glow" then glowButton = b end end
        glowButton:Click()
        local glow
        for _, t in ipairs(Shown()) do if t.path == "atlas:bags-glow-orange" then glow = t end end
        ok(glow, "the glow atlas is shown in its slot")
        eq(glow.image.atlas, "bags-glow-orange", "an atlas is shown as one")
        eq(glow.image.size[1], 64 * 1.5, "at its own proportions (64x64, scaled up at most 1.5x)")
        for _, t in ipairs(Shown()) do ok(t.path ~= "atlas:AftLevelup-WhiteStarBurst", "a star isn't a glow") end
        glow.scripts.OnClick(glow, "LeftButton")
        eq(ola.env.DyreparkenDB.decorPicks.glow, "atlas:bags-glow-orange")
        eq(#ola:Log("decor pick glow = atlas:bags%-glow%-orange"), 1)
        eq(ola.env.DyreparkenDB.scenePicks.glow, nil, "the background picks are their own")
        -- A pick stays a candidate in its slot, even if no list has it any more.
        ola.env.DyreparkenDB.decorPicks.heart = "atlas:somewhere-else"
        local found
        for _, c in ipairs(D:Candidates()) do if c.path == "atlas:somewhere-else" then found = c.slot end end
        eq(found, "heart")
        glow.scripts.OnClick(glow, "RightButton")
        eq(ola.env.DyreparkenDB.decorPicks.glow, nil)
        -- Without C_Texture, no atlas exists.
        ola.env.C_Texture = nil
        no(D.Exists("atlas:bags-glow-orange"))
    end)

    test("the families' frames in the code are families and slots there are, and pictures the client has", function()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "hello" }
        local D, S = ola.ns.Decor, ola.ns.Scenes
        local known = { default = true }
        for _, f in ipairs(S.ORDER) do known[f] = true end
        local atlases = {}
        for _, c in ipairs(D:Candidates()) do atlases[c.path] = c.slot end
        for family, art in pairs(D.FAMILY_ART) do
            ok(known[family], family .. " is a family")
            for slot, path in pairs(art) do
                ok(slot == "border" or slot == "corner", family .. ": " .. slot)
                local key = path:find("\\", 1, true) and path or "atlas:" .. path
                eq(atlases[key], slot, family .. "." .. slot .. " is a " .. slot .. " candidate: " .. path)
            end
        end
    end)

    test("/dp probe frames: a border per family, worn by the card while it's chosen; picks only while open", function()
        local w, ola = Setup()
        local D, G = ola.ns.Decor, ola.ns.SceneGallery
        ola.atlases = { ["UI-Frame-Metal-CornerTopLeft"] = true, ["DarkWoodFrameCorner"] = true,
            ["services-icon-goldborder"] = true, ["loottoast-itemborder-gold"] = true }
        ola:Slash("probe level 3")
        local card = ola:SelectPet(40) -- a cat
        local d = card.decor
        eq(d.border.atlas, "loottoast-itemborder-gold", "no family border: the shared one")
        ola:Slash("probe frames")
        ok(ola:Printed("borders exist", true))
        match(G._frame.hint.text, "^Slot: border%.default")
        eq(D.show.family, "default", "the card wears the chosen family")
        for _, b in ipairs(G._frame.families) do match(b.family, "^border%.", "borders only") end
        local function Shown()
            local shown = {}
            for _, t in ipairs(G._thumbs) do if t:IsShown() then shown[#shown + 1] = t end end
            return shown
        end
        local function Pick(slot)
            for _, b in ipairs(G._frame.families) do if b.family == slot then b:Click() end end
        end
        Pick("border.cat")
        eq(D.show.family, "cat")
        local gold
        for _, t in ipairs(Shown()) do
            if t.path == "atlas:services-icon-goldborder" then gold = t end
            ok(t.path ~= "atlas:UI-Frame-Metal-CornerTopLeft", "a corner isn't a border")
        end
        ok(gold, "the borders there are")
        gold.scripts.OnClick(gold, "LeftButton")
        eq(ola.env.DyreparkenDB.decorPicks["border.cat"], "atlas:services-icon-goldborder")
        eq(d.border.atlas, "services-icon-goldborder", "on the card at once")
        Pick("border.dragon")
        eq(d.border.atlas, "loottoast-itemborder-gold", "the dragon's: none")
        -- Closed: the code decides again; a pick left in SavedVariables doesn't.
        G._frame:Hide()
        eq(D.show, nil)
        card = ola:SelectPet(40)
        eq(d.border.atlas, "loottoast-itemborder-gold", "the pick counts only in the gallery")
        D.FAMILY_ART.cat = { border = "Interface\\Some\\Border" }
        card = ola:SelectPet(40)
        eq(d.border.tex, "Interface\\Some\\Border", "the picks written into the code; a file path works too")
        eq(table.concat(d.border.slice, ","), "18,18,18,18")
        eq(table.concat(d.corners.TOPLEFT.texCoord, ","), "0,1,0,1")
    end)

    test("corners: wood from level 3 for every pet, the filigree once the card is gold", function()
        local w, ola = Setup()
        local D = ola.ns.Decor
        ola.atlases = { ["parchmentpopup-filigree"] = true }
        local wood = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder-Corner"
        for _, key in ipairs({ "s:40", "s:5159" }) do
            local card = ola:SelectPet(tonumber(key:sub(3)))
            local d = card.decor
            D:Apply(card, key, 3)
            eq(d.corners.TOPLEFT.tex, wood, key .. ": wood")
            eq(table.concat(d.corners.BOTTOMRIGHT.texCoord, ","), "1,0,1,0", "a file, mirrored by its coordinates")
            D:Apply(card, key, 5)
            eq(d.corners.TOPLEFT.atlas, "parchmentpopup-filigree", key .. ": filigree at gold")
        end
    end)

    test("the decorations' galleries preview on the card: the slot at its level, the picture under the mouse", function()
        local w, ola = Setup()
        local D, G = ola.ns.Decor, ola.ns.SceneGallery
        ola.atlases = { ["UI-Frame-Metal-CornerTopLeft"] = true, ["AdventuresFrame-Corner-Small-TopLeft"] = true,
            ["loottoast-itemborder-gold"] = true, ["UI-Frame-Neutral-Ribbon"] = true, ["Bonus-Objective-Star"] = true }
        local card = ola:SelectPet(5159) -- nobody's: no bond decorations
        local d = card.decor
        no(d.corners.TOPLEFT:IsShown())
        ola:Slash("probe decor")
        eq(D.show.slot, "corner")
        ok(d.corners.TOPLEFT:IsShown(), "dressed at a level where corners show")
        match(G._frame.hint.text, "Hover to see it on the pet card")
        local function Thumb(path)
            for _, t in ipairs(G._thumbs) do if t:IsShown() and t.path == path then return t end end
        end
        local function Pick(slot)
            for _, b in ipairs(G._frame.families) do if b.family == slot then b:Click() end end
        end
        Pick("corner")
        local metal = Thumb("atlas:UI-Frame-Metal-CornerTopLeft")
        metal.scripts.OnEnter(metal)
        eq(d.corners.TOPLEFT.atlas, "UI-Frame-Metal-CornerTopLeft", "the one under the mouse")
        eq(ola.env.GameTooltip.lines[1], "atlas:UI-Frame-Metal-CornerTopLeft", "and its tooltip still")
        metal.scripts.OnLeave(metal)
        eq(d.corners.TOPLEFT.tex, D.ART.corner, "back to the pick (none: the code's)")
        Pick("cornerGold")
        eq(D.show.slot, "cornerGold")
        local gold = Thumb("atlas:UI-Frame-Metal-CornerTopLeft")
        ok(gold, "the corners again, for the gold level")
        gold.scripts.OnEnter(gold)
        eq(d.corners.TOPLEFT.atlas, "UI-Frame-Metal-CornerTopLeft", "dressed gold, wearing it")
        gold.scripts.OnLeave(gold)
        -- A particle slot: a few of its particles, in the picture under the mouse.
        Pick("star")
        local stars = 0
        for _, p in ipairs(d.parts) do
            if p:IsShown() and p.icon.tex == D.MEDIA .. "star" then stars = stars + 1 end
        end
        eq(stars, 6)
        local atlas = Thumb("atlas:Bonus-Objective-Star")
        atlas.scripts.OnEnter(atlas)
        eq(d.parts[1].icon.atlas, "Bonus-Objective-Star")
        atlas.scripts.OnClick(atlas, "LeftButton")
        atlas.scripts.OnLeave(atlas)
        eq(d.parts[1].icon.atlas, "Bonus-Objective-Star", "picked: it stays")
        Pick("frame")
        match(G._frame.hint.text, "Not used on the card")
        -- Closed: the card is the pet's again (the pick stays).
        G._frame:Hide()
        eq(D.show, nil)
        no(d.corners.TOPLEFT:IsShown())
        ola.env.DyreparkenDB.decorPicks.star = nil
    end)

    test("a background is a path, a file id or an atlas, cut to fill the card at its own shape", function()
        local w, ola = Setup()
        local S = ola.ns.Scenes
        -- Cover: the middle of the art, never stretched.
        local function Near(got, want, what)
            for i = 1, 4 do ok(math.abs(got[i] - want[i]) < 1e-6, ("%s %d: %s, not %s"):format(what, i, got[i], want[i])) end
        end
        Near({ S.Cover(0, 1, 0, 1, 200, 100, 100, 100) }, { 0.25, 0.75, 0, 1 }, "wide art, square card: the sides go")
        Near({ S.Cover(0, 1, 0, 1, 100, 200, 100, 100) }, { 0, 1, 0.25, 0.75 }, "tall art: top and bottom")
        Near({ S.Cover(0.2, 0.6, 0.1, 0.5, 400, 100, 200, 100) }, { 0.3, 0.5, 0.1, 0.5 }, "within the art's part")
        Near({ S.Cover(0, 1, 0, 1, nil, nil, 100, 100) }, { 0, 1, 0, 1 }, "no size: as it is")
        -- A file id: its row in Scenes.ART; an atlas: the client's part of its file.
        S.ART[7963741] = { 0, 1, 0.16, 0.84, 2992, 1152 }
        local file, l, r, t, b, aw, ah = S:Art(7963741)
        eq(file, 7963741); eq(t, 0.16); eq(aw, 2992)
        eq(S:Art("atlas:hunter-stable-bg-art_cunning"), nil, "an atlas the client lacks")
        ola.atlases = { ["hunter-stable-bg-art_cunning"] = true }
        file, l, r, t, b, aw = S:Art("atlas:hunter-stable-bg-art_cunning")
        eq(file, 4000 + #"hunter-stable-bg-art_cunning"); eq(l, 0.25); eq(aw, 64)
        -- An atlas whose art is part of its rectangle (the delve entrances: art left, parchment right).
        S.ART["atlas:hunter-stable-bg-art_cunning"] = { 0, 0.6, 0, 1, 38, 64 }
        Near({ select(2, S:Art("atlas:hunter-stable-bg-art_cunning")) }, { 0.25, 0.4, 0.125, 0.375 }, "its left part")
        eq(select(6, S:Art("atlas:hunter-stable-bg-art_cunning")), 38)
        S.ART["atlas:hunter-stable-bg-art_cunning"] = nil
        -- On the card (16 x 16 in the harness): the atlas's part, cut square.
        S.BY_FAMILY = { cat = { "atlas:Missing", "atlas:hunter-stable-bg-art_cunning" }, default = { 7963741 } }
        S.BY_SPECIES = {}
        S:Reset()
        local card = ola:SelectPet(40)
        eq(card.scene.tex, file, "the first the client has")
        Near(card.scene.texCoord, { 0.25, 0.5, 0.125, 0.375 }, "a square atlas, a square card")
        card = ola:SelectPet(5159)
        Near(card.scene.texCoord, { 0.5 - 1152 / 2992 / 2, 0.5 + 1152 / 2992 / 2, 0.16, 0.84 }, "wide art")
        -- A dungeon background: its art is 394 x 425, a little taller than wide.
        Near({ select(2, S:Art("Interface\\EncounterJournal\\UI-EJ-BACKGROUND-ZulGurub")) }, { 0, 0.76953125, 0, 0.830078125 }, "EJ")
    end)

    test("/dp probe bg: a family's suggestions and every group, cut as the card shows them; hover previews, a click picks", function()
        local w, ola = Setup()
        local S, G = ola.ns.Scenes, ola.ns.SceneGallery
        local Art = ola.ns.SceneArt
        ola:SelectPet(68) -- an owl on the card: the gallery opens on owls
        ola:Slash("probe bg")
        ok(ola:Printed("backgrounds (", true))
        ok(G._frame:IsShown())
        local owlButton
        for _, b in ipairs(G._frame.families) do if b.family == "owl" then owlButton = b end end
        ok(owlButton.highlightLocked, "the card's family")
        local function Shown()
            local list = {}
            for _, t in ipairs(G._thumbs) do if t:IsShown() then list[#list + 1] = t end end
            return list
        end
        -- Suggestions: what the code has first, then the generated ones.
        local shown = Shown()
        eq(shown[1].path, S.BY_FAMILY.owl[1])
        eq(#shown, #S:Suggestions("owl"))
        ok(#shown >= 2, "more than today's")
        -- A group, in pages.
        local loading
        for _, b in ipairs(G._frame.sources) do if b.source == "loading" then loading = b end end
        loading:Click()
        local n = 0
        for _, c in ipairs(S:Candidates()) do if c.group == "loading" then n = n + 1 end end
        ok(n > 100, n .. " loading screens")
        eq(#Shown(), 20, "a page")
        match(G._frame.hint.text, ("Page 1 of %d %%(%d pictures%%)"):format(math.ceil(n / 20), n))
        local first, last = Shown()[1].path, Shown()[20]
        G._frame.next:Click()
        match(G._frame.hint.text, "Page 2 of")
        no(Shown()[1].path == first)
        -- The last page is short: the thumbnails it doesn't need let go of their pictures.
        for _ = 3, math.ceil(n / 20) do G._frame.next:Click() end
        if n % 20 ~= 0 then no(last:IsShown()); eq(last.image.tex, nil, "a hidden one lets go of its picture") end
        G._frame.prev:Click()
        -- Cut as the card will be: the card's shape (unknown in the harness: the guess).
        local t = Shown()[1]
        eq(S:Shape(), 0.8)
        eq(t.backing.size[1], 160); eq(t.backing.size[2], 200)
        local file, l, r, tp, b, aw, ah = S:Art(t.path)
        local want = { S.Cover(l, r, tp, b, aw, ah, t.backing.size[1], t.backing.size[2]) }
        eq(table.concat(t.image.texCoord, ","), table.concat(want, ","))
        eq(t.image.tex, file)
        match(ola:TipOf(t)[1], "loading")
        -- Hover: the card shows it; away: the family's again.
        t.scripts.OnEnter(t)
        eq(ola:SelectPet(40).scene.tex, file, "any pet, while hovered")
        t.scripts.OnLeave(t)
        eq(ola.ns.Scenes.override, nil)
        no(ola:SelectPet(40).scene.tex == file, tostring(file))
        -- A click picks it for the selected family (owl), kept after a reload.
        t.scripts.OnClick(t, "LeftButton")
        eq(ola.env.DyreparkenDB.scenePicks.owl, t.path)
        eq(t.used.text, "owl"); match(owlButton.text, "%*$")
        eq(ola:SelectPet(68).scene.tex, file, "the owl wears it")
        eq(#ola:Log("bg pick owl = "), 1)
        ola:Reload()
        w:Run(20)
        ola:OpenJournal()
        eq(ola:SelectPet(68).scene.tex, file)
        -- The pick leads the family's suggestions; right-click clears it.
        S, G = ola.ns.Scenes, ola.ns.SceneGallery -- (the reloaded addon's)
        ola:Slash("probe bg")
        eq(Shown()[1].path, t.path)
        Shown()[1].scripts.OnClick(Shown()[1], "RightButton")
        eq(ola.env.DyreparkenDB.scenePicks.owl, nil)
        -- Closing the gallery ends a preview; /dp probe bg off too.
        Shown()[2].scripts.OnEnter(Shown()[2])
        ok(S.override)
        G._frame:Hide()
        eq(S.override, nil)
        ola:Slash("probe bg off")
        ok(ola:Printed("Backgrounds: back to the families.", true))
        -- Every candidate once; each generated file's crop is in Scenes.ART.
        local seen = {}
        for _, c in ipairs(S:Candidates()) do no(seen[c.path], "listed once"); seen[c.path] = true end
        for _, row in ipairs(Art.list) do
            if type(row[1]) == "number" then ok(S.ART[row[1]], row[3]) end
        end
    end)

    test("the probe has Forever's own loading screens, the new dungeons' among them", function()
        local w, ola = Setup()
        local names = {}
        for _, c in ipairs(ola.ns.Scenes:Candidates()) do if c.group == "forever" then names[c.label] = true end end
        ok(names["The Drowned City"]); ok(names["Blackmaw Hold"]); ok(names["Krol'dok Stronghold"])
        for family in pairs(ola.ns.SceneArt.families) do
            ok(family == "default" or ola.ns.Scenes.TINT[family], family .. ": a family")
        end
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
        -- The full-width sheet: the name stops at the level's name, the home at the medallion, the rest run on.
        local last = card.status.points[#card.status.points]
        eq(last[3], "RIGHT"); eq(last[4], -72, "the home line stops short of the medallion")
        eq(card.nickname.points[#card.nickname.points][4], -150)
        eq(card.personality.points[#card.personality.points][4], -12)
        -- The personality's badges from the left, under the strip (AboutPet.lua).
        eq(card.badges.points[1][1], "TOPLEFT"); eq(card.badges.points[1][4], 10)
        -- The bond strip: stars from the left, the bar after them, the goal after the bar.
        local b = card.bond
        eq(b.pips[1].points[1][4], 12); eq(b.pips[1].points[1][5], ola.ns.JournalUI.ROW_Y.strip)
        eq(b.points[1][1], "TOPLEFT"); ok(b.points[1][4] > b.pips[7].points[1][4], "the bar after the seventh star")
        eq(b.next.points[1][1], "RIGHT"); eq(b.points[2][1], "RIGHT"); eq(b.points[2][2], b.next, "the bar fills up to the goal")
        eq(#ola:Log("rotate buttons moved above the panel"), 1)
        local w2 = H.World()
        local kari = w2:AddClient("Kari Berg", { pets = { 40 } })
        w2:Settle("bond")
        kari:OpenJournal({ noRotate = true })
        card = kari:SelectPet(40)
        last = card.status.points[#card.status.points]
        eq(last[4], -52, "narrow")
        eq(#kari:Log("rotate buttons not found"), 1)
    end)

    test("without a Total Pets box, the guild boxes sit above the card", function()
        local w, c = H.Setup{ ola = { 40 }, settle = "bond" }
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

    test("hovering the personality and the bond explains them; a click on a badge, the panel tells all", function()
        local w, ola = Setup()
        ola:Slash("adopter panda")
        w:Run(40)
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        local traits = ola.ns.Personality:Traits("s:5159")
        eq(#traits, 2)
        local B = card.badges.badges
        for i, q in ipairs(traits) do
            eq(ola:TipOf(B[i]).text, q.name .. " / " .. q.desc .. " / " .. ola.ns.Personality:Effect(q)
                .. " / Klikk for mer om Panda Cub", "a trait's badge: what it means and does")
        end
        match(ola:TipOf(B[3]).text, "^Liker herbs / Herbs med dyret ute gir 5 båndpoeng %(opptil 25 om dagen%), mot 1 ellers%.")
        no(ola.ns.Story:IsOpen())
        B[3]:Click()
        ok(ola.ns.Story:IsOpen(), "a click opens the panel")
        eq(ola.ns.Story.tab, "personality", "on its personality")
        local text = ola:About("s:5159", "personality").text
        match(text, "^Egenskaper / " .. traits[1].name .. " / ")
        -- What each trait means; what it does only when that isn't a like's line already (said twice, seen in game).
        for _, q in ipairs(traits) do
            if q.like and not (q.when or q.day) then
                ok(text:find(q.name .. " / " .. q.desc .. " / ", 1, true), q.id .. ": what it means")
                no(text:find(q.desc .. "\n", 1, true), q.id .. ": its like's line says what it gives, not the trait's")
            else
                ok(text:find(q.name .. " / " .. q.desc .. "\n" .. ola.ns.Personality:Effect(q), 1, true), q.id .. ": means and does")
            end
        end
        ola:Traits{ "gronnfinger", "nattugle" } -- (one of each)
        text = ola:About("s:5159", "personality").text
        ok(text:find("Grønnfinger / " .. ola.ns.Personality.ById("gronnfinger").desc .. " / ", 1, true))
        ok(text:find(ola.ns.Personality.ById("nattugle").desc .. "\n" .. ola.ns.Personality:Effect(ola.ns.Personality.ById("nattugle")), 1, true))
        match(text, "Liker / Herbs / ")
        match(text, "vokser båndet raskere%.$")
        text = ola:TipOf(card.bond).text
        match(text, "^Bånd: Bekjent %(level 1%) / %d+ poeng til Kamerat%. / På level 2 får kortet en kant og et hint av farge%. / I dag: %+%d+ av 75 mulige poeng%. / Vokser for hver dag")
        -- At the top level.
        local now = w:ServerTime()
        ola.ns.Registry:MergeLife("s:5159", "Ola Nord", { p = 9000, f = now - 200 * 86400, t = now })
        card = ola:SelectPet(5159)
        match(ola:TipOf(card.bond).text, "Høyeste level%.")
        -- A free pet nobody has: nothing to explain on the bond; its personality a surprise, and why on hover.
        card = ola:SelectPet(68)
        eq(#ola:TipOf(card.bond), 0)
        no(card.badges:IsShown())
        match(ola:TipOf(card.personalityHit).text, "^Ukjent personlighet / Personligheten er en overraskelse")
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        no(card.badges:IsShown(), "no pet: no badges")
        no(card.personalityHit:IsShown(), "nor a hover")
    end)

    test("/dp probe card logs what the pet card is made of", function()
        local w, ola = Setup()
        ola:SelectPet(5159)
        ola:Slash("probe card")
        ok(ola:Printed("Pet card probed", true))
        ok(#ola:Log("card Frame key=modelScene") >= 1, "children, by the key they're stored under")
        ok(#ola:Log("card   ") >= 1, "and theirs, indented")
        ok(#ola:Log("text=Pepe") + #ola:Log("text=Panda Cub") >= 1, "font strings with their text")
        local w2 = H.World()
        local kari = w2:AddClient("Kari Berg")
        w2:Run(5)
        kari:Slash("probe card")
        ok(kari:Printed("Open the pet journal first.", true))
    end)

    test("Blizzard's title row (icon and name) is hidden, and stays hidden; the ribbon takes the top", function()
        local w, ola = Setup()
        local card = ola:SelectPet(5159)
        local info = ola.env.PetJournalPetCard.PetInfo
        no(info:IsShown(), "hidden")
        ok(card.titleHidden)
        info:Show() -- Blizzard's update showing it again
        no(info:IsShown(), "and kept hidden")
        local r = card.decor.ribbon.points[1]
        eq(r[1], "TOP"); eq(r[5], -10, "the ribbon at the top")
    end)

    test("a long name steps down a size or two before it's cut short", function()
        local w, ola = Setup()
        local card = ola:SelectPet(5159)
        eq(card.nickname.font, "GameFontNormalHuge", "not laid out yet: the big one")
        card.panel.geo = { l = 0, r = 336, t = 106, b = 0 } -- room for the name: 336 - 150 - 14 = 172 px
        card = ola:SelectPet(5159)
        eq(card.nickname.font, "GameFontNormalHuge", "'Panda Cub' fits big")
        ola.ns.Registry.Nickname = function() return "Brown Prairie Dogge" end -- 19 characters
        card = ola:SelectPet(5159)
        eq(card.nickname.font, "GameFontNormal", "too long for the big and the large ones")
        ola.ns.Registry.Nickname = function() return "Bambusbjørnen" end -- 14 bytes: too wide big, fits large
        card = ola:SelectPet(5159)
        eq(card.nickname.font, "GameFontNormalLarge")
    end)

    test("a click on Dagens dyr shows that pet in the journal", function()
        local w, ola = H.Setup{ ola = { 5159, 46 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        local card = ola:SelectPet(46)
        eq(card.species, "White Kitten")
        card.todayBox.scripts.OnMouseUp(card.todayBox)
        eq(ola.selectedSpecies, 5159, "Blizzard's own selection: the list scrolls to it")
        eq(card.species, "Panda Cub")
        -- Not in combat; and without the journal's function, nothing (said in the log).
        ola:SelectPet(46)
        ola.state.combat = true
        card.todayBox.scripts.OnMouseUp(card.todayBox)
        eq(card.species, "White Kitten")
        ola.state.combat = false
        eq(ola.shownSpecies, nil, "an owned pet: the list's selection was enough")
        rawset(ola.env, "PetJournal_SelectSpecies", nil)
        rawset(ola.env, "PetJournal_ShowPetCardBySpeciesID", nil)
        card.todayBox.scripts.OnMouseUp(card.todayBox)
        eq(card.species, "White Kitten")
        eq(#ola:Log("PetJournal_SelectSpecies: missing"), 1); eq(#ola:Log("PetJournal_ShowPetCardBySpeciesID: missing"), 1)
    end)

    test("the quest chip is the quest giver's \"!\", and the list marks a pet that needs a home with a house", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        eq(ola.ns.Stats.Icon("quest"), "Interface\\GossipFrame\\AvailableQuestIcon")
        ola.env.GetFileIDFromPath = function(p) return not p:find("GossipFrame") and 1 or nil end
        eq(ola.ns.Stats.Icon("quest"), "Interface\\Icons\\INV_Misc_Book_09", "a book where the client lacks it")
    end)
end
