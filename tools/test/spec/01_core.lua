-- Core: identity, helpers, bus, events, debug log, saved data.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    test("player key is First Surname and realms are dropped", function()
        local w = H.World()
        local ns = w:AddClient("Tester Surname").ns
        eq(ns.PlayerKey(), "Tester Surname")
        eq(ns.NormalizeName("Tester Surname-CAMWOWEU4Realm1PvE"), "Tester Surname", "own realm")
        eq(ns.NormalizeName("Ola Nord-CAMWOWEU4Realm2PvE"), "Ola Nord", "connected realm")
        eq(ns.NormalizeName("Ola Nord-CAMWOWEU9Realm7PvP"), "Ola Nord", "unknown realm by its shape")
        eq(ns.NormalizeName("Kari Berg-Hansen"), "Kari Berg-Hansen", "hyphenated surname stays")
        eq(ns.NormalizeName("Kari Berg-Hansen Li"), "Kari Berg-Hansen Li", "suffix with a space is no realm")
        eq(ns.NormalizeName(""), nil)
        eq(ns.NormalizeName(nil), nil)
    end)

    test("a character without a surname is keyed by first name", function()
        local w = H.World()
        eq(w:AddClient("Solo").ns.PlayerKey(), "Solo")
    end)

    test("without a realm name, any suffix with a digit counts as a realm", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { patch = function(env)
            env.GetNormalizedRealmName = function() return nil end
        end })
        eq(c.ns.NormalizeName("Ola Nord-Realm1"), "Ola Nord")
        eq(c.ns.NormalizeName("Kari Berg-Hansen"), "Kari Berg-Hansen")
    end)

    test("how long a companion has been cared for", function()
        local w = H.World()
        local ns = w:AddClient("Ola Nord").ns
        local now = w:ServerTime()
        local today = now - (now % 86400) + 43200 -- noon, so +-6 h stays on the same date
        eq(ns.CaredFor(today - 3600, today), "siden i dag")
        eq(ns.CaredFor(today + 60, today), "siden i dag", "a clock a little ahead")
        eq(ns.CaredFor(today - 86400, today), "siden i går")
        eq(ns.CaredFor(today - 2 * 86400, today), "i 2 dager")
        eq(ns.CaredFor(today - 59 * 86400, today), "i 59 dager")
        -- As a whole phrase: moved in today or yesterday, else living there for a while.
        eq(ns.Home("deg", today - 3600, today), "Flyttet inn hos deg i dag")
        eq(ns.Home("Kari Berg", today - 86400, today), "Flyttet inn hos Kari Berg i går")
        eq(ns.Home("deg", today - 3 * 86400, today), "Har bodd hos deg i 3 dager")
        eq(ns.CaredFor(today - 60 * 86400, today), "i 2 måneder")
        eq(ns.CaredFor(today - 729 * 86400, today), "i 24 måneder")
        eq(ns.CaredFor(today - 200 * 86400, today), "i 7 måneder")
        eq(ns.CaredFor(today - 800 * 86400, today), "i 2 år")
        ok(ns.CaredFor(now - 3600):find("^siden"), "defaults to now")
    end)

    test("'siden i går' goes by the calendar across a 23-hour day (DST)", function()
        local ffi = require("ffi")
        pcall(ffi.cdef, "int setenv(const char*, const char*, int); int unsetenv(const char*); void tzset(void);")
        local old = os.getenv("TZ")
        ffi.C.setenv("TZ", "Europe/Oslo", 1); ffi.C.tzset()
        local ok2, err = pcall(function()
            local w = H.World()
            local ns = w:AddClient("Ola Nord").ns
            -- Summer time starts Sunday 29 March 2026 at 02:00.
            local now = os.time({ year = 2026, month = 3, day = 30, hour = 0, min = 30 })
            eq(ns.CaredFor(os.time({ year = 2026, month = 3, day = 29, hour = 22 }), now), "siden i går")
            eq(ns.CaredFor(os.time({ year = 2026, month = 3, day = 28, hour = 22 }), now), "i 2 dager")
        end)
        if old then ffi.C.setenv("TZ", old, 1) else ffi.C.unsetenv("TZ") end
        ffi.C.tzset()
        if not ok2 then error(err, 0) end
    end)

    test("versions compare like releases", function()
        local w = H.World()
        local cmp = w:AddClient("Ola Nord").ns.CompareVersions
        eq(cmp("0.0.10", "0.0.9"), 1)
        eq(cmp("0.0.9", "0.0.10"), -1)
        eq(cmp("v0.1.0", "0.1.0"), 0)
        eq(cmp("v0.1", "v0.1.0"), 0, "missing parts are zero")
        eq(cmp("v0.1.0", "v0.1.0-beta2"), 1, "release beats pre-release")
        eq(cmp("v0.1.0-beta1", "v0.1.0"), -1)
        eq(cmp("v0.1.0-beta2", "v0.1.0-beta1"), 1)
        eq(cmp("v0.1.0-beta1", "v0.0.9"), 1)
        -- The label first, then its number: alpha < beta < release (review 2026-11-11).
        eq(cmp("0.2.0-alpha3", "0.2.0-beta1"), -1)
        eq(cmp("0.2.0-beta1", "0.2.0-alpha3"), 1)
        eq(cmp("0.2.0-alpha1", "0.2.0-beta1"), -1)
        eq(cmp("0.2.0-alpha2", "0.2.0-alpha10"), -1)
        eq(cmp("0.2.0-beta1", "0.2.0"), -1)
        eq(cmp("0.2.0-alpha9", "0.1.9"), 1)
        eq(cmp("dev", "v9.9.9"), 0, "dev equals everything")
        eq(cmp(nil, "v1.0.0"), 0, "garbage equals everything")
    end)

    test("a git checkout is a dev build, a packaged one has its tag", function()
        local w = H.World()
        local dev = w:AddClient("Ola Nord")
        ok(dev.ns.DEV)
        eq(dev.ns.VERSION, "dev")
        local rel = w:AddClient("Kari Berg", { version = "v0.1.0" })
        no(rel.ns.DEV)
        eq(rel.ns.VERSION, "v0.1.0")
        eq(rel.ns.PROTOCOL, tonumber(H.TOC.meta["X-Protocol"]))
        local bare = w:AddClient("Per Hansen", { version = "", protocol = "x" })
        ok(bare.ns.DEV, "empty version is dev")
        eq(bare.ns.PROTOCOL, 1, "unreadable protocol falls back to 1")
    end)

    test("Utf8Len counts characters, not bytes", function()
        local w = H.World()
        local ns = w:AddClient("Ola Nord").ns
        eq(ns.Utf8Len("abc"), 3)
        eq(ns.Utf8Len("æøå"), 3)
        eq(ns.Utf8Len(""), 0)
    end)

    test("a failing bus listener doesn't stop the others", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local got = 0
        c.ns.Bus.EVENTS.T, c.ns.Bus.EVENTS.NOBODY = "a: a test's", "(none): nobody listens"
        c.ns.Bus:On("T", function() error("boom") end)
        c.ns.Bus:On("T", function(a) got = a end)
        c.ns.Bus:Fire("T", 7)
        c.ns.Bus:Fire("NOBODY")
        eq(got, 7)
        local errs = c:TakeErrors()
        eq(#errs, 1)
        match(errs[1], "boom")
    end)

    test("bus events are declared: an undeclared one fails the test (the harness checks, the addon doesn't)", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        c.ns.Bus:On("BOND_LEVLE", function() end)
        c.ns.Bus:Fire("REGISTRYY")
        local errs = c:TakeErrors()
        eq(#errs, 2)
        match(errs[1], "Bus:On%(BOND_LEVLE%): not declared")
        match(errs[2], "Bus:Fire%(REGISTRYY%): not declared")
    end)

    test("bus events: each declared one is fired in the code, and each one listened to is declared", function()
        local fired, heard = {}, {}
        for _, path in ipairs(H.TOC.files) do
            if not path:find("^Libs/") then
                local f = assert(io.open(path, "rb"))
                local src = f:read("*a")
                f:close()
                for e in src:gmatch('Bus:Fire%("([%u_]+)"') do fired[e] = true end
                for e in src:gmatch('Bus:On%("([%u_]+)"') do heard[e] = true end
            end
        end
        local w = H.World()
        local events = w:AddClient("Ola Nord").ns.Bus.EVENTS
        local stale, unheard = {}, {}
        for e in pairs(events) do if not fired[e] then stale[#stale + 1] = e end end
        for e in pairs(heard) do if not fired[e] then unheard[#unheard + 1] = e end end
        eq(table.concat(stale, " "), "", "declared but never fired")
        eq(table.concat(unheard, " "), "", "listened to but never fired")
        for e in pairs(fired) do ok(events[e], e .. " is declared") end
    end)

    test("events: unknown events are refused, the frame only listens while needed", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local E = c.ns.Events
        local owner1, owner2, hits = {}, {}, 0
        no(E:On("BOGUS_EVENT", owner1, function() end), "unknown event")
        eq(#c:Log("unknown event BOGUS_EVENT"), 1)
        ok(E:On("UNIT_AURA", owner1, function() hits = hits + 1 end))
        ok(E:On("UNIT_AURA", owner2, function() error("listener failed") end))
        c:Fire("UNIT_AURA", "player")
        eq(hits, 1)
        eq(#c:TakeErrors(), 1)
        E:Off("UNIT_AURA", owner1)
        E:Off("UNIT_AURA", owner2)
        E:Off("UNIT_AURA", owner2) -- twice is fine
        E:Off("NEVER_REGISTERED", owner1)
        local frame
        for _, f in ipairs(c.frames) do if f.scripts.OnEvent and f.events.PLAYER_LOGIN ~= nil or f.events.CHAT_MSG_ADDON then frame = f end end
        no(frame.events.UNIT_AURA, "unregistered when nobody listens")
        c:Fire("UNIT_AURA", "player")
        eq(hits, 1)
    end)

    test("events: listeners changing during an event; no garbage per event", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local E = c.ns.Events
        local a, b, d, ran = {}, {}, {}, {}
        local function D() ran[#ran + 1] = "d" end
        E:On("UNIT_AURA", a, function()
            ran[#ran + 1] = "a"
            E:Off("UNIT_AURA", b) -- (removed before its turn: it doesn't run)
            E:On("UNIT_AURA", d, D) -- (added: from the next event on)
        end)
        E:On("UNIT_AURA", b, function() ran[#ran + 1] = "b" end)
        c:Fire("UNIT_AURA", "player")
        ok(ran[1] == "a" or ran[1] == "b")
        local first = table.concat(ran, ",")
        ok(first == "a" or first == "b,a", "b ran only if before a: " .. first)
        ran = {}
        c:Fire("UNIT_AURA", "player")
        table.sort(ran)
        eq(table.concat(ran, ","), "a,d")
        E:Off("UNIT_AURA", a); E:Off("UNIT_AURA", d)
        -- An event that keeps coming makes no garbage of its own. (Not measurable under --coverage:
        -- its line hook allocates.)
        if debug.gethook() then return E:Off("UNIT_AURA", a) end
        E:On("UNIT_AURA", a, function() end)
        c:Fire("UNIT_AURA", "player")
        collectgarbage("stop")
        local before = collectgarbage("count")
        for _ = 1, 1000 do c:Fire("UNIT_AURA", "player") end
        local grew = collectgarbage("count") - before
        collectgarbage("restart")
        ok(grew < 40, ("%.1f KB for 1000 events"):format(grew))
        E:Off("UNIT_AURA", a)
    end)

    test("a release forgets a debug log left from a git checkout or an old version", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { version = "v0.3.0", login = false })
        c.saved.DyreparkenDebugDB = { enabled = true, echo = true, lines = { head = 2, "a", "b" },
            api = { globals = {} }, animLengths = { [1] = {} } }
        c:Login()
        local db = c.env.DyreparkenDebugDB
        no(c.ns.Debug.enabled)
        eq(db.lines.head, 0); eq(db.lines[1], nil)
        eq(db.api, nil); eq(db.animLengths, nil)
    end)

    test("OutOfCombat runs now, or right after combat", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local E, ran = c.ns.Events, {}
        E:OutOfCombat(function() ran[#ran + 1] = "now" end)
        eq(ran[1], "now")
        c:EnterCombat()
        E:OutOfCombat(function() ran[#ran + 1] = "a" end)
        E:OutOfCombat(function() error("queued failed") end)
        E:OutOfCombat(function() ran[#ran + 1] = "b" end)
        eq(#ran, 1, "waits for combat to end")
        c:LeaveCombat()
        eq(table.concat(ran, ","), "now,a,b")
        eq(#c:TakeErrors(), 1)
        c:EnterCombat(); c:LeaveCombat()
        eq(#ran, 3, "queue ran once")
    end)

    test("debug log: ring buffer, echo, clear, and silence when off", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local D, ns = c.ns.Debug, c.ns
        ok(D.enabled)
        ns.Config.DEBUG_RING_SIZE = 5
        for i = 1, 12 do ns.Log("Test", "line %d", i) end
        local log = c:Log()
        eq(#log, 5, "ring keeps the newest")
        match(log[5], "\tTest\tline 12$")
        match(log[1], "line 8$")
        ns.Log("Test", "%d bad format", "x")
        match(c:Log()[5], "%%d bad format", "falls back to the format string")
        c:Slash("debug echo")
        ok(D.echo)
        ns.Log("Test", "echoed")
        ok(c:Printed("[Test] echoed", true))
        c:Slash("debug clear")
        ok(c:Printed("Debug log cleared"))
        eq(#c:Log(), 0)
        c:Slash("debug off")
        no(D.enabled)
        ok(c:Printed("Debug off"))
        ns.Log("Test", "silent")
        eq(#c:Log(), 0)
        c:Slash("debug")
        ok(D.enabled, "bare debug toggles")
        c:Slash("debug on")
        ok(c:Printed("Debug on %(echo to chat%)"))
    end)

    test("schema 6: nicknames move from the record to the pet", function()
        local T0 = 1790000000 -- (after the bond epoch: migration 10 keeps them)
        local w = H.World()
        local c = w:AddClient("Ola Nord", { login = false })
        c.saved.DyreparkenDB = { schema = 5, guilds = { Dyreparken = { claims = {
            ["Ola Nord"] = { k = "s:46", at = T0 + 10, ts = T0 + 20, n = "Pus", na = T0 + 15 },
            ["Kari Berg"] = { k = "s:40", at = T0 + 10, ts = T0 + 30, n = "Mjau" },
            ["Per Hansen"] = { at = T0 + 10, ts = T0 + 40 },
        }, lapses = {}, ach = {}, achSeen = {} }, Tom = {} } }
        c:Login()
        local g = c.env.DyreparkenDB.guilds.Dyreparken
        eq(g.names["s:46"]["Ola Nord"].n, "Pus")
        eq(g.names["s:46"]["Ola Nord"].at, T0 + 15)
        eq(g.names["s:40"]["Kari Berg"].at, T0 + 30, "no name time: the record's")
        eq(g.claims["Ola Nord"].n, nil)
        eq(g.claims["Ola Nord"].na, nil)
        ok(c.env.DyreparkenDB.guilds.Tom.names)
        eq(c.ns.Registry:Nickname("s:46"), "Pus")
    end)

    test("saved data from schema 1 migrates; unknown schemas reset", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { login = false })
        c.saved.DyreparkenDB = { schema = 1, guilds = {
            ["Dyreparken-CAMWOWEU4Realm5PvE"] = { pets = {}, members = {} },
            ["Dyreparken-CAMWOWEU4Realm6PvE"] = { pets = { x = 1 } },
            ["Annet Laug"] = {},
        } }
        c:Login()
        local db = c.env.DyreparkenDB
        eq(db.schema, c.ns.DB.SCHEMA)
        ok(db.guilds.Dyreparken and db.guilds.Dyreparken.claims and db.guilds.Dyreparken.lapses)
        no(db.guilds.Dyreparken.pets, "old shape dropped")
        ok(db.guilds["Annet Laug"].claims)
        ok(db.guilds["Annet Laug"].ach and db.guilds["Annet Laug"].achSeen, "guild achievements (5)")
        ok(db.games.history and db.settings)
        eq(db.known, nil, "the known list is gone (4)")
        eq(c.env.DyreparkenCharDB.autoSummon, true)
        eq(#c:Log("account migrated to 9"), 1)

        local d = w:AddClient("Kari Berg", { login = false })
        d.saved.DyreparkenDB = { schema = 0, junk = true }
        d:Login()
        eq(d.env.DyreparkenDB.schema, 0, "a schema with no step stays where it is")
        eq(d.env.DyreparkenDB.junk, true, "and its data is kept, never wiped")
        eq(#d:Log("no migration 0%->1, kept as it is"), 1)
    end)

    test("every schema has its migration step, with no gaps", function()
        local w, c = H.Setup{ ola = {}, settle = "hello" }
        local DB = c.ns.DB
        for n = 2, DB.SCHEMA do ok(type(DB.MIGRATIONS[n]) == "function", "account migration " .. n) end
        for n = 2, DB.CHAR_SCHEMA do ok(type(DB.CHAR_MIGRATIONS[n]) == "function", "char migration " .. n) end
        for n in pairs(DB.MIGRATIONS) do ok(n >= 2 and n <= DB.SCHEMA, "no step past SCHEMA: " .. n) end
        for n in pairs(DB.CHAR_MIGRATIONS) do ok(n >= 2 and n <= DB.CHAR_SCHEMA, "no char step past CHAR_SCHEMA: " .. n) end
    end)

    test("reservations and settings survive a reload", function()
        local w, c = H.Setup{ ola = {}, settle = "hello" }
        c:Slash("adopter")
        c.ns.Summon:SetEnabled(false)
        c:Reload()
        eq(c.ns.Registry:MyPet(), "s:5159")
        eq(c.env.DyreparkenCharDB.autoSummon, false)
        ok(c.ns.Debug.enabled, "debug setting persists")
    end)

    test("the addon defines no stray globals and reads no unexpected ones", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(15)
        c:Slash("adopter")
        c:OpenJournal({ extra = { 46 } })
        c:SelectPet(5159)
        c:Hover({ species = 5159, owner = "Ola Nord" })
        c:Slash("liste")
        w:Run(5)
        -- (Every test is checked for these after it runs: H.Invariants. Here, a broad tour.)
        local allowed, optional = H.ALLOWED_GLOBALS, H.OPTIONAL_GLOBALS
        for k in pairs(c.newGlobals) do ok(allowed[k], "unexpected global written: " .. tostring(k)) end
        for k in pairs(c.missingGlobals) do ok(optional[k], "read of a global the stubs lack: " .. tostring(k)) end
    end)

    test("start-up: each module declares its phase; phases run in order, modules in load order", function()
        -- Every module with an Init starts itself (Main.lua lists none).
        for line in io.lines("Dyreparken.toc") do
            local path = line:match("^([%w\\]+%.lua)$")
            if path and not path:find("^Libs") then
                local src = assert(io.open((path:gsub("\\", "/")), "rb")):read("*a")
                local obj = src:match("\nfunction (%w+):Init%(%)")
                if obj then
                    ok(src:find('ns%.Start%("%w+", function%(%) ' .. obj .. ':Init%(%) end%)'), path .. " starts itself")
                end
            end
        end
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 } })
        eq(#c:Log("^HELLO"), 0)
        no(pcall(c.ns.Start, "later", function() end), "an unknown phase fails loudly")
        w:Run(12)
        -- Settled before hello: the digest goes out after the login checks.
        local lines = c:Log("")
        local check, hello
        for i, l in ipairs(lines) do
            if not check and l:find("check %(login%)") then check = i end
            if not hello and l:find("%-> HELLO") then hello = i end
        end
        ok(check and hello and check < hello, "the login check, then HELLO")
    end)

    test("start-up: one module's error is reported and the rest of its phase still starts", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { pets = { 5159 } })
        local after
        c.ns.Start("settled", function() error("boom") end)
        c.ns.Start("settled", function() after = true end)
        w:Run(12)
        ok(after, "the next module started")
        local errs = c:TakeErrors()
        eq(#errs, 1)
        match(tostring(errs[1]), "boom")
        eq(#c:Log("%-> HELLO"), 1, "and the next phase ran too")
    end)

    test("a release has only the players' commands, in Norwegian; a git checkout has the developer ones", function()
        local w = H.World()
        local rel = w:AddClient("Ola Nord", { version = "v0.3.0", pets = { 5159 }, login = false })
        rel.saved.DyreparkenDebugDB = { enabled = true, lines = { head = 0 } } -- (left on from before)
        rel:Login()
        local dev = w:AddClient("Kari Berg", { pets = { 46 } })
        w:Run(15)
        no(rel.ns.Debug.enabled, "a log left on is turned off: nothing could turn it off now")
        rel:Slash("")
        local listed = 0
        for _, l in ipairs(rel.printed) do if l:find("  /dp ", 1, true) then listed = listed + 1 end end
        eq(listed, 8)
        for _, word in ipairs({ "probe", "debug on", "claim", "adopt", "nick Pepe", "list", "sound off", "ach",
            "version", "versjon", "report", "rapport", "pat" }) do
            rel:ClearPrinted()
            rel:Slash(word)
            ok(rel:Printed("kommandoer:", true), word .. ": the help instead")
        end
        no(rel.ns.Debug.enabled)
        eq(rel.ns.Registry:MyPet(), nil, "claim did nothing")
        rel:ClearPrinted()
        rel:Slash("prestasjoner ikoner")
        no(rel:Printed("|T", true), "no icon gallery")
        -- The git checkout: probe and debug are there.
        dev:Slash("")
        ok(dev:Printed("  /dp probe [", true)); ok(dev:Printed("  /dp debug [", true))
        dev:Slash("debug off")
        no(dev.ns.Debug.enabled)
    end)

    test("the harness reads the screen: shown text only, under shown parents (c:Visible, c:Labeled)", function()
        local w, ola = H.Setup{ settle = "hello" }
        local env = ola.env
        local f = env.CreateFrame("Frame", nil, env.UIParent)
        local fs = f:CreateFontString()
        fs:SetText("|cffff0000Hei|r på deg")
        local box = env.CreateFrame("CheckButton", nil, f)
        local label = f:CreateFontString()
        label:SetPoint("LEFT", box, "RIGHT", 4, 0)
        label:SetText("Boks")
        local button = env.CreateFrame("Button", nil, f)
        button:SetText("Trykk")
        local found, on = ola:Visible("Hei på")
        eq(found, fs, "color codes don't count"); eq(on, f)
        no(ola:Visible("Hei", nil, true), "exact: the whole text")
        eq(ola:Labeled("Boks"), box, "the box its label is anchored to")
        eq(ola:Labeled("Trykk"), button, "a button by its own text")
        fs:Hide()
        no(ola:Visible("Hei på"), "a hidden font string")
        fs:Show(); f:Hide()
        no(ola:Visible("Hei på"), "under a hidden frame"); no(ola:Labeled("Boks")); no(ola:Labeled("Trykk"))
        f:Show()
        no(ola:Visible("Hei på", env.CreateFrame("Frame")), "only under root")
        eq(#ola:Frames(function(x) return x == box end, f), 1)
    end)

    test("the stub client lacks what Forever lacks (H.MISSING, docs/FOREVER_API.md)", function()
        local w, ola = H.Setup{ settle = "hello" }
        local env = ola.env
        for _, k in ipairs(H.MISSING.globals) do eq(rawget(env, k), nil, k) end
        for _, f in ipairs(H.MISSING.fields) do eq(rawget(env, f[1])[f[2]], nil, f[1] .. "." .. f[2]) end
        for _, e in ipairs(H.MISSING.events) do
            no(env.C_EventUtils.IsEventValid(e), e)
            local ok2 = pcall(env.CreateFrame("Frame").RegisterEvent, env.CreateFrame("Frame"), e)
            no(ok2, e .. " can't be registered")
        end
    end)
end
