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
-- A secret table: type() says "table", issecretvalue doesn't know it, issecrettable does, and it can't be walked
-- or read (Forever 2026-11-14, UNIT_AURA's addedAuras in a fight).
H.SECRET_TABLE = setmetatable({}, { __tostring = function() return "<secret table>" end,
    __index = function() error("attempt to index a secret table", 2) end })

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
    CHAT_MSG_MONEY LOADING_SCREEN_ENABLED UNIT_HEALTH SPELLS_CHANGED ACTIVE_TALENT_GROUP_CHANGED TRAIT_CONFIG_UPDATED PLAYER_INTERACTION_MANAGER_FRAME_SHOW CHAT_MSG_SYSTEM CHAT_MSG_LOOT UI_ERROR_MESSAGE LOOT_OPENED UPDATE_SHAPESHIFT_FORM CALENDAR_UPDATE_EVENT_LIST UI_INFO_MESSAGE PET_BATTLE_OPENING_START PET_BATTLE_CLOSE PLAYER_UPDATE_RESTING
    PLAYER_ENTER_COMBAT PLAYER_LEAVE_COMBAT START_AUTOREPEAT_SPELL STOP_AUTOREPEAT_SPELL UNIT_COMBAT
    UNIT_PET UNIT_HAPPINESS ZONE_CHANGED UNIT_FACTION COMBAT_TEXT_UPDATE]]):gmatch("%S+") do
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

-- A file as a release tag had it (git show), for a client of that release (Client opts.from): the
-- real old code, to test that newer clients still get along with it.
local function SourceAt(tag, path)
    local id = tag .. ":" .. path
    if not sources[id] then
        assert(tag:find("^v[%w%.%-]+$"), "a release tag: " .. tostring(tag))
        local p = assert(io.popen(("git show '%s:%s' 2>/dev/null"):format(tag, path), "r"))
        local text = p:read("*a")
        p:close()
        assert(text ~= "", ("%s isn't in git (a shallow clone without tags? fetch-depth: 0)"):format(id))
        sources[id] = text
    end
    return sources[id]
end

-- files: every file, as a git checkout loads them; release: without the
-- #@do-not-package@ blocks, which the packager strips (Dev/).
local function ParseTOC(text)
    local toc = { files = {}, release = {}, meta = {} }
    local packaged = true
    for line in text:gmatch("[^\r\n]+") do
        local k, v = line:match("^##%s*([^:]+):%s*(.-)%s*$")
        if k then
            toc.meta[k] = v
        elseif line:match("^#@do%-not%-package@") then
            packaged = false
        elseif line:match("^#@end%-do%-not%-package@") then
            packaged = true
        elseif not line:match("^%s*#") and line:match("%S") then
            local path = (line:gsub("\\", "/"))
            toc.files[#toc.files + 1] = path
            if packaged then toc.release[#toc.release + 1] = path end
        end
    end
    assert(packaged, "a #@do-not-package@ block without its end")
    return toc
end
local TOC = ParseTOC(Source(ADDON .. ".toc"))
H.TOC = TOC
local tocs = {}
local function TOCAt(tag)
    tocs[tag] = tocs[tag] or ParseTOC(SourceAt(tag, ADDON .. ".toc"))
    return tocs[tag]
end

-- Compiled once per path, then loaded from bytecode: every login loads every file, and
-- compiling them again was most of the suite's time. The line info survives, so coverage
-- and error messages are the same. tag: a release's copy (SourceAt), named "@<tag>/<path>" so
-- coverage never counts it as ours.
local compiled = {}
local function Load(env, path, tag, ...)
    local id = tag and (tag .. "/" .. path) or path
    if not compiled[id] then
        local text = tag and SourceAt(tag, path) or Source(path)
        compiled[id] = string.dump(assert(loadstring(text, "@" .. id)))
    end
    local chunk = assert(loadstring(compiled[id], "@" .. id))
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

-- LibDeflate, memoized (2026-11-19): every message is compressed by its sender and decompressed by each
-- receiver and by DecodeWire, in pure Lua, and that was over half of a coverage run's line hooks. Its functions
-- are pure, so one cache by input, shared by every client, gives the same bytes on the wire. Not
-- LibSerialize's Deserialize: it returns fresh tables. (A release's own copy, opts.from, keeps a cache of its
-- own: its LibDeflate may differ.)
local deflateCaches, cached = {}, 0
local MEMO = { "CompressDeflate", "DecompressDeflate", "EncodeForWoWAddonChannel", "DecodeForWoWAddonChannel", "Adler32" }
local function Pack(...) return { n = select("#", ...), ... } end
local function Memoize(lib, id)
    local caches = deflateCaches[id or ""] or {}
    deflateCaches[id or ""] = caches
    for _, name in ipairs(MEMO) do
        local fn, cache = lib[name], caches[name] or {}
        caches[name] = cache
        lib[name] = function(self, input, more)
            if more ~= nil or type(input) ~= "string" then return fn(self, input, more) end
            local r = cache[input]
            if not r then
                if cached > 50000 then
                    for _, c in pairs(deflateCaches) do for _, t in pairs(c) do for k in pairs(t) do t[k] = nil end end end
                    cached = 0
                end
                r = Pack(fn(self, input))
                cache[input] = r
                cached = cached + 1
            end
            return unpack(r, 1, r.n)
        end
    end
end
Memoize(LibDeflate)

-- Every client gets the harness's LibDeflate (2026-11-19): loading it builds its tables in pure Lua, a big
-- share of each client's start. It keeps no state between calls, so one copy serves all.
local DEFLATE_MINOR = libEnv.LibStub.minors.LibDeflate
local function ShareDeflate(env)
    local lib = env.LibStub:NewLibrary("LibDeflate", DEFLATE_MINOR)
    for k, v in pairs(LibDeflate) do lib[k] = v end
end
local function DecodeWire(data)
    local c = LibDeflate:DecodeForWoWAddonChannel(data)
    local s = c and LibDeflate:DecompressDeflate(c)
    if not s then return nil end
    local ok, msg = LibSerialize:Deserialize(s)
    return ok and msg or nil
end
-- Encode a message exactly like Comm does (for forged/foreign traffic). level: LibDeflate's (0 stores it
-- uncompressed: still a deflate stream every client reads, at a fraction of the cost; the fuzzer's).
function H.Encode(msg, level)
    local s = LibSerialize:Serialize(msg)
    return LibDeflate:EncodeForWoWAddonChannel(LibDeflate:CompressDeflate(s, level and { level = level } or nil))
end

P.ADDON, P.LATENCY, P.KNOWN_EVENTS = ADDON, LATENCY, KNOWN_EVENTS
P.Source, P.TOC, P.TOCAt, P.Load, P.NewEnv, P.CopyTable, P.DecodeWire = Source, TOC, TOCAt, Load, NewEnv, CopyTable, DecodeWire
P.Memoize, P.ShareDeflate = Memoize, ShareDeflate
