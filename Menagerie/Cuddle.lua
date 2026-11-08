local _, ns = ...

-- Pet it on the card (2026-11-08): a click on the pet (not a drag, which
-- turns the model) gives a little burst of hearts, a speech bubble with a
-- happy line, and a soft sound. Once a day it's a cuddle for the bond too
-- (the activity "cuddle", as /pet would be), when the card shows your
-- adopted pet and it's out.
local Cuddle = {}
ns.Cuddle = Cuddle

local HEARTS = 8
local CLICK_PX, CLICK_S = 5, 0.4 -- a click: moved less than this, shorter than this
local LINES = 5 -- cuddle.line.1 .. 5 in Locale/nb.lua
-- The sound: the first of these the client knows.
Cuddle.SOUNDS = { "IG_CHARACTER_INFO_TAB", "IG_MAINMENU_OPTION_CHECKBOX_ON" }

local function OneShot(region)
    local g = region:CreateAnimationGroup()
    g:SetLooping("NONE")
    g:SetScript("OnFinished", function() region:Hide() end)
    return g
end

function Cuddle:Build(card, c, panel)
    local d = { hearts = {} }
    card.cuddle = d
    for i = 1, HEARTS do
        local p = CreateFrame("Frame", nil, c)
        p:SetFrameLevel(c:GetFrameLevel() + 20) -- over the pet: it's for it
        p:SetSize(16, 16)
        p:SetPoint("CENTER", panel, "TOP", 0, 110)
        p:SetAlpha(0)
        p:Hide()
        p.icon = p:CreateTexture(nil, "ARTWORK")
        p.icon:SetAllPoints()
        p.icon:SetTexture(ns.Decor.MEDIA .. "heart")
        p.icon:SetVertexColor(1, 0.45, 0.55, 1)
        local a = OneShot(p)
        a.move = a:CreateAnimation("Translation"); a.move:SetDuration(0.9); a.move:SetSmoothing("OUT"); a.move:SetOrder(1)
        local f1 = a:CreateAnimation("Alpha"); f1:SetFromAlpha(0); f1:SetToAlpha(1); f1:SetDuration(0.1); f1:SetOrder(1)
        local f2 = a:CreateAnimation("Alpha"); f2:SetFromAlpha(1); f2:SetToAlpha(0); f2:SetDuration(0.5); f2:SetOrder(2)
        p.anim = a
        d.hearts[i] = p
    end
    -- The speech bubble, above the pet.
    local b = CreateFrame("Frame", nil, c)
    b:SetFrameLevel(c:GetFrameLevel() + 21)
    b:SetSize(200, 26)
    b:SetPoint("BOTTOM", panel, "TOP", 0, 190)
    b:SetAlpha(0)
    b:Hide()
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0, 0, 0, 0.65)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    b.text:SetPoint("CENTER")
    local a = OneShot(b)
    local in1 = a:CreateAnimation("Alpha"); in1:SetFromAlpha(0); in1:SetToAlpha(1); in1:SetDuration(0.2); in1:SetOrder(1)
    local hold = a:CreateAnimation("Alpha"); hold:SetFromAlpha(1); hold:SetToAlpha(1); hold:SetDuration(1.8); hold:SetOrder(2)
    local out = a:CreateAnimation("Alpha"); out:SetFromAlpha(1); out:SetToAlpha(0); out:SetDuration(0.5); out:SetOrder(3)
    b.anim = a
    d.bubble = b
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
            if still and quick then Cuddle:Pet(card) end
        end)
        d.model = model
    end
    c:HookScript("OnHide", function() Cuddle:Stop(card) end)
end

function Cuddle:Stop(card)
    local d = card.cuddle
    if not d then return end
    for _, p in ipairs(d.hearts) do p.anim:Stop(); p:Hide() end
    d.bubble.anim:Stop(); d.bubble:Hide()
end

-- The pet on the card was petted.
function Cuddle:Pet(card)
    local d, key = card.cuddle, card.key
    if not d or not key then return end
    self:Stop(card)
    for i, p in ipairs(d.hearts) do
        local angle = math.pi * (0.15 + 0.7 * (i - 1) / (HEARTS - 1)) -- a fan, upwards
        local dist = 50 + (i % 3) * 14
        p.anim.move:SetOffset(math.cos(angle) * dist, math.sin(angle) * dist)
        p:Show(); p.anim:Play()
    end
    d.bubble.text:SetText(ns.T("cuddle.line." .. math.random(LINES), { pet = ns.Bonds:NameOf(key) }))
    d.bubble:SetWidth(d.bubble.text:GetStringWidth() + 20)
    d.bubble:Show(); d.bubble.anim:Play()
    for _, s in ipairs(self.SOUNDS) do
        local id = SOUNDKIT and SOUNDKIT[s]
        if id then PlaySound(id); break end
    end
    -- Once a day, a cuddle for the bond: your adopted pet, out with you.
    local today = date("%Y%m%d", ns.Now())
    local guid = ns.Activity.Plain(ns.Pets:Summoned())
    if ns.Registry:MyPet() == key and guid and ns.Pets:KeyOf(guid) == key and ns.DB.char.cardCuddle ~= today then
        ns.DB.char.cardCuddle = today
        ns.Activity:Emit("cuddle", 1, "card")
    end
end
