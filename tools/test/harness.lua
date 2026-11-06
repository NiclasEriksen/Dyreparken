-- Test harness: a simulated world with several WoW clients, each running its
-- own copy of the addon, connected by a fake addon-message network.
--
--   local w = H.World()                       -- clock, guild, network
--   local ola = w:AddClient("Ola Nord", { pets = { 5159, 46 } })
--   local kari = w:AddClient("Kari Berg")
--   w:Run(15)                                 -- advance time: OnUpdate, timers, delivery
--   ola:Slash("claim panda")
--   assert(kari.ns.Registry:Holder("s:5159") == "Ola Nord")
--
-- Each client gets its own global environment (setfenv), so its addon
-- files, libraries, SavedVariables and frames are separate. `c.ns` is the
-- addon namespace, `c.env` its globals. The stubs follow the real client as
-- probed on Forever (docs/FOREVER_API.md); keep them realistic.
--
-- Network: GUILD reaches everyone online in the sender's guild (the sender
-- too: WoW echoes your own guild/party addon messages), PARTY/RAID the
-- group, WHISPER one name. Delivery takes LATENCY seconds and keeps order.
-- `w.drop = function(m, recipient) return true end` loses messages.
-- Every message that goes on the wire is also decoded into `w.wire`
-- ({ from, chan, kind, msg, at }) so tests can count traffic.
local H = {}

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

-- Events the stub client knows. Registering anything else throws, like the
-- real client does, which catches typos.
local KNOWN_EVENTS = {}
for e in ([[ADDON_LOADED PLAYER_LOGIN PLAYER_LOGOUT PLAYER_ENTERING_WORLD PLAYER_LEAVING_WORLD
    PLAYER_REGEN_ENABLED PLAYER_REGEN_DISABLED PLAYER_MOUNT_DISPLAY_CHANGED CHAT_MSG_ADDON
    GUILD_ROSTER_UPDATE PLAYER_GUILD_UPDATE GROUP_ROSTER_UPDATE COMPANION_UPDATE BAG_UPDATE_DELAYED
    UNIT_AURA ZONE_CHANGED_NEW_AREA PLAYER_TARGET_CHANGED UPDATE_MOUSEOVER_UNIT]]):gmatch("%S+") do
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

local TOC = { files = {}, meta = {} }
for line in Source(ADDON .. ".toc"):gmatch("[^\r\n]+") do
    local k, v = line:match("^##%s*([^:]+):%s*(.-)%s*$")
    if k then
        TOC.meta[k] = v
    elseif not line:match("^%s*#") and line:match("%S") then
        TOC.files[#TOC.files + 1] = (line:gsub("\\", "/"))
    end
end
H.TOC = TOC

local function Load(env, path, ...)
    local chunk = assert(loadstring(Source(path), "@" .. path))
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

------------------------------------------------------------------------------
-- Frames
------------------------------------------------------------------------------
local Frame = {}
Frame.__index = function(self, k)
    local m = Frame[k]
    if m then return m end
    -- Unknown methods are errors on purpose: stub them here when the addon
    -- starts using one, with realistic behavior.
    if type(k) == "string" and k:match("^%u") then
        error("frame method " .. k .. " is not stubbed (tools/test/harness.lua)", 2)
    end
end
local function noop() end
for _, m in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetAllPoints",
    "SetMotionScriptsWhileDisabled", "SetFrameStrata", "SetFrameLevel", "SetAlpha", "EnableMouse",
    "RegisterForClicks", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetJustifyH",
    "SetJustifyV", "SetFontObject", "SetWordWrap" }) do
    Frame[m] = noop
end

function Frame:RegisterEvent(e)
    if not KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    self.events[e] = true
end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(e) return self.events[e] == true end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:HookScript(k, fn)
    local old = self.scripts[k]
    self.scripts[k] = old and function(...) old(...); fn(...) end or fn
end
function Frame:Show()
    if self.shown then return end
    self.shown = true
    if self.scripts.OnShow and self:IsVisible() then self.scripts.OnShow(self) end
end
function Frame:Hide()
    if not self.shown then return end
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
end
function Frame:IsShown() return self.shown end
function Frame:IsVisible()
    if not self.shown then return false end
    return self.parent == nil or self.parent:IsVisible()
end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) self.parent = p end
function Frame:GetName() return self.name end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:IsEnabled() return self.enabled end
function Frame:SetEnabled(v) self.enabled = not not v end
function Frame:SetChecked(v) self.checked = not not v end
function Frame:GetChecked() return self.checked end
-- Like the client: a disabled button ignores clicks; a check button flips
-- its state before OnClick runs.
function Frame:Click()
    if not self.enabled then return end
    if self.type == "CheckButton" then self.checked = not self.checked end
    if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end
end

local Region = {}
Region.__index = Region
for _, m in ipairs({ "SetSize", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetJustifyH", "SetJustifyV",
    "SetDrawLayer", "SetVertexColor", "SetTexCoord", "SetWordWrap", "SetFontObject" }) do
    Region[m] = noop
end
function Region:SetTexture(x) self.tex = x end
function Region:GetTexture() return self.tex end
function Region:SetAtlas(x) self.tex = x end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end
local function StripColors(x) return (tostring(x):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
H.StripColors = StripColors
-- .text as set, .plain without color codes (for assertions)
function Region:SetText(x) self.text = x; self.plain = x and StripColors(x) end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end

function Frame:CreateTexture()
    local t = setmetatable({ shown = true }, Region)
    self.textures[#self.textures + 1] = t
    return t
end
function Frame:CreateFontString()
    local t = setmetatable({ shown = true }, Region)
    self.fontStrings[#self.fontStrings + 1] = t
    return t
end

------------------------------------------------------------------------------
-- World
------------------------------------------------------------------------------
local World = {}
World.__index = World
H.worlds = {} -- every world made during the current test (the runner checks them)

function H.World(opts)
    opts = opts or {}
    local w = setmetatable({
        t = 1000, server = 1790000000, seq = 0,
        clients = {}, byName = {}, timers = {}, inflight = {}, wire = {}, chat = {},
        guilds = {}, group = nil, partial = {},
        guildName = opts.guild or "Dyreparken",
    }, World)
    H.worlds[#H.worlds + 1] = w
    return w
end

function World:ServerTime() return self.server + math.floor(self.t) end

-- Jump ahead without simulating (days of being away). GetTime keeps going
-- slowly; only the server clock jumps, which is what the addon compares.
function World:Skip(seconds) self.server = self.server + seconds end
function World:SkipDays(days) self:Skip(days * 86400) end

-- Advance time in small steps: every online client's OnUpdate (that's how
-- ChatThrottleLib sends), message delivery, and C_Timer callbacks.
function World:Run(seconds, step)
    step = step or 0.1
    local stop = self.t + seconds - 1e-9
    while self.t < stop do
        self.t = self.t + step
        for _, c in ipairs(self.clients) do
            if c.online then c:Tick(step) end
        end
        self:Deliver()
        self:RunTimers()
    end
end

function World:RunTimers()
    while true do
        local best, bi
        for i, tm in ipairs(self.timers) do
            if tm.at <= self.t + 1e-9 and (not best or tm.at < best.at or (tm.at == best.at and tm.seq < best.seq)) then
                best, bi = tm, i
            end
        end
        if not best then return end
        table.remove(self.timers, bi)
        local ok, err = xpcall(best.fn, debug.traceback)
        if not ok then best.client.errors[#best.client.errors + 1] = err end
    end
end

function World:Timer(c, seconds, fn)
    self.seq = self.seq + 1
    self.timers[#self.timers + 1] = { at = self.t + seconds, fn = fn, client = c, seq = self.seq }
end

-- Guild roster ---------------------------------------------------------------
function World:Guild(name)
    name = name or self.guildName
    local g = self.guilds[name]
    if not g then g = { members = {} }; self.guilds[name] = g end
    return g
end

-- A guild member, with or without the addon. daysOffline nil = online now.
function World:AddMember(name, daysOffline, guild)
    local g = self:Guild(guild)
    for _, m in ipairs(g.members) do if m.name == name then return m end end
    local m = { name = name, lastSeen = daysOffline and (self:ServerTime() - daysOffline * 86400) or nil }
    g.members[#g.members + 1] = m
    return m
end

function World:RemoveMember(name, guild)
    local g = self:Guild(guild)
    for i, m in ipairs(g.members) do
        if m.name == name then table.remove(g.members, i); break end
    end
    local c = self.byName[name]
    if c and c.guild == (guild or self.guildName) then c.guild = nil end
end

function World:Roster(guild)
    local rows = {}
    for _, m in ipairs(self:Guild(guild).members) do
        local c = self.byName[m.name]
        local online = c and c.online and c.guild == (guild or self.guildName)
        local days
        if not online then
            local last = (c and c.lastSeen) or m.lastSeen or self:ServerTime()
            days = math.floor((self:ServerTime() - last) / 86400)
        end
        rows[#rows + 1] = { name = m.name, online = online, days = days }
    end
    return rows
end

-- Group ------------------------------------------------------------------------
-- w:SetGroup({ "Ola Nord", "Kari Berg", "Per Uten" }) - first is the leader.
-- Names without a client are players without the addon.
function World:SetGroup(names)
    self.group = names and { members = names } or nil
end

function World:GroupOf(name)
    local g = self.group
    if not g then return nil end
    for _, n in ipairs(g.members) do if n == name then return g end end
end

-- Network ------------------------------------------------------------------------
local function StripRealm(name) return (name:gsub("%-[^%-%s]+$", "")) end

function World:Transmit(c, prefix, text, chan, target)
    self.chunks = (self.chunks or 0) + 1
    self.inflight[#self.inflight + 1] = {
        at = self.t + LATENCY, from = c, sender = c.wireName, prefix = prefix, text = text, chan = chan,
        target = target, guild = c.guild, group = self:GroupOf(c.name),
    }
    -- Decode for w.wire.
    local key = c.name .. "\0" .. chan
    local head, body = text:sub(1, 1), text:sub(2)
    local data
    if head == "S" then
        data = body
    elseif head == "F" then
        self.partial[key] = body
    elseif self.partial[key] then
        self.partial[key] = self.partial[key] .. body
        if head == "L" then data, self.partial[key] = self.partial[key], nil end
    end
    if data then
        local msg = DecodeWire(data)
        self.wire[#self.wire + 1] = { from = c.name, chan = chan, kind = msg and msg.k, msg = msg, at = self.t,
            bytes = #data }
    end
end

-- Inject raw chunks as if `sender` sent them (forged or foreign clients).
function World:Inject(sender, chan, text, target)
    self.inflight[#self.inflight + 1] = { at = self.t, sender = sender, prefix = ADDON, text = text, chan = chan,
        guild = self.guildName, group = self:GroupOf(sender), target = target }
end

-- Send a whole message from a client-less sender (encoded like Comm, one chunk or several).
function World:InjectMessage(sender, msg, chan, target)
    local data = H.Encode(msg)
    if #data <= 254 then
        self:Inject(sender, chan or "GUILD", "S" .. data, target)
    else
        local pos = 1
        while pos <= #data do
            local last = pos + 254 > #data
            self:Inject(sender, chan or "GUILD", (pos == 1 and "F" or (last and "L" or "M")) .. data:sub(pos, pos + 253))
            pos = pos + 254
        end
    end
end

function World:Recipients(m)
    local list = {}
    for _, r in ipairs(self.clients) do
        if r.online then
            local ok
            if m.chan == "GUILD" then
                ok = m.guild ~= nil and r.guild == m.guild
            elseif m.chan == "PARTY" or m.chan == "RAID" then
                ok = m.group ~= nil and self:GroupOf(r.name) == m.group
            elseif m.chan == "WHISPER" then
                ok = m.target ~= nil and StripRealm(m.target) == r.name
            end
            if ok then list[#list + 1] = r end
        end
    end
    return list
end

function World:Deliver()
    while self.inflight[1] and self.inflight[1].at <= self.t + 1e-9 do
        local m = table.remove(self.inflight, 1)
        for _, r in ipairs(self:Recipients(m)) do
            if r.prefixes[m.prefix] and not (self.drop and self.drop(m, r)) then
                r:Fire("CHAT_MSG_ADDON", m.prefix, m.text, m.chan, m.sender, r.name, 0, 0, "", 0)
            end
        end
    end
end

-- Wire messages of a kind (optionally from one client) since the start or `since`.
function World:Sent(kind, from, since)
    local n = 0
    for i = (since or 0) + 1, #self.wire do
        local m = self.wire[i]
        if m.kind == kind and (not from or m.from == from) then n = n + 1 end
    end
    return n
end

function World:Mark() return #self.wire end

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
--   patch (function(env, c): change the stub API before the addon loads)
function World:AddClient(name, opts)
    opts = opts or {}
    assert(not self.byName[name], "duplicate client " .. name)
    local first, surname = name:match("^(%S+)%s*(.*)$")
    local c = setmetatable({
        world = self, name = name, first = first, surname = surname,
        wireName = opts.realm and (name .. "-" .. opts.realm) or name,
        guild = opts.guild == nil and self.guildName or (opts.guild or nil),
        version = opts.version or TOC.meta.Version, protocol = opts.protocol or TOC.meta["X-Protocol"],
        trial = opts.trial, addons = opts.addons or {}, saved = {}, online = false,
        pets = {}, errors = {}, printed = {},
        state = { stand = 0, auras = {}, instance = "none" },
        idx = #self.clients + 1, patch = opts.patch,
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

function Client:Fire(event, ...)
    for _, f in ipairs(self.frames) do
        if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end
    end
end

function Client:Tick(step)
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
    self.frames, self.tooltipCalls, self.units = {}, {}, {}
    self.prefixes, self.missingGlobals, self.newGlobals = {}, {}, {}
    self.loaded = { [ADDON] = true }
    for _, a in ipairs(self.addons) do self.loaded[a] = true end
    self.summonCalls = 0
    local env = self:BuildEnv()
    if self.patch then self.patch(env, self) end
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
    for _, path in ipairs(TOC.files) do Load(env, path, ADDON, self.ns) end
    self:Fire("ADDON_LOADED", ADDON)
    self:Fire("PLAYER_LOGIN")
    self:Fire("PLAYER_ENTERING_WORLD", true, false)
    return self
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

-- Chat lines the addon printed for this client (color codes stripped).
function Client:Printed(pattern, plain)
    for i = #self.printed, 1, -1 do
        if self.printed[i]:find(pattern, 1, plain) then return self.printed[i] end
    end
end
function Client:ClearPrinted() self.printed = {} end

function Client:Slash(text) return self.env.SlashCmdList.DYREPARKEN(text) end

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

function Client:EnterCombat() self.state.combat = true; self:Fire("PLAYER_REGEN_DISABLED") end
function Client:LeaveCombat() self.state.combat = false; self:Fire("PLAYER_REGEN_ENABLED") end
function Client:Mount() self.state.mounted = true; self:Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
function Client:Dismount() self.state.mounted = false; self:Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
function Client:Summon(sid) self.summoned = sid and self:GuidOf(sid) or nil end
function Client:Zone()
    self:Fire("PLAYER_LEAVING_WORLD")
    self:Fire("PLAYER_ENTERING_WORLD", false, false)
end

-- World tooltip -------------------------------------------------------------------
-- Hover a companion: o = { species, owner ("First Surname" or nil), companion (false: not a pet) }.
-- Returns the lines the addon added.
function Client:Hover(o)
    local unit = "mouseover"
    local lines = { { leftText = SpeciesName(o.species or 0) } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner) }
    end
    lines[#lines + 1] = { leftText = "Pet Level 1 Critter" }
    if o.lines then lines = o.lines end
    self.units[unit] = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = SpeciesName(o.species or 0) }
    local tip = self.env.GameTooltip
    tip:ClearLines()
    tip.unit = unit
    if o.unit == false then tip.unit = nil end
    local before = #tip.lines
    for _, fn in ipairs(self.tooltipCalls) do
        fn(o.tooltip or tip, o.noData and nil or { lines = lines })
    end
    local added = {}
    for i = before + 1, #tip.lines do added[#added + 1] = tip.lines[i] end
    return added, table.concat(added, " / ")
end

-- Pet journal -----------------------------------------------------------------------
-- Loads "Blizzard_Collections" (stub frames) on first open, shows it, and
-- lists the owned pets plus `o.extra` unowned species.
-- o.bare: list buttons without .speciesID (fallback via elementData.index)
-- o.scrollUtil: no PetJournal_InitPetButton, use ScrollUtil callbacks
function Client:OpenJournal(o)
    o = o or {}
    local env = self.env
    if not rawget(env, "PetJournal") then
        local PJ = env.CreateFrame("Frame", "PetJournal")
        PJ.shown = false
        PJ.ScrollBox = { buttons = {} }
        function PJ.ScrollBox:ForEachFrame(fn) for _, b in ipairs(self.buttons) do fn(b) end end
        env.CreateFrame("Frame", "PetJournalPetCard", PJ)
        env.CreateFrame("Button", "PetJournalSummonButton", PJ)
        if o.scrollUtil then
            self.scrollCallbacks = {}
            rawset(env, "ScrollUtil", { AddInitializedFrameCallback = function(box, fn, owner)
                assert(box == PJ.ScrollBox)
                self.scrollCallbacks[#self.scrollCallbacks + 1] = fn
            end })
        else
            rawset(env, "PetJournal_InitPetButton", function() end)
        end
        rawset(env, "PetJournal_UpdatePetCard", function() end)
        self.loaded.Blizzard_Collections = true
        self:Fire("ADDON_LOADED", "Blizzard_Collections")
    end
    self:ListPets(o)
    env.PetJournal:Show()
    return self
end

function Client:CloseJournal() self.env.PetJournal:Hide() end

function Client:ListPets(o)
    o = o or {}
    local env = self.env
    local list = {}
    for _, p in ipairs(self.pets) do list[#list + 1] = { guid = p.guid, sid = p.sid, owned = true } end
    for _, sid in ipairs(o.extra or {}) do list[#list + 1] = { sid = sid, owned = false } end
    self.journalList = list
    local buttons = {}
    for i, e in ipairs(list) do
        local b = env.CreateFrame("Button", nil, env.PetJournal)
        if not o.bare then b.petID, b.speciesID, b.owned = e.guid, e.sid, e.owned end
        b.sid = e.sid -- for the harness only
        buttons[i] = b
    end
    env.PetJournal.ScrollBox.buttons = buttons
    for i, b in ipairs(buttons) do
        if rawget(env, "PetJournal_InitPetButton") then
            env.PetJournal_InitPetButton(b, { index = i })
        else
            for _, fn in ipairs(self.scrollCallbacks or {}) do fn(nil, b, { index = i }) end
        end
    end
end

-- Texture path of the marker on a species' list button, or nil if hidden.
function Client:Marker(sid)
    for _, b in ipairs(self.env.PetJournal.ScrollBox.buttons) do
        if b.sid == sid then
            local t = b.textures[1]
            return t and t.shown and t.tex or nil
        end
    end
    error("no list button for species " .. sid)
end

function Client:Button(sid)
    for _, b in ipairs(self.env.PetJournal.ScrollBox.buttons) do if b.sid == sid then return b end end
end

-- Select a pet on the card, as the journal does.
function Client:SelectPet(sid, byPetID)
    local card = self.env.PetJournalPetCard
    if byPetID then card.speciesID, card.petID = nil, self:GuidOf(sid) else card.speciesID, card.petID = sid, nil end
    self.env.PetJournal_UpdatePetCard(card)
    return self.ns.JournalUI._card
end

function Client:Card() return self.ns.JournalUI._card end

-- The last StaticPopup shown; Accept types `text` into its edit box.
function Client:PopupAccept(text, viaEnter)
    local p = assert(self.popup, "no popup shown")
    local dialog = self.env.StaticPopupDialogs[p.which]
    local eb = { text = "" }
    function eb:SetText(t) self.text = t end
    function eb:GetText() return self.text end
    function eb:HighlightText() end
    local frame = { editBox = eb, Hide = function(f) f.hidden = true end }
    function eb:GetParent() return frame end
    if dialog.OnShow then dialog.OnShow(frame) end
    local shown = eb.text
    eb.text = text
    if viaEnter then dialog.EditBoxOnEnterPressed(eb) else dialog.OnAccept(frame) end
    self.popup = nil
    return shown, frame
end

------------------------------------------------------------------------------
-- The stub client API (one environment per client)
------------------------------------------------------------------------------
function Client:BuildEnv()
    local c, w = self, self.world
    local env = NewEnv()
    local S = self.state
    local function Plain(v) return v end

    env.print = function(...) c.printed[#c.printed + 1] = table.concat({ ... }, " ") end
    env.GetTime = function() return w.t end
    env.GetServerTime = function() return w:ServerTime() end
    env.time, env.date = os.time, os.date
    env.geterrorhandler = function() return function(e) c.errors[#c.errors + 1] = tostring(e) end end
    env.debugstack = function() return debug.traceback() end
    env.hooksecurefunc = function(a, b, fn)
        local t, name = env, a
        if type(a) == "table" then t, name = a, b else fn = b end
        local old = rawget(t, name)
        assert(type(old) == "function", "hooksecurefunc: " .. tostring(name) .. " is not a function")
        rawset(t, name, function(...)
            local r = { old(...) }
            fn(...)
            return unpack(r)
        end)
    end
    env.issecretvalue = function(v) return v == H.SECRET end
    env.C_Secrets = { ShouldAurasBeSecret = function() return S.secretAuras == true end }

    -- Frames
    env.CreateFrame = function(ftype, name, parent, template)
        local f = setmetatable({ type = ftype, name = name, parent = parent, events = {}, scripts = {},
            shown = true, enabled = true, checked = false, textures = {}, fontStrings = {}, template = template }, Frame)
        c.frames[#c.frames + 1] = f
        if name then rawset(env, name, f) end
        return f
    end
    env.UIParent = env.CreateFrame("Frame", "UIParent")
    env.Minimap = env.CreateFrame("Frame", "Minimap", env.UIParent)
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m)
        c.printed[#c.printed + 1] = (tostring(m):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end }
    env.SlashCmdList = {}
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(which, ...) c.popup = { which = which, args = { ... } } end
    env.ACCEPT, env.CANCEL = "Accept", "Cancel"
    env.UNITNAME_TITLE_COMPANION = "%s's Companion"

    local tip = { lines = {} }
    function tip:AddLine(text) self.lines[#self.lines + 1] = text end
    function tip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " " .. b end
    function tip:SetText(text) self.lines = { text } end
    function tip:ClearLines() self.lines = {} end
    function tip:SetOwner(owner) self.owner = owner; self.lines = {} end
    function tip:IsOwned(owner) return self.owner == owner end
    function tip:Show() self.shown = true end
    function tip:Hide() self.shown = false; self.owner = nil end
    function tip:GetUnit()
        if not self.unit then return nil end
        local u = c.units[self.unit]
        return u and u.name, self.unit
    end
    env.GameTooltip = tip

    -- Player state
    env.InCombatLockdown = function() return S.combat == true end
    env.UnitAffectingCombat = function() return S.combat == true end
    env.IsMounted = function() return S.mounted or false end
    env.UnitOnTaxi = function() return S.taxi or false end
    env.UnitIsDeadOrGhost = function() return S.dead or false end
    env.IsFlying = function() return S.flying or false end
    env.IsStealthed = function() return S.stealthed or false end
    env.UnitCastingInfo = function() return S.casting end
    env.UnitChannelInfo = function() return S.channeling end
    env.IsInInstance = function() return S.instance ~= "none", S.instance end
    env.UnitStandState = function() return S.stand end
    env.C_Spell = { GetSpellName = function(id) return S.spellNames and S.spellNames[id] end }
    env.C_UnitAuras = { GetAuraDataBySpellName = function(unit, name, filter)
        assert(unit == "player" and filter == "HELPFUL")
        if S.aurasError then error("aura query failed") end
        return S.auras[name] and { name = name } or nil
    end }

    -- Identity (Forever: the second value is the SURNAME, not the realm)
    local function UnitNameOf(u)
        if u == nil or u == "player" then return c.first, c.surname end
        local g = w:GroupOf(c.name)
        local kind, i = tostring(u):match("^(%a+)(%d+)$")
        i = tonumber(i)
        if g and kind == "party" then
            local n = 0
            for _, name in ipairs(g.members) do
                if name ~= c.name then
                    n = n + 1
                    if n == i then return name:match("^(%S+)%s*(.*)$") end
                end
            end
        elseif g and kind == "raid" and g.members[i] then
            return g.members[i]:match("^(%S+)%s*(.*)$")
        end
        local unit = c.units[u]
        if unit then return unit.name end
    end
    env.UnitName = UnitNameOf
    env.UnitFullName = UnitNameOf
    env.UnitExists = function(u) return u == "player" or c.units[u] ~= nil end
    env.UnitGUID = function() return ("Player-0000-%08X"):format(c.idx) end
    env.GetPlayerInfoByGUID = function() return "Warrior", "WARRIOR", "Human", "Human", 2, c.first, "" end
    env.GetNormalizedRealmName = function() return "CAMWOWEU4Realm1PvE" end
    env.GetRealmName = env.GetNormalizedRealmName
    env.GetAutoCompleteRealms = function() return { "CAMWOWEU4Realm1PvE", "CAMWOWEU4Realm2PvE" } end
    env.Ambiguate = function(n) return n end
    env.GetBuildInfo = function() return "1.60.1", "70790", "Nov 4 2026", 16001 end
    env.WOW_PROJECT_ID, env.WOW_PROJECT_CAMELOT = 18, 18
    env.GetFramerate = function() return 60 end

    -- Guild
    env.IsInGuild = function() return c.guild ~= nil end
    env.GetGuildInfo = function(u) if c.guild then return c.guild, "Member", 3, nil end end
    local function Rows() return c.guild and w:Roster(c.guild) or {} end
    env.GetNumGuildMembers = function()
        local rows, online = Rows(), 0
        for _, r in ipairs(rows) do if r.online then online = online + 1 end end
        return #rows, online, online
    end
    env.GetGuildRosterInfo = function(i)
        if c.rosterPartial and i > c.rosterPartial then return nil end
        local r = Rows()[i]
        if r then return r.name, "Member", 3, 60, "Warrior", "Elwynn Forest", "", "", r.online end
    end
    -- (years, months, days, hours) for offline members, nil when online.
    env.GetGuildRosterLastOnline = function(i)
        local r = Rows()[i]
        if not r or r.online then return nil end
        local d = r.days
        return math.floor(d / 365), math.floor((d % 365) / 30), (d % 365) % 30, 0
    end
    env.C_GuildInfo = { GuildRoster = function()
        c.rosterRequests = (c.rosterRequests or 0) + 1
        if c.rosterIgnored then return end
        w:Timer(c, 0.3, function() c:Fire("GUILD_ROSTER_UPDATE", false) end)
    end }

    -- Group
    env.IsInGroup = function() return w:GroupOf(c.name) ~= nil end
    env.IsInRaid = function() local g = w:GroupOf(c.name); return g ~= nil and #g.members > 5 end
    env.GetNumGroupMembers = function() local g = w:GroupOf(c.name); return g and #g.members or 0 end
    env.GetNumSubgroupMembers = function() local g = w:GroupOf(c.name); return g and math.min(#g.members, 5) - 1 or 0 end
    env.UnitIsGroupLeader = function(u)
        local g = w:GroupOf(c.name)
        return g ~= nil and (u == "player" and g.members[1] == c.name)
    end
    env.UnitIsGroupAssistant = function() return c.assist == true end
    env.UnitInParty = function(u) return u == "player" and w:GroupOf(c.name) ~= nil end
    env.UnitInRaid = function(u) return u == "player" and env.IsInRaid() and 1 or nil end
    env.SendChatMessage = function(text, chan) w.chat[#w.chat + 1] = { from = c.name, text = text, chan = chan } end

    -- Timers
    env.C_Timer = {
        After = function(s, fn) w:Timer(c, s, fn) end,
        NewTimer = function(s, fn)
            local h = { cancelled = false }
            function h:Cancel() self.cancelled = true end
            w:Timer(c, s, function() if not h.cancelled then fn(h) end end)
            return h
        end,
    }

    -- Sound: mutes are a set of file IDs (the client forgets them on reload).
    c.muted = {}
    env.MuteSoundFile = function(id) c.muted[id] = true end
    env.UnmuteSoundFile = function(id) c.muted[id] = nil end

    -- Settings, addons
    env.C_CVar = { GetCVar = function(k) return (c.cvars or {})[k] or "1" end,
        SetCVar = function(k, v) c.cvars = c.cvars or {}; c.cvars[k] = tostring(v) end }
    env.C_AddOns = {
        GetAddOnMetadata = function(name, k)
            if name ~= ADDON then return nil end
            if k == "Version" then return c.version end
            if k == "X-Protocol" then return c.protocol end
            return TOC.meta[k]
        end,
        IsAddOnLoaded = function(n) return c.loaded[n] or false end,
    }

    -- Addon messages
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(p)
            assert(#p <= 16, "prefix too long")
            c.prefixes[p] = true
            return true
        end,
        IsAddonMessagePrefixRegistered = function(p) return c.prefixes[p] == true end,
        SendAddonMessage = function(prefix, text, chan, target)
            assert(type(text) == "string" and #text <= 255, "addon message over 255 bytes")
            assert(chan ~= "WHISPER" or target, "whisper without target")
            if c.trial then return 7 end -- Trial/Veteran accounts can't send
            w:Transmit(c, prefix, text, chan, target)
            return 0
        end,
    }
    env.Enum = {
        SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, NotInGroup = 5, AddOnMessageLockdown = 11 },
        TooltipDataType = { Unit = 2 },
    }

    -- Units (companions in the world)
    env.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
        assert(kind == env.Enum.TooltipDataType.Unit)
        c.tooltipCalls[#c.tooltipCalls + 1] = fn
    end }
    env.UnitIsBattlePetCompanion = function(u) local x = c.units[u]; return x and x.companion or false end
    env.UnitBattlePetSpeciesID = function(u) local x = c.units[u]; return x and x.species end
    env.UnitCreator = function() return nil end -- no owner API on Forever
    env.C_TooltipInfo = { GetUnit = function(u) local x = c.units[u]; return x and { lines = x.lines } end }

    -- Pet journal (Forever: GetPetInfoByPetID's real shape, probed 2026-11-06)
    local function NoFilters() error("Dyreparken must not change the pet journal filters (see CLAUDE.md)", 2) end
    env.C_PetJournal = {
        GetSummonedPetGUID = function() return c.summoned end,
        GetOwnedPetIDs = not c.noOwnedPetIDs and function()
            local ids = {}
            for _, p in ipairs(c.pets) do ids[#ids + 1] = p.guid end
            return ids
        end or nil,
        GetPetInfoByPetID = function(guid)
            for _, p in ipairs(c.pets) do
                if p.guid == guid then
                    if c.noSpeciesID then return 0, nil, 1, 0, 1, 1, false, SpeciesName(p.sid), 1, 5 end
                    return p.sid, nil, 1, 0, 1, 146955, false, SpeciesName(p.sid), 7831521, 5, 272330, ""
                end
            end
            error("Invalid pet GUID")
        end,
        GetPetInfoBySpeciesID = function(sid)
            if not H.SPECIES[sid] then return nil end
            return H.SPECIES[sid], 1000 + sid, 5, 272330
        end,
        GetNumPets = function() return #(c.journalList or c.pets), #c.pets end,
        GetPetInfoByIndex = function(i)
            local list = c.journalList or {}
            if not c.journalList then
                for _, p in ipairs(c.pets) do list[#list + 1] = { guid = p.guid, sid = p.sid, owned = true } end
            end
            local e = list[i]
            if e then return e.guid, e.sid, e.owned end
        end,
        -- Forever: toggles. Called on the pet that's out, it dismisses it.
        SummonPetByGUID = function(guid)
            c.summonCalls = c.summonCalls + 1
            if (c.summonFails or 0) > 0 then c.summonFails = c.summonFails - 1; return end
            c.summoned = c.summoned ~= guid and guid or nil
        end,
        PetIsSummonable = function() return true end,
        -- The journal's filters: Forever has no Filter button, so a filter left
        -- wrong empties the list for good. The addon must never change them.
        SetFilterChecked = NoFilters, SetAllPetTypesChecked = NoFilters, SetAllPetSourcesChecked = NoFilters,
        SetPetTypeFilter = NoFilters, SetPetSourceChecked = NoFilters, SetSearchFilter = NoFilters,
        ClearSearchFilter = NoFilters, SetDefaultFilters = NoFilters,
        GetNumCollectedInfo = function() return 1, 1 end,
    }
    return env
end

------------------------------------------------------------------------------
-- Assertions
------------------------------------------------------------------------------
local function Show(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. Show(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end
H.Show = Show

function H.eq(actual, expected, msg)
    if actual ~= expected then
        error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", Show(expected), Show(actual)), 2)
    end
end

function H.ok(v, msg)
    if not v then error(msg or "expected a true value", 2) end
    return v
end

function H.no(v, msg)
    if v then error((msg or "expected a false value") .. " (got " .. Show(v) .. ")", 2) end
end

function H.match(s, pattern, msg)
    if type(s) ~= "string" or not s:find(pattern) then
        error(("%sexpected %s to match %q"):format(msg and (msg .. ": ") or "", Show(s), pattern), 2)
    end
end

-- Every client in the world agrees on the registry: same digest, same holders.
function H.converged(w, names)
    local ref, refHolders
    for _, c in ipairs(w.clients) do
        if c.online and c.guild and (not names or names[c.name]) then
            local d = c.ns.Sync:Digest()
            local holders = Show(c.ns.Registry:Holders())
            if not ref then
                ref, refHolders = d, holders
            elseif d ~= ref or holders ~= refHolders then
                return false, ("%s differs: %s vs %s"):format(c.name, holders, refHolders)
            end
        end
    end
    return true
end

function H.assertConverged(w, msg)
    local ok, why = H.converged(w)
    if not ok then error((msg and (msg .. ": ") or "") .. why, 2) end
end

return H
