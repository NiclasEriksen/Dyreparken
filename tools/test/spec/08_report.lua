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
        c["Ola Nord"]:Slash("report")
        ok(c["Ola Nord"]:Printed("Sjekker kjæledyr ..."))
        w:Run(4)
        eq(#w.chat, 1)
        eq(w.chat[1].chan, "PARTY")
        eq(w.chat[1].text, "Dyreparken: uten kjæledyr ute: Kari Berg!")
        ok(c["Ola Nord"]:Printed("Ukjent %(uten addon%): Solo, Uten Addon"), "no surname: first name only")
        eq(w:Sent("PET"), 2)
    end)

    test("everyone has a pet: nothing posted", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" })
        c["Ola Nord"]:Slash("report")
        w:Run(4)
        eq(#w.chat, 0)
        ok(c["Ola Nord"]:Printed("Alle med addonen har kjæledyret sitt ute %(2%)."))
        no(c["Ola Nord"]:Printed("Unknown"))
    end)

    test("the one asking is checked too", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" }, { ["Ola Nord"] = { summoned = false } })
        c["Ola Nord"]:Slash("report")
        w:Run(4)
        eq(w.chat[1].text, "Dyreparken: uten kjæledyr ute: Ola Nord!")
    end)

    test("raids use the raid channel and raid units", function()
        local names = { "Ola Nord", "Kari Berg", "Per Hansen", "Liv Lund", "-Siv Dahl", "-Tor Eng", "-Anne Aas" }
        local w, c = Party(names, { ["Liv Lund"] = { summoned = false }, ["Per Hansen"] = { summoned = false } })
        c["Kari Berg"]:Slash("report")
        w:Run(4)
        eq(w.chat[1].chan, "RAID")
        eq(w.chat[1].text, "Dyreparken: uten kjæledyr ute: Liv Lund, Per Hansen!")
        ok(c["Kari Berg"]:Printed("Ukjent %(uten addon%): Anne Aas, Siv Dahl, Tor Eng"))
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
