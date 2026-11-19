---@class Dyreparken
local ns = select(2, ...)

-- A pet's personality as a row of round badges on its card, and the panel's tabs with all of it
-- (2026-11-19, the user: more traits, a third at level 7, moods and temperaments are coming; two lines of
-- text on the card had no room left). The row: its traits (their particle in their color, a gold ring),
-- what it likes (a green ring; a minor one dimmed), the dislikes found out (a red ring) and a "?" for any
-- still secret. Each badge explains itself on hover; a click opens the panel beside the window (Story.lua)
-- on "Personlighet", which tells all of it in words. "Bånd" there lists everyone's bond with the pet.
-- Room is left at the row's end for a mood or temperament, next to each other (the user, the same day).
---@class Dyreparken.AboutPet
local About = {}
ns.AboutPet = About

local L = ns.L

------------------------------------------------------------------------------
-- Icons
------------------------------------------------------------------------------
-- An activity's icon: its chip's (Stats), else its mark (one of our particle textures, Activity.KINDS);
-- the second value says it's ours (white, to tint, and no crop).
function About.ActIcon(act)
    if ns.Stats.ICONS[act] then return ns.Stats.Icon(act), false end
    local k = ns.Activity.KIND[act]
    return ns.Icon(k and k.mark or "heart"), true
end

local GOLD = { 1, 0.85, 0.4 }
-- A trait's icon: its particle (Decor.TRAITS, or the row's own icon where that's a dot) and color.
function About.TraitIcon(trait)
    local d = ns.Decor.TRAITS[trait.id] or {}
    local kind = ns.Decor.KINDS[d.kind or ""]
    local color = type(d.color) == "table" and d.color or GOLD
    return ns.Icon(d.icon or (kind and kind.tex) or "sparkle"), color
end

------------------------------------------------------------------------------
-- The row's badges, as data
------------------------------------------------------------------------------
-- { kind = "trait" | "like" | "dislike" | "secret", trait, act, minor, n }, in the row's order; nil while
-- the personality is a surprise (Personality:Known).
function About.For(key)
    local P = ns.Personality
    if not (key and P:Known(key)) then return nil end
    local list = {}
    for _, t in ipairs(P:Traits(key)) do list[#list + 1] = { kind = "trait", trait = t } end
    local _, likes = P:Of(key)
    for _, act in ipairs(likes) do list[#list + 1] = { kind = "like", act = act } end
    local minorLike = P:MinorLike(key)
    if minorLike then list[#list + 1] = { kind = "like", act = minorLike, minor = true } end
    -- The dislikes seen happen, the major ones first (Personality:DislikedWords' rule), then a "?" for the rest.
    local seen = ns.DB.char.dislikes[key] or {}
    local set, all = P:Dislikes(key)
    local shown = 0
    for _, minor in ipairs({ false, true }) do
        for _, act in ipairs(all) do
            if seen[act] and (set[act] == "minor") == minor then
                list[#list + 1] = { kind = "dislike", act = act, minor = minor or nil }
                shown = shown + 1
            end
        end
    end
    if #all > shown then list[#list + 1] = { kind = "secret", n = #all - shown } end
    return list
end

local function Cap(s) return (s:sub(1, 1):upper() .. s:sub(2)) end

-- A badge's tooltip.
function About.Lines(key, b)
    local P, pet = ns.Personality, ns.Registry:NameOf(key)
    local lines
    if b.kind == "trait" then
        lines = { { b.trait.name, 1, 0.82, 0 }, { b.trait.desc, 1, 1, 1, true }, { P:Effect(b.trait), 0.9, 0.75, 0.3, true } }
    elseif b.kind == "like" then
        lines = { { ns.T("card.likes", { list = P.NOUN[b.act] }), 0.5, 0.85, 0.5 },
            { P:LikeEffect(b.act, b.minor), 1, 1, 1, true } }
        if b.minor then lines[3] = { ns.T("about.minor.like", { pet = pet }), 0.6, 0.6, 0.6, true } end
    elseif b.kind == "dislike" then
        lines = { { Cap(ns.T("card.dislikes", { list = P.NOUN[b.act] })), 0.9, 0.5, 0.45 },
            { ns.T("about.dislike.tip", { pet = pet }), 1, 1, 1, true } }
        if b.minor then lines[3] = { ns.T("about.minor.dislike", { pet = pet }), 0.6, 0.6, 0.6, true } end
    else
        lines = { { ns.T(b.n == 1 and "card.dislikes.secret_one" or "card.dislikes.secret", { pet = pet, n = b.n }),
            0.9, 0.6, 0.55, true } }
    end
    lines[#lines + 1] = { ns.T("about.click", { pet = pet }), 0.6, 0.6, 0.6 }
    return lines
end

------------------------------------------------------------------------------
-- The row on the card
------------------------------------------------------------------------------
About.SIZE = { trait = 26, other = 22 } -- (20 was too small to tell the icons apart, seen in game 2026-11-19)
About.GAP, About.GROUP_GAP = 3, 9
local RING = { trait = { 1, 1, 1 }, like = { 0.45, 0.95, 0.45 }, dislike = { 1, 0.4, 0.35 }, secret = { 1, 0.4, 0.35 } }
local CREAM = { 1, 0.92, 0.78 }

local function NewBadge(row, card)
    local b = ns.RoundBadge(row, About.SIZE.other, { disc = 2, ring = true, ringOver = true, icon = ns.Icon("dot"),
        iconSize = 0.62, hover = { 1, 0.85, 0.5, 0.45 } })
    b.q = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.q:SetPoint("CENTER", b, "CENTER", 1, 0)
    b.q:SetText("?")
    b.q:Hide()
    b:SetScript("OnClick", function() if card.key then ns.Story:Show(card.key, "personality") end end)
    ns.SetTip(b, "ANCHOR_TOP", function(self) return card.key and self.data and About.Lines(card.key, self.data) end)
    return b
end

function About:Build(card)
    local panel = card.panel
    local row = CreateFrame("Frame", nil, panel)
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, ns.JournalUI.ROW_Y.personality + 1)
    row:SetSize(10, About.SIZE.trait)
    row:SetFrameLevel(panel:GetFrameLevel() + 4)
    row.badges = {}
    row.card = card
    card.badges = row
    row:Hide()
end

-- One badge drawn as d: its icon, ring and size.
local function Draw(b, d)
    b.data = d
    local size = d.kind == "trait" and About.SIZE.trait or About.SIZE.other
    b:SetSize(size, size)
    b.bg:SetSize(size - 2, size - 2)
    b.icon:SetSize(size * 0.68, size * 0.68)
    local ring = RING[d.kind]
    b.ring:SetDesaturated(d.kind ~= "trait")
    b.ring:SetVertexColor(ring[1], ring[2], ring[3], 1)
    b.q:SetShown(d.kind == "secret")
    b.icon:SetShown(d.kind ~= "secret")
    if d.kind == "trait" then
        local tex, color = About.TraitIcon(d.trait)
        b.icon:SetTexture(tex)
        b.icon:SetTexCoord(0, 1, 0, 1)
        b.icon:SetVertexColor(color[1], color[2], color[3], 1)
        b.icon:SetSize(size * 0.74, size * 0.74)
    elseif d.act then
        local tex, ours = About.ActIcon(d.act)
        b.icon:SetTexture(tex)
        if ours then
            b.icon:SetTexCoord(0, 1, 0, 1)
            b.icon:SetVertexColor(CREAM[1], CREAM[2], CREAM[3], 1)
        else
            b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            b.icon:SetVertexColor(1, 1, 1, 1)
        end
    end
    b:SetAlpha(d.minor and 0.55 or 1) -- (lesser, as the likes line had them dimmed)
    return size
end

function About:Update(card, key)
    local row = card.badges
    if not row then return end
    local list = About.For(key)
    if not list then row:Hide(); return end
    local x, last = 0, nil
    for i, d in ipairs(list) do
        local b = row.badges[i] or NewBadge(row, card)
        row.badges[i] = b
        local size = Draw(b, d)
        if last and last ~= d.kind then x = x + About.GROUP_GAP - About.GAP end
        b:ClearAllPoints()
        b:SetPoint("LEFT", row, "LEFT", x, 0)
        b:Show()
        x = x + size + About.GAP
        last = d.kind == "secret" and "dislike" or d.kind
    end
    for i = #list + 1, #row.badges do row.badges[i]:Hide(); row.badges[i].data = nil end
    row:SetWidth(math.max(1, x - About.GAP))
    row:Show()
end

ns.Card.Register{ id = "badges", still = true, -- (badges, no animation)
    build = function(card) About:Build(card) end,
    update = function(card, key) About:Update(card, key) end,
}

------------------------------------------------------------------------------
-- The panel's tabs
------------------------------------------------------------------------------
-- A page's lines, top to bottom: { head = text } or { icon, ours, color, title, tc, text, dim }.
local ICON_W, PAD = 20, 6

local function Item(page, i)
    page.items = page.items or {}
    local it = page.items[i]
    if it then return it end
    it = {}
    it.icon = page:CreateTexture(nil, "ARTWORK")
    it.icon:SetSize(ICON_W - 4, ICON_W - 4)
    it.title = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    it.title:SetJustifyH("LEFT")
    it.text = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    it.text:SetJustifyH("LEFT")
    it.text:SetWordWrap(true)
    page.items[i] = it
    return it
end

local function Render(page, width, entries)
    local y = 0
    for i, e in ipairs(entries) do
        local it = Item(page, i)
        it.title:ClearAllPoints(); it.text:ClearAllPoints(); it.icon:ClearAllPoints()
        local alpha = e.dim and 0.6 or 1
        if e.head then
            if i > 1 then y = y + PAD end
            it.icon:Hide(); it.text:Hide()
            it.title:SetFontObject("GameFontNormal")
            it.title:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
            it.title:SetWidth(width)
            it.title:SetText(e.head)
            it.title:SetTextColor(1, 0.82, 0, 1)
            it.title:Show()
            y = y + (it.title:GetStringHeight() or 14) + 3
        else
            local x = e.icon and ICON_W + 4 or 0
            if e.icon then
                it.icon:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -y)
                it.icon:SetTexture(e.icon)
                if e.ours then it.icon:SetTexCoord(0, 1, 0, 1) else it.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
                local c = e.color or { 1, 1, 1 }
                it.icon:SetDesaturated(e.grey == true) -- (a hint, not a dislike: the red "?" read as one)
                it.icon:SetVertexColor(c[1], c[2], c[3], alpha)
                it.icon:Show()
            else
                it.icon:Hide()
            end
            local top = y
            if e.title then
                it.title:SetFontObject("GameFontHighlight")
                it.title:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
                it.title:SetWidth(width - x)
                it.title:SetText(e.title)
                local c = e.tc or { 1, 1, 1 }
                it.title:SetTextColor(c[1], c[2], c[3], alpha)
                it.title:Show()
                y = y + (it.title:GetStringHeight() or 14) + 1
            else
                it.title:Hide()
            end
            if e.text then
                it.text:SetPoint("TOPLEFT", page, "TOPLEFT", x, -y)
                it.text:SetWidth(width - x)
                it.text:SetText(e.text)
                local c = e.textColor or { 0.85, 0.85, 0.85 }
                it.text:SetTextColor(c[1], c[2], c[3], alpha)
                it.text:Show()
                y = y + (it.text:GetStringHeight() or 12)
            else
                it.text:Hide()
            end
            if e.icon then y = math.max(y, top + ICON_W - 4) end
            y = y + PAD
        end
    end
    for i = #entries + 1, #(page.items or {}) do
        local it = page.items[i]
        it.icon:Hide(); it.title:Hide(); it.text:Hide()
    end
    return y
end
About.Render = Render

local GREEN, RED, GREY = { 0.5, 0.85, 0.5 }, { 0.9, 0.5, 0.45 }, { 0.6, 0.6, 0.6 }
local QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Personlighet: every trait, like and dislike in words (the row's badges, and what they do).
function About.PersonalityEntries(key)
    local P, pet = ns.Personality, ns.Registry:NameOf(key)
    if not P:Known(key) then
        return { { head = L["personality.unknown"] }, { text = L["personality.unknown.tip"] } }
    end
    local out = {}
    local function Add(e) out[#out + 1] = e end
    Add({ head = L["about.traits"] })
    for _, t in ipairs(P:Traits(key)) do
        local tex, color = About.TraitIcon(t)
        -- (a trait that gives a like: its points are on the like's own line below, so only what it means here;
        -- one with a moment or a day of its own says what that does: seen in game 2026-11-19, said twice)
        local liked = t.like and not (t.when or t.day)
        Add({ icon = tex, ours = true, color = color, title = t.name, tc = { 1, 0.82, 0 },
            text = liked and t.desc or (t.desc .. "\n" .. P:Effect(t)) })
    end
    local what, level = P:NextUnlock(key)
    local unlock = what and { icon = QUESTION, grey = true, text = ns.T("card.unlock." .. what,
        { level = ns.Bond.LEVELS[level][2], pet = pet }), textColor = GREY }
    if what == "trait" then Add(unlock) end -- (the third trait, at level 7)
    local list = About.For(key)
    local function Act(d, tc)
        local tex, ours = About.ActIcon(d.act)
        return tex, ours, ours and CREAM or nil, tc
    end
    Add({ head = L["about.likes"] })
    for _, d in ipairs(list) do
        if d.kind == "like" then
            local tex, ours, color = Act(d)
            Add({ icon = tex, ours = ours, color = color, dim = d.minor,
                title = Cap(P.NOUN[d.act]) .. (d.minor and (" · " .. L["about.minor"]) or ""), tc = GREEN,
                text = P:LikeEffect(d.act, d.minor) })
        end
    end
    if what == "like" then Add(unlock) end
    local dislikes = {}
    for _, d in ipairs(list) do
        if d.kind == "dislike" then
            local tex, ours, color = Act(d)
            dislikes[#dislikes + 1] = { icon = tex, ours = ours, color = color, dim = d.minor,
                title = Cap(P.NOUN[d.act]) .. (d.minor and (" · " .. L["about.minor"]) or ""), tc = RED,
                text = ns.T("about.dislike.tip", { pet = pet }) }
        elseif d.kind == "secret" then
            dislikes[#dislikes + 1] = { icon = QUESTION, textColor = { 0.9, 0.6, 0.55 },
                text = ns.T(d.n == 1 and "card.dislikes.secret_one" or "card.dislikes.secret", { pet = pet, n = d.n }) }
        end
    end
    if what == "dislike" then dislikes[#dislikes + 1] = unlock end
    if #dislikes > 0 then
        Add({ head = L["about.dislikes"] })
        for _, e in ipairs(dislikes) do Add(e) end
    end
    Add({ text = L["card.personality.hint"], textColor = GREY })
    return out
end

-- Bånd: everyone's bond with the pet the guild knows of (g.life: members only), strongest first. Bonds with a
-- pet nobody adopted come from their carers' own messages, so they may be a little behind (CLAUDE.md).
function About.BondEntries(key)
    local g, pet = ns.DB:Guild(), ns.Registry:NameOf(key)
    local holder, me = ns.Registry:Holder(key), ns.PlayerKey()
    local list = {}
    for carer, e in pairs(g and g.life[key] or {}) do
        if type(e) == "table" and type(e.p) == "number" and e.p > 0 then list[#list + 1] = { carer = carer, p = e.p } end
    end
    table.sort(list, function(a, b)
        if a.p ~= b.p then return a.p > b.p end
        return a.carer < b.carer
    end)
    if #list == 0 then return { { text = ns.T("about.bonds.none", { pet = pet }), textColor = GREY } } end
    local out = { { text = ns.T("about.bonds.intro", { pet = pet }), textColor = GREY } }
    for _, b in ipairs(list) do
        local level, name = ns.Bond:Level(b.p)
        local home = b.carer == holder
        local text = ns.T("about.bonds.line", { level = name, n = level, p = b.p })
        if home then text = text .. " · " .. ns.T("about.bonds.home", { pet = pet }) end
        out[#out + 1] = { icon = ns.Icon(home and "house" or "heart"), ours = true,
            color = home and { 1, 0.82, 0.3 } or { 1, 0.55, 0.65 },
            title = b.carer == me and L["about.bonds.you"] or b.carer, tc = b.carer == me and { 1, 0.82, 0 } or nil,
            text = text }
    end
    return out
end

ns.Story:AddTab({ id = "personality", title = L["about.tab.personality"],
    draw = function(page, key, width) return Render(page, width, About.PersonalityEntries(key)) end })
ns.Story:AddTab({ id = "bonds", title = L["about.tab.bonds"],
    draw = function(page, key, width) return Render(page, width, About.BondEntries(key)) end })
