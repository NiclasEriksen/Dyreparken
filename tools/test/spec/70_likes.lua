-- More likes (2026-11-19, the user): every trait has a like, a third trait opens up at bond level 7, and new
-- activities to like: errands, a meal, a dungeon, a duel (and the rides, boats and zeppelins, watched already).
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159" -- (Data/Unlocks.lua: its third trait Vinterpels, which likes a meal)

    -- Ola's adopted pet (a panda, unless sid), with these traits.
    local function Setup(traits, sid)
        local w, ola = H.Setup{ ola = { sid or 5159 }, journal = true }
        if traits then ola:Traits(traits, sid or 5159) end
        ola.state.auras = {}
        ola:Slash("adopter " .. (sid and "kitten" or "panda")); w:Run(5)
        return w, ola
    end
    local function Count(ola, id) return (ola.ns.Activity:Count(id)) end

    test("errands: the bank, a mailbox or the auction house, once a minute at most; a merchant isn't one", function()
        local w, ola = Setup({ "ordensdyr", "glupsk" })
        local A = ola.ns.Activity
        ok(A:IsListening("PLAYER_INTERACTION_MANAGER_FRAME_SHOW"), "Ordensdyr likes errands: heard")
        local T = ola.env.Enum.PlayerInteractionType
        local before = ola:Points(PANDA)
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.MailInfo); w:Run(1)
        eq(Count(ola, "errand"), 1)
        eq(ola:Points(PANDA), before + 5, "a like: 5 points")
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Banker); w:Run(1)
        eq(Count(ola, "errand"), 1, "within a minute: the same errand")
        w:Run(A.ERRAND_AGAIN)
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Auctioneer); w:Run(1)
        eq(Count(ola, "errand"), 2)
        w:Run(A.ERRAND_AGAIN)
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.CharacterBanker); w:Run(1)
        eq(Count(ola, "errand"), 3, "the bank as Forever's newer engine opens it")
        w:Run(A.ERRAND_AGAIN)
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Merchant); w:Run(1)
        eq(Count(ola, "errand"), 3, "a merchant: no errand")
        eq(#ola:Log("errand: not one, interaction type " .. T.Merchant), 1, "logged, to find a missing one's number")
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.MailInfo)
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Merchant); w:Run(1)
        eq(#ola:Log("errand: not one, interaction type " .. T.Merchant), 1, "once a session (review 2026-11-21: 92 lines)")
    end)

    test("a meal: the Food or Drink buff appearing, not one already on", function()
        local w, ola = Setup({ "vinterpels", "glupsk" })
        local function Buff(name, on) ola.state.auras[name] = on or nil; ola:Fire("UNIT_AURA", "player"); w:Run(1) end
        Buff("Food", true)
        eq(Count(ola, "eat"), 0, "there at the first look")
        Buff("Food", false); Buff("Food", true)
        eq(Count(ola, "eat"), 1)
        Buff("Food", false); Buff("Drink", true)
        eq(Count(ola, "eat"), 1, "a drink right after: the same meal")
        Buff("Drink", false); w:Run(ola.ns.Activity.AURA_AGAIN + 1); Buff("Drink", true)
        eq(Count(ola, "eat"), 2, "a drink is one too")
        eq(#ola:Log("eat: Drink is spell"), 1, "the log names the buff found (2026-11-20: a drink logged as Food)")
        Buff("Food & Drink", true)
        eq(Count(ola, "eat"), 2, "still eating: not again")
        -- A buff going and coming several times in a second (a Welcoming Campfire's minute ending, 2026-11-20).
        Buff("Food & Drink", false); Buff("Drink", false); w:Run(ola.ns.Activity.AURA_AGAIN + 1)
        for _ = 1, 5 do Buff("Drink", false); Buff("Drink", true) end
        eq(Count(ola, "eat"), 3, "once, not five times")
        ok(#ola:Log("Aura\teat on") > 0, "each coming logged")
        eq(#ola:Log("eat: Drink is spell"), 1, "the buff's spell once a session (review 2026-11-21: 62 lines a day)")
    end)

    test("a dungeon: going in, once a visit; not a reload or a login inside, nor the open world", function()
        local w, ola = Setup({ "huleboer", "glupsk" })
        local A = ola.ns.Activity
        local function Enter(kind, zone, login, reload)
            ola:Travel(zone or (kind == "none" and "Desolace" or "Maraudon"), { instance = kind, login = login, reload = reload })
            w:Run(1)
        end
        local before = ola:Points(PANDA)
        Enter("party")
        eq(Count(ola, "dungeon"), 1)
        eq(select(4, A:Count("dungeon", PANDA)), 1, "the pet's"); eq(ola:Points(PANDA), before + 5, "a like")
        Enter("party")
        eq(Count(ola, "dungeon"), 1, "still inside")
        -- Out and back in (2026-11-20, Maraudon: 15 s later, twice): the same visit, and a run back after a wipe.
        Enter("none"); Enter("party")
        eq(Count(ola, "dungeon"), 1, "the same dungeon again soon: the same visit")
        Enter("none"); Enter("raid", "Molten Core")
        eq(Count(ola, "dungeon"), 2, "out and into a raid")
        Enter("none"); Enter("party", "Maraudon", false, true)
        eq(Count(ola, "dungeon"), 2, "a reload inside isn't a visit")
        Enter("none"); Enter("pvp", "Warsong Gulch")
        eq(Count(ola, "dungeon"), 2, "a battleground isn't one")
        w:Run(A.DUNGEON_AGAIN)
        Enter("none"); Enter("party")
        eq(Count(ola, "dungeon"), 3, "Maraudon again, later: a new visit")
        -- Two dungeons from one zone (review 2026-11-21: named by the zone outside, the zone's name still that at
        -- the loading screen's end): each its own, by the instance's name.
        Enter("none", "The Barrens"); Enter("party", "Wailing Caverns")
        Enter("none", "The Barrens"); Enter("party", "Razorfen Kraul")
        eq(Count(ola, "dungeon"), 5, "Wailing Caverns, then Razorfen Kraul")
        ok(ola:Log("dungeon %+1 .*Razorfen Kraul")[1], "named by the instance")
    end)

    test("a dungeon's name: the instance's when it's plain, else the zone's", function()
        local w, ola = Setup({ "huleboer" })
        local A = ola.ns.Activity
        ola.state.instance, ola.state.zone, ola.state.instanceName = "party", "Tanaris", "Zul'Farrak"
        eq(A.DungeonName(), "Zul'Farrak")
        ola.state.instanceName = H.SECRET
        eq(A.DungeonName(), "Tanaris", "a secret name: the zone")
        ola.state.instanceName = ""
        eq(A.DungeonName(), "Tanaris")
        ola.env.GetInstanceInfo = nil
        eq(A.DungeonName(), "Tanaris", "no GetInstanceInfo")
    end)

    test("a dungeon waits for the pet the loading screen took (2026-11-20, Maraudon: counted to no pet)", function()
        local w, ola = Setup({ "huleboer", "glupsk" })
        local A = ola.ns.Activity
        ola.ns.DB.char.places[PANDA] = { zMaraudon = true } -- (been there: no new place's points in the way)
        local before = ola:Points(PANDA)
        local guid = ola.summoned
        ola.summoned = nil -- (gone through the loading screen)
        ola:Travel("Maraudon", { instance = "party" })
        eq(Count(ola, "dungeon"), 0, "not yet: no pet out")
        w:Run(3)
        ola.summoned = guid -- (Summon brings it back)
        w:Run(A.DUNGEON_WAIT[1] + 1)
        eq(Count(ola, "dungeon"), 1)
        eq(select(4, A:Count("dungeon", PANDA)), 1, "to the pet"); eq(ola:Points(PANDA), before + 5)
    end)

    test("a duel of yours, won or lost, is liked by a troublemaker; someone else's isn't", function()
        local w, ola = Setup(nil, 5006) -- (the Corrupted Kitten likes duels: Personality.BY_SPECIES)
        local P = ola.ns.Personality
        ok(P:Of("s:5006").duel)
        local function Sys(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Sys("Kari Berg has defeated Per Hansen in a duel")
        eq(Count(ola, "duel"), 0, "not yours")
        Sys("Ola Nord has defeated Kari Berg in a duel")
        eq(Count(ola, "duel"), 1)
        Sys("Kari Berg has defeated Ola Nord in a duel")
        eq(Count(ola, "duel"), 2, "lost: a duel too")
        eq(Count(ola, "duelwon"), 1); eq(Count(ola, "duellost"), 1)
    end)

    test("the third trait: at your bond's level 7, told once; before it, a hint on the panel", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        eq(#P:Traits(PANDA), 2)
        eq(P:Third(PANDA, true).id, "vinterpels", "pinned in Data/Unlocks.lua")
        local card = ola:SelectPet(5159)
        local function Traits()
            local n = 0
            for _, b in ipairs(card.badges.badges) do if b:IsShown() and b.data.kind == "trait" then n = n + 1 end end
            return n
        end
        eq(Traits(), 2)
        -- Just under level 7, then a real gain over it.
        local e = ola.ns.Registry:Life(PANDA, "Ola Nord")
        e.p, e.f = ola.ns.Bond.LEVELS[7][1] - 1, e.f - 200 * 86400
        match(ola:About(PANDA, "personality").text, "Når båndet ditt blir Sjelevenn, viser Panda Cub deg en ny side")
        ola.ns.Bond:Add(1, PANDA); w:Run(1)
        eq(#P:Traits(PANDA), 3)
        ok(P:Of(PANDA).eat, "and its like")
        ok(ola:Printed("Panda Cub har vist deg en ny side av seg selv: Vinterpels.", true))
        card = ola:SelectPet(5159)
        eq(Traits(), 3, "a third badge")
        no(ola:About(PANDA, "personality").text:find("ny side", 1, true), "no hint once it's there")
        ola.ns.Bonds:TellUnlocks(PANDA, 7)
        eq(ola:CountPrinted("en ny side av seg selv"), 1, "told once")
    end)
end
