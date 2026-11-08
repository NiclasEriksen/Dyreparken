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
        tooltip:AddLine(("Kallenavn: «%s»"):format(nick), 1, 1, 1)
        local by = namer == ns.PlayerKey() and "deg" or namer
        tooltip:AddLine(("Navngitt av %s, %s"):format(by, Day(namedAt)), 0.7, 0.7, 0.7)
    end
    tooltip:AddLine(" ")
    if status == "free" then
        tooltip:AddLine("Dyreparken: trenger et hjem", 0.5, 0.8, 0.5)
        Nick()
        return
    end
    tooltip:AddLine(("Bor hos %s"):format(status == "mine" and "deg" or owner), 1, 0.82, 0)
    tooltip:AddLine(("Bånd: %s"):format(ns.Bond:Label(key)), 1, 1, 1)
    Nick()
    local how = ns.CaredFor(r.at)
    tooltip:AddLine(how:sub(1, 1):upper() .. how:sub(2), 0.7, 0.7, 0.7)
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
end

local function RefreshList()
    local box = PetJournal and PetJournal.ScrollBox
    if box and box.ForEachFrame then
        box:ForEachFrame(function(button) UpdateMarker(button) end)
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

local PANEL_H = 58

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

local function UpdateExtras()
    local n, total = ns.Registry:Count(), ns.Pets:Total()
    local pct = total > 0 and math.floor(n / total * 100 + 0.5) or 0
    card.counter:SetText(("%d av %d (%d%%)"):format(n, total, pct))
    card.guildBox.tip = ("Guilden: %d av %d kjæledyr har et hjem (%d%%)."):format(n, total, pct)
    local today, owner = ns.Bonds:PetOfTheDay()
    card.today:SetText(today and ns.Bonds:NameOf(today) or "-")
    card.todayBox.tip = today and ("Dagens dyr: %s, som bor hos %s."):format(ns.Bonds:NameOf(today), owner)
        or "Dagens dyr: ingen har adoptert et kjæledyr ennå."
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
        card.scene:Hide()
        ns.Scenes:Paint(card, nil)
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
        text = "|cff80cc80Trenger et hjem|r"
    elseif status == "mine" then
        text = "|cffffd100Bor hos deg|r " .. ns.CaredFor(r.at)
    else
        text = "|cffff8080Bor hos " .. owner .. "|r " .. ns.CaredFor(r.at)
    end
    -- Big: the nickname, else the species. Small: the species (if named) and its home.
    local species = ns.Pets:NameOfKey(key) or ""
    card.nickname:SetText(nick or species)
    card.status:SetText(nick and (species .. " · " .. text) or text)
    local scene = ns.Scenes:For(key)
    if scene then
        card.scene:SetTexture(scene)
        card.scene:Show()
    else
        card.scene:Hide()
    end
    ns.Scenes:Paint(card, key)
    -- The holder's bond with it, as a bar: everyone sees everyone's.
    local points, level, name, from, nextAt = ns.Bond:Of(key)
    if points then
        card.bond.label:SetText(("Bånd: %s (nivå %d)"):format(name, level))
        card.bond.level:SetText(level)
        card.bond:SetMinMaxValues(from, nextAt or math.max(points, 1))
        card.bond:SetValue(nextAt and points or math.max(points, 1)) -- the top level: full
        card.bond.text:SetText(nextAt and ("%d / %d"):format(points, nextAt) or ("%d"):format(points))
        card.bond:Show()
    else
        card.bond:Hide()
    end

    card.key = key
    if status == "mine" then
        card.reserve:SetText("Gi slipp")
        card.reserve:Enable()
        card.reserve:Show()
        card.nick:Show()
        if ns.Registry:CanNickname(r) then card.nick:Enable() else card.nick:Disable() end
    elseif status == "free" and ownedIt then
        card.reserve:SetText("Adopter")
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
    card.floor:SetSize(230, 44)
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
    card.floor:SetPoint("CENTER", panel, "TOP", 0, 44) -- where the model stands (seen 2026-11-08)

    card.nickname = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    card.nickname:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    -- The left column stops short of the bond column (bar: 30 + 8 + 130 from the right).
    card.nickname:SetPoint("RIGHT", panel, "CENTER", 30, 0)
    card.nickname:SetJustifyH("LEFT")
    card.nickname:SetWordWrap(false)
    card.status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("TOPLEFT", card.nickname, "BOTTOMLEFT", 0, -3)
    card.status:SetPoint("RIGHT", panel, "CENTER", 30, 0)
    card.status:SetJustifyH("LEFT")
    card.status:SetWordWrap(false)

    -- The bond, right column: the level in a badge, its name, a slim bar.
    card.bond = CreateFrame("StatusBar", nil, panel)
    card.bond:SetSize(130, 12)
    card.bond:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    card.bond:SetStatusBarColor(1, 0.7, 0.2)
    card.bond.bg = card.bond:CreateTexture(nil, "BACKGROUND")
    card.bond.bg:SetAllPoints()
    card.bond.bg:SetColorTexture(1, 1, 1, 0.12)
    card.bond.badge = card.bond:CreateTexture(nil, "ARTWORK")
    card.bond.badge:SetSize(30, 30)
    card.bond.badge:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -12, -9)
    card.bond.badge:SetTexture(ns.Achievements:Icon({ id = "card:bond", icon = { "INV_ValentinesCandy",
        "Spell_Holy_SealOfSacrifice" } }))
    card.bond.level = card.bond:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
    card.bond.level:SetPoint("CENTER", card.bond.badge, "BOTTOMRIGHT", -3, 3)
    card.bond.label = card.bond:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.bond.label:SetPoint("TOPRIGHT", card.bond.badge, "TOPLEFT", -8, 1)
    card.bond:SetPoint("BOTTOMRIGHT", card.bond.badge, "BOTTOMLEFT", -8, 3)
    card.bond.text = card.bond:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.bond.text:SetPoint("CENTER", card.bond, "CENTER", 0, 0) -- on the bar, not beside it (it hit the home line)

    -- Blizzard's turn buttons sit where our rows go: move them to just above
    -- the panel, so the panel's text runs the full width. (Plain buttons;
    -- moving them taints nothing.) Seen in the middle of the panel, 2026-11-08.
    local left, right = RotateButtons(c)
    if left then
        left:ClearAllPoints()
        left:SetPoint("BOTTOMRIGHT", panel, "TOP", -3, 6)
        right:ClearAllPoints()
        right:SetPoint("BOTTOMLEFT", panel, "TOP", 3, 6)
    end
    if not left then
        -- They stay wherever they are, likely mid-panel: keep our text clear of the middle.
        card.nickname:SetPoint("RIGHT", panel, "CENTER", -52, 0)
        card.status:SetPoint("RIGHT", panel, "CENTER", -52, 0)
    end
    ns.Log("Journal", "rotate buttons %s", left and "moved above the panel" or "not found")
    card.rotate = left and { left, right } or nil
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
            local key = card.key
            local ok, msg = ns.Registry:Claim(key)
            Report(ok, msg)
            if ok then ns.Bonds:Announce("adopt", key) end
        end
    end)
    card.reserve:Hide()

    card.nick = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.nick:SetSize(90, 22)
    card.nick:SetPoint("LEFT", card.reserve, "RIGHT", 4, 0)
    card.nick:SetText("Kallenavn")
    card.nick:SetMotionScriptsWhileDisabled(true)
    card.nick:SetScript("OnClick", function() JournalUI:AskNickname() end)
    card.nick:SetScript("OnEnter", function(self)
        local _, r = ns.Registry:MyPet()
        if r and not ns.Registry:CanNickname(r) then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(("Du kan gi det et kallenavn fra %s."):format(Day(ns.Registry:NicknameUnlocksAt(r))))
            GameTooltip:Show()
        end
    end)
    card.nick:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.nick:Hide()

    -- The guild's numbers: boxes like Blizzard's "Total Pets", on its row.
    -- "Guilden x av y": y = every companion in Forever's journal
    -- (Pets:Total, Data/Companions.lua). Then "Dagens dyr".
    local count = rawget(PetJournal, "PetCount") or rawget(_G, "PetJournalPetCount")
    card.guildBox = InfoBox("Guilden", 130)
    if count then
        card.guildBox:SetPoint("LEFT", count, "RIGHT", 8, 0)
    else
        card.guildBox:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 160, 8)
    end
    card.todayBox = InfoBox("Dagens dyr", 150)
    card.todayBox:SetPoint("LEFT", card.guildBox, "RIGHT", 8, 0)
    card.counter, card.today = card.guildBox.value, card.todayBox.value

    -- Auto-summon toggle (per character, default on), bottom right of the
    -- journal. Greyed out while AutoCompanion is loaded, which takes over.
    card.auto = CreateFrame("CheckButton", nil, PetJournal, "UICheckButtonTemplate")
    card.auto:SetSize(24, 24)
    -- Far enough left for "Tilkall automatisk" (cut off at -96, seen 2026-11-08).
    card.auto:SetPoint("BOTTOMRIGHT", PetJournal, "BOTTOMRIGHT", -118, 3)
    card.autoLabel = card.auto:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.autoLabel:SetPoint("LEFT", card.auto, "RIGHT", 2, 0)
    card.autoLabel:SetText("Tilkall automatisk")
    card.auto:SetMotionScriptsWhileDisabled(true)
    card.auto:SetScript("OnClick", function(self)
        ns.Summon:SetEnabled(self:GetChecked() and true or false)
    end)
    card.auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if ns.Summon:Deferring() then
            GameTooltip:SetText("AutoCompanion er lastet og tar seg av tilkallingen.")
        else
            GameTooltip:SetText("Tilkall automatisk")
            GameTooltip:AddLine("Tilkaller kjæledyret ditt når det mangler og du ikke er opptatt.", 1, 1, 1, true)
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
StaticPopupDialogs["DYREPARKEN_NICKNAME"] = {
    text = "Kallenavn på kjæledyret ditt (maks %d tegn, tomt fjerner det):",
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
