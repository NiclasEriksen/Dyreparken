local _, ns = ...

-- A small UI kit for our frames (docs/REFACTOR.md, Phase 4): pieces that were written out
-- once per module. Tooltips are in Init.lua (ns.SetTip, ns.ShowTip), animations in Anim.lua.

-- Our own particle textures (Media/Particles, drawn by tools/draw_particles.py).
ns.MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
function ns.Icon(name) return ns.MEDIA .. name end

-- Four textures along a frame's sides, px thick, in order TOP, BOTTOM, LEFT, RIGHT (t.side).
-- color: { r, g, b, a } (nil: white, to tint later). o: layer ("BORDER"), sub (sublevel),
-- inset (px in from the frame's edges, 0), parent (the frame the textures belong to: frame).
function ns.Edges(frame, px, color, o)
    o = o or {}
    local owner, inset = o.parent or frame, o.inset or 0
    local c = color or { 1, 1, 1, 1 }
    local list = {}
    for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = owner:CreateTexture(nil, o.layer or "BORDER", nil, o.sub)
        t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
        if side == "TOP" or side == "BOTTOM" then
            local y = side == "TOP" and -inset or inset
            t:SetPoint(side .. "LEFT", frame, side .. "LEFT", inset, y)
            t:SetPoint(side .. "RIGHT", frame, side .. "RIGHT", -inset, y)
            t:SetHeight(px)
        else
            local x = side == "LEFT" and inset or -inset
            t:SetPoint("TOP" .. side, frame, "TOP" .. side, x, -inset)
            t:SetPoint("BOTTOM" .. side, frame, "BOTTOM" .. side, x, inset)
            t:SetWidth(px)
        end
        t.side = side
        list[i] = t
    end
    return list
end

-- A two-color gradient on a texture, a and b { r, g, b, a } (orientation "VERTICAL": a at the
-- bottom). Returns true if drawn; a client without gradients gets b's color at the average alpha,
-- unless plain is false (then nothing).
function ns.Gradient(t, orientation, a, b, plain)
    if t.SetGradient and CreateColor then
        t:SetGradient(orientation, CreateColor(unpack(a)), CreateColor(unpack(b)))
        return true
    end
    if plain ~= false then t:SetVertexColor(b[1], b[2], b[3], (a[4] + b[4]) / 2) end
    return false
end

-- A round button: a dark disc, a gold ring, an icon in the middle, a glow under the mouse.
-- o: icon (texture path), iconSize (a fraction of size; nil: the whole button), color ({ r, g, b, a }),
-- texCoord ({ l, r, t, b }), disc (px less than size; nil: none), ring (true: the gold ring),
-- ringOver (the ring over the icon, not under), hover ({ r, g, b, a }; nil: none).
-- Fields: b.bg (the disc), b.ring, b.icon, b.hover.
function ns.RoundBadge(parent, size, o)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    if o.disc then
        b.bg = b:CreateTexture(nil, "BORDER")
        b.bg:SetTexture(ns.Icon("dot"))
        b.bg:SetVertexColor(0, 0, 0, 0.75)
        b.bg:SetPoint("CENTER")
        b.bg:SetSize(size - o.disc, size - o.disc)
    end
    local function Ring()
        b.ring = b:CreateTexture(nil, o.ringOver and "OVERLAY" or "ARTWORK")
        b.ring:SetAtlas("communities-ring-gold")
        b.ring:SetAllPoints()
    end
    if o.ring and not o.ringOver then Ring() end
    b.icon = b:CreateTexture(nil, (o.ring and not o.ringOver) and "OVERLAY" or "ARTWORK")
    b.icon:SetTexture(o.icon)
    if o.texCoord then b.icon:SetTexCoord(unpack(o.texCoord)) end
    if o.color then b.icon:SetVertexColor(unpack(o.color)) end
    if o.iconSize then
        b.icon:SetPoint("CENTER")
        b.icon:SetSize(size * o.iconSize, size * o.iconSize)
    else
        b.icon:SetAllPoints()
    end
    if o.ring and o.ringOver then Ring() end
    if o.hover then
        b.hover = b:CreateTexture(nil, "HIGHLIGHT")
        b.hover:SetTexture(ns.Icon("dot"))
        b.hover:SetBlendMode("ADD")
        b.hover:SetVertexColor(unpack(o.hover))
        b.hover:SetAllPoints()
    end
    return b
end
