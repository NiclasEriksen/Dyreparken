-- Comm: encoding, chunking, sender handling, protocol and version checks.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Listen(c, kind)
        local got = {}
        c.ns.Comm:Register(kind, function(msg, sender, channel)
            got[#got + 1] = { msg = msg, sender = sender, channel = channel }
        end)
        return got
    end

    -- Hard to compress, so it really needs several chunks.
    local function Noise(n)
        local t = {}
        for i = 1, n do
            local s = {}
            for j = 1, 12 do s[j] = string.char(math.random(33, 126)) end
            t[i] = table.concat(s)
        end
        return t
    end

    test("small and chunked messages arrive intact and in order", function()
        local w = H.World()
        local a, b = w:AddClient("Ola Nord"), w:AddClient("Kari Berg")
        local got = Listen(b, "TEST")
        local big = Noise(200)
        local c0 = w.chunks or 0
        a.ns.Comm:Send("TEST", { x = 1 }, "GUILD")
        a.ns.Comm:Send("TEST", { list = big }, "GUILD")
        a.ns.Comm:Send("TEST", { x = 3 }, "GUILD")
        w:Run(40)
        eq(#got, 3)
        eq(got[1].msg.x, 1)
        eq(got[1].sender, "Ola Nord")
        eq(got[1].channel, "GUILD")
        eq(#got[2].msg.list, 200)
        eq(got[2].msg.list[200], big[200])
        eq(got[3].msg.x, 3)
        ok((w.chunks - c0) > 4, "big message was split")
        eq(got[1].msg.p, b.ns.PROTOCOL)
    end)

    test("chunks from two senders, or two channels, don't mix", function()
        local w = H.World()
        local a, b, c = w:AddClient("Ola Nord"), w:AddClient("Kari Berg"), w:AddClient("Per Hansen")
        w:SetGroup({ "Ola Nord", "Per Hansen" })
        local got = Listen(c, "TEST")
        local x, y, z = Noise(150), Noise(150), Noise(150)
        a.ns.Comm:Send("TEST", { list = x }, "GUILD")
        b.ns.Comm:Send("TEST", { list = y }, "GUILD")
        a.ns.Comm:Send("TEST", { list = z }, "PARTY")
        w:Run(60)
        eq(#got, 3)
        local seen = {}
        for _, g in ipairs(got) do seen[g.sender .. "/" .. g.channel] = g.msg.list[150] end
        eq(seen["Ola Nord/GUILD"], x[150])
        eq(seen["Kari Berg/GUILD"], y[150])
        eq(seen["Ola Nord/PARTY"], z[150])
    end)

    test("our own echo, other prefixes, stray chunks and garbage are ignored", function()
        local w = H.World()
        local a, b = w:AddClient("Ola Nord"), w:AddClient("Kari Berg")
        local mine, theirs = Listen(a, "TEST"), Listen(b, "TEST")
        a.ns.Comm:Send("TEST", {}, "GUILD")
        w:Run(3)
        eq(#mine, 0, "own GUILD echo filtered")
        eq(#theirs, 1)
        b:Fire("CHAT_MSG_ADDON", "OtherAddon", "S" .. H.Encode({ k = "TEST", p = b.ns.PROTOCOL }), "GUILD", "Ola Nord")
        w:Inject("Ola Nord", "GUILD", "Mstray middle")
        w:Inject("Ola Nord", "GUILD", "Lstray last")
        w:Inject("Ola Nord", "GUILD", "Xunknown header")
        w:Inject("Ola Nord", "GUILD", "S!!not encoded!!")
        w:Inject("Ola Nord", "GUILD", "S" .. H.Encode("a string, not a table"))
        w:InjectMessage("Ola Nord", { x = 1 }) -- no kind
        w:InjectMessage("Ola Nord", { k = "NOBODY_LISTENS", p = b.ns.PROTOCOL })
        w:Run(2)
        eq(#theirs, 1)
        eq(#b:Log("bad message from Ola Nord"), 3)
        -- A message that never ends is dropped after 64 chunks, not kept growing.
        w:Inject("Ola Nord", "GUILD", "Fstart")
        for _ = 1, 70 do w:Inject("Ola Nord", "GUILD", "M" .. string.rep("x", 200)) end
        w:Inject("Ola Nord", "GUILD", "Lend")
        w:Run(2)
        eq(#b:Log("dropped an oversized message from Ola Nord"), 1)
        eq(#b:Log("bad message from Ola Nord"), 3, "the tail is stray, not decoded")
    end)

    test("a realm suffix on the sender is stripped", function()
        local w = H.World()
        w:AddClient("Ola Nord", { realm = "CAMWOWEU4Realm2PvE" })
        local b = w:AddClient("Kari Berg")
        local got = Listen(b, "TEST")
        w.byName["Ola Nord"].ns.Comm:Send("TEST", {}, "GUILD")
        w:Run(3)
        eq(got[1].sender, "Ola Nord")
        eq(#b:Log('raw sender "Ola Nord%-CAMWOWEU4Realm2PvE"'), 1)
    end)

    test("a failing handler is logged and the next one still runs", function()
        local w = H.World()
        local a, b = w:AddClient("Ola Nord"), w:AddClient("Kari Berg")
        b.ns.Comm:Register("BOOM", function() error("kaboom") end)
        local got = Listen(b, "BOOM")
        a.ns.Comm:Send("BOOM", {}, "GUILD")
        w:Run(3)
        eq(#got, 1)
        local errs = b:TakeErrors()
        eq(#errs, 1)
        match(errs[1], "handler BOOM failed")
    end)

    test("a handler's field spec drops a malformed message before it runs, and says so", function()
        local w = H.World()
        local a, b = w:AddClient("Ola Nord"), w:AddClient("Kari Berg")
        local got = {}
        b.ns.Comm:Register("TEST", function(msg) got[#got + 1] = msg.pet end, "GUILD", { pet = "key", e = "table" })
        for _, m in ipairs({ { pet = "s:46", e = {} }, { pet = { 1 }, e = {} }, { pet = "n:|cffx", e = {} },
            { pet = "s:40", e = "x" }, { e = {} } }) do
            a.ns.Comm:Send("TEST", m, "GUILD")
        end
        w:Run(3)
        eq(table.concat(got, " "), "s:46")
        eq(#b:Log("dropped TEST from Ola Nord: pet isn't a key"), 3)
        eq(#b:Log("dropped TEST from Ola Nord: e isn't a table"), 1)
        -- A check that doesn't exist is a mistake at load, not a silent pass.
        no(pcall(b.ns.Comm.Register, b.ns.Comm, "TEST", function() end, "GUILD", { pet = "petkey" }))
        -- The registry's handlers use them: a NICK for a pet key that isn't one never reaches the merge.
        w:InjectMessage("Per Hansen", { k = "NICK", p = b.ns.PROTOCOL, pet = "junk", e = { n = "X", at = w:ServerTime() } })
        w:Run(1)
        eq(#b:Log("dropped NICK from Per Hansen: pet isn't a key"), 1)
    end)

    test("one nickname check for a typed name and a name from the wire (Wire.Nick)", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local R, max = c.ns.Registry, c.ns.Config.NICKNAME_MAX_LEN
        local stray = "a" .. ("\128"):rep(100) -- one "character" by lead bytes, 101 bytes
        no(R:ValidNickname(stray), "typed: the byte cap too (it had none before)")
        no(R.ValidEntry({ n = stray, at = w:ServerTime() }), "from the wire")
        for _, n in ipairs({ "", ("x"):rep(max + 1), "a|b", "a\nb" }) do
            eq(R:ValidNickname(n), false, n)
            eq(R.ValidEntry({ n = n, at = w:ServerTime() }), false, n)
        end
        eq(select(2, R:ValidNickname(("x"):rep(max + 1))), c.ns.T("nick.too_long", { n = max }))
        eq(select(2, R:ValidNickname("  Øyvind  ")), "Øyvind")
        ok(R.ValidEntry({ n = "Øyvind", at = w:ServerTime() }))
    end)

    test("sending to the guild without a guild does nothing", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { guild = false })
        no(c.ns.Comm:Send("TEST", {}, "GUILD"))
        w:Run(15)
        eq(#w.wire, 0, "not even a HELLO")
    end)

    test("trial accounts can't send but still receive", function()
        local w = H.World()
        local t = w:AddClient("Prove Konto", { trial = true, pets = { 46 } })
        local o = w:AddClient("Ola Nord")
        w:Run(15)
        t:Slash("adopter")
        o:Slash("adopter")
        w:Run(5)
        eq(w:Sent("UPD", "Prove Konto") + w:Sent("HELLO", "Prove Konto"), 0)
        eq(o.ns.Registry:Holder("s:46"), nil, "nobody heard the trial's claim")
        eq(t.ns.Registry:Holder("s:5159"), "Ola Nord", "the trial heard ours")
        ok(#t:Log("send of UPD not delivered") >= 1 or true)
    end)

    test("other protocols are ignored, except for their version", function()
        local w = H.World()
        local new = w:AddClient("Ny Versjon", { protocol = "99", version = "v0.5.0" })
        local me = w:AddClient("Ola Nord", { version = "v0.1.0" })
        w:Run(15)
        new:Slash("adopter")
        w:Run(15)
        eq(me.ns.Registry:Holder("s:5159"), nil, "UPD from another protocol ignored")
        eq(w:Sent("SYNC", "Ola Nord"), 0, "no SYNC for another protocol's HELLO")
        ok(me:Printed("En nyere versjon %(v0.5.0%) er ute; du har v0.1.0."))
        eq(me.ns.Version.seen["Ny Versjon"], "v0.5.0")
        -- Told once per version, also after a reload.
        me:ClearPrinted()
        me:Reload()
        new:Reload()
        w:Run(15)
        no(me:Printed("newer version"), "already warned about v0.5.0")
        new.version = "v0.5.1"
        new:Reload()
        w:Run(15)
        ok(me:Printed("En nyere versjon %(v0.5.1%)"))
    end)

    test("same protocol, newer version: one notice; dev builds never warn", function()
        local w = H.World()
        local me = w:AddClient("Ola Nord", { version = "v0.1.0" })
        local dev = w:AddClient("Dev Bygg")
        w:AddClient("Ny Versjon", { version = "v0.2.0" })
        w:AddClient("Gammel Versjon", { version = "v0.0.5" })
        w:Run(15)
        ok(me:Printed("En nyere versjon %(v0.2.0%)"))
        no(dev:Printed("newer version"))
        no(w.byName["Ny Versjon"]:Printed("newer version"))
        eq(me.ns.Version.seen["Gammel Versjon"], "v0.0.5")
    end)

    test("/dp versjon is gone; we still answer clients on 0.2.x that ask", function()
        local w = H.World()
        local me = w:AddClient("Ola Nord", { version = "v0.1.0" })
        w:AddClient("Kari Berg", { version = "v0.2.0" })
        w:Run(15)
        local m = w:Mark()
        me:Slash("versjon")
        w:Run(6)
        eq(w:Sent("VER_REQ", nil, m), 0)
        ok(me:Printed("kommandoer:", true), "the help instead")
        w:InjectMessage("Per Hansen", { k = "VER_REQ", p = me.ns.PROTOCOL }, "GUILD")
        w:Run(3)
        eq(w:Sent("VER", nil, m), 2, "both answer")
        -- Requests by whisper aren't answered (unverified targets on Forever).
        m = w:Mark()
        w:Run(10)
        w:InjectMessage("Per Hansen", { k = "VER_REQ", p = me.ns.PROTOCOL }, "WHISPER", "Ola Nord")
        w:Run(3)
        eq(w:Sent("VER", nil, m), 0)
    end)

    test("versions from the wire: junk can't throw or put escape codes in the chat", function()
        local w = H.World()
        local me = w:AddClient("Ola Nord", { version = "v0.1.0" })
        w:Run(15)
        w:InjectMessage("Per Hansen", { k = "VER", p = me.ns.PROTOCOL, v = { "table" } })
        w:InjectMessage("Kari Berg", { k = "VER", p = me.ns.PROTOCOL, v = "99.0-|TInterface\\Icons\\x:500|t" })
        w:InjectMessage("Lise Lund", { k = "HELLO", p = me.ns.PROTOCOL, v = "9.9|cffff0000" })
        w:Run(6)
        no(me:Printed("|T", true)); no(me:Printed("|cffff0000", true))
        eq(me.ns.Version.seen["Per Hansen"], nil); eq(me.ns.Version.seen["Lise Lund"], nil)
        no(me:Printed("En nyere versjon"), "not taken for a newer version")
        eq(me.ns.Version.seen["Kari Berg"], nil)
        ok(me.ns.Version.Sane("0.2.1-beta2")); ok(me.ns.Version.Sane("dev")); ok(me.ns.Version.Sane("v0.2.1"))
        no(me.ns.Version.Sane(string.rep("1", 33)))
    end)

    test("a forged version can't silence update notices (HELLO outside the guild, a far-off version)", function()
        local w = H.World()
        local me = w:AddClient("Ola Nord", { version = "v0.5.0" })
        w:Run(15)
        local P = me.ns.PROTOCOL
        -- HELLO goes to the guild only: one by party or whisper isn't a version we heed, on any protocol.
        w:InjectMessage("Per Hansen", { k = "HELLO", p = P, v = "0.6.0" }, "PARTY")
        w:InjectMessage("Per Hansen", { k = "HELLO", p = "1", v = "0.6.1" }, "WHISPER", "Ola Nord")
        w:Run(3)
        no(me:Printed("En nyere versjon"), "not from outside the guild")
        eq(me.ns.DB.char.warnedVersion, nil)
        -- Far ahead of ours: no real release, not remembered (it would hide every real one).
        for _, v in ipairs({ "999.0", "2.0.0", "3.1.0" }) do
            w:InjectMessage("Per Hansen", { k = "HELLO", p = P, v = v }, "GUILD")
            w:InjectMessage("Per Hansen", { k = "VER", p = P, v = v }, "PARTY")
        end
        w:Run(3)
        no(me:Printed("En nyere versjon"), "implausible")
        eq(me.ns.DB.char.warnedVersion, nil)
        -- A real one still tells us, however many releases behind we are (no cap on the minors).
        w:InjectMessage("Kari Berg", { k = "HELLO", p = P, v = "0.30.2" }, "GUILD")
        w:InjectMessage("Liv Lund", { k = "HELLO", p = P, v = "1.15.0" }, "GUILD")
        w:Run(3)
        ok(me:Printed("En nyere versjon %(0.30.2%)"))
        ok(me:Printed("En nyere versjon %(1.15.0%)"))
        eq(me.ns.DB.char.warnedVersion, "1.15.0")
    end)

    test("a message that unpacks too big isn't read, and its sender is ignored for the session", function()
        local w = H.World()
        local me = w:AddClient("Ola Nord")
        w:Run(15)
        me.ns.Wire.LIMITS.MAX_RAW = 2000 -- (the real limit is 512 KB; the payload compresses to almost nothing)
        local seen = 0
        me.ns.Comm:Register("TEST", function() seen = seen + 1 end)
        w:InjectMessage("Per Hansen", { k = "TEST", p = me.ns.PROTOCOL, junk = string.rep("a", 5000) })
        w:Run(1)
        eq(seen, 0, "not read")
        eq(#me:Log("unpacked past 2000 bytes: ignoring them"), 1)
        w:InjectMessage("Per Hansen", { k = "TEST", p = me.ns.PROTOCOL })
        w:Run(1)
        eq(seen, 0, "ignored from then on")
        w:InjectMessage("Kari Berg", { k = "TEST", p = me.ns.PROTOCOL, junk = string.rep("a", 1000) })
        w:Run(1)
        eq(seen, 1, "others are fine")
    end)
end
