local _, ns = ...

-- The backgrounds' probe (development only, never packaged: #@do-not-package@
-- in the TOC). It extends ns.Scenes. /dp probe bg <n> shows a candidate on
-- every card through Scenes.override, which a release never sets.
local Scenes = ns.Scenes
local EJ = "Interface\\EncounterJournal\\UI-EJ-BACKGROUND-"

local function Exists(path)
    if not GetFileIDFromPath then return true end
    return GetFileIDFromPath(path) ~= nil
end

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
        self.override = nil
        ns.Print("Backgrounds: back to the families.")
    elseif n then
        local c = list[n]
        if not c then return ns.Print(("No background %d (1-%d)."):format(n, #list)) end
        self.override = function() return c.path end
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
