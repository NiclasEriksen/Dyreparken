local _, ns = ...

-- A development tool: every candidate background that exists on this
-- client, as thumbnails, to pick one per family (/dp probe bg).
--
-- Choose a family at the top, then click a thumbnail: it becomes that
-- family's background at once (on the pet card), saved in
-- DyreparkenDB.scenePicks so the picks can be read from SavedVariables and
-- made the defaults (Scenes.BY_FAMILY). Right-click a thumbnail to clear
-- the families that use it.
local Gallery = {}
ns.SceneGallery = Gallery

local THUMB_W, THUMB_H, GAP, COLS = 168, 96, 8, 4
local frame, grid
local thumbs = {}
local selected = "default"
Gallery._thumbs = thumbs

local FAMILIES = { "default", "cat", "bird", "owl", "farm", "rabbit", "frog", "snake", "mechanical", "dragon",
    "pirate" }

local function Picks() return ns.DB.global.scenePicks end

-- Families that use a path, as text.
local function UsedBy(path)
    local list = {}
    for _, f in ipairs(FAMILIES) do if Picks()[f] == path then list[#list + 1] = f end end
    return table.concat(list, ", ")
end

local function Redraw()
    for _, t in ipairs(thumbs) do
        local used = UsedBy(t.path)
        t.used:SetText(used)
        t.border:SetShown(used ~= "")
    end
    for _, b in ipairs(frame.families) do
        local pick = Picks()[b.family]
        b:SetText(b.family .. (pick and " *" or ""))
        if b.family == selected then b:LockHighlight() else b:UnlockHighlight() end
    end
    frame.hint:SetText(("Familie: %s. Klikk et bilde for å velge det, høyreklikk for å fjerne."):format(selected))
end

local function OnClick(t, button)
    if button == "RightButton" then
        for _, f in ipairs(FAMILIES) do if Picks()[f] == t.path then Picks()[f] = nil end end
        ns.Log("Probe", "bg pick cleared: %s", t.path)
    else
        Picks()[selected] = t.path
        ns.Log("Probe", "bg pick %s = %s", selected, t.path)
    end
    ns.Scenes:Reset()
    Redraw()
    if ns.JournalUI.Refresh then ns.JournalUI:Refresh() end
end

local function Build()
    frame = CreateFrame("Frame", "DyreparkenSceneGallery", UIParent, "BasicFrameTemplateWithInset")
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
    frame.title:SetText("Dyreparken: bakgrunner")

    frame.families = {}
    local x, y = 12, -30
    for i, f in ipairs(FAMILIES) do
        local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        b:SetSize(84, 20)
        b:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        b.family = f
        b:SetScript("OnClick", function() selected = f; Redraw() end)
        frame.families[i] = b
        x = x + 88
        if x + 84 > width - 10 then x, y = 12, y - 24 end
    end
    frame.hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    frame.hint:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, y - 26)

    local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, y - 44)
    scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
    grid = CreateFrame("Frame", nil, scroll)
    grid:SetSize(COLS * (THUMB_W + GAP), 1)
    scroll:SetScrollChild(grid)
    Gallery._frame = frame
end

local function NewThumb()
    local t = CreateFrame("Button", nil, grid)
    t:SetSize(THUMB_W, THUMB_H + 28)
    t:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    t.image = t:CreateTexture(nil, "ARTWORK")
    t.image:SetPoint("TOPLEFT")
    t.image:SetSize(THUMB_W, THUMB_H)
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
    t:SetScript("OnClick", OnClick)
    t:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.path, 1, 1, 1)
        GameTooltip:Show()
    end)
    t:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    thumbs[#thumbs + 1] = t
    return t
end

-- Show the gallery with the candidates that exist (from Scenes:Probe).
function Gallery:Show(list)
    if not frame then Build() end
    for _, t in ipairs(thumbs) do t:Hide() end
    for i, c in ipairs(list) do
        local t = thumbs[i] or NewThumb()
        t.path = c.path
        t.image:SetTexture(c.path)
        t.label:SetText(("%d %s"):format(c.n, (c.path:match("([^\\\\]+)$") or c.path)))
        local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (THUMB_W + GAP), -row * (THUMB_H + 36))
        t:Show()
    end
    grid:SetHeight(math.ceil(#list / COLS) * (THUMB_H + 36))
    Redraw()
    frame:Show()
end
