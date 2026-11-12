-- The pet and the damage meter (Menagerie/Meter.lua, 2026-11-12): after a boss kill in a group, first in damage
-- (or healing in a raid, or the most interrupts) may bring a line, a gold bubble and a cheer. Flavor only.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    -- The meter's Current session, as the probe saw it after combat: sources sorted, ours marked.
    local function Session(rows)
        local sources = {}
        for i, r in ipairs(rows) do
            sources[i] = { name = r[1], totalAmount = r[2], isLocalPlayer = r[1] == "Ola Nord", classFilename = "WARRIOR" }
        end
        return { combatSources = sources }
    end
    local function Setup(members)
        local meter = { reads = 0 }
        local w, ola = H.Setup{ ola = { pets = { 5159 }, patch = function(env)
            env.C_DamageMeter = { GetCombatSessionFromType = function(st, kind)
                meter.reads = meter.reads + 1
                return st == 1 and meter[kind] or nil
            end }
        end } }
        ola:Slash("adopter panda"); w:Run(5)
        local names = { "Ola Nord" }
        for i = 2, members or 5 do names[i] = "Member " .. i end
        w:SetGroup(names)
        local Q = ola.ns.Quirks
        ola:Dice(0) -- (every chance comes up)
        ola:QuirksNow()
        return w, ola, meter
    end
    local function Kill(w, ola, boss)
        ola:Fire("ENCOUNTER_END", 1, boss or "Bloodmage Thalnos", 1, 5, 1)
        w:Run(2)
    end

    test("first in damage on a dungeon boss: the pet's line, a gold bubble, a cheer; read once, after the kill", function()
        local w, ola, meter = Setup(5)
        meter[0] = Session({ { "Ola Nord", 5000 }, { "Member 2", 4000 }, { "Member 3", 1000 } })
        local said = {}
        ola.ns.Bus:On("PET_SAID", function(_, kind, text) said[#said + 1] = kind end)
        Kill(w, ola)
        eq((ola.ns.Activity:Count("dmgtop")), 1)
        ok(ola.ns.DB.char.eggs.toppen, "its egg")
        ok(said[#said] == "major", "a gold bubble")
        ok(meter.reads >= 1 and meter.reads <= 3, "read once per kind, no polling")
        no(ola.ns.Meter.last.raid); no(ola.ns.Meter.last.far, "5000 against 4000: ahead, not far")
    end)

    test("not first, not in a group of three, or no pet out: nothing; healing counts only in a raid", function()
        local w, ola, meter = Setup(5)
        meter[0] = Session({ { "Member 2", 6000 }, { "Ola Nord", 5000 } })
        meter[2] = Session({ { "Ola Nord", 9000 }, { "Member 2", 10 } })
        Kill(w, ola)
        eq((ola.ns.Activity:Count("dmgtop")), 0, "second")
        eq((ola.ns.Activity:Count("healtop")), 0, "healing in a five-man: the one healer is always first")
        -- A raid: healing counts.
        local names = { "Ola Nord" }
        for i = 2, 10 do names[i] = "Member " .. i end
        w:SetGroup(names)
        Kill(w, ola, "Lucifron")
        eq((ola.ns.Activity:Count("healtop")), 1)
        ok(ola.ns.Meter.last.raid and ola.ns.Meter.last.far, "a raid, far ahead")
        eq(ola.ns.Quirks.MeterChance(), 0.95, "likelier: a raid boss and a very good result")
        -- Two in the group: not counted.
        local w2, kari, m2 = Setup(2)
        m2[0] = Session({ { "Ola Nord", 5000 }, { "Member 2", 10 } })
        Kill(w2, kari)
        eq((kari.ns.Activity:Count("dmgtop")), 0)
        -- No pet out: no boss activity with a pet, no read.
        local w3, per, m3 = Setup(5)
        m3[0] = Session({ { "Ola Nord", 5000 } })
        per:Summon(nil)
        local reads = m3.reads
        Kill(w3, per)
        eq(m3.reads, reads)
    end)

    test("the most interrupts (two at least): a line now and then; a secret or missing meter reads as nothing", function()
        local w, ola, meter = Setup(5)
        meter[5] = Session({ { "Ola Nord", 3 }, { "Member 2", 1 } })
        Kill(w, ola)
        eq((ola.ns.Activity:Count("kicktop")), 1)
        meter[5] = Session({ { "Ola Nord", 1 } })
        Kill(w, ola, "Herod")
        eq((ola.ns.Activity:Count("kicktop")), 1, "one kick isn't the most")
        meter[0] = { combatSources = H.SECRET }
        eq(ola.ns.Meter.Place(0), nil, "secret: nothing")
        meter[0] = nil
        eq(ola.ns.Meter.Place(0), nil)
    end)
end
