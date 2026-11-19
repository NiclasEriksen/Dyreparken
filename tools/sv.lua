-- The saved data, inspected outside the game (2026-11-19). Run from the addon folder after a /reload or logout
-- (the client writes SavedVariables only then):
--
--   luajit tools/sv.lua [summary]           per guild: who holds what, bonds by carer, names, lapses, owners,
--                                           held roster batches; and each saved table's size in bytes (bloat)
--   luajit tools/sv.lua check               the saved data through today's code: a harness client logs in with it
--                                           (migrations, login errors), then every stored claim, lapse, name,
--                                           bond, guild achievement and owned list goes through the check a
--                                           peer's merge runs (Sync.TABLES' valid, Owners.Valid): what the guild
--                                           would refuse of what we'd send
--   luajit tools/sv.lua picks               the editors' picks (/dp probe bg, decor, frames, lift, moves, place)
--                                           as Lua to paste into the data, each saying if the data has it already
--   --file <file>   another account file (default: WTF/Account/*/SavedVariables/Dyreparken.lua)
--   --char <file>   check: a character's file (default: the newest WTF/Account/*/<realm>/<char>/..., only
--                   without --file)
--   --name <name>   check: who logs in ("First Surname"; default: from the character file's folder)
--   --guild <name>  check: the guild (default: the one with the player's data, else the biggest)
--
-- Read-only: the files are never written. check needs the harness (tools/test/), so run it from the addon folder.
local args = { ... }
local opt = { cmd = "summary" }
local i = 1
while i <= #args do
    local a = args[i]
    local function Next() i = i + 1; return args[i] end
    if a == "--file" or a == "-f" then opt.file = Next()
    elseif a == "--char" then opt.char = Next()
    elseif a == "--name" then opt.name = Next()
    elseif a == "--guild" then opt.guild = Next()
    elseif a == "summary" or a == "check" or a == "picks" then opt.cmd = a
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
    local p = io.popen("ls -td " .. pattern .. " 2>/dev/null") -- (newest first)
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
local function Die(...) io.stderr:write(...); io.stderr:write("\n"); os.exit(1) end

local here = arg[0]:match("^(.*)/tools/sv%.lua$") or "."
local wtf = here .. "/../../../WTF/Account/"
local file = opt.file
if not file then
    file = Glob('"' .. wtf .. '"*/SavedVariables/Dyreparken.lua')[1]
    if not file then Die("no WTF/Account/*/SavedVariables/Dyreparken.lua: give one with --file") end
end
local db, err = Load(file, "DyreparkenDB")
if not db then Die("can't read ", file, ": ", tostring(err or "no DyreparkenDB")) end

-- Species names, from Data/Companions.lua's comments ("[40] = { ... }, -- Bombay").
local names = {}
for line in io.lines(here .. "/Data/Companions.lua") do
    local sid, name = line:match("^%s*%[(%d+)%] = .-%-%- (.+)$")
    if sid then names[tonumber(sid)] = name end
end
local function Pet(key)
    local sid = type(key) == "string" and tonumber(key:match("^s:(%d+)$"))
    return sid and names[sid] and (key .. " " .. names[sid]) or tostring(key)
end
local function Day(t) return type(t) == "number" and os.date("%Y-%m-%d", t) or tostring(t) end
local function Sorted(t, less)
    local keys = {}
    for k in pairs(t or {}) do keys[#keys + 1] = k end
    table.sort(keys, less or function(a, b)
        if type(a) == type(b) and (type(a) == "number" or type(a) == "string") then return a < b end
        return type(a) < type(b)
    end)
    return keys
end
local function Count(t)
    local n = 0
    for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end
    return n
end

-- A value as Lua text on one line, keys sorted (strings as WoW writes them, %q).
local function Inline(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    local out = {}
    for _, k in ipairs(Sorted(v)) do
        local key = type(k) == "string" and k:match("^[%a_][%w_]*$") and k or ("[" .. Inline(k) .. "]")
        out[#out + 1] = key .. " = " .. Inline(v[k])
    end
    return #out == 0 and "{}" or ("{ " .. table.concat(out, ", ") .. " }")
end

------------------------------------------------------------------------------
-- summary
------------------------------------------------------------------------------
-- A value's bytes as the client writes it: ["key"] = value, one a line, no indent.
local function Bytes(v)
    if type(v) == "string" then return #string.format("%q", v) end
    if type(v) ~= "table" then return #tostring(v) end
    local n = 2 -- "{" "}"
    for k, x in pairs(v) do
        n = n + 2 + (type(k) == "string" and #string.format("%q", k) or #tostring(k)) + 4 + Bytes(x) + 2
    end
    return n
end
local function Size(n)
    if n >= 1024 * 1024 then return ("%.1f MB"):format(n / 1024 / 1024) end
    if n >= 1024 then return ("%.1f KB"):format(n / 1024) end
    return n .. " B"
end

local function Summary()
    for _, gname in ipairs(Sorted(db.guilds)) do
        local g = db.guilds[gname]
        print(("== Guild %s"):format(gname))
        -- Who holds a pet, roughly as Registry derives it (earliest claim not voided by a lapse; ties: the lower
        -- name): a summary's guess, not the code's answer (check runs the code).
        local claims, lapses = g.claims or {}, g.lapses or {}
        local holder = {}
        for owner, r in pairs(claims) do
            if type(r) == "table" and r.k and not (lapses[owner] and lapses[owner] >= (r.at or 0)) then
                local h = holder[r.k]
                if not h or r.at < claims[h].at or (r.at == claims[h].at and owner < h) then holder[r.k] = owner end
            end
        end
        print(("-- Claims (%d):"):format(Count(claims)))
        for _, owner in ipairs(Sorted(claims)) do
            local r = claims[owner]
            local what
            if type(r) ~= "table" then what = "?? " .. Inline(r)
            elseif not r.k then what = "(none, released " .. Day(r.ts) .. ")"
            else
                what = Pet(r.k) .. " since " .. Day(r.at)
                    .. (holder[r.k] == owner and "" or ("  (not the holder: " .. tostring(holder[r.k]) .. ")"))
            end
            print(("  %-22s %s"):format(owner, what))
        end
        print(("-- Lapses: %d"):format(Count(lapses)))
        if g.rosterHeld then
            print(("-- Held roster batch: %d owners, since %s"):format(Count(g.rosterHeld.owners), Day(g.rosterHeld.at)))
        else
            print("-- Held roster batch: none")
        end
        -- Bonds by carer.
        local carers = {}
        local pets = 0
        for key, byCarer in pairs(g.life or {}) do
            pets = pets + 1
            for carer, e in pairs(type(byCarer) == "table" and byCarer or {}) do
                local c = carers[carer] or { n = 0, p = 0, list = {} }
                carers[carer] = c
                local p = type(e) == "table" and tonumber(e.p) or 0
                c.n, c.p = c.n + 1, c.p + p
                c.list[#c.list + 1] = { key = key, p = p }
            end
        end
        print(("-- Bonds: %d pets, %d carers (carer: entries, points in all, the top three)"):format(pets, Count(carers)))
        for _, carer in ipairs(Sorted(carers, function(a, b) return carers[a].p > carers[b].p end)) do
            local c = carers[carer]
            table.sort(c.list, function(a, b) return a.p > b.p end)
            local top = {}
            for n = 1, math.min(3, #c.list) do top[n] = Pet(c.list[n].key) .. " " .. c.list[n].p end
            print(("  %-22s %3d  %6d  %s"):format(carer, c.n, c.p, table.concat(top, ", ")))
        end
        print(("-- Names (%d pets):"):format(Count(g.names)))
        for _, key in ipairs(Sorted(g.names)) do
            local newest, by, n = nil, nil, 0
            for namer, e in pairs(type(g.names[key]) == "table" and g.names[key] or {}) do
                n = n + 1
                if type(e) == "table" and (not newest or (e.at or 0) > (newest.at or 0)) then newest, by = e, namer end
            end
            local what = newest and (newest.n and ("«" .. newest.n .. "»") or "(cleared)") or "?"
            print(("  %-28s %s by %s, %s%s  (%d entries)"):format(Pet(key), what, tostring(by), Day(newest and newest.at),
                newest and newest.x and ", void" or "", n))
        end
        print(("-- Owners (%d members):"):format(Count(g.owns)))
        for _, member in ipairs(Sorted(g.owns)) do
            local e = g.owns[member]
            local s = type(e) == "table" and type(e.s) == "string" and e.s or ""
            local n = 0
            for _ in s:gmatch("%d+") do n = n + 1 end
            print(("  %-22s %3d species, %s"):format(member, n, Day(type(e) == "table" and e.at)))
        end
        print(("-- Also: %d guild achievements, %d stories, born %s"):format(Count(g.ach), Count(g.story), Day(g.born)))
    end
    print("== Sizes (about: as the client writes them)")
    for _, var in ipairs({ "DyreparkenDB", "DyreparkenDebugDB" }) do
        local t = var == "DyreparkenDB" and db or Load(file, var)
        if type(t) == "table" then
            print(("-- %s: %s"):format(var, Size(Bytes(t))))
            local keys = Sorted(t, function(a, b) return Bytes(t[a]) > Bytes(t[b]) end)
            for _, k in ipairs(keys) do
                local v = t[k]
                print(("  %-14s %10s%s"):format(tostring(k), Size(Bytes(v)),
                    type(v) == "table" and ("  (" .. Count(v) .. " entries)") or ""))
            end
        end
    end
end

------------------------------------------------------------------------------
-- The addon in a harness client (check, picks)
------------------------------------------------------------------------------
local H
local function Harness()
    if not H then
        local ok, e = pcall(dofile, "tools/test/harness.lua")
        if not ok then Die("can't load the harness (run from the addon folder): ", tostring(e)) end
        H = e
    end
    return H
end
-- The Config as it ships: the harness moves the bond epoch to its own clock (client.lua), which real data
-- isn't on.
local function Shipped(ns, c)
    ns.Config.BOND_EPOCH = c.shippedConfig.BOND_EPOCH
    ns.Config.BONDS_SHIPPED = c.shippedConfig.BONDS_SHIPPED
end

------------------------------------------------------------------------------
-- check
------------------------------------------------------------------------------
local function DeepCopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = DeepCopy(x) end
    return out
end

-- Why an entry fails, for the report: the shape's parts a peer checks (the verdict is the code's).
local function Why(ns, store, key, author, e)
    local W, out = ns.Wire, {}
    if author ~= nil and not W.Name(author) then out[#out + 1] = "author name" end
    if (store == "names" or store == "life") and not W.Key(key) then out[#out + 1] = "pet key" end
    if store == "claims" and type(e) == "table" and e.k ~= nil and not W.Key(e.k) then out[#out + 1] = "pet key" end
    if type(e) ~= "table" then
        if store == "lapses" and not W.Since(e) then out[#out + 1] = "time " .. tostring(e) end
        return #out > 0 and table.concat(out, ", ") or "the entry"
    end
    local now = ns.Now()
    for _, f in ipairs({ "at", "ts", "f", "t", "ann" }) do
        local t = e[f]
        if t ~= nil then
            if type(t) ~= "number" then out[#out + 1] = f .. " not a number"
            elseif math.floor(t) ~= t then out[#out + 1] = f .. " not a whole second"
            elseif t > now + ns.Config.CLOCK_SLACK then out[#out + 1] = f .. " in the future (" .. Day(t) .. ")"
            elseif t < ns.Config.BOND_EPOCH and f ~= "t" and f ~= "ann" then out[#out + 1] = f .. " before BOND_EPOCH" end
        end
    end
    if store == "claims" and type(e.at) == "number" and type(e.ts) == "number" and e.at > e.ts then out[#out + 1] = "at after ts" end
    if store == "names" and e.n ~= nil and W.Nick(e.n) then out[#out + 1] = "nickname " .. W.Nick(e.n) end
    if store == "life" and type(e.p) == "number" and type(e.f) == "number" and type(e.t) == "number" then
        local cap = W.LifeCap(e.f, e.t)
        if e.p > cap then out[#out + 1] = ("p %s over the cap %s"):format(e.p, cap) end
    end
    if store == "owns" and not W.Owned(e.s) then out[#out + 1] = "species list" end
    return #out > 0 and table.concat(out, ", ") or "the entry"
end

local function Check()
    -- The character: given, else the newest one on the account (only for the real account folder).
    local charFile = opt.char
    if not charFile and not opt.file then
        charFile = Glob('"' .. wtf .. '"*/*/*/SavedVariables/Dyreparken.lua')[1]
    end
    local char
    if charFile then
        char, err = Load(charFile, "DyreparkenCharDB")
        if not char then Die("can't read ", charFile, ": ", tostring(err or "no DyreparkenCharDB")) end
    end
    local player = opt.name
        or (charFile and charFile:match("([^/]+)/SavedVariables/[^/]+$") or ""):gsub("%-", " ")
    if player == "" then player = "Sv Sjekk" end
    -- The guild: given, else the one with the player's claim, else the one with the most claims.
    local gname = opt.guild
    if not gname then
        local best = -1
        for name, g in pairs(db.guilds or {}) do
            local n = (g.claims and g.claims[player]) and math.huge or Count(g.claims)
            if n > best then gname, best = name, n end
        end
    end
    if not gname or not (db.guilds or {})[gname] then Die("no guild ", tostring(gname), " in ", file) end
    local raw = db.guilds[gname]

    local Hh = Harness()
    local w = Hh.World({ guild = gname })
    -- The clock: now, or the newest time in the data if that's later (a file from a clock ahead of ours).
    local newest = os.time()
    local function Scan(v) -- (bounded: the guild's tables only)
        if type(v) == "number" and v > newest and v < 4e9 and v > 1.7e9 then newest = v end
        if type(v) == "table" then for _, x in pairs(v) do Scan(x) end end
    end
    for _, k in ipairs({ "claims", "lapses", "names", "life", "owns", "ach" }) do Scan(raw[k]) end
    w.server = newest + 1 - math.floor(w.t)
    -- Everyone the data names is a member, online: the file is already pruned to the roster the client last
    -- read, so this keeps it as it is (no lapses, no members-only pruning here).
    local authors = {}
    for owner in pairs(raw.claims or {}) do authors[owner] = true end
    for _, store in ipairs({ "names", "life" }) do
        for _, byAuthor in pairs(raw[store] or {}) do
            for a in pairs(type(byAuthor) == "table" and byAuthor or {}) do authors[a] = true end
        end
    end
    for member in pairs(raw.owns or {}) do authors[member] = true end
    authors[player] = nil
    for name in pairs(authors) do
        if type(name) == "string" then w:AddMember(name, nil) end
    end
    local owned = {}
    local mine = raw.owns and raw.owns[player]
    for sid in (type(mine) == "table" and type(mine.s) == "string" and mine.s or ""):gmatch("%d+") do
        owned[#owned + 1] = tonumber(sid)
    end
    local c = w:AddClient(player, { login = false, pets = owned, summoned = false, fixture = Shipped })
    c.saved.DyreparkenDB = DeepCopy(db)
    c.saved.DyreparkenCharDB = char and DeepCopy(char) or nil

    print(("== check: %s in <%s>, account schema %s, character schema %s, clock %s"):format(player, gname,
        tostring(db.schema), char and tostring(char.schema) or "(no character file)", os.date("%Y-%m-%d %H:%M", w:ServerTime())))
    local problems = 0
    local ok, e = pcall(c.Login, c)
    if not ok then
        print("-- The login threw (a migration or ADDON_LOADED / PLAYER_LOGIN):")
        print("  " .. tostring(e))
        os.exit(1)
    end
    w:Run(15) -- (past the settled and hello phases: the roster read, CheckMine, the HELLO round)
    local ns = c.ns
    print(("-- Schemas now: account %s, character %s"):format(tostring(ns.DB.global.schema), tostring(ns.DB.char.schema)))
    for _, l in ipairs(c:Log("\tDB\t")) do print("  log: " .. l:gsub("^[^\t]*\t[^\t]*\t", "")) end
    local pet = ns.Registry:MyPet()
    print(("-- %s holds %s (as the code derives it: Registry:MyPet)"):format(player, pet and Pet(pet) or "no pet"))
    local errors = c:TakeErrors()
    print(("-- Errors at login: %d"):format(#errors))
    for _, x in ipairs(errors) do print("  " .. tostring(x):gsub("\n", "\n  ")) end
    problems = problems + #errors

    -- Every store a peer merges, by its check: Sync.TABLES (wire key -> the guild table it keeps) and Owners.
    local g = ns.DB:Guild()
    local STORE = { r = "claims", l = "lapses", a = "ach", n = "names", b = "life" }
    local rows = {}
    for _, row in ipairs(ns.Sync.TABLES) do
        local store = STORE[row.wire]
        if not store then
            print(("-- Sync.TABLES has a row tools/sv.lua doesn't know (%q): add it to STORE"):format(row.wire))
            problems = problems + 1
        else
            rows[#rows + 1] = { store = store, nested = row.nested, valid = row.valid, count = row.count }
        end
    end
    rows[#rows + 1] = { store = "owns", valid = ns.Owners.Valid }
    print("-- Stores (entries in the file, after the login, refused by a peer's check):")
    local refused = {}
    for _, row in ipairs(rows) do
        local function Each(t, fn)
            for k, v in pairs(type(t) == "table" and t or {}) do
                if row.nested then
                    for a, x in pairs(type(v) == "table" and v or {}) do fn(k, a, x) end
                else
                    fn(k, nil, v)
                end
            end
        end
        local before, after, bad = 0, 0, 0
        Each(raw[row.store], function() before = before + 1 end)
        Each(g[row.store], function(k, a, x)
            after = after + 1
            local fine
            if row.nested then fine = row.valid(k, a, x) else fine = row.valid(k, x) end
            if not fine then
                bad = bad + 1
                refused[#refused + 1] = ("  %-7s %s%s  %s  (%s)"):format(row.store, row.nested and (Pet(k) .. " by ") or "",
                    row.nested and tostring(a) or tostring(k), Inline(x),
                    Why(ns, row.store, k, row.nested and a or (row.store ~= "ach" and k or nil), x))
            end
        end)
        local over = row.count and after > ns.Config.SYNC_MAX_ENTRIES
        print(("  %-7s %5d %5d %5d%s"):format(row.store, before, after, bad,
            over and ("  OVER SYNC_MAX_ENTRIES (" .. ns.Config.SYNC_MAX_ENTRIES .. "): the whole part is refused") or ""))
        if over then problems = problems + 1 end
        problems = problems + bad
    end
    if #refused > 0 then
        print("-- Refused by a peer (would not be kept by the guild):")
        for _, line in ipairs(refused) do print(line) end
    end
    print(problems == 0 and "-- All good: the guild would accept everything we'd send."
        or ("-- %d problem(s)."):format(problems))
    os.exit(problems == 0 and 0 or 1)
end

------------------------------------------------------------------------------
-- picks
------------------------------------------------------------------------------
local MOVE_ORDER = { "lift", "sleep", "sleepAt", "sleepHold", "sleepUp", "canSit", "sitDown", "sit", "sitUp", "happy",
    "happyToo", "cheer", "dead", "attack", "cower", "walk", "run", "canJump", "jumpStart", "jump", "jumpEnd" }

-- A row of Data/PetMoves.lua's species table, its fields in the file's order.
local function MovesRow(row)
    local out, seen = {}, {}
    for _, k in ipairs(MOVE_ORDER) do
        if row[k] ~= nil then out[#out + 1] = k .. " = " .. tostring(row[k]); seen[k] = true end
    end
    for _, k in ipairs(Sorted(row)) do
        if not seen[k] then out[#out + 1] = tostring(k) .. " = " .. Inline(row[k]) end
    end
    return "{ " .. table.concat(out, ", ") .. " }"
end
local function Num(v) return (("%.2f"):format(v):gsub("0+$", ""):gsub("%.$", "")) end
local function Fit(p) return ("{ floor = %s, size = %s }"):format(Num(p.floor), Num(p.size)) end
local function Same(a, b, eps) return type(a) == "number" and type(b) == "number" and math.abs(a - b) < eps end
local function Mark(has) return has and "  -- (in the data already)" or "" end

local function Picks()
    local Hh = Harness()
    local w = Hh.World()
    local c = w:AddClient("Sv Sjekk", { pets = {}, summoned = false, fixture = Shipped })
    local ns = c.ns
    local handled = { scenePicks = true, decorPicks = true, liftPicks = true, movePicks = true, placePicks = true,
        modelPicks = true }

    -- Backgrounds: Scenes.BY_FAMILY[family], its first candidate.
    print("-- scenePicks -> Menagerie/Scenes.lua, Scenes.BY_FAMILY (the first candidate is shown):")
    local EJ = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-"
    for _, family in ipairs(Sorted(db.scenePicks)) do
        local path = db.scenePicks[family]
        local code = ns.Scenes.BY_FAMILY[family]
        local text = type(path) == "string" and path:sub(1, #EJ) == EJ and ("EJ .. %q"):format(path:sub(#EJ + 1)) or Inline(path)
        print(("    %s = { %s },%s"):format(family, text, Mark(code and code[1] == path)))
    end

    -- Decorations: "slot" -> Decor.ART, "slot.family" -> Decor.FAMILY_ART[family]; atlases there by bare name.
    print("-- decorPicks -> Menagerie/Decor.lua, Decor.ART (slot) and Decor.FAMILY_ART (slot.family):")
    local art, family, unclear = {}, {}, {}
    for _, slot in ipairs(Sorted(db.decorPicks)) do
        local pick = db.decorPicks[slot]
        local value = type(pick) == "string" and pick:gsub("^atlas:", "") or pick
        local kind, fam = slot:match("^(%a+)%.(%a+)$")
        if fam then
            local own = ns.Decor.FAMILY_ART[fam]
            family[fam] = family[fam] or {}
            family[fam][#family[fam] + 1] = { kind = kind, value = value, has = own and own[kind] == value }
        elseif type(slot) == "string" and slot:match("^%a+$") then
            -- A particle slot's picture is its kind's own texture unless Decor.ART names one (Decor:PartArt).
            local kindOf = ns.Decor.SLOT_KIND[slot]
            local now = kindOf and ns.Decor:PartArt(kindOf) or ns.Decor.ART[slot]
            art[#art + 1] = ("    %s = %s,%s"):format(slot, Inline(value), Mark(now == value))
        else
            unclear[#unclear + 1] = slot
        end
    end
    print("  Decor.ART:")
    for _, line in ipairs(art) do print(line) end
    print("  Decor.FAMILY_ART:")
    for _, fam in ipairs(Sorted(family)) do
        local parts, has = {}, {}
        for _, p in ipairs(family[fam]) do
            parts[#parts + 1] = p.kind .. " = " .. Inline(p.value)
            if p.has then has[#has + 1] = p.kind end
        end
        print(("    %s = { %s },%s"):format(fam, table.concat(parts, ", "), #has == #parts and Mark(true)
            or #has > 0 and ("  -- (in the data already: " .. table.concat(has, ", ") .. ")") or ""))
    end
    for _, slot in ipairs(unclear) do
        print(("  (unclear slot %s, raw: %s)"):format(Inline(slot), Inline(db.decorPicks[slot])))
    end

    -- Lifts and moves: Data/PetMoves.lua's species rows, the picks merged in (a row to replace the file's).
    print("-- liftPicks and movePicks -> Data/PetMoves.lua, ns.PetMoves.species (whole rows, picks merged in):")
    local sids = {}
    for sid in pairs(db.liftPicks or {}) do sids[tonumber(sid) or sid] = true end
    for sid in pairs(db.movePicks or {}) do sids[tonumber(sid) or sid] = true end
    local data = ns.PetMoves
    for _, sid in ipairs(Sorted(sids)) do
        local file = data.species[sid] or {}
        local row, has = {}, true
        for k, v in pairs(file) do row[k] = v end
        local lift = (db.liftPicks or {})[sid]
        if lift ~= nil then
            row.lift = lift
            has = has and Same(lift, file.lift or 0, 1e-6)
        end
        for what, v in pairs((db.movePicks or {})[sid] or {}) do
            local now = file[what]
            if now == nil then now = data.default[what] end
            if v == now then
                -- (the file has it, as its own or the default)
            else
                row[what] = v
                has = false
            end
        end
        print(("    [%s] = %s,  -- %s%s"):format(tostring(sid), MovesRow(row), names[sid] or "?",
            has and " (in the data already)" or ""))
    end

    -- Places: placePicks stage -> scene -> fit (ns.PetScenes), modelPicks stage -> model -> fit (ns.PetModels).
    print("-- placePicks -> Data/PetScenes.lua, ns.PetScenes[stage][scene]:")
    for _, stage in ipairs(Sorted(db.placePicks)) do
        local rows = ns.PetScenes[stage] or {}
        print(("  %s = {"):format(stage))
        for _, scene in ipairs(Sorted(db.placePicks[stage])) do
            local p, file = db.placePicks[stage][scene], rows[scene]
            print(("        [%s] = %s,%s"):format(tostring(scene), Fit(p),
                Mark(file and Same(file.floor, p.floor, 0.01) and Same(file.size, p.size, 0.01))))
        end
        print("  },")
    end
    print("-- modelPicks -> Data/PetScenes.lua, ns.PetModels[stage][model]:")
    local byModel = {}
    for sid in pairs(ns.Companions.species) do
        local box = ns.Moves:Box(sid)
        if box then
            local m = ns.Moves.ModelOf(box)
            byModel[m] = byModel[m] or { scene = box.scene, names = {} }
            table.insert(byModel[m].names, names[sid] or tostring(sid))
        end
    end
    for _, stage in ipairs(Sorted(db.modelPicks)) do
        local rows = ns.PetModels[stage] or {}
        print(("  %s = {"):format(stage))
        for _, model in ipairs(Sorted(db.modelPicks[stage])) do
            local p = db.modelPicks[stage][model]
            local key = model:gsub("%-0%.000", "0.000") -- (as PlaceEditor puts old keys right)
            local file, who = rows[key], byModel[key]
            if who then table.sort(who.names) end
            print(("        [%q] = %s,  -- %s: %s%s"):format(key, Fit(p), who and tostring(who.scene) or "?",
                who and table.concat(who.names, ", ") or "(no species has this model)",
                (file and Same(file.floor, p.floor, 1e-6) and Same(file.size, p.size, 1e-6)) and " (in the data already)" or ""))
        end
        print("  },")
    end

    for _, k in ipairs(Sorted(db)) do
        if type(k) == "string" and k:find("Picks$") and not handled[k] then
            print(("-- %s: tools/sv.lua doesn't know where it goes; raw:"):format(k))
            print("  " .. Inline(db[k]))
        end
    end
    os.exit(0)
end

if opt.cmd == "check" then Check() elseif opt.cmd == "picks" then Picks() else Summary() end
