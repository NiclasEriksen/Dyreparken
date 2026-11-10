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
-- or { label, choices } for a row of choices.
local ROWS = {
    { head = "settings.head.pet" },
    { key = "settings.autosummon", get = function() return ns.DB.char.autoSummon and true or false end,
        set = function(v) ns.Summon:SetEnabled(v) end, char = true },
    { key = "settings.mute", get = function() return ns.DB.char.muteSummonSound and true or false end,
        set = function(v) ns.Summon:SetMuteSound(v) end, char = true },
    { head = "settings.head.guild" },
    { key = "settings.announce", get = function() return ns.DB.char.announce and true or false end,
        set = function(v) ns.DB.char.announce = v end, char = true },
    { key = "settings.achnotify", get = function() return ns.DB.char.achNotify and true or false end,
        set = function(v) ns.DB.char.achNotify = v end, char = true },
    { head = "settings.head.chat" },
    { key = "settings.chatlines", setting = "chatLines" },
    { key = "settings.hearts", setting = "worldHearts" },
    { head = "settings.head.card" },
    { key = "settings.particles", choices = { "all", "few", "none" }, setting = "cardParticles" },
    { key = "settings.moves", setting = "cardMoves" },
    { key = "settings.celebrate", setting = "celebrate" },
}
Settings.ROWS = ROWS

local function Get(row)
    if row.get then return row.get() end
    return Settings:On(row.setting)
end

local function Tip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L[self.row.key], 1, 0.82, 0)
    GameTooltip:AddLine(L[self.row.key .. ".tip"], 1, 1, 1, true)
    if self.row.char then GameTooltip:AddLine(L["settings.char"], 0.6, 0.6, 0.6, true) end
    GameTooltip:Show()
end

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
    local y = -16
    for _, row in ipairs(ROWS) do
        if row.head then
            local h = inset:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            h:SetPoint("TOPLEFT", inset, "TOPLEFT", 20, y - 6)
            h:SetText(L[row.head])
            y = y - 34
        elseif row.choices then
            local label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            label:SetPoint("TOPLEFT", inset, "TOPLEFT", 40, y - 6)
            label:SetText(L[row.key])
            local w = { row = row, buttons = {} }
            local prev
            for _, choice in ipairs(row.choices) do
                local b = CreateFrame("CheckButton", nil, inset, "UICheckButtonTemplate")
                b:SetSize(24, 24)
                if prev then b:SetPoint("LEFT", prev.label, "RIGHT", 14, 0)
                else b:SetPoint("LEFT", label, "RIGHT", 12, 0) end
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
            b:SetPoint("TOPLEFT", inset, "TOPLEFT", 36, y)
            b.label = inset:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            b.label:SetPoint("LEFT", b, "RIGHT", 4, 0)
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
            y = y - 30
        end
    end
end

local function Redraw(p)
    for _, w in ipairs(p.widgets or {}) do
        if w.button then
            w.button:SetChecked(Get(w.row))
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
