-- tools/log.lua (2026-11-14): the debug log read outside the game, in order, split into sessions, filtered.
return function(test, H)
    local eq, ok = H.eq, H.ok

    local function Run(file, flags)
        local p = io.popen("luajit tools/log.lua -f " .. file .. " " .. flags .. " 2>&1")
        local out = {}
        for line in p:lines() do out[#out + 1] = line end
        p:close()
        return out
    end

    test("the ring in order from its head, split at each session's line, filtered by module and text", function()
        -- A ring of 4 that wrapped: head 2 is the newest, so 3, 4, 1, 2 is the order.
        local file = os.tmpname()
        local f = io.open(file, "w")
        f:write('DyreparkenDebugDB = { lines = { head = 2,\n',
            '"1790000300\\t1300.000\\tReactions\\tsaid krigsrop",\n',
            '"1790000400\\t1400.000\\tMoves\\tframe s:1: play 0 (x3)",\n',
            '"1790000100\\t1100.000\\tMoves\\tbefore",\n',
            '"1790000200\\t1200.000\\tSession\\tstart dev, Ola Nord WARRIOR",\n',
            '}, api = { glance = { n = 2 } } }\n')
        f:close()
        local all = Run(file, "-s all")
        eq(#all, 4)
        ok(all[1]:find("Moves      before", 1, true), all[1])
        ok(all[4]:find("+200.0  Moves      frame s:1: play 0 (x3)", 1, true), all[4])
        local last = Run(file, "")
        eq(#last, 3, "the newest session: from its Session line")
        eq(#Run(file, "-m Reactions"), 1)
        eq(#Run(file, "-x Moves,Session"), 1)
        eq(#Run(file, "-g krigsrop"), 1)
        local sessions = Run(file, "--sessions")
        eq(#sessions, 2)
        ok(sessions[1]:find("3 lines", 1, true) and sessions[1]:find("start dev, Ola Nord WARRIOR", 1, true), sessions[1])
        local summary = table.concat(Run(file, "--summary"), "\n")
        ok(summary:find("      3  Moves  frame s:N: play N", 1, true), summary)
        local dump = table.concat(Run(file, "--dump api.glance"), "\n")
        ok(dump:find("n = 2,", 1, true), dump)
        os.remove(file)
    end)

    test("the settled line joins its session's head; --at, --rate and --db", function()
        local file = os.tmpname()
        local f = io.open(file, "w")
        local function At(hms) -- (a time of the players' day, as the log holds it)
            local d = os.date("*t", 1790000000)
            d.hour, d.min, d.sec = hms:match("(%d+):(%d+):(%d+)")
            return os.time(d)
        end
        f:write('DyreparkenDebugDB = { lines = { head = 5,\n',
            ('"%d\\t1.000\\tSession\\tstart dev, Ola Nord WARRIOR",\n'):format(At("22:00:00")),
            ('"%d\\t2.000\\tDebug\\tenabled dev",\n'):format(At("22:00:00")),
            ('"%d\\t11.000\\tSession\\tsettled in Orgrimmar, guild G (5 members)",\n'):format(At("22:00:10")),
            ('"%d\\t481.000\\tChat\\tegg.midnatt.1: Pepe gjesper.",\n'):format(At("22:08:00")),
            ('"%d\\t601.000\\tMoves\\tframe s:1: jump (x9)",\n'):format(At("22:10:00")),
            '} }\nDyreparkenDB = { settings = { chatter = "few" } }\n')
        f:close()
        local sessions = Run(file, "--sessions")
        eq(#sessions, 1, "the settled line doesn't start a session")
        ok(sessions[1]:find("start dev, Ola Nord WARRIOR; settled in Orgrimmar", 1, true), sessions[1])
        local near = Run(file, "--at 22:08 -w 30")
        eq(#near, 1); ok(near[1]:find("egg.midnatt.1: Pepe gjesper.", 1, true), near[1])
        eq(#Run(file, "--at 22:09"), 2, "a minute either side by default")
        local rate = table.concat(Run(file, "--rate"), "\n")
        ok(rate:find("over 10 minutes", 1, true), rate)
        ok(rate:find("    0.90       9  Moves", 1, true), rate)
        ok(table.concat(Run(file, "--db settings"), "\n"):find('chatter = "few"', 1, true))
        os.remove(file)
    end)

    test("tools/lines.lua: what a pet can say, by its nature, class and race", function()
        local function Lines(flags)
            local p = io.popen("luajit tools/lines.lua " .. flags .. " 2>&1")
            local out = p:read("*a")
            p:close()
            return out
        end
        local out = Lines("egg.stup --traits kjaelen,latsabb")
        ok(out:find("Panda Cub (s:5159): traits kjaelen, latsabb; families bear", 1, true), out)
        ok(out:find("by its nature (egg.stup.latsabb)", 1, true), out)
        ok(out:find("60% of the time, else the plain ones below", 1, true) and out:find("egg.stup.1 ", 1, true),
            "mixed with the plain ones (Moments.NATURE_SHARE)")
        out = Lines("react.kattedyr --pet 70 --class druid")
        ok(not out:find("react.kattedyr.1 ", 1, true), "an apart nature: instead of the plain ones")
        out = Lines("react.totemer --class shaman --pet 70")
        ok(out:find("react.totemer.1 +Brown Prairie Dog snuser"), out)
        out = Lines("egg.luftskip --all")
        ok(out:find("-- trait skybaren:", 1, true) and out:find("-- the plain ones:", 1, true), out)
        ok(Lines("nope.x"):find("no text: nope.x", 1, true))
    end)

    test("tools/variants.lua: the line groups below their minimum, furthest first", function()
        local function Run(flags)
            local p = io.popen("luajit tools/variants.lua " .. flags .. " 2>&1")
            local out = p:read("*a")
            p:close()
            return out
        end
        local out = Run("-g activity.rested")
        ok(out:find("activity.rested.flavor +%d+ of 5") or out:find("0 groups below"), out)
        out = Run("--all -g egg.stup")
        ok(out:find("egg.stup +4 of 5  daily"), out)
        ok(out:find("egg.stup.kosete +2 of 2  nature"), out)
        ok(Run("--nope"):find("unknown option", 1, true))
    end)

    test("tools/chatter.lua: days of play in a harness client, the bond's pace and how often each line came", function()
        local p = io.popen("luajit tools/chatter.lua --days 3 --profile casual --seed 3 2>&1")
        local out = p:read("*a")
        p:close()
        ok(out:find("day   1  played", 1, true) and out:find("day   2        ", 1, true), out)
        ok(out:find("(2 of 3 days played, 1 h each), chatter normal, seed 3", 1, true), out)
        ok(out:find("Bond level reached (2250 points at 7): 2: ", 1, true), out)
        ok(out:find("\n +%d+ +%d+%%  activity%.herb%.flavor\n"), out)
    end)
end
