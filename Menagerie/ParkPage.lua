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
-- whistles), in a ring of its holder's bond level (the card's tier colors: Scenes.Tier, the family's
-- below silver), a gold glow on yours. Under the map, a stage: today's pet (Bonds:PetOfTheDay) as a
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
    c.ring = Round("BACKGROUND", 0, ICON_SIZE + 2)
    c.ring:SetColorTexture(1, 1, 1, 1)
    c.disc = Round("BACKGROUND", 1, ICON_SIZE - 8)
    c.disc:SetColorTexture(0.06, 0.05, 0.04, 1)
    c.icon = Round("ARTWORK", 0, ICON_SIZE - 8) -- (a journal icon, where there's no portrait, round as well)
    c.mine = c:CreateTexture(nil, "OVERLAY", nil, 1)
    c.mine:SetTexture(ns.Icon("ring"))
    c.mine:SetBlendMode("ADD")
    c.mine:SetVertexColor(1, 0.82, 0.2, 0.9)
    c.mine:SetSize(ICON_SIZE + 10, ICON_SIZE + 10)
    c.mine:SetPoint("CENTER")
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
        Park.Ring(c.ring, it.key, owner, match)
        local match = not filtering or Park.Matches(it.key, nil, owned)
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

-- A cell's ring: an adopted pet's holder's bond level in the card's tier colors (below silver, the
-- family's, brightened: the tints are made for the card's wash and were too faint here, 2026-11-15, the
-- user: "it should be clearer which one is adopted"); none for a pet that needs a home; fainter when the
-- filter leaves it out.
Park.RING_BRIGHT = 2.2
function Park.Ring(ring, key, owner, match)
    ring:SetShown(owner ~= nil)
    if not owner then return end
    local _, level = ns.Bond:Of(key)
    local family = ns.Scenes:Families(key)[1] or "default"
    local tint = ns.Scenes.Bright(ns.Scenes.TINT[family] or ns.Scenes.TINT.default, Park.RING_BRIGHT)
    local c = ns.Scenes.Tier(level or 1, tint)
    ring:SetVertexColor(c[1], c[2], c[3], match and 1 or Park.DIM)
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

local function Colored(line)
    local r, g, b = line[2] or 1, line[3] or 1, line[4] or 1
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, line[1])
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
    if not key then return end
    if changed then
        spot.actor = ns.Pets:LoadModel(spot.scene, key, function()
            ns.Call(spot.scene, "SetViewInsets", unpack(Park.VIEW))
        end)
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
        if spot then spot.hover = nil; Park:Spot((ns.Bonds:PetOfTheDay())) end
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
        if c:IsShown() and keys[c.key] then Park.Ring(c.ring, c.key, R:Holder(c.key), c.match) end
    end
    if spot.key and keys[spot.key] then self:Spot(spot.key, true) end
end

ns.Bus:On("REGISTRY", function(keys) if keys then Park:Bonds(keys) else Park:Refresh() end end)
