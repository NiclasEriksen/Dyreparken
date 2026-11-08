local _, ns = ...

-- Decorations on the pet card (planned 2026-11-08): more as the bond grows,
-- small touches from the pet's traits. Which art Forever ships for them is
-- unknown, so this first part is a probe: candidate textures and atlases,
-- and `/dp probe decor` shows the ones that exist in a gallery to pick from
-- (DyreparkenDB.decorPicks, one per slot: corner, border, glow, sparkle...).
local Decor = {}
ns.Decor = Decor

local I = "Interface\\"
local PATHS = {
    "Cooldown\\star4", "Cooldown\\starburst", "Cooldown\\ping4",
    "Spellbook\\UI-GlyphFrame-Glow", "SpellActivationOverlay\\IconAlert", "SpellActivationOverlay\\IconAlertAnts",
    "Buttons\\UI-ActionButton-Border", "Buttons\\CheckButtonGlow", "CastingBar\\UI-CastingBar-Spark",
    "COMMON\\StreamBackground", "COMMON\\StreamCircle", "COMMON\\StreamFrame", "COMMON\\StreamSpark",
    "TargetingFrame\\UI-RaidTargetingIcon_1", "TargetingFrame\\UI-RaidTargetingIcon_2",
    "TargetingFrame\\UI-RaidTargetingIcon_3", "TargetingFrame\\UI-RaidTargetingIcon_5",
    "TargetingFrame\\UI-TargetingFrame-Elite", "TargetingFrame\\UI-TargetingFrame-Rare-Elite",
    "AchievementFrame\\UI-Achievement-WoodBorder-Corner", "AchievementFrame\\UI-Achievement-WoodBorder",
    "AchievementFrame\\UI-Achievement-MetalBorder", "AchievementFrame\\UI-Achievement-MetalBorder-Joint",
    "AchievementFrame\\UI-Achievement-Shields", "AchievementFrame\\UI-Achievement-Alert-Glow",
    "AchievementFrame\\UI-Achievement-Borders",
    "DialogFrame\\UI-DialogBox-Gold-Border", "DialogFrame\\UI-DialogBox-Gold-Corner",
    "DialogFrame\\UI-DialogBox-Header", "DialogFrame\\UI-DialogBox-Border", "Tooltips\\UI-Tooltip-Border",
    "LevelUp\\LevelUpTex", "LevelUp\\MinorTalents", "LootFrame\\LootToast", "Collections\\Collections",
    "PetBattles\\PetJournal", "PetBattles\\PetBattleHUD", "QuestFrame\\UI-QuestTitleHighlight",
    "FullScreenTextures\\OutofControl", "Glues\\LoadingBar\\Loading-BarGlow",
    "Icons\\INV_ValentinesCandy", "Icons\\INV_ValentinesCard02", "Icons\\INV_Holiday_Christmas_Present_01",
    "Icons\\INV_Misc_Bomb_04", "Icons\\Spell_Frost_SummonWaterElemental", "Icons\\INV_Misc_Food_Wheat_01",
}
local ATLASES = {
    "AftLevelup-WhiteStarBurst", "AftLevelup-SoftCloud", "AftLevelup-GlowLine", "AftLevelup-WhiteIconGlow",
    "AftLevelup-ToastBG", "PetJournal-FavoritesIcon", "collections-newglow", "bags-glow-white", "bags-glow-orange",
    "bags-glow-purple", "bags-glow-blue", "bags-glow-green", "bags-glow-heirloom", "bags-glow-artifact",
    "GarrLanding-CircleGlow", "ArtifactsFX-SpinningGlowys", "ArtifactsFX-StarBurst", "ArtifactsFX-Whirls",
    "heartofazeroth-orb-glow", "challenges-medal-gold", "challenges-medal-silver", "challenges-medal-bronze",
    "worldquest-questmarker-epic", "worldquest-questmarker-rare", "nameplates-icon-elite-gold",
    "nameplates-icon-elite-silver", "nameplates-icon-star", "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Gold-Winged",
    "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", "UI-Frame-DiamondMetal-CornerTopLeft",
    "UI-Frame-DiamondMetal-EdgeTop", "UI-Frame-GenericMetal-CornerTopLeft", "UI-Frame-Neutral-Ribbon",
    "GarrMission_RewardsBanner", "Bonus-Objective-Star", "loottoast-arrow-orange", "honorsystem-prestige-laurel",
    "communities-ring-gold", "Relic-Rankselected-circle", "legionmission-landingbutton-druid-up",
    "Garr_LevelUpgradeArrow", "groupfinder-icon-friend", "Islands-MarkedArea", "perks-star",
}

-- Every candidate once: a file path, or "atlas:<name>".
function Decor:Candidates()
    local list = {}
    for _, p in ipairs(PATHS) do list[#list + 1] = I .. p end
    for _, a in ipairs(ATLASES) do list[#list + 1] = "atlas:" .. a end
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
    for i, path in ipairs(list) do
        local ok = Decor.Exists(path)
        if ok then have[#have + 1] = { n = i, path = path } end
        ns.Log("Probe", "decor %d %s: %s", i, ok and "YES" or "no", path)
    end
    ns.Print(("%d av %d pynt-bilder finnes; galleriet viser dem."):format(#have, #list))
    ns.SceneGallery:Show(have, "decor")
end
