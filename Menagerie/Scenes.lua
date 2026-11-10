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
    frog = { EJ .. "Maraudon" }, -- (picked again 2026-11-10; was the Wailing Caverns, the plants' too)
    snake = { EJ .. "RazorfenKraul" },
    mechanical = { EJ .. "Gnomeregan" },
    dragon = { EJ .. "RagefireChasm" },
    pirate = { EJ .. "Deadmines" },
    -- Added and picked in game 2026-11-08 (the second round).
    bug = { EJ .. "RuinsofAhnQiraj" },
    rodent = { EJ .. "Scholomance" },
    wolf = { EJ .. "ShadowfangKeep" },
    plant = { EJ .. "WailingCaverns" },
    festive = { EJ .. "TempleofAhnQiraj" },
    demon = { EJ .. "MoltenCore" },
    ooze = { EJ .. "Uldaman" },
    spirit = { EJ .. "BlackfathomDeeps" },
    -- The data pass's new families, picked in game 2026-11-10.
    bear = { EJ .. "OnyxiasLair" },
    reptile = { EJ .. "SunkenTemple" },
    murloc = { EJ .. "BlackfathomDeeps", EJ .. "Deadmines" }, -- (2026-11-10: not picked in game yet)
    default = { EJ .. "BlackrockDepths" },
}

-- The part of a picture file that holds the art. The dungeon backgrounds
-- fill only the top left of their file: Blizzard's own journal shows
-- 0-0.7695 across and 0-0.8301 down (Blizzard_EncounterJournal.xml,
-- dungeonBG); the whole file left the art in a corner (seen 2026-11-08).
function Scenes.Crop(path)
    if path:find("UI%-EJ%-BACKGROUND%-") then return 0, 0.76953125, 0, 0.830078125 end
    return 0, 1, 0, 1
end

-- A species with a background of its own (before its families).
Scenes.BY_SPECIES = {
    [5159] = { EJ .. "ZulGurub" }, -- Panda Cub (chosen 2026-11-08)
}

-- Tags that belong to a family (Data/Companions.lua tags -> family).
Scenes.ALIAS = { event = "festive", lantern = "festive", whelp = "dragon", parrot = "bird", chicken = "farm" }
-- The tint per family: the color at the top of the card's gradient (it
-- fades darker toward the panel). Drawn, so always crisp.
Scenes.TINT = {
    cat = { 0.55, 0.32, 0.12 }, bird = { 0.22, 0.42, 0.68 }, owl = { 0.12, 0.14, 0.36 },
    farm = { 0.36, 0.46, 0.14 }, rabbit = { 0.28, 0.5, 0.24 }, frog = { 0.08, 0.36, 0.26 },
    snake = { 0.52, 0.42, 0.18 }, mechanical = { 0.3, 0.36, 0.42 }, dragon = { 0.55, 0.14, 0.04 },
    pirate = { 0.08, 0.3, 0.46 }, bug = { 0.3, 0.3, 0.12 }, rodent = { 0.45, 0.32, 0.18 },
    wolf = { 0.3, 0.32, 0.38 }, plant = { 0.15, 0.42, 0.15 }, festive = { 0.55, 0.15, 0.2 },
    demon = { 0.4, 0.05, 0.2 }, ooze = { 0.2, 0.45, 0.1 }, spirit = { 0.3, 0.2, 0.5 },
    bear = { 0.42, 0.27, 0.12 }, reptile = { 0.18, 0.36, 0.22 }, murloc = { 0.08, 0.34, 0.4 }, default = { 0.36, 0.26, 0.18 },
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
Scenes.ORDER = { "dragon", "demon", "mechanical", "pirate", "murloc", "owl", "frog", "snake", "reptile", "spirit", "ooze",
    "bear", "wolf", "cat", "bug", "plant", "rabbit", "rodent", "farm", "bird", "festive" }

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
    for _, t in ipairs(type(data) == "table" and data.t or {}) do tags[self.ALIAS[t] or t] = true end
    for _, family in ipairs(self.ORDER) do
        if tags[family] then list[#list + 1] = family end
    end
    return list
end

-- The background picture for a pet, or nil (then only the drawn layers).
function Scenes:For(key)
    if self.preview then return self.preview end
    local sid = ns.Pets:SpeciesOfKey(key)
    for _, path in ipairs(sid and self.BY_SPECIES[sid] or {}) do
        if Exists(path) then return path end
    end
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

-- The light over the card by the player's clock: { from hour, name, color
-- at the top, alpha at the top } (it fades out toward the panel). Day has
-- none: the scene as it is.
Scenes.SKY = {
    { 0, "natt", { 0.04, 0.07, 0.25 }, 0.5 },
    { 5, "morgen", { 0.95, 0.55, 0.45 }, 0.22 },
    { 8, "dag" },
    { 17, "kveld", { 1, 0.62, 0.18 }, 0.22 },
    { 20, "skumring", { 0.36, 0.2, 0.5 }, 0.32 },
    { 22, "natt", { 0.04, 0.07, 0.25 }, 0.5 },
}

-- The sky for hour h (0-23).
function Scenes:Sky(h)
    local sky = self.SKY[1]
    for _, s in ipairs(self.SKY) do if h >= s[1] then sky = s end end
    return sky
end

-- The card's colors by bond level, shared by the border (Decor) and the
-- bond track: the family's own up to 2, silver at 3-4, gold from 5.
Scenes.GOLD, Scenes.SILVER = { 1, 0.8, 0.25 }, { 0.82, 0.88, 1 }
function Scenes.Tier(level, family)
    if level >= 5 then return Scenes.GOLD end
    if level >= 3 then return Scenes.SILVER end
    return family or Scenes.GOLD
end

-- A color made brighter by f (capped at 1), as a new table.
function Scenes.Bright(c, f)
    return { math.min(1, c[1] * f), math.min(1, c[2] * f), math.min(1, c[3] * f) }
end

-- Draw the card's background for a pet: the picture and the tinted layers
-- (nil: clear them). Returns the family's tint.
function Scenes:Paint(card, key)
    local scene = key and self:For(key)
    if scene then
        card.scene:SetTexture(scene)
        card.scene:SetTexCoord(self.Crop(scene))
        card.scene:Show()
    else
        card.scene:Hide()
    end
    if not key then
        card.sky:Hide()
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
    local sky = self:Sky(tonumber(date("%H", ns.Now())))
    card.skyName = sky[2]
    if sky[3] then
        local k = sky[3]
        Gradient(card.sky, "VERTICAL", { k[1], k[2], k[3], sky[4] * 0.3 }, { k[1], k[2], k[3], sky[4] })
        card.sky:Show()
    else
        card.sky:Hide()
    end
    return c
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
        ns.Print("Backgrounds: back to the families.")
    elseif n then
        local c = list[n]
        if not c then return ns.Print(("No background %d (1-%d)."):format(n, #list)) end
        self.preview = c.path
        ns.Print(("Background %d on the card: %s (exists: %s). /dp probe bg off to stop."):format(n, c.path,
            tostring(Exists(c.path))))
    else
        local have = {}
        for i, c in ipairs(list) do
            local ok = Exists(c.path)
            if ok then have[#have + 1] = { n = i, path = c.path } end
            ns.Log("Probe", "bg %d %s %s: %s", i, ok and "YES" or "no", c.family, c.path)
        end
        ns.Print(("%d of %d backgrounds exist; the gallery shows them."):format(#have, #list))
        ns.SceneGallery:Show(have)
    end
    ns.JournalUI:Refresh() -- redraw the card
end
