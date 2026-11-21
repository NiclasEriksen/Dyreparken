-- tools/sv.lua (2026-11-19): the saved data read outside the game: a summary, a check through today's code (what
-- a peer would refuse), and the editors' picks as Lua to paste.
return function(test, H)
    local ok, no = H.ok, H.no

    local function Run(flags)
        local p = io.popen("luajit tools/sv.lua " .. flags .. " 2>&1")
        local out = p:read("*a")
        p:close()
        return out
    end
    local function Has(out, text) ok(out:find(text, 1, true), ("%q not in:\n%s"):format(text, out)) end

    -- A small account: two members' claims, bonds (Kari Berg's far over what a bond can hold since it began),
    -- a name, an owned list; the picks, some already in the data, some not; a pick table no mapping knows.
    local function Files()
        local now = os.time()
        local day = now - 2 * 86400
        local account, char = os.tmpname(), os.tmpname()
        local f = io.open(account, "w")
        local text = ([[
DyreparkenDB = {
["schema"] = 14,
["guilds"] = {
["Dyreparken"] = {
["claims"] = { ["Ola Nord"] = { ["k"] = "s:5159", ["at"] = DAY, ["ts"] = DAY }, ["Kari Berg"] = { ["k"] = "s:40", ["at"] = DAY, ["ts"] = DAY } },
["lapses"] = {},
["names"] = { ["s:5159"] = { ["Ola Nord"] = { ["n"] = "Pepe", ["at"] = DAY } } },
["life"] = {
["s:5159"] = { ["Ola Nord"] = { ["p"] = 120, ["f"] = DAY, ["t"] = NOW } },
["s:40"] = { ["Kari Berg"] = { ["p"] = 99999, ["f"] = DAY, ["t"] = NOW } },
},
["owns"] = { ["Ola Nord"] = { ["at"] = DAY, ["s"] = "40,5159" } },
},
},
["scenePicks"] = { ["cat"] = 1984118, ["bird"] = 7963741, ["owl"] = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-Maraudon" },
["decorPicks"] = { ["border.cat"] = "atlas:loottoast-itemborder-gold", ["corner"] = "atlas:SomeCorner" },
["liftPicks"] = { [40] = 0.35 },
["movePicks"] = { [40] = { ["happy"] = 758 } },
["placePicks"] = { ["card"] = { [1268] = { ["floor"] = 0.45, ["size"] = 5.15 } } },
["modelPicks"] = { ["card"] = { ["-0.006 0.511 0.767"] = { ["floor"] = 0.6, ["size"] = 2.5 } } },
["oddPicks"] = { ["x"] = 1 },
}
DyreparkenDebugDB = { ["lines"] = { "a", "b" } }
]]):gsub("DAY", tostring(day)):gsub("NOW", tostring(now))
        f:write(text)
        f:close()
        f = io.open(char, "w")
        f:write('DyreparkenCharDB = { ["schema"] = 3 }\n')
        f:close()
        return account, char
    end

    test("summary: claims, bonds by carer, names, owners, and every saved table's size", function()
        local account, char = Files()
        local out = Run("--file " .. account)
        Has(out, "== Guild Dyreparken")
        Has(out, "Ola Nord               s:5159")
        Has(out, "Kari Berg                1   99999  s:40")
        Has(out, "«Pepe» by Ola Nord")
        Has(out, "Ola Nord                 2 species")
        Has(out, "-- DyreparkenDebugDB:")
        ok(out:find("\n  guilds +[%d%.]+ [KB]"), out)
        os.remove(account); os.remove(char)
    end)

    test("check: the saved data logs in through today's code, and what a peer would refuse is listed", function()
        local account, char = Files()
        local out = Run(("check --file %s --char %s --name 'Ola Nord'"):format(account, char))
        Has(out, "Ola Nord holds s:5159")
        Has(out, "-- Errors at login: 0")
        Has(out, "  life        2     2     1")
        Has(out, "  claims      2     2     0")
        Has(out, "s:40 Bombay by Kari Berg")
        Has(out, "over the cap")
        no(out:find("Ola Nord  {", 1, true), "Ola's own bond is fine")
        Has(out, "-- 1 problem(s).")
        os.remove(account); os.remove(char)
    end)

    test("picks: ready to paste, each saying whether the data has it, and a table it doesn't know raw", function()
        local account, char = Files()
        local out = Run("picks --file " .. account)
        Has(out, 'cat = { 1984118 },  -- (in the data already)  -- waycrestmanor wide')
        Has(out, 'bird = { 7963741 },  -- The Drowned City')
        -- A file's crop, from Dev/SceneArt.lua, for Scenes.ART.
        Has(out, "[7963741] = { 0, 1, 0.1571, 0.8429, 2992, 1155 },")
        ok(out:find('owl = { EJ .. "Maraudon" },\n', 1, true), out)
        Has(out, 'cat = { border = "loottoast-itemborder-gold" },  -- (in the data already)')
        ok(out:find('corner = "SomeCorner",\n', 1, true), out)
        ok(out:find("%[40%] = { lift = 0%.35, [^\n]*happy = 758[^\n]*},  %-%- Bombay\n"), out)
        Has(out, "[1268] = { floor = 0.45, size = 5.15 },  -- (in the data already)")
        Has(out, '["-0.006 0.511 0.767"] = { floor = 0.6, size = 2.5 },  -- 1270: Arctic Hare')
        Has(out, "-- oddPicks: tools/sv.lua doesn't know where it goes; raw:")
        os.remove(account); os.remove(char)
    end)
end
