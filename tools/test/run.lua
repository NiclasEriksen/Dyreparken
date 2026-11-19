-- Test runner. Run from the addon folder (tools/check.sh does):
--   luajit tools/test/run.lua                  all specs
--   luajit tools/test/run.lua sync             only tests whose "spec: name" contains "sync"
--   luajit tools/test/run.lua --coverage       plus line coverage per addon file
--   luajit tools/test/run.lua --missed=Sync    print the uncovered lines of matching files
--   luajit tools/test/run.lua --min=Menagerie/=95 --min=Core/Comm=90
--                                              fail if a file under the prefix is below n%
--   -v                                         print each test name
--   --jobs=N                                   run in N processes (default: every core, one for -v or a
--                                              filter matching fewer than 20 tests); coverage merged from all
--   --slow[=N]                                 list the N slowest tests (default 15)
--   --shuffle[=seed]                           run in a random order (the tests must not depend on it)
-- A filter that matches no test, or an unknown option, fails the run (a typo used to pass with 0 tests).
-- Shards are dealt the tests longest first, by each test's last time (tools/test/.timings, untracked).
--
-- Specs live in tools/test/spec/*.lua and return function(test, H).
-- After each test the runner fails it if any client logged a Lua error,
-- a failed comm handler, or a tooltip error (see harness Client.errors), or broke
-- one of H.Invariants (a stray global, a printed line with an unfilled {placeholder}).
-- A test that provokes errors on purpose takes them with c:TakeErrors().
package.path = "tools/test/?.lua;" .. package.path

-- The players' clock (2026-11-12, the user): the clients' os.date/os.time are the host's, and
-- days, hours and holidays fall differently elsewhere (10 tests failed in Anchorage). The
-- runner sets TZ for itself and its shards.
if os.getenv("TZ") ~= "Europe/Oslo" then
    local q = {}
    for i, a in ipairs(arg) do q[i] = "'" .. a:gsub("'", "'\\''") .. "'" end
    local ok, how, code = os.execute("TZ=Europe/Oslo luajit tools/test/run.lua " .. table.concat(q, " "))
    -- luajit (5.1 semantics) returns the raw status; 5.2-style returns true/false, "exit", code.
    if type(ok) == "number" then os.exit(ok == 0 and 0 or 1) end
    os.exit((ok and code == 0) and 0 or 1)
end

local args = { filter = nil, coverage = false, missed = {}, min = {}, verbose = false }
for _, a in ipairs(arg) do
    local m = a:match("^%-%-missed=(.+)$")
    local mp, mv = a:match("^%-%-min=(.+)=(%d+)$")
    local jobs = a:match("^%-%-jobs=(%d+)$")
    local k, n = a:match("^%-%-shard=(%d+)/(%d+)$")
    local out = a:match("^%-%-hits%-out=(.+)$")
    local list = a:match("^%-%-tests=(.+)$")
    local slow = a == "--slow" and "15" or a:match("^%-%-slow=(%d+)$")
    local seed = a == "--shuffle" and tostring(os.time()) or a:match("^%-%-shuffle=(%d+)$")
    if jobs then
        args.jobs = tonumber(jobs)
    elseif k then
        args.shard, args.shards = tonumber(k), tonumber(n)
    elseif out then
        args.hitsOut = out
    elseif list then
        args.list = list
    elseif slow then
        args.slow = tonumber(slow)
    elseif seed then
        args.seed = tonumber(seed)
    elseif a == "--coverage" then
        args.coverage = true
    elseif m then
        args.coverage = true
        args.missed[#args.missed + 1] = m
    elseif mp then
        args.coverage = true
        args.min[#args.min + 1] = { prefix = mp, pct = tonumber(mv) }
    elseif a == "-v" then
        args.verbose = true
    elseif a:match("^%-") then
        io.stderr:write("run.lua: unknown option " .. a .. "\n")
        os.exit(2)
    elseif args.filter then
        io.stderr:write("run.lua: one filter at a time (" .. args.filter .. ", " .. a .. ")\n")
        os.exit(2)
    else
        args.filter = a
    end
end

-- A clock with sub-second wall time (os.time is whole seconds; os.clock is this process's CPU only).
local function Wall()
    local p = io.popen("date +%s.%N 2>/dev/null")
    local t = p and tonumber(p:read("*l") or "")
    if p then p:close() end
    return t or os.time()
end
local wall0 = Wall()

------------------------------------------------------------------------------
-- In parallel (2026-11-11, the user: "tests taking soooooo long"): the line hook makes a
-- coverage run ~9x slower, so the suite runs in N processes, each writing the lines it hit to a file.
-- This process deals them the tests (longest first, by .timings; by index until 2026-11-19, when the
-- shards took from 28 to 61 s), then only merges and reports.
------------------------------------------------------------------------------

------------------------------------------------------------------------------
-- Coverage: a line hook counts executed lines of addon files; the lines
-- that can execute at all come from LuaJIT's bytecode line info, so blank
-- lines, comments and bare `end`s don't count against us.
------------------------------------------------------------------------------
local hits = {} -- path -> { [line] = true }
if args.coverage and not parallel then
    require("jit").off()
    local getinfo = debug.getinfo
    debug.sethook(function(_, line)
        local src = getinfo(2, "S").source
        local h = hits[src]
        if not h then h = {}; hits[src] = h end
        h[line] = true
    end, "l")
end

local H = require("harness")

local function ExecutableLines(path)
    local ju = require("jit.util")
    local f = assert(io.open(path)):read("*a")
    local src = {}
    for line in (f .. "\n"):gmatch("(.-)\r?\n") do src[#src + 1] = line end
    local lines = {}
    local function walk(fn)
        local info = ju.funcinfo(fn)
        for pc = 1, info.bytecodes - 1 do
            local l = ju.funcinfo(fn, pc).currentline
            if l then lines[l] = true end
        end
        local k = -1
        while true do
            local c = ju.funck(fn, k)
            if c == nil then break end
            if type(c) == "proto" then walk(c) end
            k = k - 1
        end
    end
    walk(assert(loadstring(f, "@" .. path)))
    -- `end`, `else`, `}` lines only hold jumps/returns the hook reports
    -- unevenly; leave them out.
    for l in pairs(lines) do
        local s = src[l] or ""
        if s:match("^%s*end[%s%),;]*$") or s:match("^%s*else%s*$") or s:match("^%s*[%)}%]]+[%s,;]*$") then
            lines[l] = nil
        end
    end
    return lines, src
end

------------------------------------------------------------------------------
-- Collect and run tests
------------------------------------------------------------------------------
local tests = {}
local specFiles = {}
for name in io.popen('ls tools/test/spec/*.lua 2>/dev/null'):lines() do specFiles[#specFiles + 1] = name end
table.sort(specFiles)
for _, path in ipairs(specFiles) do
    local spec = path:match("([^/]+)%.lua$")
    local fn = assert(loadfile(path))()
    fn(function(name, body) tests[#tests + 1] = { name = spec .. ": " .. name, fn = body } end, H)
end

-- The tests this run is about: the filter's, or a shard's list from its parent.
local chosen = {}
if args.list then
    local want = {}
    for name in io.open(args.list):lines() do want[name] = true end
    for _, t in ipairs(tests) do if want[t.name] then chosen[#chosen + 1] = t end end
else
    for _, t in ipairs(tests) do
        if not args.filter or t.name:find(args.filter, 1, true) then chosen[#chosen + 1] = t end
    end
end
if #chosen == 0 then
    io.stderr:write(("run.lua: no test matches %q\n"):format(args.filter or ""))
    os.exit(1)
end
if args.seed and not args.shard then
    math.randomseed(args.seed)
    for i = #chosen, 2, -1 do
        local j = math.random(i)
        chosen[i], chosen[j] = chosen[j], chosen[i]
    end
    print(("(shuffled, seed %d)"):format(args.seed))
end

if not args.shard and not args.jobs then
    local cores = 1
    local p = io.popen("nproc 2>/dev/null")
    if p then cores = tonumber(p:read("*l") or "") or 1; p:close() end
    args.jobs = (args.verbose or #chosen < 20) and 1 or cores
end
local parallel = not args.shard and args.jobs > 1

-- Each test's last time, per mode (a coverage run is ~20x slower, and not evenly): what deals the shards.
local TIMINGS = "tools/test/.timings" .. (args.coverage and "-coverage" or "")
local function ReadTimings()
    local t = {}
    local f = io.open(TIMINGS)
    if f then
        for line in f:lines() do
            local secs, name = line:match("^([%d%.]+)\t(.+)$")
            if secs then t[name] = tonumber(secs) end
        end
        f:close()
    end
    return t
end

local passed, failed, times = 0, {}, {}
local t0 = os.clock()
if parallel then
    -- Longest first, each to the shard with the least so far (a test never timed counts as the mean).
    local known, sum, n = ReadTimings(), 0, 0
    for _, v in pairs(known) do sum, n = sum + v, n + 1 end
    local mean = n > 0 and sum / n or 1
    local order = {}
    for i, t in ipairs(chosen) do order[i] = { t = t, cost = known[t.name] or mean, i = i } end
    table.sort(order, function(a, b) if a.cost ~= b.cost then return a.cost > b.cost end return a.i < b.i end)
    local loads, lists = {}, {}
    for k = 1, args.jobs do loads[k], lists[k] = 0, {} end
    for _, o in ipairs(order) do
        local best = 1
        for k = 2, args.jobs do if loads[k] < loads[best] then best = k end end
        loads[best] = loads[best] + o.cost
        lists[best][#lists[best] + 1] = o.t.name
    end
    -- Each shard in its own process, all at once; their lists, output and hits in temp files.
    local cmds, files = {}, {}
    for k = 1, args.jobs do
        if #lists[k] > 0 then
            local outFile, hitFile, listFile = os.tmpname(), os.tmpname(), os.tmpname()
            local lf = assert(io.open(listFile, "w"))
            lf:write(table.concat(lists[k], "\n"), "\n")
            lf:close()
            files[#files + 1] = { out = outFile, hits = hitFile, list = listFile }
            cmds[#cmds + 1] = ("luajit tools/test/run.lua --shard=%d/%d --tests=%s %s %s > %s 2>&1 &"):format(k, args.jobs,
                listFile, args.coverage and ("--coverage --hits-out=" .. hitFile) or "", args.verbose and "-v" or "", outFile)
        end
    end
    os.execute("{ " .. table.concat(cmds, " ") .. " wait; }")
    for _, f in ipairs(files) do
        local text = io.open(f.out):read("*a")
        local p = text:match("(%d+) passed, (%d+) failed")
        if not p then
            failed[#failed + 1] = "a shard crashed"
            print(text)
        else
            passed = passed + tonumber(p)
            for name in text:gmatch("  FAIL ([^\n]+)") do failed[#failed + 1] = name end
            for secs, name in text:gmatch("\nTIME\t([%d%.]+)\t([^\n]+)") do times[name] = tonumber(secs) end
            local body = ("\n" .. text):gsub("\nTIME\t[^\n]*", ""):gsub("\n%d+ passed, %d+ failed[^\n]*\n?$", "")
            if body:match("%S") then io.write(body, "\n") end
        end
        if args.coverage then
            for src, line in io.open(f.hits):read("*a"):gmatch("([^\t\n]+)\t(%d+)") do
                hits[src] = hits[src] or {}
                hits[src][tonumber(line)] = true
            end
        end
        os.remove(f.out); os.remove(f.hits); os.remove(f.list)
    end
end
for _, t in ipairs(parallel and {} or chosen) do
    do
        H.worlds = {}
        math.randomseed(42)
        local start = os.clock()
        local ok, err = xpcall(t.fn, debug.traceback)
        local problems = {}
        for _, w in ipairs(H.worlds) do
            for _, c in ipairs(w.clients) do
                if c.online then c.seenLog = c.seenLog or {}; c:CollectLogErrors() end
                for _, e in ipairs(c.errors) do problems[#problems + 1] = c.name .. ": " .. e end
                for _, e in ipairs(H.Invariants(c)) do problems[#problems + 1] = c.name .. ": " .. e end
            end
        end
        if ok and #problems > 0 then ok, err = false, "errors in clients:\n    " .. table.concat(problems, "\n    ") end
        times[t.name] = os.clock() - start
        if ok then
            passed = passed + 1
            if args.verbose then print("  ok   " .. t.name) end
        else
            failed[#failed + 1] = t.name
            print("  FAIL " .. t.name .. "\n    " .. tostring(err):gsub("\n", "\n    "))
            -- The last log lines of each client usually tell the story.
            for _, w in ipairs(H.worlds) do
                for _, c in ipairs(w.clients) do
                    if c.env then
                        local log = c:Log()
                        print("    -- " .. c.name .. " log (last 12):")
                        for i = math.max(1, #log - 11), #log do print("       " .. log[i]) end
                    end
                end
            end
        end
    end
end
if args.coverage and not parallel then debug.sethook() end
local elapsed = parallel and (Wall() - wall0) or (os.clock() - t0)
if args.shard then
    for name, secs in pairs(times) do print(("TIME\t%.4f\t%s"):format(secs, name)) end
    -- A shard: its hits for the parent, its counts (the parent reads the last line).
    if args.hitsOut then
        local f = assert(io.open(args.hitsOut, "w"))
        for src, lines in pairs(hits) do
            if src:sub(1, 1) == "@" and not src:find("^@Libs/") and not src:find("^@tools/") then
                for l in pairs(lines) do f:write(src, "\t", l, "\n") end
            end
        end
        f:close()
    end
    print(("\n%d passed, %d failed (%.1fs)"):format(passed, #failed, elapsed))
    os.exit(#failed > 0 and 1 or 0)
end

------------------------------------------------------------------------------
-- Coverage report
------------------------------------------------------------------------------
local covFail = {}
if args.coverage then
    print(("\n%-28s %6s %6s %7s"):format("file", "lines", "hit", "cover"))
    local totalL, totalH = 0, 0
    for _, path in ipairs(H.TOC.files) do
        if not path:match("^Libs/") then
            local lines, src = ExecutableLines(path)
            local h = hits["@" .. path] or {}
            local n, hit, missed = 0, 0, {}
            for l in pairs(lines) do
                n = n + 1
                if h[l] then hit = hit + 1 else missed[#missed + 1] = l end
            end
            table.sort(missed)
            totalL, totalH = totalL + n, totalH + hit
            local pct = n > 0 and hit * 100 / n or 100
            print(("%-28s %6d %6d %6.1f%%"):format(path, n, hit, pct))
            for _, m in ipairs(args.missed) do
                if path:find(m, 1, true) then
                    for _, l in ipairs(missed) do print(("    %4d  %s"):format(l, src[l])) end
                end
            end
            for _, m in ipairs(args.min) do
                if path:sub(1, #m.prefix) == m.prefix and pct < m.pct then
                    covFail[#covFail + 1] = ("%s is %.1f%% covered, below %d%%"):format(path, pct, m.pct)
                end
            end
        end
    end
    print(("%-28s %6d %6d %6.1f%%"):format("total", totalL, totalH, totalL > 0 and totalH * 100 / totalL or 100))
end

-- The times for the next run's shards: kept for the tests not run this time (a filter).
if not args.list then
    local all = ReadTimings()
    for name, secs in pairs(times) do all[name] = secs end
    local f = io.open(TIMINGS, "w")
    if f then
        for name, secs in pairs(all) do f:write(("%.4f\t%s\n"):format(secs, name)) end
        f:close()
    end
end
if args.slow then
    local list = {}
    for name, secs in pairs(times) do list[#list + 1] = { name = name, secs = secs } end
    table.sort(list, function(a, b) return a.secs > b.secs end)
    print(("\nslowest %d (CPU s%s):"):format(math.min(args.slow, #list), args.coverage and ", with coverage" or ""))
    for i = 1, math.min(args.slow, #list) do print(("  %7.3f  %s"):format(list[i].secs, list[i].name)) end
end

print(("\n%d passed, %d failed (%.1fs)"):format(passed, #failed, elapsed))
for _, f in ipairs(covFail) do print("COVERAGE: " .. f) end
if #failed > 0 or #covFail > 0 then os.exit(1) end
