-- The player's state (S: combat, mount, movement, health, zone...), the global strings the
-- addon parses chat with, maps, emotes, sounds, spells, talents, quests and auras.
local H, P = ...

return function(c, env, S)
    local w = c.world
    -- Player state
    env.InCombatLockdown = function() return S.combat == true end
    env.UnitAffectingCombat = function() return S.combat == true end
    env.IsMounted = function() return S.mounted or false end
    env.GetShapeshiftFormID = function() return S.form end -- (nil: no form, like the client)
    env.GetUnitSpeed = function(u) assert(u == "player"); return S.moving and ((S.mounted or S.form) and 14 or 7) or 0 end
    env.UnitOnTaxi = function() return S.taxi or false end
    -- The swing: main hand and off hand speeds; ranged speed first. (Secret in combat? Unknown, 2026-11-12.)
    env.UnitAttackSpeed = function(u) assert(u == "player"); return S.swing or 2.0, nil end
    env.UnitRangedDamage = function(u) assert(u == "player"); return S.rangedSwing or 0, 0, 0, 0, 0, 0 end
    env.UnitIsDeadOrGhost = function() return S.dead or false end
    env.IsFlying = function() return S.flying or false end
    env.IsStealthed = function() return S.stealthed or false end
    env.UnitHealth = function() return S.health or 100 end
    env.UnitHealthMax = function() return S.healthMax or 100 end
    env.UnitCastingInfo = function() return S.casting end
    env.UnitChannelInfo = function() return S.channeling end
    env.IsInInstance = function() return S.instance ~= "none", S.instance end
    env.UnitStandState = function() return S.stand end
    env.IsSwimming = function() return S.swimming or false end
    env.IsResting = function() return S.resting or false end
    env.UnitIsAFK = function(u) return u == "player" and S.afk or false end
    env.UnitLevel = function() return S.level or 10 end
    env.UnitFactionGroup = function(u) local f = S.faction or "Alliance"; return f, f end
    env.GetZoneText = function() return S.zone or "Elwynn Forest" end
    env.GetBindLocation = function() return S.home end
    -- The chat formats skill-ups and reputation are read with (enUS GlobalStrings).
    env.SKILL_RANK_UP = "Your skill in %s has increased to %d."
    env.FACTION_STANDING_INCREASED = "Reputation with %s increased by %d." -- (Forever's, 2026-11-09)
    -- Rolls and fishing (enUS GlobalStrings).
    env.RANDOM_ROLL_RESULT = "%s rolls %d (%d-%d)"
    -- (Forever's, /dp probe api 2026-11-11: need and greed start with a loot history link)
    env.LOOT_ROLL_ROLLED_NEED = "|HlootHistory:%d|h[Loot]|h: Need Roll - %d for %s by %s"
    env.LOOT_ROLL_ROLLED_GREED = "|HlootHistory:%d|h[Loot]|h: Greed Roll - %d for %s by %s"
    env.LOOT_ROLL_ROLLED_DE = "Disenchant Roll - %d for %s by %s"
    env.LOOT_ITEM_SELF = "You receive loot: %s"
    env.LOOT_ITEM_PUSHED_SELF = "You receive item: %s"
    env.LOOT_ITEM_SELF_MULTIPLE = "You receive loot: %sx%d."
    env.ERR_FISH_ESCAPED = "Your fish got away!"
    env.DUEL_WINNER_KNOCKOUT = "%1$s has defeated %2$s in a duel" -- (Forever's, /dp probe api 2026-11-11)
    env.DUEL_WINNER_RETREAT = "%2$s has fled from %1$s in a duel"
    env.ERR_NEWTAXIPATH = "New flight path discovered!"
    env.ERR_LEARN_SPELL_S = "You have learned a new spell: %s."
    env.ERR_LEARN_ABILITY_S = "You have learned a new ability: %s."
    env.ERR_FISH_NOT_HOOKED = "No fish are hooked."
    env.ERR_ZONE_EXPLORED = "Discovered: %s" -- (Forever's, /dp probe api 2026-11-11)
    env.ERR_ZONE_EXPLORED_XP = "Discovered %s: %d experience gained" -- (retail's)
    -- Professions as on Forever (2026-11-13): GetProfessions gives the slots' indexes (primary, primary,
    -- archaeology, fishing, cooking; nil for an empty one), GetProfessionInfo(index) name, icon, rank,
    -- maxRank (the trainer's current cap), ..., skillLine. S.professions: { [slot] = { name, rank, max } }.
    env.GetProfessions = function()
        local p = S.professions or {}
        local function At(slot) return p[slot] and slot * 10 or nil end
        return At(1), At(2), At(3), At(4), At(5)
    end
    env.GetProfessionInfo = function(i)
        local p = (S.professions or {})[i / 10]
        if not p then return nil end
        return p[1], 136246, p[2], p[3], 0, 0, 100 + i, 0, 0, 0
    end
    -- Achievements (2026-11-13, Forever has Blizzard's): the Explorer category (15607) with Explore Azeroth
    -- (62053) and the two continents' zone lists. A zone criterion is done only when the zone is fully
    -- explored. S.explored: { [zone name] = true }; Explore Azeroth is done when every zone is.
    -- S.achievementsById = false: GetAchievementInfo(id) gives nothing (only the category form works).
    local EXPLORE = { [62353] = { "Elwynn Forest", "Westfall", "Duskwood", "Riverglades" },
        [62355] = { "Durotar", "The Barrens", "Darkshore" } }
    H.EXPLORE_ZONES = EXPLORE
    local CAT = { 62053, 62353, 62355 }
    local function Done(id)
        local explored = S.explored or {}
        if id == 62053 then return Done(62353) and Done(62355) end
        for _, zone in ipairs(EXPLORE[id]) do if not explored[zone] then return false end end
        return true
    end
    local TITLES = { [62053] = "Explore Azeroth", [62353] = "Explore Eastern Kingdoms", [62355] = "Explore Kalimdor" }
    env.GetCategoryList = function() return { 92, 15607 } end
    env.GetCategoryInfo = function(cat) return cat == 15607 and "Explorer" or "General" end
    env.GetCategoryNumAchievements = function(cat) return cat == 15607 and #CAT or 0 end
    env.GetAchievementInfo = function(a, i)
        local id = a
        if i then id = a == 15607 and CAT[i] or nil
        elseif S.achievementsById == false then id = nil end
        if not TITLES[id] then return nil end
        return id, TITLES[id], 10, Done(id), 11, 13, 26, "", 0, 136246, "", false, Done(id), nil, false
    end
    env.GetAchievementNumCriteria = function(id) return id == 62053 and 2 or EXPLORE[id] and #EXPLORE[id] or 0 end
    env.GetAchievementCriteriaInfo = function(id, j)
        if id == 62053 then
            local sub = ({ 62353, 62355 })[j]
            if not sub then return nil end
            return j == 1 and "Eastern Kingdoms" or "Kalimdor", 8, Done(sub), Done(sub) and 1 or 0, 1
        end
        local zone = EXPLORE[id] and EXPLORE[id][j]
        if not zone then return nil end
        local done = (S.explored or {})[zone] == true
        return zone, 0, done, done and 1 or 0, 1
    end
    -- Map ids (S.map, default Elwynn's 1429), names from S.mapNames.
    env.C_Map = {
        GetBestMapForUnit = function(u) assert(u == "player"); return S.map or 1429 end,
        -- (S.mapTree: id -> { parent, mapType }, as the client's parents: a zone (3) in a continent (2))
        GetMapInfo = function(id)
            local t = (S.mapTree or {})[id] or {}
            return { mapID = id, name = (S.mapNames or {})[id] or ("Map " .. id), parentMapID = t[1], mapType = t[2] }
        end,
        -- (S.mapPos = { x, y }: where on the zone's map, 0..1; the middle unless a test says. A Vector2D, as the client's)
        GetPlayerMapPosition = function(id, u)
            assert(u == "player")
            if not id then return nil end
            local p = S.mapPos or { 0.5, 0.5 }
            return { x = p[1], y = p[2], GetXY = function(v) return v.x, v.y end }
        end,
    }
    -- Emotes and jumps: what the player pressed (hooked by the addon).
    env.DoEmote = function(token, target) S.lastEmote = token end
    env.JumpOrAscendStart = function() S.jumps = (S.jumps or 0) + 1 end
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    -- The cursor, in screen pixels (c.cursor = { x, y }).
    env.GetCursorPosition = function() local p = c.cursor or { 0, 0 }; return p[1], p[2] end
    -- Sounds: the ones played are recorded in c.sounds. A few SOUNDKIT names.
    env.SOUNDKIT = { UI_70_ARTIFACT_FORGE_TRAIT_GOLD_TRAIT = 83681, UI_EPICLOOT_TOAST = 31578, LEVELUPSOUND = 888,
        IG_CHARACTER_INFO_TAB = 841 }
    env.PlaySound = function(id, channel)
        c.sounds = c.sounds or {}
        c.sounds[#c.sounds + 1] = id
        return true
    end
    env.C_Spell = { GetSpellName = function(id) return S.spellNames and S.spellNames[id] end,
        -- (6603 Attack: true while auto-attack is on; the global IsCurrentSpell doesn't exist on Forever)
        IsCurrentSpell = function(id) return id == 6603 and S.attacking or false end }
    -- Spells the character knows (S.spells: id -> true; c:Learn), talents unspent (S.unspent), quests.
    env.IsPlayerSpell = function(id) return S.spells ~= nil and S.spells[id] == true end
    env.IsSpellKnown = function(id) return S.spells ~= nil and S.spells[id] == true end
    env.GetNumUnspentTalents = function() return S.unspent or 0 end
    env.C_Item = { GetItemCount = function(id) return S.items and S.items[id] or 0 end } -- (S.items: id -> count in the bags)
    -- Talents as on Forever (retail's system, Classic trees): S.config the active loadout's id,
    -- S.talents { [nodeID] = rank } its ranks, in one tree.
    env.C_ClassTalents = { GetActiveConfigID = function() return S.config end }
    env.C_Traits = {
        GetConfigInfo = function(id) return id == S.config and { ID = id, treeIDs = { 1 } } or nil end,
        GetTreeNodes = function()
            local nodes = {}
            for node in pairs(S.talents or {}) do nodes[#nodes + 1] = node end
            table.sort(nodes)
            return nodes
        end,
        GetNodeInfo = function(_, node) return { ID = node, activeRank = (S.talents or {})[node] or 0 } end,
    }
    env.C_QuestLog = {
        GetTitleForQuestID = function(id) return S.questTitles and S.questTitles[id] end,
        IsQuestFlaggedCompleted = function(id) return S.questsDone ~= nil and S.questsDone[id] == true end,
        RequestLoadQuestByID = function(id) S.questsAsked = (S.questsAsked or 0) + 1 end,
        GetAllCompletedQuestIDs = function()
            local ids = {}
            for id in pairs(S.questsDone or {}) do ids[#ids + 1] = id end
            table.sort(ids)
            return ids
        end,
    }

    env.C_UnitAuras = { GetAuraDataBySpellName = function(unit, name, filter)
        assert(unit == "player" and filter == "HELPFUL")
        if S.aurasError then error("aura query failed") end
        local a = S.auras[name]
        if type(a) == "table" then return a end -- (a test's own AuraData: duration, expirationTime...)
        return a and { name = name } or nil
    end }
end
