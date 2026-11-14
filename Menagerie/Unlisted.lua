local _, ns = ...

-- Companions we don't know (2026-11-14, the user: "notify the user when they spot/learn a companion that's not
-- in our list, so they can tell me so we can add it"): a species not in Data/Companions.lua, seen under the
-- mouse (Tooltip's COMPANION_SEEN), learned (NEW_PET_ADDED), or already owned at login. One chat line per
-- species per account, ever (DyreparkenDB.unlisted), with its name and species id and who to tell
-- (Config.REPORT_TO). Forever adds pets the journal hides (Azurky, 2026-11-09), so a few will turn up.
local Unlisted = {}
ns.Unlisted = Unlisted

function Unlisted.Known(sid)
    local list = ns.Companions and ns.Companions.species
    return list ~= nil and list[sid] ~= nil
end

-- Tell once: how = "seen" (owner: whose it was) or "learned".
function Unlisted:Notice(sid, how, owner)
    if type(sid) ~= "number" or sid <= 0 or self.Known(sid) then return end
    local told = ns.DB.global.unlisted
    if told[sid] then return end
    local name = ns.Plain((C_PetJournal.GetPetInfoBySpeciesID(sid)))
    told[sid] = { t = ns.Now(), how = how, name = type(name) == "string" and name or nil, owner = owner }
    ns.Log("Unlisted", "species %d (%s) %s%s", sid, tostring(name), how, owner and (" from " .. owner) or "")
    ns.Print(ns.T("unlisted." .. how, { name = type(name) == "string" and name ~= "" and name or ns.L["unlisted.noname"],
        id = sid, who = ns.Config.REPORT_TO }))
end

-- Everything you own: pets learned before this addon knew to ask.
function Unlisted:CheckOwned()
    for key in pairs(ns.Pets:Owned()) do
        self:Notice(ns.Pets:SpeciesOfKey(key), "learned")
    end
end

ns.Start("login", function()
    ns.Bus:On("COMPANION_SEEN", function(sid, owner)
        -- (your own pet under the mouse: you have it, so it's "learned")
        if owner == ns.PlayerKey() then return Unlisted:Notice(sid, "learned") end
        Unlisted:Notice(sid, "seen", owner)
    end)
    ns.Events:On("NEW_PET_ADDED", Unlisted, function(_, _, guid)
        guid = ns.Plain(guid)
        if type(guid) ~= "string" then return end
        local ok, sid = pcall(C_PetJournal.GetPetInfoByPetID, guid)
        if ok then Unlisted:Notice(ns.Plain(sid), "learned") end
    end)
end)
ns.Start("settled", function() Unlisted:CheckOwned() end)
