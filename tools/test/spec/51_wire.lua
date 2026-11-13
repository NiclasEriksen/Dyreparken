-- The wire, pinned: what a SYNC and a HELLO carry for a fixed world (written before Sync.TABLES
-- replaced the hand-listed stores, 2026-11-12), so a refactor can't change what peers see. The
-- digest changed with X-Protocol 10 (a claim's line carries its date and pet too).
-- The real bytes depend on table order (LibSerialize walks pairs, which differs between runs
-- and clients), so the pin is each decoded message written out with sorted keys: the same
-- content, the same types, the same layout in parts.
return function(test, H)
    local eq = H.eq

    -- Sorted keys (numbers before strings), typed values: one text for one content.
    -- (proto: the message's own protocol shows as PROTOCOL, so a bump alone doesn't touch the pin)
    local function Dump(v, proto)
        local t = type(v)
        if t == "string" then return ("%q"):format(v) end
        if t == "number" then return ("%.17g"):format(v) end
        if t ~= "table" then return tostring(v) end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            if type(a) ~= type(b) then return type(a) == "number" end
            return a < b
        end)
        local out = {}
        for _, k in ipairs(keys) do
            out[#out + 1] = "[" .. Dump(k) .. "]=" .. ((proto and k == "p" and v[k] == proto) and "PROTOCOL" or Dump(v[k]))
        end
        return "{" .. table.concat(out, ",") .. "}"
    end

    -- Ola knows a little of everything a SYNC carries; Kari logs in knowing nothing.
    local function World()
        local w = H.World()
        for _, name in ipairs({ "Per Hansen", "Liv Lund", "Bo Berg", "Gammel Kar" }) do w:AddMember(name, 0) end
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 46 }, login = false })
        w:Settle("day")
        local R, T0 = ola.ns.Registry, 1790000000
        R:MergeRecord("Per Hansen", { k = "s:5159", at = T0 + 10, ts = T0 + 20 })
        R:MergeRecord("Liv Lund", { k = "s:46", at = T0 + 11, ts = T0 + 21 })
        R:MergeRecord("Bo Berg", { at = T0 + 5, ts = T0 + 30 })
        R:MergeRecord("Gammel Kar", { k = "s:40", at = T0 + 1, ts = T0 + 2 })
        R:MergeLapse("Gammel Kar", T0 + 50)
        R:MergeName("s:5159", "Per Hansen", { n = "Bambus", at = T0 + 25 })
        R:MergeName("s:46", "Bo Berg", { n = "Pus", at = T0 + 3, x = true })
        R:MergeLife("s:5159", "Per Hansen", { p = 120, f = T0, t = T0 + 40 })
        R:MergeLife("s:46", "Liv Lund", { p = 20, f = T0, t = T0 + 40 })
        R:MergeLife("s:40", "Bo Berg", { p = 5, f = T0, t = T0 + 40 }) -- not a holder's: not in the SYNC
        ola.ns.Achievements:MergeGuild({ ["guild:family:cat"] = { at = T0 + 60, ann = T0 + 70 },
            ["guild:future:x"] = { at = T0 + 61 } })
        R:Changed()
        w:Run(10)
        local m = w:Mark()
        kari:Login()
        w:Run(40)
        return w, ola, kari, m
    end

    local PINNED = {
        [==[HELLO {["d"]=0,["k"]="HELLO",["p"]=PROTOCOL,["v"]="dev"}]==],
        [==[SYNC {["a"]={["guild:family:cat"]={["ann"]=1790000070,["at"]=1790000060},["guild:future:x"]={["at"]=1790000061}},["i"]=1,["k"]="SYNC",["l"]={["Gammel Kar"]=1790000050},["of"]=3,["p"]=PROTOCOL,["r"]={["Bo Berg"]={["at"]=1790000005,["ts"]=1790000030},["Gammel Kar"]={["at"]=1790000001,["k"]="s:40",["ts"]=1790000002},["Liv Lund"]={["at"]=1790000011,["k"]="s:46",["ts"]=1790000021},["Per Hansen"]={["at"]=1790000010,["k"]="s:5159",["ts"]=1790000020}}}]==],
        [==[SYNC {["i"]=2,["k"]="SYNC",["n"]={["s:46"]={["Bo Berg"]={["at"]=1790000003,["n"]="Pus",["x"]=true}},["s:5159"]={["Per Hansen"]={["at"]=1790000025,["n"]="Bambus"}}},["of"]=3,["p"]=PROTOCOL}]==],
        [==[SYNC {["b"]={["s:46"]={["Liv Lund"]={["f"]=1790000000,["p"]=20,["t"]=1790000040}},["s:5159"]={["Per Hansen"]={["f"]=1790000000,["p"]=120,["t"]=1790000040}}},["d"]=2218613292,["i"]=3,["k"]="SYNC",["of"]=3,["p"]=PROTOCOL}]==],
        [==[digest 2218613292]==],
    }

    test("a SYNC and a HELLO carry exactly what they carried before Sync.TABLES", function()
        local w, ola, kari, m = World()
        local seen = {}
        for i = m + 1, #w.wire do
            local x = w.wire[i]
            if (x.kind == "SYNC" and x.from == "Ola Nord") or (x.kind == "HELLO" and x.from == "Kari Berg") then
                seen[#seen + 1] = x.kind .. " " .. Dump(x.msg, ola.ns.PROTOCOL)
            end
        end
        seen[#seen + 1] = "digest " .. Dump(ola.ns.Sync:Digest())
        if #PINNED == 0 then print(table.concat(seen, "\n")) end
        eq(#seen, #PINNED, "messages")
        for i, line in ipairs(PINNED) do eq(seen[i], line, "message " .. i) end
        H.assertConverged(w)
    end)
end
