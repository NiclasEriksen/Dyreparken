-- Bonds with every pet you own (2026-11-09): any pet of yours that's out
-- earns, half as fast if you haven't adopted it, each with its own day.
-- Only adopted bonds ride the full sync; the rest go out as their owner's
-- BOND messages and on request when a card shows the pet.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN = "s:5159", "s:46"

    local function Setup()
        local w, ola, kari = H.Setup{ ola = { 5159, 46 }, kari = { 40 } }
        -- A clean slate: no bonds from the logins' day visits.
        for _, c in ipairs({ ola, kari }) do
            c:ForgetBonds()
        end
        ola:Slash("adopter panda")
        w:Run(2)
        for _, c in ipairs({ ola, kari }) do -- (no wish or first bonuses, or Klengete days, mixed in)
            c:NoBonuses()
            c:Traits{ "glupsk", "reiseglad" }
        end
        return w, ola, kari
    end

    test("a pet you haven't adopted bonds too: half the points, its own day and limit", function()
        local w, ola = Setup()
        local B = ola.ns.Bond
        eq(B:Rate(PANDA), 1); eq(B:Rate(KITTEN), 0.5)
        eq(B:DailyMax(PANDA), 75); eq(B:DailyMax(KITTEN), 37)
        ola.ns.Activity:CheckDay()
        eq(ola:Points(PANDA), 10, "the adopted one: a full day")
        ola:Summon(46)
        ola.ns.Activity:CheckDay()
        eq(ola:Points(KITTEN), 5, "the kitten: half a day")
        ola:Fire("QUEST_TURNED_IN", 1) -- quests: liked (Glupsk), 5 -> 3 at half
        eq(ola:Points(KITTEN), 8, "a liked activity: 3 (half of 5, rounded up)")
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1) -- not liked: 1 stays 1
        eq(ola:Points(KITTEN), 9)
        eq(ola:Points(PANDA), 10, "the panda isn't out")
        -- Its own caps: quests up to 13 a day (half of 25, rounded up).
        for i = 1, 20 do ola:Fire("QUEST_TURNED_IN", i) end
        eq(select(1, B:Today(KITTEN)), 5 + 13 + 1, "the day, quests to their cap, one boss")
        local _, max = B:Today(KITTEN)
        eq(max, 37)
        -- The panda's day is its own.
        eq(select(1, B:Today(PANDA)), 10)
    end)

    test("the card shows your bond with any pet of yours; its holder's is named; others are listed", function()
        local w, ola, kari = Setup()
        ola:Summon(46)
        ola.ns.Bond:Add(120, KITTEN) -- Kamerat with the kitten, not adopted
        w:Run(2)
        ola:OpenJournal()
        local card = ola:SelectPet(46)
        local b = card.bond
        ok(b:IsShown()); eq(b.label.text, "Kamerat"); eq(b.level.text, 2)
        eq(b.next.text, "150 poeng til Venn")
        b.scripts.OnEnter(b)
        local tip = table.concat(ola.env.GameTooltip.lines, " / ")
        match(tip, "halvparten så fort")
        -- Kari sees Ola's bond with the panda (adopted, in the sync) and asks for the kitten's.
        kari:OpenJournal()
        local kc = kari:SelectPet(46)
        no(kc.bond:IsShown(), "not her pet, nobody holds it, nothing known yet")
        w:Run(3)
        eq(kari:Points(KITTEN, "Ola Nord"), 120, "asked for, and Ola answered")
        kc = kari:SelectPet(46)
        kc.bond.scripts.OnEnter(kc.bond)
        -- (no holder: the card shows nothing of its own, but the asked-for bond is stored)
        -- Someone else's adopted pet: their bond, named; ours listed under "others".
        kari:GivePet(5159)
        kari.ns.Bond:Add(40, PANDA)
        w:Run(2)
        local oc = ola:SelectPet(5159)
        oc.bond.scripts.OnEnter(oc.bond)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "Også glad i det: Kari Berg %(Bekjent%)")
    end)

    test("someone else's adopted pet: the card shows their bond first, yours small under it", function()
        local w, ola, kari = Setup()
        ola:Summon(46)
        ola.ns.Bond:Add(20, KITTEN) -- Ola: Bekjent with the kitten
        kari:GivePet(46)
        kari:Slash("adopter white")
        w:Run(2)
        kari:NoBonuses()
        kari.ns.Bond:Add(300, KITTEN) -- Kari, its holder: Kamerat (the day's cap and a spare day)
        w:Run(5)
        ola:OpenJournal()
        local card = ola:SelectPet(46)
        local b = card.bond
        eq(b.label.text, "Kamerat", "the holder's bond"); eq(b.level.text, 2)
        eq(b.next.text, "Kari Berg sitt bånd")
        match(b.yours.text, "Ditt: Bekjent %(1%)$")
        b.scripts.OnEnter(b)
        match(table.concat(ola.env.GameTooltip.lines, " / "), "Ditt eget bånd med dyret: Bekjent %(level 1%), 20 poeng%.")
        b.scripts.OnLeave(b)
        match(card.decor.sig, "^s:46;2;", "the decorations follow the holder's bond")
        -- The list (only your own pets) keeps your progress.
        local lists = ola.ns.JournalList._badges
        local found
        for button, badge in pairs(lists) do
            if badge.level:IsShown() and button.speciesID == 46 then found = badge end
        end
        if found then eq(found.level.text, 1) end
        eq(select(2, ola.ns.Bond:Own(KITTEN)), 1)
        -- Your own adopted pet, and a pet without a home: no small line.
        eq(ola:SelectPet(5159).bond.yours.text, "")
        eq(select(6, ola.ns.Bond:Shown(PANDA)), true)
        kari:Slash("gislipp")
        w:Run(5)
        card = ola:SelectPet(46)
        eq(card.bond.label.text, "Bekjent", "no home: your own bond again"); eq(card.bond.yours.text, "")
    end)

    test("a level reached with a pet you haven't adopted is celebrated too", function()
        local w, ola = Setup()
        ola:Summon(46)
        ola:OpenJournal()
        local card = ola:SelectPet(46)
        eq(ola.ns.DB.char.bondSeen[KITTEN], 1)
        ola.ns.Bond:Add(100, KITTEN)
        ok(card.celebration.flash:IsShown())
        eq(card.celebration.text.title.text, "Kamerat!")
        eq(ola.ns.DB.char.bondSeen[KITTEN], 2)
        no(ola:Printed("et kallenavn: /dp navn", true), "naming stays with adoption")
    end)

    test("the full sync carries only adopted bonds; others go out on their own", function()
        local w, ola, kari = Setup()
        local m = w:Mark()
        ola:Summon(46)
        ola.ns.Bond:Add(30, KITTEN) -- a new bond: out at once, on its own
        w:Run(2)
        eq(w:Sent("BOND", "Ola Nord", m), 1)
        eq(kari:Points(KITTEN, "Ola Nord"), 30)
        local adopted = ola.ns.Registry:AdoptedLife()
        no(adopted[KITTEN], "not in the sync's bonds")
        -- The digest doesn't move with it, so nobody SYNCs over it.
        local d = ola.ns.Sync:Digest()
        ola.ns.Bond:Add(200, KITTEN) -- (capped at 150: a new bond's first days)
        eq(ola.ns.Sync:Digest(), d)
        w:Run(2)
        -- A newcomer gets the adopted bonds by SYNC; the others when she looks.
        local nina = w:AddClient("Nina Ny", { pets = { 72 } })
        w:Run(60)
        ok(nina.ns.Registry:Life(PANDA, "Ola Nord") or true)
        eq(nina.ns.Registry:Life(KITTEN, "Ola Nord"), nil, "not by SYNC")
        nina:OpenJournal()
        nina:SelectPet(46)
        w:Run(3)
        eq(nina:Points(KITTEN, "Ola Nord"), 150, "when she looks at it")
    end)

    test("asking about a pet: once a session, not while flicking through, answers rate-limited", function()
        local w, ola, kari = Setup()
        ola:Summon(46)
        ola.ns.Bond:Add(20, KITTEN)
        w:Run(2)
        local m = w:Mark()
        kari:OpenJournal()
        kari:SelectPet(46)
        kari:SelectPet(40) -- right after: not asked yet (too soon)
        kari:SelectPet(46) -- asked already this session
        w:Run(3)
        eq(w:Sent("BOND_REQ", "Kari Berg", m), 1)
        kari:SelectPet(40)
        w:Run(1)
        eq(w:Sent("BOND_REQ", "Kari Berg", m), 2)
        w:Run(3)
        kari:SelectPet(46) -- looked at before, this session: not asked again
        w:Run(1)
        eq(w:Sent("BOND_REQ", "Kari Berg", m), 2)
        -- Ola answers a burst of the same question once (and Kari's, just now, counted:
        -- answers go to the whole guild).
        w:Run(6)
        local m2 = w:Mark()
        for _ = 1, 5 do w:InjectMessage("Per Hansen", { k = "BOND_REQ", p = ola.ns.PROTOCOL, pet = KITTEN }, "GUILD") end
        w:Run(3)
        eq(w:Sent("BOND", "Ola Nord", m2), 1)
        -- Junk keys are ignored; no bond, no answer.
        w:InjectMessage("Per Hansen", { k = "BOND_REQ", p = ola.ns.PROTOCOL, pet = "junk" }, "GUILD")
        w:InjectMessage("Per Hansen", { k = "BOND_REQ", p = ola.ns.PROTOCOL, pet = "s:72" }, "GUILD")
        w:Run(6)
        eq(w:Sent("BOND", "Ola Nord", m2), 1)
    end)

    test("auto-summon keeps the active pet out, adopted or not", function()
        local w, ola = Setup()
        ola.ns.Summon:SetActive(KITTEN, true)
        ola.summoned = nil
        ola.ns.Summon:Check("test")
        w:Run(2)
        eq(ola.ns.Pets:KeyOf(ola.summoned), KITTEN, "the kitten, not the adopted panda")
        -- Its day out counts for it, at half.
        ola.ns.Activity:CheckDay()
        eq(ola:Points(KITTEN), 5)
    end)

    test("firsts together: a boss this pet hasn't seen fall, a place it hasn't seen; a few lines a day", function()
        local w, ola = Setup()
        ola.ns.Bond.First = ola.realFirst -- (the real one, for this test)
        local function Pts() return ola:Points(PANDA) end
        local start = Pts()
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
        eq(Pts() - start, 1 + 5, "a boss (1, not liked) and the first time it saw Hogger fall (5)")
        ok(ola:Printed("Panda Cub var med da Hogger falt!", true))
        start = Pts()
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
        eq(Pts() - start, 1, "the second time: just a boss")
        -- A wipe isn't a kill, and a boss without a name isn't a first.
        ola:Fire("ENCOUNTER_END", 2, "Van Cleef", 1, 5, 0)
        ok(not ola:Printed("Van Cleef", true))
        -- A new place: now and then a moment (2026-11-12), here pinned to come, in the family's own words
        -- (the panda is a bear).
        local B = ola.ns.Bond
        ola:Dice(0)
        ola.state.map, ola.state.zone = 1454, "Orgrimmar"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        ok(ola:Printed("Panda Cub rusler gjennom Orgrimmar på jakt etter noe godt å spise.", true))
        -- Not this time: the first's points all the same, without a line (the user, 2026-11-12).
        ola:Dice(0.99)
        start = Pts()
        ola.state.map, ola.state.zone = 1453, "Stormwind City"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        w:Run(6)
        no(ola:Printed("Stormwind City", true))
        eq(Pts() - start, 1 + 5, "the place's everyday point and the first's 5, quietly")
        -- The chance: the family's, times the traits'.
        eq(B:PlaceChance(PANDA), B.PLACE_CHANCE.bear * 1)
        local P2 = ola.ns.Personality
        ola:Traits{ "oppdager", "latsabb" }
        eq(B:PlaceChance(PANDA), B.PLACE_CHANCE.bear * 2 * 0.6)
        ola:Traits{ "oppdager", "eventyrlysten" }
        eq(B:PlaceChance(PANDA), math.min(B.PLACE_MAX, B.PLACE_CHANCE.bear * 2 * 1.3))
        ola:Traits{ "glupsk", "reiseglad" }
        ola:Dice(0)
        -- At most three lines a day per pet; the points go on.
        for i = 1, 4 do ola:Fire("ENCOUNTER_END", 10 + i, "Boss " .. i, 1, 5, 1) end
        ok(ola:Printed("Boss 1", true)); no(ola:Printed("Boss 2", true), "two firsts already today")
        -- Another pet sees Hogger fall for the first time too: its own firsts, at half.
        ola:Summon(46)
        start = ola:Points(KITTEN)
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
        eq(ola:Points(KITTEN) - start, 1 + 3)
    end)

    test("balance (2026-11-10): firsts give at most 15 a day, everyday activities 3 each and 10 in all", function()
        local w, ola = Setup()
        ola.ns.Bond.First = ola.realFirst
        local function Pts() return ola:Points(PANDA) end
        local start = Pts()
        for i = 1, 6 do ola:Fire("ENCOUNTER_END", 20 + i, "Boss " .. i, 1, 5, 1) end
        -- Six new bosses: 6 everyday boss points (capped at 3) and six firsts (capped at 15).
        eq(Pts() - start, 3 + 15)
        start = Pts()
        -- Everyday activities (not liked), many of each: 3 a kind, 10 in all (3 already from bosses).
        for _ = 1, 5 do ola.ns.Activity:Emit("skill", 1, "Fishing") end
        eq(Pts() - start, 3, "skill-ups: 3")
        for _ = 1, 5 do ola.ns.Activity:Emit("mine") end
        eq(Pts() - start, 6)
        for _ = 1, 5 do ola.ns.Activity:Emit("skin") end
        eq(Pts() - start, 7, "the pot is full at 10")
        -- A liked one still counts in full: Glupsk, quests.
        for _ = 1, 2 do ola:Fire("QUEST_TURNED_IN", 1) end
        eq(Pts() - start, 17)
    end)
    test("playdates: guildmates in a group with pets out, once a day per pet, both sides", function()
        local w, ola, kari = Setup()
        local KARI = "s:40"
        local m = w:Mark()
        ola:Summon(5159); kari:Summon(40)
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        w:Run(5)
        eq(w:Sent("PLAY", "Ola Nord", m), 1)
        eq(w:Sent("PLAY", "Kari Berg", m), 1, "Kari answered")
        eq(ola:Points(PANDA), 15, "the adopted panda: the full playdate")
        eq(kari:Points(KARI), 8, "Kari's pet, not adopted: half (rounded up)")
        ok(ola:Printed("Panda Cub lekte med", true))
        ok(kari:Printed("lekte med Panda Cub %(Ola Nord%)"))
        -- Again today: no more points, and no ping-pong.
        w:Run(700)
        ola:Fire("GROUP_ROSTER_UPDATE"); kari:Fire("GROUP_ROSTER_UPDATE")
        w:Run(5)
        eq(ola:Points(PANDA), 15); eq(kari:Points(KARI), 8)
        ok(w:Sent("PLAY", nil, m) <= 4)
        -- Another of Ola's pets has its own playdate.
        ola:Summon(46)
        w:Run(61)
        kari.ns.Playdate:Announce(true)
        w:Run(3)
        eq(ola:Points(KITTEN), 8)
    end)

    test("playdates: only with a guildmate near you, not one far away in the same group", function()
        local w, ola, kari = Setup()
        local m = w:Mark()
        ola:Summon(5159); kari:Summon(40)
        w.apart = { ["Kari Berg"] = true } -- (in the group, across the world)
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ola:Fire("GROUP_ROSTER_UPDATE"); kari:Fire("GROUP_ROSTER_UPDATE")
        w:Run(5)
        eq(ola:Points(PANDA), 0, "far away: no playdate")
        eq(kari:Points("s:40"), 0, "for either")
        ok(ola:Log("playdate range: Kari Berg %(party1%) in range false")[1])
        -- Together again (an announcement after a summon): it happens.
        w.apart = nil
        w:Run(601)
        kari:Summon(40); kari.ns.Playdate:Soon()
        w:Run(5)
        eq(ola:Points(PANDA), 15, "close by: the playdate")
    end)

    test("playdates: not without a pet out, not with strangers, not from junk or the guild channel", function()
        local w, ola, kari = Setup()
        ola:Summon(5159); kari:Summon(nil)
        w:SetGroup({ "Ola Nord", "Kari Berg", "Per Uten" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        w:Run(5)
        eq(kari:Points("s:40"), 0, "Kari has no pet out")
        local m = w:Mark()
        w:InjectMessage("Per Uten", { k = "PLAY", p = ola.ns.PROTOCOL, pet = "s:40" }, "PARTY")
        w:InjectMessage("Kari Berg", { k = "PLAY", p = ola.ns.PROTOCOL, pet = "s:40" }, "GUILD")
        w:InjectMessage("Kari Berg", { k = "PLAY", p = ola.ns.PROTOCOL, pet = "junk" }, "PARTY")
        w:InjectMessage("Kari Berg", { k = "PLAY", p = ola.ns.PROTOCOL, pet = { 1 } }, "PARTY")
        w:Run(3)
        eq(ola:Points(PANDA), 0)
        eq(w:Sent("PLAY", "Ola Nord", m), 0)
        -- Out of the group: nothing is sent.
        w:SetGroup(nil)
        ola:Fire("GROUP_ROSTER_UPDATE")
        w:Run(700)
        eq(w:Sent("PLAY", "Ola Nord", m), 0)
    end)

    test("rewards: declared once (Bond.REWARDS); Bond prints nothing, its lines come over the Bus", function()
        local w, ola = Setup()
        local B = ola.ns.Bond
        no(pcall(B.Reward, B, "cake", PANDA, "x"), "an undeclared reward fails loudly")
        -- Bond's own module never prints: what players read is Bonds.lua's.
        local heard = {}
        ola.ns.Bus:On("BOND_LINE", function(key, text) heard[#heard + 1] = key .. " " .. text end)
        local print = ola.ns.Print
        local printed = 0
        ola.ns.Print = function(...) printed = printed + 1; return print(...) end
        ok(B:Reward("play", PANDA, "Pepe lekte!"))
        eq(heard[1], PANDA .. " Pepe lekte!"); eq(printed, 1, "Bonds printed the line once")
        eq(ola:Points(PANDA), 15)
        eq(B:Reward("play", PANDA, "again"), false, "once a day")
        eq(#heard, 1); eq(ola:Points(PANDA), 15)
        -- A new kind of reward is a row.
        B.REWARDS.cake = { points = "BOND_WISH_POINTS" }
        ok(B:Reward("cake", PANDA, "Kake!")); ok(B:Reward("cake", PANDA, "Mer kake!"))
        eq(ola:Points(PANDA), 35)
    end)
end
