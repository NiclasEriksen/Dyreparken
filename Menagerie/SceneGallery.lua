local _, ns = ...

-- A development tool: every candidate picture that exists on this client,
-- as thumbnails, to pick one per slot.
--   /dp probe bg     backgrounds, one per family (DyreparkenDB.scenePicks):
--                    a pick shows on the pet card at once.
--   /dp probe decor  decorations for the card (DyreparkenDB.decorPicks,
--                    Decor.lua): corners, glows, sparkles...
-- Choose a slot at the top, then click a thumbnail; right-click clears the
-- slots that use it. The picks are read from SavedVariables and made the
-- defaults in code.
local Gallery = {}
ns.SceneGallery = Gallery

local THUMB_W, THUMB_H, GAP, COLS = 168, 96, 8, 4

-- The card previews the decorations' galleries (Decor.show): the chosen
-- slot, worn at a level where it shows, with the picture under the mouse.
local function Card() if ns.JournalUI.Refresh then ns.JournalUI:Refresh() end end
local function Select(slot)
    local kind, family = slot:match("^(%a+)%.(%a+)$")
    ns.Decor.show = { slot = kind or slot, family = family }
    Card()
end
local function Hover(path)
    if not ns.Decor.show then return end
    ns.Decor.show.art = path
    Card()
end
local function Closed()
    ns.Decor.show = nil
    Card()
end

-- mode -> { title, slots, picks = fn() -> table, changed = fn(),
--   select = fn(slot), hover = fn(path or nil), closed = fn() }
Gallery.MODES = {
    bg = {
        title = "Dyreparken: backgrounds",
        slots = { "default", unpack(ns.Scenes.ORDER) }, -- (every family there is: a new one shows up here too)
        picks = function() return ns.DB.global.scenePicks end,
        changed = function() ns.Scenes:Reset() end,
    },
    decor = {
        title = "Dyreparken: decorations",
        slots = { "corner", "cornerGold", "border", "frame", "glow", "sparkle", "star", "heart", "bubble", "confetti", "ribbon",
            "moon", "leaf", "paw", "note", "snow" },
        filter = true, -- show the selected slot's candidates only
        kindOf = function(slot) return slot == "cornerGold" and "corner" or slot end, -- (the gold level's corners)
        picks = function() return ns.DB.global.decorPicks end,
        changed = function() end,
        select = Select, hover = Hover, closed = Closed,
    },
    -- A border per family ("border.cat"): the card wears the chosen
    -- slot's family while the gallery is open.
    frames = {
        title = "Dyreparken: borders per family",
        slots = {},
        filter = true,
        button = 128,
        kindOf = function(slot) return slot:match("^(%a+)%.") end,
        picks = function() return ns.DB.global.decorPicks end,
        changed = function() end,
        select = Select, hover = Hover, closed = Closed,
    },
}
for _, family in ipairs(Gallery.MODES.bg.slots) do
    local slots = Gallery.MODES.frames.slots
    slots[#slots + 1] = "border." .. family
end

local views = {} -- mode -> { frame, grid, thumbs, selected, all, shown }
local Layout -- below

local function UsedBy(view, path)
    local list = {}
    for _, f in ipairs(view.cfg.slots) do if view.cfg.picks()[f] == path then list[#list + 1] = f end end
    return table.concat(list, ", ")
end

local function Redraw(view)
    for _, t in ipairs(view.thumbs) do
        local used = UsedBy(view, t.path)
        t.used:SetText(used)
        t.border:SetShown(used ~= "")
    end
    for _, b in ipairs(view.frame.families) do
        b:SetText(b.family .. (view.cfg.picks()[b.family] and " *" or ""))
        if b.family == view.selected then b:LockHighlight() else b:UnlockHighlight() end
    end
    local card = ""
    if view.cfg.hover then
        local slot = view.selected:match("^(%a+)%.") or view.selected
        card = (ns.Decor.NEED[slot] or ns.Decor.SLOT_KIND[slot]) and " Hover to see it on the pet card."
            or " (Not used on the card.)"
    end
    view.frame.hint:SetText(("Slot: %s%s. Click a picture to pick it, right-click to clear.%s"):format(
        view.selected, view.cfg.filter and (" (%d pictures)"):format(view.shown or 0) or "", card))
end

local function OnClick(view, t, button)
    local picks = view.cfg.picks()
    if button == "RightButton" then
        for _, f in ipairs(view.cfg.slots) do if picks[f] == t.path then picks[f] = nil end end
        ns.Log("Probe", "%s pick cleared: %s", view.mode, t.path)
    else
        picks[view.selected] = t.path
        ns.Log("Probe", "%s pick %s = %s", view.mode, view.selected, t.path)
    end
    view.cfg.changed()
    Redraw(view)
    if ns.JournalUI.Refresh then ns.JournalUI:Refresh() end
end

local function Build(mode)
    local cfg = Gallery.MODES[mode]
    local view = { cfg = cfg, mode = mode, thumbs = {}, selected = cfg.slots[1] }
    local frame = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    local width = COLS * (THUMB_W + GAP) + 40
    frame:SetSize(width, 600)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.title:SetPoint("TOP", frame, "TOP", 0, -5)
    frame.title:SetText(cfg.title)

    frame.families = {}
    local x, y = 12, -30
    local bw = cfg.button or 84
    for i, f in ipairs(cfg.slots) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(bw, 20)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        b.family = f
        b:SetScript("OnClick", function()
            view.selected = f
            if cfg.select then cfg.select(f) end
            if cfg.filter then Layout(view) end
            Redraw(view)
        end)
        frame.families[i] = b
        x = x + bw + 4
        if x + bw > width - 10 then x, y = 12, y - 24 end
    end
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y - 26)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y - 44)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    view.grid = CreateFrame("Frame", nil, scroll)
    view.grid:SetSize(COLS * (THUMB_W + GAP), 1)
    scroll:SetScrollChild(view.grid)
    if cfg.closed then frame:SetScript("OnHide", function() cfg.closed() end) end
    view.frame = frame
    views[mode] = view
    return view
end

local function NewThumb(view)
    local t = CreateFrame("Button", nil, view.grid)
    t:SetSize(THUMB_W, THUMB_H + 28)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t.backing = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    t.backing:SetPoint("TOPLEFT")
    t.backing:SetSize(THUMB_W, THUMB_H)
    t.image = t:CreateTexture(nil, "ARTWORK")
    t.image.box = t.backing
    t.image:SetPoint("TOPLEFT")
    t.image:SetSize(THUMB_W, THUMB_H)
    t.backing:SetColorTexture(0.12, 0.1, 0.08, 1) -- so a glow or a sparkle shows
    t.border = t:CreateTexture(nil, "BACKGROUND")
    t.border:SetPoint("TOPLEFT", -3, 3)
    t.border:SetSize(THUMB_W + 6, THUMB_H + 6)
    t.border:SetColorTexture(1, 0.82, 0, 1)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.label:SetPoint("TOPLEFT", t.backing, "BOTTOMLEFT", 0, -2)
    t.label:SetPoint("RIGHT", t, "RIGHT")
    t.label:SetJustifyH("LEFT")
    t.label:SetWordWrap(false)
    t.used = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.used:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -1)
    t:SetScript("OnClick", function(self, button) OnClick(view, self, button) end)
    ns.SetTip(t, "ANCHOR_RIGHT", function(self) return self.path end)
    if view.cfg.hover then -- the card shows it while the mouse is on it
        t:HookScript("OnEnter", function(self) view.cfg.hover(self.path) end)
        t:HookScript("OnLeave", function() view.cfg.hover(nil) end)
    end
    view.thumbs[#view.thumbs + 1] = t
    return t
end

-- Fit an atlas into the thumbnail at its own proportions (files fill it).
local function Fit(image, atlas)
    local info = atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas)
    local w, h = THUMB_W, THUMB_H
    if info and info.width and info.height and info.width > 0 and info.height > 0 then
        local scale = math.min(THUMB_W / info.width, THUMB_H / info.height, 1.5)
        w, h = info.width * scale, info.height * scale
    end
    image:ClearAllPoints()
    image:SetPoint("CENTER", image.box, "CENTER")
    image:SetSize(w, h)
end

-- Lay out the thumbnails: all of them, or the selected slot's.
function Layout(view)
    for _, t in ipairs(view.thumbs) do t:Hide() end
    local shown = 0
    for _, c in ipairs(view.all) do
        if not view.cfg.filter or c.slot == (view.cfg.kindOf and view.cfg.kindOf(view.selected) or view.selected) then
            shown = shown + 1
            local t = view.thumbs[shown] or NewThumb(view)
            t.path = c.path
            local atlas = c.path:match("^atlas:(.+)$")
            if atlas then
                t.image:SetTexCoord(0, 1, 0, 1)
                t.image:SetAtlas(atlas)
            else
                t.image:SetTexture(c.path)
                t.image:SetTexCoord(ns.Scenes.Crop(c.path))
            end
            Fit(t.image, atlas)
            t.label:SetText(("%d %s"):format(c.n, (c.path:match("([^\\\\:]+)$") or c.path)))
            local col, row = (shown - 1) % COLS, math.floor((shown - 1) / COLS)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", view.grid, "TOPLEFT", col * (THUMB_W + GAP), -row * (THUMB_H + 36))
            t:Show()
        end
    end
    view.grid:SetHeight(math.max(1, math.ceil(shown / COLS)) * (THUMB_H + 36))
    view.shown = shown
end

-- Show the candidates that exist: { n, path, slot } (a file path, or "atlas:name").
function Gallery:Show(list, mode)
    mode = mode or "bg"
    local view = views[mode] or Build(mode)
    view.all = list
    Layout(view)
    Redraw(view)
    view.frame:Show()
    if view.cfg.select then view.cfg.select(view.selected) end
    Gallery._frame, Gallery._thumbs = view.frame, view.thumbs
end
