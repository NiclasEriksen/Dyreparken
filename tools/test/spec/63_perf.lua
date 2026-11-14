-- /dp probe perf (Dev/Perf.lua, 2026-11-14): calls and time per handler while it's on; nothing when off.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    test("handlers timed by event and module, Bus events and activity sources too; off: no hook at all", function()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "bond" }
        no(ola.ns.profile, "dormant")
        ola:Slash("probe perf")
        ok(ola:Printed("Perf on", true))
        ok(ola.ns.profile)
        for id = 1, 3 do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 99000 + id) end
        ola:Fire("CHAT_MSG_SYSTEM", "Ola Nord rolls 42 (1-100)")
        local rows = {}
        for _, r in ipairs(ola.ns.Perf:Top()) do rows[r.key] = r.n end
        eq(rows["UNIT_SPELLCAST_SUCCEEDED Activity"], 3, "by the module listening")
        eq(rows["Activity herb"], 3, "each source")
        ok(rows["Bus SENSE"], "the Bus")
        ok(rows["CHAT_MSG_SYSTEM Activity"])
        ola:Slash("probe perf off")
        no(ola.ns.profile)
        ok(ola:Printed("Perf: %d+ calls in %d+ s, %d+ rows %(stopped%)"))
        ok(#ola:Log("\tPerf\tUNIT_SPELLCAST_SUCCEEDED Activity +3 calls") == 1)
        -- With the client's own numbers.
        rawset(ola.env, "C_AddOnProfiler", { GetAddOnMetric = function(_, m) return m end }) -- (the client's, not ours)
        ola.env.Enum.AddOnProfilerMetric = { SessionAverageTime = 0.25, PeakTime = 12, RecentAverageTime = 0.5 }
        ola:Slash("probe perf show")
        ok(ola:Printed("the client's: session average 0.250 ms a frame, recent 0.500, peak 12.0", true))
    end)
end
