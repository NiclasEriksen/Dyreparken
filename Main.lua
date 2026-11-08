local addonName, ns = ...

-- Bootstrap. SavedVariables exist from ADDON_LOADED on; the guild and group
-- are only reliable from PLAYER_LOGIN / PLAYER_ENTERING_WORLD.
local Main = {}

ns.Events:On("ADDON_LOADED", Main, function(_, _, name)
    if name ~= addonName then return end
    ns.Debug:Init()
    ns.DB:Init()
    ns.Comm:Init()
    ns.Version:Init()
    ns.Sync:Init()
    ns.Report:Init()
    ns.JournalUI:Init()
    ns.Tooltip:Init()
    ns.Activity:Init()
    ns.Achievements:Init()
    ns.Games:Init()
    ns.Log("Main", "loaded %s (protocol %d)", ns.VERSION, ns.PROTOCOL)
end)

ns.Events:On("PLAYER_LOGIN", Main, function()
    ns.Events:Off("PLAYER_LOGIN", Main)
    ns.Summon:Init()
    ns.Bonds:Init()
    ns.Bond:Init()
    -- Let the login burst settle before talking to the guild.
    C_Timer.After(10, function()
        -- Roster first: an answer arrives before peers' SYNCs need it.
        ns.Guild:Refresh(true)
        ns.Registry:CheckMine()
        ns.Version:Hello()
        ns.Summon:AnnounceDeferral()
        ns.Achievements:Check("login")
    end)
end)
