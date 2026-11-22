-- The pet journal: list markers, tooltips, the card, buttons, popup, checkbox.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
    local MINE, TAKEN, FREE = MEDIA .. "heart", MEDIA .. "paw", MEDIA .. "house"

    -- Ola owns Panda Cub (reserved) and White Kitten (free); Kari holds Bombay Cat.
    local COG = "|TInterface\\AddOns\\Dyreparken\\Media\\Particles\\gear:14:14:0:0:64:64:0:64:0:64:230:199:128|t"
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
        b.scripts.OnEnter(b) -- (by hand: it adds to a tooltip the button may have started)
        local text = table.concat(tip.lines, " / ")
        match(text, "^Bombay Cat / ")
        match(text, "Har bodd hos Kari Berg i 7 dager")
        match(text, 'Kallenavn: «Mjau»')
        ok(tip.shown)
        b.scripts.OnLeave(b)
        no(tip.shown)
        local mine = ola:Button(5159)
        tip:SetOwner(mine) -- Blizzard already wrote its tooltip
        tip:AddLine("Blizzard's line")
        mine.scripts.OnEnter(mine)
        match(table.concat(tip.lines, " / "), "^Blizzard's line / .*Har bodd hos deg")
        local free = ola:Button(68)
        match(ola:TipOf(free).text, "Dyreparken: trenger et hjem")
        -- A button without a species does nothing.
        ola:ListPets({ bare = true, extra = { 999 } })
        ola.journalList[#ola.journalList].sid = nil
        ola:ListPets({ bare = true })
        local blank = ola.env.CreateFrame("Button", nil, ola.env.PetJournal)
        ola.env.PetJournal_InitPetButton(blank, {})
        eq(#ola:TipOf(blank), 0)
        no(blank.textures[1].shown, "no marker without a species")
    end)

    test("card: your pet offers Gi slipp, the nickname unlocks at bond level Venn", function()
        local w, ola = Setup()
        local card = ola:SelectPet(5159)
        eq(card.status.plain, "Hos deg siden i dag")
        eq(card.reserve.text, "Gi slipp")
        ok(card.reserve.shown and card.nick.shown)
        no(card.nick.enabled, "locked until Venn")
        eq(ola:TipOf(card.nick)[1], "Du kan gi det et kallenavn når båndet deres er Venn (level 3).")
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
        eq(card.status.plain, "Panda Cub · Hos deg i 7 dager", "named: the species leads")
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
        eq(#ola:TipOf(card.nick), 0, "no tooltip once unlocked")
    end)

    test("card: Release and Reserve buttons", function()
        local w, ola, kari = Setup()
        local card = ola:SelectPet(5159)
        card.reserve:Click()
        eq(ola.ns.Registry:MyPet(), "s:5159", "letting go asks first (review 2026-11-19)")
        eq(ola.popup.which, "DYREPARKEN_LETGO")
        eq(ola.popup.args[1], "Gi slipp på Panda Cub?\n\nBåndet dere har bygget, blir ikke borte, men andre i guilden"
            .. " kan adoptere Panda Cub.")
        ola:PopupAccept()
        eq(ola.ns.Registry:MyPet(), nil)
        ok(ola:Printed("Du ga slipp på Panda Cub."))
        eq(card.reserve.text, "Adopter")
        no(card.nick.shown)
        eq(card.status.plain, "Trenger et hjem")
        card = ola:SelectPet(46)
        card.reserve:Click()
        eq(ola.ns.Registry:MyPet(), nil, "not before it's confirmed")
        eq(ola.popup.which, "DYREPARKEN_ADOPT")
        eq(ola.popup.args[1], "Adoptere White Kitten?\n\nAdopsjonen blir kunngjort i guildchatten, så hele guilden får se den."
            .. " (Slå av under " .. COG .. " Innstillinger, eller med /dp kunngjør.)")
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
        eq(card.status.plain, 'Bombay Cat · Hos Kari Berg i 7 dager')
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
        local total = ola.ns.Pets:Total() -- (from Data/Companions.lua: grows as companions are added)
        eq(card.counter.text, ("2 av %d (%d%%)"):format(total, math.floor(200 / total + 0.5)), "the stub's count")
        -- A generated species list replaces the stub's count.
        ola.ns.Companions.species = { [5159] = true, [46] = true, [40] = true, [68] = true }
        ola:SelectPet(46)
        eq(card.counter.text, "2 av 88 (2%)", "a pick doesn't redraw the guild's boxes")
        ola.ns.JournalUI:Refresh() -- (the guild's boxes: redrawn on a refresh, not on a pick)
        eq(card.counter.text, "2 av 4 (50%)")
        ola.ns.Companions = nil
        ola.ns.JournalUI:Refresh()
        eq(card.counter.text, "2 av 0 (0%)", "no data: no division by zero")
    end)

    -- The swap (2026-11-22, 0.10.0, the user: "Ta med ut" made situationally reactive).
    test("Med deg: with the pet out full for today, another pet's badge with room is a swap, green, its own words", function()
        local w, ola = Setup()
        ola:Summon(5159)
        local ns = ola.ns
        local card = ola:SelectPet(46)
        local b = card.auto
        eq(b.label.text, "Ta med ut", "the panda's day has room: no swap yet")
        no(b.swap)
        -- The panda's day fills: the kitten's card (shown) turns into a swap at once.
        ns.Bond:Today("s:5159"); ns.Bond:Today("s:46")
        ns.DB.char.bondToday.pets["s:5159"].total = ns.Bond:DailyMax("s:5159")
        ns.Bus:Fire("BOND_FULL", "s:5159")
        ok(b.swap); eq(b.label.text, "Bytt inn"); match(b.paw:GetTexture(), "swap$"); ok(b.glow:IsShown())
        local tip = ola:TipOf(b)
        eq(tip[1], "Bytt inn White Kitten")
        eq(tip[2], ("Panda Cub er fornøyd for i dag. White Kitten kan fortsatt få %d båndpoeng i dag.")
            :format(ns.Bond:DailyMax("s:46") - ns.Bond:Today("s:46")))
        eq(tip[3], "Klikk for å ta White Kitten med ut i stedet.")
        -- The panda's own card: it's the one out, no swap.
        no(ola:SelectPet(5159).auto.swap)
        -- The kitten full too: nothing to gain, the plain badge.
        ns.DB.char.bondToday.pets["s:46"].total = ns.Bond:DailyMax("s:46")
        card = ola:SelectPet(46)
        no(b.swap); eq(b.label.text, "Ta med ut"); match(b.paw:GetTexture(), "paw$")
        -- Room again, and a click swaps it in, as "Ta med ut" does.
        ns.DB.char.bondToday.pets["s:46"].total = 0
        card = ola:SelectPet(46)
        ok(b.swap)
        b:Click()
        w:Run(2)
        eq(ns.Pets:KeyOf(ola.summoned), "s:46")
        ok(b.on); no(b.swap); eq(b.label.text, "Med deg")
        -- No pet out: nothing to swap from.
        ola:Summon(nil)
        no(ola:SelectPet(5159).auto.swap)
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
        local tip = ola:TipOf(b)
        eq(tip[1], "Ta med White Kitten ut")
        match(tip[2], "^Summoner White Kitten når det er fraværende")
        eq(tip[3], "Nå holdes Panda Cub ute.")
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
        local tip = ola:TipOf(card.auto)
        eq(tip[1], "Ikke samlet")
        match(tip[2], "^Du har ikke Bombay Cat i samlingen din")
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

    test("the list shows each pet's face over Blizzard's icon, left as it was; grey where theirs is", function()
        local w, ola = Setup()
        ola:ListPets({ extra = { 72 } })
        local faces = {}
        for button, f in pairs(ola.ns.JournalList._faces) do faces[button.sid] = { f = f, icon = button.icon } end
        local panda = faces[5159]
        eq(panda.f.face.portrait, 20000 + 5159, "its portrait")
        ok(panda.f.face:IsShown()); ok(panda.f.bg:IsShown(), "on a dark square over the icon")
        eq(panda.icon.tex, 1000 + 5159, "Blizzard's icon untouched")
        no(panda.f.face.desaturated)
        ok(faces[72].f.face.desaturated, "not owned: grey, as Blizzard's")
        -- No portrait call: theirs shows, nothing of ours.
        ola.env.SetPortraitTextureFromCreatureDisplayID = nil
        ola:ListPets()
        local button = ola:Button(5159)
        local f = ola.ns.JournalList._faces[button]
        ok(f, "the new button's")
        no(f.bg:IsShown(), "no portrait: Blizzard's icon shows"); no(f.face:IsShown())
    end)

    test("with AutoCompanion the badge is greyed out", function()
        local w, ola = Setup(nil, { addons = { "AutoCompanion" } })
        local card = ola:SelectPet(5159)
        no(card.auto.on)
        no(card.auto.enabled)
        eq(card.auto.label.text, "Ta med ut")
        eq(ola:TipOf(card.auto)[1], "AutoCompanion er lastet og tar seg av summoning.")
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
        eq(ola.popup.args[1], "Adoptere White Kitten?\nDu gir da slipp på Panda Cub. Båndet dere har bygget, blir ikke"
            .. " borte.\n\nAdopsjonen blir kunngjort i guildchatten, så hele guilden får se den. (Slå av under " .. COG .. " Innstillinger,"
            .. " eller med /dp kunngjør.)")
        eq(ola.popup.args[3], "s:46", "the pet goes along with the popup")
        -- Cancelled: nothing happens.
        ola.popup = nil
        eq(ola.ns.Registry:MyPet(), "s:5159")
        -- With announcing off, no warning.
        ola:Slash("kunngjør av")
        card.reserve:Click()
        eq(ola.popup.args[1], "Adoptere White Kitten?\nDu gir da slipp på Panda Cub. Båndet dere har bygget, blir ikke borte.")
        ola:PopupAccept()
        eq(ola.ns.Registry:MyPet(), "s:46")
        ok(ola:Printed("Du adopterte White Kitten (og ga slipp på Panda Cub).", true))
        -- A popup without its pet does nothing.
        ola.env.StaticPopupDialogs.DYREPARKEN_ADOPT.OnAccept({}, nil)
        eq(ola.ns.Registry:MyPet(), "s:46")
    end)
    test("no OnLeave closes a tooltip another frame owns", function()
        local w, ola = Setup()
        ola:SelectPet(5159)
        ola:OpenJournal()
        local tip, other = ola.env.GameTooltip, {}
        local swept = 0
        for _, f in ipairs(ola.frames) do
            local leave = f.scripts and f.scripts.OnLeave
            if leave then
                tip:SetOwner(other); tip:Show()
                pcall(leave, f)
                ok(tip.shown and tip.owner == other, "OnLeave of " .. tostring(f.frameName or f.type) .. " hid it")
                swept = swept + 1
            end
        end
        ok(swept > 10, "swept " .. swept)
    end)

    test("outside a guild: Adopter is greyed with a word why, the card says so, and so do the boxes and Parken", function()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { guild = false, pets = { 5159, 46 } })
        w:Settle("bond")
        ola:OpenJournal()
        local card = ola:SelectPet(46)
        ok(card.reserve.shown); no(card.reserve:IsEnabled(), "disabled (review 2026-11-19)")
        H.match(ola:TipOf(card.reserve).text, "^Adopsjon skjer i en guild")
        eq(card.status.plain, "Ingen guild")
        eq(card.counter.text, "-")
        H.match(ola:TipOf(card.guildBox).text, "^Du er ikke i en guild")
        card.reserve:Click()
        eq(ola.popup, nil, "a disabled button does nothing")
        ola:Slash("liste"); ok(ola:Printed("Du er ikke i en guild.", true))
        ola:ClearPrinted()
        ola:Slash("navn Pepe"); ok(ola:Printed("Du er ikke i en guild.", true))
        -- A taken pet's home line is white, not red (a guildmate's pet is the good outcome).
        local w2, ola2, kari = H.Setup{ ola = { 46 }, kari = { 46 }, settle = "bond" }
        ola2:Slash("adopter"); w2:Run(2)
        kari:OpenJournal()
        card = kari:SelectPet(46)
        H.match(card.status.text, "^|cffffffff")
    end)
end
