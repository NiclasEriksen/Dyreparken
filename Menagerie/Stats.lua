local _, ns = ...

-- What you and a pet have done together, on its card (2026-11-08): small
-- chips at the top, an icon and a count each. "Days out together" first,
-- then the biggest of the rest, at most MAX. The counts are this
-- character's own (the activity engine's per-pet counters,
-- char.activity[id].pets), so only you see them. The engine counts an
-- activity only while something watches it: the bond watches the common
-- ones and your adopted pet's likes, so a pet you only had out now and then
-- may show fewer kinds than you did with it. Hover a chip for what it counts.
local Stats = {}
ns.Stats = Stats

local MAX = 5
local CHIP_H, ICON, GAP = 20, 16, 6

-- Activities with a chip, and their icons (the first the client has).
Stats.ICONS = {}
for _, k in ipairs(ns.Activity.KINDS) do Stats.ICONS[k.id] = k.icons end
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

function Stats.Icon(id)
    if not Stats.ICONS[id] then return nil end
    for _, path in ipairs(Stats.ICONS[id]) do
        if not GetFileIDFromPath or GetFileIDFromPath(path) then return path end
    end
    return QUESTION
end
local Icon = Stats.Icon

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

-- Round numbers (2026-11-10): a chip whose count reached 10, 50, 100, 500
-- or 1000 today wears a gold ring for the day. Noted the moment it's reached
-- (char.chipRounds[key][id] = { m, day }), so old counts never light up.
Stats.ROUND = { 10, 50, 100, 500, 1000 }
local function Round(before, after)
    local hit
    for _, m in ipairs(Stats.ROUND) do if before < m and after >= m then hit = m end end
    return hit
end

function Stats:OnActivity(id, n, key)
    if not (key and self.ICONS[id]) then return end
    local _, _, _, now = ns.Activity:Count(id, key)
    local m = Round(now - (n or 1), now)
    if not m then return end
    local all = ns.DB.char.chipRounds
    all[key] = all[key] or {}
    all[key][id] = { m = m, day = ns.Today() }
end

-- The round number a pet's chip reached today, or nil.
function Stats:RoundToday(key, id)
    local r = key and ns.DB.char.chipRounds[key]
    r = r and r[id]
    return r and r.day == ns.Today() and r.m or nil
end

-- A chip's tooltip: n of activity id with the pet, a round number today, the last place found.
function Stats.Lines(key, id, n)
    local pet = ns.Registry:NameOf(key)
    local lines = { { id == "day" and ns.T(n == 1 and "stats.days_one" or "stats.days", { n = n, pet = pet })
        or ns.T("stats.tip", { n = n, what = ns.Personality.NOUN[id], pet = pet }), 1, 1, 1 } }
    local round = Stats:RoundToday(key, id)
    if round then lines[#lines + 1] = { ns.T("stats.round", { m = round }), 1, 0.82, 0 } end
    local last = id == "explore" and ns.DB.char.lastPlace[key]
    if last then lines[#lines + 1] = { ns.T("stats.last_place", { place = last }), 0.8, 0.8, 0.8 } end
    return lines
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
        -- A round number today: a thin gold frame around the chip (2026-11-10: a ring
        -- around the square icon looked wrong).
        chip.ring = CreateFrame("Frame", nil, chip)
        chip.ring:SetAllPoints()
        ns.Edges(chip.ring, 1, { 1, 0.82, 0.3, 0.9 }, { layer = "OVERLAY" })
        chip.ring:Hide()
        chip.card = card
        chip:EnableMouse(true)
        ns.SetTip(chip, "ANCHOR_BOTTOM", function(self) return Stats.Lines(card.key, self.id, self.n) end)
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
            local round = self:RoundToday(key, s.id)
            chip.ring:SetShown(round ~= nil)
            if round then chip.count:SetTextColor(1, 0.82, 0) else chip.count:SetTextColor(1, 1, 1) end
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

ns.Card.Register{ id = "stats", still = true, -- (chips, no animation)
    build = function(card, c) Stats:Build(card, c) end,
    update = function(card, key) Stats:Update(card, key) end, -- (after the decor: under the ribbon when there is one)
}

ns.Start("login", function()
    ns.Bus:On("ACTIVITY", function(id, n, key) Stats:OnActivity(id, n, key) end)
end)
