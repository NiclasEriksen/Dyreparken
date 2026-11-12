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
        "holiday.", "trait.", "effect.activity.", "dislike.", "egg.", "voice.", "settings.", "feat.", "card.unlock.", "first.place." }

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
        -- (the minor ones too: without lines one could never be found, 2026-11-12)
        for _, pin in pairs(ns.UnlockPins or {}) do if pin[2] then dislikes[pin[2]] = true end end
        for a in pairs(dislikes) do ok(ns.Strings["dislike." .. a .. ".1"], "dislike." .. a); ok(P.NOUN[a], a) end
        local eggs = {}
        for _, e in ipairs(ns.Quirks.EGGS) do eggs[e.id] = true; ok(ns.Strings["egg." .. e.id .. ".1"], "egg." .. e.id) end
        for key in pairs(ns.Strings) do
            local kind, id, n = key:match("^(%a+)%.([%w_]+)%.(%d+)$")
            if kind == "dislike" then ok(dislikes[id], key .. ": nothing dislikes that") end
            if kind == "egg" then ok(eggs[id], key .. ": no such egg") end
            if (kind == "dislike" or kind == "egg") and n ~= "1" then
                ok(ns.Strings[("%s.%s.%d"):format(kind, id, n - 1)], key .. ": a gap before it")
            end
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
            ok(dynamic or used[key] or all:find('"' .. key .. '"', 1, true), key .. " is never used")
        end
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
