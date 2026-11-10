-- The pet on the card moves (Menagerie/Moves.lua), and the research probe
-- (/dp probe anim, in a git checkout).
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    -- Ola with the panda on the card at a given hour (the player's clock).
    local function Setup(hour, traits)
        local w, ola = H.Setup{ ola = { 5159, 46, 5160, 5161 }, journal = true }
        ola.ns.Personality.Traits = function() return traits or { ola.ns.Personality.ById("glupsk") } end
        ola.ns.PetMoves.species[5159] = nil -- (the panda plays the default here, whatever the file says)
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = hour }) - w:ServerTime())
        return w, ola, ola.petActor
    end

    test("/dp probe anim: finds the card's pet, lists what it has, plays one by name or id", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola:Slash("probe anim")
        match(ola:Printed("anim probe: actor by tag unwrapped", true),
            "HasAnimation=true .* has 3 of %d+: Stand %(0%), PetBattleCustom0 %(756%), PetBattleDead %(770%)$")
        eq(#ola:Log("Probe\tanim actor by tag unwrapped"), 1, "and in the log")
        ola:Slash("probe anim PetBattleCustom0")
        eq(actor.anim, 756)
        ok(ola:Printed("PetBattleCustom0 (756): SetAnimation ok; has it: true; now 756", true))
        ola:Slash("probe anim 770")
        eq(actor.anim, 770); eq(actor.speed, nil)
        ola:Slash("probe anim 6 0")
        eq(actor.anim, 6); eq(actor.speed, 0)
        ok(ola:Printed("Dead (6) at speed 0: SetAnimation ok", true))
        ola:Slash("probe anim 6 0 0.5")
        eq(actor.speed, 0); eq(actor.offset, 0.5)
        ok(ola:Printed("Dead (6) at speed 0 from 0.5 s: SetAnimation ok", true))
        ola:Slash("probe anim blend none")
        eq(actor.blendOp, 0)
        ok(ola:Printed("blend none: SetAnimationBlendOperation(0) ok", true))
        ola:Slash("probe anim blend anim")
        eq(actor.blendOp, 1)
        ola:Slash("probe anim sleep 100 0.8")
        eq(actor.anim, 100); eq(actor.speed, nil, "lying down, as the card does at night")
        ok(ola:Printed("sleep: Sleep (100), held at 0.80 s", true))
        w:Run(0.9)
        eq(actor.anim, 100); eq(actor.speed, 0); eq(actor.offset, 0.8); eq(actor.blendOp, 0)
        ola:Slash("probe anim sleep Dead")
        w:Run(1.3)
        eq(actor.anim, 6); eq(actor.offset, 1.2, "1.2 s unless told")
        ola:Slash("probe anim sleep")
        ok(ola:Printed("anim probe: sleep <id|name> [seconds]", true))
        ola:Slash("probe anim blend sideways")
        ok(ola:Printed("anim probe: blend none|anim", true))
        ola:Slash("probe anim 9999")
        eq(actor.anim, 9999, "an id not in the list is tried too")
        ola:Slash("probe anim wiggle")
        ok(ola:Printed('unknown animation "wiggle"', true))
        ola:Slash("probe anim stop")
        eq(actor.anim, 0)
    end)

    test("/dp probe anim all|custom: each one it has, a few seconds apart; stop cancels it", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        local actor = ola.petActor
        ola:Slash("probe anim all")
        w:Run(0.6)
        ok(ola:Printed("1/3 Stand (0) species 5159: set, then 0, after 0.5 s 0", true))
        w:Run(3)
        eq(actor.anim, 756)
        w:Run(3)
        eq(actor.anim, 770)
        w:Run(3.1)
        eq(actor.anim, 0, "back to standing"); ok(ola:Printed("all: done, 3 tried", true))
        -- The four custom moves only (the client can't say which it has: all four tried).
        actor.HasAnimation = nil
        ola:Slash("probe anim custom")
        for _, id in ipairs({ 756, 758, 760, 762 }) do eq(actor.anim, id); w:Run(3.05) end
        ok(ola:Printed("custom: done, 4 tried", true))
        -- Stopped halfway: nothing more plays.
        ola:Slash("probe anim all")
        w:Run(3.1)
        ola:Slash("probe anim stop")
        local n = #actor.played
        w:Run(10)
        eq(#actor.played, n)
    end)

    test("/dp probe anim without a pet model, or without HasAnimation: says so, tries anyway", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("probe anim")
        ok(ola:Printed("no PetJournalPetCard.modelScene", true))
        local w2, kari = H.Setup{ ola = { 5159 }, journal = { noActor = true } }
        kari:Slash("probe anim")
        ok(kari:Printed("anim probe: no actor in the scene", true))
        local w3, per = H.Setup{ ola = { 5159 }, journal = true }
        per:SelectPet(5159)
        per.petActor.HasAnimation = nil
        per:Slash("probe anim")
        match(per:Printed("anim probe: actor", true), "HasAnimation=false .* has 0 of")
        per:Slash("probe anim all")
        w3:Run(3.6)
        ok(per:Printed("2/%d+ Death %(1%) species 5159: set, then 1"), "unknown: every one is tried")
        per.petAnims = { [0] = true }
        per:Slash("probe anim PetBattleCustom0")
        ok(per:Printed("PetBattleCustom0 (756): SetAnimation ok; has it: nil; now 0", true))
    end)

    test("by day the pet stands; a click is a happy hop, then it stands again", function()
        local w, ola, actor = Setup(14)
        ola:SelectPet(5159)
        eq(actor.anim, 0)
        local card = ola:Card()
        ola.ns.Cuddle:Pet(card)
        eq(actor.anim, 756, "PetBattleCustom0: the panda's joyful hop")
        w:Run(2.1)
        eq(actor.anim, 0)
        -- A refresh of the same pet doesn't start it over: only what plays is put back.
        local n = #actor.played
        ola.ns.JournalUI:Refresh()
        eq(#actor.played, n + 1); eq(actor.played[#actor.played], 0)
    end)

    test("at night it's asleep on the card; a click wakes it, and it stays awake", function()
        local w, ola, actor = Setup(23)
        ola:SelectPet(5159)
        eq(actor.anim, 0, "it loads standing (posed while loading, the camera framed some pets small)")
        w:Run(0.61)
        eq(actor.anim, 6, "lying down: Dead played"); eq(actor.speed, nil); eq(actor.blendOp, 1, "smoothly")
        w:Run(0.9)
        eq(actor.speed, nil, "still lying down")
        local n = #actor.played
        w:Run(0.3)
        eq(actor.played[n + 1], 0, "standing, for a moment that isn't drawn: the client ignores the 6 it plays")
        eq(actor.played[n + 2], 6)
        eq(actor.anim, 6, "asleep: lying as Dead (6)")
        eq(actor.speed, 0, "frozen: played on, it ended and stood the pet up")
        eq(actor.offset, 1.2, "at the end of its fall (frozen at the start, it stood still)")
        eq(actor.blendOp, 0, "cut to, not blended: the blend from standing would freeze too")
        w:Run(5)
        eq(actor.anim, 6, "and stays down")
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 756, "woken: glad to see you")
        eq(actor.blendOp, 1, "blended again"); eq(actor.speed, nil)
        w:Run(2.1)
        eq(actor.anim, 0, "awake")
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 0, "still awake when you come back to it")
        -- A night owl doesn't sleep at night.
        local w2, kari, actor2 = Setup(23)
        kari.ns.Personality.Traits = function() return { kari.ns.Personality.ById("nattugle") } end
        kari:SelectPet(5159)
        eq(actor2.anim, 0)
    end)

    test("/dp probe anim night: asleep by day, to test it; again turns it off", function()
        local w, ola, actor = Setup(14)
        ola:SelectPet(5159)
        w:Run(1.81)
        eq(actor.anim, 0, "day: awake")
        ola:Slash("probe anim night")
        w:Run(1.81)
        eq(actor.anim, 6, "the card's pet falls asleep at once"); eq(actor.speed, 0)
        ola.ns.Cuddle:Pet(ola:Card())
        w:Run(2.1)
        eq(actor.anim, 0, "woken")
        ola:Slash("probe anim night"); ola:Slash("probe anim night")
        w:Run(1.81)
        eq(actor.anim, 6, "turned on again: asleep again")
        ola:Slash("probe anim night")
        w:Run(1.81)
        eq(actor.anim, 0, "off: day again")
    end)

    test("a Latsabb sits down after a while; a click gets it up", function()
        local w, ola, actor = Setup(14)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("latsabb") } end
        ola:SelectPet(5159)
        eq(actor.anim, 0)
        w:Run(6.1)
        eq(actor.anim, 96)
        w:Run(1.3)
        eq(actor.anim, 97, "sitting")
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 98, "getting up")
        -- Another pet before it sits: nothing more for the first.
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 0)
    end)

    test("a level-up casts a little spell; the day of three deaths it plays dead once", function()
        local w, ola, actor = Setup(14)
        ola:SelectPet(5159)
        ola.ns.Moves:Cheer(PANDA)
        eq(actor.anim, 754)
        w:Run(2.6)
        eq(actor.anim, 0)
        ola.ns.Moves:Cheer("s:46")
        eq(actor.anim, 0, "not the pet on the card: nothing")
        -- The egg came up today with the panda out.
        ola.ns.DB.char.eggs.dodsfall = { n = 1, day = ola.ns.Today(), key = PANDA }
        ola:SelectPet(46); ola:SelectPet(5159)
        w:Run(0.61)
        eq(actor.anim, 1, "playing dead: Death (1), the fall")
        w:Run(4.1)
        eq(actor.anim, 0, "and up again")
        ola:SelectPet(46); ola:SelectPet(5159)
        eq(actor.anim, 0, "only once")
    end)

    test("closing the journal or opening our pages stops it; the next look starts over", function()
        local w, ola, actor = Setup(14)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("latsabb") } end
        ola:SelectPet(5159)
        ola.ns.Bus:Fire("SIDEPAGE", true)
        w:Run(8)
        eq(actor.anim, 0, "covered: it didn't sit down")
        ola.ns.Bus:Fire("SIDEPAGE", false)
        w:Run(8)
        eq(actor.anim, 97, "back on the card: sitting after a while")
        ola.env.PetJournalPetCard:Hide()
        ola.env.PetJournalPetCard:Show()
        ola:SelectPet(5159)
        eq(actor.anim, 0, "shown again: from the start")
    end)

    test("Blizzard standing the model up again: put back, and logged", function()
        local w, ola, actor = Setup(23)
        ola:SelectPet(5159)
        w:Run(1.81)
        eq(actor.anim, 6)
        actor.anim = 0 -- (the model loaded anew)
        w:Run(0.31)
        eq(actor.anim, 6, "checked a moment later, and set again")
        eq(#ola:Log("Moves\ts:5159 6: set; after 0.3 s 0"), 1)
        eq(actor.anim, 6)
        -- A refresh of the card (the same pet) stood it up: lying down again, still frozen.
        actor.anim, actor.speed = 0, nil
        ola.ns.JournalUI:Refresh()
        eq(actor.anim, 6); eq(actor.speed, 0); eq(actor.offset, 1.2)
        -- Only once per check: a model that won't keep it isn't fought over.
        local n = #actor.played
        actor.anim = 0
        w:Run(2)
        ok(#actor.played <= n + 1)
    end)

    test("asleep, stood up by someone else (the journal, a model loading): lying down again", function()
        local w, ola, actor = Setup(23)
        function actor:SetModelByCreatureDisplayID(id) self.anim, self.speed, self.offset = 0, nil, nil end
        ola:SelectPet(5159)
        w:Run(1.81)
        eq(actor.anim, 6)
        actor:SetAnimation(0) -- (Blizzard's code, not ours)
        eq(actor.anim, 0)
        w:Run(0.1)
        eq(actor.anim, 6, "put back at once"); eq(actor.offset, 1.2)
        eq(#ola:Log("Moves\tSetAnimation%(0%) from outside, holding 6"), 1, "and logged, to learn what does it")
        -- A model loaded anew: once it has settled (the camera frames it as it loads).
        w:Run(1) -- (past the 0.3 s recheck)
        actor:SetModelByCreatureDisplayID(1234)
        w:Run(0.5)
        eq(actor.anim, 0, "not while it loads")
        w:Run(0.2)
        eq(actor.anim, 6, "lying again"); eq(actor.offset, 1.2)
        -- No fight with a client that insists: a few times per pet shown.
        local function Sixes(from) local n = 0; for i = from + 1, #actor.played do if actor.played[i] == 6 then n = n + 1 end end; return n end
        local before = #actor.played
        for _ = 1, 10 do actor:SetAnimation(0); w:Run(0.1) end
        eq(Sixes(before), ola.ns.Moves.REPOSE - 2, "five of ours in all, against ten of theirs")
        -- Awake, nothing is held: theirs stand.
        ola:SelectPet(46); ola:SelectPet(5159)
        w:Run(1.81)
        ola.ns.Cuddle:Pet(ola:Card())
        w:Run(2.1)
        before = #actor.played
        actor:SetAnimation(0); w:Run(1)
        eq(#actor.played - before, 1)
    end)

    test("each reaction per species, from Data/PetMoves.lua: an id, or false for none", function()
        local w, ola, actor = Setup(23)
        local M = ola.ns.Moves
        eq(M:For(PANDA, "sleep"), 6); eq(M:For(PANDA, "happy"), 756)
        -- Mini Diablo (5161) vanishes as Dead: he stays up at night.
        eq(M:For("s:5161", "sleep"), nil)
        ola:SelectPet(5161)
        eq(actor.anim, 0)
        -- A species without a happy move (the Zergling's custom move is an attack): a click only wakes it.
        ola.ns.PetMoves.species[5160] = { happy = false }
        ola:SelectPet(5160)
        w:Run(1.81)
        eq(actor.anim, 6)
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 0, "up, no attack")
        -- An edit to the file takes: another sleep for the panda, and no cheer.
        ola.ns.PetMoves.species[5159] = { sleep = 100, sleepAt = 0.4, cheer = false }
        ola:SelectPet(5159)
        w:Run(1.81)
        eq(actor.anim, 100); eq(actor.offset, 0.4, "and its own point in it")
        local n = #actor.played
        M:Cheer(PANDA)
        eq(#actor.played, n, "no cheer for it")
        -- Every value in the file (as it is, untouched) is a number or false, for a species in the journal.
        local _, fresh = H.Setup{ ola = {} }
        local data = fresh.ns.PetMoves
        for what, id in pairs(data.default) do ok(type(id) == "number", what) end
        for sid, own in pairs(data.species) do
            ok(fresh.ns.Companions.species[sid], "species " .. sid .. " is in the journal")
            for what, id in pairs(own) do
                ok(data.default[what] ~= nil or what == "lift", sid .. ": " .. what .. " is a reaction")
                ok(id == false or type(id) == "number", sid .. ": " .. what)
            end
        end
    end)

    test("the pet you keep out walks while you move and runs while you ride; nothing else gives way", function()
        local w, ola, actor = Setup(14)
        local function Listening(e)
            for _, f in ipairs(ola.frames) do if f.events[e] then return true end end
        end
        ola:Slash("adopter panda")
        w:Run(5)
        no(Listening("PLAYER_STARTED_MOVING"), "the card isn't showing")
        ola:SelectPet(5159)
        ok(Listening("PLAYER_STARTED_MOVING"))
        eq(actor.anim, 0)
        ola:Move()
        eq(actor.anim, 4, "walking")
        ola:Mount()
        eq(actor.anim, 5, "running")
        ola:Set("taxi", true); ola:Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        eq(actor.anim, 0, "a flight path: standing")
        ola:Set("taxi", false); ola:Dismount()
        eq(actor.anim, 4)
        -- Landed from a flight, standing, and no stop came: the speed says so.
        ola:Mount(); ola:Set("taxi", true); ola:Fire("PLAYER_MOUNT_DISPLAY_CHANGED")
        ola:Set("taxi", false); ola.state.moving = false
        ola:Fire("PLAYER_CONTROL_GAINED")
        eq(actor.anim, 0, "standing after the flight")
        ola:Dismount()
        eq(actor.anim, 0)
        ola:Move()
        -- A tap on the keys isn't a stop.
        ola:Halt(); w:Run(0.1); ola:Move(); w:Run(0.5)
        eq(actor.anim, 4)
        ola:Halt(); w:Run(0.31)
        eq(actor.anim, 0, "stopped")
        -- A hop on a click, then back to walking.
        ola:Move()
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 756)
        w:Run(2.1)
        eq(actor.anim, 4)
        -- Another pet's card: it just stands, and the card closed, nothing listens.
        ola:SelectPet(46)
        eq(actor.anim, 0)
        no(Listening("PLAYER_STARTED_MOVING"))
        ola:SelectPet(5159)
        eq(actor.anim, 4, "opened mid-run: GetUnitSpeed says so")
        ola.env.PetJournalPetCard:Hide()
        no(Listening("PLAYER_STARTED_MOVING"))
    end)

    test("moving never wakes a sleeping pet or gets a Latsabb up", function()
        local w, ola, actor = Setup(23)
        ola:Slash("adopter panda")
        w:Run(5)
        ola:SelectPet(5159)
        w:Run(1.81)
        eq(actor.anim, 6)
        ola:Move(); ola:Mount()
        eq(actor.anim, 6, "still asleep")
        w, ola, actor = Setup(14, nil)
        ola.ns.Personality.Traits = function() return { ola.ns.Personality.ById("latsabb") } end
        ola:Slash("adopter panda")
        w:Run(5)
        ola:SelectPet(5159)
        w:Run(8)
        eq(actor.anim, 97)
        ola:Move()
        eq(actor.anim, 97, "the Latsabb stays put")
        -- And auto-summon off: no walking.
        w, ola, actor = Setup(14)
        ola:Slash("adopter panda")
        w:Run(5)
        ola.ns.Summon:SetActive("s:5159", false)
        ola:SelectPet(5159)
        ola:Move()
        eq(actor.anim, 0)
    end)

    test("a dislike today: the first look at its card, it turns its back for a moment", function()
        local w, ola, actor = Setup(14)
        ola.ns.DB.char.sulk = { key = PANDA, day = ola.ns.Today() }
        ola:SelectPet(5159)
        w:Run(ola.ns.Moves.SETTLE + 0.05)
        ok(math.abs(actor.yaw - math.pi) < 1e-6, "back turned")
        w:Run(ola.ns.Moves.SULK + 0.1)
        eq(actor.yaw, 0, "and back")
        ola:SelectPet(46); ola:SelectPet(5159)
        w:Run(1)
        eq(actor.yaw, 0, "once")
    end)

    test("/dp probe pos: what the actor and the scene answer; moving and scaling the pet, and back", function()
        local w, ola, actor = Setup(14)
        ola:SelectPet(5159)
        ola:Slash("probe pos")
        eq(#ola:Log("Probe\tpos actor has: GetPosition SetPosition GetActiveBoundingBox"), 1)
        eq(#ola:Log("Probe\tpos projected box bottom: 200.000, 150.000"), 1, "the feet on the scene")
        ola:Slash("probe pos z 0.2")
        eq(actor.pos[3], 0.2)
        ola:Slash("probe pos scale 1.5")
        eq(actor.scale, 1.5)
        ola:Slash("probe pos reset")
        eq(actor.pos[3], 0); eq(actor.scale, 1)
        -- The box drawn on the card, and again: hidden.
        ola:Slash("probe pos box")
        eq(#ola:Log("Probe\tpos box: left 170, bottom 150, right 230, top 230"), 1)
        ola:Slash("probe pos box")
        eq(#ola:Log("Probe\tpos box hidden"), 1)
        -- Without the geometry: says so, no error.
        actor.GetPosition = nil
        ola:Slash("probe pos z 0.2")
        eq(#ola:Log("Probe\tpos no GetPosition"), 1)
        ola:Slash("probe pos")
        ola:Slash("probe pos box")
        eq(#ola:Log("Probe\tpos no box"), 1)
    end)

    test("a species' lift moves it up or down on its card at once, and only that pet", function()
        local w, ola, actor = Setup(14)
        function actor:SetModelByCreatureDisplayID() self.pos = { 0, 0, 0 } end -- (the client: its own height)
        ola.ns.PetMoves.species[5160] = { lift = 0.3 }
        ola:SelectPet(5160)
        ok(math.abs(actor.pos[3] - 0.3) < 1e-6, "lifted at once")
        w:Run(ola.ns.Moves.SETTLE + 0.05)
        ok(math.abs(actor.pos[3] - 0.3) < 1e-6, "and still, once loaded")
        ola.ns.JournalUI:Refresh()
        w:Run(1)
        ok(math.abs(actor.pos[3] - 0.3) < 1e-6, "not twice")
        -- Another pet without a lift: back to its own height (were the client to leave ours).
        ola:SelectPet(5159)
        w:Run(ola.ns.Moves.SETTLE + 0.05)
        eq(actor.pos[3], 0)
        -- The client loading the model anew puts it at its own height: lifted again.
        ola:SelectPet(5160)
        w:Run(ola.ns.Moves.SETTLE + 0.05)
        actor:SetModelByCreatureDisplayID(1)
        w:Run(ola.ns.Moves.SETTLE + 0.05)
        ok(math.abs(actor.pos[3] - 0.3) < 1e-6)
        eq(ola.ns.Moves:For("s:70", "lift"), -0.2, "the Brown Prairie Dog, by eye")
    end)

    test("review 2026-11-10: the walk follows the badge and the moment a hop ends; one-offs count only once seen", function()
        local w, ola, actor = Setup(14)
        ola:Slash("adopter panda"); w:Run(5)
        local card = ola:SelectPet(5159)
        ola:Move()
        eq(actor.anim, 4)
        card.auto.scripts.OnClick(card.auto) -- ("Med deg" off: not the pet kept out any more)
        eq(actor.anim, 0, "stands at once")
        card.auto.scripts.OnClick(card.auto)
        eq(actor.anim, 4, "on again, still moving: walks")
        -- Stopping during a hop: standing after it.
        ola.ns.Cuddle:Pet(ola:Card())
        eq(actor.anim, 756)
        ola:Halt(); w:Run(2.5)
        eq(actor.anim, 0, "the hop ends standing: we stopped meanwhile")
        -- A sulk cut short by another pet: not spent, and the next pet faces us.
        ola.ns.DB.char.sulk = { key = PANDA, day = ola.ns.Today() }
        ola:SelectPet(46); ola:SelectPet(5159); w:Run(0.2); ola:SelectPet(46); w:Run(1)
        no(ola.ns.DB.char.sulk.shown, "not seen yet")
        ola:SelectPet(5159); w:Run(0.65)
        ok(math.abs(actor.yaw - math.pi) < 1e-6)
        ola:SelectPet(46)
        eq(actor.yaw, 0, "turned back for the next pet")
    end)

    test("review 2026-11-10: a level-up celebrated as the card opens gets its cheer", function()
        local w, ola, actor = Setup(14)
        ola:Slash("adopter panda"); w:Run(5)
        local card = ola:SelectPet(5159)
        ola.env.PetJournalPetCard:Hide()
        w:SkipDays(1)
        ola.ns.Bond:Add(100)
        actor.played = {}
        ola.env.PetJournalPetCard:Show()
        ola:SelectPet(5159)
        ok(card.celebration.flash:IsShown())
        w:Run(ola.ns.Moves.SETTLE + 0.1)
        eq(actor.anim, 754, "the cheer, once the model has loaded")
        w:Run(3)
        eq(actor.anim, 0)
    end)

    test("/dp probe lift: step through the pets, a slider sets the lift; changes saved, the file's back when closed", function()
        local w, ola, actor = Setup(14)
        ola.ns.PetMoves.species[5160] = { lift = 0.3 }
        ola:Slash("probe lift")
        local E = ola.ns.LiftEditor
        ola:SelectPet(5159)
        E:Close(); ola:Slash("probe lift")
        local f = E.frame
        ok(f:IsShown())
        eq(E:Current(), 5159, "starts at the pet on the card")
        match(f.name.text, "Panda Cub %(5159%)")
        f.slider:SetValue(0.5)
        eq(ola.ns.DB.global.liftPicks[5159], 0.5, "saved: it differs from the file")
        ok(math.abs(actor.pos[3] - 0.5) < 1e-6, "and on the card at once")
        f.up:Click()
        eq(ola.ns.DB.global.liftPicks[5159], 0.55)
        f.down:Click(); f.down:Click()
        eq(ola.ns.DB.global.liftPicks[5159], 0.45)
        f.reset:Click()
        eq(ola.ns.DB.global.liftPicks[5159], nil, "the file's again: nothing saved")
        ok(math.abs(actor.pos[3]) < 1e-6)
        f.slider:SetValue(-0.2)
        -- Next: another pet; its own file value shows.
        while E:Current() ~= 5160 do f.next:Click() end
        eq(f.slider.value, 0.3, "the Zergling's lift from the file")
        f.slider:SetValue(0.3) -- (unchanged: nothing saved)
        eq(ola.ns.DB.global.liftPicks[5160], nil)
        f.prev:Click()
        match(f.saved.text, "^1 changed")
        -- Closed: the card uses the file again; the picks stay saved.
        while E:Current() ~= 5159 do f.prev:Click() end
        ok(math.abs(actor.pos[3] + 0.2) < 1e-6)
        f.close:Click()
        no(f:IsShown())
        ok(math.abs(actor.pos[3]) < 1e-6, "the file's (none) again")
        eq(ola.ns.DB.global.liftPicks[5159], -0.2, "kept for reading back")
        -- Without the journal: says so.
        ola.env.PetJournal:Hide()
        ola:Slash("probe lift")
        ok(ola:Printed("Open the pet journal first."))
    end)

    test("/dp probe gains: the gains animation on the card's pet, saving nothing", function()
        local w, ola = Setup(14)
        ola:Slash("adopter panda"); w:Run(5)
        local card = ola:SelectPet(5159)
        local look = ola.ns.DB.char.bondLook[PANDA]
        ola:Slash("probe gains 3 7")
        w:Run(ola.ns.BondTrack.GROW.delay + ola.ns.BondTrack.NUMBER_EVERY + 0.01)
        local shown = {}
        for _, f in ipairs(card.bond.numbers) do if f:IsShown() then shown[#shown + 1] = f.text.text end end
        eq(table.concat(shown, " "), "+3 +7")
        eq(ola.ns.DB.char.bondLook[PANDA], look, "nothing saved")
        ola:Slash("probe gains")
        ok(ola:Printed("Gains preview: 5, 10, 25"))
        card.bond:Hide() -- (a pet with no bond to show)
        ola:Slash("probe gains")
        ok(ola:Printed("Open a pet's card with a bond bar first."))
    end)
end
