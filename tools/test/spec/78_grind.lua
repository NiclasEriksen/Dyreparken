-- Still at it (Menagerie/Grind.lua, 2026-11-26): an hour of one activity with a pet out gets one line, liked or
-- not; and a long break starts the day's liked line over (Bond:Rested). From the log: 2 h 46 min of Timbermaw
-- rep said two lines, both eggs.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    local function Setup(traits)
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Traits(traits or { "glupsk", "rampete" })
        ola:Slash("adopter panda"); w:Run(5)
        ola:Dice(0); ola:QuirksNow()
        ola.ns.DB.char.wish = { done = true, pet = ola.ns.Registry:MyPet(), day = ola.ns.Today() }
        return w, ola
    end
    -- n of an activity, one every `every` seconds.
    local function Grind(w, ola, id, n, every, extra)
        for _ = 1, n do
            ola.ns.Activity:Emit(id, 1, extra)
            w:Run(every)
        end
        w:RunTimers()
    end

    test("an hour of rep: one line naming the faction, once a session; under the hour, or too few, nothing", function()
        local w, ola = Setup()
        Grind(w, ola, "rep", 20, 100, "Timbermaw Hold")
        no(ola:Printed("Timbermaw Hold", true), "33 minutes: not yet")
        Grind(w, ola, "rep", 20, 100, "Timbermaw Hold")
        ok(ola:PrintedLine("grind.rep", { pet = "Panda Cub", faction = "Timbermaw Hold" }), "an hour on: its line")
        eq(ola:CountPrinted("Timbermaw Hold"), 1)
        ola.ns.DB.char.quirkAt = nil
        Grind(w, ola, "rep", 40, 100, "Timbermaw Hold")
        eq(ola:CountPrinted("Timbermaw Hold"), 1, "once a session")
        ola:Reload(); w:Settle("hello"); ola:QuirksNow()
        Grind(w, ola, "rep", 40, 100, "Timbermaw Hold")
        eq(ola:CountPrinted("Timbermaw Hold"), 1, "and once a day")
        -- Herbs, a few an hour, is the everyday pace: no farm.
        Grind(w, ola, "herb", 16, 300)
        no(ola:PrintedLine("grind.herb", { pet = "Panda Cub" }), "twelve herbs an hour, for 80 minutes")
        -- The day's roll: lost, a farm says nothing all day.
        ola:Dice(0.9)
        Grind(w, ola, "mine", 20, 200)
        no(ola:PrintedLine("grind.mine", { pet = "Panda Cub" }), "today's roll lost")
    end)

    test("a gap over twenty minutes starts the run over; the quirks' 45 minutes hold it to the next time", function()
        local w, ola = Setup()
        Grind(w, ola, "gold", 40, 60)
        w:Run(ola.ns.Grind.GAP + 1)
        Grind(w, ola, "gold", 30, 60)
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "70 minutes, a break in them")
        ola.ns.DB.char.quirkAt = ola.ns.Now() -- (an egg just now)
        Grind(w, ola, "gold", 32, 60)
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "an hour now, the 45 minutes not over")
        ola.ns.DB.char.quirkAt = ola.ns.Now() - 2700
        Grind(w, ola, "gold", 1, 1)
        ok(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "the next coin")
    end)

    test("a disliked one is the dislike's; Litt halves the day's chance", function()
        local w, ola = Setup()
        ola.ns.Personality.Dislikes = function() return { fish = true }, { "fish" } end
        Grind(w, ola, "fish", 40, 100)
        no(ola:PrintedLine("grind.fish", { pet = "Panda Cub" }), "it minds fishing")
        local w2, kari = Setup()
        kari.ns.DB.global.settings.chatter = "few"
        kari:Dice(0.6)
        Grind(w2, kari, "quest", 11, 400)
        no(kari:PrintedLine("grind.quest", { pet = "Panda Cub" }), "few: a 25% roll, lost")
        eq(#kari:Log("grind:quest: today's roll lost %(25%%%)"), 1)
        local _, said = kari.ns.Grind:Runs()
        ok(said.quest, "decided for the session")
    end)

    test("a long break starts the day's liked line over; a short one doesn't, and points stay the day's", function()
        local w, ola = Setup()
        w:SetHour(1) -- (six hours on is the same day)
        local d = function() return ola.ns.DB.char.bondToday.pets[PANDA] end
        ola.ns.Bond:OnActivity("day", 1, PANDA)
        d().flavor = true
        ola:Logout(); w:Skip(3600); ola:Login(); w:Settle("hello")
        ok(d().flavor, "an hour away: the same evening")
        ola:Logout(); w:Skip(ola.ns.Bond.BREAK + 60); ola:Login(); w:Settle("hello")
        no(d().flavor, "six hours away: the day's line again")
        eq(#ola:Log("back after"), 1)
    end)
    test("coins with rep coming in are the rep farm's: one line, the rep's", function()
        local w, ola = Setup()
        for _ = 1, 70 do
            ola.ns.Activity:Emit("gold", 1)
            ola.ns.Activity:Emit("rep", 1, "Timbermaw Hold")
            w:Run(60)
        end
        w:RunTimers()
        ok(ola:PrintedLine("grind.rep", { pet = "Panda Cub", faction = "Timbermaw Hold" }), "the rep's line")
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "not the coins'")
        ola.ns.DB.char.quirkAt = nil
        Grind(w, ola, "gold", 70, 50)
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "the same farm: not later either")
    end)
    -- A fight over with this mob dead and still targeted (Grind.Killed).
    local function Kill(ola, name, who)
        ola.units.target = { name = name, who = who or { dead = true, reaction = 2 } }
        ola:Fire("PLAYER_REGEN_ENABLED")
    end
    local function Kills(w, ola, names, n, every, rep)
        for i = 1, n do
            Kill(ola, names[(i - 1) % #names + 1])
            ola.ns.Activity:Emit("gold", 1)
            if rep then ola.ns.Activity:Emit("rep", 1, rep) end
            w:Run(every)
        end
        w:RunTimers()
    end
    local DEADWOOD = { "Deadwood Shaman", "Deadwood Avenger", "Deadwood Den Watcher", "Deadwood Pathfinder" }

    test("the word the mobs share: the most kills', half of them at least, a first word at a tie, no sizes", function()
        local w, ola = Setup()
        local G = ola.ns.Grind
        local function Of(names)
            local runs = G:Runs()
            runs.mobs = nil
            for _, name in ipairs(names) do
                w:Run(1); G:OnActivity("mobs", PANDA, name)
            end
            return G.Common(runs.mobs)
        end
        eq(Of(DEADWOOD), "Deadwood")
        eq(Of({ "Elder Mottled Boar", "Mottled Boar", "Mottled Boar" }), "Boar", "Elder and Mottled are looks")
        eq(Of({ "Bloodscalp Hunter", "Bloodscalp Hunter" }), "Bloodscalp", "a tie: a first word before a last")
        eq(Of({ "Timbermaw Shaman", "Timbermaw Ursa", "Timbermaw Shaman" }), "Timbermaw", "Shaman in two of three, Timbermaw in all")
        eq(Of({ "Felpaw Wolf", "Deadwood Shaman", "Irontree Stomper", "Jadefire Satyr" }), nil, "nothing in half of them")
        -- The probe, 2026-11-27, Andorhal: an adjective is never the word, so this mixed bag shares none.
        local andorhal = {}
        for name, n in pairs({ ["Skeletal Acolyte"] = 7, ["Skeletal Executioner"] = 6, ["Rotting Ghoul"] = 3,
            ["Soulless Ghoul"] = 3, ["Freezing Ghoul"] = 1, Skeleton = 1, ["Diseased Wolf"] = 1 }) do
            for _ = 1, n do andorhal[#andorhal + 1] = name end
        end
        eq(Of(andorhal), nil, "Skeletal in 13 of 22: a look, not a kind")
        eq(Of({ "Rotting Ghoul", "Soulless Ghoul", "Freezing Ghoul" }), "Ghoul", "the ghouls alone: Ghoul")
        eq(Of({ "Dark Iron Dwarf", "Dark Iron Geologist" }), "Iron")
        eq(Of({ "Scarlet Monk", "Scarlet Zealot", "Scarlet Defender" }), "Scarlet", "a crusade's name stays")
        eq(Of({ "Venom Web Spider", "Dalaran Hatchling", "Ironbeak Hatchling" }), "Hatchling", "-ling is a noun")
    end)

    test("an hour of Deadwood: a line naming them; the coins say nothing after; a corpse only, an enemy only", function()
        local w, ola = Setup()
        Kills(w, ola, DEADWOOD, 70, 60)
        ok(ola:PrintedLine("grind.mobs", { pet = "Panda Cub", mobs = "Deadwood" }), "the mobs' line")
        no(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "not the coins'")
        local G = ola.ns.Grind
        ola.units.target = { name = "Deadwood Shaman", who = { reaction = 2 } }
        eq(G.Killed(), nil, "alive: no kill")
        ola.units.target = { name = "Kari Berg", who = { dead = true, player = true } }
        eq(G.Killed(), nil, "a player")
        ola.units.target = { name = "Thrall's Wolf", who = { dead = true, controlled = true, reaction = 2 } }
        eq(G.Killed(), nil, "someone's pet")
        ola.units.target = { name = "Timbermaw Warder", who = { dead = true, reaction = 5 } }
        eq(G.Killed(), nil, "a friendly one")
        ola.units.target = nil
        eq(G.Killed(), nil, "no target")
    end)

    test("a rep farm's kills: the rep's line, naming the mobs half the time; never mobs named as the faction", function()
        local w, ola = Setup()
        Kills(w, ola, DEADWOOD, 70, 60, "Timbermaw Hold")
        ok(ola:PrintedLine("grind.repmobs", { pet = "Panda Cub", faction = "Timbermaw Hold", mobs = "Deadwood" }), "both named")
        no(ola:PrintedLine("grind.mobs", { pet = "Panda Cub", mobs = "Deadwood" }), "one farm, one line")
        local w2, kari = Setup()
        Kills(w2, kari, { "Timbermaw Shaman", "Timbermaw Ursa" }, 70, 60, "Timbermaw Hold")
        ok(kari:PrintedLine("grind.rep", { pet = "Panda Cub", faction = "Timbermaw Hold" }), "the plain rep line")
    end)

    test("kills that share no word: no mobs line, the coins' farm then; another zone starts the run over", function()
        local w, ola = Setup()
        Kills(w, ola, { "Felpaw Wolf", "Irontree Stomper", "Jadefire Satyr", "Warpwood Moss Flayer" }, 70, 60)
        no(ola:Printed("{mobs}", true))
        ok(ola:PrintedLine("grind.gold", { pet = "Panda Cub" }), "a farm all the same")
        local w2, kari = Setup()
        Kills(w2, kari, DEADWOOD, 40, 60)
        kari:Travel("Winterspring")
        Kills(w2, kari, DEADWOOD, 30, 60)
        no(kari:PrintedLine("grind.mobs", { pet = "Panda Cub", mobs = "Deadwood" }), "40 minutes, then 30 elsewhere")
    end)
    test("a fight's other kills are the targeted one's kind: PARTY_KILL counted while it's on, at most ten", function()
        local w, ola = Setup()
        local runs = ola.ns.Grind:Runs()
        local function Fight(kills, name)
            ola:EnterCombat()
            for _ = 1, kills do ola:Fire("PARTY_KILL", "secret", "secret") end
            ola.units.target = { name = name, who = { dead = true, reaction = 2 } }
            ola:LeaveCombat()
        end
        Fight(5, "Deadwood Shaman")
        eq(runs.mobs.n, 5, "five Deadwood")
        eq(runs.mobs.words.deadwood.n, 5)
        Fight(0, "Deadwood Avenger")
        eq(runs.mobs.n, 6, "none heard: the target alone")
        Fight(30, "Deadwood Avenger")
        eq(runs.mobs.n, 16, "at most ten")
        ok(not ola:Listening("PARTY_KILL"), "heard only in a fight")
        ola:Fire("PARTY_KILL"); Kill(ola, "Deadwood Shaman")
        eq(runs.mobs.n, 17, "out of a fight: not counted")
    end)
end
