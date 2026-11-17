-- A mage's familiars (Data/Familiars.lua, Menagerie/Familiar.lua): which is out, read from its buff and
-- remembered through what can't be read; auto-summon never replaces one (2026-11-15 and 2026-11-17, the user:
-- "especially careful with flightpaths (and maybe mounts)").
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    local RAT, FROG, CAT = 1296202, 1302285, 1302303

    -- Panda Cub adopted and out, auto-summon on; a mage unless opts say otherwise.
    local function Mage(opts)
        opts = opts or {}
        opts.pets = opts.pets or { 5159, 46 }
        opts.summoned = false
        local w = H.World()
        local c = w:AddClient("Ola Nord", opts)
        c.state.class = opts.class or "MAGE"
        c:Reload()
        w:Run(26)
        c:Slash("adopter panda")
        w:Run(4)
        return w, c
    end
    local PANDA = function(c) return c:GuidOf(5159) end
    -- The mage reads a scroll: the familiar replaces the pet out, its buff comes on.
    local function Read(w, c, spell, aura)
        c:Summon(nil)
        c.state.auras[spell] = aura or true
        c:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", spell)
        w:Run(2)
    end

    test("every familiar's row is whole, its family one of the scenes', its key a wire key", function()
        local w, c = Mage()
        local seen = {}
        for _, row in ipairs(c.ns.Familiars) do
            ok(row.id and row.name and row.item and row.spell and row.npc and row.display, row.key)
            eq(row.key, "n:" .. row.name)
            ok(c.ns.Wire.Key(row.key), row.key)
            local inScenes = false
            for _, f in ipairs(c.ns.Scenes.ORDER) do inScenes = inScenes or f == row.family end
            ok(inScenes, row.family)
            no(seen[row.id]); seen[row.id] = true
            eq(c.ns.Familiar:Row(row.key), row)
        end
        eq(#c.ns.Familiars, 3)
    end)

    test("a familiar is held while its buff is on, by id or by name; ours comes back after it", function()
        local w, c = Mage()
        Read(w, c, FROG)
        eq(c.ns.Familiar:Key(), "n:Frog Familiar")
        local calls = c.summonCalls
        c:Zone(); w:Run(5)
        c:EnterCombat(); c:LeaveCombat(); w:Run(5)
        c:Mount(); c:Dismount(); w:Run(5)
        eq(c.summonCalls, calls, "the familiar stays")
        eq(c.ns.Summon.Busy(), "familiar")
        -- By name: the English one, and the client's own (the spell's name).
        c.state.auras = { ["Rat Familiar"] = true }
        eq(c.ns.Familiar:Key(), "n:Rat Familiar", "the English name")
        c.state.spellNames = { [CAT] = "Kattefamiliær" }
        c.state.auras = { ["Kattefamiliær"] = true }
        eq(c.ns.Familiar:Key(), "n:Cat Familiar", "the client's name")
        -- Gone: believed at the second read, and ours comes out.
        c.state.auras = {}
        c:Fire("UNIT_AURA", "player"); w:Run(1)
        eq(c.summonCalls, calls, "one read without the buff isn't enough")
        w:Run(3)
        eq(c.summoned, PANDA(c), "its buff gone, twice: ours")
        eq(c.ns.DB.char.familiar, nil)
        local n = #c:Log("check %(familiar%)")
        c:Fire("UNIT_AURA", "player"); w:Run(5)
        eq(#c:Log("check %(familiar%)"), n, "the watch ended with it")
    end)

    -- The user's worry: off a flight path or a mount, the buff may read as gone a moment.
    test("landing or dismounting with the auras not back yet doesn't replace the familiar", function()
        local w, c = Mage()
        Read(w, c, CAT)
        local calls = c.summonCalls
        c:Set("taxi", true); c:Zone(); w:Run(20)
        c.state.auras = {} -- (the landing's loading screen: no buffs read yet)
        c:Set("taxi", false); c:Zone(); c:Fire("UNIT_AURA", "player"); w:Run(1)
        c.state.auras[CAT] = true; c:Fire("UNIT_AURA", "player"); w:Run(10)
        eq(c.summonCalls, calls, "after the flight")
        c:Mount(); c.state.auras = {}; c:Dismount(); w:Run(1)
        c.state.auras[CAT] = true; c:Fire("UNIT_AURA", "player"); w:Run(10)
        eq(c.summonCalls, calls, "after a mount")
        eq(c.ns.Familiar:Key(), "n:Cat Familiar")
    end)

    test("an aura read that's secret or fails keeps a familiar seen; one never seen isn't made up", function()
        local w, c = Mage()
        no(c.ns.Familiar:Out())
        Read(w, c, RAT)
        local calls = c.summonCalls
        c.state.auras = {}
        c.state.secretAuras = true
        c:Zone(); w:Run(10)
        eq(c.ns.Familiar:Key(), "n:Rat Familiar", "secret auras: kept")
        c.state.secretAuras = nil
        c.state.aurasError = true
        c:Zone(); w:Run(10)
        eq(c.ns.Familiar:Key(), "n:Rat Familiar", "a failing read: kept")
        eq(c.summonCalls, calls)
        c.state.aurasError = nil
        c:Fire("UNIT_AURA", "player"); w:Run(5)
        eq(c.summoned, PANDA(c), "read plainly gone: ours")
        c.state.auras = { [RAT] = H.SECRET }
        no(c.ns.Familiar:Out(), "a secret answer with none seen")
    end)

    test("remembered through a /reload, watched again; its buff's end brings ours back without an aura event", function()
        local w, c = Mage()
        Read(w, c, FROG)
        c.state.aurasError = true -- (the login reads nothing)
        c:Reload(); w:Run(30)
        eq(c.ns.Familiar:Key(), "n:Frog Familiar", "kept through the reload")
        eq(c.summoned, nil)
        c.state.aurasError = nil
        c.state.auras = {}
        c:Fire("UNIT_AURA", "player"); w:Run(5)
        eq(c.summoned, PANDA(c), "its buff's end seen after the reload")
        -- Ending quietly: no UNIT_AURA, no read at all, only its time.
        Read(w, c, CAT, { name = "Cat Familiar", expirationTime = c.env.GetTime() + 600 })
        c.state.auras = {}
        w:Run(590)
        eq(c.summoned, nil, "not before its end")
        w:Run(15)
        eq(c.summoned, PANDA(c), "its time up: ours")
        eq(c.ns.DB.char.familiar, nil)
    end)

    test("only a mage watches for scrolls; the familiar's coming and going on the Bus", function()
        local w, c = Mage({ class = "WARRIOR" })
        Read(w, c, CAT)
        eq(#c:Log("Familiar.*out:"), 0, "no watch for a warrior's casts")
        local w2, m = Mage()
        local got = {}
        m.ns.Bus:On("FAMILIAR", function(key) got[#got + 1] = tostring(key) end)
        m:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast-1", 8690); w2:Run(2)
        eq(#got, 0, "another spell")
        Read(w2, m, CAT)
        m.state.auras = {}; m:Fire("UNIT_AURA", "player"); w2:Run(5)
        eq(table.concat(got, ","), "n:Cat Familiar,nil")
    end)
end
