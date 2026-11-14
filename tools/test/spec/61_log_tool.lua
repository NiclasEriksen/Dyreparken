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
end
