local _, ns = ...

-- Integration with the game's companion window (Collections > Pets).
--
-- Blizzard_Collections is load-on-demand. Nothing is built until it loads,
-- and nothing refreshes unless the journal is visible. Blizzard code is only
-- hooked (hooksecurefunc / HookScript), never replaced, and our per-button
-- state lives in our own weak table, not on Blizzard's frames, to avoid taint.
--
-- Forever has the Retail-style journal (probed 2026-11-06): PetJournal,
-- PetJournal.ScrollBox, PetJournalPetCard, PetJournalSummonButton.
-- (unverified) list buttons carry .petID / .speciesID like on Retail; we fall
-- back to elementData.index -> GetPetInfoByIndex.
--
-- What it adds, in parts:
--  * the list (JournalList.lua): markers, bond rings, nicknames, tooltips
--  * the pet card (here): the scene, the name and home, the personality, the
--    guild's boxes above it, and the widgets drawn for the pet (Card.lua: one registration each)
--  * the card's buttons and popups (CardActions.lua): Adopter / Gi slipp, Kallenavn
--  * the achievements tab and page (Achievements/Page.lua)
--
-- Wording (decided 2026-11-06): companions are adopted and cared for, never
-- "reserved" or "claimed" in anything players read.
local JournalUI = {}
ns.JournalUI = JournalUI

local card = {}  -- our widgets on the pet card
-- Our widgets on the card, for the modules that draw on it outside its update
-- (Story, BondTrack's previews, the editors and probes) and the tests.
function JournalUI:Card() return card end

------------------------------------------------------------------------------
-- Pet card
------------------------------------------------------------------------------
local function CardSpecies()
    local c = PetJournalPetCard
    if not c then return nil end
    if c.speciesID then return c.speciesID end
    if c.petID then return (C_PetJournal.GetPetInfoByPetID(c.petID)) end
end

-- The panel, a full-width sheet (2026-11-11, the user picked "B" of three layouts: two columns had cut
-- the home and the likes short while the bond column stood half empty). Rows, top to bottom, at fixed
-- heights from the panel's top: the name (the level's name and medallion at its right), the species and
-- home, the bond strip (stars, bar, goal: BondTrack.lua), the traits, the likes.
local PANEL_H = 106
local ROW_Y = { name = -6, status = -33, strip = -51, personality = -71, likes = -86 }
local NAME_RIGHT = 150 -- the name stops short of the level's name and the medallion
local STATUS_RIGHT = 72 -- the home line stops short of the medallion, which rises out of the top right
local COLUMN = NAME_RIGHT -- (the name's room, for the font step-down)
JournalUI.ROW_Y = ROW_Y
local MODEL_LIFT = 34 -- the model's bottom, above the panel: clear of the turn buttons
local NAME_FONTS = { "GameFontNormalHuge", "GameFontNormalLarge", "GameFontNormal" } -- the name, biggest first
-- A minor like or dislike in the likes line (Personality.lua: unlocked by your bond), dimmer than the
-- line's own color (0.8, 0.76, 0.66): lesser (the user, 2026-11-12).
local MINOR = "|cff8c8475"
-- The panel's width once laid out (nil before).
local function panel_width(c) return c.panel and c.panel:GetWidth() end

-- Blizzard's two buttons that turn the model: found by name or parentKey
-- (unprobed on Forever), left one first. Nil if not found.
local function RotateButtons(root)
    local left, right
    local function Scan(f, depth)
        for _, child in ipairs({ f:GetChildren() }) do
            local tag = child:GetName() or ""
            for k, v in pairs(f) do
                if v == child and type(k) == "string" then tag = tag .. k end
            end
            if child:GetObjectType() == "Button" and tag:find("Rotate") then
                if tag:find("Left") then left = child elseif tag:find("Right") then right = child end
            end
            if depth < 3 then Scan(child, depth + 1) end
        end
    end
    Scan(root, 1)
    if left and right then return left, right end
end

local BOX_GAP = 6 -- between the boxes on the "Total Pets" row

-- "Dagens dyr" fills the row up to the card's right edge, wherever the row
-- starts: a fixed width ran past the window (seen 2026-11-08). A long name is
-- cut short; the tooltip has it whole. (Two reads: cheap on every pick.)
local function SizeTodayBox()
    local right, from = PetJournalPetCard:GetRight(), card.guildBox:GetRight()
    if right and from then card.todayBox:SetWidth(math.max(80, right - from - BOX_GAP)) end
end

-- The guild's boxes above the card: the same whichever pet is picked, so
-- redrawn on a refresh (registry, bonds, opening), not on every pick.
local function UpdateGuildBoxes()
    if not card.counter then return end
    local n, total = ns.Registry:Count(), ns.Pets:Total()
    local pct = total > 0 and math.floor(n / total * 100 + 0.5) or 0
    card.counter:SetText(ns.T("card.guild.value", { n = n, total = total, pct = pct }))
    card.guildBox.tip = ns.T("card.guild.tip", { n = n, total = total, pct = pct })
    local today, owner = ns.Bonds:PetOfTheDay()
    card.today:SetText(today and ns.Registry:NameOf(today) or "-")
    card.todayBox.tip = today and (ns.T("card.today.tip", { pet = ns.Registry:NameOf(today), owner = owner })
        .. (ns.Pets:SpeciesOfKey(today) and "\n|cffa0a0a0" .. ns.L["card.today.click"] .. "|r" or ""))
        or ns.L["card.today.none"]
    SizeTodayBox()
end

-- The card's widgets (Card.lua): each draws itself for the pet (or clears itself, key nil).
-- ctx: the bond level shown; "scenes", first, adds the family's tint.
local function DrawWidgets(key)
    card.key = key -- (the hover tooltips and clicks follow it)
    local ctx = {}
    if key then ctx.level = select(2, ns.Bond:Shown(key)) end -- your bond with it, or its carer's
    ns.Card:Update(card, key, ctx)
    SizeTodayBox()
end

local function UpdateCard()
    if not card.status then return end
    -- Under one of our pages (Parken, Prestasjoner) the card can't be seen:
    -- no work, no animations, no celebration spent there. It's redrawn when
    -- the page closes (SIDEPAGE).
    if ns.SidePage:AnyOpen() then return end
    -- Blizzard updates the card from its own events with the journal closed
    -- too: nothing to draw then (it'd start particles, pulses and timers on a
    -- hidden card, and ask the guild for bonds). The journal's OnShow redraws.
    if not PetJournalPetCard:IsVisible() then return end
    local sid = CardSpecies()
    if not sid then
        card.status:SetText("")
        card.nickname:SetText("")
        card.personality:SetText("")
        card.likes:SetText("")
        DrawWidgets(nil)
        return
    end
    local key = ns.Pets:KeyOfSpecies(sid)
    local status, owner, r = ns.Registry:Status(key)
    local nick = ns.Registry:Nickname(key)
    local text
    if status == "free" then
        text = "|cff80cc80" .. ns.L["card.free"] .. "|r"
    elseif status == "mine" then
        text = ns.Gold(ns.Home(ns.L["home.you"], r.at))
    else
        text = "|cffff8080" .. ns.Home(owner, r.at) .. "|r"
    end
    -- Big: the nickname, else the species. Small: the species (if named) and its home.
    local species = ns.Pets:NameOfKey(key) or ""
    card.nickname:SetText(nick or species)
    -- A long name steps down a size or two before it's cut short.
    local width = panel_width(card)
    local room = width and width - COLUMN - 14
    for _, font in ipairs(NAME_FONTS) do
        card.nickname:SetFontObject(font)
        if not room or card.nickname:GetStringWidth() <= room then break end
    end
    card.status:SetText(nick and (species .. " · " .. text) or text) -- (no nickname: the big name is the species)
    card.fullName, card.species, card.home = nick or species, species, text -- for the hover
    if ns.Personality:Known(key) then
        card.personality:SetText(ns.Personality:Names(key))
        local P = ns.Personality
        local likes, dislikes = P:LikedWords(key), nil
        local minorBad
        dislikes, minorBad = P:DislikedWords(key)
        -- The minor ones (unlocked by your bond, Personality.lua) in the same line, dimmed: lesser.
        local minorLike = P:MinorLike(key)
        if minorLike then likes[#likes + 1] = MINOR .. P.NOUN[minorLike] .. "|r" end
        for _, w in ipairs(minorBad) do dislikes[#dislikes + 1] = MINOR .. w .. "|r" end
        local parts = {}
        if #likes > 0 then parts[1] = ns.T("card.likes", { list = ns.Join(likes) }) end
        if #dislikes > 0 then parts[#parts + 1] = ns.T("card.dislikes", { list = ns.Join(dislikes) }) end
        local line = table.concat(parts, " · ")
        card.likes:SetText(line:sub(1, 1):upper() .. line:sub(2))
    else -- a surprise until it's collected or adopted
        card.personality:SetText(ns.L["personality.unknown"])
        card.likes:SetText("")
    end
    DrawWidgets(key)
    ns.Sync:AskBonds(key) -- others' bonds with it (not in the full sync)
end

-- A species' card in the journal. First Blizzard's own PetJournal_SelectSpecies:
-- it scrolls the list to the pet and leaves the filters alone (works on
-- Forever for a pet you own, Dagens dyr 2026-11-09). For one you don't own
-- (the list only holds yours) it left the card on the last pet you looked at
-- (2026-11-09), so then PetJournal_ShowPetCardBySpeciesID, which in retail
-- shows any species' card. Each step is logged with the card's species after
-- it. Returns true if the card shows the species.
local function Try(name, ...)
    local fn = rawget(_G, name)
    if not fn then
        ns.Log("UI", "%s: missing", name)
        return false
    end
    local ok, err = pcall(fn, ...)
    local now = CardSpecies()
    ns.Log("UI", "%s(%s): %s, card species %s", name, tostring(select(select("#", ...), ...)),
        ok and "ok" or tostring(err), tostring(now))
    return ok
end

function JournalUI:ShowSpecies(sid)
    if not sid or ns.InCombat() then return false end
    Try("PetJournal_SelectSpecies", PetJournal, sid)
    if CardSpecies() == sid then return true end
    Try("PetJournal_ShowPetCardBySpeciesID", sid)
    return CardSpecies() == sid
end

-- A card to show when the player next opens the Pets page (the pet frame's click with the page
-- closed: PetFrame; a park icon in combat: ParkPage). Session only; the newest click wins. In combat,
-- also once the fight is over if the Pets page is up then.
function JournalUI:ShowWhenOpen(sid)
    self.pending = sid
    if ns.InCombat() then self:AfterCombat() end
end

-- The pending card when the fight ends, if the Pets page is up then (PLAYER_REGEN_ENABLED only while a
-- card waits: Events:OutOfCombat).
function JournalUI:AfterCombat()
    if self.waiting then return end
    self.waiting = true
    ns.Events:OutOfCombat(function()
        JournalUI.waiting = nil
        if PetJournal and PetJournal:IsVisible() then JournalUI:ShowPending() end
    end)
end

-- The Pets page just showed (the player opened it): the pending card, out of combat, a frame later
-- (the journal's own OnShow fills the list first).
function JournalUI:ShowPending()
    local sid = self.pending
    if not sid then return end
    if ns.InCombat() then return self:AfterCombat() end
    self.pending = nil
    C_Timer.After(0, function()
        if not (PetJournal and PetJournal:IsVisible()) then return end
        if ns.InCombat() then -- (the fight began this very frame)
            self.pending = self.pending or sid
            return self:AfterCombat()
        end
        ns.SidePage:CloseAll() -- (our pages would cover the card)
        JournalUI:ShowSpecies(sid)
    end)
end

-- A click on "Dagens dyr".
function JournalUI:ShowPetOfTheDay()
    local today = ns.Bonds:PetOfTheDay()
    self:ShowSpecies(today and ns.Pets:SpeciesOfKey(today))
end

-- A box like Blizzard's "Total Pets": a label left, a value right, a tooltip
-- (box.tip). With an icon instead of the label, the value follows the icon:
-- "Dagens dyr" cut the pet's name short ("Br...", creative review 2026-11-09).
local function InfoBox(label, width, icon)
    local box = CreateFrame("Frame", nil, PetJournal, ns.SidePage.Template("InsetFrameTemplate3"))
    box:SetSize(width, 20)
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.label:SetPoint("LEFT", box, "LEFT", 10, 0)
    box.value = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.value:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    if icon then
        box.icon = box:CreateTexture(nil, "OVERLAY")
        box.icon:SetTexture(icon[1])
        box.icon:SetVertexColor(icon[2], icon[3], icon[4], 1)
        box.icon:SetSize(14, 14)
        box.icon:SetPoint("LEFT", box, "LEFT", 7, 0)
        box.value:SetPoint("LEFT", box.icon, "RIGHT", 4, 0)
        box.value:SetJustifyH("LEFT")
    else
        box.label:SetText(label)
        box.value:SetPoint("LEFT", box.label, "RIGHT", 6, 0)
        box.value:SetJustifyH("RIGHT")
    end
    box.value:SetWordWrap(false)
    box:EnableMouse(true)
    ns.SetTip(box, "ANCHOR_BOTTOM", function(self) return self.tip or label end)
    return box
end

-- The panel: a dark strip along the bottom. It sits below the model's
-- frame level, so Blizzard's rotate buttons stay on top, in the gap
-- between our left column (name, home) and right column (the bond).
-- The guild line runs along its bottom edge.
local function BuildPanel(c)
    local panel = CreateFrame("Frame", nil, c)
    panel:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 4, 4)
    panel:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
    panel:SetHeight(PANEL_H)
    panel:SetFrameLevel(c:GetFrameLevel())
    panel.bg = panel:CreateTexture(nil, "BACKGROUND")
    panel.bg:SetAllPoints()
    panel.bg:SetColorTexture(0, 0, 0, 0.6)
    panel.edge = panel:CreateTexture(nil, "BORDER")
    panel.edge:SetPoint("TOPLEFT"); panel.edge:SetPoint("TOPRIGHT")
    panel.edge:SetHeight(1)
    panel.edge:SetColorTexture(1, 0.82, 0, 0.35)
    card.panel = panel
    card.floor:SetPoint("CENTER", panel, "TOP", 0, MODEL_LIFT + 48) -- under the pet's feet (seen 2026-11-08)
end

-- The rows: full width but for the medallion's corner; a long one ends in "...", and hovering
-- it tells all.
local function BuildRows()
    local panel = card.panel
    local function Line(font, y, right)
        local fs = panel:CreateFontString(nil, "OVERLAY", font)
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, y)
        fs:SetPoint("RIGHT", panel, "RIGHT", -right, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    -- A hover area over two lines, for the pet on the card; lines() -> its tooltip.
    local function HitOver(top, bottom, lines)
        local f = CreateFrame("Frame", nil, panel)
        f:SetPoint("TOPLEFT", top, "TOPLEFT", -2, 2)
        f:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 2, -2)
        f:EnableMouse(true)
        ns.SetTip(f, "ANCHOR_TOP", function() return card.key and lines() end)
        return f
    end
    card.nickname = Line("GameFontNormalHuge", ROW_Y.name, NAME_RIGHT)
    card.status = Line("GameFontHighlightSmall", ROW_Y.status, STATUS_RIGHT)
    -- Hover the name or the home line: both in full.
    card.nameHit = HitOver(card.nickname, card.status, function()
        local lines = { { card.fullName, 1, 0.82, 0 } }
        if card.fullName ~= card.species then lines[2] = { card.species, 1, 1, 1 } end
        lines[#lines + 1] = { card.home, 1, 1, 1, true }
        return lines
    end)
    -- Its personality: the traits, then what it likes.
    card.personality = Line("GameFontNormalSmall", ROW_Y.personality, 12)
    card.personality:SetTextColor(0.95, 0.75, 0.45)
    card.likes = Line("GameFontHighlightSmall", ROW_Y.likes, 12)
    card.likes:SetTextColor(0.8, 0.76, 0.66) -- (was the disabled grey: hard to read, creative review 2026-11-09)
    -- Hover the lines: what the traits mean and do, what it likes, and why it matters.
    card.personalityHit = HitOver(card.personality, card.likes, function() return JournalUI.PersonalityLines(card.key) end)
end

-- The personality's tooltip: what the traits mean and do, what it likes and dislikes (the minor
-- ones dimmed, as on the card; the secret ones a hint), what your bond unlocks next, and why it matters.
function JournalUI.PersonalityLines(key)
    local P = ns.Personality
    if not P:Known(key) then
        return { { ns.L["personality.unknown"], 1, 0.82, 0 }, { ns.L["personality.unknown.tip"], 1, 1, 1, true } }
    end
    local lines = P:TraitLines(key)
    local function Add(text, r, g, b) lines[#lines + 1] = { text, r, g, b, true } end
    local words = P:LikedWords(key)
    if #words > 0 then Add(ns.T("card.likes.tip", { list = ns.Join(words) }), 0.5, 0.8, 0.5) end
    local minorLike = P:MinorLike(key)
    if minorLike then Add(ns.T("card.likes.minor_tip", { list = P.NOUN[minorLike] }), 0.45, 0.62, 0.45) end
    local bad, minorBad = P:DislikedWords(key)
    if #bad > 0 then Add(ns.T("card.dislikes.tip", { list = ns.Join(bad) }), 0.85, 0.55, 0.55) end
    if #minorBad > 0 then Add(ns.T("card.dislikes.minor_tip", { list = ns.Join(minorBad) }), 0.65, 0.45, 0.45) end
    -- Dislikes not found out yet: a hint that there's something (creative review 2026-11-09).
    local _, all = P:Dislikes(key)
    local secret = #all - #bad - #minorBad
    if secret > 0 then
        Add(ns.T(secret == 1 and "card.dislikes.secret_one" or "card.dislikes.secret",
            { pet = ns.Registry:NameOf(key), n = secret }), 0.75, 0.6, 0.6)
    end
    -- What your bond unlocks next (the minor ones): a small reason to keep going.
    local what, level = P:NextUnlock(key)
    if what then
        Add(ns.T("card.unlock." .. what, { level = ns.Bond.LEVELS[level][2], pet = ns.Registry:NameOf(key) }), 0.6, 0.6, 0.6)
    end
    Add(ns.L["card.personality.hint"], 0.7, 0.7, 0.7)
    return lines
end

-- Blizzard's turn buttons sit where our rows go: move them to just above
-- the panel, so the panel's text runs the full width. (Plain buttons;
-- moving them taints nothing.) Seen in the middle of the panel, 2026-11-08.
local function BuildRotate(c)
    local panel = card.panel
    local left, right = RotateButtons(c)
    if left then
        left:ClearAllPoints()
        left:SetPoint("BOTTOMRIGHT", panel, "TOP", -3, 6)
        right:ClearAllPoints()
        right:SetPoint("BOTTOMLEFT", panel, "TOP", 3, 6)
        -- The model (their parent) ends just above them, so the pet stands
        -- clear of the buttons instead of behind them (seen 2026-11-08).
        local model = left:GetParent()
        if model and model ~= c then
            model:ClearAllPoints()
            model:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
            model:SetPoint("BOTTOMRIGHT", panel, "TOPRIGHT", 0, MODEL_LIFT)
            card.model = model
        end
    end
    if not left then
        -- They stay wherever they are, likely mid-panel: keep our text clear of the middle.
        for _, row in ipairs({ card.nickname, card.status, card.personality, card.likes }) do
            row:SetPoint("RIGHT", panel, "CENTER", -52, 0)
        end
    end
    ns.Log("Journal", "rotate buttons %s", left and "moved above the panel" or "not found")
    -- Blizzard's title row (the pet's icon and name at the top) says what the
    -- list and our panel already say: hidden, and kept hidden, for room at
    -- the top (2026-11-08). Dragging and the pet's tooltip stay on the list.
    local info = rawget(c, "PetInfo")
    if info then
        info:Hide()
        info:HookScript("OnShow", function(self) self:Hide() end)
        card.titleHidden = true
    end
end

-- JournalUI's own parts of the card, and the pet's pose (Moves.lua).
ns.Card.Register{ id = "panel", still = true, build = function(_, c) BuildPanel(c) end }
ns.Card.Register{ id = "rows", still = true, build = function() BuildRows() end } -- (UpdateCard fills them)
ns.Card.Register{ id = "rotate", still = true, build = function(_, c) BuildRotate(c) end }
ns.Card.Register{ id = "moves",
    update = function(_, key) ns.Moves:Update(card, key) end, -- asleep at night, a Latsabb sitting...
    stop = function() ns.Moves:Stop() end, -- (the pet's pose starts over next time)
}

local function BuildCard()
    local c = PetJournalPetCard
    if not c or card.status then return end
    ns.Card:Build(card, c)

    -- The guild's numbers: boxes like Blizzard's "Total Pets", on its row.
    -- "Guilden x av y": y = every companion in Forever's journal
    -- (Pets:Total, Data/Companions.lua). Then "Dagens dyr".
    local count = rawget(PetJournal, "PetCount") or rawget(_G, "PetJournalPetCount")
    card.guildBox = InfoBox(ns.L["card.guild"], 140)
    if count then
        card.guildBox:SetPoint("LEFT", count, "RIGHT", BOX_GAP, 0)
    else
        card.guildBox:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 160, 8)
    end
    card.todayBox = InfoBox(ns.L["card.today"], 140,
        { ns.Icon("star"), 1, 0.82, 0.3 })
    card.todayBox:SetPoint("LEFT", card.guildBox, "RIGHT", BOX_GAP, 0)
    card.todayBox:SetScript("OnMouseUp", function() JournalUI:ShowPetOfTheDay() end)
    card.counter, card.today = card.guildBox.value, card.todayBox.value

    -- The fallback tab buttons (SidePage) line up right to left from here,
    -- bottom right of the journal (where the old "Hold ute" box was).
    card.tabAnchor = CreateFrame("Frame", nil, PetJournal)
    card.tabAnchor:SetSize(1, 22)
    card.tabAnchor:SetPoint("BOTTOMRIGHT", PetJournal, "BOTTOMRIGHT", -6, 3)

    -- The achievements tab and page (Achievements/Page.lua).
    ns.AchPage:Attach(PetJournal, card.tabAnchor)
    -- The settings' cog in the title bar (Settings.lua).
    ns.Settings:AttachCog(PetJournal)
end

------------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------------
-- keys: { [petKey] = true } when only those pets' bonds changed (a guildmate's BOND, our own
-- points): their rings in the list, and the card only if it shows one of them. Else all of it.
function JournalUI:Refresh(keys)
    if not (PetJournal and PetJournal:IsVisible()) then return end
    if ns.SidePage:AnyOpen() then return end -- under our page: refreshed when it closes
    if keys then
        ns.JournalList:Refresh(keys)
        if card.key and keys[card.key] then UpdateCard() end
        return
    end
    UpdateGuildBoxes()
    ns.JournalList:Refresh()
    UpdateCard()
end

local function OnJournalLoaded()
    ns.Log("UI", "Blizzard_Collections loaded; PetJournal=%s InitPetButton=%s UpdatePetCard=%s",
        tostring(PetJournal ~= nil), tostring(PetJournal_InitPetButton ~= nil), tostring(PetJournal_UpdatePetCard ~= nil))
    if not PetJournal then return end
    BuildCard()
    if PetJournal_InitPetButton then
        hooksecurefunc("PetJournal_InitPetButton", ns.JournalList.InitButton)
    elseif ScrollUtil and ScrollUtil.AddInitializedFrameCallback and PetJournal.ScrollBox then
        ScrollUtil.AddInitializedFrameCallback(PetJournal.ScrollBox, function(_, button, elementData)
            ns.JournalList.InitButton(button, elementData)
        end, JournalUI, false)
    end
    if PetJournal_UpdatePetCard then hooksecurefunc("PetJournal_UpdatePetCard", UpdateCard) end
    PetJournal:HookScript("OnShow", function()
        ns.Guild:Refresh()
        ns.Achievements:Check("journal", "account")
        JournalUI:Refresh()
        JournalUI:ShowPending()
    end)
    ns.Bus:On("REGISTRY", function(keys) JournalUI:Refresh(keys) end)
    ns.Bus:On("SIDEPAGE", function(open)
        if open then
            ns.Card:Pause(card) -- (every widget's pause or stop: Card.lua)
        else
            JournalUI:Refresh()
        end
    end)
    ns.Bus:On("BOND", function(key) JournalUI:Refresh({ [key] = true }) end)
end

function JournalUI:Init()
    if C_AddOns.IsAddOnLoaded("Blizzard_Collections") then
        OnJournalLoaded()
        return
    end
    ns.Events:On("ADDON_LOADED", JournalUI, function(_, _, name)
        if name ~= "Blizzard_Collections" then return end
        ns.Events:Off("ADDON_LOADED", JournalUI)
        OnJournalLoaded()
    end)
end

ns.Start("loaded", function() JournalUI:Init() end)
