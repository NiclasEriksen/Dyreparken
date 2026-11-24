-- Wishes by nature (2026-11-14, the user): now and then a pet wishes for what fits its traits and
-- families instead of a like: company from the guild for a social pet (in a group with a guildmate, a
-- playdate, a guildmate's pet met), never a loner; a trip to one of its zones that you can reach. And
-- every wish has words of its own on the card, the same all day.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, OWL, WOLF = "s:5159", "s:68", "s:5018"

    -- Ola with the panda adopted and out; Kari (a guildmate) with her Bombay.
    local function Setup()
        local w, ola, kari = H.Setup{ ola = { 5159, 68, 5018 }, kari = { 40 }, settle = "bond" }
        ola:Traits({ "latsabb", "glupsk" }, 5159) -- (likes naps and quests: nothing these tests watch)
        ola:Slash("adopter panda")
        w:Run(5)
        ola:OpenJournal()
        eq(ola.ns.Registry:MyPet(), PANDA)
        eq(ola.ns.Pets:OutKey(), PANDA)
        return w, ola, kari, ola.ns.Wish
    end
    -- Today's wish made anew, as the one given (the day's pick is tested below, by For).
    local function Wishes(ola, id, zone)
        ola.ns.Wish.For = function() return id, zone end
        ola.ns.DB.char.wish = nil
        return ola.ns.Wish:Today()
    end
    local function Earned(ola) local e = ola.ns.Registry:Life(PANDA, "Ola Nord"); return e and e.p or 0 end

    test("a trip's zones: its families' homes and its traits', only those you can reach", function()
        local w, ola, kari, W = Setup()
        ola:Traits({ "latsabb", "glupsk" }, 68)
        ola.state.level, ola.state.faction = 10, "Alliance"
        eq(table.concat(W.Zones(OWL), ", "), "Darnassus, Teldrassil", "the owl's homes; Moonglade is too far for a 10")
        ola.state.faction = "Horde"
        eq(#W.Zones(OWL), 0, "never the other faction's land")
        ola.state.level = 50
        eq(table.concat(W.Zones(OWL), ", "), "Dalaran, Moonglade, Shen'dralas, Stonetalon Mountains, The Hinterlands",
            "Shen'dralas and Dalaran: Forever's own, the moon's and the mages'; an owl is a bird too (2026-11-22)")
        -- Vinterpels: the cold ones too (not Alterac Valley, a battleground).
        ola:Traits({ "vinterpels", "latsabb" }, 68)
        ola.state.level, ola.state.faction = 60, "Alliance"
        eq(table.concat(W.Zones(OWL), ", "), "Alterac Mountains, Dalaran, Darnassus, Dun Morogh, Ironforge, Moonglade, Shen'dralas, Stonetalon Mountains, Teldrassil, The Hinterlands, Winterspring")
        -- The panda's (a bear: Loch Modan 10, Ashenvale 18, Feralas 40) at 9: none; at 10, Loch Modan.
        ola.state.level = 9
        eq(#W.Zones(PANDA), 0)
        ola.state.level = 10
        eq(table.concat(W.Zones(PANDA), ", "), "Loch Modan")
    end)

    test("every choice gets its days: each of four extra wishes, each of four likes (2026-11-22: Adler32's never)", function()
        local w, ola, kari, W = Setup()
        local function Days(fn)
            local n = {}
            for d = 0, 364 do
                local id = fn(os.date("%Y%m%d", os.time({ year = 2026, month = 1, day = 1 + d, hour = 12 })))
                if id then n[id] = (n[id] or 0) + 1 end
            end
            return n
        end
        -- Flokkdyr with company lately, at 10: three kinds of company and a trip (Loch Modan), four choices.
        ola:Traits({ "flokkdyr", "latsabb" }, 5159)
        ola.ns.DB.char.company = ola.ns.Now()
        local extra = Days(function(day) return (W:Extra(PANDA, day)) end)
        for _, id in ipairs({ "guildgroup", "playmate", "guildpet", "zone" }) do
            ok((extra[id] or 0) >= 10, ("a wish by nature, %s: %d days of 365"):format(id, extra[id] or 0))
        end
        ola.ns.DB.char.company = nil
        ola.ns.Personality.Of = function() return {}, { "herb", "fish", "quest", "skin" } end
        local likes = Days(function(day) return (W:For(PANDA, day)) end)
        for _, id in ipairs({ "herb", "fish", "quest", "skin" }) do
            ok((likes[id] or 0) >= 40, ("a like, %s: %d days of 365"):format(id, likes[id] or 0))
        end
    end)

    test("company from the guild: for a social trait or family, never a loner", function()
        local w, ola, kari, W = Setup()
        ola:Traits({ "flokkdyr", "latsabb" }, 5159)
        eq(#W.Social(PANDA), 0, "no guildmate with you lately: none (2026-11-14, the user)")
        -- A group with Kari, a guildmate: company for COMPANY_DAYS, after the group too.
        w:SetGroup({ "Ola Nord", "Kari Berg" }); ola:Fire("GROUP_ROSTER_UPDATE"); w:Run(1)
        w:SetGroup(nil); ola:Fire("GROUP_ROSTER_UPDATE")
        ok(ola.ns.DB.char.company, "the group counted as company")
        eq(table.concat(W.Social(PANDA), " "), "guildgroup playmate guildpet", "a social trait: all three")
        w:Skip(W.COMPANY_DAYS * 86400 + 60)
        eq(#W.Social(PANDA), 0, "days ago: none again")
        ola.ns.DB.char.company = ola.ns.Now()
        ola:Traits({ "latsabb", "glupsk" }, 5159)
        eq(#W.Social(PANDA), 0, "neither social nor a social family")
        ola:Traits({ "latsabb", "glupsk" }, 5018)
        eq(table.concat(W.Social(WOLF), " "), "guildgroup", "a wolf: its pack")
        ola:Traits({ "einstoing", "latsabb" }, 5018)
        eq(#W.Social(WOLF), 0, "a loner never, whatever its family")
    end)

    test("a wish by nature comes one day in EXTRA_EVERY or so, the same all day, and only if one fits", function()
        local w, ola, kari, W = Setup()
        ola:Traits({ "flokkdyr", "latsabb" }, 5159)
        local extra, n = { guildgroup = true, playmate = true, guildpet = true }, 0
        -- No guildmate with you lately: no company wishes at all (a solo player's streak broke on them).
        for d = 0, 199 do
            local day = os.date("%Y%m%d", os.time({ year = 2026, month = 1, day = 1 + d, hour = 12 }))
            no(extra[W:For(PANDA, day)], "no company lately: " .. day)
        end
        ok(ola.ns.Activity:IsListening("GROUP_ROSTER_UPDATE"), "what brings company is heard")
        ola.ns.DB.char.company = ola.ns.Now() - (W.COMPANY_DAYS - 1) * 86400 -- (a guildmate two days ago)
        for d = 0, 199 do
            local day = os.date("%Y%m%d", os.time({ year = 2026, month = 1, day = 1 + d, hour = 12 }))
            local id = W:For(PANDA, day)
            if extra[id] and W:Extra(PANDA, day) == id then n = n + 1 end -- (not Flokkdyr's like, a wish of its own)
            eq(W:For(PANDA, day), id, "the same all day")
        end
        ok(n >= 25 and n <= 75, "about one day in four (less the campfire's): " .. n)
        ola:Traits({ "latsabb", "glupsk" }, 5159)
        ola.state.level = 9 -- (under the bear's first trip, Loch Modan at 10: likes only)
        for d = 1, 28 do
            local id = W:For(PANDA, ("202602%02d"):format(d))
            no(extra[id] or id == "zone", "nothing fits: its likes and the campfire only, " .. tostring(id))
        end
    end)

    test("a trip is never to where you are as it's made (it would come true by itself)", function()
        local w, ola, kari, W = Setup()
        ola:Traits({ "ordensdyr", "glupsk" }, 5159)
        ola.state.zone = "Ironforge"
        local zones = table.concat(W.Zones(PANDA), ",")
        ok(zones:find("Stormwind City", 1, true), zones)
        no(zones:find("Ironforge", 1, true), "where you stand")
    end)

    test("a trip: entering the zone with the pet out does it, and so does being there already", function()
        local w, ola, kari, W = Setup()
        local wish = Wishes(ola, "zone", "Durotar")
        eq(wish.zone, "Durotar"); no(wish.done)
        ok(W:Watching())
        local card = ola:SelectPet(5159)
        match(card.wish.text.text, "Durotar")
        -- Elsewhere: not yet.
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        no(W:Today().done)
        -- Without the pet: not its trip.
        ola:Summon(68)
        ola.state.zone = "Durotar"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        no(W:Today().done, "the owl went")
        ola.state.zone = "Elwynn Forest"
        ola:Summon(5159)
        local before = Earned(ola)
        ola.state.zone = "Durotar"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        ok(W:Today().done)
        ok(ola:PrintedLine("wish.granted", { pet = "Panda Cub", activity = "en tur til Durotar", n = 10 }))
        eq(Earned(ola) - before, 10)
        no(W:Watching(), "done: the zone isn't watched")
        -- Another day, already there as it's wished for.
        w:SkipDays(1)
        ok(Wishes(ola, "zone", "Durotar").done, "already there")
    end)

    test("company: a guildmate in your group, a playdate, a guildmate's pet; never a stranger", function()
        local w, ola, kari, W = Setup()
        Wishes(ola, "guildgroup")
        w:SetGroup({ "Ola Nord", "Per Uten" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        w:Run(3)
        no(W:Today().done, "a stranger")
        w:SetGroup({ "Ola Nord", "Per Uten", "Kari Berg" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        w:Run(3)
        ok(W:Today().done)
        ok(ola:PrintedLine("wish.granted.full", { pet = "Panda Cub", activity = "selskap fra guilden" }))
        -- Still together the next day: at once.
        w:SkipDays(1)
        ok(Wishes(ola, "guildgroup").done, "already together")
        w:SetGroup(nil)
        ola:Fire("GROUP_ROSTER_UPDATE")

        -- A playdate (past Playdate's ten minutes between announcements: the group above made one).
        w:SkipDays(1)
        w:Run(700)
        Wishes(ola, "playmate")
        kari:Summon(40)
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        w:Run(5)
        ok(W:Today().done)
        ok(ola:PrintedLine("wish.granted.full", { pet = "Panda Cub", activity = "en lekeavtale" }))
        w:SetGroup(nil)

        -- A guildmate's pet, met under the mouse; a stranger's isn't.
        w:SkipDays(1)
        Wishes(ola, "guildpet")
        ola:Hover{ species = 40, owner = "Per Uten" }
        w:Run(1)
        no(W:Today().done, "a stranger's pet")
        ola:Hover{ species = 40, owner = "Kari Berg" }
        w:Run(1)
        ok(W:Today().done)
        ok(ola:PrintedLine("wish.granted.full", { pet = "Panda Cub", activity = "dyrevenner fra guilden" }))
    end)

    test("the wish's activity is watched only while it's pending, and not after you let the pet go", function()
        local w, ola, kari, W = Setup()
        local A = ola.ns.Activity
        ola:Slash("debug off") -- (the debug log wants every activity)
        no(A:IsListening("MIRROR_TIMER_START"), "nobody here likes diving")
        Wishes(ola, "dive")
        ok(A:IsListening("MIRROR_TIMER_START"), "today's wish")
        ola:Slash("gislipp")
        w:Run(5)
        no(A:IsListening("MIRROR_TIMER_START"), "no adopted pet: no wish")
    end)

    test("every wish has words of its own: a like's, the campfire's, company, a trip", function()
        local w, ola = Setup()
        local ns = ola.ns
        for _, k in ipairs(ns.Activity.KINDS) do
            if k.wish ~= false and k.id ~= "day" then
                ok(#ns.Variants("wish.say." .. k.id) >= 2, k.id .. ": its own lines")
                ok(ns.Personality.NOUN[k.id], k.id .. ": a noun for the granted line")
            end
        end
        ok(#ns.Variants("wish.say.zone") >= 2)
        for _, key in ipairs(ns.Variants("wish.say.zone")) do match(ns.L[key], "{zone}") end
        for zone in pairs(ns.Wish.ZONES) do ok(type(ns.Wish.ZONES[zone][1]) == "number", zone) end
    end)

    test("Data/Zones.lua: each row's fields are ones we read, its families exist, a capital has its faction", function()
        local _, ola = H.Setup{ ola = {} }
        local ns = ola.ns
        local families = {}
        for _, f in ipairs(ns.Scenes.ORDER) do families[f] = true end
        local FIELDS = { level = "number", faction = "string", capital = "boolean", climate = "string", high = "boolean",
            neutral = "boolean", home = "table" }
        for name, r in pairs(ns.Zones.rows) do
            for k, v in pairs(r) do eq(type(v), FIELDS[k], name .. "." .. k) end
            if r.faction then ok(r.faction == "Alliance" or r.faction == "Horde", name) end
            if r.climate then ok(r.climate == "cold" or r.climate == "warm", name) end
            if r.capital then ok(r.faction, name .. ": a capital's faction") end
            for _, f in ipairs(r.home or {}) do ok(families[f], name .. ": no family " .. f) end
        end
        -- The views the modules read.
        eq(ns.Sense.CAPITALS["Orgrimmar"], "Horde"); ok(ns.Sense.NEUTRAL["Booty Bay"])
        ok(ns.Personality.COLD["Winterspring"]); ok(ns.Personality.CITIES["Undercity"])
        eq(ns.Wish.ZONES["Tanaris"][1], 40); eq(ns.Wish.ZONES["Gnomeregan"], nil, "an instance: never a trip")
        eq(table.concat(ns.Quirks.HOME_ZONES.pirate, ","), "Stranglethorn Vale,Tanaris,The Barrens")
    end)
    -- Review 2026-11-24 Q12: the wish showed only on the card and the pet frame (off by default).
    test("today's wish is said once, at the adopted pet's day's visit; not once it's done", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        local function Told() return ola:CountPrinted("Dagens ønske:") end
        w:SkipDays(1); ola:Reload(); w:Settle("day"); w:Run(ola.ns.Wish.TELL_AFTER + 20)
        eq(Told(), 1, "the day's first visit, a minute on")
        local w1 = ola.ns.Wish:Today()
        match(ola:Printed("Dagens ønske:", true), ola.ns.Wish.Line(w1), "its card line")
        ok(w1.told)
        ola:Reload(); w:Settle("day"); w:Run(ola.ns.Wish.TELL_AFTER + 20)
        eq(Told(), 1, "once a day, through a /reload")
        -- Done already when the day's visit comes: nothing to say.
        w:SkipDays(1)
        local w2 = ola.ns.Wish:Today()
        w2.done = true
        ola.ns.Activity:CheckDay(); w:Run(ola.ns.Wish.TELL_AFTER + 20)
        eq(Told(), 1, "done: quiet")
    end)
end
