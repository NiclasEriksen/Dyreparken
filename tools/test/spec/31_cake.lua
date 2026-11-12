-- The anniversary cake (Menagerie/Cake.lua): on an adopted pet's milestone
-- day, a cake with flickering candles on its card.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    test("a cake on the milestone day only, for your pet and the guild's, with what's celebrated", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 46 }, journal = true }
        ola:Slash("adopter panda"); kari:Slash("adopter white")
        w:Run(10)
        local card = ola:SelectPet(5159)
        local cake = card.cake
        no(cake:IsShown(), "no milestone on day one")
        -- Thirty calendar days on (as the milestone lines count them).
        local at = select(2, ola.ns.Registry:Holder("s:5159")).at
        local Day = ola.ns.Bonds.DayNumber
        while Day(w:ServerTime()) - Day(at) < 30 do w:Skip(3600) end
        ola:SelectPet(5159)
        ok(cake:IsShown())
        match(cake.cake.tex, "Particles\\cake$")
        for _, t in ipairs(cake.flames) do ok(t.flicker:IsPlaying(), "the candles flicker") end
        local tip = ola:TipOf(cake)
        eq(tip[1], "Merkedag!")
        eq(tip[2], "I dag har Panda Cub bodd hos deg i 1 måned!")
        -- Kari's kitten, adopted the same day: the guild's celebration shows too.
        ola:SelectPet(46)
        ok(cake:IsShown())
        eq(ola:TipOf(cake)[2], "Kari Berg og White Kitten feirer 1 måned sammen i dag!")
        -- Our page over the card: gone (and redrawn when it closes); the journal closing stops the candles.
        ola.ns.Bus:Fire("SIDEPAGE", true)
        no(cake:IsShown())
        ola:SelectPet(46)
        ok(cake:IsShown())
        ola.env.PetJournalPetCard:Hide() -- (the journal closing hides the card)
        for _, t in ipairs(cake.flames) do no(t.flicker:IsPlaying()) end
        ola.env.PetJournalPetCard:Show()
        -- The next day: no cake.
        w:SkipDays(1)
        ola:SelectPet(5159)
        no(cake:IsShown())
        for _, t in ipairs(cake.flames) do no(t.flicker:IsPlaying()) end
    end)

    test("a click on a guildmate's cake congratulates them in guild chat, once a day, with announcing on", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 46 }, journal = true }
        ola:Slash("adopter panda"); kari:Slash("adopter white")
        w:Run(10)
        local at = select(2, ola.ns.Registry:Holder("s:46")).at
        local Day = ola.ns.Bonds.DayNumber
        while Day(w:ServerTime()) - Day(at) < 30 do w:Skip(3600) end
        local function Posts()
            local list = {}
            for _, m in ipairs(w.chat) do if m.from == "Ola Nord" and m.chan == "GUILD" then list[#list + 1] = m.text end end
            return list
        end
        local before = #Posts()
        -- Her own: nothing to click.
        local cake = ola:SelectPet(5159).cake
        no(ola:TipOf(cake).text:find("gratulere"))
        cake:Click()
        eq(#Posts(), before)
        -- Kari's: the tooltip says so, and a click posts.
        cake = ola:SelectPet(46).cake
        match(ola:TipOf(cake).text, "Klikk for å gratulere")
        cake:Click()
        eq(Posts()[#Posts()], "Gratulerer med 1 måned sammen, Kari Berg og White Kitten!")
        cake:Click()
        eq(#Posts(), before + 1, "once a day")
        -- Announcing off: no post.
        ola.ns.DB.char.congratulated = nil
        ola:Slash("kunngjør av")
        cake:Click()
        eq(#Posts(), before + 1)
    end)

    test("no cake for a pet without a home", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        local card = ola:SelectPet(5159)
        no(card.cake:IsShown())
        eq(ola.ns.Cake:Today("s:5159"), nil)
    end)
end
