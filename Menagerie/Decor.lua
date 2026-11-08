local _, ns = ...

-- Decorations on the pet card (planned 2026-11-08): more as the bond grows,
-- small touches from the pet's traits. Which art Forever ships for them is
-- unknown, so this first part is a probe: candidate textures and atlases
-- per slot (corner, border, glow, sparkle...), and `/dp probe decor` shows
-- the ones that exist in a gallery, one slot at a time, to pick from
-- (DyreparkenDB.decorPicks, one per slot).
local Decor = {}
ns.Decor = Decor

-- The slots, in the gallery's order.
Decor.SLOTS = { "corner", "border", "frame", "glow", "sparkle", "star", "heart", "bubble", "confetti", "ribbon", "moon",
    "leaf", "paw" }

-- File paths found in the first probe (2026-11-08), per slot; the atlases
-- come from DecorCandidates.lua (generated from the retail atlas list).
local I = "Interface\\"
local PATHS = {
    corner = { "AchievementFrame\\UI-Achievement-WoodBorder-Corner", "DialogFrame\\UI-DialogBox-Gold-Corner" },
    border = { "DialogFrame\\UI-DialogBox-Gold-Border", "Tooltips\\UI-Tooltip-Border",
        "AchievementFrame\\UI-Achievement-WoodBorder", "AchievementFrame\\UI-Achievement-MetalBorder-Joint",
        "Buttons\\UI-ActionButton-Border" },
    frame = { "TargetingFrame\\UI-TargetingFrame-Elite", "TargetingFrame\\UI-TargetingFrame-Rare-Elite",
        "COMMON\\StreamCircle", "COMMON\\StreamFrame" },
    glow = { "Spellbook\\UI-GlyphFrame-Glow", "SpellActivationOverlay\\IconAlert", "Buttons\\CheckButtonGlow",
        "AchievementFrame\\UI-Achievement-Alert-Glow", "QuestFrame\\UI-QuestTitleHighlight", "COMMON\\StreamBackground" },
    sparkle = { "COMMON\\StreamSpark", "CastingBar\\UI-CastingBar-Spark", "Cooldown\\ping4" },
    star = { "Cooldown\\star4", "Cooldown\\starburst", "TargetingFrame\\UI-RaidTargetingIcon_1" },
    heart = { "Icons\\INV_ValentinesCandy", "Icons\\INV_ValentinesCard02" },
    bubble = { "Icons\\Spell_Frost_SummonWaterElemental" },
    confetti = { "Icons\\INV_Misc_Bomb_04", "Icons\\INV_Holiday_Christmas_Present_01" },
    ribbon = { "DialogFrame\\UI-DialogBox-Header", "AchievementFrame\\UI-Achievement-Shields" },
    moon = { "TargetingFrame\\UI-RaidTargetingIcon_5" },
    leaf = { "Icons\\INV_Misc_Food_Wheat_01" },
    paw = {},
}
-- The first probe's atlases that aren't in the generated lists' first picks.
local ATLASES = {
    glow = { "AftLevelup-WhiteIconGlow", "AftLevelup-SoftCloud", "bags-glow-orange", "bags-glow-heirloom",
        "GarrLanding-CircleGlow", "collections-newglow" },
    sparkle = { "ArtifactsFX-SpinningGlowys", "ArtifactsFX-Whirls" },
    star = { "AftLevelup-WhiteStarBurst", "ArtifactsFX-StarBurst", "PetJournal-FavoritesIcon", "Bonus-Objective-Star" },
    frame = { "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged", "communities-ring-gold", "challenges-medal-gold" },
    corner = { "UI-Frame-DiamondMetal-CornerTopLeft" },
    ribbon = { "UI-Frame-Neutral-Ribbon", "GarrMission_RewardsBanner", "honorsystem-prestige-laurel" },
}

-- Every candidate once, with its slot: { path, slot }. A path is a file
-- path or "atlas:<name>". The current picks stay in, wherever they're from.
function Decor:Candidates()
    local list, seen = {}, {}
    local function Add(path, slot)
        if seen[path] then return end
        seen[path] = true
        list[#list + 1] = { path = path, slot = slot }
    end
    local generated = ns.DecorCandidates or {}
    for _, slot in ipairs(self.SLOTS) do
        local pick = ns.DB.global.decorPicks[slot]
        if pick then Add(pick, slot) end
        for _, p in ipairs(PATHS[slot] or {}) do Add(I .. p, slot) end
        for _, a in ipairs(ATLASES[slot] or {}) do Add("atlas:" .. a, slot) end
        for _, a in ipairs(generated[slot] or {}) do Add("atlas:" .. a, slot) end
    end
    return list
end

-- Does the client have it?
function Decor.Exists(path)
    local atlas = path:match("^atlas:(.+)$")
    if atlas then
        return C_Texture ~= nil and C_Texture.GetAtlasInfo ~= nil and C_Texture.GetAtlasInfo(atlas) ~= nil
    end
    if not GetFileIDFromPath then return true end
    return GetFileIDFromPath(path) ~= nil
end

-- /dp probe decor
function Decor:Probe()
    local have, list = {}, self:Candidates()
    for i, c in ipairs(list) do
        local ok = Decor.Exists(c.path)
        if ok then have[#have + 1] = { n = i, path = c.path, slot = c.slot } end
        ns.Log("Probe", "decor %d %s %s: %s", i, ok and "YES" or "no", c.slot, c.path)
    end
    ns.Print(("%d av %d pynt-bilder finnes; galleriet viser dem."):format(#have, #list))
    ns.SceneGallery:Show(have, "decor")
end
