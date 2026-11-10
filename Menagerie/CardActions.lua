local _, ns = ...

-- The card's buttons, right of Blizzard's Summon button (which on Forever
-- sits at the journal's bottom left, under the list): Adopter / Gi slipp and
-- Kallenavn, and the popups they open. The popups' Accept is the click that
-- allows the guild chat post (Bonds:Announce).
local CardActions = {}
ns.CardActions = CardActions

-- An action's ok, message: the message is shown either way.
local function Report(_, msg)
    if msg then ns.Print(msg) end
end

function CardActions:Build(card, c)
    local anchor = PetJournalSummonButton or c
    card.reserve = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.reserve:SetSize(90, 22)
    -- Forever puts the Summon/Dismiss button at the bottom left of the
    -- journal (under the list), so our buttons go to its right, under the card.
    card.reserve:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    card.reserve:SetScript("OnClick", function()
        local status = ns.Registry:Status(card.key)
        if status == "mine" then
            Report(ns.Registry:Release())
        else
            CardActions:AskAdopt(card.key)
        end
    end)
    card.reserve:Hide()

    card.nick = CreateFrame("Button", nil, PetJournal, "UIPanelButtonTemplate")
    card.nick:SetSize(90, 22)
    card.nick:SetPoint("LEFT", card.reserve, "RIGHT", 4, 0)
    card.nick:SetText(ns.L["card.nick"])
    card.nick:SetMotionScriptsWhileDisabled(true)
    card.nick:SetScript("OnClick", function() CardActions:AskNickname() end)
    card.nick:SetScript("OnEnter", function(self)
        local key, r = ns.Registry:MyPet()
        if r and not ns.Registry:CanNickname(r) then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ns.T("card.nick.locked", { level = ns.Bond.LEVELS[ns.Config.NICKNAME_LEVEL][2],
                n = ns.Config.NICKNAME_LEVEL }), 1, 1, 1, 1, true)
            if ns.Registry:Nickname(key) then GameTooltip:AddLine(ns.L["card.nick.clearable"], 1, 0.82, 0, true) end
            GameTooltip:Show()
        end
    end)
    card.nick:SetScript("OnLeave", function() GameTooltip:Hide() end)
    card.nick:Hide()
end

-- The buttons for the pet on the card (key nil: none).
function CardActions:Update(card, key)
    local status, _, r = ns.Registry:Status(key)
    if key and status == "mine" then
        card.reserve:SetText(ns.L["card.letgo"])
        card.reserve:Enable()
        card.reserve:Show()
        card.nick:Show()
        -- (locked, it still opens to clear a name the pet came with)
        if ns.Registry:CanNickname(r) or ns.Registry:Nickname(key) then card.nick:Enable() else card.nick:Disable() end
    elseif key and status == "free" and ns.Pets:IsOwned(key) then
        card.reserve:SetText(ns.L["card.adopt"])
        card.reserve:Enable()
        card.reserve:Show()
        card.nick:Hide()
    else
        card.reserve:Hide()
        card.nick:Hide()
    end
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

function CardActions:AskAdopt(key)
    if not key then return end
    local text = ns.T("adopt.confirm", { pet = ns.Pets:NameOfKey(key) })
    local mine = ns.Registry:MyPet()
    if mine and mine ~= key then text = text .. "\n" .. ns.T("adopt.confirm.swap", { pet = ns.Registry:NameOf(mine) }) end
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
        local key, r = ns.Registry:MyPet()
        -- Below Venn, clearing is all it can do: an empty field makes that the obvious step.
        local name = key and ns.Registry:CanNickname(r) and ns.Registry:Nickname(key) or ""
        if eb then eb:SetText(name); eb:HighlightText() end
    end,
    OnAccept = function(self)
        local eb = self.editBox or self.EditBox
        CardActions:Rename(eb and eb:GetText() or "")
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        CardActions:Rename(self:GetText())
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

-- From the dialog's Accept or Enter: a click or keypress, so it may post.
function CardActions:Rename(text)
    local ok, msg = ns.Registry:SetNickname(text)
    Report(ok, msg)
    if ok then ns.Bonds:Announce("name", (ns.Registry:MyPet())) end
end

function CardActions:AskNickname()
    StaticPopup_Show("DYREPARKEN_NICKNAME", ns.Config.NICKNAME_MAX_LEN)
end
