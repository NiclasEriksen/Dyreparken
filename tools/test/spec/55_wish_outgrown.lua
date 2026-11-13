-- Wishes a character has outgrown (2026-11-13, the user, D2 option B): an explore wish comes true by
-- finding a new area or entering a zone not fully explored, and by itself with everything explored and
-- seen; a skill wish by itself with every profession at its cap. The explore wish's events only on its day.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local OWL = "s:68"

    -- Ola with her owl adopted and out, and today's wish the one given (made now, as at the day's start).
    local function Setup(id, each)
        local w, ola = H.Setup{ ola = { 68, 40 }, settle = "bond", each = each }
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
        return w, ola, ola.ns.Wish
    end
    local function Earned(ola) local e = ola.ns.Registry:Life(OWL, "Ola Nord"); return e and e.p or 0 end

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
        local before = Earned(ola)
        ola:Fire("UI_INFO_MESSAGE", 0, "Discovered: Goldshire")
        ok(W:Today().done)
        ok(ola:Printed("Great Horned Owl fikk ønsket sitt oppfylt: nye steder! (+10 båndpoeng)", true))
        eq(Earned(ola) - before, 10)
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
        ok(ola:Printed("Great Horned Owl fikk ønsket sitt oppfylt: nye steder!", true))
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
        ok(ola:Printed("Du har lært alt trenerne kan lære deg nå, og Great Horned Owl er stolt av deg. Ønsket er oppfylt! (+10 båndpoeng)", true))
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
end
