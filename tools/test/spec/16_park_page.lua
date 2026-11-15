-- "Parken": the park map page, its tab next to the achievements tab, the
-- records, and switching between our two pages.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- A small journal: 4 cats, a farm bird, a rabbit, the panda.
    local function Fixture()
        return { build = 1, species = {
            [40] = { a = true, t = { "cat" }, s = "vendor", w = "Donni Anthania (Elwynn Forest)" },
            [41] = { a = true, t = { "cat" } },
            [42] = { a = true, t = { "cat" }, s = "drop" }, [46] = { a = true, t = { "cat" } },
            [84] = { a = true, t = { "farm", "bird" } },
            [72] = { a = true, t = { "rabbit" }, s = "quest", w = "Waskily Wabbits! (Dun Morogh)" },
            [5159] = { a = false, s = "promo" }, -- (its words in Locale: source.where.5159)
        } }
    end

    local function Setup()
        local w = H.World({ members = H.FOLK }) -- (only members' adoptions are kept)
        local cs = {}
        for _, m in ipairs({ { "Ola Nord", { 5159, 40, 72 } }, { "Kari Berg", { 41 } }, { "Per Hansen", { 42 } } }) do
            local c = w:AddClient(m[1], { pets = m[2] })
            c:Companions(Fixture().species)
            cs[#cs + 1] = c
        end
        w:Run(20)
        return w, unpack(cs)
    end

    -- The park's icons as the player sees them: shown on the page, each with a species' portrait (the
    -- harness's GetPetInfoBySpeciesID gives species sid the display 20000 + sid).
    local function SpeciesOf(f)
        for _, t in ipairs(f.textures) do
            if t.shown and type(t.portrait) == "number" and H.SPECIES[t.portrait - 20000] then return t.portrait - 20000 end
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
        match(Tip(ola, kitty), "^Cornish Rex Cat / Flyttet inn hos Kari Berg i dag / Bånd: Bekjent %(level 1%) / %S+ og %S+ · liker [^/]* / Klikk for å se kortet%.$", "the traits by name; no effect paragraphs; no source without data")
        match(Tip(ola, rabbit), "Trenger et hjem / .* / Kilde: Oppdrag – Waskily Wabbits! %(Dun Morogh%) / Du har dette dyret, og kan adoptere det%.")
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

    -- Enclosures (2026-11-15, the user): each family one piece of the grid, fenced where it meets another.
    test("enclosures: the path through the grid goes cell to cell, so every family is one piece", function()
        local w, ola = Setup()
        local Park = ola.ns.ParkPage
        for cols = 1, 21 do
            local n = cols * Park.BAND * 3 + 2
            local path, seen = Park.Path(cols, n), {}
            eq(#path, n)
            for i, p in ipairs(path) do
                ok(p[1] >= 0 and p[1] < cols, "inside")
                local id = p[1] .. ":" .. p[2]
                no(seen[id], "each cell once"); seen[id] = true
                if i > 1 then
                    local q = path[i - 1]
                    eq(math.abs(p[1] - q[1]) + math.abs(p[2] - q[2]), 1, ("next to the one before (%d columns, cell %d)"):format(cols, i))
                end
            end
            -- Filled band by band: no row used before the one above it is full.
            local rows = {}
            for _, p in ipairs(path) do rows[p[2]] = (rows[p[2]] or 0) + 1 end
            for r = 0, math.floor((n - 1) / (cols * Park.BAND)) * Park.BAND - 1 do eq(rows[r], cols) end
        end
        -- One fence on every line between two families, and on the edge of the map; none inside a family.
        local grid, path = {}, Park.Path(7, 40)
        for i, p in ipairs(path) do
            grid[p[2]] = grid[p[2]] or {}
            grid[p[2]][p[1]] = ({ "cat", "farm", "owl", "bug" })[math.floor((i - 1) / 9) % 4 + 1] -- (runs of 9)
        end
        local drawn = {}
        for i, p in ipairs(path) do
            local f = Park.Fences(grid, p[1], p[2])
            if f.top then drawn["h" .. p[1] .. ":" .. p[2]] = (drawn["h" .. p[1] .. ":" .. p[2]] or 0) + 1 end
            if f.left then drawn["v" .. p[1] .. ":" .. p[2]] = (drawn["v" .. p[1] .. ":" .. p[2]] or 0) + 1 end
            if f.bottom then drawn["h" .. p[1] .. ":" .. (p[2] + 1)] = (drawn["h" .. p[1] .. ":" .. (p[2] + 1)] or 0) + 1 end
            if f.right then drawn["v" .. (p[1] + 1) .. ":" .. p[2]] = (drawn["v" .. (p[1] + 1) .. ":" .. p[2]] or 0) + 1 end
        end
        local function At(c, r) return grid[r] and grid[r][c] end
        for _, p in ipairs(path) do
            local c, r = p[1], p[2]
            for _, e in ipairs({ { "h" .. c .. ":" .. r, At(c, r - 1) }, { "h" .. c .. ":" .. (r + 1), At(c, r + 1) },
                { "v" .. c .. ":" .. r, At(c - 1, r) }, { "v" .. (c + 1) .. ":" .. r, At(c + 1, r) } }) do
                eq(drawn[e[1]], e[2] ~= grid[r][c] and 1 or nil, "line " .. e[1])
            end
        end
    end)

    test("enclosures on the map: a family's cells side by side, its tint under them, a fence where it ends", function()
        local w, ola = Setup()
        ola:OpenJournal({ sideTabs = 4 })
        ola:Page("Parken"):Open()
        -- By family (Scenes.ORDER: cats, rabbits, farm), the panda (none) last; by name within one.
        local cat = { Cell(ola, 40), Cell(ola, 41), Cell(ola, 42), Cell(ola, 46) }
        for _, c in ipairs(cat) do eq(c.family, "cat") end
        eq(Cell(ola, 72).family, "rabbit"); eq(Cell(ola, 84).family, "farm"); eq(Cell(ola, 5159).family, "default")
        -- The four cats down the first column and one on: their tint; the second (Bombay) fenced only on its
        -- left, the map's edge (above and below are cats; right, the rabbits draw that line).
        for _, c in ipairs(cat) do eq(c.pen.vertexColor[4], ola.ns.ParkPage.PEN_ALPHA, "its tint") end
        local bombay = Cell(ola, 40)
        ok(bombay.fences.left:IsShown()); no(bombay.fences.top:IsShown()); no(bombay.fences.bottom:IsShown())
        no(bombay.fences.right:IsShown())
        ok(bombay.posts.tl:IsShown()); ok(bombay.posts.bl:IsShown()); no(bombay.posts.tr:IsShown())
        eq(bombay.fences.left.tex, ola.ns.Icon("plank"))
    end)

    test("enclosures' signs: the family's mark, its homes on hover, a click shows only it; the pointer lights its family", function()
        local w, ola, kari = Setup()
        kari:Slash("adopter")
        w:Run(5)
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken"):Open()
        local Park = ola.ns.ParkPage
        local signs = page:Frames(function(f) return f.family ~= nil and f.mark ~= nil end)
        eq(#signs, 4, "cats, rabbits, farm, the rest")
        local cats
        for _, sg in ipairs(signs) do if sg.family == "cat" then cats = sg end end
        eq(cats.mark.tex, ola.ns.Icon("yarn"))
        -- Every family's mark is its card's ambience (one row in Decor.FAMILY), a shape, not a dot.
        for _, f in ipairs(ola.ns.Scenes.ORDER) do
            local tex = ola.ns.Decor.Mark(f)
            ok(tex ~= ola.ns.Icon("dot"), f .. ": a shape of its own")
            local spec = ola.ns.Decor.FAMILY[f]
            if not spec.mark then eq(tex, ola.ns.Icon(ola.ns.Decor.KINDS[spec.kind].tex), f .. ": its ambience's") end
        end
        eq(ola:TipOf(cats).text, "Katter / 1 av 4 har et hjem / Klikk for å vise bare dem.")
        eq(Park.FamilyName("spirit"), "Ånder"); eq(Park.FamilyName("default"), "Andre dyr")
        -- On its first corner: the cats' first cell's top left.
        local first = Cell(ola, 42) -- (Black Tabby: the first by name)
        eq(cats.points[1][4], first.points[1][4] + Park.SIGN_IN[1], "leaning in from its corner")
        eq(cats.points[1][5], first.points[1][5] - Park.SIGN_IN[2])
        eq(first.size[1], 40, "the whole cell takes the mouse, between the faces too")
        -- Hovered (the sign or a cat): the cats' tint brighter, the others' as they were.
        cats.scripts.OnEnter(cats)
        eq(Cell(ola, 41).pen.vertexColor[4], Park.PEN_LIT); eq(Cell(ola, 72).pen.vertexColor[4], Park.PEN_ALPHA)
        ok(cats.lit:IsShown(), "its sign lit too")
        cats.scripts.OnLeave(cats)
        no(cats.lit:IsShown())
        eq(Cell(ola, 41).pen.vertexColor[4], Park.PEN_ALPHA)
        local rabbit = Cell(ola, 72)
        rabbit.scripts.OnEnter(rabbit)
        eq(rabbit.pen.vertexColor[4], Park.PEN_LIT, "a pet lights its own family"); eq(Cell(ola, 41).pen.vertexColor[4], Park.PEN_ALPHA)
        no(cats.lit:IsShown())
        rabbit.scripts.OnLeave(rabbit)
        -- A click: the cats only; the others dimmed, their tints faint, their signs too; again, all.
        cats:Click()
        eq(page.frame.matches.text, "4 treff")
        eq(Cell(ola, 72).icon.alpha, Park.DIM); eq(Cell(ola, 72).pen.vertexColor[4], Park.PEN_EMPTY)
        ok(cats.chosen:IsShown())
        match(ola:TipOf(cats).text, "Klikk igjen for å vise alle%.$")
        cats:Click()
        eq(page.frame.matches.text, "")
        eq(Cell(ola, 72).icon.alpha, 0.55, "back: free, not filtered out")
        -- The search, too: a family it leaves empty fades.
        Park.filter.text = "tabby"; Park:Refresh()
        eq(Cell(ola, 84).pen.vertexColor[4], Park.PEN_EMPTY, "no farm animal matches")
        eq(Cell(ola, 41).pen.vertexColor[4], Park.PEN_ALPHA, "a cat does")
        Park.filter.text = ""; Park:Refresh()
        -- The grid's empty cells: the garden, a pen of its own with its lawn and fences, a piece on the first few.
        local plots = page:Frames(function(f) return f.art ~= nil and f.pen ~= nil end)
        ok(#plots > #Park.DECOR, "every empty cell")
        local pieces, fenced = 0, 0
        for _, pl in ipairs(plots) do
            if pl.art:IsShown() then pieces = pieces + 1 end
            eq(pl.pen.vertexColor[4], Park.LAWN[4])
            for _, t in pairs(pl.fences) do if t:IsShown() then fenced = fenced + 1 end end
        end
        eq(pieces, #Park.DECOR, "a small journal on a wide page: the rest is lawn")
        ok(fenced > 0, "fenced like the others")
    end)

    test("portraits in rings: the family's color, deeper with the bond, a glint and a shine higher up; none for a free one, gold for yours", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        kari:Slash("adopter")
        w:Run(5)
        ola:OpenJournal({ sideTabs = 4 })
        ola:Page("Parken"):Open()
        local panda, kitty, tabby = Cell(ola, 5159), Cell(ola, 41), Cell(ola, 42)
        eq(panda.icon.portrait, 20000 + 5159, "its own face, not the journal's icon")
        eq(panda.icon.tex, nil)
        ok(panda.icon.mask, "round")
        local cat = ola.ns.Scenes.TINT.cat
        local P = ola.ns.ParkPage
        eq(kitty.ring.vertexColor[2], P.RingColor("cat", 1)[2], "level 1: the family's color, lifted")
        ok(kitty.ring:IsShown()); no(kitty.glint:IsShown(), "no glint yet")
        eq(kitty.ring.vertexColor[4], P.RingColor("cat", 1)[4], "at full strength, not as filtered out")
        eq(panda.ring.vertexColor[1], ola.ns.Scenes.GOLD[1], "your own: gold")
        -- Deeper and brighter along the levels.
        local one, seven = P.RingColor("cat", 1), P.RingColor("cat", 7)
        ok(seven[1] >= one[1] and seven[3] <= one[3] and seven[4] > one[4], "level 7: deeper, brighter, stronger")
        no(tabby.ring:IsShown(), "free: no ring")
        ok(panda.mine:IsShown())
        -- Kari's bond grows to silver: her cat's ring follows, without a redraw of the rest.
        local now = ola.ns.Now()
        w:InjectMessage("Kari Berg", { k = "BOND", p = ola.ns.PROTOCOL, pet = "s:41", e = { p = 1500, f = now - 86400 * 30, t = now } })
        w:Run(1)
        local level = select(2, ola.ns.Bond:Of("s:41"))
        ok(level >= P.SHEEN_AT, "level " .. level)
        local kit = Cell(ola, 41)
        eq(kit.ring.vertexColor[2], P.RingColor("cat", level)[2], "a guildmate's bond: its ring, still the family's")
        ok(kit.glint:IsShown(), "a glint"); ok(kit.glint.pulse:IsPlaying(), "on its way")
        -- Now and then: a new wait after each flash, within GLINT_WAIT.
        local g, span = kit.glint.pulse, P.GLINT_WAIT
        g:Finish()
        ok(g:IsPlaying(), "again")
        ok(g.wait.duration >= span[1] and g.wait.duration <= span[2], "after a wait within GLINT_WAIT")
        ok(kit.sheen:IsShown(), "and a shine")
        no(panda.glint:IsShown(), "your own: its gold glow instead")
        -- A whole redraw (an adoption, the page opened again) keeps them so.
        ola.ns.ParkPage:Refresh()
        ok(Cell(ola, 41).glint:IsShown(), "after a redraw too")
        eq(Cell(ola, 41).ring.vertexColor[4], P.RingColor("cat", level)[4])
        -- No portrait call: the journal's icon, round as well.
        ola.env.SetPortraitTextureFromCreatureDisplayID = nil
        ola.ns.ParkPage:Refresh()
        eq(kitty.icon.tex, 1000 + 41, "the same cell, its journal icon")
        eq(kitty.icon.portrait, nil)
    end)

    test("the spotlight: today's pet on its card's backdrop, the one under the mouse while hovered, a click opens its card", function()
        local w, ola, kari = Setup()
        ola:OpenJournal({ sideTabs = 4 })
        local P = ola.ns.ParkPage
        ola:Page("Parken"):Open()
        ok(ola:Visible(ola.ns.L["park.spot.hint"]), "nobody's pet of the day yet: a hint")
        kari:Slash("adopter cornish"); w:Run(5)
        local today = ola.ns.Bonds:PetOfTheDay()
        eq(today, "s:41")
        ok(ola:Visible(ola.ns.L["park.spot.today"]), "today's pet, crowned")
        ok(ola:Visible("Cornish Rex Cat"))
        no(ola:Visible(ola.ns.L["park.spot.hint"]))
        local _, likes = P.spot.text.text:gsub(" · liker", "")
        eq(likes, 1, "its personality once (it was twice: 2026-11-15)")
        local scene = P.spot.scene
        eq(scene.actor.display, 20000 + 41, "its model")
        local lift = ola.ns.Moves:For("s:41", "lift")
        ok(lift and lift ~= 0, "the cat has a lift")
        eq(scene.actor.pos[3], lift, "lifted as on the card (Data/PetMoves.lua)")
        eq(scene.scripts.OnUpdate, nil, "its camera still a while after: an open park costs nothing")
        -- Under the mouse: the rabbit; the mouse gone, today's pet again in a moment.
        local rabbit = Cell(ola, 72)
        rabbit.scripts.OnEnter(rabbit)
        eq(scene.actor.display, 20000 + 72)
        ok(scene.scripts.OnUpdate, "the camera, for the new pet")
        w:Run(P.CAMERA_FOR + 0.1)
        eq(scene.scripts.OnUpdate, nil, "then still")
        ok(ola:Visible("Trenger et hjem"))
        no(ola:Visible(ola.ns.L["park.spot.today"]), "no crown on another pet")
        rabbit.scripts.OnLeave(rabbit)
        w:Run(0.5)
        eq(scene.actor.display, 20000 + 72, "not at once (the next icon may come)")
        w:Run(P.SPOT_BACK)
        eq(scene.actor.display, 20000 + 41, "today's pet again")
        -- Hovered, then the park closed (a click on the icon): it doesn't change pets unseen.
        rabbit.scripts.OnEnter(rabbit)
        eq(scene.actor.display, 20000 + 72)
        rabbit.scripts.OnLeave(rabbit)
        P.spot:Hide()
        w:Run(P.SPOT_BACK + 0.5)
        eq(scene.actor.display, 20000 + 72, "hidden: left as it was")
        P.spot:Show()
        eq(scene.actor.display, 20000 + 41, "shown again: today's pet")
        -- A click on the stage: its card.
        P.spot:Click()
        no(P:IsOpen())
        eq(ola.shownSpecies, 41)
    end)

    test("tooltips say where a pet comes from: the kind, and where when known (names from the data, prose from Locale)", function()
        local w, ola = Setup()
        ola:OpenJournal({ sideTabs = 4 })
        ola:Page("Parken"):Open()
        match(Tip(ola, Cell(ola, 40)), " / Kilde: Selger – Donni Anthania %(Elwynn Forest%) / ")
        match(Tip(ola, Cell(ola, 42)), " / Kilde: Drop / ")
        match(Tip(ola, Cell(ola, 5159)), " / Kilde: Kampanje – Blizzard%-butikken: Skyborne Epic Pack eller Warcraft Forever Collection / ")
    end)

    test("search and filters: what doesn't match is dimmed in place; names, owners and families match, sources don't", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        kari:Slash("adopter")
        w:Run(5)
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken"):Open()
        local P, f = ola.ns.ParkPage, page.frame
        local function Lit()
            local list = {}
            for _, c in ipairs(Cells(ola)) do
                if not (c.icon.desaturated and c.icon.alpha == P.DIM) then list[#list + 1] = SpeciesOf(c) end
            end
            table.sort(list)
            return table.concat(list, " ")
        end
        eq(Lit(), "40 41 42 46 72 84 5159", "no filter: the map as it was")
        eq(f.matches.text, "")
        ola:Type(f.search, "BOMBAY")
        eq(Lit(), "40", "a species' name, any case")
        eq(#Cells(ola), 7, "dimmed in place, not hidden")
        eq(f.matches.text, "1 treff")
        no(f.search.Instructions:IsShown(), "the template's own handler still runs")
        no(Cell(ola, 5159).mine:IsShown(), "a dimmed one shows no glow")
        ola:Type(f.search, "kari")
        eq(Lit(), "41", "who has it")
        ola:Type(f.search, " kari ")
        eq(Lit(), "41", "spaces around don't count")
        ola:Type(f.search, "donni")
        eq(Lit(), "", "not the source (the user: searching it was a mistake)")
        ola:Type(f.search, "selger")
        eq(Lit(), "")
        ola:Type(f.search, P.Fold(ola.ns.AchTexts.generic.families.rabbit))
        eq(Lit(), "72", "a family")
        ola:Type(f.search, "")
        eq(Lit(), "40 41 42 46 72 84 5159")
        ok(f.search.Instructions:IsShown())
        -- The toggles: no home; no home and yours.
        ola:Labeled("Trenger et hjem"):Click()
        eq(Lit(), "40 42 46 72 84", "nobody has adopted them")
        eq(f.matches.text, "5 treff")
        ola:Labeled("Kan adopteres"):Click()
        eq(Lit(), "40 72", "and Ola owns them")
        ola:Labeled("Trenger et hjem"):Click()
        eq(Lit(), "40 72", "adoptable alone means the same")
        ola:Type(f.search, "snowshoe")
        eq(Lit(), "72", "search and toggles together")
        -- Kari lets go of hers while the page is open: the filter follows.
        ola:Type(f.search, "")
        ola:Labeled("Kan adopteres"):Click()
        ola:Labeled("Trenger et hjem"):Click()
        kari:Slash("gislipp")
        w:Run(5)
        eq(Lit(), "40 41 42 46 72 84")
        match(Tip(ola, Cell(ola, 72)), "^Snowshoe Rabbit", "a tooltip still works on a match")
        eq(P.Fold("ÆØÅ Kari"), "æøå kari")
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
