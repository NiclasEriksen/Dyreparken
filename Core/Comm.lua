local _, ns = ...

-- Addon messaging. One prefix; every message is a table
--   { k = kind, p = PROTOCOL, ... }
-- serialized with LibSerialize, compressed with LibDeflate, encoded for the
-- addon channel, then split into <=255 byte chunks. Sending goes through
-- ChatThrottleLib so we never trip the server throttle (10 msgs per prefix,
-- +1/s; too much traffic can disconnect).
--
-- Chunk header (1 byte): "S" whole message, "F" first, "M" middle, "L" last.
-- Chunks from one sender arrive in order on one channel, and the receiver
-- joins them per sender and channel. So every chunk goes out through one
-- FIFO here and one CTL queue: two messages in separate queues would
-- interleave and spoil each other.
--
-- Pacing: ChatThrottleLib only limits bytes per second. The server also
-- drops anything past 10 messages per prefix (+1/s), so a big SYNC would
-- lose chunks. The outbox spends from its own bucket of BURST and waits
-- for refills with one C_Timer, so it's idle when there's nothing to send.
--
-- Handlers: ns.Comm:Register(kind, fn(msg, sender, channel)); several
-- modules may listen to the same kind (HELLO: Version and Sync).
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
local CTL = ChatThrottleLib
local PREFIX = ns.Config.COMM_PREFIX
local CHUNK = 254 -- 255 minus the header byte

local BURST = 8           -- of the server's 10, leaving room for slack
local REFILL = 1          -- per second, like the server
local MAX_PARTS = 64      -- chunks per incoming message (16 KB); more is junk

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
        outbox[first], first = nil, first + 1
        tokens = tokens - 1
        CTL:SendAddonMessage(c.prio, PREFIX, c.text, c.channel, c.target, PREFIX, c.cb, c.kind)
    end
    if first <= last then
        waiting = true
        C_Timer.After(math.max(0.1, (1 - tokens) / REFILL), Drain)
    else
        first, last = 1, 0
    end
end

local function Queue(prio, text, channel, target, cb, kind)
    last = last + 1
    outbox[last] = { prio = prio, text = text, channel = channel, target = target, cb = cb, kind = kind }
    if not waiting then Drain() end
end

function Comm:Register(kind, fn)
    local list = handlers[kind]
    if not list then list = {}; handlers[kind] = list end
    list[#list + 1] = fn
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
    local ok, msg = LibSerialize:Deserialize(s)
    if ok and type(msg) == "table" then return msg end
end

local function OnSent(kind, sent)
    -- CTL passes (arg, didSend, ...); result codes are logged for research.
    if not sent then ns.Log("Comm", "send of %s not delivered", tostring(kind)) end
end

-- channel: "GUILD", "RAID", "PARTY", "INSTANCE_CHAT", "WHISPER". prio: "BULK", "NORMAL", "ALERT".
function Comm:Send(kind, msg, channel, target, prio)
    if channel == "GUILD" and not IsInGuild() then return false end
    -- The server refuses these outside a group (NotInGroup); say so to the caller.
    if (channel == "PARTY" or channel == "RAID") and not IsInGroup() then return false end
    msg.k, msg.p = kind, ns.PROTOCOL
    local data = Encode(msg)
    prio = prio or "NORMAL"
    local n = #data
    if n <= CHUNK then
        Queue(prio, "S" .. data, channel, target, OnSent, kind)
    else
        local pos = 1
        while pos <= n do
            local final = pos + CHUNK > n
            local head = pos == 1 and "F" or (final and "L" or "M")
            Queue(prio, head .. data:sub(pos, pos + CHUNK - 1), channel, target, final and OnSent or nil, kind)
            pos = pos + CHUNK
        end
    end
    ns.Log("Comm", "-> %s %s%s (%d bytes)", kind, channel, target and (" " .. target) or "", n)
    return true
end

local function Dispatch(data, sender, channel)
    local msg = Decode(data)
    if not msg or type(msg.k) ~= "string" then
        ns.Log("Comm", "bad message from %s", sender)
        return
    end
    if msg.p ~= ns.PROTOCOL then
        ns.Bus:Fire("PROTOCOL_MISMATCH", sender, msg.p, msg)
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
    elseif head == "M" or head == "L" then
        local parts = partial[key]
        if not parts then return end
        if #parts >= MAX_PARTS then
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
