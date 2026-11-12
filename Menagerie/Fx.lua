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
-- between bursts.
local Fx = {}
ns.Fx = Fx

Fx.POOL = 24
Fx.AGAIN = 4 -- seconds before the same companion bursts again
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"

local layer, pool, nextOne
local function Layer()
    if layer then return layer end
    layer = CreateFrame("Frame", nil, UIParent)
    layer:SetAllPoints()
    layer:SetFrameStrata("HIGH")
    pool, nextOne = {}, 1
    Fx.particles = pool -- (for the tests)
    return layer
end

local function NewParticle()
    local p = CreateFrame("Frame", nil, Layer())
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

-- The next particle, reusing the oldest when all are busy.
local function Take()
    Layer()
    local p = pool[nextOne]
    if not p then p = NewParticle(); pool[nextOne] = p end
    nextOne = nextOne % Fx.POOL + 1
    p.anim:Stop()
    return p
end

-- A burst of n particles of a kind (Decor.KINDS) from a point: anchor =
-- { frame, point, x, y }. o: n, color, alpha, size (scale), spread, rise (px).
function Fx:Burst(anchor, kind, o)
    local k = ns.Decor.KINDS[kind]
    if not k then return end
    local n, size, spread, rise = o.n or 5, o.size or 1, o.spread or 30, o.rise or 50
    local c = o.color or { 1, 1, 1 }
    for i = 1, n do
        local p = Take()
        p.icon:SetTexture(MEDIA .. k.tex)
        p.icon:SetBlendMode(k.add and "ADD" or "BLEND")
        p.icon:SetVertexColor(c[1], c[2], c[3], o.alpha or 1)
        local s = math.random(k.size[1], k.size[2]) * size
        p:SetSize(s, s)
        p:ClearAllPoints()
        p:SetPoint("CENTER", anchor[1], anchor[2], anchor[3] + math.random(-spread, spread) / 3,
            anchor[4] + math.random(-spread, spread) / 3)
        local g, dx = p.anim, math.random(-spread, spread)
        local fall = k.path == "fall" and -1 or 1 -- feathers and leaves drift down
        g.hold:SetDuration(0.01 + (i - 1) * 0.08)
        g.up:SetOffset(dx * 0.4, fall * rise * 0.5); g.up:SetDuration(0.4)
        g.fadeIn:SetDuration(0.25)
        g.drift:SetOffset(dx * 0.6, fall * rise * 0.5); g.drift:SetDuration(1.1)
        g.fadeOut:SetDuration(1.1)
        g.grow:SetScaleTo(k.path == "burst" and 0.4 or 0.8, k.path == "burst" and 0.4 or 0.8)
        g.grow:SetDuration(1.1)
        p:Show()
        g:Play()
    end
end

------------------------------------------------------------------------------
-- In the world: a companion under the mouse
------------------------------------------------------------------------------
local last = {} -- species .. owner -> when it last burst (GetTime)

-- How loved it is, without a word (2026-11-10): the hearts in its holder's
-- bond tier, pink, a deeper rose from Venn (3), warm gold from 5. Their own
-- colors (2026-11-12, the user: the card's silver made them almost white):
-- edit these to change the hearts alone; the card's tiers are Scenes.SILVER/GOLD.
Fx.PINK = { 1, 0.45, 0.6 }   -- anyone's companion, or its holder's bond under 3
Fx.ROSE = { 0.95, 0.2, 0.4 } -- its holder's bond at Venn (3) or 4
Fx.GOLD = { 1, 0.72, 0.15 }  -- at 5 and up
function Fx:HeartColor(species, owner)
    local key = type(species) == "number" and ns.Pets:KeyOfSpecies(species)
    if not (key and owner and ns.Registry:Holder(key) == owner) then return self.PINK end
    local _, level = ns.Bond:Of(key)
    if (level or 0) >= 5 then return self.GOLD end
    if (level or 0) >= 3 then return self.ROSE end
    return self.PINK
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
