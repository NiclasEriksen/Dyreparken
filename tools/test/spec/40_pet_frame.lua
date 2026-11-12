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
        w:SetDate(2027, 3, 2, hour or 14)
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
        -- The pet draws past the frame (sides and top), with the card's view where it was; the frame
        -- itself, the click and Edit Mode's box, stays the rectangle around the pet.
        eq(table.concat(scene.insets, " "), "60 60 " .. (80 + PF.H - 86) .. " -50", "the card's view, in the wider scene")
        eq(scene.size[1], PF.W + 120); eq(scene.size[2], PF.H + 80)
        local sp = scene.points[#scene.points]
        eq(sp[1], "TOPLEFT"); eq(sp[2], f); eq(sp[4], -60); eq(sp[5], 80)
        eq(f.size[1], PF.W, "the frame: the clickable rectangle")
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
        f.click.scripts.OnDragStart(f.click)
        ok(f:IsUserPlaced(), "the client's StartMoving")
        f:ClearAllPoints(); f:SetPoint("TOPLEFT", ola.env.UIParent, "TOPLEFT", 40, -50)
        f.click.scripts.OnDragStop(f.click)
        eq(table.concat(ola.ns.DB.char.petFrame, " "), "TOPLEFT TOPLEFT 40 -50 1")
        no(f:IsUserPlaced(), "not in the client's layout cache: the spot is ours (char.petFrame)")
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

    -- From wherever the window is: onto the Pets page, the pet's card (2026-11-11, the user).
    test("a click opens the Pets page from another page or a closed window, on the pet's card", function()
        local w, ola, PF = Setup(14)
        local f, env = PF.frame, ola.env
        ola:OpenJournal({ sideTabs = 3 })
        ola:ClickTab(1) -- (the player: Mounts)
        f.click.scripts.OnClick(f.click, "LeftButton"); w:Run(0.1)
        ok(env.PetJournal:IsVisible(), "open on Mounts: over to Pets")
        eq(env.PetJournalPetCard.speciesID, 5159)
        -- Closed on Mounts: opened on Pets.
        ola:ClickTab(1); ola:CloseJournal()
        f.click.scripts.OnClick(f.click, "LeftButton"); w:Run(0.1)
        ok(env.CollectionsJournal:IsShown()); ok(env.PetJournal:IsVisible())
        eq(env.PetJournalPetCard.speciesID, 5159)
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

    test("another pet out while the bar still grows: the new pet's bond, not the last one's rise", function()
        local w, ola, PF = Setup(14)
        local bar = PF.frame.bar
        ola.ns.Bond:Add(50, PANDA)
        w:Run(ola.ns.BondTrack.GROW.delay + 0.1) -- (growing, a number rising)
        ola:Summon(46); ola:Fire("COMPANION_UPDATE", "CRITTER"); w:Run(0.35)
        w:Run(3)
        local p, level, _, _, nextAt = ola.ns.Bond:Own("s:46")
        eq(PF.key, "s:46")
        eq(bar:GetValue(), nextAt and p or math.max(p, 1), "the kitten's points")
        eq(bar.level.text, level)
        for _, n in ipairs(bar.numbers or {}) do no(n:IsShown(), "no numbers from the panda") end
        no(bar:IsShown(), "and no peek for them")
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
        eq(table.concat(PF.scene.insets, " "), "0 0 " .. (PF.H - 86) .. " -50", "framed: the pet stays within the border")
        eq(PF.scene.size[1], PF.W)
        ola.ns.DB.global.settings.petFrameArt = false; PF:Apply()
        no(f.bg:IsShown()); no(f.border:IsShown())
        eq(PF.scene.size[1], PF.W + 120, "unframed: wide again")
    end)

    -- The wheel in Edit Mode keeps the frame's centre on screen (2026-11-11, a review): the client counts
    -- anchor offsets in the frame's own scaled units, so SetScale alone moved it away from its spot.
    test("sized with the wheel, it stays where it is: its centre kept on screen", function()
        local w, ola, PF = Setup(14)
        local f, env = PF.frame, ola.env
        env.UIParent.scale = 0.8 -- (the UI's own scale: it cancels out)
        PF:EditMode(true)
        f.geo = { l = 100, r = 300, t = 420, b = 200 } -- (laid out: its centre at 200, 310 in its own units)
        local function Screen()
            local p = f.points[#f.points]
            eq(p[1], "CENTER"); eq(p[2], env.UIParent); eq(p[3], "BOTTOMLEFT")
            return p[4] * f:GetEffectiveScale(), p[5] * f:GetEffectiveScale()
        end
        f.click.scripts.OnMouseWheel(f.click, 1)
        eq(f:GetScale(), 1.05)
        local x, y = Screen()
        ok(math.abs(x - 200 * 0.8) < 1e-6 and math.abs(y - 310 * 0.8) < 1e-6, "the same spot on screen")
        -- The client lays it out there; a few steps down, still there.
        local p = f.points[#f.points]
        f.geo = { l = p[4] - 100, r = p[4] + 100, t = p[5] + 110, b = p[5] - 110 }
        for _ = 1, 3 do
            f.click.scripts.OnMouseWheel(f.click, -1)
            p = f.points[#f.points]
            f.geo = { l = p[4] - 100, r = p[4] + 100, t = p[5] + 110, b = p[5] - 110 }
        end
        eq(f:GetScale(), 0.9)
        x, y = Screen()
        ok(math.abs(x - 200 * 0.8) < 1e-6 and math.abs(y - 310 * 0.8) < 1e-6, "still")
        local saved = ola.ns.DB.char.petFrame
        eq(saved[1], "CENTER"); eq(saved[2], "BOTTOMLEFT"); eq(saved[5], 0.9)
        ok(math.abs(saved[3] * 0.9 * 0.8 - 160) < 1e-6, "saved as it stands")
    end)

    test("the Zzz and a level's stars are sized and placed with the frame", function()
        local w, ola, PF = Setup(23, false)
        ola.ns.DB.char.petFrame = { "CENTER", "CENTER", 0, 0, 2 }
        ola.ns.DB.global.settings.petFrame = true; PF:Apply()
        local z
        for _, p in ipairs(ola.ns.Fx.particles or {}) do
            if p:IsShown() and tostring(p.icon.tex):find("zee$") then z = p end
        end
        ok(z, "a Zzz")
        local at = z.points[1]
        ok(at[4] >= PF.ZZZ_AT[1] * 2 - 4 and at[4] <= PF.ZZZ_AT[1] * 2 + 4, "right of the middle, twice as far")
        ok(at[5] >= PF.ZZZ_AT[2] * 2 - 4 and at[5] <= PF.ZZZ_AT[2] * 2 + 4, "head height, twice as high")
        ok(z.size[1] >= 12 * 0.7 * 2, "twice the size")
        eq(z.anim.up.offset[2], 20 * 2, "rising twice as far")
        -- By day, a level: the stars, the same.
        local w2, kari, PF2 = Setup(14, false)
        kari.ns.DB.char.petFrame = { "CENTER", "CENTER", 0, 0, 2 }
        kari.ns.DB.global.settings.petFrame = true; PF2:Apply()
        kari.ns.Bond:Add(150, PANDA)
        local star
        for _, p in ipairs(kari.ns.Fx.particles or {}) do
            if p:IsShown() and tostring(p.icon.tex):find("star$") and p.points[1][2] == PF2.scene then star = p end
        end
        ok(star, "stars over the pet")
        ok(star.size[1] >= 10 * 0.8 * 2, "twice the size")
        eq(star.anim.up.offset[2], 25 * 2)
    end)

    test("options: hidden in combat; faded when nothing happens, full under the mouse and after a pet event", function()
        local w, ola, PF = Setup(14)
        local f = PF.frame
        local S = ola.ns.DB.global.settings
        -- Hidden in combat: off by default, nothing listened to.
        no(PF.combatOn) -- (the fight events are Fight.lua's too, while the frame is on)
        ola:EnterCombat(); w:Run(0.1)
        ok(f:IsShown(), "the option is off")
        ola:LeaveCombat()
        S.petFrameCombat = true; PF:Apply()
        ok(PF.combatOn)
        ola:EnterCombat()
        no(f:IsShown(), "in combat: hidden")
        ola:LeaveCombat()
        ok(f:IsShown(), "out again")
        S.petFrameCombat = false; PF:Apply()
        no(PF.combatOn, "off: the events go")
        -- Faded: off by default.
        eq(f:GetAlpha(), 1)
        w:Run(10) -- (the day's first points just rose: at full a moment)
        S.petFrameFade = true; PF:Apply()
        eq(f:GetAlpha(), 0.25, "faded to 25% by default")
        f.click.scripts.OnEnter(f.click)
        eq(f:GetAlpha(), 1, "under the mouse: full")
        f.click.scripts.OnLeave(f.click)
        eq(f:GetAlpha(), 0.25)
        ola.ns.Bond:Add(5, PANDA)
        eq(f:GetAlpha(), 1, "points rising: full")
        w:Run(8)
        eq(f:GetAlpha(), 0.25, "and faded again")
        ola.ns.Bond:Add(150, PANDA) -- (a new level)
        eq(f:GetAlpha(), 1)
        w:Run(8)
        S.petFrameAlpha = 0.5; PF:Apply()
        eq(f:GetAlpha(), 0.5, "the slider's value")
        PF:EditMode(true)
        eq(f:GetAlpha(), 1, "Edit Mode: full, to place it")
        PF:EditMode(false)
        -- The settings page: the two boxes and the slider, greyed while the frame is off.
        local Set = ola.ns.Settings
        ola:OpenJournal()
        Set:Open()
        local slider
        for _, wd in ipairs(Set._sp.widgets) do if wd.slider then slider = wd.slider end end
        ok(slider, "a slider")
        eq(slider:GetValue(), 0.5)
        eq(slider.pct.text, "50%")
        slider.scripts.OnValueChanged(slider, 0.3, true)
        eq(S.petFrameAlpha, 0.3)
        eq(f:GetAlpha(), 0.3)
        S.petFrameFade = false; Set:Refresh()
        no(slider:IsEnabled(), "not fading: the slider waits")
    end)

    test("asleep in a loop on the frame, other companions nearby refreshing it leave the pose alone", function()
        local w, ola, PF = Setup(23)
        local S = ola.ns.DB.global.settings
        S.petFrame = false; PF:Apply()
        ola.ns.PetMoves.species[5159] = { sleepHold = 100, sleepUp = false }
        S.petFrame = true; PF:Apply()
        w:Run(ola.ns.Moves.SLEEP_AFTER + 2)
        local actor = PF.actor
        eq(actor.anim, 100)
        local n = #actor.played
        for _ = 1, 5 do ola:Fire("COMPANION_UPDATE", "CRITTER"); w:Run(1) end
        eq(#actor.played, n, "not played again: that starts the move over (2026-11-12)")
    end)

    test("idle, it costs nothing: other companions don't redo it, and the scene's camera runs only after a change", function()
        local w, ola, PF = Setup(14)
        local scene = PF.scene
        ok(scene.scripts.OnUpdate, "the template's OnUpdate, right after the pet's scene was set")
        w:Run(PF.CAMERA_FOR + 0.5)
        eq(scene.scripts.OnUpdate, nil, "taken off once the camera has settled")
        local updates = scene.updates
        w:Run(10)
        eq(scene.updates, updates, "nothing runs every frame while it just stands there")
        -- Other companions nearby: no refresh at all.
        local refreshes = 0
        local Refresh = PF.Refresh
        PF.Refresh = function(...) refreshes = refreshes + 1; return Refresh(...) end
        for _ = 1, 10 do ola:Fire("COMPANION_UPDATE", "CRITTER"); w:Run(0.5) end
        eq(refreshes, 0, "the same pet out: nothing to redo")
        -- Another pet out: redone, its scene's camera running again for a while.
        ola:Summon(46); ola:Fire("COMPANION_UPDATE", "CRITTER"); w:Run(0.4)
        eq(refreshes, 1)
        eq(PF.key, "s:46")
        ok(scene.scripts.OnUpdate, "the camera runs again for the new pet's scene")
        w:Run(PF.CAMERA_FOR + 0.5)
        eq(scene.scripts.OnUpdate, nil)
        PF.Refresh = Refresh
    end)

    test("the pet speaks: a bubble over it by kind, the frame at full, a lesser line never cuts a greater one short", function()
        local w, ola, PF = Setup(14)
        local S = ola.ns.DB.global.settings
        S.petFrameFade = true; PF:Fade()
        local f = ola.env.DyreparkenPetFrame
        eq(f:GetAlpha(), 0.25, "faded, idle")
        local Bus = ola.ns.Bus
        Bus:Fire("PET_SAID", "s:46", "like", "Not the pet out.")
        eq(f.bubble, nil, "another pet's line: nothing")
        Bus:Fire("PET_SAID", "s:5159", "dislike", "Pandaen liker ikke det.")
        local b = f.bubble
        ok(b:IsShown())
        ok(b.anim:IsPlaying())
        eq(f:GetAlpha(), 1, "at full while it speaks")
        eq(b.icon.tex, ola.ns.Decor.MEDIA .. "rain")
        eq(b.tex.tex, ola.ns.Decor.MEDIA .. "thought", "a dislike: a thought bubble")
        -- A major one takes over; a remark meanwhile doesn't.
        Bus:Fire("PET_SAID", "s:5159", "major", "Level 60!")
        eq(b.icon.tex, ola.ns.Decor.MEDIA .. "star")
        Bus:Fire("PET_SAID", "s:5159", "say", "Hm.")
        eq(b.icon.tex, ola.ns.Decor.MEDIA .. "star", "a remark waits")
        ok(b.icon:IsShown()); eq(b.tex.tex, ola.ns.Decor.MEDIA .. "shout", "still the shout, not the remark's bubble")
        -- Under the mouse: the last line said.
        f.click.scripts.OnEnter(f.click)
        H.match(table.concat(ola.env.GameTooltip.lines, " / "), "Hm%.")
        f.click.scripts.OnLeave(f.click)
        -- Done: the fade returns, and the next remark gets its own bubble.
        w:Run(PF.SAY_FOR + 0.5)
        eq(f:GetAlpha(), 0.25, "faded again")
        b.anim:Finish()
        no(b:IsShown())
        Bus:Fire("PET_SAID", "s:5159", "say", "Hm.")
        ok(b:IsShown()); no(b.icon:IsShown())
        eq(b.tex.tex, ola.ns.Decor.MEDIA .. "speech", "a remark: the speech bubble with its dots")
    end)

    test("what makes it speak: a liked moment, a level, an egg, a dislike; all through PET_SAID", function()
        local w, ola, PF = Setup(14)
        local kinds = {}
        ola.ns.Bus:On("PET_SAID", function(key, kind) kinds[#kinds + 1] = kind end)
        ola.ns.Bus:Fire("BOND_LINE", "s:5159", "Pandaen elsker urter!", "like")
        ola.ns.Bus:Fire("BOND_LINE", "s:5159", "Ønsket gikk i oppfyllelse!", "major")
        ola.ns.Bus:Fire("BOND_LEVEL", "s:5159", 3, "Venn")
        local Q = ola.ns.Quirks
        ola:QuirksNow()
        Q:Say("Pandaen gjesper.", "test", "egg", nil, nil, "s:5159")
        Q:Say("Pandaen grøsser.", "test", "dislike", nil, nil, "s:5159")
        w:Run(1)
        eq(table.concat(kinds, " "), "like major major say dislike")
    end)
end
