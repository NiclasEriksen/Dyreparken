-- Made-up data from a guild member (review 2026-11-21, part A): what a forger can't do any more to someone
-- else's adoption, bond, name or saved data. "Per Hansen" is a member (H.FOLK) whose messages are injected.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    local function World()
        local w = H.World({ members = H.FOLK })
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46 } })
        w:Run(20)
        ola:Slash("adopter")
        w:Settle("day")
        return w, ola, kari
    end

    test("a claim dated long before it was written can't take a pet from its holder", function()
        local w, ola, kari = World()
        local now, E = w:ServerTime(), kari.ns.Config.BOND_EPOCH
        -- Per's own record, "claimed" at the addon's start: the earliest claim, so it won any pet.
        w:InjectMessage("Per Hansen", { k = "UPD", p = kari.ns.PROTOCOL, r = { k = PANDA, at = E, ts = now } })
        w:Run(10)
        eq(ola.ns.Registry:MyPet(), PANDA)
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        ok(kari:Log("refused Per Hansen's claim on s:5159")[1])
        -- A real race still goes to the earlier claim, a moment apart.
        local mine = ola.ns.Registry:MyRecord()
        w:InjectMessage("Per Hansen", { k = "UPD", p = kari.ns.PROTOCOL,
            r = { k = PANDA, at = mine.at - 20, ts = mine.at - 20 } })
        w:Run(10)
        eq(kari.ns.Registry:Holder(PANDA), "Per Hansen")
        eq(ola.ns.Registry:MyPet(), nil)
    end)

    -- The known limit (kept, the user, 2026-11-21): the refusal is judged against what a client holds, so one that
    -- hasn't the holder's record yet when the forgery comes (a newcomer's first moments) takes it, and keeps it
    -- until that pet's adoption changes. No rule on the data alone converges and can't be gamed (a forged copy of
    -- the holder's record makes them write it again, as late as the forgery). What it costs is bounded: one SYNC
    -- round a login between them, none more in a session; the holder and everyone who knew them keep theirs.
    test("known limit: a newcomer who gets a backdated claim before the holder's record keeps it, quietly", function()
        local w, ola, kari = World()
        local E = kari.ns.Config.BOND_EPOCH
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:InjectMessage("Per Hansen", { k = "UPD", p = kari.ns.PROTOCOL, r = { k = PANDA, at = E, ts = w:ServerTime() } })
        w:Run(60)
        eq(nina.ns.Registry:Holder(PANDA), "Per Hansen")
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        eq(ola.ns.Registry:MyPet(), PANDA)
        local m = w:Mark()
        w:Run(1800)
        eq(w:Sent("SYNC", nil, m), 0, "no SYNCs back and forth within the session")
        nina:Reload(); w:Run(120)
        ok(w:Sent("SYNC", nil, m) <= 2 * 3, "one round at the login (a SYNC is three parts)")
        eq(nina.ns.Registry:Holder(PANDA), "Per Hansen")
    end)

    test("a made-up lapse of someone online: they adopt the pet again at once", function()
        local w, ola, kari = World()
        local p = kari.ns.PROTOCOL
        w:InjectMessage("Per Hansen", { k = "LAPSE", p = p, l = { ["Ola Nord"] = w:ServerTime() } })
        w:Run(10)
        eq(ola.ns.Registry:MyPet(), PANDA)
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        ok(ola:Printed("Noen meldte at du var lenge borte", true))
        no(ola:Printed("dro tilbake til parken", true))
        -- Stamped as far ahead as peers allow: she waits for its moment, then adopts again.
        w:InjectMessage("Per Hansen", { k = "LAPSE", p = p, l = { ["Ola Nord"] = w:ServerTime() + 300 } })
        w:Run(10)
        eq(ola.ns.Registry:MyPet(), PANDA)
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        H.assertConverged(w)
    end)

    test("a lapse from before our login is taken as ever", function()
        local w, ola, kari = World()
        ola:Logout(); w:Run(60)
        w:InjectMessage("Per Hansen", { k = "LAPSE", p = kari.ns.PROTOCOL, l = { ["Ola Nord"] = w:ServerTime() } })
        w:Run(5); w:Skip(60)
        ola:Login(); w:Run(60)
        eq(ola.ns.Registry:MyPet(), nil)
        ok(ola:Printed("dro tilbake til parken", true))
    end)

    test("bonds made up for someone can't push out their real one, or raise it on their own client", function()
        local w, ola, kari = World()
        ola:SetBond(PANDA, 1500)
        kari:SetBond(PANDA, 1500, { who = "Ola Nord" })
        local b, now = {}, w:ServerTime()
        for i = 1, 400 do b["n:junk" .. i] = { ["Ola Nord"] = { p = 0, f = now, t = now } } end
        w:InjectMessage("Per Hansen", { k = "SYNC", p = kari.ns.PROTOCOL, i = 3, of = 3, d = 1, b = b })
        w:Run(10)
        eq(kari.ns.Registry:Life(PANDA, "Ola Nord").p, 1500, "the real bond stays on peers")
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord").p, 1500)
        eq(ola.ns.Registry:Life("n:junk1", "Ola Nord"), nil, "her own client refused them")
        -- A copy of her bond, maxed out: her client keeps the truth.
        local f = now - 40 * 86400
        w:InjectMessage("Per Hansen", { k = "SYNC", p = kari.ns.PROTOCOL, i = 3, of = 3, d = 1,
            b = { [PANDA] = { ["Ola Nord"] = { p = ola.ns.Wire.LifeCap(f, now), f = f, t = now } } } })
        w:Run(10)
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord").p, 1500)
        ok(ola:Log("refused a copy of our bond with s:5159 from Per Hansen")[1])
    end)

    test("names made up for someone can't push out the one they gave their pet", function()
        local w, ola, kari = World()
        ola:SetBond(PANDA, 600)
        ola:Slash("navn Bambus")
        w:Run(20)
        eq(kari.ns.Registry:Nickname(PANDA), "Bambus")
        local n = {}
        for i = 1, 60 do n["n:junk" .. i] = { ["Ola Nord"] = { n = "x", at = w:ServerTime() + 1 } } end
        w:InjectMessage("Per Hansen", { k = "SYNC", p = kari.ns.PROTOCOL, i = 2, of = 3, d = 1, n = n })
        w:Run(10)
        eq(kari.ns.Registry:Nickname(PANDA), "Bambus")
        eq(ola.ns.Registry:Nickname(PANDA), "Bambus")
        local mine = 0
        for _, by in pairs(ola.ns.DB:Guild().names) do if by["Ola Nord"] then mine = mine + 1 end end
        eq(mine, 1, "no void entries of hers for the made-up keys")
    end)

    test("a name dated at the very second of an adoption isn't inherited", function()
        local w, ola, kari = World()
        local at = ola.ns.Registry:MyRecord().at
        w:InjectMessage("Per Hansen", { k = "NICK", p = kari.ns.PROTOCOL, pet = PANDA, e = { n = "Stinkern", at = at } })
        w:Run(5)
        eq(kari.ns.Registry:Nickname(PANDA), nil)
        eq(ola.ns.Registry:Nickname(PANDA), nil)
        -- One from before it is the pet's, as ever (an earlier carer's).
        w:InjectMessage("Liv Lund", { k = "NICK", p = kari.ns.PROTOCOL, pet = PANDA, e = { n = "Pepe", at = at - 1 } })
        w:Run(5)
        eq(kari.ns.Registry:Nickname(PANDA), "Pepe")
    end)

    -- A copy from before this login (our other PC's, or someone's made-up one) that took our pet: asked on the
    -- pet journal's page whether to keep it (the user, 2026-11-21).
    local function Taken(w, ola, kari)
        ola:Logout(); w:Skip(3600); ola:Login(); w:Settle("hello")
        local mine = ola.ns.Registry:MyRecord()
        w:InjectMessage("Kari Berg", { k = "SYNC", p = kari.ns.PROTOCOL, d = 1,
            r = { ["Ola Nord"] = { at = mine.at, ts = mine.ts + 1 } }, l = {} })
        w:Run(5)
        eq(ola.ns.Registry:MyPet(), nil)
        return mine
    end

    test("a pre-login copy that took our pet: the journal asks, and keeping it brings it back as it was", function()
        local w, ola, kari = World()
        local mine = Taken(w, ola, kari)
        no(ola.popup, "not before the journal shows")
        ola:OpenJournal()
        eq(ola.popup and ola.popup.which, "DYREPARKEN_OWNCHANGE")
        ok(ola.popup.args[1]:find("Ifølge Kari Berg bor ikke Panda Cub hos deg lenger", 1, true))
        -- Escape: asked again next time, after a reload too.
        ola:PopupCancel(true)
        ola:CloseJournal(); ola:Reload(); w:Run(20); ola:OpenJournal()
        eq(ola.popup and ola.popup.which, "DYREPARKEN_OWNCHANGE")
        ola:PopupAccept()
        w:Run(5)
        eq(ola.ns.Registry:MyPet(), PANDA)
        eq(ola.ns.Registry:MyRecord().at, mine.at, "the same adoption, its date kept")
        eq(kari.ns.Registry:Holder(PANDA), "Ola Nord")
        ok(ola:Printed("Panda Cub bor fortsatt hos deg", true))
        ola:CloseJournal(); ola:OpenJournal()
        no(ola.popup, "answered")
        H.assertConverged(w)
    end)

    test("a pre-login copy that took our pet: \"it was me\" lets it be; one adopted since stays its new home's", function()
        local w, ola, kari = World()
        Taken(w, ola, kari)
        ola:OpenJournal()
        ola:PopupCancel()
        ola:CloseJournal(); ola:OpenJournal()
        no(ola.popup)
        eq(ola.ns.Registry:MyPet(), nil)
        -- Again, and Per adopts the Panda before she answers.
        local w2, ola2, kari2 = World()
        Taken(w2, ola2, kari2)
        local now = w2:ServerTime()
        w2:InjectMessage("Per Hansen", { k = "UPD", p = kari2.ns.PROTOCOL, r = { k = PANDA, at = now, ts = now } })
        w2:Run(5)
        ola2:OpenJournal()
        ola2:PopupAccept()
        w2:Run(5)
        eq(ola2.ns.Registry:MyPet(), nil)
        eq(kari2.ns.Registry:Holder(PANDA), "Per Hansen")
        ok(ola2:Printed("Det bor allerede hos Per Hansen", true))
    end)

    test("bonds under made-up keys leave no stories behind", function()
        local w, ola = World()
        for i = 1, 30 do
            local now = w:ServerTime()
            w:InjectMessage("Per Hansen", { k = "BOND", p = ola.ns.PROTOCOL, pet = "n:junk" .. i, e = { p = 1, f = now, t = now } })
        end
        w:Run(5)
        local g = ola.ns.DB:Guild()
        g.story["n:old"] = { e = {}, lv = { ["Per Hansen"] = 1 } } -- (one from before)
        ola.ns.Story:Scan()
        for key in pairs(g.story) do no(key:find("^n:junk") or key == "n:old", key) end
        ok(g.story[PANDA])
    end)
end
