-- The pet card's decorations (Menagerie/Decor.lua): more with every bond
-- level, particles from the pet's traits and the date, all played by the
-- client's animation groups and stopped when the card has nothing to show.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    -- Ola, the journal open, the panda's traits given (by id).
    local function Setup(...)
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        local ids = { ... }
        if #ids == 0 then ids = { "glupsk", "reiseglad" } end -- no particles of their own
        ola.ns.Personality.Traits = function()
            local list = {}
            for _, id in ipairs(ids) do list[#list + 1] = ola.ns.Personality.ById(id) end
            return list
        end
        w:Run(20)
        ola:OpenJournal()
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
        for _, e in ipairs(d.edges) do no(e:IsShown()) end
        no(d.wash[1]:IsShown())
        Level(2)
        for i = 1, 4 do ok(d.edges[i]:IsShown(), "a border"); ok(d.wash[i]:IsShown(), "a wash of color") end
        eq(Color(d.edges[1])[1], math.min(1, cat[1] * 1.7), "in the family's color")
        no(d.corners.TOPLEFT:IsShown())
        Level(3)
        local n = 0
        for point, t in pairs(d.corners) do ok(t:IsShown(), point); n = n + 1 end
        eq(n, 4)
        eq(table.concat(d.corners.BOTTOMRIGHT.texCoord, ","), "1,0,1,0", "mirrored into each corner")
        ok(d.corners.TOPLEFT.desaturated, "silver corners")
        eq(Color(d.edges[1])[3], 1, "a silver border")
        no(d.glows[1]:IsShown())
        Level(4)
        for _, g in ipairs(d.glows) do ok(g:IsShown()); ok(g.breathe:IsPlaying(), "it breathes") end
        eq(d.glows[1].breathe.a.toAlpha, 1, "at full strength at its peak")
        eq(#Parts(d), 0)
        Level(5)
        no(d.corners.TOPLEFT.desaturated, "gold corners")
        eq(Color(d.edges[1])[3], 0.25, "a gold border")
        eq(Color(d.glows[1])[3], 0.25, "a gold glow")
        eq(#Parts(d), 6, "sparks")
        eq(Parts(d)[1].tex, D.MEDIA .. "sparkle")
        eq(Playing(d), 6)
        no(d.ribbon:IsShown()); no(d.rays:IsShown())
        Level(6)
        ok(d.ribbon:IsShown()); eq(d.ribbonText.text, "Uatskillelig")
        ok(d.rays:IsShown()); ok(d.rays.turn:IsPlaying(), "turning rays")
        local slow = d.rays.turn.a.duration
        no(d.edges[1].shimmer:IsPlaying())
        Level(7)
        eq(d.ribbonText.text, "Sjelevenn")
        eq(#Parts(d), 10, "sparks and hearts")
        ok(d.edges[1].shimmer:IsPlaying(), "the gold edge glows")
        ok(d.rays.turn.a.duration < slow, "the rays turn faster")
        -- Back down: everything above goes.
        Level(1)
        no(d.ribbon:IsShown()); no(d.glows[1]:IsShown()); no(d.glows[1].breathe:IsPlaying())
        no(d.rays.turn:IsPlaying()); no(d.edges[1].shimmer:IsPlaying())
        eq(#Parts(d), 0); eq(Playing(d), 0)
    end)

    test("each kind of particle moves its own way, on a timeline that never shows it standing still", function()
        local w, ola, card, d = Setup("dykker", "nattugle")
        local D = ola.ns.Decor
        At(w, ola, 9, 21, 12)
        D:Apply(card, PANDA, 1)
        local parts = Parts(d)
        eq(#parts, 4, "a Dykker's bubbles; no stars by day")
        eq(parts[1].tex, D.MEDIA .. "bubble")
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
            eq(p.tex, D.MEDIA .. D.KINDS[kind].tex)
            return p
        end
        local leaf = Kind("gronnfinger", "leaf")
        ok(leaf.anim.moveA.offset[2] < 0, "leaves fall")
        ok(leaf.sway:IsPlaying()); ok(leaf.tilt:IsPlaying()); eq(leaf.sway.looping, "BOUNCE")
        local heart = Kind("kosete", "heart")
        ok(heart.throb:IsPlaying()); eq(heart.throb.a.scaleTo[1], 1.3); no(heart.sway:IsPlaying(), "only what it does")
        At(w, ola, 5, 17, 12)
        local confetti = Kind("festglad", "confetti")
        ok(confetti.spin:IsPlaying()); ok(confetti.sway:IsPlaying())
        ok(Parts(d)[1].vertexColor[1] ~= Parts(d)[4].vertexColor[1] or Parts(d)[1].vertexColor[3] ~= Parts(d)[4].vertexColor[3],
            "in many colors")
        -- Sparks fly out from the pet, quickly, shrinking.
        At(w, ola, 9, 21, 12)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("glupsk") } end
        D:Apply(card, PANDA, 5)
        local spark = Parts(d)[1]
        eq(spark.tex, D.MEDIA .. "sparkle")
        ok(spark.anim.moveA.duration < 1, "fast"); eq(spark.anim.moveA.smoothing, "OUT")
        eq(spark.anim.grow.scaleTo[1], 0.3); ok(spark.spin:IsPlaying())
        -- Stars twinkle in place at night.
        At(w, ola, 9, 21, 23)
        local star = Kind("nattugle", "star")
        eq(star.anim.moveA.offset[1], 0); eq(star.anim.moveA.offset[2], 0)
        eq(star.anim.grow.scaleTo[1], 1.6)
        -- Not on a holiday any more: no confetti. December: snow for everyone.
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("festglad") } end
        At(w, ola, 5, 18, 12)
        D:Apply(card, PANDA, 1)
        eq(#Parts(d), 0, "the day after")
        At(w, ola, 12, 3, 12)
        D:Apply(card, PANDA, 1)
        eq(#Parts(d), 5); eq(Parts(d)[1].tex, D.MEDIA .. "snowflake")
        ok(Parts(d)[1].spin:IsPlaying())
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
        local w, ola, card, d = Setup("dykker", "glupsk")
        At(w, ola, 9, 21, 12)
        ola:Slash("adopter panda")
        w:Run(5)
        local g = ola.ns.DB:Guild()
        local now = ola.ns.Now()
        g.life[PANDA] = { ["Ola Nord"] = { p = 1000, f = now - 200 * 86400, t = now } } -- God venn: level 4
        card = ola:SelectPet(5159)
        ok(d.glows[1]:IsShown()); ok(d.corners.TOPLEFT:IsShown())
        eq(#Parts(d), 4, "the Dykker's bubbles")
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
        ok(ola:Printed("Kortet vises som nivå 7 (Sjelevenn)", true))
        ok(d.ribbon:IsShown(), "any pet, even one nobody holds")
        ola:Slash("probe level 3")
        no(d.ribbon:IsShown()); ok(d.corners.TOPLEFT:IsShown())
        ola:Slash("probe level off")
        ok(ola:Printed("Kortet viser det virkelige nivået igjen.", true))
        no(d.corners.TOPLEFT:IsShown())
        ola:Slash("probe level 99")
        no(d.corners.TOPLEFT:IsShown(), "out of range: off")
    end)
end
