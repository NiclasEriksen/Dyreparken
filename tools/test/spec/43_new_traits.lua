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
        Emote("You laugh."); w:Run(A.EMOTE_EVERY); Emote("You tell a joke."); Emote("You wave."); w:Run(1)
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

    test("one like from the families: every species with a choice has its pick, the adopted kept theirs", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        for sid in pairs(ola.ns.Companions.species) do
            local key = "s:" .. sid
            local can = P:FamilyLikes(ola.ns.Scenes:Families(key))
            local pick = P.FAMILY_PICK[sid]
            if #can > 1 then ok(pick ~= nil, sid .. ": pick its family like (Personality.FAMILY_PICK)") end
            local picks = type(pick) == "table" and pick or pick and { pick } or {}
            for _, act in ipairs(picks) do
                ok(table.concat(can, " "):find(act, 1, true), sid .. ": " .. act .. " isn't its families'")
            end
        end
        -- (the adopted pets of 2026-11-12 kept all their family likes; each trait's like after them since 2026-11-19)
        eq(table.concat((select(2, P:Of("s:51"))), " "), "taxi fish pvp dive guildgroup", "Senegal")
        eq(table.concat((select(2, P:Of("s:39"))), " "), "mine skill dance camp", "Mechanical Squirrel")
        eq(table.concat((select(2, P:Of("s:5159"))), " "), "herb fish cuddle", "Panda Cub")
        eq(table.concat((select(2, P:Of("s:47"))), " "), "boat taxi chat fun", "Cockatiel: six likes before")
    end)

    -- 2026-11-19 (the user): at most 6 likes and 3 dislikes, and with everything unlocked (level 7: the minor ones and
    -- the third trait) at least 4 likes and 2 dislikes. (Was 4 to 6 likes and dislikes together, 2026-11-12.)
    test("every species: 4 to 6 likes and 2 to 3 dislikes at level 7, never more before", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        local level = 7
        P.YourLevel = function() return level end
        local function Counts(key)
            local _, likes = P:Of(key)
            local _, dislikes = P:Dislikes(key)
            return #likes + (P:MinorLike(key) and 1 or 0), #dislikes
        end
        local where = " (Personality's tables, Data/Unlocks.lua: tools/pin_unlocks.lua)"
        for sid in pairs(ola.ns.Companions.species) do
            local key = "s:" .. sid
            level = 7
            local l, d = Counts(key)
            ok(l >= 4 and l <= 6, sid .. ": " .. l .. " likes" .. where)
            ok(d >= 2 and d <= 3, sid .. ": " .. d .. " dislikes" .. where)
            level = 0
            local l0, d0 = Counts(key)
            ok(l0 <= l and d0 <= d, sid .. ": nothing lost on the way")
        end
        -- (a family dislike a species is spared; none from its families)
        no(P:Dislikes("s:47").pvp, "the Cockatiel, a pirate's bird, doesn't mind PvP")
        ok(P:Dislikes("s:40").dive, "a cat still minds the water")
        ok(P:Dislikes("s:42").boat, "and boats")
        no(P:Dislikes("s:44").boat, "but not the Siamese, a ship's cat")
        ok(P:Dislikes("s:44").taxi, "it minds flying instead")
        eq(table.concat((select(2, P:Of("s:125"))), " "), "nap dive", "Speedy: no family like")
    end)
end
