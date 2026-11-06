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
--    check = yours to claim (owned and free)
--  * owner / nickname / date lines in the list button tooltip
--  * a status line on the pet card, plus Reserve/Release and Nickname buttons
--    (right of the Summon button, which on Forever sits bottom left)
--  * "x reserved of y known" on the card, an Auto-summon checkbox
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

local function Since(t)
    return date("%d %b %Y", t)
end

-- Tooltip lines for a pet key. Used by list buttons and the world tooltip.
function JournalUI:AddTooltipLines(tooltip, key)
    local status, owner, r = Status(key)
    tooltip:AddLine(" ")
    if status == "free" then
        tooltip:AddLine("Dyreparken: not reserved", 0.5, 0.8, 0.5)
        return
    end
    tooltip:AddLine(("Reserved by %s"):format(status == "mine" and "you" or owner), 1, 0.82, 0)
    if r.n then tooltip:AddLine(('Nickname: "%s"'):format(r.n), 1, 1, 1) end
    tooltip:AddLine("Since " .. Since(r.at), 0.7, 0.7, 0.7)
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

local function UpdateExtras()
    card.counter:SetText(("Guild: %d reserved of %d known"):format(ns.Registry:Count(), ns.Pets:KnownCount()))
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
        card.reserve:Hide()
        card.nick:Hide()
        return
    end
    local key = ns.Pets:KeyOfSpecies(sid)
    local status, owner, r = Status(key)
    local ownedIt = ns.Pets:Owned()[key] ~= nil
    if status == "free" then
        card.status:SetText("|cff80cc80Not reserved|r")
    elseif status == "mine" then
        local text = "|cffffd100Reserved by you|r since " .. Since(r.at)
        if r.n then text = text .. ' - "' .. r.n .. '"' end
        card.status:SetText(text)
    else
        local text = "|cffff8080Reserved by " .. owner .. "|r since " .. Since(r.at)
        if r.n then text = text .. ' - "' .. r.n .. '"' end
        card.status:SetText(text)
    end

    card.key = key
    if status == "mine" then
        card.reserve:SetText("Release")
        card.reserve:Enable()
        card.reserve:Show()
        card.nick:Show()
        if ns.Registry:CanNickname(r) then card.nick:Enable() else card.nick:Disable() end
    elseif status == "free" and ownedIt then
        card.reserve:SetText("Reserve")
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

local function BuildCard()
    local c = PetJournalPetCard
    if not c or card.status then return end
    card.status = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.status:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 12, 10)
    card.status:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -12, 10)
    card.status:SetJustifyH("LEFT")

    local anchor = PetJournalSummonButton or c
    card.reserve = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.reserve:SetSize(90, 22)
    -- Forever puts the Summon/Dismiss button at the bottom left of the
    -- journal (under the list), so our buttons go to its right, under the card.
    card.reserve:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    card.reserve:SetScript("OnClick", function()
        local status = Status(card.key)
        if status == "mine" then Report(ns.Registry:Release()) else Report(ns.Registry:Claim(card.key)) end
    end)
    card.reserve:Hide()

    card.nick = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.nick:SetSize(90, 22)
    card.nick:SetPoint("LEFT", card.reserve, "RIGHT", 4, 0)
    card.nick:SetText("Nickname")
    card.nick:SetMotionScriptsWhileDisabled(true)
    card.nick:SetScript("OnClick", function() JournalUI:AskNickname() end)
    card.nick:SetScript("OnEnter", function(self)
        local _, r = ns.Registry:MyPet()
        if r and not ns.Registry:CanNickname(r) then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(("You can name it from %s."):format(Since(ns.Registry:NicknameUnlocksAt(r))))
            GameTooltip:Show()
        end
    end)
    card.nick:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.nick:Hide()

    -- "x reserved of y known": y = every species this client has come across
    -- (see Pets:NoteKnown). Top right of the card.
    card.counter = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.counter:SetPoint("TOPRIGHT", c, "TOPRIGHT", -12, -12)

    -- Auto-summon toggle (per character, default on), bottom right of the
    -- journal. Greyed out while AutoCompanion is loaded, which takes over.
    card.auto = CreateFrame("CheckButton", nil, PetJournal, "UICheckButtonTemplate")
    card.auto:SetSize(24, 24)
    card.auto:SetPoint("BOTTOMRIGHT", PetJournal, "BOTTOMRIGHT", -96, 3)
    card.autoLabel = card.auto:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.autoLabel:SetPoint("LEFT", card.auto, "RIGHT", 2, 0)
    card.autoLabel:SetText("Auto-summon")
    card.auto:SetMotionScriptsWhileDisabled(true)
    card.auto:SetScript("OnClick", function(self)
        ns.Summon:SetEnabled(self:GetChecked() and true or false)
    end)
    card.auto:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if ns.Summon:Deferring() then
            GameTooltip:SetText("AutoCompanion is loaded and handles summoning.")
        else
            GameTooltip:SetText("Auto-summon")
            GameTooltip:AddLine("Summon your reserved companion when it's missing and you're idle.", 1, 1, 1, true)
        end
        GameTooltip:Show()
    end)
    card.auto:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

------------------------------------------------------------------------------
-- Nickname popup
------------------------------------------------------------------------------
StaticPopupDialogs["DYREPARKEN_NICKNAME"] = {
    text = "Nickname for your companion (max %d characters, empty to clear):",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    maxLetters = ns.Config.NICKNAME_MAX_LEN,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    OnShow = function(self)
        local eb = self.editBox or self.EditBox
        local _, r = ns.Registry:MyPet()
        if eb then eb:SetText(r and r.n or ""); eb:HighlightText() end
    end,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox
        Report(ns.Registry:SetNickname(eb and eb:GetText() or ""))
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        Report(ns.Registry:SetNickname(self:GetText()))
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

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
        ns.Pets:NoteOwnedKnown()
        ns.Guild:Refresh()
        JournalUI:Refresh()
    end)
    ns.Bus:On("REGISTRY", function() JournalUI:Refresh() end)
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
