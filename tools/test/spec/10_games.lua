-- Party games framework. Deliberately light (see CLAUDE.md "Testing"): the
-- games part is meant to change fast while it takes shape, so these only
-- pin what must never break: the UI is always given back to the player.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    test("games are defined by id; only leaders and assists lead", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local G = c.ns.Games
        G:Define({ id = "test", name = "Test" })
        ok(G.defs.test)
        ok(not pcall(G.Define, G, { name = "No id" }))
        no(G:CanLead())
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ok(G:CanLead())
        w:SetGroup({ "Kari Berg", "Ola Nord" })
        c.assist = true
        ok(G:CanLead())
    end)

    test("UI changes are undone, also after a reload mid-game", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local UI = c.ns.Games.UIState
        UI:Apply({ hide = { "Minimap", "NoSuchFrame" }, cvars = { nameplateShowFriends = "0" } })
        no(c.env.Minimap:IsShown())
        eq(c.cvars.nameplateShowFriends, "0")
        c:Reload() -- the stash is saved; the new session restores it
        ok(c.env.Minimap:IsShown())
        eq(c.cvars.nameplateShowFriends, "1")
        eq(c.env.DyreparkenDB.games.stash, nil)
        UI:Restore() -- nothing stashed: nothing to do
    end)

    test("hiding waits for combat to end", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        c:EnterCombat()
        c.ns.Games.UIState:Apply({ hide = { "Minimap" } })
        ok(c.env.Minimap:IsShown())
        c:LeaveCombat()
        no(c.env.Minimap:IsShown())
    end)

    test("results go into the history", function()
        local w = H.World()
        local c = w:AddClient("Ola Nord")
        local G = c.ns.Games
        G:Record({ id = "test" }, { sid = "x1", at = 5, leader = "Ola Nord" }, { kind = "single", ranking = { { "Kari Berg" } } })
        local h = c.env.DyreparkenDB.games.history
        eq(#h, 1)
        eq(h[1].result.ranking[1][1], "Kari Berg")
    end)
end
