-- Bad luck in a fight (2026-11-14, the user): five weapon swings missed in a row, or three spells resisted in
-- a row, are eggs (bom, motstand), said after the fight. Read from UNIT_COMBAT on the target, which doesn't say
-- who hit: so only solo, without a combat pet of yours, and for swings with your auto-attack on.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    local function Setup(traits)
        local w, ola = H.Setup{ ola = { 5159 }, settle = "bond" }
        ola:Traits(traits or { "glupsk", "helgedyr" }, 5159)
        ola:Slash("adopter panda"); w:Run(5)
        ola:Dice(0)
        ola:QuirksNow()
        ola.state.attacking = true
        ola.state.combat = true
        ola:Fire("PLAYER_REGEN_DISABLED")
        return w, ola
    end
    local function Hit(ola, action, school) ola:Fire("UNIT_COMBAT", "target", action, "", H.SECRET, school or 1) end
    local function After(w, ola)
        ola.state.combat = false
        ola:Fire("PLAYER_REGEN_ENABLED")
        w:Run(5)
    end
    local function Said(ola, prefix)
        for _, k in ipairs(ola.ns.Variants(prefix)) do
            if ola:Printed(ola.ns.T(k, { pet = "Panda Cub" }), true) then return true end
        end
        return false
    end

    test("five swings missed in a row: a line after the fight; a hit between them starts over", function()
        local w, ola = Setup()
        for _ = 1, 4 do Hit(ola, "MISS") end
        Hit(ola, "WOUND")
        Hit(ola, "DODGE"); Hit(ola, "PARRY"); Hit(ola, "MISS"); Hit(ola, "MISS")
        w:Run(1)
        no(Said(ola, "egg.bom"), "four since the hit")
        Hit(ola, "WOUND", 4) -- (a spell's hit doesn't break a swing's run)
        Hit(ola, "MISS")
        w:Run(3)
        no(Said(ola, "egg.bom"), "not in the fight")
        After(w, ola)
        ok(Said(ola, "egg.bom"))
        eq(ola.ns.DB.char.eggs.bom.n, 1)
    end)

    -- The same rule as the reactions (2026-11-15, the user): a fight that ended with your death says nothing
    -- about it; and a rare egg spends none of the quirks' 45 minutes.
    test("a fight that ended with your death: its egg unsaid; a rare egg leaves the 45 minutes free", function()
        local w, ola = Setup()
        for _ = 1, 5 do Hit(ola, "MISS") end
        ola.state.dead = true
        After(w, ola)
        no(Said(ola, "egg.bom"), "dead")
        ok(ola:Log("egg bom: unsaid")[1])
        eq(ola.ns.DB.char.eggs.bom, nil)
        ola.state.dead = false
        ola.state.combat = true; ola:Fire("PLAYER_REGEN_DISABLED")
        for _ = 1, 5 do Hit(ola, "MISS") end
        After(w, ola)
        ok(Said(ola, "egg.bom"))
        eq(ola.ns.Moments:Left("quirk"), 0, "rare: nothing spent")
    end)

    test("three spells resisted in a row, by its nature; a spell's hit between them starts over", function()
        local w, ola = Setup({ "skoyer", "glupsk" })
        Hit(ola, "RESIST", 16); Hit(ola, "RESIST", 16)
        Hit(ola, "WOUND", 16)
        Hit(ola, "RESIST", 4); Hit(ola, "RESIST", 8)
        Hit(ola, "WOUND", 1) -- (a swing's hit doesn't break a spell's run)
        Hit(ola, "RESIST", 16)
        After(w, ola)
        ok(Said(ola, "egg.motstand.skoyer"))
    end)

    test("the target's hits are heard only in a fight of your own: not out of one, not in a group", function()
        local w, ola = Setup()
        local A = ola.ns.Activity
        ok(A:IsListening("UNIT_COMBAT"), "in a fight, solo")
        no(A:IsListening("UNIT_HEALTH"), "a fall only counts out of one")
        After(w, ola)
        no(A:IsListening("UNIT_COMBAT"), "after it")
        ok(A:IsListening("UNIT_HEALTH"))
        w:SetGroup({ "Ola Nord", "Per Hansen" }); ola:Fire("GROUP_ROSTER_UPDATE")
        ola.state.combat = true; ola:Fire("PLAYER_REGEN_DISABLED")
        no(A:IsListening("UNIT_COMBAT"), "in a group's fight: anyone's hits")
        local updates = #ola:Log("Activity")
        for _ = 1, 20 do ola:Fire("GROUP_ROSTER_UPDATE") end -- (a raid's roster: in bursts, nothing changed)
        w:SetGroup(nil); ola:Fire("GROUP_ROSTER_UPDATE")
        ok(A:IsListening("UNIT_COMBAT"), "the group gone, mid-fight")
        -- A run doesn't carry over into the next fight.
        for _ = 1, 4 do Hit(ola, "MISS") end
        After(w, ola)
        ola.state.combat = true; ola:Fire("PLAYER_REGEN_DISABLED")
        Hit(ola, "MISS")
        After(w, ola)
        no(Said(ola, "egg.bom"))
    end)

    test("not when it may be someone else's: in a group, with a combat pet out, or without your auto-attack", function()
        local w, ola = Setup()
        ola.state.attacking = false
        for _ = 1, 5 do Hit(ola, "MISS") end
        ola.state.attacking = true
        ola.units.pet = { who = { name = "Kitty", family = { "Cat", 2 } } }
        for _ = 1, 5 do Hit(ola, "MISS") end
        for _ = 1, 3 do Hit(ola, "RESIST", 16) end
        ola.units.pet = nil
        w:SetGroup({ "Ola Nord", "Per Hansen" })
        for _ = 1, 5 do Hit(ola, "MISS") end
        for _ = 1, 3 do Hit(ola, "RESIST", 16) end
        w:SetGroup(nil)
        After(w, ola)
        no(Said(ola, "egg.bom")); no(Said(ola, "egg.motstand"))
        -- Every trait it lists has its lines.
        for _, id in ipairs({ "bom", "motstand" }) do
            for _, t in ipairs(ola.ns.Quirks.EggById(id).traits) do ok(ola.ns.Strings["egg." .. id .. "." .. t .. ".1"], id .. "." .. t) end
        end
    end)
end
