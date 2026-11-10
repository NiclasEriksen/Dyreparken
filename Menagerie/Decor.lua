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
    "leaf", "paw", "note", "snow" }

-- Our own particles (Media/Particles, drawn by tools/draw_particles.py):
-- white with soft edges, to tint and animate. Shown first in their slots.
Decor.MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
local OWN = {
    glow = { "dot" }, sparkle = { "sparkle", "dot" }, star = { "star" }, heart = { "heart" }, bubble = { "bubble" },
    confetti = { "confetti" }, moon = { "moon" }, leaf = { "leaf" }, paw = { "paw" }, note = { "note" },
    snow = { "snowflake" },
}

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

------------------------------------------------------------------------------
-- On the card (2026-11-08). Two sources of decoration, both behind the pet
-- (textures on the card itself, which the model's frame draws over):
--   the BOND LEVEL of the pet's holder: every level adds something you can
--     see from across the room, so a pet that has been loved long looks it;
--   the pet's TRAITS (and the date): particles, each kind with its own
--     motion: leaves sway down, hearts throb, sparks fly, confetti spins...
--   the pet's FAMILY (2026-11-09): a soft ambience every card has, bond or
--     not (feathers, embers, gears, fireflies...), and a border of its own
--     (FAMILY_ART).
-- Moving parts are animation groups: the client plays them, no OnUpdate.
-- They run only while the card shows something; Apply(card, nil) and the
-- card's OnHide stop them all. A pool of particles is made once.
--
-- A particle is three layers, each with at most one group playing, since
-- two groups moving one region fight frame by frame instead of adding up
-- (hearts flickered, swaying leaves jumped: seen 2026-11-08):
--   the HOLDER frame: the path and the fades, a timeline in steps (orders),
--     never delays inside a step (a waiting Alpha animation applies its
--     start value, which left particles opaque and still):
--       1 wait, invisible   2 move and fade in   3 move on and fade out
--   an INNER frame: the sway (side to side);
--   the TEXTURE: one of spin, tilt (rock) or throb (beat).
-- Back-and-forth motions are never BOUNCE loops: those blinked where they
-- turned (hearts, notes, leaves, while REPEAT spins were smooth). They're
-- REPEAT loops of steps that end where they began: out, back past the
-- middle, home (Swing below).
------------------------------------------------------------------------------
local POOL = 32 -- a family, two traits, the date and the bond at once
local GOLD, SILVER = ns.Scenes.GOLD, ns.Scenes.SILVER
Decor.ART = { -- the picks from the gallery (2026-11-08, second round)
    border = "loottoast-itemborder-gold", -- an item frame, nine-sliced around the card
    -- Corners for every pet (decided 2026-11-09): wood from level 3, the
    -- parchment filigree once the card turns gold (5).
    corner = "Interface\\AchievementFrame\\UI-Achievement-WoodBorder-Corner",
    cornerGold = "parchmentpopup-filigree",
    ribbon = "UI-Frame-Neutral-Ribbon",
    glow = Decor.MEDIA .. "dot",
}

-- What each level adds, for the bond's tooltip ("på nivå 3: ...").
Decor.LEVELS = {}
for n = 2, 7 do Decor.LEVELS[n] = ns.L["decor.level." .. n] end


-- Kinds of particles: the texture, the path, the extra motions, and sizes.
--   path: rise, fall, burst (flies out from the pet), twinkle (in place),
--   steps (paw prints along the ground), drift (wanders a little, slowly),
--   wind (blows across the card, left to right)
--   motions (one of spin, tilt, throb, flap: they share the texture); sway
--   x = "pet": starts around the pet, not spread across the card; y: where
--   it starts (from the panel's top); dist: how far it rises or falls;
--   grow: its scale at the end; add: drawn as light (embers, fireflies)
Decor.KINDS = {
    heart = { tex = "heart", path = "rise", throb = true, size = { 16, 24 }, dur = { 5, 7 } },
    bubble = { tex = "bubble", path = "rise", sway = 8, size = { 10, 20 }, dur = { 5, 8 } },
    leaf = { tex = "leaf", path = "fall", sway = 26, tilt = 35, size = { 14, 22 }, dur = { 7, 10 } },
    confetti = { tex = "confetti", path = "fall", sway = 14, spin = 1.2, size = { 8, 12 }, dur = { 4, 6 } },
    snow = { tex = "snowflake", path = "fall", sway = 12, spin = 6, size = { 10, 16 }, dur = { 9, 12 } },
    note = { tex = "note", path = "rise", sway = 16, tilt = 20, size = { 16, 22 }, dur = { 5, 7 } },
    spark = { tex = "sparkle", path = "burst", spin = 1.5, size = { 12, 22 }, dur = { 1.4, 2.2 } },
    star = { tex = "star", path = "twinkle", spin = 8, size = { 10, 18 }, dur = { 2, 3.5 } },
    paw = { tex = "paw", path = "steps", size = { 16, 18 }, dur = { 4, 4 } },
    -- The families' ambience (2026-11-09).
    feather = { tex = "feather", path = "fall", sway = 30, tilt = 40, size = { 14, 20 }, dur = { 8, 11 } },
    ember = { tex = "ember", path = "rise", sway = 10, throb = 1.2, period = 0.6, add = true, size = { 8, 14 }, dur = { 4, 6 } },
    gear = { tex = "gear", path = "drift", spin = 9, size = { 14, 22 }, dur = { 6, 9 } },
    mote = { tex = "dot", path = "drift", add = true, size = { 6, 12 }, dur = { 6, 9 } },
    firefly = { tex = "dot", path = "drift", throb = 1.5, period = 1.6, add = true, size = { 8, 12 }, dur = { 5, 8 } },
    wisp = { tex = "wisp", path = "drift", sway = 14, add = true, size = { 18, 26 }, dur = { 6, 9 } },
    coin = { tex = "coin", path = "twinkle", y = { 20, 90 }, flap = 0.2, grow = 1, size = { 12, 16 }, dur = { 3, 5 } },
    grain = { tex = "grain", path = "fall", sway = 20, tilt = 30, size = { 16, 22 }, dur = { 8, 11 } },
    seed = { tex = "seed", path = "fall", spin = 3, size = { 8, 12 }, dur = { 6, 8 } },
    clover = { tex = "clover", path = "fall", sway = 22, tilt = 30, size = { 12, 18 }, dur = { 8, 10 } },
    sand = { tex = "dot", path = "wind", size = { 3, 6 }, dur = { 5, 7 } },
    mist = { tex = "mist", path = "wind", y = { 10, 80 }, size = { 60, 90 }, dur = { 12, 16 } },
    lights = { tex = "dot", path = "twinkle", add = true, size = { 8, 12 }, dur = { 2, 4 } },
    -- The rest of the traits (2026-11-09).
    crumb = { tex = "crumb", path = "fall", x = "pet", y = { 80, 130 }, dist = { 60, 90 }, spin = 2.5, size = { 6, 10 },
        dur = { 2.5, 3.5 } },
    sword = { tex = "sword", path = "burst", size = { 14, 20 }, dur = { 1.6, 2.2 } },
    cloud = { tex = "cloud", path = "wind", y = { 220, 320 }, size = { 40, 60 }, dur = { 14, 18 } },
    bolt = { tex = "bolt", path = "burst", tilt = 20, size = { 12, 18 }, dur = { 1.2, 1.8 } },
    pebble = { tex = "pebble", path = "fall", y = { 40, 80 }, dist = { 30, 60 }, tilt = 25, size = { 10, 16 },
        dur = { 3, 4 } },
    halo = { tex = "halo", path = "twinkle", x = "pet", spread = 0, y = { 215, 215 }, grow = 1.08, add = true,
        size = { 60, 60 }, dur = { 4, 4 } },
    hearth = { tex = "sparkle", path = "rise", sway = 10, add = true, size = { 8, 12 }, dur = { 6, 8 } },
    chevron = { tex = "chevron", path = "rise", x = "pet", y = { 60, 100 }, dist = { 120, 160 }, size = { 14, 18 },
        dur = { 3, 4 } },
    zee = { tex = "zee", path = "rise", x = "pet", y = { 150, 180 }, dist = { 80, 110 }, grow = 1.8, tilt = 15,
        size = { 12, 18 }, dur = { 4, 5 } },
    speech = { tex = "speech", path = "twinkle", x = "pet", y = { 150, 230 }, grow = 1, throb = 1.15,
        size = { 18, 24 }, dur = { 2.5, 3.5 } },
    flock = { tex = "dot", path = "drift", x = "pet", y = { 60, 200 }, add = true, size = { 8, 12 }, dur = { 5, 7 } },
    drop = { tex = "drop", path = "fall", dist = { 220, 280 }, size = { 8, 12 }, dur = { 2.5, 3.5 } },
    butterfly = { tex = "butterfly", path = "drift", flap = 0.35, sway = 20, size = { 14, 20 }, dur = { 7, 10 } },
}

-- Particles per trait: { kind, how many, color, alpha }. "when" limits it to
-- a day (Personality's own rules: holidays, weekends). A trait with a
-- moment of its own (Nattugle, Flokkdyr, Huleboer...) shows exactly then:
-- its own rule (Personality's when, on Bond.Context).
local function Holiday(t) return ns.Personality.Holiday(t) ~= nil end
local function Weekend(t) return ns.Personality.IsWeekend(t) end
Decor.TRAITS = {
    nattugle = { kind = "star", n = 5, color = { 0.85, 0.9, 1 } },
    festglad = { kind = "confetti", n = 10, color = "rainbow", when = Holiday },
    helgedyr = { kind = "note", n = 3, color = { 1, 0.9, 0.6 }, when = Weekend },
    dansefot = { kind = "note", n = 3, color = { 1, 0.8, 0.95 } },
    kosete = { kind = "heart", n = 2, color = { 1, 0.45, 0.55 } },
    kjaelen = { kind = "heart", n = 2, color = { 1, 0.55, 0.7 } },
    dykker = { kind = "bubble", n = 4, color = { 0.7, 0.9, 1 } },
    vannhund = { kind = "bubble", n = 3, color = { 0.6, 0.85, 1 } },
    gronnfinger = { kind = "leaf", n = 3, color = { 0.55, 0.85, 0.4 } },
    oppdager = { kind = "paw", n = 4, color = { 0.9, 0.8, 0.65 } },
    hoppetass = { kind = "paw", n = 4, color = { 0.9, 0.8, 0.65 } },
    glupsk = { kind = "crumb", n = 3, color = { 0.85, 0.65, 0.4 } },
    eventyrlysten = { kind = "sword", n = 3, color = { 1, 0.45, 0.35 } },
    reiseglad = { kind = "cloud", n = 2, color = { 1, 1, 1 }, alpha = 0.6 },
    rampete = { kind = "bolt", n = 3, color = { 1, 0.9, 0.3 } },
    steinhard = { kind = "pebble", n = 3, color = { 0.7, 0.68, 0.65 } },
    trofast = { kind = "halo", n = 1, color = { 1, 0.9, 0.55 }, alpha = 0.8 },
    hjemlengsel = { kind = "hearth", n = 4, color = { 0.45, 0.75, 1 } },
    ambisios = { kind = "chevron", n = 3, color = { 0.5, 1, 0.5 }, alpha = 0.8 },
    latsabb = { kind = "zee", n = 3, color = { 0.8, 0.85, 1 } },
    pratsom = { kind = "speech", n = 2, color = { 1, 1, 1 }, alpha = 0.85 },
    flokkdyr = { kind = "flock", n = 5, color = { 1, 0.85, 0.4 } },
    einstoing = { kind = "wisp", n = 1, color = { 0.8, 0.75, 1 } },
    huleboer = { kind = "drop", n = 3, color = { 0.6, 0.75, 0.9 } },
    friluftsdyr = { kind = "butterfly", n = 2, color = { 1, 0.75, 0.4 } },
}

-- Every pet's family (Scenes:Families, the first one; else default) has an
-- ambience of its own, always, softer than the traits' (decided 2026-11-09).
Decor.FAMILY = {
    bird = { kind = "feather", n = 3, color = { 0.95, 0.95, 1 } },
    owl = { kind = "feather", n = 3, color = { 0.75, 0.65, 0.55 } },
    cat = { kind = "mote", n = 6, color = { 1, 0.85, 0.55 } },
    farm = { kind = "grain", n = 3, color = { 0.95, 0.8, 0.4 } },
    rabbit = { kind = "clover", n = 3, color = { 0.5, 0.85, 0.45 } },
    frog = { kind = "firefly", n = 5, color = { 0.75, 1, 0.4 } },
    snake = { kind = "sand", n = 8, color = { 0.95, 0.8, 0.5 } },
    mechanical = { kind = "gear", n = 3, color = { 0.75, 0.8, 0.85 } },
    dragon = { kind = "ember", n = 6, color = { 1, 0.55, 0.15 } },
    pirate = { kind = "coin", n = 3, color = { 1, 0.82, 0.3 } },
    bug = { kind = "firefly", n = 5, color = { 1, 0.9, 0.35 } },
    rodent = { kind = "seed", n = 3, color = { 0.8, 0.65, 0.45 } },
    wolf = { kind = "mist", n = 3, color = { 0.8, 0.85, 0.95 }, alpha = 0.35 },
    plant = { kind = "mote", n = 6, color = { 0.85, 1, 0.45 } },
    festive = { kind = "lights", n = 6, color = "rainbow" },
    demon = { kind = "ember", n = 6, color = { 0.5, 1, 0.2 } },
    ooze = { kind = "bubble", n = 4, color = { 0.55, 1, 0.35 } },
    spirit = { kind = "wisp", n = 4, color = { 0.7, 0.75, 1 } },
    default = { kind = "mote", n = 5, color = { 1, 0.9, 0.7 } },
}
Decor.FAMILY_ALPHA = 0.7 -- the ambience stays behind the traits
for _, spec in pairs(Decor.FAMILY) do spec.alpha = spec.alpha or Decor.FAMILY_ALPHA end
local RAINBOW = { { 1, 0.35, 0.35 }, { 1, 0.8, 0.25 }, { 0.4, 0.85, 0.4 }, { 0.35, 0.65, 1 }, { 0.85, 0.45, 1 } }
local FLAG = { { 0.85, 0.15, 0.2 }, { 1, 1, 1 }, { 0.15, 0.3, 0.75 } } -- 17. mai

-- The date's particles, every card (2026-11-10): a few days of the year, and
-- the seasons as the faintest touch (`season`: one particle, half seen,
-- drawn last so a full card drops it first; the user: "veeery sparingly",
-- the regular particles should easily overtake them). { when = fn(t), spec };
-- a palette color (a list of colors) goes round.
local function Month(...)
    local set = {}
    for _, m in ipairs({ ... }) do set[m] = true end
    return function(t) return set[tonumber(date("%m", t))] == true end
end
local function Day(md) return function(t) return date("%m%d", t) == md end end
Decor.DATES = {
    { when = Month(12), spec = { kind = "snow", n = 5, color = { 1, 1, 1 } } },
    { when = Month(10, 11), season = true, spec = { kind = "leaf", n = 1, color = { 0.95, 0.55, 0.2 }, alpha = 0.4 } },
    { when = Month(4, 5), season = true, spec = { kind = "clover", n = 1, color = { 0.5, 0.85, 0.45 }, alpha = 0.4 } },
    { when = Month(6, 7, 8), season = true, spec = { kind = "butterfly", n = 1, color = { 1, 0.8, 0.5 }, alpha = 0.4 } },
    { when = Day("0517"), spec = { kind = "confetti", n = 9, color = FLAG } },
    { when = Day("0623"), spec = { kind = "ember", n = 6, color = { 1, 0.6, 0.2 } } }, -- sankthans
    { when = function(t) -- the turn of the year: ten minutes either side of midnight
        local md, hm = date("%m%d", t), tonumber(date("%H%M", t))
        return (md == "1231" and hm >= 2350) or (md == "0101" and hm < 10)
    end, spec = { kind = "spark", n = 8, color = "rainbow" } },
}

-- A trait's particles show twice as many on a day its liked activity
-- happened with this pet of yours out (2026-11-10): chevrons pour up on the
-- day you dinged together.
Decor.LIVELY = 2
local function Lively(trait, key)
    -- (only your own pet, with it out: the user, 2026-11-10)
    return trait.like ~= nil and ns.Pets:IsOwned(key) and ns.Activity:TodayWith(trait.like, key) > 0
end

-- An atlas, mirrored if asked: SetTexCoord would replace the atlas's own
-- coordinates, so the file and its coordinates are set by hand.
local function SetAtlasFlipped(tex, atlas, flipX, flipY)
    local info = C_Texture.GetAtlasInfo(atlas)
    if not (flipX or flipY) or not (info and info.file and info.leftTexCoord) then
        tex:SetAtlas(atlas)
        return
    end
    local l, r, t, b = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
    if flipX then l, r = r, l end
    if flipY then t, b = b, t end
    tex:SetTexture(info.file)
    tex:SetTexCoord(l, r, t, b)
end

-- A picture for a slot: an atlas ("atlas:<name>", or a bare name) or a
-- file path, mirrored if asked.
local function SetArt(tex, art, flipX, flipY)
    local atlas = art:match("^atlas:(.+)$") or (not art:find("\\", 1, true) and art)
    if atlas then return SetAtlasFlipped(tex, atlas, flipX, flipY) end
    tex:SetTexture(art)
    tex:SetTexCoord(flipX and 1 or 0, flipX and 0 or 1, flipY and 1 or 0, flipY and 0 or 1)
end

-- Per family, a border of its own (2026-11-09): picked in game with
-- /dp probe frames, then written here; a family without one has
-- Decor.ART's. "default" is for pets without a family. Atlases by name,
-- files by path. (Corners are the same for every pet: Decor.ART.)
Decor.FAMILY_ART = { -- picked in game 2026-11-09
    default = { border = "UI-Frame-GenericMetal-ExitButtonBorder" },
    cat = { border = "loottoast-itemborder-gold" },
    bird = { border = "loottoast-itemborder-gold" },
    owl = { border = "loottoast-itemborder-gold" },
    farm = { border = "loottoast-itemborder-gold" },
    pirate = { border = "loottoast-itemborder-gold" },
    mechanical = { border = "services-icon-goldborder" },
    dragon = { border = "UI-Frame-GenericMetal-ExitButtonBorder" },
    bug = { border = "services-icon-goldborder" },
}

-- The galleries' preview (2026-11-09): while /dp probe decor or frames is
-- open, Decor.show = { slot, family, art }: the card wears the chosen slot
-- (the art under the mouse, else the pick), dressed at a level where that
-- slot shows; a particle slot shows a few of its particles.
Decor.show = nil
Decor.NEED = { border = 2, corner = 3, glow = 4, cornerGold = 5, ribbon = 6 } -- the level a slot first shows at
Decor.SLOT_KIND = { sparkle = "spark", star = "star", heart = "heart", bubble = "bubble", confetti = "confetti",
    leaf = "leaf", paw = "paw", note = "note", snow = "snow" }
local KIND_SLOT = {}
for slot, kind in pairs(Decor.SLOT_KIND) do KIND_SLOT[kind] = slot end

-- The picture for a slot: the preview's, the family's, the slot's, else
-- nil (a particle's own texture). The galleries' picks (DyreparkenDB.
-- decorPicks) count only while a gallery is open: once written into the
-- code, an old pick left in SavedVariables mustn't hide what the code says.
function Decor:Art(slot, family)
    local s, picks = self.show, ns.DB.global.decorPicks
    if s and s.art and s.slot == slot and (not s.family or s.family == family) then return s.art end
    local own = family and self.FAMILY_ART[family]
    return s and family and picks[slot .. "." .. family] or own and own[slot] or s and picks[slot] or self.ART[slot]
end

-- A particle kind's picture.
function Decor:PartArt(kind)
    local slot = KIND_SLOT[kind]
    return slot and self:Art(slot) or self.MEDIA .. self.KINDS[kind].tex
end

-- A stable little random per pet, so its particles keep their places.
local function Rng(seed)
    local x = seed % 2147483647
    if x <= 0 then x = x + 2147483646 end
    return function(a, b)
        x = x * 16807 % 2147483647
        return a + (b - a) * (x / 2147483647)
    end
end

-- A looping group with one animation of a kind, origin in the middle.
local function Loop(t, kind, looping)
    local g = t:CreateAnimationGroup()
    g:SetLooping(looping)
    local a = g:CreateAnimation(kind)
    if a.SetOrigin and kind ~= "Translation" and kind ~= "Alpha" then a:SetOrigin("CENTER", 0, 0) end
    a:SetSmoothing("IN_OUT")
    g.a = g.a or a
    return g, a
end

local function Timeline(holder, grow)
    local g = holder:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    g.hold = g:CreateAnimation("Alpha"); g.hold:SetFromAlpha(0); g.hold:SetToAlpha(0); g.hold:SetOrder(1)
    g.moveA = g:CreateAnimation("Translation"); g.moveA:SetOrder(2)
    g.fadeIn = g:CreateAnimation("Alpha"); g.fadeIn:SetFromAlpha(0); g.fadeIn:SetToAlpha(1); g.fadeIn:SetOrder(2)
    g.moveB = g:CreateAnimation("Translation"); g.moveB:SetOrder(3)
    g.fadeOut = g:CreateAnimation("Alpha"); g.fadeOut:SetFromAlpha(1); g.fadeOut:SetToAlpha(0); g.fadeOut:SetOrder(3)
    if grow then g.grow = g:CreateAnimation("Scale"); g.grow:SetOrder(3); g.grow:SetOrigin("CENTER", 0, 0) end
    return g
end

-- A back-and-forth motion as a REPEAT loop of steps (see the header):
-- Translation and Rotation swing out, across and home like a pendulum;
-- Scale beats (up, back down, rest). Steps are relative, so they add up to
-- nothing over a loop and it never jumps.
local function Swing(region, kind)
    local g = region:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    g.kind = kind
    g.steps = {}
    for i = 1, 3 do
        local a = g:CreateAnimation(kind == "Scale" and (i == 3 and "Translation" or "Scale") or kind)
        a:SetOrder(i)
        if a.SetOrigin and kind ~= "Translation" and not (kind == "Scale" and i == 3) then a:SetOrigin("CENTER", 0, 0) end
        g.steps[i] = a
    end
    return g
end

-- Set a swing's size (pixels, degrees, or a scale factor) and one loop's length.
local function SetSwing(g, amount, period, across)
    local a1, a2, a3 = g.steps[1], g.steps[2], g.steps[3]
    if g.kind == "Scale" then -- a beat: up quickly, down, then a rest (a still step)
        local y = across and 1 or amount -- across: the width only
        a1:SetScale(amount, y); a1:SetDuration(period * 0.3); a1:SetSmoothing("OUT")
        a2:SetScale(1 / amount, 1 / y); a2:SetDuration(period * 0.4); a2:SetSmoothing("IN_OUT")
        a3:SetOffset(0, 0); a3:SetDuration(period * 0.3)
        return
    end
    -- A pendulum: fastest through the middle, still at the ends.
    local set = g.kind == "Rotation" and function(a, v) a:SetDegrees(v) end or function(a, v) a:SetOffset(v, 0) end
    set(a1, amount); a1:SetDuration(period / 4); a1:SetSmoothing("OUT")
    set(a2, -2 * amount); a2:SetDuration(period / 2); a2:SetSmoothing("IN_OUT")
    set(a3, amount); a3:SetDuration(period / 4); a3:SetSmoothing("IN")
end
Decor.SetSwing = SetSwing

local Pulse = ns.Anim.Pulse

local function NewParticle(c)
    local holder = CreateFrame("Frame", nil, c)
    holder:SetFrameLevel(c:GetFrameLevel()) -- under the model's frame: behind the pet
    holder:Hide()
    holder:SetAlpha(0) -- unseen at rest: only the timeline shows it
    holder.plain, holder.growing = Timeline(holder, false), Timeline(holder, true)
    holder.inner = CreateFrame("Frame", nil, holder)
    holder.inner:SetAllPoints()
    holder.icon = holder.inner:CreateTexture(nil, "ARTWORK")
    holder.icon:SetAllPoints()
    holder.sway = Swing(holder.inner, "Translation")
    holder.spin = Loop(holder.icon, "Rotation", "REPEAT")
    holder.tilt = Swing(holder.icon, "Rotation")
    holder.throb = Swing(holder.icon, "Scale")
    holder.groups = { holder.plain, holder.growing, holder.sway, holder.spin, holder.tilt, holder.throb }
    holder.anim = holder.plain
    return holder
end

-- Build the textures once (JournalUI's BuildCard): c = the card frame, panel
-- = its bottom panel (particles live above it).
function Decor:Build(card, c, panel)
    local d = { c = c, panel = panel, parts = {} }
    card.decor = d
    -- 2+: a border (family, then silver, then gold): the picked frame,
    -- nine-sliced around the card; drawn edges where the client can't slice.
    -- And a wash of color in from the edges.
    d.border = c:CreateTexture(nil, "BORDER", nil, 2)
    d.border:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
    d.border:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
    d.sliced = d.border.SetTextureSliceMargins ~= nil and Enum and Enum.UITextureSliceMode ~= nil
    if d.sliced then
        d.border:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
    end
    d.border:Hide()
    d.border.shimmer = Pulse(d.border, 0.55, 1, 3.2) -- 7: it glows
    d.edges, d.wash = {}, {}
    for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = c:CreateTexture(nil, "BORDER", nil, 2)
        t:SetColorTexture(1, 1, 1, 1)
        local w = c:CreateTexture(nil, "BACKGROUND", nil, 4)
        w:SetColorTexture(1, 1, 1, 1)
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and -4 or 4
            t:SetPoint(side .. "LEFT", c, side .. "LEFT", 4, y); t:SetPoint(side .. "RIGHT", c, side .. "RIGHT", -4, y)
            t:SetHeight(3)
            w:SetPoint(side .. "LEFT", c, side .. "LEFT", 4, y); w:SetPoint(side .. "RIGHT", c, side .. "RIGHT", -4, y)
            w:SetHeight(60)
        else
            local x = side == "LEFT" and 4 or -4
            t:SetPoint("TOP" .. side, c, "TOP" .. side, x, -4); t:SetPoint("BOTTOM" .. side, c, "BOTTOM" .. side, x, 4)
            t:SetWidth(3)
            w:SetPoint("TOP" .. side, c, "TOP" .. side, x, -4); w:SetPoint("BOTTOM" .. side, c, "BOTTOM" .. side, x, 4)
            w:SetWidth(60)
        end
        w.side = side
        t:Hide(); w:Hide()
        d.edges[i], d.wash[i] = t, w
    end
    -- 3+: corners (the picked piece is a top left; the rest mirror it).
    d.corners = {}
    for _, point in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
        local t = c:CreateTexture(nil, "BORDER", nil, 3)
        t:SetSize(48, 48)
        t:SetPoint(point, c, point, point:find("LEFT") and 2 or -2, point:find("TOP") and -2 or 2)
        t:Hide()
        d.corners[point] = t
    end
    -- 4+: a glow under the pet, breathing: a wide one and a bright core.
    d.glows = {}
    for i, size in ipairs({ { 420, 260 }, { 220, 110 } }) do
        local t = c:CreateTexture(nil, "BORDER", nil, i)
        t:SetBlendMode("ADD")
        t:SetSize(size[1], size[2])
        t:SetPoint("CENTER", panel, "TOP", 0, i == 1 and 120 or 90)
        t:Hide()
        t.breathe = Pulse(t, i == 1 and 0.55 or 0.7, 1, 4.4)
        d.glows[i] = t
    end
    -- 6+: light rays behind the pet, turning slowly.
    -- Over the glow, not under it: under, the glow drowned them (seen 2026-11-08).
    d.rays = c:CreateTexture(nil, "BORDER", nil, 3)
    d.rays:SetTexture(self.MEDIA .. "rays")
    d.rays:SetBlendMode("ADD")
    d.rays:SetSize(600, 600)
    d.rays:SetPoint("CENTER", panel, "TOP", 0, 150)
    d.rays:Hide()
    d.rays.turn = Loop(d.rays, "Rotation", "REPEAT")
    d.rays.turn.a:SetDegrees(-360); d.rays.turn.a:SetSmoothing("NONE")
    -- 6+: a ribbon with the level's name, under the title row.
    d.ribbon = c:CreateTexture(nil, "BORDER", nil, 4)
    d.ribbon:SetSize(250, 75)
    d.ribbon:SetPoint("TOP", c, "TOP", 0, -10) -- at the top: Blizzard's title row is hidden (JournalUI)
    d.ribbon:Hide()
    d.ribbonText = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d.ribbonText:SetPoint("CENTER", d.ribbon, "CENTER", 0, 2)
    d.ribbonText:Hide()
    for i = 1, POOL do d.parts[i] = NewParticle(c) end
    c:HookScript("OnHide", function() Decor:Stop(card) end)
end

function Decor:Stop(card)
    local d = card.decor
    if not d then return end
    d.playing = false
    for _, p in ipairs(d.parts) do
        for _, g in ipairs(p.groups) do g:Stop() end
        p:Hide()
    end
    for _, t in ipairs(d.glows) do t.breathe:Stop() end
    d.border.shimmer:Stop()
    d.rays.turn:Stop()
end

-- One particle: where it starts, its timeline and its extra motions.
-- (x, y) from the panel's top left; the area is the card above the panel.
local function Launch(p, spec, rng, i, n, panel)
    local k = Decor.KINDS[spec.kind]
    local width = panel:GetWidth() or 400
    local icon = p.icon
    SetArt(icon, Decor:PartArt(spec.kind))
    icon:SetBlendMode(k.add and "ADD" or "BLEND")
    local c = spec.color
    if c == "rainbow" then c = RAINBOW end
    if type(c[1]) == "table" then c = c[(i - 1) % #c + 1] end -- a palette
    icon:SetVertexColor(c[1], c[2], c[3], spec.alpha or 1)
    icon:SetRotation(0)
    local size = rng(k.size[1], k.size[2])
    p:SetSize(size, size)
    local dur = rng(k.dur[1], k.dur[2])
    local x, y, dx, dy = width * (i - 0.5) / n + rng(-20, 20), 0, 0, 0
    if k.x == "pet" then x = width / 2 + rng(-1, 1) * (k.spread or 50) end
    local function Y(a, b) return k.y and rng(k.y[1], k.y[2]) or rng(a, b) end
    local function Dist(a, b) return k.dist and rng(k.dist[1], k.dist[2]) or rng(a, b) end
    local grow = k.grow
    if k.path == "rise" then
        y, dx, dy = Y(10, 70), rng(-20, 20), Dist(150, 230)
    elseif k.path == "fall" then
        y, dx, dy = Y(270, 330), rng(-30, 30), -Dist(200, 260)
    elseif k.path == "burst" then -- out from around the pet, in every direction
        local a = rng(0, 2 * math.pi)
        x, y = width / 2 + rng(-30, 30), rng(70, 130)
        dx, dy, grow = math.cos(a) * rng(90, 150), math.sin(a) * rng(60, 120), grow or 0.3
    elseif k.path == "twinkle" then
        y, grow = Y(190, 320), grow or 1.6
    elseif k.path == "drift" then -- a slow wander, anywhere above the panel
        y, dx, dy = Y(40, 280), rng(-40, 40), rng(-25, 25)
    elseif k.path == "wind" then -- in from the left, across
        x, y, dx, dy = rng(0, width * 0.3), Y(30, 300), width * rng(0.5, 0.7), rng(-15, 15)
    else -- steps: paw prints, one after another, along the ground
        x, y = width * 0.22 + (i - 1) * 36, 20 + (i % 2) * 12
        icon:SetRotation(-0.3)
    end
    p:ClearAllPoints()
    p:SetPoint("CENTER", panel, "TOPLEFT", x, y)
    local g = grow and grow ~= 1 and p.growing or p.plain
    p.anim = g
    local wait = (i - 1) * dur / n + 0.01 -- staggered, so they don't all go at once
    g.hold:SetDuration(wait)
    local first = k.path == "burst" and 0.35 or 0.4
    g.moveA:SetOffset(dx * first, dy * first); g.moveA:SetDuration(dur * first)
    g.moveA:SetSmoothing(k.path == "burst" and "OUT" or "NONE")
    g.fadeIn:SetDuration(dur * (k.path == "burst" and 0.1 or 0.25))
    g.moveB:SetOffset(dx * (1 - first), dy * (1 - first)); g.moveB:SetDuration(dur * (1 - first))
    g.fadeOut:SetDuration(dur * (1 - first))
    if g.grow then g.grow:SetScaleFrom(1, 1); g.grow:SetScaleTo(grow, grow); g.grow:SetDuration(dur * (1 - first)) end
    p:Show()
    g:Play()
    -- Its own motions, alongside, each on its own layer.
    if k.sway then
        SetSwing(p.sway, rng(0.6, 1) * k.sway * (i % 2 == 0 and 1 or -1), rng(2.2, 3.6))
        p.sway:Play()
    end
    if k.spin then
        p.spin.a:SetDegrees((i % 2 == 0 and 360 or -360))
        p.spin.a:SetDuration(k.spin * rng(0.8, 1.3))
        p.spin.a:SetSmoothing("NONE")
        p.spin:Play()
    elseif k.tilt then
        SetSwing(p.tilt, k.tilt * (i % 2 == 0 and 1 or -1), rng(1.8, 2.8))
        p.tilt:Play()
    elseif k.throb or k.flap then -- a beat; a flap beats across only (wings, a turning coin)
        SetSwing(p.throb, k.flap or (k.throb == true and 1.25 or k.throb), k.period or (k.flap and 0.5 or 0.9),
            k.flap ~= nil)
        p.throb:Play()
    end
end

-- The particle specs for a pet right now: its traits', December's snow,
-- and the bond's sparks (5+) and hearts (7).
-- How many of the everyday particles (traits, the family's ambience, the
-- snow) show at a bond level (2026-11-09: a bit much at level 1): 70% at 1
-- and below, rising evenly to all of them at 7. The level's own rewards
-- (sparks, hearts) keep their counts.
Decor.DENSITY_LOW = 0.7
function Decor.Density(level)
    local f = Decor.DENSITY_LOW + (1 - Decor.DENSITY_LOW) * ((level or 1) - 1) / 6
    return math.max(Decor.DENSITY_LOW, math.min(1, f))
end

local function Thinned(spec, f)
    if not spec or f >= 1 then return spec end
    local copy = {}
    for k, v in pairs(spec) do copy[k] = v end
    copy.n = math.max(1, math.floor(spec.n * f + 0.5))
    return copy
end

function Decor:Specs(key, level, t)
    local list, ctx = {}, nil
    local f = self.Density(level)
    local demo = self.show and self.SLOT_KIND[self.show.slot] -- the gallery's particle slot
    if demo then list[1] = { kind = demo, n = 6, color = { 1, 1, 1 } } end
    -- (no trait particles for a pet whose personality is still a surprise)
    for _, trait in ipairs(ns.Personality:Known(key) and ns.Personality:Traits(key) or {}) do
        local spec = self.TRAITS[trait.id]
        local now = spec and (not spec.when or spec.when(t))
        if now and trait.when then
            if not ctx then ctx = ns.Bond.Context(); ctx.t = t end
            now = trait.when(ctx)
        end
        if now then
            local shown = Thinned(spec, f)
            if Lively(trait, key) then
                local more = {}
                for k, v in pairs(shown) do more[k] = v end -- (a copy: shown may be the trait's own)
                more.n = shown.n * self.LIVELY
                shown = more
            end
            list[#list + 1] = shown
        end
    end
    -- The park's birthday: confetti on every card.
    if ns.Bonds:ParkBirthday(t) then list[#list + 1] = { kind = "confetti", n = 8, color = "rainbow" } end
    -- Asleep on the card (Moves): a few Zzz, whatever its traits.
    if ns.Moves:Rest(key, t) == "sleep" then list[#list + 1] = { kind = "zee", n = 3, color = { 0.8, 0.85, 1 } } end
    for _, d in ipairs(self.DATES) do
        if not d.season and d.when(t) then list[#list + 1] = Thinned(d.spec, f) end
    end
    if level >= 5 then list[#list + 1] = { kind = "spark", n = 6, color = GOLD } end
    if level >= 7 then list[#list + 1] = { kind = "heart", n = 4, color = { 1, 0.4, 0.5 } } end
    -- Last: the pool may run out, and the ambience is what can go.
    local family = ns.Scenes:Families(key)[1]
    list[#list + 1] = Thinned(self.FAMILY[family] or self.FAMILY.default, f)
    for _, d in ipairs(self.DATES) do -- (the season: the very last, the first to go)
        if d.season and d.when(t) then list[#list + 1] = d.spec end
    end
    return list
end

local Bright = ns.Scenes.Bright

-- Show the decorations for a pet (nil: none). level: its holder's bond
-- level (nil when nobody holds it); color: the family's tint.
function Decor:Apply(card, key, level, color)
    local d = card.decor
    if not d then return end
    -- The same pet, level, tint and particles as now: leave them playing.
    -- (Every card refresh used to restart them all: guildmates' bond updates
    -- made the hearts and leaves blink out and fade back in.)
    level = self.preview or level or 0
    local need = self.show and self.NEED[self.show.slot]
    if need and level < need then level = need end
    local sig, art
    if key then
        local family = self.show and self.show.family or ns.Scenes:Families(key)[1] or "default"
        art = { self:Art("border", family), self:Art(level >= 5 and "cornerGold" or "corner", family), self:Art("glow"), self:Art("ribbon") }
        local parts = { key, level, color and table.concat(color, ",") or "", table.concat(art, ";") }
        for _, spec in ipairs(self:Specs(key, level, ns.Now())) do
            parts[#parts + 1] = spec.kind .. spec.n .. self:PartArt(spec.kind)
        end
        sig = table.concat(parts, ";")
        if sig == d.sig and d.playing then return end
    end
    self:Stop(card)
    d.sig, d.playing = sig, key ~= nil
    for i = 1, 4 do d.edges[i]:Hide(); d.wash[i]:Hide() end
    d.border:Hide()
    for _, t in pairs(d.corners) do t:Hide() end
    for _, t in ipairs(d.glows) do t:Hide() end
    d.rays:Hide(); d.ribbon:Hide(); d.ribbonText:Hide()
    d.used = 0
    if not key then return end
    local arts = table.concat(art, ";")
    if d.art ~= arts then -- the family's frame, the glow, the ribbon
        d.art = arts
        if d.sliced then
            SetArt(d.border, art[1])
            d.border:SetTextureSliceMargins(18, 18, 18, 18)
        end
        for point, t in pairs(d.corners) do SetArt(t, art[2], point:find("RIGHT") ~= nil, point:find("BOTTOM") ~= nil) end
        for _, t in ipairs(d.glows) do SetArt(t, art[3]) end
        SetArt(d.ribbon, art[4])
    end
    color = color or GOLD
    if level >= 2 then
        local e = ns.Scenes.Tier(level, Bright(color, 1.7)) -- (the border: 2 has the family's own)
        local wash = level >= 5 and GOLD or Bright(color, 1.7)
        if d.sliced then
            -- The frame is gold: grey it for the family color and silver.
            d.border:SetDesaturated(level < 5)
            local tint = level >= 5 and { 1, 1, 1 } or e
            d.border:SetVertexColor(tint[1], tint[2], tint[3], 1)
            d.border:Show()
        end
        for i = 1, 4 do
            d.edges[i]:SetVertexColor(e[1], e[2], e[3], 0.9)
            d.edges[i]:SetShown(not d.sliced)
            local w = d.wash[i]
            local strong, clear = { wash[1], wash[2], wash[3], level >= 5 and 0.12 or 0.16 }, { wash[1], wash[2], wash[3], 0 } -- the art shows through
            local function G(o, a, b)
                if w.SetGradient and CreateColor then w:SetGradient(o, CreateColor(unpack(a)), CreateColor(unpack(b))) end
            end
            if w.side == "TOP" then G("VERTICAL", clear, strong)
            elseif w.side == "BOTTOM" then G("VERTICAL", strong, clear)
            elseif w.side == "LEFT" then G("HORIZONTAL", strong, clear)
            else G("HORIZONTAL", clear, strong) end
            w:Show()
        end
    end
    if level >= 3 then
        local tint = level >= 5 and { 1, 0.85, 0.45 } or SILVER -- stone: gilded from 5
        for _, t in pairs(d.corners) do
            t:SetDesaturated(level < 5)
            t:SetVertexColor(tint[1], tint[2], tint[3], 1)
            t:Show()
        end
    end
    if level >= 4 then
        local g = level >= 5 and GOLD or Bright(color, 2.2)
        for _, t in ipairs(d.glows) do
            t:SetVertexColor(g[1], g[2], g[3], 1)
            t:Show()
            t.breathe:Play()
        end
    end
    if level >= 6 then
        d.ribbonText:SetText(ns.Bond.LEVELS[level][2])
        d.ribbon:Show(); d.ribbonText:Show()
        d.rays:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
        d.rays:SetAlpha(level >= 7 and 1 or 0.8)
        d.rays.turn.a:SetDuration(level >= 7 and 40 or 70)
        d.rays:Show()
        d.rays.turn:Play()
    end
    if level >= 7 then d.border.shimmer:Play() end
    -- Particles, up to the pool's size.
    local rng = Rng((ns.Pets:SpeciesOfKey(key) or 1) * 7919 + level)
    for _, spec in ipairs(self:Specs(key, level, ns.Now())) do
        for i = 1, spec.n do
            if d.used >= POOL then break end
            d.used = d.used + 1
            Launch(d.parts[d.used], spec, rng, i, spec.n, d.panel)
        end
    end
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
    ns.JournalUI:Refresh()
end
