local _, ns = ...

-- Pet it on the card (2026-11-08): a click on the pet (not a drag, which
-- turns the model) answers quietly where you clicked: a ripple, a few small
-- hearts rising, and a warm glow flaring under the pet; a soft sound. No
-- text (a speech bubble read badly, the user decided). Once a day it's a
-- cuddle for the bond too (the activity "cuddle", as /pet would be), when
-- the card shows your adopted pet and it's out.
local Cuddle = {}
ns.Cuddle = Cuddle

local HEARTS = 4
local CLICK_PX, CLICK_S = 5, 0.4 -- a click: moved less than this, shorter than this
-- The sound: the first of these the client knows.
Cuddle.SOUNDS = { "IG_CHARACTER_INFO_TAB", "IG_MAINMENU_OPTION_CHECKBOX_ON" }

local OneShot = ns.Anim.OneShot

local function Fade(g, from, to, dur, order)
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(dur); a:SetOrder(order)
    return a
end

-- A frame over the pet, unseen at rest, holding one texture.
local function Piece(c, level, size, texture)
    local p = CreateFrame("Frame", nil, c)
    p:SetFrameLevel(c:GetFrameLevel() + level)
    p:SetSize(size, size)
    p:SetAlpha(0)
    p:Hide()
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    p.icon:SetTexture(ns.Decor.MEDIA .. texture)
    return p
end

function Cuddle:Build(card, c, panel)
    local d = { hearts = {}, c = c, panel = panel }
    card.cuddle = d
    -- The ripple: a ring growing and fading where you clicked.
    d.ripple = Piece(c, 20, 24, "ring")
    d.ripple.icon:SetVertexColor(1, 0.85, 0.75, 1)
    d.ripple.icon:SetBlendMode("ADD")
    local r = OneShot(d.ripple)
    Fade(r, 0, 0.9, 0.08, 1)
    local grow = r:CreateAnimation("Scale")
    grow:SetScaleFrom(1, 1); grow:SetScaleTo(3, 3); grow:SetDuration(0.6); grow:SetSmoothing("OUT")
    grow:SetOrigin("CENTER", 0, 0); grow:SetOrder(2)
    Fade(r, 0.9, 0, 0.6, 2)
    d.ripple.anim = r
    -- A few small hearts rising from the same spot.
    for i = 1, HEARTS do
        local p = Piece(c, 20, 12, "heart")
        p.icon:SetVertexColor(1, 0.5, 0.6, 0.85)
        local a = OneShot(p)
        a.move = a:CreateAnimation("Translation"); a.move:SetDuration(0.8); a.move:SetSmoothing("OUT"); a.move:SetOrder(1)
        Fade(a, 0, 1, 0.12, 1)
        Fade(a, 1, 0, 0.45, 2)
        p.anim = a
        d.hearts[i] = p
    end
    -- A warm glow flaring under the pet, behind it.
    d.glow = c:CreateTexture(nil, "BORDER", nil, 4)
    d.glow:SetTexture(ns.Decor.MEDIA .. "dot")
    d.glow:SetBlendMode("ADD")
    d.glow:SetVertexColor(1, 0.75, 0.5, 1)
    d.glow:SetSize(260, 120)
    d.glow:SetPoint("CENTER", panel, "TOP", 0, 80)
    d.glow:SetAlpha(0)
    d.glow:Hide()
    local g = OneShot(d.glow)
    Fade(g, 0, 0.6, 0.15, 1)
    Fade(g, 0.6, 0, 0.9, 2)
    d.glow.anim = g
    -- Clicks on the model: down, then up close by and soon after.
    local model = card.model or rawget(c, "modelScene")
    if model then
        local downAt, downX, downY
        model:HookScript("OnMouseDown", function()
            downAt = GetTime()
            downX, downY = GetCursorPosition()
        end)
        model:HookScript("OnMouseUp", function()
            if not downAt then return end
            local x, y = GetCursorPosition()
            local still = math.abs(x - downX) < CLICK_PX and math.abs(y - downY) < CLICK_PX
            local quick = GetTime() - downAt < CLICK_S
            downAt = nil
            if still and quick then Cuddle:Pet(card, x, y) end
        end)
        d.model = model
    end
    c:HookScript("OnHide", function() Cuddle:Stop(card) end)
end

function Cuddle:Stop(card)
    local d = card.cuddle
    if not d then return end
    for _, p in ipairs(d.hearts) do p.anim:Stop(); p:Hide() end
    d.ripple.anim:Stop(); d.ripple:Hide()
    d.glow.anim:Stop(); d.glow:Hide()
end

-- Where the cursor is (screen pixels) on the card, from its bottom left; nil
-- before the card is laid out.
local function OnCard(c, x, y)
    local left, bottom, scale = c:GetLeft(), c:GetBottom(), c:GetEffectiveScale()
    if not (x and left and bottom and scale and scale > 0) then return nil end
    return x / scale - left, y / scale - bottom
end

-- The pet on the card was petted (x, y: the cursor, screen pixels).
function Cuddle:Pet(card, x, y)
    local d, key = card.cuddle, card.key
    if not d or not key then return end
    self:Stop(card)
    local cx, cy = OnCard(d.c, x, y)
    local function Place(p)
        p:ClearAllPoints()
        if cx then p:SetPoint("CENTER", d.c, "BOTTOMLEFT", cx, cy)
        else p:SetPoint("CENTER", d.panel, "TOP", 0, 110) end -- not laid out: over the pet
    end
    Place(d.ripple)
    d.ripple:Show(); d.ripple.anim:Play()
    for i, p in ipairs(d.hearts) do
        Place(p)
        p.anim.move:SetOffset((i - (HEARTS + 1) / 2) * 12, 30 + (i % 2) * 10) -- up, a little apart
        p:Show(); p.anim:Play()
    end
    d.glow:Show(); d.glow.anim:Play()
    for _, s in ipairs(self.SOUNDS) do
        local id = SOUNDKIT and SOUNDKIT[s]
        if id then PlaySound(id); break end
    end
    -- Once a day, a cuddle for the bond: your adopted pet, out with you.
    local today = ns.Today()
    local guid = ns.Activity.Plain(ns.Pets:Summoned())
    if guid and ns.Pets:KeyOf(guid) == key and ns.DB.char.cardCuddle ~= today then
        ns.DB.char.cardCuddle = today
        ns.Activity:Emit("cuddle", 1, "card")
    end
end
