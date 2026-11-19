-- The debug log, read outside the game (2026-11-14, the user: "we both need better tools to log / test in
-- game"). Run from the addon folder after a /reload or logout (the client writes SavedVariables only then):
--
--   luajit tools/log.lua                    the newest session, oldest line first
--   luajit tools/log.lua -s 2               the session before it (-s all: every session in the ring)
--   luajit tools/log.lua --sessions         one line per session: its header, how long, how many lines
--   luajit tools/log.lua -m Reactions,Wish  only these modules (-x Moves,Sense: all but these)
--   luajit tools/log.lua -g "said today"    only lines with this text (plain; -p for a Lua pattern)
--   luajit tools/log.lua --summary          lines per module, and the commonest lines (numbers as N)
--   luajit tools/log.lua --errors           our Lua errors: the log's, then BugGrabber's saved ones of the last
--                                           7 days (--errors-all: every one it kept; old ones are usually fixed)
--   luajit tools/log.lua --dump api.glance  a table in DyreparkenDebugDB, as Lua
--   luajit tools/log.lua --db settings      a table in DyreparkenDB (the account's data), as Lua
--   luajit tools/log.lua --at 22:08 [-w 90] the lines around a time of day (every session; the newest day that has
--                                           any), 60 s either side by default: "my pet said something odd at 22:08"
--   luajit tools/log.lua --rate             lines per minute per module (a noisy new module stands out)
--   luajit tools/log.lua -n 50              the last 50 lines only
--   luajit tools/log.lua -f <file>          another SavedVariables file (default: WTF/Account/*/SavedVariables)
--
-- Lines are "serverTime  GetTime  module  message" (Core/Debug.lua); shown as "HH:MM:SS  +s  module  message",
-- +s the seconds since the session's start. A login writes a "Session" line, where sessions split.
local args = { ... }
local opt = { session = "1" }
local i = 1
while i <= #args do
    local a = args[i]
    local function Next() i = i + 1; return args[i] end
    if a == "-s" then opt.session = Next()
    elseif a == "-m" then opt.only = Next()
    elseif a == "-x" then opt.except = Next()
    elseif a == "-g" then opt.grep = Next()
    elseif a == "-p" then opt.pattern = Next()
    elseif a == "-n" then opt.tail = tonumber(Next())
    elseif a == "-f" then opt.file = Next()
    elseif a == "--sessions" then opt.sessions = true
    elseif a == "--summary" then opt.summary = true
    elseif a == "--errors" then opt.errors = true
    elseif a == "--errors-all" then opt.errors, opt.allErrors = true, true
    elseif a == "--dump" then opt.dump = Next()
    elseif a == "--db" then opt.db = Next()
    elseif a == "--at" then opt.at = Next(); opt.session = "all"
    elseif a == "-w" then opt.window = tonumber(Next())
    elseif a == "--rate" then opt.rate = true
    elseif a == "-h" or a == "--help" then
        for line in io.lines(arg[0]) do
            if not line:find("^%-%-") then break end
            print((line:gsub("^%-%- ?", "")))
        end
        os.exit(0)
    else
        io.stderr:write("unknown option ", a, " (-h for help)\n"); os.exit(2)
    end
    i = i + 1
end

local function Glob(pattern)
    local p = io.popen("ls -d " .. pattern .. " 2>/dev/null")
    local out = {}
    for line in p:lines() do out[#out + 1] = line end
    p:close()
    return out
end
local function Load(file, name)
    local f, err = loadfile(file)
    if not f then return nil, err end
    local env = {}
    setfenv(f, env)
    local ok, e = pcall(f)
    if not ok then return nil, e end
    return env[name]
end

local here = arg[0]:match("^(.*)/tools/log%.lua$") or "."
local file = opt.file
if not file then
    local found = Glob('"' .. here .. '/../../../WTF/Account/"*/SavedVariables/Dyreparken.lua')
    file = found[1]
    if not file then io.stderr:write("no WTF/Account/*/SavedVariables/Dyreparken.lua: give one with -f\n"); os.exit(1) end
end
local db, err = Load(file, opt.db and "DyreparkenDB" or "DyreparkenDebugDB")
if not db then io.stderr:write("can't read ", file, ": ", tostring(err or "no DyreparkenDebugDB"), "\n"); os.exit(1) end

-- A table as Lua text, keys sorted.
local function Show(v, indent, seen)
    indent, seen = indent or "", seen or {}
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    if seen[v] then return "<cycle>" end
    seen[v] = true
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
        return type(a) < type(b)
    end)
    if #keys == 0 then return "{}" end
    local out = { "{" }
    for _, k in ipairs(keys) do
        local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. Show(k) .. "]")
        out[#out + 1] = indent .. "  " .. key .. " = " .. Show(v[k], indent .. "  ", seen) .. ","
    end
    out[#out + 1] = indent .. "}"
    return table.concat(out, "\n")
end

if opt.dump or opt.db then
    local v = db
    for part in (opt.dump or opt.db):gmatch("[^%.]+") do
        if type(v) ~= "table" then v = nil; break end
        v = v[tonumber(part) or part]
    end
    print(Show(v))
    os.exit(0)
end

-- The ring, oldest first: lines.head is the newest index, the ring as big as its biggest index.
local ring = db.lines or {}
local size = 0
for k in pairs(ring) do if type(k) == "number" and k > size then size = k end end
local head = ring.head or size
local entries = {}
for n = 1, size do
    local line = ring[((head + n - 1) % size) + 1]
    if type(line) == "string" then
        local t, gt, module, msg = line:match("^(%d+)\t([%d%.]+)\t([^\t]*)\t(.*)$")
        if t then entries[#entries + 1] = { t = tonumber(t), gt = tonumber(gt), module = module, msg = msg } end
    end
end

-- Sessions: from each "Session start" line (and the ring's start, which may be the middle of one). The
-- "Session settled ..." line later on adds where the player was to the session's head.
local sessions = {}
for _, e in ipairs(entries) do
    local start = e.module == "Session" and e.msg:find("^start")
    if start or #sessions == 0 then
        sessions[#sessions + 1] = { head = start and e.msg or "(the ring's start: the session before is cut)", lines = {} }
    elseif e.module == "Session" and e.msg:find("^settled") and not sessions[#sessions].settled then
        sessions[#sessions].settled = true
        sessions[#sessions].head = sessions[#sessions].head .. "; " .. e.msg
    end
    local s = sessions[#sessions]
    s.lines[#s.lines + 1] = e
end

if opt.sessions then
    for n = #sessions, 1, -1 do
        local s = sessions[n]
        local a, b = s.lines[1], s.lines[#s.lines]
        print(("%2d  %s  %5d lines, %s  %s"):format(#sessions - n + 1, os.date("%Y-%m-%d %H:%M", a.t), #s.lines,
            ("%dm"):format(math.floor((b.t - a.t) / 60 + 0.5)), s.head))
    end
    os.exit(0)
end

local picked = {}
if opt.session == "all" then
    picked = sessions
else
    local n = tonumber(opt.session) or 1
    picked = { sessions[#sessions - n + 1] }
    if not picked[1] then io.stderr:write("no session ", opt.session, " (", #sessions, " in the log)\n"); os.exit(1) end
end

local function Set(list)
    if not list then return nil end
    local s = {}
    for m in list:gmatch("[^,]+") do s[m] = true end
    return s
end
local only, except = Set(opt.only), Set(opt.except)
-- --at: seconds into the day, and the newest day with a line that near it.
local atDay, atSecs
if opt.at then
    local h, m, sec = opt.at:match("^(%d+):(%d+):?(%d*)$")
    if not h then io.stderr:write("--at HH:MM[:SS]\n"); os.exit(2) end
    atSecs = tonumber(h) * 3600 + tonumber(m) * 60 + (tonumber(sec) or 0)
    opt.window = opt.window or 60
    for _, e in ipairs(entries) do
        local d = os.date("*t", e.t)
        if math.abs(d.hour * 3600 + d.min * 60 + d.sec - atSecs) <= opt.window then atDay = os.date("%Y%m%d", e.t) end
    end
    if not atDay then io.stderr:write("no line within ", opt.window, " s of ", opt.at, "\n"); os.exit(1) end
end
local function Keep(e)
    if atDay then
        local d = os.date("*t", e.t)
        if os.date("%Y%m%d", e.t) ~= atDay or math.abs(d.hour * 3600 + d.min * 60 + d.sec - atSecs) > opt.window then
            return false
        end
    end
    if only and not only[e.module] then return false end
    if except and except[e.module] then return false end
    local text = e.module .. "\t" .. e.msg
    if opt.grep and not text:find(opt.grep, 1, true) then return false end
    if opt.pattern and not text:find(opt.pattern) then return false end
    return true
end

local out = {}
for _, s in ipairs(picked) do
    local start = s.lines[1]
    for _, e in ipairs(s.lines) do
        if Keep(e) then out[#out + 1] = { e = e, start = start } end
    end
end

if opt.errors then
    print("-- Errors in the log:")
    for _, o in ipairs(out) do
        if o.e.module == "Error" then print(os.date("%m-%d %H:%M:%S", o.e.t) .. "  " .. o.e.msg) end
    end
    local bugs = Glob('"' .. file:match("^(.*)/[^/]*$") .. '/!BugGrabber.lua"')[1]
    local bdb = bugs and Load(bugs, "BugGrabberDB")
    print("-- BugGrabber's saved errors that name Dyreparken (newest first" .. (opt.allErrors and "" or ", the last 7 days") .. "):")
    local list = bdb and bdb.errors or {}
    local since, older = not opt.allErrors and (os.time() - 7 * 86400) or nil, 0
    for n = #list, 1, -1 do
        local e = list[n]
        local ours = type(e) == "table" and ((e.message or ""):find("Dyreparken") or (e.stack or ""):find("Dyreparken"))
        if ours and since and type(e.time) == "number" and e.time < since then
            older = older + 1
        elseif ours then
            local when = type(e.time) == "number" and os.date("%Y-%m-%d %H:%M:%S", e.time) or tostring(e.time)
            print(("%s  x%d  session %s\n  %s\n  %s"):format(when, e.counter or 1, tostring(e.session),
                tostring(e.message), (tostring(e.stack or "")):gsub("\n", "\n  ")))
        end
    end
    if older > 0 then print(("(%d older ones: --errors-all)"):format(older)) end
    os.exit(0)
end

if opt.summary then
    local modules, shapes = {}, {}
    for _, o in ipairs(out) do
        local n = tonumber(o.e.msg:match(" %(x(%d+)%)$")) or 1
        modules[o.e.module] = (modules[o.e.module] or 0) + n
        local shape = o.e.module .. "  " .. o.e.msg:gsub(" %(x%d+%)$", ""):gsub("%-?%d+%.?%d*", "N")
        shapes[shape] = (shapes[shape] or 0) + n
    end
    local function Top(t, limit)
        local list = {}
        for k, v in pairs(t) do list[#list + 1] = { k, v } end
        table.sort(list, function(a, b) return a[2] > b[2] end)
        for n = 1, math.min(limit, #list) do print(("%7d  %s"):format(list[n][2], list[n][1])) end
    end
    print("-- Lines per module:"); Top(modules, 40)
    print("-- The commonest lines:"); Top(shapes, 25)
    os.exit(0)
end

if opt.rate then
    -- Over the sessions' own time (a session's first line to its last), the " (xN)" counted in.
    local minutes, count = 0, {}
    for _, s in ipairs(picked) do minutes = minutes + (s.lines[#s.lines].t - s.lines[1].t) / 60 end
    for _, o in ipairs(out) do
        count[o.e.module] = (count[o.e.module] or 0) + (tonumber(o.e.msg:match(" %(x(%d+)%)$")) or 1)
    end
    local list = {}
    for m, n in pairs(count) do list[#list + 1] = { m, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    print(("-- Lines per minute over %.0f minutes:"):format(minutes))
    for _, x in ipairs(list) do print(("%8.2f  %6d  %s"):format(x[2] / math.max(minutes, 1), x[2], x[1])) end
    os.exit(0)
end

local from = opt.tail and math.max(1, #out - opt.tail + 1) or 1
for n = from, #out do
    local e, start = out[n].e, out[n].start
    print(("%s  %+8.1f  %-10s %s"):format(os.date("%H:%M:%S", e.t), e.gt - start.gt, e.module, e.msg))
end
