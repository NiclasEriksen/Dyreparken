-- Personality (likes and a quirk per species), the gathering activities,
-- and the bond points they bring (Personality.lua, Activity.lua, Bond.lua).
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Fixture()
        return { build = 1, species = {
            [40] = { a = true, t = { "cat" } }, [84] = { a = true, t = { "bird", "dragon" } },
            [5159] = { a = false }, [72] = { a = true },
        } }
    end

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        ola.ns.Companions = Fixture()
        w:Run(40)
        return w, ola, ola.ns.Personality
    end

    local function Herb(c) c:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 2366) end

    test("likes come from the species, the families and the quirk", function()
        local w, ola, P = Setup()
        local likes, list, quirk = P:Of(PANDA)
        eq(list[1], "herb", "the panda's own: bamboo")
        eq(quirk.name, "Kosete")
        eq(P:Line(PANDA), "Kosete · liker urtesanking", "dager sammen isn't listed as a like")
        ok(likes.day)
        local cat = { P:Of("s:40") }
        ok(cat[1].fish, "cats like fishing")
        local dragon = { P:Of("s:84") }
        ok(dragon[1].boss and dragon[1].taxi, "the dragon's likes")
        ok(P:Of("s:72").quest, "no family: quests")
        -- Joined in Norwegian.
        P.QUIRKS = { { name = "Glupsk", desc = "", like = "quest" } }
        eq(P:Line("s:84"), "Glupsk · liker boss-drap, flyturer og oppdrag")
        P.QUIRKS = { { name = "Kosete", desc = "", like = "day" } }
        eq(P:Line("s:999"), "Kosete · liker oppdrag")
        P.BY_FAMILY, P.DEFAULT = {}, {}
        eq(P:Line("s:999"), "Kosete", "nothing liked but the days")
    end)

    test("quirks are picked from the species: the same everywhere, all of them in use", function()
        local w, ola, P = Setup()
        local kari = w:AddClient("Kari Berg")
        w:Run(12)
        local seen = {}
        for sid = 1, 400 do
            local key = "s:" .. sid
            eq(P:Quirk(key).name, kari.ns.Personality:Quirk(key).name)
            seen[P:Quirk(key).name] = true
        end
        for _, q in ipairs(P.QUIRKS) do ok(seen[q.name], q.name) end
    end)

    test("gathering: your own casts, by spell id or name, out of combat", function()
        local w, ola = Setup()
        local A = ola.ns.Activity
        Herb(ola)
        eq(A:Count("herb"), 1)
        ola.state.spellNames = { [99001] = "Mining", [99002] = "Fishing", [99003] = "Skinning", [99004] = "Frostbolt" }
        for id = 99001, 99004 do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", id) end
        eq(A:Count("mine"), 1); eq(A:Count("fish"), 1); eq(A:Count("skin"), 1)
        -- Registered for the player only, so a raid's casts never even reach us.
        local filters = 0
        for _, f in ipairs(ola.frames) do
            local u = f.unitFilter and f.unitFilter.UNIT_SPELLCAST_SUCCEEDED
            if u and f.events.UNIT_SPELLCAST_SUCCEEDED then
                filters = filters + 1
                eq(u[1], "player"); eq(#u, 1)
            end
        end
        eq(filters, 1, "one unit-filtered registration")
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "Cast", 2366)
        eq(A:Count("herb"), 1, "someone else's cast never reaches us")
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", H.SECRET)
        ola:EnterCombat()
        Herb(ola)
        ola:LeaveCombat()
        eq(A:Count("herb"), 1, "secret ids and casts in combat don't count")
        eq(ola.ns.Activity.GatherKind(nil), nil)
    end)

    test("liked activities bring more bond points, capped per day; the first one gets a line", function()
        local w, ola, P = Setup()
        ola:Slash("adopter panda")
        w:Run(40)
        local function Points() return ola.ns.Registry:Life(PANDA, "Ola Nord").p end
        ola.ns.Activity:CheckDay()
        eq(Points(), 20, "Kosete: a day counts double")
        Herb(ola)
        eq(Points(), 25, "a liked activity: 5")
        ok(ola:Printed("Panda Cub koste seg med urtesanking!", true))
        for _ = 1, 10 do Herb(ola) end
        eq(Points(), 45, "at most 25 a day from herbs")
        ola:Fire("QUEST_TURNED_IN", 1)
        eq(Points(), 46, "anything else: 1")
        for _ = 1, 10 do ola:Fire("QUEST_TURNED_IN", 1) end
        eq(Points(), 50, "at most 5 a day")
        local lines = 0
        for _, l in ipairs(ola.printed) do if l:find("koste seg", 1, true) then lines = lines + 1 end end
        eq(lines, 1, "one line a day")
        -- A new day.
        w:SkipDays(1)
        Herb(ola)
        eq(Points(), 55)
        -- Not with another companion out.
        ola:Summon(40)
        Herb(ola)
        eq(Points(), 55)
    end)

    test("the card and tooltips tell its personality", function()
        local w, ola, P = Setup()
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        eq(card.personality.text, "Kosete · liker urtesanking")
        local tip = ola.env.GameTooltip
        tip:ClearLines()
        ola.ns.JournalUI:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "trenger et hjem / Kosete · liker urtesanking$")
        ola:Slash("adopter panda")
        tip:ClearLines()
        ola.ns.JournalUI:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "Bånd: .* / Kosete · liker urtesanking / Siden i dag$")
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        eq(card.personality.text, "")
    end)
end
