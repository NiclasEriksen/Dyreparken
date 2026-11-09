local _, ns = ...

-- Animation pieces shared by the pet card (Decor, BondTrack, Cuddle). What
-- the client taught us (docs/FOREVER_API.md, 2026-11-08): no BOUNCE loops
-- (they blink where they turn), and one playing group per region.
local Anim = {}
ns.Anim = Anim

-- A breathing alpha, lo -> hi -> lo, as a REPEAT loop. g.a is the rising half.
function Anim.Pulse(region, lo, hi, period)
    local g = region:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    local up = g:CreateAnimation("Alpha")
    up:SetFromAlpha(lo); up:SetToAlpha(hi); up:SetDuration(period / 2); up:SetSmoothing("IN_OUT"); up:SetOrder(1)
    local down = g:CreateAnimation("Alpha")
    down:SetFromAlpha(hi); down:SetToAlpha(lo); down:SetDuration(period / 2); down:SetSmoothing("IN_OUT")
    down:SetOrder(2)
    g.a = up
    return g
end

-- An alpha step in a group.
function Anim.Fade(g, from, to, dur, order)
    local a = g:CreateAnimation("Alpha")
    a:SetFromAlpha(from); a:SetToAlpha(to); a:SetDuration(dur); a:SetOrder(order)
    return a
end

-- A scale step from the region's center (smoothing: "OUT", "IN_OUT"..., optional).
function Anim.Scale(g, from, to, dur, order, smoothing)
    local a = g:CreateAnimation("Scale")
    a:SetScaleFrom(from, from); a:SetScaleTo(to, to); a:SetDuration(dur); a:SetOrder(order)
    a:SetOrigin("CENTER", 0, 0)
    if smoothing then a:SetSmoothing(smoothing) end
    return a
end

-- A group that plays once and hides its region when done.
function Anim.OneShot(region)
    local g = region:CreateAnimationGroup()
    g:SetLooping("NONE")
    g:SetScript("OnFinished", function() region:Hide() end)
    return g
end
