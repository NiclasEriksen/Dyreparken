-- Class reactions (Menagerie/Reactions.lua, 2026-11-14): your pet reacts to what your class does, read from the
-- sensors. Once a day each; common ones at most one line every 20 minutes (their own budget), rare ones always;
-- in a fight, said after it; by the pet's nature; counted for the achievements to come.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"
    local SPELLS = { [1] = "Battle Shout", [2] = "Battle Stance", [3] = "Defensive Stance", [4] = "Berserker Stance",
        [5] = "Feign Death", [6] = "Divine Shield", [7] = "Hearthstone", [8] = "Searing Totem", [9] = "Healing Stream Totem",
        [10] = "Windfury Totem", [11] = "Stoneskin Totem", [12] = "Summon Imp", [13] = "Polymorph: Pig", [14] = "Ghost Wolf",
        [15] = "Sprint" }

    -- Ola, of the class given, with the panda adopted and out; every chance and delay at once.
    local function Setup(class)
        local w, ola = H.Setup{ ola = { 5159 }, settle = "bond" }
        ola:Traits({ "glupsk", "helgedyr" }, 5159) -- (no row lists these: the plain lines)
        ola:Slash("adopter panda")
        w:Run(5)
        ola.state.class = class
        ola.state.spellNames = SPELLS
        ola.ns.Reactions:Watch()
        ola:Dice(0)
        ola:QuirksNow()
        return w, ola, ola.ns.Reactions
    end
    local function Cast(ola, id) ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", id) end
    local function Said(ola, id)
        local list = {}
        for _, k in ipairs(ola.ns.Variants("react." .. id)) do list[#list + 1] = ola.ns.T(k, { pet = "Panda Cub" }) end
        for _, line in ipairs(list) do if ola:Printed(line, true) then return true end end
        return false
    end

    test("a warrior's Battle Shout: a line, once a day; not in a fight (calm), not without a pet, not for a mage", function()
        local w, ola, R = Setup("WARRIOR")
        ok(ola.ns.Sense:Wants("cast")); no(ola.ns.Sense:Wants("glance"), "only what the class's rows need")
        ola.state.combat = true
        Cast(ola, 1)
        ola.state.combat = false
        ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(1)
        no(Said(ola, "krigsrop"), "shouted in a fight: no")
        ok(ola:Log("krigsrop: in a fight %(Battle Shout%)")[1], "and the log says why")
        -- The roll lost.
        ola:Dice(0.9)
        Cast(ola, 1)
        w:Run(1)
        no(Said(ola, "krigsrop")); ok(ola:Log("krigsrop: the roll")[1])
        ola:Dice(0)
        Cast(ola, 1)
        w:Run(1)
        ok(Said(ola, "krigsrop"))
        eq(ola.ns.DB.char.reacts.krigsrop.n, 1)
        ok(ola.ns.DB.char.reactAt, "a common one: the budget is spent")
        local story = ola.ns.Story:Of(PANDA)
        eq(story[#story].x, "react:krigsrop", "in its story")
        -- Again today: no.
        ola.ns.DB.char.reactAt = nil
        Cast(ola, 1)
        w:Run(1)
        eq(ola.ns.DB.char.reacts.krigsrop.n, 1, "once a day")
        -- Tomorrow, but no pet out.
        w:SkipDays(1)
        ola.ns.DB.char.reactAt = nil
        ola:Summon(nil)
        Cast(ola, 1)
        w:Run(1)
        eq(ola.ns.DB.char.reacts.krigsrop.n, 1, "no pet: no line")
        ok(ola:Log("krigsrop: no pet out")[1])
        -- A mage doesn't shout.
        ola:Summon(5159)
        ola.state.class = "MAGE"
        R:Watch()
        Cast(ola, 1)
        w:Run(1)
        eq(ola.ns.DB.char.reacts.krigsrop.n, 1)
    end)

    test("the budget: one common line in 20 minutes; a rare one always; a fight's said after it", function()
        local w, ola, R = Setup("PALADIN")
        -- The bubble-hearth (rare): Divine Shield in a fight, the hearthstone ending after it.
        ola.ns.DB.char.reactAt = ola.ns.Now()
        Cast(ola, 7)
        w:Run(1)
        no(Said(ola, "boblehjem"), "a hearthstone alone: nothing")
        ola.state.combat = true
        Cast(ola, 6)
        ola.state.combat = false
        ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(12)
        Cast(ola, 7)
        w:Run(1)
        ok(Said(ola, "boblehjem"), "rare: the budget doesn't hold it back")
        -- A hunter: Feign Death in a fight is said after it; the next common one waits 20 minutes.
        w:SkipDays(1)
        ola.state.class = "HUNTER"
        R:Watch()
        ola.ns.DB.char.reactAt = nil
        ola.state.combat = true
        ola:Fire("PLAYER_REGEN_DISABLED")
        Cast(ola, 5)
        w:Run(3)
        no(Said(ola, "spilldod"), "not in the fight")
        ola.state.combat = false
        ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(1)
        ok(Said(ola, "spilldod"), "after it")
        local at = ola.ns.DB.char.reactAt
        ok(at)
        no(R:Ready(), "the 20 minutes")
        w:Run(R.EVERY)
        ok(R:Ready())
    end)

    test("by its nature, by what it saw: a warlock's Imp, a sheep for a farm pet, the stance dance, a totem garden", function()
        local w, ola, R = Setup("WARLOCK")
        Cast(ola, 12)
        w:Run(1)
        ok(Said(ola, "demonen.imp"), "the Imp's own lines")
        -- A mage's pig for a farm pet: its cousin.
        w:SkipDays(1)
        ola.ns.DB.char.reactAt = nil
        ola.state.class = "MAGE"
        R:Watch()
        Cast(ola, 13)
        w:Run(1)
        ok(Said(ola, "sau"), "a bear: the plain lines")
        -- A warrior's three stances in ten seconds; two aren't a dance.
        w:SkipDays(1)
        ola.ns.DB.char.reactAt = nil
        ola.state.class = "WARRIOR"
        R:Watch()
        Cast(ola, 2); Cast(ola, 3)
        w:Run(1)
        no(Said(ola, "stansdans"))
        Cast(ola, 4)
        w:Run(1)
        ok(Said(ola, "stansdans"))
        -- A shaman's four totems: a whole garden (rare, past the budget); one alone is just a totem.
        w:SkipDays(1)
        ola.state.class = "SHAMAN"
        R:Watch()
        ola.ns.DB.char.reactAt = ola.ns.Now()
        -- (the totems' own line said already today, as in game: the garden is a row of its own)
        ola.ns.DB.char.reacts.totemer = { n = 1, day = ola.ns.Today() }
        -- (in a fight, as a shaman drops them: said after it)
        ola.state.combat = true
        ola:Fire("PLAYER_REGEN_DISABLED")
        Cast(ola, 8); Cast(ola, 9); Cast(ola, 10)
        w:Run(1)
        no(Said(ola, "totemer"), "three, and the budget spent")
        ok(ola:Log("totemer: said today")[1])
        ok(ola:Log("totemhage: not its moment")[1], "three kinds: no garden yet")
        Cast(ola, 11)
        w:Run(1)
        no(Said(ola, "totemhage"), "not in the fight")
        ola.state.combat = false
        ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(1)
        ok(Said(ola, "totemhage"), "a whole garden, after the fight")
        -- Ghost Wolf (seen in game, 2026-11-14: six casts and no line, the log's reasons added since).
        w:SkipDays(1)
        ola.ns.DB.char.reactAt = nil
        Cast(ola, 14)
        w:Run(1)
        ok(Said(ola, "spokelsesulv"))
    end)

    test("a trait's own line", function()
        local w, ola = Setup("ROGUE")
        ola:Traits({ "hoppetass", "glupsk" }, 5159)
        Cast(ola, 15)
        w:Run(1)
        ok(Said(ola, "spurt.hoppetass"))
    end)

    test("every row: a known class and sensor, its own lines, and lines for every nature it lists", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local ns = ola.ns
        local CLASSES = { WARRIOR = 0, ROGUE = 0, HUNTER = 0, WARLOCK = 0, MAGE = 0, PRIEST = 0, PALADIN = 0, DRUID = 0, SHAMAN = 0 }
        for _, row in ipairs(ns.Reactions.ROWS) do
            ok(CLASSES[row.class], row.id .. ": a class")
            CLASSES[row.class] = CLASSES[row.class] + 1
            ok(row.spells or row.starts or row.ends, row.id .. ": a name to match")
            if row.id ~= "demonen" then ok(#ns.Variants("react." .. row.id) >= 2, row.id .. ": two lines at least") end
            for _, x in ipairs(row.traits or {}) do ok(ns.Strings["react." .. row.id .. "." .. x .. ".1"], row.id .. "." .. x) end
            for _, x in ipairs(row.families or {}) do ok(ns.Strings["react." .. row.id .. "." .. x .. ".1"], row.id .. "." .. x) end
        end
        for class, n in pairs(CLASSES) do ok(n >= 3, class .. ": three rows at least") end
        for _, name in ipairs(ns.Reactions.ById("demonen").spells) do
            ok(ns.Strings["react.demonen." .. name:match("^Summon (%a+)$"):lower() .. ".1"], name)
        end
        ok(ns.Strings["react.totemhage.1"])
        match(ns.L["react.krigsrop.1"], "{pet}")
    end)
end
