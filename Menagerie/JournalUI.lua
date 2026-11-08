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
-- What it adds:
--  * a marker on each list button: star = yours, lock = someone else's,
--    check = yours to adopt (owned and free)
--  * who cares for it, nickname and how long, in the list button tooltip
--  * a status line on the pet card, plus Adopt/Let go and Nickname buttons
--    (right of the Summon button, which on Forever sits bottom left)
--  * "Guild: x of y cared for (z%)" on the card, an Auto-summon checkbox
--  * the achievements tab and page (Achievements/Page.lua)
--
-- Wording (decided 2026-11-06): companions are adopted and cared for, never
-- "reserved" or "claimed" in anything players read.
local JournalUI = {}
ns.JournalUI = JournalUI

local ICON_MINE = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1"
local ICON_TAKEN = "Interface\\LFGFrame\\UI-LFG-ICON-LOCK"
local ICON_FREE = "Interface\\RaidFrame\\ReadyCheck-Ready"

local markers = setmetatable({}, { __mode = "k" }) -- button -> texture
local badges = setmetatable({}, { __mode = "k" })  -- button -> { ring, level, nick }
JournalUI._badges = badges -- (for the tests)
local hooked = setmetatable({}, { __mode = "k" })  -- button -> true
local speciesOf = setmetatable({}, { __mode = "k" }) -- button -> speciesID, owned
local ownedOf = setmetatable({}, { __mode = "k" })
local card = {}  -- our widgets on the pet card
JournalUI._card = card -- for tools/smoke.lua

------------------------------------------------------------------------------
-- Status of a pet key, for markers and text.
------------------------------------------------------------------------------
-- "mine", "taken", "free" (and owner, record)
local function Status(key)
    local owner, r = ns.Registry:Holder(key)
    if not owner then return "free" end
    if owner == ns.PlayerKey() then return "mine", owner, r end
    return "taken", owner, r
end

local function Day(t)
    return date("%d.%m.%Y", t)
end

-- Tooltip lines for a pet key. Used by list buttons and the world tooltip.
function JournalUI:AddTooltipLines(tooltip, key)
    local status, owner, r = Status(key)
    local nick, namer, namedAt = ns.Registry:Nickname(key)
    local function Nick()
        if not nick then return end
        tooltip:AddLine(ns.T("tip.nick", { nick = nick }), 1, 1, 1)
        local by = namer == ns.PlayerKey() and ns.L["home.you"] or namer
        tooltip:AddLine(ns.T("tip.named_by", { who = by, date = Day(namedAt) }), 0.7, 0.7, 0.7)
    end
    tooltip:AddLine(" ")
    if status == "free" then
        tooltip:AddLine(ns.L["tip.free"], 0.5, 0.8, 0.5)
        Nick()
        tooltip:AddLine(ns.Personality:Line(key), 0.7, 0.7, 0.7)
        return
    end
    tooltip:AddLine(ns.Home(status == "mine" and ns.L["home.you"] or owner, r.at), 1, 0.82, 0)
    tooltip:AddLine(ns.T("tip.bond", { label = ns.Bond:Label(key) }), 1, 1, 1)
    Nick()
    tooltip:AddLine(ns.Personality:Line(key), 0.7, 0.7, 0.7)
end

------------------------------------------------------------------------------
-- List buttons
------------------------------------------------------------------------------
local function ButtonSpecies(button, elementData)
    local sid, owned = button.speciesID, button.owned
    if not sid and elementData and elementData.index then
        local _, s, isOwned = C_PetJournal.GetPetInfoByIndex(elementData.index)
        sid, owned = s, isOwned
    end
    return sid, owned
end

local function UpdateMarker(button)
    local sid = speciesOf[button]
    local tex = markers[button]
    if not tex then
        tex = button:CreateTexture(nil, "OVERLAY")
        tex:SetSize(16, 16)
        tex:SetPoint("RIGHT", button, "RIGHT", -6, 0)
        markers[button] = tex
    end
    if not sid then tex:Hide(); return end
    local status = Status(ns.Pets:KeyOfSpecies(sid))
    if status == "mine" then
        tex:SetTexture(ICON_MINE)
    elseif status == "taken" then
        tex:SetTexture(ICON_TAKEN)
    elseif ownedOf[button] then
        tex:SetTexture(ICON_FREE)
    else
        tex:Hide()
        return
    end
    tex:Show()
end

-- An adopted pet's bond level in a small gold ring, left of the marker, and
-- its nickname under the name (2026-11-08): the whole park at a glance.
local function UpdateBadge(button)
    local b = badges[button]
    if not b then
        b = {}
        b.ring = button:CreateTexture(nil, "OVERLAY")
        b.ring:SetAtlas("communities-ring-gold")
        b.ring:SetSize(20, 20)
        b.ring:SetPoint("RIGHT", button, "RIGHT", -26, 0)
        b.level = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.level:SetPoint("CENTER", b.ring, "CENTER", 0, 0)
        local name = rawget(button, "name")
        if type(name) == "table" and name.GetObjectType then
            b.name = name
            b.nick = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        end
        badges[button] = b
    end
    local sid = speciesOf[button]
    local key = sid and ns.Pets:KeyOfSpecies(sid)
    local _, level = ns.Bond:Of(key)
    b.ring:SetShown(level ~= nil); b.level:SetShown(level ~= nil)
    if level then b.level:SetText(level) end
    local nick = key and ns.Registry:Nickname(key)
    if b.nick then
        -- On the name's own row, right after it (under it spilled out of the
        -- button: seen 2026-11-08).
        b.nick:SetText(nick and ns.T("list.nick", { nick = nick }) or "")
        b.nick:ClearAllPoints()
        b.nick:SetPoint("LEFT", b.name, "LEFT", b.name:GetStringWidth() + 5, 0)
        b.nick:SetShown(nick ~= nil)
    end
end

local function OnButtonEnter(button)
    local sid = speciesOf[button]
    if not sid then return end
    if not GameTooltip:IsOwned(button) then
        GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        GameTooltip:SetText(ns.Pets:NameOfKey(ns.Pets:KeyOfSpecies(sid)))
    end
    JournalUI:AddTooltipLines(GameTooltip, ns.Pets:KeyOfSpecies(sid))
    GameTooltip:Show()
end

local function OnButtonLeave(button)
    if GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end

local function InitButton(button, elementData)
    local sid, owned = ButtonSpecies(button, elementData)
    speciesOf[button], ownedOf[button] = sid, owned
    if not hooked[button] then
        hooked[button] = true
        button:HookScript("OnEnter", OnButtonEnter)
        button:HookScript("OnLeave", OnButtonLeave)
    end
    UpdateMarker(button)
    UpdateBadge(button)
end

local function RefreshList()
    local box = PetJournal and PetJournal.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(function(button) UpdateMarker(button); UpdateBadge(button) end)
    end
end

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

local function UpdateExtras()
    local n, total = ns.Registry:Count(), ns.Pets:Total()
    local pct = total > 0 and math.floor(n / total * 100 + 0.5) or 0
    card.counter:SetText(ns.T("card.guild.value", { n = n, total = total, pct = pct }))
    card.guildBox.tip = ns.T("card.guild.tip", { n = n, total = total, pct = pct })
    local today, owner = ns.Bonds:PetOfTheDay()
    card.today:SetText(today and ns.Bonds:NameOf(today) or "-")
    card.todayBox.tip = today and ns.T("card.today.tip", { pet = ns.Bonds:NameOf(today), owner = owner })
        or ns.L["card.today.none"]
    -- "Dagens dyr" fills the row up to the card's right edge, wherever the
    -- row starts: a fixed width ran past the window (seen 2026-11-08). A long
    -- name is cut short; the tooltip has it whole.
    local right, from = PetJournalPetCard:GetRight(), card.guildBox:GetRight()
    if right and from then card.todayBox:SetWidth(math.max(80, right - from - BOX_GAP)) end
    local deferring = ns.Summon:Deferring()
    card.auto:SetChecked(ns.DB.char.autoSummon and not deferring)
    card.auto:SetEnabled(not deferring)
    card.autoLabel:SetTextColor(deferring and 0.5 or 1, deferring and 0.5 or 0.82, deferring and 0.5 or 0)
end

local function UpdateCard()
    if not card.status then return end
    UpdateExtras()
    local sid = CardSpecies()
    if not sid then
        card.status:SetText("")
        card.nickname:SetText("")
        card.personality:SetText("")
        card.likes:SetText("")
        card.key = nil -- the hover tooltips follow it
        card.scene:Hide()
        ns.Scenes:Paint(card, nil)
        ns.Decor:Apply(card, nil)
        ns.Stats:Update(card, nil)
        ns.Wish:Update(card, nil)
        card.bond:Hide()
        card.reserve:Hide()
        card.nick:Hide()
        return
    end
    local key = ns.Pets:KeyOfSpecies(sid)
    local status, owner, r = Status(key)
    local ownedIt = ns.Pets:Owned()[key] ~= nil
    local nick = ns.Registry:Nickname(key)
    local text
    if status == "free" then
        text = "|cff80cc80" .. ns.L["card.free"] .. "|r"
    elseif status == "mine" then
        text = "|cffffd100" .. ns.Home(ns.L["home.you"], r.at) .. "|r"
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
    card.personality:SetText(ns.Personality:Names(key))
    local likes = ns.Personality:LikedWords(key)
    card.likes:SetText(#likes > 0 and ns.T("card.likes", { list = ns.Personality.Join(likes) }) or "")
    local scene = ns.Scenes:For(key)
    if scene then
        card.scene:SetTexture(scene)
        card.scene:SetTexCoord(ns.Scenes.Crop(scene))
        card.scene:Show()
    else
        card.scene:Hide()
    end
    ns.Scenes:Paint(card, key)
    -- The holder's bond with it: everyone sees everyone's.
    local tint = ns.Scenes.TINT[card.family] or ns.Scenes.TINT.default
    local _, level = ns.Bond:Of(key)
    ns.Decor:Apply(card, key, level, tint)
    ns.Stats:Update(card, key) -- (after the decorations: it sits under the ribbon when there is one)
    ns.Wish:Update(card, key) -- (under the chips)
    ns.BondTrack:Update(card, key, { math.min(1, tint[1] * 1.7), math.min(1, tint[2] * 1.7), math.min(1, tint[3] * 1.7) })

    card.key = key
    if status == "mine" then
        card.reserve:SetText(ns.L["card.letgo"])
        card.reserve:Enable()
        card.reserve:Show()
        card.nick:Show()
        if ns.Registry:CanNickname(r) then card.nick:Enable() else card.nick:Disable() end
    elseif status == "free" and ownedIt then
        card.reserve:SetText(ns.L["card.adopt"])
        card.reserve:Enable()
        card.reserve:Show()
        card.nick:Hide()
    else
        card.reserve:Hide()
        card.nick:Hide()
    end
end

local function Report(ok, msg)
    if msg then ns.Print(msg) end
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
    box:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(self.tip or label, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
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

    card.nickname = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    card.nickname:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    -- The left column stops at the bond column; a long line ends in "...",
    -- and hovering it tells all.
    card.nickname:SetPoint("RIGHT", panel, "RIGHT", -COLUMN, 0)
    card.nickname:SetJustifyH("LEFT")
    card.nickname:SetWordWrap(false)
    card.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("TOPLEFT", card.nickname, "BOTTOMLEFT", 0, -3)
    card.status:SetPoint("RIGHT", panel, "RIGHT", -COLUMN, 0)
    card.status:SetJustifyH("LEFT")
    card.status:SetWordWrap(false)
    -- Hover the name or the home line: both in full (a long one ends in "...").
    card.nameHit = CreateFrame("Frame", nil, panel)
    card.nameHit:SetPoint("TOPLEFT", card.nickname, "TOPLEFT", -2, 2)
    card.nameHit:SetPoint("BOTTOMRIGHT", card.status, "BOTTOMRIGHT", 2, -2)
    card.nameHit:EnableMouse(true)
    card.nameHit:SetScript("OnEnter", function(self)
        if not card.key then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(card.fullName, 1, 0.82, 0)
        if card.fullName ~= card.species then GameTooltip:AddLine(card.species, 1, 1, 1) end
        GameTooltip:AddLine(card.home, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    card.nameHit:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)
    -- Its personality: the traits, then what it likes.
    card.personality = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.personality:SetPoint("TOPLEFT", card.status, "BOTTOMLEFT", 0, -5)
    card.personality:SetPoint("RIGHT", panel, "RIGHT", -COLUMN, 0)
    card.personality:SetJustifyH("LEFT")
    card.personality:SetWordWrap(false)
    card.personality:SetTextColor(0.95, 0.75, 0.45)
    card.likes = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.likes:SetPoint("TOPLEFT", card.personality, "BOTTOMLEFT", 0, -3)
    card.likes:SetPoint("RIGHT", panel, "RIGHT", -COLUMN, 0)
    card.likes:SetJustifyH("LEFT")
    card.likes:SetWordWrap(false)
    -- Hover the line: what the traits mean and do, what it likes, and why it matters.
    card.personalityHit = CreateFrame("Frame", nil, panel)
    card.personalityHit:SetPoint("TOPLEFT", card.personality, "TOPLEFT", -2, 2)
    card.personalityHit:SetPoint("BOTTOMRIGHT", card.likes, "BOTTOMRIGHT", 2, -2)
    card.personalityHit:EnableMouse(true)
    card.personalityHit:SetScript("OnEnter", function(self)
        if not card.key then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:ClearLines()
        ns.Personality:Describe(GameTooltip, card.key)
        local words = ns.Personality:LikedWords(card.key)
        if #words > 0 then
            GameTooltip:AddLine(("Liker: %s"):format(table.concat(words, ", ")), 0.5, 0.8, 0.5, true)
        end
        GameTooltip:AddLine(ns.L["card.personality.hint"], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    card.personalityHit:SetScript("OnLeave", function(self) if GameTooltip:IsOwned(self) then GameTooltip:Hide() end end)

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
    card.rotate = left and { left, right } or nil
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
    -- The pet's nickname, big, right above the status line.
    card.bond:Hide()

    local anchor = PetJournalSummonButton or c
    card.reserve = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.reserve:SetSize(90, 22)
    -- Forever puts the Summon/Dismiss button at the bottom left of the
    -- journal (under the list), so our buttons go to its right, under the card.
    card.reserve:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    card.reserve:SetScript("OnClick", function()
        local status = Status(card.key)
        if status == "mine" then
            Report(ns.Registry:Release())
        else
            JournalUI:AskAdopt(card.key)
        end
    end)
    card.reserve:Hide()

    card.nick = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.nick:SetSize(90, 22)
    card.nick:SetPoint("LEFT", card.reserve, "RIGHT", 4, 0)
    card.nick:SetText(ns.L["card.nick"])
    card.nick:SetMotionScriptsWhileDisabled(true)
    card.nick:SetScript("OnClick", function() JournalUI:AskNickname() end)
    card.nick:SetScript("OnEnter", function(self)
        local _, r = ns.Registry:MyPet()
        if r and not ns.Registry:CanNickname(r) then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns.T("card.nick.locked", { level = ns.Bond.LEVELS[ns.Config.NICKNAME_LEVEL][2],
                n = ns.Config.NICKNAME_LEVEL }), 1, 1, 1, 1, true)
            GameTooltip:Show()
        end
    end)
    card.nick:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.nick:Hide()

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

    -- Auto-summon toggle (per character, default on), bottom right of the
    -- journal. Greyed out while AutoCompanion is loaded, which takes over.
    card.auto = CreateFrame("CheckButton", nil, PetJournal, "UICheckButtonTemplate")
    card.auto:SetSize(24, 24)
    -- Far enough left for "Tilkall automatisk" (cut off at -96, seen 2026-11-08).
    card.auto:SetPoint("BOTTOMRIGHT", PetJournal, "BOTTOMRIGHT", -118, 3)
    card.autoLabel = card.auto:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.autoLabel:SetPoint("LEFT", card.auto, "RIGHT", 2, 0)
    card.autoLabel:SetText(ns.L["card.auto"])
    card.auto:SetMotionScriptsWhileDisabled(true)
    card.auto:SetScript("OnClick", function(self)
        ns.Summon:SetEnabled(self:GetChecked() and true or false)
    end)
    card.auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if ns.Summon:Deferring() then
            GameTooltip:SetText(ns.L["card.auto.deferred"])
        else
            GameTooltip:SetText(ns.L["card.auto"])
            GameTooltip:AddLine(ns.L["card.auto.tip"], 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    card.auto:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- The achievements tab and page (Achievements/Page.lua).
    ns.AchPage:Attach(PetJournal, card.auto)
end

------------------------------------------------------------------------------
-- Nickname popup
------------------------------------------------------------------------------
-- Adopting from the card asks first: it's posted to guild chat (when
-- announcing is on), and it lets go of the pet you had (decided 2026-11-08).
-- /dp adopter doesn't ask: typing it is asking.
StaticPopupDialogs["DYREPARKEN_ADOPT"] = {
    text = "%s",
    button1 = ns.L["card.adopt"],
    button2 = CANCEL,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    -- The click is the hardware event that allows the guild chat post.
    OnAccept = function(_, key)
        if not key then return end
        local ok, msg = ns.Registry:Claim(key)
        if msg then ns.Print(msg) end
        if ok then ns.Bonds:Announce("adopt", key) end
    end,
}

function JournalUI:AskAdopt(key)
    if not key then return end
    local text = ns.T("adopt.confirm", { pet = ns.Pets:NameOfKey(key) })
    local mine = ns.Registry:MyPet()
    if mine and mine ~= key then text = text .. "\n" .. ns.T("adopt.confirm.swap", { pet = ns.Bonds:NameOf(mine) }) end
    if ns.DB.char.announce then text = text .. "\n\n" .. ns.L["adopt.confirm.announce"] end
    StaticPopup_Show("DYREPARKEN_ADOPT", text, nil, key)
end

StaticPopupDialogs["DYREPARKEN_NICKNAME"] = {
    text = ns.T("card.nick.popup", { n = "%d" }), -- StaticPopup_Show fills in the number
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = ns.Config.NICKNAME_MAX_LEN,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        local key = ns.Registry:MyPet()
        if eb then eb:SetText(key and ns.Registry:Nickname(key) or ""); eb:HighlightText() end
    end,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox
        JournalUI:Rename(eb and eb:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        JournalUI:Rename(self:GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

-- From the dialog's Accept or Enter: a click or keypress, so it may post.
function JournalUI:Rename(text)
    local ok, msg = ns.Registry:SetNickname(text)
    Report(ok, msg)
    if ok then ns.Bonds:Announce("name", (ns.Registry:MyPet())) end
end

function JournalUI:AskNickname()
    StaticPopup_Show("DYREPARKEN_NICKNAME", ns.Config.NICKNAME_MAX_LEN)
end

------------------------------------------------------------------------------
-- Wiring
------------------------------------------------------------------------------
function JournalUI:Refresh()
    if not (PetJournal and PetJournal:IsVisible()) then return end
    RefreshList()
    UpdateCard()
end

local function OnJournalLoaded()
    ns.Log("UI", "Blizzard_Collections loaded; PetJournal=%s InitPetButton=%s UpdatePetCard=%s",
        tostring(PetJournal ~= nil), tostring(PetJournal_InitPetButton ~= nil), tostring(PetJournal_UpdatePetCard ~= nil))
    if not PetJournal then return end
    BuildCard()
    if PetJournal_InitPetButton then
        hooksecurefunc("PetJournal_InitPetButton", InitButton)
    elseif ScrollUtil and ScrollUtil.AddInitializedFrameCallback and PetJournal.ScrollBox then
        ScrollUtil.AddInitializedFrameCallback(PetJournal.ScrollBox, function(_, button, elementData)
            InitButton(button, elementData)
        end, JournalUI, false)
    end
    if PetJournal_UpdatePetCard then hooksecurefunc("PetJournal_UpdatePetCard", UpdateCard) end
    PetJournal:HookScript("OnShow", function()
        ns.Guild:Refresh()
        ns.Achievements:Check("journal", "account")
        JournalUI:Refresh()
    end)
    ns.Bus:On("REGISTRY", function() JournalUI:Refresh() end)
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
