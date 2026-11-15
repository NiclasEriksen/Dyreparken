local _, ns = ...

-- "Parken": the park map, a page of the Collections window (a SidePage,
-- see Core/SidePage.lua), next to the achievements.
--
-- At the top, the park's records: the longest friendship, the most popular
-- family, the newest arrival. Below, every companion in Forever's journal
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
-- its shape (the user). The search reads a pet's name, nickname, who has it and its families; not its source
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
-- Everything comes from the registry; nothing is sent. We can't know which
-- pets other members own (that isn't synced), so there's no "nobody has it".
-- Loads after Achievements/Page.lua, so its tab comes second.
local Park = {}
ns.ParkPage = Park

local CELL, ICON_SIZE = 40, 36
local READY = "Interface\\RaidFrame\\ReadyCheck-Ready"

local sp, page, child, records, legend, spot
local cells = {}
local spotT, cameraT = ns.Timers(), ns.Timers()
-- (200 until 2026-11-15: the six rows of the map then overflowed by a few pixels, and a scrollbar showed
-- with nothing to scroll)
Park.SPOT_H = 180        -- the stage under the map
Park.SCENE_W = 280       -- its model's part, at the left
-- The model's view in the stage: the pet frame's (0, 0, 84, -50 on 170 px) a third larger, so the pet
-- stands as there, bigger (2026-11-15, the first look: small and off to the side). Tuned by eye.
Park.VIEW = { 0, 0, 54, -68 } -- (its box the same 190 px as on the 200 px stage: the pet as big)
Park.SPOT_BACK = 1       -- seconds after the mouse leaves an icon, today's pet again
Park.CAMERA_FOR = 2      -- the stage's camera runs this long after a change (PF.CAMERA_FOR)
-- The filter: { text = lower-cased search, free = bool, adopt = bool }, for this session.
Park.filter = { text = "", free = false, adopt = false }
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

-- Everything the search looks through for a pet, folded.
function Park.Haystack(key)
    local parts = { ns.Pets:NameOfKey(key) or "" }
    parts[#parts + 1] = ns.Registry:Nickname(key) or ""
    parts[#parts + 1] = ns.Registry:Holder(key) or ""
    local sid = ns.Pets:SpeciesOfKey(key)
    local data = sid and ns.Companions and ns.Companions.species and ns.Companions.species[sid]
    local names = ns.AchTexts.generic.families
    for _, tag in ipairs(type(data) == "table" and data.t or {}) do parts[#parts + 1] = names[tag] or "" end
    return Park.Fold(table.concat(parts, "\31"))
end

-- Whether a pet passes the filter (owned: Pets:Owned()).
function Park.Matches(key, filter, owned)
    filter = filter or Park.filter
    local owner = ns.Registry:Holder(key)
    if (filter.free or filter.adopt) and owner then return false end
    if filter.adopt and not (owned or ns.Pets:Owned())[key] then return false end
    local text = filter.text or ""
    return text == "" or Park.Haystack(key):find(text, 1, true) ~= nil
end

function Park.Filtering(filter)
    filter = filter or Park.filter
    return filter.free or filter.adopt or (filter.text or "") ~= ""
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
    if not oldest then return { ns.L["park.empty"] } end
    local lines = {}
    lines[1] = ns.T("park.oldest", { pet = ns.Registry:NameOf(oldest.key), owner = oldest.owner,
        time = ns.CaredFor(oldest.at, now) })
    local best, bestN
    for tag, n in pairs(families) do
        if not best or n > bestN or (n == bestN and names[tag] < names[best]) then best, bestN = tag, n end
    end
    if best then
        lines[#lines + 1] = ns.T("park.family", { family = names[best], n = bestN })
    end
    -- With one pet in the park, it's both the oldest and the newest: once is enough.
    if newest.key ~= oldest.key then
        local home = ns.Home(newest.owner, newest.at, now)
        lines[#lines + 1] = ns.T("park.newest", { pet = ns.Registry:NameOf(newest.key),
            home = home:sub(1, 1):lower() .. home:sub(2) })
    end
    return lines
end

-- An icon's tooltip: the pet's nickname over its species, then the list's lines (JournalList.PetLines),
-- then whether you could adopt it and what a click does.
function Park.Lines(key)
    local nick = ns.Registry:Nickname(key)
    local lines = { { nick or ns.Pets:NameOfKey(key) } }
    if nick then lines[2] = { ns.Pets:NameOfKey(key), 0.7, 0.7, 0.7 } end
    for _, l in ipairs(ns.JournalList.PetLines(key, "park.free")) do lines[#lines + 1] = l end
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

local ROUND = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local function NewCell()
    local c = CreateFrame("Button", nil, child)
    c:SetSize(ICON_SIZE, ICON_SIZE)
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
    c.glint:SetPoint("CENTER", c, "TOPRIGHT", -6, -6)
    c.glint:SetAlpha(0)
    c.glint.pulse = Park.Glint(c.glint)
    c.free = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.free:SetTexture(READY)
    c.free:SetSize(14, 14)
    c.free:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 2, -2)
    -- Below the icon: ANCHOR_RIGHT grew upwards over the page's header from the top rows (UX review 2026-11-11).
    ns.SetTip(c, "ANCHOR_BOTTOMRIGHT", function(self) return Park.Lines(self.key) end)
    c:SetScript("OnClick", function(self) Park:Show(self.key) end)
    -- (hooked: SetTip's own OnEnter shows the tooltip)
    c:HookScript("OnEnter", function(self) Park:Spot(self.key) end)
    c:HookScript("OnLeave", function() Park:SpotBack() end)
    cells[#cells + 1] = c
    return c
end

-- Every journal species as a pet key, sorted by name.
local function AllKeys()
    local list = {}
    local data = ns.Companions and ns.Companions.species
    for sid in pairs(data or {}) do
        local key = ns.Pets:KeyOfSpecies(sid)
        list[#list + 1] = { key = key, name = ns.Pets:NameOfKey(key) or "" }
    end
    table.sort(list, function(a, b) return a.name < b.name or (a.name == b.name and a.key < b.key) end)
    return list
end

local function Redraw()
    local R = ns.Registry
    local lines = Park:Records()
    records:SetText(table.concat(lines, "\n"))
    local top = 8 + records:GetStringHeight() + 8
    legend:ClearAllPoints()
    legend:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -top)
    top = top + 22
    local width = child:GetWidth() or 659
    local cols = math.max(1, math.floor((width - 8) / CELL))
    local owned, me = ns.Pets:Owned(), ns.PlayerKey()
    local homes, matches = 0, 0
    local filtering = Park.Filtering()
    local keys = AllKeys()
    for i, it in ipairs(keys) do
        local c = cells[i] or NewCell()
        c.key = it.key
        ns.Pets:Portrait(c.icon, it.key)
        local owner = R:Holder(it.key)
        local match = not filtering or Park.Matches(it.key, nil, owned)
        Park.Ring(c, it.key, owner, match) -- (after match: before it, every ring was drawn as filtered out)
        if match then matches = matches + 1 end
        c.match = match
        c.icon:SetDesaturated(owner == nil or not match)
        c.icon:SetAlpha(not match and Park.DIM or owner and 1 or 0.55)
        c.mine:SetShown(owner == me and match)
        c.free:SetShown(owner == nil and owned[it.key] ~= nil and match)
        if owner then homes = homes + 1 end
        local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", child, "TOPLEFT", 8 + col * CELL, -(top + row * CELL))
        c:Show()
    end
    for i = #keys + 1, #cells do cells[i]:Hide() end
    child:SetHeight(top + math.ceil(#keys / cols) * CELL + 8)
    Park:Spot(spot.hover or (ns.Bonds:PetOfTheDay()), true)
    page.summary:SetText(("%d/%d"):format(homes, #keys))
    page.matches:SetText(filtering and ns.T("park.matches", { n = matches }) or "")
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
function Park.Glint(tex)
    local g = tex:CreateAnimationGroup()
    local wait = g:CreateAnimation("Alpha") -- (a step that changes nothing: the pause, set before each play)
    wait:SetFromAlpha(0); wait:SetToAlpha(0); wait:SetOrder(1)
    ns.Anim.Fade(g, 0, 1, 0.18, 2)
    ns.Anim.Fade(g, 1, 0, 0.6, 3)
    local function Again()
        local span = Park.GLINT_WAIT
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
        or owner and Park.RingColor(ns.Scenes:Families(key)[1] or "default", level)
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
    local scene = CreateFrame("ModelScene", nil, spot, "ModelSceneMixinTemplate")
    ns.Call(scene, "EnableMouse", false)
    ns.Call(scene, "EnableMouseWheel", false)
    scene:SetSize(Park.SCENE_W, Park.SPOT_H - 4)
    scene:SetPoint("BOTTOMLEFT", spot, "BOTTOMLEFT", 10, 2)
    spot.scene = scene
    spot.today = spot:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    spot.today:SetPoint("TOPLEFT", spot, "TOPLEFT", Park.SCENE_W + 24, -18)
    spot.name = spot:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    spot.name:SetPoint("TOPLEFT", spot.today, "BOTTOMLEFT", 0, -6)
    spot.name:SetShadowColor(0, 0, 0, 1); spot.name:SetShadowOffset(1, -1)
    spot.species = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spot.species:SetPoint("TOPLEFT", spot.name, "BOTTOMLEFT", 0, -4)
    spot.text = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spot.text:SetPoint("TOPLEFT", spot.species, "BOTTOMLEFT", 0, -8)
    spot.text:SetPoint("RIGHT", spot, "RIGHT", -16, 0)
    spot.text:SetJustifyH("LEFT")
    spot.text:SetSpacing(3)
    spot.hint = spot:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    spot.hint:SetPoint("CENTER")
    spot.hint:SetText(ns.L["park.spot.hint"])
    spot:SetScript("OnClick", function(self) if self.key then Park:Show(self.key) end end)
    -- A stage of Moves, as the pet frame has (2026-11-15, the user: "a good portion of the pets are rendered
    -- way too high up or even low"): each pet's lift (Data/PetMoves.lua, found by eye on the card) and its
    -- pose; the day's moments stay the card's. Stopped while the park is hidden.
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
    spot.card.floor:Hide() -- (the card's shadow under the feet: placed for the card's model only)
    if not key then spot.stage:Update(spot, nil); return end
    if changed then
        spot.stage:Update(spot, nil) -- (the last pet's pose ends)
        spot.actor = ns.Pets:LoadModel(spot.scene, key, function()
            ns.Call(spot.scene, "SetViewInsets", unpack(Park.VIEW))
        end)
        spot.stage:Update(spot, key) -- (its lift and pose)
        Camera()
    end
    spot.today:SetText(key == today and ("|T%s:16|t %s"):format(ns.Icon("crown"), ns.L["park.spot.today"]) or "")
    local nick = ns.Registry:Nickname(key)
    spot.name:SetText(nick or ns.Pets:NameOfKey(key))
    spot.species:SetText(nick and ns.Pets:NameOfKey(key) or "")
    local lines = {}
    -- (the home, the bond, the personality: the icons' tooltip lines)
    for _, l in ipairs(ns.JournalList.PetLines(key, "park.free")) do lines[#lines + 1] = Colored(l) end
    local source = Park.Source(key)
    if source then lines[#lines + 1] = Colored({ source, 0.6, 0.8, 1 }) end
    spot.text:SetText(table.concat(lines, "\n"))
    -- The words centered beside the pet (from the top they left the stage's lower half empty, 2026-11-15).
    local h = spot.today:GetStringHeight() + 6 + spot.name:GetStringHeight() + 4 + spot.species:GetStringHeight()
        + 8 + spot.text:GetStringHeight()
    spot.today:ClearAllPoints()
    spot.today:SetPoint("TOPLEFT", spot, "TOPLEFT", Park.SCENE_W + 24, -math.max(10, (self.SPOT_H - h) / 2))
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
    records = child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    records:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -8)
    records:SetPoint("RIGHT", child, "RIGHT", -8, 0)
    records:SetJustifyH("LEFT")
    legend = child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    legend:SetTextColor(0.8, 0.76, 0.66) -- (the disabled grey was hard to read, UX review 2026-11-11)
    legend:SetText(ns.T("park.legend", { icon = ("|T%s:14|t"):format(READY) }))
    BuildSpot(inset)
end

sp = ns.SidePage:New({
    id = "Park",
    title = ns.L["park.title"],
    icon = ns.Achievements:Icon({ id = "page:park", icon = { "INV_Box_PetCarrier_01", "Ability_Hunter_BeastCall" } }),
    build = Build,
    refresh = Redraw,
})

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
