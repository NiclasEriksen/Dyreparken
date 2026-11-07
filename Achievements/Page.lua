local _, ns = ...

-- The achievements page of the Collections window.
--
-- Forever's Collections window has its tabs (Pets, Mounts, Toys, ...) down
-- the right edge (docs/FOREVER_API.md). We add a tab of our own under them,
-- built from the same atlases, on every page of the window. Clicking it
-- shows our page; clicking any of Blizzard's tabs goes back.
--
-- TAINT AND COMBAT: we never touch Blizzard's tab list or call its SetTab,
-- and never hide its pages (the Toys page holds secure buttons, which addon
-- code can't hide in combat). Our page simply COVERS the content area below
-- the title bar, above whatever page is showing. While it's up, Blizzard's
-- selected-tab highlight is hidden (a texture, no state) and the window
-- title reads "Prestasjoner"; both come back when we leave, unless Blizzard
-- already set them anew. We leave when:
--   * one of Blizzard's tabs is pressed (OnMouseDown, hooked),
--   * one of its pages shows (OnShow, hooked: a tab we didn't see),
--   * the window hides.
--
-- The page: grouped by category (Defs.lua `cat`); each row an icon, name and
-- description, a progress bar or the date earned, and a Del button on what
-- you can share (Ach:Shareable; a click, so Forever lets it post to guild
-- chat). Hovering a row lists the pets behind it (Ach:Details).
-- Built on first use, refreshed only while shown.
--
-- Without side tabs (a Retail-style window), a "Prestasjoner" button left of
-- Auto-summon opens the page instead.
local Page = {}
ns.AchPage = Page

local ROW_H, HEADER_H, TITLE_H = 46, 26, 26
local CATS = { "collection", "family", "loyalty", "guild" }
local NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ICON = "Interface\\Icons\\Achievement_General" -- (unverified) on Forever
local SELECTED = "common-sidetab-selected"

local host, journal, page, child, tab, textButton
local rows, headers = {}, {} -- id -> row, cat -> font string
local hidden = {}            -- Blizzard's selected highlights we hid
local savedTitle             -- the window title we replaced
Page._rows, Page._headers = rows, headers

local function T() return ns.AchTexts.generic end
local function A() return ns.Achievements end

------------------------------------------------------------------------------
-- Finding the side tabs
------------------------------------------------------------------------------
-- What starts at or past the window's right edge. On Forever the tabs sit in
-- an unnamed strip as tall as the window (probed 2026-11-07); a frame at
-- least half the window's height is such a container (look inside, two
-- levels at most), anything smaller is a tab. Returns the shown tabs top to
-- bottom.
local function SideTabs()
    local right = host:GetRight()
    local tabs = {}
    if not right then return tabs end
    local tall = (host:GetHeight() or 0) / 2
    local function Scan(parent, depth)
        for _, f in ipairs({ parent:GetChildren() }) do
            local left = f ~= tab and f:IsShown() and f:GetLeft()
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

-- A tab's "selected" highlight textures (atlas common-sidetab-selected).
local function SelectedRegions(f)
    local list = {}
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetAtlas and r:GetAtlas() == SELECTED then list[#list + 1] = r end
    end
    return list
end

------------------------------------------------------------------------------
-- Rows
------------------------------------------------------------------------------
local function ShowTooltip(r)
    local it = r.data
    local tx = ns.AchTexts[it.id] or {}
    GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
    GameTooltip:SetText(A():Name(it.id))
    if tx.desc then GameTooltip:AddLine(tx.desc, 1, 1, 1, true) end
    if it.got then
        GameTooltip:AddLine(T().tip_earned:format(date("%d.%m.%Y", it.got.at)), 0.25, 1, 0.25)
        if type(it.got.ann) == "number" then GameTooltip:AddLine(T().tip_shared, 0.7, 0.7, 0.7) end
    elseif it.need then
        GameTooltip:AddLine(A():Progress(it.def, it.have, it.need), 0.7, 0.7, 0.7)
    end
    local title, items, more = A():Details(it.def, Page.ctx)
    if items then
        GameTooltip:AddLine(" ")
        if title then GameTooltip:AddLine(title, 1, 0.82, 0) end
        for _, item in ipairs(items) do
            if item.done then
                GameTooltip:AddLine(item.text, 0.25, 1, 0.25)
            else
                GameTooltip:AddLine(item.text, 0.6, 0.6, 0.6)
            end
        end
        if more > 0 then GameTooltip:AddLine(T().tip_more:format(more), 0.6, 0.6, 0.6) end
    end
    GameTooltip:Show()
end

local function HideTooltip(self)
    if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
end

local function NewRow(id)
    local r = CreateFrame("Button", nil, child)
    r:SetHeight(ROW_H)
    r.bg = r:CreateTexture(nil, "BACKGROUND")
    r.bg:SetAllPoints()
    r.bg:SetColorTexture(1, 1, 1, 0.04)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(38, 38)
    r.icon:SetPoint("LEFT", r, "LEFT", 4, 0)

    r.share = CreateFrame("Button", nil, r, "UIPanelButtonTemplate")
    r.share:SetSize(46, 22)
    r.share:SetPoint("RIGHT", r, "RIGHT", -6, 0)
    r.share:SetText(T().share_button)
    r.share:SetScript("OnClick", function() A():Share(id) end)
    r.share:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(T().share_button_tip)
        GameTooltip:Show()
    end)
    r.share:SetScript("OnLeave", HideTooltip)

    -- Right side: the date earned, or a bar with the progress on it.
    r.info = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.bar = CreateFrame("StatusBar", nil, r)
    r.bar:SetSize(150, 14)
    r.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    r.bar:SetStatusBarColor(0.1, 0.6, 0.1)
    r.bar.bg = r.bar:CreateTexture(nil, "BACKGROUND")
    r.bar.bg:SetAllPoints()
    r.bar.bg:SetColorTexture(0, 0, 0, 0.5)
    r.bar.text = r.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.bar.text:SetPoint("CENTER", r.bar, "CENTER", 0, 0)

    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -3)
    r.name:SetPoint("RIGHT", r.bar, "LEFT", -8, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.desc = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.desc:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 8, 3)
    r.desc:SetPoint("RIGHT", r.bar, "LEFT", -8, 0)
    r.desc:SetJustifyH("LEFT")
    r.desc:SetWordWrap(false)

    r:SetScript("OnEnter", ShowTooltip)
    r:SetScript("OnLeave", HideTooltip)
    rows[id] = r
    return r
end

local function Header(cat)
    local h = headers[cat]
    if not h then
        h = child:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        h:SetJustifyH("LEFT")
        headers[cat] = h
    end
    h:SetText(T()["cat_" .. cat] or cat)
    return h
end

local function FillRow(r, it)
    r.data = it
    r.icon:SetTexture(it.def.icon or NO_ICON)
    r.icon:SetDesaturated(not it.got)
    r.name:SetText(A():Name(it.id))
    r.desc:SetText((ns.AchTexts[it.id] or {}).desc or "")
    local canShare = A():Shareable(it.id)
    r.share:SetShown(canShare)
    -- What's on the right sits left of Del when there is one.
    local edge, x = r, -10
    if canShare then edge, x = r.share, -8 end
    local point = edge == r and "RIGHT" or "LEFT"
    r.bar:ClearAllPoints()
    r.bar:SetPoint("RIGHT", edge, point, x, 0)
    r.info:ClearAllPoints()
    r.info:SetPoint("RIGHT", edge, point, x, 0)
    if it.got then
        r.name:SetTextColor(1, 0.82, 0)
        r.desc:SetTextColor(1, 1, 1)
        r.info:SetText(A():RowInfo(it))
        r.info:Show()
        r.bar:Hide()
    else
        r.name:SetTextColor(0.6, 0.6, 0.6)
        r.desc:SetTextColor(0.5, 0.5, 0.5)
        r.info:Hide()
        r.bar:SetMinMaxValues(0, math.max(it.need or 1, 1))
        r.bar:SetValue(it.have or 0)
        r.bar.text:SetText(A():RowInfo(it))
        r.bar:Show()
    end
end

function Page:Refresh()
    if not (page and page:IsVisible()) then return end
    local list, ctx = A():Rows()
    Page.ctx = ctx
    local byCat = {}
    for _, it in ipairs(list) do
        local cat = it.def.cat or "collection"
        byCat[cat] = byCat[cat] or {}
        table.insert(byCat[cat], it)
    end
    for _, r in pairs(rows) do r:Hide() end
    for _, h in pairs(headers) do h:Hide() end
    local y, earned = 4, 0
    for _, cat in ipairs(CATS) do
        local items = byCat[cat]
        if items then
            local h = Header(cat)
            h:ClearAllPoints()
            h:SetPoint("TOPLEFT", child, "TOPLEFT", 6, -y)
            h:Show()
            y = y + HEADER_H
            for _, it in ipairs(items) do
                local r = rows[it.id] or NewRow(it.id)
                r:ClearAllPoints()
                r:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
                r:SetPoint("RIGHT", child, "RIGHT", 0, 0)
                FillRow(r, it)
                r:Show()
                if it.got then earned = earned + 1 end
                y = y + ROW_H + 2
            end
            y = y + 8
        end
    end
    child:SetHeight(y)
    page.summary:SetText(T().page_summary:format(earned, #list))
end

------------------------------------------------------------------------------
-- Showing and leaving the page
------------------------------------------------------------------------------
local function TitleText()
    local get = rawget(host, "GetTitleText") -- PortraitFrameMixin
    return get and get(host)
end

local function Build()
    -- The content area below the title bar, on top of whatever page shows.
    page = CreateFrame("Frame", "DyreparkenAchievementsPage", host)
    page:SetPoint("TOPLEFT", host, "TOPLEFT", 4, -TITLE_H)
    page:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -4, 4)
    page:SetFrameLevel(host:GetFrameLevel() + 500)
    page:EnableMouse(true)
    page.bg = page:CreateTexture(nil, "BACKGROUND")
    page.bg:SetAllPoints()
    page.bg:SetColorTexture(0.06, 0.05, 0.04, 1)
    page.summary = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    page.summary:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, -10)
    page.heading = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    page.heading:SetPoint("TOPLEFT", page, "TOPLEFT", 14, -10)
    page.heading:SetText(T().page_title)

    local scroll = CreateFrame("ScrollFrame", nil, page, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", page, "TOPLEFT", 8, -34)
    scroll:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -28, 8)
    child = CreateFrame("Frame", nil, scroll)
    child:SetSize((host:GetWidth() or 703) - 44, 1)
    scroll:SetScrollChild(child)
    page:SetScript("OnShow", function() Page:Refresh() end)
    Page._page = page
    page:Hide()
end

function Page:IsOpen() return page ~= nil and page:IsVisible() end

function Page:Open()
    if not page then Build() end
    if page:IsShown() then return end
    -- Blizzard's tab looks unselected while we're up.
    for _, f in ipairs(SideTabs()) do
        for _, r in ipairs(SelectedRegions(f)) do
            if r:IsShown() then r:Hide(); hidden[#hidden + 1] = r end
        end
    end
    local fs = TitleText()
    if fs then
        savedTitle = fs:GetText()
        fs:SetText(T().page_title)
    end
    if tab.selected then tab.selected:Show() end
    page:Show()
end

function Page:Close()
    if not (page and page:IsShown()) then return end
    page:Hide()
    if tab.selected then tab.selected:Hide() end
    -- Put back what we hid, unless Blizzard has selected a tab since (then
    -- its own update already drew the right one).
    local any = false
    for _, f in ipairs(SideTabs()) do
        for _, r in ipairs(SelectedRegions(f)) do any = any or r:IsShown() end
    end
    if not any then
        for _, r in ipairs(hidden) do r:Show() end
    end
    hidden = {}
    local fs = TitleText()
    if fs and fs:GetText() == T().page_title then fs:SetText(savedTitle) end
    savedTitle = nil
end

------------------------------------------------------------------------------
-- Our tab
------------------------------------------------------------------------------
local hooked = setmetatable({}, { __mode = "k" })

local function ButtonTip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(T().page_title)
    GameTooltip:Show()
end

-- Our tab under the last of Blizzard's, the same size and spacing; and
-- leave our page when one of theirs is pressed. Runs each time the window
-- shows: tabs only have a position once it's laid out.
function Page:Layout()
    local tabs = SideTabs()
    ns.Log("Ach", "layout: %d side tabs", #tabs)
    for _, f in ipairs(tabs) do
        if not hooked[f] then
            hooked[f] = true
            f:HookScript("OnMouseDown", function() Page:Close() end)
        end
    end
    if #tabs == 0 then
        tab:Hide()
        textButton:Show()
        return
    end
    local last = tabs[#tabs]
    local gap = 2
    if #tabs >= 2 then gap = math.max(0, (tabs[#tabs - 1]:GetBottom() or 0) - (last:GetTop() or 0)) end
    tab:SetSize(last:GetWidth() or 55, last:GetHeight() or 55)
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -gap)
    tab:Show()
    textButton:Hide()
end

local function BuildTab()
    -- Like Forever's side tabs (probed 2026-11-07): background, the icon
    -- masked to the tab's shape, a selected and a hover highlight. The
    -- atlases are 55x60 on a 55x55 tab.
    tab = CreateFrame("Button", nil, host)
    tab:SetSize(55, 55)
    tab.bg = tab:CreateTexture(nil, "BACKGROUND")
    tab.bg:SetAtlas("common-sidetab")
    tab.bg:SetSize(55, 60)
    tab.bg:SetPoint("CENTER")
    tab.icon = tab:CreateTexture(nil, "ARTWORK")
    tab.icon:SetTexture(ICON)
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
    tab:SetScript("OnClick", function() Page:Open() end)
    tab:SetScript("OnEnter", ButtonTip)
    tab:SetScript("OnLeave", HideTooltip)
    tab:Hide()
    Page._tab = tab
end

-- Called once by JournalUI when Blizzard_Collections loads. `anchor` is the
-- Auto-summon checkbox, for the fallback button.
function Page:Attach(petJournal, anchor)
    journal = petJournal
    host = petJournal:GetParent() or petJournal -- CollectionsJournal
    BuildTab()

    textButton = CreateFrame("Button", nil, petJournal, "UIPanelButtonTemplate")
    textButton:SetSize(110, 22)
    textButton:SetPoint("RIGHT", anchor, "LEFT", -6, 0)
    textButton:SetText(T().page_title)
    textButton:SetScript("OnClick", function() Page:Open() end)
    Page._button = textButton

    -- Leave when another page shows (a tab we didn't see pressed) or the
    -- window closes.
    for _, f in ipairs({ host:GetChildren() }) do
        if f:GetObjectType() == "Frame" and f:GetName() then
            f:HookScript("OnShow", function() Page:Close() end)
        end
    end
    host:HookScript("OnHide", function() Page:Close() end)
    host:HookScript("OnShow", function() Page:Layout() end)
    if host:IsVisible() then Page:Layout() end
    ns.Bus:On("ACH", function() Page:Refresh() end)
    ns.Bus:On("REGISTRY", function() Page:Refresh() end)
end

-- /dp probe tabs: what the side tabs look like, to match them.
function Page:Probe()
    if not host then return ns.Print("Open the pet journal first.") end
    local L = function(...) ns.Log("Probe", ...) end
    L("host %s %s right=%s level=%s", tostring(host:GetName()), host:GetObjectType(), tostring(host:GetRight()),
        tostring(host:GetFrameLevel()))
    for i, f in ipairs({ host:GetChildren() }) do
        L("child %d %s %s shown=%s l=%s r=%s t=%s b=%s w=%s h=%s", i, tostring(f:GetName()), f:GetObjectType(),
            tostring(f:IsShown()), tostring(f:GetLeft()), tostring(f:GetRight()), tostring(f:GetTop()),
            tostring(f:GetBottom()), tostring(f:GetWidth()), tostring(f:GetHeight()))
    end
    local tabs = SideTabs()
    for i, f in ipairs(tabs) do
        L("tab %d %s %s l=%s t=%s w=%s h=%s kids=%d", i, tostring(f:GetName()), f:GetObjectType(),
            tostring(f:GetLeft()), tostring(f:GetTop()), tostring(f:GetWidth()), tostring(f:GetHeight()),
            select("#", f:GetChildren()))
        for j, r in ipairs({ f:GetRegions() }) do
            local tex = r.GetTexture and r:GetTexture()
            local atlas = r.GetAtlas and r:GetAtlas()
            L("tab %d region %d %s layer=%s tex=%s atlas=%s w=%s h=%s", i, j, r:GetObjectType(),
                tostring(r.GetDrawLayer and r:GetDrawLayer()), tostring(tex), tostring(atlas),
                tostring(r:GetWidth()), tostring(r:GetHeight()))
        end
    end
    ns.Print(("Probed %d side tabs; /reload and send the debug log."):format(#tabs))
end
