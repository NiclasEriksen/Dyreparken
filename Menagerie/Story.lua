---@class Dyreparken
local ns = select(2, ...)

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
-- Shown from a small book button on the card, as a panel right of the Collections window, newest first.
-- The panel has tabs (2026-11-19, the user: more about a pet than the card has room for): the story,
-- and the ones AboutPet.lua adds (Story:AddTab), its personality in full and everyone's bonds with it.
-- The book shows for every pet, with an arrow that says the panel opens out to the side.
---@class Dyreparken.Story
local Story = {}
ns.Story = Story

Story.MAX = 80 -- entries per pet; the oldest go first
Story.WIDTH = 300
-- Flavor older than FLAVOR_DAYS (the lines it said, its days as the pet of the day) is folded into one grey line
-- a run, "N interaksjoner" (2026-11-19, the user: the milestones stay; the story is the biggest thing we keep).
-- Its eggs stay known (s.eggs), so one isn't added again as new.
Story.FLAVOR = { egg = true, day = true }
Story.FLAVOR_DAYS = 30

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
    if e.k == "egg" and s.eggs and s.eggs[e.x] then return false end -- (one folded away already)
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

-- Old flavor folded into "many" lines (FLAVOR_DAYS), next ones joined: { t = the first, u = the last, v = how many }.
function Story.Compact(s, now)
    local cut, out, changed = now - Story.FLAVOR_DAYS * 86400, {}, false
    for _, e in ipairs(s.e) do
        local old = Story.FLAVOR[e.k] and e.t < cut
        if old or e.k == "many" then
            if old then
                changed = true
                if e.k == "egg" and e.x then s.eggs = s.eggs or {}; s.eggs[e.x] = true end
            end
            local n, u = e.k == "many" and e.v or 1, e.u or e.t
            local last = out[#out]
            if last and last.k == "many" then
                last.v, last.u, changed = last.v + n, math.max(last.u, u), true
            else
                out[#out + 1] = { t = e.t, k = "many", v = n, u = u }
            end
        else
            out[#out + 1] = e
        end
    end
    if changed then s.e = out end
    return changed
end

-- Its carers' levels seen, members only (as g.life: the roster prunes them, review 2026-11-19: never pruned).
local function PruneLevels(s, roster)
    for carer in pairs(s.lv or {}) do if not roster[carer] then s.lv[carer] = nil end end
end

function Story:Scan()
    local g = G()
    if not g then return end
    g.story = g.story or {}
    local now = ns.Now()
    local roster = ns.Registry.Roster()
    for _, s in pairs(g.story) do
        Story.Compact(s, now)
        if roster then PruneLevels(s, roster) end
    end
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

-- After new entries: an open panel. (The book shows for every pet: Update; under our pages it stays hidden
-- until the card is drawn anew.)
function Story:Changed()
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
    if k == "many" then return ns.T("story.many", { n = v }) end
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
local ICON = "Interface\\Icons\\INV_Misc_Book_09"
local SIZE = 30

-- The book button's tooltip.
function Story.ButtonLines(key)
    if not key then return nil end
    local open = Story:IsOpen() and Story.panel.key == key
    return { { ns.T("about.title", { pet = ns.Registry:NameOf(key) }), 1, 0.82, 0 },
        { ns.L["about.tip"], 1, 1, 1, true },
        { ns.L[open and "about.close" or "about.open"], 0.6, 0.6, 0.6 } }
end

-- The panel's tabs, in order: { id, title, draw = fn(page, key, width) -> height }. The story's is the first.
Story.TABS = {}
function Story:AddTab(tab)
    assert(tab.id and tab.title and tab.draw, "Story:AddTab: id, title, draw")
    for _, t in ipairs(self.TABS) do assert(t.id ~= tab.id, "Story:AddTab: " .. tab.id .. " twice") end
    self.TABS[#self.TABS + 1] = tab
end
local function TabOf(id)
    for _, t in ipairs(Story.TABS) do if t.id == id then return t end end
end

-- The arrow beside the book: points out of the window (the panel opens there), back in while it's open.
local ARROW_OUT, ARROW_IN = -math.pi / 2, math.pi / 2
function Story:Arrow()
    local card = ns.JournalUI and ns.JournalUI:Card()
    local b = card and card.story
    if not (b and b.arrow) then return end
    local open = self:IsOpen() and self.panel.key == card.key
    b.arrow:SetRotation(open and ARROW_IN or ARROW_OUT)
    b.arrow:SetVertexColor(1, 0.82, 0.3, open and 1 or 0.85)
end

function Story:Build(card, c)
    local b = ns.RoundBadge(c, SIZE, { disc = 2, ring = true, ringOver = true, icon = ICON, iconSize = 0.62,
        texCoord = { 0.08, 0.92, 0.08, 0.92 }, hover = { 1, 0.85, 0.5, 0.5 } })
    b.card = card
    b:SetPoint("TOPRIGHT", c, "TOPRIGHT", -19, -70) -- (under the "Med deg" badge and its label)
    b:SetFrameLevel(c:GetFrameLevel() + 30)
    b:SetScript("OnClick", function() Story:Toggle(card.key) end)
    ns.SetTip(b, "ANCHOR_LEFT", function() return Story.ButtonLines(card.key) end)
    -- It opens something out to the side: an arrow says so (2026-11-19, the user: "make it obvious").
    b.arrow = b:CreateTexture(nil, "OVERLAY")
    b.arrow:SetTexture(ns.Icon("chevron"))
    b.arrow:SetSize(12, 12)
    b.arrow:SetPoint("LEFT", b, "RIGHT", 0, 0)
    b:Hide()
    card.story = b
    self:Arrow()
end

-- The pet on the card: the button for any pet; an open panel follows the card.
function Story:Update(card, key)
    local b = card.story
    if not b then return end
    b:SetShown(key ~= nil)
    if not key then return self:Close() end -- (no pet on the card: not the last one's story beside it)
    if self.panel and self.panel:IsShown() and key ~= self.panel.key then self:Show(key) end
    self:Arrow()
end

-- Dense (2026-11-14, the user: "more dense"): the text in the small font, as
-- the date above it, and a small gap between entries, so a long life shows more
-- at once. The date is a line of the small font (about 12 px; was 14 with the
-- big text, and a 10 px gap).
local ROW_GAP = 4
local DATE_H = 12

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
        -- No buttons at the bottom: Blizzard's own call gives the inset that strip (2026-11-14, "more dense").
        if ButtonFrameTemplate_HideButtonBar then ButtonFrameTemplate_HideButtonBar(f) end
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
        inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6) -- (no button bar, as above)
    end
    f.scroll = CreateFrame("ScrollFrame", nil, inset, "UIPanelScrollFrameTemplate")
    f.scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
    f.scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 4) -- (room for the scroll bar on the right)
    f.child = CreateFrame("Frame", nil, f.scroll)
    f.child:SetSize(self.WIDTH - 46, 1)
    f.scroll:SetScrollChild(f.child)
    f.rows = {}
    f.pages = { story = f.child } -- (each tab's own scroll child, made when first shown)
    -- The tabs, under the title: plain words, the chosen one bright with a gold line under it.
    f.tabs = {}
    local x = 12
    for _, t in ipairs(self.TABS) do
        local b = CreateFrame("Button", nil, f)
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b.text:SetPoint("CENTER")
        b.text:SetText(t.title)
        local w = (b.text:GetStringWidth() or 40) + 16
        b:SetSize(w, 22)
        b:SetPoint("TOPLEFT", f, "TOPLEFT", x, -30)
        b.line = b:CreateTexture(nil, "ARTWORK")
        b.line:SetColorTexture(1, 0.82, 0, 0.9)
        b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 0)
        b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -4, 0)
        b.line:SetHeight(2)
        b.hover = b:CreateTexture(nil, "HIGHLIGHT")
        b.hover:SetColorTexture(1, 0.82, 0, 0.12)
        b.hover:SetAllPoints()
        b:SetScript("OnClick", function() Story:Tab(t.id) end)
        b.id = t.id
        f.tabs[#f.tabs + 1] = b
        x = x + w + 2
    end
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
    r.text = f.child:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.text:SetJustifyH("LEFT")
    r.text:SetWidth(Story.WIDTH - 50) -- (wider lines wrap less)
    r.text:SetWordWrap(true)
    f.rows[i] = r
    return r
end

-- Draws the open tab for f.key.
function Story:Redraw()
    local f = self.panel
    if not (f and f:IsShown() and f.key) then return end
    local key = f.key
    f:SetStoryTitle(ns.T("about.title", { pet = ns.Registry:NameOf(key) }))
    local tab = TabOf(self.tab) or self.TABS[1]
    for _, b in ipairs(f.tabs) do
        local on = b.id == tab.id
        b.line:SetShown(on)
        if on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(0.8, 0.7, 0.45) end
    end
    local page = f.pages[tab.id]
    if not page then
        page = CreateFrame("Frame", nil, f.scroll)
        page:SetSize(self.WIDTH - 46, 1)
        f.pages[tab.id] = page
    end
    for id, p in pairs(f.pages) do p:SetShown(id == tab.id) end
    f.scroll:SetScrollChild(page)
    page:SetHeight(math.max(1, tab.draw(page, key, self.WIDTH - 46) or 1))
    f.scroll:SetVerticalScroll(0)
end

-- The story itself, newest at the top.
local function DrawStory(_, key)
    local self, f = Story, Story.panel
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
        r.date:SetText(e.u and e.u ~= e.t and ns.Date(e.u) ~= ns.Date(e.t) and (ns.Date(e.t) .. " – " .. ns.Date(e.u))
            or ns.Date(e.t))
        r.text:ClearAllPoints()
        r.text:SetPoint("TOPLEFT", r.date, "BOTTOMLEFT", 0, -1)
        r.text:SetText(self:Text(key, e, i == firstAdopt))
        -- (folded flavor in grey: it's been shortened, the user)
        if e.k == "many" then r.text:SetTextColor(0.6, 0.6, 0.6) else r.text:SetTextColor(1, 1, 1) end
        r.date:Show(); r.text:Show()
        y = y + DATE_H + 1 + (r.text:GetStringHeight() or 12) + ROW_GAP
    end
    if n == 0 then
        local r = Row(f, 1)
        r.date:Hide()
        r.text:ClearAllPoints()
        r.text:SetPoint("TOPLEFT", f.child, "TOPLEFT", 0, 0)
        r.text:SetText(ns.L["story.none"])
        r.text:Show()
        n, y = 1, 16
    end
    for i = n + 1, #f.rows do f.rows[i].date:Hide(); f.rows[i].text:Hide() end
    return y
end
Story:AddTab({ id = "story", title = ns.L["about.tab.story"], draw = DrawStory })

-- Opens the panel on a pet; tab: which (nil: the one last open this session, else the story).
function Story:Show(key, tab)
    -- (the window our pages live in: known once the journal has loaded, as the card's button needs too)
    if not (key and ns.SidePage:Host()) then return end
    if tab then self.tab = tab end
    if not self.panel then self:BuildPanel() end
    self.panel.key = key
    Place(self.panel) -- (each time: the tabs may have moved since)
    self.panel:Show()
    self:Redraw()
    self:Arrow()
end

-- Another tab of the open panel.
function Story:Tab(id)
    self.tab = id
    self:Redraw()
end

function Story:Close()
    if self.panel then self.panel:Hide(); self.panel.key = nil end
    self:Arrow()
end

function Story:IsOpen() return self.panel ~= nil and self.panel:IsShown() end

function Story:Toggle(key)
    if self:IsOpen() and self.panel.key == key then self:Close() else self:Show(key) end
end

-- Only the pets whose bonds changed (REGISTRY with keys, our own BOND), the whole guild otherwise: a guildmate's
-- bond line came about once a minute in a busy guild (the performance review, 2026-11-14).
local soon = { all = false, keys = {} }
local Rescan = ns.Debounce(2, function()
    local all, keys = soon.all, soon.keys
    soon.all, soon.keys = false, {}
    if all then return Story:Scan() end
    local g = G()
    if not g then return end
    g.story = g.story or {}
    local now = ns.Now()
    for key in pairs(keys) do ScanPet(g, key, now) end
    -- (and today's pet of the day, as Scan does: past midnight a bond change may be all that comes)
    local pick, holder = ns.Bonds:PetOfTheDay(now)
    if pick then Add(g, pick, { t = now, k = "day", w = holder, v = ns.Today(now) }) end
    Story:Changed()
end)
ns.Bus:On("REGISTRY", function(keys)
    if type(keys) == "table" then
        for k in pairs(keys) do soon.keys[k] = true end
    else
        soon.all = true
    end
    Rescan()
end)
ns.Bus:On("BOND", function(key)
    if key then soon.keys[key] = true else soon.all = true end
    Rescan()
end)
ns.Card.Register{ id = "story",
    build = function(card, c) Story:Build(card, c) end,
    update = function(card, key) Story:Update(card, key) end,
    -- Our pages cover the card: the panel closes, and the button hides (over the model's level, like the
    -- cake: it'd show through our page). The window closing closes the panel too: BuildPanel.
    pause = function(card) Story:Update(card, nil) end,
}
ns.Start("settled", function() Story:Scan() end)
