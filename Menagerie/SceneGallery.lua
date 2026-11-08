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

-- mode -> { title, slots, picks = fn() -> table, changed = fn() }
Gallery.MODES = {
    bg = {
        title = "Dyreparken: bakgrunner",
        slots = { "default", "cat", "bird", "owl", "farm", "rabbit", "frog", "snake", "mechanical", "dragon",
            "pirate", "bug", "rodent", "wolf", "plant", "festive", "demon", "ooze", "spirit" },
        picks = function() return ns.DB.global.scenePicks end,
        changed = function() ns.Scenes:Reset() end,
    },
    decor = {
        title = "Dyreparken: pynt",
        slots = { "corner", "border", "glow", "sparkle", "star", "heart", "bubble", "confetti", "ribbon", "frame" },
        picks = function() return ns.DB.global.decorPicks end,
        changed = function() end,
    },
}

local views = {} -- mode -> { frame, grid, thumbs, selected }

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
    view.frame.hint:SetText(("Valgt: %s. Klikk et bilde for å velge det, høyreklikk for å fjerne."):format(
        view.selected))
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
    for i, f in ipairs(cfg.slots) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(84, 20)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        b.family = f
        b:SetScript("OnClick", function() view.selected = f; Redraw(view) end)
        frame.families[i] = b
        x = x + 88
        if x + 84 > width - 10 then x, y = 12, y - 24 end
    end
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y - 26)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y - 44)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    view.grid = CreateFrame("Frame", nil, scroll)
    view.grid:SetSize(COLS * (THUMB_W + GAP), 1)
    scroll:SetScrollChild(view.grid)
    view.frame = frame
    views[mode] = view
    return view
end

local function NewThumb(view)
    local t = CreateFrame("Button", nil, view.grid)
    t:SetSize(THUMB_W, THUMB_H + 28)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t.image = t:CreateTexture(nil, "ARTWORK")
    t.image:SetPoint("TOPLEFT")
    t.image:SetSize(THUMB_W, THUMB_H)
    t.backing = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    t.backing:SetAllPoints(t.image)
    t.backing:SetColorTexture(0.12, 0.1, 0.08, 1) -- so a glow or a sparkle shows
    t.border = t:CreateTexture(nil, "BACKGROUND")
    t.border:SetPoint("TOPLEFT", -3, 3)
    t.border:SetSize(THUMB_W + 6, THUMB_H + 6)
    t.border:SetColorTexture(1, 0.82, 0, 1)
    t.label = t:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    t.label:SetPoint("TOPLEFT", t.image, "BOTTOMLEFT", 0, -2)
    t.label:SetPoint("RIGHT", t, "RIGHT")
    t.label:SetJustifyH("LEFT")
    t.label:SetWordWrap(false)
    t.used = t:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    t.used:SetPoint("TOPLEFT", t.label, "BOTTOMLEFT", 0, -1)
    t:SetScript("OnClick", function(self, button) OnClick(view, self, button) end)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.path, 1, 1, 1)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    view.thumbs[#view.thumbs + 1] = t
    return t
end

-- Show the candidates that exist: { n, path } (a file path, or "atlas:name").
function Gallery:Show(list, mode)
    mode = mode or "bg"
    local view = views[mode] or Build(mode)
    for _, t in ipairs(view.thumbs) do t:Hide() end
    for i, c in ipairs(list) do
        local t = view.thumbs[i] or NewThumb(view)
        t.path = c.path
        local atlas = c.path:match("^atlas:(.+)$")
        if atlas then t.image:SetAtlas(atlas) else t.image:SetTexture(c.path) end
        t.label:SetText(("%d %s"):format(c.n, (c.path:match("([^\\\\:]+)$") or c.path)))
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", view.grid, "TOPLEFT", col * (THUMB_W + GAP), -row * (THUMB_H + 36))
        t:Show()
    end
    view.grid:SetHeight(math.ceil(#list / COLS) * (THUMB_H + 36))
    Redraw(view)
    view.frame:Show()
    Gallery._frame, Gallery._thumbs = view.frame, view.thumbs
end
