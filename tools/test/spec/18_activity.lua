-- The activity engine (Core/Activity.lua): sources, on-demand events,
-- counting after combat, the daily visit, failure handling, and the
-- `activity` achievement kind.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"
    local ME = {} -- a consumer

    -- Ola with an adopted panda out; the debug log off, so nothing listens by itself.
    local function Setup(opts)
        local w, c = H.Setup{ ola = opts or { 5159, 46 }, settle = "hello" }
        c:Slash("adopter panda")
        c:Slash("debug off")
        -- The bond wants its activities while you have a pet (19_bond.lua): not here.
        for _, id in ipairs(c.ns.Bond.ACTIVITIES) do c.ns.Activity:Drop(id, c.ns.Bond) end
        -- Nor Quirks' (the panda's dislikes, the eggs': 29_quirks.lua).
        for _, k in ipairs(c.ns.Activity.KINDS) do
            c.ns.Activity:Drop(k.id, c.ns.Bond) -- (the panda's likes too: Klengete's cuddles, an emote, since 2026-11-19)
            c.ns.Activity:Drop(k.id, c.ns.Quirks)
            c.ns.Activity:Drop(k.id, c.ns.Achievements) -- (and the achievements': boss, pvp, quest)
        end
        return w, c, c.ns.Activity
    end


    test("idle without consumers; events come and go with Want and Drop", function()
        local w, c, A = Setup()
        for _, e in ipairs({ "ENCOUNTER_END", "CHAT_MSG_TEXT_EMOTE", "PLAYER_PVP_KILLS_CHANGED" }) do
            no(c:Listening(e), e .. " not registered")
        end
        A:Want("boss", ME)
        ok(c:Listening("ENCOUNTER_END")); ok(A:IsListening("ENCOUNTER_END"))
        no(c:Listening("CHAT_MSG_TEXT_EMOTE"))
        local other = {}
        A:Want("boss", other)
        A:Drop("boss", ME)
        ok(c:Listening("ENCOUNTER_END"), "still wanted by another")
        A:Drop("boss", other)
        no(c:Listening("ENCOUNTER_END"))
        -- The debug log wants everything.
        c:Slash("debug on")
        ok(c:Listening("ENCOUNTER_END")); ok(c:Listening("CHAT_MSG_TEXT_EMOTE"))
        c:Slash("debug off")
        no(c:Listening("CHAT_MSG_TEXT_EMOTE"))
    end)

    test("an undeclared activity fails loudly, before any listener sees it", function()
        local w, c = H.Setup{ ola = { 5159 }, settle = "hello" }
        local heard = 0
        c.ns.Bus:On("ACTIVITY", function() heard = heard + 1 end)
        local fine, err = pcall(c.ns.Activity.Emit, c.ns.Activity, "nosuchthing")
        no(fine)
        match(tostring(err), "declare nosuchthing")
        eq(heard, 0)
    end)

    test("a boss kill in combat counts once combat ends, with the pet that was out", function()
        local w, c, A = Setup()
        A:Want("boss", ME)
        local seen = {}
        c.ns.Bus:On("ACTIVITY", function(...) seen[#seen + 1] = { ... } end)
        c:EnterCombat()
        c:Fire("ENCOUNTER_END", 1084, "Hogger", 1, 5, 1)
        eq(A:Count("boss"), 0, "not while in combat")
        c:LeaveCombat()
        local total, mine, today, panda = A:Count("boss", PANDA)
        eq(total, 1); eq(mine, 1, "with the adopted pet out"); eq(today, 1); eq(panda, 1)
        eq(seen[1][1], "boss"); eq(seen[1][2], 1); eq(seen[1][3], PANDA); eq(seen[1][4], true)
        -- A wipe, a secret result: nothing.
        c:Fire("ENCOUNTER_END", 1084, "Hogger", 1, 5, 0)
        c:Fire("ENCOUNTER_END", 1084, "Hogger", 1, 5, H.SECRET)
        eq(A:Count("boss"), 1)
        -- Another companion out: counted, but not as "mine".
        c:Summon(46)
        c:Fire("ENCOUNTER_END", 1085, "Van Cleef", 1, 5, 1)
        total, mine = A:Count("boss")
        eq(total, 2); eq(mine, 1)
        eq(select(4, A:Count("boss", "s:46")), 1)
        -- No companion at all.
        c:Summon(nil)
        c:Fire("ENCOUNTER_END", 1086, "Mr. Smite", 1, 5, 1)
        eq(A:Count("boss"), 3)
        -- Saved per character.
        c:Reload()
        eq(c.ns.Activity:Count("boss"), 3)
    end)

    test("quests count; today starts over each day", function()
        local w, c, A = Setup()
        A:Want("quest", ME)
        c:Fire("QUEST_TURNED_IN", 176, 450, 0)
        c:Fire("QUEST_TURNED_IN", H.SECRET, 0, 0)
        local total, _, today = A:Count("quest")
        eq(total, 2); eq(today, 2)
        w:SkipDays(1)
        total, _, today = A:Count("quest")
        eq(total, 2); eq(today, 0, "a new day")
        c:Fire("QUEST_TURNED_IN", 177)
        eq(select(3, A:Count("quest")), 1)
        eq(A:Count("never-seen"), 0)
    end)

    test("honorable kills count the rise in the session counter", function()
        local w, c, A = Setup()
        c.state.hk = 3
        A:Want("pvp", ME)
        c.state.hk = 5
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(A:Count("pvp"), 2, "from the counter when watching began")
        c.state.hk = 0
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(A:Count("pvp"), 2, "a new session starts at 0: nothing")
        c.state.hk = 1
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(A:Count("pvp"), 3)
        ok(A:Available("pvp"))
        c.env.GetPVPSessionStats = nil
        no(A:Available("pvp"), "no counter: unavailable")
        c:Fire("PLAYER_PVP_KILLS_CHANGED")
        eq(A:Count("pvp"), 3)
    end)

    -- A flight: the take-off (the hook; mounted on the taxi), then the landing (off the taxi, dismounted).
    local function Fly(w, c, node, long)
        c.env.TakeTaxiNode(node)
        c:Mount(); w:Run(long or 0)
        c.state.taxi = false
        c:Dismount(); w:Run(3)
    end

    test("flight paths come from a hook that does nothing unless wanted, and count as you land", function()
        local w, c, A = Setup()
        eq(A:Wanted().taxi, nil, "(nobody else wants it yet)")
        Fly(w, c, 1)
        eq(A:Count("taxi"), 0)
        A:Want("taxi", ME)
        Fly(w, c, 2)
        eq(A:Count("taxi"), 1)
        A:Drop("taxi", ME)
        eq(A:Wanted().taxi, nil)
        Fly(w, c, 3)
        eq(A:Count("taxi"), 1, "hooked for good, but idle")
        A:Want("taxi", ME)
        -- (2026-11-18, the user: "kissed the ground after landing" a few seconds into the flight)
        local before = A:Count("taxi")
        local watched = A:Wanted() and c.ns.Events:Registered()["PLAYER_MOUNT_DISPLAY_CHANGED"] or 0
        c.env.TakeTaxiNode(4)
        c:Mount(); w:Run(60)
        eq(A:Count("taxi"), before, "not while flying")
        eq(c.ns.Events:Registered()["PLAYER_MOUNT_DISPLAY_CHANGED"], watched + 1, "the landing watched, only now")
        c.state.taxi = false
        c:Dismount(); w:Run(1)
        eq(A:Count("taxi"), before, "on your feet first")
        w:Run(2)
        eq(A:Count("taxi"), before + 1, "landed, once (hooked once)")
        eq(c.ns.Events:Registered()["PLAYER_MOUNT_DISPLAY_CHANGED"], watched, "the watch ended")
        c:Mount(); c:Dismount(); w:Run(5)
        eq(A:Count("taxi"), before + 1, "only the flight's own landing")
        -- Control gained off the taxi lands it too.
        c.env.TakeTaxiNode(5); w:Run(30)
        c.state.taxi = false
        c:Fire("PLAYER_CONTROL_GAINED"); w:Run(3)
        eq(A:Count("taxi"), before + 2, "control back")
        local w2 = H.World()
        local c2 = w2:AddClient("Kari Berg", { patch = function(env) env.TakeTaxiNode = nil end })
        w2:Settle("hello")
        no(c2.ns.Activity:Available("taxi"))
        c2.ns.Activity:Want("taxi", ME)
    end)

    test("a flight counts only once the taxi was seen: not a dismount before take-off, not a node that failed", function()
        local w, c, A = Setup()
        A:Want("taxi", ME)
        local before = A:Count("taxi")
        -- Mounted at the flight master: picking the node dismounts you before the taxi starts (review 2026-11-19).
        c:Mount()
        c.env.TakeTaxiNode(1)
        c.state.taxi = false
        c:Dismount(); w:Run(3)
        eq(A:Count("taxi"), before, "not at take-off")
        c.state.taxi = true; w:Run(40) -- (seen by the read a few seconds after the take-off, no event needed)
        c.state.taxi = false
        c:Fire("PLAYER_CONTROL_GAINED"); w:Run(3)
        eq(A:Count("taxi"), before + 1, "the landing")
        -- A node that fails (no money): no take-off, and the watch ends unused.
        c.env.TakeTaxiNode(2)
        c.state.taxi = false
        ok(c:Listening("PLAYER_CONTROL_GAINED"))
        w:Run(A.TAKEOFF_WITHIN + 1)
        no(c:Listening("PLAYER_CONTROL_GAINED"), "given up")
        c:Mount(); c:Dismount(); w:Run(5)
        eq(A:Count("taxi"), before + 1, "no flight that never was")
    end)

    test("the daily visit: once a day per companion out", function()
        local w, c, A = Setup()
        A:Want("day", ME)
        A:CheckDay()
        eq(A:Count("day"), 1)
        A:CheckDay()
        eq(A:Count("day"), 1, "once a day")
        w:SkipDays(1)
        c:Summon(46)
        A:CheckDay()
        eq(A:Count("day"), 2, "another companion has its own day")
        A:CheckDay()
        eq(A:Count("day"), 2, "once")
        -- Summoning the panda: checked a moment later.
        c.env.C_PetJournal.SummonPetByGUID(c:GuidOf(5159))
        c:Summon(5159)
        w:Run(3)
        eq(A:Count("day"), 3)
        -- After a login, by itself.
        w:SkipDays(1)
        c:Reload()
        c.ns.Activity:Want("day", ME)
        w:Run(35)
        eq(c.ns.Activity:Count("day"), 4, "after a login, by itself")
        -- Unwanted: not counted.
        c.ns.Activity:Drop("day", ME)
        c.ns.Activity:Drop("day", c.ns.Bond) -- the bond wants it too while you have a pet
        w:SkipDays(1)
        c.ns.Activity:CheckDay()
        eq(c.ns.Activity:Count("day"), 4, "unwanted: not counted")
    end)

    test("a missing event makes its activity unavailable; a broken filter switches off once", function()
        local w, c, A = Setup()
        A.KIND.ghost, A.KIND.bad = { id = "ghost" }, { id = "bad" } -- (test kinds)
        no(pcall(A.Source, A, { id = "undeclared", events = {}, filter = function() end }), "a kind must be declared")
        A:Source({ id = "ghost", events = { "NO_SUCH_EVENT" }, filter = function() return 1 end })
        A:Want("ghost", ME)
        no(A:Available("ghost"))
        no(A:IsListening("NO_SUCH_EVENT"))
        no(A:Available("nothing-declared"))
        local calls = 0
        A:Source({ id = "bad", events = { "QUEST_TURNED_IN" }, filter = function()
            calls = calls + 1
            error("boom")
        end })
        A:Want("bad", ME)
        A:Want("quest", ME)
        c:Fire("QUEST_TURNED_IN", 1)
        c:Fire("QUEST_TURNED_IN", 2)
        eq(calls, 1, "switched off after the first error")
        no(A:Available("bad"))
        eq(#c:Log("bad switched off: "), 0, "the log is off")
        eq(A:Count("quest"), 2, "the other source on the same event goes on")
        eq(#c:TakeErrors(), 0, "no Lua errors")
    end)

    test("debug on logs every activity", function()
        local w, c, A = Setup()
        c:Slash("debug on")
        c:Fire("ENCOUNTER_END", 1084, "Hogger", 1, 5, 1)
        eq(#c:Log("boss %+1 pet=s:5159 mine=true Hogger"), 1)
    end)

    test("activity achievements: hidden when unavailable, earned from the counters", function()
        local w, c, A = Setup()
        local Ach = c.ns.Achievements
        local d = { id = "test:boss", kind = "activity", act = "boss", n = 2, pet = true, scope = "char",
            cat = "loyalty" }
        table.insert(c.ns.AchDefs, d)
        Ach.defsById[d.id] = d
        c.ns.AchTexts[d.id] = { name = "Bosskamerat", desc = "To bosser med dyret ute." }
        Ach:WatchActivities()
        Ach:WatchActivities()
        Ach:Check("login", "char") -- its first look, as at login (a first look is quiet)
        ok(c:Listening("ENCOUNTER_END"), "watched for the achievement")
        local done, have, need = Ach:Evaluate(d, {})
        eq(done, false); eq(have, 0); eq(need, 2)
        c:Fire("ENCOUNTER_END", 1, "A", 1, 5, 1)
        c:Summon(46)
        c:Fire("ENCOUNTER_END", 2, "B", 1, 5, 1)
        no(Ach:Got("test:boss"), "only one with the adopted pet out")
        c:Summon(5159)
        c:Fire("ENCOUNTER_END", 3, "C", 1, 5, 1)
        w:Run(2)
        ok(Ach:Got("test:boss"))
        ok(c:Printed("[Bosskamerat]", true))
        local any = { id = "test:quest", kind = "activity", act = "pvp", n = 1 }
        c.env.GetPVPSessionStats = nil
        eq(Ach:Evaluate(any, {}), nil, "hidden while unavailable")
    end)
end
