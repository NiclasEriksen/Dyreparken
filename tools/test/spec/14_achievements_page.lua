-- The achievements page of the Collections window: our side tab, covering
-- and leaving Blizzard's pages, rows, the Del button (a click, so it may post
-- to guild chat), tooltips with the missing pets.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- Adoption announcements (Bonds) aren't what these tests count.
    local function DropAdoptions(w)
        for i = #w.chat, 1, -1 do if w.chat[i].text:find(" adopterte ", 1, true) then table.remove(w.chat, i) end end
    end


    -- Same small list as 12_achievements: 4 cats, 15 counting pets.
    local function Fixture()
        local species = {
            [40] = { a = true, t = { "cat" } }, [41] = { a = true, t = { "cat" } },
            [42] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat" } },
            [7] = { a = true, t = { "farm", "bird" } }, [84] = { a = true, t = { "farm", "bird" } },
            [68] = { a = true, t = { "owl", "bird" } }, [72] = { a = true, t = { "rabbit" } },
            [90] = { a = true, t = { "bird", "pirate" } },
            [5159] = { a = false },
        }
        for sid = 2001, 2006 do species[sid] = { a = true } end
        return { build = 1, species = species }
    end
    local function Fix(c) c.ns.Companions = Fixture(); return c end

    local function Setup(pets, opts)
        local w = H.World()
        opts = opts or {}
        opts.pets = pets
        local ola = Fix(w:AddClient("Ola Nord", opts))
        local kari = Fix(w:AddClient("Kari Berg", { pets = { 41 } }))
        w:Run(12)
        return w, ola, kari
    end

    -- Open the journal (Forever's: 4 side tabs) and our page.
    local function Open(c, o)
        c:OpenJournal(o or { sideTabs = 4 })
        local P = c.ns.AchPage
        if P._tab:IsShown() then P._tab:Click() else P._button:Click() end
        return P
    end

    local function Tooltip(c, row)
        row.scripts.OnEnter(row)
        local lines = c.env.GameTooltip.lines
        row.scripts.OnLeave(row)
        return table.concat(lines, "\n")
    end

    local function Selected(c, n)
        local t = c.env["CollectionsJournalTab" .. n]
        return t.sel1:IsShown() and t.sel2:IsShown()
    end

    test("a side tab like Blizzard's: the page covers theirs, their tabs go back", function()
        local w, ola = Setup({ 40 })
        ola:OpenJournal({ sideTabs = 4 })
        local env, P = ola.env, ola.ns.AchPage
        local tab = P._tab
        ok(tab:IsShown())
        no(P._button:IsShown(), "no fallback button")
        no(P._page, "nothing built before the first click")
        eq(tab.points[1][2], env.CollectionsJournalTab4, "under the last tab")
        eq(tab.points[1][5], -2, "the same spacing")
        eq(tab.size[1], 55); eq(tab.size[2], 55)
        eq(tab.bg.atlas, "common-sidetab")
        eq(tab.icon.mask, tab.mask, "the icon is masked to the tab's shape")
        eq(tab.mask.atlas, "common-sidetab-mask")
        eq(tab.hover.atlas, "common-sidetab-hover")
        no(tab.selected:IsShown())
        tab.scripts.OnEnter(tab)
        eq(env.GameTooltip.lines[1], "Prestasjoner")
        tab.scripts.OnLeave(tab)

        ok(Selected(ola, 2), "Pets is selected")
        tab:Click()
        ok(P:IsOpen())
        ok(tab.selected:IsShown())
        no(Selected(ola, 2), "Blizzard's highlight is hidden while we're up")
        eq(env.CollectionsJournal.titleFS.text, "Prestasjoner")
        ok(P._page.level > env.CollectionsJournal:GetFrameLevel() + 100, "above every page")
        ok(env.PetJournal:IsShown(), "their page isn't hidden, only covered")
        local CJ = env.CollectionsJournal
        ok(CJ.NineSlice.level > P._page.level, "the border stays on top")
        eq(CJ.PortraitContainer.level, CJ.NineSlice.level + 1, "so do the portrait, the title, the close button")
        eq(CJ.TitleContainer.level, CJ.NineSlice.level + 2, "in their own order")
        eq(CJ.CloseButton.level, CJ.NineSlice.level + 2)
        local portrait = CJ.PortraitContainer.portrait
        eq(portrait.tex, "Interface\\Icons\\Achievement_General", "our icon in the portrait")
        eq(P._page.bg.tex, 2002, "the window's own background")
        ok(P._page.bg.horizTile and P._page.bg.vertTile)
        tab:Click()
        ok(P:IsOpen(), "pressing it again stays, like their tabs")

        -- Back to Pets: their tab, their highlight, their title.
        ola:ClickTab(2)
        no(P:IsOpen())
        no(tab.selected:IsShown())
        ok(Selected(ola, 2))
        eq(env.CollectionsJournal.titleFS.text, "Pet Journal")
        eq(CJ.NineSlice.level, 3, "put back"); eq(CJ.PortraitContainer.level, 4); eq(CJ.TitleContainer.level, 5)
        eq(portrait.tex, 1001, "their portrait back")
        -- Blizzard set a new portrait while we were up: theirs stays.
        tab:Click()
        portrait:SetTexture(1003)
        ola:ClickTab(2)
        eq(portrait.tex, 1003)

        -- To Mounts: only Mounts is selected afterwards.
        tab:Click()
        ola:ClickTab(1)
        no(P:IsOpen())
        ok(env.MountJournal:IsShown())
        ok(Selected(ola, 1)); no(Selected(ola, 2))
        eq(env.CollectionsJournal.titleFS.text, "Mounts")

        -- From Mounts, then the window closes: it opens on Mounts again.
        tab:Click()
        ok(P:IsOpen())
        ola:CloseJournal()
        no(P._page:IsShown(), "closing the window leaves the page")
        ok(Selected(ola, 1), "their highlight is back")
        eq(env.CollectionsJournal.titleFS.text, "Mounts")
        env.CollectionsJournal:Show()
        no(P:IsOpen())

        -- A page showing without a tab press we saw (a keybind, another
        -- addon) also leaves ours, and their new highlight stays the only one.
        tab:Click()
        env.CollectionsJournal_SetTab(env.CollectionsJournal, 2)
        no(P:IsOpen())
        ok(Selected(ola, 2)); no(Selected(ola, 1))
        P:Close() -- already closed: nothing to do
        P:Refresh() -- not visible: nothing to do
    end)

    test("rows: grouped, the date when earned, a bar until then", function()
        local w, ola = Setup({ 40, 41, 42, 46, 7 })
        local P = Open(ola)
        local rows, heads = P._rows, P._headers
        local cat = rows["family:cat"]
        ok(cat:IsShown())
        eq(cat.name.text, "Alle kattene")
        eq(cat.desc.text, "Ha alle kattene.")
        ok(cat.info:IsShown()); no(cat.bar:IsShown())
        match(cat.info.text, "^%d%d%.%d%d%.%d%d%d%d$", "earned: the date")
        eq(cat.icon.desaturated, false)
        local ten = rows["count:10"]
        no(ten.info:IsShown()); ok(ten.bar:IsShown())
        eq(ten.bar.value, 5); eq(ten.bar.max, 10)
        eq(ten.bar.text.text, "5/10")
        eq(ten.icon.desaturated, true, "unearned rows are dimmed")
        eq(rows["loyal:30"].bar.text.text, "0/30 dager")
        no(rows["count:25"], "25 > 15 counting pets: no row")
        no(rows["family:dragon"], "no dragons in this list")
        for _, c in ipairs({ "collection", "family", "loyalty", "guild" }) do ok(heads[c]:IsShown(), c) end
        eq(heads.collection.text, "Samlingen")
        eq(heads.guild.text, "Guilden")
        match(P._page.summary.text, "^1/%d+$")
        no(cat.share:IsShown(), "quiet on the first run: nothing to share")
        eq(cat.info.points[1][2], cat, "no Del: at the right edge")
    end)

    test("without side tabs: a button opens the page", function()
        local w, ola = Setup({ 40 })
        ola:OpenJournal()
        local P = ola.ns.AchPage
        ok(P._button:IsShown())
        no(P._tab:IsShown())
        eq(P._button.text, "Prestasjoner")
        P._button:Click()
        ok(P:IsOpen())
        ola:CloseJournal()
        no(P._page:IsShown())
    end)

    test("Del shares that one achievement in guild chat, then goes away", function()
        local w, ola = Setup({ 40, 41, 42, 7, 84, 68, 72, 90, 2001 })
        local P = Open(ola)
        no(P._rows["family:cat"].share:IsShown())
        ola:GivePet(46); ola:Fire("NEW_PET_ADDED", ola:GuidOf(46))
        w:Run(2)
        -- The page was open: it refreshed by itself.
        local cat, ten = P._rows["family:cat"], P._rows["count:10"]
        ok(cat.share:IsShown(), "new: Del")
        ok(ten.share:IsShown())
        eq(cat.share.text, "Del")
        eq(cat.info.points[1][2], cat.share, "the date sits left of Del")
        cat.share.scripts.OnEnter(cat.share)
        eq(ola.env.GameTooltip.lines[1], "Del det i guild-chatten.")
        cat.share.scripts.OnLeave(cat.share)
        cat.share:Click()
        eq(#w.chat, 1, "only that one")
        eq(w.chat[1].text, "Ola Nord har gitt alle kattene et hjem! [Alle kattene]")
        no(cat.share:IsShown(), "shared: gone")
        ok(ten.share:IsShown(), "the other one still waits")
        match(Tooltip(ola, cat), "Delt i guild%-chatten%.")
    end)

    test("tooltips: what it takes, and the missing pets", function()
        local w, ola = Setup({ 40, 41 })
        local P = Open(ola)
        local tip = Tooltip(ola, P._rows["family:cat"])
        match(tip, "^Alle kattene\nHa alle kattene%.\n2/4\n \nMangler:\nBlack Tabby Cat\nWhite Kitten$")
        -- "All of them": 13 missing, 12 shown.
        match(Tooltip(ola, P._rows["count:all"]), "%.%.%. og 1 til$")
        -- A count tier lists nothing.
        eq(Tooltip(ola, P._rows["count:10"]), "Ti små venner\nHa 10 kjæledyr.\n2/10")
        -- Earned: the date, no list.
        ola:GivePet(42); ola:GivePet(46)
        ola.ns.Achievements:Check("test")
        match(Tooltip(ola, P._rows["family:cat"]), "^Alle kattene\nHa alle kattene%.\nFått %d%d%.%d%d%.%d%d%d%d$")
    end)

    test("guild rows: who cares for what, follows the registry; Del for officers only", function()
        local w = H.World()
        local names = { { "Ola Nord", 40, 1, "Bombay" }, { "Kari Berg", 41, 3, "Cornish" }, { "Per Hansen", 42, 3, "Tabby" },
            { "Liv Lund", 46, 3 } }
        local cs = {}
        for _, m in ipairs(names) do cs[m[1]] = Fix(w:AddClient(m[1], { pets = { m[2], 46 }, rank = m[3] })) end
        w:Run(12)
        for _, m in ipairs(names) do if m[4] then cs[m[1]]:Slash("adopt " .. m[4]) end end
        w:Run(20)
        local ola, kari = cs["Ola Nord"], cs["Kari Berg"]
        local P = Open(ola)
        local row = P._rows["guild:family:cat"]
        eq(row.bar.text.text, "3/4")
        local tip = Tooltip(ola, row)
        match(tip, "Bombay Cat: Ola Nord")
        match(tip, "White Kitten: trenger et hjem")
        match(Tooltip(ola, P._rows["guild:all"]), "Trenger et hjem:\n")
        -- Liv adopts the last cat: the guild has every cat.
        cs["Liv Lund"]:Slash("adopt White Kitten")
        w:Run(20)
        DropAdoptions(w)
        ok(row.info:IsShown(), "earned while the page was open")
        ok(row.share:IsShown(), "officer: Del")
        local KP = Open(kari)
        no(KP._rows["guild:family:cat"].share:IsShown(), "member: no Del")
        row.share:Click()
        eq(#w.chat, 1)
        match(w.chat[1].text, "%[Kattehuset%]$")
    end)

    test("not in a guild: no guild rows", function()
        local w, ola = Setup({ 40 }, { guild = false })
        local P = Open(ola)
        no(P._rows["guild:family:cat"])
        no(P._headers.guild)
        ok(P._headers.family:IsShown())
    end)

    test("/dp probe tabs logs the tabs; finding them skips what isn't one", function()
        local w, ola = Setup({ 40 })
        ola:Slash("probe tabs")
        ok(ola:Printed("Open the pet journal first."))
        ola:OpenJournal({ sideTabs = 2 })
        -- Not tabs: a hidden button in the strip, and a button three levels down.
        local env = ola.env
        local strip = env.CollectionsJournalTab1:GetParent()
        local hidden = env.CreateFrame("Button", nil, strip)
        hidden.geo, hidden.shown = { l = 702, r = 752, t = 10, b = 0 }, false
        local deep = env.CreateFrame("Frame", nil, env.CollectionsJournal)
        deep.geo = { l = 760, r = 770, t = 600, b = 0 }
        local deeper = env.CreateFrame("Frame", nil, deep)
        deeper.geo = { l = 760, r = 770, t = 600, b = 0 }
        env.CreateFrame("Button", nil, deeper).geo = { l = 760, r = 770, t = 0, b = -50 }
        ola:Slash("probe tabs")
        ok(ola:Printed("Probed 2 side tabs", true))
        eq(#ola:Log("tab 2 region 2 Texture layer=ARTWORK tex=tab2 "), 1)
        eq(#ola:Log("tab 1 region 3 Texture layer=ARTWORK tex=common%-sidetab%-selected atlas=common%-sidetab%-selected"), 1)
        -- One tab only: the usual 2 px gap.
        local w2, liv = Setup({ 40 })
        liv:OpenJournal({ sideTabs = 1 })
        eq(liv.ns.AchPage._tab.points[1][5], -2)
    end)

    test("icons: the first candidate the client has; /dp ach icons previews them", function()
        local w = H.World()
        local missing = {
            ["Interface\\Icons\\INV_Box_Birdcage_01"] = true,
            ["Interface\\Icons\\Ability_Hunter_Pet_Owl"] = true,
        }
        local ola = Fix(w:AddClient("Ola Nord", { pets = { 40 } }))
        ola.missingFiles = missing
        w:Run(12)
        local A = ola.ns.Achievements
        local D = A.defsById
        eq(A:Icon(D["count:10"]), "Interface\\Icons\\INV_Misc_PetBiscuit_01", "the first one is missing")
        eq(A:Icon(D["family:owl"]), A.NO_ICON, "none there: a question mark")
        eq(A:Icon({ id = "t:num", icon = { 12345, "X" } }), 12345, "file ids are taken as they are")
        eq(A:Icon({ id = "t:path", icon = "Interface\\Foo\\Bar" }), "Interface\\Foo\\Bar", "full paths stay")
        eq(A:Icon({ id = "t:bad", icon = { true } }), A.NO_ICON)
        ola:Slash("ach icons")
        local line = ola:Printed("Ti små venner: ", true)
        match(line, "|TInterface\\Icons\\INV_Box_Birdcage_01:24|t INV_Box_Birdcage_01 %(missing%)", "drawn and marked")
        match(line, "|TInterface\\Icons\\INV_Misc_PetBiscuit_01:24|t INV_Misc_PetBiscuit_01   ")
        local P = Open(ola)
        eq(P._rows["count:10"].icon.tex, "Interface\\Icons\\INV_Misc_PetBiscuit_01")
        -- A client without GetFileIDFromPath takes the first.
        local kari = Fix(w:AddClient("Kari Berg", { pets = { 40 }, patch = function(env) env.GetFileIDFromPath = nil end }))
        w:Run(12)
        eq(kari.ns.Achievements:Icon(D["count:10"]), "Interface\\Icons\\INV_Box_Birdcage_01")
    end)

    test("the background: the window's atlas, or the texture in its Bg frame, or the rock", function()
        local function BgWith(setup)
            local w = H.World()
            local c = Fix(w:AddClient("Ola Nord", { pets = { 40 } }))
            w:Run(12)
            c:OpenJournal({ sideTabs = 2 })
            setup(c.env.CollectionsJournal, c.env)
            c.ns.AchPage._tab:Click()
            return c.ns.AchPage._page.bg
        end
        eq(BgWith(function(cj) cj.Bg:SetAtlas("UI-Frame-Bg") end).atlas, "UI-Frame-Bg")
        eq(BgWith(function(cj, env)
            cj.Bg = env.CreateFrame("Frame", nil, cj)
            cj.Bg:CreateTexture():SetTexture(3003)
        end).tex, 3003)
        eq(BgWith(function(cj) cj.Bg = nil end).tex, "Interface\\FrameGeneral\\UI-Background-Rock")
        -- No portrait texture, nothing to lift: still opens.
        local w = H.World()
        local c = Fix(w:AddClient("Ola Nord", { pets = { 40 } }))
        w:Run(12)
        c:OpenJournal({ sideTabs = 2 })
        local cj = c.env.CollectionsJournal
        cj.PortraitContainer.portrait = nil
        cj.NineSlice, cj.TitleContainer, cj.CloseButton = nil, nil, nil
        c.ns.AchPage._tab:Click()
        ok(c.ns.AchPage:IsOpen())
        c:ClickTab(2)
    end)
end
