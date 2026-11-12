-- A packaged release (refactor phase 5, 2026-11-12): the packager strips the
-- TOC's #@do-not-package@ blocks and .pkgmeta leaves Dev/ out, so the probes,
-- editors and galleries aren't there and ns.DEV is false. What ships must
-- never reach into them.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    test("the release's TOC: no Dev/ file, and every Dev/ file only in a do-not-package block", function()
        local release = {}
        for _, path in ipairs(H.TOC.release) do
            release[path] = true
            no(path:find("^Dev/"), path .. " ships")
        end
        local dev = 0
        for _, path in ipairs(H.TOC.files) do
            if path:find("^Dev/") then
                dev = dev + 1
                no(release[path], path .. " is packaged")
            end
        end
        ok(dev >= 10, "the Dev/ files load in a checkout")
        ok(#H.TOC.release + dev == #H.TOC.files, "everything else ships")
    end)

    test("a release logs in, shows cards, hovers, lists, frames the pet, and has no developer commands", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord", { release = true, pets = { 5159, 40 } })
        local ns = c.ns
        no(ns.DEV, "a release's version")
        for _, m in ipairs({ "ApiProbe", "Kills", "SceneGallery", "LiftEditor", "MovesEditor", "DecorCandidates" }) do
            eq(ns[m], nil, m .. " isn't there")
        end
        for _, f in ipairs({ { ns.Pets, "Probe" }, { ns.Moves, "Probe" }, { ns.Moves, "SetEditing" },
            { ns.Decor, "Probe" }, { ns.Decor, "Preview" }, { ns.Scenes, "Probe" }, { ns.BondTrack, "Preview" },
            { ns.JournalUI, "ProbeCard" }, { ns.AchPage, "Probe" } }) do
            eq(f[1][f[2]], nil, f[2] .. " isn't there")
        end
        w:Settle("day")
        c:Slash("adopter panda")
        c:OpenJournal({ extra = { 46 } })
        c:SelectPet(5159)
        ok(c:Card().key == "s:5159", "the card shows the pet")
        ns.Cuddle:Pet(c:Card()) -- a cuddle: Moves and Decor on the card
        c:SelectPet(40)
        c:SelectPet(46)
        c:SelectPet(5159)
        c:Hover({ species = 5159, owner = "Ola Nord" })
        c:Slash("liste")
        c:Slash("klapp")
        -- The developer words are unknown here: the help, and nothing else.
        for _, cmd in ipairs({ "probe", "probe anim", "probe api", "probe lift", "debug on" }) do
            local before = #c.printed
            c:Slash(cmd)
            ok(c.printed[before + 1] and c.printed[before + 1]:find("kommandoer:", 1, true), cmd .. ": the help")
            for i = before + 1, #c.printed do no(c.printed[i]:find("probe", 1, true), cmd .. ": no probe in the help") end
        end
        no(ns.Debug.enabled, "no debug log in a release")
        eq(c.env.DyreparkenDebugDB.lines.head, 0, "nothing logged")
        -- The pet frame, on from the settings page.
        local S = ns.Settings
        S.cog:Click()
        for _, wd in ipairs(S._sp.widgets) do
            if wd.row.key == "settings.petframe" then wd.button:Click() end
        end
        ok(ns.Settings:On("petFrame"), "the pet frame is on")
        S.cog:Click()
        w:Run(60)
        -- Through a night, the card and the frame posed by the release's code alone.
        w:SetDate(2026, 11, 20, 23, 30)
        c:SelectPet(40)
        c:SelectPet(5159)
        w:Run(30)
        eq(ns.Moves.override, nil); eq(ns.Decor.override, nil); eq(ns.Scenes.override, nil)
        eq(ns.BondTrack.override, nil)
        c:Reload()
        w:Run(20)
        c:OpenJournal()
        c:SelectPet(5159)
        w:Run(5)
        eq(#c.errors, 0, "no errors")
    end)
end
