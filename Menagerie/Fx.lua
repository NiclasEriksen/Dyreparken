local _, ns = ...

-- Little bursts of the card's particles outside the journal (2026-11-09).
--
-- In the world: companions get no nameplate on Forever (docs/FOREVER_API.md),
-- so nothing follows a pet around. The mouse does: hovering a companion puts
-- the cursor on it, so a burst at the cursor comes from the pet: a few
-- hearts, any companion's (2026-11-10: its family's ambience as well was too
-- much). Once per pet per few seconds (the tooltip is redrawn while you hover), never in combat
-- (Tooltip.lua's COMPANION_SEEN).
--
-- On screen, discreetly: a few sparkles at the chat window's corner when a
-- bond line is printed there, and sparkles and hearts at a bond level-up.
--
-- One-shot groups only (each particle: wait, rise and fade in, drift and fade
-- out; hidden when done), from a small pool built on first use. Nothing runs
-- between bursts. The same engine plays the card's bursts (Fx:Emit: the bond's
-- celebration, a cuddle's ripple and hearts, the paw badge's ring) on the card's
-- own layer, a pool per parent.
local Fx = {}
ns.Fx = Fx

Fx.POOL = 24
Fx.AGAIN = 4 -- seconds before the same companion bursts again

-- One engine for every burst (docs/REFACTOR.md, Phase 4): the world's and the chat's on a layer over
-- UIParent at HIGH strata; the card's on the card itself, at a frame level each burst picks, so they
-- stay under our side pages (the user, 2026-11-12). A pool per parent, built on first use.
local pools = {} -- parent -> { list, next, max }
local function Pool(parent, max)
    local pool = pools[parent]
    if not pool then
        pool = { list = {}, next = 1, max = max or Fx.POOL }
        pools[parent] = pool
    end
    return pool
end

local layer
local function Layer()
    if layer then return layer end
    layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints()
    layer:SetFrameStrata("HIGH")
    Fx.particles = Pool(layer).list -- (for the tests)
    return layer
end

-- Each particle plays one group: a hold (unseen), then step A (up: a move, fadeIn), then step B
-- (drift: a move, fadeOut, grow: a scale from 1); hidden when done.
local function NewParticle(parent)
    local p = CreateFrame("Frame", nil, parent)
    p:Hide()
    p.icon = p:CreateTexture(nil, "ARTWORK")
    p.icon:SetAllPoints()
    local g = ns.Anim.OneShot(p)
    g.hold = ns.Anim.Fade(g, 0, 0, 0.01, 1)
    g.up = g:CreateAnimation("Translation"); g.up:SetOrder(2); g.up:SetSmoothing("OUT")
    g.fadeIn = ns.Anim.Fade(g, 0, 1, 0.2, 2)
    g.drift = g:CreateAnimation("Translation"); g.drift:SetOrder(3)
    g.fadeOut = ns.Anim.Fade(g, 1, 0, 1, 3)
    g.grow = ns.Anim.Scale(g, 1, 1, 1, 3)
    p.anim = g
    return p
end

-- The next particle of a parent's pool, reusing the oldest when all are busy.
local function Take(parent, max)
    local pool = Pool(parent, max)
    local p = pool.list[pool.next]
    if not p then p = NewParticle(parent); pool.list[pool.next] = p end
    pool.next = pool.next % pool.max + 1
    p.anim:Stop()
    return p
end

local function Move(a, m, dur)
    a:SetOffset(m and m[1] or 0, m and m[2] or 0)
    a:SetDuration(m and m[3] or dur)
    a:SetSmoothing(m and m[4] or "NONE")
end
local function Alpha(a, f, dur)
    a:SetFromAlpha(f[1]); a:SetToAlpha(f[2]); a:SetDuration(f[3] or dur)
end

-- Particles from a point, each as told. o: parent (nil: the HIGH layer), level (a frame level),
-- pool (its size, the first time a parent is used), tag (Fx:Stop's), anchor { frame, point, x, y }.
-- A particle: tex (path), add (blend ADD), color { r, g, b }, alpha, size (px, or { w, h }),
-- x, y (from the anchor), delay (s), up { dx, dy, dur, smoothing } and fadeIn { from, to, dur },
-- then drift { dx, dy, dur, smoothing }, fadeOut { from, to, dur } and grow { to, dur, smoothing }.
-- Returns the particles.
function Fx:Emit(o, list)
    local parent = o.parent or Layer()
    local out = {}
    for i, s in ipairs(list) do
        local p = Take(parent, o.pool)
        p.tag = o.tag
        if o.level then p:SetFrameLevel(o.level) end
        p.icon:SetTexture(s.tex)
        p.icon:SetBlendMode(s.add and "ADD" or "BLEND")
        local c = s.color or { 1, 1, 1 }
        p.icon:SetVertexColor(c[1], c[2], c[3], s.alpha or 1)
        local w, h = s.size, s.size
        if type(w) == "table" then w, h = w[1], w[2] end
        p:SetSize(w, h)
        p:ClearAllPoints()
        local at = o.anchor
        p:SetPoint("CENTER", at[1], at[2], (at[3] or 0) + (s.x or 0), (at[4] or 0) + (s.y or 0))
        local g = p.anim
        g.hold:SetDuration(s.delay or 0.01)
        local fadeIn = s.fadeIn or { 0, 1, 0.01 }
        Move(g.up, s.up, fadeIn[3] or 0.01)
        Alpha(g.fadeIn, fadeIn, 0.01)
        local fadeOut = s.fadeOut or { 1, 0, 0.01 }
        Move(g.drift, s.drift, fadeOut[3] or 0.01)
        Alpha(g.fadeOut, fadeOut, 0.01)
        local grow = s.grow or {}
        g.grow:SetScaleTo(grow[1] or 1, grow[1] or 1)
        g.grow:SetDuration(grow[2] or fadeOut[3] or 0.01)
        g.grow:SetSmoothing(grow[3] or "NONE")
        p:Show()
        g:Play()
        out[i] = p
    end
    return out
end

-- Stop a parent's particles (nil: the HIGH layer's), only a tag's if given.
function Fx:Stop(parent, tag)
    local pool = pools[parent or Layer()]
    for _, p in ipairs(pool and pool.list or {}) do
        if tag == nil or p.tag == tag then p.anim:Stop(); p:Hide() end
    end
end

-- How many of a parent's particles (of a tag) are playing now.
function Fx:Playing(parent, tag)
    local pool, n = pools[parent or Layer()], 0
    for _, p in ipairs(pool and pool.list or {}) do
        if (tag == nil or p.tag == tag) and p:IsShown() and p.anim:IsPlaying() then n = n + 1 end
    end
    return n
end

-- A burst of n particles of a kind (Decor.KINDS) from a point: anchor =
-- { frame, point, x, y }. o: n, color, alpha, size (scale), spread, rise (px);
-- parent, level, tag (as Emit's).
function Fx:Burst(anchor, kind, o)
    local k = ns.Decor.KINDS[kind]
    if not k then return end
    local n, size, spread, rise = o.n or 5, o.size or 1, o.spread or 30, o.rise or 50
    local fall = k.path == "fall" and -1 or 1 -- feathers and leaves drift down
    local shrink = k.path == "burst" and 0.4 or 0.8
    local list = {}
    for i = 1, n do
        local s = math.random(k.size[1], k.size[2]) * size
        local x, y = math.random(-spread, spread) / 3, math.random(-spread, spread) / 3
        local dx = math.random(-spread, spread)
        list[i] = { tex = ns.Icon(k.tex), add = k.add, color = o.color, alpha = o.alpha, size = s, x = x, y = y,
            delay = 0.01 + (i - 1) * 0.08,
            up = { dx * 0.4, fall * rise * 0.5, 0.4, "OUT" }, fadeIn = { 0, 1, 0.25 },
            drift = { dx * 0.6, fall * rise * 0.5, 1.1 }, fadeOut = { 1, 0, 1.1 }, grow = { shrink, 1.1 } }
    end
    return self:Emit({ parent = o.parent, level = o.level, tag = o.tag, anchor = anchor }, list)
end

------------------------------------------------------------------------------
-- In the world: a companion under the mouse
------------------------------------------------------------------------------
local last = {} -- species .. owner -> when it last burst (GetTime)

-- How loved it is, without a word (2026-11-10): the hearts in its holder's
-- bond tier (Scenes.LEVELS), pink, a deeper rose at silver (Venn, 3), warm gold
-- at gold (5). Their own colors (2026-11-12, the user: the card's silver made
-- them almost white): edit these to change the hearts alone; the card's tiers
-- are Scenes.SILVER/GOLD.
Fx.PINK = { 1, 0.45, 0.6 }   -- anyone's companion, or its holder's bond under silver
Fx.ROSE = { 0.95, 0.2, 0.4 } -- its holder's bond at silver
Fx.GOLD = { 1, 0.72, 0.15 }  -- at gold
function Fx:HeartColor(species, owner)
    local key = type(species) == "number" and ns.Pets:KeyOfSpecies(species)
    if not (key and owner and ns.Registry:Holder(key) == owner) then return self.PINK end
    local _, level = ns.Bond:Of(key)
    local tier = ns.Scenes.Reward(level or 0, "tier")
    return tier == "gold" and self.GOLD or tier == "silver" and self.ROSE or self.PINK
end

function Fx:Hovered(species, owner)
    if not ns.Settings:On("worldHearts") then return end
    local id = tostring(species) .. "|" .. tostring(owner)
    local now = GetTime()
    if last[id] and now - last[id] < self.AGAIN then return end
    last[id] = now
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    local at = { UIParent, "BOTTOMLEFT", x / scale, y / scale }
    self:Burst(at, "heart", { n = 3, color = self:HeartColor(species, owner), size = 0.7, rise = 60 })
    ns.Log("Fx", "hover %s (%s)", tostring(species), tostring(owner))
end

------------------------------------------------------------------------------
-- On screen: at the chat window, where the lines are printed
------------------------------------------------------------------------------
local function AtChat()
    return { DEFAULT_CHAT_FRAME, "TOPRIGHT", -24, -8 }
end

function Fx:Line()
    if not (ns.Settings:On("worldHearts") and ns.Settings:On("chatLines")) then return end
    self:Burst(AtChat(), "spark", { n = 4, color = { 1, 0.85, 0.4 }, size = 0.6, spread = 24, rise = 24 })
end

function Fx:LevelUp()
    if not ns.Settings:On("worldHearts") then return end
    local at = AtChat()
    self:Burst(at, "spark", { n = 6, color = { 1, 0.85, 0.4 }, size = 0.8, spread = 40, rise = 40 })
    self:Burst(at, "heart", { n = 4, color = { 1, 0.45, 0.6 }, size = 0.8, spread = 30, rise = 70 })
end

function Fx:Init()
    ns.Bus:On("COMPANION_SEEN", function(species, owner) Fx:Hovered(species, owner) end)
    ns.Bus:On("BOND_LINE", function() Fx:Line() end)
    ns.Bus:On("BOND_LEVEL", function() Fx:LevelUp() end)
end

ns.Start("login", function() Fx:Init() end)
