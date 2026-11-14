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
        if unit then return unit.name end
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
    env.UnitExists = function(u) return u == "player" or c.units[u] ~= nil end
    env.UnitGUID = function(u)
        if c.units[u] and c.units[u].secret then return nil end -- (a unit in combat: its identity is secret)
        return ("Player-0000-%08X"):format(c.idx)
    end
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
