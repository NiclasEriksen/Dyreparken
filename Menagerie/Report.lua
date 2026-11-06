local _, ns = ...

-- /dp report: who in the raid/party has no companion out, called out in chat.
--
-- Open question: how do we see other players' companions? Options:
--  1. Ask over addon comms (only works for addon users).
--  2. Scan nearby units: companions show up as units with a creator; there is
--     no group-wide API on modern clients that lists them. Needs research on
--     Forever (UnitCreator? nameplates? secret values?).
-- Until decided, this only asks addon users (option 1).
local Report = {}
ns.Report = Report

function Report:Init()
    ns.Comm:Register("PET_REQ", function(_, sender)
        local guid = ns.Pets:Summoned()
        ns.Comm:Send("PET", { out = guid and ns.Pets:KeyOf(guid) or false }, "WHISPER", sender, "BULK")
    end)
    ns.Comm:Register("PET", function(msg, sender)
        if Report.collecting then Report.collecting[sender] = msg.out or false end
    end)
end

function Report:Run()
    if not IsInGroup() then
        ns.Print("You're not in a group.")
        return
    end
    -- TODO: send PET_REQ, wait, compare against the group roster, and post
    -- the names to RAID/PARTY with SendChatMessage (hardware event needed?
    -- verify on Forever; slash commands count as one).
    ns.Print("Report: not implemented yet.")
end
