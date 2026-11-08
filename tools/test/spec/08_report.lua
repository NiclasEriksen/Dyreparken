-- /dp report: who in the group has no companion out (addon users only).
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Party(names, opts)
        local w = H.World()
        local clients = {}
        for _, n in ipairs(names) do
            if not n:find("^%-") then clients[n] = w:AddClient(n, opts and opts[n]) end
        end
        local members = {}
        for _, n in ipairs(names) do members[#members + 1] = (n:gsub("^%-", "")) end
        w:SetGroup(members)
        w:Run(20)
        return w, clients
    end

    test("calls out addon users without a pet; others are unknown", function()
        local w, c = Party({ "Ola Nord", "Kari Berg", "Per Hansen", "-Uten Addon", "-Solo" },
            { ["Kari Berg"] = { summoned = false } })
        local ola = c["Ola Nord"]
        ola:Slash("rapport")
        ok(ola:Printed("Sjekker kjæledyr ..."))
        w:Run(4)
        eq(#w.chat, 0, "nothing posted before the click")
        eq(ola.popup.which, "DYREPARKEN_REPORT")
        eq(ola.popup.args[1], "Dyreparken: Kari Berg har ikke kjæledyret sitt ute!", "the dialog shows the line")
        ola:PopupAccept()
        eq(#w.chat, 1)
        eq(w.chat[1].chan, "PARTY")
        eq(w.chat[1].text, "Dyreparken: Kari Berg har ikke kjæledyret sitt ute!")
        ok(ola:Printed("Ukjent %(uten addon%): Solo, Uten Addon"), "no surname: first name only")
        eq(w:Sent("PET"), 2)
    end)

    test("a forgotten companion is called out by its nickname", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" }, { ["Kari Berg"] = { pets = { 40 } } })
        local kari = c["Kari Berg"]
        kari:Slash("adopter")
        w:SkipDays(7)
        kari:Slash("navn Mjau")
        kari:Summon(nil)
        w:Run(1)
        c["Ola Nord"]:Slash("rapport")
        w:Run(4)
        c["Ola Nord"]:PopupAccept()
        eq(w.chat[#w.chat].text, "Dyreparken: Kari Berg har glemt Mjau hjemme!")
    end)

    test("everyone has a pet: praise, if you want to share it", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" })
        c["Ola Nord"]:Slash("report")
        w:Run(4)
        eq(#w.chat, 0)
        ok(c["Ola Nord"]:Printed("Alle med addonen har kjæledyret sitt ute %(2%)."))
        c["Ola Nord"]:PopupAccept()
        eq(w.chat[1].text, "Dyreparken: Alle 2 har kjæledyret ute. For en gjeng!")
        -- With members of unknown status, only the addon users are praised.
        local w2, c2 = Party({ "Ola Nord", "Kari Berg", "-Uten Addon" })
        c2["Ola Nord"]:Slash("rapport")
        w2:Run(4)
        c2["Ola Nord"]:PopupAccept()
        eq(w2.chat[1].text, "Dyreparken: Alle 2 med Dyreparken har kjæledyret ute!")
        -- Alone with the addon: nothing to share.
        local w3, c3 = Party({ "Ola Nord", "-Uten Addon" })
        c3["Ola Nord"]:Slash("rapport")
        w3:Run(4)
        eq(c3["Ola Nord"].popup, nil)
    end)

    test("the one asking is checked too; leaving the group cancels the post", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" }, { ["Ola Nord"] = { summoned = false } })
        c["Ola Nord"]:Slash("report")
        w:Run(4)
        w:SetGroup(nil)
        c["Ola Nord"]:PopupAccept()
        eq(#w.chat, 0, "not in a group any more")
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        c["Ola Nord"]:Slash("report")
        w:Run(4)
        c["Ola Nord"]:PopupAccept()
        eq(w.chat[1].text, "Dyreparken: Ola Nord har ikke kjæledyret sitt ute!")
    end)

    test("raids use the raid channel and raid units; long lists are cut to fit", function()
        local names = { "Ola Nord", "Kari Berg", "Per Hansen", "Liv Lund", "-Siv Dahl", "-Tor Eng", "-Anne Aas" }
        local w, c = Party(names, { ["Liv Lund"] = { summoned = false }, ["Per Hansen"] = { summoned = false } })
        c["Kari Berg"]:Slash("report")
        w:Run(4)
        c["Kari Berg"]:PopupAccept()
        eq(w.chat[1].chan, "RAID")
        eq(w.chat[1].text, "Dyreparken: Disse har glemt kjæledyret hjemme: Liv Lund, Per Hansen!")
        ok(c["Kari Berg"]:Printed("Ukjent %(uten addon%): Anne Aas, Siv Dahl, Tor Eng"))
        local R = c["Kari Berg"].ns.Report
        local many = {}
        for i = 1, 40 do many[i] = ("Medlem%02d Etternavn"):format(i) end
        local text = R:Message(many, 0, 0)
        ok(#text <= 255, #text .. " characters")
        match(text, " og %d+ til!$")
        match(text, "^Dyreparken: Disse har glemt kjæledyret hjemme: Medlem01 Etternavn, Medlem02")
    end)

    test("not in a group, or already running", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        c:Slash("report")
        ok(c:Printed("Du er ikke i en gruppe."))
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        c:Slash("report")
        c:Slash("report")
        ok(c:Printed("En rapport kjører allerede."))
        w:Run(4)
        ok(c:Printed("Ukjent %(uten addon%): Kari Berg"))
    end)

    test("requests outside the group, and stray answers, are ignored", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" })
        local m = w:Mark()
        w:InjectMessage("Per Hansen", { k = "PET_REQ", p = c["Ola Nord"].ns.PROTOCOL }, "GUILD")
        w:InjectMessage("Per Hansen", { k = "PET", p = c["Ola Nord"].ns.PROTOCOL, out = false }, "PARTY")
        w:Run(4)
        eq(w:Sent("PET", nil, m), 0)
        eq(#w.chat, 0)
    end)
end
