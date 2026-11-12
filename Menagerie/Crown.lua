local _, ns = ...

-- The pet of the day's crown (2026-11-10, in place of a halo over its head:
-- the client can't tell where a pet's head is on its card, /dp probe pos): a
-- small gold crown at the card's top left, beside the cake when there is one.
-- Hovering it says so.
local Crown = {}
ns.Crown = Crown

local SIZE = 26

function Crown:Build(card, c)
    local f = CreateFrame("Frame", nil, c)
    f:SetSize(SIZE, SIZE)
    f:SetFrameLevel(c:GetFrameLevel() + 30) -- (over the model, like the cake and the paw badge)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetTexture(ns.Decor.MEDIA .. "crown")
    f.icon:SetVertexColor(ns.Scenes.GOLD[1], ns.Scenes.GOLD[2], ns.Scenes.GOLD[3], 1)
    f.icon:SetAllPoints()
    f:EnableMouse(true)
    ns.SetTip(f, "ANCHOR_RIGHT", function() return {
        { ns.L["card.today"], 1, 0.82, 0 },
        { ns.T("card.crown.tip", { pet = ns.Registry:NameOf(card.key) }), 1, 1, 1, true },
    } end)
    f:Hide()
    card.crown = f
end

-- After the cake (its place depends on whether the cake shows).
function Crown:Update(card, key)
    local f = card.crown
    if not f then return end
    local today = key and ns.Bonds:PetOfTheDay() == key
    if not today then return f:Hide() end
    f:ClearAllPoints()
    if card.cake and card.cake:IsShown() then
        f:SetPoint("LEFT", card.cake, "RIGHT", 4, 0)
    else
        f:SetPoint("TOPLEFT", f:GetParent(), "TOPLEFT", 20, -18)
    end
    f:Show()
end

ns.Card.Register{ id = "crown",
    build = function(card, c) Crown:Build(card, c) end,
    update = function(card, key) Crown:Update(card, key) end, -- (after the cake: beside it)
    pause = function(card) Crown:Update(card, nil) end, -- (over the model's level: it'd show through our page)
}
