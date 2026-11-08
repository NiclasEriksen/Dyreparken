local _, ns = ...

-- Today's wish (2026-11-08): each day your adopted pet wishes for one thing
-- it likes. Done with it out, the wish brings Config.BOND_WISH_POINTS (within
-- the day's limit), a line in chat, and a tick on its card. A reason to do
-- something with your pet today, not just have it out.
--
-- The wish is one of the pet's likes (Personality), picked from the date and
-- the pet, so it holds all day and through reloads; never something you
-- can't do when you like (dying, a level). Kept per character in
-- char.wish = { day, pet, id, done }.
local Wish = {}
ns.Wish = Wish

-- Likes that can't be a wish: you can't do them on demand.
Wish.NEVER = { revive = true, level = true, day = true }

-- What the pet wishes for on a day ("YYYYMMDD").
function Wish:For(key, day)
    local _, list = ns.Personality:Of(key)
    local choices = {}
    for _, act in ipairs(list) do
        if not self.NEVER[act] then choices[#choices + 1] = act end
    end
    if #choices == 0 then choices = { "quest" } end
    local h = LibStub("LibDeflate"):Adler32("wish " .. day .. " " .. key)
    return choices[h % #choices + 1]
end

-- Today's wish for your adopted pet: { pet, id, done }, or nil without one.
function Wish:Today()
    local key = ns.Registry:MyPet()
    if not key then return nil end
    local day = date("%Y%m%d", ns.Now())
    local w = ns.DB.char.wish
    if not w or w.day ~= day or w.pet ~= key then
        w = { day = day, pet = key, id = self:For(key, day), done = false }
        ns.DB.char.wish = w
    end
    return w
end

function Wish:OnActivity(id, key)
    local w = self:Today()
    if not w or w.done or w.pet ~= key or w.id ~= id then return end
    w.done = true
    local points = ns.Config.BOND_WISH_POINTS
    local name = ns.Bonds:NameOf(key)
    ns.Print(ns.T("wish.granted", { pet = name, activity = ns.Personality.NOUN[id], n = points }))
    ns.Log("Bond", "wish %s granted for %s", id, key)
    ns.Bond:Bonus(points, key)
end

function Wish:Init()
    -- (OnActivity checks the pet out is today's wisher: your adopted pet.)
    ns.Bus:On("ACTIVITY", function(id, _, key) Wish:OnActivity(id, key) end)
end

------------------------------------------------------------------------------
-- On the card: a line under the chips, for your own pet.
------------------------------------------------------------------------------
function Wish:Build(card, c)
    local f = CreateFrame("Frame", nil, c)
    f:SetSize(260, 18)
    f:SetFrameLevel(c:GetFrameLevel() + 5)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(16, 16)
    f.icon:SetPoint("LEFT")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
    f:EnableMouse(true)
    f:SetScript("OnEnter", function(self)
        local w = Wish:Today()
        if not w then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(ns.L["wish.title"], 1, 0.82, 0)
        GameTooltip:AddLine(ns.T(w.done and "wish.tip.done" or "wish.tip", { pet = ns.Bonds:NameOf(w.pet),
            n = ns.Config.BOND_WISH_POINTS }), 1, 1, 1, true)
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    f:Hide()
    card.wish = f
end

function Wish:Update(card, key)
    local f = card.wish
    if not f then return end
    local w = key and self:Today()
    if not w or w.pet ~= key then f:Hide(); return end
    local icons = ns.Stats.ICONS[w.id]
    f.icon:SetTexture(icons and icons[1] or (ns.Decor.MEDIA .. "heart"))
    if w.done then
        f.text:SetText(ns.L["wish.done"])
        f.text:SetTextColor(0.4, 1, 0.4)
        f.icon:SetDesaturated(false)
    else
        f.text:SetText(ns.T("wish.line", { pet = ns.Bonds:NameOf(key), activity = ns.Personality.NOUN[w.id] }))
        f.text:SetTextColor(1, 0.82, 0)
    end
    f:SetWidth(20 + f.text:GetStringWidth())
    f:ClearAllPoints()
    local stats = card.stats
    if stats and stats:IsShown() then
        f:SetPoint("TOP", stats, "BOTTOM", 0, -4)
    elseif card.decor and card.decor.ribbon:IsShown() then
        f:SetPoint("TOP", card.decor.ribbon, "BOTTOM", 0, -2)
    else
        f:SetPoint("TOP", card.panel:GetParent(), "TOP", 0, -14)
    end
    f:Show()
end
