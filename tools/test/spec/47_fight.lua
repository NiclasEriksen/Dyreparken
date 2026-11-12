-- The pet joins your fights (Menagerie/Fight.lua, 2026-11-12): on the pet frame, now and then, an attack
-- move (a timid pet cowers, a Latsabb watches), from your swings (physical hits on your target while your
-- auto-attack is on, one per weapon swing) and your casts; no combat log on Forever.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    -- Ola with her Panda Cub out on the pet frame, these traits, every roll a yes (or as set).
    local function Setup(traits, roll)
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        ola:Traits(traits or {})
        w:SetDate(2027, 3, 2, 14)
        ola.ns.DB.global.settings.petFrame = true
        ola.ns.PetFrame:Apply()
        local F = ola.ns.Fight
        ola.ns.random = function() return roll or 0 end
        return w, ola, F, ola.ns.PetFrame.actor
    end
    local function Hit(ola, school, flag) ola:Fire("UNIT_COMBAT", "target", "WOUND", flag or "", H.SECRET, school or 1) end
    local function Moves(ola, what) return #ola:Log("Fight	.*" .. what .. " %(") end

    test("a fight: a pounce at its start, then now and then on your swings, one per swing, a few seconds apart", function()
        local w, ola, F, actor = Setup()
        ola.state.attacking = true -- (auto-attack on as the fight starts)
        ola:Slash("debug on")
        ola:EnterCombat()
        eq(actor.anim, 750, "a pounce")
        w:Run(2)
        Hit(ola)
        eq(Moves(ola, "attack"), 1, "too soon after the last move")
        w:Run(3)
        Hit(ola)
        eq(Moves(ola, "attack"), 2, "a swing")
        eq(actor.anim, 750)
        w:Run(5)
        Hit(ola, 4)
        eq(Moves(ola, "attack"), 2, "fire: a weapon's proc or a spell, not a swing")
        Hit(ola)
        eq(Moves(ola, "attack"), 3)
        w:Run(5)
        Hit(ola); w:Run(0.5); Hit(ola) -- (in a group others' hits come in between)
        eq(Moves(ola, "attack"), 4)
        w:Run(2)
        ok(ola:Log("Fight	.*swing 2.0 s")[1], "the weapon's speed")
        -- One per swing, whatever the gap between moves.
        F.GAP = { solo = 0, group = 0 }
        w:Run(5); Hit(ola); w:Run(0.5); Hit(ola)
        eq(Moves(ola, "attack"), 5, "half a second: someone else's")
        w:Run(1.5); Hit(ola)
        eq(Moves(ola, "attack"), 6, "two seconds on: your next swing")
        F.GAP = { solo = 3, group = 5 }; w:Run(5)
        -- Auto-attack off: the hits on the target are someone else's.
        ola:Fire("PLAYER_LEAVE_COMBAT")
        w:Run(5); Hit(ola)
        eq(Moves(ola, "attack"), 6)
        -- A cast of yours is a chance too.
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 8053)
        eq(Moves(ola, "attack"), 7)
        ola:LeaveCombat()
        w:Run(5)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-2", 8053)
        eq(Moves(ola, "attack"), 7, "the fight is over: nothing listened to")
    end)

    test("auto shot (unverified: no ranged weapon probed yet) by the ranged speed; auto-attack started mid-fight", function()
        local w, ola, F = Setup()
        ola:Slash("debug on")
        ola.state.rangedSwing = 3.0
        ola:EnterCombat() -- (a spell first: no auto-attack yet)
        w:Run(5); Hit(ola)
        eq(Moves(ola, "attack"), 1, "the start only: the hits aren't yours")
        ola:Fire("START_AUTOREPEAT_SPELL")
        F.GAP = { solo = 0, group = 0 }
        Hit(ola); w:Run(2); Hit(ola)
        eq(Moves(ola, "attack"), 2, "one per 3 s shot")
        w:Run(1); Hit(ola)
        eq(Moves(ola, "attack"), 3)
        ola:Fire("STOP_AUTOREPEAT_SPELL")
        w:Run(5); Hit(ola)
        eq(Moves(ola, "attack"), 3, "stopped")
        ola:Fire("PLAYER_ENTER_COMBAT") -- (into melee)
        Hit(ola)
        eq(Moves(ola, "attack"), 4)
        ola:LeaveCombat()
    end)

    test("now and then: a roll per swing, likelier solo, for a fighter and on a crit", function()
        local w, ola, F = Setup(nil, 0.4)
        ola:Slash("debug on")
        ola.state.attacking = true
        ola:EnterCombat()
        eq(Moves(ola, "attack"), 1, "the start: likely")
        w:Run(5); Hit(ola)
        eq(Moves(ola, "attack"), 2, "solo, a plain pet: 0.4 is yes")
        w:SetGroup({ "Ola Nord", "Kari Berg", "Per Hansen" })
        ok(ola.env.IsInGroup(), "(in a group)")
        w:Run(6); Hit(ola)
        eq(Moves(ola, "attack"), 2, "in a group: 0.4 is no")
        w:Run(6); Hit(ola, 1, "CRITICAL")
        eq(Moves(ola, "attack"), 3, "a crit: yes")
        ola:LeaveCombat()
        local w2, kari, F2 = Setup({ "jeger", "latsabb" }, 0.55)
        kari:Slash("debug on")
        kari.state.attacking = true
        kari:EnterCombat()
        w2:Run(5); Hit(kari)
        eq(Moves(kari, "attack"), 2, "a fighter (Jeger wins over Latsabb), solo: 0.55 is yes, at the start and the swing")
    end)

    test("by its nature: a timid pet cowers, a Latsabb watches, a pet without the move stands", function()
        local w, ola, F, actor = Setup({ "kosete" })
        eq(F.Nature(PANDA), "timid")
        ola:EnterCombat()
        eq(actor.anim, 748, "it cowers")
        ola:LeaveCombat()
        local w2, kari, F2, actor2 = Setup({ "latsabb" })
        eq(F2.Nature(PANDA), "watch")
        kari:Slash("debug on")
        kari:EnterCombat()
        ok(kari:Log("Fight") and not kari:Log("Fight	.*joins in")[1], "it doesn't join in: nothing listened to")
        no(actor2.anim == 750)
        kari:LeaveCombat()
        local w3, per, F3, actor3 = Setup()
        per.ns.PetMoves.species[5159] = { attack = false }
        per:EnterCombat()
        no(actor3.anim == 750, "no attack move for it")
    end)

    test("only with the pet frame showing it: off, hidden in combat, or no pet out", function()
        local w, ola, F, actor = Setup()
        ola:Slash("debug on")
        ola.ns.DB.global.settings.petFrameCombat = true; ola.ns.PetFrame:Apply()
        ola:EnterCombat()
        eq(Moves(ola, "attack"), 0, "hidden in combat")
        ola:LeaveCombat()
        ola.ns.DB.global.settings.petFrameCombat = false
        ola.ns.DB.global.settings.petFrame = false; ola.ns.PetFrame:Apply()
        ola:EnterCombat()
        eq(Moves(ola, "attack"), 0, "the frame off: the fight events not even listened to")
        ola:LeaveCombat()
    end)
end
