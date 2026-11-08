local _, ns = ...

-- The achievements page of the Collections window (a SidePage, see
-- Core/SidePage.lua for the tab, covering and leaving).
--
-- The page: grouped by category (Defs.lua `cat`); each row an icon, name and
-- description, a progress bar or the date earned, and a Del button on what
-- you can share (Ach:Shareable; a click, so Forever lets it post to guild
-- chat). Hovering a row lists the pets behind it (Ach:Details).
local Page = {}
ns.AchPage = Page

local ROW_H, HEADER_H = 46, 26
local CATS = { "collection", "family", "loyalty", "guild" }
local ICON = "Interface\\Icons\\Achievement_General" -- (unverified) on Forever

local sp, page, child -- the SidePage, its frame, the scroll child
local rows, headers = {}, {} -- id -> row, cat -> font string
Page._rows, Page._headers = rows, headers

local function T() return ns.AchTexts.generic end
local function A() return ns.Achievements end

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
        GameTooltip:AddLine(ns.Fill(T().tip_earned, { date = date("%d.%m.%Y", it.got.at) }), 0.25, 1, 0.25)
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
        if more > 0 then GameTooltip:AddLine(ns.Fill(T().tip_more, { n = more }), 0.6, 0.6, 0.6) end
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
    r.icon:SetTexture(A():Icon(it.def))
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

local function Redraw()
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
    page.summary:SetText(("%d/%d"):format(earned, #list))
end

------------------------------------------------------------------------------
-- The page
------------------------------------------------------------------------------
local function Build(p)
    -- Laid out like the pet page: a counter box at the top and the list in an
    -- inset that starts below the portrait.
    page = p.frame
    page.summary = ns.SidePage:CounterBox(p, T().page_count)
    child = ns.SidePage:ScrollInset(p)
    Page._page = page
end

sp = ns.SidePage:New({ id = "Achievements", title = T().page_title, icon = ICON, build = Build, refresh = Redraw })

function Page:Refresh() sp:Refresh() end
function Page:IsOpen() return sp:IsOpen() end
function Page:Open() sp:Open() end
function Page:Close() sp:Close() end
function Page:Layout() ns.SidePage:Layout() end

-- Called once by JournalUI when Blizzard_Collections loads.
function Page:Attach(petJournal, anchor)
    ns.SidePage:Attach(petJournal, anchor)
    Page._tab, Page._button = sp.tab, sp.button
    ns.Bus:On("ACH", function() Page:Refresh() end)
    ns.Bus:On("REGISTRY", function() Page:Refresh() end)
end

-- /dp probe tabs: what the side tabs look like, to match them.
function Page:Probe()
    local host = ns.SidePage:Host()
    if not host then return ns.Print("Open the pet journal first.") end
    local L = function(...) ns.Log("Probe", ...) end
    L("host %s %s right=%s level=%s", tostring(host:GetName()), host:GetObjectType(), tostring(host:GetRight()),
        tostring(host:GetFrameLevel()))
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer", "CloseButton", "Bg", "TopTileStreaks" }) do
        local f = rawget(host, key)
        L("host.%s: %s level=%s", key, tostring(f ~= nil), tostring(f and f.GetFrameLevel and f:GetFrameLevel()))
    end
    for i, f in ipairs({ host:GetChildren() }) do
        L("child %d %s %s shown=%s l=%s r=%s t=%s b=%s w=%s h=%s", i, tostring(f:GetName()), f:GetObjectType(),
            tostring(f:IsShown()), tostring(f:GetLeft()), tostring(f:GetRight()), tostring(f:GetTop()),
            tostring(f:GetBottom()), tostring(f:GetWidth()), tostring(f:GetHeight()))
    end
    local tabs = ns.SidePage:SideTabs()
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
