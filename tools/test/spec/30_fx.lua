-- Fx (Menagerie/Fx.lua): bursts at the cursor over a companion in the world,
-- and small ones at the chat window for bond lines and level-ups.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        ola:Companions{ [40] = { a = true, t = { "cat" } }, [5159] = { a = true, t = { "dragon" } } }
        w:Settle("hello")
        return w, ola, ola.ns.Fx
    end
    -- The particles playing now (started since the last call), by texture.
    local function Started(c)
        local by, n = {}, 0
        for _, p in ipairs(c.ns.Fx.particles or {}) do
            local plays = p.anim.plays or 0
            if p:IsShown() and plays > (p.seen or 0) then
                local tex = p.icon.tex:match("([^\\]+)$")
                by[tex] = (by[tex] or 0) + 1
                n = n + 1
            end
            p.seen = plays
        end
        return by, n
    end

    test("a companion under the mouse: a few hearts at the cursor, any companion's", function()
        local w, ola, Fx = Setup()
        ola.cursor = { 640, 360 }
        ola:Hover{ species = 40, owner = "Kari Berg" }
        local by, n = Started(ola)
        eq(by.heart, 3); eq(n, 3, "only hearts: the family's ambience as well was too much")
        local p = Fx.particles[1]
        eq(p.points[1][2], ola.env.UIParent); eq(p.points[1][3], "BOTTOMLEFT")
        ok(math.abs(p.points[1][4] - 640) <= 10 and math.abs(p.points[1][5] - 360) <= 10, "at the cursor")
        ok(p.anim.looping == "NONE", "one-shot")
        -- The tooltip is redrawn while you hover: not again for a few seconds.
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(select(2, Started(ola)), 0)
        w:Run(5)
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(select(2, Started(ola)), 3)
        -- Your own: the same.
        ola:Hover{ species = 5159, owner = "Ola Nord" }
        by, n = Started(ola)
        eq(by.heart, 3); eq(n, 3)
        -- In combat the tooltip isn't read at all.
        w:Run(5)
        ola.state.combat = true
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(select(2, Started(ola)), 0)
        -- A particle's end hides it.
        p.anim:Finish()
        no(p:IsShown())
    end)

    test("bursts reuse a small pool", function()
        local w, ola, Fx = Setup()
        for i = 1, 10 do
            ola:Hover{ species = 40, owner = "Person " .. i }
        end
        eq(#Fx.particles, Fx.POOL, "never more than the pool")
        Started(ola)
        ola:Hover{ species = 46, owner = "Kari Berg" }
        eq(Started(ola).heart, 3)
        Fx:Burst({ ola.env.UIParent, "CENTER", 0, 0 }, "nothing", {})
        eq(select(2, Started(ola)), 0)
    end)

    test("on screen: a few sparkles at the chat for a bond line, hearts too at a level-up", function()
        local w, ola, Fx = Setup()
        Started(ola)
        ola.ns.Bus:Fire("BOND_LINE", "s:5159", "Panda Cub elsker å bli kost med!")
        local by, n = Started(ola)
        eq(by.sparkle, 4); eq(n, 4)
        eq(Fx.particles[1].points[1][2], ola.env.DEFAULT_CHAT_FRAME)
        ola.ns.Bus:Fire("BOND_LEVEL", "s:5159", 2, "Kjent")
        by = Started(ola)
        eq(by.sparkle, 6); eq(by.heart, 4)
        eq(Fx.particles[5].icon.tex, MEDIA .. "sparkle")
    end)
end
