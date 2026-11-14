-- Units: names (Forever's second value is the surname), range, GUIDs, the realm, the build;
-- companions in the world, nameplates and their tooltip data.
local H, P = ...

return function(c, env, S)
    local w = c.world
    -- Identity (Forever: the second value is the SURNAME, not the realm)
    local function UnitNameOf(u)
        if u == nil or u == "player" then return c.first, c.surname end
        local g = w:GroupOf(c.name)
        local kind, i = tostring(u):match("^(%a+)(%d+)$")
        i = tonumber(i)
        if g and kind == "party" then
            local n = 0
            for _, name in ipairs(g.members) do
                if name ~= c.name then
                    n = n + 1
                    if n == i then return name:match("^(%S+)%s*(.*)$") end
                end
            end
        elseif g and kind == "raid" and g.members[i] then
            return g.members[i]:match("^(%S+)%s*(.*)$")
        end
        local unit = c.units[u]
        if unit then return unit.name or (unit.who and unit.who.name) end
    end
    env.UnitName = UnitNameOf
    -- Range in the group: everyone is together unless w.apart[name] (that player is far from the rest).
    -- Like retail: in range, and whether it could check (not for a unit outside the group).
    local function InGroup(u) return tostring(u):match("^party%d") or tostring(u):match("^raid%d") end
    env.UnitInRange = function(u)
        local first, surname = UnitNameOf(u)
        if not (first and InGroup(u)) then return false, false end
        local name = surname and surname ~= "" and (first .. " " .. surname) or first
        local apart = w.apart and (w.apart[name] or w.apart[c.name])
        return not apart, true
    end
    env.UnitIsVisible = function(u)
        local first = UnitNameOf(u)
        return first ~= nil
    end
    env.UnitFullName = UnitNameOf
    env.UnitExists = function(u)
        if u == "player" or c.units[u] ~= nil then return true end
        return (tostring(u):match("^party%d+$") or tostring(u):match("^raid%d+$")) and UnitNameOf(u) ~= nil or false
    end
    env.UnitGUID = function(u)
        if c.units[u] and c.units[u].secret then return nil end -- (a unit in combat: its identity is secret)
        local who = c.units[u] and c.units[u].who
        if who and who.guid then return who.guid end
        return ("Player-0000-%08X"):format(c.idx)
    end
    -- Who a unit is (Forever: /dp probe api glance, 2026-11-14): you (S.class, S.race, S.faction, S.pvp), a
    -- group member (a player of your faction), or a unit a test put under the mouse (c:Hover{ who = ... }).
    local CLASS = { WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
        SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid" }
    local function Who(u)
        if u == "player" then
            return { player = true, class = S.class or "WARRIOR", race = S.race or "Human", faction = S.faction or "Alliance",
                pvp = S.pvp }
        end
        if InGroup(u) and UnitNameOf(u) then return { player = true, class = "WARRIOR", race = "Human", faction = S.faction or "Alliance" } end
        local x = c.units[u]
        return x and x.who
    end
    env.C_Secrets.ShouldUnitIdentityBeSecret = function(u) return c.units[u] ~= nil and c.units[u].secret == true end
    env.UnitIsPlayer = function(u) local x = Who(u); return x ~= nil and x.player == true end
    env.UnitClass = function(u)
        local x = Who(u)
        if not (x and x.class) then return nil end
        return CLASS[x.class] or x.class, x.class
    end
    env.UnitRace = function(u) local x = Who(u); if x and x.race then return x.race, x.race end end
    env.UnitFactionGroup = function(u) local x = Who(u); if x and x.faction then return x.faction, x.faction end end
    env.UnitIsPVP = function(u) local x = Who(u); return x ~= nil and x.pvp == true end
    env.UnitReaction = function(_, u)
        local x = Who(u)
        if not x then return nil end
        return x.reaction or (x.faction and (x.faction == (S.faction or "Alliance") and 5 or 2)) or 4
    end
    env.UnitIsEnemy = function(a, u) return (env.UnitReaction(a, u) or 4) <= 2 end
    env.UnitCreatureFamily = function(u) local x = Who(u); if x and x.family then return x.family[1], x.family[2] end end
    env.UnitCreatureType = function(u)
        local x = Who(u)
        if x and x.type then return x.type[1], x.type[2] end
        if x and x.player then return "Humanoid", 7 end
    end
    env.UnitClassification = function(u) local x = Who(u); return x and (x.classif or "normal") or nil end
    env.GetPlayerInfoByGUID = function() return "Warrior", "WARRIOR", "Human", "Human", 2, c.first, "" end
    env.GetNormalizedRealmName = function() return "CAMWOWEU4Realm1PvE" end
    env.GetRealmName = env.GetNormalizedRealmName
    env.GetAutoCompleteRealms = function() return { "CAMWOWEU4Realm1PvE", "CAMWOWEU4Realm2PvE" } end
    env.Ambiguate = function(n) return n end
    env.GetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end
    env.WOW_PROJECT_ID, env.WOW_PROJECT_CAMELOT = 18, 18
    env.GetFramerate = function() return 60 end


    -- Units (companions in the world)
    env.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
        assert(kind == env.Enum.TooltipDataType.Unit)
        c.tooltipCalls[#c.tooltipCalls + 1] = fn
    end }
    env.UnitIsBattlePetCompanion = function(u) local x = c.units[u]; return x and x.companion or false end
    env.UnitBattlePetSpeciesID = function(u) local x = c.units[u]; return x and x.species end
    -- Nameplates (c:Nameplate): the frame over a unit; nil for a unit without one.
    c.plates = {}
    env.C_NamePlate = {
        GetNamePlateForUnit = function(u) return c.plates[u] end,
        GetNamePlates = function()
            local list = {}
            for _, p in pairs(c.plates) do list[#list + 1] = p end
            table.sort(list, function(a, b) return a.namePlateUnitToken < b.namePlateUnitToken end)
            return list
        end,
    }
    env.UnitCreator = function() return nil end -- no owner API on Forever
    env.C_TooltipInfo = { GetUnit = function(u) local x = c.units[u]; return x and { lines = x.lines } end }

end
