-- The settings page (Menagerie/Settings.lua): a cog in the pet journal's
-- title bar opens our own page; each setting does what it says.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Setup()
        local w, ola = H.Setup{ ola = { 5159, 40 }, journal = true }
        ola:Slash("adopter panda")
        w:Run(5)
        return w, ola, ola.ns.Settings
    end
    local function Widget(S, key)
        for _, wd in ipairs(S._sp.widgets) do if wd.row.key == key then return wd end end
    end

    test("the cog opens the page and closes it; no side tab of its own; it shows on the pet page only", function()
        local w, ola, S = Setup()
        local cog = S.cog
        ok(cog and cog:IsShown())
        no(S._sp.tab, "no side tab")
        cog:Click()
        ok(S:IsOpen()); ok(ola.ns.SidePage:AnyOpen(), "it covers the card like our other pages")
        eq(ola.env.CollectionsJournal:GetTitleText().text, "Innstillinger", "its title in the window's")
        cog:Click()
        no(S:IsOpen())
        ola.env.PetJournal:Hide()
        no(cog:IsShown(), "another page of the window: no cog")
        ola.env.PetJournal:Show()
        ok(cog:IsShown())
    end)

    test("the boxes show the settings and change them; the older ones stay per character", function()
        local w, ola, S = Setup()
        S:Open()
        local auto = Widget(S, "settings.autosummon").button
        ok(auto:GetChecked())
        auto:Click()
        eq(ola.ns.DB.char.autoSummon, false, "auto-summon off")
        local mute = Widget(S, "settings.mute").button
        ok(mute:GetChecked()); mute:Click()
        eq(ola.ns.DB.char.muteSummonSound, false)
        Widget(S, "settings.announce").button:Click()
        eq(ola.ns.DB.char.announce, false)
        Widget(S, "settings.achnotify").button:Click()
        eq(ola.ns.DB.char.achNotify, false)
        local lines = Widget(S, "settings.chatlines").button
        ok(lines:GetChecked()); lines:Click()
        eq(ola.ns.DB.global.settings.chatLines, false, "the account's")
        -- The tooltip says what it does, and which are per character.
        auto.scripts.OnEnter(auto)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "Gjelder bare denne karakteren")
        -- Shown again: as they are now.
        S:Close(); S:Open()
        no(Widget(S, "settings.autosummon").button:GetChecked())
        no(Widget(S, "settings.chatlines").button:GetChecked())
    end)

    test("card particles: all, fewer or none", function()
        local w, ola, S = Setup()
        local card = ola:SelectPet(5159)
        local function Shown()
            local n = 0
            for _, p in ipairs(card.decor.parts) do if p:IsShown() then n = n + 1 end end
            return n
        end
        local all = Shown()
        ok(all > 2)
        S:Open()
        local choices = Widget(S, "settings.particles").buttons
        eq(choices[1].choice, "all"); ok(choices[1]:GetChecked())
        choices[3]:Click()
        ok(choices[3]:GetChecked()); no(choices[1]:GetChecked(), "one at a time")
        S:Close()
        card = ola:SelectPet(5159)
        eq(Shown(), 0, "none")
        S:Open(); choices[2]:Click(); S:Close()
        card = ola:SelectPet(5159)
        ok(Shown() > 0 and Shown() < all, "fewer")
    end)

    test("the pet's moves off: it stands, even at night, and a click doesn't hop; the lift still applies", function()
        local w, ola, S = Setup()
        ola.ns.PetMoves.species[5159] = { lift = 0.2 }
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 23 }) - w:ServerTime())
        local actor = ola.petActor
        ola.ns.DB.global.settings.cardMoves = false
        ola:SelectPet(5159)
        w:Run(2)
        eq(actor.anim or 0, 0, "not asleep (left standing as the client loads it)")
        ok(math.abs(actor.pos[3] - 0.2) < 1e-6, "still on its shadow")
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim or 0, 0, "no hop")
        ola.ns.DB.global.settings.cardMoves = true
        ola:SelectPet(40); ola:SelectPet(5159)
        w:Run(2)
        eq(actor.anim, 6, "on again: asleep")
    end)

    test("celebrations, chat lines and hearts off", function()
        local w, ola, S = Setup()
        local card = ola:SelectPet(5159)
        ola.ns.DB.global.settings.celebrate = false
        ola.ns.BondTrack:Celebrate(card, PANDA, 3)
        no(card.celebration.text:IsShown(), "no celebration")
        -- No easter eggs or bond lines in the chat.
        ola.ns.DB.global.settings.chatLines = false
        ola.ns.Quirks.random = function(n) return n and 1 or 0 end
        ola.ns.Quirks.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } }
        w:Skip(os.time({ year = 2027, month = 3, day = 9, hour = 13, min = 37 }) - w:ServerTime())
        ola:ClearPrinted()
        ola.ns.Activity:Emit("herb")
        w:RunTimers()
        no(ola:Printed("13:37", true), "no egg")
        no(ola:Printed("koste seg", true), "no bond line")
        -- No hearts over companions.
        ola.ns.DB.global.settings.worldHearts = false
        ola:Hover({ species = 40, owner = "Kari Berg" })
        local shown = 0
        for _, p in ipairs(ola.ns.Fx.particles or {}) do if p:IsShown() then shown = shown + 1 end end
        eq(shown, 0)
    end)
end
