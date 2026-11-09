local _, ns = ...

-- The pet journal's list (JournalUI wires it): a marker on each button
-- (heart = yours, paw = someone else's, ring = yours to adopt), the bond
-- level in a ring, the nickname after the name, a gold paw on the pet kept
-- out, and who cares for it in the button's tooltip. Per-button state lives
-- in our own weak tables, never on Blizzard's frames (taint).
local JournalList = {}
ns.JournalList = JournalList

-- The list's markers, from our own drawn set (Media/Particles; 2026-11-09:
-- the raid star, padlock and tick didn't fit the card's style): a heart for
-- yours, a paw for someone else's, a little house for one that needs a home
-- (a green ring until 2026-11-09: it looked like the bond level's ring next to it).
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
local MARKERS = {
    mine = { MEDIA .. "heart", 1, 0.45, 0.55 },
    taken = { MEDIA .. "paw", 0.65, 0.65, 0.65 },
    free = { MEDIA .. "house", 0.45, 0.9, 0.45 },
}

local markers = setmetatable({}, { __mode = "k" }) -- button -> texture
local badges = setmetatable({}, { __mode = "k" })  -- button -> { ring, level, nick }
JournalList._badges = badges -- (for the tests)
local hooked = setmetatable({}, { __mode = "k" })  -- button -> true
local speciesOf = setmetatable({}, { __mode = "k" }) -- button -> speciesID, owned
local ownedOf = setmetatable({}, { __mode = "k" })

local Day = ns.Date

-- Tooltip lines for a pet key. Used by list buttons and the world tooltip.
function JournalList:AddTooltipLines(tooltip, key)
    local status, owner, r = ns.Registry:Status(key)
    local nick, namer, namedAt = ns.Registry:Nickname(key)
    local function Nick()
        if not nick then return end
        tooltip:AddLine(ns.T("tip.nick", { nick = nick }), 1, 1, 1)
        local by = namer == ns.PlayerKey() and ns.L["home.you"] or namer
        tooltip:AddLine(ns.T("tip.named_by", { who = by, date = Day(namedAt) }), 0.7, 0.7, 0.7)
    end
    tooltip:AddLine(" ")
    if status == "free" then
        tooltip:AddLine(ns.L["tip.free"], 0.5, 0.8, 0.5)
        Nick()
        tooltip:AddLine(ns.Personality:Line(key), 0.7, 0.7, 0.7)
        return
    end
    tooltip:AddLine(ns.Home(status == "mine" and ns.L["home.you"] or owner, r.at), 1, 0.82, 0)
    tooltip:AddLine(ns.T("tip.bond", { label = ns.Bond:Label(key) }), 1, 1, 1)
    Nick()
    tooltip:AddLine(ns.Personality:Line(key), 0.7, 0.7, 0.7)
end

local function ButtonSpecies(button, elementData)
    local sid, owned = button.speciesID, button.owned
    if not sid and elementData and elementData.index then
        local _, s, isOwned = C_PetJournal.GetPetInfoByIndex(elementData.index)
        sid, owned = s, isOwned
    end
    return sid, owned
end

local function UpdateMarker(button)
    local sid = speciesOf[button]
    local tex = markers[button]
    if not tex then
        tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetSize(16, 16)
        tex:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        markers[button] = tex
    end
    if not sid then tex:Hide(); return end
    local status = ns.Registry:Status(ns.Pets:KeyOfSpecies(sid))
    local m = MARKERS[status ~= "free" and status or (ownedOf[button] and "free" or "")]
    if not m then tex:Hide(); return end
    tex:SetTexture(m[1])
    tex:SetVertexColor(m[2], m[3], m[4], 1)
    tex:Show()
end

-- An adopted pet's bond level in a small gold ring, left of the marker, and
-- its nickname under the name (2026-11-08): the whole park at a glance.
local function UpdateBadge(button, ctx)
    local b = badges[button]
    if not b then
        b = {}
        b.ring = button:CreateTexture(nil, "OVERLAY")
        b.ring:SetAtlas("communities-ring-gold")
        b.ring:SetSize(20, 20)
        b.ring:SetPoint("RIGHT", button, "RIGHT", -26, 0)
        b.level = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.level:SetPoint("CENTER", b.ring, "CENTER", 0, 0)
        local name = rawget(button, "name")
        if type(name) == "table" and name.GetObjectType then
            b.name = name
            b.nick = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        end
        -- The pet kept out (OutBadge): a small gold paw on its icon.
        local icon = rawget(button, "icon")
        b.out = button:CreateTexture(nil, "OVERLAY", nil, 7)
        b.out:SetTexture(MEDIA .. "paw")
        b.out:SetVertexColor(1, 0.82, 0.3, 1)
        b.out:SetSize(16, 16)
        if type(icon) == "table" and icon.GetObjectType then
            b.out:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 3, -3)
        else
            b.out:SetPoint("LEFT", button, "LEFT", 30, -10)
        end
        badges[button] = b
    end
    local sid = speciesOf[button]
    local key = sid and ns.Pets:KeyOfSpecies(sid)
    -- Your level with it, in gold; else its carer's, in grey.
    local p, level, _, _, _, mine = ns.Bond:Own(key)
    if mine and p == 0 and key ~= ctx.myPet then -- one of yours, no bond yet: its carer's, if any
        level, mine = select(2, ns.Bond:Of(key)), false
    end
    b.out:SetShown(key ~= nil and key == ctx.active)
    b.ring:SetShown(level ~= nil); b.level:SetShown(level ~= nil)
    if level then
        b.level:SetText(level)
        b.ring:SetDesaturated(not mine)
        b.level:SetTextColor(mine and 1 or 0.7, mine and 0.82 or 0.7, mine and 0 or 0.7)
    end
    local nick = key and ns.Registry:Nickname(key)
    if b.nick then
        -- On the name's own row, right after it (under it spilled out of the
        -- button: seen 2026-11-08).
        b.nick:SetText(nick and ns.T("list.nick", { nick = nick }) or "")
        b.nick:ClearAllPoints()
        b.nick:SetPoint("LEFT", b.name, "LEFT", b.name:GetStringWidth() + 5, 0)
        b.nick:SetShown(nick ~= nil)
    end
end

local function OnButtonEnter(button)
    local sid = speciesOf[button]
    if not sid then return end
    if not GameTooltip:IsOwned(button) then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.Pets:NameOfKey(ns.Pets:KeyOfSpecies(sid)))
    end
    local key = ns.Pets:KeyOfSpecies(sid)
    JournalList:AddTooltipLines(GameTooltip, key)
    if key == ns.Summon:ActiveKey() then -- (ours only: not in the world tooltip, where it's anyone's)
        GameTooltip:AddLine(ns.T("card.out.on.title", { pet = ns.Registry:NameOf(key) }), 1, 0.82, 0.3)
    end
    GameTooltip:Show()
end

local function OnButtonLeave(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

-- What every list button's badge compares with, read once per refresh.
local function ListContext()
    return { myPet = ns.Registry:MyPet(), active = ns.Summon:ActiveKey() }
end

function JournalList.InitButton(button, elementData)
    local sid, owned = ButtonSpecies(button, elementData)
    speciesOf[button], ownedOf[button] = sid, owned
    if not hooked[button] then
        hooked[button] = true
        button:HookScript("OnEnter", OnButtonEnter)
        button:HookScript("OnLeave", OnButtonLeave)
    end
    UpdateMarker(button)
    UpdateBadge(button, ListContext())
end

function JournalList:Refresh()
    local box = PetJournal and PetJournal.ScrollBox
    if box and box.ForEachFrame then
        local ctx = ListContext() -- (the same for every button)
        box:ForEachFrame(function(button) UpdateMarker(button); UpdateBadge(button, ctx) end)
    end
end
