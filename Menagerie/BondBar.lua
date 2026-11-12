local _, ns = ...

-- A bond bar: the card's (BondTrack.lua) and the pet frame's (PetFrame.lua). The fill from the
-- tier's dark to its bright, and the gains since you last looked (2026-11-10, the user: "feedback
-- from loyalty gains"): the bar grows from where it was to now, in steps, and each gain floats up
-- from its tip as "+N", one after another. Timers and one-shot groups only; Stop ends them.
--
--   local bar = ns.BondBar.New(parent, { texture = path })  -- a StatusBar; size and place it
--   bar:Set(points, from, top, tier)   -- within the level: from..top; tier: a color (Scenes.Tier)
--   bar:Gains(last, list)              -- grow from `last` to the points Set, the numbers in `list`
--   bar:Stop()                         -- the growth ends where it was going, the numbers go
--
-- (bar.numbers is the pool of rising numbers: the tests read it.)
local BondBar = {}
ns.BondBar = BondBar

BondBar.GROW = { delay = 0.4, steps = 14, every = 0.06 } -- the growth: after the model, in steps
BondBar.NUMBER_EVERY = 0.45 -- seconds between the numbers
-- How a number shows: in, rising, then out. 2026-11-11, the user: "hard to see. They're blending with the
-- text underneath and they're gone too soon": longer (about 3 s, was 2), outlined, on a dark halo, and
-- drawn above the window (DIALOG), so nothing on the card covers them.
BondBar.NUMBER = { fadeIn = 0.2, rise = 2.2, fadeOut = 0.8, height = 40 }
local NUMBERS = 6

-- How long gains take to show, the last number gone (PetFrame keeps its bar up this long).
function BondBar.GainsFor()
    local N = BondBar.NUMBER
    return BondBar.GROW.delay + N.fadeIn + N.rise + N.fadeOut
end

local Bar = {}

local function Numbers(b)
    if b.numbers then return b.numbers end
    b.numbers = {}
    local holder = CreateFrame("Frame", nil, b)
    holder:SetAllPoints() -- (a child: drawn over the bar)
    holder:SetFrameStrata("DIALOG") -- (and over everything on the card)
    local N, GOLD = BondBar.NUMBER, ns.Scenes.GOLD
    for i = 1, NUMBERS do
        local f = CreateFrame("Frame", nil, holder)
        f:SetSize(60, 24)
        f:Hide()
        f.halo = f:CreateTexture(nil, "BACKGROUND")
        f.halo:SetTexture(ns.Decor.MEDIA .. "dot")
        f.halo:SetPoint("CENTER")
        f.halo:SetSize(64, 34)
        f.halo:SetVertexColor(0, 0, 0, 0.75)
        f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.text:SetPoint("CENTER")
        local path, size = f.text:GetFont()
        if path then f.text:SetFont(path, (size or 16) + 2, "OUTLINE") end
        f.text:SetShadowColor(0, 0, 0, 1)
        f.text:SetShadowOffset(1, -1)
        f.text:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
        local a = ns.Anim.OneShot(f)
        ns.Anim.Fade(a, 0, 1, N.fadeIn, 1)
        a.rise = a:CreateAnimation("Translation"); a.rise:SetOffset(0, N.height); a.rise:SetDuration(N.rise)
        a.rise:SetSmoothing("OUT"); a.rise:SetOrder(2)
        ns.Anim.Fade(a, 1, 0, N.fadeOut, 3)
        f.anim = a
        b.numbers[i] = f
    end
    return b.numbers
end

function BondBar.New(parent, opts)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetStatusBarTexture(opts and opts.texture or "Interface\\Buttons\\WHITE8X8")
    b.timers = ns.Timers()
    for k, fn in pairs(Bar) do b[k] = fn end
    return b
end

-- The growth ends where it was going (numbers already rising finish).
local function EndGrowth(self)
    self.timers:Cancel()
    if self.growTo then self:SetValue(self.growTo); self.growTo, self.growAt = nil, nil end
end

-- The value now: the top level's bar is full. A refresh while the bar grows to these same points
-- keeps it growing (Blizzard updates the card as it opens); to other points, the growth ends.
function Bar:Set(points, from, top, tier)
    self.shown = { points = points, from = from, top = top } -- (not .points: a frame's anchors, in the tests)
    self:SetMinMaxValues(from, top)
    local value = points >= top and top or points
    if self.growTo == points and self.growAt then
        value = self.growAt
    elseif self.growTo then
        EndGrowth(self)
    end
    self:SetValue(value)
    local fill = self:GetStatusBarTexture()
    if fill and CreateColor then
        fill:SetGradient("HORIZONTAL", CreateColor(tier[1] * 0.55, tier[2] * 0.55, tier[3] * 0.55, 1),
            CreateColor(math.min(1, tier[1] * 1.15), math.min(1, tier[2] * 1.15), math.min(1, tier[3] * 1.15), 1))
    else
        self:SetStatusBarColor(tier[1], tier[2], tier[3])
    end
end

function Bar:Stop()
    EndGrowth(self)
    for _, f in ipairs(self.numbers or {}) do f.anim:Stop(); f:Hide() end
end

-- From `last` to the points Set (within this level), and the numbers in `list` rising from the tip.
function Bar:Gains(last, list)
    local shown = self.shown
    if not shown then return end
    local points, from, top = shown.points, shown.from, shown.top
    local t = self.timers
    t:Cancel() -- (an earlier growth ends here)
    local start = math.max(from, last)
    if start < points then
        local g = BondBar.GROW
        self.growTo, self.growAt = points, start
        self:SetValue(start)
        t:After(g.delay, function()
            t:Every(g.every, g.steps, function(i)
                self.growAt = start + (points - start) * i / g.steps
                self:SetValue(self.growAt)
                if i == g.steps then self.growTo, self.growAt = nil, nil end
            end)
        end)
    end
    local pool = Numbers(self)
    local width = self:GetWidth() or 120
    local x = width * math.max(0, math.min(1, (points - from) / math.max(1, top - from)))
    for i, n in ipairs(list) do
        if i > #pool then break end
        t:After(BondBar.GROW.delay + (i - 1) * BondBar.NUMBER_EVERY, function()
            local f = pool[i]
            f.text:SetText("+" .. n)
            f:ClearAllPoints()
            f:SetPoint("BOTTOM", self, "BOTTOMLEFT", x + ((i % 2 == 0) and 10 or -10), 6)
            f:Show(); f.anim:Play()
        end)
    end
end
