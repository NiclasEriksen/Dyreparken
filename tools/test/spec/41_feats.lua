-- Feats (Menagerie/Feats.lua, 2026-11-12, the user): a class quest's reward, riding and level 60 give
-- the pet that's out 25 points, once per character; a trainer visit, a dual-spec switch, a talent
-- reset and the tenth levels are flavor (eggs) only.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"
    local NAMES = { [697] = "Summon Voidwalker", [712] = "Summon Succubus", [71] = "Defensive Stance",
        [5487] = "Bear Form", [1066] = "Aquatic Form", [33388] = "Apprentice Riding" }

    -- Ola, her Panda Cub adopted and out; o.spells: known before she logs in.
    local function Setup(o)
        o = o or {}
        local w, ola = H.Setup{ ola = { 5159, 46 }, each = function(c)
            c.state.spellNames = NAMES
            c.state.spells = {}
            for _, id in ipairs(o.spells or {}) do c.state.spells[id] = true end
            c.state.level = o.level or 10
        end }
        ola:Slash("adopter panda"); w:Run(5)
        local Q = ola.ns.Quirks
        ola:Dice(0) -- (every chance comes up, the first line)
        ola:QuirksNow()
        return w, ola, ola.ns.Feats
    end
    local function Learn(w, ola, id)
        ola.state.spells[id] = true
        ola:Fire("SPELLS_CHANGED")
        w:Run(ola.ns.Feats.SETTLE + 0.5)
    end
    local function Points(ola) return (ola.ns.Bond:Own(PANDA)) end
    local function Rewards(ola) return #ola:Log("reward feat for") end

    test("a spell a class quest teaches: 25 points with the pet out, a line, its story; once", function()
        local w, ola, F = Setup()
        local before = Points(ola)
        Learn(w, ola, 697)
        eq(Points(ola) - before, 25)
        ok(ola:Printed("Pandaen var med da du lærte Summon Voidwalker! (+25 båndpoeng)", true) or
            ola:Printed("var med da du lærte Summon Voidwalker! %(%+25 båndpoeng%)"))
        local rec = ola.ns.DB.char.feats.voidwalker
        eq(rec.key, PANDA); eq(rec.what, "Summon Voidwalker"); no(rec.before)
        local story = ola.ns.Story:Of(PANDA)
        ok(story and story[#story].k == "feat" and story[#story].x == "voidwalker", "in its story")
        eq(ola.ns.Story:Text(PANDA, story[#story]), "Milepæl sammen med deg: Summon Voidwalker")
        -- Its quest handed in as well (both ways see it): still once.
        ola:Fire("QUEST_TURNED_IN", 1689, 0, 0); w:Run(1)
        ola:Fire("SPELLS_CHANGED"); w:Run(2)
        eq(Rewards(ola), 1, "once")
        eq(Points(ola) - before, 26, "(and the quest's own point)")
    end)

    test("a feat goes past the day's limit and isn't counted in it: a full day doesn't lose it", function()
        local w, ola, F = Setup()
        local B = ola.ns.Bond
        local d = ola.ns.DB.char.bondToday.pets[PANDA]
        d.total = 75 -- (a busy day: full)
        local before = Points(ola)
        Learn(w, ola, 697)
        eq(Points(ola) - before, 25, "all of it")
        eq((B:Today(PANDA)), 75, "the day's share stays as it was")
        -- Within the wire's cap all the same: a peer takes it.
        local e = ola.ns.Registry:Life(PANDA, "Ola Nord")
        ok(ola.ns.Registry.ValidLife(e))
    end)

    test("what a character had when we first looked isn't new, and a flood at once isn't feats", function()
        local w, ola, F = Setup{ spells = { 71, 5487 } }
        local feats = ola.ns.DB.char.feats
        ok(feats.defstance.before and feats.bear.before, "had before: no reward")
        local before = Points(ola)
        ola:Fire("SPELLS_CHANGED"); w:Run(2)
        eq(Points(ola), before)
        -- The spellbook arriving late: three at one look.
        ola.state.spells[697], ola.state.spells[712], ola.state.spells[1066] = true, true, true
        ola:Fire("SPELLS_CHANGED"); w:Run(2)
        eq(Points(ola), before, "taken as had before")
        ok(feats.voidwalker.before and feats.succubus.before and feats.aquatic.before)
        -- Nothing seen before the first look (the spells load a while after login).
        local w2, kari = H.World(), nil
        kari = w2:AddClient("Kari Berg", { pets = { 40 } })
        kari.state.spells = { [697] = true }
        kari:Fire("SPELLS_CHANGED"); w2:Run(2)
        eq(kari.ns.DB.char.feats.voidwalker, nil, "not before the first look")
        w2:Run(kari.ns.Feats.FIRST_LOOK)
        ok(kari.ns.DB.char.feats.voidwalker.before)
    end)

    test("an item's quest (a totem), Forever's own copy of a chain; and none without a pet out", function()
        local w, ola, F = Setup()
        local before = Points(ola)
        ola:Fire("QUEST_TURNED_IN", 94375, 0, 0); w:Run(1) -- (the Dwarf Shaman's Call of Earth)
        eq(Points(ola) - before, 26, "25, and the quest's own point")
        ok(ola:Printed("var med da du fikk jordtotemet!"))
        -- No pet out: done, without a reward, and not later either.
        ola:Summon(nil)
        ola:Fire("QUEST_TURNED_IN", 1527, 0, 0); w:Run(1)
        ok(ola.ns.DB.char.feats.fire, "done")
        eq(ola.ns.DB.char.feats.fire.key, nil)
        ola:Summon(5159)
        ola:Fire("QUEST_TURNED_IN", 1527, 0, 0); w:Run(1)
        eq(Rewards(ola), 1, "not later either")
        -- A quest that's no feat: only its own point.
        ola:Fire("QUEST_TURNED_IN", 189, 0, 0); w:Run(1)
        eq(Rewards(ola), 1)
    end)

    test("a totem by the item itself, whichever chain gave it; one had before (its quest done, or in the bags) isn't new", function()
        local w, ola = Setup()
        local before = Rewards(ola)
        ola:Fire("CHAT_MSG_LOOT", "You receive item: |cffffffff|Hitem:5176::::::::36:::::|h[Fire Totem]|h|r.")
        w:Run(1)
        eq(Rewards(ola) - before, 1)
        ok(ola:Printed("var med da du fikk ildtotemet!"))
        ola:Fire("CHAT_MSG_LOOT", "Kari Berg receives item: |cffffffff|Hitem:5177::::::::36:::::|h[Water Totem]|h|r.")
        w:Run(1)
        eq(Rewards(ola) - before, 1, "someone else's")
        -- A shaman who did the earth quest (any race's copy flags them all) and carries the water totem.
        local w2 = H.World()
        local per = w2:AddClient("Per Hansen", { pets = { 40 } })
        per.state.questsDone = { [1521] = true }
        per.state.items = { [5177] = 1 }
        w2:Run(per.ns.Feats.FIRST_LOOK + 1)
        local feats = per.ns.DB.char.feats
        ok(feats.earth.before and feats.water.before)
        eq(feats.fire, nil)
        eq(per.ns.Feats.ItemOf("You receive loot: |cff9d9d9d|Hitem:2589::::::::|h[Linen Cloth]|h|r."), 2589)
        eq(per.ns.Feats.ItemOf(nil), nil)
    end)

    test("riding: a feat, with a good chance of the pet's own line", function()
        local w, ola, F = Setup()
        Learn(w, ola, 33388)
        ok(ola:Printed("var med da du lærte å ri!"))
        w:Run(1)
        ok(ola:Printed("salen") or ola:Printed("ridedyret"), "the riding egg")
        eq(ola:Eggs("ridning"), 1)
    end)

    test("level 60: points and its own egg; the tenth levels below it only by a chance that grows", function()
        local w, ola, F = Setup()
        local Q = ola.ns.Quirks
        eq(Q.CAKE_CHANCE[10] < Q.CAKE_CHANCE[50], true)
        -- A chance that doesn't come up at 10, and does at 50.
        ola:Dice(0.3)
        ola:Fire("PLAYER_LEVEL_UP", 10); w:Run(1)
        eq(ola:Eggs("kake"), 0, "20% at level 10: not this time")
        ola:Fire("PLAYER_LEVEL_UP", 50); w:Run(1)
        eq(ola:Eggs("kake"), 1, "80% at 50")
        local before = Points(ola)
        ola:Fire("PLAYER_LEVEL_UP", 60); w:Run(1)
        eq(Points(ola) - before, 25)
        ok(ola:Printed("Level 60! Pandaen har vært med deg helt til toppen.") or ola:Printed("har vært med deg helt til toppen"))
        eq(ola:Eggs("maks"), 1)
        eq(ola:Eggs("kake"), 1, "60 is the feat's, not a cake")
    end)

    test("flavor only: a trainer visit (its lines as one), a dual-spec switch, a talent reset", function()
        local w, ola, F = Setup()
        local A = ola.ns.Activity
        local before = Points(ola)
        for _, s in ipairs({ "Fireball", "Frost Nova", "Arcane Intellect" }) do
            ola:Fire("CHAT_MSG_SYSTEM", "You have learned a new spell: " .. s .. ".")
        end
        w:Run(1)
        eq((A:Count("train")), 1, "one visit")
        w:Run(F.TRAIN_TOGETHER + 1)
        ola:Fire("CHAT_MSG_SYSTEM", "You have learned a new ability: Parry."); w:Run(1)
        eq((A:Count("train")), 2, "another visit")
        -- A feat's own line isn't a visit.
        w:Run(F.TRAIN_TOGETHER + 1)
        Learn(w, ola, 71)
        ola:Fire("CHAT_MSG_SYSTEM", "You have learned a new ability: Defensive Stance."); w:Run(1)
        eq((A:Count("train")), 2)
        -- Dual spec.
        ola:Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1); w:Run(1)
        eq((A:Count("specswap")), 1)
        ola:Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 2); w:Run(1)
        eq((A:Count("specswap")), 1, "no change, no switch")
        -- Right after a switch, unspent points jumping are that spec's: no reset.
        ola.state.unspent = 20; ola:Fire("SPELLS_CHANGED"); w:Run(2)
        eq((A:Count("respec")), 0)
        -- Later: spent, then all back at once.
        w:Run(F.SWAP_QUIET)
        ola.state.unspent = 0; ola:Fire("SPELLS_CHANGED"); w:Run(2)
        ola.state.unspent = 1; ola:Fire("SPELLS_CHANGED"); w:Run(2) -- (a level: one point)
        eq((A:Count("respec")), 0)
        ola.state.unspent = 31; ola:Fire("SPELLS_CHANGED"); w:Run(2)
        eq((A:Count("respec")), 1, "a trainer's unlearn-all: the points back, unspent")
        ok(ola:Eggs("glemsel") > 0, "the confused pet")
        eq(Rewards(ola), 1, "only the feat gave a reward")
    end)

    test("the trainer's window is a visit; a reset in the talent frame is ranks taken back in one change", function()
        local w, ola, F = Setup()
        local A = ola.ns.Activity
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 5); w:Run(1)
        eq((A:Count("train")), 0, "a merchant")
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", 7); w:Run(1)
        ola:Fire("CHAT_MSG_SYSTEM", "You have learned a new spell: Fireball."); w:Run(1)
        eq((A:Count("train")), 1, "the window and its lines: one visit")
        -- Talents: a loadout with ranks, first seen at login (Setup's first look came before these).
        ola.state.config, ola.state.talents = 100, { [1] = 5, [2] = 3, [3] = 1 }
        F.ranks = F.Ranks()
        ola.state.talents[4] = 1; ola:Fire("TRAIT_CONFIG_UPDATED", 100); w:Run(1)
        eq((A:Count("respec")), 0, "a new point spent")
        ola.state.talents[3] = 0; ola.state.talents[5] = 1; ola:Fire("TRAIT_CONFIG_UPDATED", 100); w:Run(1)
        eq((A:Count("respec")), 0, "one point moved")
        ola.state.talents = { [6] = 5, [7] = 5, [1] = 1 }; ola:Fire("TRAIT_CONFIG_UPDATED", 100); w:Run(1)
        eq((A:Count("respec")), 1, "reset and picked anew in one change")
        -- The other spec's loadout: a switch, not a reset.
        ola.state.config, ola.state.talents = 200, { [9] = 5 }
        ola:Fire("TRAIT_CONFIG_UPDATED", 200); w:Run(1)
        eq((A:Count("respec")), 1)
        eq(F.TakenBack(nil, {}), nil)
    end)

    test("every feat has its line and story; quest ids belong to one feat each", function()
        local w, ola, F = Setup()
        local S = ola.ns.Strings
        local seen = {}
        for _, f in ipairs(F.LIST) do
            local line = f.line or "spell"
            ok(S["feat." .. line], f.id); ok(S["feat.story." .. line], f.id)
            if f.totem then ok(S["feat.totem." .. f.totem], f.id) end
            ok(f.spells or f.quests or f.level, f.id .. " can be seen")
            for _, q in ipairs(f.quests or {}) do
                no(seen[q], "quest " .. q .. " twice"); seen[q] = true
            end
        end
    end)
end
