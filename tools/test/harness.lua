-- Test harness: a simulated world with several WoW clients, each running its
-- own copy of the addon, connected by a fake addon-message network.
--
--   local w = H.World()                       -- clock, guild, network
--   local ola = w:AddClient("Ola Nord", { pets = { 5159, 46 } })
--   local kari = w:AddClient("Kari Berg")
--   w:Run(15)                                 -- advance time: OnUpdate, timers, delivery
--   w:Settle("hello")                         -- ... to a named stage of the login (World.SETTLE)
--   local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } } -- the usual world, settled
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
    UNIT_AURA ZONE_CHANGED_NEW_AREA PLAYER_TARGET_CHANGED UPDATE_MOUSEOVER_UNIT CHAT_MSG_GUILD
    CHAT_MSG_PARTY CHAT_MSG_RAID NEW_PET_ADDED PET_JOURNAL_LIST_UPDATE
    ENCOUNTER_START ENCOUNTER_END BOSS_KILL PLAYER_PVP_KILLS_CHANGED QUEST_TURNED_IN UNIT_SPELLCAST_SUCCEEDED
    PLAYER_DEAD PLAYER_ALIVE PLAYER_UNGHOST MIRROR_TIMER_START PLAYER_LEVEL_UP PLAYER_FLAGS_CHANGED
    CHAT_MSG_TEXT_EMOTE CHAT_MSG_SKILL CHAT_MSG_COMBAT_FACTION_CHANGE
    NAME_PLATE_UNIT_ADDED NAME_PLATE_UNIT_REMOVED FORBIDDEN_NAME_PLATE_UNIT_ADDED]]):gmatch("%S+") do
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
    "SetMotionScriptsWhileDisabled", "SetFrameStrata", "EnableMouse", "SetMovable", "RegisterForDrag",
    "StartMoving", "StopMovingOrSizing",
    "RegisterForClicks", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetJustifyH",
    "SetJustifyV", "SetFontObject", "SetWordWrap" }) do
    Frame[m] = noop
end

function Frame:RegisterEvent(e)
    if not KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    self.events[e] = true
end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:LockHighlight() self.highlightLocked = true end
function Frame:UnlockHighlight() self.highlightLocked = false end
function Frame:RegisterUnitEvent(e, ...)
    if not KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    self.events[e] = true
    self.unitFilter = self.unitFilter or {}
    self.unitFilter[e] = { ... }
end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(e) return self.events[e] == true end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:HookScript(k, fn)
    local old = self.scripts[k]
    self.scripts[k] = old and function(...) old(...); fn(...) end or fn
end
-- Like the client: showing or hiding a frame also fires OnShow/OnHide on
-- its shown descendants, whose visibility changes with it.
local function Cascade(f, script)
    for _, kid in ipairs(f.client and f.client.frames or {}) do
        if kid.parent == f and kid.shown then
            if kid.scripts[script] then kid.scripts[script](kid) end
            Cascade(kid, script)
        end
    end
end
function Frame:Show()
    if self.shown then return end
    self.shown = true
    if self:IsVisible() then
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        Cascade(self, "OnShow")
    end
end
function Frame:Hide()
    if not self.shown then return end
    local was = self.parent == nil or self.parent:IsVisible()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
    if was then Cascade(self, "OnHide") end
end
function Frame:IsShown() return self.shown end
function Frame:IsForbidden() return self.forbidden == true end
function Frame:IsVisible()
    if not self.shown then return false end
    return self.parent == nil or self.parent:IsVisible()
end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) self.parent = p end
function Frame:GetName() return self.frameName end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:IsEnabled() return self.enabled end
function Frame:SetEnabled(v) self.enabled = not not v end
-- Geometry: nil (not laid out) unless a test sets f.geo = { l, r, t, b }.
function Frame:GetLeft() return self.geo and self.geo.l end
function Frame:GetEffectiveScale() return self.scale or 1 end
function Frame:GetRight() return self.geo and self.geo.r end
function Frame:GetTop() return self.geo and self.geo.t end
function Frame:GetBottom() return self.geo and self.geo.b end
function Frame:GetWidth() return self.geo and (self.geo.r - self.geo.l) end
function Frame:GetHeight() return self.geo and (self.geo.t - self.geo.b) end
function Frame:GetObjectType() return self.type end
-- The recorded anchors and size, as the client reports them.
function Frame:GetPoint(i) local p = (self.points or {})[i or 1]; if p then return unpack(p) end end
function Frame:GetSize() if self.size then return self.size[1], self.size[2] end return 0, 0 end
function Frame:GetChildren()
    local kids = {}
    for _, f in ipairs(self.client.frames) do if f.parent == self then kids[#kids + 1] = f end end
    return unpack(kids)
end
function Frame:GetRegions()
    local all = {}
    for _, t in ipairs(self.textures) do all[#all + 1] = t end
    for _, t in ipairs(self.fontStrings) do all[#all + 1] = t end
    return unpack(all)
end
function Frame:SetCheckedTexture(x) self.checkedTex = x end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetFrameLevel(n) self.level = n end
-- StatusBar
function Frame:SetStatusBarTexture(x) self.barTex = x end
function Frame:SetStatusBarColor(...) self.barColor = { ... } end
function Frame:GetStatusBarTexture()
    if not self.barRegion then self.barRegion = self:CreateTexture() end
    return self.barRegion
end
function Frame:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Frame:SetValue(v) self.value = v end
-- Anchors and size are recorded (not laid out): f.points, f.size.
function Frame:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetSize(w, h) self.size = { w, h } end
function Frame:SetWidth(w) self.size = { w, self.size and self.size[2] } end
function Frame:SetHeight(h) self.size = { self.size and self.size[1], h } end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:SetScrollChild(f) self.scrollChild = f end
function Frame:SetChecked(v) self.checked = not not v end
function Frame:GetChecked() return self.checked end
-- Like the client: a disabled button ignores clicks; a check button flips
-- its state before OnClick runs.
-- Runs fn as a hardware event (a keypress or click) for client c: only then
-- may the addon post to guild chat (Forever, docs/FOREVER_API.md).
local function Hardware(c, fn, ...)
    if not c then return fn(...) end
    c.hardware = (c.hardware or 0) + 1
    local r = { pcall(fn, ...) }
    c.hardware = c.hardware - 1
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, table.maxn(r))
end
H.Hardware = Hardware

function Frame:Click()
    if not self.enabled then return end
    if self.type == "CheckButton" then self.checked = not self.checked end
    if self.scripts.OnClick then Hardware(self.client, self.scripts.OnClick, self, "LeftButton") end
end

local Region = {}
Region.__index = Region
for _, m in ipairs({ "SetWidth", "SetHeight", "SetAllPoints", "SetJustifyH", "SetJustifyV",
    "SetDrawLayer", "SetWordWrap" }) do
    Region[m] = noop
end
function Region:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function Region:ClearAllPoints() self.points = {} end
function Region:SetTexture(x) self.tex = x; self.atlas = nil end -- (an atlas set before is gone)
function Region:GetTexture() return self.tex end
function Region:SetAtlas(x) self.tex = x; self.atlas = x end
function Region:SetTexCoord(...) self.texCoord = { ... } end

-- Animation groups (texture:CreateAnimationGroup): recorded, not run. The
-- client plays them on its own (no OnUpdate in the addon).
local AnimGroup, Anim = {}, {}
AnimGroup.__index, Anim.__index = AnimGroup, Anim
local ANIM_TYPES = { Alpha = true, Translation = true, Scale = true, Rotation = true }
function AnimGroup:CreateAnimation(kind)
    if not ANIM_TYPES[kind] then error("unknown animation type " .. tostring(kind), 2) end
    local a = setmetatable({ kind = kind, group = self }, Anim)
    self.anims[#self.anims + 1] = a
    return a
end
function AnimGroup:SetLooping(v) self.looping = v end
function AnimGroup:SetToFinalAlpha(v) self.finalAlpha = v end
function AnimGroup:Play() self.playing = true; self.plays = (self.plays or 0) + 1 end
function AnimGroup:Stop() self.playing = false end
function AnimGroup:IsPlaying() return self.playing == true end
function AnimGroup:GetAnimations() return unpack(self.anims) end
-- OnFinished etc.: kept, and run by a test with g:Finish() (a one-shot group ending).
function AnimGroup:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function AnimGroup:Finish()
    self.playing = false
    if self.scripts and self.scripts.OnFinished then self.scripts.OnFinished(self) end
end
for _, m in ipairs({ "Duration", "StartDelay", "Order", "Smoothing", "FromAlpha", "ToAlpha", "Degrees" }) do
    local key = m:sub(1, 1):lower() .. m:sub(2)
    Anim["Set" .. m] = function(self, v) self[key] = v end
end
function Anim:SetOffset(x, y) self.offset = { x, y } end
function Anim:SetScale(x, y) self.scale = { x, y } end
function Anim:SetScaleFrom(x, y) self.scaleFrom = { x, y } end
function Anim:SetScaleTo(x, y) self.scaleTo = { x, y } end
function Anim:SetOrigin(point, x, y) self.origin = { point, x, y } end
function Region:CreateAnimationGroup()
    local g = setmetatable({ anims = {}, parent = self }, AnimGroup)
    self.animGroups = self.animGroups or {}
    self.animGroups[#self.animGroups + 1] = g
    return g
end
function Region:SetRotation(r) self.rotation = r end
Frame.CreateAnimationGroup = Region.CreateAnimationGroup
function Frame:SetAlpha(a) self.alpha = a end
function Region:SetSize(w, h) self.size = { w, h } end
function Region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
-- Nine-slice a texture (Retail 10.0+): the margins stay, the middle stretches.
function Region:SetTextureSliceMargins(l, t, r, b) self.slice = { l, t, r, b } end
function Region:SetTextureSliceMode(m) self.sliceMode = m end
function Region:GetAtlas() return self.atlas end
function Region:SetColorTexture(...) self.color = { ... } end
function Region:SetHorizTile(v) self.horizTile = v end
function Region:SetVertTile(v) self.vertTile = v end
function Region:AddMaskTexture(m) self.mask = m end
function Region:GetObjectType() return self.ftype or "Texture" end
function Region:GetPoint(i) local p = (self.points or {})[i or 1]; if p then return unpack(p) end end
function Region:GetSize() if self.size then return self.size[1], self.size[2] end return 0, 0 end
function Region:GetDrawLayer() return "ARTWORK" end
function Region:GetWidth() return 16 end
function Region:GetHeight() return 16 end
function Region:SetDesaturated(v) self.desaturated = not not v end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end
function Region:SetShown(v) self.shown = not not v end
local function StripColors(x) return (tostring(x):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
H.StripColors = StripColors
-- .text as set, .plain without color codes (for assertions)
function Region:SetText(x) self.text = x; self.plain = x and StripColors(x) end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:SetShadowOffset(x, y) self.shadow = { x, y } end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetGradient(o, a, b) self.gradient = { o, a, b } end
function Region:SetBlendMode(m) self.blend = m end
-- The font in use, and the text's width estimated from it (px per character).
local FONT_W = { GameFontNormalHuge = 13, GameFontNormalLarge = 10, GameFontNormal = 8 }
function Region:SetFontObject(f) self.font = f end
function Region:GetStringWidth() return #(self.plain or self.text or "") * (FONT_W[self.font] or 7) end
-- About 14 px a line, like GameFontHighlight.
function Region:GetStringHeight()
    local _, n = (self.text or ""):gsub("\n", "")
    return self.text and (n + 1) * 14 or 0
end

function Frame:CreateTexture()
    local t = setmetatable({ shown = true }, Region)
    self.textures[#self.textures + 1] = t
    return t
end
function Frame:CreateMaskTexture()
    local t = setmetatable({ shown = true, ftype = "MaskTexture" }, Region)
    self.textures[#self.textures + 1] = t
    return t
end
function Frame:CreateFontString(_, _, template)
    local t = setmetatable({ shown = true, ftype = "FontString", font = template }, Region)
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

-- The usual world: Ola Nord (and Kari Berg, if given), logged in and
-- settled. o.ola / o.kari: a pets list or the client's opts; o.each(c):
-- before the login settles (fixtures, stubs); o.settle: a stage (World:Settle,
-- default "day"); o.journal: Ola opens the pet journal (true, or its opts).
-- Returns w, ola, kari.
function H.Setup(o)
    o = o or {}
    local w = H.World(o.world)
    local function Opts(v) return type(v[1]) == "number" and { pets = v } or v end
    local ola = w:AddClient("Ola Nord", Opts(o.ola or { 5159 }))
    local kari = o.kari and w:AddClient("Kari Berg", Opts(o.kari))
    if o.each then o.each(ola); if kari then o.each(kari) end end
    w:Settle(o.settle)
    if o.journal then ola:OpenJournal(o.journal ~= true and o.journal or nil) end
    return w, ola, kari
end

function World:ServerTime() return self.server + math.floor(self.t) end

-- Jump ahead without simulating (days of being away). GetTime keeps going
-- slowly; only the server clock jumps, which is what the addon compares.
function World:Skip(seconds) self.server = self.server + seconds end
function World:SkipDays(days) self:Skip(days * 86400) end

-- Bring every online client's adopted pet up to the bond level that allows a
-- nickname (Config.NICKNAME_LEVEL), through Bond:Add like real points (it's
-- published the same way). For tests that name pets; it was 7 days of care
-- until 2026-11-09.
function World:Befriend()
    for _, c in ipairs(self.clients) do
        if c.online and c.ns.Registry:MyPet() then
            local need = c.ns.Bond.LEVELS[c.ns.Config.NICKNAME_LEVEL][1]
            local p = c.ns.Bond:Of(c.ns.Registry:MyPet()) or 0
            if p < need then c.ns.Bond:Add(need - p) end
        end
    end
end

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

-- The login, in named stages (the addon's own timers: Main.lua, Bond.lua,
-- Activity.lua, Bonds.lua). Each waits from now:
--   hello  12 s: past the settled and hello phases (10 s) and the HELLO round
--   bond   20 s: Bond's seed and first publish (20 s)
--   day    40 s: the first day's visit and the login lines (30 s), and what they send
World.SETTLE = { hello = 12, bond = 20, day = 40 }
function World:Settle(stage)
    self:Run((assert(World.SETTLE[stage or "day"], "unknown stage")))
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
        -- A SYNC goes in parts (Sync.lua): counted once, by its first.
        local part = kind == "SYNC" and m.msg and m.msg.i
        if m.kind == kind and (not from or m.from == from) and (not part or part == 1) then n = n + 1 end
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
--   patch (function(env, c): change the stub API before the addon loads),
--   rank (guild rank index: 0 guild master, 1 officer, default 3 member),
--   oldTemplates (the client lacks the modern frame templates)
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
        idx = #self.clients + 1, patch = opts.patch, rank = opts.rank or 3, oldTemplates = opts.oldTemplates,
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
    -- The bond epoch (no bond is older than the addon) as in the real world:
    -- before any test data. The test clock starts in September 2026.
    self.ns.Config.BOND_EPOCH = self.world.epoch or (1790000000 - 1000 * 86400)
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

function Client:EnterCombat() self.state.combat = true; self:Fire("PLAYER_REGEN_DISABLED") end
function Client:LeaveCombat() self.state.combat = false; self:Fire("PLAYER_REGEN_ENABLED") end
function Client:Mount() self.state.mounted = true; self:Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
function Client:Dismount() self.state.mounted = false; self:Fire("PLAYER_MOUNT_DISPLAY_CHANGED") end
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
-- A nameplate comes up over a unit: o = { species, owner, companion (false: not a pet), name, forbidden }.
-- Returns the unit token and the plate.
function Client:Nameplate(o)
    local n = 0
    for _ in pairs(self.plates) do n = n + 1 end
    local unit = "nameplate" .. (n + 1)
    local lines = { { leftText = o.name or SpeciesName(o.species or 0), lineIndex = 1 } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner), lineIndex = 2 }
    end
    self.units[unit] = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = o.name or SpeciesName(o.species or 0) }
    local plate = self.env.CreateFrame("Frame")
    plate.namePlateUnitToken, plate.forbidden = unit, o.forbidden
    plate:Show()
    self.plates[unit] = plate
    self:Fire(o.forbidden and "FORBIDDEN_NAME_PLATE_UNIT_ADDED" or "NAME_PLATE_UNIT_ADDED", unit)
    return unit, plate
end

function Client:Zone()
    self:Fire("PLAYER_LEAVING_WORLD")
    self:Fire("PLAYER_ENTERING_WORLD", false, false)
end

-- World tooltip -------------------------------------------------------------------
-- Hover a companion: o = { species, owner ("First Surname" or nil), companion (false: not a pet) }.
-- Returns the lines the addon added (and the whole tooltip, third).
function Client:Hover(o)
    local unit = "mouseover"
    local lines = { { leftText = SpeciesName(o.species or 0) } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner) }
    end
    lines[#lines + 1] = { leftText = "Pet Level 1 Critter" }
    if o.lines then lines = o.lines end
    for i, l in ipairs(lines) do if type(l) == "table" and l.lineIndex == nil then l.lineIndex = i end end
    self.units[unit] = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = SpeciesName(o.species or 0) }
    local tip = self.env.GameTooltip
    tip:ClearLines()
    -- The client fills in the unit's own lines before the post-calls run.
    for _, l in ipairs(lines) do
        if type(l.leftText) == "string" then tip:AddLine(l.leftText) end
    end
    tip.unit = unit
    if o.unit == false then tip.unit = nil end
    local before = #tip.lines
    local data = not o.noData and { lines = lines } or nil
    self.lastTooltipData = data
    for _, fn in ipairs(self.tooltipCalls) do
        fn(o.tooltip or tip, data)
    end
    local added = {}
    for i = before + 1, #tip.lines do added[#added + 1] = tip.lines[i] end
    -- Third: every line of the tooltip as shown, after any rewriting.
    return added, table.concat(added, " / "), tip.lines
end

-- Target a companion (same o as Hover; nil clears the target).
function Client:Target(o)
    if not o then self.units.target = nil; return end
    local lines = { { leftText = SpeciesName(o.species or 0) } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner) }
    end
    lines[#lines + 1] = { leftText = "Pet Level 1 Critter" }
    self.units.target = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = o.name or SpeciesName(o.species or 0) }
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
        -- Forever's Collections window (probed 2026-11-07), with its side tabs
        -- along the right edge when o.sideTabs = n (laid out: geometry set):
        -- an unnamed strip as tall as the window, 55 px past its right edge,
        -- holding Frames CollectionsJournalTab1..n drawn with atlases. Tab 1
        -- is Mounts, tab 2 Pets (selected). A tab switches on mouse up
        -- (CollectionsJournal_SetTab): pages, the selected highlight, the title.
        local CJ = env.CreateFrame("Frame", "CollectionsJournal")
        CJ.shown = false
        CJ.titleFS = CJ:CreateFontString()
        CJ.GetTitleText = function(self) return self.titleFS end -- PortraitFrameMixin
        -- PortraitFrameTemplate's parentKeys: border, portrait, title, close
        -- button (frames), and the background (a tiled texture).
        CJ.NineSlice = env.CreateFrame("Frame", nil, CJ); CJ.NineSlice.level = 3
        CJ.PortraitContainer = env.CreateFrame("Frame", nil, CJ); CJ.PortraitContainer.level = 4
        CJ.PortraitContainer.portrait = CJ.PortraitContainer:CreateTexture()
        CJ.PortraitContainer.portrait:SetTexture(1001) -- Pets' portrait, a file id
        CJ.TitleContainer = env.CreateFrame("Frame", nil, CJ); CJ.TitleContainer.level = 5
        CJ.CloseButton = env.CreateFrame("Button", "CollectionsJournalCloseButton", CJ); CJ.CloseButton.level = 5
        CJ.Bg = CJ:CreateTexture(); CJ.Bg:SetTexture(2002)
        local MJ = env.CreateFrame("Frame", "MountJournal", CJ)
        MJ.shown = false
        local PJ = env.CreateFrame("Frame", "PetJournal", CJ)
        CJ.geo = o.sideTabs and { l = 0, r = 700, t = 600, b = 0 } or nil
        local strip = env.CreateFrame("Frame", nil, CJ)
        strip.geo = o.sideTabs and { l = 700, r = 755, t = 600, b = 0 } or nil
        local tabs = {}
        rawset(env, "CollectionsJournal_SetTab", function(cj, n)
            cj.selectedTab = n
            for i, t in ipairs(tabs) do
                t.sel1:SetShown(i == n); t.sel2:SetShown(i == n)
            end
            MJ:SetShown(n == 1)
            PJ:SetShown(n == 2)
            cj.titleFS:SetText(n == 1 and "Mounts" or n == 2 and "Pet Journal" or "Tab " .. n)
        end)
        for i = 1, o.sideTabs or 0 do
            local t = env.CreateFrame("Frame", "CollectionsJournalTab" .. i, strip)
            t:CreateTexture():SetAtlas("common-sidetab")
            t:CreateTexture():SetTexture("tab" .. i)
            t.sel1 = t:CreateTexture(); t.sel1:SetAtlas("common-sidetab-selected")
            t.sel2 = t:CreateTexture(); t.sel2:SetAtlas("common-sidetab-selected")
            t:CreateTexture():SetAtlas("common-sidetab-hover")
            t.geo = { l = 700, r = 755, t = 560 - (i - 1) * 57, b = 505 - (i - 1) * 57 }
            t:SetScript("OnMouseUp", function() env.CollectionsJournal_SetTab(CJ, i) end)
            tabs[i] = t
        end
        PJ.shown = false
        PJ.ScrollBox = { buttons = {} }
        function PJ.ScrollBox:ForEachFrame(fn) for _, b in ipairs(self.buttons) do fn(b) end end
        local petCard = env.CreateFrame("Frame", "PetJournalPetCard", PJ)
        -- Its title row: the pet's icon and name (Forever, /dp probe card 2026-11-08).
        petCard.PetInfo = env.CreateFrame("Button", "PetJournalPetCardPetInfo", petCard)
        petCard.PetInfo.icon = petCard.PetInfo:CreateTexture()
        petCard.PetInfo.name = petCard.PetInfo:CreateFontString()
        -- The "Total Pets" box (o.noPetCount leaves it out).
        if not o.noPetCount then PJ.PetCount = env.CreateFrame("Frame", nil, PJ) end
        -- The model with its two turn buttons (parentKeys, like Retail's
        -- ModelScene; o.noRotate leaves them out).
        if not o.noRotate then
            local model = env.CreateFrame("Frame", nil, petCard)
            petCard.modelScene = model
            model.RotateLeftButton = env.CreateFrame("Button", nil, model)
            model.RotateRightButton = env.CreateFrame("Button", nil, model)
        end
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
        -- Selects a species and shows its card (Blizzard_Collections; o.noSelect: missing).
        if not o.noSelect then
            rawset(env, "PetJournal_SelectSpecies", function(pj, sid)
                assert(pj == env.PetJournal, "PetJournal_SelectSpecies(PetJournal, speciesID)")
                self.selectedSpecies = sid
                self:SelectPet(sid)
            end)
        end
        self.loaded.Blizzard_Collections = true
        self:Fire("ADDON_LOADED", "Blizzard_Collections")
    end
    self:ListPets(o)
    env.CollectionsJournal:Show()
    if env.CollectionsJournal.selectedTab == nil and rawget(env, "CollectionsJournalTab2") then
        env.CollectionsJournal_SetTab(env.CollectionsJournal, 2)
    end
    env.PetJournal:Show()
    return self
end

function Client:CloseJournal() self.env.CollectionsJournal:Hide() end

-- Press side tab n of the Collections window: mouse down, then up (a click).
function Client:ClickTab(n)
    local t = self.env["CollectionsJournalTab" .. n]
    for _, s in ipairs({ "OnMouseDown", "OnMouseUp" }) do
        if t.scripts[s] then Hardware(self, t.scripts[s], t, "LeftButton") end
    end
end

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
        b.name = b:CreateFontString() -- the species' name, as on Retail's list buttons
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
    -- StaticPopup_Show(which, text1, text2, data): data reaches OnAccept (and dialog.data), as in the client.
    local data = p.args[3]
    local frame = { editBox = eb, data = data, Hide = function(f) f.hidden = true end }
    function eb:GetParent() return frame end
    if dialog.OnShow then dialog.OnShow(frame) end
    local shown = eb.text
    eb.text = text
    -- Clicking Accept or pressing Enter is a hardware event.
    if viaEnter then Hardware(self, dialog.EditBoxOnEnterPressed, eb) else Hardware(self, dialog.OnAccept, frame, data) end
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
        local f = setmetatable({ type = ftype, frameName = name, parent = parent, events = {}, scripts = {},
            shown = true, enabled = true, checked = false, textures = {}, fontStrings = {}, template = template }, Frame)
        f.client = c
        c.frames[#c.frames + 1] = f
        -- PortraitFrameMixin, mixed in (a plain field, like the real client).
        if template == "ButtonFrameTemplate" then f.SetTitle = function(self, t) self.titleText = t end end
        if name then rawset(env, name, f) end
        return f
    end
    -- Templates the client has. c.oldTemplates: only the pre-Dragonflight ones.
    local MODERN = { ButtonFrameTemplate = true, ScrollFrameTemplate = true }
    env.C_XMLUtil = { GetTemplateInfo = function(name)
        if MODERN[name] and c.oldTemplates then return nil end
        return { type = "Frame", width = 0, height = 0 }
    end }
    -- Paths the client has: every one, except those in c.missingFiles.
    env.GetFileIDFromPath = function(path)
        if c.missingFiles and c.missingFiles[path] then return nil end
        return 100000 + #path
    end
    -- Atlases the client has: those in c.atlases (none by default).
    env.C_Texture = { GetAtlasInfo = function(name)
        if c.atlases and c.atlases[name] then
            return { width = 64, height = 64, file = 4000 + #name, leftTexCoord = 0.25, rightTexCoord = 0.5,
                topTexCoord = 0.125, bottomTexCoord = 0.375 }
        end
        return nil
    end }
    env.ButtonFrameTemplate_HidePortrait = function(f) f.portraitHidden = true end
    env.ButtonFrameTemplate_HideButtonBar = function(f) f.buttonBarHidden = true end
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
    env.UNKNOWNOBJECT = "Unknown" -- a unit the client has no name for yet

    -- lines[i] = left text; right[i], colors[i], hidden[i] per line. The
    -- GameTooltipTextLeftN / RightN font strings read and write these.
    local tip = { lines = {}, right = {}, colors = {}, hidden = {} }
    function tip:GetName() return "GameTooltip" end
    function tip:NumLines() return #self.lines end
    for i = 1, 40 do
        local function Side(isRight)
            local fs = {}
            function fs:GetText()
                if isRight then return tip.right[i] end
                return tip.lines[i]
            end
            function fs:SetText(x)
                if isRight then tip.right[i] = x else tip.lines[i] = x or "" end
            end
            function fs:SetTextColor(r, g, b) if not isRight then tip.colors[i] = { r, g, b } end end
            function fs:GetTextColor()
                local col = tip.colors[i] or { 1, 1, 1 }
                return col[1], col[2], col[3], 1
            end
            function fs:Show() if isRight then tip.rightShown = tip.rightShown or {}; tip.rightShown[i] = true
                else tip.hidden[i] = nil end end
            function fs:Hide() if isRight then tip.rightShown = tip.rightShown or {}; tip.rightShown[i] = nil
                else tip.hidden[i] = true end end
            function fs:IsShown()
                if isRight then return (tip.rightShown or {})[i] == true end
                return tip.lines[i] ~= nil and not tip.hidden[i]
            end
            return fs
        end
        env["GameTooltipTextLeft" .. i] = Side(false)
        env["GameTooltipTextRight" .. i] = Side(true)
    end
    function tip:AddLine(text, r, g, b)
        self.lines[#self.lines + 1] = text
        if r then self.colors[#self.lines] = { r, g, b } end
    end
    function tip:AddDoubleLine(a, b) self.lines[#self.lines + 1] = a .. " " .. b end
    function tip:SetText(text) self.lines = { text } end
    function tip:ClearLines() self.lines, self.right, self.colors, self.hidden = {}, {}, {}, {} end
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
    env.IsSwimming = function() return S.swimming or false end
    env.IsResting = function() return S.resting or false end
    env.UnitIsAFK = function(u) return u == "player" and S.afk or false end
    env.UnitLevel = function() return S.level or 10 end
    env.GetZoneText = function() return S.zone or "Elwynn Forest" end
    -- The chat formats skill-ups and reputation are read with (enUS GlobalStrings).
    env.SKILL_RANK_UP = "Your skill in %s has increased to %d."
    env.FACTION_STANDING_INCREASED = "Reputation with %s increased by %d." -- (Forever's, 2026-11-09)
    -- Map ids (S.map, default Elwynn's 1429), names from S.mapNames.
    env.C_Map = {
        GetBestMapForUnit = function(u) assert(u == "player"); return S.map or 1429 end,
        GetMapInfo = function(id) return { mapID = id, name = (S.mapNames or {})[id] or ("Map " .. id) } end,
    }
    -- Emotes and jumps: what the player pressed (hooked by the addon).
    env.DoEmote = function(token, target) S.lastEmote = token end
    env.JumpOrAscendStart = function() S.jumps = (S.jumps or 0) + 1 end
    env.CreateColor = function(r, g, b, a) return { r = r, g = g, b = b, a = a } end
    -- The cursor, in screen pixels (c.cursor = { x, y }).
    env.GetCursorPosition = function() local p = c.cursor or { 0, 0 }; return p[1], p[2] end
    -- Sounds: the ones played are recorded in c.sounds. A few SOUNDKIT names.
    env.SOUNDKIT = { UI_70_ARTIFACT_FORGE_TRAIT_GOLD_TRAIT = 83681, UI_EPICLOOT_TOAST = 31578, LEVELUPSOUND = 888,
        IG_CHARACTER_INFO_TAB = 841 }
    env.PlaySound = function(id, channel)
        c.sounds = c.sounds or {}
        c.sounds[#c.sounds + 1] = id
        return true
    end
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
    local RANKS = { [0] = "Guild Master", [1] = "Officer" }
    env.GetGuildInfo = function(u) if c.guild then return c.guild, RANKS[c.rank] or "Member", c.rank, nil end end
    env.IsGuildLeader = function() return c.guild ~= nil and c.rank == 0 end
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
    -- Honorable kills, honor (S.hk, S.honor); lifetime: kills, highest rank.
    env.TakeTaxiNode = function(i) S.taxi = i end
    env.GetPVPSessionStats = function() return S.hk or 0, S.honor or 0 end
    env.GetPVPLifetimeStats = function() return S.lifetimeHK or 0, 0 end
    env.C_EventUtils = { IsEventValid = function(e) return KNOWN_EVENTS[e] == true end }
    env.C_GuildInfo = { IsGuildOfficer = function() return c.guild ~= nil and c.rank <= 1 end,
        GuildRoster = function()
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
    -- Guild and group chat come back to every online member, the sender included.
    -- c.chatBlocked = "error" | "silent" simulates a client that refuses.
    -- Like Forever, a GUILD post that isn't from a keypress or click (Slash,
    -- Click) is blocked: nothing is posted, no Lua error, and the test fails
    -- unless it takes the error (c:TakeErrors()). PARTY/RAID are unprobed.
    env.SendChatMessage = function(text, chan)
        if c.chatBlocked == "error" then error("SendChatMessage: blocked", 2) end
        if c.chatBlocked == "silent" then return end
        if chan == "GUILD" and (c.hardware or 0) == 0 then
            c.errors[#c.errors + 1] = "ADDON_ACTION_BLOCKED: SendChatMessage GUILD outside a keypress or click"
            return
        end
        w.chat[#w.chat + 1] = { from = c.name, text = text, chan = chan }
        local g = w:GroupOf(c.name)
        w:Timer(c, LATENCY, function()
            for _, r in ipairs(w.clients) do
                if r.online and chan == "GUILD" and c.guild and r.guild == c.guild then
                    r:Fire("CHAT_MSG_GUILD", text, c.name)
                elseif r.online and (chan == "PARTY" or chan == "RAID") and g and w:GroupOf(r.name) == g then
                    r:Fire("CHAT_MSG_" .. chan, text, c.name)
                end
            end
        end)
    end

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
            -- The server's throttle (docs/FOREVER_API.md): per prefix, 10
            -- messages, +1 per second. Over it, the message is dropped.
            c.throttle = c.throttle or {}
            local b = c.throttle[prefix] or { tokens = 10, at = w.t }
            c.throttle[prefix] = b
            b.tokens, b.at = math.min(10, b.tokens + (w.t - b.at)), w.t
            if b.tokens < 1 then
                w.throttled = (w.throttled or 0) + 1
                return 3
            end
            b.tokens = b.tokens - 1
            w:Transmit(c, prefix, text, chan, target)
            return 0
        end,
    }
    env.Enum = {
        SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, NotInGroup = 5, AddOnMessageLockdown = 11 },
        TooltipDataType = { Unit = 2 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
    }

    -- Units (companions in the world)
    env.TooltipDataProcessor = { AddTooltipPostCall = function(kind, fn)
        assert(kind == env.Enum.TooltipDataType.Unit)
        c.tooltipCalls[#c.tooltipCalls + 1] = fn
    end }
    env.UnitIsBattlePetCompanion = function(u) local x = c.units[u]; return x and x.companion or false end
    env.UnitBattlePetSpeciesID = function(u) local x = c.units[u]; return x and x.species end
    -- Nameplates (c:Nameplate): the frame over a unit; nil for a unit without one.
    c.plates = {}
    env.C_NamePlate = {
        GetNamePlateForUnit = function(u) return c.plates[u] end,
        GetNamePlates = function()
            local list = {}
            for _, p in pairs(c.plates) do list[#list + 1] = p end
            table.sort(list, function(a, b) return a.namePlateUnitToken < b.namePlateUnitToken end)
            return list
        end,
    }
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
        -- (owned, max) for a species: how many of it this client has.
        GetNumCollectedInfo = function(sid)
            local n = 0
            for _, p in ipairs(c.pets) do if p.sid == sid then n = n + 1 end end
            return n, 3
        end,
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
            local R = c.ns.Registry
            local nicks = {}
            for key in pairs(select(3, R:All())) do nicks[key] = R:Nickname(key) or false end
            local holders = Show(R:Holders()) .. " names " .. Show(nicks)
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
    -- Let what's already on its way land first (a bond published at the
    -- 30-second day visit after a login, say), then compare.
    w:Run(3)
    local ok, why = H.converged(w)
    if not ok then error((msg and (msg .. ": ") or "") .. why, 2) end
end

return H
