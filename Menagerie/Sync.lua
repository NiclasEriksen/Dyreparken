local _, ns = ...

-- Keeping the registry the same on every client.
--
-- Messages (all on GUILD):
--   HELLO  { v, d }        login announcement (Version.lua) with our digest
--   SYNC   { r, l, n, a, d } full state: r[owner] = record, l[owner] = lapse,
--                          n[petKey][namer] = naming entry (Registry.lua),
--                          a[id] = guild achievement (Achievements.lua),
--                          d = the sender's digest after sending
--   ACH    { a }           guild achievements someone just found or shared
--                          (handled in Achievements.lua; part of the digest)
--   UPD    { r }           the sender's own record changed
--   NICK   { pet, e }      the sender named a pet (or cleared or voided the name)
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
local lastSent -- GetTime() of our last SYNC

-- At most one SYNC of ours per this many seconds. Normally a round or two
-- settles everything; this caps the cost if something never settles (a
-- bug, or a peer that refuses what we keep).
local SYNC_GAP = 30

-- Adler-32 of a canonical listing of the registry.
function Sync:Digest()
    local claims, lapses, names = ns.Registry:All()
    local parts = {}
    for owner, r in pairs(claims) do parts[#parts + 1] = "c" .. owner .. "\31" .. r.ts end
    for owner, t in pairs(lapses) do parts[#parts + 1] = "l" .. owner .. "\31" .. t end
    for key, byKey in pairs(names) do
        for namer, e in pairs(byKey) do parts[#parts + 1] = "n" .. key .. "\31" .. namer .. "\31" .. e.at end
    end
    ns.Achievements:DigestParts(parts)
    if #parts == 0 then return 0 end
    table.sort(parts)
    return LibDeflate:Adler32(table.concat(parts, "\30"))
end

local function SendFull()
    pending = nil
    if not IsInGuild() then return end
    lastSent = GetTime()
    local claims, lapses, names = ns.Registry:All()
    ns.Comm:Send("SYNC", { r = claims, l = lapses, n = names, a = ns.Achievements:GuildRecords(), d = Sync:Digest() },
        "GUILD", nil, "BULK")
end

local function Schedule()
    if pending then return end
    local token = {}
    pending = token
    local delay = 2 + math.random() * 6
    if lastSent then delay = math.max(delay, lastSent + SYNC_GAP - GetTime()) end
    C_Timer.After(delay, function()
        if pending == token then SendFull() end
    end)
end

local function Cancel()
    pending = nil
end

-- Merge a batch; returns true if anything changed.
local function MergeAll(r, l, n)
    local changed = false
    if type(n) == "table" then
        for key, byKey in pairs(n) do
            if type(byKey) == "table" then
                for namer, e in pairs(byKey) do
                    if ns.Registry:MergeName(key, namer, e) then changed = true end
                end
            end
        end
    end
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

-- Registry traffic only counts on the guild channel: a whisper or party
-- message comes from anyone, guild member or not.
local function Accept(msg, channel) return msg.p == ns.PROTOCOL and channel == "GUILD" end

function Sync:Init()
    ns.Comm:Register("HELLO", function(msg, _, channel)
        if not Accept(msg, channel) then return end
        if msg.d ~= Sync:Digest() then Schedule() end
    end)
    ns.Comm:Register("SYNC", function(msg, _, channel)
        if not Accept(msg, channel) then return end
        MergeAll(msg.r, msg.l, msg.n)
        ns.Achievements:MergeGuild(msg.a)
        if Sync:Digest() == msg.d then
            Cancel() -- someone said it for us
        else
            Schedule() -- we know things the sender doesn't
        end
    end)
    ns.Comm:Register("UPD", function(msg, sender, channel)
        if not Accept(msg, channel) then return end
        -- Only the owner writes their record. Relayed copies come via SYNC.
        MergeAll({ [sender] = msg.r }, nil)
    end)
    ns.Comm:Register("NICK", function(msg, sender, channel)
        if not Accept(msg, channel) then return end
        if type(msg.pet) ~= "string" then return end
        -- Only the namer writes their entry, like UPD.
        MergeAll(nil, nil, { [msg.pet] = { [sender] = msg.e } })
    end)
    ns.Comm:Register("LAPSE", function(msg, _, channel)
        if not Accept(msg, channel) then return end
        MergeAll(nil, msg.l)
    end)

    -- Our own edits go out right away.
    ns.Bus:On("MY_RECORD", function(_, r)
        ns.Comm:Send("UPD", { r = r }, "GUILD")
        ns.Registry:CheckMine()
    end)
    ns.Bus:On("MY_NAME", function(key, e)
        ns.Comm:Send("NICK", { pet = key, e = e }, "GUILD")
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
