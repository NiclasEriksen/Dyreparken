local _, ns = ...

-- Integration with the game's companion window and tooltips.
--
-- The Collections journal is load-on-demand (Blizzard_Collections). We wait
-- for it to load before touching it, and build nothing until it's first
-- shown. Everything is hooked (hooksecurefunc / HookScript), never replaced,
-- to avoid taint.
--
-- TODO (needs /dp probe output from Forever to confirm frame names):
--  * free/reserved icon on each list button (PetJournal ScrollBox buttons)
--  * owner + nickname on hover and in the pet card
--  * "Reserve" button on the pet card
--  * companion tooltips (GameTooltip on companion units) show owner/nickname
local JournalUI = {}
ns.JournalUI = JournalUI

local function OnJournalLoaded()
    ns.Log("UI", "Blizzard_Collections loaded; PetJournal=%s", tostring(PetJournal ~= nil))
    if not PetJournal then return end
    PetJournal:HookScript("OnShow", function() JournalUI:Refresh() end)
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

function JournalUI:Refresh()
    -- TODO
end
