local _, ns = ...

-- Keeping the registry the same on every client.
--
-- Messages (all on GUILD):
--   HELLO  { v, d }        login announcement (Version.lua) with our digest
--   SYNC   { r, l, a, d }  full state: r[owner] = record, l[owner] = lapse,
--                          a[id] = guild achievement (Achievements.lua),
--                          d = the sender's digest after sending
--   ACH    { a }           guild achievements someone just found or shared
--                          (handled in Achievements.lua; part of the digest)
--   UPD    { r }           the sender's own record changed
--   LAPSE  { l }           lapses someone just noticed
--
-- Flow: a client logs in and sends HELLO with its digest. Peers whose
-- digest differs schedule a SYNC after a random 2-8 s delay, and cancel it
-- if they see someone else's SYNC that already brings them in line, so
-- usually only one peer answers. Whoever receives a SYNC merges it. If they
-- still differ afterwards (they knew something the sender didn't), they
-- schedule a SYNC of their own the same way. Everything merges
-- monotonically, so this settles after a round or two.
--
-- Everything is idle between logins and edits: no timers, no polling.
local Sync = {}
ns.Sync = Sync

local LibDeflate = LibStub("LibDeflate")
local pending -- the scheduled SYNC broadcast, if any

-- Adler-32 of a canonical listing of the registry.
function Sync:Digest()
    local claims, lapses = ns.Registry:All()
    local parts = {}
    for owner, r in pairs(claims) do parts[#parts + 1] = "c" .. owner .. "\31" .. r.ts end
    for owner, t in pairs(lapses) do parts[#parts + 1] = "l" .. owner .. "\31" .. t end
    ns.Achievements:DigestParts(parts)
    if #parts == 0 then return 0 end
    table.sort(parts)
    return LibDeflate:Adler32(table.concat(parts, "\30"))
end

local function SendFull()
    pending = nil
    if not IsInGuild() then return end
    local claims, lapses = ns.Registry:All()
    ns.Comm:Send("SYNC", { r = claims, l = lapses, a = ns.Achievements:GuildRecords(), d = Sync:Digest() },
        "GUILD", nil, "BULK")
end

local function Schedule()
    if pending then return end
    local token = {}
    pending = token
    C_Timer.After(2 + math.random() * 6, function()
        if pending == token then SendFull() end
    end)
end

local function Cancel()
    pending = nil
end

-- Merge a batch; returns true if anything changed.
local function MergeAll(r, l)
    local changed = false
    if type(r) == "table" then
        for owner, rec in pairs(r) do
            if ns.Registry:MergeRecord(owner, rec) then changed = true end
        end
    end
    if type(l) == "table" then
        for owner, t in pairs(l) do
            if ns.Registry:MergeLapse(owner, t) then changed = true end
        end
    end
    if changed then
        ns.Registry:Changed()
        ns.Registry:CheckMine()
    end
    return changed
end

local function SameProtocol(msg) return msg.p == ns.PROTOCOL end

function Sync:Init()
    ns.Comm:Register("HELLO", function(msg)
        if not SameProtocol(msg) then return end
        if msg.d ~= Sync:Digest() then Schedule() end
    end)
    ns.Comm:Register("SYNC", function(msg)
        if not SameProtocol(msg) then return end
        MergeAll(msg.r, msg.l)
        ns.Achievements:MergeGuild(msg.a)
        if Sync:Digest() == msg.d then
            Cancel() -- someone said it for us
        else
            Schedule() -- we know things the sender doesn't
        end
    end)
    ns.Comm:Register("UPD", function(msg, sender)
        if not SameProtocol(msg) then return end
        -- Only the owner writes their record. Relayed copies come via SYNC.
        MergeAll({ [sender] = msg.r }, nil)
    end)
    ns.Comm:Register("LAPSE", function(msg)
        if not SameProtocol(msg) then return end
        MergeAll(nil, msg.l)
    end)

    -- Our own edits go out right away.
    ns.Bus:On("MY_RECORD", function(_, r)
        ns.Comm:Send("UPD", { r = r }, "GUILD")
        ns.Registry:CheckMine()
    end)
    -- A fresh roster may reveal owners who left or went inactive.
    ns.Bus:On("ROSTER", function()
        local added = ns.Registry:CheckRoster()
        if added then
            ns.Registry:Changed()
            ns.Comm:Send("LAPSE", { l = added }, "GUILD", nil, "BULK")
            ns.Registry:CheckMine()
        end
    end)
end
