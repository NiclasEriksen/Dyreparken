-- Headless smoke test: loads every TOC file in order with stubbed WoW globals,
-- fires ADDON_LOADED and PLAYER_LOGIN, round-trips a comm message and runs
-- some slash commands. Catches load-order mistakes, nil globals and runtime
-- errors in init paths without starting the game.
--   luajit tools/smoke.lua        (run from the addon folder; tools/check.sh runs it)
-- The stubs are deliberately minimal: add one when the addon starts using a
-- new API, and keep its behavior realistic (see docs/FOREVER_API.md).

local ADDON = "Dyreparken"
local printed = {}

-- Frames ---------------------------------------------------------------------
local frames = {}
local function NewFrame()
    local f = { events = {}, scripts = {}, shown = true }
    function f:RegisterEvent(e)
        if e:find("BOGUS") then error("Attempt to register unknown event \"" .. e .. "\"") end
        self.events[e] = true
    end
    function f:UnregisterEvent(e) self.events[e] = nil end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:HookScript(k, fn) self.scripts[k] = fn end
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetScript(k) return self.scripts[k] end
    frames[#frames + 1] = f
    return f
end
CreateFrame = function() return NewFrame() end
local function Fire(event, ...)
    for _, f in ipairs(frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

-- Globals ----------------------------------------------------------------------
local now = 1000
local timers = {}
GetTime = function() return now end
GetServerTime = function() return 1790000000 + math.floor(now) end
time = os.time; date = os.date
geterrorhandler = function() return function(e) error(e, 0) end end
hooksecurefunc = function() end
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
CopyTable = function(t)
    local c = {}
    for k, v in pairs(t) do c[k] = type(v) == "table" and CopyTable(v) or v end
    return c
end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
strsplit = function(d, s) local r = {} for p in (s .. d):gmatch("(.-)" .. d) do r[#r + 1] = p end return unpack(r) end
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m; print("  chat: " .. m) end }
SlashCmdList = {}
InCombatLockdown = function() return false end
-- Forever: the second value is the surname, not the realm.
UnitFullName = function() return "Tester", "Surname" end
GetNormalizedRealmName = function() return "Realm" end
GetRealmName = GetNormalizedRealmName
IsInGuild = function() return true end
GetGuildInfo = function() return "Dyreparken", "Member", 3, nil end
IsInGroup = function() return false end
IsInRaid = function() return false end
UnitIsGroupLeader = function() return false end
UnitIsGroupAssistant = function() return false end
C_Timer = { After = function(s, fn) timers[#timers + 1] = { at = now + s, fn = fn } end,
    NewTicker = function() return { Cancel = function() end } end }
C_CVar = { GetCVar = function() return "1" end, SetCVar = function() end }
local loaded = { [ADDON] = true }
local meta = { Version = "0.0.1", ["X-Protocol"] = "1" }
C_AddOns = {
    GetAddOnMetadata = function(_, k) return meta[k] end,
    IsAddOnLoaded = function(n) return loaded[n] or false end,
}
local sentAddon = {}
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(p) assert(#p <= 16, "prefix too long") return true end,
    SendAddonMessage = function(prefix, text, chan, target)
        assert(#text <= 255, "addon message over 255 bytes")
        sentAddon[#sentAddon + 1] = { prefix, text, chan, target }
        return 0
    end,
    IsAddonMessagePrefixRegistered = function() return true end,
}
Enum = { SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3 } }
C_PetJournal = {
    GetSummonedPetGUID = function() return "BattlePet-0-00000008B2A2" end,
    GetOwnedPetIDs = function() return { "BattlePet-0-000000000001" } end,
    -- Real Forever shape (probed 2026-11-06): Panda Cub
    GetPetInfoByPetID = function() return 5159, nil, 1, 0, 1, 146955, false, "Panda Cub", 7831521, 5, 272330, "" end,
    GetNumPets = function() return 1, 1 end,
    SummonPetByGUID = function() end,
}
GetFramerate = function() return 60 end
UnitName = function() return "Tester", "Surname" end
UnitGUID = function() return "Player-0000-00000001" end
GetPlayerInfoByGUID = function() return "Warrior", "WARRIOR", "Human", "Human", 2, "Tester", "" end
GetAutoCompleteRealms = function() return { "Realm", "OtherRealm" } end
GetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end
Ambiguate = function(n) return n end

-- Load TOC ---------------------------------------------------------------------
local ns = {}
local toc = assert(io.open(ADDON .. ".toc")):read("*a")
for line in toc:gmatch("[^\r\n]+") do
    if not line:match("^%s*#") and line:match("%S") then
        local path = line:gsub("\\", "/")
        local chunk = assert(loadfile(path))
        chunk(ADDON, ns)
    end
end

Fire("ADDON_LOADED", ADDON)
Fire("PLAYER_LOGIN")
Fire("PLAYER_ENTERING_WORLD", true, false)
now = now + 11
for _, t in ipairs(timers) do if t.at <= now then t.fn() end end
-- Let ChatThrottleLib flush its queue.
for _ = 1, 20 do
    now = now + 0.5
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.5) end end
end
assert(#sentAddon >= 1, "HELLO was not sent")

-- Comm round trip, including a multi-chunk message.
local got
ns.Comm:Register("TEST", function(msg, sender) got = { msg = msg, sender = sender } end)
local big = {}
for i = 1, 200 do big[i] = "pet" .. i .. string.char(65 + i % 26) end
local before = #sentAddon
ns.Comm:Send("TEST", { list = big }, "GUILD")
for _ = 1, 400 do
    now = now + 0.5
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.5) end end
end
assert(#sentAddon - before > 1, "big message should be chunked")
for i = before + 1, #sentAddon do
    local m = sentAddon[i]
    Fire("CHAT_MSG_ADDON", m[1], m[2], m[3], "Other Person")
end
assert(got and got.sender == "Other Person-Realm" and #got.msg.list == 200 and got.msg.list[200] == big[200],
    "multi-chunk round trip failed")

-- Identity (Forever names have surnames; senders omit our own realm).
assert(ns.PlayerKey() == "Tester Surname-Realm", ns.PlayerKey())
assert(ns.NormalizeName("Tester Surname") == ns.PlayerKey())
assert(ns.NormalizeName("Ola Nord-OtherRealm") == "Ola Nord-OtherRealm")
assert(ns.NormalizeName("Kari Berg-Hansen") == "Kari Berg-Hansen-Realm", "hyphenated surname")
assert(ns.DisplayName("Tester Surname-Realm") == "Tester Surname")
-- Our own echo must be ignored.
local echoed
ns.Comm:Register("ECHO", function() echoed = true end)
local n0 = #sentAddon
ns.Comm:Send("ECHO", {}, "GUILD")
for _ = 1, 20 do
    now = now + 0.5
    for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.5) end end
end
for i = n0 + 1, #sentAddon do local m = sentAddon[i]; Fire("CHAT_MSG_ADDON", m[1], m[2], m[3], "Tester Surname") end
assert(not echoed, "own message was not filtered")

-- Slash commands.
SlashCmdList.DYREPARKEN("")
SlashCmdList.DYREPARKEN("debug on")
SlashCmdList.DYREPARKEN("probe")
assert(ns.Pets:KeyOf("x") == "s:5159")
assert(ns.Registry:ValidNickname("Mr. Whiskers"))
assert(not ns.Registry:ValidNickname(string.rep("a", 21)))
assert(ns.CompareVersions("0.0.10", "0.0.9") == 1)
assert(#DyreparkenDebugDB.lines > 0 or DyreparkenDebugDB.lines.head > 0, "debug log empty")

print("SMOKE OK (" .. (#sentAddon) .. " addon messages, " .. #printed .. " chat lines)")
