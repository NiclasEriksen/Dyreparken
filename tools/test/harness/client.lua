-- A Client: one player's game, with its own global environment (BuildEnv, from env/*.lua),
-- its own copy of the addon and its SavedVariables (login, logout, reload), its events and
-- frames, the checks run after every test (H.Invariants, the Bus), and the helpers that pin a
-- test's world (Fixture, Companions, Traits, Dice, QuirksNow), read what it printed (Said,
-- Printed, Log) and set the player's state (Set, EnterCombat, Mount, Move...).
local H, P = ...
local ADDON, TOC, Load, CopyTable = P.ADDON, P.TOC, P.Load, P.CopyTable
local Hardware, World = P.Hardware, P.World

------------------------------------------------------------------------------
-- Clients
------------------------------------------------------------------------------
local Client = {}
Client.__index = Client
H.Client = Client

local function SpeciesName(sid) return H.SPECIES[sid] or ("Species " .. tostring(sid)) end

-- opts: guild (name or false), pets ({ speciesID, ... }), summoned (speciesID),
--   realm (adds "-Realm" to the sender name on the wire), version (TOC Version),
--   protocol (X-Protocol), trial (can't send addon messages), addons ({ "AutoCompanion" }),
--   login (false: create offline), debug (false: debug log off),
--   patch (function(env, c): change the stub API before the addon loads),
--   rank (guild rank index: 0 guild master, 1 officer, default 3 member),
--   oldTemplates (the client lacks the modern frame templates),
--   fixture (function(ns, c): change the addon's data after its files load, before ADDON_LOADED,
--   at every login; see Client:Fixture),
--   release (true: a packaged release: the TOC without its #@do-not-package@ blocks, so no Dev/
--   files, and a release's version, so ns.DEV is false)
function World:AddClient(name, opts)
    opts = opts or {}
    assert(not self.byName[name], "duplicate client " .. name)
    local first, surname = name:match("^(%S+)%s*(.*)$")
    local c = setmetatable({
        world = self, name = name, first = first, surname = surname,
        wireName = opts.realm and (name .. "-" .. opts.realm) or name,
        guild = opts.guild == nil and self.guildName or (opts.guild or nil),
        version = opts.version or (opts.release and "9.9.9") or TOC.meta.Version, release = opts.release,
        protocol = opts.protocol or TOC.meta["X-Protocol"],
        trial = opts.trial, addons = opts.addons or {}, saved = {}, online = false,
        pets = {}, errors = {}, printed = {},
        state = { stand = 0, auras = {}, instance = "none" },
        idx = #self.clients + 1, patch = opts.patch, rank = opts.rank or 3, oldTemplates = opts.oldTemplates,
        fixtures = { opts.fixture },
    }, Client)
    if opts.debug ~= false then c.saved.DyreparkenDebugDB = { enabled = true } end
    for _, sid in ipairs(opts.pets or { 5159 }) do c:GivePet(sid) end
    if opts.summoned ~= false then
        c.summoned = c:GuidOf(opts.summoned or (opts.pets and opts.pets[1]) or 5159)
    end
    self.clients[#self.clients + 1] = c
    self.byName[name] = c
    if c.guild then self:AddMember(name, nil, c.guild) end
    if opts.login ~= false then c:Login() end
    return c
end

function Client:GuidOf(sid)
    for _, p in ipairs(self.pets) do if p.sid == sid then return p.guid end end
end

function Client:GivePet(sid)
    if self:GuidOf(sid) then return end
    self.pets[#self.pets + 1] = { sid = sid, guid = ("BattlePet-0-%06X%06X"):format(self.idx or 0, sid) }
end

-- (Event handlers are the addon's code: insecure, even when Blizzard's code fired the event.)
function Client:Fire(event, ...)
    if (self.secure or 0) > 0 then return P.Insecure(self, self.Fire, self, event, ...) end
    for _, f in ipairs(self.frames) do
        local units = f.unitFilter and f.unitFilter[event]
        local unitOK = true
        if units then
            unitOK = false
            for _, u in ipairs(units) do if u == (...) then unitOK = true end end
        end
        if f.events[event] and unitOK and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

function Client:Tick(step)
    if (self.secure or 0) > 0 then return P.Insecure(self, self.Tick, self, step) end
    for _, f in ipairs(self.frames) do
        if f.shown and f.scripts.OnUpdate then f.scripts.OnUpdate(f, step) end
    end
end

local SAVED = { "DyreparkenDB", "DyreparkenCharDB", "DyreparkenDebugDB" }

-- SavedVariables are written as Lua text: only plain data survives.
local function SaveCopy(v, path)
    local t = type(v)
    if t == "table" then
        local c = {}
        for k, x in pairs(v) do
            assert(type(k) == "string" or type(k) == "number" or type(k) == "boolean",
                "SavedVariables key of type " .. type(k) .. " at " .. path)
            c[k] = SaveCopy(x, path .. "." .. tostring(k))
        end
        return c
    end
    assert(t == "string" or t == "number" or t == "boolean", "SavedVariables can't hold a " .. t .. " at " .. path)
    return v
end

function Client:Login()
    assert(not self.online, self.name .. " is already online")
    self.online = true
    self.frames, self.tooltipCalls, self.units, self.sidePages = {}, {}, {}, {}
    self.prefixes, self.missingGlobals, self.newGlobals = {}, {}, {}
    self.loaded = { [ADDON] = true }
    for _, a in ipairs(self.addons) do self.loaded[a] = true end
    self.summonCalls = 0
    local env = self:BuildEnv()
    if self.patch then self.patch(env, self) end
    -- The client's own globals, before the addon runs: what's added after is the addon's.
    self.stubKeys = {}
    for k in pairs(env) do self.stubKeys[k] = true end
    for _, k in ipairs(SAVED) do
        if self.saved[k] then env[k] = SaveCopy(self.saved[k], k) end
    end
    -- From here on, reads of unknown globals and new globals are recorded.
    local c = self
    setmetatable(env, {
        __index = function(_, k)
            -- Libraries probe for their own globals; only the addon's reads count.
            local src = debug.getinfo(2, "S").source
            if not src:find("^@Libs/") then c.missingGlobals[k] = true end
        end,
        __newindex = function(t, k, v) c.newGlobals[k] = true; rawset(t, k, v) end,
    })
    self.env, self.ns = env, {}
    for _, path in ipairs(self.release and TOC.release or TOC.files) do
        Load(env, path, ADDON, self.ns)
        if path == "Core/Init.lua" then
            self:CheckBus() -- (before any module listens)
            self.ns.STRICT = true -- (our own bugs throw here; in the game they're logged: Registry:WriteOwn)
        end
    end
    -- The Config as it ships, before the test values below (52_protocol fingerprints it).
    self.shippedConfig = CopyTable(self.ns.Config)
    -- The bond epoch (no bond is older than the addon) as in the real world:
    -- before any test data. The test clock starts in September 2026.
    self.ns.Config.BOND_EPOCH = self.world.epoch or (1790000000 - 1000 * 86400)
    -- Bonds shipped as the world starts: its adoptions are new (a test moves it to have them seeded).
    self.ns.Config.BONDS_SHIPPED = self.world.bondsShipped or 1790000000
    for _, fn in ipairs(self.fixtures) do fn(self.ns, self) end
    self:Fire("ADDON_LOADED", ADDON)
    self:Fire("PLAYER_LOGIN")
    self:Fire("PLAYER_ENTERING_WORLD", true, false)
    return self
end

-- The Bus's events are declared (ns.Bus.EVENTS, Core/Init.lua): firing or
-- listening to another is an error the test fails on (a typo would otherwise
-- just never arrive). Here, not in the addon, so the game doesn't pay for it.
function Client:CheckBus()
    local bus, c = self.ns.Bus, self
    local on, fire = bus.On, bus.Fire
    local function Check(how, event)
        if not bus.EVENTS[event] then
            c.errors[#c.errors + 1] = ("Bus:%s(%s): not declared in ns.Bus.EVENTS (Core/Init.lua)"):format(how, tostring(event))
        end
    end
    function bus:On(event, fn) Check("On", event); return on(self, event, fn) end
    function bus:Fire(event, ...) Check("Fire", event); return fire(self, event, ...) end
end

-- Comm handler failures and tooltip errors are only logged (pcall'd), so the
-- harness reads them from the debug log.
function Client:CollectLogErrors()
    local db = self.env and rawget(self.env, "DyreparkenDebugDB")
    local lines = db and db.lines
    if not lines then return end
    for i = 1, #lines do
        local l = lines[i]
        if l and (l:find("\thandler %S+ failed") or l:find("\tTooltip\terror")) and not self.seenLog[l] then
            self.seenLog[l] = true
            self.errors[#self.errors + 1] = "logged: " .. l
        end
    end
end

-- Errors so far (thrown and logged), cleared: for tests that provoke them.
function Client:TakeErrors()
    self.seenLog = self.seenLog or {}
    self:CollectLogErrors()
    local e = self.errors
    self.errors = {}
    return e
end

function Client:Logout()
    assert(self.online, self.name .. " is not online")
    self:Fire("PLAYER_LOGOUT")
    self.seenLog = self.seenLog or {}
    self:CollectLogErrors()
    for _, k in ipairs(SAVED) do
        local v = rawget(self.env, k)
        self.saved[k] = v ~= nil and SaveCopy(v, k) or nil
    end
    self.online = false
    self.lastSeen = self.world:ServerTime()
    for i = #self.world.timers, 1, -1 do
        if self.world.timers[i].client == self then table.remove(self.world.timers, i) end
    end
    return self
end

function Client:Reload()
    self:Logout()
    self.lastSeen = nil
    return self:Login()
end

-- Checked after every test (run.lua), for every client: what no test should ever see.
-- Globals the addon may write, and ones it may read that the stubs lack (it checks for them).
H.ALLOWED_GLOBALS = { DyreparkenDB = true, DyreparkenCharDB = true, DyreparkenDebugDB = true,
    SLASH_DYREPARKEN1 = true, SLASH_DYREPARKEN2 = true, LibStub = true }
H.OPTIONAL_GLOBALS = { DyreparkenDB = true, DyreparkenCharDB = true, DyreparkenDebugDB = true, -- first login
    GetAddOnMetadata = true, ScrollUtil = true, SendAddonMessage = true,
    RegisterAddonMessagePrefix = true, io = true --[[ LibDeflate's command line mode ]] }
function H.Invariants(c)
    local out = {}
    for k in pairs(c.newGlobals or {}) do
        if not H.ALLOWED_GLOBALS[k] then out[#out + 1] = "wrote a stray global: " .. tostring(k) end
    end
    -- (Reads of missing globals only in 01_core's tour: many tests take a stub away on purpose.)
    if not c.allowRawText then
        for _, line in ipairs(c.printed) do
            local hole = line:match("{%a+}")
            if hole then out[#out + 1] = "printed an unfilled " .. hole .. ": " .. line end
        end
    end
    return out
end

-- A change to the addon's data that holds for this client from now on, across reloads:
-- run now (when online) and at every login, after the addon's files load and before
-- ADDON_LOADED. For data, not behavior: stub APIs with opts.patch.
function Client:Fixture(fn)
    self.fixtures[#self.fixtures + 1] = fn
    if self.online then fn(self.ns, self) end
end

local function Copy(t)
    if type(t) ~= "table" then return t end
    local out = {}
    for k, v in pairs(t) do out[Copy(k)] = Copy(v) end
    return out
end

-- The journal's species (Data/Companions.lua) replaced by these: { [sid] = { a = counts, t = tags } }
-- (a fresh copy at each login). H.COMPANIONS is the usual set.
function Client:Companions(species)
    self:Fixture(function(ns) ns.Companions = { build = 1, species = Copy(species) } end)
end
H.COMPANIONS = {
    [40] = { a = true, t = { "cat" } }, [41] = { a = true, t = { "cat" } },
    [42] = { a = true, t = { "cat" } }, [46] = { a = true, t = { "cat" } },
    [7] = { a = true, t = { "farm", "bird" } }, [84] = { a = true, t = { "farm", "bird" } },
    [68] = { a = true, t = { "owl", "bird" } }, [72] = { a = true, t = { "rabbit" } },
    [90] = { a = true, t = { "bird", "pirate" } },
    [5159] = { a = false }, -- promo: in the total, not in achievements
    [2001] = { a = true }, [2002] = { a = true }, [2003] = { a = true }, -- filler: 15 counting pets
    [2004] = { a = true }, [2005] = { a = true }, [2006] = { a = true },
}

-- Pin a species' traits (ids, at most two) instead of Data/Traits.lua's; sid nil: every
-- species. Personality's own rules still run (Known, likes from the traits...).
-- c:Traits(nil) puts the real pins back.
function Client:Traits(ids, sid)
    if not self.traitFn then
        self.traitFn = function(ns, c)
            local real, pins = ns.TraitPins or {}, c.traitPins
            if not pins then ns.Personality.PINNED = real; return end
            local out = setmetatable({}, { __index = function(_, k) return pins.all or real[k] end })
            for k, v in pairs(pins) do if k ~= "all" then out[k] = v end end
            ns.Personality.PINNED = out
        end
        self.fixtures[#self.fixtures + 1] = self.traitFn
    end
    if ids == nil then
        self.traitPins = nil
    else
        self.traitPins = self.traitPins or {}
        self.traitPins[sid or "all"] = ids
    end
    if self.online then self.traitFn(self.ns, self) end
end

-- Chat lines said by now: the pending timers run first (a quirk line waits a moment).
function Client:Said(text) self.world:RunTimers(); return self:Printed(text, true) end
-- How many printed lines hold this text (plain), the pending timers run first.
function Client:CountPrinted(text)
    self.world:RunTimers()
    local n = 0
    for _, l in ipairs(self.printed) do if l:find(text, 1, true) then n = n + 1 end end
    return n
end
-- How many times this character has found an easter egg (Quirks: char.eggs; 0 for never).
-- An egg counts once its line is said (a line can wait a moment: c:Said runs the timers).
function Client:Eggs(id)
    local e = self.ns.DB.char.eggs[id]
    return e and e.n or 0
end
-- A carer's bond points with a pet (default: this client's own), 0 for none.
function Client:Points(key, who)
    local e = self.ns.Registry:Life(key, who or self.name)
    return e and e.p or 0
end

-- Pin every chance the addon rolls (ns.random, Core/Init.lua): a roll without arguments
-- gives `roll` (default 0: every chance comes up), a pick from n gives the `pick`th (default 1,
-- kept within n: the first line). Call again to change them mid-test.
function Client:Dice(roll, pick)
    roll, pick = roll or 0, pick or 1
    self.ns.random = function(a, b)
        if not a then return roll end
        local lo, hi = b and a or 1, b or a
        return math.max(lo, math.min(hi, lo + pick - 1))
    end
end

-- Quirk lines at once: every delay tier (read from the real table, so a new one is
-- covered) at zero, and no line said yet in the last 45 minutes.
function Client:QuirksNow()
    local Q = self.ns.Quirks
    for k in pairs(Q.DELAY) do Q.DELAY[k] = { 0, 0 } end
    self.ns.DB.char.quirkAt = nil
end

-- Chat lines the addon printed for this client (color codes stripped).
function Client:Printed(pattern, plain)
    for i = #self.printed, 1, -1 do
        if self.printed[i]:find(pattern, 1, plain) then return self.printed[i] end
    end
end
function Client:ClearPrinted() self.printed = {} end

function Client:Slash(text) return Hardware(self, self.env.SlashCmdList.DYREPARKEN, text) end

-- Debug log lines (newest last), optionally only those matching a pattern.
function Client:Log(pattern)
    local db = rawget(self.env, "DyreparkenDebugDB")
    local lines = db and db.lines or {}
    local out = {}
    local size = self.ns.Config and self.ns.Config.DEBUG_RING_SIZE or 2000
    local head = lines.head or 0
    for n = 1, size do
        local l = lines[((head + n - 1) % size) + 1]
        if l and (not pattern or l:find(pattern)) then out[#out + 1] = l end
    end
    return out
end

-- Player state -------------------------------------------------------------------
-- c:Set("mounted", true) etc. Keys: combat, dead, mounted, taxi, flying,
-- stealthed, casting, channeling, stand, instance, secretAuras.
function Client:Set(k, v) self.state[k] = v; return self end

-- Combat: lockdown starts, the secure state drivers ([combat] hide...) apply, then the event.
function Client:EnterCombat() self.state.combat = true; self:Drive(); self:Fire("PLAYER_REGEN_DISABLED") end
function Client:LeaveCombat() self.state.combat = false; self:Drive(); self:Fire("PLAYER_REGEN_ENABLED") end
-- Secure state drivers (RegisterStateDriver(frame, "visibility", "[combat] hide; show")), applied by
-- Blizzard's code: secure. Conditions known here: combat, nocombat; else the stub throws.
local CONDITIONS = { combat = function(S) return S.combat == true end, nocombat = function(S) return S.combat ~= true end }
function Client:DriverState(cond)
    for clause in cond:gmatch("[^;]+") do
        local conds, action = clause:match("^%s*%[([^%]]*)%]%s*(%S+)%s*$")
        if not conds then action = clause:match("^%s*(%S+)%s*$") end
        local all = true
        for name in (conds or ""):gmatch("[^,%s]+") do
            local test = CONDITIONS[name]
            if not test then error("state driver condition [" .. name .. "] is not stubbed (tools/test/harness/client.lua)", 2) end
            if not test(self.state) then all = false end
        end
        if all then return action end
    end
end
function Client:Drive()
    for f, d in pairs(self.drivers or {}) do
        if d.state == "visibility" then
            local v = self:DriverState(d.cond)
            P.Secure(self, function() if v == "show" then f:Show() elseif v == "hide" then f:Hide() end end)
        end
    end
end
function Client:Mount() self.state.mounted = true; self:Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
function Client:Dismount() self.state.mounted = false; self:Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
-- Moving: the client's start and stop events, and GetUnitSpeed.
function Client:Move() self.state.moving = true; self:Fire("PLAYER_STARTED_MOVING") end
function Client:Halt() self.state.moving = false; self:Fire("PLAYER_STOPPED_MOVING") end
function Client:Summon(sid) self.summoned = sid and self:GuidOf(sid) or nil end

-- A clean bond slate: no bonds, nothing earned today, no day visits yet
-- (logins give the pet out a day; tests that count from zero call this).
function Client:ForgetBonds()
    self.ns.DB:Guild().life = {}
    self.ns.DB.char.bondToday, self.ns.DB.char.activity.day = nil, nil
end

-- Only the activities' own points: no wish and no first-time bonuses mixed
-- in (26_story.lua and 28_multibond.lua test those). c.realFirst keeps Bond.First.
function Client:NoBonuses()
    self.ns.Wish.OnActivity = function() end
    self.realFirst, self.ns.Bond.First = self.ns.Bond.First, function() end
end

function Client:Zone()
    self:Fire("PLAYER_LEAVING_WORLD")
    self:Fire("PLAYER_ENTERING_WORLD", false, false)
end

P.Client, P.SpeciesName = Client, SpeciesName

-- The stub client API, one environment per client: each env/*.lua adds a part, in this order.
local ENV = {}
for i, name in ipairs({ "core", "frames", "tooltip", "player", "calendar", "units", "guild", "group", "system",
    "comm", "journal" }) do
    ENV[i] = assert(loadfile(P.dir .. "env/" .. name .. ".lua"))(H, P)
end
function Client:BuildEnv()
    local env = P.NewEnv()
    for _, part in ipairs(ENV) do part(self, env, self.state) end
    return env
end
