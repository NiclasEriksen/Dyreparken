-- The pet card's decorations (Menagerie/Decor.lua): more with every bond
-- level, particles from the pet's traits and the date, all played by the
-- client's animation groups and stopped when the card has nothing to show.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    -- An everyday kind's count at a bond level (Decor.Density: 70% at 1, all at 7).
    local function N(D, n, level) return math.max(1, math.floor(n * D.Density(level) + 0.5)) end
    local PANDA = "s:5159"

    -- Ola, the journal open, the panda's traits given (by id; none: no
    -- particles of their own). The families' ambience is left out here, so
    -- the counts are the traits' and the bond's (it has tests of its own).
    local function Setup(...)
        local ids = { ... }
        local w, ola = H.Setup{ ola = { 5159, 40 }, settle = "bond", journal = true, each = function(c)
            c.ns.Decor.FAMILY, c.ns.Decor.FAMILY_ART = {}, {}
            c.ns.Bonds.PetOfTheDay = function() return nil end -- (its halo has a test of its own: 34_touches.lua)
            c.ns.Personality.Traits = function()
                local list = {}
                for _, id in ipairs(ids) do list[#list + 1] = c.ns.Personality.ById(id) end
                return list
            end
        end }
        local card = ola:SelectPet(5159)
        return w, ola, card, card.decor
    end

    -- Move the clock to a date and hour (keeping the harness's own counting).
    local function At(w, ola, month, day, hour)
        local now = ola.ns.Now()
        local t = os.date("*t", now)
        t.month, t.day, t.hour, t.min = month, day, hour, 0
        w:Skip(os.time(t) - now)
    end

    local function Parts(d)
        local list = {}
        for _, t in ipairs(d.parts) do
            if t:IsShown() then list[#list + 1] = t end
        end
        return list
    end

    local function Playing(d)
        local n = 0
        for _, t in ipairs(d.parts) do if t.anim:IsPlaying() then n = n + 1 end end
        return n
    end

    test("every bond level adds something you can see; nothing for a pet nobody holds", function()
        local w, ola, card, d = Setup()
        At(w, ola, 9, 21, 12) -- a Monday in September, at noon: no dated extras
        local D = ola.ns.Decor
        local cat = ola.ns.Scenes.TINT.cat
        local function Level(n) D:Apply(card, PANDA, n, cat) end
        local function Color(t) return t.vertexColor end
        Level(nil)
        for _, e in ipairs(d.edges) do no(e:IsShown()) end
        eq(#Parts(d), 0)
        Level(1)
        no(d.border:IsShown())
        no(d.wash[1]:IsShown())
        Level(2)
        ok(d.border:IsShown(), "a border: the picked frame")
        eq(d.border.atlas, "loottoast-itemborder-gold")
        eq(table.concat(d.border.slice, ","), "18,18,18,18", "nine-sliced around the card")
        eq(d.border.sliceMode, 0)
        for i = 1, 4 do no(d.edges[i]:IsShown(), "no drawn edges where it slices"); ok(d.wash[i]:IsShown(), "a wash") end
        ok(d.border.desaturated)
        eq(Color(d.border)[1], math.min(1, cat[1] * 1.7), "in the family's color")
        no(d.corners.TOPLEFT:IsShown())
        Level(3)
        local n = 0
        for point, t in pairs(d.corners) do ok(t:IsShown(), point); n = n + 1 end
        eq(n, 4)
        eq(d.corners.TOPLEFT.tex, D.ART.corner, "the code's corner")
        ok(d.corners.TOPLEFT.desaturated, "silver corners")
        eq(Color(d.border)[3], 1, "a silver border")
        no(d.glows[1]:IsShown())
        Level(4)
        for _, g in ipairs(d.glows) do ok(g:IsShown()); ok(g.breathe:IsPlaying(), "it breathes") end
        eq(d.glows[1].breathe.a.toAlpha, 1, "at full strength at its peak")
        eq(#Parts(d), 0)
        Level(5)
        no(d.corners.TOPLEFT.desaturated, "gilded corners")
        no(d.border.desaturated, "the frame's own gold"); eq(Color(d.border)[3], 1)
        eq(Color(d.glows[1])[3], 0.25, "a gold glow")
        eq(#Parts(d), 6, "sparks")
        eq(Parts(d)[1].icon.tex, D.MEDIA .. "sparkle")
        eq(Playing(d), 6)
        no(d.ribbon:IsShown()); no(d.rays:IsShown())
        Level(6)
        ok(d.ribbon:IsShown()); eq(d.ribbonText.text, "Uatskillelig")
        ok(d.rays:IsShown()); ok(d.rays.turn:IsPlaying(), "turning rays")
        local slow = d.rays.turn.a.duration
        no(d.border.shimmer:IsPlaying())
        Level(7)
        eq(d.ribbonText.text, "Sjelevenn")
        eq(#Parts(d), 10, "sparks and hearts")
        ok(d.border.shimmer:IsPlaying(), "the gold edge glows")
        ok(d.rays.turn.a.duration < slow, "the rays turn faster")
        -- Back down: everything above goes.
        Level(1)
        no(d.ribbon:IsShown()); no(d.glows[1]:IsShown()); no(d.glows[1].breathe:IsPlaying())
        no(d.rays.turn:IsPlaying()); no(d.border.shimmer:IsPlaying())
        eq(#Parts(d), 0); eq(Playing(d), 0)
    end)

    test("each kind of particle moves its own way, on a timeline that never shows it standing still", function()
        local w, ola, card, d = Setup("dykker", "nattugle")
        local D = ola.ns.Decor
        At(w, ola, 9, 21, 12)
        D:Apply(card, PANDA, 1)
        local parts = Parts(d)
        eq(#parts, N(D, 4, 1), "a Dykker's bubbles (thinned at level 1); no stars by day")
        eq(parts[1].icon.tex, D.MEDIA .. "bubble")
        local g = parts[1].anim
        ok(g:IsPlaying()); eq(g.looping, "REPEAT")
        -- The timeline: wait unseen, move and fade in, move on and fade out.
        eq(parts[1].alpha, 0, "unseen at rest")
        eq(g.hold.order, 1); eq(g.hold.fromAlpha, 0); eq(g.hold.toAlpha, 0)
        eq(g.moveA.order, 2); eq(g.fadeIn.order, 2); eq(g.moveB.order, 3); eq(g.fadeOut.order, 3)
        for _, a in ipairs(g.anims) do eq(a.startDelay, nil, "no delays inside a step") end
        ok(g.moveA.offset[2] + g.moveB.offset[2] > 0, "bubbles rise")
        ok(parts[2].anim.hold.duration > g.hold.duration, "one after another")
        ok(parts[1].sway:IsPlaying(), "and wobble"); no(parts[1].spin:IsPlaying())
        -- Leaves sway and rock on the way down; hearts beat; confetti spins.
        local function Kind(trait, kind)
            ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById(trait) } end
            D:Apply(card, PANDA, 1)
            local p = Parts(d)[1]
            eq(p.icon.tex, D.MEDIA .. D.KINDS[kind].tex)
            return p
        end
        local leaf = Kind("gronnfinger", "leaf")
        ok(leaf.anim.moveA.offset[2] < 0, "leaves fall")
        ok(leaf.sway:IsPlaying()); ok(leaf.tilt:IsPlaying())
        -- Swings loop seamlessly: steps that add up to nothing, never BOUNCE (it blinked).
        local function Sum(g, f) local n = 0; for _, a in ipairs(g.steps) do n = n + f(a) end; return n end
        eq(leaf.sway.looping, "REPEAT")
        ok(leaf.sway.steps[1].offset[1] ~= 0, "it does sway")
        ok(math.abs(Sum(leaf.sway, function(a) return a.offset[1] end)) < 1e-9, "and comes home")
        ok(math.abs(Sum(leaf.tilt, function(a) return a.degrees end)) < 1e-9)
        eq(leaf.tilt.steps[1].smoothing, "OUT"); eq(leaf.tilt.steps[3].smoothing, "IN", "a pendulum")
        local heart = Kind("kosete", "heart")
        ok(heart.throb:IsPlaying()); no(heart.sway:IsPlaying(), "only what it does")
        local up, down = heart.throb.steps[1].scale[1], heart.throb.steps[2].scale[1]
        eq(up, 1.25); ok(math.abs(up * down - 1) < 1e-9, "a beat that ends at its own size")
        eq(heart.throb.looping, "REPEAT")
        eq(heart.anim, heart.plain, "no scale on its path: the beat is the only scaling (it flickered)")
        no(heart.plain.grow)
        At(w, ola, 5, 17, 12)
        local confetti = Kind("festglad", "confetti")
        ok(confetti.spin:IsPlaying()); ok(confetti.sway:IsPlaying())
        ok(Parts(d)[1].icon.vertexColor[1] ~= Parts(d)[4].icon.vertexColor[1] or Parts(d)[1].icon.vertexColor[3] ~= Parts(d)[4].icon.vertexColor[3],
            "in many colors")
        -- Sparks fly out from the pet, quickly, shrinking.
        At(w, ola, 9, 21, 12)
        ola.ns.Personality.Traits = function() return {} end
        D:Apply(card, PANDA, 5)
        local spark = Parts(d)[1]
        eq(spark.icon.tex, D.MEDIA .. "sparkle")
        ok(spark.anim.moveA.duration < 1, "fast"); eq(spark.anim.moveA.smoothing, "OUT")
        eq(spark.anim.grow.scaleTo[1], 0.3); ok(spark.spin:IsPlaying())
        -- Stars twinkle in place at night.
        At(w, ola, 9, 21, 23)
        local star = Kind("nattugle", "star")
        eq(star.anim.moveA.offset[1], 0); eq(star.anim.moveA.offset[2], 0)
        eq(star.anim.grow.scaleTo[1], 1.6)
        -- Not on a holiday any more: no confetti. December: snow for everyone.
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("festglad") } end
        At(w, ola, 3, 18, 12) -- (March: no season's particles)
        D:Apply(card, PANDA, 1)
        eq(#Parts(d), 0, "not a holiday")
        At(w, ola, 12, 3, 12)
        D:Apply(card, PANDA, 1)
        eq(#Parts(d), N(D, 5, 1)); eq(Parts(d)[1].icon.tex, D.MEDIA .. "snowflake")
        ok(Parts(d)[1].spin:IsPlaying())
    end)

    test("one moving group per layer, for every kind: two groups on one region fight (seen in game)", function()
        local w, ola, card, d = Setup()
        At(w, ola, 12, 24, 23) -- julaften at night in December
        local D = ola.ns.Decor
        local all = {}
        for id in pairs(D.TRAITS) do all[#all + 1] = id end
        local i = 0
        ola.ns.Personality.Traits = function()
            i = i + 1
            return { ola.ns.Personality.ById(all[(i - 1) % #all + 1]) }
        end
        for _ = 1, #all do
            for _, level in ipairs({ 1, 5, 7 }) do
                D:Apply(card, PANDA, level)
                for _, p in ipairs(Parts(d)) do
                    local by = {}
                    for _, g in ipairs(p.groups) do
                        if g:IsPlaying() then
                            local region = g.parent
                            by[region] = (by[region] or 0) + 1
                            eq(by[region], 1, "one group per region")
                        end
                    end
                    ok(p.anim:IsPlaying())
                    eq(p.anim.parent, p, "the path on the holder")
                    if p.sway:IsPlaying() then eq(p.sway.parent, p.inner) end
                end
            end
        end
        for name, k in pairs(D.KINDS) do
            local n = (k.spin and 1 or 0) + (k.tilt and 1 or 0) + (k.throb and 1 or 0)
            ok(n <= 1, name .. ": spin, tilt and throb share the texture")
        end
    end)

    test("no BOUNCE loops anywhere on the card (they blinked where they turned)", function()
        local w, ola, card, d = Setup("dykker", "gronnfinger")
        At(w, ola, 12, 24, 23)
        ola.ns.Decor:Apply(card, PANDA, 7)
        local seen = 0
        local function Check(region)
            for _, g in ipairs(region.animGroups or {}) do
                seen = seen + 1
                ok(g.looping ~= "BOUNCE", "a BOUNCE loop")
            end
        end
        for _, p in ipairs(d.parts) do Check(p); Check(p.inner); Check(p.icon) end
        for _, t in ipairs(d.glows) do Check(t) end
        Check(d.border); Check(d.rays)
        ok(seen > 100)
        eq(d.glows[1].breathe.looping, "REPEAT")
        eq(d.border.shimmer.a.toAlpha, 1)
    end)

    test("never more particles than the pool; the same pet keeps its layout", function()
        local w, ola, card, d = Setup("dykker", "kosete")
        local D = ola.ns.Decor
        At(w, ola, 12, 24, 23) -- julaften, at night, in December
        D.TRAITS.kosete = { kind = "heart", n = 40, color = { 1, 0, 0 } }
        D:Apply(card, PANDA, 7)
        eq(#Parts(d), #d.parts, "capped at the pool")
        D.TRAITS.kosete = { kind = "heart", n = 2, color = { 1, 0, 0 } }
        D:Apply(card, PANDA, 5)
        local first = Parts(d)[1].points[1][4]
        D:Apply(card, "s:40", 5)
        D:Apply(card, PANDA, 5)
        eq(Parts(d)[1].points[1][4], first, "the panda's bubbles are where they were")
    end)

    test("on the card: the holder's level shows, the tooltip says what's next, and hiding stops it all", function()
        local w, ola, card, d = Setup("dykker")
        At(w, ola, 9, 21, 12)
        ola:Slash("adopter panda")
        w:Run(5)
        local g = ola.ns.DB:Guild()
        local now = ola.ns.Now()
        g.life[PANDA] = { ["Ola Nord"] = { p = 600, f = now - 200 * 86400, t = now } } -- God venn: level 4
        card = ola:SelectPet(5159)
        ok(d.glows[1]:IsShown()); ok(d.corners.TOPLEFT:IsShown())
        eq(#Parts(d), N(ola.ns.Decor, 4, 4), "the Dykker's bubbles")
        card.bond.scripts.OnEnter(card.bond)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "På nivå 5 får kortet gull overalt, og gnister som flyr%.")
        -- Nobody's pet: the card's decorations go, the traits' stay.
        card = ola:SelectPet(40)
        no(d.glows[1]:IsShown()); no(d.corners.TOPLEFT:IsShown())
        -- No pet selected: nothing.
        card = ola:SelectPet(5159)
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        eq(#Parts(d), 0); eq(Playing(d), 0); no(d.glows[1]:IsShown())
        -- Closing the journal stops every animation.
        card = ola:SelectPet(5159)
        ok(Playing(d) > 0)
        local extra = Parts(d)[1].sway
        ok(extra:IsPlaying())
        c:Hide()
        eq(Playing(d), 0); no(d.glows[1].breathe:IsPlaying()); no(extra:IsPlaying())
    end)

    test("/dp probe level <n> dresses the card as that level, until off", function()
        local w, ola, card, d = Setup()
        At(w, ola, 9, 21, 12)
        no(d.ribbon:IsShown())
        ola:Slash("probe level 7")
        ok(ola:Printed("The card shows level 7 (Sjelevenn)", true))
        ok(d.ribbon:IsShown(), "any pet, even one nobody holds")
        ola:Slash("probe level 3")
        no(d.ribbon:IsShown()); ok(d.corners.TOPLEFT:IsShown())
        ola:Slash("probe level off")
        ok(ola:Printed("The card shows the real level again.", true))
        no(d.corners.TOPLEFT:IsShown())
        ola:Slash("probe level 99")
        no(d.corners.TOPLEFT:IsShown(), "out of range: off")
    end)

    test("the corner is mirrored by its atlas coordinates; without slicing, drawn edges", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        ola.atlases = { ["AdventuresFrame-Corner-Small-TopLeft"] = true }
        ola.env.Enum.UITextureSliceMode = nil -- a client that can't nine-slice
        ola.ns.Decor.FAMILY_ART = {}
        ola.ns.Decor.ART.corner = "AdventuresFrame-Corner-Small-TopLeft" -- (an atlas, for this test)
        w:Run(20)
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        local d = card.decor
        local file = ola.env.C_Texture.GetAtlasInfo("AdventuresFrame-Corner-Small-TopLeft").file
        eq(d.corners.TOPLEFT.atlas, "AdventuresFrame-Corner-Small-TopLeft", "the original as it is")
        eq(d.corners.BOTTOMRIGHT.tex, file)
        eq(table.concat(d.corners.BOTTOMRIGHT.texCoord, ","), "0.5,0.25,0.375,0.125", "mirrored both ways")
        eq(table.concat(d.corners.TOPRIGHT.texCoord, ","), "0.5,0.25,0.125,0.375")
        eq(table.concat(d.corners.BOTTOMLEFT.texCoord, ","), "0.25,0.5,0.375,0.125")
        no(d.sliced)
        ola.ns.Decor:Apply(card, PANDA, 2, { 0.5, 0.5, 0.5 })
        no(d.border:IsShown())
        for _, e in ipairs(d.edges) do ok(e:IsShown(), "drawn edges instead") end
    end)

    test("every pet has its family's ambience, always, soft, and last in the pool", function()
        local w, ola = H.Setup{ ola = { 5159, 40 }, settle = "bond", journal = true, each = function(c)
            c.ns.Personality.Traits = function() return {} end
        end }
        local D = ola.ns.Decor
        At(w, ola, 9, 21, 12)
        local card = ola:SelectPet(40) -- a Bombay: a cat, nobody's
        local d = card.decor
        local parts = Parts(d)
        eq(#parts, N(D, D.FAMILY.cat.n), "a cat's motes, with no bond at all (thinned)")
        eq(parts[1].icon.tex, D.MEDIA .. "dot")
        eq(parts[1].icon.blend, "ADD", "motes are light")
        eq(parts[1].icon.vertexColor[4], D.FAMILY_ALPHA, "softer than the traits")
        ok(parts[1].anim:IsPlaying())
        card = ola:SelectPet(5159) -- the panda has no family: the default
        eq(#Parts(d), N(D, D.FAMILY.default.n))
        -- Every family has one, and each is a kind there is.
        for _, family in ipairs(ola.ns.Scenes.ORDER) do
            local spec = D.FAMILY[family]
            ok(spec, family .. " has an ambience")
            ok(D.KINDS[spec.kind], family .. ": " .. spec.kind)
        end
        -- When the pool runs out, it's the ambience that goes.
        D.TRAITS.kosete = { kind = "heart", n = 60, color = { 1, 0, 0 } } -- (42 at level 1: still past the pool)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("kosete") } end
        D:Apply(card, PANDA, 1)
        eq(#Parts(d), #d.parts)
        for _, p in ipairs(Parts(d)) do eq(p.icon.tex, D.MEDIA .. "heart") end
    end)

    test("every trait shows itself; the ones with a moment only then", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 }, settle = "bond", journal = true, each = function(c)
            c.ns.Decor.FAMILY = {}
        end }
        local D, P = ola.ns.Decor, ola.ns.Personality
        for _, t in ipairs(P.TRAITS) do
            local spec = D.TRAITS[t.id]
            ok(spec, t.id .. " has particles")
            ok(D.KINDS[spec.kind], t.id .. ": " .. spec.kind)
        end
        -- Every texture a kind uses is drawn (tools/draw_particles.py).
        for name, k in pairs(D.KINDS) do
            local f = io.open("Media/Particles/" .. k.tex .. ".tga", "rb")
            ok(f, name .. ": Media/Particles/" .. k.tex .. ".tga"); if f then f:close() end
            local n = (k.spin and 1 or 0) + (k.tilt and 1 or 0) + ((k.throb or k.flap) and 1 or 0)
            ok(n <= 1, name .. ": spin, tilt, throb and flap share the texture")
        end
        At(w, ola, 9, 21, 12)
        local card = ola:SelectPet(5159)
        local d = card.decor
        local function With(id)
            P.Traits = function() return { P.ById(id) } end
            D:Apply(card, PANDA, 1)
            return Parts(d)
        end
        eq(#With("flokkdyr"), 0, "alone: no flock")
        eq(#With("einstoing"), 1, "a lone wisp")
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        eq(#With("flokkdyr"), N(D, D.TRAITS.flokkdyr.n, 1), "with a guildmate")
        eq(#With("einstoing"), 0)
        eq(#With("friluftsdyr"), N(D, 2, 1), "butterflies outdoors")
        eq(#With("huleboer"), 0)
        ola.state.instance = "party"
        eq(#With("huleboer"), N(D, 3, 1), "drips in a dungeon")
        eq(#With("friluftsdyr"), 0)
        eq(#With("nattugle"), 0, "stars only at night")
        At(w, ola, 9, 21, 23)
        eq(#With("nattugle"), N(D, 5, 1))
    end)

    test("the new motions: wings flap, z's grow from the pet, wind blows across, embers glow", function()
        local w, ola, card, d = Setup()
        local D, P = ola.ns.Decor, ola.ns.Personality
        At(w, ola, 9, 21, 12)
        local function With(id)
            P.Traits = function() return { P.ById(id) } end
            D:Apply(card, PANDA, 1)
            return Parts(d)[1]
        end
        local fly = With("friluftsdyr")
        eq(fly.icon.tex, D.MEDIA .. "butterfly")
        ok(fly.throb:IsPlaying())
        eq(fly.throb.steps[1].scale[2], 1, "a flap: across only")
        ok(math.abs(fly.throb.steps[1].scale[1] * fly.throb.steps[2].scale[1] - 1) < 1e-9, "and open again")
        ok(fly.sway:IsPlaying())
        local z = With("latsabb")
        eq(z.icon.tex, D.MEDIA .. "zee")
        local width = d.panel:GetWidth() or 400
        ok(math.abs(z.points[1][4] - width / 2) <= 50, "from around the pet")
        ok(z.anim.moveA.offset[2] > 0, "rising"); eq(z.anim.grow.scaleTo[1], 1.8, "and growing")
        local cloud = With("reiseglad")
        ok(cloud.anim.moveA.offset[1] + cloud.anim.moveB.offset[1] > 100, "blown across")
        eq(cloud.icon.vertexColor[4], 0.6)
        eq(cloud.icon.blend, "BLEND")
        local halo = With("trofast")
        eq(halo.points[1][4], width / 2, "right over the pet")
        eq(halo.anim.grow.scaleTo[1], 1.08, "breathing a little"); eq(halo.anim.moveA.offset[1], 0)
        local speech = With("pratsom")
        ok(speech.anim == speech.plain, "a bubble keeps its size: only the beat")
        D.FAMILY = { default = D.FAMILY.default }
        D.FAMILY.default = { kind = "ember", n = 2, color = { 1, 0.5, 0 } }
        P.Traits = function() return {} end
        D:Apply(card, PANDA, 1)
        local ember = Parts(d)[1]
        eq(ember.icon.blend, "ADD"); ok(ember.throb:IsPlaying(), "it flickers")
        ok(ember.throb.steps[1].duration < 0.3, "quickly")
    end)

    test("fewer everyday particles at the first levels, all of them at 7; the level's own rewards stay", function()
        local w, ola, card, d = Setup("dykker")
        local D = ola.ns.Decor
        At(w, ola, 9, 21, 12)
        eq(D.Density(1), 0.7); eq(D.Density(nil), 0.7); eq(D.Density(7), 1)
        for l = 2, 7 do ok(D.Density(l) > D.Density(l - 1), "rises with every level") end
        local function Count(level, kind)
            D:Apply(card, PANDA, level)
            local n = 0
            for _, p in ipairs(Parts(d)) do if p.icon.tex == D.MEDIA .. kind then n = n + 1 end end
            return n
        end
        eq(Count(1, "bubble"), 3, "4 bubbles: 3 at level 1")
        eq(Count(7, "bubble"), 4, "... all 4 at 7")
        eq(Count(7, "heart"), 4, "level 7's hearts: all of them")
        eq(Count(5, "sparkle"), 6, "level 5's sparks: all of them")
        for _, s in ipairs(D:Specs(PANDA, 1, ola.ns.Now())) do
            ok(s ~= D.TRAITS.dykker or s.n == 4, "the shared table is never changed")
        end
        eq(D.TRAITS.dykker.n, 4)
    end)
end
