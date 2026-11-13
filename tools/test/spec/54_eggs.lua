-- Easter eggs of 2026-11-13 (the user's ideas, Menagerie/Quirks.lua): Hakkebakkeloven (a playdate between a
-- hunter and its prey), Bastians runde (22:00), Gjensynsglede (back with a pet after days apart).
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    -- Ola's Panda Cub, adopted and out, as the family asked; Kari's Bombay Cat (40) a cat, the
    -- 46 a rodent, 72 a plant. The dice say yes and pick the first line.
    local function Setup(family, traits)
        local w, ola = H.Setup{ ola = { 5159 } }
        w:AddMember("Kari Berg", 0); ola.ns.Guild:Refresh(true); w:Run(1)
        ola:Companions{ [5159] = { a = true, t = { family } }, [40] = { a = true, t = { "cat" } },
            [46] = { a = true, t = { "rodent" } }, [72] = { a = true, t = { "plant" } } }
        ola:Traits(traits or { "glupsk", "rampete" })
        ola:Slash("adopter panda"); w:Run(5)
        ola:Dice(0)
        ola:QuirksNow()
        return w, ola
    end

    local function Play(ola, theirs, who)
        local P = ola.ns.Playdate
        P.Near = function() return true end -- (range has its own test, 28_multibond)
        P:Heard(who or "Kari Berg", theirs)
        ola.world:RunTimers()
    end

    test("hakkebakke: a hunter and its prey at a playdate keep the forest's law, by which side yours is on", function()
        local w, ola = Setup("cat")
        Play(ola, "s:72")
        no(ola:Printed("Hakkebakke", true), "a plant: nobody's prey")
        Play(ola, "s:46", "Per Hansen")
        no(ola:Printed("Hakkebakke", true), "not a guildmate")
        w:AddMember("Per Hansen", 0); ola.ns.Guild:Refresh(true); w:Run(1)
        Play(ola, "s:46", "Per Hansen")
        ok(ola:Printed("Panda Cub ser lenge på", true), "the cat and the rodent: yours is the hunter")
        ok(ola:Printed("husker Hakkebakkeloven", true))
        Play(ola, "s:46", "Per Hansen")
        eq(ola:CountPrinted("Hakkebakkeloven"), 1, "once a day")
        -- The other side: a rabbit meets a cat.
        local w2, kari = Setup("rabbit")
        Play(kari, "s:40")
        ok(kari:Printed("alle dyrene i skogen skal jo være venner", true), "yours is the prey")
        -- A Venneflokk beams either way; a Røverdyr licks its lips, as the hunter only.
        local w3, per = Setup("rabbit", { "venneflokk", "glupsk" })
        Play(per, "s:40")
        ok(per:Printed("Alle dyrene i skogen skal være venner!", true))
        local w4, liv = Setup("cat", { "roverdyr", "glupsk" })
        Play(liv, "s:46", "Kari Berg")
        ok(liv:Printed("slikker seg rundt munnen", true))
        local w5, bo = Setup("rabbit", { "roverdyr", "glupsk" })
        Play(bo, "s:40")
        no(bo:Printed("slikker seg", true)); ok(bo:Printed("skal jo være venner", true), "a Røverdyr rabbit is still prey")
        for f, list in pairs(ola.ns.Quirks.PREY) do
            no(f == list[1], f .. " doesn't hunt its own")
        end
    end)
end
