local addonName, ns = ...

-- Bootstrap: runs the start-up phases (ns.Start in each module, Core/Init.lua).
-- SavedVariables exist from ADDON_LOADED on; the guild and group are only
-- reliable from PLAYER_LOGIN / PLAYER_ENTERING_WORLD.
local Main = {}

ns.Events:On("ADDON_LOADED", Main, function(_, _, name)
    if name ~= addonName then return end
    ns.RunPhase("loaded")
    ns.Log("Main", "loaded %s (protocol %d)", ns.VERSION, ns.PROTOCOL)
end)

ns.Events:On("PLAYER_LOGIN", Main, function()
    ns.Events:Off("PLAYER_LOGIN", Main)
    ns.RunPhase("login")
    -- Let the login burst settle before talking to the guild.
    C_Timer.After(10, function()
        ns.RunPhase("settled")
        ns.RunPhase("hello")
    end)
end)
