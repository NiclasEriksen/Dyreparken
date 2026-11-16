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

    -- (hidden: true keeps "Skjul ukjente dyr" on, the default: 46 and 84, which nobody has, are question
    -- marks. The older tests look at every portrait: off.)
    local function Setup(hidden)
        local w = H.World({ members = H.FOLK }) -- (only members' adoptions are kept)
        local cs = {}
        for _, m in ipairs({ { "Ola Nord", { 5159, 40, 72 } }, { "Kari Berg", { 41 } }, { "Per Hansen", { 42 } } }) do
            local c = w:AddClient(m[1], { pets = m[2] })
            c:Companions(Fixture().species)
            if not hidden then c.ns.DB.global.settings.hideUnknown = false end
            cs[#cs + 1] = c
        end
        w:Run(20)
        return w, unpack(cs)
    end

    -- The park's icons as the player sees them: shown on the page, each with a species' portrait (the
    -- harness's GetPetInfoBySpeciesID gives species sid the display 20000 + sid), or on a client without
    -- portraits its journal icon (the file 1000 + sid).
    local function SpeciesOf(f)
        for _, t in ipairs(f.textures) do
            if t.shown and type(t.portrait) == "number" and H.SPECIES[t.portrait - 20000] then return t.portrait - 20000 end
            if t.shown and t.mask and type(t.tex) == "number" and H.SPECIES[t.tex - 1000] then return t.tex - 1000 end
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
        -- Yours: now and then paw prints walk out of its cell (the user, 2026-11-15); nobody else's.
        ok(panda.trail:IsShown()); ok(panda.trail.paws[1].walk:IsPlaying())
        no(kitty.trail:IsShown())
        ok(tabby.icon.desaturated, "free: grey"); eq(tabby.icon.alpha, 0.55)
        no(tabby.free:IsShown(), "Ola doesn't own it")
        ok(rabbit.free:IsShown(), "free, and Ola owns it: he could adopt it")
        -- Sorted by name; laid out in rows.
        eq(SpeciesOf(Cells(ola)[1]), 42, "Black Tabby Cat first")
        match(Tip(ola, kitty), "^Cornish Rex Cat / Flyttet inn hos Kari Berg i dag / Bånd: Bekjent %(level 1%) / %S+ og %S+ · liker [^/]* / Klikk for å se dyret%.$", "the traits by name; no effect paragraphs; no source without data")
        match(Tip(ola, rabbit), "Trenger et hjem / .* / Kilde: Quest – Waskily Wabbits! %(Dun Morogh%) / Du har dette dyret, og kan adoptere det%.")
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
        -- The ground's grain: one tile over TURF_CELLS cells each way, each cell its part by its place, so the
        -- grain runs on from cell to cell (a cell's right edge is the next one's left) and the tile repeats.
        local Park = ola.ns.ParkPage
        eq(bombay.pen.tex, ola.ns.Icon("turf"))
        eq(#bombay.pen.texCoord, 4)
        local n = Park.TURF_CELLS
        local a, b = { Park.Grain(0, 0) }, { Park.Grain(1, 0) }
        eq(a[1], 0); eq(a[2], b[1], "on to the right"); eq(a[4], ({ Park.Grain(0, 1) })[3], "on down")
        eq(Park.Grain(n, n), Park.Grain(0, 0), "the tile again")
        eq(({ Park.Grain(n - 1, 0) })[2], 1)
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
        eq(ola:TipOf(cats).text, "Katter / 1 av 4 har et hjem / " .. ola.ns.L["park.sign.show"])
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
        -- Chosen: bigger by its size (not a scale: that would move it off its post), its board gilded; and
        -- a click swings it on its post, coming to rest where it was.
        eq(cats.size[1], Park.SIGN_W * Park.CHOSEN_SCALE); eq(cats.board.vertexColor[1], Park.CHOSEN_TINT[1])
        for _, g in ipairs(cats.wobble) do ok(g:IsPlaying(), "it swings") end
        local turn = 0
        for _, step in ipairs(Park.SWING) do turn = turn + step[1] end
        eq(turn, 0, "back where it was")
        for _, g in ipairs(cats.wobble) do
            -- (each about its own top edge: an offset origin flung the mark off sideways in game)
            for _, an in ipairs(g.anims) do eq(an.origin[1], "TOP"); eq(an.origin[2], 0); eq(an.origin[3], 0) end
        end
        match(ola:TipOf(cats).text, "Klikk igjen for å vise alle%.$")
        cats:Click()
        eq(page.frame.matches.text, "")
        eq(cats.size[1], Park.SIGN_W); no(cats.chosen:IsShown())
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

    -- The user, 2026-11-15: "hidden details, like clicking a bush triggers an effect"; a rare surprise too.
    test("the garden's secrets: a click on a piece, a hop and a few particles; now and then a surprise", function()
        local w, ola = Setup()
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken")
        page:Open()
        local Park = ola.ns.ParkPage
        for _, piece in ipairs(Park.DECOR) do
            local g = Park.GARDEN[piece]
            ok(g, piece .. ": its secret")
            for _, b in ipairs({ g, unpack(g.surprise or {}) }) do ok(ola.ns.Decor.KINDS[b.kind], piece .. ": " .. b.kind) end
        end
        local plots = page:Frames(function(f) return f.art ~= nil and f.pen ~= nil end)
        local tree, lawn
        for _, pl in ipairs(plots) do
            if pl.piece == "tree" and not tree then tree = pl end
            if not pl.piece then lawn = pl end
        end
        eq(lawn.mouse, false, "bare lawn: the mouse goes through")
        ola:Dice(0.99)
        ola:Press(tree)
        eq(ola.ns.Fx:Playing(tree, "garden"), Park.GARDEN.tree.n, "its leaves")
        -- (tossed up out of the tree first, then settling a little: straight down read as too heavy)
        local leaf
        for _, f in ipairs(ola:Frames(function(f) return f.anim and f.anim.up and f:IsShown() end, tree)) do leaf = f end
        ok(leaf.anim.up.offset[2] > 0, "up first")
        ok(leaf.anim.drift.offset[2] < 0 and -leaf.anim.drift.offset[2] < leaf.anim.up.offset[2], "then down, less")
        ok(tree.hop:IsPlaying())
        ola:Press(tree)
        eq(ola.ns.Fx:Playing(tree, "garden"), Park.GARDEN.tree.n, "again at once: nothing more")
        w:Run(1); ola.ns.Fx:Stop(tree, "garden") -- (the harness plays no animation out by itself)
        ola:Dice(0)
        ola:Press(tree)
        local n = Park.GARDEN.tree.n
        for _, b in ipairs(Park.GARDEN.tree.surprise) do n = n + b.n end
        eq(ola.ns.Fx:Playing(tree, "garden"), n, "the surprise: a bird takes off")
        eq(#ola:Log("the tree's surprise"), 1)
        -- A sound with each click (2026-11-16): the piece's, and a chirp for the bird.
        local heard = ola.soundFiles
        eq(heard[1], Park.SOUNDS.tree[1], "a rustle of leaves")
        eq(heard[2], Park.SOUNDS.tree[1], "twice at once, to be heard (PlaySoundFile has no volume)")
        eq(ola.soundChannels[1], "SFX")
        eq(#heard, 5, "once a click: again at once was nothing, so no sound either; the surprise's chirp")
        local chirps = {}
        for _, id in ipairs(Park.SURPRISE_SOUNDS.tree) do chirps[id] = true end
        ok(chirps[heard[5]], "a bird's chirp")
        eq(ola.soundChannels[5], "Ambience", "the birds a little softer, on the ambience's slider")
        -- A file the client lacks: the next one; none at all: silence, no error.
        local stump
        for _, pl in ipairs(plots) do if pl.piece == "stump" then stump = pl end end
        ola.missingSounds = { [Park.SOUNDS.stump[1]] = true }
        ola:Dice(0.99)
        ola:Press(stump)
        eq(heard[#heard], Park.SOUNDS.stump[2], "the next one that plays")
        ok(heard[#heard - 1] ~= Park.SOUNDS.stump[2], "the knock only once: loud enough")
        for _, id in ipairs(Park.SOUNDS.stump) do ola.missingSounds[id] = true end
        local before = #heard
        w:Run(1)
        ola:Press(stump)
        eq(#ola.soundFiles, before, "none plays: silence")
    end)

    -- The user, 2026-11-15: "Oh yes I like it": every piece clicked within a short while, the whole garden goes off.
    test("the garden's hidden extra: every piece clicked in a short while, and they all burst at once", function()
        local w, ola = Setup()
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken")
        page:Open()
        local Park = ola.ns.ParkPage
        local byPiece, all = {}, {}
        for _, pl in ipairs(page:Frames(function(f) return f.art ~= nil and f.pen ~= nil end)) do
            if pl.piece then byPiece[pl.piece] = byPiece[pl.piece] or pl; all[#all + 1] = pl end
        end
        ola:Dice(0.99)
        local kinds = {}
        for piece in pairs(byPiece) do kinds[#kinds + 1] = piece end
        table.sort(kinds)
        -- All but one, then a wait too long: the first ones are forgotten.
        for i = 1, #kinds - 1 do ola:Press(byPiece[kinds[i]]); w:Run(1) end
        w:Run(Park.ALL_WITHIN + 1)
        ola:Press(byPiece[kinds[#kinds]])
        eq(#ola:Log("the whole garden"), 0, "too slow")
        for _, pl in ipairs(all) do ola.ns.Fx:Stop(pl, "garden") end
        local before = #(ola.soundFiles or {})
        local want = 1
        for i = 1, #kinds - 1 do ola:Press(byPiece[kinds[i]]); w:Run(1); want = want + (Park.SOUNDS[kinds[i]].times or 1) end
        eq(#ola:Log("the whole garden"), 1, "every piece within the while")
        eq(#ola.soundFiles - before, want, "a sound a click, and one chirp for the whole garden, not one a piece")
        for _, pl in ipairs(all) do
            ok(ola.ns.Fx:Playing(pl, "garden") > Park.GARDEN[pl.piece].n, pl.piece .. ": its surprise too")
        end
    end)

    test("the garden by the clock and the calendar: night's fireflies, December's snow, the season's lawn and leaves", function()
        local w, ola = Setup()
        local Park = ola.ns.ParkPage
        w:SetDate(2026, 10, 15, 23) -- an autumn night
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken")
        page:Open()
        local plots = page:Frames(function(f) return f.art ~= nil and f.pen ~= nil end)
        local lawn = Park.LAWNS.autumn
        for _, pl in ipairs(plots) do
            ok(pl.firefly:IsShown()); no(pl.snow:IsShown())
            eq(pl.pen.vertexColor[2], lawn[2] * Park.NIGHT_DIM, "autumn's lawn, darker at night")
        end
        -- A redraw (a letter typed in the search) leaves them where they are (2026-11-16, the performance pass:
        -- every redraw moved the fireflies and started the snow over).
        local at = plots[1].firefly.points[1]
        ola:Type(page.frame.search, "k")
        eq(plots[1].firefly.points[1], at, "the firefly stays put")
        ola:Type(page.frame.search, "")
        local leaves = Park.Poke("tree", 0.99, Park.Weather())
        eq(leaves[1].kind, "leaf"); eq(leaves[1].color, Park.AUTUMN)
        page.frame:Hide()
        w:SetDate(2026, 12, 3, 12) -- a December day
        page:Open()
        for _, pl in ipairs(plots) do
            no(pl.firefly:IsShown()); ok(pl.snow:IsShown()); ok(pl.snow.fall:IsPlaying())
            eq(pl.pen.vertexColor[2], Park.LAWNS.winter[2])
        end
        local plays = plots[1].snow.fall.plays
        ola:Type(page.frame.search, "k")
        eq(plots[1].snow.fall.plays, plays, "the snow falls on, not started over")
        ola:Type(page.frame.search, "")
        eq(Park.Poke("bush", 0.99, Park.Weather())[1].kind, "snow", "winter: snow off the bushes")
        eq(Park.Poke("pond", 0.99, Park.Weather())[1].kind, "bubble")
        page.frame:Hide()
        w:SetDate(2027, 7, 1, 12)
        page:Open()
        no(plots[1].snow:IsShown()); no(plots[1].firefly:IsShown())
        eq(Park.Poke("tree", 0.99, Park.Weather())[1].color, Park.GARDEN.tree.color)
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
        -- A redraw draws no portrait again: each is drawn as its cell gets its pet (2026-11-16, the performance
        -- pass: every redraw drew all of them, on every letter typed in the search).
        local drawn, draw = 0, ola.env.SetPortraitTextureFromCreatureDisplayID
        ola.env.SetPortraitTextureFromCreatureDisplayID = function(...) drawn = drawn + 1; return draw(...) end
        ola.ns.ParkPage:Refresh()
        ola:Type(ola:Page("Parken").frame.search, "kat")
        eq(drawn, 0, "a redraw, a search: no portrait drawn again")
        ola.env.SetPortraitTextureFromCreatureDisplayID = draw
        -- A client with no portrait call: the journal's icon, round as well.
        local w2, other = Setup()
        w2:Run(5)
        other.env.SetPortraitTextureFromCreatureDisplayID = nil
        other:OpenJournal({ sideTabs = 4 })
        other:Page("Parken"):Open()
        eq(Cell(other, 41).icon.tex, 1000 + 41, "its journal icon")
        eq(Cell(other, 41).icon.portrait, nil)
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
        -- Placed by its feet, as on the card (Data/PetScenes.lua: its scene's floor; the stubs' scene is 1271).
        eq(select(3, scene.actor:IsUsingCenterForOrigin()), false)
        eq(scene.actor.pos[3], ola.ns.PetScenes.card[1271].floor, "its feet on its scene's floor")
        -- The card's shadow under it, where the card's lands in this view.
        local floor = P.spot.card.floor
        ok(floor:IsShown(), "a shadow under the pet")
        eq(floor.points[1][2], scene); eq(floor.points[1][5], P.SHADOW.y)
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
        match(Tip(ola, Cell(ola, 40)), " / Kilde: " .. ola.ns.L["source.vendor"] .. " – Donni Anthania %(Elwynn Forest%) / ")
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
        ola:Type(f.search, "kari b")
        eq(Lit(), "41", "the whole name, from its start")
        ola:Type(f.search, "ka")
        ok(Lit():find("41"), "from the start of the name")
        ola:Type(f.search, "berg")
        eq(Lit(), "", "not the surname alone (2026-11-16: \"as\" found the user's pet by Hjelp Plask)")
        ola:Type(f.search, "ari")
        eq(Lit(), "", "nor the middle of a name")
        ola:Type(f.search, "donni")
        eq(Lit(), "", "not the source (the user: searching it was a mistake)")
        ola:Type(f.search, P.Fold(ola.ns.L["source.vendor"]))
        eq(Lit(), "")
        ola:Type(f.search, P.Fold(ola.ns.AchTexts.generic.families.rabbit))
        eq(Lit(), "72", "a family")
        ola:Type(f.search, "")
        eq(Lit(), "40 41 42 46 72 84 5159")
        ok(f.search.Instructions:IsShown())
        -- The toggles: no home; no home and yours.
        ola:Labeled(ola.ns.L["park.filter.free"]):Click()
        eq(Lit(), "40 42 46 72 84", "nobody has adopted them")
        eq(f.matches.text, "5 treff")
        ola:Labeled("Kan adopteres"):Click()
        eq(Lit(), "40 72", "and Ola owns them")
        ola:Labeled(ola.ns.L["park.filter.free"]):Click()
        eq(Lit(), "40 72", "adoptable alone means the same")
        ola:Type(f.search, "snowshoe")
        eq(Lit(), "72", "search and toggles together")
        -- Kari lets go of hers while the page is open: the filter follows.
        ola:Type(f.search, "")
        ola:Labeled("Kan adopteres"):Click()
        ola:Labeled(ola.ns.L["park.filter.free"]):Click()
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
        match(Tip(ola, cell), "Klikk for å se dyret%.")
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
        eq(ola:CountPrinted(ola.ns.T("park.combat_hint", { pet = ola.ns.Pets:NameOfKey("s:72") })), 1,
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

    -- Unknown pets (2026-11-15, the user): nobody in the guild has 46 or 84.
    test("a pet nobody in the guild has is a question mark: no name, a wiggle, no stage; the setting shows it", function()
        local w, ola, kari = Setup(true)
        ola:OpenJournal({ sideTabs = 4 })
        local page = ola:Page("Parken"):Open()
        local f = page.frame
        local function Marks()
            return page:Frames(function(fr)
                for _, fs in ipairs(fr.fontStrings) do if fs.shown and fs.text == "?" then return true end end
            end)
        end
        local function Mark(cell)
            for _, fs in ipairs(cell.fontStrings) do if fs.text == "?" then return fs end end
        end
        eq(#Marks(), 2, "the White Kitten and the Westfall Chicken")
        eq(#Cells(ola), 5, "no portrait for them")
        -- A known one's tooltip names who else has it, as the card's home line does.
        match(Tip(ola, Cell(ola, 41)), "Kari Berg har dette dyret%.")
        local bombay = Tip(ola, Cell(ola, 40))
        no(bombay:find("Berg har", 1, true) or bombay:find("Hansen har", 1, true), "only Ola has a Bombay")
        ok(page:Text("?: ingen har det ennå."), "the legend")
        local cell = Marks()[1]
        local tip = Tip(ola, cell)
        eq(tip, "??? / Ingen i guilden har funnet dette dyret ennå.")
        for _, sid in ipairs({ 46, 84 }) do no(tip:find(H.SPECIES[sid], 1, true), "no name") end
        -- Hover: the stage passes it by. Click: it wiggles, and stays in the park.
        cell.scripts.OnEnter(cell)
        no(page:Text("White Kitten")); no(page:Text("Westfall Chicken"))
        cell.scripts.OnLeave(cell)
        cell:Click()
        ok(page:IsOpen(), "no card: nothing to show")
        local g = Mark(cell).animGroups[1]
        ok(g:IsPlaying(), "a wiggle")
        local sum = 0
        for _, a in ipairs(g.anims) do sum = sum + a.offset[1] end
        eq(sum, 0, "it comes home")
        -- A search by name can't tell which is which.
        ola:Type(f.search, "kitten")
        eq(f.matches.text, "0 treff")
        ola:Type(f.search, "")
        -- Kari finds a chicken: the park shows it, at once.
        kari:GivePet(84)
        kari:Fire("NEW_PET_ADDED", kari:GuidOf(84))
        w:Run(ola.ns.Config.OWN_LEARN_DELAY + 1)
        eq(#Marks(), 1)
        ok(Cell(ola, 84), "its portrait")
        -- "Skjul ukjente dyr" off: the White Kitten's portrait too, and the legend says nothing of marks.
        ola.ns.Settings.cog:Click()
        local box = ola:Page("Innstillinger"):Labeled("Skjul ukjente dyr")
        ok(box:GetChecked(), "on by default")
        box:Click()
        eq(ola.env.DyreparkenDB.settings.hideUnknown, false)
        page:Open()
        eq(#Marks(), 0)
        eq(#Cells(ola), 7)
        no(page:Text("ingen har det"))
    end)
end
