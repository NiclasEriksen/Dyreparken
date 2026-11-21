-- /dp probe verify (Dev/Verify.lua, 2026-11-20, the user): one checklist of everything unconfirmed in game, each
-- item ticking itself the first time it happens (a log line, an event, an answer read now, or by hand), kept
-- account-wide, on again at each login until turned off.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local function Setup()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("probe verify")
        return w, ola, ola.ns.Verify
    end
    local function State(V, id) return (V:State(assert(V.BY[id], id))) end

    test("on: debug on, a summary, every activity with what to do; on again after a reload", function()
        local w, ola, V = Setup()
        ok(ola.ns.Debug.enabled, "the debug log on")
        match(table.concat(ola.printed, "\n"), "Verify: %d+ of %d+ confirmed%. Open: activity %d+")
        for _, k in ipairs(ola.ns.Activity.KINDS) do
            ok(V.HOW[k[1]], "what to do for " .. k[1])
        end
        for _, area in ipairs({ "activity", "api", "react", "egg", "zone", "route", "look", "new" }) do
            local n = 0
            for _, item in ipairs(V.ITEMS) do if item.area == area then n = n + 1 end end
            ok(n > 0, "items in " .. area)
        end
        ok(ola:Listening("PLAYER_CONTROL_GAINED"), "its own events heard")
        ola:Reload(); w:Settle("hello")
        ok(ola.ns.Verify.armed, "on again at the login"); ok(ola:Listening("PLAYER_CONTROL_GAINED"))
        ola:Slash("probe verify off")
        no(ola.ns.Verify.armed); no(ola:Listening("PLAYER_CONTROL_GAINED")); eq(ola.ns.Debug.tap, nil)
        ola:Reload(); w:Settle("hello")
        no(ola.ns.Verify.armed, "off stays off")
    end)

    test("each way of ticking: a log line, an event, a unit's event, a zone, by hand; kept, said once", function()
        local w, ola, V = Setup()
        local ns = ola.ns
        -- An activity counted (its log line).
        eq(State(V, "activity:dance"), "open")
        ns.Activity:Emit("dance", 1); w:Run(1)
        eq(State(V, "activity:dance"), "seen")
        ok(ola:Printed("Verify: activity:dance (dance +1 pet=s:5159", true))
        ns.Activity:Emit("dance", 1); w:Run(1)
        eq(ola:CountPrinted("Verify: activity:dance"), 1, "said once")
        -- Counted before (this character's counters): done, nothing to do.
        ns.DB.char.activity.skin = { total = 2, mine = 2, pets = {} }
        eq(State(V, "activity:skin"), "before")
        -- An egg's moment rolled, a reaction sensed (held back by its roll: the sensor worked), a ride's route.
        ns.Log("Moments", "egg:baal: today's roll lost (25%%)")
        eq(State(V, "egg:baal"), "seen")
        ns.Log("Reactions", "krigsrop: not today (the day's roll) (Battle Shout)")
        eq(State(V, "react:krigsrop"), "seen", "a warrior's")
        no(V.BY["react:spokelsesulv"], "not another class's")
        ns.Log("Voyage", "boat: The Barrens at 0.72,0.48 -> Stranglethorn Vale at 0.2,0.88")
        eq(State(V, "route:boat:Stranglethorn Vale-The Barrens"), "seen", "either way")
        ns.Log("Activity", "eat: Refreshment is spell 1234")
        eq(State(V, "api:refreshment"), "seen")
        -- A fire's buff renewed, and its names collected.
        ns.Log("Aura", "camp on: Camp Benefits 1229741, 7200 of 7200 s left")
        ns.Log("Aura", "camp renewed: Camp Benefits 1229741, 180 s were left, now 3600")
        eq(State(V, "api:camprenew"), "seen")
        eq(#ola.env.DyreparkenDebugDB.verify.seen["api:campbuffs"].details, 2)
        -- What comes as a countdown ends, whatever it's called; not any other time.
        local gain = { addedAuras = { { name = "Camp Spirit", spellId = 1229999, duration = 3600 } } }
        ola:Fire("UNIT_AURA", "player", gain); w:Run(1)
        eq(State(V, "api:campgain"), "open", "no countdown ended")
        ns.Log("Aura", "campwarm off"); w:Run(1)
        ola:Fire("UNIT_AURA", "player", gain); w:Run(1)
        eq(ola.env.DyreparkenDebugDB.verify.seen["api:campgain"].detail, "Camp Spirit 1229999 (3600 s)")
        -- Its own events: one, then no longer heard; a unit's (the target's RESIST).
        ola:Fire("PLAYER_CONTROL_GAINED"); w:Run(1)
        eq(State(V, "api:control"), "seen"); no(ola:Listening("PLAYER_CONTROL_GAINED"), "answered: not heard any more")
        ola:Fire("UNIT_COMBAT", "target", "WOUND", "", 10, 1); w:Run(1)
        eq(State(V, "api:resist"), "open", "a hit isn't one")
        ola:Fire("UNIT_COMBAT", "target", "RESIST", "", 0, 1); w:Run(1)
        eq(State(V, "api:resist"), "seen")
        -- Zones by the client's name; one Data/Zones lacks is collected.
        ola.state.zone = "Durotar"; ola:Fire("ZONE_CHANGED_NEW_AREA"); w:Run(1)
        eq(State(V, "zone:Durotar"), "seen")
        ola.state.instance, ola.state.zone = "party", "Maraudon"; ola:Fire("ZONE_CHANGED_NEW_AREA"); w:Run(1)
        eq(State(V, "new:zonenames"), "open", "a dungeon isn't a zone")
        ola.state.instance = "none"
        ola.state.zone = "Nowhere Isle"; ola:Fire("ZONE_CHANGED_NEW_AREA"); w:Run(1)
        ola.state.zone = "Elsewhere Isle"; ola:Fire("ZONE_CHANGED_NEW_AREA"); w:Run(1)
        local rec = ola.env.DyreparkenDebugDB.verify.seen["new:zonenames"]
        eq(rec.details[1], "Nowhere Isle"); eq(rec.details[2], "Elsewhere Isle")
        -- Resting: an inn or a city, not a sleeping bag, whose Well-Rested comes a minute after the resting does
        -- (2026-11-20, the user): told only once that minute is over.
        ola.state.spellNames = { [429959] = "Well-Rested" }
        ola.state.resting = true; ola:Fire("PLAYER_UPDATE_RESTING"); w:Run(60)
        ola.state.auras = { [429959] = true }; w:Run(V.INN_AFTER)
        eq(State(V, "new:inn"), "open", "a sleeping bag isn't an inn")
        ola.state.auras = {}; ola.state.resting = false; ola:Fire("PLAYER_UPDATE_RESTING"); w:Run(1)
        ola.state.resting = true; ola:Fire("PLAYER_UPDATE_RESTING"); w:Run(10)
        ola.state.resting = false; ola:Fire("PLAYER_UPDATE_RESTING"); w:Run(V.INN_AFTER)
        eq(State(V, "new:inn"), "open", "resting only a moment: nothing told")
        ola.state.zone, ola.state.subzone = "Feralas", "Camp Mojache"
        ola.state.resting = true; ola:Fire("PLAYER_UPDATE_RESTING"); w:Run(V.INN_AFTER - 5)
        eq(State(V, "new:inn"), "open", "not yet")
        w:Run(10)
        eq(State(V, "new:inn"), "seen")
        match(ola.env.DyreparkenDebugDB.verify.seen["new:inn"].detail, "in Feralas / Camp Mojache$")
        ola.state.resting = false
        -- Mounted: your own mount, not a flight path, where IsMounted() is true too (2026-11-20, the user).
        ola.state.mounted = true; ola:Fire("PLAYER_MOUNT_DISPLAY_CHANGED"); w:Run(1)
        ola.state.taxi = true; w:Run(V.MOUNT_AFTER)
        eq(State(V, "new:mount"), "open", "a flight path isn't a mount")
        ola.state.taxi = nil; ola.state.mounted = false; ola:Fire("PLAYER_MOUNT_DISPLAY_CHANGED"); w:Run(1)
        ola.state.mounted = true; ola:Fire("PLAYER_MOUNT_DISPLAY_CHANGED"); w:Run(V.MOUNT_AFTER - 1)
        eq(State(V, "new:mount"), "open", "not yet")
        w:Run(2)
        eq(State(V, "new:mount"), "seen")
        match(ola.env.DyreparkenDebugDB.verify.seen["new:mount"].detail, "^mounted in Feralas$")
        ola.state.mounted = false
        -- Window types, collected with their names.
        local T = ola.env.Enum.PlayerInteractionType
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Merchant); w:Run(1)
        ola:Fire("PLAYER_INTERACTION_MANAGER_FRAME_SHOW", T.Trainer); w:Run(1)
        rec = ola.env.DyreparkenDebugDB.verify.seen["new:interactions"]
        eq(rec.details[1], "Merchant " .. T.Merchant); eq(rec.details[2], "Trainer " .. T.Trainer)
        -- Read now: the calendar's clock.
        eq(State(V, "api:calendarclock"), "seen")
        match(ola.env.DyreparkenDebugDB.verify.seen["api:calendarclock"].detail, "^calendar %d%d:%d%d, date%(%) ")
        -- By hand.
        ola:Slash("probe verify ok afknap")
        eq(State(V, "look:afknap"), "seen")
        ola:Slash("probe verify ok nothing")
        ok(ola:Printed("no item \"nothing\"", true))
        -- Kept across a reload, and for the account.
        ola:Reload(); w:Settle("hello")
        eq(ola.ns.Verify:State(ola.ns.Verify.BY["activity:dance"]), "seen")
        eq(ola.env.DyreparkenDebugDB.verify.seen["activity:dance"].who, "Ola Nord")
    end)

    test("one counted before the probe started ticks silently; a first time says so, with the session's count", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local ns = ola.ns
        ns.DB.char.activity.fish = { total = 30, mine = 30, pets = {} }
        ola:Slash("probe verify")
        local V = ns.Verify
        ns.Activity:Emit("fish", 1); w:Run(1)
        eq(V:State(V.BY["activity:fish"]), "seen")
        eq(ola:CountPrinted("Verify: activity:fish"), 0, "known: silent")
        eq(#ola:Log("seen activity:fish %(known%)"), 1, "logged as known")
        ns.Activity:Emit("dance", 1); w:Run(1)
        ns.Activity:Emit("duel", 1); w:Run(1)
        ok(ola:Printed("Verify: activity:dance", true)); ok(ola:Printed("(2 new this session)", true))
    end)

    test("the lists: what's open with what to do, all of them with what was seen; missing events; reset", function()
        local w, ola, V = Setup()
        ola.ns.Activity:Emit("dance", 1); w:Run(1)
        ola:Slash("probe verify activity")
        ok(ola:Printed("- duel: fight a duel", true))
        no(ola:Printed("dance: /dance", true), "done: not listed")
        ola:Slash("probe verify activity all")
        ok(ola:Printed("dance: /dance - seen: dance +1", true))
        -- An event the client lacks: said so, not an error.
        ok(V.BY["new:trade"].missing, "no TRADE_SHOW in the stubs")
        ola:Slash("probe verify new")
        ok(ola:Printed("trade: open a trade with a player - its event isn't in the client", true))
        ola:Slash("probe verify nonsense")
        ok(ola:Printed("no area \"nonsense\"", true))
        ola.ns.Log("Activity", "eat: Refreshment is spell 1234")
        eq(State(V, "api:refreshment"), "seen")
        -- One wrong tick undone; the flight path's from before a taxi was told apart, dropped at the start.
        ola:Slash("probe verify forget api:refreshment")
        eq(State(V, "api:refreshment"), "open"); ok(ola:Printed("api:refreshment open again", true))
        ola:Slash("probe verify forget api:refreshment")
        ok(ola:Printed("no tick \"api:refreshment\" to forget", true))
        ola.env.DyreparkenDebugDB.verify.seen["new:mount"] = { at = 1, who = "Ola Nord", detail = "mounted true" }
        ola:Reload(); w:Settle("hello"); V = ola.ns.Verify
        eq(State(V, "new:mount"), "open", "the flight path's tick dropped")
        ola.ns.Log("Activity", "eat: Refreshment is spell 1234")
        ola:Slash("probe verify reset")
        eq(State(V, "api:refreshment"), "open", "forgotten")
        eq(State(V, "activity:dance"), "before", "the character's own counters stay")
        ok(V.armed, "still on")
    end)
end
