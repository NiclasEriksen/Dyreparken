local _, ns = ...

-- What you and a pet have done together, on its card (2026-11-08): small
-- chips at the top, an icon and a count each. "Days out together" first,
-- then the biggest of the rest, at most MAX. The counts are this
-- character's own (the activity engine's per-pet counters,
-- char.activity[id].pets), so they show on any pet you've had out, and
-- only to you. Hover a chip for what it counts.
local Stats = {}
ns.Stats = Stats

local MAX = 5
local CHIP_H, ICON, GAP = 20, 16, 6

-- Activities with a chip, and their icons (the first the client has).
Stats.ICONS = {
    day = { "Interface\\Icons\\INV_Misc_PocketWatch_01" },
    boss = { "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
    quest = { "Interface\\GossipFrame\\ActiveQuestIcon", "Interface\\Icons\\INV_Misc_Note_01" }, -- (the first is missing on Forever)
    herb = { "Interface\\Icons\\Trade_Herbalism" },
    mine = { "Interface\\Icons\\Trade_Mining" },
    fish = { "Interface\\Icons\\Trade_Fishing" },
    skin = { "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    taxi = { "Interface\\TaxiFrame\\UI-Taxi-Icon-Green", "Interface\\Icons\\Ability_Mount_Gryphon_01" },
    pvp = { "Interface\\Icons\\Ability_DualWield" },
    explore = { "Interface\\Icons\\INV_Misc_Map_01" },
    hearth = { "Interface\\Icons\\INV_Misc_Rune_01" },
}
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local function Icon(id)
    for _, path in ipairs(Stats.ICONS[id]) do
        if not GetFileIDFromPath or GetFileIDFromPath(path) then return path end
    end
    return QUESTION
end

-- The chips for a pet: { id, n }, days first, then by count.
function Stats:For(key)
    local list = {}
    for id in pairs(self.ICONS) do
        local _, _, _, n = ns.Activity:Count(id, key)
        if n > 0 then list[#list + 1] = { id = id, n = n } end
    end
    table.sort(list, function(a, b)
        if (a.id == "day") ~= (b.id == "day") then return a.id == "day" end
        if a.n ~= b.n then return a.n > b.n end
        return a.id < b.id
    end)
    while #list > MAX do table.remove(list) end
    return list
end

local function Tip(self)
    local card = self.card
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    local pet = ns.Bonds:NameOf(card.key)
    if self.id == "day" then
        GameTooltip:SetText(ns.T("stats.days", { n = self.n, pet = pet }), 1, 1, 1)
    else
        GameTooltip:SetText(ns.T("stats.tip", { n = self.n, what = ns.Personality.NOUN[self.id], pet = pet }), 1, 1, 1)
    end
    GameTooltip:Show()
end

function Stats:Build(card, c)
    local row = CreateFrame("Frame", nil, c)
    row:SetSize(10, CHIP_H)
    row:SetFrameLevel(c:GetFrameLevel() + 5)
    row.chips = {}
    for i = 1, MAX do
        local chip = CreateFrame("Frame", nil, row)
        chip:SetHeight(CHIP_H)
        chip.bg = chip:CreateTexture(nil, "BACKGROUND")
        chip.bg:SetAllPoints()
        chip.bg:SetColorTexture(0, 0, 0, 0.5)
        chip.icon = chip:CreateTexture(nil, "ARTWORK")
        chip.icon:SetSize(ICON, ICON)
        chip.icon:SetPoint("LEFT", chip, "LEFT", 3, 0)
        chip.count = chip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        chip.count:SetPoint("LEFT", chip.icon, "RIGHT", 3, 0)
        chip.card = card
        chip:EnableMouse(true)
        chip:SetScript("OnEnter", Tip)
        chip:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
        chip:Hide()
        row.chips[i] = chip
    end
    card.stats = row
    row:Hide()
end

-- Show the chips for a pet (none: hidden). Below the ribbon when it shows.
function Stats:Update(card, key)
    local row = card.stats
    if not row then return end
    local list = key and self:For(key) or {}
    if #list == 0 then row:Hide(); return end
    local x = 0
    for i, chip in ipairs(row.chips) do
        local s = list[i]
        if s then
            chip.id, chip.n = s.id, s.n
            chip.icon:SetTexture(Icon(s.id))
            chip.count:SetText(s.n)
            local w = 3 + ICON + 3 + chip.count:GetStringWidth() + 6
            chip:SetWidth(w)
            chip:ClearAllPoints()
            chip:SetPoint("LEFT", row, "LEFT", x, 0)
            x = x + w + GAP
            chip:Show()
        else
            chip:Hide()
        end
    end
    row:SetWidth(math.max(1, x - GAP))
    row:ClearAllPoints()
    local ribbon = card.decor and card.decor.ribbon
    if ribbon and ribbon:IsShown() then
        row:SetPoint("TOP", ribbon, "BOTTOM", 0, -2)
    else
        row:SetPoint("TOP", card.panel:GetParent(), "TOP", 0, -14)
    end
    row:Show()
end
