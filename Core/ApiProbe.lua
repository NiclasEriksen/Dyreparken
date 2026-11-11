local _, ns = ...

-- /dp probe api (development, 2026-11-11): what this client really has, instead of
-- guessing. The user: "we're going to run a bunch of probes determining what
-- capabilities we have in this client". Read-only: nothing is set, sent, posted,
-- summoned or filtered (never the journal's setters); the frames made for it are
-- scratch ones, hidden or invisible. Results go to DyreparkenDebugDB.api (not the
-- log's ring, which they'd flood), written to disk on /reload:
--   globals     every global function's name; and the other global tables
--   namespaces  every C_* table and what's in it (functions by name, other values by type)
--   enum        every Enum table and its values
--   events      which events a frame may register (unknown ones are refused)
--   widgets     which frame types CreateFrame makes, their methods and script handlers
--   templates   which XML templates exist
--   strings     the global strings our chat parsing and wording rely on
--   values      what a long list of getters return right now (player, place, forms,
--               pets, guild, target and mouseover: target a companion first)
--   card        the pet card's model scene and actor: their methods, handlers and state
--   calendar    today's calendar events (holidays), once the calendar has loaded
--   model       a model of the card's pet in an invisible PlayerModel: which animations it
--               has (HasAnimation), and how long the card's ones play (OnAnimFinished)
-- `/dp probe api` runs them all (open a pet's card first for card and model);
-- `/dp probe api <section>` one; `/dp probe api clear` forgets them.
local Api = {}
ns.ApiProbe = Api

local function G(path)
    local v = _G
    for part in path:gmatch("[^%.]+") do
        if type(v) ~= "table" then return nil end
        v = rawget(v, part)
    end
    return v
end

-- A value as text for the saved file (secret values can't be read: marked so).
local function Show(v)
    if ns.IsSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return ("%q"):format(v) end
    if t == "table" then
        local parts, n = {}, 0
        for k, x in pairs(v) do
            n = n + 1
            if n > 12 then parts[#parts + 1] = "..."; break end
            parts[#parts + 1] = tostring(k) .. "=" .. (type(x) == "table" and "{...}" or Show(x))
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    return tostring(v)
end

local function Pack(...) return { n = select("#", ...), ... } end

-- Calls fn and returns what it gave as text, or why it failed.
local function Try(fn, ...)
    local r = Pack(pcall(fn, ...))
    if not r[1] then return "error: " .. tostring(r[2]) end
    local out = {}
    for i = 2, r.n do out[#out + 1] = Show(r[i]) end
    return #out > 0 and table.concat(out, ", ") or "(nothing)"
end

local function Sorted(t)
    local list = {}
    for k in pairs(t) do list[#list + 1] = tostring(k) end
    table.sort(list)
    return list
end

-- An object's methods: its metatable's __index table (widgets), else its own functions.
local function Methods(obj)
    local found = {}
    local mt = getmetatable(obj)
    local index = type(mt) == "table" and rawget(mt, "__index")
    if type(index) == "table" then
        for k, v in pairs(index) do if type(v) == "function" then found[k] = true end end
    end
    if type(obj) == "table" then
        for k, v in pairs(obj) do if type(v) == "function" then found[k] = true end end
    end
    return Sorted(found)
end

Api.HANDLERS = { "OnShow", "OnHide", "OnUpdate", "OnEvent", "OnClick", "OnEnter", "OnLeave", "OnMouseDown",
    "OnMouseUp", "OnMouseWheel", "OnSizeChanged", "OnDragStart", "OnValueChanged", "OnTextChanged",
    "OnModelLoaded", "OnModelLoading", "OnAnimFinished", "OnAnimStarted", "OnUpdateModel", "OnModelCleared",
    "OnDressModel", "OnFinished", "OnLoop", "OnPlay", "OnStop", "OnTooltipSetUnit", "OnTooltipCleared",
    "OnHyperlinkClick", "OnHyperlinkEnter" }

local function Scripts(obj)
    local has = {}
    if type(obj) ~= "table" and type(obj) ~= "userdata" then return has end
    local ok, fn = pcall(function() return obj.HasScript end)
    if not (ok and type(fn) == "function") then return { "(no HasScript)" } end
    for _, h in ipairs(Api.HANDLERS) do
        local okH, yes = pcall(fn, obj, h)
        if okH and yes then has[#has + 1] = h end
    end
    return has
end

local function Describe(obj)
    if obj == nil then return { missing = true } end
    local okT, kind = pcall(function() return obj.GetObjectType and obj:GetObjectType() end)
    return { type = okT and kind or nil, methods = Methods(obj), scripts = Scripts(obj) }
end

------------------------------------------------------------------------------
-- The sections
------------------------------------------------------------------------------
local S = {}
Api.SECTIONS = S

function S.globals(out)
    local fns, tables = {}, {}
    for k, v in pairs(_G) do
        if type(k) == "string" then
            if type(v) == "function" then fns[#fns + 1] = k
            elseif type(v) == "table" and not k:find("^C_") and not k:find("^Enum$") then tables[#tables + 1] = k end
        end
    end
    table.sort(fns); table.sort(tables)
    out.functions, out.tables = fns, tables
    return ("%d functions, %d tables"):format(#fns, #tables)
end

function S.namespaces(out)
    local n = 0
    for k, v in pairs(_G) do
        if type(k) == "string" and k:find("^C_") and type(v) == "table" then
            local members = {}
            for name, x in pairs(v) do
                members[#members + 1] = type(x) == "function" and tostring(name) or (tostring(name) .. " (" .. type(x) .. ")")
            end
            table.sort(members)
            out[k] = members
            n = n + 1
        end
    end
    return ("%d namespaces"):format(n)
end

function S.enum(out)
    local E, n = G("Enum"), 0
    if type(E) ~= "table" then return "no Enum" end
    for name, t in pairs(E) do
        if type(t) == "table" then
            local vals = {}
            for k, v in pairs(t) do vals[#vals + 1] = tostring(k) .. "=" .. Show(v) end
            table.sort(vals)
            out[tostring(name)] = table.concat(vals, " ")
            n = n + 1
        end
    end
    return ("%d enums"):format(n)
end

-- Events our features use, or might: every one we register now, and candidates.
Api.EVENTS = [[
ADDON_LOADED PLAYER_LOGIN PLAYER_LOGOUT PLAYER_ENTERING_WORLD PLAYER_LEAVING_WORLD PLAYER_REGEN_ENABLED
PLAYER_REGEN_DISABLED PLAYER_MOUNT_DISPLAY_CHANGED CHAT_MSG_ADDON GUILD_ROSTER_UPDATE PLAYER_GUILD_UPDATE
GROUP_ROSTER_UPDATE COMPANION_UPDATE BAG_UPDATE_DELAYED UNIT_AURA ZONE_CHANGED_NEW_AREA ZONE_CHANGED
ZONE_CHANGED_INDOORS PLAYER_TARGET_CHANGED UPDATE_MOUSEOVER_UNIT CHAT_MSG_GUILD CHAT_MSG_PARTY CHAT_MSG_RAID
NEW_PET_ADDED PET_JOURNAL_LIST_UPDATE PET_JOURNAL_PET_DELETED ENCOUNTER_START ENCOUNTER_END BOSS_KILL
PLAYER_PVP_KILLS_CHANGED QUEST_TURNED_IN QUEST_ACCEPTED QUEST_LOG_UPDATE UNIT_SPELLCAST_SUCCEEDED
UNIT_SPELLCAST_START UNIT_SPELLCAST_CHANNEL_START PLAYER_DEAD PLAYER_ALIVE PLAYER_UNGHOST MIRROR_TIMER_START
PLAYER_LEVEL_UP PLAYER_XP_UPDATE PLAYER_FLAGS_CHANGED CHAT_MSG_TEXT_EMOTE CHAT_MSG_EMOTE CHAT_MSG_SKILL
CHAT_MSG_COMBAT_FACTION_CHANGE CHAT_MSG_COMBAT_XP_GAIN CHAT_MSG_SYSTEM CHAT_MSG_LOOT CHAT_MSG_MONEY
CHAT_MSG_MONSTER_EMOTE CHAT_MSG_MONSTER_SAY CHAT_MSG_WHISPER CHAT_MSG_CHANNEL CHAT_MSG_ACHIEVEMENT
CHAT_MSG_GUILD_ACHIEVEMENT CHAT_MSG_PET_INFO NAME_PLATE_UNIT_ADDED NAME_PLATE_UNIT_REMOVED
FORBIDDEN_NAME_PLATE_UNIT_ADDED PLAYER_STARTED_MOVING PLAYER_STOPPED_MOVING PLAYER_CONTROL_GAINED
PLAYER_CONTROL_LOST UI_ERROR_MESSAGE UI_INFO_MESSAGE LOOT_OPENED LOOT_CLOSED LOOT_READY START_LOOT_ROLL
LOOT_ROLLS_COMPLETE UPDATE_SHAPESHIFT_FORM UPDATE_SHAPESHIFT_FORMS UNIT_PET UNIT_FLAGS UNIT_MODEL_CHANGED
ACHIEVEMENT_EARNED CRITERIA_UPDATE CRITERIA_EARNED SKILL_LINES_CHANGED TRADE_SKILL_SHOW LEARNED_SPELL_IN_TAB
HEARTHSTONE_BOUND PLAYER_UPDATE_RESTING PLAYER_CAMPING TIME_PLAYED_MSG CALENDAR_UPDATE_EVENT_LIST
CALENDAR_UPDATE_EVENT NEW_MOUNT_ADDED NEW_TOY_ADDED TOYS_UPDATED MERCHANT_SHOW MAIL_SHOW BANKFRAME_OPENED
AUCTION_HOUSE_SHOW GOSSIP_SHOW TAXIMAP_OPENED BARBER_SHOP_OPEN DUEL_REQUESTED DUEL_FINISHED
UPDATE_BATTLEFIELD_STATUS PLAYER_INTERACTION_MANAGER_FRAME_SHOW UNIT_ENTERED_VEHICLE UNIT_EXITED_VEHICLE
PET_BATTLE_OPENING_START PET_BATTLE_CLOSE LFG_COMPLETION_REWARD ENCOUNTER_LOOT_RECEIVED SPELLS_CHANGED
PLAYER_EQUIPMENT_CHANGED UNIT_INVENTORY_CHANGED FRIENDLIST_UPDATE CLUB_MESSAGE_ADDED GUILD_MOTD
CHAT_MSG_BN_WHISPER PLAYER_SPECIALIZATION_CHANGED ACTIVE_TALENT_GROUP_CHANGED MODIFIER_STATE_CHANGED
CINEMATIC_START CINEMATIC_STOP PLAY_MOVIE SCREENSHOT_SUCCEEDED UPDATE_FACTION COMBAT_TEXT_UPDATE
CVAR_UPDATE DISPLAY_SIZE_CHANGED UI_SCALE_CHANGED SOUNDKIT_FINISHED]]

function S.events(out)
    local f = CreateFrame("Frame")
    local yes, no = {}, {}
    for e in Api.EVENTS:gmatch("%S+") do
        local ok = pcall(f.RegisterEvent, f, e)
        if ok then yes[#yes + 1] = e else no[#no + 1] = e end
    end
    f:UnregisterAllEvents()
    out.known, out.unknown = yes, no
    return ("%d known, %d unknown: %s"):format(#yes, #no, table.concat(no, " "))
end

Api.WIDGETS = { "Frame", "Button", "CheckButton", "EditBox", "Slider", "StatusBar", "ScrollFrame", "Cooldown",
    "Model", "PlayerModel", "DressUpModel", "CinematicModel", "TabardModel", "ModelScene", "SimpleHTML",
    "MessageFrame", "ScrollingMessageFrame", "ColorSelect", "MovieFrame", "Browser", "GameTooltip",
    "OffScreenFrame", "UnitPositionFrame", "FogOfWarFrame", "QuestPOIFrame" }

local function Scratch()
    if not Api.scratch then
        Api.scratch = CreateFrame("Frame", nil, UIParent)
        Api.scratch:Hide()
    end
    return Api.scratch
end

function S.widgets(out)
    local made, failed = 0, {}
    for _, kind in ipairs(Api.WIDGETS) do
        local ok, f = pcall(CreateFrame, kind, nil, Scratch())
        if ok and f then
            out[kind] = Describe(f)
            -- Its regions and animations too, once (from the plain frame).
            if kind == "Frame" then
                local function Region(name, make)
                    local okR, r = pcall(make)
                    out[name] = okR and Describe(r) or { error = tostring(r) }
                end
                Region("Texture", function() return f:CreateTexture() end)
                Region("FontString", function() return f:CreateFontString() end)
                Region("AnimationGroup", function() return f:CreateAnimationGroup() end)
                Region("Animation", function() return f:CreateAnimationGroup():CreateAnimation("Alpha") end)
            end
            made = made + 1
        else
            failed[#failed + 1] = kind
            out[kind] = { error = tostring(f) }
        end
    end
    return ("%d made; not: %s"):format(made, table.concat(failed, " "))
end

-- { template, frame type }
Api.TEMPLATES = {
    { "ButtonFrameTemplate", "Frame" }, { "PortraitFrameTemplate", "Frame" }, { "BasicFrameTemplate", "Frame" },
    { "BasicFrameTemplateWithInset", "Frame" }, { "InsetFrameTemplate", "Frame" }, { "BackdropTemplate", "Frame" },
    { "TooltipBackdropTemplate", "Frame" }, { "DialogBorderTemplate", "Frame" }, { "ThinGoldEdgeTemplate", "Frame" },
    { "GlowBoxTemplate", "Frame" }, { "NineSlicePanelTemplate", "Frame" }, { "TabSystemTemplate", "Frame" },
    { "UIPanelButtonTemplate", "Button" }, { "UIPanelCloseButton", "Button" }, { "UIPanelCloseButtonNoScripts", "Button" },
    { "PanelTabButtonTemplate", "Button" }, { "CharacterFrameTabButtonTemplate", "Button" },
    { "SecureActionButtonTemplate", "Button" }, { "ActionButtonTemplate", "CheckButton" },
    { "ItemButtonTemplate", "Button" }, { "UICheckButtonTemplate", "CheckButton" },
    { "InterfaceOptionsCheckButtonTemplate", "CheckButton" }, { "SettingsCheckboxTemplate", "CheckButton" },
    { "OptionsSliderTemplate", "Slider" }, { "MinimalSliderWithSteppersTemplate", "Frame" },
    { "InputBoxTemplate", "EditBox" }, { "SearchBoxTemplate", "EditBox" },
    { "UIDropDownMenuTemplate", "Frame" }, { "WowStyle1DropdownTemplate", "DropdownButton" },
    { "UIPanelScrollFrameTemplate", "ScrollFrame" }, { "ScrollFrameTemplate", "ScrollFrame" },
    { "WowScrollBoxList", "Frame" }, { "MinimalScrollBar", "EventFrame" },
    { "GameTooltipTemplate", "GameTooltip" }, { "SharedTooltipTemplate", "GameTooltip" },
    { "ModelSceneMixinTemplate", "ModelScene" }, { "NonInteractableModelSceneMixinTemplate", "ModelScene" },
    { "PanningModelSceneMixinTemplate", "ModelScene" }, { "ModelWithControlsTemplate", "PlayerModel" },
}

function S.templates(out)
    local yes, no = {}, {}
    for _, t in ipairs(Api.TEMPLATES) do
        local ok, err = pcall(CreateFrame, t[2], nil, Scratch(), t[1])
        if ok then yes[#yes + 1] = t[1] else no[#no + 1] = t[1]; out[t[1]] = tostring(err) end
    end
    out.exist, out.missing = yes, no
    return ("%d exist; missing: %s"):format(#yes, table.concat(no, " "))
end

Api.STRINGS = { "ERR_FISH_ESCAPED", "ERR_FISH_NOT_HOOKED", "RANDOM_ROLL_RESULT", "LOOT_ROLL_ROLLED_NEED",
    "LOOT_ROLL_ROLLED_GREED", "LOOT_ROLL_ROLLED_DE", "LOOT_ROLL_NEED_SELF", "LOOT_ROLL_GREED_SELF",
    "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "ERR_SKILL_UP_SI", "SKILL_RANK_UP", "FACTION_STANDING_INCREASED",
    "FACTION_STANDING_INCREASED_GENERIC", "FACTION_STANDING_CHANGED", "ACHIEVEMENT_BROADCAST",
    "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP", "ERR_NEWTAXIPATH", "ERR_LEARN_RECIPE_S", "ERR_LEARN_SPELL_S",
    "ERR_LEARN_ABILITY_S", "ERR_DEATHBIND_SUCCESS_S", "ERR_PLAYER_DIED_S", "DUEL_WINNER_KNOCKOUT",
    "DUEL_WINNER_RETREAT", "TIME_PLAYED_MSG", "COMBATLOG_XPGAIN_FIRSTPERSON", "COMBATLOG_HONORGAIN",
    "ERR_FRIEND_ONLINE_SS", "ERR_FRIEND_OFFLINE_S", "ERR_GUILD_JOIN_S", "ERR_GUILD_LEAVE_S",
    "ERR_GUILD_REMOVE_SS", "ERR_QUEST_REWARD_EXP_I", "QUEST_COMPLETE", "PLAYER_LEVEL_UP",
    "UNIT_YOU", "YOU", "TUTORIAL_TITLE19", "BATTLE_PET_SOURCE_1", "PET_JOURNAL", "COMPANIONS", "PETS",
    "ERR_SPELL_FAILED_ANOTHER_IN_PROGRESS", "SPELL_FAILED_NOT_MOUNTED", "ERR_NOT_WHILE_MOUNTED" }

function S.strings(out)
    local missing = {}
    for _, k in ipairs(Api.STRINGS) do
        local v = G(k)
        if v == nil then missing[#missing + 1] = k else out[k] = Show(v) end
    end
    out.missing = missing
    return ("%d of %d; missing: %s"):format(#Api.STRINGS - #missing, #Api.STRINGS, table.concat(missing, " "))
end

-- { label, path to the function, args... }; called as they are, read-only getters only.
Api.VALUES = {
    { "GetBuildInfo" }, { "GetLocale" }, { "GetCurrentRegion" }, { "GetServerTime" }, { "GetGameTime" },
    { "time" }, { "date", "*t" }, { "C_DateAndTime.GetCurrentCalendarTime" }, { "GetCVar", "portal" },
    { "UnitName", "player" }, { "UnitFullName", "player" }, { "UnitPVPName", "player" }, { "UnitRace", "player" },
    { "UnitClass", "player" }, { "UnitLevel", "player" }, { "UnitSex", "player" }, { "UnitGUID", "player" },
    { "GetRealmName" }, { "GetNormalizedRealmName" }, { "UnitFactionGroup", "player" }, { "GetMoney" },
    { "UnitStandState", "player" }, { "GetShapeshiftFormID" }, { "GetShapeshiftForm" }, { "GetNumShapeshiftForms" },
    { "IsMounted" }, { "IsFlying" }, { "IsSwimming" }, { "IsSubmerged" }, { "IsFalling" }, { "IsIndoors" },
    { "IsOutdoors" }, { "IsResting" }, { "IsStealthed" }, { "UnitOnTaxi", "player" }, { "GetUnitSpeed", "player" },
    { "UnitInVehicle", "player" }, { "UnitIsAFK", "player" }, { "UnitIsDND", "player" },
    { "UnitIsDeadOrGhost", "player" }, { "InCombatLockdown" }, { "UnitCastingInfo", "player" },
    { "UnitChannelInfo", "player" }, { "GetXPExhaustion" }, { "UnitXP", "player" }, { "UnitXPMax", "player" },
    { "GetBindLocation" }, { "GetZoneText" }, { "GetRealZoneText" }, { "GetSubZoneText" }, { "GetMinimapZoneText" },
    { "GetInstanceInfo" }, { "IsInInstance" }, { "GetZonePVPInfo" }, { "C_Map.GetBestMapForUnit", "player" },
    { "IsInGuild" }, { "GetGuildInfo", "player" }, { "GetNumGuildMembers" }, { "GetGuildRosterInfo", 1 },
    { "GetGuildRosterMOTD" }, { "C_GuildInfo.GetGuildRankOrder" }, { "IsInGroup" }, { "IsInRaid" },
    { "GetNumGroupMembers" }, { "UnitIsGroupLeader", "player" },
    { "C_PetJournal.GetNumPets" }, { "C_PetJournal.GetSummonedPetGUID" }, { "C_PetJournal.IsJournalUnlocked" },
    { "C_PetJournal.GetPetInfoBySpeciesID", 5159 }, { "C_PetJournal.GetNumPetSources" },
    { "C_PetJournal.GetNumPetTypes" }, { "GetNumCompanions", "CRITTER" }, { "GetCompanionInfo", "CRITTER", 1 },
    { "UnitName", "target" }, { "UnitGUID", "target" }, { "UnitCreatureType", "target" },
    { "UnitCreatureFamily", "target" }, { "UnitBattlePetSpeciesID", "target" }, { "UnitBattlePetType", "target" },
    { "UnitBattlePetLevel", "target" }, { "UnitIsBattlePetCompanion", "target" },
    { "UnitIsOtherPlayersBattlePet", "target" }, { "UnitIsBattlePet", "target" }, { "UnitClassification", "target" },
    { "UnitName", "mouseover" }, { "UnitBattlePetSpeciesID", "mouseover" }, { "UnitGUID", "mouseover" },
    { "GetNumCompletedAchievements" }, { "GetTotalAchievementPoints" }, { "GetAchievementInfo", 6 },
    { "GetCategoryList" }, { "GetStatistic", 60 }, { "GetProfessions" }, { "GetNumSkillLines" },
    { "GetSkillLineInfo", 1 }, { "GetNumFactions" }, { "GetWatchedFactionInfo" },
    { "C_Reputation.GetWatchedFactionData" }, { "C_MountJournal.GetNumMounts" }, { "C_ToyBox.GetNumToys" },
    { "C_ChatInfo.GetRegisteredAddonMessagePrefixes" }, { "C_ChatInfo.GetNumActiveChannels" }, { "GetChannelList" },
    { "C_Calendar.GetDate" }, { "C_AddOns.GetNumAddOns" }, { "GetNumAddOns" }, { "C_CVar.GetCVar", "nameplateShowAll" },
    { "GetCVar", "Sound_EnableSFX" }, { "issecretvalue", 1 }, { "C_Spell.GetSpellName", 8690 },
    { "GetSpellInfo", 8690 }, { "C_Spell.GetSpellCooldown", 8690 }, { "GetItemCount", 6948 },
    { "C_Item.GetItemNameByID", 6948 }, { "C_Container.GetContainerNumSlots", 0 }, { "GetContainerNumSlots", 0 },
    { "C_PlayerInfo.GetPlayerMythicPlusRatingSummary", "player" }, { "C_Texture.GetAtlasInfo", "PetJournal-FavoritesIcon" },
    { "GetScreenWidth" }, { "GetScreenHeight" },
}

function S.values(out)
    local missing = {}
    for _, v in ipairs(Api.VALUES) do
        local label = v[1] .. "(" .. table.concat((function()
            local a = {}
            for i = 2, #v do a[#a + 1] = type(v[i]) == "table" and "self" or Show(v[i]) end
            return a
        end)(), ", ") .. ")"
        local fn = G(v[1])
        if type(fn) ~= "function" then
            missing[#missing + 1] = v[1]
            out[label] = "(missing)"
        else
            out[label] = Try(fn, select(2, unpack(v)))
        end
    end
    out.missing = missing
    return ("%d calls; missing: %s"):format(#Api.VALUES, table.concat(missing, " "))
end

function S.card(out)
    local card = G("PetJournalPetCard")
    if not card then return "no pet card (open the pet journal)" end
    out.card = Describe(card)
    local scene = card.modelScene
    out.scene = Describe(scene)
    if scene then
        out.sceneState = {
            id = Try(function() return scene:GetModelSceneID() end),
            camera = Try(function() return scene:GetCameraPosition() end),
            fov = Try(function() return scene:GetCameraFieldOfView() end),
        }
    end
    local actor = ns.Moves and ns.Moves:Actor()
    out.actor = Describe(actor)
    if actor then
        local state = {}
        for _, m in ipairs({ "GetAnimation", "GetPosition", "GetYaw", "GetPitch", "GetRoll", "GetScale", "GetAlpha",
            "GetModelFileID", "GetModelPath", "GetModelUnitGUID", "GetActiveBoundingBox", "GetMaxBoundingBox",
            "IsLoaded", "IsShown", "IsVisible", "GetPaused", "GetAnimationBlendOperation", "GetDesaturation",
            "GetParticleOverrideScale", "GetSpellVisualKit" }) do
            local ok, fn = pcall(function() return actor[m] end)
            state[m] = (ok and type(fn) == "function") and Try(fn, actor) or "(missing)"
        end
        out.actorState = state
    end
    out.key = ns.JournalUI and ns.JournalUI._card and ns.JournalUI._card.key
    return ("card %s, scene %s, actor %s"):format(card and "yes" or "no", scene and "yes" or "no", actor and "yes" or "no")
end

-- Today's events (holidays): asked for, then read once the calendar has loaded (or after a while).
Api.CALENDAR_WAIT = 3
function S.calendar(out)
    local C = G("C_Calendar")
    if type(C) ~= "table" then return "no C_Calendar" end
    if C.OpenCalendar then pcall(C.OpenCalendar) end
    local token = {}
    Api.calendarToken = token
    C_Timer.After(Api.CALENDAR_WAIT, function()
        if Api.calendarToken ~= token then return end
        local day = Try(function()
            -- (Forever has no C_Calendar.GetDate: 2026-11-11)
            local t = C.GetDate and C.GetDate() or C_DateAndTime.GetCurrentCalendarTime()
            return t.monthDay
        end)
        local monthDay = tonumber(day)
        out.today = day
        local events = {}
        local okN, n = pcall(C.GetNumDayEvents, 0, monthDay)
        out.count = okN and Show(n) or ("error: " .. tostring(n))
        for i = 1, (okN and type(n) == "number") and n or 0 do
            events[#events + 1] = Try(C.GetDayEvent, 0, monthDay, i)
            if C.GetHolidayInfo then events[#events + 1] = "  holiday: " .. Try(C.GetHolidayInfo, 0, monthDay, i) end
        end
        out.events = events
        ns.Log("Api", "calendar: %s events today", tostring(out.count))
        ns.Print(("api probe: calendar read, %s events today"):format(tostring(out.count)))
    end)
    return "asked; read in " .. Api.CALENDAR_WAIT .. " s"
end

-- A model of the card's pet in an invisible PlayerModel: its animations, and how
-- long the card's moves play (the card's actor has no OnAnimFinished: the user, 2026-11-11).
Api.ANIM_MAX = 1500
Api.TIME_OUT = 6
function S.model(out)
    local key = ns.JournalUI and ns.JournalUI._card and ns.JournalUI._card.key
    local sid = key and ns.Pets:SpeciesOfKey(key)
    if not sid then return "open a pet's card first" end
    local info = Pack(pcall(C_PetJournal.GetPetInfoBySpeciesID, sid))
    local display = info[13] -- (after pcall's ok: the 12th, creatureDisplayID)
    out.species, out.display = sid, Show(display)
    local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
    if not ok then return "no PlayerModel: " .. tostring(m) end
    Api.model = m
    pcall(function() m:SetSize(64, 64); m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0); m:SetAlpha(0) end)
    out.methods, out.scripts = Methods(m), Scripts(m)
    local okD, err = pcall(function() return m:SetDisplayInfo(display) end)
    if not okD then return "SetDisplayInfo: " .. tostring(err) end
    local done
    local function Read()
        if done then return end
        done = true
        local has = {}
        local okH = pcall(function()
            for id = 0, Api.ANIM_MAX do if m:HasAnimation(id) then has[#has + 1] = id end end
        end)
        out.animations = okH and table.concat(has, " ") or "(no HasAnimation)"
        ns.Log("Api", "model %d: %d animations", sid, #has)
        Api:TimeMoves(m, key, out)
    end
    local function Hook(script, fn)
        local okS = pcall(m.SetScript, m, script, fn)
        return okS
    end
    if not Hook("OnModelLoaded", Read) then out.noLoadedScript = true end
    C_Timer.After(2, Read) -- (if it never says so)
    return "model of species " .. sid .. " loading"
end

-- How long each of the card's moves plays on this model, by OnAnimFinished.
function Api:TimeMoves(m, key, out)
    local ids, seen = {}, {}
    for _, what in ipairs({ "happy", "happyToo", "cheer", "sleepUp", "sitDown", "sitUp", "sleep", "dead" }) do
        local id = ns.Moves:For(key, what)
        if id and not seen[id] then seen[id] = true; ids[#ids + 1] = { what, id } end
    end
    out.lengths = {}
    local okS, has = pcall(function() return m:HasScript("OnAnimFinished") end)
    has = okS and has
    if not has then out.lengths = "(no OnAnimFinished)"; return self:Finish(out) end
    local i, started, token = 0, 0, {}
    local function Next()
        i = i + 1
        local step = ids[i]
        if not step then
            token = nil -- (the last one's time-out: nothing more)
            m:SetScript("OnAnimFinished", nil)
            return self:Finish(out)
        end
        local mine = {}
        token = mine
        started = GetTime()
        pcall(function() m:SetAnimation(step[2]) end)
        C_Timer.After(self.TIME_OUT, function()
            if token ~= mine then return end
            out.lengths[step[1] .. " " .. step[2]] = "no end in " .. self.TIME_OUT .. " s"
            Next()
        end)
    end
    m:SetScript("OnAnimFinished", function()
        local step = ids[i]
        if not step then return end
        out.lengths[step[1] .. " " .. step[2]] = ("%.2f s"):format(GetTime() - started)
        Next()
    end)
    Next()
end

function Api:Finish(out)
    if self.model then pcall(self.model.Hide, self.model) end
    ns.Log("Api", "model: done")
    ns.Print("api probe: model done; /reload to write DyreparkenDebugDB.api")
end

------------------------------------------------------------------------------
Api.ORDER = { "globals", "namespaces", "enum", "events", "widgets", "templates", "strings", "values", "card",
    "calendar", "model" }

function Api:Run(arg)
    DyreparkenDebugDB = DyreparkenDebugDB or {}
    if arg == "clear" then
        DyreparkenDebugDB.api = nil
        return ns.Print("api probe: cleared")
    end
    local db = DyreparkenDebugDB.api or {}
    DyreparkenDebugDB.api = db
    db.at, db.build = date("%Y-%m-%d %H:%M"), Try(GetBuildInfo)
    local list = arg and { arg } or self.ORDER
    for _, name in ipairs(list) do
        local fn = S[name]
        if not fn then return ns.Print("api probe: sections are " .. table.concat(self.ORDER, " ")) end
        local out = {}
        db[name] = out
        local ok, summary = pcall(fn, out)
        summary = ok and summary or ("failed: " .. tostring(summary))
        ns.Log("Api", "%s: %s", name, tostring(summary))
        ns.Print(("api probe %s: %s"):format(name, tostring(summary)))
    end
    ns.Print("api probe: saved in DyreparkenDebugDB.api on /reload")
end
