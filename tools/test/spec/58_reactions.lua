-- Class reactions (Menagerie/Reactions.lua, 2026-11-14): your pet reacts to what your class does, read from the
-- sensors. Once a day each; common ones at most one line every 20 minutes (their own budget), rare ones always;
-- in a fight, said after it; by the pet's nature; counted for the achievements to come.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"
    local SPELLS = { [1] = "Battle Shout", [2] = "Battle Stance", [3] = "Defensive Stance", [4] = "Berserker Stance",
        [5] = "Feign Death", [6] = "Divine Shield", [7] = "Hearthstone", [8] = "Searing Totem", [9] = "Healing Stream Totem",
        [10] = "Windfury Totem", [11] = "Stoneskin Totem", [12] = "Summon Imp", [13] = "Polymorph: Pig", [14] = "Ghost Wolf",
        [15] = "Sprint", [16] = "Tame Beast" }

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
        w:Run(ola.ns.Moments.BUDGETS.react.every)
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
        -- A shaman's four totems: a whole garden (common since the user found it twice in a short while: the
        -- budget holds it back too); one alone is just a totem.
        w:SkipDays(1)
        ola.state.class = "SHAMAN"
        R:Watch()
        ola.ns.DB.char.reactAt = ola.ns.Now()
        Cast(ola, 8); Cast(ola, 9); Cast(ola, 10); Cast(ola, 11)
        w:Run(1)
        ok(ola:Log("totemhage: the 20 minutes")[1], "the budget spent: no garden")
        ola.ns.DB.char.reactAt = nil
        w:Run(R.TOTEM_SPAN + 1) -- (those four gone from the garden's span)
        -- (the totems' own line said already today, as in game: the garden is a row of its own)
        ola.ns.DB.char.reacts.totemer = { n = 1, day = ola.ns.Today() }
        -- (in a fight, as a shaman drops them: said after it)
        ola.state.combat = true
        ola:Fire("PLAYER_REGEN_DISABLED")
        Cast(ola, 8); Cast(ola, 9); Cast(ola, 10)
        w:Run(1)
        no(Said(ola, "totemer"), "three")
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

    test("a fight that ends with your death: its line goes unsaid, nothing spent; other lines while dead come; the next fight's too", function()
        local w, ola, R = Setup("HUNTER")
        ola.ns.DB.char.reactAt = nil
        ola.state.combat = true
        ola:Fire("PLAYER_REGEN_DISABLED")
        Cast(ola, 5)
        ola.state.combat, ola.state.dead = false, true -- (died: the fight ends with it)
        ola:Fire("PLAYER_DEAD"); ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(5)
        no(Said(ola, "spilldod"), "not after the death")
        eq(ola.ns.DB.char.reactAt, nil, "the 20 minutes not spent")
        no(ola.ns.Moments:Pending(), "the slot free again")
        -- Dead, out of a fight: a line comes as ever (the user: "it's okay for many lines to fire when I'm dead").
        ola.ns.Moments:Say({ text = "Hm, du ligger.", key = PANDA, why = "dead line", afterFight = true })
        w:Run(20)
        ok(ola:Printed("Hm, du ligger.", true), "said while dead")
        ola.state.dead = false; ola:Fire("PLAYER_UNGHOST")
        ola.state.combat = true
        ola:Fire("PLAYER_REGEN_DISABLED")
        Cast(ola, 5)
        ola.state.combat = false
        ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(5)
        ok(Said(ola, "spilldod"), "alive: said after the fight")
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
        local RACES = { Human = true, Dwarf = true, NightElf = true, Gnome = true, Orc = true, Scourge = true, Tauren = true,
            Troll = true }
        for _, row in ipairs(ns.Reactions.ROWS) do
            ok(CLASSES[row.class] or (row.class == nil and RACES[row.race]), row.id .. ": a class or a race")
            if row.class then CLASSES[row.class] = CLASSES[row.class] + 1 end
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
    test("a shaman's Purge and Ancestral Spirit (rare: past the 20 minutes); a Tauren's War Stomp, whatever the class", function()
        local w, ola, R = Setup("SHAMAN")
        ola.state.spellNames = { [370] = "Purge", [2008] = "Ancestral Spirit", [20549] = "War Stomp" }
        Cast(ola, 370)
        w:Run(5)
        ok(Said(ola, "renselse"), "Purge")
        Cast(ola, 2008)
        w:Run(5)
        ok(Said(ola, "forfedre"), "Ancestral Spirit, rare: the 20 minutes don't hold it back")
        -- Said today: the log says so once a row a day, not at every cast (a shaman's totems wrote it hundreds of times).
        Cast(ola, 370); Cast(ola, 370); Cast(ola, 370)
        eq(#ola:Log("renselse: said today"), 1)
        -- War Stomp is the Tauren's: a Human shaman doesn't even watch for it, a Tauren warrior does.
        ola.ns.DB.char.reactAt = nil
        Cast(ola, 20549)
        w:Run(5)
        no(Said(ola, "krigsstamp"), "a Human")
        ola.state.class, ola.state.race = "WARRIOR", "Tauren"
        R:Watch()
        ola.ns.DB.char.reactAt = nil
        Cast(ola, 20549)
        w:Run(5)
        ok(Said(ola, "krigsstamp"), "a Tauren warrior")
    end)

    test("one line on its way at a time, an egg's or a reaction's (Moments); one held back waits its turn", function()
        local w, ola = Setup("WARRIOR")
        w:Run(30) -- (the day's visit and its eggs first)
        for k in pairs(ola.ns.Moments.DELAY) do ola.ns.Moments.DELAY[k] = { 5, 5 } end
        -- A roll's egg on its way: the shout waits its turn, and comes after it (the user, 2026-11-14: "queue them").
        ola:Fire("CHAT_MSG_SYSTEM", "Ola Nord rolls 1 (1-100)")
        Cast(ola, 1)
        ok(ola:Log("krigsrop: a line on its way")[1])
        ok(ola:Log("react:krigsrop waits its turn")[1])
        w:Run(5.5)
        eq(ola.ns.DB.char.eggs.ener.n, 1, "the egg said")
        no(Said(ola, "krigsrop"), "not seconds after it: its own wait starts now")
        ok(ola.ns.Moments:Pending(), "the shout on its way")
        no(ola.ns.Quirks:Ready(), "and the eggs wait for it")
        w:Run(5)
        ok(Said(ola, "krigsrop"))
        no(ola.ns.Moments:Pending())
        -- Older than LATER_MAX: it has passed.
        w:SkipDays(1)
        local M = ola.ns.Moments
        for k in pairs(M.DELAY) do M.DELAY[k] = { 90, 90 } end
        M:Say({ text = "Hm.", key = PANDA, why = "a slow line" })
        Cast(ola, 1)
        w:Run(95)
        ok(ola:Log("react:krigsrop waits its turn")[2], "held back again")
        ok(ola.ns.DB.char.reacts.krigsrop.day ~= ola.ns.Today(), "a minute and more: gone")
    end)

    test("a rare row with a line on its way: said anyway some of the time (RARE_SKIP), else after it", function()
        local w, ola, R = Setup("HUNTER")
        w:Run(30) -- (the day's visit and its eggs first)
        local M = ola.ns.Moments
        for k in pairs(M.DELAY) do M.DELAY[k] = { 5, 5 } end
        M:Say({ text = "Hm.", key = PANDA, why = "another line" })
        ola:Dice(R.RARE_SKIP + 0.01)
        Cast(ola, 16)
        ok(ola:Log("sjalusi: a line on its way")[1], "not now")
        w:Run(5.5)
        no(Said(ola, "sjalusi"))
        w:Run(5)
        ok(Said(ola, "sjalusi"), "after the other line")
        w:SkipDays(1)
        M:Say({ text = "Hm.", key = PANDA, why = "another line" })
        ola:Dice(R.RARE_SKIP - 0.01)
        Cast(ola, 16)
        ok(M:Queued("react:sjalusi"), "said anyway: on its way beside the other")
        w:Run(6)
        eq(ola.ns.DB.char.reacts.sjalusi.n, 2)
    end)

    test("a rare row on its way isn't decided again: Moonkin twice in one fight is one line after it", function()
        local w, ola, R = Setup("DRUID")
        ola.state.spellNames[17] = "Moonkin Form"
        w:Run(30)
        ola.ns.Moments:Say({ text = "Hm.", key = PANDA, why = "another line" }) -- (a line on its way: RARE_SKIP's roll)
        ola:Dice(0)
        ola.state.combat = true; ola:Fire("PLAYER_REGEN_DISABLED")
        Cast(ola, 17); Cast(ola, 17)
        ok(ola:Log("kjempeugle: on its way already")[1], "the second: already on its way")
        ola.state.combat = false; ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(5)
        eq(ola.ns.DB.char.reacts.kjempeugle.n, 1)
    end)
end
