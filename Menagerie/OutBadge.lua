local _, ns = ...

-- "Med deg" (2026-11-09): which pet auto-summon keeps out, as a round paw
-- badge at the top right of the pet's box. It replaced a plain "Hold ute"
-- tickbox at the window's bottom edge, too anonymous for the choice the bond
-- system turns on. Active: a gold ring and paw, breathing softly, "Med deg".
-- Not: dim and grey, "Ta med ut". A click toggles it (Summon:SetActive),
-- with a small burst when a pet comes along. For a pet you don't own (seen
-- from Parken, Dagens dyr), a dim "Ikke samlet" in its place (2026-11-09:
-- nothing said whose pet you were looking at); greyed while AutoCompanion
-- does the summoning.
local OutBadge = {}
ns.OutBadge = OutBadge

local SIZE = 40
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
OutBadge.SOUNDS = { "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_CHARACTER_INFO_TAB" }

-- The badge's tooltip for the pet on the card: on (kept out), or not owned.
function OutBadge.Lines(key, on, notOwned)
    if notOwned then
        return { { ns.L["card.notowned"], 0.8, 0.8, 0.8 },
            { ns.T("card.notowned.tip", { pet = key and ns.Pets:NameOfKey(key) or "" }), 1, 1, 1, true } }
    elseif ns.Summon:Deferring() then
        return { { ns.L["card.auto.deferred"], 1, 1, 1, true } }
    end
    local pet = key and ns.Registry:NameOf(key) or ""
    local lines = {
        { on and ns.T("card.out.on.title", { pet = pet }) or ns.T("card.out.off.title", { pet = pet }), 1, 0.82, 0 },
        { ns.T("card.auto.tip", { pet = pet }), 1, 1, 1, true },
    }
    local active = ns.Summon:ActiveKey()
    if active and active ~= key then
        lines[#lines + 1] = { ns.T("card.auto.now", { pet = ns.Registry:NameOf(active) }), 0.7, 0.7, 0.7, true }
    end
    lines[#lines + 1] = { on and ns.L["card.out.on.click"] or ns.T("card.out.off.click", { pet = pet }), 0.5, 0.8, 0.5, true }
    return lines
end

local function Tip(self) ns.ShowTip(self, "ANCHOR_LEFT", OutBadge.Lines(self.card.key, self.on, self.notOwned)) end

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
        if not card.key or self.notOwned then return end
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
    b.on = false
    b.glow.pulse:Stop()
    if not key then return b:Hide() end
    b.notOwned = not ns.Pets:IsOwned(key)
    if b.notOwned then
        b:SetEnabled(false)
        b.ring:SetDesaturated(true); b.ring:SetAlpha(0.35)
        b.paw:SetVertexColor(0.45, 0.45, 0.45, 0.5)
        b.label:SetText(ns.L["card.notowned"]); b.label:SetTextColor(0.55, 0.55, 0.55)
        b.glow:Hide()
        return b:Show()
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

ns.Card.Register{ id = "outbadge",
    build = function(card, c) OutBadge:Build(card, c) end,
    update = function(card, key) OutBadge:Update(card, key) end,
    pause = function(card) OutBadge:Update(card, nil) end, -- (over the model's level: it'd show through our page)
    stop = function(card) if card.auto then card.auto.glow.pulse:Stop() end end, -- (Update starts it again)
}
