-- Saved data has a declared shape and an owner (Core/DB.lua): every key the
-- code reads or writes in DyreparkenDB / DyreparkenCharDB is listed in the
-- defaults, under the module that owns it, and only that module's file
-- assigns it (others go through the owner: Bonds:SetAnnounce, Wish:Shown ...).
-- Read from the source, since keys with a nil default don't exist at runtime.
return function(test, H)
    local eq, ok = H.eq, H.ok

    local function Read(path)
        local f = assert(io.open(path, "rb"))
        local s = f:read("*a")
        f:close()
        return s
    end

    -- The addon's own code: the TOC's files but the libraries, data and strings.
    local function Sources()
        local list = {}
        for _, path in ipairs(H.TOC.files) do
            if not (path:find("^Libs/") or path:find("^Data/") or path:find("^Locale/")) then list[#list + 1] = path end
        end
        return list
    end

    -- A defaults table's top-level keys -> owner, from its "-- [Owner]" headings.
    local function Declared(src, name)
        local keys, owner, inside = {}, nil, false
        for line in src:gmatch("[^\n]*") do
            if line:find("^local " .. name .. " = {") then
                inside = true
            elseif inside then
                if line:find("^}") then break end
                owner = line:match("^    %-%- %[([%w_]+)%]") or owner
                local key = line:match("^    ([%a_][%w_]*)%s*=")
                if key then keys[key] = owner or "?" end
            end
        end
        return keys
    end

    -- Code without its comments and strings (prose like "char.wish = { ... }" isn't a write).
    local function Code(src)
        local out = {}
        for line in (src .. "\n"):gmatch("([^\n]*)\n") do
            out[#out + 1] = (line:gsub('"[^"]*"', '""'):gsub("%-%-.*$", ""))
        end
        return out
    end

    -- Does the access ending at `pos` assign it (or a field in it)? `a.b[k].c = v`, `a.b, x = ...`.
    local function Assigns(line, pos)
        while true do
            local s, e = line:find("^%.[%a_][%w_]*", pos)
            if not s then s, e = line:find("^%b[]", pos) end
            if not s then break end
            pos = e + 1
        end
        local rest = line:sub(pos)
        if rest:find("^%s*=[^=]") then return true end
        return rest:find("^%s*,") and rest:find("[^=~<>]=[^=]") ~= nil
    end

    -- Every access: { file, line, scope ("char"/"global"), key, write }.
    local function Accesses()
        local out = {}
        for _, path in ipairs(Sources()) do
            local lines = Code(Read(path))
            local aliases = {}
            for _, line in ipairs(lines) do
                local a, scope = line:match("local%s+([%a_][%w_]*)%s*=%s*ns%.DB%.(%a+)%s*$")
                if a then aliases[a] = scope end
            end
            for n, line in ipairs(lines) do
                local function Scan(pattern, scope)
                    local init = 1
                    while true do
                        local s, e, key = line:find(pattern, init)
                        if not s then break end
                        out[#out + 1] = { file = path, line = n, scope = scope, key = key, write = Assigns(line, e + 1) }
                        init = e + 1
                    end
                end
                Scan("DB%.char%.([%a_][%w_]*)", "char")
                Scan("DB%.global%.([%a_][%w_]*)", "global")
                for a, scope in pairs(aliases) do Scan("%f[%w_]" .. a .. "%.([%a_][%w_]*)", scope) end
                -- (a key built at runtime, or the SavedVariables by name, can't be checked)
                if line:find("DB%.char%s*%[") or line:find("DB%.global%s*%[") then
                    out[#out + 1] = { file = path, line = n, scope = "char", key = "[dynamic]" }
                end
                if path ~= "Core/DB.lua" and (line:find("DyreparkenCharDB") or line:find("DyreparkenDB%f[^%w_]")) then
                    out[#out + 1] = { file = path, line = n, scope = "char", key = "[by name]" }
                end
            end
        end
        return out
    end

    local function OwnerFile(owner)
        for _, path in ipairs(H.TOC.files) do
            if path:match("([^/]+)%.lua$") == owner then return path end
        end
    end

    test("every saved key the code uses is declared in Core/DB.lua, with an owner that exists", function()
        local db = Read("Core/DB.lua")
        local declared = { char = Declared(db, "CHAR_DEFAULTS"), global = Declared(db, "ACCOUNT_DEFAULTS") }
        ok(next(declared.char) and next(declared.global), "the defaults were found")
        ok(declared.char.wish and declared.char.bondToday, "keys with a nil default are listed too")
        for scope, keys in pairs(declared) do
            for key, owner in pairs(keys) do
                ok(owner ~= "?" and OwnerFile(owner), ("%s.%s: its owner %s is a file in the TOC"):format(scope, key, tostring(owner)))
            end
        end
        local bad, n = {}, 0
        for _, a in ipairs(Accesses()) do
            n = n + 1
            if not declared[a.scope][a.key] then bad[#bad + 1] = ("%s:%d DB.%s.%s"):format(a.file, a.line, a.scope, a.key) end
        end
        ok(n > 100, "the scan finds the accesses (" .. n .. ")")
        eq(table.concat(bad, "\n"), "", "keys used but not declared in Core/DB.lua")
    end)

    test("only a saved key's owner writes it; the others ask the owner", function()
        local db = Read("Core/DB.lua")
        local declared = { char = Declared(db, "CHAR_DEFAULTS"), global = Declared(db, "ACCOUNT_DEFAULTS") }
        local bad, writes = {}, 0
        for _, a in ipairs(Accesses()) do
            local owner = declared[a.scope][a.key]
            if a.write and owner then
                writes = writes + 1
                if OwnerFile(owner) ~= a.file then
                    bad[#bad + 1] = ("%s:%d writes DB.%s.%s (owner: %s)"):format(a.file, a.line, a.scope, a.key, owner)
                end
            end
        end
        ok(writes > 20, "the scan finds the writes (" .. writes .. ")")
        eq(table.concat(bad, "\n"), "", "writes from outside the owner")
    end)

    test("the defaults apply: a new character has every table the modules index into", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        w:Run(5)
        local char, global = c.env.DyreparkenCharDB, c.env.DyreparkenDB
        eq(char.schema, c.ns.DB.CHAR_SCHEMA)
        eq(global.schema, c.ns.DB.SCHEMA)
        for _, k in ipairs({ "dislikes", "eggs", "firsts", "bondGains", "places", "lastPlace", "feats", "unlocksTold" }) do
            eq(type(char[k]), "table", k)
        end
        eq(char.wishes.n, 0)
        eq(char.wish, nil, "today's wish is made on demand (Wish:Today)")
    end)
end
