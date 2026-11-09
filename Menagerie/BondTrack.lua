local _, ns = ...

-- The bond on the pet card (2026-11-08): the part of the card people look at
-- to see how far they've come, so it should feel like progress.
--   a MEDALLION with the level, rising out of the panel: the picked gold ring,
--     tinted like the card (family color, silver from 3, gold from 5), and
--     glowing from 5;
--   a TRACK of seven stars, one per level: reached ones gold, the current one
--     pulsing, the rest dark; hover one for what it brings;
--   a BAR to the next level, its fill tinted the same, a spark at its tip.
-- And a CELEBRATION when your own pet has reached a level you haven't seen
-- on its card yet: a flash of light, a burst of sparks and hearts, the
-- level's name rising over the pet, a sound. Seen levels are kept per pet
-- (char.bondSeen), so it happens once, the next time you look.
local Track = {}
ns.BondTrack = Track

local WHITE = "Interface\\Buttons\\WHITE8X8"
local DISC = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local RING = "communities-ring-gold"
local GOLD, SILVER = { 1, 0.8, 0.25 }, { 0.82, 0.88, 1 }
local BAR_W, PIP, PIP_GAP = 128, 14, 5
-- The level-up sound: the first of these the client knows.
Track.SOUNDS = { "UI_70_ARTIFACT_FORGE_TRAIT_GOLD_TRAIT", "UI_EPICLOOT_TOAST", "LEVELUPSOUND" }

-- The tier color for a level: the family's (2 and below), silver (3-4), gold (5+).
function Track.Tier(level, family)
    if level >= 5 then return GOLD end
    if level >= 3 then return SILVER end
    return family or GOLD
end

local Pulse, Hide = ns.Anim.Pulse, ns.HideTip

-- The bond's tooltip (the bar and the medallion).
local function BondTip(self, card)
    local points, level, name, _, nextAt = ns.Bond:Of(card.key)
    if not points then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(ns.T("bond.tip.title", { level = name, n = level }), 1, 0.82, 0)
    if nextAt then
        local nextName = ns.Bond.LEVELS[level + 1][2]
        GameTooltip:AddLine(ns.T("bond.tip.to_next", { n = nextAt - points, level = nextName }), 1, 1, 1)
        local decor = ns.Decor.LEVELS[level + 1]
        if decor then
            GameTooltip:AddLine(ns.T("bond.tip.next_decor", { n = level + 1, decor = decor }), 0.5, 0.8, 0.5, true)
        end
    else
        GameTooltip:AddLine(ns.L["bond.tip.top"], 1, 1, 1)
    end
    if ns.Registry:MyPet() == card.key then
        local today, max = ns.Bond:Today()
        if today >= max then
            GameTooltip:AddLine(ns.T("bond.tip.today_full", { max = max }), 0.4, 1, 0.4, true)
        else
            GameTooltip:AddLine(ns.T("bond.tip.today", { n = today, max = max }), 0.5, 0.8, 1, true)
        end
    end
    GameTooltip:AddLine(ns.L["bond.tip.how"], 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end

-- A star on the track: what level n is and brings, and whether it's reached.
local function PipTip(self, card)
    local n = self.n
    local l = ns.Bond.LEVELS[n]
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(ns.T("bond.star.title", { n = n, level = l[2] }), 1, 0.82, 0)
    GameTooltip:AddLine(n == 1 and ns.L["bond.star.first"] or ns.T("bond.star.from", { n = l[1] }), 1, 1, 1)
    if ns.Decor.LEVELS[n] then
        GameTooltip:AddLine(ns.T("bond.star.decor", { decor = ns.Decor.LEVELS[n] }), 0.5, 0.8, 0.5, true)
    end
    if n == ns.Config.NICKNAME_LEVEL then GameTooltip:AddLine(ns.L["bond.star.nick"], 0.5, 0.8, 0.5, true) end
    local _, level = ns.Bond:Of(card.key)
    if level and n <= level then GameTooltip:AddLine(ns.L["bond.star.reached"], 0.4, 1, 0.4) end
    GameTooltip:Show()
end

-- Build it on the card's panel (JournalUI's BuildCard). card.bond is the bar;
-- everything else hangs on it, so showing or hiding the bar does all.
function Track:Build(card, c, panel)
    local b = CreateFrame("StatusBar", nil, panel)
    card.bond = b
    -- The column, top to bottom: the level's name, the stars, the bar with
    -- the points on it, what's next. The medallion stands to its right.
    b:SetSize(BAR_W, 13)
    b:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -72, -48)
    b:SetStatusBarTexture(WHITE)
    b.bg = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 0.6)
    b.edge = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.edge:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
    b.edge:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
    b.edge:SetColorTexture(1, 0.82, 0, 0.35)
    -- Today's points, lit up on the bar (your own pet).
    b.today = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.today:SetColorTexture(1, 1, 1, 1)
    b.today:SetBlendMode("ADD")
    b.today:SetVertexColor(1, 1, 0.8, 0.35)
    b.today:Hide()
    b.spark = b:CreateTexture(nil, "OVERLAY")
    b.spark:SetTexture(ns.Decor.MEDIA .. "sparkle")
    b.spark:SetBlendMode("ADD")
    b.spark:SetSize(20, 20)
    b.spark:SetPoint("CENTER", b:GetStatusBarTexture(), "RIGHT", 0, 0)
    -- The points, on the bar only while you hover it (on all the time, it
    -- was noise: seen 2026-11-08).
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:Hide()
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -72, -8)
    b.label:SetJustifyH("RIGHT")
    b.next = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    b.next:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -4)
    b.next:SetJustifyH("RIGHT")

    -- The medallion, rising out of the panel's top right.
    local m = CreateFrame("Frame", nil, b)
    m:SetSize(56, 56)
    m:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, 18)
    m:SetFrameLevel(panel:GetFrameLevel() + 3)
    m.glow = m:CreateTexture(nil, "BACKGROUND")
    m.glow:SetTexture(ns.Decor.MEDIA .. "dot")
    m.glow:SetBlendMode("ADD")
    m.glow:SetPoint("CENTER")
    m.glow:SetSize(110, 110)
    m.glow:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    m.glow.pulse = Pulse(m.glow, 0.5, 1, 3)
    m.disc = m:CreateTexture(nil, "BORDER")
    m.disc:SetTexture(DISC)
    m.disc:SetPoint("CENTER")
    m.disc:SetSize(44, 44)
    m.ring = m:CreateTexture(nil, "ARTWORK")
    m.ring:SetAtlas(RING)
    m.ring:SetAllPoints()
    m.num = m:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    m.num:SetPoint("CENTER", m, "CENTER", 0, 1)
    m:EnableMouse(true)
    m:SetScript("OnEnter", function(self) BondTip(self, card) end)
    m:SetScript("OnLeave", Hide)
    b.medal = m
    b.level = m.num -- (the level number, as before)

    -- The track: seven stars between the label and the bar.
    b.pips = {}
    local n = #ns.Bond.LEVELS
    for i = 1, n do
        local p = CreateFrame("Frame", nil, b)
        p:SetSize(PIP, PIP)
        p:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -72 - (n - i) * (PIP + PIP_GAP), -27)
        p.n = i
        p.star = p:CreateTexture(nil, "ARTWORK")
        p.star:SetTexture(ns.Decor.MEDIA .. "star")
        p.star:SetAllPoints()
        p.halo = p:CreateTexture(nil, "BACKGROUND")
        p.halo:SetTexture(ns.Decor.MEDIA .. "dot")
        p.halo:SetBlendMode("ADD")
        p.halo:SetPoint("CENTER")
        p.halo:SetSize(PIP * 2.6, PIP * 2.6)
        p.halo:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
        p.halo.pulse = Pulse(p.halo, 0.3, 1, 1.6)
        p:EnableMouse(true)
        p:SetScript("OnEnter", function(self) PipTip(self, card) end)
        p:SetScript("OnLeave", Hide)
        b.pips[i] = p
    end
    b:EnableMouse(true)
    b:SetScript("OnEnter", function(self) self.text:Show(); BondTip(self, card) end)
    b:SetScript("OnLeave", function(self) self.text:Hide(); Hide(self) end)
    self:BuildCelebration(card, c, panel)
    c:HookScript("OnHide", function() Track:Pause(card) end)
    b:Hide()
end

-- The track's own pulses stopped (the card hidden or covered); Update starts them again.
function Track:Pause(card)
    local b = card.bond
    if not b then return end
    b.medal.glow.pulse:Stop()
    for _, p in ipairs(b.pips) do p.halo.pulse:Stop() end
end

-- Show the holder's bond with the pet (none: hidden). family: its tint.
function Track:Update(card, key, family)
    local b = card.bond
    local points, level, name, from, nextAt = ns.Bond:Of(key)
    if not points then
        b:Hide()
        return
    end
    if ns.Decor.preview then -- /dp probe level: that level, its name and its points
        level = ns.Decor.preview
        name, from = ns.Bond.LEVELS[level][2], ns.Bond.LEVELS[level][1]
        nextAt = ns.Bond.LEVELS[level + 1] and ns.Bond.LEVELS[level + 1][1]
        points = math.max(points, from)
        if nextAt then points = math.min(points, nextAt - 1) end -- within the level shown
    end
    local tier = self.Tier(level, family)
    b.label:SetText(name) -- the number is on the medallion
    b.level:SetText(level)
    -- The bar: from the tier's dark to its bright, a spark at the tip.
    b:SetMinMaxValues(from, nextAt or math.max(points, 1))
    b:SetValue(nextAt and points or math.max(points, 1)) -- the top level: full
    local fill = b:GetStatusBarTexture()
    fill:SetGradient("HORIZONTAL", CreateColor(tier[1] * 0.55, tier[2] * 0.55, tier[3] * 0.55, 1),
        CreateColor(math.min(1, tier[1] * 1.15), math.min(1, tier[2] * 1.15), math.min(1, tier[3] * 1.15), 1))
    -- Your own pet: what today brought, and whether the day is full.
    local mine = ns.Registry:MyPet() == key and not ns.Decor.preview
    local today, max = 0, 0
    if mine then today, max = ns.Bond:Today() end
    local full = mine and today >= max
    b.spark:SetShown(nextAt ~= nil and points > from and not full)
    local top = nextAt or math.max(points, 1)
    local span = math.max(1, top - from)
    local lo = math.max(0, math.min(1, (points - today - from) / span))
    local hi = math.max(0, math.min(1, (points - from) / span))
    if mine and today > 0 and hi > lo then
        b.today:ClearAllPoints()
        b.today:SetPoint("TOPLEFT", b, "TOPLEFT", BAR_W * lo, 0)
        b.today:SetSize(BAR_W * (hi - lo), b:GetHeight() or 13)
        b.today:Show()
    else
        b.today:Hide()
    end
    local vars = { have = points, need = nextAt, today = today }
    if nextAt then
        b.text:SetText(ns.T(mine and today > 0 and "bond.bar.today" or "bond.bar", vars))
    else
        b.text:SetText(ns.T(mine and today > 0 and "bond.bar.top_today" or "bond.bar.top", vars))
    end
    if full then
        b.next:SetText(ns.T("bond.full.line", { icon = "|TInterface\\RaidFrame\\ReadyCheck-Ready:12|t" }))
        b.next:SetTextColor(0.4, 1, 0.4)
        b.edge:SetColorTexture(0.4, 1, 0.4, 0.6)
    else
        b.next:SetText(nextAt and ns.T("bond.next", { n = nextAt - points, level = ns.Bond.LEVELS[level + 1][2] })
            or ns.L["bond.top"])
        b.next:SetTextColor(0.6, 0.6, 0.6)
        b.edge:SetColorTexture(1, 0.82, 0, 0.35)
    end
    -- The medallion: the ring greyed and tinted below gold, its disc dark in the tier.
    local m = b.medal
    m.ring:SetDesaturated(level < 5)
    if level >= 5 then m.ring:SetVertexColor(1, 1, 1, 1) else m.ring:SetVertexColor(tier[1], tier[2], tier[3], 1) end
    m.disc:SetVertexColor(tier[1] * 0.25, tier[2] * 0.25, tier[3] * 0.25, 0.95)
    m.num:SetTextColor(math.min(1, tier[1] * 1.2), math.min(1, tier[2] * 1.2), math.min(1, tier[3] * 1.2))
    m.glow:SetShown(level >= 5)
    if level >= 5 then m.glow.pulse:Play() else m.glow.pulse:Stop() end
    -- The track.
    for i, p in ipairs(b.pips) do
        if i < level then
            p.star:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
            p.star:SetDesaturated(false)
            p.halo:Hide(); p.halo.pulse:Stop()
        elseif i == level then
            p.star:SetVertexColor(1, 1, 0.85, 1)
            p.halo:Show(); p.halo.pulse:Play()
        else
            p.star:SetVertexColor(0.3, 0.3, 0.3, 0.7)
            p.halo:Hide(); p.halo.pulse:Stop()
        end
    end
    b:Show()
    -- Your own pet, at a level you haven't seen on its card: celebrate, but
    -- only where it can be seen; otherwise it waits for the next real look.
    if ns.Registry:MyPet() == key and not ns.Decor.preview and card.panel:IsVisible() then
        local seen = ns.DB.char.bondSeen
        if seen[key] == nil then
            seen[key] = level -- the first look: nothing to celebrate yet
        elseif level > seen[key] then
            seen[key] = level
            self:Celebrate(card, key, level)
        end
    end
end

------------------------------------------------------------------------------
-- The celebration
------------------------------------------------------------------------------
local BURST = 16

local OneShot = ns.Anim.OneShot

function Track:BuildCelebration(card, c, panel)
    local cel = { parts = {} }
    card.celebration = cel
    -- A flash of the light rays, turning as it fades.
    cel.flash = c:CreateTexture(nil, "BORDER", nil, 7)
    cel.flash:SetTexture(ns.Decor.MEDIA .. "rays")
    cel.flash:SetBlendMode("ADD")
    cel.flash:SetSize(560, 560)
    cel.flash:SetPoint("CENTER", panel, "TOP", 0, 140)
    cel.flash:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1)
    cel.flash:SetAlpha(0)
    cel.flash:Hide()
    local g = OneShot(cel.flash)
    local inA = g:CreateAnimation("Alpha"); inA:SetFromAlpha(0); inA:SetToAlpha(1); inA:SetDuration(0.25); inA:SetOrder(1)
    local inR = g:CreateAnimation("Rotation"); inR:SetDegrees(-15); inR:SetDuration(0.25); inR:SetOrder(1)
    local out = g:CreateAnimation("Alpha"); out:SetFromAlpha(1); out:SetToAlpha(0); out:SetDuration(1.8); out:SetOrder(2)
    local outR = g:CreateAnimation("Rotation"); outR:SetDegrees(-60); outR:SetDuration(1.8); outR:SetOrder(2)
    cel.flash.anim = g
    -- A burst of sparks and hearts out from the pet.
    for i = 1, BURST do
        local p = CreateFrame("Frame", nil, c)
        p:SetFrameLevel(c:GetFrameLevel())
        p:SetSize(20, 20)
        p:SetPoint("CENTER", panel, "TOP", 0, 100)
        p:SetAlpha(0)
        p:Hide()
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        local a = OneShot(p)
        a.move = a:CreateAnimation("Translation"); a.move:SetDuration(1.3); a.move:SetSmoothing("OUT"); a.move:SetOrder(1)
        local f1 = a:CreateAnimation("Alpha"); f1:SetFromAlpha(0); f1:SetToAlpha(1); f1:SetDuration(0.12); f1:SetOrder(1)
        local f2 = a:CreateAnimation("Alpha"); f2:SetFromAlpha(1); f2:SetToAlpha(0); f2:SetDuration(0.7); f2:SetOrder(2)
        local s2 = a:CreateAnimation("Scale"); s2:SetScaleFrom(1, 1); s2:SetScaleTo(0.4, 0.4); s2:SetDuration(0.7)
        s2:SetOrder(2); s2:SetOrigin("CENTER", 0, 0)
        p.anim = a
        cel.parts[i] = p
    end
    -- The level's name, rising and growing over the pet, then fading.
    local t = CreateFrame("Frame", nil, c)
    t:SetFrameLevel(c:GetFrameLevel() + 20) -- over the pet
    t:SetSize(300, 70)
    t:SetPoint("CENTER", panel, "TOP", 0, 200)
    t:SetAlpha(0)
    t:Hide()
    t.title = t:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    t.title:SetPoint("TOP", t, "TOP", 0, 0)
    t.sub = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t.sub:SetPoint("TOP", t.title, "BOTTOM", 0, -6)
    t.sub:SetWidth(300)
    local a = OneShot(t)
    local in1 = a:CreateAnimation("Alpha"); in1:SetFromAlpha(0); in1:SetToAlpha(1); in1:SetDuration(0.35); in1:SetOrder(1)
    local grow = a:CreateAnimation("Scale"); grow:SetScaleFrom(0.5, 0.5); grow:SetScaleTo(1, 1); grow:SetDuration(0.35)
    grow:SetSmoothing("OUT"); grow:SetOrder(1); grow:SetOrigin("CENTER", 0, 0)
    local rise = a:CreateAnimation("Translation"); rise:SetOffset(0, 18); rise:SetDuration(2.6); rise:SetOrder(2)
    local hold = a:CreateAnimation("Alpha"); hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(2.6); hold:SetOrder(2)
    local fade = a:CreateAnimation("Alpha"); fade:SetFromAlpha(1); fade:SetToAlpha(0); fade:SetDuration(0.8); fade:SetOrder(3)
    t.anim = a
    cel.text = t
    c:HookScript("OnHide", function() Track:StopCelebration(card) end)
end

function Track:StopCelebration(card)
    local cel = card.celebration
    if not cel then return end
    cel.flash.anim:Stop(); cel.flash:Hide()
    cel.text.anim:Stop(); cel.text:Hide()
    for _, p in ipairs(cel.parts) do p.anim:Stop(); p:Hide() end
end

-- The moment: light, a burst, the level's name, what it brings, a sound.
function Track:Celebrate(card, key, level)
    local cel = card.celebration
    if not cel then return end
    self:StopCelebration(card)
    cel.flash:Show(); cel.flash.anim:Play()
    for i, p in ipairs(cel.parts) do
        local heart = i % 3 == 0
        p.icon:SetTexture(ns.Decor.MEDIA .. (heart and "heart" or "sparkle"))
        if heart then p.icon:SetVertexColor(1, 0.45, 0.55, 1) else p.icon:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 1) end
        local angle = (i - 1) / BURST * 2 * math.pi
        local dist = 110 + (i % 4) * 22
        p.anim.move:SetOffset(math.cos(angle) * dist, math.sin(angle) * dist * 0.8)
        p:Show(); p.anim:Play()
    end
    local name = ns.Bond.LEVELS[level][2]
    cel.text.title:SetText(ns.T("bond.celebrate.title", { level = name }))
    local decor = ns.Decor.LEVELS[level]
    cel.text.sub:SetText(ns.T("bond.celebrate.text", { pet = ns.Bonds:NameOf(key), n = level })
        .. (decor and ("\n" .. ns.T("bond.celebrate.decor", { decor = decor })) or ""))
    cel.text:Show(); cel.text.anim:Play()
    for _, s in ipairs(self.SOUNDS) do
        local id = SOUNDKIT and SOUNDKIT[s]
        if id then
            PlaySound(id)
            ns.Log("Bond", "celebration sound %s", s)
            break
        end
    end
    ns.Log("Bond", "celebrated %s level %d", key, level)
end

-- /dp probe celebrate: the celebration on the card as it is (development).
function Track:Preview()
    local card = ns.JournalUI._card
    if not (card and card.key and card.celebration) then
        return ns.Print("Open the pet card first.")
    end
    local _, level = ns.Bond:Of(card.key)
    self:Celebrate(card, card.key, ns.Decor.preview or level or 1)
end
