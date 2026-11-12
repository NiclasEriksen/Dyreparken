local _, ns = ...

-- The settings page (2026-11-10): a page of the Collections window like
-- Parken and Prestasjoner (Core/SidePage.lua), but with no side tab: a small
-- cog in the pet journal's title bar opens it, left of the close button.
--
-- The four older settings are per character (char: autoSummon,
-- muteSummonSound, announce, achNotify) and keep their slash commands. The
-- new ones are for the account (DyreparkenDB.settings, Core/DB.lua):
--   chatLines      the lines for easter eggs, dislikes, likes and firsts in the chat
--                  (off: they still happen and count, without a line; the user, 2026-11-10)
--   worldHearts    hearts over a hovered companion, sparkles at the chat window
--   cardParticles  "all", "few" or "none" on the pet card
--   cardMoves      the pet on the card moves (asleep, hops, walks...)
--   celebrate      the bond level-up celebration on the card
--   petFrame       the pet frame on screen (off by default; placed and sized in Edit Mode: PetFrame.lua)
--   petFrameArt    its background and border (off by default: it floats)
--   petFrameCombat hidden in combat; petFrameFade faded to petFrameAlpha (0.25) when nothing happens (2026-11-11)
-- Modules read them with Settings:On(key) / Settings:Get(key).
local Settings = {}
ns.Settings = Settings

local L = ns.L

function Settings:Get(key) return ns.DB.global.settings[key] end
function Settings:On(key) return ns.DB.global.settings[key] ~= false end

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
    { key = "settings.chatlines", setting = "chatLines" },
    { key = "settings.hearts", setting = "worldHearts" },
    { column = 2 }, -- (2026-11-11: one column had outgrown the page)
    { head = "settings.head.card" },
    { key = "settings.particles", choices = { "all", "few", "none" }, setting = "cardParticles" },
    { key = "settings.moves", setting = "cardMoves" },
    { key = "settings.celebrate", setting = "celebrate" },
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

local function Build(p)
    local f = p.frame
    local inset = CreateFrame("Frame", nil, f, ns.SidePage.Template("InsetFrameTemplate"))
    inset:SetPoint("TOPLEFT", f, "TOPLEFT", 60, -50)
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -60, 30)
    -- Back to the pets (the user, 2026-11-10: else only closing the window left the page).
    local back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    back:SetSize(120, 22)
    back:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 4)
    back:SetText(L["settings.back"])
    back:SetScript("OnClick", function() p:Close() end)
    p.back = back
    p.widgets = {}
    -- Two columns, each label within its own (2026-11-11, the user: "elements overlap and don't
    -- wrap"): wrapped at COL_W, the row as tall as its text.
    local COL_W = Settings.COL_W
    local y, x, at = -16, 0, "TOPLEFT"
    for i, row in ipairs(ROWS) do
        if row.column then
            y, x, at = -16, 10, "TOP"
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
            p.widgets[#p.widgets + 1] = { row = row, slider = s }
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
            p.widgets[#p.widgets + 1] = w
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
            p.widgets[#p.widgets + 1] = { row = row, button = b }
            y = y - math.max(30, b.label:GetStringHeight() + 16)
        end
    end
end

local function Redraw(p)
    for _, w in ipairs(p.widgets or {}) do
        if w.slider then
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

local sp = ns.SidePage:New({
    id = "Settings",
    title = L["settings.title"],
    icon = ns.Decor.MEDIA .. "gear",
    tab = false, -- (the cog opens it)
    build = Build,
    refresh = Redraw,
})
Settings._sp = sp

function Settings:Open() sp:Open() end
function Settings:Close() sp:Close() end
function Settings:IsOpen() return sp:IsOpen() end
function Settings:Refresh() sp:Refresh() end

-- The cog: in the title bar, left of the close button; only on the pet journal's page.
function Settings:AttachCog(petJournal)
    local host = petJournal:GetParent() or petJournal
    local cog = CreateFrame("Button", nil, host)
    cog:SetSize(18, 18)
    local close = rawget(host, "CloseButton")
    if close then cog:SetPoint("RIGHT", close, "LEFT", -2, 0)
    else cog:SetPoint("TOPRIGHT", host, "TOPRIGHT", -28, -3) end
    cog:SetFrameLevel(host:GetFrameLevel() + 520) -- (over our pages, like the close button)
    cog.icon = cog:CreateTexture(nil, "ARTWORK")
    cog.icon:SetTexture(ns.Decor.MEDIA .. "gear")
    cog.icon:SetVertexColor(0.9, 0.78, 0.5, 1)
    cog.icon:SetAllPoints()
    cog.hover = cog:CreateTexture(nil, "HIGHLIGHT")
    cog.hover:SetTexture(ns.Decor.MEDIA .. "dot")
    cog.hover:SetBlendMode("ADD")
    cog.hover:SetVertexColor(1, 0.85, 0.5, 0.6)
    cog.hover:SetAllPoints()
    cog:SetScript("OnClick", function()
        if sp:IsOpen() then sp:Close() else sp:Open() end
    end)
    ns.SetTip(cog, "ANCHOR_BOTTOM", L["settings.title"])
    cog:SetShown(petJournal:IsShown())
    petJournal:HookScript("OnShow", function() cog:Show() end)
    petJournal:HookScript("OnHide", function() cog:Hide() end)
    self.cog = cog
end
