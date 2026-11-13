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
    -- A setting's control on the open page, by the label the player reads (Locale's text for key).
    local function Box(c, key) return c:Page("Innstillinger"):Labeled(c.ns.L[key]) end

    test("the cog opens the page and closes it; no side tab of its own; it shows on the pet page only", function()
        local w, ola, S = Setup()
        local cog = S.cog
        ok(cog and cog:IsShown())
        local page = ola:Page("Innstillinger")
        no(page.tab, "no side tab")
        cog:Click()
        ok(S:IsOpen()); ok(ola.ns.SidePage:AnyOpen(), "it covers the card like our other pages")
        eq(ola.env.CollectionsJournal:GetTitleText().text, "Innstillinger", "its title in the window's")
        cog:Click()
        no(S:IsOpen())
        cog:Click()
        page:Labeled("Tilbake"):Click()
        no(S:IsOpen(), "Tilbake: back to the pets")
        ola.env.PetJournal:Hide()
        no(cog:IsShown(), "another page of the window: no cog")
        ola.env.PetJournal:Show()
        ok(cog:IsShown())
    end)

    test("the boxes show the settings and change them; the older ones stay per character", function()
        local w, ola, S = Setup()
        S:Open()
        local auto = Box(ola, "settings.autosummon")
        ok(auto:GetChecked())
        auto:Click()
        eq(ola.ns.DB.char.autoSummon, false, "auto-summon off")
        local mute = Box(ola, "settings.mute")
        ok(mute:GetChecked()); mute:Click()
        eq(ola.ns.DB.char.muteSummonSound, false)
        Box(ola, "settings.announce"):Click()
        eq(ola.ns.DB.char.announce, false)
        Box(ola, "settings.achnotify"):Click()
        eq(ola.ns.DB.char.achNotify, false)
        local lines = Box(ola, "settings.chatlines")
        ok(lines:GetChecked()); lines:Click()
        eq(ola.ns.DB.global.settings.chatLines, false, "the account's")
        -- The tooltip says what it does, and which are per character.
        match(ola:TipOf(auto).text, "Gjelder bare denne karakteren")
        -- Shown again: as they are now.
        S:Close(); S:Open()
        no(Box(ola, "settings.autosummon"):GetChecked())
        no(Box(ola, "settings.chatlines"):GetChecked())
    end)

    test("card particles: all, fewer or none", function()
        local w, ola, S = Setup()
        w:Befriend() -- (past the first levels' sparse particles: one of a kind can't be halved)
        local card = ola:SelectPet(5159)
        local function Shown()
            local n = 0
            for _, p in ipairs(card.decor.parts) do if p:IsShown() then n = n + 1 end end
            return n
        end
        local all = Shown()
        ok(all > 2)
        S:Open()
        local choices = { Box(ola, "settings.particles.all"), Box(ola, "settings.particles.few"),
            Box(ola, "settings.particles.none") }
        ok(choices[1]:GetChecked())
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
        w:SetDate(2027, 3, 2, 23)
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
        ola:Dice(0)
        ola:QuirksNow()
        w:SetDate(2027, 3, 9, 13, 37)
        ola:ClearPrinted()
        ola.ns.Activity:Emit("herb")
        w:RunTimers()
        no(ola:Printed("13:37", true), "no egg line")
        ok(ola:Eggs("leet") > 0, "but the egg was found: it counts")
        no(ola:Printed("koste seg", true), "no bond line")
        -- No hearts over companions.
        ola.ns.DB.global.settings.worldHearts = false
        ola:Hover({ species = 40, owner = "Kari Berg" })
        local shown = 0
        for _, p in ipairs(ola.ns.Fx.particles or {}) do if p:IsShown() then shown = shown + 1 end end
        eq(shown, 0)
    end)

    test("the frame's art waits for the frame: greyed while it's off; the per-character sections say so", function()
        local w, ola, S = Setup()
        S:Open()
        local art = Box(ola, "settings.petframeart")
        no(art:IsEnabled(), "the frame is off: nothing to frame")
        local label = ola:Page("Innstillinger"):Text(ola.ns.L["settings.petframeart"], true)
        eq(label.color[1], 0.5)
        Box(ola, "settings.petframe"):Click()
        ok(art:IsEnabled())
        eq(label.color[1], 1)
        local notes = 0
        for _, row in ipairs(S.ROWS) do if row.char and row.head then notes = notes + 1 end end
        eq(notes, 2, "Dyret ditt and Guilden")
        -- The particles are radio buttons.
        eq(Box(ola, "settings.particles.all").template, "UIRadioButtonTemplate")
    end)
end
