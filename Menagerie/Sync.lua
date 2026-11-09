local _, ns = ...

-- Keeping the registry the same on every client.
--
-- Messages (all on GUILD):
--   HELLO  { v, d }        login announcement (Version.lua) with our digest
--   SYNC   { r, l, n, b, a, d, i, of } full state, in parts (i of of), each
--                          well under what receivers accept (Comm MAX_PARTS):
--                          1: r[owner] = record, l[owner] = lapse,
--                             a[id] = guild achievement (Achievements.lua)
--                          2: n[petKey][namer] = naming entry (Registry.lua)
--                          3: b[petKey][carer] = bond entry (Registry.lua)
--                          d (the last part) = the sender's digest. A part
--                          with more than SYNC_MAX_ENTRIES entries is junk
--                          and refused whole.
--   ACH    { a }           guild achievements someone just found or shared
--                          (handled in Achievements.lua; part of the digest)
--   UPD    { r }           the sender's own record changed
--   NICK   { pet, e }      the sender named a pet (or cleared or voided the name)
--   BOND   { pet, e }      the sender's bond with a pet (Bond.lua)
--   BOND_REQ { pet }       who has a bond with this pet? (a card shows it);
--                          each member with one answers with their own BOND
--   LAPSE  { l }           lapses someone just noticed
--
-- Flow: a client logs in and sends HELLO with its digest. Peers whose
-- digest differs schedule a SYNC after a random 2-8 s delay. When someone
-- else's SYNC starts arriving (its first chunk, Comm COMM_INCOMING), they
-- hold theirs back, and cancel it if that SYNC brings them in line, so
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
    local life = ns.Registry:AdoptedLife()
    local parts = {}
    -- Bonds by level, not points: points go out lazily (Bond.lua), and peers
    -- shouldn't SYNC over a few points. A level change goes out at once.
    for key, byKey in pairs(life) do
        for carer, e in pairs(byKey) do
            parts[#parts + 1] = "b" .. key .. "\31" .. carer .. "\31" .. ns.Bond:Level(e.p)
        end
    end
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
    local life = ns.Registry:AdoptedLife() -- the holders' bonds only (Registry.lua)
    local parts = {
        { r = claims, l = lapses, a = ns.Achievements:GuildRecords() },
        { n = names },
        { b = life },
    }
    for i, msg in ipairs(parts) do
        msg.i, msg.of = i, #parts
        if i == #parts then msg.d = Sync:Digest() end
        ns.Comm:Send("SYNC", msg, "GUILD")
    end
end

local function Later(delay)
    local token = {}
    pending = token
    if lastSent then delay = math.max(delay, lastSent + SYNC_GAP - GetTime()) end
    C_Timer.After(delay, function()
        if pending == token then SendFull() end
    end)
end

local function Schedule()
    if pending then return end
    Later(2 + math.random() * 6)
end

-- Someone's SYNC is on its way: wait for it before sending ours (it may
-- say it all). Comes back to it if that SYNC never finishes arriving.
local HOLD = 30
local function Hold()
    if pending then Later(HOLD) end
end

-- Ask the guild for bonds with a pet (its card is showing): once per pet a
-- session, and not while flicking through pets (one ask per ASK_GAP).
local asked, lastAsk = {}, nil
local ASK_GAP = 1.5
function Sync:AskBonds(key)
    if not key or asked[key] or not IsInGuild() then return end
    local now = GetTime()
    if lastAsk and now - lastAsk < ASK_GAP then return end
    asked[key], lastAsk = true, now
    ns.Comm:Send("BOND_REQ", { pet = key }, "GUILD")
end

-- Someone told us something we know better (an older date, say): answer
-- with a SYNC, the usual way (delayed, one at a time).
function Sync:Nudge() Schedule() end

local function Cancel()
    pending = nil
end

-- Entries in a part: a table of tables (n, b) counts the inner ones.
local function Count(t, nested)
    if type(t) ~= "table" then return 0 end
    local n = 0
    for _, v in pairs(t) do
        if nested then
            if type(v) == "table" then for _ in pairs(v) do n = n + 1 end end
        else
            n = n + 1
        end
    end
    return n
end

-- More entries than any guild has: junk, or someone flooding everyone's
-- saved data (and every SYNC after it). Refused whole.
local function TooBig(msg)
    local max = ns.Config.SYNC_MAX_ENTRIES
    return Count(msg.r) > max or Count(msg.l) > max or Count(msg.n, true) > max or Count(msg.b, true) > max
end

-- Merge a batch; returns true if anything changed.
local function MergeAll(r, l, n, b)
    local changed = false
    if type(b) == "table" then
        for key, byKey in pairs(b) do
            if type(byKey) == "table" then
                for carer, e in pairs(byKey) do
                    if ns.Registry:MergeLife(key, carer, e) then changed = true end
                end
            end
        end
    end
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

function Sync:Init()
    -- (HELLO gets through with any protocol: Version compares them; we don't)
    ns.Comm:Register("HELLO", function(msg)
        if msg.p == ns.PROTOCOL and msg.d ~= Sync:Digest() then Schedule() end
    end, "GUILD")
    ns.Comm:Register("SYNC", function(msg, sender, channel)
        if TooBig(msg) then
            ns.Log("Sync", "refused a SYNC from %s: too many entries", tostring(sender))
            return
        end
        MergeAll(msg.r, msg.l, msg.n, msg.b)
        ns.Achievements:MergeGuild(msg.a)
        local i, of = tonumber(msg.i), tonumber(msg.of)
        if i and of and i < of then
            Hold() -- more parts to come: judge when the last is in
        elseif Sync:Digest() == msg.d then
            Cancel() -- someone said it for us
        else
            -- We know things the sender doesn't: answer soon (a hold ends here).
            Later(2 + math.random() * 6)
        end
    end, "GUILD")
    ns.Bus:On("COMM_INCOMING", function(_, channel)
        if channel == "GUILD" then Hold() end
    end)
    ns.Comm:Register("UPD", function(msg, sender, channel)
        -- Only the owner writes their record. Relayed copies come via SYNC.
        MergeAll({ [sender] = msg.r }, nil)
    end, "GUILD")
    ns.Comm:Register("NICK", function(msg, sender, channel)
        if type(msg.pet) ~= "string" then return end
        -- Only the namer writes their entry, like UPD.
        MergeAll(nil, nil, { [msg.pet] = { [sender] = msg.e } })
    end, "GUILD")
    ns.Comm:Register("BOND", function(msg, sender, channel)
        if type(msg.pet) ~= "string" then return end
        MergeAll(nil, nil, nil, { [msg.pet] = { [sender] = msg.e } })
    end, "GUILD")
    ns.Comm:Register("BOND_REQ", function(msg, _, channel)
        if not ns.Registry.ValidKey(msg.pet) then return end
        local e = ns.Registry:Life(msg.pet, ns.PlayerKey())
        if e and ns.Comm:MayReply("BOND:" .. msg.pet, channel) then
            ns.Comm:Send("BOND", { pet = msg.pet, e = e }, "GUILD")
        end
    end, "GUILD")
    ns.Comm:Register("LAPSE", function(msg, _, channel)
        MergeAll(nil, msg.l)
    end, "GUILD")

    -- Our own edits go out right away.
    ns.Bus:On("MY_RECORD", function(_, r)
        ns.Comm:Send("UPD", { r = r }, "GUILD")
        ns.Registry:CheckMine()
    end)
    ns.Bus:On("MY_BOND", function(key, e)
        ns.Comm:Send("BOND", { pet = key, e = e }, "GUILD")
    end)
    ns.Bus:On("MY_NAME", function(key, e)
        ns.Comm:Send("NICK", { pet = key, e = e }, "GUILD")
    end)
    -- A fresh roster may reveal owners who left or went inactive.
    ns.Bus:On("ROSTER", function()
        local added = ns.Registry:CheckRoster()
        if added then
            ns.Registry:Changed()
            ns.Comm:Send("LAPSE", { l = added }, "GUILD")
            ns.Registry:CheckMine()
        end
    end)
end
