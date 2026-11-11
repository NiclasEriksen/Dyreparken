-- Campfires and sleeping bags (2026-11-11, the user): the buffs as activities, a wish for any
-- pet (the fire) or a cozy one (the sleeping bag), and eggs: cozy pets love it, adventurous ones
-- get restless.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local NAMES = { [1283391] = "Campfire", [1229741] = "Campfire's Warmth", [429959] = "Well-Rested" }

    -- Ola with her Bombay Cat adopted, with these traits (ids).
    local function Setup(ids)
        local w, ola = H.Setup{ ola = { 40 } }
        ola.state.spellNames = NAMES
        ola.state.auras = {}
        local P = ola.ns.Personality
        local traits = {}
        for _, id in ipairs(ids or {}) do traits[#traits + 1] = P.ById(id) end
        P.Traits = function() return traits end
        ola:Slash("adopter bombay"); w:Run(5)
        local Q = ola.ns.Quirks
        Q.random = function(n) return n and 1 or 0 end
        Q.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } }
        return w, ola, Q
    end
    local function Buff(ola, name, on)
        ola.state.auras[name] = on or nil
        ola:Fire("UNIT_AURA", "player")
    end
    local function Count(ola, id) return (ola.ns.Activity:Count(id)) end

    test("the buffs: counted as they come, not the ones already there, not in combat or while auras are secret", function()
        local w, ola = Setup()
        ola:Slash("debug on")
        Buff(ola, "Campfire's Warmth", true)
        eq(Count(ola, "camp"), 0, "there at the first look: a /reload by the fire")
        Buff(ola, "Campfire's Warmth", false); Buff(ola, "Campfire's Warmth", true)
        eq(Count(ola, "camp"), 1)
        Buff(ola, "Campfire's Warmth", true)
        eq(Count(ola, "camp"), 1, "still there: not again")
        Buff(ola, "Well-Rested", false); Buff(ola, "Well-Rested", true)
        eq(Count(ola, "rested"), 1)
        Buff(ola, "Campfire", false); Buff(ola, "Campfire", true)
        eq(Count(ola, "campnear"), 1)
        -- Welcoming Campfire: by name, its id logged.
        Buff(ola, "Welcoming Campfire", false); Buff(ola, "Welcoming Campfire", true)
        eq(Count(ola, "campwarm"), 1)
        ok(ola:Log("campwarm: Welcoming Campfire is spell")[1])
        -- In combat, nothing; secret auras, nothing.
        Buff(ola, "Campfire", false)
        ola.state.combat = true
        Buff(ola, "Campfire", true)
        ola.state.combat = false
        eq(Count(ola, "campnear"), 1)
        rawset(ola.env, "C_Secrets", { ShouldAurasBeSecret = function() return true end })
        Buff(ola, "Campfire", false); Buff(ola, "Campfire", true)
        eq(Count(ola, "campnear"), 1)
    end)

    test("wishes: any pet now and then wishes for the fire; only a cozy one for a sleeping bag", function()
        local w, ola = Setup({ "glupsk" })
        local W, P = ola.ns.Wish, ola.ns.Personality
        local function Days(ids)
            local traits = {}
            for _, id in ipairs(ids) do traits[#traits + 1] = P.ById(id) end
            P.Traits = function() return traits end
            local seen = {}
            for d = 1, 120 do
                local day = os.date("%Y%m%d", w:ServerTime() + d * 86400)
                local id = W:For("s:40", day)
                seen[id] = (seen[id] or 0) + 1
            end
            return seen
        end
        local glupsk = Days({ "glupsk", "rampete" })
        ok((glupsk.camp or 0) > 5 and (glupsk.camp or 0) < 40, "the fire, about one day in six")
        eq(glupsk.rested, nil, "not a cozy pet: no sleeping bag")
        local lazy = Days({ "latsabb", "glupsk" })
        ok((lazy.rested or 0) > 5, "a Latsabb wishes for a sleeping bag")
        -- A wish for the fire, done by the fire.
        ola.ns.DB.char.wish = { day = ola.ns.Today(), pet = "s:40", id = "camp", done = false }
        Buff(ola, "Campfire's Warmth", true); Buff(ola, "Campfire's Warmth", false); Buff(ola, "Campfire's Warmth", true)
        ok(ola.ns.DB.char.wish.done, "the wish came true")
        ok(ola:Printed("Bombay Cat fikk ønsket sitt oppfylt: bålkos!", true))
    end)

    test("eggs: a cozy pet enjoys the fire and the sleeping bag, an adventurous one gets restless, the rest say nothing", function()
        local function Run(ids, buff)
            local w, ola = Setup(ids)
            Buff(ola, buff, false); Buff(ola, buff, true); w:Run(1)
            return ola
        end
        local cozy = Run({ "kosete", "glupsk" }, "Campfire's Warmth")
        ok(cozy:Printed("Bombay Cat er helt rolig. Bålkos", true), "cozy by the fire")
        local bold = Run({ "eventyrlysten", "glupsk" }, "Campfire's Warmth")
        ok(bold:Printed("Bombay Cat har sittet stille lenge nok", true), "restless")
        local plain = Run({ "glupsk", "rampete" }, "Campfire's Warmth")
        eq(plain.ns.DB.char.eggs.baal, nil, "doesn't care")
        local both = Run({ "latsabb", "oppdager" }, "Welcoming Campfire")
        ok(both:Printed("Bombay Cat krøller seg sammen ved bålet", true), "cozy wins")
        local sleepy = Run({ "eventyrlysten", "glupsk" }, "Well-Rested")
        ok(sleepy:Printed("Bombay Cat var oppe før soloppgang", true))
        -- A fire nearby: a cozy pet, now and then.
        local near = Run({ "hjemlengsel", "glupsk" }, "Campfire")
        ok(near:Printed("Bombay Cat kikker lengselsfullt", true))
    end)
end
