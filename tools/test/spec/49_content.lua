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

    -- Whole UTF-8 letters only: a byte cut off a two-byte letter shows as a box in game.
    local function UTF8(s)
        local i, n = 1, #s
        while i <= n do
            local c = s:byte(i)
            local len = c < 0x80 and 1 or (c >= 0xC2 and c <= 0xDF) and 2 or (c >= 0xE0 and c <= 0xEF) and 3
                or (c >= 0xF0 and c <= 0xF4) and 4 or nil
            if not len or i + len - 1 > n then return false end
            for j = i + 1, i + len - 1 do
                local b = s:byte(j); if b < 0x80 or b > 0xBF then return false end
            end
            i = i + len
        end
        return true
    end

    test("an activity's words with a capital first letter stay whole letters (2026-11-20: \"å sove\" showed a box)", function()
        local ns = World()
        local P = ns.Personality
        -- (LuaJIT's upper leaves a lone byte of an "å" alone; the game's changed it: as the game does, for this test)
        local upper = string.upper
        string.upper = function(t) return (upper(t):gsub("[\128-\255]", function(c) return #t == 1 and "?" or c end)) end
        local done, err = pcall(function()
        local n = 0
        for _, k in ipairs(ns.Activity.KINDS) do
            local noun = P.NOUN[k[1]]
            if noun then
                n = n + 1
                local cap = ns.Capital(noun)
                ok(UTF8(cap), k[1] .. ": " .. cap); ok(UTF8(P:Doing(k[1])), k[1] .. " (Doing)")
                eq(ns.LowerFirst(cap), noun:match("^[A-ZÆØÅ]") and ns.LowerFirst(noun) or noun, k[1])
            end
        end
        ok(n > 20)
        eq(ns.Capital("å sove i sovepose"), "Å sove i sovepose"); eq(ns.Capital("ærend"), "Ærend")
        eq(ns.LowerFirst("Øl Øl"), "øl Øl"); eq(ns.Capital(""), "")
        end)
        string.upper = upper
        if not done then error(err, 0) end
    end)

    test("sources: every kind in Data/Companions.lua has its word; a store or subscription pet says where", function()
        local ns = World()
        local missing = {}
        for sid, d in pairs(ns.Companions.species) do
            if d.s and not ns.Strings["source." .. d.s] then missing[#missing + 1] = sid .. " source." .. d.s end
            if d.s == "promo" and not (d.w or ns.Strings["source.where." .. sid]) then
                missing[#missing + 1] = sid .. " source.where." .. sid
            end
        end
        for key in pairs(ns.Strings) do
            local sid = key:match("^source%.where%.(%d+)$")
            if sid and not ns.Companions.species[tonumber(sid)] then missing[#missing + 1] = key .. " (no such species)" end
        end
        table.sort(missing)
        eq(table.concat(missing, ", "), "")
    end)

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

    test("lines: every group in tools/variants_rules.lua's ENFORCED has its minimum of texts", function()
        local ns = World()
        local V = dofile("tools/variants_rules.lua")
        local groups = {}
        for _, g in ipairs(V.Groups(ns)) do groups[g.key] = g end
        for _, key in ipairs(V.ENFORCED) do
            local g = groups[key]
            ok(g, key .. ": not a line group (tools/variants.lua --all lists them)")
            if g then ok(g.n >= g.min, ("%s: %d of %d texts (%s)"):format(key, g.n, g.min, g.why)) end
        end
    end)

    test("eggs and reactions: every nature in a row's apart is one of its own, with lines", function()
        local ns = World()
        local function Check(prefix, row)
            for _, x in ipairs(row.apart or {}) do
                local listed = false
                for _, v in ipairs(row.traits or {}) do listed = listed or v == x end
                for _, v in ipairs(row.families or {}) do listed = listed or v == x end
                for _, v in ipairs(row.first or {}) do listed = listed or v == x end
                ok(listed, prefix .. "." .. row.id .. ": apart " .. x .. " isn't in its traits or families")
                ok(ns.Strings[prefix .. "." .. row.id .. "." .. x .. ".1"], prefix .. "." .. row.id .. "." .. x .. ": no lines")
            end
        end
        for _, e in ipairs(ns.Quirks.EGGS) do Check("egg", e) end
        for _, r in ipairs(ns.Reactions.ROWS) do Check("react", r) end
    end)

    test("eggs and reactions: every trait or family they list is the one picked for some species", function()
        -- Moments.Nature takes the first the pet has, so one listed after another that every such pet also has
        -- is never said (review 2026-11-19: every owl is a bird, and bird came first; both reptiles are Dykker).
        -- (Ola owns every species: a personality is known only then, Personality:Known)
        local sids = {}
        for sid in pairs(World().Companions.species) do sids[#sids + 1] = sid end
        table.sort(sids)
        local _, ola = H.Setup{ ola = sids, settle = "hello" }
        local ns, keys = ola.ns, {}
        for _, sid in ipairs(sids) do keys[#keys + 1] = "s:" .. sid end
        local function Walk(prefix, row)
            local picked = {}
            for _, key in ipairs(keys) do
                local k = ns.Moments.Nature(prefix, row, key)
                if k then picked[k] = true end
            end
            for _, list in ipairs({ row.traits or {}, row.families or {} }) do
                for _, x in ipairs(list) do
                    local k = prefix .. "." .. row.id .. "." .. x
                    ok(not ns.Strings[k .. ".1"] or picked[k], k .. ": no species gets it (an earlier one in the lists wins)")
                end
            end
        end
        -- Only rows that pick by nature (a test of its own may name its lines: hakkebakke's playdates).
        local function ByNature(file)
            local src, rows = Sources()[file], {}
            local starts = {}
            for at, id in src:gmatch('(){ id = "([%w_]+)"') do starts[#starts + 1] = { at = at, id = id } end
            for i, r in ipairs(starts) do
                local block = src:sub(r.at, starts[i + 1] and starts[i + 1].at - 1 or #src)
                rows[r.id] = block:find("ByNature") ~= nil or not block:find("test = ")
            end
            return rows
        end
        local eggs, reacts = ByNature("Menagerie/Quirks.lua"), ByNature("Menagerie/Reactions.lua")
        for _, e in ipairs(ns.Quirks.EGGS) do if eggs[e.id] then Walk("egg", e) end end
        for _, r in ipairs(ns.Reactions.ROWS) do if reacts[r.id] then Walk("react", r) end end
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

    -- The card's badges (AboutPet.lua, 2026-11-19): every like and dislike any species can have, and every trait,
    -- has an icon of its own: a chip's game icon, else one of our textures, never the question mark or a plain dot.
    test("badges: every like, dislike and trait has an icon, and our textures exist", function()
        local ns = World()
        local P, A = ns.Personality, ns.AboutPet
        local function Ours(path)
            local name = path:match("Particles\\(.+)$")
            local f = name and io.open("Media/Particles/" .. name .. ".tga", "rb")
            if f then f:close() end
            return f ~= nil
        end
        local acts = {}
        for sid in pairs(ns.Companions.species) do
            local key = "s:" .. sid
            for _, a in ipairs(select(2, P:Of(key))) do acts[a] = sid end
            for _, a in ipairs(select(2, P:Dislikes(key, true))) do acts[a] = sid end
            local like = P:Minor(key)
            if like then acts[like] = sid end
        end
        local n = 0
        for a, sid in pairs(acts) do
            n = n + 1
            local path, ours = A.ActIcon(a)
            no(path:find("QuestionMark"), a .. " (" .. sid .. "): an icon")
            no(path:find("\\dot$"), a .. ": not a plain dot")
            if ours then ok(Ours(path), a .. ": " .. path .. " exists") end
        end
        ok(n > 20, "every activity a pet can have")
        for _, t in ipairs(P.TRAITS) do
            local path = A.TraitIcon(t)
            ok(Ours(path), t.id .. ": " .. path .. " exists")
            no(path:find("\\dot$") or path:find("\\sparkle$"), t.id .. ": a shape of its own, not " .. path)
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
