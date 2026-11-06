-- Test runner. Run from the addon folder (tools/check.sh does):
--   luajit tools/test/run.lua                  all specs
--   luajit tools/test/run.lua sync             only tests whose "spec: name" contains "sync"
--   luajit tools/test/run.lua --coverage       plus line coverage per addon file
--   luajit tools/test/run.lua --missed=Sync    print the uncovered lines of matching files
--   luajit tools/test/run.lua --min=Menagerie/=95 --min=Core/Comm=90
--                                              fail if a file under the prefix is below n%
--   -v                                         print each test name
--
-- Specs live in tools/test/spec/*.lua and return function(test, H).
-- After each test the runner fails it if any client logged a Lua error,
-- a failed comm handler, or a tooltip error (see harness Client.errors).
-- Set `c.errors = {}` in a test that provokes errors on purpose.
package.path = "tools/test/?.lua;" .. package.path

local args = { filter = nil, coverage = false, missed = {}, min = {}, verbose = false }
for _, a in ipairs(arg) do
    local m = a:match("^%-%-missed=(.+)$")
    local mp, mv = a:match("^%-%-min=(.+)=(%d+)$")
    if a == "--coverage" then
        args.coverage = true
    elseif m then
        args.coverage = true
        args.missed[#args.missed + 1] = m
    elseif mp then
        args.coverage = true
        args.min[#args.min + 1] = { prefix = mp, pct = tonumber(mv) }
    elseif a == "-v" then
        args.verbose = true
    else
        args.filter = a
    end
end

------------------------------------------------------------------------------
-- Coverage: a line hook counts executed lines of addon files; the lines
-- that can execute at all come from LuaJIT's bytecode line info, so blank
-- lines, comments and bare `end`s don't count against us.
------------------------------------------------------------------------------
local hits = {} -- path -> { [line] = true }
if args.coverage then
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

local passed, failed = 0, {}
local t0 = os.clock()
for _, t in ipairs(tests) do
    if not args.filter or t.name:find(args.filter, 1, true) then
        H.worlds = {}
        math.randomseed(42)
        local ok, err = xpcall(t.fn, debug.traceback)
        local problems = {}
        for _, w in ipairs(H.worlds) do
            for _, c in ipairs(w.clients) do
                if c.online then c.seenLog = c.seenLog or {}; c:CollectLogErrors() end
                for _, e in ipairs(c.errors) do problems[#problems + 1] = c.name .. ": " .. e end
            end
        end
        if ok and #problems > 0 then ok, err = false, "errors in clients:\n    " .. table.concat(problems, "\n    ") end
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
if args.coverage then debug.sethook() end
local elapsed = os.clock() - t0

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

print(("\n%d passed, %d failed (%.1fs)"):format(passed, #failed, elapsed))
for _, f in ipairs(covFail) do print("COVERAGE: " .. f) end
if #failed > 0 or #covFail > 0 then os.exit(1) end
