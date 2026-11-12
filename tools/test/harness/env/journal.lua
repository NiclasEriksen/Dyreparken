-- C_PetJournal, as on Forever (GetPetInfoByPetID's real shape); the filter setters throw.
local H, P = ...
local SpeciesName = P.SpeciesName

return function(c, env, S)
    local w = c.world
    -- Pet journal (Forever: GetPetInfoByPetID's real shape, probed 2026-11-06)
    local function NoFilters() error("Dyreparken must not change the pet journal filters (see CLAUDE.md)", 2) end
    env.C_PetJournal = {
        GetSummonedPetGUID = function() return c.summoned end,
        GetOwnedPetIDs = not c.noOwnedPetIDs and function()
            local ids = {}
            for _, p in ipairs(c.pets) do ids[#ids + 1] = p.guid end
            return ids
        end or nil,
        GetPetInfoByPetID = function(guid)
            for _, p in ipairs(c.pets) do
                if p.guid == guid then
                    if c.noSpeciesID then return 0, nil, 1, 0, 1, 1, false, SpeciesName(p.sid), 1, 5 end
                    return p.sid, nil, 1, 0, 1, 146955, false, SpeciesName(p.sid), 7831521, 5, 272330, ""
                end
            end
            error("Invalid pet GUID")
        end,
        GetPetInfoBySpeciesID = function(sid)
            if not H.SPECIES[sid] then return nil end
            -- name, icon, petType, creatureID, sourceText, description, isWild, canBattle, tradable, unique,
            -- obtainable, creatureDisplayID (as on Forever: /dp probe api, 2026-11-11)
            return H.SPECIES[sid], 1000 + sid, 5, 272330, "", "", false, true, false, true, true, 20000 + sid
        end,
        GetNumPets = function() return #(c.journalList or c.pets), #c.pets end,
        -- (Forever: 1271, 7 for the prairie dog, /dp probe api petframe; one scene for all here)
        GetPetModelSceneInfoBySpeciesID = function(sid) if H.SPECIES[sid] then return 1271, 7 end end,
        GetPetInfoByIndex = function(i)
            local list = c.journalList or {}
            if not c.journalList then
                for _, p in ipairs(c.pets) do list[#list + 1] = { guid = p.guid, sid = p.sid, owned = true } end
            end
            local e = list[i]
            if e then return e.guid, e.sid, e.owned end
        end,
        -- Forever: toggles. Called on the pet that's out, it dismisses it.
        SummonPetByGUID = function(guid)
            c.summonCalls = c.summonCalls + 1
            if (c.summonFails or 0) > 0 then c.summonFails = c.summonFails - 1; return end
            c.summoned = c.summoned ~= guid and guid or nil
        end,
        PetIsSummonable = function() return true end,
        -- The journal's filters: Forever has no Filter button, so a filter left
        -- wrong empties the list for good. The addon must never change them.
        SetFilterChecked = NoFilters, SetAllPetTypesChecked = NoFilters, SetAllPetSourcesChecked = NoFilters,
        SetPetTypeFilter = NoFilters, SetPetSourceChecked = NoFilters, SetSearchFilter = NoFilters,
        ClearSearchFilter = NoFilters, SetDefaultFilters = NoFilters,
        -- (owned, max) for a species: how many of it this client has.
        GetNumCollectedInfo = function(sid)
            local n = 0
            for _, p in ipairs(c.pets) do if p.sid == sid then n = n + 1 end end
            return n, 3
        end,
    }
end
