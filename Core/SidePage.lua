local _, ns = ...

-- Our own pages of the Collections window (achievements, the park map).
--
-- Forever's Collections window has its tabs (Pets, Mounts, Toys, ...) down
-- the right edge (docs/FOREVER_API.md). Each of our pages gets a tab under
-- them, built from the same atlases, on every page of the window. Clicking it
-- shows our page; clicking any of Blizzard's tabs, or another of ours, leaves.
--
-- TAINT AND COMBAT: we never touch Blizzard's tab list or call its SetTab,
-- and never hide its pages (the Toys page holds secure buttons, which addon
-- code can't hide in combat). Our page simply COVERS the content area below
-- the title bar, above whatever page is showing. While it's up, Blizzard's
-- selected-tab highlight is hidden (a texture, no state) and the window
-- title reads the page's title; both come back when we leave, unless
-- Blizzard already set them anew. The window's portrait and border reach into
-- the content area, so they're lifted above our page while it's up (frame
-- levels only), else the page cuts the round portrait in half. We leave when:
--   * one of Blizzard's tabs is pressed (OnMouseDown, hooked),
--   * one of its pages shows (OnShow, hooked: a tab we didn't see),
--   * another of our pages opens,
--   * the window hides.
--
-- Pages are built on first use and refreshed only while shown.
--
-- Without side tabs (a Retail-style window), text buttons left of the
-- Auto-summon checkbox open the pages instead.
--
-- A page: SidePage:New{ id, title, icon, build = fn(p), refresh = fn(p) }.
-- build fills p.frame (the cover, background already set); refresh redraws.
local SidePage = {}
ns.SidePage = SidePage

local TITLE_H = 21
local SELECTED = "common-sidetab-selected"
local LIFT = { "NineSlice", "PortraitContainer", "TitleContainer", "CloseButton" }

local pages = {}              -- in tab order
local ours = {}               -- our tab frames (not Blizzard's)
local host, anchor
local hidden = {}             -- Blizzard's selected highlights we hid
local lifted = {}             -- frame -> its level before we lifted it
local savedPortrait           -- { texture, its old file, ours as reported }
local savedTitle              -- the window title we replaced

local Proto = {}
Proto.__index = Proto

------------------------------------------------------------------------------
-- Finding the side tabs
------------------------------------------------------------------------------
-- What starts at or past the window's right edge. On Forever the tabs sit in
-- an unnamed strip as tall as the window (probed 2026-11-07); a frame at
-- least half the window's height is such a container (look inside, two
-- levels at most), anything smaller is a tab. Returns Blizzard's shown tabs
-- top to bottom.
function SidePage:SideTabs()
    local tabs = {}
    local right = host and host:GetRight()
    if not right then return tabs end
    local tall = (host:GetHeight() or 0) / 2
    local function Scan(parent, depth)
        for _, f in ipairs({ parent:GetChildren() }) do
            local left = not ours[f] and f:IsShown() and f:GetLeft()
            if left and left >= right - 8 then
                if (f:GetHeight() or 0) >= tall then
                    if depth < 2 then Scan(f, depth + 1) end
                else
                    tabs[#tabs + 1] = f
                end
            end
        end
    end
    Scan(host, 1)
    table.sort(tabs, function(a, b) return (a:GetTop() or 0) > (b:GetTop() or 0) end)
    return tabs
end

function SidePage:Host() return host end

-- A tab's "selected" highlight textures (atlas common-sidetab-selected).
local function SelectedRegions(f)
    local list = {}
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetAtlas and r:GetAtlas() == SELECTED then list[#list + 1] = r end
    end
    return list
end

------------------------------------------------------------------------------
-- Building
------------------------------------------------------------------------------
-- The first template the client has (C_XMLUtil.GetTemplateInfo), or nil.
function SidePage.Template(name)
    local X = C_XMLUtil
    if X and X.GetTemplateInfo and X.GetTemplateInfo(name) then return name end
end

local function TitleText()
    local get = rawget(host, "GetTitleText") -- PortraitFrameMixin
    return get and get(host)
end

-- Our background: the window's own (its Bg region, an atlas or a tiled
-- texture), so the page looks like part of it; else the classic rock.
local function MirrorBackground(dst)
    local src = rawget(host, "Bg")
    if src and src.GetObjectType and src:GetObjectType() == "Frame" then src = (src:GetRegions()) end
    local atlas = src and src.GetAtlas and src:GetAtlas()
    local tex = src and src.GetTexture and src:GetTexture()
    if atlas then
        dst:SetAtlas(atlas)
        return "atlas " .. atlas
    end
    tex = tex or "Interface\\FrameGeneral\\UI-Background-Rock"
    dst:SetTexture(tex, "REPEAT", "REPEAT")
    dst:SetHorizTile(true)
    dst:SetVertTile(true)
    return "texture " .. tostring(tex)
end

function Proto:Build()
    -- The whole window below the title bar, on top of whatever page shows.
    local f = CreateFrame("Frame", "Dyreparken" .. self.def.id .. "Page", host)
    f:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -TITLE_H)
    f:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    f:SetFrameLevel(host:GetFrameLevel() + 500)
    f:EnableMouse(true)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    ns.Log("Page", "%s background: %s", self.def.id, MirrorBackground(f.bg))
    self.frame = f
    self.def.build(self)
    f:SetScript("OnShow", function() self:Refresh() end)
    f:Hide()
end

-- A counter box at the top, centered like the pet page's "Total Pets".
-- Returns the value font string.
function SidePage:CounterBox(p, label)
    local box = CreateFrame("Frame", nil, p.frame, SidePage.Template("InsetFrameTemplate3"))
    box:SetSize(150, 20)
    box:SetPoint("TOP", host, "TOP", 0, -36)
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.label:SetPoint("LEFT", box, "LEFT", 10, 0)
    box.label:SetText(label)
    local value = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    value:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    return value
end

-- The inset below the portrait, with a scroll frame. Returns the scroll child.
function SidePage:ScrollInset(p, top)
    local inset = CreateFrame("Frame", nil, p.frame, SidePage.Template("InsetFrameTemplate"))
    inset:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -(top or 60))
    inset:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -6, 26)
    local scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 4, -4)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 4)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize((host:GetWidth() or 703) - 44, 1)
    scroll:SetScrollChild(child)
    return child
end

------------------------------------------------------------------------------
-- Showing and leaving
------------------------------------------------------------------------------
function Proto:IsOpen() return self.frame ~= nil and self.frame:IsVisible() end

function Proto:Refresh()
    if self:IsOpen() then self.def.refresh(self) end
end

function Proto:Open()
    if not self.frame then self:Build() end
    if self.frame:IsShown() then return end
    SidePage:CloseAll()
    -- Blizzard's tab looks unselected while we're up.
    for _, f in ipairs(SidePage:SideTabs()) do
        for _, r in ipairs(SelectedRegions(f)) do
            if r:IsShown() then r:Hide(); hidden[#hidden + 1] = r end
        end
    end
    local fs = TitleText()
    if fs then
        savedTitle = fs:GetText()
        fs:SetText(self.def.title)
    end
    if self.tab then self.tab.selected:Show() end
    -- The window's border, portrait, title and close button go above our
    -- page, all by the same amount so their own order stays (lifting only
    -- the border hid the title, seen 2026-11-07). Mixin parentKeys are plain
    -- fields: rawget, no errors if one is missing.
    local low
    for _, key in ipairs(LIFT) do
        local f = rawget(host, key)
        if f and f.SetFrameLevel then
            lifted[f] = f:GetFrameLevel()
            low = math.min(low or lifted[f], lifted[f])
        end
    end
    for f, level in pairs(lifted) do f:SetFrameLevel(self.frame:GetFrameLevel() + 10 + level - low) end
    -- Our icon in the round portrait.
    local portrait = rawget(host, "PortraitContainer")
    portrait = portrait and rawget(portrait, "portrait")
    if portrait then
        savedPortrait = { portrait, portrait:GetTexture() }
        portrait:SetTexture(self.def.icon)
        savedPortrait[3] = portrait:GetTexture() -- as the client reports ours
    end
    self.frame:Show()
    ns.Bus:Fire("SIDEPAGE", true)
end

function Proto:Close()
    if not (self.frame and self.frame:IsShown()) then return end
    self.frame:Hide()
    if self.tab then self.tab.selected:Hide() end
    -- Put back what we hid, unless Blizzard has selected a tab since (then
    -- its own update already drew the right one).
    local any = false
    for _, f in ipairs(SidePage:SideTabs()) do
        for _, r in ipairs(SelectedRegions(f)) do any = any or r:IsShown() end
    end
    if not any then
        for _, r in ipairs(hidden) do r:Show() end
    end
    hidden = {}
    for f, level in pairs(lifted) do f:SetFrameLevel(level) end
    lifted = {}
    -- The portrait back, unless Blizzard has set a new one since.
    if savedPortrait then
        local p, old, mine = savedPortrait[1], savedPortrait[2], savedPortrait[3]
        if p:GetTexture() == mine and old then p:SetTexture(old) end
        savedPortrait = nil
    end
    local fs = TitleText()
    if fs and fs:GetText() == self.def.title then fs:SetText(savedTitle) end
    savedTitle = nil
    ns.Bus:Fire("SIDEPAGE", false)
end

-- Is one of our pages covering the window? (The journal under it stays
-- "visible" to the client: JournalUI asks this before updating its card.)
function SidePage:AnyOpen()
    for _, p in ipairs(pages) do if p:IsOpen() then return true end end
    return false
end

function SidePage:CloseAll()
    for _, p in ipairs(pages) do p:Close() end
end

------------------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })

local function HideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

-- Our tabs under the last of Blizzard's, the same size and spacing; and
-- leave our pages when one of theirs is pressed. Runs each time the window
-- shows: tabs only have a position once it's laid out.
function SidePage:Layout()
    local tabs = self:SideTabs()
    ns.Log("Page", "layout: %d side tabs", #tabs)
    for _, f in ipairs(tabs) do
        if not hooked[f] then
            hooked[f] = true
            f:HookScript("OnMouseDown", function() SidePage:CloseAll() end)
        end
    end
    for _, p in ipairs(pages) do p.tab:SetShown(#tabs > 0); p.button:SetShown(#tabs == 0) end
    if #tabs == 0 then return end
    local last = tabs[#tabs]
    local gap = 2
    if #tabs >= 2 then gap = math.max(0, (tabs[#tabs - 1]:GetBottom() or 0) - (last:GetTop() or 0)) end
    for _, p in ipairs(pages) do
        p.tab:SetSize(last:GetWidth() or 55, last:GetHeight() or 55)
        p.tab:ClearAllPoints()
        p.tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
        last = p.tab
    end
end

local function BuildTab(p)
    -- Like Forever's side tabs (probed 2026-11-07): background, the icon
    -- masked to the tab's shape, a selected and a hover highlight. The
    -- atlases are 55x60 on a 55x55 tab.
    local tab = CreateFrame("Button", nil, host)
    tab:SetSize(55, 55)
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAtlas("common-sidetab")
    tab.bg:SetSize(55, 60)
    tab.bg:SetPoint("CENTER")
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetTexture(p.def.icon)
    tab.icon:SetSize(50, 50)
    tab.icon:SetPoint("CENTER")
    tab.mask = tab:CreateMaskTexture()
    tab.mask:SetAtlas("common-sidetab-mask")
    tab.mask:SetSize(55, 60)
    tab.mask:SetPoint("CENTER")
    tab.icon:AddMaskTexture(tab.mask)
    tab.selected = tab:CreateTexture(nil, "OVERLAY")
    tab.selected:SetAtlas(SELECTED)
    tab.selected:SetSize(55, 60)
    tab.selected:SetPoint("CENTER")
    tab.selected:Hide()
    tab.hover = tab:CreateTexture(nil, "HIGHLIGHT")
    tab.hover:SetAtlas("common-sidetab-hover")
    tab.hover:SetSize(55, 60)
    tab.hover:SetPoint("CENTER")
    tab:SetScript("OnClick", function() p:Open() end)
    tab:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(p.def.title)
        GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", HideTooltip)
    tab:Hide()
    ours[tab] = true
    p.tab = tab

    -- The fallback: a text button, right to left from the anchor.
    local b = CreateFrame("Button", nil, anchor:GetParent(), "UIPanelButtonTemplate")
    b:SetSize(110, 22)
    local prev
    for i, q in ipairs(pages) do if q == p then prev = pages[i - 1] end end
    if prev then b:SetPoint("RIGHT", prev.button, "LEFT", -4, 0)
    else b:SetPoint("RIGHT", anchor, "LEFT", -6, 0) end
    b:SetText(p.def.title)
    b:SetScript("OnClick", function() p:Open() end)
    b:Hide()
    p.button = b
end

function SidePage:New(def)
    local p = setmetatable({ def = def }, Proto)
    pages[#pages + 1] = p
    if host then BuildTab(p) end
    return p
end

-- Called once by JournalUI when Blizzard_Collections loads. `button` is the
-- Auto-summon checkbox, which the fallback buttons line up with.
function SidePage:Attach(petJournal, button)
    host = petJournal:GetParent() or petJournal -- CollectionsJournal
    anchor = button
    for _, p in ipairs(pages) do BuildTab(p) end
    -- Leave when another page shows (a tab we didn't see pressed) or the
    -- window closes.
    for _, f in ipairs({ host:GetChildren() }) do
        if f:GetObjectType() == "Frame" and f:GetName() then
            f:HookScript("OnShow", function() SidePage:CloseAll() end)
        end
    end
    host:HookScript("OnHide", function() SidePage:CloseAll() end)
    host:HookScript("OnShow", function() SidePage:Layout() end)
    if host:IsVisible() then SidePage:Layout() end
end
