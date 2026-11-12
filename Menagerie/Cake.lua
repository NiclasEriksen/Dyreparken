local _, ns = ...

-- The anniversary cake (2026-11-09, docs/IDEAS.md): on an adopted pet's
-- milestone day (1 month, 100 days, every year with its carer; the same
-- days as the milestone lines, Bonds:Milestone) a small cake sits at the
-- top left of its card, three candle flames flickering over it. Any adopted
-- pet's card, not only yours: the guild's celebrations show too. Hovering
-- it says which milestone. Only on the day itself; the flames play only
-- while it shows. A click on a guildmate's cake congratulates them in guild
-- chat (2026-11-10; the click is the hardware event Forever wants): once a
-- day per pet, and only with announcing on (/dp kunngjør).
local Cake = {}
ns.Cake = Cake

local SIZE = 34
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
local FLAMES = { { -0.3, 1.1 }, { 0, 0.9 }, { 0.3, 1.3 } } -- candle x (as in tools/draw_particles.py), flicker period

-- The cake's tooltip: whose milestone, and whether a click congratulates.
function Cake.Lines(key, m)
    if not m then return nil end
    local lines = {
        { ns.L["card.cake.title"], 1, 0.82, 0 },
        { m.owner == ns.PlayerKey() and ns.T("milestone.mine", { pet = m.pet, time = m.time })
            or ns.T("milestone.other", { owner = m.owner, pet = m.pet, time = m.time }), 1, 1, 1, true },
    }
    if Cake:CanCongratulate(key, m) then lines[3] = { ns.L["card.cake.click"], 0.5, 0.8, 0.5, true } end
    return lines
end

local function Said()
    local c = ns.DB.char.congratulated
    if not c or c.day ~= ns.Today() then
        c = { day = ns.Today(), pets = {} }
        ns.DB.char.congratulated = c
    end
    return c.pets
end

function Cake:CanCongratulate(key, m)
    return key and m and m.owner ~= ns.PlayerKey() and ns.DB.char.announce and IsInGuild() and not Said()[key]
end

-- From the click on the cake.
function Cake:Congratulate(card)
    local f, key = card.cake, card.key
    local m = f and f.milestone
    if not self:CanCongratulate(key, m) then return end
    Said()[key] = true
    SendChatMessage(ns.T("cake.congrats", { time = m.time, owner = m.owner, pet = m.pet }), "GUILD")
    GameTooltip:Hide()
end

function Cake:Build(card, c)
    local f = CreateFrame("Button", nil, c)
    f.card = card
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
    ns.SetTip(f, "ANCHOR_RIGHT", function(self) return Cake.Lines(card.key, self.milestone) end)
    f:SetScript("OnClick", function() Cake:Congratulate(card) end)
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

ns.Card.Register{ id = "cake",
    build = function(card, c) Cake:Build(card, c) end,
    update = function(card, key) Cake:Update(card, key) end,
    pause = function(card) Cake:Update(card, nil) end, -- (over the model's level: it'd show through our page)
    -- The journal closing: no flames in the dark (shown again, the card redraws them).
    stop = function(card)
        for _, t in ipairs(card.cake and card.cake.flames or {}) do t.flicker:Stop() end
    end,
}
