---@class Dyreparken
local ns = select(2, ...)

-- The settings page (2026-11-10): a page of the Collections window like
-- Parken and Prestasjoner (Core/SidePage.lua), but with no side tab: a small
-- cog in the window's title bar opens it, left of the close button, on any of
-- our pages (AttachCog). The same rows are in Blizzard's options too (Canvas).
--
-- The four older settings are per character (char: autoSummon,
-- muteSummonSound, announce, achNotify) and keep their slash commands. The
-- new ones are for the account (DyreparkenDB.settings, Core/DB.lua):
--   chatter        how much the pet says in the chat (2026-11-15, the user; on/off until then, chatLines):
--                  "none" (the lines still happen and count, without a line; the user, 2026-11-10), "few",
--                  "normal", "many": Settings.CHATTER
--   worldHearts    hearts over a hovered companion, sparkles at the chat window
--   cardParticles  "all", "few" or "none" on the pet card
--   cardMoves      the pet on the card moves (asleep, hops, walks...)
--   celebrate      the bond level-up celebration on the card
--   petSounds      a click on the pet on its card plays its own sound (2026-11-16, on by default: Cuddle)
--   petFrame       the pet frame on screen (off by default; placed and sized in Edit Mode: PetFrame.lua)
--   petFrameArt    its background and border (off by default: it floats)
--   petFrameCombat hidden in combat; petFrameFade faded to petFrameAlpha (0.25) when nothing happens (2026-11-11)
--   hideUnknown    Parken shows a pet nobody in the guild has as a question mark (2026-11-15, on by default)
-- Modules read them with Settings:On(key) / Settings:Get(key).
---@class Dyreparken.Settings
local Settings = {}
ns.Settings = Settings

local L = ns.L

function Settings:Get(key) return ns.DB.global.settings[key] end
function Settings:On(key) return ns.DB.global.settings[key] ~= false end

-- "Småting i chatten", its four steps (2026-11-15, the user): `every` scales the cooldowns between lines
-- (Moments.BUDGETS: the quirks' 45 minutes, the reactions' 20), `egg` the chances of what's counted (eggs, a
-- dislike's discovery, a rare reaction), `flavor` those of the lines that are only lines (a common reaction,
-- a known dislike again, a minor like's line). "few": 90 minutes and half the chances, so fewer eggs found
-- (the user: "that's their tradeoff"); "many": 15 minutes and more of the lines, the eggs as they are (their
-- achievements stay as hard: an egg's wait stays 45 minutes too, Moments:Every). "none" counts as "normal",
-- its lines hidden.
Settings.CHATTER_STEPS = { "none", "few", "normal", "many" }
Settings.CHATTER = {
    none = { every = 1, egg = 1, flavor = 1 },
    few = { every = 2, egg = 0.5, flavor = 0.5 },
    normal = { every = 1, egg = 1, flavor = 1 },
    many = { every = 1 / 3, egg = 1, flavor = 1.5 },
}
function Settings:Chatter()
    local v = ns.DB.global.settings.chatter
    return self.CHATTER[v] and v or "normal"
end
-- The chat lines show (any step but "none").
function Settings:Chatty() return self:Chatter() ~= "none" end
-- A chance as the step makes it (kind: "egg" or "flavor"), at most 1.
function Settings:Chance(chance, kind)
    return math.min(1, chance * self.CHATTER[self:Chatter()][kind])
end

local function Set(key, value)
    ns.DB.global.settings[key] = value
    ns.Log("Settings", "%s = %s", key, tostring(value))
    if ns.JournalUI then ns.JournalUI:Refresh() end -- (the card follows at once)
end

-- The page in sections (2026-11-21, the user: "messy, and often overlaps its container"): each on a faint panel
-- with an icon and a gold line under its heading, in two columns of about the same height; settings for this
-- character alone marked with a grey * and a note under the columns. A section: { head, icon, column, rows };
-- a row: { key, tip, get, set } for a checkbox, { key, choices [, perLine] } for radio buttons, { key, steps }
-- or { key, slider } for a slider; `char`: this character's; `needs`: greyed and indented while it's false.
local SECTIONS = {
    { head = "settings.head.pet", icon = "paw", column = 1, rows = {
        { key = "settings.autosummon", get = function() return ns.DB.char.autoSummon and true or false end,
            set = function(v) ns.Summon:SetEnabled(v) end, char = true },
        { key = "settings.mute", get = function() return ns.DB.char.muteSummonSound and true or false end,
            set = function(v) ns.Summon:SetMuteSound(v) end, char = true },
    } },
    { head = "settings.head.frame", icon = "star", column = 1, rows = {
        -- (the hearts over a companion in the world: on screen too; here, the columns come out even, 2026-11-21)
        { key = "settings.hearts", setting = "worldHearts" },
        { key = "settings.petframe", get = function() return ns.PetFrame:Enabled() end,
            set = function(v) Set("petFrame", v); ns.PetFrame:Apply() end },
        { key = "settings.petframeart", get = function() return ns.Settings:Get("petFrameArt") == true end,
            set = function(v) Set("petFrameArt", v); ns.PetFrame:Apply() end,
            needs = function() return ns.PetFrame:Enabled() end }, -- (greyed and indented while the frame is off)
        { key = "settings.petframecombat", get = function() return ns.Settings:Get("petFrameCombat") == true end,
            set = function(v) Set("petFrameCombat", v); ns.PetFrame:Apply() end,
            needs = function() return ns.PetFrame:Enabled() end },
        { key = "settings.petframefade", get = function() return ns.Settings:Get("petFrameFade") == true end,
            set = function(v) Set("petFrameFade", v); ns.PetFrame:Apply() end,
            needs = function() return ns.PetFrame:Enabled() end },
        { key = "settings.petframealpha", slider = { 0.05, 0.9, 0.05 }, setting = "petFrameAlpha",
            set = function(v) Set("petFrameAlpha", v); ns.PetFrame:Apply() end,
            needs = function() return ns.PetFrame:Enabled() and ns.Settings:Get("petFrameFade") == true end },
    } },
    { head = "settings.head.park", icon = "tree", column = 1, rows = {
        { key = "settings.hideunknown", setting = "hideUnknown",
            set = function(v) Set("hideUnknown", v); ns.ParkPage:Refresh() end },
    } },
    { head = "settings.head.card", icon = "sparkle", column = 2, rows = {
        { key = "settings.particles", choices = { "all", "few", "none" }, setting = "cardParticles" },
        -- (the pet frame's stage too: it reads the setting only when it poses the pet, and walked on)
        { key = "settings.moves", setting = "cardMoves",
            set = function(v) Set("cardMoves", v); ns.PetFrame:Apply() end },
        { key = "settings.celebrate", setting = "celebrate" },
        { key = "settings.petsounds", setting = "petSounds" },
    } },
    { head = "settings.head.chat", icon = "speech", column = 2, rows = {
        { key = "settings.chatter", steps = Settings.CHATTER_STEPS, setting = "chatter" },
        -- (the client's chat windows, by their names: GetChatWindowInfo; one not set up isn't offered)
        { key = "settings.chatframe", choices = { "1", "2", "3", "4" }, perLine = 2, setting = "chatFrame",
            label = function(choice)
                local name = GetChatWindowInfo and ns.Plain((GetChatWindowInfo(tonumber(choice))))
                return type(name) == "string" and name ~= "" and name or ns.T("settings.chatframe.n", { n = choice })
            end },
        { key = "settings.announce", get = function() return ns.DB.char.announce and true or false end,
            set = function(v) ns.Bonds:SetAnnounce(v, true) end, char = true },
        { key = "settings.achnotify", get = function() return ns.DB.char.achNotify and true or false end,
            set = function(v) ns.Achievements:SetNotify(v, true) end, char = true },
        { key = "settings.achothers", setting = "achOthers" },
    } },
}
Settings.SECTIONS = SECTIONS
-- Every row, in order, each section's heading row ({ head, section }) before its rows (the tests walk them).
local ROWS = {}
for _, sec in ipairs(SECTIONS) do
    ROWS[#ROWS + 1] = { head = sec.head, section = sec }
    for _, row in ipairs(sec.rows) do ROWS[#ROWS + 1] = row end
end
Settings.ROWS = ROWS
-- The page's room: the inset is about 580 x 500 (seen 2026-11-21); two columns and the gaps around them.
Settings.PAGE = { w = 580, h = 500 }
Settings.GAP = 12 -- between the columns and around them, and between sections
Settings.COL_W = math.floor((Settings.PAGE.w - 3 * Settings.GAP) / 2)
-- Heights: a heading, a checkbox row (a line), a label over its widget, a radio line, a slider, a section's
-- padding below its last row.
Settings.H = { head = 30, check = 24, label = 18, radio = 22, slider = 26, pad = 8 }

local function Get(row)
    if row.get then return row.get() end
    return Settings:On(row.setting)
end

-- A setting's tooltip: what it does, and whether it's this character's alone.
function Settings.Lines(row)
    local lines = { { L[row.key], 1, 0.82, 0 }, { L[row.key .. ".tip"], 1, 1, 1, true } }
    if row.char then lines[3] = { L["settings.char"], 0.6, 0.6, 0.6, true } end
    return lines
end

local function Tip(self) ns.ShowTip(self, "ANCHOR_RIGHT", Settings.Lines(self.row)) end

-- One section's panel and rows, its top-left at x, y on `inset`; its widgets into `widgets`. Returns its height.
local function Section(inset, widgets, sec, x, y)
    local W, H = Settings.COL_W, Settings.H
    local panel = CreateFrame("Frame", nil, inset)
    panel:SetPoint("TOPLEFT", inset, "TOPLEFT", x, y)
    panel:SetWidth(W)
    panel.section = sec
    local bg = panel:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.3)
    local icon = panel:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(ns.Icon(sec.icon))
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -7)
    icon:SetVertexColor(1, 0.82, 0.3)
    local h = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    h:SetPoint("LEFT", icon, "RIGHT", 6, 0)
    h:SetText(L[sec.head])
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -H.head + 3)
    line:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -H.head + 3)
    line:SetHeight(1)
    local e = ns.BondBar.EDGE
    line:SetColorTexture(e[1], e[2], e[3], e[4])
    local top = -H.head - 2
    local function Label(row, indent)
        local label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", indent, top - 2)
        label:SetWidth(W - indent - 8)
        label:SetJustifyH("LEFT")
        label:SetText(L[row.key])
        top = top - H.label
        return label
    end
    local function Slider(row, label, lo, hi, step)
        local s = CreateFrame("Slider", nil, panel, "OptionsSliderTemplate")
        s:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, top - 6)
        s:SetSize(W - 100, 16)
        s:SetOrientation("HORIZONTAL")
        s:SetMinMaxValues(lo, hi)
        s:SetValueStep(step)
        s:SetObeyStepOnDrag(true)
        -- (the template's ends say "Low" and "High", in English; the value is beside it)
        for _, k in ipairs({ "Low", "High", "Text" }) do
            local fs = rawget(s, k)
            if fs and fs.SetText then fs:SetText("") end
        end
        s.pct = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        s.pct:SetPoint("LEFT", s, "RIGHT", 8, 0)
        s.row, s.label = row, label
        s:SetScript("OnEnter", Tip)
        s:SetScript("OnLeave", ns.HideTip)
        top = top - H.slider
        return s
    end
    for _, row in ipairs(sec.rows) do
        if row.slider then
            -- A slider (2026-11-11: the pet frame's faded opacity), its value in percent beside it.
            local s = Slider(row, Label(row, 14), row.slider[1], row.slider[2], row.slider[3])
            s:SetScript("OnValueChanged", function(self, v, user)
                v = tonumber(("%.2f"):format(math.floor(v / row.slider[3] + 0.5) * row.slider[3])) -- (0.3, not 0.30000000000000004)
                self.pct:SetText(("%d%%"):format(math.floor(v * 100 + 0.5)))
                if user then row.set(v) end
            end)
            widgets[#widgets + 1] = { row = row, slider = s }
        elseif row.steps then
            -- A slider of named steps (2026-11-15: "Småting i chatten"), the step's name beside it.
            local s = Slider(row, Label(row, 14), 1, #row.steps, 1)
            s:SetScript("OnValueChanged", function(self, v, user)
                local step = row.steps[math.max(1, math.min(#row.steps, math.floor(v + 0.5)))]
                self.pct:SetText(L[row.key .. "." .. step])
                if user then Set(row.setting, step) end
            end)
            widgets[#widgets + 1] = { row = row, steps = s }
        elseif row.choices then
            Label(row, 14)
            local w = { row = row, buttons = {} }
            local per = row.perLine or #row.choices
            local cell = math.floor((W - 30) / per)
            for i, choice in ipairs(row.choices) do
                -- Radio buttons: one of a few (they were checkboxes, UX review 2026-11-11). The template
                -- isn't probed on Forever yet: checkboxes if it's missing.
                local okR, b = pcall(CreateFrame, "CheckButton", nil, panel, "UIRadioButtonTemplate")
                if okR and b then b:SetSize(18, 18)
                else b = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate"); b:SetSize(22, 22) end
                local col, line = (i - 1) % per, math.floor((i - 1) / per)
                b:SetPoint("TOPLEFT", panel, "TOPLEFT", 22 + col * cell, top - 2 - line * H.radio)
                b.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b.label:SetPoint("LEFT", b, "RIGHT", 2, 0)
                b.label:SetWidth(cell - 26)
                b.label:SetJustifyH("LEFT")
                b.label:SetWordWrap(false)
                b.label:SetText(row.label and row.label(choice) or L[row.key .. "." .. choice])
                b.row, b.choice = row, choice
                b:SetScript("OnClick", function()
                    Set(row.setting, choice)
                    Settings:Refresh()
                end)
                b:SetScript("OnEnter", Tip)
                b:SetScript("OnLeave", ns.HideTip)
                w.buttons[#w.buttons + 1] = b
            end
            top = top - math.ceil(#row.choices / per) * H.radio - 4
            widgets[#widgets + 1] = w
        else
            local indent = 10 + (row.needs and 16 or 0)
            local b = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
            b:SetSize(24, 24)
            b:SetPoint("TOPLEFT", panel, "TOPLEFT", indent, top)
            b.label = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.label:SetPoint("TOPLEFT", b, "TOPRIGHT", 2, -5)
            b.label:SetJustifyH("LEFT")
            b.label:SetWordWrap(true)
            b.label:SetWidth(W - indent - 24 - 22) -- (room for the * at the right)
            b.label:SetText(L[row.key])
            if row.char then -- (this character's alone: the note under the columns says so)
                b.mark = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
                b.mark:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -10, top - 5)
                b.mark:SetTextColor(0.6, 0.6, 0.6)
                b.mark:SetText("*")
            end
            b.row = row
            b:SetScript("OnClick", function(self)
                local on = self:GetChecked() and true or false
                if row.set then row.set(on) else Set(row.setting, on) end
                Settings:Refresh()
            end)
            b:SetScript("OnEnter", Tip)
            b:SetScript("OnLeave", ns.HideTip)
            widgets[#widgets + 1] = { row = row, button = b }
            top = top - math.max(H.check, (b.label:GetStringHeight() or 0) + 10)
        end
    end
    local height = -top + H.pad
    panel:SetHeight(height)
    return height, panel
end

-- The sections into a frame (the page's inset, or the options panel's scroll child: Canvas), each row's widgets
-- into `widgets`, in their two columns (the options panel too: room for both, 2026-11-21, the user). Returns the
-- height they took, and the sections' panels.
local function Fill(inset, widgets)
    local G = Settings.GAP
    local tops, panels = { -G, -G }, {}
    for _, sec in ipairs(SECTIONS) do
        local col = sec.column
        local x = G + (col - 1) * (Settings.COL_W + G)
        local h, panel = Section(inset, widgets, sec, x, tops[col])
        panels[#panels + 1] = panel
        tops[col] = tops[col] - h - G
    end
    -- What the * means, under the columns.
    local note = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetTextColor(0.6, 0.6, 0.6)
    note:SetText(L["settings.char.note"])
    local deepest = math.min(tops[1], tops[2])
    note:SetPoint("TOPLEFT", inset, "TOPLEFT", G, deepest)
    return -deepest + 20, panels
end

-- Where the page was opened from: one of our other pages (Parken, Prestasjoner), whose cog it was; "Tilbake"
-- goes back there. nil: the pets.
local from

local function Build(p)
    local f = p.frame
    local inset = CreateFrame("Frame", nil, f, ns.SidePage.Template("InsetFrameTemplate"))
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -50)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -60, 30)
    -- Back to where it was opened from (the user, 2026-11-10: else only closing the window left the page).
    local back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    back:SetSize(120, 22)
    back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    back:SetText(L["settings.back"])
    back:SetScript("OnClick", function() Settings:Back() end)
    p.back = back
    p.widgets = {}
    p.height, p.panels = Fill(inset, p.widgets)
    Settings.built = p -- (the tests read its sections' panels and height)
end

local function Draw(widgets)
    for _, w in ipairs(widgets or {}) do
        if w.steps then
            local now = Settings:Chatter()
            for i, step in ipairs(w.row.steps) do
                if step == now then w.steps:SetValue(i); w.steps.pct:SetText(L[w.row.key .. "." .. step]) end
            end
        elseif w.slider then
            local on = not w.row.needs or w.row.needs()
            w.slider:SetValue(Settings:Get(w.row.setting) or 0.25)
            w.slider.pct:SetText(("%d%%"):format(math.floor((Settings:Get(w.row.setting) or 0.25) * 100 + 0.5)))
            w.slider:SetEnabled(on)
            if on then w.slider.label:SetTextColor(1, 1, 1) else w.slider.label:SetTextColor(0.5, 0.5, 0.5) end
        elseif w.button then
            w.button:SetChecked(Get(w.row))
            local on = not w.row.needs or w.row.needs()
            w.button:SetEnabled(on)
            if on then w.button.label:SetTextColor(1, 1, 1) else w.button.label:SetTextColor(0.5, 0.5, 0.5) end
        else
            local now = Settings:Get(w.row.setting) or "all"
            for _, b in ipairs(w.buttons) do b:SetChecked(b.choice == now) end
        end
    end
end
local canvas -- the options panel's page (Canvas), once built
local function Redraw(p)
    Draw(p.widgets)
end

local sp = ns.SidePage:New({
    id = "Settings",
    title = L["settings.title"],
    icon = ns.Icon("gear"),
    tab = false, -- (the cog opens it)
    build = Build,
    refresh = Redraw,
})

function Settings:Open() sp:Open() end
function Settings:Close() sp:Close() end
function Settings:IsOpen() return sp:IsOpen() end
function Settings:Refresh()
    sp:Refresh()
    if canvas and canvas:IsVisible() then Draw(canvas.widgets) end
end

-- Leave the page: back to the page it was opened from, or the pets.
function Settings:Back()
    local back = from
    from = nil
    if back and back ~= sp then back:Open() else sp:Close() end
end

-- The cog: in the title bar, left of the close button, wherever one of ours shows (2026-11-15, the user:
-- "we have 3 different panels and settings only shows on one of them"): the pets, Parken, Prestasjoner, and
-- this page. Not on Blizzard's other pages (Mounts, Toys...). A click on another of our pages opens this one
-- over it, and "Tilbake" goes back there.
function Settings:AttachCog(petJournal)
    local host = petJournal:GetParent() or petJournal
    local cog = ns.RoundBadge(host, 18, { icon = ns.Icon("gear"), color = { 0.9, 0.78, 0.5, 1 }, hover = { 1, 0.85, 0.5, 0.6 } })
    local close = rawget(host, "CloseButton")
    if close then cog:SetPoint("RIGHT", close, "LEFT", -2, 0)
    else cog:SetPoint("TOPRIGHT", host, "TOPRIGHT", -28, -3) end
    cog:SetFrameLevel(host:GetFrameLevel() + 520) -- (over our pages, like the close button)
    cog:SetScript("OnClick", function()
        if sp:IsOpen() then return Settings:Back() end
        from = ns.SidePage:Current()
        sp:Open()
    end)
    ns.SetTip(cog, "ANCHOR_BOTTOM", L["settings.title"])
    local base = host:GetFrameLevel() + 520
    local function Update()
        cog:SetShown(petJournal:IsShown() or ns.SidePage:AnyOpen())
        -- Over whatever an open page lifted: the window's title bar goes above our page (SidePage), and in the
        -- game it covered the cog on Parken and Prestasjoner (2026-11-15, the user: "only visible on the pet
        -- journal tab"), though the cog was shown.
        local top = ns.SidePage:TopLevel()
        cog:SetFrameLevel(math.max(base, (top or 0) + 5))
        if not sp:IsOpen() then from = nil end -- (left some other way: a tab, the window closed)
        ns.Log("Settings", "cog: shown %s, visible %s, level %d (lifted up to %s; pets %s, page %s)", tostring(cog:IsShown()),
            tostring(cog:IsVisible()), cog:GetFrameLevel(), tostring(top), tostring(petJournal:IsShown()),
            tostring(ns.SidePage:Current() and ns.SidePage:Current().def.id))
    end
    Update()
    petJournal:HookScript("OnShow", Update)
    petJournal:HookScript("OnHide", Update)
    ns.Bus:On("SIDEPAGE", Update)
    self.cog = cog
end

-- The same settings in Blizzard's options (Esc > Options > AddOns, 2026-11-15, the user): the same two columns
-- (2026-11-21: one left half the panel empty), scrolling, on a canvas of our own (Settings.RegisterCanvasLayoutCategory: on Forever,
-- docs/FOREVER_API.md). Built the first time it shows; the journal's page and this one read the same
-- settings, and a change on either redraws both. Nothing protected in it, so it works in combat too.
function Settings.Canvas()
    local api = rawget(_G, "Settings") -- (Blizzard's; ours is the local `Settings`)
    if type(api) ~= "table" or not (api.RegisterCanvasLayoutCategory and api.RegisterAddOnCategory) then
        ns.Log("Settings", "no Settings API: not in the options panel")
        return
    end
    local f = CreateFrame("Frame")
    f:Hide()
    f:SetScript("OnShow", function(self)
        if not self.widgets then
            local title = self:CreateFontString(nil, "OVERLAY", "GameFontHighlightHuge")
            title:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -15)
            title:SetText(L["settings.options.title"])
            local scroll = CreateFrame("ScrollFrame", nil, self, "UIPanelScrollFrameTemplate")
            scroll.scrollBarHideable = true
            scroll:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -46)
            scroll:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -28, 8)
            local child = CreateFrame("Frame", nil, scroll)
            child:SetSize(2 * Settings.COL_W + 3 * Settings.GAP, 1)
            scroll:SetScrollChild(child)
            self.widgets = {}
            local height, panels = Fill(child, self.widgets)
            child:SetHeight(height)
            self.panels = panels
        end
        Draw(self.widgets)
    end)
    local category = api.RegisterCanvasLayoutCategory(f, L["settings.options.title"])
    api.RegisterAddOnCategory(category)
    canvas, Settings.category = f, category
    return f
end

ns.Start("login", function() Settings.Canvas() end)
