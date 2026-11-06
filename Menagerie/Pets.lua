local _, ns = ...

-- Read-only access to the player's companion collection (C_PetJournal).
--
-- Pet key: the guild-wide identity of a companion "species", used for
-- reservations and on the wire. It must be the same on every client.
--   * "s:<speciesID>". Forever returns real species IDs (Panda Cub = 5159,
--     probed 2026-11-06, build 70790; Forever's own numbering, not Retail's).
--     Locale independent, unlike the name.
--   * Fallback "n:<speciesName>" only if a client ever returns no ID.
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

-- Development aid: print AND log what the journal API gives us on this
-- client, so the output can be read from SavedVariables after /reload.
local function Out(fmt, ...)
    local msg = fmt:format(...)
    ns.Print(msg)
    ns.Log("Probe", "%s", msg)
end

local function Has(t, k) return tostring(t ~= nil and t[k] ~= nil) end

local function Pack(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, ", ")
end

function Pets:Probe()
    local PJ = C_PetJournal
    Out("build: %s", Pack(GetBuildInfo()))
    Out("project: WOW_PROJECT_ID=%s CAMELOT=%s", tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_CAMELOT))
    -- Identity: Forever has surnames and odd realm strings; we need to know
    -- which API matches the sender name in CHAT_MSG_ADDON.
    Out("identity: UnitName=%s | UnitFullName=%s | GetRealmName=%s | GetNormalizedRealmName=%s | PlayerKey=%s",
        Pack(UnitName("player")), Pack(UnitFullName("player")), tostring(GetRealmName()),
        tostring(GetNormalizedRealmName()), tostring(ns.PlayerKey()))
    Out("identity: GUID=%s | GetGuildInfo=%s | GetPlayerInfoByGUID=%s",
        tostring(UnitGUID("player")), Pack(GetGuildInfo("player")),
        GetPlayerInfoByGUID and Pack(GetPlayerInfoByGUID(UnitGUID("player"))) or "nil")
    local list = GetAutoCompleteRealms and GetAutoCompleteRealms()
    Out("connected realms: %s", type(list) == "table" and table.concat(list, ", ") or tostring(list))
    local fns = { "GetOwnedPetIDs", "GetPetInfoByPetID", "GetPetInfoBySpeciesID", "GetPetInfoByIndex",
        "GetNumPets", "GetSummonedPetGUID", "SummonPetByGUID", "SetCustomName", "PetIsSummonable",
        "GetPetSummonInfo", "FindPetIDByName", "GetNumCollectedInfo", "PetIsFavorite" }
    local have = {}
    for _, f in ipairs(fns) do have[#have + 1] = f .. "=" .. Has(PJ, f) end
    Out("C_PetJournal: %s", table.concat(have, " "))
    Out("frames: CollectionsJournal=%s PetJournal=%s Blizzard_Collections=%s",
        tostring(CollectionsJournal ~= nil), tostring(PetJournal ~= nil),
        tostring(C_AddOns.IsAddOnLoaded("Blizzard_Collections")))
    if PetJournal then
        Out("PetJournal children: ScrollBox=%s PetCard=%s SummonButton=%s",
            Has(PetJournal, "ScrollBox"), tostring(PetJournalPetCard ~= nil), tostring(PetJournalSummonButton ~= nil))
    end
    Out("GetNumPets: %s", Pack(PJ.GetNumPets()))
    local guid = self:Summoned()
    if not guid then
        Out("No companion summoned; summon one and probe again for its info.")
        return
    end
    Out("summoned %s: %s", tostring(guid), Pack(pcall(PJ.GetPetInfoByPetID, guid)))
    local speciesID = Info(guid)
    if PJ.GetPetInfoBySpeciesID and speciesID then
        Out("bySpecies %s: %s", tostring(speciesID), Pack(pcall(PJ.GetPetInfoBySpeciesID, speciesID)))
    end
    if PJ.GetNumCollectedInfo and speciesID then
        Out("collected %s: %s", tostring(speciesID), Pack(pcall(PJ.GetNumCollectedInfo, speciesID)))
    end
    if PJ.PetIsSummonable then Out("summonable: %s", Pack(pcall(PJ.PetIsSummonable, guid))) end
end
