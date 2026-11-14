-- Companions we don't know (Menagerie/Unlisted.lua, 2026-11-14, the user): a species not in Data/Companions.lua,
-- seen, learned or owned, is told once per account in chat, with its name, its species id and who to tell.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    -- The journal's list without the rabbit (72) and the macaw (90); Ola owns the macaw.
    local function Setup()
        local list = {}
        for sid, v in pairs(H.COMPANIONS) do if sid ~= 72 and sid ~= 90 then list[sid] = v end end
        return H.Setup{ ola = { 5159, 90 }, kari = { 72 }, settle = "hello", each = function(c) c:Companions(list) end }
    end
    local SEEN = "Dyreparken kjenner ikke Snowshoe Rabbit (art 72) ennå. Si fra til Hjelp Plask, så kommer den med!"
    local OWNED = "Du har Hyacinth Macaw (art 90), som Dyreparken ikke kjenner ennå. Si fra til Hjelp Plask, så kommer den med!"
    local function Count(c, text)
        local n = 0
        for _, line in ipairs(c.printed) do if line:find(text, 1, true) then n = n + 1 end end
        return n
    end

    test("an unknown pet you own is told once at login; one seen under the mouse once; never again", function()
        local w, ola, kari = Setup()
        eq(Count(ola, OWNED), 1, "owned at login")
        no(ola:Printed("Panda Cub (art", true), "a pet we know: nothing")
        ola:Hover{ species = 72, owner = "Kari Berg" }
        eq(Count(ola, SEEN), 1)
        ola:Hover{ species = 72, owner = "Kari Berg" }
        ola:GivePet(72); ola:Fire("NEW_PET_ADDED", ola:GuidOf(72))
        eq(Count(ola, SEEN), 1, "once per species")
        eq(Count(ola, "(art 72)"), 1, "learning it later: already told")
        eq(ola.ns.DB.global.unlisted[72].owner, "Kari Berg")
        eq(ola.ns.DB.global.unlisted[90].how, "learned")
        -- After a reload: still told.
        ola:Reload()
        w:Settle("hello")
        eq(Count(ola, "(art 90)"), 1)
    end)

    test("learning one: told at once, by its name or without one", function()
        local w, ola = Setup()
        ola:GivePet(3001); ola:Fire("NEW_PET_ADDED", ola:GuidOf(3001))
        ok(ola:Printed("Du har et ukjent dyr (art 3001), som Dyreparken ikke kjenner ennå.", true))
        ola:GivePet(46); ola:Fire("NEW_PET_ADDED", ola:GuidOf(46))
        eq(Count(ola, "(art 46)"), 0, "a pet we know")
        ola:Fire("NEW_PET_ADDED", "BattlePet-0-NOSUCH")
        ola:Fire("NEW_PET_ADDED", H.SECRET)
    end)
end
