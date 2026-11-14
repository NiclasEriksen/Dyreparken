-- The harness's foundations: the addon's name, the stub client's known events and species,
-- reading the TOC, compiling the addon's files once (Load), a clean Lua 5.1 global
-- environment with WoW's extras (NewEnv), and the wire codec (H.Encode, P.DecodeWire).
local H, P = ...

local ADDON = "Dyreparken"
local LATENCY = 0.05
H.ADDON = ADDON

-- Species as Forever's journal names them (5159 and 46 probed on 1.60.1).
H.SPECIES = {
    [5159] = "Panda Cub", [46] = "White Kitten", [40] = "Bombay Cat", [41] = "Cornish Rex Cat",
    [68] = "Great Horned Owl", [72] = "Snowshoe Rabbit", [84] = "Westfall Chicken", [90] = "Hyacinth Macaw",
    [7] = "Ancona Chicken", [42] = "Black Tabby Cat",
}
-- A value the client hides from addons (Forever "secret values").
H.SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })

-- What Forever doesn't have (docs/FOREVER_API.md, "Missing"): the stub client must lack it too
-- (01_core checks), so the addon can't come to rely on it. Keep this in step with the doc.
-- (UnitStandState is missing too, but still stubbed: an open question, docs/REFACTOR.md Q11.)
H.MISSING = {
    globals = { "GetSpellInfo", "GetItemInfo", "UnitAura", "GetMerchantItemInfo", "GetSpecialization",
        "GetItemCount", "GetContainerNumSlots", "GetNumFactions", "GetWatchedFactionInfo", "GetNumSkillLines",
        "GetSkillLineInfo", "GetZonePVPInfo", "GetNumAddOns", "IsCurrentSpell", "IsAutoRepeatSpell",
        "CombatLogGetCurrentEventInfo", "require", "dofile", "loadfile", "io" },
    fields = { { "C_Calendar", "GetDate" } },
    events = { "COMBAT_LOG_EVENT_UNFILTERED", "PLAYER_TARGET_SET_ATTACKING" },
}

-- Events the stub client knows. Registering anything else throws, like the
-- real client does, which catches typos.
local KNOWN_EVENTS = {}
for e in ([[ADDON_LOADED PLAYER_LOGIN PLAYER_LOGOUT PLAYER_ENTERING_WORLD PLAYER_LEAVING_WORLD
    PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED PLAYER_MOUNT_DISPLAY_CHANGED CHAT_MSG_ADDON
    GUILD_ROSTER_UPDATE PLAYER_GUILD_UPDATE GROUP_ROSTER_UPDATE COMPANION_UPDATE BAG_UPDATE_DELAYED
    UNIT_AURA ZONE_CHANGED_NEW_AREA PLAYER_TARGET_CHANGED UPDATE_MOUSEOVER_UNIT CHAT_MSG_GUILD
    CHAT_MSG_PARTY CHAT_MSG_RAID NEW_PET_ADDED PET_JOURNAL_LIST_UPDATE
    ENCOUNTER_START ENCOUNTER_END BOSS_KILL PLAYER_PVP_KILLS_CHANGED QUEST_TURNED_IN UNIT_SPELLCAST_SUCCEEDED
    PLAYER_DEAD PLAYER_ALIVE PLAYER_UNGHOST MIRROR_TIMER_START PLAYER_LEVEL_UP PLAYER_FLAGS_CHANGED
    CHAT_MSG_TEXT_EMOTE CHAT_MSG_SKILL CHAT_MSG_COMBAT_FACTION_CHANGE
    NAME_PLATE_UNIT_ADDED NAME_PLATE_UNIT_REMOVED FORBIDDEN_NAME_PLATE_UNIT_ADDED
    PLAYER_STARTED_MOVING PLAYER_STOPPED_MOVING CHAT_MSG_EMOTE PLAYER_CONTROL_GAINED
    CHAT_MSG_MONEY LOADING_SCREEN_ENABLED UNIT_HEALTH SPELLS_CHANGED ACTIVE_TALENT_GROUP_CHANGED TRAIT_CONFIG_UPDATED PLAYER_INTERACTION_MANAGER_FRAME_SHOW CHAT_MSG_SYSTEM CHAT_MSG_LOOT UI_ERROR_MESSAGE LOOT_OPENED UPDATE_SHAPESHIFT_FORM CALENDAR_UPDATE_EVENT_LIST UI_INFO_MESSAGE PET_BATTLE_OPENING_START PET_BATTLE_CLOSE
    PLAYER_ENTER_COMBAT PLAYER_LEAVE_COMBAT START_AUTOREPEAT_SPELL STOP_AUTOREPEAT_SPELL UNIT_COMBAT
    UNIT_PET UNIT_HAPPINESS ZONE_CHANGED UNIT_FACTION]]):gmatch("%S+") do
    KNOWN_EVENTS[e] = true
end

------------------------------------------------------------------------------
-- Sources and the TOC
------------------------------------------------------------------------------
local sources = {}
local function Source(path)
    if not sources[path] then
        local f = assert(io.open(path, "rb"), "missing " .. path)
        sources[path] = f:read("*a")
        f:close()
    end
    return sources[path]
end

-- files: every file, as a git checkout loads them; release: without the
-- #@do-not-package@ blocks, which the packager strips (Dev/).
local TOC = { files = {}, release = {}, meta = {} }
local packaged = true
for line in Source(ADDON .. ".toc"):gmatch("[^\r\n]+") do
    local k, v = line:match("^##%s*([^:]+):%s*(.-)%s*$")
    if k then
        TOC.meta[k] = v
    elseif line:match("^#@do%-not%-package@") then
        packaged = false
    elseif line:match("^#@end%-do%-not%-package@") then
        packaged = true
    elseif not line:match("^%s*#") and line:match("%S") then
        local path = (line:gsub("\\", "/"))
        TOC.files[#TOC.files + 1] = path
        if packaged then TOC.release[#TOC.release + 1] = path end
    end
end
assert(packaged, "a #@do-not-package@ block without its end")
H.TOC = TOC

-- Compiled once per path, then loaded from bytecode: every login loads every file, and
-- compiling them again was most of the suite's time. The line info survives, so coverage
-- and error messages are the same.
local compiled = {}
local function Load(env, path, ...)
    if not compiled[path] then
        compiled[path] = string.dump(assert(loadstring(Source(path), "@" .. path)))
    end
    local chunk = assert(loadstring(compiled[path], "@" .. path))
    setfenv(chunk, env)
    return chunk(...)
end

------------------------------------------------------------------------------
-- A clean global environment with Lua 5.1 and WoW's Lua extras
------------------------------------------------------------------------------
local STD = { "assert", "error", "ipairs", "next", "pairs", "pcall", "rawequal", "rawget", "rawset", "select",
    "setmetatable", "getmetatable", "tonumber", "tostring", "type", "unpack", "xpcall", "loadstring",
    "setfenv", "getfenv", "string", "table", "math", "coroutine", "bit", "_VERSION", "collectgarbage" }

local function strsplit(delim, s, pieces)
    local out, pos = {}, 1
    while true do
        if pieces and #out == pieces - 1 then out[#out + 1] = s:sub(pos); break end
        local a, b = s:find("[" .. delim:gsub("%p", "%%%0") .. "]", pos)
        if not a then out[#out + 1] = s:sub(pos); break end
        out[#out + 1] = s:sub(pos, a - 1)
        pos = b + 1
    end
    return unpack(out)
end

local function CopyTable(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end
    return c
end
H.CopyTable = CopyTable

local function NewEnv()
    local env = {}
    for _, k in ipairs(STD) do env[k] = _G[k] end
    env.os = { time = os.time, date = os.date, clock = os.clock }
    env._G = env
    env.strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
    env.strsplit = strsplit
    env.wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.CopyTable = CopyTable
    env.tinsert, env.tremove, env.sort = table.insert, table.remove, table.sort
    env.strsub, env.strlen, env.strbyte, env.strchar = string.sub, string.len, string.byte, string.char
    env.strfind, env.strmatch, env.strlower, env.strupper = string.find, string.match, string.lower, string.upper
    env.strrep, env.format, env.gsub = string.rep, string.format, string.gsub
    env.floor, env.ceil, env.min, env.max, env.abs = math.floor, math.ceil, math.min, math.max, math.abs
    return env
end

-- The libraries, loaded once more for the harness itself to decode traffic.
local libEnv = NewEnv()
libEnv.GetTime = function() return 0 end
for _, p in ipairs({ "Libs/LibStub/LibStub.lua", "Libs/LibSerialize/LibSerialize.lua", "Libs/LibDeflate/LibDeflate.lua" }) do
    Load(libEnv, p)
end
local LibSerialize, LibDeflate = libEnv.LibStub("LibSerialize"), libEnv.LibStub("LibDeflate")
local function DecodeWire(data)
    local c = LibDeflate:DecodeForWoWAddonChannel(data)
    local s = c and LibDeflate:DecompressDeflate(c)
    if not s then return nil end
    local ok, msg = LibSerialize:Deserialize(s)
    return ok and msg or nil
end
-- Encode a message exactly like Comm does (for forged/foreign traffic).
function H.Encode(msg)
    return LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(LibSerialize:Serialize(msg)))
end

P.ADDON, P.LATENCY, P.KNOWN_EVENTS = ADDON, LATENCY, KNOWN_EVENTS
P.Source, P.TOC, P.Load, P.NewEnv, P.CopyTable, P.DecodeWire = Source, TOC, Load, NewEnv, CopyTable, DecodeWire
