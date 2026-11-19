-- A new player's first steps (Menagerie/Onboarding.lua, 2026-11-19): the welcome once an account, the line after
-- a character's first adoption, the card's "?", and none of it for someone who had Dyreparken before.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match

    local WELCOME = "Velkommen til Dyreparken!"

    test("a new account: the welcome once, after the login; the line after the first adoption, once", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 46 } })
        no(ola:Printed(WELCOME, true), "not in the login's first seconds")
        w:Settle("hello")
        eq(ola:CountPrinted(WELCOME), 1)
        ok(ola:Printed("Åpne samlingen (Shift+P)", true), "where it lives")
        ok(ola:Printed("Parken og Prestasjoner er fanene", true))
        ola:Reload(); w:Settle("day")
        eq(ola:CountPrinted(WELCOME), 1, "once an account")
        ola:Slash("adopter panda")
        w:Run(1)
        local done, how
        for i, l in ipairs(ola.printed) do
            if l:find("Du adopterte Panda Cub", 1, true) then done = i end
            if l:find("Ha Panda Cub ute med deg: 10 poeng om dagen", 1, true) then how = i end
        end
        ok(done and how and how > done, "after the adoption's own line")
        ok(ola:Printed("(opptil 75)", true))
        ola:Slash("adopter white"); w:Run(1)
        no(ola:Printed("Ha White Kitten ute med deg", true), "a character's first adoption only")
        -- Another character on the same account: welcomed already, but its own first adoption is told.
        local kari = w:AddClient("Kari Berg", { pets = { 40 }, login = false })
        kari.saved.DyreparkenDB = ola.env.DyreparkenDB
        kari:Login(); w:Settle("hello")
        no(kari:Printed(WELCOME, true))
        kari:Slash("adopter"); w:Run(1)
        ok(kari:Printed("Ha Bombay Cat ute med deg", true))
    end)

    test("outside a guild: the welcome says what still works", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { guild = false })
        w:Settle("hello")
        ok(ola:Printed("Den er for guilder", true))
        no(ola:Printed("Åpne samlingen (Shift+P) og adopter", true))
    end)

    test("someone who had Dyreparken before: no welcome, no line after adopting (the migrations)", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 }, login = false })
        ola.saved.DyreparkenDB = { schema = 14, guilds = {}, settings = {} }
        ola.saved.DyreparkenCharDB = { schema = 3 }
        ola:Login(); w:Settle("hello")
        no(ola:Printed(WELCOME, true))
        ola:Slash("adopter"); w:Run(1)
        no(ola:Printed("ute med deg: 10 poeng", true))
    end)

    test("the card's ?: how this pet's bond grows, by what's known of it", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 40 } }
        ola:Slash("adopter panda"); w:Run(2)
        ola:OpenJournal({ extra = { 68 } })
        local card = ola:SelectPet(5159)
        ok(card.help:IsShown())
        local tip = ola:TipOf(card.help)
        eq(tip[1], "Slik blir du venn med Panda Cub")
        match(tip.text, "10 båndpoeng om dagen, og opptil 75")
        match(tip.text, "Panda Cub liker ")
        match(tip.text, "I dag: .*%(%+10%)")
        match(tip.text, "leker dyrene sammen: %+15")
        -- Not yours, and nobody has it: no likes to tell, no wish.
        card = ola:SelectPet(68)
        tip = ola:TipOf(card.help)
        match(tip.text, "Personligheten er ukjent")
        match(tip.text, "Adopter dyret, så får det et ønske")
    end)

    test("/dp fresh: the welcome and the adoption line now; reset: a new player's again at the next login", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        ola:Slash("adopter"); w:Run(2)
        ola:ClearPrinted()
        ola:Slash("fresh")
        w:Run(1)
        ok(ola:Printed(WELCOME, true)); ok(ola:Printed("Ha Panda Cub ute med deg", true))
        ola:ClearPrinted()
        ola:Slash("fresh solo")
        ok(ola:Printed("Den er for guilder", true))
        ola:Slash("fresh reset")
        ola:ClearPrinted()
        ola:Reload(); w:Settle("hello")
        no(ola:Printed(WELCOME, true), "(a pet adopted: an old hand, nothing to tell)")
        ola:Slash("gislipp"); ola.env.DyreparkenDB.welcomed = nil
        ola:Reload(); w:Settle("hello")
        ok(ola:Printed(WELCOME, true))
    end)
end
