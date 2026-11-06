local _, ns = ...

-- Addon messaging. One prefix; every message is a table
--   { k = kind, p = PROTOCOL, ... }
-- serialized with LibSerialize, compressed with LibDeflate, encoded for the
-- addon channel, then split into <=255 byte chunks. Sending goes through
-- ChatThrottleLib so we never trip the server throttle (10 msgs per prefix,
-- +1/s; too much traffic can disconnect).
--
-- Chunk header (1 byte): "S" whole message, "F" first, "M" middle, "L" last.
-- Chunks from one sender arrive in order on one channel.
--
-- Handlers: ns.Comm:Register(kind, fn(msg, sender, channel)).
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

local handlers = {}
local partial = {} -- sender .. channel -> { parts }

function Comm:Register(kind, fn)
    handlers[kind] = fn
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
    msg.k, msg.p = kind, ns.PROTOCOL
    local data = Encode(msg)
    prio = prio or "NORMAL"
    local queue = PREFIX .. kind
    local n = #data
    if n <= CHUNK then
        CTL:SendAddonMessage(prio, PREFIX, "S" .. data, channel, target, queue, OnSent, kind)
    else
        local pos = 1
        while pos <= n do
            local last = pos + CHUNK > n
            local head = pos == 1 and "F" or (last and "L" or "M")
            CTL:SendAddonMessage(prio, PREFIX, head .. data:sub(pos, pos + CHUNK - 1), channel, target, queue,
                last and OnSent or nil, kind)
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
    local fn = handlers[msg.k]
    ns.Log("Comm", "<- %s from %s (%s)", msg.k, sender, channel)
    if fn then fn(msg, sender, channel) end
end

local function OnAddonMessage(_, _, prefix, text, channel, sender)
    if prefix ~= PREFIX then return end
    local raw = sender
    sender = ns.NormalizeName(sender)
    if sender == ns.PlayerKey() then return end
    ns.Log("Comm", "raw sender %q", tostring(raw))
    if not sender then return end
    local head, body = text:sub(1, 1), text:sub(2)
    local key = sender .. channel
    if head == "S" then
        Dispatch(body, sender, channel)
    elseif head == "F" then
        partial[key] = { body }
    elseif head == "M" or head == "L" then
        local parts = partial[key]
        if not parts then return end
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
