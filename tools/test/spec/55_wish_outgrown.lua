-- Wishes a character has outgrown (2026-11-13, the user, D2 option B): an explore wish comes true by
-- finding a new area or entering a zone not fully explored, and by itself with everything explored and
-- seen; a skill wish by itself with every profession at its cap. The explore wish's events only on its day.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local OWL = "s:68"

    -- Ola with her owl adopted and out, and today's wish the one given (made now, as at the day's start).
    local function Setup(id, each, kari)
        local w, ola, k = H.Setup{ ola = { 68, 40 }, kari = kari, settle = "bond", each = each }
        ola:Slash("adopter owl")
        w:Run(5)
        eq(ola.ns.Registry:MyPet(), OWL)
        eq(ola.ns.Pets:OutKey(), OWL)
        ola.ns.Wish.For = function() return id end
        ola.ns.DB.char.wish = nil
        -- Its usual zone, seen long ago: no new place for it here.
        ola.ns.DB.char.places[OWL] = { m1429 = true }
        ola.state.explored = { ["Elwynn Forest"] = true }
        ola:OpenJournal()
        return w, ola, ola.ns.Wish, k
    end
    test("an explore wish: a new area of your own does it, even where the owl has been before", function()
        local w, ola, W = Setup("explore")
        local wish = W:Today()
        eq(wish.id, "explore"); no(wish.done)
        -- Back to Elwynn, seen: no new place, no wish.
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        no(W:Today().done, "a zone it has seen, and fully explored")
        -- Another pet out: not its wish.
        ola:Summon(40)
        ola:Fire("UI_INFO_MESSAGE", 0, "Discovered: Goldshire")
        no(W:Today().done, "the cat found it")
        ola:Summon(68)
        -- Not any line on screen.
        ola:Fire("UI_INFO_MESSAGE", 0, "Not enough mana")
        no(W:Today().done)
        local before = ola:Points(OWL)
        ola:Fire("UI_INFO_MESSAGE", 0, "Discovered: Goldshire")
        ok(W:Today().done)
        ok(ola:PrintedLine("wish.granted", { pet = "Great Horned Owl", activity = "nye steder", n = 10 }))
        eq(ola:Points(OWL) - before, 10)
        eq(ola.ns.DB.char.wishes.n, 1, "counted in the streak")
        no(W:Watching(), "done: the events go")
        -- In system chat too, with the experience it gives (another day).
        w:SkipDays(1)
        ola.ns.DB.char.wish = nil
        W:Today()
        ok(W:Watching())
        ola:Fire("CHAT_MSG_SYSTEM", "Discovered Moonbrook: 120 experience gained")
        ok(W:Today().done)
        eq(ola.ns.DB.char.wishes.streak, 2)
    end)

    test("an explore wish: entering a zone not fully explored does it, not one explored or off the lists", function()
        local w, ola, W = Setup("explore")
        W:Today()
        ola.state.zone = "Elwynn Forest"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        no(W:Today().done, "fully explored")
        ola.state.zone = "The Deadmines"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        no(W:Today().done, "not a zone on the lists")
        ola.state.zone = "Westfall"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        no(W:Today().done, "a few seconds on, with the pet back out")
        w:Run(6)
        ok(W:Today().done)
        ok(ola:PrintedLine("wish.granted.full", { pet = "Great Horned Owl", activity = "nye steder" }))
    end)

    test("an explore wish comes true by itself once everything is explored and the owl has seen it all", function()
        local w, ola, W = Setup("explore")
        local explored = {}
        for _, list in pairs(H.EXPLORE_ZONES) do
            for _, zone in ipairs(list) do explored[zone] = true end
        end
        ola.state.explored = explored
        -- Every zone but Darkshore seen together: not yet.
        local places = ola.ns.DB.char.places[OWL]
        for zone in pairs(explored) do if zone ~= "Darkshore" then places["z" .. zone] = true end end
        no(W:Today().done, "Darkshore still to see together")
        ok(W:Watching())
        -- Darkshore by its map id (the client's name for it).
        ola.state.mapNames = { [1439] = "Darkshore" }
        places.m1439 = true
        ola:SelectPet(68) -- (the card shows it)
        ok(W:Today().done)
        ok(ola:Printed("Great Horned Owl har sett hver krok av verden sammen med deg, og ønsker seg bare å være med deg i dag. Ønsket er oppfylt! (+10 båndpoeng)", true))
        eq(ola.ns.DB.char.wishes.n, 1)
        no(W:Watching())
        -- Read by the category when the id form gives nothing; not without the pet out.
        w:SkipDays(1)
        ola.state.achievementsById = false
        ola:Summon(40)
        ola.ns.DB.char.wish = nil
        no(W:Today().done, "the owl isn't out")
        ola:Summon(68)
        ola.ns.Activity:Emit("quest", 1)
        ok(W:Today().done, "by the category's list")
    end)

    test("a skill wish comes true by itself with every profession at its cap, not with one below it", function()
        local w, ola, W = Setup("skill")
        no(W:Today().done, "no professions: one can still be learned")
        w:SkipDays(1)
        ola.state.professions = { [1] = { "Herbalism", 225, 225 }, [4] = { "Fishing", 193, 225 } }
        ola.ns.DB.char.wish = nil
        no(W:Today().done, "fishing below its cap")
        ola:SelectPet(68)
        no(W:Today().done)
        ola.state.professions[4][2] = 225
        ola:SelectPet(68)
        ok(W:Today().done)
        ok(ola:Printed("Du har lært alt trenerne kan lære deg, og Great Horned Owl er stolt av deg. Ønsket er oppfylt! (+10 båndpoeng)", true))
        eq(ola.ns.DB.char.wishes.n, 1)
        no(W:Watching(), "never the explore events")
    end)

    test("the explore wish's events only on its day, and gone when the day ends", function()
        local w, ola, W = Setup("herb")
        local E = ola.ns.Events
        local function Any()
            for _, e in ipairs({ "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM", "ZONE_CHANGED_NEW_AREA" }) do
                if E:Has(e, W.WATCH) then return true end
            end
            return false
        end
        W:Today()
        no(W:Watching()); no(Any(), "a herb wish: nothing more watched")
        w:SkipDays(1)
        W.For = function() return "explore" end
        W:Today()
        ok(W:Watching()); ok(E:Has("UI_INFO_MESSAGE", W.WATCH)); ok(E:Has("ZONE_CHANGED_NEW_AREA", W.WATCH))
        -- Kept through a reload.
        ola:Reload()
        w:Run(15)
        W = ola.ns.Wish
        ok(W:Watching(), "a wish made before the reload")
        -- Past midnight, the next event finds a new day's wish, a herb: off.
        w:SkipDays(1)
        W.For = function() return "herb" end
        ola:Fire("UI_INFO_MESSAGE", 0, "Not enough mana")
        no(W:Watching()); no(Any())
        eq(W:Today().id, "herb")
    end)
    -- A friend's gathering (2026-11-15, the user): a party member mining near you does a mining wish. By
    -- their Dyreparken's GATHER on the party (their casts are secret to us on Forever).
    test("a gathering wish: a party member's gathering nearby does it, by message, with its own line; the wish only", function()
        local w, ola, W, kari = Setup("mine", nil, { 40 })
        eq(W:Today().id, "mine")
        local function Mine(c, id) c:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", id or 2575); w:Run(2) end
        Mine(kari)
        eq(w:Sent("GATHER"), 0, "alone: nobody to tell")
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        Mine(kari, 2366) -- (herbs: not the wish)
        eq(w:Sent("GATHER"), 1); no(W:Today().done)
        w:Run(W.GATHER_EVERY)
        w.apart = { ["Kari Berg"] = true }
        Mine(kari)
        no(W:Today().done, "too far away")
        w.apart = nil
        w:Run(W.GATHER_EVERY)
        ola:Summon(40)
        Mine(kari)
        no(W:Today().done, "the owl isn't out")
        ola:Summon(68)
        Mine(kari)
        eq(w:Sent("GATHER"), 3, "one a kind every GATHER_EVERY seconds")
        w:Run(W.GATHER_EVERY)
        local before = ola:Points(OWL)
        Mine(kari)
        ok(W:Today().done)
        ok(ola:Printed("Great Horned Owl fikk se Kari Berg gjøre det, og ønsket ble oppfylt", true))
        eq(ola:Points(OWL) - before, 10)
        eq((ola.ns.Activity:Count("mine")), 0, "not your activity")
        -- Another day: not in a fight, not from outside the party, not in a raid.
        w:SkipDays(1)
        ola.ns.DB.char.wish = nil
        W:Today()
        ola:EnterCombat()
        w:Run(W.GATHER_EVERY); Mine(kari)
        no(W:Today().done, "in a fight")
        ola:LeaveCombat()
        w:InjectMessage("Per Hansen", { k = "GATHER", p = ola.ns.PROTOCOL, g = "mine" }, "PARTY")
        w:Run(1)
        no(W:Today().done, "not in our party")
        w:InjectMessage("Kari Berg", { k = "GATHER", p = ola.ns.PROTOCOL, g = { "mine" } }, "PARTY")
        w:Run(1)
        no(W:Today().done, "a malformed kind")
        w:SetGroup({ "Ola Nord", "Kari Berg", "Per Hansen", "Liv Lund", "Siv Dahl", "Tor Eng" })
        local sent = w:Sent("GATHER")
        w:Run(W.GATHER_EVERY); Mine(kari)
        eq(w:Sent("GATHER"), sent, "a raid: nobody told")
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        w:Run(W.GATHER_EVERY); Mine(kari)
        ok(W:Today().done)
    end)

    test("a gathering wish comes true by a node hovered: a herb for herbs, not a vein; never in a fight", function()
        local w, ola, W = Setup("herb")
        local wish = W:Today()
        eq(wish.id, "herb"); no(wish.done)
        ola:HoverObject({ "Copper Vein", "Mining" })
        no(W:Today().done, "a vein isn't a herb")
        ok(ola:Log("hovered: Copper Vein / Mining %(mine%)")[1], "what it saw, in the log")
        ola:HoverObject({ "" })
        no(ola:Log("hovered:  ")[1], "an empty tooltip isn't logged (2026-11-24)")
        ola:EnterCombat()
        ola:HoverObject({ "Peacebloom", "Herbalism" })
        no(W:Today().done, "not in a fight")
        ola:LeaveCombat()
        ola:HoverObject({ "Peacebloom", "Herbalism" })
        ok(W:Today().done)
        ok(ola:Printed("fikk se det på nært hold", true))
        -- Not a trainer's tooltip (review 2026-11-19), nor a unit's "Herbalism" at all.
        local w4, liv, W4 = Setup("herb")
        W4:Today()
        liv:Hover({ unit = false, lines = { { leftText = "Herbalist Ella" }, { leftText = "Herbalism Trainer" } } })
        no(W4:Today().done, "a trainer")
        liv:HoverObject({ "Herbalism Trainer's Sign", "Herbalism" })
        no(W4:Today().done, "a line that says trainer, anywhere")
        -- On foot with the pet out only: not from a flight path or a mount (the user, 2026-11-19).
        liv.state.taxi = true
        liv:HoverObject({ "Peacebloom", "Herbalism" })
        no(W4:Today().done, "from the flight path")
        liv.state.taxi = false; liv:Mount()
        liv:HoverObject({ "Peacebloom", "Herbalism" })
        no(W4:Today().done, "mounted")
        liv:Dismount()
        liv:HoverObject({ "Peacebloom", "Herbalism" })
        ok(W4:Today().done, "on foot")
        -- A skinning wish by a skinnable corpse, a unit's tooltip.
        local w2, kari, W2 = Setup("skin")
        eq(W2:Today().id, "skin") -- (made, as the day's first activity does)
        kari:Hover({ unit = false, lines = { { leftText = "Young Wolf" }, { leftText = "Skinnable" } } })
        ok(W2:Today().done, "a skinnable corpse")
        -- Another wish: hovering does nothing.
        local w3, per, W3 = Setup("quest")
        W3:Today()
        per:HoverObject({ "Peacebloom", "Herbalism" })
        no(W3:Today().done)
        no(per:Log("hovered:")[1], "not even read")
    end)
end
