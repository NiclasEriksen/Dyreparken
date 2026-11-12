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

-- Decor's particle motions (moved here from Decor.lua, docs/REFACTOR.md Phase 4).
-- A looping group with one animation of a kind, origin in the middle.
function Anim.Loop(t, kind, looping)
    local g = t:CreateAnimationGroup()
    g:SetLooping(looping)
    local a = g:CreateAnimation(kind)
    if a.SetOrigin and kind ~= "Translation" and kind ~= "Alpha" then a:SetOrigin("CENTER", 0, 0) end
    a:SetSmoothing("IN_OUT")
    g.a = g.a or a
    return g, a
end

function Anim.Timeline(holder, grow)
    local g = holder:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    g.hold = g:CreateAnimation("Alpha"); g.hold:SetFromAlpha(0); g.hold:SetToAlpha(0); g.hold:SetOrder(1)
    g.moveA = g:CreateAnimation("Translation"); g.moveA:SetOrder(2)
    g.fadeIn = g:CreateAnimation("Alpha"); g.fadeIn:SetFromAlpha(0); g.fadeIn:SetToAlpha(1); g.fadeIn:SetOrder(2)
    g.moveB = g:CreateAnimation("Translation"); g.moveB:SetOrder(3)
    g.fadeOut = g:CreateAnimation("Alpha"); g.fadeOut:SetFromAlpha(1); g.fadeOut:SetToAlpha(0); g.fadeOut:SetOrder(3)
    if grow then g.grow = g:CreateAnimation("Scale"); g.grow:SetOrder(3); g.grow:SetOrigin("CENTER", 0, 0) end
    return g
end

-- A back-and-forth motion as a REPEAT loop of steps (no BOUNCE):
-- Translation and Rotation swing out, across and home like a pendulum;
-- Scale beats (up, back down, rest). Steps are relative, so they add up to
-- nothing over a loop and it never jumps.
function Anim.Swing(region, kind)
    local g = region:CreateAnimationGroup()
    g:SetLooping("REPEAT")
    g.kind = kind
    g.steps = {}
    for i = 1, 3 do
        local a = g:CreateAnimation(kind == "Scale" and (i == 3 and "Translation" or "Scale") or kind)
        a:SetOrder(i)
        if a.SetOrigin and kind ~= "Translation" and not (kind == "Scale" and i == 3) then a:SetOrigin("CENTER", 0, 0) end
        g.steps[i] = a
    end
    return g
end

-- Set a swing's size (pixels, degrees, or a scale factor) and one loop's length.
function Anim.SetSwing(g, amount, period, across)
    local a1, a2, a3 = g.steps[1], g.steps[2], g.steps[3]
    if g.kind == "Scale" then -- a beat: up quickly, down, then a rest (a still step)
        local y = across and 1 or amount -- across: the width only
        a1:SetScale(amount, y); a1:SetDuration(period * 0.3); a1:SetSmoothing("OUT")
        a2:SetScale(1 / amount, 1 / y); a2:SetDuration(period * 0.4); a2:SetSmoothing("IN_OUT")
        a3:SetOffset(0, 0); a3:SetDuration(period * 0.3)
        return
    end
    -- A pendulum: fastest through the middle, still at the ends.
    local set = g.kind == "Rotation" and function(a, v) a:SetDegrees(v) end or function(a, v) a:SetOffset(v, 0) end
    set(a1, amount); a1:SetDuration(period / 4); a1:SetSmoothing("OUT")
    set(a2, -2 * amount); a2:SetDuration(period / 2); a2:SetSmoothing("IN_OUT")
    set(a3, amount); a3:SetDuration(period / 4); a3:SetSmoothing("IN")
end
