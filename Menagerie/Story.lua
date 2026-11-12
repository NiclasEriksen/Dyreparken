local _, ns = ...

-- A pet's story (2026-11-10, docs/PET_LIFE.md stage 5): a short timeline of
-- its life in the guild, as this client sees it. Local only, nothing on the
-- wire (the user: "only needs to be local for now"). What goes in (decided
-- with the user, 2026-11-10):
--   the guild's   adopt (moved in with someone), letgo (moved out, after how
--                 long), name / unname, level (a carer reached a bond level),
--                 milestone (1 month, 100 days, each year with its carer),
--                 day (pet of the day, the days this client saw it)
--   yours         first.boss, first.place, first.play (the very first only,
--                 with you), ach (an achievement earned with it out), egg (an
--                 easter egg with it: the line it said)
-- The guild's part is found by comparing the registry with what the story
-- last saw (Scan, after REGISTRY and BOND), so it starts with what's known
-- when it first runs: current homes and names with their real dates, and
-- milestones already passed. Anything that can't be dated is left out
-- (levels already reached, earlier carers: a bond's start isn't an adoption).
--
-- Data: g.story[petKey] = { e = { { t, k, w, v }... } oldest first, at most
-- Story.MAX; h = { o = owner, at } the home it's in; n = the name it had
-- (false: none); lv = { [carer] = level seen } }.
--
-- Shown from a small book button on the card (only when there's a story),
-- as a panel right of the Collections window, newest first.
local Story = {}
ns.Story = Story

Story.MAX = 80 -- entries per pet; the oldest go first
Story.WIDTH = 300

local function G() return ns.DB:Guild() end

local function State(g, key, make)
    local s = g.story[key]
    if not s and make then
        s = { e = {}, lv = {} }
        g.story[key] = s
    end
    return s
end

local DATED = { adopt = true, letgo = true, name = true, unname = true } -- (may happen again, another day)
local function Same(a, b)
    if a.k ~= b.k or a.w ~= b.w then return false end
    if a.k == "egg" then return a.x == b.x end -- (each egg once a pet, whatever line it said)
    return a.v == b.v and (a.t == b.t or not DATED[a.k])
end

-- Adds an entry (once), in time order. True if it was new.
local function Add(g, key, e)
    local s = State(g, key, true)
    for _, o in ipairs(s.e) do if Same(o, e) then return false end end
    local i = #s.e + 1
    while i > 1 and s.e[i - 1].t > e.t do i = i - 1 end
    table.insert(s.e, i, e)
    while #s.e > Story.MAX do table.remove(s.e, 1) end
    ns.Log("Story", "%s %s %s %s at %s", key, e.k, tostring(e.w), tostring(e.v), ns.Date(e.t))
    return true
end

local function Has(g, key, k, w)
    local s = State(g, key)
    for _, o in ipairs(s and s.e or {}) do if o.k == k and o.w == w then return true end end
end

------------------------------------------------------------------------------
-- The guild's part: what changed since the last look
------------------------------------------------------------------------------
-- Noon of the day `days` after t (milestones are calendar days, Bonds.DayNumber).
local function DaysAfter(t, days)
    local d = date("*t", t)
    return time({ year = d.year, month = d.month, day = d.day + days, hour = 12 })
end

-- Its anniversaries with a carer that have come by now (same days as the cake).
local function Milestones(g, key, h, now)
    local function At(t, label)
        if t <= now then Add(g, key, { t = t, k = "milestone", w = h.o, v = label .. "\31" .. h.at }) end
    end
    At(DaysAfter(h.at, 30), "month")
    At(DaysAfter(h.at, 100), "days100")
    local a = date("*t", h.at)
    for y = 1, tonumber(date("%Y", now)) - a.year do
        local day = a.day
        if a.month == 2 and day == 29 and date("*t", time({ year = a.year + y, month = 3, day = 0, hour = 12 })).day == 28 then
            day = 28
        end
        At(time({ year = a.year + y, month = a.month, day = day, hour = 12 }), "years" .. y)
    end
end

-- When a carer let it go: their record's change (they let go, or took
-- another pet), else their lapse, else now (seen just now).
local function LetGoTime(g, h, key, now)
    local r = g.claims[h.o]
    local t = (r and r.k ~= key and r.ts) or g.lapses[h.o] or now
    return math.max(h.at, math.min(t, now))
end

local function ScanPet(g, key, now)
    local s = State(g, key)
    local owner, r = ns.Registry:Holder(key)
    -- Its home.
    local h = s and s.h
    if h and (h.o ~= owner or h.at ~= (r and r.at)) then
        local t = LetGoTime(g, h, key, now)
        Add(g, key, { t = t, k = "letgo", w = h.o, v = ns.Bonds.DayNumber(t) - ns.Bonds.DayNumber(h.at) })
        s.h = nil
    end
    if owner and r and r.at and not (s and s.h) then
        Add(g, key, { t = r.at, k = "adopt", w = owner })
        s = State(g, key, true)
        s.h = { o = owner, at = r.at }
    end
    if s and s.h then Milestones(g, key, s.h, now) end
    -- Its name.
    local nick, by, at = ns.Registry:Nickname(key)
    if nick or (s and s.n) then
        s = State(g, key, true)
        if nick and nick ~= s.n then
            Add(g, key, { t = at or now, k = "name", w = by, v = nick })
        elseif not nick and s.n then
            Add(g, key, { t = now, k = "unname", w = owner, v = s.n })
        end
        s.n = nick or false
    end
    -- Its carers' bond levels: a new one after the first look (the first can't be dated).
    local life = g.life[key]
    if type(life) == "table" then
        for carer, e in pairs(life) do
            if type(e) == "table" and type(e.p) == "number" then
                local level = ns.Bond:Level(e.p)
                s = State(g, key, true)
                local seen = s.lv[carer]
                if seen and level > seen then
                    for l = math.max(seen + 1, 2), level do
                        Add(g, key, { t = math.min(e.t or now, now), k = "level", w = carer, v = l })
                    end
                end
                if not seen or level > seen then s.lv[carer] = level end
            end
        end
    end
end

function Story:Scan()
    local g = G()
    if not g then return end
    g.story = g.story or {}
    local now = ns.Now()
    local keys = {}
    for key in pairs(ns.Registry:Holders()) do keys[key] = true end
    for key, s in pairs(g.story) do if s.h or s.n then keys[key] = true end end
    for key in pairs(g.life) do keys[key] = true end
    for key in pairs(g.names) do keys[key] = true end
    for key in pairs(keys) do ScanPet(g, key, now) end
    -- Today's pet of the day, once a day (the days this client is on).
    local pick, holder = ns.Bonds:PetOfTheDay(now)
    if pick then Add(g, pick, { t = now, k = "day", w = holder, v = ns.Today(now) }) end
    self:Changed()
end

-- After new entries: the card's button (a first entry shows it) and an open panel.
function Story:Changed()
    local card = ns.JournalUI and ns.JournalUI:Card()
    if card and card.story and card.key then card.story:SetShown(self:Of(card.key) ~= nil) end
    self:Redraw()
end

------------------------------------------------------------------------------
-- Your part: told by the modules where it happens
------------------------------------------------------------------------------
-- A moment with your pet: once per kind and pet (each egg line, each achievement).
function Story:Mine(key, k, v, x)
    local g = G()
    if not (g and key) then return end
    local me = ns.PlayerKey()
    if k:sub(1, 6) == "first." and Has(g, key, k, me) then return end
    if Add(g, key, { t = ns.Now(), k = k, w = me, v = v, x = x }) then self:Changed() end
end

-- Achievements just earned (Achievements:Notify): with the pet out now.
function Story:Achievements(ids)
    local key = ns.Pets:OutKey()
    if not key then return end
    for _, id in ipairs(ids) do self:Mine(key, "ach", id) end
end

------------------------------------------------------------------------------
-- Reading it
------------------------------------------------------------------------------
-- The pet's entries, oldest first (nil if none).
function Story:Of(key)
    local g = G()
    local s = g and key and g.story and g.story[key]
    if s and #s.e > 0 then return s.e end
end

local function Days(n)
    if n <= 0 then return ns.L["story.days.0"] end
    if n == 1 then return ns.L["story.days.1"] end
    return ns.T("story.days", { n = n })
end

local function Who(w)
    if w == ns.PlayerKey() then return ns.L["home.you"] end
    return w or "?"
end

-- One entry as a line.
function Story:Text(key, e, first)
    local k, v = e.k, e.v
    local vars = { who = Who(e.w), pet = ns.Pets:NameOfKey(key) or "?" }
    if k == "adopt" then return ns.T(first and "story.first" or "story.adopt", vars) end
    if k == "letgo" then vars.days = Days(v or 0); return ns.T("story.letgo", vars) end
    if k == "name" or k == "unname" then vars.name = v; return ns.T(k == "name" and "story.name" or "story.unname", vars) end
    if k == "level" then
        local l = ns.Bond.LEVELS[v]
        vars.level, vars.n = l and l[2] or "?", v
        return ns.T("story.level", vars)
    end
    if k == "milestone" then
        local label = tostring(v):match("^[^\31]*")
        local years = label:match("^years(%d+)$")
        vars.time = years and ns.T("milestone.years", { n = tonumber(years) })
            or ns.L[label == "month" and "milestone.month" or "milestone.days100"]
        return ns.T("story.milestone", vars)
    end
    if k == "day" then return ns.L["story.day"] end
    if k == "first.boss" or k == "first.place" then
        vars.what = v
        return ns.T(k == "first.boss" and "story.first.boss" or "story.first.place", vars)
    end
    if k == "first.play" then
        local owner, theirs = tostring(v):match("^(.-)\31(.*)$")
        vars.owner, vars.friend = owner or "?", theirs and ns.Pets:NameOfKey(theirs) or "?"
        return ns.T("story.first.play", vars)
    end
    if k == "ach" then vars.name = ns.Achievements and ns.Achievements:Name(v) or tostring(v); return ns.T("story.ach", vars) end
    if k == "egg" then vars.line = v; return ns.T("story.egg", vars) end
    if k == "feat" then vars.what = v; return ns.T("story.feat", vars) end
    return k
end

------------------------------------------------------------------------------
-- The card's button and the panel
------------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\Dyreparken\\Media\\Particles\\"
local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local SIZE = 30

-- The book button's tooltip.
function Story.ButtonLines(key)
    if not key then return nil end
    return { { ns.T("story.title", { pet = ns.Registry:NameOf(key) }), 1, 0.82, 0 },
        { ns.T("story.tip", { n = #(Story:Of(key) or {}) }), 1, 1, 1, true } }
end

function Story:Build(card, c)
    local b = CreateFrame("Button", nil, c)
    b.card = card
    b:SetSize(SIZE, SIZE)
    b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -19, -70) -- (under the "Med deg" badge and its label)
    b:SetFrameLevel(c:GetFrameLevel() + 30)
    b.bg = b:CreateTexture(nil, "BORDER")
    b.bg:SetTexture(MEDIA .. "dot")
    b.bg:SetVertexColor(0, 0, 0, 0.75)
    b.bg:SetPoint("CENTER")
    b.bg:SetSize(SIZE - 2, SIZE - 2)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetTexture(ICON)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon:SetPoint("CENTER")
    b.icon:SetSize(SIZE * 0.62, SIZE * 0.62)
    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetAtlas("communities-ring-gold")
    b.ring:SetAllPoints()
    b.hover = b:CreateTexture(nil, "HIGHLIGHT")
    b.hover:SetTexture(MEDIA .. "dot")
    b.hover:SetBlendMode("ADD")
    b.hover:SetVertexColor(1, 0.85, 0.5, 0.5)
    b.hover:SetAllPoints()
    b:SetScript("OnClick", function() Story:Toggle(card.key) end)
    ns.SetTip(b, "ANCHOR_LEFT", function() return Story.ButtonLines(card.key) end)
    b:Hide()
    card.story = b
end

-- The pet on the card: the button if it has a story; an open panel follows the card.
function Story:Update(card, key)
    local b = card.story
    if not b then return end
    b:SetShown(self:Of(key) ~= nil)
    if self.panel and self.panel:IsShown() and key and key ~= self.panel.key then self:Show(key) end
end

local ROW_GAP = 10

-- Past the side tabs when they're laid out; else about their width (Forever's, seen 2026-11-10).
Story.TABS_W = 62
local function Place(f)
    local host = ns.SidePage:Host()
    local right, edge = ns.SidePage:TabsRight(), host:GetRight()
    local x = (right and edge) and (right - edge) or Story.TABS_W
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", host, "TOPRIGHT", x + 2, 0)
    f:SetPoint("BOTTOMLEFT", host, "BOTTOMRIGHT", x + 2, 0) -- (as tall as the window)
end

-- Like the Collections window itself (2026-11-10, the user: a plain dark box didn't
-- match): Blizzard's ButtonFrameTemplate without its portrait, the content in an
-- inset. Without the template (older clients), a plain frame of our own.
function Story:BuildPanel()
    local host = ns.SidePage:Host()
    local template = ns.SidePage.Template("ButtonFrameTemplate")
    -- On UIParent, not the window: as the window's child, the side tab scan
    -- (SidePage:TabsRight) took its buttons for tabs, and it crept right with
    -- every pet shown (2026-11-10). Hidden with the window by the hooks below.
    local f = CreateFrame("Frame", "DyreparkenStoryPanel", UIParent, template)
    f:SetFrameStrata(host:GetFrameStrata() or "HIGH")
    f:SetWidth(self.WIDTH)
    f:EnableMouse(true)
    if template then
        if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    else
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        f.bg:SetColorTexture(0.06, 0.05, 0.04, 0.95)
    end
    -- The title: the template's own title text, else ours.
    f.SetStoryTitle = function(_, text)
        if template and f.SetTitle then return f:SetTitle(text) end
        if not f.title then
            f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            f.title:SetPoint("TOP", f, "TOP", 0, -6)
            f.title:SetPoint("LEFT", f, "LEFT", 30, 0)
            f.title:SetPoint("RIGHT", f, "RIGHT", -30, 0)
            f.title:SetWordWrap(false)
        end
        f.title:SetText(text)
    end
    f.close = rawget(f, "CloseButton")
    if not f.close then
        f.close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    end
    f.close:SetScript("OnClick", function() Story:Close() end)
    local inset = rawget(f, "Inset")
    if not inset then
        inset = CreateFrame("Frame", nil, f, ns.SidePage.Template("InsetFrameTemplate"))
        inset:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
        inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 26)
    end
    f.scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 8, -8)
    f.scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 6)
    f.child = CreateFrame("Frame", nil, f.scroll)
    f.child:SetSize(self.WIDTH - 50, 1)
    f.scroll:SetScrollChild(f.child)
    f.rows = {}
    -- Only beside the pets: another tab of the window, or the window closing, closes it.
    if PetJournal then PetJournal:HookScript("OnHide", function() Story:Close() end) end
    host:HookScript("OnHide", function() Story:Close() end)
    self.panel = f
end

local function Row(f, i)
    local r = f.rows[i]
    if r then return r end
    r = {}
    r.date = f.child:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    r.date:SetJustifyH("LEFT")
    r.text = f.child:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetJustifyH("LEFT")
    r.text:SetWidth(Story.WIDTH - 54)
    r.text:SetWordWrap(true)
    f.rows[i] = r
    return r
end

-- Draws the story of f.key, newest at the top.
function Story:Redraw()
    local f = self.panel
    if not (f and f:IsShown() and f.key) then return end
    local key = f.key
    f:SetStoryTitle(ns.T("story.title", { pet = ns.Registry:NameOf(key) }))
    local list = self:Of(key) or {}
    local firstAdopt
    for i, e in ipairs(list) do if e.k == "adopt" then firstAdopt = i; break end end
    local y = 0
    local n = 0
    for i = #list, 1, -1 do
        local e = list[i]
        n = n + 1
        local r = Row(f, n)
        r.date:ClearAllPoints()
        r.date:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, -y)
        r.date:SetText(ns.Date(e.t))
        r.text:ClearAllPoints()
        r.text:SetPoint("TOPLEFT", r.date, "BOTTOMLEFT", 0, -2)
        r.text:SetText(self:Text(key, e, i == firstAdopt))
        r.date:Show(); r.text:Show()
        y = y + 14 + (r.text:GetStringHeight() or 14) + ROW_GAP
    end
    if n == 0 then
        local r = Row(f, 1)
        r.date:Hide()
        r.text:ClearAllPoints()
        r.text:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, 0)
        r.text:SetText(ns.L["story.none"])
        r.text:Show()
        n, y = 1, 20
    end
    for i = n + 1, #f.rows do f.rows[i].date:Hide(); f.rows[i].text:Hide() end
    f.child:SetHeight(math.max(1, y))
    f.scroll:SetVerticalScroll(0)
end

function Story:Show(key)
    -- (the window our pages live in: known once the journal has loaded, as the card's button needs too)
    if not (key and ns.SidePage:Host()) then return end
    if not self.panel then self:BuildPanel() end
    self.panel.key = key
    Place(self.panel) -- (each time: the tabs may have moved since)
    self.panel:Show()
    self:Redraw()
end

function Story:Close()
    if self.panel then self.panel:Hide(); self.panel.key = nil end
end

function Story:IsOpen() return self.panel ~= nil and self.panel:IsShown() end

function Story:Toggle(key)
    if self:IsOpen() and self.panel.key == key then self:Close() else self:Show(key) end
end

local Rescan = ns.Debounce(2, function() Story:Scan() end)
ns.Bus:On("REGISTRY", Rescan)
ns.Bus:On("BOND", Rescan)
ns.Card.Register{ id = "story",
    build = function(card, c) Story:Build(card, c) end,
    update = function(card, key) Story:Update(card, key) end,
    pause = function() Story:Close() end, -- (our pages cover the card; the window closing closes it: BuildPanel)
}
ns.Start("settled", function() Story:Scan() end)
