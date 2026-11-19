---@class Dyreparken
local ns = select(2, ...)

-- "Parken": the park map, a page of the Collections window (a SidePage,
-- see Core/SidePage.lua), next to the achievements.
--
-- Every companion in Forever's journal
-- (Data/Companions.lua) as an icon: in color when it has a home, grey when
-- it's looking for one, a gold glow on yours, and a green tick on free ones
-- you own (you could adopt them). Hovering one tells its story; a click opens
-- its card on the Pets page (2026-11-09: the journal's list holds only the
-- pets you own, so this is how you see the rest). Only when the Pets page is
-- the one under ours: switching tabs is Blizzard's SetTab, which we never
-- call (Core/SidePage.lua: taint).
--
-- A search box and two toggles (2026-11-14, the user): "Trenger et hjem" (nobody has adopted it) and "Kan
-- adopteres" (that, and you own it). What doesn't match is dimmed in place, not hidden, so the park keeps
-- its shape (the user). The search reads a pet's name, nickname, who has it (from the start of the name only,
-- 2026-11-16) and its families; not its source
-- (2026-11-14, the user: searching it was a mistake). The tooltip says where a pet comes from
-- (Data/Companions.lua: s, w).
--
-- Portraits and the spotlight (2026-11-15, the user picked them): each pet is its own face, a round
-- portrait drawn from its model (Pets:Portrait; a third of the journal's icons were cages, crates and
-- whistles), in a ring of its family's color, deeper as its holder's bond grows, with a glint and a
-- shine at the higher levels (Park.Ring), gold with a glow on yours. Under the map, a stage: today's pet (Bonds:PetOfTheDay) as a
-- live model on its card's backdrop (Scenes), with its name, home and personality; the pet under the
-- mouse takes its place while hovered. A click there opens its card, as an icon's does. The stage's
-- camera runs only a moment after a change (as the pet frame's: PF:Camera), so an open park costs nothing.
--
-- Enclosures (2026-11-15, the user: "group pets by families, with dynamic enclosures ... stacked together
-- like tetris with irregular borders if needed. Almost like a flood fill"): still one grid, but each family
-- (its first, as its ring's: Scenes:Families) is a run of cells along one path through it (Park.Path), so
-- every family is one piece, its own shape; a tint of its color under its cells and a fence on every
-- edge it shares with another family or the outside (Park.Fences). In Scenes.ORDER, those without a family
-- last; by name within one.
--
-- The enclosures' extras (2026-11-15, the user: "I like all 5"): a wooden sign on each one's first corner
-- with its family's mark (Park.SIGN), its name and homes on hover, a click shows only that family
-- (Park.filter.family; again: all; its mark is the card's ambience, Decor.Mark); the pointer's family brightens its tint (Park.Highlight); a family the
-- filter leaves empty fades its tint; the grid's empty cells are a bit of park (Park.DECOR: a pond, trees...).
--
-- Unknown pets (2026-11-15, the user): a pet nobody in the guild owns (Owners:Any, X-Protocol 11) is a small
-- question mark in its place, not a dark portrait ("the park will look less noisy"); its tooltip names
-- nothing, a click wiggles it (a tease), and the stage and the search pass it by. "Skjul ukjente dyr" in
-- the settings (hideUnknown, on by default) shows them as before.
--
-- Everything comes from the registry and Owners; nothing is sent.
-- Loads after Achievements/Page.lua, so its tab comes second.
---@class Dyreparken.ParkPage
---@field override? { hour: integer, month: integer } the garden's hour and month (Dev/: /dp probe garden; a release leaves it nil)
local Park = {}
ns.ParkPage = Park

-- (36 until the enclosures, 2026-11-15: their fences ran over the faces' rims; a wooden fence on the line
-- between two cells, 2 px into each, leaves a pixel at 34)
local CELL, ICON_SIZE = 40, 34
-- "Can be adopted": the list's mark, the green house (review 2026-11-19: a ready check's tick here, a house in the
-- list, and the same tick for "fullt for i dag" on the bond bar).
local FREE_RGB = { 0.45, 0.9, 0.45 }
local function FreeIcon(size, rgb)
    rgb = rgb or FREE_RGB
    return ("|T%s:%d:%d:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(ns.Icon("house"), size, size,
        math.floor(rgb[1] * 255), math.floor(rgb[2] * 255), math.floor(rgb[3] * 255))
end

local sp, page, child, spot
local cells = {}
local signs, plots = {}, {} -- family -> its sign; the garden's cells, in order
local spotT, cameraT = ns.Timers(), ns.Timers()
-- (200 until 2026-11-15: the six rows of the map then overflowed by a few pixels, and a scrollbar showed
-- with nothing to scroll)
-- (180 until 2026-11-16, the user: "shrink the highlight stage by 10-15% to make more room for the map": 13%
-- smaller, its view and shadow with it, so the pet stands as before, a little smaller)
Park.SPOT_H = 156        -- the stage under the map
Park.SPOT_LINES = 4      -- the stage's lines beside the pet, at most (the rest: the icon's tooltip)
Park.NAME_FONTS = { "GameFontNormalHuge", "GameFontNormalLarge", "GameFontNormal" } -- the stage's name, biggest first
Park.SCENE_W = 230       -- its model's part, at the left
Park.SIDE_W = 200        -- the guild's records and the legend, at the right (2026-11-16, the user: moved in from over the map)
-- The model's view in the stage: the pet frame's (0, 0, 84, -50 on 170 px) a third larger, so the pet
-- stands as there, bigger (2026-11-15, the first look: small and off to the side). Tuned by eye.
-- (2026-11-16, the user: the pets "lowered (slightly)" once they stood on their feet: the view 10 lower, as tall;
-- then all of it 13% smaller with the stage: 64, -78 on 180 px)
Park.VIEW = { 0, 0, 56, -68 }
-- The card's shadow under the pet (2026-11-16, the user: "add the same shadow from the pet journal"): pets
-- stand on their feet now, every scene's floor set by eye on the card's shadow (Data/PetScenes.lua), so here
-- too they all stand on one line. Where it is, by eye from the user's screenshots: feet 27 to 33 up the
-- scene, a kitten lying 60 wide (worked out from the card's view it came out three times too big and far too
-- high: "way too big and just looks silly"); then up to meet them, the pets 10 lower (the user: "the model
-- lowered (slightly) and the shadow moved further up"). Centered under the pet: y is its middle, up from the
-- scene's bottom.
Park.SHADOW = { y = 35, w = 78, h = 14 } -- (40, 90, 16 on the 180 px stage)
Park.SPOT_BACK = 1       -- seconds after the mouse leaves an icon, today's pet again
Park.CAMERA_FOR = 2      -- the stage's camera runs this long after a change (PF.CAMERA_FOR)
-- The filter: { text = lower-cased search, free = bool, adopt = bool }, for this session.
Park.filter = { text = "", free = false, adopt = false, family = nil } -- (family: a sign clicked)
Park.DIM = 0.12

-- Lower case, the Norwegian letters too (string.lower leaves UTF-8's alone).
local UPPER = { ["Æ"] = "æ", ["Ø"] = "ø", ["Å"] = "å", ["É"] = "é" }
function Park.Fold(text)
    text = tostring(text or ""):lower()
    for up, low in pairs(UPPER) do text = text:gsub(up, low) end
    return text
end

-- Where a pet comes from, as its tooltip line, or nil (no curation row).
function Park.Source(key)
    local sid = ns.Pets:SpeciesOfKey(key)
    local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
    if type(data) ~= "table" or not data.s then return nil end
    local how = ns.L["source." .. data.s]
    local where = ns.Strings["source.where." .. sid] or data.w
    if where then return ns.T("source.line.where", { how = how, where = where }) end
    return ns.T("source.line", { how = how })
end

-- Everything the search looks through for a pet anywhere in it, folded: its name, nickname and families. Who
-- has it is matched only from the start of their name (Park.Matches).
function Park.Haystack(key)
    local parts = { ns.Pets:NameOfKey(key) or "" }
    parts[#parts + 1] = ns.Registry:Nickname(key) or ""
    local sid = ns.Pets:SpeciesOfKey(key)
    local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
    local names = ns.AchTexts.generic.families
    for _, tag in ipairs(type(data) == "table" and data.t or {}) do parts[#parts + 1] = names[tag] or "" end
    return Park.Fold(table.concat(parts, "\31"))
end

-- A pet nobody in the guild has, shown as a question mark (the header).
function Park.Unknown(key)
    return ns.Settings:On("hideUnknown") and not ns.Owners:Any(key)
end

-- A pet's enclosure: its first family (as its ring's), else "default".
function Park.FamilyOf(key) return ns.Scenes:Families(key)[1] or "default" end

-- Whether a pet passes the filter (owned: Pets:Owned()).
function Park.Matches(key, filter, owned)
    filter = filter or Park.filter
    if filter.family and Park.FamilyOf(key) ~= filter.family then return false end
    local owner = ns.Registry:Holder(key)
    if (filter.free or filter.adopt) and owner then return false end
    if filter.adopt and not (owned or ns.Pets:Owned())[key] then return false end
    local text = filter.text or ""
    if text ~= "" and Park.Unknown(key) then return false end -- (a search must not tell which "?" is which)
    if text == "" or Park.Haystack(key):find(text, 1, true) then return true end
    -- Who has it, only from the start of their name (2026-11-16, the user: "as" found the prairie dog by its
    -- holder Hjelp Plask; "only from the first name on (e.g. not 'pla')"): "hj", "hjelp pl" find it.
    return owner ~= nil and Park.Fold(owner):sub(1, #text) == text
end

function Park.Filtering(filter)
    filter = filter or Park.filter
    return filter.free or filter.adopt or (filter.text or "") ~= "" or filter.family ~= nil
end

-- The park's records as lines, from the current holders.
function Park:Records(now)
    now = now or ns.Now()
    local R = ns.Registry
    local oldest, newest
    local families, names = {}, ns.AchTexts.generic.families
    for key, owner in pairs(R:Holders()) do
        local _, r = R:Holder(key)
        if not oldest or r.at < oldest.at or (r.at == oldest.at and key < oldest.key) then
            oldest = { key = key, owner = owner, at = r.at }
        end
        if not newest or r.at > newest.at or (r.at == newest.at and key < newest.key) then
            newest = { key = key, owner = owner, at = r.at }
        end
        local sid = ns.Pets:SpeciesOfKey(key)
        local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
        for _, tag in ipairs(type(data) == "table" and data.t or {}) do
            if names[tag] then families[tag] = (families[tag] or 0) + 1 end
        end
    end
    if not oldest then
        local empty = IsInGuild() and ns.L["park.empty"] or ns.L["park.no_guild"]
        return { empty, short = { { ns.L["park.rec.empty"], "", empty } } }
    end
    -- The lines, and for the stage's side a short form of each: { label, value, the line in full (its tooltip) }.
    local lines, short = {}, {}
    lines.short = short
    local function Add(label, value, line)
        lines[#lines + 1] = line
        short[#short + 1] = { ns.L[label], value, line }
    end
    local oldName = ns.Registry:NameOf(oldest.key)
    Add("park.rec.oldest", ns.T("park.rec.who", { pet = oldName, owner = oldest.owner }),
        ns.T("park.oldest", { pet = oldName, owner = oldest.owner, time = ns.CaredFor(oldest.at, now) }))
    local best, bestN
    for tag, n in pairs(families) do
        if not best or n > bestN or (n == bestN and names[tag] < names[best]) then best, bestN = tag, n end
    end
    if best then
        Add("park.rec.family", ns.T("park.rec.families", { family = names[best], n = bestN }),
            ns.T("park.family", { family = names[best], n = bestN }))
    end
    -- With one pet in the park, it's both the oldest and the newest: once is enough.
    if newest.key ~= oldest.key then
        local home = ns.Home(newest.owner, newest.at, now)
        local newName = ns.Registry:NameOf(newest.key)
        Add("park.rec.newest", ns.T("park.rec.who", { pet = newName, owner = newest.owner }),
            ns.T("park.newest", { pet = newName, home = home:sub(1, 1):lower() .. home:sub(2) }))
    end
    return lines
end

-- An icon's tooltip: the pet's nickname over its species, then the list's lines (JournalList.PetLines),
-- then whether you could adopt it and what a click does.
function Park.Lines(key)
    if Park.Unknown(key) then
        return { { ns.L["park.unknown"], 0.6, 0.6, 0.6 }, { ns.L["park.unknown.tip"], 1, 1, 1, true } }
    end
    local nick = ns.Registry:Nickname(key)
    local lines = { { nick or ns.Pets:NameOfKey(key) } }
    if nick then lines[2] = { ns.Pets:NameOfKey(key), 0.7, 0.7, 0.7 } end
    for _, l in ipairs(ns.JournalList.PetLines(key, "park.free")) do lines[#lines + 1] = l end
    -- Who else has one, as under the card's home line (Owners:Line; 2026-11-15, the user)
    local others = ns.Owners:Line(key)
    if others then lines[#lines + 1] = { others, 0.8, 0.76, 0.66, true } end
    local source = Park.Source(key)
    if source then lines[#lines + 1] = { source, 0.6, 0.8, 1 } end
    local owner = ns.Registry:Holder(key)
    if owner ~= ns.PlayerKey() and ns.Pets:IsOwned(key) then
        lines[#lines + 1] = { ns.L[owner and "park.also_yours" or "park.can_adopt"], 1, 1, 1 }
    end
    if ns.Pets:SpeciesOfKey(key) then
        lines[#lines + 1] = { ns.L[Park:CanShow() and "park.click" or "park.click.pets"], 0.6, 0.6, 0.6, true }
    end
    return lines
end

-- The Pets page is under ours (shown, only covered), so its card can show.
function Park:CanShow()
    return PetJournal ~= nil and PetJournal:IsShown() == true
end

-- A click on an icon: leave the park, show that pet's card. In combat it's remembered, with a hint
-- (one a burst), and shows once the fight is over if the Pets page is still up (JournalUI:AfterCombat).
Park.HINT_EVERY = 10
function Park:Show(key)
    local sid = ns.Pets:SpeciesOfKey(key)
    if not sid or not self:CanShow() then return end
    if ns.InCombat() then
        ns.JournalUI:ShowWhenOpen(sid)
        local now = GetTime()
        if ns.Config.CLICK_HINTS and (not self.hintAt or now - self.hintAt >= self.HINT_EVERY) then
            self.hintAt = now
            ns.Print(ns.T("park.combat_hint", { pet = ns.Registry:NameOf(key) }))
        end
        return
    end
    ns.SidePage:CloseAll()
    ns.JournalUI:ShowSpecies(sid)
end

-- A cell's share of an enclosure on frame c (a pet's cell, or a plot of the garden): its tint (Park.Pen)
-- over the whole square, and its fences (Park.Fences): a rail on the line, half in this cell and half in
-- the next (clear of the face by a pixel), a post at each end (its corners, where the round face doesn't reach).
function Park.Enclosure(c)
    c.pen = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    c.pen:SetTexture(ns.Icon("turf"))
    c.pen:SetSize(CELL, CELL)
    c.pen:SetPoint("CENTER")
    local h, t = CELL / 2, Park.FENCE
    c.fences, c.posts = {}, {}
    for side, at in pairs({ top = { 0, h }, bottom = { 0, -h }, left = { -h, 0 }, right = { h, 0 } }) do
        local r = c:CreateTexture(nil, "BACKGROUND", nil, -6)
        r:SetTexture(ns.Icon("plank"), "REPEAT", "CLAMP")
        local across = side == "top" or side == "bottom"
        r:SetSize(across and CELL or t, across and t or CELL)
        r:SetPoint("CENTER", c, "CENTER", at[1], at[2])
        local n = CELL / Park.PLANK -- (tiles along it; on the sides turned a quarter: grain along the rail)
        if across then r:SetTexCoord(0, n, 0, 1) else r:SetTexCoord(0, 1, n, 1, 0, 0, n, 0) end
        c.fences[side] = r
    end
    for corner, at in pairs({ tl = { -h, h }, tr = { h, h }, bl = { -h, -h }, br = { h, -h } }) do
        local p = c:CreateTexture(nil, "BACKGROUND", nil, -5)
        p:SetTexture(ns.Icon("post"))
        p:SetSize(Park.POST, Park.POST)
        p:SetPoint("CENTER", c, "CENTER", at[1], at[2])
        c.posts[corner] = p
    end
end

local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function NewCell()
    local c = CreateFrame("Button", nil, child)
    -- The whole cell takes the mouse, the face drawn in its middle: between two faces is still the enclosure
    -- (2026-11-15, the user: it didn't light up "if you hover between the pets").
    c:SetSize(CELL, CELL)
    -- Three round layers, each cut by its own mask: the ring (a colored disc, its edge showing), a dark disc,
    -- the face. (Our soft ring particle vanished at this size: seen 2026-11-15.)
    local function Round(layer, sub, size)
        local t = c:CreateTexture(nil, layer, nil, sub)
        t:SetSize(size, size)
        t:SetPoint("CENTER")
        local m = c:CreateMaskTexture()
        m:SetTexture(ROUND, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        m:SetAllPoints(t)
        t:AddMaskTexture(m)
        return t
    end
    -- (a 2 px edge: 5 px was "a bit much", 2026-11-15, the user: thinner, the faces a little bigger)
    c.ring = Round("BACKGROUND", 0, ICON_SIZE)
    c.ring:SetColorTexture(1, 1, 1, 1)
    c.disc = Round("BACKGROUND", 1, ICON_SIZE - 4)
    c.disc:SetColorTexture(0.06, 0.05, 0.04, 1)
    c.icon = Round("ARTWORK", 0, ICON_SIZE - 4) -- (a journal icon, where there's no portrait, round as well)
    c.mine = c:CreateTexture(nil, "OVERLAY", nil, 1)
    c.mine:SetTexture(ns.Icon("ring"))
    c.mine:SetBlendMode("ADD")
    c.mine:SetVertexColor(1, 0.82, 0.2, 0.9)
    c.mine:SetSize(ICON_SIZE + 10, ICON_SIZE + 10)
    c.mine:SetPoint("CENTER")
    -- The ring's shine from level 5 (a soft glow in its color) and its glint from 3.
    c.sheen = c:CreateTexture(nil, "BACKGROUND", nil, -1)
    c.sheen:SetTexture(ns.Icon("ring"))
    c.sheen:SetBlendMode("ADD")
    c.sheen:SetSize(ICON_SIZE + 8, ICON_SIZE + 8)
    c.sheen:SetPoint("CENTER")
    c.glint = c:CreateTexture(nil, "OVERLAY", nil, 3)
    c.glint:SetTexture(ns.Icon("sparkle"))
    c.glint:SetBlendMode("ADD")
    c.glint:SetPoint("CENTER", c.ring, "TOPRIGHT", -6, -6)
    c.glint:SetAlpha(0)
    c.glint.pulse = Park.Glint(c.glint)
    Park.Enclosure(c)
    c.free = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.free:SetTexture(ns.Icon("house"))
    c.free:SetVertexColor(FREE_RGB[1], FREE_RGB[2], FREE_RGB[3])
    c.free:SetSize(14, 14)
    c.free:SetPoint("BOTTOMRIGHT", c.ring, "BOTTOMRIGHT", 2, -2)
    Park.Mystery(c)
    -- Below the icon: ANCHOR_RIGHT grew upwards over the page's header from the top rows (UX review 2026-11-11).
    ns.SetTip(c, "ANCHOR_BOTTOMRIGHT", function(self) return Park.Lines(self.key) end)
    c:SetScript("OnClick", function(self)
        if self.unknown then Park.Wiggle(self) else Park:Show(self.key) end
    end)
    -- (hooked: SetTip's own OnEnter shows the tooltip)
    c:HookScript("OnEnter", function(self)
        if not self.unknown then Park:Spot(self.key) end
        Park:Highlight(self.family)
    end)
    c:HookScript("OnLeave", function() Park:SpotBack(); Park:Highlight(nil) end)
    Park.Trail(c)
    cells[#cells + 1] = c
    return c
end

-- An unknown pet's question mark, and its wiggle when clicked: a quick shake side to side, steps that come
-- home (no BOUNCE), on the mark alone.
Park.MYSTERY_COLOR = { 0.85, 0.78, 0.6, 0.75 }
Park.WIGGLE = { 3, -6, 6, -5, 2 } -- pixels, each step relative: they add up to nothing
Park.WIGGLE_STEP = 0.05
function Park.Mystery(c)
    local q = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    q:SetPoint("CENTER")
    q:SetText("?")
    local col = Park.MYSTERY_COLOR
    q:SetTextColor(col[1], col[2], col[3])
    q:Hide()
    local g = q:CreateAnimationGroup()
    g:SetLooping("NONE")
    for i, dx in ipairs(Park.WIGGLE) do
        local a = g:CreateAnimation("Translation")
        a:SetOffset(dx, 0); a:SetDuration(Park.WIGGLE_STEP); a:SetOrder(i); a:SetSmoothing("IN_OUT")
    end
    q.wiggle = g
    c.mystery = q
end
function Park.Wiggle(c)
    c.mystery.wiggle:Stop()
    c.mystery.wiggle:Play()
end

-- Your own pet's cell (2026-11-15, the user): now and then a few paw prints walk out of it, a new way each
-- time, and fade. Animation only, on a frame over the cells (they lead onto the neighbors'): nothing runs
-- while the park is hidden or the pet isn't yours.
Park.PAWS, Park.PAWS_WAIT, Park.PAW_STEP = 3, { 8, 25 }, 0.35
function Park.Trail(c)
    local trail = CreateFrame("Frame", nil, c)
    trail:SetAllPoints()
    trail:SetFrameLevel(c:GetFrameLevel() + 3)
    trail:Hide()
    trail.paws = {}
    for i = 1, Park.PAWS do
        local paw = trail:CreateTexture(nil, "OVERLAY")
        paw:SetTexture(ns.Icon("paw"))
        paw:SetVertexColor(1, 0.85, 0.45, 0.85)
        paw:SetSize(9, 9)
        paw:SetAlpha(0)
        local g = paw:CreateAnimationGroup()
        g.wait = ns.Anim.Fade(g, 0, 0, 1, 1) -- (the pause, set before each play)
        ns.Anim.Fade(g, 0, 1, 0.15, 2)
        ns.Anim.Fade(g, 1, 1, 0.6, 3)
        ns.Anim.Fade(g, 1, 0, 0.9, 4)
        paw.walk = g
        trail.paws[i] = paw
    end
    function trail.Again()
        local span = Park.PAWS_WAIT
        local base = span[1] + math.random() * (span[2] - span[1])
        local a = math.random() * 2 * math.pi -- (the way it goes: a look, not a chance, so math.random)
        for i, paw in ipairs(trail.paws) do
            local r, side = 13 + i * 8, (i % 2 == 0 and 3 or -3)
            paw:ClearAllPoints()
            paw:SetPoint("CENTER", trail, "CENTER", math.cos(a) * r - math.sin(a) * side, math.sin(a) * r + math.cos(a) * side)
            paw:SetRotation(a - math.pi / 2)
            paw.walk.wait:SetDuration(base + (i - 1) * Park.PAW_STEP)
            paw.walk:Stop(); paw.walk:Play()
        end
    end
    trail.paws[Park.PAWS].walk:SetScript("OnFinished", function() if trail:IsShown() then trail.Again() end end)
    c.trail = trail
end
function Park.Walk(c, on)
    local trail = c.trail
    if on and not trail:IsShown() then trail:Show(); trail.Again()
    elseif not on and trail:IsShown() then
        trail:Hide()
        for _, paw in ipairs(trail.paws) do paw.walk:Stop() end
    end
end

-- Every journal species as a pet key with its family (its first, or "default"), by family
-- (Scenes.ORDER, "default" last), then by name.
local function AllKeys()
    local list, rank = {}, {}
    for i, f in ipairs(ns.Scenes.ORDER) do rank[f] = i end
    local data = ns.Companions and ns.Companions.species
    for sid in pairs(data or {}) do
        local key = ns.Pets:KeyOfSpecies(sid)
        local family = Park.FamilyOf(key)
        list[#list + 1] = { key = key, name = ns.Pets:NameOfKey(key) or "", family = family,
            rank = rank[family] or #ns.Scenes.ORDER + 1 }
    end
    table.sort(list, function(a, b)
        if a.rank ~= b.rank then return a.rank < b.rank end
        return a.name < b.name or (a.name == b.name and a.key < b.key)
    end)
    return list
end

-- The path through the grid the families are laid along: { { col, row }, ... } (from 0), each cell next
-- to the one before it, so a run of cells is always one piece. Bands BAND rows high, the first left to
-- right, the next back, and so on; in a band, column by column, down, up, down (shapes about three
-- deep: the families' pieces come out as blocks and L's and steps, not long strips). With an even number of
-- columns, a band's last two are taken row by row instead, so it still ends at the bottom of its outer
-- column, above where the next band starts (BAND odd for that).
Park.BAND = 3
function Park.Path(cols, n)
    local path, band = {}, Park.BAND
    local b = 0
    while #path < n do
        local top = b * band
        local rtl = b % 2 == 1
        local function Col(i) return rtl and cols - 1 - i or i end
        local single = cols % 2 == 1 and cols or cols - 2
        for i = 0, single - 1 do
            for j = 0, band - 1 do
                local r = i % 2 == 0 and j or band - 1 - j
                path[#path + 1] = { Col(i), top + r }
            end
        end
        if cols % 2 == 0 then -- (the last two, row by row: inner, outer; outer, inner; ...)
            for j = 0, band - 1 do
                local a, z = Col(single), Col(single + 1)
                if j % 2 == 1 then a, z = z, a end
                path[#path + 1] = { a, top + j }
                path[#path + 1] = { z, top + j }
            end
        end
        b = b + 1
    end
    for i = #path, n + 1, -1 do path[i] = nil end
    return path
end

-- Which of a cell's sides it fences in a laid-out grid ({ [row] = { [col] = family } }): { top, bottom, left,
-- right }. One fence on each line between two families, as between paddocks (the user's look, 2026-11-15: two
-- lines side by side were busy): the cell below or right of a line draws it (its top, its left), and a cell
-- draws its bottom and right only where nobody is beyond (the map's edge, an empty cell).
local STEP = { top = { 0, -1 }, bottom = { 0, 1 }, left = { -1, 0 }, right = { 1, 0 } }
function Park.Fences(grid, col, row)
    local mine = grid[row] and grid[row][col]
    local out = {}
    for side, d in pairs(STEP) do
        local beyond = grid[row + d[2]] and grid[row + d[2]][col + d[1]]
        if side == "top" or side == "left" then out[side] = beyond ~= mine else out[side] = beyond == nil end
    end
    return out
end

local function Redraw()
    local R = ns.Registry
    Park:Side(Park:Records())
    local top = 8
    local width = child:GetWidth() or 659
    local cols = math.max(1, math.floor((width - 8) / CELL))
    local owned, me = ns.Pets:Owned(), ns.PlayerKey()
    local homes, matches = 0, 0
    local filtering = Park.Filtering()
    local keys = AllKeys()
    local families = {}
    for i, it in ipairs(keys) do families[i] = it.family end
    local path, gardenCells, rows = Park.Layout(cols, families)
    local grid = {}
    for r = 0, rows - 1 do grid[r] = {} end
    for _, at in ipairs(gardenCells) do grid[at[2]][at[1]] = "garden" end
    local groups = {} -- family -> { n, homes, matches, col, row (its first cell: the top row, then the left) }
    Park.groups = groups
    for i, it in ipairs(keys) do
        local col, row = path[i][1], path[i][2]
        grid[row][col] = it.family
        local g = groups[it.family]
        if not g then g = { n = 0, homes = 0, matches = 0, col = col, row = row }; groups[it.family] = g end
        if row < g.row or (row == g.row and col < g.col) then g.col, g.row = col, row end
        g.n = g.n + 1
    end
    for i, it in ipairs(keys) do
        local c = cells[i] or NewCell()
        c.key = it.key
        -- Its face drawn only as the cell gets its pet (the performance pass, 2026-11-16: every redraw drew a
        -- portrait for every pet, on every letter typed in the search, every filter, every guildmate's change).
        if c.drawn ~= it.key then ns.Pets:Portrait(c.icon, it.key); c.drawn = it.key end
        local owner = R:Holder(it.key)
        local match = not filtering or Park.Matches(it.key, nil, owned)
        c.unknown = Park.Unknown(it.key)
        Park.Ring(c, it.key, owner, match) -- (after match: before it, every ring was drawn as filtered out)
        local g = groups[it.family]
        if match then matches = matches + 1; g.matches = g.matches + 1 end
        if owner then g.homes = g.homes + 1 end
        c.match = match
        c.icon:SetDesaturated(owner == nil or not match)
        c.icon:SetAlpha(not match and Park.DIM or owner and 1 or 0.55)
        c.icon:SetShown(not c.unknown); c.disc:SetShown(not c.unknown)
        c.mystery:SetShown(c.unknown)
        c.mystery:SetAlpha(match and Park.MYSTERY_COLOR[4] or Park.DIM)
        c.mine:SetShown(owner == me and match)
        Park.Walk(c, owner == me and match)
        -- A house on every free one, green where you could adopt it (review 2026-11-19: "needs a home" was
        -- told by its grey alone).
        c.free:SetShown(owner == nil and match)
        local can = owned[it.key] ~= nil
        c.free:SetVertexColor(can and FREE_RGB[1] or 0.62, can and FREE_RGB[2] or 0.62, can and FREE_RGB[3] or 0.62)
        c.free:SetAlpha(can and 1 or 0.7)
        if owner then homes = homes + 1 end
        local col, row = path[i][1], path[i][2]
        c.family = it.family
        Park.Pen(c, it.family, Park.Fences(grid, col, row), col, row)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", child, "TOPLEFT", 8 + col * CELL, -(top + row * CELL))
        c:Show()
    end
    for i = #keys + 1, #cells do cells[i]:Hide() end
    Park.filtering = filtering
    Park:Highlight(Park.lit, true) -- (the tints, now the groups' matches are known)
    -- Signs, at each enclosure's first corner (on its post).
    for family, g in pairs(groups) do
        local sg = signs[family] or Park.NewSign(family)
        sg:ClearAllPoints()
        -- (leaning into its enclosure from the corner post, so it's plain whose it is: on the post it sat as
        -- much on the neighbors', the user's look 2026-11-15)
        sg:SetPoint("CENTER", child, "TOPLEFT", 8 + g.col * CELL + Park.SIGN_IN[1], -(top + g.row * CELL + Park.SIGN_IN[2]))
        Park.Choose(sg, Park.filter.family == family)
        sg:SetAlpha(filtering and g.matches == 0 and 0.45 or 1)
        sg:Show()
    end
    for family, sg in pairs(signs) do if not groups[family] then sg:Hide() end end
    -- The empty cells: the park's garden, a pen of its own (its lawn the tint, its fences as the others':
    -- loose pieces on bare ground read as clumsy, the user's look 2026-11-15), its pieces toward the middle.
    local free = gardenCells
    local pieces = Park.Middle(free)
    local n = 0
    local weather = Park.Weather()
    for _, at in ipairs(free) do
        local col, row = at[1], at[2]
        n = n + 1
        local pl = plots[n] or Park.NewPlot()
        pl:ClearAllPoints()
        pl:SetPoint("TOPLEFT", child, "TOPLEFT", 8 + col * CELL, -(top + row * CELL))
        Park.Pen(pl, "garden", Park.Fences(grid, col, row), col, row)
        pl.piece = pieces[n]
        pl.art:SetShown(pl.piece ~= nil)
        pl:EnableMouse(pl.piece ~= nil) -- (bare lawn: the mouse goes through)
        Park.Sky(pl, weather)
        if pl.piece then pl.art:SetTexture(ns.Icon(pl.piece)) end
        pl:Show()
    end
    for i = n + 1, #plots do plots[i]:Hide() end
    child:SetHeight(top + rows * CELL + 8)
    Park:Spot(spot.hover or (ns.Bonds:PetOfTheDay()), true)
    page.summary:SetText(("%d/%d"):format(homes, #keys))
    page.matches:SetText(filtering and ns.T("park.matches", { n = matches }) or "")
end

-- A cell's share of its family's enclosure: the tint of its family's color under it (Park.RingColor at
-- level 4), its fences in wood (Media/Particles/plank, post: tools/draw_particles.py), and a post at every
-- end of one. FENCE px thick on the line, a tile of the plank every PLANK px along it.
Park.FENCE, Park.POST, Park.PLANK, Park.PEN_ALPHA = 4, 6, 32, 0.2
-- The ground's grain (Media/Particles/turf, 2026-11-15, the user: "the flat color is a bit too clean for a
-- zoo"): one seamless tile over TURF_CELLS cells each way, each cell its own part of it by its place on the
-- map, so the grain runs on across cells with no seams.
Park.TURF_CELLS = 4
function Park.Grain(col, row)
    local n = Park.TURF_CELLS
    local u, v = (col % n) / n, (row % n) / n
    return u, u + 1 / n, v, v + 1 / n
end
function Park.Pen(c, family, fences, col, row)
    c.pen:SetTexCoord(Park.Grain(col or 0, row or 0))
    local col = family == "garden" and Park.LAWN or Park.RingColor(family, 4)
    c.penColor = col
    c.pen:SetVertexColor(col[1], col[2], col[3], family == "garden" and col[4] or Park.PEN_ALPHA)
    for side, t in pairs(c.fences) do t:SetShown(fences[side] == true) end
    local f = fences
    c.posts.tl:SetShown(f.top or f.left); c.posts.tr:SetShown(f.top or f.right)
    c.posts.bl:SetShown(f.bottom or f.left); c.posts.br:SetShown(f.bottom or f.right)
end

-- A garden cell's weather: its lawn, a firefly at night (and the bench's lamp lit), snow in December (each
-- somewhere in the cell).
-- (Placed only as they come: a redraw, every letter typed in the search, moved the fireflies and started the
-- snow over, the performance pass 2026-11-16.)
function Park.Sky(pl, w)
    pl.penColor = w.lawn
    pl.pen:SetVertexColor(w.lawn[1], w.lawn[2], w.lawn[3], w.lawn[4])
    if w.night and not pl.night then
        pl.firefly:ClearAllPoints()
        pl.firefly:SetPoint("CENTER", pl, "CENTER", math.random(-14, 14), math.random(-14, 14))
    end
    pl.night = w.night
    pl.firefly:SetShown(w.night)
    if w.night then
        if not pl.firefly.pulse:IsPlaying() then pl.firefly.pulse.Again() end
    else
        pl.firefly.pulse:Stop()
    end
    if w.snow and not (pl.snowing and pl.snow.fall:IsPlaying()) then
        pl.snow:ClearAllPoints()
        pl.snow:SetPoint("TOP", pl, "TOP", math.random(-14, 14), -2)
        pl.snow.fall:Stop(); pl.snow.fall:Play()
    elseif not w.snow then
        pl.snow.fall:Stop()
    end
    pl.snowing = w.snow
    pl.snow:SetShown(w.snow)    pl.lamp:SetShown(w.night and pl.piece == "bench") -- (its lamp lit from dusk on)
end

-- The tints: the pointer's family (lit) brighter, a family the filter leaves with nothing fainter.
Park.PEN_LIT, Park.PEN_EMPTY = 0.38, 0.06
-- (again: the tints anew though the pointer's family is the same, after a redraw; else only on a change: from
-- one pet to the next in an enclosure, leave and enter each repainted every cell, the performance pass)
function Park:Highlight(family, again)
    if family == self.lit and not again then return end
    self.lit = family
    local groups = self.groups or {}
    for _, c in ipairs(cells) do
        if c:IsShown() and c.penColor then
            local g = groups[c.family]
            local a = Park.PEN_ALPHA
            if self.filtering and g and g.matches == 0 then a = Park.PEN_EMPTY
            elseif family and c.family == family then a = Park.PEN_LIT end
            local col = c.penColor
            c.pen:SetVertexColor(col[1], col[2], col[3], a)
        end
    end
    for fam, sg in pairs(signs) do sg.lit:SetShown(family == fam) end
end

Park.SIGN_W, Park.SIGN_H = 20, 15
Park.SIGN_IN = { 4, 3 } -- px right of and below its corner post: on it, leaning into its own pen

-- A family's name as a title ("Katter"), its Norwegian letters too.
local CAP = { ["å"] = "Å", ["ø"] = "Ø", ["æ"] = "Æ" }
function Park.FamilyName(family)
    local name = family == "default" and ns.L["park.family.default"] or ns.AchTexts.generic.families[family] or family
    local first = name:match("^[\195][\128-\191]") or name:sub(1, 1)
    return (CAP[first] or first:upper()) .. name:sub(#first + 1)
end

-- Its sign's tooltip: the name, its homes, what a click does.
function Park.SignLines(family)
    local g = Park.groups and Park.groups[family] or { n = 0, homes = 0 }
    return {
        { Park.FamilyName(family) },
        { ns.T("park.sign.homes", { homes = g.homes, n = g.n }), 1, 1, 1 },
        { ns.L[Park.filter.family == family and "park.sign.all" or "park.sign.show"], 0.6, 0.6, 0.6, true },
    }
end

function Park.NewSign(family)
    local sg = CreateFrame("Button", nil, child)
    sg:SetSize(Park.SIGN_W, Park.SIGN_H)
    sg:SetFrameLevel(child:GetFrameLevel() + 5) -- (over the cells: it sits on their corner)
    local board = sg:CreateTexture(nil, "ARTWORK")
    board:SetTexture(ns.Icon("sign"))
    board:SetTexCoord(0, 1, 4 / 32, 28 / 32) -- (the board on its 32x32)
    board:SetAllPoints()
    sg.board = board
    -- (its mark: the family's ambience on its card, Decor.FAMILY, so the two match)
    local tex, r, g, b = ns.Decor.Mark(family)
    sg.mark = sg:CreateTexture(nil, "OVERLAY")
    sg.mark:SetTexture(tex)
    sg.mark:SetVertexColor(r, g, b, 1)
    sg.mark:SetSize(Park.SIGN_H - 3, Park.SIGN_H - 3)
    sg.mark:SetPoint("CENTER", 0, -1)
    -- The family shown alone: its sign a little bigger, its board gilded, a soft warm light behind it (a gold
    -- ring round it until 2026-11-15, the user: "a bit too much"). Park.Choose.
    sg.chosen = sg:CreateTexture(nil, "BACKGROUND")
    sg.chosen:SetTexture(ns.Icon("dot"))
    sg.chosen:SetBlendMode("ADD")
    sg.chosen:SetVertexColor(1, 0.8, 0.35, 0.6)
    sg.chosen:SetSize(Park.SIGN_W + 12, Park.SIGN_H + 12)
    sg.chosen:SetPoint("CENTER")
    sg.chosen:Hide()
    -- Its enclosure under the mouse: a soft light round it (Park:Highlight).
    sg.lit = sg:CreateTexture(nil, "BACKGROUND", nil, 1)
    sg.lit:SetTexture(ns.Icon("dot"))
    sg.lit:SetBlendMode("ADD")
    sg.lit:SetVertexColor(1, 0.9, 0.7, 0.55)
    sg.lit:SetSize(Park.SIGN_W + 16, Park.SIGN_H + 16)
    sg.lit:SetPoint("CENTER")
    sg.lit:Hide()
    sg.family = family
    ns.SetTip(sg, "ANCHOR_BOTTOMRIGHT", function(self) return Park.SignLines(self.family) end)
    sg:HookScript("OnEnter", function(self) Park:Highlight(self.family) end)
    sg:HookScript("OnLeave", function() Park:Highlight(nil) end)
    -- A click: it swings on its post a moment (the user, 2026-11-15), the board and its mark together, each
    -- about its own top edge (the mark's is 2 px under the board's: near enough). An origin offset from the
    -- mark's top to the board's flung the mark off sideways in game, the user's look 2026-11-15.
    sg.wobble = { Park.Swing(board), Park.Swing(sg.mark) }
    sg:SetScript("OnClick", function(self)
        for _, g in ipairs(self.wobble) do g:Stop(); g:Play() end
        Park:ShowFamily(self.family)
    end)
    signs[family] = sg
    return sg
end

-- A swing back and forth that comes to rest where it started (the steps add up to nothing), about the
-- region's top edge.
Park.SWING = { { 10, 0.08 }, { -16, 0.16 }, { 10, 0.14 }, { -4, 0.12 } }
function Park.Swing(region)
    local g = region:CreateAnimationGroup()
    for i, step in ipairs(Park.SWING) do
        local a = g:CreateAnimation("Rotation")
        a:SetDegrees(step[1]); a:SetDuration(step[2]); a:SetOrder(i); a:SetSmoothing("IN_OUT")
        a:SetOrigin("TOP", 0, 0)
    end
    return g
end

Park.CHOSEN_SCALE, Park.CHOSEN_TINT = 1.2, { 1, 0.85, 0.5 }
function Park.Choose(sg, on)
    sg.chosen:SetShown(on)
    -- (bigger by its size, not SetScale: a scale would move its anchor's offsets too, off its post)
    local k = on and Park.CHOSEN_SCALE or 1
    sg:SetSize(Park.SIGN_W * k, Park.SIGN_H * k)
    local t = on and Park.CHOSEN_TINT or { 1, 1, 1 }
    sg.board:SetVertexColor(t[1], t[2], t[3], 1)
end

-- A sign clicked: only that family (dimmed in place, as the other filters); clicked again, all.
function Park:ShowFamily(family)
    self.filter.family = self.filter.family ~= family and family or nil
    self:Refresh()
end

-- The garden's pieces, on its cells nearest its middle (Park.Middle); the rest is lawn.
-- (2026-11-16, the user: "a little generic ... more Dyreparken/Zoo/Sabeltann related, while also preserving the
-- green space / common area look": a zoo walk's signpost, bench under a lamp and feed trough came; the big tree,
-- the pond, the flowers and the stump stayed, the bush and the second tree went. A pirate ship on the pond
-- "reads poorly", and so did a feed barrow. In this order nearest the garden's middle.)
Park.DECOR = { "tree", "pond", "flowers", "bench", "signpost", "trough", "stump" }
-- The garden: GARDEN_CELLS cells, always, in among the pets nearest the map's middle (Park.Layout; 2026-11-16, the
-- user: "minimum space available for the decorations", then, seeing a whole band of it, "a little ridiculous
-- (big), and not towards the middle of the cluster").
Park.GARDEN_CELLS = 9

-- Where everything goes, for pets of these families in order (families[i]) on a map cols wide: each pet's cell
-- ({ col, row } by index), the garden's cells, and the rows. The garden is a run of the path (Park.Path) like a
-- family's, so the families stay whole: it goes in between two families (or before the first, after the last),
-- wherever its cells' middle comes nearest the map's. Cells past the last pet stay empty.
function Park.Layout(cols, families)
    local n, G = #families, Park.GARDEN_CELLS
    local path = Park.Path(cols, n + G)
    local rows = 0
    for _, at in ipairs(path) do rows = math.max(rows, at[2] + 1) end
    local mc, mr = (cols - 1) / 2, (rows - 1) / 2
    local best, bestD
    for b = 0, n do
        if b == 0 or b == n or families[b] ~= families[b + 1] then
            local x, y = 0, 0
            for i = b + 1, b + G do x, y = x + path[i][1], y + path[i][2] end
            x, y = x / G - mc, (y / G - mr) * 1.5 -- (a band's rows count more: across, the map is wide)
            local d = x * x + y * y
            if not bestD or d < bestD - 1e-9 then best, bestD = b, d end
        end
    end
    local place, garden = {}, {}
    for i = 1, n do place[i] = path[i <= best and i or i + G] end
    for i = best + 1, best + G do garden[#garden + 1] = path[i] end
    table.sort(garden, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]) end)
    return place, garden, rows
end

-- Which garden cell gets which piece: { [i] = piece } over free (the garden's cells, { col, row }, in reading
-- order). The pieces go, in DECOR's order, on the cells nearest the garden's own middle (2026-11-16, the user:
-- "place those more towards the centre"; until then the first cells, at one end).
function Park.Middle(free)
    if #free == 0 then return {} end
    local mc, mr = 0, 0
    for _, at in ipairs(free) do mc, mr = mc + at[1], mr + at[2] end
    mc, mr = mc / #free, mr / #free
    local order = {}
    for i = 1, #free do order[i] = i end
    local function D(i) local c, r = free[i][1] - mc, free[i][2] - mr; return c * c + r * r end
    table.sort(order, function(a, b)
        local da, db = D(a), D(b)
        if da ~= db then return da < db end
        return a < b
    end)
    local out = {}
    for k, piece in ipairs(Park.DECOR) do
        if not order[k] then break end
        out[order[k]] = piece
    end
    return out
end
Park.LAWN = { 0.3, 0.55, 0.22, 0.22 } -- (r, g, b, a: its tint)

-- The garden's secrets (2026-11-15, the user: "hidden details, like clicking a bush triggers an effect, so it
-- comes alive more"; "effects + a rare surprise"): a click on a piece makes it give a little hop and a few of
-- the card's particles; one in SURPRISE_ONE a surprise of its own. Nothing tells you, nothing is saved.
-- A piece: { kind, n, color } (Decor.KINDS, as Fx:Burst takes them), and its surprise, the same.
local GREEN, BROWN = { 0.55, 0.8, 0.3 }, { 0.62, 0.45, 0.28 }
Park.GARDEN = {
    -- (about 40% fewer of everything, 2026-11-16, the user: "too many particles in the garden ... reduced by 30-50%")
    tree = { kind = "leaf", n = 3, color = GREEN, -- a bird takes off: feathers, a song
        surprise = { { kind = "feather", n = 2, color = { 0.95, 0.85, 0.7 } }, { kind = "note", n = 2, color = { 1, 0.85, 0.4 } } } },
    pond = { kind = "bubble", n = 2, color = { 0.6, 0.85, 1 }, -- a frog sings (as the Musical Gustjumper's do)
        surprise = { { kind = "lilypad", n = 1, color = { 0.45, 0.8, 0.4 } }, { kind = "note", n = 2, color = { 0.5, 1, 0.6 } } } },
    signpost = { kind = "chevron", n = 2, color = { 0.85, 0.65, 0.4 }, -- the arrows all point somewhere new
        surprise = { { kind = "chevron", n = 4, color = { 1, 0.85, 0.4 } } } },
    bench = { kind = "crumb", n = 2, color = BROWN, -- someone fed the pigeons: one lands
        surprise = { { kind = "feather", n = 2, color = { 0.75, 0.75, 0.8 } }, { kind = "crumb", n = 2, color = BROWN } } },
    trough = { kind = "grain", n = 2, color = { 0.95, 0.8, 0.4 }, -- a hungry visitor follows the feed
        surprise = { { kind = "paw", n = 3, color = BROWN } } },
    flowers = { kind = "petal", n = 3, color = { 1, 0.7, 0.85 },
        surprise = { { kind = "butterfly", n = 2, color = { 0.6, 0.8, 1 } } } },
    stump = { kind = "crumb", n = 2, color = BROWN, -- a squirrel's hidden stash
        surprise = { { kind = "seed", n = 4, color = { 0.8, 0.6, 0.35 } }, { kind = "paw", n = 1, color = BROWN } } },
}
Park.SURPRISE_ONE = 8
Park.LAMP = { 14, 13, 18 } -- the bench's lamp head on its 34 px art (x, y from the middle), its glow's size

-- And a sound (2026-11-16, the user: "soft subtle pleasant ones ... soft knock on wood on the stump, herb pick
-- sound on the flowers"): the game's own files, by id (the community listfile), the first of a piece's that
-- plays (PlaySoundFile says whether it will: a file Forever lacks is passed by). Mostly the classic bags'
-- pick-up and put-down sounds: short, quiet, made for a click. The tree's surprise, a bird taking off, chirps
-- (one of ten, by chance: a look, so math.random; newer files, so maybe not on Forever: then nothing).
-- PlaySoundFile has no volume, so (2026-11-16, the user: "the water and plant sounds are a little too soft,
-- and the birds a tiny bit too loud") a soft one plays twice at once (`times`: the same file started in the
-- same frame adds up, about twice as loud), and the birds go on the Ambience channel (their slider: by
-- default 0.6 of the SFX one's 1.0; the user's 0.5 to 0.55).
Park.SOUNDS = {
    stump = { 567566, 567576 },                -- putdownwoodsmall, pickupwoodsmall: a soft knock
    flowers = { 567552, times = 2 },           -- pickupherb
    tree = { 567553, 567552, times = 2 },      -- putdownherb: a rustle of leaves
    pond = { 540262, 567555, times = 2 },      -- footstepssmallwatera: a little splash; else pickupwater_liquid01
    signpost = { 567558, 567576 },             -- pickupwoodlarge, pickupwoodsmall: a wooden knock
    bench = { 567567, 567566 },                -- putdownwoodlarge, putdownwoodsmall
    trough = { 567559, 567570 },               -- putdownbag, putdownfoodgeneric: a soft sack of feed
}
local CHIRPS = { 1067029, 1067030, 1067031, 1067032, 1067033, 1067034, 1067035, 1067036, 1067037, 1067038,
    channel = "Ambience" }
Park.SURPRISE_SOUNDS = {
    tree = CHIRPS,
    bench = CHIRPS, -- (the pigeon)
}
Park.Sound = ns.PlaySoundFiles -- (Core/Init.lua)

-- The garden by the clock and the calendar (2026-11-15, the user): the lawn by the season, darker at night
-- (Scenes' sky: evening's dusk and night), fireflies at night, snow falling in December (Decor.DATES'
-- snow); in autumn the trees and bushes give orange leaves, in winter snow. The player's clock, as the card's
-- light. Park.override (Dev/: /dp probe garden) sets the hour and month to look at.
Park.LAWNS = { spring = { 0.32, 0.6, 0.24 }, summer = { 0.3, 0.55, 0.22 }, autumn = { 0.55, 0.48, 0.2 },
    winter = { 0.72, 0.8, 0.9 } }
Park.SEASONS = { "winter", "winter", "spring", "spring", "spring", "summer", "summer", "summer", "autumn",
    "autumn", "autumn", "winter" }
Park.NIGHT_DIM = 0.55
function Park.Weather(t)
    local d = date("*t", t or ns.Now())
    local o = Park.override
    local hour, month = o and o.hour or d.hour, o and o.month or d.month
    local sky = ns.Scenes:Sky(hour)[2]
    local w = { season = Park.SEASONS[month], night = sky == "natt" or sky == "skumring", snow = month == 12 }
    local c, dim = Park.LAWNS[w.season], w.night and Park.NIGHT_DIM or 1
    w.lawn = { c[1] * dim, c[2] * dim, c[3] * dim, Park.LAWN[4] }
    return w
end
Park.AUTUMN = { 0.95, 0.55, 0.2 }
Park.POKE_AGAIN = 0.4 -- seconds: a click sooner on the same piece does nothing (no wall of particles)

-- What a click on a piece gives: its bursts, and whether it was the surprise (pure: the tests read it).
function Park.Poke(piece, roll, weather)
    local g = Park.GARDEN[piece]
    if not g then return {}, false end
    local first = { kind = g.kind, n = g.n, color = g.color }
    local season = weather and weather.season
    if g.kind == "leaf" and season == "winter" then first = { kind = "snow", n = g.n, color = { 1, 1, 1 } }
    elseif g.kind == "leaf" and season == "autumn" then first.color = Park.AUTUMN end
    local out = { first }
    local surprise = roll ~= nil and roll < 1 / Park.SURPRISE_ONE
    if surprise then for _, b in ipairs(g.surprise or {}) do out[#out + 1] = b end end
    return out, surprise
end

Park.FIREFLY_WAIT, Park.SNOW_FALL = { 2, 9 }, 5

-- A click on a piece: a hop and its bursts (Park.Poke), and the hidden extra: every piece in the garden
-- clicked within ALL_WITHIN seconds, and the whole garden goes off at once, every piece's surprise.
Park.ALL_WITHIN = 15
local found = {} -- piece -> when it was last clicked (GetTime)
function Park.AllFound(seen, pieces, now)
    if not next(pieces) then return false end
    for piece in pairs(pieces) do
        if not (seen[piece] and now - seen[piece] <= Park.ALL_WITHIN) then return false end
    end
    return true
end
local function Burst(pl, bursts)
    pl.hop:Stop(); pl.hop:Play()
    for i, b in ipairs(bursts) do
        ns.Fx:Burst({ pl, "CENTER", 0, 0 }, b.kind, { n = b.n, color = b.color, size = i == 1 and 0.7 or 0.8,
            spread = 24, rise = 36, pop = true, parent = pl, level = pl:GetFrameLevel() + 5, tag = "garden" })
    end
end
function Park:PokePlot(pl)
    if not pl.piece then return end
    local now = GetTime()
    if pl.pokedAt and now - pl.pokedAt < Park.POKE_AGAIN then return end
    pl.pokedAt = now
    local weather = Park.Weather()
    local bursts, surprise = Park.Poke(pl.piece, ns.random(), weather)
    Burst(pl, bursts)
    Park.Sound(Park.SOUNDS[pl.piece])
    if surprise then Park.Sound(Park.SURPRISE_SOUNDS[pl.piece], true) end
    if surprise then ns.Log("Park", "the %s's surprise", pl.piece) end
    found[pl.piece] = now
    local pieces = {}
    for _, p in ipairs(plots) do if p:IsShown() and p.piece then pieces[p.piece] = true end end
    if Park.AllFound(found, pieces, now) then
        for k in pairs(found) do found[k] = nil end
        ns.Log("Park", "the whole garden")
        Park.Sound(Park.SURPRISE_SOUNDS.tree, true) -- (one sound for it all, not one a piece at once)
        for _, p in ipairs(plots) do
            if p:IsShown() and p.piece then Burst(p, (Park.Poke(p.piece, 0, weather))) end
        end
    end
end

-- A cell of the garden: its share of the pen, and a piece of art (Park.DECOR) in the middle; a click on the
-- piece: Park:PokePlot.
function Park.NewPlot()
    local pl = CreateFrame("Button", nil, child)
    pl:SetSize(CELL, CELL)
    Park.Enclosure(pl)
    pl.art = pl:CreateTexture(nil, "ARTWORK")
    pl.art:SetSize(CELL - 6, CELL - 6)
    pl.art:SetPoint("CENTER")
    -- (a hop: up a little and back, from its middle)
    local hop = pl.art:CreateAnimationGroup()
    ns.Anim.Scale(hop, 1, 1.15, 0.1, 1, "OUT")
    ns.Anim.Scale(hop, 1.15, 1 / 1.15, 0.25, 2, "IN_OUT")
    pl.hop = hop
    -- At night a firefly now and then (Park.Glint's flash, a wait of its own), and in December a snowflake
    -- falling through, over and over: animation only, stopped while hidden.
    pl.firefly = pl:CreateTexture(nil, "OVERLAY")
    pl.firefly:SetTexture(ns.Icon("dot"))
    pl.firefly:SetBlendMode("ADD")
    pl.firefly:SetVertexColor(0.85, 1, 0.45, 1)
    pl.firefly:SetSize(7, 7)
    pl.firefly:SetAlpha(0)
    pl.firefly.pulse = Park.Glint(pl.firefly, Park.FIREFLY_WAIT)
    -- The bench's lamp, lit at night (Park.LAMP: where its head is on the art, from the middle).
    pl.lamp = pl:CreateTexture(nil, "OVERLAY")
    pl.lamp:SetTexture(ns.Icon("dot"))
    pl.lamp:SetBlendMode("ADD")
    pl.lamp:SetVertexColor(1, 0.8, 0.4, 0.9)
    pl.lamp:SetSize(Park.LAMP[3], Park.LAMP[3])
    pl.lamp:SetPoint("CENTER", pl, "CENTER", Park.LAMP[1], Park.LAMP[2])
    pl.lamp:Hide()
    pl.snow = pl:CreateTexture(nil, "OVERLAY")
    pl.snow:SetTexture(ns.Icon("snowflake"))
    pl.snow:SetSize(7, 7)
    pl.snow:SetAlpha(0)
    local fall = pl.snow:CreateAnimationGroup()
    fall:SetLooping("REPEAT")
    local drop = fall:CreateAnimation("Translation"); drop:SetOffset(0, -(CELL - 8)); drop:SetDuration(Park.SNOW_FALL); drop:SetOrder(1)
    ns.Anim.Fade(fall, 0, 0.9, Park.SNOW_FALL * 0.25, 1)
    local melt = ns.Anim.Fade(fall, 0.9, 0, Park.SNOW_FALL * 0.3, 1); melt:SetStartDelay(Park.SNOW_FALL * 0.7)
    pl.snow.fall = fall
    pl:SetScript("OnClick", function(self) Park:PokePlot(self) end)
    plots[#plots + 1] = pl
    return pl
end

-- A cell's ring (2026-11-15, the user): an adopted pet's family color at every level, paler at the first
-- and deeper and brighter as its holder's bond grows (Park.RingColor), a glint from GLINT_AT and a shine
-- from SHEEN_AT ("with a glint / something shiny for higher levels"); your own pet's in gold (with its
-- glow). None for a pet that needs a home. Fainter when the filter leaves it out.
Park.GLINT_AT, Park.SHEEN_AT = 3, 5
-- A glint now and then (2026-11-15, the user: a steady twinkle "seems permanent / not random enough"): a
-- wait of GLINT_WAIT seconds picked anew each time (math.random: a look, not a chance, Init's ns.random note),
-- a quick flash, gone again. Animation only:
-- nothing runs while the park is hidden.
Park.GLINT_WAIT = { 3, 14 }
function Park.Glint(tex, waitSpan)
    local g = tex:CreateAnimationGroup()
    local wait = g:CreateAnimation("Alpha") -- (a step that changes nothing: the pause, set before each play)
    wait:SetFromAlpha(0); wait:SetToAlpha(0); wait:SetOrder(1)
    ns.Anim.Fade(g, 0, 1, 0.18, 2)
    ns.Anim.Fade(g, 1, 0, 0.6, 3)
    local function Again()
        local span = waitSpan or Park.GLINT_WAIT
        wait:SetDuration(span[1] + math.random() * (span[2] - span[1]))
        g:Play()
    end
    g:SetScript("OnFinished", function() if tex:IsShown() then Again() end end)
    g.Again, g.wait = Again, wait
    return g
end

-- { r, g, b, a } for a family at a bond level: saturated (away from its grey) and brightened along the
-- levels; the tints are made for the card's dark wash, so even level 1 is lifted.
function Park.RingColor(family, level)
    local c = ns.Scenes.TINT[family] or ns.Scenes.TINT.default
    local t = math.min(1, math.max(0, ((level or 1) - 1) / 6))
    local sat, bright = 1 + 0.8 * t, 1.6 + 1.0 * t
    local grey = (c[1] + c[2] + c[3]) / 3
    local out = {}
    for i = 1, 3 do out[i] = math.min(1, math.max(0, (grey + (c[i] - grey) * sat) * bright)) end
    out[4] = 0.75 + 0.25 * t
    return out
end

function Park.Ring(c, key, owner, match)
    local level = owner and select(2, ns.Bond:Of(key)) or 0
    local mine = owner ~= nil and owner == ns.PlayerKey()
    local col = mine and { ns.Scenes.GOLD[1], ns.Scenes.GOLD[2], ns.Scenes.GOLD[3], 1 }
        or owner and Park.RingColor(Park.FamilyOf(key), level)
    if c.unknown then col = nil end -- (a question mark has no ring: nobody holds it)
    c.ring:SetShown(col ~= nil)
    local glint = col ~= nil and not mine and match and level >= Park.GLINT_AT
    local sheen = col ~= nil and not mine and match and level >= Park.SHEEN_AT
    c.glint:SetShown(glint); c.sheen:SetShown(sheen)
    if glint then
        local size = level >= Park.SHEEN_AT and 18 or 13
        c.glint:SetSize(size, size)
        if not c.glint.pulse:IsPlaying() then c.glint.pulse.Again() end
    else
        c.glint.pulse:Stop()
    end
    if not col then return end
    c.ring:SetVertexColor(col[1], col[2], col[3], match and col[4] or Park.DIM)
    if sheen then c.sheen:SetVertexColor(col[1], col[2], col[3], 0.4) end
end

------------------------------------------------------------------------------
-- The spotlight: today's pet, or the one under the mouse
------------------------------------------------------------------------------
local function BuildSpot(inset)
    spot = CreateFrame("Button", nil, inset)
    Park.spot = spot -- (the tests read its model)
    spot:SetHeight(Park.SPOT_H)
    -- (fixed under the map, which scrolls above it: in the scroll it was cut off at the bottom, 2026-11-15)
    spot:SetPoint("BOTTOMLEFT", inset, "BOTTOMLEFT", 4, 4)
    spot:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -4, 4)
    spot.card = {}
    ns.Scenes:Build(spot.card, spot) -- (the card's backdrop: its picture, tint, light of the hour, edges)
    -- Fenced all round as the pens are (2026-11-16, the user: "frame the highlight panel with the same fence we
    -- use for pens"): their rails and posts, over the backdrop's edge (Park.StageFence lays them to its size).
    local fence = CreateFrame("Frame", nil, spot)
    fence:SetAllPoints()
    fence:SetFrameLevel(spot:GetFrameLevel() + 6)
    fence.rails, fence.posts = {}, {}
    local t = Park.STAGE_FENCE
    for _, side in ipairs({ "top", "bottom", "left", "right" }) do
        local r = fence:CreateTexture(nil, "ARTWORK", nil, 1)
        r:SetTexture(ns.Icon("plank"), "REPEAT", "CLAMP")
        local across = side == "top" or side == "bottom"
        local edge = side:upper()
        if across then
            r:SetHeight(t)
            r:SetPoint(edge .. "LEFT", fence, edge .. "LEFT", 0, 0)
            r:SetPoint(edge .. "RIGHT", fence, edge .. "RIGHT", 0, 0)
        else
            r:SetWidth(t)
            r:SetPoint("TOP" .. edge, fence, "TOP" .. edge, 0, 0)
            r:SetPoint("BOTTOM" .. edge, fence, "BOTTOM" .. edge, 0, 0)
        end
        fence.rails[side] = r
    end
    fence:SetScript("OnSizeChanged", function(self, w, h) Park.StageFence(self, w, h) end)
    spot.fence = fence
    local scene = CreateFrame("ModelScene", nil, spot, "ModelSceneMixinTemplate")
    ns.Call(scene, "EnableMouse", false)
    ns.Call(scene, "EnableMouseWheel", false)
    scene:SetSize(Park.SCENE_W, Park.SPOT_H - 4)
    scene:SetPoint("BOTTOMLEFT", spot, "BOTTOMLEFT", 10, 2)
    spot.scene = scene
    spot.card.floor:ClearAllPoints()
    spot.card.floor:SetPoint("CENTER", scene, "BOTTOM", 0, Park.SHADOW.y)
    spot.card.floor:SetSize(Park.SHADOW.w, Park.SHADOW.h)
    spot.today = spot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spot.today:SetPoint("TOPLEFT", spot, "TOPLEFT", Park.SCENE_W + 16, -18)
    spot.name = spot:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    spot.name:SetPoint("TOPLEFT", spot.today, "BOTTOMLEFT", 0, -6)
    spot.name:SetShadowColor(0, 0, 0, 1); spot.name:SetShadowOffset(1, -1)
    spot.species = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spot.species:SetPoint("TOPLEFT", spot.name, "BOTTOMLEFT", 0, -4)
    spot.text = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spot.text:SetPoint("TOPLEFT", spot.species, "BOTTOMLEFT", 0, -8)
    -- The side: the guild's records (a short line each, the full one on hover) and the legend, past a thin line.
    local side = CreateFrame("Frame", nil, spot)
    side:SetPoint("TOPRIGHT", spot, "TOPRIGHT", -16, -14)
    side:SetPoint("BOTTOMRIGHT", spot, "BOTTOMRIGHT", -16, 14) -- (clear of the stage's fence)
    side:SetWidth(Park.SIDE_W)
    side.rule = side:CreateTexture(nil, "ARTWORK")
    side.rule:SetColorTexture(1, 0.85, 0.6, 0.18)
    side.rule:SetWidth(1)
    side.rule:SetPoint("TOPRIGHT", side, "TOPLEFT", -10, 0)
    side.rule:SetPoint("BOTTOMRIGHT", side, "BOTTOMLEFT", -10, 0)
    side.recs = {}
    for i = 1, 3 do
        local r = CreateFrame("Frame", nil, side)
        r:SetSize(Park.SIDE_W, 30)
        r:SetPoint("TOPLEFT", side, "TOPLEFT", 0, -(i - 1) * 32)
        r.label = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        r.label:SetPoint("TOPLEFT")
        r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        r.value:SetPoint("TOPLEFT", r.label, "BOTTOMLEFT", 0, -2)
        r.value:SetWidth(Park.SIDE_W)
        r.value:SetJustifyH("LEFT")
        r.value:SetWordWrap(false)
        r:EnableMouse(true)
        r:SetScript("OnEnter", function(self) ns.ShowTip(self, "ANCHOR_TOP", { { self.tip or "", 1, 1, 1, true } }) end)
        r:SetScript("OnLeave", ns.HideTip)
        side.recs[i] = r
    end
    side.legend = CreateFrame("Frame", nil, side)
    side.legend:SetPoint("BOTTOMLEFT")
    side.legend:SetSize(Park.SIDE_W, 30)
    side.legend.text = side.legend:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    side.legend.text:SetPoint("BOTTOMLEFT")
    side.legend.text:SetWidth(Park.SIDE_W)
    side.legend.text:SetJustifyH("LEFT")
    side.legend.text:SetSpacing(3)
    side.legend.text:SetTextColor(0.8, 0.76, 0.66) -- (the disabled grey was hard to read, UX review 2026-11-11)
    side.legend:EnableMouse(true)
    side.legend:SetScript("OnEnter", function(self) ns.ShowTip(self, "ANCHOR_TOP", { { Park.Legend(), 1, 1, 1, true } }) end)
    side.legend:SetScript("OnLeave", ns.HideTip)
    spot.side = side
    spot.text:SetPoint("RIGHT", side.rule, "LEFT", -12, 0)
    -- The name, its species and the crown's line end at the rule too, cut with "..." (review 2026-11-19: a Huge
    -- "Mechanical Squirrel Box" ran into the records).
    for _, t in ipairs({ spot.today, spot.name, spot.species }) do
        t:SetPoint("RIGHT", side.rule, "LEFT", -12, 0)
        t:SetJustifyH("LEFT")
        t:SetWordWrap(false)
    end
    spot.text:SetJustifyH("LEFT")
    spot.text:SetSpacing(3)
    spot.hint = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spot.hint:SetTextColor(0.75, 0.75, 0.75) -- (meant to be read: not the disabled grey, review 2026-11-19)
    spot.hint:SetPoint("CENTER")
    spot.hint:SetText(ns.L["park.spot.hint"])
    spot:SetScript("OnClick", function(self) if self.key then Park:Show(self.key) end end)
    -- A stage of Moves, as the pet frame has (2026-11-15, the user: "a good portion of the pets are rendered
    -- way too high up or even low"): each pet placed by its feet as on the card (Moves.FRAMING, Data/PetScenes.lua:
    -- the card's rows, or the park's own) and its pose; the day's moments stay the card's. Stopped while the park
    -- is hidden.
    spot.stage = ns.Moves.NewStage("park", {
        moments = false,
        private = true, -- (its own scene: nothing else stands it up)
        actor = function() return spot.actor end,
        scene = function() return spot.scene end,
        anchor = function() return spot end,
    })
    -- (and the way back to today's pet ends: a click on an icon closes the park as the mouse leaves it,
    -- and the stage got a pet while hidden, its stage following it unseen: code review 2026-11-15)
    spot:SetScript("OnHide", function() spotT:Cancel(); spot.hover = nil; spot.stage:Update(spot, nil) end)
    -- Shown again: today's pet (one left hovered as it hid would linger), posed anew.
    spot:SetScript("OnShow", function()
        local today = (ns.Bonds:PetOfTheDay())
        if today ~= spot.key then Park:Spot(today) elseif spot.key then spot.stage:Update(spot, spot.key) end
    end)
    -- The template's camera runs on every frame drawn: only a moment after a change (PF:Camera).
    local ok, fn = pcall(scene.GetScript, scene, "OnUpdate")
    spot.update = ok and type(fn) == "function" and fn or nil
end

-- The stage's fence laid to its size (w x h): the rails' planks repeated along them, as the pens' are (a
-- quarter turned on the sides), and a post at each corner and about every two cells along each side.
Park.STAGE_FENCE = Park.FENCE -- (6 at first: "too thick and encroaches on the text a bit", the user, 2026-11-16)
function Park.StageFence(f, w, h)
    if not (w and h and w > 0 and h > 0) then return end
    for side, r in pairs(f.rails) do
        local across = side == "top" or side == "bottom"
        local n = (across and w or h) / Park.PLANK
        if across then r:SetTexCoord(0, n, 0, 1) else r:SetTexCoord(0, 1, n, 1, 0, 0, n, 0) end
    end
    local at, half = {}, Park.STAGE_FENCE / 2
    local function Along(x0, y0, x1, y1, ends) -- (ends: its corners too; the sides' are the top's and bottom's)
        local k = math.max(1, math.floor(math.max(math.abs(x1 - x0), math.abs(y1 - y0)) / (CELL * 2) + 0.5))
        for i = ends and 0 or 1, ends and k or k - 1 do at[#at + 1] = { x0 + (x1 - x0) * i / k, y0 + (y1 - y0) * i / k } end
    end
    Along(half, -half, w - half, -half, true); Along(half, -(h - half), w - half, -(h - half), true)
    Along(half, -half, half, -(h - half)); Along(w - half, -half, w - half, -(h - half))
    for i, p in ipairs(at) do
        local post = f.posts[i]
        if not post then
            post = f:CreateTexture(nil, "ARTWORK", nil, 2)
            post:SetTexture(ns.Icon("post"))
            post:SetSize(Park.POST, Park.POST)
            f.posts[i] = post
        end
        post:ClearAllPoints()
        post:SetPoint("CENTER", f, "TOPLEFT", p[1], p[2])
        post:Show()
    end
    for i = #at + 1, #f.posts do f.posts[i]:Hide() end
end

local function Camera()
    if not spot.update then return end
    spot.scene:SetScript("OnUpdate", spot.update)
    cameraT:Cancel()
    cameraT:After(Park.CAMERA_FOR, function() spot.scene:SetScript("OnUpdate", nil) end)
end

-- A tooltip line { text, r, g, b } as colored text; a color inside it (a minor like, dimmed) goes back to
-- the line's after its |r, not to the font's white.
local function Colored(line)
    local r, g, b = line[2] or 1, line[3] or 1, line[4] or 1
    local color = ("|cff%02x%02x%02x"):format(r * 255, g * 255, b * 255)
    return color .. line[1]:gsub("|r", "|r" .. color) .. "|r"
end

-- The stage shows key (nil: nobody's pet of the day yet, only the hint). again: its words anew (a redraw).
function Park:Spot(key, again)
    if not spot then return end
    spotT:Cancel()
    if key == spot.key and not again then return end
    local today = (ns.Bonds:PetOfTheDay())
    spot.hover = key ~= today and key or nil
    local changed = key ~= spot.key
    spot.key = key
    ns.Scenes:Paint(spot.card, key)
    spot.hint:SetShown(key == nil)
    for _, t in ipairs({ spot.today, spot.name, spot.species, spot.text }) do t:SetShown(key ~= nil) end
    spot.scene:SetShown(key ~= nil)
    if not key then spot.stage:Update(spot, nil); return end
    if changed then
        spot.stage:Update(spot, nil) -- (the last pet's pose ends)
        spot.actor = ns.Pets:LoadModel(spot.scene, key, function()
            ns.Call(spot.scene, "SetViewInsets", unpack(Park.VIEW))
        end)
        spot.stage:Loading() -- (its load watched: the pose waits for it)
        spot.stage:Update(spot, key) -- (its lift and pose)
        Camera()
    end
    spot.today:SetText(key == today and ("|T%s:16|t %s"):format(ns.Icon("crown"), ns.L["park.spot.today"]) or "")
    local nick = ns.Registry:Nickname(key)
    spot.name:SetText(nick or ns.Pets:NameOfKey(key))
    -- A long name steps down a size or two before it's cut, as on the card.
    local sideAt, spotAt = spot.side:GetLeft(), spot:GetLeft() -- (the rule sits 10 left of the side)
    local room = sideAt and spotAt and (sideAt - 10 - 12 - spotAt - Park.SCENE_W - 16)
    for _, font in ipairs(Park.NAME_FONTS) do
        spot.name:SetFontObject(font)
        if not room or spot.name:GetStringWidth() <= room then break end
    end
    spot.species:SetText(nick and ns.Pets:NameOfKey(key) or "")
    local lines = {}
    -- (the home, the bond, the personality: the icons' tooltip lines; not where it comes from, 2026-11-16, the
    -- user: with many likes and a long source "the text gets too long vertically", and the tooltip has it)
    for _, l in ipairs(ns.JournalList.PetLines(key, "park.free")) do lines[#lines + 1] = Colored(l) end
    -- At most what the stage holds (review 2026-11-19: a long home on two lines pushed the rest under the fence);
    -- the rest is in the icon's tooltip.
    local function Height()
        return spot.today:GetStringHeight() + 6 + spot.name:GetStringHeight() + 4 + spot.species:GetStringHeight()
            + 8 + spot.text:GetStringHeight()
    end
    spot.text:SetText(table.concat(lines, "\n", 1, math.min(#lines, Park.SPOT_LINES)))
    for n = math.min(#lines, Park.SPOT_LINES) - 1, 1, -1 do
        if Height() <= self.SPOT_H - 12 then break end
        spot.text:SetText(table.concat(lines, "\n", 1, n))
    end
    -- The words centered beside the pet (from the top they left the stage's lower half empty, 2026-11-15).
    local h = Height()
    spot.today:ClearAllPoints()
    spot.today:SetPoint("TOPLEFT", spot, "TOPLEFT", Park.SCENE_W + 16, -math.max(14, (self.SPOT_H - h) / 2))
    spot.today:SetPoint("RIGHT", spot.side.rule, "LEFT", -12, 0)
end

-- The stage's side: the records' short lines (Park:Records(), its .short), the legend.
function Park:Side(lines)
    local side = spot and spot.side
    if not side then return end
    for i, r in ipairs(side.recs) do
        local rec = lines.short and lines.short[i]
        r:SetShown(rec ~= nil)
        if rec then
            r.label:SetText(rec[1]); r.value:SetText(rec[2]); r.tip = rec[3]
        end
    end
    side.legend.text:SetText(Park.LegendShort())
end

-- The mouse left an icon: today's pet again, in a moment (the next icon's hover cancels it).
function Park:SpotBack()
    spotT:After(self.SPOT_BACK, function()
        if spot and spot:IsVisible() then spot.hover = nil; Park:Spot((ns.Bonds:PetOfTheDay())) end
    end)
end

-- The search box: Blizzard's (an instruction text and a clear button), else a plain one.
local function SearchBox(parent)
    local template = ns.SidePage.Template("SearchBoxTemplate") or ns.SidePage.Template("InputBoxTemplate")
    local box = CreateFrame("EditBox", nil, parent, template)
    box:SetSize(150, 20)
    box:SetAutoFocus(false)
    box:SetMaxLetters(40)
    if box.Instructions then box.Instructions:SetText(ns.L["park.search"]) end
    -- (HookScript: the template's own OnTextChanged shows and hides the instruction and the clear button)
    box:HookScript("OnTextChanged", function(self)
        local text = Park.Fold(self:GetText()):gsub("^%s+", ""):gsub("%s+$", "")
        if text == Park.filter.text then return end
        Park.filter.text = text
        Park:Refresh()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    -- (hooked, not set: the template may have its own)
    box:HookScript("OnEnter", function(self) ns.ShowTip(self, "ANCHOR_BOTTOMRIGHT", { { ns.L["park.search.tip"], 1, 1, 1, true } }) end)
    box:HookScript("OnLeave", ns.HideTip)
    return box
end

local function Toggle(parent, field, anchor)
    local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    b:SetSize(24, 24)
    b:SetPoint("LEFT", anchor, "RIGHT", 10, 0)
    b.label = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("LEFT", b, "RIGHT", 0, 0)
    b.label:SetText(ns.L["park.filter." .. field])
    b:SetScript("OnClick", function(self)
        Park.filter[field] = self:GetChecked() and true or false
        Park:Refresh()
    end)
    ns.SetTip(b, "ANCHOR_BOTTOMRIGHT", ns.L["park.filter." .. field .. ".tip"])
    return b
end

local function Build(p)
    page = p.frame
    local counter
    page.summary, counter = ns.SidePage:CounterBox(p, ns.L["park.counter"])
    -- Left of the counter: the search and how many match; right of it: the two toggles.
    page.search = SearchBox(page)
    page.search:SetPoint("RIGHT", counter, "LEFT", -70, 0)
    page.matches = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    page.matches:SetPoint("LEFT", page.search, "RIGHT", 6, 0)
    page.free = Toggle(page, "free", counter)
    page.adopt = Toggle(page, "adopt", page.free.label)
    local inset
    child, inset = ns.SidePage:ScrollInset(p, nil, Park.SPOT_H + 6)
    BuildSpot(inset)
end

sp = ns.SidePage:New({
    id = "Park",
    title = ns.L["park.title"],
    icon = ns.Achievements:Icon({ id = "page:park", icon = { "INV_Box_PetCarrier_01", "Ability_Hunter_BeastCall" } }),
    build = Build,
    refresh = Redraw,
})

-- What the map's marks mean, and the question mark while unknown pets are hidden: in full (the legend's
-- tooltip), and short, two lines under the records on the stage's side.
function Park.Legend()
    local text = ns.T("park.legend", { icon = FreeIcon(14) })
    if ns.Settings:On("hideUnknown") then text = text .. "  " .. ns.L["park.legend.unknown"] end
    return text
end
function Park.LegendShort()
    local function Dot(c) return ("|T%s:10:10:0:0:64:64:0:64:0:64:%d:%d:%d|t"):format(ns.Icon("dot"), c[1], c[2], c[3]) end
    local text = ns.T("park.legend.short", { home = Dot({ 255, 200, 60 }), free = FreeIcon(10, { 0.62, 0.62, 0.62 }),
        icon = FreeIcon(12) })
    if ns.Settings:On("hideUnknown") then text = text .. "   " .. ns.L["park.legend.short.unknown"] end
    return text
end

function Park:Open() sp:Open() end
function Park:IsOpen() return sp:IsOpen() end
function Park:Refresh() sp:Refresh() end

-- Only these pets' bonds changed (a guildmate's BOND): their rings, and the stage if it shows one of them;
-- the rest stays (a whole redraw on every bond was what 53_card guards against).
function Park:Bonds(keys)
    if not (self:IsOpen() and spot) then return end
    local R = ns.Registry
    for _, c in ipairs(cells) do
        if c:IsShown() and keys[c.key] then Park.Ring(c, c.key, R:Holder(c.key), c.match) end
    end
    if spot.key and keys[spot.key] then self:Spot(spot.key, true) end
end

ns.Bus:On("REGISTRY", function(keys) if keys then Park:Bonds(keys) else Park:Refresh() end end)
ns.Bus:On("OWNERS", function() Park:Refresh() end)
