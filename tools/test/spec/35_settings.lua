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
        -- "Småting i chatten": a slider of four steps, the step's name beside it.
        local chatter = ola:Frames(function(f) return f.row and f.row.steps ~= nil end)[1]
        ok(chatter, "a slider"); eq(chatter.pct.text, "Vanlig")
        chatter:SetValue(2); chatter.scripts.OnValueChanged(chatter, 2, true) -- (dragged)
        eq(ola.ns.DB.global.settings.chatter, "few", "the account's"); eq(chatter.pct.text, "Litt")
        -- The tooltip says what it does, and which are per character.
        match(ola:TipOf(auto).text, "Gjelder bare denne karakteren")
        -- Shown again: as they are now.
        S:Close(); S:Open()
        no(Box(ola, "settings.autosummon"):GetChecked())
        eq(ola:Frames(function(f) return f.row and f.row.steps ~= nil end)[1].pct.text, "Litt")
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
        ola.ns.PetModels = { card = {}, park = {}, frame = {} } -- (the lift, not placed by its feet: Data/PetScenes.lua's rows left out)
        ola.ns.PetScenes = { card = {}, park = {}, frame = {} }
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
        ola.ns.DB.global.settings.chatter = "none"
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

    test("Småting i chatten: Litt doubles the cooldowns and halves every chance, Mye a third and more lines, eggs as they are", function()
        local w, ola, S = Setup()
        local M, set = ola.ns.Moments, ola.ns.DB.global.settings
        local function Step(v) set.chatter = v end
        eq(M:Every("quirk"), 2700); eq(M:Every("react"), 1200)
        Step("few"); eq(M:Every("quirk"), 5400, "90 minutes"); eq(M:Every("quirk", true), 5400, "an egg's too"); eq(S:Chance(0.4, "flavor"), 0.2); eq(S:Chance(0.5, "egg"), 0.25)
        Step("many"); eq(M:Every("quirk"), 900, "15 minutes"); eq(M:Every("react"), 400)
        eq(M:Every("quirk", true), 2700, "but an egg's wait stays 45 minutes"); eq(M:Every("react", true), 1200)
        ok(math.abs(S:Chance(0.4, "flavor") - 0.6) < 1e-9, "more lines"); eq(S:Chance(0.5, "egg"), 0.5, "eggs as they are")
        eq(S:Chance(0.8, "flavor"), 1, "at most 1")
        -- A line 20 minutes ago: on Mye a known dislike may speak again, a common egg still waits.
        ola.ns.DB.char.quirkAt = ola.ns.Now() - 1200
        ok(ola.ns.Quirks:Ready(), "a dislike: past 15 minutes"); no(ola.ns.Quirks:Ready(true), "an egg: not 45 yet")
        Step("none"); eq(M:Every("quirk"), 2700, "none: as normal, the lines hidden"); no(S:Chatty())
        Step("bogus"); eq(S:Chatter(), "normal")
        -- In play: the midnight egg (on 15% of days) at a roll of 0.1 speaks on Vanlig, not on Litt. The day's
        -- roll: Litt's lost one keeps it quiet that night, Vanlig gets the next.
        local E = ola.ns.Quirks.EGGS
        local midnight
        for _, e in ipairs(E) do if e.id == "midnatt" then midnight = e.chance end end
        ola:QuirksNow()
        ola:Dice(midnight * 0.6)
        Step("few")
        w:SetDate(2027, 3, 9, 0, 5)
        ola.ns.Activity:Emit("herb")
        w:RunTimers()
        eq(ola:Eggs("midnatt"), 0, "Litt: half the chance")
        Step("normal")
        ola.ns.Activity:Emit("herb")
        w:RunTimers()
        eq(ola:Eggs("midnatt"), 0, "the same night: the day's roll was lost")
        w:SetDate(2027, 3, 10, 0, 5)
        ola.ns.Activity:Emit("herb")
        w:RunTimers()
        eq(ola:Eggs("midnatt"), 1, "Vanlig, the next night")
    end)

    test("migration 14: Småting i chatten off becomes Ingenting, on becomes Vanlig", function()
        local w = H.World()
        for _, v in ipairs({ { false, "none" }, { true, "normal" } }) do
            local c = w:AddClient(v[1] and "Kari Berg" or "Ola Nord", { login = false })
            c.saved.DyreparkenDB = { schema = 13, settings = { chatLines = v[1], worldHearts = true } }
            c:Login()
            eq(c.env.DyreparkenDB.settings.chatter, v[2]); eq(c.env.DyreparkenDB.settings.chatLines, nil)
        end
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

    -- 2026-11-15, the user: "we have 3 different panels and settings only shows on one of them".
    test("the cog shows on all three of our pages, and Tilbake goes back to where it was opened", function()
        local w, ola = H.Setup{ ola = { 5159, 40 } }
        local S = ola.ns.Settings
        ola:OpenJournal({ sideTabs = 4 })
        local cog = S.cog
        local park, ach = ola:Page("Parken"), ola:Page("Prestasjoner")
        ok(cog:IsVisible(), "the pets")
        -- (a title bar well above the border, as it may be on Forever: lifted over our page, it covered a cog
        -- shown at a fixed level, seen in the game)
        local CJ = ola.env.CollectionsJournal
        CJ.TitleContainer.level = 40
        park:Open()
        ok(cog:IsVisible(), "Parken")
        ok(cog:GetFrameLevel() > CJ.TitleContainer:GetFrameLevel(), "over the lifted title bar")
        cog:Click()
        ok(S:IsOpen()); ok(cog:IsVisible(), "the settings page itself")
        ola:Page("Innstillinger"):Labeled("Tilbake"):Click()
        ok(park:IsOpen(), "back to Parken")
        ach:Open()
        cog:Click()
        cog:Click()
        ok(ach:IsOpen(), "the cog again: back too")
        -- Over Blizzard's Mounts page: only while one of ours covers it.
        ola:ClickTab(1)
        no(ach:IsOpen()); no(cog:IsVisible(), "Mounts: not ours")
        park:Open()
        ok(cog:IsVisible())
        cog:Click()
        ola:Page("Innstillinger"):Labeled("Tilbake"):Click()
        ok(park:IsOpen())
        -- Left by a tab: next time Tilbake goes to the pets.
        cog:Click()
        ola:ClickTab(2)
        no(S:IsOpen())
        cog:Click()
        ola:Page("Innstillinger"):Labeled("Tilbake"):Click()
        no(ola.ns.SidePage:AnyOpen(), "the pets")
    end)

    test("the same settings in Blizzard's options: one column, either place changes both", function()
        local w, ola, S = Setup()
        local canvas = ola:OpenOptions("Dyreparken")
        ok(canvas, "Esc > Options > AddOns > Dyreparken")
        local L = ola.ns.L
        local box = ola:Labeled(L["settings.hideunknown"], canvas)
        ok(box and box:GetChecked())
        ok(ola:Visible(L["settings.head.frame"], canvas), "every section")
        ok(ola:Labeled(L["settings.autosummon"], canvas), "the character's too")
        -- One column: everything left-aligned under the first.
        local lefts = {}
        for _, row in ipairs(S.ROWS) do
            if row.key and not row.slider and not row.steps and not row.choices then
                local b = ola:Labeled(L[row.key], canvas)
                lefts[b.points[1][3]] = true
            end
        end
        no(lefts.TOP, "no second column")
        -- A click redraws it: the frame's art waits for the frame, here as on the journal's page.
        local art = ola:Labeled(L["settings.petframeart"], canvas)
        no(art:IsEnabled())
        ola:Labeled(L["settings.petframe"], canvas):Click()
        ok(art:IsEnabled())
        -- In combat too: nothing protected in it.
        ola:EnterCombat()
        box:Click()
        ola:LeaveCombat()
        eq(ola.env.DyreparkenDB.settings.hideUnknown, false)
        ola:CloseOptions()
        ola:OpenJournal()
        S.cog:Click()
        no(Box(ola, "settings.hideunknown"):GetChecked(), "the journal's page reads it")
        Box(ola, "settings.hideunknown"):Click()
        local again = ola:OpenOptions("Dyreparken")
        eq(again, canvas)
        ok(box:GetChecked(), "and the other way")
        eq(#ola:Frames(function(f) return f.row == S.ROWS[2] end, canvas), 1, "built once")
    end)

    test("no options panel on a client without Blizzard's Settings API: the journal's page still works", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { patch = function(env) env.Settings = nil end })
        w:Settle("hello")
        eq(#ola.optionCategories, 0)
        ok(#ola:Log("no Settings API") >= 1)
    end)
end
