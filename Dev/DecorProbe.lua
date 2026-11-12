local _, ns = ...

-- The decorations' probes and previews (development only, never packaged:
-- #@do-not-package@ in the TOC). They extend ns.Decor:
--   /dp probe decor     every candidate picture that exists, in a gallery
--   /dp probe frames    a border per family, in a gallery
--   /dp probe level <n> the card dressed as that bond level
-- While a gallery or a level preview is open, Decor.override (which a
-- release never sets) dresses the card, and BondTrack.override shows the level.
local Decor = ns.Decor

-- Our own particles first in their slots.
local OWN = {
    glow = { "dot" }, sparkle = { "sparkle", "dot" }, star = { "star" }, heart = { "heart" }, bubble = { "bubble" },
    confetti = { "confetti" }, moon = { "moon" }, leaf = { "leaf" }, paw = { "paw" }, note = { "note" },
    snow = { "snowflake" },
}

-- The slots, in the gallery's order.
Decor.SLOTS = { "corner", "border", "frame", "glow", "sparkle", "star", "heart", "bubble", "confetti", "ribbon", "moon",
    "leaf", "paw", "note", "snow" }

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
        for _, name in ipairs(OWN[slot] or {}) do Add(self.MEDIA .. name, slot) end
        for _, p in ipairs(PATHS[slot] or {}) do Add(I .. p, slot) end
        for _, a in ipairs(ATLASES[slot] or {}) do Add("atlas:" .. a, slot) end
        for _, a in ipairs(generated[slot] or {}) do Add("atlas:" .. a, slot) end
    end
    return list
end

-- Does the client have it?
function Decor.Exists(path)
    -- Our own files: always there (and an addon file has no file id).
    if path:sub(1, #Decor.MEDIA) == Decor.MEDIA then return true end
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
    ns.Print(("%d of %d decoration pictures exist; the gallery shows them."):format(#have, #list))
    ns.SceneGallery:Show(have, "decor")
end

-- /dp probe frames: a border per family. While the gallery is open the
-- card wears the family whose slot is chosen, and its pick (Decor.show).
function Decor:ProbeFrames()
    local have = {}
    for i, c in ipairs(self:Candidates()) do
        if c.slot == "border" and Decor.Exists(c.path) then
            have[#have + 1] = { n = i, path = c.path, slot = c.slot }
        end
    end
    ns.Print(("%d borders exist. Pick one per family; the card shows it while the gallery is open.")
        :format(#have))
    ns.SceneGallery:Show(have, "frames")
end

-- The galleries' preview (2026-11-09): while /dp probe decor or frames is
-- open, Decor.show = { slot, family, art }: the card wears the chosen slot
-- (the art under the mouse, else the pick), dressed at a level where that
-- slot shows; a particle slot shows a few of its particles.
Decor.show = nil
Decor.NEED = { border = 2, corner = 3, glow = 4, cornerGold = 5, ribbon = 6 } -- the level a slot first shows at

local OVERRIDE = {}

-- The picture for a slot: the preview's, the family's, the slot's, else nil
-- (a particle's own texture). The galleries' picks (DyreparkenDB.decorPicks)
-- count only while a gallery is open: once written into the code, an old
-- pick left in SavedVariables mustn't hide what the code says.
function OVERRIDE.Art(slot, family)
    local s, picks = Decor.show, ns.DB.global.decorPicks
    if s and s.art and s.slot == slot and (not s.family or s.family == family) then return s.art end
    local own = family and Decor.FAMILY_ART[family]
    return s and family and picks[slot .. "." .. family] or own and own[slot] or s and picks[slot] or Decor.ART[slot]
end

-- The level the card is dressed at: the preview's, raised to where the gallery's slot shows.
function OVERRIDE.Level(level)
    level = Decor.preview or level or 0
    local need = Decor.show and Decor.NEED[Decor.show.slot]
    if need and level < need then level = need end
    return level
end

function OVERRIDE.Family() return Decor.show and Decor.show.family end
function OVERRIDE.Demo() return Decor.show and Decor.SLOT_KIND[Decor.show.slot] end

-- The bond bar (BondTrack:Update) at the previewed level: its name, and points within it. Quiet:
-- no gains and no celebration.
local function TrackLevel(points, level, name, from, nextAt)
    level = Decor.preview
    name, from = ns.Bond.LEVELS[level][2], ns.Bond.LEVELS[level][1]
    nextAt = ns.Bond.LEVELS[level + 1] and ns.Bond.LEVELS[level + 1][1]
    points = math.max(points, from)
    if nextAt then points = math.min(points, nextAt - 1) end -- within the level shown
    return points, level, name, from, nextAt, true
end

-- After Decor.show or Decor.preview changed.
function Decor:SyncOverride()
    self.override = (self.show or self.preview) and OVERRIDE or nil
    ns.BondTrack.override = self.preview and TrackLevel or nil
end

-- A gallery's slot chosen (SceneGallery), or nil when it closes.
function Decor:SetShow(show)
    self.show = show
    self:SyncOverride()
end

-- /dp probe level <1-7>: show the card dressed as that bond level, for any
-- pet, until /dp probe level off (development).
function Decor:Preview(arg)
    local n = tonumber(arg)
    if n and n >= 1 and n <= #ns.Bond.LEVELS then
        self.preview = math.floor(n)
        ns.Print(("The card shows level %d (%s). /dp probe level off to stop."):format(self.preview,
            ns.Bond.LEVELS[self.preview][2]))
    else
        self.preview = nil
        ns.Print("The card shows the real level again.")
    end
    self:SyncOverride()
    ns.JournalUI:Refresh()
end
