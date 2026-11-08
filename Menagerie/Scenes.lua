local _, ns = ...

-- Backgrounds behind the companion on the pet card, by family (our tags in
-- Data/Companions.lua). Each family lists candidate textures, best first;
-- the card shows the first the client has (GetFileIDFromPath). Which large
-- art Forever ships is unknown (2026-11-08), so these are guesses until
-- `/dp probe bg` has listed them and they've been looked at in game
-- (`/dp probe bg <n>` previews one on the card).
local Scenes = {}
ns.Scenes = Scenes

local PB, EJ, LS = "Interface\\PetBattles\\", "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-",
    "Interface\\Glues\\LoadingScreens\\"

-- family tag -> candidates. "default" is for pets without a listed family.
Scenes.BY_FAMILY = {
    cat = { LS .. "LoadScreenElwynnForest", LS .. "LoadScreenGoldshire", PB .. "Weather-Darkness" },
    bird = { PB .. "Weather-Sunlight", LS .. "LoadScreenWestfall" },
    owl = { PB .. "Weather-Moonlight", LS .. "LoadScreenDarnassus" },
    farm = { LS .. "LoadScreenWestfall", PB .. "Weather-Sunlight" },
    rabbit = { LS .. "LoadScreenElwynnForest", PB .. "Weather-Sunlight" },
    frog = { PB .. "Weather-Rain", EJ .. "WailingCaverns", PB .. "Weather-Mud" },
    snake = { PB .. "Weather-Sandstorm", EJ .. "WailingCaverns" },
    mechanical = { PB .. "Weather-StaticField", EJ .. "Gnomeregan" },
    dragon = { PB .. "Weather-BurntEarth", EJ .. "BlackrockDepths" },
    pirate = { EJ .. "TheDeadmines", LS .. "LoadScreenDeadmines", PB .. "Weather-Rain" },
    default = { LS .. "LoadScreenEasternKingdom", LS .. "LoadScreenKalimdor", PB .. "Weather-Sunlight" },
}
-- The order families are tried in, for a pet with several tags.
Scenes.ORDER = { "dragon", "mechanical", "pirate", "owl", "frog", "snake", "cat", "rabbit", "farm", "bird" }

local function Exists(path)
    if not GetFileIDFromPath then return true end
    return GetFileIDFromPath(path) ~= nil
end

local found = {} -- family -> path or false (cached)
local function First(family)
    if found[family] == nil then
        found[family] = false
        for _, path in ipairs(Scenes.BY_FAMILY[family] or {}) do
            if Exists(path) then found[family] = path; break end
        end
    end
    return found[family] or nil
end

-- The background for a pet, or nil (then the card keeps Blizzard's).
function Scenes:For(key)
    if self.preview then return self.preview end
    local sid = ns.Pets:SpeciesOfKey(key)
    local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
    local tags = {}
    for _, t in ipairs(type(data) == "table" and data.t or {}) do tags[t] = true end
    for _, family in ipairs(self.ORDER) do
        if tags[family] then
            local path = First(family)
            if path then return path end
        end
    end
    return First("default")
end

-- Every candidate once, numbered, in a stable order.
function Scenes:Candidates()
    local list, seen = {}, {}
    local families = { "default" }
    for _, f in ipairs(self.ORDER) do families[#families + 1] = f end
    for _, f in ipairs(families) do
        for _, path in ipairs(self.BY_FAMILY[f]) do
            if not seen[path] then
                seen[path] = true
                list[#list + 1] = { path = path, family = f }
            end
        end
    end
    return list
end

-- /dp probe bg: which candidates the client has. /dp probe bg <n>: show
-- candidate n on the card (any pet) until /dp probe bg off.
function Scenes:Probe(arg)
    local list = self:Candidates()
    local n = tonumber(arg)
    if arg == "off" then
        self.preview = nil
        ns.Print("Bakgrunn: tilbake til familiene.")
    elseif n then
        local c = list[n]
        if not c then return ns.Print(("Ingen bakgrunn nr. %d (1-%d)."):format(n, #list)) end
        self.preview = c.path
        ns.Print(("Bakgrunn %d på kortet: %s (finnes: %s). /dp probe bg off for å avslutte."):format(n, c.path,
            tostring(Exists(c.path))))
    else
        local have = 0
        for i, c in ipairs(list) do
            local ok = Exists(c.path)
            if ok then have = have + 1 end
            local msg = ("bg %d %s %s: %s"):format(i, ok and "YES" or "no", c.family, c.path)
            ns.Log("Probe", "%s", msg)
            if ok then ns.Print(msg) end
        end
        ns.Print(("%d av %d bakgrunner finnes. Forhåndsvis med /dp probe bg <nr>."):format(have, #list))
    end
    ns.JournalUI:Refresh() -- redraw the card
end
