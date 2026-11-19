-- Who owns which pets (Menagerie/Owners.lua, X-Protocol 11), and the protocol window that lets a 0.7
-- client (X-Protocol 10) keep syncing the registry with newer ones.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- Every online client with Owners agrees on the store (its digest), after what's on its way lands.
    local function Converged(w)
        local ref, who
        for _, c in ipairs(w.clients) do
            if c.online and c.guild and c.ns.Owners then
                local d = c.ns.Owners:Digest()
                if not ref then ref, who = d, c.name
                else eq(d, ref, c.name .. " and " .. who .. " agree on who owns what") end
            end
        end
    end
    local function Owns(c, owner, sid)
        local t = c.ns.Owners:Of("s:" .. sid)
        return t ~= nil and t[owner] == true
    end
    local function Learn(c, ...)
        for _, sid in ipairs({ ... }) do
            c:GivePet(sid)
            c:Fire("NEW_PET_ADDED", c:GuidOf(sid))
        end
    end
    local function OwnSyncs(w, since)
        local n = 0
        for i = (since or 0) + 1, #w.wire do
            local m = w.wire[i]
            if m.kind == "OWN_SYNC" and m.msg.i == 1 then n = n + 1 end
        end
        return n
    end

    test("a 0.7 client and new ones keep syncing the registry; ownership passes it by", function()
        local w = H.World()
        local old = w:AddClient("Gammel Versjon", { from = "v0.7.1", pets = { 46 } })
        local new = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 41 } })
        w:Settle("hello")
        eq(old.ns.PROTOCOL, 10); ok(new.ns.PROTOCOL > 10); eq(new.ns.PROTOCOL_FLOOR, 10)
        new:Slash("adopter")
        old:Slash("adopter")
        w:Run(30)
        eq(old.ns.Registry:Holder("s:5159"), "Ola Nord", "the old client reads a new one's UPD")
        eq(new.ns.Registry:Holder("s:46"), "Gammel Versjon", "and the other way")
        H.assertConverged(w)
        -- Another 0.7 client logs in knowing nothing: a SYNC (stamped 10) brings it all.
        local late = w:AddClient("Gammel To", { from = "v0.7.1", pets = { 40 }, login = false })
        old:Logout()
        late:Login()
        w:Run(40)
        eq(late.ns.Registry:Holder("s:5159"), "Ola Nord")
        eq(late.ns.Registry:Holder("s:46"), "Gammel Versjon")
        H.assertConverged(w)
        old:Login()
        w:Run(40)
        -- The new ones know who owns what; the old one's pet is known by its adoption.
        ok(Owns(new, "Kari Berg", 41)); ok(Owns(kari, "Ola Nord", 5159))
        ok(new.ns.Owners:Any("s:46"), "a 0.7 client's adoption counts")
        eq(new.ns.DB:Guild().owns["Gammel Versjon"], nil, "it never sent a list")
        Converged(w)
        -- Every OWN reached the old client and was dropped there, as a kind it doesn't know.
        local stamped = {}
        for _, m in ipairs(w.wire) do
            if not m.from:find("^Gammel") then stamped[m.kind] = m.msg.p end
        end
        eq(stamped.OWN, 11); eq(stamped.OWN_SYNC, 11); eq(stamped.HELLO, 10); eq(stamped.SYNC, 10); eq(stamped.UPD, 10)
        ok(#old:Log("<- OWN") == 0, "never handled")
        -- And it settles: no SYNC going back and forth.
        local m = w:Mark()
        w:Run(600)
        eq(w:Sent("SYNC", nil, m), 0)
        eq(OwnSyncs(w, m), 0)
    end)

    test("the protocol window: a newer client's kinds we know are read, its newer ones and an older floor's not", function()
        local w = H.World()
        local me = w:AddClient("Ola Nord", { version = "v0.8.0" })
        -- One protocol past ours with the floor still 10: everything it shares with us goes out at 10.
        local P = me.ns.PROTOCOL
        local newer = w:AddClient("Ny Versjon", { protocol = tostring(P + 1), floor = "10", version = "v0.9.0" })
        w:Settle("hello")
        newer:Slash("adopter")
        w:Run(10)
        eq(me.ns.Registry:Holder("s:5159"), "Ny Versjon")
        w:InjectMessage("Ny Versjon", { k = "UPD", p = P + 1, r = { at = w:ServerTime(), ts = w:ServerTime() } })
        w:Run(2)
        eq(me.ns.Registry:Holder("s:5159"), "Ny Versjon", "a kind stamped past ours is dropped")
        ok(me:Printed("En nyere versjon %(v0.9.0%)"), "its version is still heard")
        -- A floor past ours: we're too old for it; nothing but HELLO crosses.
        local far = w:AddClient("Langt Fram", { protocol = tostring(P + 2), floor = tostring(P + 1), pets = { 46 } })
        w:Settle("hello")
        far:Slash("adopter")
        w:Run(10)
        eq(me.ns.Registry:Holder("s:46"), nil)
        eq(me.ns.DB:Guild().owns["Langt Fram"], nil)
    end)

    test("everyone learns who owns what, those who were offline too, with one answer a round", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        local kari = w:AddClient("Kari Berg", { pets = { 41 } })
        local per = w:AddClient("Per Hansen", { pets = { 42 }, login = false })
        w:Settle("hello")
        ok(Owns(ola, "Kari Berg", 41)); ok(Owns(kari, "Ola Nord", 40)); ok(Owns(kari, "Ola Nord", 5159))
        no(Owns(ola, "Per Hansen", 42), "never online")
        local m = w:Mark()
        per:Login()
        w:Run(60)
        ok(Owns(per, "Ola Nord", 40), "the OWN_SYNC brought it"); ok(Owns(per, "Kari Berg", 41))
        ok(Owns(ola, "Per Hansen", 42), "his own OWN")
        eq(OwnSyncs(w, m), 1, "one of the two answered; the other's was cancelled")
        Converged(w)
        -- A login with nothing new costs nothing.
        m = w:Mark()
        kari:Reload()
        w:Run(60)
        eq(OwnSyncs(w, m), 0); eq(w:Sent("OWN", nil, m), 0)
        -- Saved: after a reload the store is still there.
        ok(Owns(kari, "Per Hansen", 42))
    end)

    test("pets learned go out once together; the list never shrinks", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 41 } }
        local m = w:Mark()
        Learn(kari, 46, 84)
        w:Run(1)
        Learn(kari, 72)
        w:Run(kari.ns.Config.OWN_LEARN_DELAY + 1)
        eq(w:Sent("OWN", "Kari Berg", m), 1, "a few at once: one OWN")
        eq(kari.ns.DB:Guild().owns["Kari Berg"].s, "41,46,72,84", "ascending")
        for _, sid in ipairs({ 46, 72, 84 }) do ok(Owns(ola, "Kari Berg", sid)) end
        -- The journal reads short (not loaded yet, say): what we had stays, and nothing goes out.
        kari.pets = {}
        m = w:Mark()
        kari:Reload()
        w:Run(30)
        eq(kari.ns.DB:Guild().owns["Kari Berg"].s, "41,46,72,84")
        eq(w:Sent("OWN", "Kari Berg", m), 0)
        -- A pet learned again (the same one): nothing new.
        Learn(kari, 41)
        w:Run(kari.ns.Config.OWN_LEARN_DELAY + 1)
        eq(w:Sent("OWN", "Kari Berg", m), 0)
        -- Not in a guild: nothing to tell.
        kari.guild = nil
        Learn(kari, 90)
        w:Run(kari.ns.Config.OWN_LEARN_DELAY + 1)
        eq(w:Sent("OWN", "Kari Berg", m), 0)
    end)

    test("a lost OWN comes with the next HELLO's OWN_SYNC", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 41 } }
        w.drop = function(_, r) return r.name == "Ola Nord" end
        Learn(kari, 46)
        w:Run(kari.ns.Config.OWN_LEARN_DELAY + 1)
        w.drop = nil
        no(Owns(ola, "Kari Berg", 46))
        ola:Reload()
        w:Run(60)
        ok(Owns(ola, "Kari Berg", 46))
        Converged(w)
    end)

    test("forged or broken entries are refused; a copy of ours that isn't ours is answered", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 41 } }
        local now = w:ServerTime()
        local before = ola.ns.Owners:Digest()
        local bad = {
            ["Kari Berg"] = { at = now + 10, s = "41,40" },            -- not ascending
            ["Per Hansen"] = { at = now, s = "041" },                  -- a zero in front
            ["Liv Lund"] = { at = now + 3600, s = "40" },              -- from the future
            ["Bo Berg"] = { at = now, s = "40,,41" },                  -- an empty id
            ["Ny|Navn"] = { at = now, s = "40" },                      -- a name the chat can't take
            ["Gammel Kar"] = { at = 1000, s = "40" },                  -- older than the addon
            ["Lang Liste"] = { at = now, s = ("1,"):rep(3000) .. "2" }, -- too long
            ["Tabell Mann"] = { at = now, s = { 40 } },
        }
        w:InjectMessage("Kari Berg", { k = "OWN_SYNC", p = 11, o = bad, i = 1, of = 1, d = 1 })
        w:InjectMessage("Kari Berg", { k = "OWN", p = 11, e = "nope" })
        w:Run(2)
        eq(ola.ns.Owners:Digest(), before, "nothing taken")
        -- The longest list a member could have is fine; one more isn't.
        local ids = {}
        for i = 1, 512 do ids[i] = i end
        ok(ola.ns.Wire.Owned(table.concat(ids, ",")))
        ids[513] = 513
        no(ola.ns.Wire.Owned(table.concat(ids, ",")))
        -- Too many entries in one message: refused whole.
        local many = {}
        for i = 1, ola.ns.Config.SYNC_MAX_ENTRIES + 1 do many["Navn " .. i] = { at = now, s = "40" } end
        w:InjectMessage("Kari Berg", { k = "OWN_SYNC", p = 11, o = many, i = 1, of = 1, d = 1 })
        w:Run(2)
        eq(ola.ns.Owners:Digest(), before)
        ok(#ola:Log("refused an OWN_SYNC from Kari Berg") >= 1)
        -- Someone says Ola owns everything: Ola's own list stays, written newer, and the guild takes it.
        local mine = ola.ns.DB:Guild().owns["Ola Nord"]
        local was = mine.at
        local m = w:Mark()
        w:InjectMessage("Kari Berg", { k = "OWN_SYNC", p = 11, o = { ["Ola Nord"] = { at = now + 60, s = "40,41,42,46" } },
            i = 1, of = 1, d = 1 })
        w:Run(5)
        eq(ola.ns.DB:Guild().owns["Ola Nord"].s, "5159")
        ok(ola.ns.DB:Guild().owns["Ola Nord"].at > was)
        eq(w:Sent("OWN", "Ola Nord", m), 1)
        -- (Kari's copy is the forger's here: injected straight to Ola, never to her)
        eq(kari.ns.DB:Guild().owns["Ola Nord"].s, "5159")
        -- An older copy of ours changes nothing.
        m = w:Mark()
        w:InjectMessage("Kari Berg", { k = "OWN_SYNC", p = 11, o = { ["Ola Nord"] = { at = was - 5, s = "40" } }, i = 1, of = 1, d = 1 })
        w:Run(5)
        eq(w:Sent("OWN", "Ola Nord", m), 0)
    end)

    test("a newer copy of our list from before this login (our other PC's) joins ours", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 41 } }
        -- Written on the other PC an hour before this login, with a pet this one's SavedVariables don't have.
        ola:Logout(); w:Skip(7200); ola:Login(); w:Settle("hello")
        local at = ola.ns.DB:Guild().owns["Ola Nord"].at
        local m = w:Mark()
        w:InjectMessage("Kari Berg", { k = "OWN_SYNC", p = 11, i = 1, of = 1, d = 1,
            o = { ["Ola Nord"] = { at = at + 1, s = "40,5159" } } })
        w:Run(5)
        eq(ola.ns.DB:Guild().owns["Ola Nord"].s, "40,5159", "joined, not outdone")
        eq(w:Sent("OWN", "Ola Nord", m), 1)
        eq(kari.ns.DB:Guild().owns["Ola Nord"].s, "40,5159")
    end)

    test("members only: a non-member's list isn't kept, and who leaves goes at the next roster", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 41 } }
        local now = w:ServerTime()
        w:InjectMessage("Kari Berg", { k = "OWN_SYNC", p = 11, o = { ["Ikke Medlem"] = { at = now, s = "40" } }, i = 1, of = 1, d = 1 })
        w:Run(2)
        no(Owns(ola, "Ikke Medlem", 40), "the roster doesn't list them")
        ok(Owns(ola, "Kari Berg", 41))
        w:RemoveMember("Kari Berg")
        ola.ns.Guild:Refresh(true)
        w:Run(20)
        no(Owns(ola, "Kari Berg", 41), "pruned")
        ok(Owns(ola, "Ola Nord", 5159), "ours stays")
    end)

    test("a big guild's OWN_SYNC goes in parts, and a newcomer gets all of it", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local now = w:ServerTime()
        for i = 1, 60 do
            local name = ("Medlem Nr%02d"):format(i)
            w:AddMember(name, 0)
            w:InjectMessage(name, { k = "OWN", p = 11, e = { at = now, s = "40,41," .. (100 + i) } })
        end
        w:Run(5)
        eq(#ola.ns.Owners:Others("s:40"), 60)
        local nykommer = w:AddClient("Ny Kommer", { pets = { 46 } })
        local m = w:Mark()
        w:Run(90)
        local parts = {}
        for i = m + 1, #w.wire do
            local x = w.wire[i]
            if x.kind == "OWN_SYNC" and x.from == "Ola Nord" then parts[#parts + 1] = x.msg end
        end
        eq(#parts, 3, "25 members a part")
        eq(parts[3].of, 3); ok(parts[3].d ~= nil); eq(parts[1].d, nil, "the digest in the last part only")
        eq(#nykommer.ns.Owners:Others("s:41"), 60)
        ok(Owns(nykommer, "Ola Nord", 5159))
        ok(Owns(nykommer, "Medlem Nr60", 160))
        Converged(w)
    end)

    test("the card's home line names the others who have it: two by name, a count from three", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        local kari = w:AddClient("Kari Berg", { pets = { 5159, 40 } })
        w:AddClient("Per Hansen", { pets = { 40, 41 } })
        local liv = w:AddClient("Liv Lund", { pets = { 41 } })
        w:Settle("hello")
        ola:OpenJournal()
        local function Home(sid)
            local card = ola:SelectPet(sid)
            return ola:TipOf(card.nameHit).text
        end
        match(Home(5159), "Kari Berg har også dette dyret%.$", "one, and you have it too")
        kari:Slash("adopter panda")
        w:Run(5)
        local tip = Home(5159)
        match(tip, "Flyttet inn hos Kari Berg")
        no(tip:find("Kari Berg har", 1, true), "the holder isn't named twice")
        match(Home(40), "Kari Berg og Per Hansen har også dette dyret%.$")
        -- Liv learns one too: three others, a count.
        Learn(liv, 40)
        w:Run(ola.ns.Config.OWN_LEARN_DELAY + 1)
        match(Home(40), "3 andre i guilden har også dette dyret%.$")
        -- A pet you don't have, nobody's adopted: no "også".
        eq(ola.ns.Owners:Line("s:41"), "Liv Lund og Per Hansen har dette dyret.")
        Learn(kari, 41); Learn(ola, 46)
        w:Run(ola.ns.Config.OWN_LEARN_DELAY + 1)
        eq(ola.ns.Owners:Line("s:41"), "3 i guilden har dette dyret.")
        eq(ola.ns.Owners:Line("s:72"), nil, "nobody")
        eq(liv.ns.Owners:Line("s:46"), "Ola Nord har dette dyret.")
    end)
end
