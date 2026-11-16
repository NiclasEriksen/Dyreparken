---@class Dyreparken
local ns = select(2, ...)

-- Pet it on the card (2026-11-08): a click on the pet (not a drag, which
-- turns the model) answers quietly where you clicked: a ripple, a few small
-- hearts rising (every other one the pet's own particle), and a warm glow
-- flaring under the pet; a sound, its own (Data/PetSounds.lua) or a soft click. No
-- text (a speech bubble read badly, the user decided). Once a day it's a
-- cuddle for the bond too (the activity "cuddle", as /pet would be), when
-- the card shows a pet of yours that's out (any pet, adopted or not: the user, 2026-11-12).
---@class Dyreparken.Cuddle
local Cuddle = {}
ns.Cuddle = Cuddle

local HEARTS = 4
-- Where a click pets the pet (2026-11-10): the area Blizzard frames every pet
-- in, as fractions of the model scene (left, right, bottom, top). The client
-- can't say where the pet itself is (docs/FOREVER_API.md), so one area for all.
-- (2026-11-16, the user: the pets stand on the card's shadow by their feet and are smaller on average now,
-- "shrink that one as well": the middle two fifths across, from just under the shadow to a little over the
-- tallest; until then 0.22, 0.78, 0.04, 0.75. By eye from a card screenshot: to check in game.)
Cuddle.AREA = { 0.3, 0.7, 0.12, 0.6 }

-- Is the cursor (screen pixels) in that area of the model scene?
function Cuddle:OnPet(model, x, y)
    local scale, left, bottom = model:GetEffectiveScale(), model:GetLeft(), model:GetBottom()
    local w, h = model:GetWidth(), model:GetHeight()
    if not (scale and scale > 0 and left and bottom and w and h and w > 0 and h > 0) then return true end -- (not laid out)
    local fx, fy = (x / scale - left) / w, (y / scale - bottom) / h
    local a = self.AREA
    return fx >= a[1] and fx <= a[2] and fy >= a[3] and fy <= a[4]
end
local CLICK_PX, CLICK_S = 5, 0.4 -- a click: moved less than this, shorter than this
-- The sound: the pet's own (Data/PetSounds.lua, 2026-11-16: the setting "petSounds"), at most one every
-- SOUND_GAP seconds; else, and for a pet with none, the first of these soft clicks the client knows.
Cuddle.SOUNDS = { "IG_CHARACTER_INFO_TAB", "IG_MAINMENU_OPTION_CHECKBOX_ON" }
Cuddle.SOUND_GAP = 1.2

-- The pet's own sound, if it has one and the setting is on: the file played, or nil.
function Cuddle:PetSound(key)
    if not ns.Settings:On("petSounds") then return nil end
    if self.soundAt and GetTime() - self.soundAt < self.SOUND_GAP then return nil end
    local P = ns.PetSounds
    local set = P.SETS[P.SPECIES[ns.Pets:SpeciesOfKey(key) or 0] or ""]
    local id = ns.PlaySoundFiles(set, true)
    if id then self.soundAt = GetTime() end
    return id
end

local OneShot, Fade = ns.Anim.OneShot, ns.Anim.Fade

function Cuddle:Build(card, c, panel)
    -- (the ripple and the hearts: Fx, on the card's own layer, over the pet; Pet)
    local d = { hearts = {}, c = c, panel = panel }
    card.cuddle = d
    -- A warm glow flaring under the pet, behind it.
    d.glow = c:CreateTexture(nil, "BORDER", nil, 4)
    d.glow:SetTexture(ns.Icon("dot"))
    d.glow:SetBlendMode("ADD")
    d.glow:SetVertexColor(1, 0.75, 0.5, 1)
    d.glow:SetSize(260, 120)
    d.glow:SetPoint("CENTER", panel, "TOP", 0, 80)
    d.glow:SetAlpha(0)
    d.glow:Hide()
    local g = OneShot(d.glow)
    Fade(g, 0, 0.6, 0.15, 1)
    Fade(g, 0.6, 0, 0.9, 2)
    d.glow.anim = g
    -- Clicks on the model: down, then up close by and soon after.
    local model = card.model or rawget(c, "modelScene")
    if model then
        local downAt, downX, downY
        model:HookScript("OnMouseDown", function()
            downAt = GetTime()
            downX, downY = GetCursorPosition()
        end)
        model:HookScript("OnMouseUp", function()
            if not downAt then return end
            local x, y = GetCursorPosition()
            local still = math.abs(x - downX) < CLICK_PX and math.abs(y - downY) < CLICK_PX
            local quick = GetTime() - downAt < CLICK_S
            downAt = nil
            if still and quick and Cuddle:OnPet(model, x, y) then Cuddle:Pet(card, x, y) end
        end)
        d.model = model
    end
end

function Cuddle:Stop(card)
    local d = card.cuddle
    if not d then return end
    ns.Fx:Stop(d.c, "cuddle")
    d.glow.anim:Stop(); d.glow:Hide()
end

-- The pet's own particle (2026-11-10): its first trait's, if it has one and
-- its personality is known, else its family's. { tex, color }.
local function Own(key)
    local D = ns.Decor
    local spec
    if ns.Personality:Known(key) then
        for _, t in ipairs(ns.Personality:Traits(key)) do
            spec = D.TRAITS[t.id]
            if spec then break end
        end
    end
    spec = spec or D.FAMILY[ns.Scenes:Families(key)[1] or "default"] or D.FAMILY.default
    local c = spec.color
    if type(c) ~= "table" or type(c[1]) == "table" then c = { 1, 0.85, 0.5 } end -- (rainbow, a palette: one warm color)
    return D.KINDS[spec.kind].tex, c
end

-- Where the cursor is (screen pixels) on the card, from its bottom left; nil
-- before the card is laid out.
local function OnCard(c, x, y)
    local left, bottom, scale = c:GetLeft(), c:GetBottom(), c:GetEffectiveScale()
    if not (x and left and bottom and scale and scale > 0) then return nil end
    return x / scale - left, y / scale - bottom
end

-- The pet on the card was petted (x, y: the cursor, screen pixels).
function Cuddle:Pet(card, x, y)
    local d, key = card.cuddle, card.key
    if not d or not key then return end
    self:Stop(card)
    local cx, cy = OnCard(d.c, x, y)
    local o = { parent = d.c, level = d.c:GetFrameLevel() + 20, tag = "cuddle",
        anchor = cx and { d.c, "BOTTOMLEFT", cx, cy } or { d.panel, "TOP", 0, 110 } } -- (not laid out: over the pet)
    -- The ripple: a ring growing and fading where you clicked.
    d.ripple = ns.Fx:Emit(o, { { tex = ns.Icon("ring"), add = true, color = { 1, 0.85, 0.75 }, size = 24,
        fadeIn = { 0, 0.9, 0.08 }, fadeOut = { 0.9, 0, 0.6 }, grow = { 3, 0.6, "OUT" } } })[1]
    -- A few small hearts rising from the same spot; every other one the pet's own particle:
    -- bubbles from a Dykker, crumbs from a Glupsk.
    local tex, color = Own(key)
    local hearts = {}
    for i = 1, HEARTS do
        local own = i % 2 == 0
        hearts[i] = { tex = ns.Icon(own and tex or "heart"), color = own and color or { 1, 0.5, 0.6 },
            alpha = own and 0.9 or 0.85, size = 12,
            up = { (i - (HEARTS + 1) / 2) * 12, 30 + (i % 2) * 10, 0.8, "OUT" }, fadeIn = { 0, 1, 0.12 }, -- up, a little apart
            fadeOut = { 1, 0, 0.45 } }
    end
    d.hearts = ns.Fx:Emit(o, hearts)
    d.glow:Show(); d.glow.anim:Play()
    if not self:PetSound(key) then ns.PlayFirstSound(self.SOUNDS) end
    ns.Moves:Cuddle(key) -- (wakes it, or a happy hop)
    -- Once a day, a cuddle for the bond: the pet that's out with you, any of yours.
    local today = ns.Today()
    if ns.Pets:OutKey() == key and ns.DB.char.cardCuddle ~= today then
        ns.DB.char.cardCuddle = today
        ns.Activity:Emit("cuddle", 1, "card")
    end
end

-- (After the model is found, "rotate": it listens for clicks on it. Its bursts end under our pages too.)
ns.Card.Register{ id = "cuddle",
    build = function(card, c) Cuddle:Build(card, c, card.panel) end,
    stop = function(card) Cuddle:Stop(card) end,
}
