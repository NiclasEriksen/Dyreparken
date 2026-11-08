local _, ns = ...

-- Backgrounds behind the companion on the pet card, by family (our tags in
-- Data/Companions.lua). Each family lists candidate textures, best first;
-- the card shows the first the client has (GetFileIDFromPath). Which large
-- art Forever ships is unknown (2026-11-08), so these are guesses until
-- `/dp probe bg` has listed them and they've been looked at in game
-- (`/dp probe bg <n>` previews one on the card).
local Scenes = {}
ns.Scenes = Scenes

local EJ = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-"

-- family tag -> candidates. "default" is for pets without a listed family.
-- Picked in game from the gallery, 2026-11-08 (build 70862): dungeon
-- backgrounds (UI-EJ-BACKGROUND-*). The pet battle weathers are small
-- overlays (a blur when stretched) and the loading screens that exist are
-- the generic splash, so neither is used.
Scenes.BY_FAMILY = {
    cat = { EJ .. "TheStockade" },
    bird = { EJ .. "ShadowfangKeep" },
    owl = { EJ .. "ScarletMonastery" },
    farm = { EJ .. "Karazhan" },
    rabbit = { EJ .. "RazorfenDowns" },
    frog = { EJ .. "WailingCaverns" },
    snake = { EJ .. "RazorfenKraul" },
    mechanical = { EJ .. "Gnomeregan" },
    dragon = { EJ .. "RagefireChasm" },
    pirate = { EJ .. "Deadmines" },
    default = { EJ .. "BlackrockDepths" },
}
-- The tint per family: the color at the top of the card's gradient (it
-- fades darker toward the panel). Drawn, so always crisp.
Scenes.TINT = {
    cat = { 0.55, 0.32, 0.12 }, bird = { 0.22, 0.42, 0.68 }, owl = { 0.12, 0.14, 0.36 },
    farm = { 0.36, 0.46, 0.14 }, rabbit = { 0.28, 0.5, 0.24 }, frog = { 0.08, 0.36, 0.26 },
    snake = { 0.52, 0.42, 0.18 }, mechanical = { 0.3, 0.36, 0.42 }, dragon = { 0.55, 0.14, 0.04 },
    pirate = { 0.08, 0.3, 0.46 }, default = { 0.36, 0.26, 0.18 },
}

-- Dungeon backgrounds to look for (not used until seen): the classic
-- dungeons and raids, by the naming that found three (UI-EJ-BACKGROUND-),
-- and the same names as lore backgrounds. /dp probe bg lists the ones found.
local NAMES = { "RagefireChasm", "Ragefire", "Deadmines", "ShadowfangKeep", "BlackfathomDeeps", "TheStockade",
    "StormwindStockades", "RazorfenKraul", "RazorfenDowns", "ScarletMonastery", "ScarletHalls", "Uldaman",
    "ZulFarrak", "Maraudon", "SunkenTemple", "TempleOfAtalHakkar", "BlackrockSpire", "LowerBlackrockSpire",
    "UpperBlackrockSpire", "DireMaul", "Scholomance", "Stratholme", "MoltenCore", "BlackwingLair", "OnyxiasLair",
    "ZulGurub", "RuinsofAhnQiraj", "TempleofAhnQiraj", "Naxxramas", "Karazhan", "WailingCaverns", "Gnomeregan",
    "BlackrockDepths" }
Scenes.EXTRA = {}
for _, n in ipairs(NAMES) do Scenes.EXTRA[#Scenes.EXTRA + 1] = EJ .. n end
for _, n in ipairs(NAMES) do Scenes.EXTRA[#Scenes.EXTRA + 1] = "Interface\\EncounterJournal\\UI-EJ-LOREBG-" .. n end

-- The order families are tried in, for a pet with several tags.
Scenes.ORDER = { "dragon", "mechanical", "pirate", "owl", "frog", "snake", "cat", "rabbit", "farm", "bird" }

local function Exists(path)
    if not GetFileIDFromPath then return true end
    return GetFileIDFromPath(path) ~= nil
end

local found = {} -- family -> path or false (cached)
local function First(family)
    -- A pick made in the gallery (SceneGallery.lua) comes first.
    local pick = ns.DB.global.scenePicks[family]
    if pick then return pick end
    if found[family] == nil then
        found[family] = false
        for _, path in ipairs(Scenes.BY_FAMILY[family] or {}) do
            if Exists(path) then found[family] = path; break end
        end
    end
    return found[family] or nil
end

-- Forget the cached lookups (after picks change).
function Scenes:Reset() wipe(found) end

-- A pet's families in our order (first = the one that sets its look).
function Scenes:Families(key)
    local sid = ns.Pets:SpeciesOfKey(key)
    local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
    local tags, list = {}, {}
    for _, t in ipairs(type(data) == "table" and data.t or {}) do tags[t] = true end
    for _, family in ipairs(self.ORDER) do
        if tags[family] then list[#list + 1] = family end
    end
    return list
end

-- The background picture for a pet, or nil (then only the drawn layers).
function Scenes:For(key)
    if self.preview then return self.preview end
    for _, family in ipairs(self:Families(key)) do
        local path = First(family)
        if path then return path end
    end
    return First("default")
end

local function Gradient(t, orientation, a, b)
    if t.SetGradient and CreateColor then
        t:SetGradient(orientation, CreateColor(unpack(a)), CreateColor(unpack(b)))
    else
        t:SetVertexColor(b[1], b[2], b[3], (a[4] + b[4]) / 2)
    end
end

-- Draw the tinted layers on the card for a pet (nil: clear them).
function Scenes:Paint(card, key)
    if not key then
        card.tint:Hide(); card.floor:Hide()
        for _, e in ipairs(card.edges) do e:Hide() end
        return
    end
    local family = self:Families(key)[1] or "default"
    local c = self.TINT[family] or self.TINT.default
    -- VERTICAL: the first color is the bottom.
    Gradient(card.tint, "VERTICAL", { c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 0.55 }, { c[1], c[2], c[3], 0.6 })
    card.tint:Show()
    for _, e in ipairs(card.edges) do
        local dark, clear = { 0, 0, 0, 0.7 }, { 0, 0, 0, 0 }
        if e.side == "TOP" then Gradient(e, "VERTICAL", clear, dark)
        elseif e.side == "LEFT" then Gradient(e, "HORIZONTAL", dark, clear)
        else Gradient(e, "HORIZONTAL", clear, dark) end
        e:Show()
    end
    card.floor:Show()
    card.family = family
end

-- Every candidate once, numbered, in a stable order.
function Scenes:Candidates()
    local list, seen = {}, {}
    local families = { "default" }
    for _, f in ipairs(self.ORDER) do families[#families + 1] = f end
    for _, f in ipairs(families) do
        for _, path in ipairs(self.BY_FAMILY[f] or {}) do
            if not seen[path] then
                seen[path] = true
                list[#list + 1] = { path = path, family = f }
            end
        end
    end
    for _, path in ipairs(self.EXTRA) do
        if not seen[path] then
            seen[path] = true
            list[#list + 1] = { path = path, family = "probe" }
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
        local have = {}
        for i, c in ipairs(list) do
            local ok = Exists(c.path)
            if ok then have[#have + 1] = { n = i, path = c.path } end
            ns.Log("Probe", "bg %d %s %s: %s", i, ok and "YES" or "no", c.family, c.path)
        end
        ns.Print(("%d av %d bakgrunner finnes; galleriet viser dem."):format(#have, #list))
        ns.SceneGallery:Show(have)
    end
    ns.JournalUI:Refresh() -- redraw the card
end
