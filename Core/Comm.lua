local _, ns = ...

-- Addon messaging. One prefix; every message is a table
--   { k = kind, p = PROTOCOL, ... }
-- serialized with LibSerialize, compressed with LibDeflate, encoded for the
-- addon channel, then split into <=255 byte chunks, sent straight to the
-- server by our own outbox, paced to its throttle (10 msgs per prefix, +1/s;
-- too much traffic can disconnect). Not through ChatThrottleLib (until
-- 2026-11-09): it queues behind other addons' traffic and then sends in a
-- burst, past the throttle.
--
-- Chunk header (1 byte): "S" whole message, "F" first, "M" middle, "L" last.
-- Chunks from one sender arrive in order on one channel, and the receiver
-- joins them per sender and channel. So every chunk goes out through one
-- FIFO here: two messages sent side by side would interleave and spoil each
-- other.
--
-- Pacing: the outbox spends from its own bucket of Config.COMM_BURST and waits for
-- refills with one C_Timer, so it's idle when there's nothing to send. If
-- the server still says "throttled" (another addon on our prefix? never
-- seen), the chunk stays first in line and waits a second.
--
-- Size: a message over MAX_PARTS chunks is dropped by every receiver, so
-- it isn't sent at all (logged); SYNC goes in parts (Sync.lua).
--
-- Handlers: ns.Comm:Register(kind, fn(msg, sender, channel), from, fields); several
-- modules may listen to the same kind (HELLO: Version and Sync). from:
-- "GUILD" or "GROUP" (party or raid): a message of that kind arriving on any
-- other channel never reaches fn. Only HELLO gets through with another
-- protocol (versions can be compared); its handlers check msg.p themselves.
-- fields: { name = check } with a check named in Wire.CHECKS ("key",
-- "table", "version"): a message whose field fails it is dropped (and
-- logged) before fn runs, so handlers needn't check shapes by hand.
--
-- Notes (Forever 1.60.1):
--  * Trial/Veteran accounts cannot send addon messages at all.
--  * SendAddonMessage may return AddOnMessageLockdown (11); when it applies
--    isn't documented. We log result codes so we can find out.
--  * Anyone can send anything: treat every message as untrusted input.
local Comm = {}
ns.Comm = Comm

local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")
local PREFIX = ns.Config.COMM_PREFIX
local CHUNK = 254 -- 255 minus the header byte

local BURST = ns.Config.COMM_BURST
local REFILL = 1          -- per second, like the server
-- What peers accept (Wire.LIMITS): MAX_PARTS chunks per incoming message
-- (16 KB), and MAX_RAW bytes it may unpack to. 16 KB of deflated text is at
-- most ~150 KB of real data; a crafted 16 KB stream unpacks to 8 MB (code
-- review 2026-11-09: seconds of work, then a table of millions to read).
-- Past MAX_RAW it isn't read, and its sender is ignored for the session
-- (Comm.ignored).
local LIMITS = ns.Wire.LIMITS
Comm.ignored = {}

local handlers = {}
local partial = {} -- sender .. channel -> { parts }

local outbox, first, last = {}, 1, 0
local tokens, stamp = BURST, nil
local waiting = false

local function Drain()
    waiting = false
    local now = GetTime()
    tokens = math.min(BURST, tokens + (now - (stamp or now)) * REFILL)
    stamp = now
    -- The epsilon: float rounding must not leave us a hair short forever.
    while first <= last and tokens >= 1 - 1e-6 do
        local c = outbox[first]
        tokens = tokens - 1
        local result = C_ChatInfo.SendAddonMessage(PREFIX, c.text, c.channel, c.target)
        local codes = Enum.SendAddonMessageResult
        if codes and result == codes.AddonMessageThrottle then
            -- Keep it first in line; try again once a token has come back.
            tokens = 0
            ns.Log("Comm", "throttled by the server; waiting")
            break
        end
        outbox[first], first = nil, first + 1
        if c.cb then c.cb(c.kind, result == nil or result == true or (codes and result == codes.Success)) end
    end
    if first <= last then
        waiting = true
        C_Timer.After(math.max(0.1, (1 - tokens) / REFILL), Drain)
    else
        first, last = 1, 0
    end
end

local function Queue(text, channel, target, cb, kind)
    last = last + 1
    outbox[last] = { text = text, channel = channel, target = target, cb = cb, kind = kind }
    if not waiting then Drain() end
end

-- Requests anyone can send (VER_REQ, PET_REQ) are answered at most once per
-- channel every Config.REPLY_GAP seconds: a member sending them in a loop must not
-- fill everyone's outbox. A second asker within the gap usually heard our
-- first answer anyway (answers go to the whole channel).
local replied = {} -- kind .. channel -> GetTime()
function Comm:MayReply(kind, channel)
    local key, now = kind .. "\31" .. tostring(channel), GetTime()
    if replied[key] and now - replied[key] < ns.Config.REPLY_GAP then return false end
    replied[key] = now
    return true
end

-- Chunks waiting in the outbox: answers nobody needs at once can skip a turn
-- while it's long, so our own news isn't stuck behind them.
function Comm:Backlog() return last - first + 1 end

local FROM = { GUILD = { GUILD = true }, GROUP = { PARTY = true, RAID = true } }
-- What each registration accepts, for the protocol snapshot (52_protocol):
-- Comm.registered[i] = { kind, from, fields }.
Comm.registered = {}
function Comm:Register(kind, fn, from, fields)
    local list = handlers[kind]
    if not list then list = {}; handlers[kind] = list end
    local only = from and assert(FROM[from], "Comm:Register: from is GUILD or GROUP")
    local checks = ns.Wire.CHECKS
    for name, check in pairs(fields or {}) do
        assert(checks[check], "Comm:Register: no field check " .. tostring(check) .. " for " .. kind .. "." .. name)
    end
    Comm.registered[#Comm.registered + 1] = { kind = kind, from = from, fields = fields }
    list[#list + 1] = function(msg, sender, channel)
        if only and not only[channel] then return end
        for name, check in pairs(fields or {}) do
            if not checks[check](msg[name]) then
                ns.Log("Comm", "dropped %s from %s: %s isn't a %s", kind, sender, name, check)
                return
            end
        end
        return fn(msg, sender, channel)
    end
end

local function Encode(msg)
    local s = LibSerialize:Serialize(msg)
    local c = LibDeflate:CompressDeflate(s)
    return LibDeflate:EncodeForWoWAddonChannel(c)
end

local function Decode(data)
    local c = LibDeflate:DecodeForWoWAddonChannel(data)
    if not c then return nil end
    local s = LibDeflate:DecompressDeflate(c)
    if not s then return nil end
    if #s > LIMITS.MAX_RAW then return nil, true end
    local ok, msg = LibSerialize:Deserialize(s)
    if ok and type(msg) == "table" then return msg end
end

local function OnSent(kind, sent)
    if not sent then ns.Log("Comm", "send of %s not delivered", tostring(kind)) end
end

-- channel: "GUILD", "RAID", "PARTY", "INSTANCE_CHAT", "WHISPER". (No
-- priorities: the outbox is first in, first out.)
function Comm:Send(kind, msg, channel, target)
    if channel == "GUILD" and not IsInGuild() then return false end
    -- The server refuses these outside a group (NotInGroup); say so to the caller.
    if (channel == "PARTY" or channel == "RAID") and not IsInGroup() then return false end
    msg.k, msg.p = kind, ns.PROTOCOL
    local data = Encode(msg)
    local n = #data
    if n > CHUNK * LIMITS.MAX_PARTS then
        -- Every receiver would drop it: don't spend the channel on it.
        ns.Log("Comm", "not sent: %s is too big (%d bytes, over %d chunks)", kind, n, LIMITS.MAX_PARTS)
        return false
    end
    if n <= CHUNK then
        Queue("S" .. data, channel, target, OnSent, kind)
    else
        local pos = 1
        while pos <= n do
            local final = pos + CHUNK > n
            local head = pos == 1 and "F" or (final and "L" or "M")
            Queue(head .. data:sub(pos, pos + CHUNK - 1), channel, target, final and OnSent or nil, kind)
            pos = pos + CHUNK
        end
    end
    ns.Log("Comm", "-> %s %s%s (%d bytes)", kind, channel, target and (" " .. target) or "", n)
    return true
end

local function Dispatch(data, sender, channel)
    if Comm.ignored[sender] then return end
    local msg, bomb = Decode(data)
    if bomb then
        Comm.ignored[sender] = true
        ns.Log("Comm", "a message from %s unpacked past %d bytes: ignoring them this session", sender, LIMITS.MAX_RAW)
        return
    end
    if not msg or type(msg.k) ~= "string" then
        ns.Log("Comm", "bad message from %s", sender)
        return
    end
    if msg.p ~= ns.PROTOCOL then
        ns.Bus:Fire("PROTOCOL_MISMATCH", sender, msg.p, msg, channel)
        if msg.k ~= "HELLO" then return end -- HELLO is always readable, so versions can be compared
    end
    ns.Log("Comm", "<- %s from %s (%s)", msg.k, sender, channel)
    local list = handlers[msg.k]
    if not list then return end
    for i = 1, #list do
        local ok, err = pcall(list[i], msg, sender, channel)
        if not ok then ns.Log("Comm", "handler %s failed: %s", msg.k, tostring(err)) end
    end
end

local function OnAddonMessage(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX then return end
    local raw = sender
    sender = ns.NormalizeName(sender)
    if sender == ns.PlayerKey() then return end
    if not sender then return end
    if raw ~= sender then ns.Log("Comm", "raw sender %q", tostring(raw)) end
    local head, body = text:sub(1, 1), text:sub(2)
    local key = sender .. channel
    if head == "S" then
        Dispatch(body, sender, channel)
    elseif head == "F" then
        partial[key] = { body }
        -- A long message is on its way (only SYNC parts are this long):
        -- Sync holds back its own until it has seen it.
        ns.Bus:Fire("COMM_INCOMING", sender, channel)
    elseif head == "M" or head == "L" then
        local parts = partial[key]
        if not parts then return end
        if #parts >= LIMITS.MAX_PARTS then
            partial[key] = nil
            ns.Log("Comm", "dropped an oversized message from %s", sender)
            return
        end
        parts[#parts + 1] = body
        if head == "L" then
            partial[key] = nil
            Dispatch(table.concat(parts), sender, channel)
        end
    end
end

function Comm:Init()
    C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
    ns.Events:On("CHAT_MSG_ADDON", Comm, OnAddonMessage)
end

ns.Start("loaded", function() Comm:Init() end)
