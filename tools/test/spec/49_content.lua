-- The content as data (2026-11-12 refactor): traits, eggs, activities, families and their lines,
-- walked whole, so a new trait, egg or family is checked without a test of its own. Each test
-- names what it holds; a failure says what's missing where.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    local function World()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "hello" }
        return ola.ns
    end

    -- Every addon source file the TOC loads (Dev too), as text.
    local function Sources()
        local out = {}
        for _, path in ipairs(H.TOC.files) do
            if not path:find("^Libs/") then
                local f = assert(io.open(path, "rb"))
                out[path] = f:read("*a")
                f:close()
            end
        end
        return out
    end

    -- The {placeholders} of a line, as a sorted string.
    local function Holes(s)
        local list = {}
        for h in s:gmatch("{(%a+)}") do list[#list + 1] = h end
        table.sort(list)
        local seen, out = {}, {}
        for _, h in ipairs(list) do if not seen[h] then seen[h] = true; out[#out + 1] = h end end
        return table.concat(out, ",")
    end

    test("traits: words, tags, likes and opposites all exist", function()
        local ns = World()
        local P, S, KIND = ns.Personality, ns.Strings, ns.Activity.KIND
        for _, t in ipairs(P.TRAITS) do
            local k = "trait." .. t.id
            ok(S[k .. ".name"] and S[k .. ".desc"], t.id .. ": name and desc")
            if t.when then ok(S[k .. ".when"] and S[k .. ".flavor"], t.id .. ": when and flavor") end
            if t.day then
                ok(S[k .. ".day"], t.id .. ": day")
                ok(type(t.dayX) == "number" and t.dayX > 1, t.id .. ": dayX")
            end
            if t.like then ok(KIND[t.like], t.id .. ": like " .. t.like .. " is an activity") end
            if t.dislike then ok(KIND[t.dislike], t.id .. ": dislike " .. t.dislike .. " is an activity") end
            if t.against then
                local o = P.ById(t.against)
                ok(o and o.against == t.id, t.id .. ": against " .. t.against .. ", both ways")
            end
            for _, tag in ipairs(t.is or {}) do ok(P.TAGS[tag], t.id .. ": tag " .. tag) end
            ok(t.place == nil or type(t.place) == "number", t.id .. ": place")
            ok(ns.Decor.TRAITS[t.id], t.id .. ": its particles (Decor.TRAITS)")
        end
        for id in pairs(ns.Decor.TRAITS) do ok(P.ById(id), "Decor.TRAITS: no trait " .. id) end
    end)

    test("every trait id and tag named in the code exists", function()
        local ns = World()
        local P = ns.Personality
        local n = 0
        for path, src in pairs(Sources()) do
            for id in src:gmatch('[Pp]ersonality:Has%([^,()]+,%s*"([%w_]+)"%)') do
                ok(P.ById(id), path .. ": no trait " .. id); n = n + 1
            end
            for id in src:gmatch('HasTrait%([^,()]+,%s*"([%w_]+)"%)') do
                ok(P.ById(id), path .. ": no trait " .. id); n = n + 1
            end
            for tag in src:gmatch('Tagged%([^,()]+,%s*"([%w_]+)"%)') do
                ok(P.TAGS[tag], path .. ": no tag " .. tag); n = n + 1
            end
        end
        ok(n > 10, "found " .. n)
    end)

    test("eggs: each has its lines, and every line of a trait or a family is reachable", function()
        local ns = World()
        local Q, S, P = ns.Quirks, ns.Strings, ns.Personality
        local quirks = Sources()["Menagerie/Quirks.lua"]
        -- Lines a test names itself (_key = "egg...."), and prefixes it builds ("egg.hjemme." .. family).
        local literal, dynamic = {}, {}
        for k in quirks:gmatch('"(egg%.[%w_%.]+)"') do literal[k] = true end
        for k in quirks:gmatch('"(egg%.[%w_]+)%."%s*%.%.') do dynamic[k] = true end
        for k in pairs(literal) do
            if not k:find("%.%d+$") and not k:find("%.$") and not dynamic[k] then ok(S[k .. ".1"], "a line named in Quirks.lua has none: " .. k) end
        end
        local families = {}
        for _, f in ipairs(ns.Scenes.ORDER) do families[f] = true end
        for _, e in ipairs(Q.EGGS) do
            local any = S["egg." .. e.id .. ".1"]
            for k in pairs(S) do if k:find("^egg%." .. e.id .. "%.") then any = true end end
            ok(any, e.id .. ": has lines")
            for _, t in ipairs(e.traits or {}) do ok(S["egg." .. e.id .. "." .. t .. ".1"], e.id .. ": a line for " .. t) end
            for _, f in ipairs(e.families or {}) do
                ok(families[f], e.id .. ": family " .. f .. " is in Scenes.ORDER")
                ok(S["egg." .. e.id .. "." .. f .. ".1"], e.id .. ": a line for " .. f)
            end
        end
        -- The other way: a line for a trait or family that no list or test reaches would never be said.
        for k in pairs(S) do
            local id, x = k:match("^egg%.([%w_]+)%.([%w_]+)%.1$")
            if id and Q.EggById(id) and (P.ById(x) or families[x]) then
                local e, listed = Q.EggById(id), false
                for _, v in ipairs(e.traits or {}) do listed = listed or v == x end
                for _, v in ipairs(e.families or {}) do listed = listed or v == x end
                ok(listed or literal["egg." .. id .. "." .. x] or dynamic["egg." .. id],
                    k .. ": never said (add " .. x .. " to the egg's traits or families)")
            end
        end
    end)

    test("eggs: Quirks.WATCH is every activity the eggs need that the bond doesn't always watch", function()
        local ns = World()
        local Q, KIND = ns.Quirks, ns.Activity.KIND
        local watch = {}
        for _, id in ipairs(Q.WATCH) do watch[id] = true end
        for _, e in ipairs(Q.EGGS) do
            local k = KIND[e.on]
            if k and not k.always then
                eq(watch[e.on] or false, e.watch ~= false, e.id .. " on " .. e.on)
            end
        end
        no(watch.dance, "not every emote nearby")
        ok(watch.fall and watch.zeppelin and watch.level)
    end)

    test("every variant of a line takes the same placeholders as its first", function()
        local ns = World()
        local S = ns.Strings
        local n = 0
        for k, v in pairs(S) do
            local prefix, i = k:match("^(.+)%.(%d+)$")
            if prefix and i ~= "1" and S[prefix .. ".1"] then
                eq(Holes(v), Holes(S[prefix .. ".1"]), k .. " against " .. prefix .. ".1")
                n = n + 1
            end
        end
        ok(n > 50, "variants: " .. n)
    end)

    test("activities: each has its noun, and every dislike a pet can have has lines", function()
        local ns = World()
        local S, P = ns.Strings, ns.Personality
        for _, k in ipairs(ns.Activity.KINDS) do ok(S["activity." .. k.id], k.id .. ": activity." .. k.id) end
        local dislikes = {}
        for _, list in pairs(P.DISLIKE_BY_FAMILY) do for _, a in ipairs(list) do dislikes[a] = "a family's" end end
        for _, t in ipairs(P.TRAITS) do if t.dislike then dislikes[t.dislike] = t.id end end
        for sid, pin in pairs(ns.UnlockPins or {}) do if pin[2] then dislikes[pin[2]] = "minor of " .. sid end end
        for a, from in pairs(dislikes) do
            ok(ns.Activity.KIND[a], a .. " (" .. from .. ") is an activity")
            ok(S["dislike." .. a .. ".1"], a .. " (" .. from .. "): dislike." .. a .. ".1")
        end
        for sid, pin in pairs(ns.UnlockPins or {}) do
            if pin[1] then ok(ns.Activity.KIND[pin[1]], sid .. ": minor like " .. pin[1]) end
        end
    end)

    test("families: every one in Scenes.ORDER has its rows, and no table names one that isn't", function()
        local ns = World()
        local P, Sc, D, B, Q = ns.Personality, ns.Scenes, ns.Decor, ns.Bond, ns.Quirks
        local order = {}
        for _, f in ipairs(Sc.ORDER) do order[f] = true end
        -- Every family needs these (a new family: add a row to each).
        local NEED = {
            ["Personality.BY_FAMILY"] = P.BY_FAMILY, ["Personality.DISLIKE_BY_FAMILY"] = P.DISLIKE_BY_FAMILY,
            ["Scenes.TINT"] = Sc.TINT, ["Scenes.BY_FAMILY"] = Sc.BY_FAMILY, ["Decor.FAMILY"] = D.FAMILY,
            ["Bond.PLACE_CHANCE"] = B.PLACE_CHANCE,
        }
        -- These may leave a family out (art picked by hand, homes where there are some).
        local MAY = { ["Decor.FAMILY_ART"] = D.FAMILY_ART, ["Quirks.HOME_ZONES"] = Q.HOME_ZONES, ["Quirks.PREY"] = Q.PREY }
        for f, list in pairs(Q.PREY) do
            for _, p in ipairs(list) do ok(order[p], "Quirks.PREY " .. f .. ": " .. p .. " isn't a family") end
        end
        local SPARE = { default = true, DEFAULT = true } -- (the fallbacks' own rows)
        for name, t in pairs(NEED) do
            for f in pairs(order) do ok(t[f], name .. ": no row for " .. f) end
        end
        for _, set in ipairs({ NEED, MAY }) do
            for name, t in pairs(set) do
                for f in pairs(t) do ok(order[f] or SPARE[f], name .. ": " .. tostring(f) .. " isn't a family (Scenes.ORDER)") end
            end
        end
        for tag, f in pairs(Sc.ALIAS) do ok(order[f], "Scenes.ALIAS " .. tag .. " -> " .. f) end
    end)
end
