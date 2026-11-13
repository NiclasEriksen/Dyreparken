-- The World: the shared clock (GetTime and the server's), timers, the guild roster, the
-- group, and the addon-message network (delivery after LATENCY, in order; w.drop loses
-- messages; every decoded message in w.wire). H.World, H.Setup.
local H, P = ...
local ADDON, LATENCY, DecodeWire = P.ADDON, P.LATENCY, P.DecodeWire

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
    for _, name in ipairs(opts.members or {}) do w:AddMember(name, 0) end
    return w
end

-- Guildmates the specs name in data they merge by hand (H.World{ members = H.FOLK }): since
-- X-Protocol 10 only members' data is kept (Registry: members only), so a peer's claim, name or
-- bond in a test needs its author in the guild, as in the game.
H.FOLK = { "Kari Berg", "Per Hansen", "Liv Lund", "Bo Berg", "Anne Aas", "Bjorn Aas", "Siv Dahl", "Tor Eng", "Nina Ny" }

-- The usual world: Ola Nord (and Kari Berg, if given), logged in and
-- settled. o.world: H.World's opts ({ members = H.FOLK }). o.ola / o.kari: a pets list or the client's opts; o.each(c):
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
-- Move the clock forward to a date and time on the players' clock (Europe/Oslo, run.lua).
function World:SetDate(year, month, day, hour, min)
    local t = os.time({ year = year, month = month, day = day, hour = hour or 12, min = min or 0 })
    assert(t >= self:ServerTime(), "SetDate only moves forward")
    self:Skip(t - self:ServerTime())
end

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

P.World = World
