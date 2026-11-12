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
-- `/dp probe api <section>` one; `/dp probe api clear` forgets them. Two more, run only by name:
--   holidays    the calendar's holidays for the coming year (it steps the calendar through the months and
--               puts it back), for Data/Holidays.lua
--   lengths     how long every species' one-off moves play (all species, a few minutes), into
--               DyreparkenDebugDB.animLengths for tools/anim_lengths.lua -> Data/AnimLengths.lua
--   petframe    (2026-11-11, groundwork for the on-screen pet frame) a test frame in the middle of the
--               screen: our own model scene with the pet that's out, as the journal card builds it.
--               Left-click: its happy move; right-click: close. Logs each step, and whether Edit Mode
--               tells us when it opens and closes (EventRegistry "EditMode.Enter"/"EditMode.Exit").
--   meter       (2026-11-12, the user: could the pet react to the built-in damage meter, a first place in
--               damage or healing?) C_DamageMeter now (every session, damage/healing/interrupts: secret or
--               not, the sources, your place), saved; and from then on, this session, every DAMAGE_METER_*
--               event and each combat's end logged with the same read ("meter ..." lines in the log).
--               Retail's docs: the data is SecretWhenInCombat; out of combat it should read.
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
    { "ItemButtonTemplate", "Button" }, { "UICheckButtonTemplate", "CheckButton" }, { "UIRadioButtonTemplate", "CheckButton" },
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

-- The coming year's holidays: the calendar set to each month in turn (its events load a moment
-- later), every day's events read, then set back to this month.
Api.MONTH_WAIT, Api.MONTHS = 2, 12
function S.holidays(out)
    local C = G("C_Calendar")
    if type(C) ~= "table" or not C.SetAbsMonth then return "no C_Calendar.SetAbsMonth" end
    pcall(C.OpenCalendar)
    local now = C_DateAndTime.GetCurrentCalendarTime()
    local seen, list = {}, {}
    out.list = list
    local function Month(i)
        if i >= Api.MONTHS then
            pcall(C.SetAbsMonth, now.month, now.year)
            table.sort(list, function(a, b) return a.first < b.first end)
            ns.Log("Api", "holidays: %d", #list)
            return ns.Print(("api probe: holidays done, %d; /reload to write them"):format(#list))
        end
        local m = (now.month - 1 + i) % 12 + 1
        local y = now.year + math.floor((now.month - 1 + i) / 12)
        pcall(C.SetAbsMonth, m, y)
        C_Timer.After(Api.MONTH_WAIT, function()
            for day = 1, 31 do
                local okN, n = pcall(C.GetNumDayEvents, 0, day)
                for j = 1, (okN and type(n) == "number") and n or 0 do
                    local okE, e = pcall(C.GetDayEvent, 0, day, j)
                    if okE and type(e) == "table" and e.eventID then
                        local when = ("%04d-%02d-%02d"):format(y, m, day)
                        local h = seen[e.eventID]
                        if not h then
                            local okH, info = pcall(C.GetHolidayInfo, 0, day, j)
                            h = { id = e.eventID, title = Show(e.title), type = e.eventType, texture = e.iconTexture,
                                sequence = e.sequenceType, days = e.numSequenceDays, first = when, dates = {},
                                name = okH and type(info) == "table" and Show(info.name) or nil,
                                description = okH and type(info) == "table" and Show(info.description) or nil }
                            seen[e.eventID] = h
                            list[#list + 1] = h
                        end
                        h.last = when
                        h.dates[#h.dates + 1] = when
                    end
                end
            end
            Month(i + 1)
        end)
    end
    Month(0)
    return ("asked; %d months, %d s each"):format(Api.MONTHS, Api.MONTH_WAIT)
end

-- How long every species' one-off moves play, by OnAnimFinished on invisible PlayerModels, a few at a
-- time. Each is timed twice (the first may be cut short by the stand it interrupts); the second counts.
Api.WORKERS, Api.LOAD_WAIT = 6, 2
Api.PARTS = { "happy", "happyToo", "cheer", "sleepUp", "sitDown", "sitUp", "sleep", "dead" }
-- arg (2026-11-12, the user: "running the lengths probe for all animals when we add a single new one"):
-- none: only the species with a move unmeasured (Moves:Unmeasured: a new companion, or a move changed in
-- Data/PetMoves.lua); "all": every species; species ids: those. Each run saves only what it measured (a
-- leftover run, older than the file, once overwrote it: 2026-11-12); tools/anim_lengths.lua merges that
-- into Data/AnimLengths.lua and keeps the rest.
function S.lengths(out, arg)
    local queue = {}
    if arg == "all" then
        for sid in pairs(ns.Companions.species) do queue[#queue + 1] = sid end
    elseif arg then
        for id in arg:gmatch("%d+") do queue[#queue + 1] = tonumber(id) end
    else
        queue = ns.Moves:Unmeasured()
    end
    table.sort(queue)
    local total = #queue
    if total == 0 then return "every species is measured: nothing to do (all: every species anew)" end
    local saved = {}
    DyreparkenDebugDB.animLengths = saved
    out.species, out.done = #queue, 0
    local workers = 0
    local function Ids(sid)
        local key, ids, seen = ns.Pets:KeyOfSpecies(sid), { 0 }, { [0] = true }
        for _, what in ipairs(Api.PARTS) do
            local id = ns.Moves:For(key, what)
            if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end
        end
        return ids
    end
    local function Work(m)
        local sid = table.remove(queue, 1)
        if not sid then
            workers = workers - 1
            pcall(m.Hide, m)
            if workers == 0 then
                ns.Log("Api", "lengths: done, %d species", out.done)
                ns.Print(("api probe: lengths done, %d species; /reload to write them"):format(out.done))
            end
            return
        end
        local info = Pack(pcall(C_PetJournal.GetPetInfoBySpeciesID, sid))
        local display = info[13]
        local mine = { display = display }
        saved[sid] = mine
        local ids, i, round, started, token = Ids(sid), 0, 0, 0, nil
        local function Next()
            round = round + 1
            if round > 2 then round, i = 1, i + 1 end
            if i == 0 then i = 1 end
            local id = ids[i]
            if not id then
                token = nil
                out.done = out.done + 1
                if out.done % 10 == 0 then ns.Print(("api probe: lengths %d / %d"):format(out.done, out.species)) end
                return Work(m)
            end
            local t = {}
            token, started = t, GetTime()
            pcall(m.SetAnimation, m, id)
            C_Timer.After(Api.TIME_OUT, function()
                if token ~= t then return end
                mine[id] = "none"
                Next()
            end)
        end
        m:SetScript("OnAnimFinished", function()
            if not token or not ids[i] then return end
            local took = GetTime() - started
            if round == 2 then mine[ids[i]] = tonumber(("%.2f"):format(took)) end
            Next()
        end)
        local loaded
        local function Go()
            if loaded then return end
            loaded = true
            Next()
        end
        m:SetScript("OnModelLoaded", Go)
        if not (display and pcall(m.SetDisplayInfo, m, display)) then
            mine.error, out.done = "no display", out.done + 1
            return Work(m)
        end
        C_Timer.After(Api.LOAD_WAIT, Go)
    end
    for _ = 1, Api.WORKERS do
        local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if not ok then return "no PlayerModel: " .. tostring(m) end
        pcall(function() m:SetSize(64, 64); m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0); m:SetAlpha(0) end)
        workers = workers + 1
        Work(m)
    end
    return ("%d species, %d at a time"):format(total, Api.WORKERS)
end

-- Our own model scene with the pet that's out, built the way Blizzard's pet card does it
-- (PetJournal_UpdatePetCard): the species' model scene id, then the "unwrapped" actor's model.
Api.PETFRAME_W, Api.PETFRAME_H = 240, 220
function S.petframe(out)
    local key = ns.Pets:OutKey()
    local sid = key and ns.Pets:SpeciesOfKey(key)
    if not sid then return "summon a pet first" end
    out.species = sid
    local f = Api.petFrame
    if not f then
        f = CreateFrame("Frame", "DyreparkenPetFrameProbe", UIParent)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
        f:SetMovable(true)
        local okS, scene = pcall(CreateFrame, "ModelScene", nil, f, "ModelSceneMixinTemplate")
        out.scene = okS and "made" or ("failed: " .. tostring(scene))
        if not okS then return out.scene end
        scene:SetAllPoints()
        -- (2026-11-11, the first run: the scene took the mouse, to rotate the pet; a click never arrived)
        pcall(function() scene:EnableMouse(false) end); pcall(function() scene:EnableMouseWheel(false) end)
        f.scene = scene
        -- On top: takes the clicks (left: its happy move; right: close) and drags.
        local click = CreateFrame("Button", nil, f)
        click:SetAllPoints()
        click:SetFrameLevel(scene:GetFrameLevel() + 5)
        click:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        click:RegisterForDrag("LeftButton")
        click:SetScript("OnDragStart", function() f:StartMoving() end)
        click:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
        f.click = click
        -- Its bounds, faintly (2026-11-11, the second run: the pet still cut off at the same place in a
        -- bigger frame, so not by the frame's edge).
        f.bg = f:CreateTexture(nil, "BACKGROUND")
        f.bg:SetAllPoints()
        f.bg:SetColorTexture(0, 0, 0, 0.3)
        Api.petFrame = f
    end
    -- The card's shape (2026-11-11, the first run: in a 180x180 frame only the pet's bottom half
    -- showed; the scene's camera is set for the card): the card's scene size, if the journal has
    -- been open, else a guess.
    local card = G("PetJournalPetCard")
    local cardScene = card and rawget(card, "modelScene")
    local okW, w, h = pcall(function() return cardScene:GetSize() end)
    out.cardSize = okW and Show(w) .. " x " .. Show(h) or "(open the pet journal first)"
    -- (third run: our scene and the card's had the same camera, but the card sets view insets of
    -- 0, 0, 300, -50 on 386 px: the model's view is its bottom part, from 50 px below the edge to 86
    -- above, the space above it left to the text and to tall pets. The same here, at any height.)
    f:SetSize(Api.PETFRAME_W, Api.PETFRAME_H)
    out.insets = Try(function() return f.scene:SetViewInsets(0, 0, Api.PETFRAME_H - 86, -50) end)
    local scene = f.scene
    local info = Pack(pcall(C_PetJournal.GetPetModelSceneInfoBySpeciesID, sid))
    out.sceneInfo = Try(function() return select(2, unpack(info, 1, info.n)) end)
    local sceneID = info[2]
    local display = Pack(pcall(C_PetJournal.GetPetInfoBySpeciesID, sid))[13]
    out.display = Show(display)
    out.transition = Try(function()
        return scene:TransitionToModelSceneID(sceneID, rawget(_G, "CAMERA_TRANSITION_TYPE_IMMEDIATE") or 1,
            rawget(_G, "CAMERA_MODIFICATION_TYPE_DISCARD") or 1, true)
    end)
    pcall(function() scene:SetViewInsets(0, 0, Api.PETFRAME_H - 86, -50) end) -- (again: a new scene may reset them)
    local okA, actor = pcall(function() return scene:GetActorByTag("unwrapped") end)
    out.actor = okA and (actor and "found" or "no unwrapped actor") or ("failed: " .. tostring(actor))
    if not (okA and actor) then
        -- Not in this scene: one of our own.
        okA, actor = pcall(function() return scene:CreateActor() end)
        out.created = okA and (actor and "made one" or "nil") or ("failed: " .. tostring(actor))
    end
    if okA and actor then
        out.model = Try(function() return actor:SetModelByCreatureDisplayID(display) end)
        out.methods = #Methods(actor) .. " methods"
        f.actor = actor
        -- Where it stands, against the card's actor (0, 0, 0.3 at scale 19.48 for the prairie dog).
        C_Timer.After(1, function()
            out.position = Try(function() return actor:GetPosition() end)
            out.scale = Try(function() return actor:GetScale() end)
            local cardActor = ns.Moves:Actor()
            out.cardPosition = cardActor and Try(function() return cardActor:GetPosition() end) or "(no card)"
            ns.Log("Api", "petframe: size %s, position %s, scale %s; card's position %s", tostring(out.cardSize),
                tostring(out.position), tostring(out.scale), tostring(out.cardPosition))
            -- The camera and view of ours against the card's: what clips the pet?
            local function View(sc)
                if not sc then return "(none)" end
                local parts = {}
                for _, m in ipairs({ "GetViewInsets", "GetCameraPosition", "GetCameraFieldOfView", "GetCameraNearClip",
                    "GetCameraFarClip", "GetModelSceneID", "GetSize", "GetEffectiveScale", "DoesClipChildren" }) do
                    local okM, fn = pcall(function() return sc[m] end)
                    parts[#parts + 1] = m .. "=" .. ((okM and type(fn) == "function") and Try(fn, sc) or "-")
                end
                local okC, cam = pcall(function() return sc:GetActiveCamera() end)
                if okC and cam then
                    for _, m in ipairs({ "GetTarget", "GetZoomDistance", "GetMinZoomDistance", "GetMaxZoomDistance",
                        "GetYaw", "GetPitch", "GetFieldOfView", "GetNearClip", "GetFarClip" }) do
                        local okM, fn = pcall(function() return cam[m] end)
                        parts[#parts + 1] = "cam." .. m .. "=" .. ((okM and type(fn) == "function") and Try(fn, cam) or "-")
                    end
                end
                return table.concat(parts, "; ")
            end
            out.view, out.cardView = View(scene), View(cardScene)
            ns.Log("Api", "petframe view: %s", out.view)
            ns.Log("Api", "petframe card view: %s", out.cardView)
        end)
    end
    f.click:SetScript("OnClick", function(_, button)
        if button == "RightButton" then f:Hide(); return end
        if f.actor then
            local happy = ns.Moves:For(key, "happy") or 756
            ns.Log("Api", "petframe click: SetAnimation(%d): %s", happy, Try(function() return f.actor:SetAnimation(happy) end))
        end
    end)
    f:Show()
    -- Edit Mode: does it tell us when it opens and closes?
    local ER = G("EventRegistry")
    out.editMode = { manager = G("EditModeManagerFrame") ~= nil, registry = ER ~= nil }
    if ER and ER.RegisterCallback and not Api.editHooked then
        Api.editHooked = true
        for _, ev in ipairs({ "EditMode.Enter", "EditMode.Exit" }) do
            out.editMode[ev] = Try(function()
                ER:RegisterCallback(ev, function()
                    ns.Log("Api", "petframe: %s fired", ev)
                    ns.Print("api probe: " .. ev .. " fired")
                end, Api)
            end)
        end
    end
    ns.Log("Api", "petframe: scene %s, info %s, transition %s, actor %s, model %s", tostring(out.scene),
        tostring(out.sceneInfo), tostring(out.transition), tostring(out.actor), tostring(out.model))
    return ("species %d: scene %s, actor %s; click it, then open and close Edit Mode"):format(sid,
        tostring(out.scene), tostring(out.actor))
end

------------------------------------------------------------------------------
-- The built-in damage meter (C_DamageMeter, Retail 12.0's).
------------------------------------------------------------------------------
Api.METER_TYPES = { 0, 2, 5 } -- DamageDone, HealingDone, Interrupts (Enum.DamageMeterType)
Api.METER_SESSIONS = { 0, 1, 2 } -- Overall, Current, Expired (Enum.DamageMeterSessionType)

-- One session of one kind, as text: secret or not, how many sources, the top few, and our place.
function Api.MeterRead(sessionType, kind)
    local DM = rawget(_G, "C_DamageMeter")
    if not (DM and DM.GetCombatSessionFromType) then return "no C_DamageMeter" end
    local ok, s = pcall(DM.GetCombatSessionFromType, sessionType, kind)
    if not ok then return "error: " .. tostring(s) end
    if s == nil then return "nil" end
    if ns.IsSecret(s) then return "<secret session>" end
    local sources = s.combatSources
    if ns.IsSecret(sources) then return "sources <secret>" end
    if type(sources) ~= "table" then return "total " .. Show(s.totalAmount) .. ", no sources" end
    local parts, mine, open = {}, nil, true
    for i, src in ipairs(sources) do
        local total = src.totalAmount
        if ns.IsSecret(total) then open = false end
        if src.isLocalPlayer == true then mine = i end
        if i <= 5 then
            parts[#parts + 1] = ("%d %s (%s%s) %s, %s/s"):format(i, Show(src.name), Show(src.classFilename),
                src.isLocalPlayer == true and ", you" or "", Show(total), Show(src.amountPerSecond))
        end
    end
    -- Our place: the list's order, if it's sorted (checked only on plain numbers).
    local sorted = open
    if open then
        for i = 2, #sources do
            local a, b = sources[i - 1].totalAmount, sources[i].totalAmount
            if type(a) == "number" and type(b) == "number" and a < b then sorted = false end
        end
    end
    return ("%d sources, total %s, max %s, duration %s; you %s%s; %s"):format(#sources, Show(s.totalAmount),
        Show(s.maxAmount), Show(s.durationSeconds), mine and ("#" .. mine) or "not in it",
        open and (sorted and " (sorted)" or " (NOT sorted)") or " (amounts secret)", table.concat(parts, "; "))
end

-- Every session and kind, one line each.
function Api.MeterAll(why)
    local inCombat = ns.Plain(InCombatLockdown()) and "in combat" or "out of combat"
    for _, st in ipairs(Api.METER_SESSIONS) do
        for _, kind in ipairs(Api.METER_TYPES) do
            ns.Log("Api", "meter %s (%s) session %d type %d: %s", why, inCombat, st, kind, Api.MeterRead(st, kind))
        end
    end
end

function S.meter(out)
    local DM = rawget(_G, "C_DamageMeter")
    if not DM then return "no C_DamageMeter" end
    out.available = Try(DM.IsDamageMeterAvailable)
    out.sessions = Try(DM.GetAvailableCombatSessions)
    local okA, list = pcall(DM.GetAvailableCombatSessions)
    if okA and type(list) == "table" and list[1] then
        local first = list[#list]
        out.lastSession = Show(first)
        out.fromID = Try(function() return DM.GetCombatSessionFromID(first.sessionID, 0) end)
        out.durationOfID = Try(DM.GetSessionDurationSeconds, first.sessionID)
    end
    out.durationCurrent = Try(DM.GetSessionDurationSeconds, 1)
    out.reads = {}
    for _, st in ipairs(Api.METER_SESSIONS) do
        for _, kind in ipairs(Api.METER_TYPES) do
            out.reads[("session %d type %d"):format(st, kind)] = Api.MeterRead(st, kind)
        end
    end
    -- From now on, this session: each meter event and each combat's end, read the same way.
    if not Api.meterWatch then
        local f = CreateFrame("Frame")
        Api.meterWatch = f
        for _, e in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_CURRENT_SESSION_UPDATED",
            "DAMAGE_METER_RESET", "PLAYER_REGEN_ENABLED" }) do
            local ok = pcall(f.RegisterEvent, f, e)
            out["event " .. e] = ok and "registered" or "refused"
        end
        local last = {}
        f:SetScript("OnEvent", function(_, event, a, b)
            -- (the updates come often in a fight: one line per event kind every 2 s)
            local now = GetTime()
            if event ~= "PLAYER_REGEN_ENABLED" and last[event] and now - last[event] < 2 then return end
            last[event] = now
            ns.Log("Api", "meter event %s %s %s", event, Show(a), Show(b))
            if event == "PLAYER_REGEN_ENABLED" then
                C_Timer.After(1, function() Api.MeterAll("after combat") end)
            elseif event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
                ns.Log("Api", "meter session %s type %s now: %s", Show(b), Show(a), Api.MeterRead(1, ns.Plain(a) or 0))
            end
        end)
    end
    return ("available %s; %d reads; watching this session"):format(out.available, 9)
end

------------------------------------------------------------------------------
-- feats (2026-11-12, Menagerie/Feats.lua, by name only): what Feats is built on, read without doing
-- anything to the character (the user can't respec, switch spec or visit a trainer for now):
--   every feat's spells (the client's name for each id, known or not) and quests (title, done), so
--   wrong ids show; the character's completed quests whose titles are a feat quest's under another
--   id (Forever's copies for its new race/class pairings); the talent and spec getters' values;
--   which candidate events the client knows; global strings about learning, talents and specs.
-- Then, this session, it watches: each candidate event that fires is logged with its payload and
-- the unspent talent points, so a respec, a spec switch or a trainer visit some day is caught.
Api.FEAT_EVENTS = { "SPELLS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
    "LEARNED_SPELL_IN_SKILL_LINE", "LEARNED_SPELL_IN_TAB", "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE",
    "TRAIT_CONFIG_UPDATED", "TRAIT_CONFIG_LIST_UPDATED", "CONFIRM_TALENT_WIPE", "TALENTS_INVOLUNTARILY_RESET",
    "ACTIVE_COMBAT_CONFIG_CHANGED", "SPEC_INVOLUNTARILY_CHANGED", "TRAINER_SHOW", "TRAINER_CLOSED",
    "TRAINER_UPDATE", "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "SKILL_LINES_CHANGED", "NEW_MOUNT_ADDED" }
Api.FEAT_STRINGS = { "LEARN", "TALENT", "SPECIALIZ", "RESPEC", "DUAL", "RIDING" }
Api.QUEST_BATCH, Api.QUEST_EVERY, Api.QUEST_WAIT = 25, 1, 5 -- quest titles asked for: this many a second, then a wait
function S.feats(out)
    local F = ns.Feats
    if not F then return "no Feats" end
    local QL = rawget(_G, "C_QuestLog") or {}
    local Title = QL.GetTitleForQuestID
    local function QuestTitle(id) return Title and ns.Plain(Title(id)) or nil end
    local spells = {}
    local unknownSpells, known = 0, 0
    for _, f in ipairs(F.LIST) do
        for _, id in ipairs(f.spells or {}) do
            local name = ns.SpellName(id)
            if not name then unknownSpells = unknownSpells + 1 end
            local has = F:Has({ spells = { id } }) and true or false
            if has then known = known + 1 end
            spells[#spells + 1] = ("%s %d %s%s"):format(f.id, id, tostring(name or "NO SPELL"), has and " (known)" or "")
        end
    end
    out.spells = spells
    -- The items (the totems): the client's name for each id, and how many are in the bags.
    out.items = {}
    local CI = rawget(_G, "C_Item") or {}
    for _, f in ipairs(F.LIST) do
        for _, id in ipairs(f.items or {}) do
            out.items[#out.items + 1] = ("%s %d %s, in bags %s"):format(f.id, id,
                CI.GetItemNameByID and Try(CI.GetItemNameByID, id) or "?", CI.GetItemCount and Try(CI.GetItemCount, id) or "?")
        end
    end
    local okC, ids = pcall(QL.GetAllCompletedQuestIDs or function() return nil end)
    ids = okC and type(ids) == "table" and ids or {}
    out.completed = #ids
    -- The quests' titles, and a completed quest with a feat quest's title under an id we don't have
    -- (Forever's copy). A title the client hasn't seen yet is nil: asked for (RequestLoadQuestByID,
    -- a few at a time), and read again QUEST_WAIT seconds later (2026-11-12: the first run had none).
    local function Quests()
        local quests, titles, copies = {}, {}, {}
        for _, f in ipairs(F.LIST) do
            for _, id in ipairs(f.quests or {}) do
                local title = QuestTitle(id)
                if title then titles[title] = f.id end
                local done = QL.IsQuestFlaggedCompleted and Try(QL.IsQuestFlaggedCompleted, id) or "?"
                quests[#quests + 1] = ("%s %d %s, done %s"):format(f.id, id, tostring(title or "(no title yet)"), done)
            end
        end
        local untitled = 0
        for _, id in ipairs(ids) do
            local title = QuestTitle(id)
            if not title then untitled = untitled + 1 end
            if title and titles[title] and not F.BY_QUEST[id] then
                copies[#copies + 1] = ("%d %s (like %s)"):format(id, title, titles[title])
            end
        end
        out.quests, out.copies, out.untitled = quests, copies, untitled
    end
    Quests()
    if QL.RequestLoadQuestByID then
        local ask = {}
        for _, f in ipairs(F.LIST) do for _, id in ipairs(f.quests or {}) do ask[#ask + 1] = id end end
        for _, id in ipairs(ids) do ask[#ask + 1] = id end
        for i = 1, #ask, Api.QUEST_BATCH do
            C_Timer.After((i - 1) / Api.QUEST_BATCH * Api.QUEST_EVERY, function()
                for j = i, math.min(i + Api.QUEST_BATCH - 1, #ask) do pcall(QL.RequestLoadQuestByID, ask[j]) end
            end)
        end
        local wait = math.ceil(#ask / Api.QUEST_BATCH) * Api.QUEST_EVERY + Api.QUEST_WAIT
        C_Timer.After(wait, function()
            Quests()
            local line = ("feats: titles read, %d copies, %d completed quests still untitled"):format(#out.copies, out.untitled)
            ns.Log("Api", "%s", line)
            ns.Print("api probe " .. line .. "; /reload to save")
        end)
    end
    -- The talents (retail's system on Forever): the active loadout, its trees, a node's fields.
    out.talents = {}
    local okT = pcall(function()
        local T, config = out.talents, C_ClassTalents.GetActiveConfigID()
        T.config = Show(config)
        local info = C_Traits.GetConfigInfo(config)
        T.info = Show(info)
        local ranks = F.Ranks()
        local n, sum = 0, 0
        for node, r in pairs(ranks or {}) do if node ~= "config" then n, sum = n + 1, sum + r end end
        T.ranked, T.ranks = n, sum
        for _, tree in ipairs(info and info.treeIDs or {}) do
            local nodes = C_Traits.GetTreeNodes(tree) or {}
            T["tree " .. tostring(tree)] = #nodes .. " nodes"
            for _, node in ipairs(nodes) do
                local ni = C_Traits.GetNodeInfo(config, node)
                if type(ni) == "table" and not T.sampleNode then T.sampleNode = Show(ni) end
            end
        end
    end)
    if not okT then out.talents.error = "no talent config" end
    out.feats = {}
    for id, rec in pairs(ns.DB.char.feats) do out.feats[#out.feats + 1] = id .. " " .. Show(rec) end
    table.sort(out.feats)
    out.values = {
        unspent = Try(GetNumUnspentTalents or error),
        level = Try(UnitLevel, "player"),
        activeSpecGroup = Try(function() return C_SpecializationInfo.GetActiveSpecGroup() end),
        specialization = Try(function() return C_SpecializationInfo.GetSpecialization() end),
        numSpecs = Try(GetNumSpecializations or error),
        canTalents = Try(function() return C_SpecializationInfo.CanPlayerUseTalentUI() end),
        activeConfig = Try(function() return C_ClassTalents.GetActiveConfigID() end),
        unspentClass = Try(function() return C_ClassTalents.HasUnspentTalentPoints() end),
        trainerType = Try(function() return Enum.PlayerInteractionType.Trainer end),
    }
    out.strings = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and #v < 200 then
            for _, word in ipairs(Api.FEAT_STRINGS) do
                if k:find(word, 1, true) and (k:find("^ERR_") or k:find("WIPE") or k:find("RESET") or k:find("SWITCH")
                    or k:find("CHANGE") or k:find("ACTIV")) then
                    out.strings[#out.strings + 1] = k .. " = " .. v
                    break
                end
            end
        end
    end
    table.sort(out.strings)
    local refused = {}
    if not Api.featWatch then
        local f = CreateFrame("Frame")
        Api.featWatch = f
        for _, e in ipairs(Api.FEAT_EVENTS) do
            if not pcall(f.RegisterEvent, f, e) then refused[#refused + 1] = e end
        end
        Api.featRefused = refused
        local last = {}
        f:SetScript("OnEvent", function(_, event, ...)
            -- (SPELLS_CHANGED comes in bursts, with every stance or form: one line every 2 s)
            local now = GetTime()
            if last[event] and now - last[event] < 2 then return end
            last[event] = now
            local args = {}
            for i = 1, math.min(select("#", ...), 4) do args[#args + 1] = Show((select(i, ...))) end
            local ranks, sum = F.Ranks(), 0
            for node, r in pairs(ranks or {}) do if node ~= "config" then sum = sum + r end end
            ns.Log("Api", "feat event %s (%s) unspent %s, level %s, config %s, ranks %d", event, table.concat(args, ", "),
                Try(GetNumUnspentTalents or error), Try(UnitLevel, "player"), tostring(ranks and ranks.config), sum)
        end)
    end
    out.refused = Api.featRefused
    return ("%d of %d spells known to the client, %d known here; %d quests (%d completed, %d copies); %d strings; events refused: %s; watching this session")
        :format(#spells - unknownSpells, #spells, known, #out.quests, out.completed, #out.copies, #out.strings,
            #out.refused > 0 and table.concat(out.refused, " ") or "none")
end

------------------------------------------------------------------------------
-- transport (2026-11-12, by name only: zeppelins and boats, for the pets that love or fear them). The client
-- has no API for being on a transport, so this watches what a ride looks like from the inside: every zone,
-- subzone and world change (with the map, its continent, the instance, a flight path or not), the spells
-- you cast (a hearthstone or a portal is no ride), and while it's on, a sample every SAMPLE seconds (zone,
-- position, speed: on a ship you move without moving). All to the debug log ("transport ..."), this
-- session. Ride a zeppelin or a boat with it on, then /reload.
Api.TRANSPORT_EVENTS = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "PLAYER_ENTERING_WORLD",
    "PLAYER_LEAVING_WORLD", "LOADING_SCREEN_ENABLED", "LOADING_SCREEN_DISABLED", "NEW_WMO_CHUNK",
    "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }
Api.TRANSPORT_SAMPLE = 5
function Api.Where()
    local function P(fn, ...) local ok, v = pcall(fn, ...); return ok and ns.Plain(v) or nil end
    local map = C_Map and P(C_Map.GetBestMapForUnit, "player")
    local chain, id = {}, map
    for _ = 1, 6 do
        local info = id and C_Map and P(C_Map.GetMapInfo, id)
        if type(info) ~= "table" then break end
        chain[#chain + 1] = ("%s:%s(%s)"):format(tostring(info.mapID), tostring(info.name), tostring(info.mapType))
        id = info.parentMapID
    end
    local x, y
    local okP, pos = pcall(function() return map and C_Map.GetPlayerMapPosition(map, "player") end)
    if okP and pos and pos.GetXY then x, y = pos:GetXY() end
    local inst = { pcall(GetInstanceInfo) }
    return ("zone %q sub %q real %q mini %q | map %s | at %s,%s | speed %s | taxi %s flying %s mounted %s swim %s "
        .. "indoors %s | instance %s %s"):format(
        tostring(P(GetZoneText)), tostring(P(GetSubZoneText)), tostring(P(GetRealZoneText)), tostring(P(GetMinimapZoneText)),
        table.concat(chain, " < "), x and ("%.3f"):format(x) or "?", y and ("%.3f"):format(y) or "?",
        tostring(P(GetUnitSpeed, "player")), tostring(P(UnitOnTaxi, "player")), tostring(P(IsFlying)), tostring(P(IsMounted)),
        tostring(P(IsSwimming)), tostring(P(IsIndoors)), tostring(inst[2]), tostring(inst[3]))
end
function S.transport(out)
    out.now = Api.Where()
    if Api.transportWatch then return "watching already: " .. out.now end
    local f = CreateFrame("Frame")
    Api.transportWatch = f
    local refused = {}
    for _, e in ipairs(Api.TRANSPORT_EVENTS) do
        if not pcall(f.RegisterEvent, f, e) then refused[#refused + 1] = e end
    end
    pcall(f.RegisterUnitEvent, f, "UNIT_SPELLCAST_SUCCEEDED", "player")
    out.refused = refused
    f:SetScript("OnEvent", function(_, event, a, b, c)
        if event == "UNIT_SPELLCAST_SUCCEEDED" then
            local id = ns.Plain(c)
            return ns.Log("Api", "transport cast %s %s", tostring(id), tostring(ns.SpellName(id)))
        end
        ns.Log("Api", "transport %s (%s, %s) %s", event, Show(a), Show(b), Api.Where())
    end)
    local function Sample()
        ns.Log("Api", "transport sample %s", Api.Where())
        C_Timer.After(Api.TRANSPORT_SAMPLE, Sample)
    end
    C_Timer.After(Api.TRANSPORT_SAMPLE, Sample)
    return ("watching this session (events refused: %s): %s"):format(#refused > 0 and table.concat(refused, " ") or "none", out.now)
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
    -- "<section> [its argument]": a section by name may take one (lengths: all, or species ids).
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    local list = word ~= "" and { word } or self.ORDER
    rest = rest ~= "" and rest or nil
    for _, name in ipairs(list) do
        local fn = S[name]
        if not fn then return ns.Print("api probe: sections are " .. table.concat(self.ORDER, " ") .. " (and holidays, lengths [all|ids], petframe, meter, feats, transport)") end
        local out = {}
        db[name] = out
        local ok, summary = pcall(fn, out, rest)
        summary = ok and summary or ("failed: " .. tostring(summary))
        ns.Log("Api", "%s: %s", name, tostring(summary))
        ns.Print(("api probe %s: %s"):format(name, tostring(summary)))
    end
    ns.Print("api probe: saved in DyreparkenDebugDB.api on /reload")
end
