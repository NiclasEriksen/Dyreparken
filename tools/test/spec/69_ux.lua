-- The UX review of 2026-11-19 (docs/review-2026-11-19/05-ui-ux.md, the user's picks): fewer lines in chat, and
-- the ones that stay where the player wants them.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    test("our own achievement's share hint: only the first three times", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local A = ola.ns.Achievements
        for _ = 1, 5 do A:Notify({ "count:10" }) end
        eq(ola:CountPrinted("Del det i guildchatten"), A.SHARE_HINTS)
    end)

    test("guildmates' achievement lines: on by default, off with their own box", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        kari.ns.Achievements:Notify({ "count:10" }); w:Run(2)
        ok(ola:Printed("Kari Berg fikk", true))
        ola:ClearPrinted()
        ola.ns.DB.global.settings.achOthers = false
        kari.ns.Achievements:Notify({ "family:cat" }); w:Run(2)
        no(ola:Printed("Kari Berg fikk", true), "turned off")
        ola:OpenJournal({ sideTabs = 4 })
        ola.ns.Settings:Open()
        ok(ola:Page("Innstillinger"):Labeled(ola.ns.L["settings.achothers"]), "a box in the settings")
    end)

    test("/dp prestasjoner: the count and the unshared ones; alle: every one", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local rows = #ola.ns.Achievements:Rows()
        ola:ClearPrinted()
        ola:Slash("prestasjoner")
        ok(#ola.printed <= 3, "a few lines, not " .. rows)
        ok(ola:Printed("Alle står under Prestasjoner i samlingen", true))
        ola:ClearPrinted()
        ola:Slash("prestasjoner alle")
        eq(#ola.printed, rows + 1, "the header and every row")
    end)

    test("AutoCompanion's notice once a character, not at every login", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { addons = { "AutoCompanion" } })
        w:Settle("hello")
        local said = ola:CountPrinted("AutoCompanion")
        ok(said >= 1)
        ola:Reload(); w:Settle("hello")
        eq(ola:CountPrinted("AutoCompanion"), said, "not again")
    end)

    test("a full day in chat only for the adopted pet; the others' on their cards", function()
        local w, ola = H.Setup{ ola = { 5159, 46 } }
        ola:Slash("adopter panda"); w:Run(2)
        ola:ClearPrinted()
        ola.ns.Bus:Fire("BOND_FULL", "s:46")
        no(ola:Printed("White Kitten", true), "not adopted: nothing in chat")
        ola.ns.Bus:Fire("BOND_FULL", "s:5159")
        ok(ola:Printed("Panda Cub", true))
    end)

    test("the chat window our lines go to: the setting's, the main one if it's gone", function()
        local second = {}
        local w, ola = H.Setup{ ola = { pets = { 5159 }, patch = function(env)
            env.ChatFrame2 = { AddMessage = function(_, m) second[#second + 1] = m end }
            env.GetChatWindowInfo = function(i) return ({ "General", "Combat Log" })[i] end
        end } }
        ola.ns.DB.global.settings.chatFrame = "2"
        ola:ClearPrinted()
        ola.ns.Print("hei")
        eq(#ola.printed, 0); match(second[#second], "hei$")
        ola.ns.DB.global.settings.chatFrame = "3" -- (no such window)
        ola.ns.Print("igjen")
        ok(ola:Printed("igjen", true))
        ola:OpenJournal({ sideTabs = 4 })
        ola.ns.Settings:Open()
        ok(ola:Visible("Combat Log"), "the windows by their names in the settings")
    end)

    test("the list's tooltip says your own bond in words; the badge points to the pet frame", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 40 }, kari = { 40 } }
        kari:Slash("adopter"); w:Run(2)
        ola:SetBond("s:40", 300)
        local text = {}
        for _, l in ipairs(ola.ns.JournalList.PetLines("s:40", "tip.free")) do text[#text + 1] = l[1] end
        ok(table.concat(text, " / "):find("Ditt bånd: Venn (level 3)", 1, true), table.concat(text, " / "))
        local lines = {}
        for _, l in ipairs(ola.ns.OutBadge.Lines("s:5159", false)) do lines[#lines + 1] = l[1] end
        ok(table.concat(lines, " "):find("Vis dyret ditt på skjermen", 1, true), "the pet frame's setting named")
    end)
end
