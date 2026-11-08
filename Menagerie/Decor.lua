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
    ns.Print(("%d av %d pynt-bilder finnes; galleriet viser dem."):format(#have, #list))
    ns.SceneGallery:Show(have, "decor")
end

------------------------------------------------------------------------------
-- On the card (2026-11-08). Two sources of decoration, both behind the pet
-- (textures on the card itself, which the model's frame draws over):
--   the BOND LEVEL of the pet's holder: every level adds something, so a
--     pet that has been loved long looks it, to everyone;
--   the pet's TRAITS (and the date): small particles, e.g. bubbles for a
--     Dykker, stars for a Nattugle at night, confetti on a holiday.
-- Moving parts are animation groups: the client plays them, no OnUpdate.
-- They run only while the card shows something; Apply(card, nil) and the
-- card's OnHide stop them all. A pool of particles is made once.
------------------------------------------------------------------------------
local POOL = 16
local GOLD = { 1, 0.82, 0.3 }
Decor.ART = { -- the picks from the gallery (2026-11-08)
    corner = "Interface\\DialogFrame\\UI-DialogBox-Gold-Corner",
    ribbon = "atlas:UI-Frame-Venthyr-Ribbon",
    crown = "atlas:titleprestige-starcrown",
}

-- What each level adds, for the bond's tooltip ("på nivå 3: ...").
Decor.LEVELS = {
    [2] = "en kant i familiens farge",
    [3] = "gullhjørner",
    [4] = "en glød under kjæledyret",
    [5] = "glitter som stiger",
    [6] = "et bånd med navnet på nivået",
    [7] = "en krone, hjerter og en gullkant som gløder",
}

-- Particles per trait: { texture, motion, count, color }. "when" limits it
-- to a moment (Personality's own rules: night, holidays, weekends).
local function Night(t) local h = tonumber(date("%H", t)); return h >= 20 or h < 5 end
local function Holiday(t) return ns.Personality.HOLIDAYS[date("%m%d", t)] ~= nil end
local function Weekend(t) local w = tonumber(date("%w", t)); return w == 0 or w == 6 end
Decor.TRAITS = {
    nattugle = { tex = "star", motion = "twinkle", n = 4, color = { 0.85, 0.9, 1 }, when = Night },
    festglad = { tex = "confetti", motion = "fall", n = 8, color = "rainbow", when = Holiday },
    helgedyr = { tex = "note", motion = "rise", n = 3, color = { 1, 0.9, 0.6 }, when = Weekend },
    dansefot = { tex = "note", motion = "rise", n = 3, color = { 1, 0.85, 0.95 } },
    kosete = { tex = "heart", motion = "rise", n = 2, color = { 1, 0.45, 0.55 } },
    kjaelen = { tex = "heart", motion = "rise", n = 2, color = { 1, 0.55, 0.7 } },
    dykker = { tex = "bubble", motion = "rise", n = 4, color = { 0.7, 0.9, 1 } },
    vannhund = { tex = "bubble", motion = "rise", n = 3, color = { 0.6, 0.85, 1 } },
    gronnfinger = { tex = "leaf", motion = "fall", n = 3, color = { 0.55, 0.85, 0.4 } },
    oppdager = { tex = "paw", motion = "floor", n = 3, color = { 0.9, 0.8, 0.65 } },
    hoppetass = { tex = "paw", motion = "floor", n = 3, color = { 0.9, 0.8, 0.65 } },
}
-- Every pet, in December: a little snow.
local function December(t) return date("%m", t) == "12" end
local RAINBOW = { { 1, 0.35, 0.35 }, { 1, 0.8, 0.25 }, { 0.4, 0.85, 0.4 }, { 0.35, 0.65, 1 }, { 0.85, 0.45, 1 } }

local function SetArt(tex, path)
    local atlas = path:match("^atlas:(.+)$")
    if atlas then tex:SetAtlas(atlas) else tex:SetTexture(path) end
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

-- Build the textures once (JournalUI's BuildCard): c = the card frame, panel
-- = its bottom panel (particles live above it).
function Decor:Build(card, c, panel)
    local d = { c = c, panel = panel, parts = {} }
    card.decor = d
    -- Level 2 and 7: a thin border, in the family's color (gold at 7).
    d.edges = {}
    for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = c:CreateTexture(nil, "BORDER", nil, 2)
        t:SetColorTexture(1, 1, 1, 1)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT", c, side .. "LEFT", 4, side == "TOP" and -4 or 4)
            t:SetPoint(side .. "RIGHT", c, side .. "RIGHT", -4, side == "TOP" and -4 or 4)
            t:SetHeight(2)
        else
            t:SetPoint("TOP" .. side, c, "TOP" .. side, side == "LEFT" and 4 or -4, -4)
            t:SetPoint("BOTTOM" .. side, c, "BOTTOM" .. side, side == "LEFT" and 4 or -4, 4)
            t:SetWidth(2)
        end
        t:Hide()
        -- Level 7: the gold edge glows.
        t.shimmer = t:CreateAnimationGroup()
        t.shimmer:SetLooping("BOUNCE")
        local s = t.shimmer:CreateAnimation("Alpha")
        s:SetFromAlpha(0.45); s:SetToAlpha(1); s:SetDuration(1.8); s:SetSmoothing("IN_OUT")
        d.edges[i] = t
    end
    -- Level 3: gold corners (the picked piece is a top left; the rest mirror it).
    d.corners = {}
    local FLIP = { TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 }, BOTTOMLEFT = { 0, 1, 1, 0 },
        BOTTOMRIGHT = { 1, 0, 1, 0 } }
    for point, tc in pairs(FLIP) do
        local t = c:CreateTexture(nil, "BORDER", nil, 3)
        SetArt(t, self.ART.corner)
        t:SetTexCoord(unpack(tc))
        t:SetSize(32, 32)
        local x = point:find("LEFT") and 4 or -4
        local y = point:find("TOP") and -4 or 4
        t:SetPoint(point, c, point, x, y)
        t:Hide()
        d.corners[point] = t
    end
    -- Level 4: a soft glow under the pet, breathing.
    d.glow = c:CreateTexture(nil, "BORDER", nil, 1)
    d.glow:SetTexture(self.MEDIA .. "dot")
    d.glow:SetBlendMode("ADD")
    d.glow:SetSize(300, 140)
    d.glow:SetPoint("CENTER", panel, "TOP", 0, 110)
    d.glow:Hide()
    d.breathe = d.glow:CreateAnimationGroup()
    d.breathe:SetLooping("BOUNCE")
    local a = d.breathe:CreateAnimation("Alpha")
    a:SetFromAlpha(0.35); a:SetToAlpha(0.7); a:SetDuration(2.5); a:SetSmoothing("IN_OUT")
    -- Level 6: a ribbon at the top with the level's name; 7: a crown on it.
    d.ribbon = c:CreateTexture(nil, "BORDER", nil, 4)
    SetArt(d.ribbon, self.ART.ribbon)
    d.ribbon:SetSize(220, 44)
    d.ribbon:SetPoint("TOP", c, "TOP", 0, -52)
    d.ribbon:Hide()
    d.ribbonText = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d.ribbonText:SetPoint("CENTER", d.ribbon, "CENTER", 0, 2)
    d.ribbonText:Hide()
    d.crown = c:CreateTexture(nil, "BORDER", nil, 5)
    SetArt(d.crown, self.ART.crown)
    d.crown:SetSize(56, 36)
    d.crown:SetPoint("BOTTOM", d.ribbon, "TOP", 0, -10)
    d.crown:Hide()
    -- The particle pool: each with its own animation (move, fade, grow).
    for i = 1, POOL do
        local t = c:CreateTexture(nil, "BORDER", nil, 6)
        t:Hide()
        local g = t:CreateAnimationGroup()
        g:SetLooping("REPEAT")
        -- One timeline (all order 1): wait, then move while fading in and
        -- out. At rest a particle is invisible (alpha 0), so it never sits
        -- still and visible while it waits for its turn.
        g.move = g:CreateAnimation("Translation")
        g.fadeIn = g:CreateAnimation("Alpha")
        g.fadeIn:SetFromAlpha(0); g.fadeIn:SetToAlpha(1)
        g.fadeOut = g:CreateAnimation("Alpha")
        g.fadeOut:SetFromAlpha(1); g.fadeOut:SetToAlpha(0)
        for _, a in ipairs({ g.move, g.fadeIn, g.fadeOut }) do a:SetOrder(1) end
        t:SetAlpha(0)
        t.anim = g
        d.parts[i] = t
    end
    c:HookScript("OnHide", function() Decor:Stop(card) end)
end

function Decor:Stop(card)
    local d = card.decor
    if not d then return end
    for _, t in ipairs(d.parts) do t.anim:Stop(); t:Hide() end
    d.breathe:Stop()
    for _, e in ipairs(d.edges) do e.shimmer:Stop() end
end

-- One particle: where it starts and how it moves. (x, y) from the panel's
-- top left; the area is the card above the panel.
local function Launch(t, spec, rng, i, n, panel)
    local width = panel:GetWidth() or 400
    local tex = spec.tex
    t:SetTexture(Decor.MEDIA .. tex)
    local c = spec.color
    if c == "rainbow" then c = RAINBOW[(i - 1) % #RAINBOW + 1] end
    t:SetVertexColor(c[1], c[2], c[3], 1)
    local size = rng(14, 24)
    if tex == "bubble" then size = rng(10, 20) end
    t:SetSize(size, size)
    local g = t.anim
    local x = width * (i - 0.5) / n + rng(-20, 20)
    local y, dx, dy, dur
    if spec.motion == "rise" then
        y, dx, dy, dur = rng(10, 60), rng(-20, 20), rng(140, 220), rng(5, 8)
    elseif spec.motion == "fall" then
        y, dx, dy, dur = rng(260, 320), rng(-30, 30), -rng(180, 240), rng(6, 9)
    elseif spec.motion == "twinkle" then
        y, dx, dy, dur = rng(200, 320), 0, 0, rng(1.5, 3)
    else -- floor: paw prints along the ground
        x, y, dx, dy, dur = width * 0.25 + (i - 1) * 34, rng(16, 30), 0, 0, 3
        t:SetRotation(-0.4)
    end
    t:ClearAllPoints()
    t:SetPoint("CENTER", panel, "TOPLEFT", x, y)
    g.move:SetOffset(dx, dy)
    local wait = (i - 1) * dur / n -- staggered, so they don't all go at once
    g.move:SetStartDelay(wait); g.move:SetDuration(dur)
    g.fadeIn:SetStartDelay(wait); g.fadeIn:SetDuration(dur * 0.3)
    g.fadeOut:SetStartDelay(wait + dur * 0.6); g.fadeOut:SetDuration(dur * 0.4)
    t:Show()
    g:Play()
end

-- The particle specs for a pet right now: its traits', December's snow,
-- and the bond's sparkles (5+) and hearts (7).
function Decor:Specs(key, level, t)
    local list = {}
    for _, trait in ipairs(ns.Personality:Traits(key)) do
        local spec = self.TRAITS[trait.id]
        if spec and (not spec.when or spec.when(t)) then list[#list + 1] = spec end
    end
    if December(t) then list[#list + 1] = { tex = "snowflake", motion = "fall", n = 4, color = { 1, 1, 1 } } end
    if level >= 5 then list[#list + 1] = { tex = "sparkle", motion = "rise", n = 4, color = GOLD } end
    if level >= 7 then list[#list + 1] = { tex = "heart", motion = "rise", n = 3, color = { 1, 0.4, 0.5 } } end
    return list
end

-- Show the decorations for a pet (nil: none). level: its holder's bond
-- level (nil when nobody holds it); color: the family's tint.
function Decor:Apply(card, key, level, color)
    local d = card.decor
    if not d then return end
    self:Stop(card)
    for _, e in ipairs(d.edges) do e:Hide() end
    for _, t in pairs(d.corners) do t:Hide() end
    d.glow:Hide(); d.ribbon:Hide(); d.ribbonText:Hide(); d.crown:Hide()
    d.used = 0
    if not key then return end
    level = self.preview or level or 0
    if level >= 2 then
        local c = level >= 7 and GOLD or color or GOLD
        for _, e in ipairs(d.edges) do
            e:SetVertexColor(math.min(1, c[1] * 1.6), math.min(1, c[2] * 1.6), math.min(1, c[3] * 1.6), 0.8)
            e:Show()
        end
    end
    if level >= 3 then for _, t in pairs(d.corners) do t:Show() end end
    if level >= 4 then
        local c = color or GOLD
        d.glow:SetVertexColor(math.min(1, c[1] * 1.8), math.min(1, c[2] * 1.8), math.min(1, c[3] * 1.8), 1)
        d.glow:Show()
        d.breathe:Play()
    end
    if level >= 6 then
        d.ribbonText:SetText(ns.Bond.LEVELS[level][2])
        d.ribbon:Show(); d.ribbonText:Show()
    end
    if level >= 7 then d.crown:Show() end
    if level >= 7 then for _, e in ipairs(d.edges) do e.shimmer:Play() end end
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
        ns.Print(("Kortet vises som nivå %d (%s). /dp probe level off for å avslutte."):format(self.preview,
            ns.Bond.LEVELS[self.preview][2]))
    else
        self.preview = nil
        ns.Print("Kortet viser det virkelige nivået igjen.")
    end
    ns.JournalUI:Refresh()
end
