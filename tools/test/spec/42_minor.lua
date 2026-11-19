-- Minor likes and dislikes (Personality.lua, 2026-11-12, the user): your own bond with a pet unlocks one
-- more like at level 4 and one more dislike at level 6. Lesser than the major ones: fewer points, flavor a
-- third as often, dimmed on the card; the dislike a secret until it happens.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159" -- (Data/Unlocks.lua: nap, then pvp; its majors: herb, fish; boss disliked)

    local function Setup()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:Slash("adopter panda"); w:Run(5)
        local Q = ola.ns.Quirks
        ola:Dice(0)
        ola:QuirksNow()
        ola:Dice(0) -- (the minor like's flavor comes up)
        return w, ola, ola.ns.Personality
    end
    -- Your bond, just under a level, then over it by a real gain (so the level-up fires).
    local function ToLevel(w, ola, level)
        local e = ola.ns.Registry:Life(PANDA, "Ola Nord")
        e.p, e.f = ola.ns.Bond.LEVELS[level][1] - 1, e.f - 60 * 86400
        ola.ns.Bond:Add(1, PANDA)
        w:Run(1)
    end
    local function Points(ola) return (ola.ns.Bond:Today(PANDA)) end

    test("the minor like: locked until your bond reaches level 4, then 2 points each, 10 a day, its line by chance", function()
        local w, ola, P = Setup()
        eq(table.concat({ P:Minor(PANDA) }, " "), "nap pvp")
        eq(P:MinorLike(PANDA), nil, "level 1")
        local before = Points(ola)
        ola.ns.Activity:Emit("nap", 1); w:Run(1)
        eq(Points(ola) - before, 0, "nothing until then (a nap isn't an everyday activity)")
        ToLevel(w, ola, 4)
        ok(ola:Printed("har åpnet seg mer for deg: det liker lur i byen også, litt."), "told at the level-up")
        eq(P:MinorLike(PANDA), "nap")
        before = Points(ola)
        ola.ns.Activity:Emit("nap", 1); w:Run(1)
        eq(Points(ola) - before, 2)
        ok(ola:Printed("lur i byen", true), "its line (by chance: pinned to come)")
        for _ = 1, 10 do ola.ns.Activity:Emit("nap", 1) end
        w:Run(1)
        eq(Points(ola) - before, 10, "at most 10 a day")
        ok(ola.ns.Activity:IsListening("PLAYER_FLAGS_CHANGED"), "the bond watches it now")
        -- Told once: a later level doesn't say it again.
        ToLevel(w, ola, 5)
        local lines = 0
        for _, l in ipairs(ola.printed) do if l:find("åpnet seg mer", 1, true) then lines = lines + 1 end end
        eq(lines, 1, "once")
    end)

    test("the minor dislike: unlocked at level 6 but a secret until it happens, then rarer, dimmed on the card", function()
        local w, ola, P = Setup()
        ToLevel(w, ola, 6)
        ok(ola:Printed("Det er noe nytt", true), "only a hint")
        local set = P:Dislikes(PANDA)
        eq(set.pvp, "minor")
        eq(#(select(2, P:DislikedWords(PANDA))), 0, "not seen yet")
        local card = ola:SelectPet(5159)
        local function Badge(kind, act)
            for _, b in ipairs(card.badges.badges) do
                if b:IsShown() and b.data.kind == kind and b.data.act == act then return b end
            end
        end
        no(Badge("dislike", "pvp"), "secret")
        ok(Badge("secret"), "a ? for it")
        -- It happens; the minor chance (pinned to come up) speaks.
        ola:Dice(0.1) -- (under 0.15: the minor dislike's first time)
        ola.ns.Activity:Emit("pvp", 1); w:RunTimers()
        ok(ola.ns.DB.char.dislikes[PANDA].pvp, "found")
        local major, minor = P:DislikedWords(PANDA)
        eq(#minor, 1)
        card = ola:SelectPet(5159)
        eq(Badge("dislike", "pvp").alpha, 0.55, "dimmed")
        eq(Badge("like", "nap").alpha, 0.55, "the minor like too")
        -- The list's tooltip and the park's stage too, dimmed the same (2026-11-15, the user: they left them out).
        local pline = P:Line(PANDA)
        match(pline, "|cff8c8475" .. P.NOUN.nap .. "|r", "the minor like in the shared line")
        match(pline, "liker ikke [^·]*|cff8c8475" .. P.NOUN.pvp, "the dislike seen, minor")
        ola:OpenJournal({ sideTabs = 4 })
        local Park = ola.ns.ParkPage
        ola:Page("Parken"):Open()
        Park:Spot(PANDA)
        match(Park.spot.text.text, "|cff8c8475" .. P.NOUN.nap .. "|r|cff", "on the stage, back to the line's color after it")
        ola:SelectPet(5159)
        -- The panel's Personlighet: the minor ones marked (and dimmed).
        local tip = ola:About(PANDA, "personality").text
        match(tip, "Liker / .*" .. P.NOUN.nap:sub(1, 1):upper() .. P.NOUN.nap:sub(2) .. " · litt")
        match(tip, "Liker ikke / .*PvP · litt")
        -- Again later: rarer than a major dislike (0.1 is past MINOR_AGAIN).
        ola.ns.DB.char.quirkAt = nil
        local said = #ola:Log("dislike " .. PANDA .. " pvp")
        ola.ns.Activity:Emit("pvp", 1); w:RunTimers()
        eq(#ola:Log("dislike " .. PANDA .. " pvp"), said, "0.1: a major dislike would have spoken, not a minor one")
    end)

    test("the panel says what your bond unlocks next (4, 6, 7), and nothing once it's all unlocked", function()
        local w, ola, P = Setup()
        local card = ola:SelectPet(5159)
        local function Tip() return ola:About(PANDA, "personality").text end
        match(Tip(), "Når båndet ditt blir " .. ola.ns.Bond.LEVELS[4][2] .. ", lærer du mer om hva")
        ToLevel(w, ola, 4)
        match(Tip(), "Når båndet ditt blir " .. ola.ns.Bond.LEVELS[6][2] .. ", lærer du mer om")
        ToLevel(w, ola, 6)
        match(Tip(), "Når båndet ditt blir " .. ola.ns.Bond.LEVELS[7][2] .. ", viser Panda Cub deg en ny side") -- (a third trait)
        ToLevel(w, ola, 7)
        no(Tip():find("Når båndet ditt blir", 1, true))
    end)

    test("every species is pinned, and its minor ones never clash with its major ones", function()
        local w, ola, P = Setup()
        local A = ola.ns.Activity
        for sid in pairs(ola.ns.Companions.species) do
            local pin = P.MINOR_PINS[sid]
            ok(pin, "species " .. sid .. " pinned")
            local key = "s:" .. sid
            local likes = P:Of(key)
            local _, majors = P:Dislikes(key)
            -- (and with its third trait too, at level 7: Personality:Third, all)
            local third = P.ById(pin[3] or "")
            if third and third.like then likes = setmetatable({ [third.like] = true }, { __index = likes }) end
            for i = 1, 2 do if pin[i] then ok(A.KIND[pin[i]], pin[i]) end end
            ok(pin[3] and P.ById(pin[3]), sid .. ": a third trait (level 7)")
            no(pin[1] and likes[pin[1]], sid .. ": the minor like is a major one")
            no(pin[2] and likes[pin[2]], sid .. ": the minor dislike is liked")
            for _, d in ipairs(majors) do no(d == pin[2], sid .. ": the minor dislike is a major one") end
            ok(pin[1] ~= pin[2] or not pin[1], sid)
        end
    end)
end
