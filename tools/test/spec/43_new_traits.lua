-- The traits of 2026-11-12 (the user, for 0.5): Sjørøver (gold), Skøyer (silly emotes), Røverdyr (sneaking)
-- and Ordensdyr (in a city), Venneflokk (meeting other pets), Vinterpels and Solelsker (cold and warm zones),
-- Tivolidyr (the Darkmoon Faire), Bålkos (campfires), Skybåren (high places), Jeger, Håndverker, Diplomat.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    local function Setup()
        local w, ola = H.Setup{ ola = { 5159 } }
        return w, ola, ola.ns.Activity
    end
    local function Want(A, id) A:Want(id, "test") end

    test("the new activities: gold looted, a silly emote, into stealth, another player's pet met", function()
        local w, ola, A = Setup()
        for _, id in ipairs({ "gold", "fun", "sneak", "meet" }) do Want(A, id) end
        ola:Fire("CHAT_MSG_MONEY", "You loot 5 Silver"); w:Run(1)
        eq((A:Count("gold")), 1)
        local me = ola.env.UnitGUID("player")
        local function Emote(text) ola:Fire("CHAT_MSG_TEXT_EMOTE", text, "Ola Nord", "", "", "", "", 0, 0, "", 0, 0, me) end
        Emote("You laugh."); Emote("You tell a joke."); Emote("You wave."); w:Run(1)
        eq((A:Count("fun")), 2, "laughing and joking; waving isn't silly")
        eq(A.EmoteKind("With arms flapping, you strut around. Cluck, Cluck, Chicken!"), "fun")
        eq(A.EmoteKind("You dance."), "dance", "dancing stays its own")
        -- Stealth: from not stealthed into it, once.
        ola:Fire("UNIT_AURA", "player"); w:Run(1)
        ola.state.stealthed = true
        ola:Fire("UNIT_AURA", "player"); ola:Fire("UNIT_AURA", "player"); w:Run(1)
        eq((A:Count("sneak")), 1)
        ola.state.stealthed = false; ola:Fire("UNIT_AURA", "player")
        ola.state.stealthed = true; ola:Fire("UNIT_AURA", "player"); w:Run(1)
        eq((A:Count("sneak")), 2, "again after coming out")
        -- Meeting: each owner's pet once a day, never your own.
        ola.ns.Bus:Fire("COMPANION_SEEN", 40, "Kari Berg")
        ola.ns.Bus:Fire("COMPANION_SEEN", 40, "Kari Berg")
        ola.ns.Bus:Fire("COMPANION_SEEN", 46, "Kari Berg")
        ola.ns.Bus:Fire("COMPANION_SEEN", 40, "Ola Nord")
        ola.ns.Bus:Fire("COMPANION_SEEN", 40, nil)
        w:Run(1)
        eq((A:Count("meet")), 2)
        w:SkipDays(1)
        ola.ns.Bus:Fire("COMPANION_SEEN", 40, "Kari Berg"); w:Run(1)
        eq((A:Count("meet")), 3, "a new day")
    end)

    test("the zone traits read where you are; Ordensdyr a city; they never pair with their opposites", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        local function Moment(id, zone)
            ola.state.zone = zone
            return P.ById(id).when(ola.ns.Bond.Context()) and true or false
        end
        ok(Moment("vinterpels", "Winterspring")); no(Moment("vinterpels", "Tanaris"))
        ok(Moment("solelsker", "Tanaris")); no(Moment("solelsker", "Winterspring"))
        ok(Moment("skybaren", "Thunder Bluff")); no(Moment("skybaren", "Westfall"))
        ok(Moment("ordensdyr", "Stormwind City")); no(Moment("ordensdyr", "Elwynn Forest"))
        eq(P.ById("vinterpels").against, "solelsker"); eq(P.ById("roverdyr").against, "ordensdyr")
        for sid, pin in pairs(P.PINNED) do
            no(P.ById(pin[1]).against == pin[2], sid .. ": a trait with its opposite")
        end
    end)

    test("Tivolidyr: a double day while the Darkmoon Faire is on (the calendar's event 263)", function()
        local w, ola = Setup()
        local P, Hol = ola.ns.Personality, ola.ns.Holidays
        eq(Hol.EVENTS[263], "darkmoon")
        local t = ola.ns.Now()
        local trait = P.ById("tivolidyr")
        local on = false
        Hol.Has = function(_, _, word) return word == "darkmoon" and on end
        eq(trait.day(t), 1)
        on = true
        eq(trait.day(t), 2)
        ok(ola.ns.Decor.TRAITS.tivolidyr.when(t), "its lights, that day")
    end)

    test("every new trait has its words, its particles, and pets that have it", function()
        local w, ola = Setup()
        local P, S = ola.ns.Personality, ola.ns.Strings
        local used = {}
        for _, pin in pairs(P.PINNED) do used[pin[1]] = true; used[pin[2]] = true end
        for _, id in ipairs({ "sjorover", "skoyer", "roverdyr", "ordensdyr", "venneflokk", "vinterpels", "solelsker",
            "tivolidyr", "balkos", "skybaren", "jeger", "handverker", "diplomat" }) do
            local t = P.ById(id)
            ok(t, id)
            ok(S["trait." .. id .. ".name"] and S["trait." .. id .. ".desc"], id .. ": words")
            if t.when then ok(S["trait." .. id .. ".when"] and S["trait." .. id .. ".flavor"], id .. ": its moment") end
            ok(ola.ns.Decor.TRAITS[id], id .. ": particles")
            ok(used[id], id .. ": some species has it")
        end
    end)

    test("the adopted pets keep their traits (the rework of 2026-11-12 left them as they were)", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        local KEPT = { [39] = "dansefot friluftsdyr", [42] = "pratsom flokkdyr", [51] = "vannhund flokkdyr", [55] = "steinhard dykker",
            [70] = "helgedyr hjemlengsel", [5075] = "hoppetass steinhard", [5159] = "kosete gronnfinger",
            [5160] = "kjaelen pratsom", [5161] = "eventyrlysten reiseglad" }
        for sid, ids in pairs(KEPT) do eq(table.concat(P.PINNED[sid], " "), ids, tostring(sid)) end
    end)
end
