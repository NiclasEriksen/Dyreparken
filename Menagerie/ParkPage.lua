local _, ns = ...

-- "Parken": the park map, a page of the Collections window (a SidePage,
-- see Core/SidePage.lua), next to the achievements.
--
-- At the top, the park's records: the longest friendship, the most popular
-- family, the newest arrival. Below, every companion in Forever's journal
-- (Data/Companions.lua) as an icon: in color when it has a home, grey when
-- it's looking for one, a gold glow on yours, and a green tick on free ones
-- you own (you could adopt them). Hovering one tells its story; a click opens
-- its card on the Pets page (2026-11-09: the journal's list holds only the
-- pets you own, so this is how you see the rest). Only when the Pets page is
-- the one under ours: switching tabs is Blizzard's SetTab, which we never
-- call (Core/SidePage.lua: taint).
--
-- Everything comes from the registry; nothing is sent. We can't know which
-- pets other members own (that isn't synced), so there's no "nobody has it".
-- Loads after Achievements/Page.lua, so its tab comes second.
local Park = {}
ns.ParkPage = Park

local CELL, ICON_SIZE = 40, 36
local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"

local sp, page, child, records, legend
local cells = {}
Park._cells = cells

local Day = ns.Date


-- The park's records as lines, from the current holders.
function Park:Records(now)
    now = now or ns.Now()
    local R = ns.Registry
    local oldest, newest
    local families, names = {}, ns.AchTexts.generic.families
    for key, owner in pairs(R:Holders()) do
        local _, r = R:Holder(key)
        if not oldest or r.at < oldest.at or (r.at == oldest.at and key < oldest.key) then
            oldest = { key = key, owner = owner, at = r.at }
        end
        if not newest or r.at > newest.at or (r.at == newest.at and key < newest.key) then
            newest = { key = key, owner = owner, at = r.at }
        end
        local sid = ns.Pets:SpeciesOfKey(key)
        local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
        for _, tag in ipairs(type(data) == "table" and data.t or {}) do
            if names[tag] then families[tag] = (families[tag] or 0) + 1 end
        end
    end
    if not oldest then return { ns.L["park.empty"] } end
    local lines = {}
    lines[1] = ns.T("park.oldest", { pet = ns.Registry:NameOf(oldest.key), owner = oldest.owner,
        time = ns.CaredFor(oldest.at, now) })
    local best, bestN
    for tag, n in pairs(families) do
        if not best or n > bestN or (n == bestN and names[tag] < names[best]) then best, bestN = tag, n end
    end
    if best then
        lines[#lines + 1] = ns.T("park.family", { family = names[best], n = bestN })
    end
    -- With one pet in the park, it's both the oldest and the newest: once is enough.
    if newest.key ~= oldest.key then
        local home = ns.Home(newest.owner, newest.at, now)
        lines[#lines + 1] = ns.T("park.newest", { pet = ns.Registry:NameOf(newest.key),
            home = home:sub(1, 1):lower() .. home:sub(2) })
    end
    return lines
end

local function ShowTooltip(cell)
    local key = cell.key
    local R = ns.Registry
    local owner, r = R:Holder(key)
    local nick, namer, namedAt = R:Nickname(key)
    -- Below the icon: ANCHOR_RIGHT grew upwards over the page's header from the top rows (UX review 2026-11-11).
    GameTooltip:SetOwner(cell, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(nick or ns.Pets:NameOfKey(key))
    if nick then GameTooltip:AddLine(ns.Pets:NameOfKey(key), 0.7, 0.7, 0.7) end
    if owner then
        local who = owner == ns.PlayerKey() and ns.L["home.you"] or owner
        GameTooltip:AddLine(ns.Home(who, r.at), 1, 0.82, 0)
        GameTooltip:AddLine(ns.T("tip.bond", { label = ns.Bond:Label(key) }), 1, 1, 1)
    else
        GameTooltip:AddLine(ns.L["park.free"], 0.5, 0.8, 0.5)
    end
    if nick then
        local by = namer == ns.PlayerKey() and ns.L["home.you"] or namer
        GameTooltip:AddLine(ns.T("tip.named_by", { who = by, date = Day(namedAt) }), 0.7, 0.7, 0.7)
    end
    -- The traits by name only (2026-11-11, the user): what they do is on the card's personality tooltip.
    GameTooltip:AddLine(ns.Personality:Line(key), 0.7, 0.7, 0.7)
    if owner ~= ns.PlayerKey() and ns.Pets:IsOwned(key) then
        GameTooltip:AddLine(ns.L[owner and "park.also_yours" or "park.can_adopt"],
            1, 1, 1)
    end
    if ns.Pets:SpeciesOfKey(key) then
        GameTooltip:AddLine(ns.L[Park:CanShow() and "park.click" or "park.click.pets"], 0.6, 0.6, 0.6, true)
    end
    GameTooltip:Show()
end

-- The Pets page is under ours (shown, only covered), so its card can show.
function Park:CanShow()
    return PetJournal ~= nil and PetJournal:IsShown() == true
end

-- A click on an icon: leave the park, show that pet's card.
function Park:Show(key)
    local sid = ns.Pets:SpeciesOfKey(key)
    if not sid or not self:CanShow() or ns.InCombat() then return end
    ns.SidePage:CloseAll()
    ns.JournalUI:ShowSpecies(sid)
end

local function NewCell()
    local c = CreateFrame("Button", nil, child)
    c:SetSize(ICON_SIZE, ICON_SIZE)
    c.icon = c:CreateTexture(nil, "ARTWORK")
    c.icon:SetAllPoints()
    c.mine = c:CreateTexture(nil, "OVERLAY")
    c.mine:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    c.mine:SetBlendMode("ADD")
    c.mine:SetAllPoints()
    c.free = c:CreateTexture(nil, "OVERLAY")
    c.free:SetTexture(READY)
    c.free:SetSize(14, 14)
    c.free:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 2, -2)
    c:SetScript("OnEnter", ShowTooltip)
    c:SetScript("OnLeave", ns.HideTip)
    c:SetScript("OnClick", function(self) Park:Show(self.key) end)
    cells[#cells + 1] = c
    return c
end

-- Every journal species as a pet key, sorted by name.
local function AllKeys()
    local list = {}
    local data = ns.Companions and ns.Companions.species
    for sid in pairs(data or {}) do
        local key = ns.Pets:KeyOfSpecies(sid)
        list[#list + 1] = { key = key, name = ns.Pets:NameOfKey(key) or "" }
    end
    table.sort(list, function(a, b) return a.name < b.name or (a.name == b.name and a.key < b.key) end)
    return list
end

local function Redraw()
    local R = ns.Registry
    local lines = Park:Records()
    records:SetText(table.concat(lines, "\n"))
    local top = 8 + records:GetStringHeight() + 8
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -top)
    top = top + 22
    local width = child:GetWidth() or 659
    local cols = math.max(1, math.floor((width - 8) / CELL))
    local owned, me = ns.Pets:Owned(), ns.PlayerKey()
    local homes = 0
    local keys = AllKeys()
    for i, it in ipairs(keys) do
        local c = cells[i] or NewCell()
        c.key = it.key
        c.icon:SetTexture(ns.Pets:IconOfKey(it.key))
        local owner = R:Holder(it.key)
        c.icon:SetDesaturated(owner == nil)
        c.icon:SetAlpha(owner and 1 or 0.55)
        c.mine:SetShown(owner == me)
        c.free:SetShown(owner == nil and owned[it.key] ~= nil)
        if owner then homes = homes + 1 end
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", child, "TOPLEFT", 8 + col * CELL, -(top + row * CELL))
        c:Show()
    end
    for i = #keys + 1, #cells do cells[i]:Hide() end
    child:SetHeight(top + math.ceil(#keys / cols) * CELL + 8)
    page.summary:SetText(("%d/%d"):format(homes, #keys))
end

local function Build(p)
    page = p.frame
    page.summary = ns.SidePage:CounterBox(p, ns.L["park.counter"])
    child = ns.SidePage:ScrollInset(p)
    records = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    records:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -8)
    records:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    records:SetJustifyH("LEFT")
    legend = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legend:SetTextColor(0.8, 0.76, 0.66) -- (the disabled grey was hard to read, UX review 2026-11-11)
    legend:SetText(ns.T("park.legend", { icon = ("|T%s:14|t"):format(READY) }))
    Park._page, Park._records, Park._legend = page, records, legend
end

sp = ns.SidePage:New({
    id = "Park",
    title = ns.L["park.title"],
    icon = ns.Achievements:Icon({ id = "page:park", icon = { "INV_Box_PetCarrier_01", "Ability_Hunter_BeastCall" } }),
    build = Build,
    refresh = Redraw,
})
Park._sp = sp

function Park:Open() sp:Open() end
function Park:IsOpen() return sp:IsOpen() end
function Park:Refresh() sp:Refresh() end

-- (Bonds show only in a cell's tooltip, read as it opens: a change of bonds alone redraws nothing.)
ns.Bus:On("REGISTRY", function(keys) if not keys then Park:Refresh() end end)
