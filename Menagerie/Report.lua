local _, ns = ...

-- The answering half of the old /dp rapport (who in the group has no
-- companion out). The command was removed on 2026-11-09, when the addon
-- spread beyond the guild: calling people out isn't for everyone. Clients
-- still on 0.2.x can run it, so we keep answering them: PET_REQ on the
-- group channel -> PET { out } on the same channel, at most once per
-- MayReply window.
local Report = {}
ns.Report = Report

function Report:Init()
    ns.Comm:Register("PET_REQ", function(_, _, channel)
        if not ns.Comm:MayReply("PET", channel) then return end
        ns.Comm:Send("PET", { out = ns.Pets:OutKey() ~= nil }, channel)
    end, "GROUP")
end

ns.Start("loaded", function() Report:Init() end)
