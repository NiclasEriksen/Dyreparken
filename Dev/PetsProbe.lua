local _, ns = ...

-- The journal probes (/dp probe, /dp probe more, /dp probe ach): development
-- only, never packaged (#@do-not-package@ in the TOC). They extend ns.Pets.
local Pets = ns.Pets

local function Info(guid)
    local ok, speciesID = pcall(C_PetJournal.GetPetInfoByPetID, guid)
    if ok then return speciesID end
end

-- Development aid: print AND log what the journal API gives us on this
-- client, so the output can be read from SavedVariables after /reload.
local function Out(fmt, ...)
    local msg = fmt:format(...)
    ns.Print(msg)
    ns.Log("Probe", "%s", msg)
end

local function Has(t, k) return tostring(t ~= nil and t[k] ~= nil) end

local function Pack(...)
    local parts = {}
    for i = 1, select("#", ...) do parts[#parts + 1] = tostring((select(i, ...))) end
    return table.concat(parts, ", ")
end

-- Achievements need three things this client hasn't shown yet
-- (docs/ACHIEVEMENTS.md, build order step 1): whether an addon may post to
-- guild chat from a timer, which event says "you learned a pet", and how to
-- tell an officer. A test line can be posted (and checked that it came
-- back) to guild or group chat, either straight from the command (a keypress)
-- or 2 s later from a timer.
-- Found 2026-11-06: guild chat from a timer is blocked (ADDON_ACTION_BLOCKED).
local PROBE_TEXT = "Dyreparken: test message from /dp probe ach (please ignore)."

-- mode: nil (APIs only), "post" (guild, timer), "now" (guild, keypress),
-- "group" (party/raid, timer), "groupnow" (party/raid, keypress)
function Pets:ProbeAch(mode)
    local GI = C_GuildInfo
    Out("guild: GetGuildInfo=%s | IsGuildLeader=%s | C_GuildInfo.IsGuildOfficer=%s",
        Pack(GetGuildInfo("player")), IsGuildLeader and tostring(IsGuildLeader()) or "missing",
        GI and GI.IsGuildOfficer and tostring(GI.IsGuildOfficer()) or "missing")
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    for _, e in ipairs({ "NEW_PET_ADDED", "PET_JOURNAL_LIST_UPDATE", "COMPANION_LEARNED", "CHAT_MSG_GUILD",
        "CHAT_MSG_PARTY" }) do
        Out("event %s: %s", e, valid and tostring(valid(e)) or "C_EventUtils.IsEventValid missing")
    end
    Out("chat: SendChatMessage=%s | C_ChatInfo.SendChatMessage=%s", type(SendChatMessage),
        C_ChatInfo and type(C_ChatInfo.SendChatMessage) or "missing")
    if not mode then
        Out("Test posts: '/dp probe ach post|now' (guild chat), 'group|groupnow' (party/raid chat);"
            .. " plain = from a timer, now = straight from the command.")
        return
    end
    local group = mode == "group" or mode == "groupnow"
    local chan, event
    if group then
        if not IsInGroup() then return Out("Not in a group: nothing posted.") end
        chan = ns.GroupChannel()
        event = IsInRaid() and "CHAT_MSG_RAID" or "CHAT_MSG_PARTY"
    else
        if not IsInGuild() then return Out("Not in a guild: nothing posted.") end
        chan, event = "GUILD", "CHAT_MSG_GUILD"
    end
    local how = (mode == "now" or mode == "groupnow") and "the command" or "a timer"
    local echoed = false
    ns.Events:On(event, Pets, function(_, _, text)
        -- The text may be a secret value; comparing one can throw.
        local ok, same = pcall(function() return text == PROBE_TEXT end)
        if ok and same then echoed = true end
    end)
    local function Post()
        local send = C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
        local ok, err = pcall(send, PROBE_TEXT, chan)
        Out("%s post from %s: %s", chan, how, ok and "no error" or ("error: " .. tostring(err)))
        C_Timer.After(5, function()
            ns.Events:Off(event, Pets)
            Out("%s post from %s reached chat: %s", chan, how, tostring(echoed))
        end)
    end
    if how == "a timer" then C_Timer.After(2, Post) else Post() end
end

function Pets:Probe()
    local PJ = C_PetJournal
    Out("build: %s", Pack(GetBuildInfo()))
    -- (open questions in CLAUDE.md: does it exist, and what does it say standing?)
    Out("UnitStandState: %s", type(UnitStandState) == "function" and tostring(UnitStandState("player")) or "missing")
    Out("project: WOW_PROJECT_ID=%s CAMELOT=%s", tostring(WOW_PROJECT_ID), tostring(WOW_PROJECT_CAMELOT))
    -- Identity: Forever has surnames and odd realm strings; we need to know
    -- which API matches the sender name in CHAT_MSG_ADDON.
    Out("identity: UnitName=%s | UnitFullName=%s | GetRealmName=%s | GetNormalizedRealmName=%s | PlayerKey=%s",
        Pack(UnitName("player")), Pack(UnitFullName("player")), tostring(GetRealmName()),
        tostring(GetNormalizedRealmName()), tostring(ns.PlayerKey()))
    Out("identity: GUID=%s | GetGuildInfo=%s | GetPlayerInfoByGUID=%s",
        tostring(UnitGUID("player")), Pack(GetGuildInfo("player")),
        GetPlayerInfoByGUID and Pack(GetPlayerInfoByGUID(UnitGUID("player"))) or "nil")
    local list = GetAutoCompleteRealms and GetAutoCompleteRealms()
    Out("connected realms: %s", type(list) == "table" and table.concat(list, ", ") or tostring(list))
    local fns = { "GetOwnedPetIDs", "GetPetInfoByPetID", "GetPetInfoBySpeciesID", "GetPetInfoByIndex",
        "GetNumPets", "GetSummonedPetGUID", "SummonPetByGUID", "SetCustomName", "PetIsSummonable",
        "GetPetSummonInfo", "FindPetIDByName", "GetNumCollectedInfo", "PetIsFavorite" }
    local have = {}
    for _, f in ipairs(fns) do have[#have + 1] = f .. "=" .. Has(PJ, f) end
    Out("C_PetJournal: %s", table.concat(have, " "))
    Out("frames: CollectionsJournal=%s PetJournal=%s Blizzard_Collections=%s",
        tostring(CollectionsJournal ~= nil), tostring(PetJournal ~= nil),
        tostring(C_AddOns.IsAddOnLoaded("Blizzard_Collections")))
    if PetJournal then
        Out("PetJournal children: ScrollBox=%s PetCard=%s SummonButton=%s",
            Has(PetJournal, "ScrollBox"), tostring(PetJournalPetCard ~= nil), tostring(PetJournalSummonButton ~= nil))
    end
    Out("GetNumPets: %s", Pack(PJ.GetNumPets()))
    local guid = self:Summoned()
    if not guid then
        Out("No companion summoned; summon one and probe again for its info.")
        return
    end
    Out("summoned %s: %s", tostring(guid), Pack(pcall(PJ.GetPetInfoByPetID, guid)))
    local speciesID = Info(guid)
    if PJ.GetPetInfoBySpeciesID and speciesID then
        Out("bySpecies %s: %s", tostring(speciesID), Pack(pcall(PJ.GetPetInfoBySpeciesID, speciesID)))
    end
    if PJ.GetNumCollectedInfo and speciesID then
        Out("collected %s: %s", tostring(speciesID), Pack(pcall(PJ.GetNumCollectedInfo, speciesID)))
    end
    if PJ.PetIsSummonable then Out("summonable: %s", Pack(pcall(PJ.PetIsSummonable, guid))) end
end

-- Journal hooks, roster format, and the target (target someone's companion
-- first). Separate from Probe so it can run without a pet out.
function Pets:ProbeMore()
    Out("hooks: PetJournal_InitPetButton=%s PetJournal_UpdatePetCard=%s ScrollUtil=%s TooltipDataProcessor=%s",
        tostring(PetJournal_InitPetButton ~= nil), tostring(PetJournal_UpdatePetCard ~= nil),
        tostring(ScrollUtil ~= nil and ScrollUtil.AddInitializedFrameCallback ~= nil),
        tostring(TooltipDataProcessor ~= nil))
    if PetJournal and PetJournal.ScrollBox and PetJournal.ScrollBox.ForEachFrame then
        local n = 0
        PetJournal.ScrollBox:ForEachFrame(function(b)
            n = n + 1
            if n <= 2 then
                Out("list button %d: petID=%s speciesID=%s owned=%s index=%s", n, tostring(b.petID),
                    tostring(b.speciesID), tostring(b.owned), tostring(b.index))
            end
        end)
        Out("list buttons visible: %d", n)
    end
    local total, online = GetNumGuildMembers()
    Out("roster: %s total, %s online", tostring(total), tostring(online))
    -- Offline members are what matters for inactivity: log a few of those.
    local shown = 0
    for i = 1, total or 0 do
        local name, _, _, _, _, _, _, _, online = GetGuildRosterInfo(i)
        if not online and shown < 4 then
            shown = shown + 1
            Out("roster offline %d: name=%q lastOnline=%s", i, tostring(name), Pack(GetGuildRosterLastOnline(i)))
        end
    end
    if UnitExists("target") then
        Out("target: name=%s guid=%s speciesID=%s companion=%s creator=%s",
            Pack(UnitName("target")), tostring(UnitGUID("target")),
            tostring(UnitBattlePetSpeciesID and UnitBattlePetSpeciesID("target")),
            tostring(UnitIsBattlePetCompanion and UnitIsBattlePetCompanion("target")),
            tostring(UnitCreator and UnitCreator("target")))
        -- Does the unit's species ID match the journal's? (Kitten = 46 from the
        -- unit; our Panda Cub = 5159 from the journal: same numbering?)
        local usid = UnitBattlePetSpeciesID and UnitBattlePetSpeciesID("target")
        if usid then
            Out("target species %s in journal: %s | owner from tooltip: %s", tostring(usid),
                Pack(pcall(C_PetJournal.GetPetInfoBySpeciesID, usid)), tostring(ns.Tooltip:OwnerOf("target")))
        end
        local summoned = self:Summoned()
        if summoned then
            Out("your summoned pet: journal speciesID=%s", tostring((C_PetJournal.GetPetInfoByPetID(summoned))))
        end
        local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit("target")
        if data and data.lines then
            for i, line in ipairs(data.lines) do Out("target tooltip %d: %s", i, tostring(line.leftText)) end
        end
    else
        Out("No target: target a companion (yours or another player's) and run /dp probe more.")
    end
end
