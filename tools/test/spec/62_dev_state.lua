-- /dp state (Dev/State.lua, 2026-11-14): why nothing is said now, in chat and in the log.
return function(test, H)
    local ok = H.ok

    test("the pet and its day, the cooldowns, today's lines, the wish, what's listened to", function()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "day" }
        ola:Slash("adopter panda"); w:Run(5)
        ola.ns.DB.char.quirkAt = ola.ns.Now() - 60
        ola.ns.DB.char.eggs.bom = { n = 1, day = ola.ns.Today() }
        ola.ns.DB.char.reacts.krigsrop = { n = 2, day = ola.ns.Today() }
        ola:Slash("state")
        ok(ola:Printed("pet out s:5159 (adopted), bond", true))
        ok(ola:Printed("quirks: in 44m; eggs today: bom", true))
        ok(ola:Printed("rows of your class): free; said today: krigsrop", true))
        ok(ola:Printed("wish: ", true))
        ok(ola:Printed("listening: ", true))
        ok(#ola:Log("\tState\tevents: .*CHAT_MSG_ADDON") == 1, "the whole of it in the log")
    end)
end
