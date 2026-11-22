-- The strings (Locale/nb.lua, ns.L / ns.T / ns.Fill in Core/Init.lua): every
-- key the code asks for exists, every key in the file is used, placeholders
-- are named, and a missing one shows instead of breaking anything.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    -- The addon's own Lua files (the TOC's, without the libraries and the locale).
    local function Sources()
        local files = {}
        for line in io.lines("Dyreparken.toc") do
            local f = line:match("^([%w_\\/]+%.lua)%s*$")
            if f and not f:find("^Libs") and not f:find("^Locale") then files[#files + 1] = (f:gsub("\\", "/")) end
        end
        return files
    end

    local function Read(path)
        local f = assert(io.open(path, "rb"))
        local s = f:read("*a")
        f:close()
        return s
    end

    -- Keys made from parts in the code ("trait." .. id .. ".name"): the
    -- prefixes, each checked against the runtime tables below.
    local DYNAMIC = { "time.", "home.", "bond.level.", "decor.level.", "effect.times.", "activity.",
        "holiday.", "trait.", "effect.activity.", "dislike.", "egg.", "voice.", "settings.", "feat.", "card.unlock.", "first.place.", "first.boss.",
        "source.", "park.filter.", "wish.say.", "react.", "unlisted.", "play." }

    test("ns.T fills named placeholders; a missing key or value shows, never breaks", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(5)
        local ns = c.ns
        eq(ns.T("bond.next", { n = 110, level = "God venn" }), "110 poeng til God venn")
        eq(ns.T("bond.next", { n = 5 }), "5 poeng til {level}", "a value not given stays visible")
        eq(ns.T("adopt.taken", { owner = "100% Kari" }), "Det bor allerede hos 100% Kari.", "a % in a value is fine")
        eq(ns.T("cmd.sound.on"), "Summonlyden er på.", "no vars: the text as it is")
        eq(ns.L["no.such.key"], "no.such.key")
        eq(#c:Log("missing string no.such.key"), 1, "and it's logged")
        eq(ns.Fill(nil, { a = 1 }), nil)
    end)

    test("every key the code asks for is in Locale/nb.lua, and every key there is used", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(5)
        local ns = c.ns
        local used = {}
        local code = {}
        for _, path in ipairs(Sources()) do
            local s = Read(path)
            code[#code + 1] = s
            for key in s:gmatch('L%["([%w_%.:]+)"%]') do used[key] = path end
            for key in s:gmatch('ns%.T%("([%w_%.:]+)"') do used[key] = path end
        end
        for key in pairs(used) do
            if key:sub(-1) == "." then used[key] = nil end -- a prefix: "home." .. kind
        end
        ok(next(used), "the scan finds keys")
        for key, path in pairs(used) do
            ok(ns.Strings[key] ~= nil, key .. " (" .. path .. ") is missing from Locale/nb.lua")
        end
        -- Keys built from parts: the tables that hold them are all filled.
        for _, t in ipairs(ns.Personality.TRAITS) do
            for _, field in ipairs({ "name", "desc" }) do
                ok(ns.Strings["trait." .. t.id .. "." .. field], t.id .. "." .. field)
            end
            if t.when then ok(ns.Strings["trait." .. t.id .. ".when"]); ok(ns.Strings["trait." .. t.id .. ".flavor"]) end
            if t.day then ok(ns.Strings["trait." .. t.id .. ".day"], t.id .. ".day") end
            if t.dayFlavor then ok(ns.Strings["trait." .. t.id .. ".dayflavor"], t.id .. ".dayflavor") end
        end
        for act, noun in pairs(ns.Personality.NOUN) do ok(ns.Strings["activity." .. act], act) end
        -- Quirks: a line for every dislike and egg, and none for one that doesn't exist.
        local P, dislikes = ns.Personality, {}
        for _, list in pairs(P.DISLIKE_BY_FAMILY) do for _, a in ipairs(list) do dislikes[a] = true end end
        for _, t in ipairs(P.TRAITS) do if t.dislike then dislikes[t.dislike] = true end end
        for _, by in pairs(P.WEATHER.dislikes) do
            for _, list in pairs(by) do for _, a in ipairs(list) do dislikes[a] = true end end
        end
        -- (the minor ones too: without lines one could never be found, 2026-11-12)
        for _, pin in pairs(ns.UnlockPins or {}) do if pin[2] then dislikes[pin[2]] = true end end
        for a in pairs(dislikes) do ok(ns.Strings["dislike." .. a .. ".1"], "dislike." .. a); ok(P.NOUN[a], a) end
        -- (2026-11-17: the familiars' lines, drafted for the user before their eggs exist; their step adds the
        -- rows to Quirks.EGGS and this goes)
        local eggs = { tryllet = true, poff = true, vikar = true }
        for _, e in ipairs(ns.Quirks.EGGS) do eggs[e.id] = true; ok(ns.Strings["egg." .. e.id .. ".1"], "egg." .. e.id) end
        for key in pairs(ns.Strings) do
            local kind, id, n = key:match("^(%a+)%.([%w_]+)%.(%d+)$")
            if kind == "dislike" then ok(dislikes[id], key .. ": nothing dislikes that") end
            if kind == "egg" then ok(eggs[id], key .. ": no such egg") end
            if (kind == "dislike" or kind == "egg") and n ~= "1" then
                ok(ns.Strings[("%s.%s.%d"):format(kind, id, n - 1)], key .. ": a gap before it")
            end
        end
        -- Playdates between families (Playdate.Line): two families of Scenes.ORDER, numbered from 1.
        local family = {}
        for _, f in ipairs(ns.Scenes.ORDER) do family[f] = true end
        for key in pairs(ns.Strings) do
            local a, b, n = key:match("^play%.(%a+)%.(%a+)%.(%d+)$")
            if a then
                ok(family[a] and family[b], key .. ": not two families")
                ok(n == "1" or ns.Strings[("play.%s.%s.%d"):format(a, b, n - 1)], key .. ": a gap before it")
            elseif key:find("^play%.") and not key:find("^play%.line%.%d+$") then
                ok(({ ["play.line"] = 1, ["play.inseparable"] = 1, ["play.best"] = 1 })[key], key .. ": not a playdate line")
            end
        end
        -- Every group of variants, whatever its kind, numbered without a gap (ns.Variants stops at one: a line past
        -- it is never said), and the player's own lines under a class or race the client has (a typo, .shamen.,
        -- would never be said either). Keys numbered by an id (holiday.0101, source.where.5159) have no .1.
        local CLASSES = { warrior = 1, paladin = 1, hunter = 1, rogue = 1, priest = 1, shaman = 1, mage = 1, warlock = 1, druid = 1 }
        local RACES = { human = 1, dwarf = 1, nightelf = 1, gnome = 1, orc = 1, scourge = 1, tauren = 1, troll = 1, skyborne = 1 }
        for key in pairs(ns.Strings) do
            local prefix, n = key:match("^(.+)%.(%d+)$")
            if prefix and ns.Strings[prefix .. ".1"] and tonumber(n) > 1 then
                ok(ns.Strings[("%s.%d"):format(prefix, n - 1)], key .. ": a gap before it")
            end
            local class = key:match("%.class%.([^.]+)%.%d+$")
            if class then ok(CLASSES[class], key .. ": no such class (the client's file name, lower case)") end
            local race = key:match("%.race%.([^.]+)%.%d+$")
            if race then ok(RACES[race], key .. ": no such race (the client's file name, lower case)") end
        end
        for day, name in pairs(ns.Personality.HOLIDAYS) do ok(ns.Strings["holiday." .. day], day) end
        for i = 1, #ns.Bond.LEVELS do ok(ns.Strings["bond.level." .. i]) end
        for n = 2, 7 do ok(ns.Strings["decor.level." .. n]) end
        for _, k in ipairs({ "today", "yesterday", "days", "months", "years" }) do ok(ns.Strings["time." .. k], k) end
        -- And nothing in the file goes unused (made from parts, or named in the code).
        local all = table.concat(code, "\n")
        for key in pairs(ns.Strings) do
            local dynamic = false
            for _, prefix in ipairs(DYNAMIC) do if key:sub(1, #prefix) == prefix then dynamic = true end end
            -- (a numbered variant of a line the code picks by its bare key: ns.PickLine reads them all; Bond.Line
            -- picks too, for the keys given to it: the wish's from Wish:Grant)
            local base = key:match("^(.+)%.%d+$")
            -- (a moment's variant: ns.Lines mixes prefix.<moment> in, 2026-11-22: .remember, .spring, .cold...)
            for _, m in ipairs({ "morning", "evening", "night", "winter", "spring", "summer", "autumn", "cold", "warm", "remember" }) do
                if base and base:sub(-#m - 1) == "." .. m then base = base:sub(1, -#m - 2) end
            end
            local variant = base and (all:find('ns.PickLine("' .. base .. '"', 1, true)
                or ({ ["wish.granted"] = 1, ["wish.granted.full"] = 1 })[base])
            ok(dynamic or variant or used[key] or all:find('"' .. key .. '"', 1, true), key .. " is never used")
        end
    end)

    test("a line's texts: the bare key, its variants, and the player's class's and race's mixed in", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        c.state.class, c.state.race = "MAGE", "NightElf"
        w:Run(5)
        local ns, L = c.ns, c.ns.L
        L["t.line"] = "bare"; L["t.line.1"] = "one"; L["t.line.2"] = "two"
        L["t.line.class.mage.1"] = "mage"; L["t.line.class.warrior.1"] = "warrior"
        L["t.line.race.nightelf.1"] = "elf"; L["t.line.race.nightelf.3"] = "a gap: never"
        eq(table.concat(ns.Lines("t.line"), " "), "t.line t.line.1 t.line.2 t.line.class.mage.1 t.line.race.nightelf.1")
        local seen = {}
        for pick = 1, 5 do c:Dice(0, pick); seen[#seen + 1] = ns.PickLine("t.line") end
        eq(table.concat(seen, " "), "bare one two mage elf")
        eq(#ns.Lines("t.none"), 0); eq(ns.PickLine("t.none"), nil)
        -- Never the same variant twice in a row (2026-11-22): the same pick takes the next one instead.
        c:Dice(0, 1)
        eq(ns.PickLine("t.line"), "bare")
        eq(ns.PickLine("t.line"), "one", "the last one is left out")
        eq(ns.PickLine("t.line"), "bare", "and only the last")
        L["t.solo"] = "solo"
        eq(ns.PickLine("t.solo"), "solo"); eq(ns.PickLine("t.solo"), "solo", "a line with one text says it again")
        c:Reload()
        c:Dice(0, 1)
        ns = c.ns
        ns.L["t.line"] = "bare"; ns.L["t.line.1"] = "one"
        ns.DB.char.lastLines = { ["t.line"] = "t.line" }
        eq(ns.PickLine("t.line"), "one", "kept across a reload (char.lastLines)")
    end)

    test("a line's texts: the moment's (time of day, season, the zone's climate) and a pet's memory mixed in", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(5)
        local ns, L = c.ns, c.ns.L
        L["t.m.1"] = "plain"; L["t.m.night.1"] = "night"; L["t.m.evening.1"] = "evening"; L["t.m.morning.1"] = "morning"
        L["t.m.winter.1"] = "winter"; L["t.m.summer.1"] = "summer"; L["t.m.cold.1"] = "cold"; L["t.m.warm.1"] = "warm"
        L["t.m.remember.1"] = "{count} times"
        local function Lines(vars) return table.concat(ns.Lines("t.m", vars), " ") end
        w:SetDate(2027, 1, 10, 23)
        c:Set("zone", "Dun Morogh")
        eq(Lines(), "t.m.1 t.m.night.1 t.m.winter.1 t.m.cold.1", "a winter night in a cold zone")
        w:SetDate(2027, 7, 10, 12)
        c:Set("zone", "Durotar")
        eq(Lines(), "t.m.1 t.m.summer.1 t.m.warm.1", "a summer's day, warm: no part of the day for the day itself")
        w:SetDate(2027, 8, 10, 6)
        c:Set("zone", "Elwynn Forest")
        eq(Lines(), "t.m.1 t.m.morning.1 t.m.summer.1", "a summer morning in a zone with no climate")
        w:SetDate(2027, 10, 10, 18)
        eq(Lines(), "t.m.1 t.m.evening.1", "an autumn evening (Scenes.SKY's evening; no autumn lines)")
        eq(Lines({ count = ns.Config.LINES_REMEMBER - 1 }), "t.m.1 t.m.evening.1", "not yet a memory")
        eq(Lines({ count = ns.Config.LINES_REMEMBER }), "t.m.1 t.m.evening.1 t.m.remember.1", "a memory from LINES_REMEMBER on")
        c:Dice(0, 3)
        eq(ns.PickLine("t.m", { count = 12 }), "12 times")
    end)

    test("the new place's and the wish's lines have the class's and race's too", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 } })
        c.state.class = "MAGE"
        w:Run(5)
        local ns, L = c.ns, c.ns.L
        L["first.place.class.mage.1"] = "{pet} ser etter en portal i {place}."
        c:Dice(0.99, 99) -- (not the family's own; the last of the general ones: the class's)
        eq(ns.Bond:PlaceLine("s:5159", "Ratchet"), "Panda Cub ser etter en portal i Ratchet.")
        L["wish.say.zz.class.mage.1"] = "{pet} vil se deg trylle i dag"
        eq(ns.Wish.Line({ id = "zz", pet = "s:5159", day = "2026-11-17" }), "Panda Cub vil se deg trylle i dag")
    end)

    test("placeholders are named: no printf codes left in the texts", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(5)
        local ns = c.ns
        local function Check(where, s)
            if type(s) ~= "string" then return end
            no(s:find("%%[sd]"), where .. ": " .. s)
        end
        for key, s in pairs(ns.Strings) do Check(key, s) end
        for id, t in pairs(ns.AchTexts) do
            for field, s in pairs(t) do
                if type(s) == "table" then for k, v in pairs(s) do Check(id .. "." .. k, v) end else Check(id .. "." .. field, s) end
            end
        end
    end)
end
