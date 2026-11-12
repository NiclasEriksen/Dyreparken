-- The pet card's plumbing (docs/REFACTOR.md, Phase 4): the widget registry (Menagerie/Card.lua),
-- ns.Timers, the shared bond bar, and refreshing only what changed.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    test("every card widget is registered in order, and each can be stopped or says it has nothing to stop", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        local Card = ola.ns.Card
        local list = Card:List()
        eq(#list, #Card.ORDER, "every id in ORDER registered")
        for i, spec in ipairs(list) do
            eq(spec.id, Card.ORDER[i])
            ok(spec.stop or spec.pause or spec.still, spec.id .. ": a stop or a pause")
        end
        -- A new widget that forgets it can't register.
        Card.ORDER[#Card.ORDER + 1] = "new"
        local okR, err = pcall(Card.Register, { id = "new", build = function() end, update = function() end })
        Card.ORDER[#Card.ORDER] = nil
        no(okR); H.match(tostring(err), "needs a stop or a pause")
        no(pcall(Card.Register, { id = "nowhere", still = true }), "an id outside ORDER")
        no(pcall(Card.Register, { id = "decor", still = true }), "an id twice")
    end)

    -- B14: our page over the card stopped the decorations but not the bond's celebration or a
    -- cuddle's hearts, which played on unseen under it.
    test("opening one of our pages stops everything on the card: the celebration and a cuddle's hearts too", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        local card = ola:SelectPet(5159)
        w:SkipDays(1)
        ola.ns.Bond:Add(100) -- (a level: celebrated on the open card)
        local cel, d = card.celebration, card.cuddle
        ok(cel.flash.anim:IsPlaying(), "celebrating")
        ola.ns.Cuddle:Pet(card, 500, 500)
        ok(d.ripple.anim:IsPlaying(), "a cuddle")
        ok(d.hearts[1].anim:IsPlaying())
        ola.ns.ParkPage._sp:Open()
        no(cel.flash.anim:IsPlaying(), "the celebration stops under the page")
        no(cel.text:IsShown())
        for _, p in ipairs(cel.parts) do no(p.anim:IsPlaying()) end
        no(d.ripple.anim:IsPlaying(), "the cuddle stops")
        for _, p in ipairs(d.hearts) do no(p.anim:IsPlaying()); no(p:IsShown()) end
        no(d.glow.anim:IsPlaying())
        -- And everything else that animates.
        no(card.bond.medal.glow.pulse:IsPlaying())
        for _, p in ipairs(card.decor.parts) do no(p.anim:IsPlaying()) end
    end)
end
