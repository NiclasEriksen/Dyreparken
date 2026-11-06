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
    function f:IsShown() return self.shown end
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:GetScript(k) return self.scripts[k] end
    function f:HookScript(k, fn)
        local old = self.scripts[k]
        self.scripts[k] = old and function(...) old(...); fn(...) end or fn
    end
    function f:IsVisible() return self.shown end
    function f:SetSize() end
    function f:SetPoint() end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text end
    function f:Enable() self.enabled = true end
    function f:Disable() self.enabled = false end
    function f:SetMotionScriptsWhileDisabled() end
    function f:Click() if self.scripts.OnClick then self.scripts.OnClick(self) end end
    function f:CreateTexture()
        local t = { shown = true }
        function t:SetSize() end
        function t:SetPoint() end
        function t:SetTexture(x) self.tex = x end
        function t:Show() self.shown = true end
        function t:Hide() self.shown = false end
        return t
    end
    function f:CreateFontString()
        local t = {}
        function t:SetPoint() end
        function t:SetJustifyH() end
        function t:SetText(x) self.text = x end
        return t
    end
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
local dayOffset = 0 -- tests jump days ahead with this
GetServerTime = function() return 1790000000 + math.floor(now) + dayOffset * 86400 end
time = os.time; date = os.date
geterrorhandler = function() return function(e) error(e, 0) end end
hooksecurefunc = function(a, b, c)
    local t, name, fn = _G, a, b
    if type(a) == "table" then t, name, fn = a, b, c end
    local old = t[name]
    t[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end
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
StaticPopupDialogs = {}
StaticPopup_Show = function() end
ACCEPT, CANCEL = "Accept", "Cancel"
GameTooltip = { IsOwned = function() return false end, SetOwner = function() end, SetText = function() end,
    AddLine = function() end, Show = function() end, Hide = function() end }
InCombatLockdown = function() return false end
IsMounted = function() return false end
UnitOnTaxi = function() return false end
UnitIsDeadOrGhost = function() return false end
UnitExists = function() return false end
-- Forever: the second value is the surname, not the realm.
UnitFullName = function() return "Tester", "Surname" end
GetNormalizedRealmName = function() return "Realm" end
GetRealmName = GetNormalizedRealmName
IsInGuild = function() return true end
-- Roster: rows of { name, daysOffline }. Forever roster name format unverified.
local roster = { { "Tester Surname", 0 }, { "Ola Nord", 0 }, { "Kari Berg", 0 } }
GetNumGuildMembers = function() return #roster, #roster end
GetGuildRosterInfo = function(i) return roster[i] and roster[i][1] end
GetGuildRosterLastOnline = function(i) local d = roster[i] and roster[i][2] or 0; if d == 0 then return nil end return 0, 0, d, 0 end
C_GuildInfo = { GuildRoster = function() C_Timer.After(0.1, function() Fire("GUILD_ROSTER_UPDATE") end) end }
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
    GetPetInfoBySpeciesID = function(sid)
        if sid == 5159 then return "Panda Cub", 7831521, 5, 272330 end
        return "Species " .. sid, 1
    end,
}
GetFramerate = function() return 60 end
UnitName = function() return "Tester", "Surname" end
UnitGUID = function() return "Player-0000-00000001" end
GetPlayerInfoByGUID = function() return "Warrior", "WARRIOR", "Human", "Human", 2, "Tester", "" end
GetAutoCompleteRealms = function() return { "Realm", "OtherRealm" } end
GetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end
Ambiguate = function(n) return n end

-- Saved data as schema 1 left it, to exercise migrations.
DyreparkenDB = { schema = 1, guilds = { ["Dyreparken-CAMWOWEU4Realm5PvE"] = { pets = {}, members = {} } } }

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
for i = #timers, 1, -1 do local t = timers[i]; if t.at <= now then table.remove(timers, i); t.fn() end end
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
assert(got and got.sender == "Other Person" and #got.msg.list == 200 and got.msg.list[200] == big[200],
    "multi-chunk round trip failed")

-- Identity: "First Surname", realms ignored.
assert(ns.PlayerKey() == "Tester Surname", ns.PlayerKey())
assert(ns.NormalizeName("Tester Surname") == ns.PlayerKey())
assert(ns.NormalizeName("Tester Surname-Realm") == ns.PlayerKey())
assert(ns.NormalizeName("Ola Nord-CAMWOWEU4Realm5PvE") == "Ola Nord", "unknown realm by pattern")
assert(ns.NormalizeName("Kari Berg-Hansen") == "Kari Berg-Hansen", "hyphenated surname")
-- Migration 2 rekeyed guilds without realm.
assert(ns.DB:Guild() == DyreparkenDB.guilds["Dyreparken"])
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

-- Registry and sync ------------------------------------------------------------
-- Advance time: ChatThrottleLib's OnUpdate always, C_Timer callbacks unless
-- noTimers (message delivery shouldn't fire our own delayed answers).
local function Flush(seconds, noTimers)
    for _ = 1, (seconds or 10) * 2 do
        now = now + 0.5
        for _, f in ipairs(frames) do if f.scripts.OnUpdate then f.scripts.OnUpdate(f, 0.5) end end
        if noTimers then break end
        local due = {}
        for i = #timers, 1, -1 do if timers[i].at <= now then due[#due + 1] = table.remove(timers, i) end end
        for i = #due, 1, -1 do due[i].fn() end
    end
end
-- Deliver a message as if a peer sent it: encode it with our own Comm, then
-- feed the chunks back in under the peer's name.
local function FromPeer(sender, kind, msg)
    local n0 = #sentAddon
    -- Mute the log while encoding, so the peer's message isn't counted as ours.
    local log = ns.Log
    ns.Log = function() end
    ns.Comm:Send(kind, msg, "GUILD")
    ns.Log = log
    -- CTL sends in OnUpdate; a few ticks drain it without firing timers.
    for _ = 1, 60 do Flush(1, true) end
    -- Only our new message's chunks: anything else we sent meanwhile is ours.
    for i = n0 + 1, #sentAddon do
        local m = sentAddon[i]
        Fire("CHAT_MSG_ADDON", m[1], m[2], m[3], sender)
    end
end
local function Sent(kind)
    -- Kinds we sent, decoded from the outgoing chunks is overkill: count via log.
    local n = 0
    for i = 1, DyreparkenDebugDB.lines.head do
        local line = DyreparkenDebugDB.lines[i]
        if line and line:find("\t-> " .. kind .. " ", 1, true) then n = n + 1 end
    end
    return n
end
local function Printed(pattern)
    for i = #printed, math.max(1, #printed - 5), -1 do if printed[i]:find(pattern) then return true end end
    return false
end

ns.Debug:SetEnabled(true)
local R = ns.Registry
local PANDA = "s:5159"
ns.DB:Guild() -- create guild tables

-- 1. Claim the summoned pet.
SlashCmdList.DYREPARKEN("claim")
assert(R:MyPet() == PANDA, "claim failed")
assert(Printed("Reserved Panda Cub"), "no claim message")
Flush(5)
assert(Sent("UPD") >= 1, "UPD not sent")

-- 2. A later claim by a peer loses.
local mine = R:MyRecord()
FromPeer("Ola Nord", "UPD", { r = { k = PANDA, at = mine.at + 5, ts = mine.at + 5 } })
assert(R:Holder(PANDA) == "Tester Surname", "later claim should lose")

-- 3. An earlier claim by a peer wins, and we withdraw ours with a notice.
FromPeer("Kari Berg", "UPD", { r = { k = PANDA, at = mine.at - 100, ts = mine.at - 100 } })
assert(R:Holder(PANDA) == "Kari Berg", "earlier claim should win")
assert(not R:MyPet() and R:MyRecord().k == nil, "we should have released")
assert(Printed("before you did"), "no lost-race notice")

-- 4. A UPD only updates the sender's own record, newest ts wins.
FromPeer("Ola Nord", "UPD", { r = { k = "s:1", at = mine.at + 10, ts = mine.at + 10 } })
-- An older copy of her record (lower ts) is ignored.
FromPeer("Ola Nord", "UPD", { r = { k = "s:2", at = 1, ts = 1 } })
assert(R:Holder("s:1") == "Ola Nord")

-- 5. Garbage is ignored.
FromPeer("Ola Nord", "UPD", { r = { k = 5, at = "x" } })
FromPeer("Ola Nord", "SYNC", { r = "nope", l = { ["X"] = "y" }, d = 1 })
assert(R:Holder("s:1") == "Ola Nord")

-- 6. Kari leaves the guild: the roster shows it, a lapse is recorded and shared.
table.remove(roster, 3)
ns.Guild:Refresh(true)
Flush(2)
assert(R:Holder(PANDA) == nil, "lapsed owner should not hold")
assert(Sent("LAPSE") >= 1, "LAPSE not sent")
-- Kari's old record arriving again doesn't revive the claim.
FromPeer("Ola Nord", "SYNC", { r = { ["Kari Berg"] = { k = PANDA, at = mine.at - 100, ts = mine.at - 100 } }, l = {}, d = 0 })
assert(R:Holder(PANDA) == nil, "lapse must stick")

-- 7. Claim again; nickname is locked for 7 days, then allowed.
assert(R:Claim(PANDA), "reclaim failed")
local ok, msg = R:SetNickname("Bambus")
assert(not ok and msg:find("You can name it from"), "nickname should be locked")
dayOffset = 7
ok = R:SetNickname("Bambus")
assert(ok and R:MyRecord().n == "Bambus", "nickname should be set")
assert(not R:SetNickname(string.rep("x", 21)), "too long")
SlashCmdList.DYREPARKEN("nick Mr Bambus")
assert(R:MyRecord().n == "Mr Bambus", "nick via slash keeps case: " .. tostring(R:MyRecord().n))
SlashCmdList.DYREPARKEN("nick")
assert(R:MyRecord().n == nil, "empty nick clears")

-- 8. Sync: a HELLO with another digest makes us answer with SYNC (once).
local before = Sent("SYNC")
FromPeer("Ola Nord", "HELLO", { v = "0.0.1", d = 12345 })
Flush(10)
assert(Sent("SYNC") == before + 1, "expected one SYNC answer")
-- A HELLO with our digest gets no answer.
FromPeer("Ola Nord", "HELLO", { v = "0.0.1", d = ns.Sync:Digest() })
Flush(10)
assert(Sent("SYNC") == before + 1, "no SYNC expected for equal digest")
-- Suppression: we schedule, but someone else's SYNC that matches us cancels ours.
local claims, lapses = R:All()
FromPeer("Ola Nord", "HELLO", { v = "0.0.1", d = 999 })
FromPeer("Kari Berg", "SYNC", { r = claims, l = lapses, d = ns.Sync:Digest() })
Flush(10)
assert(Sent("SYNC") == before + 1, "our SYNC should have been cancelled")

-- 9. Journal UI: load Blizzard_Collections with stub frames and drive it.
PetJournal = CreateFrame("Frame")
PetJournal.ScrollBox = { buttons = {} }
function PetJournal.ScrollBox:ForEachFrame(fn) for _, b in ipairs(self.buttons) do fn(b) end end
PetJournalPetCard = CreateFrame("Frame")
PetJournalSummonButton = CreateFrame("Button")
PetJournal_InitPetButton = function(button, elementData) end
PetJournal_UpdatePetCard = function(self) end
loaded["Blizzard_Collections"] = true
Fire("ADDON_LOADED", "Blizzard_Collections")
local b1 = CreateFrame("Button"); b1.petID = "BattlePet-0-00000008B2A2"; b1.speciesID = 5159; b1.owned = true
local b2 = CreateFrame("Button"); b2.speciesID = 1; b2.owned = false
PetJournal.ScrollBox.buttons = { b1, b2 }
PetJournal_InitPetButton(b1, { index = 1 })
PetJournal_InitPetButton(b2, { index = 2 })
PetJournal.scripts.OnShow(PetJournal)
Flush(2)
PetJournalPetCard.speciesID = 5159
PetJournal_UpdatePetCard(PetJournalPetCard)
b1.scripts.OnEnter(b1); b1.scripts.OnLeave(b1)
local card = ns.JournalUI._card
assert(card.reserve.text == "Release" and card.reserve.shown, "card should offer Release for our pet")
assert(card.status.text:find("Reserved by you"), card.status.text)
card.reserve:Click()
assert(R:Holder(PANDA) == nil, "Release button should release")
assert(card.reserve.text == "Reserve", "card should offer Reserve after release")
card.reserve:Click()
assert(R:Holder(PANDA) == "Tester Surname", "Reserve button should claim")
-- Someone else's pet: no button.
PetJournalPetCard.speciesID = 1
PetJournal_UpdatePetCard(PetJournalPetCard)
assert(not card.reserve.shown and card.status.text:find("Reserved by Ola Nord"), card.status.text)

-- 10. Release.
SlashCmdList.DYREPARKEN("release")
assert(R:Holder(PANDA) == nil and Printed("Released Panda Cub"))
SlashCmdList.DYREPARKEN("list")

-- Slash commands.
SlashCmdList.DYREPARKEN("")
SlashCmdList.DYREPARKEN("debug on")
SlashCmdList.DYREPARKEN("probe")
SlashCmdList.DYREPARKEN("probe more")
assert(ns.Pets:KeyOf("x") == "s:5159")
assert(ns.Registry:ValidNickname("Mr. Whiskers"))
assert(not ns.Registry:ValidNickname(string.rep("a", 21)))
assert(ns.CompareVersions("0.0.10", "0.0.9") == 1)
assert(#DyreparkenDebugDB.lines > 0 or DyreparkenDebugDB.lines.head > 0, "debug log empty")

print("SMOKE OK (" .. (#sentAddon) .. " addon messages, " .. #printed .. " chat lines)")
