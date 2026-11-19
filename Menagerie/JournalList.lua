---@class Dyreparken
local ns = select(2, ...)

-- The pet journal's list (JournalUI wires it): a marker on each button
-- (heart = yours, paw = someone else's, ring = yours to adopt), the bond
-- level in a ring, the nickname after the name, a gold paw on the pet kept
-- out, and who cares for it in the button's tooltip. Per-button state lives
-- in our own weak tables, never on Blizzard's frames (taint).
---@class Dyreparken.JournalList
local JournalList = {}
ns.JournalList = JournalList

-- The list's markers, from our own drawn set (Media/Particles; 2026-11-09:
-- the raid star, padlock and tick didn't fit the card's style): a heart for
-- yours, a paw for someone else's, a little house for one that needs a home
-- (a green ring until 2026-11-09: it looked like the bond level's ring next to it).
local MARKERS = {
    mine = { ns.Icon("heart"), 1, 0.45, 0.55 },
    taken = { ns.Icon("paw"), 0.65, 0.65, 0.65 },
    free = { ns.Icon("house"), 0.45, 0.9, 0.45 },
}

local markers = setmetatable({}, { __mode = "k" }) -- button -> texture
local badges = setmetatable({}, { __mode = "k" })  -- button -> { ring, level, nick }
JournalList._badges = badges -- (for the tests)
local faces = setmetatable({}, { __mode = "k" })   -- button -> { bg, face }
JournalList._faces = faces -- (for the tests)
local hooked = setmetatable({}, { __mode = "k" })  -- button -> true
local speciesOf = setmetatable({}, { __mode = "k" }) -- button -> speciesID, owned
local ownedOf = setmetatable({}, { __mode = "k" })

local Day = ns.Date

-- A pet's lines in a tooltip, shared by the list's buttons and the park's icons: its home and
-- bond (or that it needs one: free, the text for that), who named it, its traits by name.
-- nick: the nickname as a line of its own (the park has it as the title instead).
function JournalList.PetLines(key, free, nick)
    local lines = {}
    local function Add(text, r, g, b) lines[#lines + 1] = { text, r, g, b } end
    local status, owner, r = ns.Registry:Status(key)
    if status == "free" then
        Add(ns.L[free], 0.5, 0.8, 0.5)
    else
        Add(ns.Home(status == "mine" and ns.L["home.you"] or owner, r.at), 1, 0.82, 0)
        Add(ns.T("tip.bond", { label = ns.Bond:Label(key) }), 1, 1, 1)
    end
    -- Your own bond with one you don't hold, in words: the ring tells it by its color alone (gold yours, grey its
    -- carer's: review 2026-11-19).
    local p, level, levelName, _, _, yours = ns.Bond:Own(key)
    if yours and status ~= "mine" and p and p > 0 then
        Add(ns.T("tip.yours", { label = ns.T("bond.label", { level = levelName, n = level }) }), 1, 0.82, 0)
    end
    local name, namer, namedAt = ns.Registry:Nickname(key)
    if name then
        if nick then Add(ns.T("tip.nick", { nick = name }), 1, 1, 1) end
        Add(ns.T("tip.named_by", { who = namer == ns.PlayerKey() and ns.L["home.you"] or namer, date = Day(namedAt) }),
            0.7, 0.7, 0.7)
    end
    Add(ns.Personality:Line(key), 0.7, 0.7, 0.7)
    return lines
end

-- The same under a tooltip someone else started (a list button's, Blizzard's).
function JournalList:AddTooltipLines(tooltip, key)
    tooltip:AddLine(" ")
    ns.AddTipLines(tooltip, self.PetLines(key, "tip.free", true))
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

-- The pet's own face over the button's icon (2026-11-15, the user: the park's portraits, in the list
-- too; the Brown Prairie Dog's icon is a whistle): our textures over Blizzard's icon, which is left as it
-- is underneath (never set on their frame), on a dark square that hides it; grey when theirs is.
local function UpdateFace(button)
    local icon = rawget(button, "icon")
    if not (type(icon) == "table" and icon.GetObjectType) then return end
    local f = faces[button]
    if not f then
        f = {}
        f.bg = button:CreateTexture(nil, "ARTWORK", nil, 6)
        f.bg:SetColorTexture(0.05, 0.04, 0.03, 1)
        f.bg:SetAllPoints(icon)
        f.face = button:CreateTexture(nil, "ARTWORK", nil, 7)
        f.face:SetPoint("TOPLEFT", icon, "TOPLEFT", 1, -1)
        f.face:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
        faces[button] = f
    end
    local sid = speciesOf[button]
    local shown = sid ~= nil and ns.Pets:Portrait(f.face, ns.Pets:KeyOfSpecies(sid))
    f.bg:SetShown(shown); f.face:SetShown(shown)
    if shown then
        local okD, grey = pcall(icon.IsDesaturated, icon)
        f.face:SetDesaturated(okD and grey and true or false)
    end
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
            -- (warm, as the card's likes line: disabled grey read as unavailable, review 2026-11-19)
            b.nick = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            b.nick:SetTextColor(0.8, 0.76, 0.66)
            b.nick:SetWordWrap(false)
        end
        -- The pet kept out (OutBadge): a small gold paw on its icon, on a dark disc (review 2026-11-19: a bare paw
        -- was also the grey "someone else's" mark at the row's end).
        local icon = rawget(button, "icon")
        b.outDisc = button:CreateTexture(nil, "OVERLAY", nil, 6)
        b.outDisc:SetTexture(ns.Icon("dot"))
        b.outDisc:SetVertexColor(0.1, 0.07, 0.03, 0.9)
        b.outDisc:SetSize(18, 18)
        b.out = button:CreateTexture(nil, "OVERLAY", nil, 7)
        b.out:SetTexture(ns.Icon("paw"))
        b.out:SetVertexColor(1, 0.82, 0.3, 1)
        b.out:SetSize(13, 13)
        if type(icon) == "table" and icon.GetObjectType then
            b.outDisc:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 4, -4)
        else
            b.outDisc:SetPoint("LEFT", button, "LEFT", 29, -10)
        end
        b.out:SetPoint("CENTER", b.outDisc, "CENTER", 0, 0)
        badges[button] = b
    end
    local sid = speciesOf[button]
    local key = sid and ns.Pets:KeyOfSpecies(sid)
    -- Your level with it, in gold; else its carer's, in grey.
    local p, level, _, _, _, mine = ns.Bond:Own(key)
    if mine and p == 0 and key ~= ctx.myPet then -- one of yours, no bond yet: its carer's, if any
        level, mine = select(2, ns.Bond:Of(key)), false
    end
    b.out:SetShown(key ~= nil and key == ctx.active); b.outDisc:SetShown(b.out:IsShown())
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
        -- (it ends before the ring, cut with "...", review 2026-11-19; a name on two lines: under it)
        if (b.name.GetNumLines and b.name:GetNumLines() or 1) > 1 then
            b.nick:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -1)
        else
            b.nick:SetPoint("LEFT", b.name, "LEFT", b.name:GetStringWidth() + 5, 0)
        end
        b.nick:SetPoint("RIGHT", b.ring, "LEFT", -4, 0)
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
    UpdateFace(button)
end

-- keys: only these pets' bonds changed (their rings), else all of it.
function JournalList:Refresh(keys)
    local box = PetJournal and PetJournal.ScrollBox
    if box and box.ForEachFrame then
        local ctx = ListContext() -- (the same for every button)
        box:ForEachFrame(function(button)
            if not keys then
                UpdateMarker(button); UpdateBadge(button, ctx)
            elseif speciesOf[button] and keys[ns.Pets:KeyOfSpecies(speciesOf[button])] then
                UpdateBadge(button, ctx)
            end
        end)
    end
end
