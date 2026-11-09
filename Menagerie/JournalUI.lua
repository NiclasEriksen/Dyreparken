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
--    guild's boxes above it, and the widgets drawn for the pet (WIDGETS)
--  * the card's buttons and popups (CardActions.lua): Adopter / Gi slipp, Kallenavn
--  * the achievements tab and page (Achievements/Page.lua)
--
-- Wording (decided 2026-11-06): companions are adopted and cared for, never
-- "reserved" or "claimed" in anything players read.
local JournalUI = {}
ns.JournalUI = JournalUI

local card = {}  -- our widgets on the pet card
JournalUI._card = card -- for tools/smoke.lua

------------------------------------------------------------------------------
-- Pet card
------------------------------------------------------------------------------
local function CardSpecies()
    local c = PetJournalPetCard
    if not c then return nil end
    if c.speciesID then return c.speciesID end
    if c.petID then return (C_PetJournal.GetPetInfoByPetID(c.petID)) end
end

local PANEL_H = 86 -- four lines on the left: name, home, traits, likes
local COLUMN = 214 -- the bond column, from the panel's right edge (BondTrack.lua): the left column ends there
local MODEL_LIFT = 34 -- the model's bottom, above the panel: clear of the turn buttons
local NAME_FONTS = { "GameFontNormalHuge", "GameFontNormalLarge", "GameFontNormal" } -- the name, biggest first
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
    card.todayBox.tip = today and ns.T("card.today.tip", { pet = ns.Registry:NameOf(today), owner = owner })
        or ns.L["card.today.none"]
    SizeTodayBox()
end

-- The card's widgets, in drawing order: each draws itself for the pet (or
-- clears itself, key nil). ctx: the family's tint and the bond level shown.
-- A new widget is a Build in BuildCard and a line here.
local WIDGETS = {
    function(key, ctx) ns.Decor:Apply(card, key, ctx.level, ctx.tint) end,
    function(key) ns.Stats:Update(card, key) end, -- (after the decorations: under the ribbon when there is one)
    function(key) ns.Wish:Update(card, key) end,  -- (under the chips)
    function(key, ctx) ns.BondTrack:Update(card, key, ns.Scenes.Bright(ctx.tint, 1.7)) end,
    function(key) ns.OutBadge:Update(card, key) end, -- "Med deg": is this the pet kept out?
}

local function DrawWidgets(key)
    card.key = key -- (the hover tooltips and clicks follow it)
    local ctx = { tint = ns.Scenes:Paint(card, key) or ns.Scenes.TINT.default } -- (the picture, the light)
    if key then ctx.level = select(2, ns.Bond:Shown(key)) end -- your bond with it, or its carer's
    for _, draw in ipairs(WIDGETS) do draw(key, ctx) end
    SizeTodayBox()
end

local function UpdateCard()
    if not card.status then return end
    -- Under one of our pages (Parken, Prestasjoner) the card can't be seen:
    -- no work, no animations, no celebration spent there. It's redrawn when
    -- the page closes (SIDEPAGE).
    if ns.SidePage:AnyOpen() then return end
    local sid = CardSpecies()
    if not sid then
        card.status:SetText("")
        card.nickname:SetText("")
        card.personality:SetText("")
        card.likes:SetText("")
        DrawWidgets(nil)
        ns.CardActions:Update(card, nil)
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
    card.status:SetText(nick and (species .. " · " .. text) or text)
    card.fullName, card.species, card.home = nick or species, species, text -- for the hover
    if ns.Personality:Known(key) then
        card.personality:SetText(ns.Personality:Names(key))
        local likes = ns.Personality:LikedWords(key)
        card.likes:SetText(#likes > 0 and ns.T("card.likes", { list = ns.Join(likes) }) or "")
    else -- a surprise until it's collected or adopted
        card.personality:SetText(ns.L["personality.unknown"])
        card.likes:SetText("")
    end
    DrawWidgets(key)
    ns.Sync:AskBonds(key) -- others' bonds with it (not in the full sync)
    ns.CardActions:Update(card, key)
end

-- A box like Blizzard's "Total Pets": a label left, a value right, a tooltip (box.tip).
local function InfoBox(label, width)
    local box = CreateFrame("Frame", nil, PetJournal, ns.SidePage.Template("InsetFrameTemplate3"))
    box:SetSize(width, 20)
    box.label = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    box.label:SetPoint("LEFT", box, "LEFT", 10, 0)
    box.label:SetText(label)
    box.value = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    box.value:SetPoint("RIGHT", box, "RIGHT", -10, 0)
    box.value:SetPoint("LEFT", box.label, "RIGHT", 6, 0)
    box.value:SetJustifyH("RIGHT")
    box.value:SetWordWrap(false)
    box:EnableMouse(true)
    ns.SetTip(box, "ANCHOR_BOTTOM", function(self) return self.tip or label end)
    return box
end

local function BuildCard()
    local c = PetJournalPetCard
    if not c or card.status then return end
    -- The scene behind the model (Scenes.lua), under everything else.
    -- The backdrop, in layers (Scenes.lua): dungeon art where the family has
    -- one, a gradient tinted by family, dark edges, and a floor shadow under
    -- the model. Nothing is stretched past its size: the tint and edges are
    -- drawn, not pictures.
    card.scene = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.scene:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
    card.scene:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
    card.scene:SetAlpha(0.8)
    card.scene:Hide()
    card.tint = c:CreateTexture(nil, "BACKGROUND", nil, 2)
    card.tint:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
    card.tint:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
    card.tint:SetColorTexture(1, 1, 1, 1)
    card.tint:Hide()
    -- The light of the hour over the scene (Scenes.SKY).
    card.sky = c:CreateTexture(nil, "BACKGROUND", nil, 3)
    card.sky:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
    card.sky:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
    card.sky:SetColorTexture(1, 1, 1, 1)
    card.sky:Hide()
    card.edges = {}
    for i, side in ipairs({ "TOP", "LEFT", "RIGHT" }) do
        local t = c:CreateTexture(nil, "BACKGROUND", nil, 3)
        t:SetColorTexture(1, 1, 1, 1)
        if side == "TOP" then
            t:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4); t:SetPoint("TOPRIGHT", c, "TOPRIGHT", -4, -4)
            t:SetHeight(70)
        else
            t:SetPoint("TOP" .. side, c, "TOP" .. side, side == "LEFT" and 4 or -4, -4)
            t:SetPoint("BOTTOM" .. side, c, "BOTTOM" .. side, side == "LEFT" and 4 or -4, 4)
            t:SetWidth(70)
        end
        t.side = side
        card.edges[i] = t
    end
    card.floor = c:CreateTexture(nil, "BORDER")
    card.floor:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask")
    card.floor:SetVertexColor(0, 0, 0, 0.45)
    card.floor:SetSize(200, 36)
    card.floor:Hide()

    -- The panel: a dark strip along the bottom. It sits below the model's
    -- frame level, so Blizzard's rotate buttons stay on top, in the gap
    -- between our left column (name, home) and right column (the bond).
    -- The guild line runs along its bottom edge.
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
    ns.Decor:Build(card, c, panel)
    ns.Stats:Build(card, c)
    ns.Wish:Build(card, c)
    ns.OutBadge:Build(card, c)

    -- The left column: lines that stop at the bond column; a long one ends in
    -- "...", and hovering it tells all.
    local function Line(font, below, gap)
        local fs = panel:CreateFontString(nil, "OVERLAY", font)
        if below then fs:SetPoint("TOPLEFT", below, "BOTTOMLEFT", 0, -gap)
        else fs:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8) end
        fs:SetPoint("RIGHT", panel, "RIGHT", -COLUMN, 0)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    -- A hover area over two lines, for the pet on the card.
    local function HitOver(top, bottom, onEnter)
        local f = CreateFrame("Frame", nil, panel)
        f:SetPoint("TOPLEFT", top, "TOPLEFT", -2, 2)
        f:SetPoint("BOTTOMRIGHT", bottom, "BOTTOMRIGHT", 2, -2)
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self)
            if not card.key then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:ClearLines()
            onEnter()
            GameTooltip:Show()
        end)
        f:SetScript("OnLeave", ns.HideTip)
        return f
    end
    card.nickname = Line("GameFontNormalHuge")
    card.status = Line("GameFontHighlightSmall", card.nickname, 3)
    -- Hover the name or the home line: both in full.
    card.nameHit = HitOver(card.nickname, card.status, function()
        GameTooltip:SetText(card.fullName, 1, 0.82, 0)
        if card.fullName ~= card.species then GameTooltip:AddLine(card.species, 1, 1, 1) end
        GameTooltip:AddLine(card.home, 1, 1, 1, true)
    end)
    -- Its personality: the traits, then what it likes.
    card.personality = Line("GameFontNormalSmall", card.status, 5)
    card.personality:SetTextColor(0.95, 0.75, 0.45)
    card.likes = Line("GameFontDisableSmall", card.personality, 3)
    -- Hover the lines: what the traits mean and do, what it likes, and why it matters.
    card.personalityHit = HitOver(card.personality, card.likes, function()
        if not ns.Personality:Known(card.key) then
            GameTooltip:SetText(ns.L["personality.unknown"], 1, 0.82, 0)
            GameTooltip:AddLine(ns.L["personality.unknown.tip"], 1, 1, 1, true)
            return
        end
        ns.Personality:Describe(GameTooltip, card.key)
        local words = ns.Personality:LikedWords(card.key)
        if #words > 0 then
            GameTooltip:AddLine(ns.T("card.likes.tip", { list = ns.Join(words) }), 0.5, 0.8, 0.5, true)
        end
        GameTooltip:AddLine(ns.L["card.personality.hint"], 0.7, 0.7, 0.7, true)
    end)

    -- The bond, right column: a medallion, the track of levels, a bar (BondTrack.lua).
    ns.BondTrack:Build(card, c, panel)

    -- Blizzard's turn buttons sit where our rows go: move them to just above
    -- the panel, so the panel's text runs the full width. (Plain buttons;
    -- moving them taints nothing.) Seen in the middle of the panel, 2026-11-08.
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
        card.nickname:SetPoint("RIGHT", panel, "CENTER", -52, 0)
        card.status:SetPoint("RIGHT", panel, "CENTER", -52, 0)
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
    ns.Cuddle:Build(card, c, panel) -- (after the model is found: it listens for clicks on it)

    ns.CardActions:Build(card, c)

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
    card.todayBox = InfoBox(ns.L["card.today"], 140)
    card.todayBox:SetPoint("LEFT", card.guildBox, "RIGHT", BOX_GAP, 0)
    card.counter, card.today = card.guildBox.value, card.todayBox.value

    -- The fallback tab buttons (SidePage) line up right to left from here,
    -- bottom right of the journal (where the old "Hold ute" box was).
    card.tabAnchor = CreateFrame("Frame", nil, PetJournal)
    card.tabAnchor:SetSize(1, 22)
    card.tabAnchor:SetPoint("BOTTOMRIGHT", PetJournal, "BOTTOMRIGHT", -6, 3)

    -- The achievements tab and page (Achievements/Page.lua).
    ns.AchPage:Attach(PetJournal, card.tabAnchor)
end

------------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------------
function JournalUI:Refresh()
    if not (PetJournal and PetJournal:IsVisible()) then return end
    if ns.SidePage:AnyOpen() then return end -- under our page: refreshed when it closes
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
    end)
    ns.Bus:On("REGISTRY", function() JournalUI:Refresh() end)
    ns.Bus:On("SIDEPAGE", function(open)
        if open then
            ns.Decor:Stop(card)
            ns.BondTrack:Pause(card)
        else
            JournalUI:Refresh()
        end
    end)
    ns.Bus:On("BOND", function() JournalUI:Refresh() end)
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

-- /dp probe card: what Blizzard's pet card is made of on Forever (2026-11-08:
-- to hide its title row, the pet's icon and name at the top, we need its
-- name). Logs the card's children and regions, two levels down: the key
-- they're stored under on their parent, the type, shown, size and anchor.
function JournalUI:ProbeCard()
    local c = rawget(_G, "PetJournalPetCard")
    if not c then return ns.Print("Open the pet journal first.") end
    local function KeyOf(parent, obj)
        for k, v in pairs(parent) do if v == obj and type(k) == "string" then return k end end
        return "-"
    end
    local function Describe(obj, parent, depth)
        local ok, kind = pcall(obj.GetObjectType, obj)
        local name = obj.GetName and obj:GetName() or nil
        local w, h
        if obj.GetSize then w, h = obj:GetSize() end
        local point, rel, relPoint, x, y = nil, nil, nil, nil, nil
        if obj.GetPoint then point, rel, relPoint, x, y = obj:GetPoint(1) end
        local relName = rel and ((rel.GetName and rel:GetName()) or KeyOf(parent, rel)) or "-"
        local text = obj.GetText and obj:GetText() or nil
        ns.Log("Probe", "card %s%s key=%s name=%s shown=%s size=%sx%s at=%s %s %s %s,%s%s", ("  "):rep(depth),
            tostring(ok and kind or "?"), KeyOf(parent, obj), tostring(name), tostring(obj.IsShown and obj:IsShown()),
            tostring(w and math.floor(w)), tostring(h and math.floor(h)), tostring(point), tostring(relName),
            tostring(relPoint), tostring(x and math.floor(x)), tostring(y and math.floor(y)),
            text and (" text=" .. tostring(text)) or "")
    end
    local function Walk(frame, depth)
        for _, r in ipairs({ frame:GetRegions() }) do Describe(r, frame, depth) end
        for _, child in ipairs({ frame:GetChildren() }) do
            Describe(child, frame, depth)
            if depth < 2 then Walk(child, depth + 1) end
        end
    end
    Walk(c, 0)
    ns.Print("Pet card probed; /reload and send the debug log.")
end
