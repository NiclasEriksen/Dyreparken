---@class Dyreparken
local ns = select(2, ...)

-- /dp probe watch (2026-11-24, docs/review-2026-11-24): the review's open in-game questions as watches that log
-- what the client really does, this session, to the debug log ("Watch <watch> ..."; read with
-- `luajit tools/log.lua -m Watch`), with a short summary in DyreparkenDebugDB.watch (errors seen, subzones seen,
-- events refused). Listening only: nothing is summoned, set, sent or posted. Off until asked for; all go off
-- after Watch.FOR seconds or "/dp probe watch off". The hooks can't be taken off: they do nothing while off.
--   sit    (AC1, AC3) sitting as you do it: the sit key, the sit emotes, jumps, going AFK, moving after a sit (our
--          guess, "seated", logged so it can be told against what you see); every UI error (type, text, the
--          globals it matches, the pet out then and half a second later); every SummonPetByGUID call (anyone's:
--          the journal's, ours) and the pet a second later. Try: sit (X or /sit) and summon another pet from the
--          journal; the same on a chair; idle until the game marks you AFK; summon twice quickly (the cooldown).
--   craft  (AC2, AC10) the profession window, and while it's open (or the cast says it's a trade skill) each
--          cast's start and end with UnitCastingInfo's returns (isTradeSkill?) and the gap since the last one
--          ended. Try: craft five of something, and summon a pet from the journal halfway.
--   group  (AC8, social 12) ready checks and pull countdowns (DBM, BigWigs, /countdown), and each group member's
--          range as every API gives it (UnitDistanceSquared's two values, UnitInRange, CheckInteractDistance,
--          UnitIsVisible): at a roster change, a ready check, a countdown, every RANGE_EVERY s in a group, and
--          "/dp probe watch range". Try: stand next to a party member, then 20, 50 and 100 yards off.
--   scene  (AC9) cutscenes, movies, vehicles and pet battles: their events, the pet out then and SCENE_AFTER later.
--   pet    (AC4; review Q5, M2) every change of the pet out (COMPANION_UPDATE, against the last read), with what
--          was going on and whether a summon call came just before (none: the game did it); at mounting,
--          landing, loading screens, death and stealth the pet out then and AFTER seconds on: does the game put
--          it away, and bring it back by itself? Try: mount, fly a flight path, hearth, die.
--   spot   (AC6, AC7; review 11-21 C2, D2) every zone and subzone change (the four zone names, the instance's
--          name, type and difficulty), swimming in and out (how fast it flips at a shore), and every subzone
--          seen, per zone, in DyreparkenDebugDB.watch.subzones (for our own subzone lists).
--   jump   (review Q22) after a jump, IsFalling at JUMP_READS seconds: can a landing be read?
---@class Dyreparken.Watch
local Watch = {}
ns.Watch = Watch

Watch.ORDER = { "sit", "craft", "group", "scene", "pet", "spot", "jump" }
Watch.FOR = 3600 -- seconds, then every watch goes off
Watch.MAX = 3000 -- lines a session, every watch together (the log's ring holds 8000)
Watch.AFTER = { 1, 3, 6 } -- seconds after a pet watch moment: the pet out again
Watch.SCENE_AFTER = 2
Watch.ERROR_AFTER = 0.5 -- a UI error: the pet out this long after (a refused summon takes it?)
Watch.CALL_AFTER = 1 -- a summon call: the pet out this long after
Watch.CALL_RECENT = 2 -- a pet change this soon after a call is the call's
Watch.RANGE_EVERY = 20
Watch.JUMP_READS = { 0.3, 1, 2 }
Watch.JUMP_GAP = 2 -- seconds between two jumps read (a bunny-hop run would flood the log)
Watch.ERRORS_KEPT = 60
Watch.SITTING = { "ERR_CANT_DO_THAT_WHILE_SITTING", "ERR_NOT_WHILE_SITTING", "SPELL_FAILED_NOT_STANDING" }
Watch.COOLDOWN = { "ERR_ABILITY_COOLDOWN", "SPELL_FAILED_NOT_READY" }
Watch.SIT_EMOTES = { SIT = true, SLEEP = true, KNEEL = true, LAYDOWN = true, DEAD = true }

Watch.on = {}
local W = {} -- id -> { events = { { event, fn, unit } }, start, stop, t = its timers }
local lines, loading, seated, lastCall = 0, false, false, nil
local sessionT = ns.Timers()

local function Store()
    DyreparkenDebugDB = DyreparkenDebugDB or {}
    local db = DyreparkenDebugDB.watch or {}
    DyreparkenDebugDB.watch = db
    db.refused, db.errors, db.subzones = db.refused or {}, db.errors or {}, db.subzones or {}
    return db
end

local function Log(id, fmt, ...)
    lines = lines + 1
    if lines > Watch.MAX then
        if lines == Watch.MAX + 1 then ns.Log("Watch", "line cap reached (%d): the rest of this session goes unlogged", Watch.MAX) end
        return
    end
    ns.Log("Watch", id .. " " .. fmt, ...)
end

local function Show(v)
    if ns.IsSecret(v) then return "<secret>" end
    if type(v) == "string" then return ("%q"):format(v) end
    return tostring(v)
end
local function Shows(...)
    local out = {}
    for i = 1, select("#", ...) do out[i] = Show((select(i, ...))) end
    return table.concat(out, ", ")
end

-- A yes/no from the client by the function's name: "1", "0", "secret", "err" or "-" (no such function).
local function Flag(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return "-" end
    local ok, v = pcall(fn, ...)
    if not ok then return "err" end
    if ns.IsSecret(v) then return "secret" end
    return v and "1" or "0"
end
-- What a function by its name returns, as text ("-": no such function).
local function Try(name, ...)
    local fn = rawget(_G, name)
    if type(fn) ~= "function" then return "-" end
    local r = { pcall(fn, ...) }
    if not r[1] then return "err" end
    return Shows(unpack(r, 2, table.maxn(r)))
end

function Watch.Pet()
    local ok, guid = pcall(C_PetJournal.GetSummonedPetGUID)
    if not ok then return "err" end
    if ns.IsSecret(guid) then return "<secret>" end
    if not guid then return "none" end
    return tostring(ns.Pets:KeyOf(guid) or guid)
end

function Watch.State()
    return ("mounted %s taxi %s flying %s dead %s ghost %s vehicle %s stealth %s swim %s combat %s afk %s resting %s loading %s seated %s")
        :format(Flag("IsMounted"), Flag("UnitOnTaxi", "player"), Flag("IsFlying"), Flag("UnitIsDeadOrGhost", "player"),
            Flag("UnitIsGhost", "player"), Flag("UnitInVehicle", "player"), Flag("IsStealthed"), Flag("IsSwimming"),
            Flag("InCombatLockdown"), Flag("UnitIsAFK", "player"), Flag("IsResting"), loading and "1" or "0",
            seated and "1" or "0")
end

local function SinceCall()
    return lastCall and ("%.2f s after %s"):format(GetTime() - lastCall.at, lastCall.what) or "no call yet"
end

-- The pet out, again a little later (each moment of a watch: did it go, did it come back?).
local function Later(id, label, secs)
    for _, s in ipairs(secs) do
        W[id].t:After(s, function() Log(id, "%s +%gs: pet %s | %s", label, s, Watch.Pet(), Watch.State()) end)
    end
end

local function Matches(text, names)
    for _, g in ipairs(names) do
        local v = rawget(_G, g)
        if type(v) == "string" and v ~= "" and text == v then return g end
    end
end

------------------------------------------------------------------------------
-- The hooks: installed at the first watch, quiet while their watch is off
------------------------------------------------------------------------------
local hooked
local function Hook(name, fn)
    if type(rawget(_G, name)) ~= "function" then return name .. " missing" end
    hooksecurefunc(name, fn)
end
local function InstallHooks()
    if hooked then return end
    hooked = {}
    local function Call(what)
        return function(guid)
            lastCall = { at = GetTime(), what = what }
            if not (Watch.on.sit or Watch.on.pet) then return end
            local id = Watch.on.sit and "sit" or "pet"
            Log(id, "call %s(%s): pet before %s | %s", what, Show(guid), Watch.Pet(), Watch.State())
            W[id].t:After(Watch.CALL_AFTER, function()
                Log(id, "call %s +%gs: pet %s", what, Watch.CALL_AFTER, Watch.Pet())
            end)
        end
    end
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", Call("SummonPetByGUID"))
    if rawget(C_PetJournal, "SummonRandomPet") then hooksecurefunc(C_PetJournal, "SummonRandomPet", Call("SummonRandomPet")) end
    hooked[#hooked + 1] = Hook("SitStandOrDescendStart", function()
        if not Watch.on.sit then return end
        seated = not seated
        Log("sit", "sit key: seated now %s (a guess: the key toggles) | %s", tostring(seated), Watch.State())
    end)
    hooked[#hooked + 1] = Hook("DoEmote", function(token)
        if not Watch.on.sit then return end
        token = type(token) == "string" and token:upper() or ""
        if Watch.SIT_EMOTES[token] then seated = true
        elseif token == "STAND" then seated = false
        else return end
        Log("sit", "emote %s: seated %s | %s", token, tostring(seated), Watch.State())
    end)
    local lastJump = -math.huge
    hooked[#hooked + 1] = Hook("JumpOrAscendStart", function()
        if Watch.on.sit and seated then
            seated = false
            Log("sit", "jump: stood up")
        end
        if not Watch.on.jump or GetTime() - lastJump < Watch.JUMP_GAP then return end
        lastJump = GetTime()
        local reads = {}
        for i, s in ipairs(Watch.JUMP_READS) do
            W.jump.t:After(s, function()
                reads[i] = ("%gs %s"):format(s, Flag("IsFalling"))
                if i == #Watch.JUMP_READS then Log("jump", "falling at %s | swim %s", table.concat(reads, ", "), Flag("IsSwimming")) end
            end)
        end
    end)
    if #hooked > 0 then ns.Log("Watch", "hooks missing: %s", table.concat(hooked, ", ")) end
end

------------------------------------------------------------------------------
-- The watches
------------------------------------------------------------------------------
W.sit = { events = {
    { "UI_ERROR_MESSAGE", function(_, _, kind, text)
        text = ns.Plain(text)
        local shown = type(text) == "string" and text or Show(text)
        local matched = type(text) == "string" and (Matches(text, Watch.SITTING) or Matches(text, Watch.COOLDOWN)) or "none"
        local db = Store()
        if db.errors[shown] or (db.errorKinds or 0) < Watch.ERRORS_KEPT then
            if not db.errors[shown] then db.errorKinds = (db.errorKinds or 0) + 1 end
            db.errors[shown] = (db.errors[shown] or 0) + 1
        end
        Log("sit", "ui error %s %s (matches %s; %s): pet %s | %s", Show(kind), shown, matched, SinceCall(), Watch.Pet(), Watch.State())
        W.sit.t:After(Watch.ERROR_AFTER, function() Log("sit", "ui error +%gs: pet %s", Watch.ERROR_AFTER, Watch.Pet()) end)
    end },
    { "PLAYER_FLAGS_CHANGED", function()
        local afk = Flag("UnitIsAFK", "player")
        if afk == W.sit.afk then return end
        W.sit.afk = afk
        Log("sit", "afk %s (UnitStandState %s) | %s", afk, Try("UnitStandState", "player"), Watch.State())
    end, "player" },
    { "PLAYER_STARTED_MOVING", function()
        if not seated then return end
        seated = false
        Log("sit", "moved: stood up | pet %s", Watch.Pet())
    end },
}, start = function()
    W.sit.afk = Flag("UnitIsAFK", "player")
    return ("UnitStandState %s, SitStandOrDescendStart %s"):format(type(rawget(_G, "UnitStandState")) == "function" and "there" or "missing",
        type(rawget(_G, "SitStandOrDescendStart")) == "function" and "there" or "missing")
end }

-- (the spell too: 2026-11-24's run had TRADE_SKILL_SHOW before five instant casts with no crafting at all)
local function CastLine(event, spellID)
    local name = spellID and ns.SpellName(spellID)
    local info = Try("UnitCastingInfo", "player")
    local channel = Try("UnitChannelInfo", "player")
    local gap = W.craft.ended and ("%.2f s since the last end"):format(GetTime() - W.craft.ended) or "first"
    return ("%s %s (%s) window %s | casting %s | channel %s | %s | pet %s"):format(event, Show(name), Show(spellID),
        tostring(W.craft.open), info, channel, gap, Watch.Pet())
end
local function Cast(_, event, _, _, spellID)
    local ok, trade = pcall(function() return select(6, UnitCastingInfo("player")) == true end)
    if not (W.craft.open or (ok and trade)) then return end
    Log("craft", "%s", CastLine(event, ns.Plain(spellID)))
    if event ~= "UNIT_SPELLCAST_START" and event ~= "UNIT_SPELLCAST_CHANNEL_START" then W.craft.ended = GetTime() end
end
W.craft = { events = {
    { "TRADE_SKILL_SHOW", function() W.craft.open = true; Log("craft", "window open | %s", Watch.State()) end },
    { "TRADE_SKILL_CLOSE", function() Log("craft", "window closed (open before: %s)", tostring(W.craft.open)); W.craft.open = false end },
    { "TRADE_SKILL_UPDATE", function() Log("craft", "TRADE_SKILL_UPDATE (open %s)", tostring(W.craft.open)) end },
    { "CRAFT_SHOW", function() W.craft.open = true; Log("craft", "CRAFT_SHOW (the enchanting window?)") end },
    { "CRAFT_CLOSE", function() W.craft.open = false; Log("craft", "CRAFT_CLOSE") end },
    { "UNIT_SPELLCAST_START", Cast, "player" }, { "UNIT_SPELLCAST_STOP", Cast, "player" },
    { "UNIT_SPELLCAST_SUCCEEDED", Cast, "player" }, { "UNIT_SPELLCAST_INTERRUPTED", Cast, "player" },
    { "UNIT_SPELLCAST_FAILED", Cast, "player" }, { "UNIT_SPELLCAST_CHANNEL_START", Cast, "player" },
    { "UNIT_SPELLCAST_CHANNEL_STOP", Cast, "player" },
}, start = function()
    W.craft.open, W.craft.ended = false, nil
    local have = {}
    for _, name in ipairs({ "GetTradeskillRepeatCount", "GetNumTradeSkills", "GetTradeSkillLine", "GetCraftDisplaySkillLine",
        "C_TradeSkillUI", "UnitCastingInfo", "UnitChannelInfo" }) do
        have[#have + 1] = name .. (rawget(_G, name) ~= nil and " there" or " missing")
    end
    return table.concat(have, ", ")
end }

function Watch.Range(why)
    if ns.Plain(IsInGroup()) ~= true then return Log("group", "range (%s): not in a group", why) end
    local raid = ns.Plain(IsInRaid()) == true
    local me, n = ns.Plain((UnitName("player"))), 0
    for i = 1, raid and 40 or 4 do
        local u = (raid and "raid" or "party") .. i
        local name = ns.Plain((UnitName(u)))
        if name and name ~= me then
            n = n + 1
            if n > 10 then return end
            Log("group", "range (%s) %s: distance² %s | in range %s | interact(4) %s | visible %s", why, tostring(name),
                Try("UnitDistanceSquared", u), Try("UnitInRange", u), Try("CheckInteractDistance", u, 4), Try("UnitIsVisible", u))
        end
    end
end
local function GroupEvent(range)
    return function(_, event, ...)
        Log("group", "%s (%s) | pet %s", event, Shows(...), Watch.Pet())
        if range then Watch.Range(event) end
    end
end
W.group = { events = {
    { "READY_CHECK", GroupEvent(true) }, { "READY_CHECK_CONFIRM", GroupEvent() }, { "READY_CHECK_FINISHED", GroupEvent() },
    { "START_PLAYER_COUNTDOWN", GroupEvent(true) }, { "CANCEL_PLAYER_COUNTDOWN", GroupEvent() }, { "START_TIMER", GroupEvent() },
    { "GROUP_ROSTER_UPDATE", GroupEvent(true) },
}, start = function()
    W.group.t:Every(Watch.RANGE_EVERY, math.floor(Watch.FOR / Watch.RANGE_EVERY), function()
        if ns.Plain(IsInGroup()) == true then Watch.Range("every " .. Watch.RANGE_EVERY .. " s") end
    end)
    return "in a group: " .. Flag("IsInGroup")
end }

local function SceneEvent(_, event, ...)
    Log("scene", "%s (%s) | pet %s | %s", event, Shows(...), Watch.Pet(), Watch.State())
    Later("scene", event, { Watch.SCENE_AFTER })
end
W.scene = { events = {
    { "CINEMATIC_START", SceneEvent }, { "CINEMATIC_STOP", SceneEvent }, { "PLAY_MOVIE", SceneEvent },
    { "STOP_MOVIE", SceneEvent }, { "UNIT_ENTERED_VEHICLE", SceneEvent, "player" },
    { "UNIT_EXITED_VEHICLE", SceneEvent, "player" }, { "PET_BATTLE_OPENING_START", SceneEvent },
    { "PET_BATTLE_CLOSE", SceneEvent },
} }

local function PetMoment(_, event, ...)
    if event == "PLAYER_LEAVING_WORLD" then loading = true end
    if event == "PLAYER_ENTERING_WORLD" then loading = false end
    Log("pet", "%s (%s): pet %s | %s", event, Shows(...), Watch.Pet(), Watch.State())
    Later("pet", event, Watch.AFTER)
end
W.pet = { events = {
    { "COMPANION_UPDATE", function(_, _, kind)
        local now = Watch.Pet()
        if now == W.pet.last then return end
        local recent = lastCall and GetTime() - lastCall.at < Watch.CALL_RECENT
        Log("pet", "out %s -> %s (%s; %s: %s) | %s", tostring(W.pet.last), now, Show(kind), SinceCall(),
            recent and "a call's" or "the game's, or a click no hook sees", Watch.State())
        W.pet.last = now
    end },
    { "PLAYER_MOUNT_DISPLAY_CHANGED", PetMoment }, { "PLAYER_CONTROL_LOST", PetMoment },
    { "PLAYER_CONTROL_GAINED", PetMoment }, { "PLAYER_LEAVING_WORLD", PetMoment },
    { "PLAYER_ENTERING_WORLD", PetMoment }, { "PLAYER_DEAD", PetMoment }, { "PLAYER_ALIVE", PetMoment },
    { "PLAYER_UNGHOST", PetMoment }, { "UPDATE_STEALTH", PetMoment },
}, start = function()
    W.pet.last = Watch.Pet()
    return "pet out " .. W.pet.last
end }

function Watch.Where()
    local inst = Try("GetInstanceInfo")
    return ("zone %s sub %s real %s mini %s | instance %s | flying %s taxi %s swim %s indoors %s"):format(
        Try("GetZoneText"), Try("GetSubZoneText"), Try("GetRealZoneText"), Try("GetMinimapZoneText"), inst,
        Flag("IsFlying"), Flag("UnitOnTaxi", "player"), Flag("IsSwimming"), Flag("IsIndoors"))
end
local function Spot(_, event)
    local zone, sub = ns.Plain(GetZoneText()), ns.Plain(GetSubZoneText())
    local key = tostring(zone) .. "/" .. tostring(sub)
    if key == W.spot.at and event ~= "PLAYER_ENTERING_WORLD" and event ~= "ZONE_CHANGED_NEW_AREA" then return end
    W.spot.at = key
    Log("spot", "%s: %s", event, Watch.Where())
    if type(zone) == "string" and type(sub) == "string" and sub ~= "" then
        local z = Store().subzones
        z[zone] = z[zone] or {}
        z[zone][sub] = (z[zone][sub] or 0) + 1
    end
end
local function Swim(_, event)
    local now = Flag("IsSwimming")
    if now == W.spot.swim then return end
    local t = GetTime()
    local last = W.spot.flipped
    W.spot.swim, W.spot.flipped = now, t
    Log("spot", "swim %s at %s (%s, %s since the last flip)", now, event, Try("GetSubZoneText"),
        last and ("%.1f s"):format(t - last) or "first")
end
W.spot = { events = {
    { "ZONE_CHANGED", Spot }, { "ZONE_CHANGED_INDOORS", Spot }, { "ZONE_CHANGED_NEW_AREA", Spot },
    { "PLAYER_ENTERING_WORLD", Spot }, { "PLAYER_STARTED_MOVING", Swim }, { "PLAYER_STOPPED_MOVING", Swim },
}, start = function()
    W.spot.at, W.spot.swim, W.spot.flipped = nil, Flag("IsSwimming"), nil
    return Watch.Where()
end }

W.jump = { events = {}, start = function() return "IsFalling " .. Flag("IsFalling") end }

for _, id in ipairs(Watch.ORDER) do W[id].t = ns.Timers() end
Watch.W = W

------------------------------------------------------------------------------
-- On and off
------------------------------------------------------------------------------
function Watch:Start(id)
    local w = W[id]
    if self.on[id] then return "on already" end
    InstallHooks()
    self.on[id] = true
    local refused = {}
    for _, e in ipairs(w.events) do
        if not ns.Events:On(e[1], w, e[2], e[3]) then refused[#refused + 1] = e[1] end
    end
    Store().refused[id] = refused
    local said = w.start and w.start() or ""
    Log(id, "on: %s; events refused: %s", said, #refused > 0 and table.concat(refused, " ") or "none")
    return #refused > 0 and ("refused " .. table.concat(refused, " ")) or "ok"
end

function Watch:Stop(id)
    if not self.on[id] then return end
    self.on[id] = nil
    ns.Events:OffAll(W[id])
    W[id].t:Cancel()
    if id == "sit" then seated = false end
    Log(id, "off")
end

function Watch:StopAll()
    for _, id in ipairs(self.ORDER) do self:Stop(id) end
    sessionT:Cancel()
end

function Watch:Command(arg)
    local words = {}
    for w in (arg or ""):gmatch("%S+") do words[#words + 1] = w:lower() end
    local first = words[1]
    if first == "off" then
        self:StopAll()
        return ns.Print("watch: all off (the log has what they saw; /reload to save it)")
    end
    if first == "range" then
        Watch.Range("now")
        return ns.Print("watch: range read into the log")
    end
    if first == "status" then
        local on = {}
        for _, id in ipairs(self.ORDER) do if self.on[id] then on[#on + 1] = id end end
        return ns.Print(("watch: on %s; %d lines this session"):format(#on > 0 and table.concat(on, " ") or "none", lines))
    end
    local list = (not first or first == "all") and self.ORDER or words
    for _, id in ipairs(list) do
        if not W[id] then
            return ns.Print("watch: no watch \"" .. id .. "\"; watches are " .. table.concat(self.ORDER, " ")
                .. " (all with none given), and range, status, off")
        end
    end
    if not ns.Debug.enabled then ns.Debug:SetEnabled(true, ns.Debug.echo) end
    local db = Store()
    db.at, db.build = date("%Y-%m-%d %H:%M"), Try("GetBuildInfo")
    local said = {}
    for _, id in ipairs(list) do said[#said + 1] = id .. ": " .. self:Start(id) end
    sessionT:Cancel()
    sessionT:After(self.FOR, function() Watch:StopAll() end)
    ns.Print(("watch: %s, for %d min (/dp probe watch off). Read with luajit tools/log.lua -m Watch after /reload.")
        :format(table.concat(said, ", "), self.FOR / 60))
end
