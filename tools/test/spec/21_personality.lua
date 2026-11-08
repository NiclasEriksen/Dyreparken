-- Personality (likes and two traits per species), the gathering activities,
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

    -- Give a client's pets these traits (by id), whatever the species.
    local function Give(c, ...)
        local ids = { ... }
        c.ns.Personality.Traits = function()
            local list = {}
            for _, id in ipairs(ids) do list[#list + 1] = c.ns.Personality.ById(id) end
            return list
        end
    end

    test("likes come from the species, the families and the traits", function()
        local w, ola, P = Setup()
        Give(ola, "kosete", "nattugle")
        local likes, list, traits = P:Of(PANDA)
        eq(list[1], "herb", "the panda's own: bamboo")
        eq(#list, 1, "neither trait adds a like")
        eq(traits[1].name, "Kosete"); eq(traits[2].name, "Nattugle")
        eq(P:Line(PANDA), "Kosete og Nattugle · liker herbs")
        local cat = { P:Of("s:40") }
        ok(cat[1].fish, "cats like fishing")
        local dragon = { P:Of("s:84") }
        ok(dragon[1].boss and dragon[1].taxi, "the dragon's likes")
        ok(P:Of("s:72").quest, "no family: quests")
        Give(ola, "glupsk", "reiseglad")
        eq(P:Line("s:84"), "Glupsk og Reiseglad · liker boss-kills, flyturer og quests", "a like is listed once")
        P.BY_FAMILY, P.DEFAULT = {}, {}
        Give(ola, "kosete", "helgedyr")
        eq(P:Line("s:999"), "Kosete og Helgedyr", "nothing liked but the days")
        -- What each kind of trait does, in numbers.
        local E = function(id) return P:Effect(P.ById(id)) end
        eq(E("glupsk"), "Quests med kjæledyret ute gir 5 bånd-poeng (opptil 25 om dagen), mot 1 ellers.")
        eq(E("kosete"), "Hver dag sammen gir dobbelt så mange bånd-poeng (20 i stedet for 10).")
        eq(E("helgedyr"), "En lørdag eller søndag sammen gir dobbelt så mange bånd-poeng (20 i stedet for 10).")
        match(E("festglad"), "^En høytidsdag sammen %(17%. mai, .*%) gir tre ganger så mange bånd%-poeng %(30 i stedet for 10%)%.$")
        eq(E("flokkdyr"), "Alt dere gjør sammen med en fra guilden i gruppen gir 5 bånd-poeng (opptil 25 om dagen), mot 1 ellers.")
    end)

    test("two traits per species: the same everywhere, never a contradiction, all of them in use", function()
        local w, ola, P = Setup()
        local kari = w:AddClient("Kari Berg")
        w:Run(12)
        local seen = {}
        for sid = 1, 600 do
            local key = "s:" .. sid
            local a, b = P:Traits(key), kari.ns.Personality:Traits(key)
            eq(#a, 2, key)
            eq(a[1].id, b[1].id); eq(a[2].id, b[2].id)
            ok(a[1] ~= a[2], "two different ones")
            ok(a[1].against ~= a[2].id and a[2].against ~= a[1].id, "never Flokkdyr and Einstøing together")
            seen[a[1].id], seen[a[2].id] = true, true
        end
        for _, q in ipairs(P.TRAITS) do ok(seen[q.id], q.id) end
        -- Pinned species keep theirs (Data/Traits.lua).
        eq(P:Names(PANDA), "Kosete og Grønnfinger")
    end)

    test("every journal species is pinned to two real traits that go together", function()
        local w = H.World()
        local kari = w:AddClient("Kari Berg") -- the real Data/Companions.lua
        w:Run(12)
        local P, pins = kari.ns.Personality, kari.ns.TraitPins
        ok(pins, "Data/Traits.lua is loaded")
        eq(P.PINNED, pins)
        local n = 0
        for sid in pairs(kari.ns.Companions.species) do
            ok(pins[sid], "species " .. sid .. " pinned (run tools/pin_traits.lua)")
            n = n + 1
        end
        ok(n > 50)
        for sid, pin in pairs(pins) do
            local a, b = P.ById(pin[1]), P.ById(pin[2])
            ok(a and b and a ~= b, "pin " .. sid)
            ok(a.against ~= b.id, "pin " .. sid .. " contradicts itself")
            local t = P:Traits("s:" .. sid)
            eq(t[1], a); eq(t[2], b)
        end
        -- Every pair that contradicts itself names the other way too.
        for _, q in ipairs(P.TRAITS) do
            if q.against then eq(P.ById(q.against).against, q.id) end
        end
    end)

    test("day traits: Kosete, the weekend and the holidays multiply the day", function()
        local w, ola, P = Setup()
        local function At(y, m, d) return os.time({ year = y, month = m, day = d, hour = 12 }) end
        Give(ola, "kosete", "helgedyr")
        eq(P:DayFactor(PANDA, At(2026, 11, 9)), 2, "a Monday: Kosete only")
        eq(P:DayFactor(PANDA, At(2026, 11, 7)), 4, "a Saturday: both")
        local x, why = P:DayFactor(PANDA, At(2026, 11, 8))
        eq(x, 4); eq(why.id, "kosete", "the first one that counted")
        Give(ola, "festglad", "glupsk")
        eq(P:DayFactor(PANDA, At(2027, 5, 17)), 3, "17. mai")
        eq(P:DayFactor(PANDA, At(2027, 5, 18)), 1)
        eq(P:DayFactor(PANDA, At(2026, 12, 24)), 3, "julaften")
        -- In the bond: today is a holiday (whatever today is), with a line.
        P.HOLIDAYS[os.date("%m%d", ola.ns.Now())] = "testdagen"
        ola:Slash("adopter panda")
        w:Run(40)
        ola.ns.Activity:CheckDay()
        eq(ola.ns.Registry:Life(PANDA, "Ola Nord").p, 30)
        ok(ola:Printed("Panda Cub feirer testdagen med deg!", true))
    end)

    test("when traits: anything done at the right moment is liked, with one cap per trait", function()
        local w, ola, P = Setup()
        local kari = w:AddClient("Kari Berg")
        ola.ns.Guild:Refresh(true) -- Ola's roster snapshot, with Kari in it
        w:Run(2)
        Give(ola, "flokkdyr", "huleboer")
        ola:Slash("adopter panda")
        w:Run(40)
        local function Points() local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); return e and e.p or 0 end
        local function Quest() ola:Fire("QUEST_TURNED_IN", 1) end
        local start = Points()
        Quest()
        eq(Points(), start + 1, "solo, outdoors: just a quest")
        w:SetGroup({ "Ola Nord", "Per Ukjent" })
        Quest()
        eq(Points(), start + 2, "a group, but nobody from the guild (we don't count)")
        -- In a group with a guildmate: Flokkdyr.
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        Quest()
        eq(Points(), start + 7)
        ok(ola:Printed("Panda Cub koste seg i flokken!", true))
        for _ = 1, 3 do Quest() end
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
        eq(Points(), start + 27, "one cap for the trait, whatever the activity")
        -- Then in a dungeon: Huleboer has its own cap.
        ola.state.instance = "party"
        Quest()
        eq(Points(), start + 32)
        local lines = 0
        for _, l in ipairs(ola.printed) do if l:find("Panda Cub", 1, true) and l:find("!", 1, true) then lines = lines + 1 end end
        eq(lines, 1, "still one line a day")
        -- A battleground isn't a dungeon.
        ola.state.instance = "pvp"
        w:SetGroup({ "Ola Nord", "Per Ukjent" })
        Quest()
        eq(Points(), start + 33, "no guildmate, no dungeon: back to 1")
        -- A group we can't read gives no bonus, and no error.
        ola.env.UnitName = function(u) if u ~= "player" then error("secret") end return "Ola", "Nord" end
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ola.state.instance = "none"
        Quest()
        eq(Points(), start + 34)
    end)

    test("Nattugle, Einstøing and Friluftsdyr read the clock, the group and the world", function()
        local w, ola, P = Setup()
        local function Fit(id, ctx)
            ctx.guildmates = ctx.guildmates or 0
            return P.ById(id).when(ctx) == true
        end
        local function H(h) return os.time({ year = 2026, month = 11, day = 8, hour = h }) end
        ok(Fit("nattugle", { t = H(23) })); ok(Fit("nattugle", { t = H(3) }))
        no(Fit("nattugle", { t = H(4) })); no(Fit("nattugle", { t = H(21) }))
        ok(Fit("einstoing", { group = false })); no(Fit("einstoing", { group = true }))
        ok(Fit("friluftsdyr", { instance = false })); no(Fit("friluftsdyr", { instance = true }))
        -- The context, as Bond builds it.
        local ctx = ola.ns.Bond.Context()
        eq(ctx.group, false); eq(ctx.instance, false); eq(ctx.guildmates, 0)
        ola.state.instance = "raid"
        ok(ola.ns.Bond.Context().instance)
        -- Only built for a pet with such a trait.
        Give(ola, "kosete", "glupsk")
        no(P:WantsContext(PANDA))
        Give(ola, "kosete", "nattugle")
        ok(P:WantsContext(PANDA))
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
            if u and f.events.UNIT_SPELLCAST_SUCCEEDED and f ~= ola.ns.Kills._unitFrame then -- (the debug probe's own)
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
        Give(ola, "kosete", "steinhard")
        ola:Slash("adopter panda")
        w:Run(40)
        local function Points() return ola.ns.Registry:Life(PANDA, "Ola Nord").p end
        ola.ns.Activity:CheckDay()
        eq(Points(), 20, "Kosete: a day counts double")
        Herb(ola)
        eq(Points(), 25, "a liked activity: 5")
        ok(ola:Printed("Panda Cub koste seg med herbs!", true))
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
        Give(ola, "kosete", "reiseglad")
        ola:OpenJournal()
        local card = ola:SelectPet(5159)
        eq(card.personality.text, "Kosete og Reiseglad · liker herbs og flyturer")
        local tip = ola.env.GameTooltip
        tip:ClearLines()
        ola.ns.JournalUI:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "trenger et hjem / Kosete og Reiseglad · liker herbs og flyturer$")
        ola:Slash("adopter panda")
        tip:ClearLines()
        ola.ns.JournalUI:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "Bånd: .* / Kosete og Reiseglad · liker herbs og flyturer / Siden i dag$")
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        eq(card.personality.text, "")
    end)
end
