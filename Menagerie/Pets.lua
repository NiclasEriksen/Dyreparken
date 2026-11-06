local _, ns = ...

-- Read-only access to the player's companion collection (C_PetJournal).
--
-- Pet key: the guild-wide identity of a companion "species", used for
-- reservations and on the wire. It must be the same on every client.
--   * Prefer speciesID (locale independent).
--   * AutoCompanion avoids speciesID on Forever and keys by English name;
--     whether speciesID is reliable on Forever is UNVERIFIED. `/dp probe`
--     dumps what the journal returns so we can decide. Until then KeyOf
--     falls back to "n:<speciesName>" when there is no speciesID.
-- Forever has no pet battles, caging or trading: one copy per companion.
local Pets = {}
ns.Pets = Pets

-- GetPetInfoByPetID returns: speciesID, customName, level, xp, maxXp,
-- displayID, isFavorite, name (species name), icon, petType, ...
local function Info(guid)
    if not guid then return nil end
    local ok, speciesID, customName, _, _, _, _, _, speciesName, icon = pcall(C_PetJournal.GetPetInfoByPetID, guid)
    if not ok then return nil end
    return speciesID, speciesName, icon, customName
end

function Pets:KeyOf(guid)
    local speciesID, speciesName = Info(guid)
    if type(speciesID) == "number" and speciesID > 0 then return "s:" .. speciesID end
    if type(speciesName) == "string" and speciesName ~= "" then return "n:" .. speciesName end
    return nil
end

function Pets:Summoned()
    return C_PetJournal.GetSummonedPetGUID()
end

-- { [petKey] = guid } for everything the player owns. Built on demand only
-- (when the journal opens, when picking); not cached across sessions.
function Pets:Owned()
    local result = {}
    local ids = C_PetJournal.GetOwnedPetIDs and C_PetJournal.GetOwnedPetIDs()
    if type(ids) == "table" then
        for _, guid in ipairs(ids) do
            local key = self:KeyOf(guid)
            if key then result[key] = guid end
        end
    else
        for i = 1, C_PetJournal.GetNumPets() do
            local guid, _, isOwned = C_PetJournal.GetPetInfoByIndex(i)
            if isOwned and guid then
                local key = self:KeyOf(guid)
                if key then result[key] = guid end
            end
        end
    end
    return result
end

-- Development aid: print and log what the journal API gives us on this client.
function Pets:Probe()
    local P = ns.Print
    P("Probe: C_PetJournal=" .. tostring(C_PetJournal ~= nil)
        .. " GetOwnedPetIDs=" .. tostring(C_PetJournal and C_PetJournal.GetOwnedPetIDs ~= nil)
        .. " SetCustomName=" .. tostring(C_PetJournal and C_PetJournal.SetCustomName ~= nil))
    P("Frames: CollectionsJournal=" .. tostring(CollectionsJournal ~= nil)
        .. " PetJournal=" .. tostring(PetJournal ~= nil)
        .. " Blizzard_Collections loaded=" .. tostring(C_AddOns.IsAddOnLoaded("Blizzard_Collections")))
    local n, owned = C_PetJournal.GetNumPets()
    P(("GetNumPets: %s shown, %s owned"):format(tostring(n), tostring(owned)))
    local guid = self:Summoned()
    if guid then
        local results = { pcall(C_PetJournal.GetPetInfoByPetID, guid) }
        local parts = {}
        for i = 2, math.min(#results, 13) do parts[#parts + 1] = tostring(results[i]) end
        P("Summoned " .. tostring(guid) .. ": " .. table.concat(parts, ", "))
        ns.Log("Probe", "summoned %s: %s", tostring(guid), table.concat(parts, ", "))
    else
        P("No companion summoned; summon one and probe again for its info.")
    end
end
