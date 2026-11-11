-- The pet frame (Menagerie/PetFrame.lua): the pet that's out on screen, off by default, moving 1:1
-- as on the journal card (its own stage of Moves.lua); a click opens its card; placed in Edit Mode.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no
    local PANDA = "s:5159"

    local function Listening(c, e)
        for _, f in ipairs(c.frames) do if f.events[e] then return true end end
        return false
    end
    -- Ola with her Panda Cub adopted and out, at a given hour; the frame turned on.
    local function Setup(hour, on)
        local w, ola = H.Setup{ ola = { 5159, 46 } }
        ola:Slash("adopter panda"); w:Run(5)
        ola.ns.PetMoves.species[5159] = { sleepHold = false, sleepUp = false, canSit = true } -- (the panda pauses)
        ola.ns.Moves.SLEEP_AFTER = 0.6
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = hour or 14 }) - w:ServerTime())
        local PF = ola.ns.PetFrame
        if on ~= false then ola.ns.DB.global.settings.petFrame = true; PF:Apply() end
        return w, ola, PF
    end

    test("off by default: nothing built, nothing listened to; turned on, the pet that's out, framed as on the card", function()
        local w, ola, PF = Setup(14, false)
        eq(ola.ns.DB.global.settings.petFrame, false)
        eq(PF.frame, nil, "no frame")
        no(Listening(ola, "COMPANION_UPDATE"))
        ola.ns.DB.global.settings.petFrame = true; PF:Apply()
        local f = ola.env.DyreparkenPetFrame
        ok(f:IsShown())
        ok(Listening(ola, "COMPANION_UPDATE"))
        local scene = PF.scene
        eq(scene.sceneID, 1271, "the species' model scene")
        eq(table.concat(scene.insets, " "), "0 0 " .. (PF.H - 86) .. " -50", "the card's view, for its height")
        no(scene.mouse, "the scene takes no mouse (it would rotate the pet)")
        eq(PF.actor.display, 20000 + 5159, "the pet's model")
        eq(f.name.text, "Panda Cub")
        eq(f.bar.level.text, 1, "your bond's level")
        -- Off again: hidden, nothing listened to.
        ola.ns.DB.global.settings.petFrame = false; PF:Apply()
        no(f:IsShown())
        no(Listening(ola, "COMPANION_UPDATE"))
    end)

    test("it moves as on the card: asleep at night, a cheer at a new level, walking with you", function()
        local w, ola, PF = Setup(23)
        local actor = PF.actor
        w:Run(0.61)
        eq(actor.anim, 6, "lying down, as the card's pet would")
        w:Run(1.3)
        ola.ns.Moves:Cheer(PANDA)
        eq(actor.anim, 754, "a cheer wakes it")
        -- By day, the pet you keep out walks while you move.
        local w2, kari, PF2 = Setup(14)
        kari:Move()
        eq(PF2.actor.anim, 4, "walking with you")
        kari:Halt(); w2:Run(0.31)
        eq(PF2.actor.anim, 0)
    end)

    test("a click opens the pet journal on its card; not in combat; in Edit Mode it's dragged instead", function()
        local w, ola, PF = Setup(14)
        local f = PF.frame
        f.click.scripts.OnClick(f.click, "LeftButton")
        w:Run(0.1)
        eq(ola.toggled, 1, "the Collections window, opened")
        ok(ola.env.PetJournal:IsVisible())
        eq(ola.env.PetJournalPetCard.speciesID, 5159, "on the panda's card")
        ola.env.CollectionsJournal:Hide()
        ola.state.combat = true
        f.click.scripts.OnClick(f.click, "LeftButton"); w:Run(0.1)
        eq(ola.toggled, 1, "not in combat")
        ola.state.combat = false
        -- Edit Mode (Blizzard's, by its callbacks): highlighted, dragged, the spot kept; a click doesn't open anything.
        local callbacks = {}
        rawset(ola.env, "EventRegistry", { RegisterCallback = function(_, ev, fn) callbacks[ev] = fn end })
        PF:HookEditMode()
        callbacks["EditMode.Enter"]()
        ok(f.edit:IsShown())
        f.click.scripts.OnClick(f.click, "LeftButton"); w:Run(0.1)
        eq(ola.toggled, 1)
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", ola.env.UIParent, "TOPLEFT", 40, -50)
        f.click.scripts.OnDragStop(f.click)
        eq(table.concat(ola.ns.DB.char.petFrame, " "), "TOPLEFT TOPLEFT 40 -50 1")
        -- Sized with the mouse wheel, between half and double; the label says how big.
        ok(f.click.wheel, "the wheel, only in Edit Mode")
        eq(f.edit.label.text, "Dyreparken: dyret ditt\nDra for å flytte, rull for størrelse (100%)")
        for _ = 1, 4 do f.click.scripts.OnMouseWheel(f.click, 1) end
        eq(f:GetScale(), 1.2)
        ok(f.edit.label.text:find("(120%)", 1, true))
        for _ = 1, 40 do f.click.scripts.OnMouseWheel(f.click, -1) end
        eq(f:GetScale(), PF.MIN_SCALE, "no smaller than half")
        for _ = 1, 4 do f.click.scripts.OnMouseWheel(f.click, 1) end
        eq(ola.ns.DB.char.petFrame[5], 0.7, "kept with the spot")
        callbacks["EditMode.Exit"]()
        no(f.edit:IsShown())
        no(f.click.wheel, "out of Edit Mode: no wheel")
        f.click.scripts.OnMouseWheel(f.click, 1)
        eq(f:GetScale(), 0.7, "(and a stray scroll changes nothing)")
        -- Kept: after a reload it stands there.
        ola:Reload(); w:Run(15)
        local p = ola.env.DyreparkenPetFrame.points[1]
        eq(p[1], "TOPLEFT"); eq(p[4], 40); eq(p[5], -50)
        eq(ola.env.DyreparkenPetFrame:GetScale(), 0.7)
    end)

    test("it follows the pet that's out: dismissed, hidden (but shown in Edit Mode); another pet, its model; a pet battle hides it", function()
        local w, ola, PF = Setup(14)
        local f = PF.frame
        ola:Summon(nil); ola:Fire("COMPANION_UPDATE", "CRITTER"); w:Run(0.4)
        no(f:IsShown(), "no pet out")
        PF:EditMode(true)
        ok(f:IsShown(), "Edit Mode: there to place")
        eq(f.name.text, ola.ns.L["petframe.name"])
        PF:EditMode(false)
        ola:Summon(46); ola:Fire("COMPANION_UPDATE", "CRITTER"); w:Run(0.4)
        ok(f:IsShown())
        eq(PF.actor.display, 20000 + 46, "the kitten now")
        ola:Fire("PET_BATTLE_OPENING_START")
        no(f:IsShown())
        ola:Fire("PET_BATTLE_CLOSE")
        ok(f:IsShown())
    end)

    test("the bar: your bond, its points rising as they come; its tooltip", function()
        local w, ola, PF = Setup(14)
        local bar = PF.frame.bar
        ola.ns.Bond:Add(7, PANDA)
        w:Run(ola.ns.BondTrack.GROW.delay + 0.01)
        local shown = {}
        for _, n in ipairs(bar.numbers or {}) do if n:IsShown() then shown[#shown + 1] = n.text.text end end
        eq(table.concat(shown, " "), "+7")
        ok(bar:IsShown(), "shown while the numbers rise")
        -- Its tooltip: the name, and what a click does.
        PF.frame.click.scripts.OnEnter(PF.frame.click)
        eq(ola.env.GameTooltip.lines[1], "Panda Cub")
        eq(ola.env.GameTooltip.lines[2], ola.ns.L["petframe.tip"])
    end)

    test("the bar and level show only under the mouse, and while points rise (a level comes with them)", function()
        local w, ola, PF = Setup(14)
        local f, bar = PF.frame, PF.frame.bar
        no(bar:IsShown(), "hidden at rest")
        f.click.scripts.OnEnter(f.click)
        ok(bar:IsShown(), "under the mouse")
        f.click.scripts.OnLeave(f.click)
        no(bar:IsShown())
        -- Points: it shows while they rise, then hides; a level, the same.
        ola.ns.Bond:Add(7, PANDA)
        ok(bar:IsShown())
        w:Run(3)
        ok(bar:IsShown(), "still rising")
        w:Run(3)
        no(bar:IsShown(), "gone again")
        ola.ns.Bond:Add(150, PANDA)
        ok(bar:IsShown())
        w:Run(6)
        no(bar:IsShown())
        -- The mouse over it when a peek ends: it stays.
        ola.ns.Bond:Add(3, PANDA)
        f.click.scripts.OnEnter(f.click)
        w:Run(10)
        ok(bar:IsShown(), "the mouse still over it")
    end)

    local function Bursts(ola, tex)
        local n = 0
        for _, p in ipairs(ola.ns.Fx.particles or {}) do
            if p:IsShown() and tostring(p.icon.tex):find(tex .. "$") then n = n + 1 end
        end
        return n
    end

    test("asleep, a Zzz rises now and then (none once it's awake); night falls on it while it's there", function()
        local w, ola, PF = Setup(23)
        ok(Bursts(ola, "zee") >= 1, "a Zzz")
        w:Run(PF.ZZZ_EVERY + 0.01)
        ok(PF.zzz, "and on")
        ola.ns.Moves:Cheer(PANDA) -- (woken)
        w:Run(PF.ZZZ_EVERY * 2)
        no(PF.zzz, "awake: the Zzz end")
        -- At 21:00, standing; at 22:00 it lies down without anything else happening.
        local w2, kari, PF2 = Setup(21)
        w2:Run(3590)
        eq(PF2.stage.shown.mode, "stand")
        w2:Run(12)
        eq(PF2.stage.shown.mode, "sleep", "night fell")
        ok(PF2.zzz)
    end)

    test("a new level with the pet that's out: it cheers on the frame, stars burst, the bar shows the level", function()
        local w, ola, PF = Setup(14)
        local actor = PF.actor
        ola.ns.Bond:Add(150, PANDA)
        eq(actor.anim, 754, "its cheer")
        ok(Bursts(ola, "star") >= 1, "stars")
        eq(PF.frame.bar.level.text, 2)
        -- Another pet's level: nothing here.
        local played = #actor.played
        ola.ns.PetFrame:LevelUp("s:46")
        eq(#actor.played, played)
    end)

    test("frame art, off by default: the window rock behind the pet and Blizzard's nine-slice border", function()
        local w, ola, PF = Setup(14, false)
        local applied
        rawset(ola.env, "NineSliceLayouts", { ButtonFrameTemplateNoPortrait = { name = "bftnp" } })
        rawset(ola.env, "NineSliceUtil", { ApplyLayout = function(frame, layout) applied = layout.name end })
        ola.ns.DB.global.settings.petFrame = true; PF:Apply()
        local f = PF.frame
        eq(f.bg, nil, "off: it floats")
        ola.ns.DB.global.settings.petFrameArt = true; PF:Apply()
        ok(f.bg:IsShown() and f.border:IsShown())
        eq(applied, "bftnp", "the modern window border")
        ok(f.border:GetFrameLevel() > PF.scene:GetFrameLevel(), "over the scene's edges")
        ok(f.click:GetFrameLevel() > f.border:GetFrameLevel(), "under the click layer")
        ola.ns.DB.global.settings.petFrameArt = false; PF:Apply()
        no(f.bg:IsShown()); no(f.border:IsShown())
    end)
end
