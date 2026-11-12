local _, ns = ...

-- Keeping the registry the same on every client.
--
-- Messages (all on GUILD):
--   HELLO  { v, d }        login announcement (Version.lua) with our digest
--   SYNC   { r, l, n, b, a, d, i, of } full state, in parts (i of of), each
--                          well under what receivers accept (Wire.LIMITS.MAX_PARTS):
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

-- Every store the sync carries, one row each. Digest, SendFull, TooBig and
-- MergeAll only loop over this (until 2026-11-12 each listed the stores by
-- hand, about seven places a store, and guild achievements came in through
-- hooks of their own). A row:
--   wire    its key in a SYNC part (and in UPD/NICK/BOND/LAPSE, as MergeAll takes them)
--   part    the SYNC part it rides in (the header above): changing it changes the wire
--   nested  t[key][author] = entry (else t[author] = entry)
--   source  fn() -> what we send and digest (of bonds, the holders' only: Registry:AdoptedLife)
--   valid   fn(key[, author], entry): the check a merge runs on a peer's copy (and WriteOwn on ours)
--   merge   fn(key[, author], entry) -> changed; it checks `valid` itself (the merges are public),
--           or mergeAll fn(t) -> changed, for a store that merges a whole table at once
--   digest  fn(key[, author], entry) -> its line in the digest; the first letter keeps stores apart
--   count   counted against Config.SYNC_MAX_ENTRIES (TooBig). Guild achievements never were, and
--           counting them now would refuse what older peers accept.
--   registry  a change here is a registry change (Registry:Changed, CheckMine)
-- The parts, the digest and what TooBig counts are the wire: tools/test/spec/50_wire.lua pins
-- them for a fixed world.
local R = ns.Registry
Sync.TABLES = {
    { wire = "r", part = 1, source = function() return (R:All()) end, valid = R.ValidClaim,
        merge = function(owner, r) return R:MergeRecord(owner, r) end,
        digest = function(owner, r) return "c" .. owner .. "\31" .. r.ts end, count = true, registry = true },
    { wire = "l", part = 1, source = function() return (select(2, R:All())) end, valid = R.ValidLapseOf,
        merge = function(owner, t) return R:MergeLapse(owner, t) end,
        digest = function(owner, t) return "l" .. owner .. "\31" .. t end, count = true, registry = true },
    -- (Achievements.lua loads after this file: its functions are looked up when called.)
    { wire = "a", part = 1, source = function() return ns.Achievements:GuildRecords() end,
        valid = function(id, rec) return ns.Achievements.ValidGuildRecord(id, rec) end,
        mergeAll = function(t) return (ns.Achievements:MergeGuild(t)) end,
        digest = function(id, rec) return "a" .. id .. "\31" .. rec.at .. "\31" .. tostring(rec.ann or "-") end },
    { wire = "n", part = 2, nested = true, source = function() return (select(3, R:All())) end, valid = R.ValidNaming,
        merge = function(key, namer, e) return R:MergeName(key, namer, e) end,
        digest = function(key, namer, e) return "n" .. key .. "\31" .. namer .. "\31" .. e.at end,
        count = true, registry = true },
    -- Bonds by level, not points: points go out lazily (Bond.lua), and peers
    -- shouldn't SYNC over a few points. A level change goes out at once.
    { wire = "b", part = 3, nested = true, source = function() return R:AdoptedLife() end, valid = R.ValidBond,
        merge = function(key, carer, e) return R:MergeLife(key, carer, e) end,
        digest = function(key, carer, e) return "b" .. key .. "\31" .. carer .. "\31" .. ns.Bond:Level(e.p) end,
        count = true, registry = true },
}

-- Adler-32 of a canonical listing of every store.
function Sync:Digest()
    local parts = {}
    for _, row in ipairs(Sync.TABLES) do
        for k, v in pairs(row.source()) do
            if row.nested then
                for author, e in pairs(v) do parts[#parts + 1] = row.digest(k, author, e) end
            else
                parts[#parts + 1] = row.digest(k, v)
            end
        end
    end
    if #parts == 0 then return 0 end
    table.sort(parts)
    return LibDeflate:Adler32(table.concat(parts, "\30"))
end

local function SendFull()
    pending = nil
    if not IsInGuild() then return end
    lastSent = GetTime()
    local parts = {}
    for _, row in ipairs(Sync.TABLES) do
        parts[row.part] = parts[row.part] or {}
        parts[row.part][row.wire] = row.source()
    end
    for i, msg in ipairs(parts) do
        msg.i, msg.of = i, #parts
        if i == #parts then msg.d = Sync:Digest() end
        ns.Comm:Send("SYNC", msg, "GUILD")
    end
end

-- However often others' SYNCs hold ours back (below), it goes out this many
-- seconds after it was first scheduled: parts anyone can send, rising and
-- starting over, held it forever (code review 2026-11-11). A real SYNC of a
-- big guild takes well under this; past it, two SYNCs at once only cost traffic.
local MAX_HOLD = 120
local deadline -- GetTime() by which the pending SYNC goes out

local function Later(delay)
    local token = {}
    if not pending then deadline = GetTime() + MAX_HOLD end
    pending = token
    delay = math.max(0, math.min(delay, deadline - GetTime()))
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
-- Once per SYNC of ours: a chunk that starts and never finishes (anyone can
-- send one) held it back again every time (code review 2026-11-10).
local HOLD = 30
local held
local function Hold()
    if pending and pending ~= held then
        Later(HOLD)
        held = pending
    end
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

local function Cancel(by)
    if pending then ns.Log("Sync", "%s's SYNC said it all: ours cancelled", tostring(by)) end
    pending = nil
end

local answered = {} -- sender -> "their digest/ours" we last answered a SYNC for
local progress = {} -- sender -> the last part (i) of their SYNC on its way

-- BOND_REQ answers: once per pet every few seconds (Comm:MayReply) let one
-- member asking about many pets in a loop fill our outbox, a minute and more
-- ahead of our own UPD (code review 2026-11-11). So each asker gets at most
-- BOND_ANSWERS a minute (a card asks once per pet a session; a bond answered
-- late is fine, by design), and none while the outbox already has a queue.
local BOND_ANSWERS, BOND_WINDOW, BOND_BACKLOG = 10, 60, 2
local budget = {} -- asker -> { n = answers, at = GetTime() the window began }
local function AnswerBudget(asker)
    local now, b = GetTime(), budget[asker]
    if not b or now - b.at >= BOND_WINDOW then
        b = { n = 0, at = now }
        budget[asker] = b
    end
    if b.n >= BOND_ANSWERS then return false end
    b.n = b.n + 1
    return true
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
    for _, row in ipairs(Sync.TABLES) do
        if row.count and Count(msg[row.wire], row.nested) > max then return true end
    end
    return false
end

-- Merge what a message carries, by the stores' wire keys ({ r = ..., n = ... });
-- returns true if the registry changed.
local function MergeAll(msg)
    local changed = false
    for _, row in ipairs(Sync.TABLES) do
        local t = msg[row.wire]
        if type(t) == "table" then
            if row.mergeAll then
                row.mergeAll(t)
            elseif row.nested then
                for key, byKey in pairs(t) do
                    if type(byKey) == "table" then
                        for author, e in pairs(byKey) do
                            if row.merge(key, author, e) and row.registry then changed = true end
                        end
                    end
                end
            else
                for key, e in pairs(t) do
                    if row.merge(key, e) and row.registry then changed = true end
                end
            end
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
        MergeAll(msg)
        local i, of = tonumber(msg.i), tonumber(msg.of)
        local mine = Sync:Digest()
        if i and of and i < of then
            -- More parts to come: judge when the last is in. A whole part arriving is progress,
            -- so it holds ours back again (a big SYNC can take longer than one hold). Only a
            -- part past the sender's last one is: the same first part sent over and over held
            -- ours forever (code review 2026-11-11).
            if i > (progress[sender] or 0) then
                progress[sender] = i
                if pending then Later(HOLD) end
            end
            return
        end
        -- A whole SYNC (every part before this one came, in order) saying what we'd say: ours isn't
        -- needed. Only a whole one: a lone forged last part carrying our digest (anyone reads it in
        -- HELLO) cancelled the answer a newcomer was waiting for (found 2026-11-11).
        local whole = of and of >= 2 and progress[sender] == of - 1
        progress[sender] = nil
        if mine == msg.d and whole then
            Cancel(sender) -- someone said it for us
        elseif answered[sender] == tostring(msg.d) .. "/" .. mine then
            -- The same disagreement we answered already: they keep what we refuse (an older
            -- version kept a forgery the rules refuse now). Answering again would go on
            -- forever (code review 2026-11-10); a change on either side answers anew.
            ns.Log("Sync", "%s still differs the same way; not answering again", tostring(sender))
        else
            -- We know things the sender doesn't: answer soon (a hold ends here).
            answered[sender] = tostring(msg.d) .. "/" .. mine
            Later(2 + math.random() * 6)
        end
    end, "GUILD")
    ns.Bus:On("COMM_INCOMING", function(_, channel)
        if channel == "GUILD" then Hold() end
    end)
    ns.Comm:Register("UPD", function(msg, sender, channel)
        -- A record is written the moment it's sent: its ts against our clock shows how far
        -- apart the two clocks are (the debug log: Config.CLOCK_SLACK assumes one clock).
        if type(msg.r.ts) == "number" then
            ns.Log("Sync", "clock: %s's record is %+d s from ours", tostring(sender), msg.r.ts - ns.Now())
        end
        -- Only the owner writes their record. Relayed copies come via SYNC.
        MergeAll({ r = { [sender] = msg.r } })
    end, "GUILD", { r = "table" })
    ns.Comm:Register("NICK", function(msg, sender, channel)
        -- Only the namer writes their entry, like UPD.
        MergeAll({ n = { [msg.pet] = { [sender] = msg.e } } })
    end, "GUILD", { pet = "key", e = "table" })
    ns.Comm:Register("BOND", function(msg, sender, channel)
        MergeAll({ b = { [msg.pet] = { [sender] = msg.e } } })
    end, "GUILD", { pet = "key", e = "table" })
    ns.Comm:Register("BOND_REQ", function(msg, sender, channel)
        local e = ns.Registry:Life(msg.pet, ns.PlayerKey())
        if not e or ns.Comm:Backlog() > BOND_BACKLOG then return end
        if ns.Comm:MayReply("BOND:" .. msg.pet, channel) and AnswerBudget(sender) then
            ns.Comm:Send("BOND", { pet = msg.pet, e = e }, "GUILD")
        end
    end, "GUILD", { pet = "key" })
    ns.Comm:Register("LAPSE", function(msg, _, channel)
        MergeAll({ l = msg.l })
    end, "GUILD", { l = "table" })

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

ns.Start("loaded", function() Sync:Init() end)
