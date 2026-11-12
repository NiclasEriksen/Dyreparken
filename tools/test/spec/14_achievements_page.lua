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
    local function Fix(c) c:Companions(H.COMPANIONS); return c end

    local function Setup(pets, opts)
        opts = opts or {}
        opts.pets = pets
        return H.Setup{ ola = opts, kari = { 41 }, each = Fix, settle = "hello" }
    end

    -- Open the journal (Forever's: 4 side tabs) and our page, as a player does: the page's view
    -- (harness c:Page).
    local function Open(c, o)
        c:OpenJournal(o or { sideTabs = 4 })
        return c:Page("Prestasjoner"):Open()
    end
    -- An achievement's row on the open page, by the name it shows.
    local function Row(page, id) return page:Row(page.client.ns.Achievements:Name(id)) end

    local function Tooltip(c, row)
        return table.concat(c:TipOf(row), "\n")
    end

    local function Selected(c, n)
        local t = c.env["CollectionsJournalTab" .. n]
        return t.sel1:IsShown() and t.sel2:IsShown()
    end

    test("a side tab like Blizzard's: the page covers theirs, their tabs go back", function()
        local w, ola = Setup({ 40 })
        ola:OpenJournal({ sideTabs = 4 })
        local env, P, page = ola.env, ola.ns.AchPage, ola:Page("Prestasjoner")
        local tab = page.tab
        ok(tab:IsShown())
        no(page.button:IsShown(), "no fallback button")
        no(rawget(env, "DyreparkenAchievementsPage"), "nothing built before the first click")
        eq(tab.points[1][2], env.CollectionsJournalTab4, "under the last tab")
        eq(tab.points[1][5], -2, "the same spacing")
        eq(tab.size[1], 55); eq(tab.size[2], 55)
        eq(tab.bg.atlas, "common-sidetab")
        eq(tab.icon.mask, tab.mask, "the icon is masked to the tab's shape")
        eq(tab.mask.atlas, "common-sidetab-mask")
        eq(tab.hover.atlas, "common-sidetab-hover")
        no(tab.selected:IsShown())
        eq(ola:TipOf(tab)[1], "Prestasjoner")

        ok(Selected(ola, 2), "Pets is selected")
        tab:Click()
        ok(P:IsOpen())
        ok(tab.selected:IsShown())
        no(Selected(ola, 2), "Blizzard's highlight is hidden while we're up")
        eq(env.CollectionsJournal.titleFS.text, "Prestasjoner")
        ok(page.frame.level > env.CollectionsJournal:GetFrameLevel() + 100, "above every page")
        ok(env.PetJournal:IsShown(), "their page isn't hidden, only covered")
        local CJ = env.CollectionsJournal
        ok(CJ.NineSlice.level > page.frame.level, "the border stays on top")
        eq(CJ.PortraitContainer.level, CJ.NineSlice.level + 1, "so do the portrait, the title, the close button")
        eq(CJ.TitleContainer.level, CJ.NineSlice.level + 2, "in their own order")
        eq(CJ.CloseButton.level, CJ.NineSlice.level + 2)
        local portrait = CJ.PortraitContainer.portrait
        eq(portrait.tex, "Interface\\Icons\\Achievement_General", "our icon in the portrait")
        eq(page.frame.bg.tex, 2002, "the window's own background")
        ok(page.frame.bg.horizTile and page.frame.bg.vertTile)
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
        no(page.frame:IsShown(), "closing the window leaves the page")
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
        local cat = Row(P, "family:cat")
        ok(cat:IsShown())
        eq(cat.name.text, "Kattevræl")
        eq(cat.desc.text, "Ha alle kattene.")
        ok(cat.info:IsShown()); no(cat.bar:IsShown())
        match(cat.info.text, "^%d%d%.%d%d%.%d%d%d%d$", "earned: the date")
        eq(cat.icon.desaturated, false)
        local ten = Row(P, "count:10")
        no(ten.info:IsShown()); ok(ten.bar:IsShown())
        eq(ten.bar.value, 5); eq(ten.bar.max, 10)
        eq(ten.bar.text.text, "5/10")
        eq(ten.icon.desaturated, true, "unearned rows are dimmed")
        eq(Row(P, "loyal:30").bar.text.text, "0/270 poeng")
        no(Row(P, "count:25"), "25 > 15 counting pets: no row")
        no(Row(P, "family:dragon"), "no dragons in this list")
        for _, head in ipairs({ "Samlingen", "Familier", "Lojalitet", "Guilden" }) do ok(P:Text(head, true), head) end
        match(P.frame.summary.text, "^1/%d+$")
        no(cat.share:IsShown(), "quiet on the first run: nothing to share")
        eq(cat.info.points[1][2], cat, "no Del: at the right edge")
    end)

    test("without side tabs: a button opens the page", function()
        local w, ola = Setup({ 40 })
        ola:OpenJournal()
        local page = ola:Page("Prestasjoner")
        ok(page.button:IsShown(), "the button reads Prestasjoner")
        no(page.tab:IsShown())
        page.button:Click()
        ok(ola.ns.AchPage:IsOpen())
        ola:CloseJournal()
        no(page.frame:IsShown())
    end)

    test("Del shares that one achievement in guild chat, then goes away", function()
        local w, ola = Setup({ 40, 41, 42, 7, 84, 68, 72, 90, 2001 })
        local P = Open(ola)
        no(Row(P, "family:cat").share:IsShown())
        ola:GivePet(46); ola:Fire("NEW_PET_ADDED", ola:GuidOf(46))
        w:Run(2)
        -- The page was open: it refreshed by itself.
        local cat, ten = Row(P, "family:cat"), Row(P, "count:10")
        ok(cat.share:IsShown(), "new: Del")
        ok(ten.share:IsShown())
        eq(cat.share.text, "Del")
        eq(cat.info.points[1][2], cat.share, "the date sits left of Del")
        eq(ola:TipOf(cat.share)[1], "Del det i guildchatten.")
        cat.share:Click()
        eq(#w.chat, 1, "only that one")
        eq(w.chat[1].text, "Ola Nord har gitt alle kattene et hjem! [Kattevræl]")
        no(cat.share:IsShown(), "shared: gone")
        ok(ten.share:IsShown(), "the other one still waits")
        match(Tooltip(ola, cat), "Delt i guildchatten%.")
    end)

    test("tooltips: what it takes, and the missing pets", function()
        local w, ola = Setup({ 40, 41 })
        local P = Open(ola)
        local tip = Tooltip(ola, Row(P, "family:cat"))
        match(tip, "^Kattevræl\nHa alle kattene%.\n2/4\n \nMangler:\nBlack Tabby Cat\nWhite Kitten$")
        -- "All of them": 13 missing, 12 shown.
        match(Tooltip(ola, Row(P, "count:all")), "%.%.%. og 1 til$")
        -- A count tier lists nothing.
        eq(Tooltip(ola, Row(P, "count:10")), "Ti små indianere\nHa 10 dyr.\n2/10")
        -- Earned: the date, no list.
        ola:GivePet(42); ola:GivePet(46)
        ola.ns.Achievements:Check("test")
        match(Tooltip(ola, Row(P, "family:cat")), "^Kattevræl\nHa alle kattene%.\nFått %d%d%.%d%d%.%d%d%d%d$")
    end)

    test("guild rows: who cares for what, follows the registry; Del for officers only", function()
        local w = H.World()
        local names = { { "Ola Nord", 40, 1, "Bombay" }, { "Kari Berg", 41, 3, "Cornish" }, { "Per Hansen", 42, 3, "Tabby" },
            { "Liv Lund", 46, 3 } }
        local cs = {}
        for _, m in ipairs(names) do cs[m[1]] = Fix(w:AddClient(m[1], { pets = { m[2], 46 }, rank = m[3] })) end
        w:Settle("hello")
        for _, m in ipairs(names) do if m[4] then cs[m[1]]:Slash("adopter " .. m[4]) end end
        w:Run(20)
        local ola, kari = cs["Ola Nord"], cs["Kari Berg"]
        local P = Open(ola)
        local row = Row(P, "guild:family:cat")
        eq(row.bar.text.text, "3/4")
        local tip = Tooltip(ola, row)
        match(tip, "Bombay Cat: Ola Nord")
        match(tip, "White Kitten: trenger et hjem")
        match(Tooltip(ola, Row(P, "guild:all")), "Trenger et hjem:\n")
        -- Liv adopts the last cat: the guild has every cat.
        cs["Liv Lund"]:Slash("adopter White Kitten")
        w:Run(20)
        DropAdoptions(w)
        ok(row.info:IsShown(), "earned while the page was open")
        ok(row.share:IsShown(), "officer: Del")
        local KP = Open(kari)
        no(Row(KP, "guild:family:cat").share:IsShown(), "member: no Del")
        row.share:Click()
        eq(#w.chat, 1)
        match(w.chat[1].text, "%[Kattehuset%]$")
    end)

    test("not in a guild: no guild rows", function()
        local w, ola = Setup({ 40 }, { guild = false })
        local P = Open(ola)
        no(Row(P, "guild:family:cat"))
        no(P:Text("Guilden", true), "no guild heading")
        ok(P:Text("Familier", true))
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
        eq(liv:Page("Prestasjoner").tab.points[1][5], -2)
    end)

    test("icons: the first candidate the client has", function()
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
        local P = Open(ola)
        eq(Row(P, "count:10").icon.tex, "Interface\\Icons\\INV_Misc_PetBiscuit_01")
        -- A client without GetFileIDFromPath takes the first.
        local kari = Fix(w:AddClient("Kari Berg", { pets = { 40 }, patch = function(env) env.GetFileIDFromPath = nil end }))
        w:Settle("hello")
        eq(kari.ns.Achievements:Icon(D["count:10"]), "Interface\\Icons\\INV_Box_Birdcage_01")
    end)

    test("the background: the window's atlas, or the texture in its Bg frame, or the rock", function()
        local function BgWith(setup)
            local w = H.World()
            local c = Fix(w:AddClient("Ola Nord", { pets = { 40 } }))
            w:Settle("hello")
            c:OpenJournal({ sideTabs = 2 })
            setup(c.env.CollectionsJournal, c.env)
            return c:Page("Prestasjoner"):Open().frame.bg
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
        w:Settle("hello")
        c:OpenJournal({ sideTabs = 2 })
        local cj = c.env.CollectionsJournal
        cj.PortraitContainer.portrait = nil
        cj.NineSlice, cj.TitleContainer, cj.CloseButton = nil, nil, nil
        c:Page("Prestasjoner").tab:Click()
        ok(c.ns.AchPage:IsOpen())
        c:ClickTab(2)
    end)
end
