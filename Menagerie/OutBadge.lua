---@class Dyreparken
local ns = select(2, ...)

-- "Med deg" (2026-11-09): which pet auto-summon keeps out, as a round paw
-- badge at the top right of the pet's box. It replaced a plain "Hold ute"
-- tickbox at the window's bottom edge, too anonymous for the choice the bond
-- system turns on. Active: a gold ring and paw, breathing softly, "Med deg".
-- Not: dim and grey, "Ta med ut". A click toggles it (Summon:SetActive),
-- with a small burst when a pet comes along. For a pet you don't own (seen
-- from Parken, Dagens dyr), a dim "Ikke samlet" in its place (2026-11-09:
-- nothing said whose pet you were looking at); greyed while AutoCompanion
-- does the summoning.
--
-- A swap (2026-11-22, 0.10.0, the user: "The swap button should replace 'ta med ut', basically making the 'ta med
-- ut' button label/icon/color situationally reactive"): while the pet out now has a full day, the card of a pet of
-- yours with room today shows "Bytt til" instead, green, with two arrows. The click is the same (it takes the pet
-- out, Summon:SetActive); only the badge tells you it's worth it.
---@class Dyreparken.OutBadge
local OutBadge = {}
ns.OutBadge = OutBadge

local SIZE = 40
local SWAP_COLOR = { 0.45, 0.95, 0.55 }

-- The pet out now, when a swap to key is worth it: the one out has a full day and key has room. Else nil.
function OutBadge.Swap(key)
    local out = ns.Pets:OutKey()
    if not (key and out) or out == key or not ns.Pets:IsOwned(key) then return end
    if ns.Bond:Open(out) or not ns.Bond:Open(key) then return end
    return out
end
OutBadge.SOUNDS = { "IG_MAINMENU_OPTION_CHECKBOX_ON", "IG_CHARACTER_INFO_TAB" }

-- The badge's tooltip for the pet on the card: on (kept out), or not owned.
function OutBadge.Lines(key, on, notOwned)
    if notOwned then
        return { { ns.L["card.notowned"], 0.8, 0.8, 0.8 },
            { ns.T("card.notowned.tip", { pet = key and ns.Pets:NameOfKey(key) or "" }), 1, 1, 1, true } }
    elseif ns.Summon:Deferring() then
        return { { ns.L["card.auto.deferred"], 1, 1, 1, true } }
    end
    local pet = key and ns.Registry:NameOf(key) or ""
    local out = not on and OutBadge.Swap(key)
    if out then
        local today, max = ns.Bond:Today(key)
        return {
            { ns.T("card.out.swap.title", { pet = pet }), SWAP_COLOR[1], SWAP_COLOR[2], SWAP_COLOR[3] },
            { ns.T("card.out.swap.tip", { other = ns.Registry:NameOf(out), pet = pet, n = max - today }), 1, 1, 1, true },
            { ns.T("card.out.swap.click", { pet = pet }), 0.5, 0.8, 0.5, true },
        }
    end
    local lines = {
        { on and ns.T("card.out.on.title", { pet = pet }) or ns.T("card.out.off.title", { pet = pet }), 1, 0.82, 0 },
        { ns.T("card.auto.tip", { pet = pet }), 1, 1, 1, true },
    }
    local active = ns.Summon:ActiveKey()
    if active and active ~= key then
        lines[#lines + 1] = { ns.T("card.auto.now", { pet = ns.Registry:NameOf(active) }), 0.7, 0.7, 0.7, true }
    end
    -- (the pet frame, off by default, was found only in the settings: review 2026-11-19)
    if not ns.PetFrame:Enabled() then lines[#lines + 1] = { ns.L["card.out.frame_hint"], 0.6, 0.8, 1, true } end
    lines[#lines + 1] = { on and ns.L["card.out.on.click"] or ns.T("card.out.off.click", { pet = pet }), 0.5, 0.8, 0.5, true }
    return lines
end

local function Tip(self) ns.ShowTip(self, "ANCHOR_LEFT", OutBadge.Lines(self.card.key, self.on, self.notOwned)) end

-- Turnus' toggle (2026-11-22, 0.10.0, the user: "a toggle on each, small one"): a small badge on "Med deg"'s corner.
OutBadge.TURNUS_SIZE = 20
local TURNUS_GOLD = { 1, 0.82, 0.3 }
function OutBadge.TurnusLines(key)
    local T, pet = ns.Turnus, ns.Registry:NameOf(key)
    local has = T:Has(key)
    local lines = {
        { ns.T(has and "turnus.card.on" or "turnus.card.off", { pet = pet }), TURNUS_GOLD[1], TURNUS_GOLD[2], TURNUS_GOLD[3] },
        { ns.T("turnus.card.tip", { min = T.MIN, max = T.MAX }), 1, 1, 1, true },
    }
    local list = T:List()
    if #list > 0 then
        local names = {}
        for _, k in ipairs(list) do names[#names + 1] = ns.Registry:NameOf(k) end
        lines[#lines + 1] = { ns.T("turnus.card.list", { list = ns.Join(names) }), 0.7, 0.7, 0.7, true }
        if #list < T.MIN then lines[#lines + 1] = { ns.L["turnus.card.more"], 0.7, 0.7, 0.7, true } end
    end
    if not has and T:Full() then
        lines[#lines + 1] = { ns.T("turnus.card.full", { max = T.MAX }), 1, 0.5, 0.4, true }
    else
        lines[#lines + 1] = { ns.T(has and "turnus.card.click.on" or "turnus.card.click.off", { pet = pet }), 0.5, 0.8, 0.5, true }
    end
    return lines
end

local function BuildTurnus(card, b)
    local t = ns.RoundBadge(b:GetParent(), OutBadge.TURNUS_SIZE, { disc = 2, ring = true, icon = ns.Icon("turnus"), iconSize = 0.62 })
    -- On the paw badge's top-right corner, a small one riding it (2026-11-22, the user: left of it, it crowded the
    -- chips and badges on the card's left).
    t:SetPoint("CENTER", b, "TOPRIGHT", -2, -2)
    t:SetFrameLevel(b:GetFrameLevel() + 2)
    t:SetMotionScriptsWhileDisabled(true)
    t:SetScript("OnClick", function(self)
        if not card.key then return end
        if ns.Turnus:Toggle(card.key) then ns.PlayFirstSound(OutBadge.SOUNDS) end
        OutBadge:Update(card, card.key)
        if GameTooltip:IsOwned(self) then ns.ShowTip(self, "ANCHOR_LEFT", OutBadge.TurnusLines(card.key)) end
        if ns.Story:IsOpen() then ns.Story:Redraw() end -- (Flokk lists it)
    end)
    ns.SetTip(t, "ANCHOR_LEFT", function() return card.key and OutBadge.TurnusLines(card.key) end)
    t:Hide()
    return t
end

function OutBadge:Build(card, c)
    local b = ns.RoundBadge(c, SIZE, { disc = 4, ring = true, icon = ns.Icon("paw"), iconSize = 0.55 })
    b.paw = b.icon
    b.card = card
    b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -12)
    b:SetFrameLevel(c:GetFrameLevel() + 30) -- over the model and the decor's corners
    b.glow = b:CreateTexture(nil, "BACKGROUND")
    b.glow:SetTexture(ns.Icon("dot"))
    b.glow:SetBlendMode("ADD")
    b.glow:SetVertexColor(1, 0.75, 0.3, 1)
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(SIZE * 1.9, SIZE * 1.9)
    b.glow.pulse = ns.Anim.Pulse(b.glow, 0.35, 0.8, 2.6)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
    b.label:SetShadowOffset(1, -1)

    b:SetMotionScriptsWhileDisabled(true)
    b:SetScript("OnClick", function(self)
        if not card.key or self.notOwned then return end
        local on = not self.on
        ns.Summon:SetActive(card.key, on)
        if on then
            -- A burst: a ring growing out of the badge.
            self.burst = ns.Fx:Emit({ parent = self, pool = 1, anchor = { self, "CENTER", 0, 0 } }, { { tex = ns.Icon("ring"),
                add = true, color = { 1, 0.85, 0.4 }, size = SIZE, fadeIn = { 1, 1 }, fadeOut = { 1, 0, 0.6 },
                grow = { 2.2, 0.6, "OUT" } } })[1]
            ns.PlayFirstSound(OutBadge.SOUNDS)
        end
        ns.JournalUI:Refresh()
        if GameTooltip:IsOwned(self) then Tip(self) end
    end)
    b:SetScript("OnEnter", Tip)
    b:SetScript("OnLeave", ns.HideTip)
    b:Hide()
    card.auto = b
    b.turnus = BuildTurnus(card, b)
end

local function UpdateTurnus(t, key, show)
    if not show then return t:Hide() end
    local on = ns.Turnus:Has(key)
    t.ring:SetDesaturated(not on)
    t.ring:SetAlpha(on and 1 or 0.6)
    if on then t.icon:SetVertexColor(TURNUS_GOLD[1], TURNUS_GOLD[2], TURNUS_GOLD[3], 1)
    else t.icon:SetVertexColor(0.6, 0.6, 0.6, 0.8) end
    t:SetEnabled(on or not ns.Turnus:Full())
    t:Show()
end

-- The pet on the card: is it the one kept out?
function OutBadge:Update(card, key)
    local b = card.auto
    if not b then return end
    b.on = false
    b.glow.pulse:Stop()
    if not key then UpdateTurnus(b.turnus, key, false); return b:Hide() end
    b.notOwned = not ns.Pets:IsOwned(key)
    UpdateTurnus(b.turnus, key, not b.notOwned and not ns.Summon:Deferring())
    if b.notOwned then
        b:SetEnabled(false)
        b.ring:SetDesaturated(true); b.ring:SetAlpha(0.35)
        b.paw:SetVertexColor(0.45, 0.45, 0.45, 0.5)
        b.label:SetText(ns.L["card.notowned"]); b.label:SetTextColor(0.55, 0.55, 0.55)
        b.glow:Hide()
        return b:Show()
    end
    local deferring = ns.Summon:Deferring()
    local on = not deferring and ns.Summon:ActiveKey() == key
    local swap = not on and not deferring and OutBadge.Swap(key) and true or false
    b.on, b.swap = on, swap
    b:SetEnabled(not deferring)
    b.paw:SetTexture(ns.Icon(swap and "swap" or "paw"))
    b.ring:SetDesaturated(not on)
    b.ring:SetAlpha((on or swap) and 1 or 0.6)
    if swap then b.ring:SetVertexColor(SWAP_COLOR[1], SWAP_COLOR[2], SWAP_COLOR[3]) else b.ring:SetVertexColor(1, 1, 1) end
    if on then b.paw:SetVertexColor(1, 0.82, 0.3, 1)
    elseif swap then b.paw:SetVertexColor(SWAP_COLOR[1], SWAP_COLOR[2], SWAP_COLOR[3], 1)
    else b.paw:SetVertexColor(0.6, 0.6, 0.6, 0.8) end
    b.label:SetText(on and ns.L["card.out.on"] or swap and ns.L["card.out.swap"] or ns.L["card.out.off"])
    if on then b.label:SetTextColor(1, 0.82, 0)
    elseif swap then b.label:SetTextColor(SWAP_COLOR[1], SWAP_COLOR[2], SWAP_COLOR[3])
    else b.label:SetTextColor(0.6, 0.6, 0.6) end
    b.glow:SetShown(on or swap)
    if swap then b.glow:SetVertexColor(SWAP_COLOR[1], SWAP_COLOR[2], SWAP_COLOR[3], 1) else b.glow:SetVertexColor(1, 0.75, 0.3, 1) end
    if on or swap then b.glow.pulse:Play() else b.glow.pulse:Stop() end
    b:Show()
end

ns.Card.Register{ id = "outbadge",
    build = function(card, c) OutBadge:Build(card, c) end,
    update = function(card, key) OutBadge:Update(card, key) end,
    pause = function(card) OutBadge:Update(card, nil) end, -- (over the model's level: it'd show through our page)
    stop = function(card) if card.auto then card.auto.glow.pulse:Stop() end end, -- (Update starts it again)
}
