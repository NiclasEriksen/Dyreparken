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
        eq(card.status.plain, "Panda Cub · Har bodd hos deg i 30 dager")
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
        eq(table.concat(card.scene.texCoord, ","), "0,0.76953125,0,0.830078125")
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
            local now = ola.ns.Now()
            local t = os.date("*t", now)
            t.hour, t.min = h, 30
            w:Skip(os.time(t) - now)
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

    test("/dp probe bg opens a gallery of what exists; picks become the family's background", function()
        local w, ola = Setup()
        ola.ns.Scenes.BY_FAMILY = Lists()
        local list = ola.ns.Scenes:Candidates()
        ola.missingFiles = { [list[2].path] = true }
        ola:Slash("probe bg")
        ok(ola:Printed(("%d of %d backgrounds exist; the gallery shows them."):format(#list - 1, #list), true))
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
        ola:Reload()
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
        ok(ola:Printed("No background 999", true))
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
        -- The full-width sheet: the name stops at the level's name, the home at the medallion, the rest run on.
        local last = card.status.points[#card.status.points]
        eq(last[3], "RIGHT"); eq(last[4], -72, "the home line stops short of the medallion")
        eq(card.nickname.points[#card.nickname.points][4], -150)
        for _, row in ipairs({ card.personality, card.likes }) do eq(row.points[#row.points][4], -12) end
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
        local text = ola:TipOf(card.personalityHit).text
        local traits = ola.ns.Personality:Traits("s:5159")
        eq(#traits, 2)
        match(text, "^" .. traits[1].name .. " / ")
        for _, q in ipairs(traits) do
            ok(text:find(q.name .. " / " .. q.desc, 1, true), "what each trait means")
            ok(text:find(ola.ns.Personality:Effect(q), 1, true), "and what it does")
        end
        match(text, "Liker: herbs")
        match(text, "vokser båndet raskere%.$")
        text = ola:TipOf(card.bond).text
        match(text, "^Bånd: Bekjent %(level 1%) / %d+ poeng til Kamerat%. / På level 2 får kortet en kant og et hint av farge%. / I dag: %+%d+ av 75 mulige poeng%. / Vokser for hver dag")
        -- At the top level.
        local now = w:ServerTime()
        ola.ns.Registry:MergeLife("s:5159", "Ola Nord", { p = 9000, f = now - 200 * 86400, t = now })
        card = ola:SelectPet(5159)
        match(ola:TipOf(card.bond).text, "Høyeste level%.")
        -- A free pet we don't own: nothing to explain on the bond; the personality still tells.
        card = ola:SelectPet(68)
        eq(#ola:TipOf(card.bond), 0)
        ok(#ola:TipOf(card.personalityHit) >= 2)
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        eq(#ola:TipOf(card.personalityHit), 0, "no pet: no tooltip")
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

    test("a click on Dagens dyr shows that pet in the journal; the likes line is readable", function()
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
        -- The likes: light text now, not the disabled grey.
        eq(card.likes.font, "GameFontHighlightSmall")
        eq(card.likes.color[1], 0.8)
    end)

    test("the quest chip is the quest giver's \"!\", and the list marks a pet that needs a home with a house", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        eq(ola.ns.Stats.Icon("quest"), "Interface\\GossipFrame\\AvailableQuestIcon")
        ola.env.GetFileIDFromPath = function(p) return not p:find("GossipFrame") and 1 or nil end
        eq(ola.ns.Stats.Icon("quest"), "Interface\\Icons\\INV_Misc_Book_09", "a book where the client lacks it")
    end)
end
