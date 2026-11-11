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
end
