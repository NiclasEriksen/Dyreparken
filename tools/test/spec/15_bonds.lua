-- Bonds: milestone lines at login, the nickname unlock note, petting
-- (/dp klapp), and the name history in the journal and on adoption.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    -- Ola adopts the panda, Kari the cat; then time passes.
    local function Setup()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        ola:Slash("adopter")
        w:Run(1)
        return w, ola, kari
    end

    -- The full day's line (2026-11-22, the content review §4.2): a nudge toward a pet of yours with room today.
    test("a full day: the line names another pet with room today, the longest since out; else the plain line, three times", function()
        local w, ola = H.Setup{ ola = { 5159, 46, 40 } }
        ola:Slash("adopter panda"); w:Run(5)
        local ns, B = ola.ns, ola.ns.Bonds
        local char = ns.DB.char
        local function Day(n) return ns.Today(ns.Now() - n * 86400) end
        local function Line() return (B:FullLine(PANDA)) end
        -- (Ola's login put the kitten or the cat out first: forget who has been out, so each case is set here)
        char.activity.day.on = {}
        eq(Line(), "Panda Cub er fornøyd for i dag. Bombay Cat har aldri vært ute med deg: kanskje det er dens tur?",
            "never out: the first by name")
        char.activity.day.on["s:40"] = Day(1)
        char.activity.day.on["s:46"] = Day(4)
        eq(Line(), "Panda Cub er fornøyd for i dag. White Kitten har ikke vært ute på 4 dager: kanskje den vil være med?",
            "the longest since out first")
        char.activity.day.on["s:46"] = ns.Today()
        char.bondToday.pets["s:46"] = { got = {}, total = ns.Bond:DailyMax("s:46") }
        eq(Line(), "Panda Cub er fornøyd for i dag. Bombay Cat var med i går, og vil gjerne ut igjen.", "a full one left out")
        char.bondToday.pets["s:40"] = { got = {}, total = ns.Bond:DailyMax("s:40") }
        for _ = 1, B.FULL_HINTS do eq(Line(), "Båndet med Panda Cub er fullt for i dag. Fortsett i morgen!") end
        eq(Line(), nil, "none with room: the plain line, its first three times only")
    end)

    -- 2026-11-22, the user: the pet frame's swap named a pet outside the Turnus.
    test("a full day's suggestion: your Turnus pets first, the next in turn with room; others only when none has", function()
        local w, ola = H.Setup{ ola = { 5159, 46, 40 } }
        ola:Slash("adopter panda"); w:Run(5)
        local ns = ola.ns
        local char = ns.DB.char
        local function Day(n) return ns.Today(ns.Now() - n * 86400) end
        char.activity.day.on = { ["s:46"] = Day(9), ["s:40"] = Day(1) }
        eq((ns.Bond:NextOpen(PANDA)), "s:46", "no Turnus: the longest since out")
        ns.Turnus:Toggle(PANDA); ns.Turnus:Toggle("s:40")
        local key, days = ns.Bond:NextOpen(PANDA)
        eq(key, "s:40", "the Turnus pet, though the kitten waited longer"); eq(days, 1)
        ns.Bond:Today("s:40"); char.bondToday.pets["s:40"].total = ns.Bond:DailyMax("s:40")
        eq((ns.Bond:NextOpen(PANDA)), "s:46", "the Turnus pets full: anyone with room")
        -- Your adopted pet first, then whose turn it is today (not the list's order: what Turnus takes over with).
        ns.Turnus:Toggle("s:46"); char.bondToday.pets["s:40"].total = 0
        char.turnusDay.turn = "s:46"
        eq((ns.Bond:NextOpen(PANDA)), "s:46", "today's turn")
    end)

    test("a full day's nudge has a link: a click takes that pet out; a made-up key or a pet you don't own does nothing", function()
        local w, ola = H.Setup{ ola = { 5159, 46 } }
        ola:Slash("adopter panda"); w:Run(5)
        local ns = ola.ns
        ola:Summon(5159)
        ns.Bond:Today(PANDA); ns.Bond:Today("s:46")
        ns.DB.char.bondToday.pets["s:46"].total = 0
        ns.Bus:Fire("BOND_FULL", PANDA)
        match(ola:Printed("er fornøyd for i dag", true), "|Haddon:Dyreparken:swap:s:46|h%[Ta med White Kitten ut%]|h")
        ok(ola:ClickLink("Ta med White Kitten ut"))
        w:Run(2)
        eq(ns.Summon:ActiveKey(), "s:46"); eq(ns.Pets:KeyOf(ola.summoned), "s:46")
        -- Forged data: nothing.
        local env = ola.env
        env.EventRegistry:TriggerEvent("SetItemRef", "addon:Dyreparken:swap:s:40", "", "LeftButton") -- (not ours)
        env.EventRegistry:TriggerEvent("SetItemRef", "addon:Dyreparken:swap:x:junk", "", "LeftButton")
        env.EventRegistry:TriggerEvent("SetItemRef", "addon:Dyreparken:nosuch:s:5159", "", "LeftButton")
        env.EventRegistry:TriggerEvent("SetItemRef", "item:1234", "", "LeftButton")
        eq(ns.Summon:ActiveKey(), "s:46")
    end)

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
        eq(ola:CountPrinted("bodd hos deg"), 0, "not right at login: the sync comes first")
        w:Run(15)
        ok(ola:Printed("I dag har Panda Cub bodd hos deg i 1 måned!", true))
        ok(kari:Printed("Ola Nord og Panda Cub feirer 1 måned sammen i dag!", true))
        no(ola:Printed("Ola Nord og Panda Cub", true), "your own isn't in the guild list")
        -- Again the same day: nothing new.
        ola:Reload(); kari:Reload()
        w:Settle("day")
        eq(ola:CountPrinted("bodd hos deg"), 1)
        eq(kari:CountPrinted("feirer"), 1)
        -- The next day there's no milestone.
        w:SkipDays(1)
        kari:Reload()
        w:Settle("day")
        eq(kari:CountPrinted("feirer"), 1)
    end)

    test("the nickname is used, and long guild lists are cut", function()
        local w, ola = H.Setup{ ola = { 5159 }, settle = "bond" }
        ola:Slash("adopter")
        w:SkipDays(7)
        w:Befriend()
        ola:Slash("navn Pepe")
        local R = ola.ns.Registry
        local now = w:ServerTime()
        for i = 1, 7 do w:AddMember(("Medlem%d Etternavn"):format(i)) end
        ola.ns.Guild:Refresh(true) -- (only members' adoptions are kept: they're in the roster now)
        w:Run(1)
        for i = 1, 7 do
            local owner = ("Medlem%d Etternavn"):format(i)
            R:MergeRecord(owner, { k = "s:" .. (40 + i), at = now - 7 * 86400, ts = now })
        end
        R:Changed()
        w:SkipDays(93)
        ola:Reload()
        w:Settle("day")
        ok(ola:Printed("I dag har Pepe bodd hos deg i 100 dager!", true))
        -- (one line for all of them, 2026-11-19, the user)
        eq(ola:CountPrinted("feirer 100 dager sammen i dag!"), 0)
        ok(ola:Printed("I dag feirer Medlem1 Etternavn, Medlem2 Etternavn, Medlem3 Etternavn og 4 til en merkedag med dyret sitt!", true))
    end)

    test("nickname unlock: told once per adoption, inherited names too", function()
        local w, ola, kari = Setup()
        w:SkipDays(7)
        w:Befriend()
        ola:Reload()
        w:Settle("day")
        ok(ola:Printed("Nå kan du gi Panda Cub et kallenavn: trykk Kallenavn på kortet, eller /dp navn.", true))
        ola:Reload()
        w:Settle("day")
        eq(ola:CountPrinted("Nå kan du gi"), 1)
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
        ok(kari:Printed("Nå kan du gi Pepe et nytt kallenavn hvis du vil: trykk Kallenavn på kortet, eller /dp navn.", true))
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
        c:ClearPrinted() -- (a new player's welcome)
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
        -- /klapp on its own: the same (2026-11-19, the user).
        ola:Chat("/klapp")
        eq(Emotes(ola)[3], "klapper Pepe.", "/klapp, the same as /dp klapp")
        ola:Chat("/dp klapp")
        eq(Emotes(ola)[4], "klapper Pepe.", "and /dp klapp typed in the chat box")
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
        ok(kari:Printed(kari.ns.L["pat.combat"], true))
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
        -- Someone else's adoption or letting go mid-day: today's pet stays unless it was theirs or theirs outscores it
        -- (2026-11-23, the user: it changed at random times). Over days, with ten pets adopted: it rarely moves.
        local B = ola.ns.Bonds
        eq(B.Hash("dagens dyr"), 4046441398, "the same number on every client (a fixed hash)")
        local keys = {}
        for i = 1, 10 do keys[i] = "s:" .. (100 + i) end
        local function Pick(list, day)
            local p, b
            for _, k in ipairs(list) do
                local sc = B.Hash("dagens dyr " .. day .. " " .. k)
                if not b or sc > b then p, b = k, sc end
            end
            return p
        end
        local moved = 0
        for d = 1, 200 do
            local day = ola.ns.Today(ola.ns.Now() + d * 86400)
            local more = { unpack(keys) }; more[#more + 1] = "s:999"
            if Pick(more, day) ~= Pick(keys, day) then moved = moved + 1 end
        end
        ok(moved > 0 and moved < 50, "a new pet took the crown on " .. moved .. " of 200 days (about 1 in 11)")
        -- And in the world: a guildmate whose pet isn't today's lets it go: the same pick, for everyone.
        local before = B:PetOfTheDay()
        local other = before ~= "s:40" and kari or per
        other:Slash("gislipp"); w:Run(10)
        eq(B:PetOfTheDay(), before, "letting go of another pet: today's stays")
        eq(kari.ns.Bonds:PetOfTheDay(), before)
        other:Slash("adopter"); w:Run(10)
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

    test("day numbers are calendar days, across DST and the year's end", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local D = c.ns.Bonds.DayNumber
        local function T(y, m, d, h, min) return os.time({ year = y, month = m, day = d, hour = h, min = min or 0 }) end
        eq(D(T(2027, 3, 28, 23, 30)) - D(T(2027, 3, 27, 0, 30)), 1, "over the spring's short night")
        eq(D(T(2026, 10, 25, 23, 59)) - D(T(2026, 10, 25, 0, 1)), 0, "the autumn's long day is one day")
        eq(D(T(2027, 1, 1, 0, 5)) - D(T(2026, 12, 31, 23, 55)), 1)
        eq(D(T(2028, 3, 1, 12)) - D(T(2028, 2, 28, 12)), 2, "a leap year's 29 February")
    end)

    -- 2026-11-22, the user: /bonk, /boop and /pat at the pet, three answers each.
    test("your /bonk, /boop and /pat at the pet that's out: it answers, once a minute per emote; not someone else's", function()
        local w, ola = Setup()
        ola:Summon(5159); w:Run(1)
        local me = ola.env.UnitGUID("player")
        local function Emote(text, guid) ola:Fire("CHAT_MSG_TEXT_EMOTE", text, "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, guid or me) end
        local before = #ola.printed
        Emote("You bonk Panda Cub on the noggin. Doh!")
        Emote("You boop Panda Cub on the nose.")
        Emote("You gently pat Panda Cub.")
        local said = {}
        for i = before + 1, #ola.printed do said[#said + 1] = ola.printed[i] end
        eq(#said, 3, "an answer each")
        for _, kind in ipairs({ "bonk", "boop", "pat" }) do
            local hit = false
            for n = 1, 3 do
                local want = ola.ns.T("emote." .. kind .. "." .. n, { pet = "Panda Cub" })
                for _, line in ipairs(said) do if line:find(want, 1, true) then hit = true end end
            end
            ok(hit, kind .. ": one of its lines")
        end
        Emote("You gently pat Panda Cub."); eq(#ola.printed, before + 3, "again within the minute: nothing")
        w:Run(61); Emote("You gently pat Panda Cub."); eq(#ola.printed, before + 4, "a minute on: again")
        w:Run(61)
        Emote("You gently pat Bombay Cat."); Emote("You bonk Kari Berg on the noggin. Doh!")
        Emote("Kari Berg gently pats Panda Cub.", "Player-0000-00000099")
        eq(#ola.printed, before + 4, "another pet, a player, someone else's emote: nothing")
    end)
end
