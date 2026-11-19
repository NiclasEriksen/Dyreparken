-- /dp try (Dev/Try.lua, 2026-11-14): a line now, by the pet's nature, to see it in game; nothing counted.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    test("an egg's or a reaction's line now, by nature, one variant or all; nothing counted; a wish for the card", function()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "bond" }
        ola:Traits({ "skoyer", "glupsk" }, 5159)
        ola:Slash("adopter panda"); w:Run(5)
        local ns = ola.ns
        ola:Slash("try egg ener 2")
        ok(ola:Printed("Panda Cub ler så den hikster. En av hundre!", true))
        ola:Slash("try egg bom 1")
        ok(ola:Printed(ns.T("egg.bom.skoyer.1", { pet = "Panda Cub" }), true), "by its nature (Skøyer)")
        eq(ns.DB.char.eggs.bom, nil, "not counted")
        eq(ns.DB.char.quirkAt, nil, "no cooldown spent")
        ola:ClearPrinted()
        ola:Slash("try react krigsrop all")
        local n = #ns.Variants("react.krigsrop")
        for _, t in ipairs({ "latsabb", "pratsom", "kjaelen" }) do n = n + #ns.Variants("react.krigsrop." .. t) end
        eq(#ola.printed, n, "every line it has, by nature too")
        ola:Slash("try react nosuch")
        ok(ola:Printed("No reaction nosuch.", true))
        ola:Slash("try line wish.say.fish 1")
        ok(ola:Printed(ns.T("wish.say.fish.1", { pet = "Panda Cub", activity = "<activity>", zone = "<zone>" }), true),
            "a placeholder it can't fill shows as <name>")
        ola:Slash("try wish zone Tanaris")
        ok(ola:Printed("Today's wish: zone (Tanaris).", true))
        eq(ns.DB.char.wish.id, "zone"); eq(ns.DB.char.wish.zone, "Tanaris")
        -- A dislike's line, and its sulk owed as a real one's (the pet frame turns away: 40_pet_frame); all: lines only.
        ola:Slash("try dislike taxi all")
        no(ns.Moves:Owed("s:5159", "sulk"), "listing its lines: no sulk")
        ola:Slash("try dislike taxi 1")
        ok(ola:Printed(ns.T("dislike.taxi.1", { pet = "Panda Cub" }), true))
        ok(ns.Moves:Owed("s:5159", "sulk"), "its sulk, for the card")
        ola:Slash("try what")
        ok(ola:Printed("/dp try egg/react", true))
    end)
end
