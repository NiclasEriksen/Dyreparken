-- Sensors (Menagerie/Sense.lua, 2026-11-14): what the class, race and faction reactions will read. Dormant
-- unless wanted; each subject as Forever gives it (/dp probe api glance); nothing from a secret unit.
return function(test, H)
    local eq, ok, no = H.eq, H.ok, H.no

    -- Ola with every sensor wanted (as a consumer will), and what they saw.
    local function Setup()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } }
        local got = {}
        ola.ns.Bus:On("SENSE", function(kind, s) got[#got + 1] = { kind = kind, s = s } end)
        local OWNER = {}
        for _, kind in ipairs(ola.ns.Sense.KINDS) do ola.ns.Sense:Want(kind, OWNER) end
        local function Last(kind)
            for i = #got, 1, -1 do if got[i].kind == kind then return got[i].s end end
        end
        local function Count(kind)
            local n = 0
            for _, g in ipairs(got) do if g.kind == kind then n = n + 1 end end
            return n
        end
        return w, ola, kari, Last, Count, OWNER
    end

    test("dormant unless wanted: no events, and the tooltip glance does nothing", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local S = ola.ns.Sense
        local n = 0
        ola.ns.Bus:On("SENSE", function() n = n + 1 end)
        for _, kind in ipairs(S.KINDS) do no(S:Listening(kind), kind) end
        ola:Hover{ companion = false, who = { player = true, name = "Elkid", class = "MAGE", race = "Gnome", faction = "Alliance",
            guid = "Player-6939-012B8EA5" } }
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8690)
        eq(n, 0)
        local me = {}
        S:Want("cast", me)
        ok(S:Listening("cast")); no(S:Listening("zone"))
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8690)
        eq(n, 1)
        S:Drop("cast", me)
        no(S:Listening("cast"))
    end)

    test("/dp probe sense: every sensor on, each subject in the debug log; off again", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local S = ola.ns.Sense
        ola:Slash("probe sense")
        for _, kind in ipairs(S.KINDS) do if kind ~= "glance" then ok(S:Listening(kind), kind) end end
        ok(S:Wants("glance"))
        ola.state.spellNames = { [8690] = "Hearthstone" }
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 8690)
        ok(ola:Log("cast combat=false id=8690 name=Hearthstone")[1])
        ola:Slash("probe sense off")
        for _, kind in ipairs(S.KINDS) do no(S:Wants(kind), kind) end
    end)

    test("matching: a value, a set, present or absent, and a list in the subject", function()
        local w, ola = H.Setup{ ola = { 5159 } }
        local M = ola.ns.Sense.Match
        local s = { kind = "pet", families = { "cat" }, enemy = false, class = "HUNTER" }
        ok(M(s, { kind = "pet" })); no(M(s, { kind = "player" }))
        ok(M(s, { kind = { "pet", "demon" } }))
        ok(M(s, { families = "cat" })); ok(M(s, { families = { "wolf", "cat" } })); no(M(s, { families = { "bird" } }))
        ok(M(s, { class = true })); ok(M(s, { pvp = false })); ok(M(s, { enemy = false })); no(M(s, { enemy = true }))
        ok(M(s, {})); no(M(nil, {}))
    end)

    test("the glance: players of both factions, a hunter's pet, a demon, a totem, a companion; each once", function()
        local w, ola, kari, Last, Count = Setup()
        ola.state.faction = "Horde"
        ola:Hover{ companion = false, who = { player = true, name = "Elkid", class = "MAGE", race = "Gnome", faction = "Alliance",
            pvp = true, guid = "Player-6939-012B8EA5" } }
        local s = Last("glance")
        eq(s.kind, "player"); eq(s.class, "MAGE"); eq(s.race, "Gnome"); eq(s.faction, "Alliance")
        ok(s.enemy); ok(s.pvp); eq(s.reaction, 2); eq(s.key, "Elkid")
        ola:Hover{ companion = false, who = { player = true, name = "Elkid", class = "MAGE", race = "Gnome", faction = "Alliance",
            guid = "Player-6939-012B8EA5" } }
        eq(Count("glance"), 1, "the same unit again: not yet")
        -- A hunter's cat: the shared npc id, its owner from the tooltip line, our family.
        ola:Hover{ companion = false, lines = { { leftText = "Cat" }, { leftText = "Byfired Derifyb's Pet" } },
            who = { name = "Cat", faction = "Horde", family = { "Cat", 2 }, type = { "Beast", 1 }, guid = "Pet-0-6849-0-7-165189-0AB" } }
        s = Last("glance")
        eq(s.kind, "pet"); eq(s.npc, 165189); eq(s.owner, "Byfired Derifyb"); eq(s.family, "Cat"); eq(s.families[1], "cat")
        no(s.enemy)
        -- A warlock's Imp.
        ola:Hover{ companion = false, lines = { { leftText = "Kupqua" }, { leftText = "Lamento Funesto's Minion" } },
            who = { name = "Kupqua", faction = "Horde", family = { "Imp", 23 }, type = { "Demon", 3 }, guid = "Pet-0-6849-0-7-416-209D" } }
        s = Last("glance")
        eq(s.kind, "demon"); eq(s.owner, "Lamento Funesto"); eq(s.families[1], "demon")
        -- A totem and a critter.
        ola:Hover{ companion = false, who = { name = "Healing Stream Totem III", faction = "Horde", type = { "Totem", 11 },
            guid = "Creature-0-1-2-3-3907-AA" } }
        eq(Last("glance").kind, "totem"); eq(Last("glance").npc, 3907)
        ola:Hover{ companion = false, who = { name = "Rabbit", type = { "Critter", 8 }, guid = "Creature-0-1-2-3-721-AB" } }
        eq(Last("glance").kind, "critter")
        -- A guildmate's companion.
        ola:Hover{ species = 40, owner = "Kari Berg" }
        s = Last("glance")
        eq(s.kind, "companion"); eq(s.species, 40); eq(s.owner, "Kari Berg")
    end)

    test("the glance: nothing from a unit in combat, nor while you fight", function()
        local w, ola, kari, Last, Count = Setup()
        ola:Hover{ companion = false, secret = true, who = { player = true, name = "Elkid", class = "MAGE", faction = "Alliance" } }
        eq(Count("glance"), 0, "a secret identity")
        ola.state.combat = true
        ola:Hover{ companion = false, who = { player = true, name = "Ivar", class = "WARRIOR", faction = "Horde",
            guid = "Player-1-2" } }
        eq(Count("glance"), 0, "in combat")
    end)

    test("your casts, forms, buffs, pet and PvP flag", function()
        local w, ola, kari, Last, Count = Setup()
        ola.state.spellNames = { [1238640] = "Ghost Wolf" }
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "x", 1238640)
        eq(Last("cast").name, "Ghost Wolf"); eq(Last("cast").id, 1238640); eq(Last("cast").combat, false)
        ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "target", "x", 1)
        eq(Count("cast"), 1, "only yours")
        -- Forms: a change only (it fires with none, on a cast).
        ola.state.form = 16
        ola:Fire("UPDATE_SHAPESHIFT_FORM")
        ola:Fire("UPDATE_SHAPESHIFT_FORM")
        eq(Count("form"), 1); eq(Last("form").id, 16)
        ola.state.form = nil
        ola:Fire("UPDATE_SHAPESHIFT_FORM")
        eq(Last("form").was, 16); eq(Last("form").id, nil)
        -- Buffs gained; none while auras are secret.
        ola:Fire("UNIT_AURA", "player", { addedAuras = { { name = "Plainsrunning", spellId = 1299038, isHelpful = true },
            { name = "Weakened Soul", spellId = 6788, isHelpful = false } } })
        eq(Count("buff"), 1); eq(Last("buff").name, "Plainsrunning")
        ola:Fire("UNIT_AURA", "player", H.SECRET)
        ola:Fire("UNIT_AURA", "player", { addedAuras = H.SECRET })
        eq(Count("buff"), 1)
        -- A hunter's pet called, and dismissed.
        ola.units.pet = { who = { name = "Kitty", family = { "Cat", 2 }, type = { "Beast", 1 }, guid = "Pet-0-1-2-3-165189-01" } }
        ola:Fire("UNIT_PET", "player")
        local s = Last("pet")
        ok(s.out); eq(s.name, "Kitty"); eq(s.familyId, 2); eq(s.families[1], "cat")
        ola:Fire("UNIT_PET", "player")
        eq(Count("pet"), 1, "the same pet")
        ola.units.pet = nil
        ola:Fire("UNIT_PET", "player")
        no(Last("pet").out)
        -- The PvP flag.
        ola.state.pvp = true
        ola:Fire("PLAYER_FLAGS_CHANGED", "player")
        ola:Fire("UNIT_FACTION", "player")
        eq(Count("flag"), 1); ok(Last("flag").on)
    end)

    test("your group, zones as places, and emotes at you", function()
        local w, ola, kari, Last, Count = Setup()
        w:SetGroup({ "Ola Nord", "Kari Berg" })
        ola:Fire("GROUP_ROSTER_UPDATE")
        ola:Fire("GROUP_ROSTER_UPDATE")
        eq(Count("group"), 1, "a change only")
        eq(#Last("group").members, 1); eq(Last("group").members[1].key, "Kari Berg")
        -- Zones: your capital, the enemy's, a goblin town, a battleground.
        ola.state.faction = "Horde"
        ola.state.zone = "Orgrimmar"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        eq(Last("zone").place, "home"); eq(Last("zone").was, "Elwynn Forest")
        ola.state.zone = "Stormwind City"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        eq(Last("zone").place, "enemy")
        ola.state.zone, ola.state.subzone = "Stranglethorn Vale", "Booty Bay"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        ola:Fire("ZONE_CHANGED")
        eq(Count("zone"), 3, "the subzone with it, once"); eq(Last("zone").place, "neutral"); eq(Last("zone").subzone, "Booty Bay")
        ola.state.zone, ola.state.subzone, ola.state.instance = "Warsong Gulch", nil, "pvp"
        ola:Fire("ZONE_CHANGED_NEW_AREA")
        eq(Last("zone").place, "battleground")
        -- Emotes: someone else's, at you or not; never your own.
        ola:Fire("CHAT_MSG_TEXT_EMOTE", "Kari bows before you.", "Kari Berg", "", "", "", "", 0, 0, "", 0, 1, "Player-0000-00000002")
        local s = Last("emote")
        eq(s.from, "Kari Berg"); ok(s.me); eq(s.class, "WARRIOR")
        ola:Fire("CHAT_MSG_TEXT_EMOTE", "Kari waves.", "Kari Berg", "", "", "", "", 0, 0, "", 0, 2, "Player-0000-00000002")
        no(Last("emote").me)
        ola:Fire("CHAT_MSG_TEXT_EMOTE", "You dance.", "Ola Nord", "", "", "", "", 0, 0, "", 0, 3, "Player-0000-00000001")
        eq(Count("emote"), 2)
    end)
end
