-- /dp probe api (Core/ApiProbe.lua): what the client has, read-only, saved in
-- DyreparkenDebugDB.api. Here against the stub client: every section runs
-- without an error, and what it finds is in the saved table.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    test("every section runs and saves what it finds; nothing is sent or posted", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        -- The stubs have no calendar: one with a holiday today.
        rawset(ola.env, "C_Calendar", {
            OpenCalendar = function() end,
            GetNumDayEvents = function(offset, day) return (offset == 0 and day == 11) and 1 or 0 end,
            GetDayEvent = function() return { title = "Hallow's End" } end,
        })
        rawset(ola.env, "C_DateAndTime", { GetCurrentCalendarTime = function() return { monthDay = 11 } end })
        local sent = #w.wire
        ola:Slash("probe api")
        local db = ola.env.DyreparkenDebugDB.api
        ok(db.at and db.build)
        ok(#db.globals.functions > 50, "the global functions")
        ok(db.namespaces.C_PetJournal, "a namespace and what's in it")
        ok(db.events.known[1]); match(table.concat(db.events.unknown, " "), "SOUNDKIT_FINISHED", "an event the client lacks")
        ok(db.widgets.Frame.methods, "a frame's methods")
        ok(db.widgets.Texture, "a texture's")
        ok(db.templates.exist and db.templates.missing)
        eq(db.strings.missing[1] ~= nil, true)
        eq(db.values["UnitName(\"player\")"], "\"Ola\", \"Nord\"", "every value it returned")
        eq(db.values["GetShapeshiftFormID()"], "nil", "no form: nil")
        eq(db.values["GetLocale()"], "(missing)", "a function the client lacks")
        ok(db.card.actor and db.card.actorState, "the card's actor")
        match(ola:Printed("api probe model", true), "SetDisplayInfo", "the stubs' PlayerModel can't: why not, saved")
        w:Run(10)
        eq(db.calendar.count, "1", "the calendar, once it has loaded")
        match(db.calendar.events[1], "Hallow's End")
        eq(#w.wire, sent, "nothing sent")
        ola:Slash("probe api values")
        ok(db.values, "one section")
        ola:Slash("probe api nonsense")
        match(ola:Printed("api probe", true), "sections are")
        ola:Slash("probe api clear")
        eq(ola.env.DyreparkenDebugDB.api, nil)
    end)

    test("the model: its animations by HasAnimation, and how long the card's moves play", function()
        local w, ola = H.Setup{ ola = { 5159 }, journal = true }
        ola:SelectPet(5159)
        -- A PlayerModel like retail's: loads, has three animations, says when one ends.
        local real = ola.env.CreateFrame
        local model
        ola.env.CreateFrame = function(kind, ...)
            if kind ~= "PlayerModel" then return real(kind, ...) end
            local scripts = {}
            model = {
                SetSize = function() end, SetPoint = function() end, SetAlpha = function() end,
                Hide = function(self) self.hidden = true end,
                SetDisplayInfo = function(self, id) self.display = id end,
                HasAnimation = function(_, id) return id == 0 or id == 756 or id == 748 end,
                HasScript = function(_, h) return h == "OnAnimFinished" or h == "OnModelLoaded" end,
                SetScript = function(_, h, fn) scripts[h] = fn end,
                SetAnimation = function(self, id)
                    self.anim = id
                    if id ~= 99 then -- (the panda's lie-down: as if it never ended)
                        ola.env.C_Timer.After(id == 748 and 0.8 or 1.5, function()
                            if self.anim == id and scripts.OnAnimFinished then scripts.OnAnimFinished(self) end
                        end)
                    end
                end,
            }
            model.scripts = scripts
            return model
        end
        ola:Slash("probe api model")
        local out = ola.env.DyreparkenDebugDB.api.model
        eq(out.species, 5159)
        model.scripts.OnModelLoaded(model)
        eq(out.animations, "0 748 756")
        w:Run(20)
        eq(out.lengths["happy 756"], "1.50 s")
        eq(out.lengths["happyToo 748"], "0.80 s")
        match(out.lengths["sleep 99"], "^no end in")
        ok(model.hidden, "hidden when done")
        match(ola:Printed("api probe", true), "model done")
    end)

    test("the model and the card need a pet's card", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("probe api card")
        match(ola:Printed("api probe card", true), "no pet card")
        ola:OpenJournal()
        ola:Slash("probe api model")
        match(ola:Printed("api probe model", true), "open a pet's card first")
    end)

    -- A PlayerModel like the client's: loads, says when an animation ends (Stand 2 s, 99 never, others 1.2 s).
    local function Models(ola)
        local real, made = ola.env.CreateFrame, {}
        ola.env.CreateFrame = function(kind, ...)
            if kind ~= "PlayerModel" then return real(kind, ...) end
            local scripts = {}
            local m = { scripts = scripts }
            function m.SetSize() end
            function m.SetPoint() end
            function m.SetAlpha() end
            function m:Hide() self.hidden = true end
            function m:SetDisplayInfo(id)
                self.display = id
                ola.env.C_Timer.After(0.5, function() if scripts.OnModelLoaded then scripts.OnModelLoaded(self) end end)
            end
            function m.SetScript(_, h, fn) scripts[h] = fn end
            function m:SetAnimation(id)
                self.anim = id
                if id == 99 then return end
                ola.env.C_Timer.After(id == 0 and 2 or 1.2, function()
                    if self.anim == id and scripts.OnAnimFinished then scripts.OnAnimFinished(self) end
                end)
            end
            made[#made + 1] = m
            return m
        end
        return made
    end

    test("lengths all: every species' one-offs timed on a few models at once, saved for tools/anim_lengths.lua", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local made = Models(ola)
        local species = 0
        for _ in pairs(ola.ns.Companions.species) do species = species + 1 end
        ola:Slash("probe api lengths all")
        eq(#made, 6, "six at a time")
        w:Run(900)
        local saved = ola.env.DyreparkenDebugDB.animLengths
        local n = 0
        for _ in pairs(saved) do n = n + 1 end
        eq(n, species, "every species")
        eq(saved[5159][0], 2, "Stand, to tell a missing one by")
        eq(saved[5159][756], 1.2)
        eq(saved[40][99], "none", "the cats' lie-down: no end")
        ok(made[1].hidden, "hidden when done")
        match(ola:Printed("api probe", true), "lengths done, " .. species .. " species")
    end)

    test("lengths: the probe times every move Moves:Unmeasured asks about", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local timed = {}
        for _, what in ipairs(ola.ns.ApiProbe.PARTS) do timed[what] = true end
        for _, what in ipairs(ola.ns.Moves.MEASURED) do ok(timed[what], what .. " (ApiProbe.PARTS)") end
    end)

    test("lengths: only the species with a move unmeasured (a new companion), added to the last run; or ids", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        Models(ola)
        local M = ola.ns.Moves
        -- (the attack and cower moves, 2026-11-12, as if already measured)
        for _, own in pairs(ola.ns.AnimLengths) do own[750] = own[750] or 1; own[748] = own[748] or 1 end
        ola.ns.AnimLengths[40] = nil -- (as if the Bombay were new)
        local missing = M:Unmeasured()
        ok(#missing >= 1)
        local has40 = false
        for _, sid in ipairs(missing) do if sid == 40 then has40 = true end end
        ok(has40, "the Bombay, unmeasured")
        ola.env.DyreparkenDebugDB.animLengths = { [5159] = { [0] = 2 } } -- (an earlier run's)
        ola:Slash("probe api lengths")
        w:Run(300)
        local saved = ola.env.DyreparkenDebugDB.animLengths
        ok(saved[40] and saved[40][0], "measured")
        eq(saved[5159], nil, "only this run's: an earlier one's would overwrite newer lines in the file")
        eq(saved[5160], nil, "a measured species left alone")
        match(ola:Printed("api probe", true), "lengths done, " .. #missing .. " species")
        -- By id.
        ola.env.DyreparkenDebugDB.animLengths = nil
        ola:Slash("probe api lengths 5160 46")
        w:Run(120)
        saved = ola.env.DyreparkenDebugDB.animLengths
        ok(saved[5160] and saved[46]); eq(saved[40], nil)
        -- Nothing to do.
        ola.ns.Moves.Unmeasured = function() return {} end
        ola:Slash("probe api lengths")
        match(ola:Printed("api probe lengths", true), "nothing to do")
    end)

    test("holidays: the calendar stepped through a year, each holiday once with its days, and put back", function()
        local w, ola = H.Setup{ ola = {} }
        local at = { month = 11, year = 2026 }
        local set = {}
        rawset(ola.env, "C_DateAndTime", { GetCurrentCalendarTime = function() return { month = 11, year = 2026, monthDay = 11 } end })
        rawset(ola.env, "C_Calendar", {
            OpenCalendar = function() end,
            SetAbsMonth = function(m, y) at = { month = m, year = y }; set[#set + 1] = m .. "/" .. y end,
            GetNumDayEvents = function(_, day)
                if at.month == 11 and day >= 9 and day <= 16 then return 1 end
                if at.month == 12 and day == 25 then return 1 end
                return 0
            end,
            GetDayEvent = function(_, day)
                return at.month == 11 and { eventID = 263, title = "Darkmoon Faire", eventType = 4, iconTexture = 235447 }
                    or { eventID = 141, title = "Feast of Winter Veil", eventType = 4 }
            end,
            GetHolidayInfo = function() return { name = at.month == 11 and "Darkmoon Faire" or "Feast of Winter Veil" } end,
        })
        ola:Slash("probe api holidays")
        w:Run(40)
        local list = ola.env.DyreparkenDebugDB.api.holidays.list
        eq(#list, 2)
        eq(list[1].id, 263); eq(list[1].first, "2026-11-09"); eq(list[1].last, "2026-11-16"); eq(list[1].texture, 235447)
        eq(#list[1].dates, 8, "every day it's on")
        eq(list[2].id, 141); eq(list[2].first, "2026-12-25")
        eq(set[2], "12/2026"); eq(set[3], "1/2027", "into the next year")
        eq(set[#set], "11/2026", "put back")
        rawset(ola.env, "C_Calendar", {})
        ola:Slash("probe api holidays")
        match(ola:Printed("api probe holidays", true), "no C_Calendar.SetAbsMonth")
    end)

    test("feats: every feat's spells and quests as the client has them, Forever's copies, then a watch", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola.state.spellNames = { [697] = "Summon Voidwalker", [71] = "Defensive Stance" }
        ola.state.spells = { [71] = true }
        ola.state.questTitles = { [1689] = "The Binding", [99001] = "The Binding", [1503] = "Forged Steel" }
        ola.state.questsDone = { [1503] = true, [99001] = true }
        ola:Slash("probe api feats")
        local out = ola.env.DyreparkenDebugDB.api.feats
        local spells = table.concat(out.spells, "\n")
        match(spells, "voidwalker 697 Summon Voidwalker\n")
        match(spells, "defstance 71 Defensive Stance %(known%)")
        match(spells, "succubus 712 NO SPELL")
        match(table.concat(out.quests, "\n"), "defstance 1503 Forged Steel, done true")
        match(out.items[1], "^earth 5175 .*, in bags 0$")
        eq(out.copies[1], "99001 The Binding (like voidwalker)", "a completed quest with a feat quest's title")
        ok(out.values.unspent)
        match(ola:Printed("api probe feats", true), "1 copies")
        -- Titles the client hadn't loaded: asked for, a few a second, and read again after.
        ola.state.questTitles[99002] = nil
        ola.state.questsDone[99002] = true
        ola.state.config, ola.state.talents = 100, { [1] = 5, [2] = 2 }
        ola:Slash("probe api feats")
        out = ola.env.DyreparkenDebugDB.api.feats
        eq(out.untitled, 1)
        eq(out.talents.ranked, 2); eq(out.talents.ranks, 7)
        ok(out.talents.sampleNode, "a node's fields")
        ola.state.questTitles[99002] = "The Binding"
        w:Run(10)
        eq(ola.state.questsAsked > 37, true, "the feats' quests and the completed ones")
        eq(#out.copies, 2, "the late title found")
        match(ola:Printed("titles read", true), "2 copies, 0 completed quests still untitled")
        -- The watch: a candidate event that fires is logged, with the unspent points.
        ola.state.unspent = 31
        ola:Fire("ACTIVE_TALENT_GROUP_CHANGED", 2, 1)
        match(ola:Log("feat event")[1], "ACTIVE_TALENT_GROUP_CHANGED %(2, 1%) unspent 31")
        ola:Fire("ACTIVE_TALENT_GROUP_CHANGED", 1, 2)
        eq(#ola:Log("feat event"), 1, "one line per event kind every 2 s")
        match(ola:Log("feat event")[1], "config 100, ranks 7")
    end)

    test("petframe: our own scene with the pet that's out, a click plays its happy move, Edit Mode's callbacks", function()
        local _, none = H.Setup{ ola = {} }
        none.ns.Pets.OutKey = function() return nil end -- (no pet out)
        none:Slash("probe api petframe")
        match(none:Printed("api probe petframe", true), "summon a pet first")
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter panda"); w:Run(5)
        ok(ola.ns.Pets:OutKey(), "out")
        -- A ModelScene like the client's, with the pet card's "unwrapped" actor.
        local real = ola.env.CreateFrame
        local actor = { SetModelByCreatureDisplayID = function(self, id) self.display = id end,
            SetAnimation = function(self, id) self.anim = id end }
        ola.env.CreateFrame = function(kind, name, parent, template)
            local f = real(kind == "ModelScene" and "Frame" or kind, name, parent, template)
            if kind == "ModelScene" then
                function f:TransitionToModelSceneID(id) self.sceneID = id end
                function f:GetActorByTag(tag) return tag == "unwrapped" and self.sceneID and actor or nil end
            end
            return f
        end
        ola.env.C_PetJournal.GetPetModelSceneInfoBySpeciesID = function() return 1271, 1272 end
        local callbacks = {}
        rawset(ola.env, "EventRegistry", { RegisterCallback = function(_, ev, fn) callbacks[ev] = fn end })
        rawset(ola.env, "EditModeManagerFrame", {})
        ola:Slash("probe api petframe")
        local out = ola.env.DyreparkenDebugDB.api.petframe
        eq(out.scene, "made"); eq(out.actor, "found")
        eq(actor.display, 20000 + 5159, "the species' display")
        local f = ola.env.DyreparkenPetFrameProbe
        f.click.scripts.OnClick(f.click, "LeftButton")
        eq(actor.anim, ola.ns.Moves:For("s:5159", "happy"))
        ok(callbacks["EditMode.Enter"] and callbacks["EditMode.Exit"])
        callbacks["EditMode.Enter"]()
        ok(ola:Printed("EditMode.Enter fired", true))
        f.click.scripts.OnClick(f.click, "RightButton")
        no(f:IsShown())
        -- No unwrapped actor in the scene: one of our own.
        ola.env.C_PetJournal.GetPetModelSceneInfoBySpeciesID = function() return nil end
        f.scene.CreateActor = function() return actor end
        ola:Slash("probe api petframe")
        eq(ola.env.DyreparkenDebugDB.api.petframe.created, "made one")
    end)

    test("meter: C_DamageMeter's sessions read (secret or not, your place), then watched after each fight", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local secret = false
        local function Session(kind)
            if secret then return { combatSources = H.SECRET } end
            return { totalAmount = 300, maxAmount = 200, durationSeconds = 30, combatSources = {
                { name = "Kari Berg", classFilename = "MAGE", totalAmount = 200, amountPerSecond = 6.6, isLocalPlayer = false },
                { name = "Ola", classFilename = "WARRIOR", totalAmount = 100, amountPerSecond = 3.3, isLocalPlayer = true },
            } }
        end
        rawset(ola.env, "C_DamageMeter", {
            IsDamageMeterAvailable = function() return true end,
            GetAvailableCombatSessions = function() return { { sessionID = 4, name = "Hogger" } } end,
            GetCombatSessionFromID = function() return Session(0) end,
            GetSessionDurationSeconds = function() return 30 end,
            GetCombatSessionFromType = function(_, kind) return Session(kind) end,
        })
        ola:Slash("probe api meter")
        local db = ola.env.DyreparkenDebugDB.api.meter
        eq(db.available, "true")
        match(db.reads["session 1 type 0"], "^2 sources, total 300, max 200, duration 30; you #2 %(sorted%); 1 \"Kari Berg\" %(\"MAGE\"%) 200")
        -- A fight's end: read again a second later; in a fight the data is secret.
        ola:EnterCombat(); secret = true
        ola:LeaveCombat() -- (still secret: the test says so, to see it logged)
        w:Run(1.1)
        ok(ola:Log("meter after combat %(out of combat%) session 1 type 0: sources <secret>")[1])
        secret = false
        rawset(ola.env, "C_DamageMeter", nil)
        eq(ola.ns.ApiProbe.MeterRead(1, 0), "no C_DamageMeter")
    end)

    test("combat: auto-attack, auto shot, casts and hits logged this session, with the swing speeds", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("debug on")
        ola:Slash("probe api combat")
        match(ola:Printed("api probe combat", true), "watching this session.*speed 2")
        ola:Fire("PLAYER_ENTER_COMBAT")
        match(ola:Log("combat PLAYER_ENTER_COMBAT")[1], "| speed 2")
        ola:Fire("UNIT_COMBAT", "target", "WOUND", "", 120, 1)
        match(ola:Log("combat UNIT_COMBAT")[1], '"target", "WOUND"')
        ola.env.DyreparkenDebugDB.api = nil
        ola:Slash("probe api combat")
        match(ola:Printed("api probe combat", true), "watching already")
    end)

    test("transport: where you are, logged at every zone and world change, each cast, and every few seconds", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola.state.zone = "Durotar"
        ola:Slash("probe api transport")
        match(ola:Printed("api probe transport", true), 'watching this session.*zone "Durotar"')
        ola.state.zone = "Tirisfal Glades"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        match(ola:Log("transport ZONE_CHANGED_NEW_AREA")[1], 'zone "Tirisfal Glades"')
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8690)
        ok(ola:Log("transport cast 8690")[1])
        w:Run(11)
        eq(#ola:Log("transport sample"), 2)
        ola:Slash("probe api transport")
        match(ola:Printed("api probe transport", true), "watching already")
    end)
end
