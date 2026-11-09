-- The answering half of the old /dp rapport (Menagerie/Report.lua): the
-- command is gone (2026-11-09), but clients on 0.2.x can still ask.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    local function Party(names)
        local w = H.World()
        local clients = {}
        for _, n in ipairs(names) do clients[n] = w:AddClient(n, { pets = { 5159 } }) end
        local members = { "Per Hansen" } -- (the one asking: an old client, no addon here)
        for _, n in ipairs(names) do members[#members + 1] = n end
        w:SetGroup(members)
        w:Run(12)
        return w, clients
    end

    test("an old client asking the group: we answer whether our pet is out", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" })
        c["Kari Berg"].summoned = nil
        local m = w:Mark()
        w:InjectMessage("Per Hansen", { k = "PET_REQ", p = c["Ola Nord"].ns.PROTOCOL }, "PARTY")
        w:Run(4)
        local answers = {}
        for i = m + 1, #w.wire do
            local x = w.wire[i]
            if x.kind == "PET" then answers[x.from] = x.msg.out end
        end
        eq(answers["Ola Nord"], true); eq(answers["Kari Berg"], false)
        -- At most one answer per window.
        m = w:Mark()
        w:InjectMessage("Per Hansen", { k = "PET_REQ", p = c["Ola Nord"].ns.PROTOCOL }, "PARTY")
        w:Run(1)
        eq(w:Sent("PET", nil, m), 0)
    end)

    test("the command itself is gone", function()
        local w, c = Party({ "Ola Nord" })
        local m = w:Mark()
        c["Ola Nord"]:Slash("rapport")
        w:Run(4)
        eq(w:Sent("PET_REQ", nil, m), 0)
        ok(c["Ola Nord"]:Printed("kommandoer:", true), "the help instead")
        no(c["Ola Nord"]:Printed("rapport", true), "and it isn't listed")
    end)

    test("requests outside the group are ignored", function()
        local w, c = Party({ "Ola Nord", "Kari Berg" })
        local m = w:Mark()
        w:InjectMessage("Per Hansen", { k = "PET_REQ", p = c["Ola Nord"].ns.PROTOCOL }, "GUILD")
        w:Run(4)
        eq(w:Sent("PET", nil, m), 0)
    end)
end
