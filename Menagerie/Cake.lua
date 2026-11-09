local _, ns = ...

-- The anniversary cake (2026-11-09, docs/IDEAS.md): on an adopted pet's
-- milestone day (1 month, 100 days, every year with its carer; the same
-- days as the milestone lines, Bonds:Milestone) a small cake sits at the
-- top left of its card, three candle flames flickering over it. Any adopted
-- pet's card, not only yours: the guild's celebrations show too. Hovering
-- it says which milestone. Only on the day itself; the flames play only
-- while it shows.
local Cake = {}
ns.Cake = Cake

local SIZE = 34
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
local FLAMES = { { -0.3, 1.1 }, { 0, 0.9 }, { 0.3, 1.3 } } -- candle x (as in tools/draw_particles.py), flicker period

local function Tip(self)
    local m = self.milestone
    if not m then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(ns.L["card.cake.title"], 1, 0.82, 0)
    GameTooltip:AddLine(m.owner == ns.PlayerKey() and ns.T("milestone.mine", { pet = m.pet, time = m.time })
        or ns.T("milestone.other", { owner = m.owner, pet = m.pet, time = m.time }), 1, 1, 1, true)
    GameTooltip:Show()
end

function Cake:Build(card, c)
    local f = CreateFrame("Frame", nil, c)
    f:SetSize(SIZE, SIZE)
    f:SetPoint("TOPLEFT", c, "TOPLEFT", 16, -14)
    f:SetFrameLevel(c:GetFrameLevel() + 30) -- over the model and the decor's corners, like the paw badge
    f.cake = f:CreateTexture(nil, "ARTWORK")
    f.cake:SetTexture(MEDIA .. "cake")
    f.cake:SetVertexColor(1, 0.8, 0.85, 1)
    f.cake:SetAllPoints()
    f.flames = {}
    for i, fl in ipairs(FLAMES) do
        local t = f:CreateTexture(nil, "OVERLAY")
        t:SetTexture(MEDIA .. "ember")
        t:SetBlendMode("ADD")
        t:SetVertexColor(1, 0.7, 0.25, 1)
        t:SetSize(9, 12)
        t:SetPoint("BOTTOM", f, "CENTER", fl[1] * SIZE / 2, SIZE * 0.27)
        t.flicker = ns.Anim.Pulse(t, 0.55, 1, fl[2])
        f.flames[i] = t
    end
    f:EnableMouse(true)
    f:SetScript("OnEnter", Tip)
    f:SetScript("OnLeave", ns.HideTip)
    -- The journal closing: no flames in the dark (shown again, the card redraws them).
    f:SetScript("OnHide", function(self) for _, t in ipairs(self.flames) do t.flicker:Stop() end end)
    f:Hide()
    card.cake = f
end

-- Its milestone today, if it has a home: { owner, pet, time }.
function Cake:Today(key, now)
    local owner, r = ns.Registry:Holder(key)
    local time = owner and ns.Bonds:Milestone(r.at, now)
    return time and { owner = owner, pet = ns.Registry:NameOf(key), time = time }
end

function Cake:Update(card, key)
    local f = card.cake
    if not f then return end
    local m = key and self:Today(key)
    f.milestone = m
    for _, t in ipairs(f.flames) do
        if m then t.flicker:Play() else t.flicker:Stop() end
    end
    f:SetShown(m ~= nil)
end
