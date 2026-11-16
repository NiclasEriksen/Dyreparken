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

-- The rows, top to bottom: a heading, or { label, tip, get, set } for a checkbox,
-- or { label, choices } for a row of choices; { column = 2 }: the rest in the right half.
local ROWS = {
    { head = "settings.head.pet", char = true },
    { key = "settings.autosummon", get = function() return ns.DB.char.autoSummon and true or false end,
        set = function(v) ns.Summon:SetEnabled(v) end, char = true },
    { key = "settings.mute", get = function() return ns.DB.char.muteSummonSound and true or false end,
        set = function(v) ns.Summon:SetMuteSound(v) end, char = true },
    { head = "settings.head.guild", char = true },
    { key = "settings.announce", get = function() return ns.DB.char.announce and true or false end,
        set = function(v) ns.Bonds:SetAnnounce(v, true) end, char = true },
    { key = "settings.achnotify", get = function() return ns.DB.char.achNotify and true or false end,
        set = function(v) ns.Achievements:SetNotify(v, true) end, char = true },
    { head = "settings.head.chat" },
    { key = "settings.chatter", steps = Settings.CHATTER_STEPS, setting = "chatter" },
    { key = "settings.hearts", setting = "worldHearts" },
    { head = "settings.head.park" },
    { key = "settings.hideunknown", setting = "hideUnknown",
        set = function(v) Set("hideUnknown", v); ns.ParkPage:Refresh() end },
    { column = 2 }, -- (2026-11-11: one column had outgrown the page)
    { head = "settings.head.card" },
    { key = "settings.particles", choices = { "all", "few", "none" }, setting = "cardParticles" },
    -- (the pet frame's stage too: it reads the setting only when it poses the pet, and walked on)
    { key = "settings.moves", setting = "cardMoves",
        set = function(v) Set("cardMoves", v); ns.PetFrame:Apply() end },
    { key = "settings.celebrate", setting = "celebrate" },
    { key = "settings.petsounds", setting = "petSounds" },
    { head = "settings.head.frame" },
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
}
Settings.ROWS = ROWS
Settings.COL_W = 330 -- a column's width (the page's inset is about 700)

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

-- The rows into a frame (the page's inset, or the options panel's scroll child: Canvas), each row's widgets
-- into `widgets`. one: a single column, for the options panel, narrower than the journal (its { column }
-- row is passed by). Returns the height the rows took.
local function Fill(inset, widgets, one)
    -- Two columns, each label within its own (2026-11-11, the user: "elements overlap and don't
    -- wrap"): wrapped at COL_W, the row as tall as its text.
    local COL_W = Settings.COL_W
    local y, x, at = -16, 0, "TOPLEFT"
    local deepest = 0
    for i, row in ipairs(ROWS) do
        if row.column then
            if not one then y, x, at = -16, 10, "TOP" end
        elseif row.head then
            if i > 1 and not ROWS[i - 1].column then y = y - 8 end -- (a little air before a heading)
            local h = inset:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            h:SetPoint("TOPLEFT", inset, at, x + 20, y - 6)
            h:SetText(L[row.head])
            if row.char then -- (these are per character; the rest is for the account: UX review 2026-11-11)
                local note = inset:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                note:SetPoint("BOTTOMLEFT", h, "BOTTOMRIGHT", 8, 1)
                note:SetText(L["settings.char.head"])
            end
            y = y - 34
        elseif row.slider then
            -- A slider (2026-11-11: the pet frame's faded opacity), its value in percent beside it.
            local label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOPLEFT", inset, at, x + 54, y - 6)
            label:SetText(L[row.key])
            y = y - 26
            local s = CreateFrame("Slider", nil, inset, "OptionsSliderTemplate")
            s:SetPoint("TOPLEFT", inset, at, x + 58, y - 4)
            s:SetSize(COL_W - 140, 16)
            s:SetOrientation("HORIZONTAL")
            s:SetMinMaxValues(row.slider[1], row.slider[2])
            s:SetValueStep(row.slider[3])
            s:SetObeyStepOnDrag(true)
            s.pct = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            s.pct:SetPoint("LEFT", s, "RIGHT", 10, 0)
            s.row, s.label = row, label
            s:SetScript("OnValueChanged", function(self, v, user)
                v = tonumber(("%.2f"):format(math.floor(v / row.slider[3] + 0.5) * row.slider[3])) -- (0.3, not 0.30000000000000004)
                self.pct:SetText(("%d%%"):format(math.floor(v * 100 + 0.5)))
                if user then row.set(v) end
            end)
            s:SetScript("OnEnter", Tip)
            s:SetScript("OnLeave", ns.HideTip)
            widgets[#widgets + 1] = { row = row, slider = s }
            y = y - 34
        elseif row.steps then
            -- A slider of named steps (2026-11-15: "Småting i chatten"), the step's name beside it.
            local label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOPLEFT", inset, at, x + 40, y - 6)
            label:SetText(L[row.key])
            y = y - 26
            local s = CreateFrame("Slider", nil, inset, "OptionsSliderTemplate")
            s:SetPoint("TOPLEFT", inset, at, x + 44, y - 4)
            s:SetSize(COL_W - 150, 16)
            s:SetOrientation("HORIZONTAL")
            s:SetMinMaxValues(1, #row.steps)
            s:SetValueStep(1)
            s:SetObeyStepOnDrag(true)
            s.pct = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            s.pct:SetPoint("LEFT", s, "RIGHT", 10, 0)
            s.row, s.label = row, label
            s:SetScript("OnValueChanged", function(self, v, user)
                local step = row.steps[math.max(1, math.min(#row.steps, math.floor(v + 0.5)))]
                self.pct:SetText(L[row.key .. "." .. step])
                if user then Set(row.setting, step) end
            end)
            s:SetScript("OnEnter", Tip)
            s:SetScript("OnLeave", ns.HideTip)
            widgets[#widgets + 1] = { row = row, steps = s }
            y = y - 34
        elseif row.choices then
            local label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOPLEFT", inset, at, x + 40, y - 6)
            label:SetText(L[row.key])
            y = y - 24 -- (the choices on a line of their own, under it)
            local w = { row = row, buttons = {} }
            local prev
            for _, choice in ipairs(row.choices) do
                -- Radio buttons: one of three (they were checkboxes, UX review 2026-11-11). The template
                -- isn't probed on Forever yet: checkboxes if it's missing.
                local okR, b = pcall(CreateFrame, "CheckButton", nil, inset, "UIRadioButtonTemplate")
                if okR and b then b:SetSize(18, 18)
                else b = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate"); b:SetSize(24, 24) end
                if prev then b:SetPoint("LEFT", prev.label, "RIGHT", 14, 0)
                else b:SetPoint("TOPLEFT", inset, at, x + 52, y) end
                b.label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                b.label:SetPoint("LEFT", b, "RIGHT", 2, 0)
                b.label:SetText(L[row.key .. "." .. choice])
                b.row, b.choice = row, choice
                b:SetScript("OnClick", function()
                    Set(row.setting, choice)
                    Settings:Refresh()
                end)
                b:SetScript("OnEnter", Tip)
                b:SetScript("OnLeave", ns.HideTip)
                w.buttons[#w.buttons + 1] = b
                prev = b
            end
            widgets[#widgets + 1] = w
            y = y - 30
        else
            local b = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
            b:SetSize(26, 26)
            b:SetPoint("TOPLEFT", inset, at, x + 36 + (row.needs and 18 or 0), y)
            b.label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.label:SetPoint("TOPLEFT", b, "TOPRIGHT", 4, -6)
            b.label:SetWidth(COL_W - 70)
            b.label:SetJustifyH("LEFT")
            b.label:SetWordWrap(true)
            b.label:SetText(L[row.key])
            b.row = row
            b:SetScript("OnClick", function(self)
                local on = self:GetChecked() and true or false
                if row.set then row.set(on) else Set(row.setting, on) end
                Settings:Refresh()
            end)
            b:SetScript("OnEnter", Tip)
            b:SetScript("OnLeave", ns.HideTip)
            widgets[#widgets + 1] = { row = row, button = b }
            y = y - math.max(30, b.label:GetStringHeight() + 16)
        end
        deepest = math.min(deepest, y)
    end
    return 16 - deepest
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
    Fill(inset, p.widgets)
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

-- The same settings in Blizzard's options (Esc > Options > AddOns, 2026-11-15, the user): the rows in one
-- column, scrolling, on a canvas of our own (Settings.RegisterCanvasLayoutCategory: on Forever,
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
            child:SetSize(Settings.COL_W + 20, 1)
            scroll:SetScrollChild(child)
            self.widgets = {}
            child:SetHeight(Fill(child, self.widgets, true))
        end
        Draw(self.widgets)
    end)
    local category = api.RegisterCanvasLayoutCategory(f, L["settings.options.title"])
    api.RegisterAddOnCategory(category)
    canvas, Settings.category = f, category
    return f
end

ns.Start("login", function() Settings.Canvas() end)
