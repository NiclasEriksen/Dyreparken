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

-- The name a companion goes by in the world: its journal name, else the species.
function Pets:WorldName(guid)
    local _, speciesName, _, customName = Info(guid)
    if type(customName) == "string" and customName ~= "" then return customName end
    if type(speciesName) == "string" and speciesName ~= "" then return speciesName end
    return nil
end

-- Do we own one of this pet? One call for its species, not a walk of the
-- whole collection (Owned): the card asks on every update.
function Pets:IsOwned(key)
    local sid = self:SpeciesOfKey(key)
    if not (sid and C_PetJournal.GetNumCollectedInfo) then return self:Owned()[key] ~= nil end
    local n = C_PetJournal.GetNumCollectedInfo(sid)
    return type(n) == "number" and n > 0
end

function Pets:Summoned()
    return C_PetJournal.GetSummonedPetGUID()
end

-- The companion out right now: its key and guid (nil for none, or a secret).
function Pets:OutKey()
    local guid = ns.Plain(self:Summoned())
    local key = guid and self:KeyOf(guid)
    if key then return key, guid end
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

-- Species ID from a pet key ("s:5159" -> 5159).
function Pets:SpeciesOfKey(key)
    return tonumber(type(key) == "string" and key:match("^s:(%d+)$"))
end

function Pets:KeyOfSpecies(speciesID)
    return speciesID and "s:" .. speciesID or nil
end

-- Display name and icon for a pet key, whether or not we own it.
function Pets:NameOfKey(key)
    local sid = self:SpeciesOfKey(key)
    if sid and C_PetJournal.GetPetInfoBySpeciesID then
        local name = C_PetJournal.GetPetInfoBySpeciesID(sid)
        if type(name) == "string" and name ~= "" then return name end
    end
    local n = type(key) == "string" and key:match("^n:(.+)$")
    return n or tostring(key)
end

function Pets:IconOfKey(key)
    local sid = self:SpeciesOfKey(key)
    if sid and C_PetJournal.GetPetInfoBySpeciesID then
        local _, icon = C_PetJournal.GetPetInfoBySpeciesID(sid)
        return icon
    end
end

-- How many companions Forever has (Data/Companions.lua): counted from the
-- generated species list when there is one, else the stub's count.
function Pets:Total()
    local data = ns.Companions
    if not data then return 0 end
    if type(data.species) == "table" then
        local n = 0
        for _ in pairs(data.species) do n = n + 1 end
        return n
    end
    return data.count or 0
end

-- Find an owned pet by (part of) its name, case-insensitive. Returns key, guid.
function Pets:FindOwned(text)
    text = text:lower()
    local exact, partial
    for key, guid in pairs(self:Owned()) do
        local name = self:NameOfKey(key):lower()
        if name == text then exact = exact or { key, guid } end
        if name:find(text, 1, true) then partial = partial or { key, guid } end
    end
    local hit = exact or partial
    if hit then return hit[1], hit[2] end
end
