-- Bonds: milestone lines at login, the nickname unlock note, petting
-- (/dp klapp), and the name history in the journal and on adoption.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Count(c, text)
        local n = 0
        for _, line in ipairs(c.printed) do if line:find(text, 1, true) then n = n + 1 end end
        return n
    end

    -- Ola adopts the panda, Kari the cat; then time passes.
    local function Setup()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        ola:Slash("adopter")
        w:Run(1)
        return w, ola, kari
    end

    test("milestones: by calendar day, 1 month, 100 days, every year", function()
        local w = H.World()
        local B = w:AddClient("Ola Nord").ns.Bonds
        local at = os.time({ year = 2026, month = 1, day = 10, hour = 23 })
        local function On(y, m, d, h) return B:Milestone(at, os.time({ year = y, month = m, day = d, hour = h or 1 })) end
        eq(On(2026, 1, 10, 23), nil, "the same day")
        eq(On(2026, 2, 8), nil)
        eq(On(2026, 2, 9), "1 måned", "30 calendar days, even an hour past midnight")
        eq(On(2026, 2, 10), nil)
        eq(On(2026, 4, 20), "100 dager")
        eq(On(2027, 1, 10), "1 år")
        eq(On(2028, 1, 10), "2 år")
        eq(On(2028, 1, 11), nil)
    end)

    test("a month together: one line for you, one for the guild, once a day", function()
        local w, ola, kari = Setup()
        w:SkipDays(30)
        ola:Reload(); kari:Reload()
        w:Run(25)
        eq(Count(ola, "bodd hos deg"), 0, "not right at login: the sync comes first")
        w:Run(15)
        ok(ola:Printed("I dag har Panda Cub bodd hos deg i 1 måned!", true))
        ok(kari:Printed("Ola Nord og Panda Cub feirer 1 måned sammen i dag!", true))
        no(ola:Printed("Ola Nord og Panda Cub", true), "your own isn't in the guild list")
        -- Again the same day: nothing new.
        ola:Reload(); kari:Reload()
        w:Settle("day")
        eq(Count(ola, "bodd hos deg"), 1)
        eq(Count(kari, "feirer"), 1)
        -- The next day there's no milestone.
        w:SkipDays(1)
        kari:Reload()
        w:Settle("day")
        eq(Count(kari, "feirer"), 1)
    end)

    test("the nickname is used, and long guild lists are cut", function()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "bond" }
        ola:Slash("adopter")
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Pepe")
        local R = ola.ns.Registry
        local now = w:ServerTime()
        for i = 1, 7 do
            local owner = ("Medlem%d Etternavn"):format(i)
            w:AddMember(owner)
            R:MergeRecord(owner, { k = "s:" .. (40 + i), at = now - 7 * 86400, ts = now })
        end
        R:Changed()
        w:SkipDays(93)
        ola:Reload()
        w:Settle("day")
        ok(ola:Printed("I dag har Pepe bodd hos deg i 100 dager!", true))
        eq(Count(ola, "feirer 100 dager sammen i dag!"), 5)
        ok(ola:Printed("... og 2 til.", true))
    end)

    test("nickname unlock: told once per adoption, inherited names too", function()
        local w, ola, kari = Setup()
        w:SkipDays(7)
        w:Befriend()
        ola:Reload()
        w:Settle("day")
        ok(ola:Printed("Nå kan du gi Panda Cub et kallenavn: /dp navn", true))
        ola:Reload()
        w:Settle("day")
        eq(Count(ola, "Nå kan du gi"), 1)
        ola:Slash("navn Pepe")
        ola:Slash("gislipp")
        w:Run(1)
        -- Kari adopts the named panda and gets the note a week later.
        kari:GivePet(5159)
        kari:Slash("adopter panda")
        ok(kari:Printed("Du adopterte Panda Cub. Det heter «Pepe», et navn det fikk av Ola Nord. Ta godt vare på det!",
            true))
        w:SkipDays(7)
        w:Befriend()
        kari:Reload()
        w:Settle("day")
        ok(kari:Printed("Nå kan du gi Pepe et nytt kallenavn hvis du vil: /dp navn", true))
    end)

    test("adopting your own named pet again keeps its name quietly", function()
        local w, ola = Setup()
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Pepe")
        ola:Slash("gislipp")
        ola:Slash("adopter")
        ok(ola:Printed("Du adopterte Panda Cub. Det heter fortsatt «Pepe».", true))
    end)

    test("no guild: no milestones", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { guild = false })
        w:Settle("day")
        c.ns.Bonds:Celebrate()
        eq(#c.printed, 0)
    end)

    test("klapp: your own pet by nickname, others' with their owner", function()
        local w, ola, kari = Setup()
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Pepe")
        w:Run(1)
        local function Emotes(c)
            local list = {}
            for _, m in ipairs(w.chat) do if m.from == c.name and m.chan == "EMOTE" then list[#list + 1] = m.text end end
            return list
        end
        ola:Slash("klapp")
        eq(Emotes(ola)[1], "klapper Pepe.", "your own summoned pet")
        ola:Target({ species = 5159, owner = "Ola Nord" })
        ola:Slash("klapp")
        eq(Emotes(ola)[2], "klapper Pepe.", "your own, targeted")
        kari:Target({ species = 5159, owner = "Ola Nord" })
        kari:Slash("klapp")
        eq(Emotes(kari)[1], "klapper Pepe (Ola Nord sin Panda Cub).")
        kari:Target({ species = 46, owner = "Per Hansen" })
        kari:Slash("klapp")
        eq(Emotes(kari)[2], "klapper Per Hansen sin White Kitten.", "no reservation: the owner from the tooltip")
        kari:Target({ species = 46 })
        kari:Slash("klapp")
        eq(Emotes(kari)[3], "klapper White Kitten.", "no owner line")
        kari:Target({ species = 46, name = H.SECRET })
        kari:Slash("klapp")
        eq(#Emotes(kari), 3, "unreadable name: nothing")
        -- Not a companion: your own pet instead (Kari's cat isn't adopted: species name).
        kari:Target({ species = 46, companion = false })
        kari:Slash("klapp")
        eq(Emotes(kari)[4], "klapper Bombay Cat.")
        kari:Summon(nil)
        kari:Target(nil)
        kari:Slash("klapp")
        ok(kari:Printed("Summon dyret ditt, eller velg et dyr som mål.", true))
        kari:EnterCombat()
        kari:Slash("klapp")
        ok(kari:Printed("Ikke nå, du er i kamp.", true))
        eq(#Emotes(kari), 4)
    end)

    test("the journal tooltip says who named the pet, and when", function()
        local w, ola, kari = Setup()
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Pepe")
        w:Run(1)
        local today = os.date("%d.%m.%Y", w:ServerTime())
        local tip = kari.env.GameTooltip
        tip:ClearLines()
        kari.ns.JournalList:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "Kallenavn: «Pepe» / Navngitt av Ola Nord, " .. today:gsub("%.", "%%."))
        tip:ClearLines()
        ola.ns.JournalList:AddTooltipLines(ola.env.GameTooltip, PANDA)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "Navngitt av deg")
        ola:Slash("gislipp")
        w:Run(1)
        tip:ClearLines()
        kari.ns.JournalList:AddTooltipLines(tip, PANDA)
        match(table.concat(tip.lines, " / "), "trenger et hjem / Kallenavn: «Pepe» / Navngitt av Ola Nord")
    end)

    test("adopting and naming are announced in guild chat; off with /dp kunngjør", function()
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 40 }, settle = "bond" }
        local function Guild()
            local list = {}
            for _, m in ipairs(w.chat) do if m.chan == "GUILD" then list[#list + 1] = m.text end end
            return list
        end
        ola:Slash("adopter")
        eq(Guild()[1], "Dyreparken: Ola Nord adopterte Panda Cub!")
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Pepe")
        eq(Guild()[2], "Dyreparken: Ola Nord ga Panda Cub kallenavnet «Pepe»!")
        ola:Slash("navn Pepe")
        eq(#Guild(), 2, "nothing changed: nothing posted")
        ola:Slash("navn")
        eq(#Guild(), 2, "clearing isn't announced")
        -- The journal dialog posts too (Accept is a click).
        ola.ns.CardActions:AskNickname()
        ola:PopupAccept("Pepe")
        eq(#Guild(), 2, "the same line within an hour isn't repeated")
        ola.ns.CardActions:AskNickname()
        ola:PopupAccept("Bambus", true)
        eq(Guild()[3], "Dyreparken: Ola Nord ga Panda Cub kallenavnet «Bambus»!")
        -- Adopting a named pet: the name comes along.
        ola:Slash("gislipp")
        w:Run(10) -- Ola sent a burst; the outbox paces it
        kari:GivePet(5159)
        kari:Slash("adopter panda")
        eq(Guild()[4], "Dyreparken: Kari Berg adopterte Panda Cub («Bambus»)!")
        -- The card's Adopt button.
        ola:OpenJournal()
        local card = ola:SelectPet(46)
        card.reserve:Click()
        eq(#Guild(), 4, "asked first")
        ola:PopupAccept() -- the click on Adopter is what may post
        eq(Guild()[5], "Dyreparken: Ola Nord adopterte White Kitten!")
        -- Turned off (per character, saved).
        ola:Slash("kunngjør av")
        ok(ola:Printed("kunngjøres ikke lenger", true))
        ola:Reload()
        w:Settle("bond")
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Tuss")
        eq(ola.ns.Registry:Nickname("s:46"), "Tuss")
        eq(#Guild(), 5, "named, but not announced")
        ola:Slash("kunngjør")
        eq(ola.env.DyreparkenCharDB.announce, true, "toggles back on")
        ola:Slash("kunngjør på")
        eq(ola.env.DyreparkenCharDB.announce, true)
        -- A failed adoption posts nothing.
        ola:Slash("adopter panda")
        eq(#Guild(), 5)
    end)

    test("dagens dyr: the same pet for everyone, a new pick each day, shown on the card", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159 } })
        local kari = w:AddClient("Kari Berg", { pets = { 40 } })
        local per = w:AddClient("Per Hansen", { pets = { 46 } })
        w:Settle("bond")
        eq(ola.ns.Bonds:PetOfTheDay(), nil, "nobody has adopted yet")
        ola:OpenJournal()
        eq(ola:SelectPet(5159).today.text, "-")
        for _, c in ipairs({ ola, kari, per }) do c:Slash("adopter") end
        -- A made-up species isn't picked.
        ola.ns.Registry:MergeRecord("Liv Lund", { k = "s:999999", at = 1, ts = 1 })
        ola.ns.Registry:Changed()
        w:Run(10)
        local seen = {}
        for day = 1, 20 do
            local pick, owner = ola.ns.Bonds:PetOfTheDay()
            eq(kari.ns.Bonds:PetOfTheDay(), pick, "day " .. day .. ": everyone agrees")
            no(pick == "s:999999")
            eq(owner, ola.ns.Registry:Holder(pick))
            seen[pick] = true
            w:SkipDays(1)
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        eq(n, 3, "over 20 days every pet gets its day")
        -- The card names it, by nickname.
        w:SkipDays(7)
        w:Befriend()
        for _, c in ipairs({ ola, kari, per }) do c:Slash("navn Stjerne" .. c.name:sub(1, 1)) end
        w:Run(10)
        local pick, owner = ola.ns.Bonds:PetOfTheDay()
        local card = ola:SelectPet(5159)
        eq(card.today.text, ola.ns.Registry:Nickname(pick))
        match(card.today.text, "^Stjerne")
        eq(ola:Card().todayBox.tip, ("Dagens dyr: %s, som bor hos %s.\n|cffa0a0a0Klikk for å se det.|r")
            :format(card.today.text, owner))
    end)
end
