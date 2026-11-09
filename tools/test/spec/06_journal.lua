-- The pet journal: list markers, tooltips, the card, buttons, popup, checkbox.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
    local MINE, TAKEN, FREE = MEDIA .. "heart", MEDIA .. "paw", MEDIA .. "house"

    -- Ola owns Panda Cub (reserved) and White Kitten (free); Kari holds Bombay Cat.
    local function Setup(journalOpts, olaOpts)
        olaOpts = olaOpts or {}
        olaOpts.pets = olaOpts.pets or { 5159, 46 }
        local w, ola, kari = H.Setup{ ola = olaOpts, kari = { 40 }, settle = "bond" }
        ola:Slash("adopter panda")
        kari:Slash("adopter")
        w:Run(2)
        journalOpts = journalOpts or {}
        journalOpts.extra = journalOpts.extra or { 40, 68 }
        ola:OpenJournal(journalOpts)
        return w, ola, kari
    end

    test("markers: star for yours, lock for taken, check for yours to claim", function()
        local w, ola = Setup()
        eq(ola:Marker(5159), MINE)
        eq(ola:Marker(46), FREE)
        eq(ola:Marker(40), TAKEN)
        eq(ola:Marker(68), nil, "not owned and free: no marker")
    end)

    test("markers work from the journal index when buttons carry no species", function()
        local w, ola = Setup({ bare = true })
        eq(ola:Marker(5159), MINE)
        eq(ola:Marker(40), TAKEN)
        eq(ola:Marker(68), nil)
    end)

    test("markers work through ScrollUtil when the init hook is missing", function()
        local w, ola = Setup({ scrollUtil = true })
        eq(ola:Marker(5159), MINE)
        eq(ola:Marker(40), TAKEN)
    end)

    test("the open journal follows registry changes; a closed one waits", function()
        local w, ola, kari = Setup()
        kari:Slash("gislipp")
        w:Run(1)
        eq(ola:Marker(40), nil, "refreshed while open")
        ola:CloseJournal()
        kari.ns.Registry:Claim("s:40")
        w:Run(1)
        eq(ola:Marker(40), nil, "no work while closed")
        ola.env.CollectionsJournal:Show()
        eq(ola:Marker(40), TAKEN, "refreshed on show")
    end)

    test("list tooltips show owner, nickname and date", function()
        local w, ola, kari = Setup()
        w:SkipDays(7)
        w:Befriend()
        kari:Slash("navn Mjau")
        w:Run(1)
        local tip = ola.env.GameTooltip
        local b = ola:Button(40)
        b.scripts.OnEnter(b)
        local text = table.concat(tip.lines, " / ")
        match(text, "^Bombay Cat / ")
        match(text, "Bor hos Kari Berg i 7 dager")
        match(text, 'Kallenavn: «Mjau»')
        ok(tip.shown)
        b.scripts.OnLeave(b)
        no(tip.shown)
        local mine = ola:Button(5159)
        tip:SetOwner(mine) -- Blizzard already wrote its tooltip
        tip:AddLine("Blizzard's line")
        mine.scripts.OnEnter(mine)
        match(table.concat(tip.lines, " / "), "^Blizzard's line / .*Bor hos deg")
        local free = ola:Button(68)
        free.scripts.OnEnter(free)
        match(table.concat(tip.lines, " / "), "Dyreparken: trenger et hjem")
        -- A button without a species does nothing.
        ola:ListPets({ bare = true, extra = { 999 } })
        ola.journalList[#ola.journalList].sid = nil
        ola:ListPets({ bare = true })
        local blank = ola.env.CreateFrame("Button", nil, ola.env.PetJournal)
        ola.env.PetJournal_InitPetButton(blank, {})
        tip:SetOwner(nil)
        blank.scripts.OnEnter(blank)
        eq(#tip.lines, 0)
        no(blank.textures[1].shown, "no marker without a species")
    end)

    test("card: your pet offers Gi slipp, the nickname unlocks at bond level Venn", function()
        local w, ola = Setup()
        local card = ola:SelectPet(5159)
        eq(card.status.plain, "Flyttet inn hos deg i dag")
        eq(card.reserve.text, "Gi slipp")
        ok(card.reserve.shown and card.nick.shown)
        no(card.nick.enabled, "locked until Venn")
        local tip = ola.env.GameTooltip
        card.nick.scripts.OnEnter(card.nick)
        eq(tip.lines[1], "Du kan gi det et kallenavn når båndet deres er Venn (nivå 3).")
        card.nick.scripts.OnLeave(card.nick)
        w:SkipDays(7)
        w:Befriend()
        card = ola:SelectPet(5159, true) -- the card can also come with a petID
        ok(card.nick.enabled)
        card.nick:Click()
        eq(ola.popup.which, "DYREPARKEN_NICKNAME")
        eq(ola.popup.args[1], 20)
        ola:PopupAccept("Bambus")
        eq(ola.ns.Registry:Nickname("s:5159"), "Bambus")
        ok(ola:Printed('Kallenavnet er nå «Bambus».'))
        eq(card.nickname.text, "Bambus", "big, on its own line")
        eq(card.status.plain, "Panda Cub · Bor hos deg i 7 dager", "named: the species leads")
        -- The popup shows the current nickname; Enter also accepts.
        ola.ns.CardActions:AskNickname()
        local shown, frame = ola:PopupAccept("Bamse", true)
        eq(shown, "Bambus")
        ok(frame.hidden)
        eq(ola.ns.Registry:Nickname("s:5159"), "Bamse")
        -- Escape closes it.
        local eb = { GetParent = function() return frame end }
        frame.hidden = false
        ola.env.StaticPopupDialogs.DYREPARKEN_NICKNAME.EditBoxOnEscapePressed(eb)
        ok(frame.hidden)
        tip:SetOwner(nil)
        card.nick.scripts.OnEnter(card.nick)
        eq(#tip.lines, 0, "no tooltip once unlocked")
    end)

    test("card: Release and Reserve buttons", function()
        local w, ola, kari = Setup()
        local card = ola:SelectPet(5159)
        card.reserve:Click()
        eq(ola.ns.Registry:MyPet(), nil)
        ok(ola:Printed("Du ga slipp på Panda Cub."))
        eq(card.reserve.text, "Adopter")
        no(card.nick.shown)
        eq(card.status.plain, "Trenger et hjem")
        card = ola:SelectPet(46)
        card.reserve:Click()
        eq(ola.ns.Registry:MyPet(), nil, "not before it's confirmed")
        eq(ola.popup.which, "DYREPARKEN_ADOPT")
        eq(ola.popup.args[1], "Adoptere White Kitten?\n\nAdopsjonen blir kunngjort i guild-chatten, så hele guilden får se den."
            .. " (Slå av med /dp kunngjør.)")
        ola:PopupAccept()
        eq(ola.ns.Registry:MyPet(), "s:46")
        ok(ola:Printed("Du adopterte White Kitten."))
        w:Run(1)
        eq(kari.ns.Registry:Holder("s:46"), "Ola Nord")
        eq(ola:Marker(46), MINE)
    end)

    test("card: someone else's pet and pets you don't own get no buttons", function()
        local w, ola, kari = Setup()
        w:SkipDays(7)
        w:Befriend()
        kari:Slash("navn Mjau")
        w:Run(1)
        local card = ola:SelectPet(40)
        eq(card.status.plain, 'Bombay Cat · Bor hos Kari Berg i 7 dager')
        eq(card.nickname.text, "Mjau")
        no(card.reserve.shown); no(card.nick.shown)
        card = ola:SelectPet(68)
        eq(card.status.plain, "Trenger et hjem")
        no(card.reserve.shown)
        local pc = ola.env.PetJournalPetCard
        pc.speciesID, pc.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(pc)
        eq(card.status.plain, "")
        no(card.reserve.shown)
    end)

    test("counter: cared for of every companion in Forever, with a percentage", function()
        local w, ola = Setup()
        local card = ola:SelectPet(5159)
        eq(card.counter.text, "2 av 83 (2%)", "the stub's count")
        -- A generated species list replaces the stub's count.
        ola.ns.Companions.species = { [5159] = true, [46] = true, [40] = true, [68] = true }
        ola:SelectPet(46)
        eq(card.counter.text, "2 av 83 (2%)", "a pick doesn't redraw the guild's boxes")
        ola.ns.JournalUI:Refresh() -- (the guild's boxes: redrawn on a refresh, not on a pick)
        eq(card.counter.text, "2 av 4 (50%)")
        ola.ns.Companions = nil
        ola.ns.JournalUI:Refresh()
        eq(card.counter.text, "2 av 0 (0%)", "no data: no division by zero")
    end)

    test("Med deg: the badge on the card picks the pet kept out; adopting makes it so; one at a time", function()
        local w, ola = Setup()
        local posts = #w.chat
        local card = ola:SelectPet(5159)
        local b = card.auto
        ok(b:IsShown()); ok(b.on, "the adopted panda is kept out")
        eq(b.label.text, "Med deg"); no(b.ring.desaturated)
        eq(ola.ns.Summon:ActiveKey(), "s:5159")
        -- The kitten's card: not the active one.
        card = ola:SelectPet(46)
        no(b.on); eq(b.label.text, "Ta med ut"); ok(b.ring.desaturated)
        local tip = ola.env.GameTooltip
        b.scripts.OnEnter(b)
        eq(tip.lines[1], "Ta med White Kitten ut")
        match(tip.lines[2], "^Summoner White Kitten når det er fraværende")
        eq(tip.lines[3], "Nå holdes Panda Cub ute.")
        b.scripts.OnLeave(b)
        b:Click()
        eq(ola.ns.Summon:ActiveKey(), "s:46", "now the kitten, adopted or not")
        ok(b.on); ok(b.burst:IsShown(), "a burst as it comes along")
        w:Run(2)
        eq(ola.ns.Pets:KeyOf(ola.summoned), "s:46", "chosen on the card: it replaces the pet out")
        no(ola:SelectPet(5159).auto.on, "one at a time")
        eq(ola.env.DyreparkenCharDB.activePet, "s:46")
        -- Back to the panda: it comes out again (seen 2026-11-09: it didn't).
        ola:SelectPet(5159).auto:Click()
        w:Run(2)
        eq(ola.ns.Pets:KeyOf(ola.summoned), "s:5159")
        -- A later trigger never replaces a pet you summoned yourself.
        ola:Summon(46)
        ola.ns.Summon:Check("PLAYER_ENTERING_WORLD")
        w:Run(2)
        eq(ola.ns.Pets:KeyOf(ola.summoned), "s:46")
        -- The badge again: auto-summon off.
        card = ola:SelectPet(5159)
        card.auto:Click()
        eq(ola.ns.Summon:ActiveKey(), nil)
        no(ola.ns.Summon:Enabled()); no(card.auto.on)
        eq(#w.chat, posts, "choosing which pet to keep out posts nothing")
        -- A pet we don't own: "Ikke samlet" in the badge's place, dim, and a click does nothing.
        card = ola:SelectPet(40)
        ok(card.auto:IsShown()); ok(card.auto.notOwned)
        eq(card.auto.label.text, "Ikke samlet")
        card.auto.scripts.OnEnter(card.auto)
        eq(ola.env.GameTooltip.lines[1], "Ikke samlet")
        match(ola.env.GameTooltip.lines[2], "^Du har ikke Bombay Cat i samlingen din")
        card.auto.scripts.OnLeave(card.auto)
        card.auto.scripts.OnClick(card.auto)
        eq(ola.ns.Summon:ActiveKey(), nil, "not taken along")
        -- Back on one of ours: the badge again.
        card = ola:SelectPet(5159)
        no(card.auto.notOwned); eq(card.auto.label.text, "Ta med ut")
        -- Adopting makes a pet the active one, turns auto-summon back on, and swaps it in.
        ola:Summon(5159)
        ola:Slash("adopter white kitten")
        w:Run(2)
        eq(ola.env.DyreparkenCharDB.activePet, "s:46")
        ok(ola.ns.Summon:Enabled())
        eq(ola.ns.Pets:KeyOf(ola.summoned), "s:46", "out in place of the panda")
        -- Other edits of our record leave the active pet alone.
        ola:SelectPet(5159).auto:Click()
        ola.ns.Bond:Add(600, "s:46") -- (Venn: naming unlocked)
        ola:Slash("navn Mjau")
        w:Run(2)
        eq(ola.ns.Summon:ActiveKey(), "s:5159", "a nickname doesn't move it")
    end)

    test("the list marks the pet kept out with a paw on its icon", function()
        local w, ola = Setup()
        ola:SelectPet(5159)
        local function Paw(sid)
            for button, b in pairs(ola.ns.JournalList._badges) do
                if button.speciesID == sid then return b.out:IsShown() end
            end
        end
        ok(Paw(5159)); no(Paw(46))
        ola:SelectPet(46).auto:Click()
        ok(Paw(46)); no(Paw(5159), "only the active one")
    end)

    test("with AutoCompanion the badge is greyed out", function()
        local w, ola = Setup(nil, { addons = { "AutoCompanion" } })
        local card = ola:SelectPet(5159)
        no(card.auto.on)
        no(card.auto.enabled)
        eq(card.auto.label.text, "Ta med ut")
        card.auto.scripts.OnEnter(card.auto)
        eq(ola.env.GameTooltip.lines[1], "AutoCompanion er lastet og tar seg av summoning.")
    end)

    test("opening the journal requests the roster (throttled)", function()
        local w, ola = Setup()
        local n = ola.rosterRequests
        ola:CloseJournal()
        ola.env.CollectionsJournal:Show()
        eq(ola.rosterRequests, n, "the login roster is recent")
        w:Skip(301)
        ola:CloseJournal()
        ola.env.CollectionsJournal:Show()
        eq(ola.rosterRequests, n + 1)
    end)

    test("Blizzard_Collections loaded before us, or without a journal", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { addons = { "Blizzard_Collections" } })
        eq(#c:Log("Blizzard_Collections loaded; PetJournal=false"), 1)
        c.ns.JournalUI:Refresh() -- nothing to refresh, no error
        local d = w:AddClient("Kari Berg")
        d.loaded.Blizzard_Collections = true
        d:Fire("ADDON_LOADED", "SomethingElse")
        d:Fire("ADDON_LOADED", "Blizzard_Collections")
        eq(#d:Log("PetJournal=false"), 1)
    end)

    test("the addon never touches the journal filters (the harness throws if it does)", function()
        local w, ola = Setup()
        local J = ola.env.C_PetJournal
        local okCall, err = pcall(J.SetDefaultFilters)
        no(okCall)
        match(err, "must not change the pet journal filters")
        ola:OpenJournal()
        ola:SelectPet(5159)
    end)

    test("adopting from the card asks first: what it lets go of, and that the guild will see it", function()
        local w, ola, kari = Setup()
        ola:Slash("adopter panda")
        ola:OpenJournal()
        local card = ola:SelectPet(46)
        card.reserve:Click()
        eq(ola.popup.args[1], "Adoptere White Kitten?\nDu gir da slipp på Panda Cub.\n\nAdopsjonen blir kunngjort i"
            .. " guild-chatten, så hele guilden får se den. (Slå av med /dp kunngjør.)")
        eq(ola.popup.args[3], "s:46", "the pet goes along with the popup")
        -- Cancelled: nothing happens.
        ola.popup = nil
        eq(ola.ns.Registry:MyPet(), "s:5159")
        -- With announcing off, no warning.
        ola:Slash("kunngjør av")
        card.reserve:Click()
        eq(ola.popup.args[1], "Adoptere White Kitten?\nDu gir da slipp på Panda Cub.")
        ola:PopupAccept()
        eq(ola.ns.Registry:MyPet(), "s:46")
        ok(ola:Printed("Du adopterte White Kitten (og ga slipp på Panda Cub).", true))
        -- A popup without its pet does nothing.
        ola.env.StaticPopupDialogs.DYREPARKEN_ADOPT.OnAccept({}, nil)
        eq(ola.ns.Registry:MyPet(), "s:46")
    end)
end
