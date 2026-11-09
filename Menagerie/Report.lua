local _, ns = ...

-- /dp report: who in the raid/party has no companion out.
--
-- Decided 2026-11-06: only addon users are checked. There's no API to see
-- another player's companion (only by hovering or targeting it), so players
-- without the addon are listed locally as "unknown" and not called out.
--
-- Flow: PET_REQ to RAID/PARTY -> every addon user answers PET { out } on
-- the same channel -> after WAIT seconds we compare with the group roster.
-- The result (who forgot their companion, by its nickname, or praise when
-- everyone has one out) is shown in a dialog, and its button posts it to
-- group chat. Posting needs a click: guild chat from a timer is blocked on
-- Forever, and group chat from a timer is unprobed (docs/FOREVER_API.md).
-- It also lets the player see a call-out before it goes out.
--
-- Answers go to the group channel, not by whisper: whisper targets with
-- surnames ("First Surname") are unverified on Forever, and a group is small.
local Report = {}
ns.Report = Report

local WAIT = 3
local MAX_CHAT = 255

local function GroupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end


local function GroupMembers()
    local list = ns.GroupKeys()
    if #list == 0 then list[1] = ns.PlayerKey() end
    return list
end

local function HasCompanion()
    return ns.Pets:Summoned() ~= nil
end

function Report:Init()
    ns.Comm:Register("PET_REQ", function(_, _, channel)
        if channel ~= "RAID" and channel ~= "PARTY" then return end
        if not ns.Comm:MayReply("PET", channel) then return end
        ns.Comm:Send("PET", { out = HasCompanion() }, channel, nil, "BULK")
    end)
    ns.Comm:Register("PET", function(msg, sender)
        if Report.collecting then Report.collecting[sender] = msg.out and true or false end
    end)
end

local function Join(list)
    table.sort(list)
    return table.concat(list, ", ")
end

-- What a member's companion is called, if they have adopted one.
local function PetOf(name)
    for key, owner in pairs(ns.Registry:Holders()) do
        if owner == name then return ns.Registry:Nickname(key) or ns.Pets:NameOfKey(key) end
    end
end

-- The line for group chat, or nil when there's nothing to say.
function Report:Message(missing, ok, unknown)
    if #missing == 1 then
        local pet = PetOf(missing[1])
        return ns.T(pet and "report.one_pet" or "report.one", { player = missing[1], pet = pet })
    end
    if #missing > 1 then
        table.sort(missing)
        local head = ns.L["report.many"]
        local text, shown = head, 0
        for i, name in ipairs(missing) do
            local pet = PetOf(name)
            local item = (i > 1 and ", " or "") .. (pet and ns.T("report.many_item_pet", { player = name, pet = pet }) or name)
            local rest = #missing - i
            -- Leave room for the " og N til!" tail if more would follow.
            if #text + #item + (rest > 0 and 14 or 1) > MAX_CHAT then break end
            text, shown = text .. item, i
        end
        if shown < #missing then return text .. ns.T("report.many_more", { n = #missing - shown }) end
        return text .. "!"
    end
    if ok < 2 then return nil end
    return ns.T(unknown == 0 and "report.all" or "report.all_users", { n = ok })
end

StaticPopupDialogs["DYREPARKEN_REPORT"] = {
    text = "%s",
    button1 = ns.L["report.button"],
    button2 = CANCEL,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    -- The button click is the hardware event that allows posting.
    OnAccept = function() Report:Post() end,
}

function Report:Post()
    local p = self.pending
    self.pending = nil
    local channel = GroupChannel()
    if p and channel then SendChatMessage(p, channel) end
end

function Report:Run()
    local channel = GroupChannel()
    if not channel then return ns.Print(ns.L["report.no_group"]) end
    if self.collecting then return ns.Print(ns.L["report.running"]) end
    self.collecting = { [ns.PlayerKey()] = HasCompanion() }
    ns.Comm:Send("PET_REQ", {}, channel)
    ns.Print(ns.L["report.checking"])
    C_Timer.After(WAIT, function()
        local answers = self.collecting
        self.collecting = nil
        local missing, unknown, ok = {}, {}, 0
        for _, name in ipairs(GroupMembers()) do
            local out = answers[name]
            if out == nil then
                unknown[#unknown + 1] = name
            elseif out then
                ok = ok + 1
            else
                missing[#missing + 1] = name
            end
        end
        if #missing == 0 then ns.Print(ns.T("report.all_local", { n = ok })) end
        if #unknown > 0 then ns.Print(ns.T("report.unknown", { list = Join(unknown) })) end
        local text = self:Message(missing, ok, #unknown)
        if text then
            self.pending = text
            StaticPopup_Show("DYREPARKEN_REPORT", text)
        end
        ns.Log("Report", "ok=%d missing=%d unknown=%d", ok, #missing, #unknown)
    end)
end
