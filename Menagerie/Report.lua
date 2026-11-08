local _, ns = ...

-- /dp report: who in the raid/party has no companion out.
--
-- Decided 2026-11-06: only addon users are checked. There's no API to see
-- another player's companion (only by hovering or targeting it), so players
-- without the addon are listed locally as "unknown" and not called out.
--
-- Flow: PET_REQ to RAID/PARTY -> every addon user answers PET { out } on
-- the same channel -> after WAIT seconds we compare with the group roster
-- and post the names without a companion to group chat.
--
-- Answers go to the group channel, not by whisper: whisper targets with
-- surnames ("First Surname") are unverified on Forever, and a group is small.
local Report = {}
ns.Report = Report

local WAIT = 3

local function GroupChannel()
    if IsInRaid() then return "RAID" end
    if IsInGroup() then return "PARTY" end
end

-- "First Surname" for a group unit (UnitName's second value is the surname).
local function UnitKey(unit)
    local first, surname = UnitName(unit)
    if not first then return nil end
    if surname and surname ~= "" then return ns.NormalizeName(first .. " " .. surname) end
    return first
end

local function GroupMembers()
    local list = {}
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local key = UnitKey("raid" .. i)
            if key then list[#list + 1] = key end
        end
    else
        list[1] = ns.PlayerKey()
        for i = 1, GetNumSubgroupMembers() do
            local key = UnitKey("party" .. i)
            if key then list[#list + 1] = key end
        end
    end
    return list
end

local function HasCompanion()
    return ns.Pets:Summoned() ~= nil
end

function Report:Init()
    ns.Comm:Register("PET_REQ", function(_, _, channel)
        if channel ~= "RAID" and channel ~= "PARTY" then return end
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

function Report:Run()
    local channel = GroupChannel()
    if not channel then return ns.Print("Du er ikke i en gruppe.") end
    if self.collecting then return ns.Print("En rapport kjører allerede.") end
    self.collecting = { [ns.PlayerKey()] = HasCompanion() }
    ns.Comm:Send("PET_REQ", {}, channel)
    ns.Print("Sjekker kjæledyr ...")
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
        if #missing > 0 then
            SendChatMessage("Dyreparken: uten kjæledyr ute: " .. Join(missing) .. "!", channel)
        else
            ns.Print(("Alle med addonen har kjæledyret sitt ute (%d)."):format(ok))
        end
        if #unknown > 0 then ns.Print("Ukjent (uten addon): " .. Join(unknown)) end
        ns.Log("Report", "ok=%d missing=%d unknown=%d", ok, #missing, #unknown)
    end)
end
