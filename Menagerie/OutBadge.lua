local _, ns = ...

-- "Med deg" (2026-11-09): which pet auto-summon keeps out, as a round paw
-- badge at the top right of the pet's box. It replaced a plain "Hold ute"
-- tickbox at the window's bottom edge, too anonymous for the choice the bond
-- system turns on. Active: a gold ring and paw, breathing softly, "Med deg".
-- Not: dim and grey, "Ta med ut". A click toggles it (Summon:SetActive),
-- with a small burst when a pet comes along. Hidden for a pet you don't own;
-- greyed while AutoCompanion does the summoning.
local OutBadge = {}
ns.OutBadge = OutBadge

local SIZE = 40
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
OutBadge.SOUNDS = { "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_CHARACTER_INFO_TAB" }

local function Tip(self)
    local card = self.card
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    if ns.Summon:Deferring() then
        GameTooltip:SetText(ns.L["card.auto.deferred"], 1, 1, 1, 1, true)
    else
        local pet = card.key and ns.Registry:NameOf(card.key) or ""
        GameTooltip:SetText(self.on and ns.T("card.out.on.title", { pet = pet })
            or ns.T("card.out.off.title", { pet = pet }), 1, 0.82, 0)
        GameTooltip:AddLine(ns.T("card.auto.tip", { pet = pet }), 1, 1, 1, true)
        local active = ns.Summon:ActiveKey()
        if active and active ~= card.key then
            GameTooltip:AddLine(ns.T("card.auto.now", { pet = ns.Registry:NameOf(active) }), 0.7, 0.7, 0.7, true)
        end
        GameTooltip:AddLine(self.on and ns.L["card.out.on.click"] or ns.T("card.out.off.click", { pet = pet }), 0.5, 0.8, 0.5, true)
    end
    GameTooltip:Show()
end

function OutBadge:Build(card, c)
    local b = CreateFrame("Button", nil, c)
    b.card = card
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -12)
    b:SetFrameLevel(c:GetFrameLevel() + 30) -- over the model and the decor's corners
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(MEDIA .. "dot")
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(1, 0.75, 0.3, 1)
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(SIZE * 1.9, SIZE * 1.9)
    b.glow.pulse = ns.Anim.Pulse(b.glow, 0.35, 0.8, 2.6)
    b.bg = b:CreateTexture(nil, "BORDER")
    b.bg:SetTexture(MEDIA .. "dot")
    b.bg:SetVertexColor(0, 0, 0, 0.75)
    b.bg:SetPoint("CENTER")
    b.bg:SetSize(SIZE - 4, SIZE - 4)
    b.ring = b:CreateTexture(nil, "ARTWORK")
    b.ring:SetAtlas("communities-ring-gold")
    b.ring:SetAllPoints()
    b.paw = b:CreateTexture(nil, "OVERLAY")
    b.paw:SetTexture(MEDIA .. "paw")
    b.paw:SetPoint("CENTER")
    b.paw:SetSize(SIZE * 0.55, SIZE * 0.55)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.label:SetShadowOffset(1, -1)
    -- A burst when a pet comes along: a ring growing out of the badge.
    b.burst = b:CreateTexture(nil, "OVERLAY")
    b.burst:SetTexture(MEDIA .. "ring")
    b.burst:SetBlendMode("ADD")
    b.burst:SetVertexColor(1, 0.85, 0.4, 1)
    b.burst:SetPoint("CENTER")
    b.burst:SetSize(SIZE, SIZE)
    b.burst:Hide()
    local g = ns.Anim.OneShot(b.burst)
    ns.Anim.Fade(g, 1, 0, 0.6, 1)
    ns.Anim.Scale(g, 1, 2.2, 0.6, 1, "OUT")
    b.burst.anim = g

    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function(self)
        if not card.key then return end
        local on = not self.on
        ns.Summon:SetActive(card.key, on)
        if on then
            self.burst:Show(); self.burst.anim:Play()
            ns.PlayFirstSound(OutBadge.SOUNDS)
        end
        ns.JournalUI:Refresh()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", ns.HideTip)
    b:Hide()
    card.auto = b
end

-- The pet on the card: is it the one kept out?
function OutBadge:Update(card, key)
    local b = card.auto
    if not b then return end
    if not (key and ns.Pets:IsOwned(key)) then
        b.on = false
        b.glow.pulse:Stop(); b:Hide()
        return
    end
    local deferring = ns.Summon:Deferring()
    local on = not deferring and ns.Summon:ActiveKey() == key
    b.on = on
    b:SetEnabled(not deferring)
    b.ring:SetDesaturated(not on)
    b.ring:SetAlpha(on and 1 or 0.6)
    if on then b.paw:SetVertexColor(1, 0.82, 0.3, 1) else b.paw:SetVertexColor(0.6, 0.6, 0.6, 0.8) end
    b.label:SetText(on and ns.L["card.out.on"] or ns.L["card.out.off"])
    if on then b.label:SetTextColor(1, 0.82, 0) else b.label:SetTextColor(0.6, 0.6, 0.6) end
    b.glow:SetShown(on)
    if on then b.glow.pulse:Play() else b.glow.pulse:Stop() end
    b:Show()
end
