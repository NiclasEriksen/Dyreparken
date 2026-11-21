---@class Dyreparken
local ns = select(2, ...)

-- Keeping the registry the same on every client.
--
-- Messages (all on GUILD):
--   HELLO  { v, d, o }     login announcement (Version.lua) with our digest (o: Owners.lua's, its own sync)
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
--   BOND_REQ { pet }       who has a bond with this pet? (an older client's card asks so);
--                          each member with one answers with their own BOND
--   BONDS_REQ { pet }      the same, from a newer client (2026-11-19): one answer for all, BONDS
--   BONDS  { pet, b }      every bond with the pet that the sender knows, b[carer] = entry: one
--                          client answers for the guild; the others hold theirs back, and drop it
--                          if it said all they knew (Sync:OnBondsReq)
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
---@class Dyreparken.Sync
local Sync = {}
ns.Sync = Sync

local LibDeflate = LibStub("LibDeflate")
local pending -- the scheduled SYNC broadcast, if any
local lastSent -- GetTime() of our last SYNC

-- At most one SYNC of ours per Config.SYNC_GAP seconds. Normally a round or two
-- settles everything; this caps the cost if something never settles (a
-- bug, or a peer that refuses what we keep).
local C = ns.Config

-- Every store the sync carries, one row each. Digest, SendFull, TooBig and
-- MergeAll only loop over this (until 2026-11-12 each listed the stores by
-- hand, about seven places a store, and guild achievements came in through
-- hooks of their own). A row:
--   wire    its key in a SYNC part (and in UPD/NICK/BOND/LAPSE, as MergeAll takes them)
--   part    the SYNC part it rides in (the header above): changing it changes the wire
--   nested  t[key][author] = entry (else t[author] = entry)
--   source  fn() -> what we send and digest (of bonds, the holders' only: Registry:AdoptedLife)
--   valid   fn(key[, author], entry): the check a merge runs on a peer's copy (and WriteOwn on ours)
--   merge   fn(key[, author], entry, from) -> changed; it checks `valid` itself (the merges are
--           public), and whether the author is a member (Registry: members only; from: the sender),
--           or mergeAll fn(t) -> changed, for a store that merges a whole table at once
--   digest  fn(key[, author], entry) -> its line in the digest; the first letter keeps stores apart
--   count   counted against Config.SYNC_MAX_ENTRIES (TooBig). Guild achievements never were, and
--           counting them now would refuse what older peers accept.
--   registry  a change here is a registry change (Registry:Changed, CheckMine)
--   keyed   a change here touches only its pet (bonds): Registry:Changed names the pets, so the
--           card and the list redraw only those (a guildmate's BOND came for every point)
-- The parts, the digest and what TooBig counts are the wire: tools/test/spec/50_wire.lua pins
-- them for a fixed world.
local R = ns.Registry
Sync.TABLES = {
    -- A claim's digest line carries its pet and date too (X-Protocol 10): with the time of its
    -- write alone, a relayed copy with the same time and another pet was never corrected.
    { wire = "r", part = 1, source = function() return (R:All()) end, valid = R.ValidClaim,
        merge = function(owner, r, from) return R:MergeRecord(owner, r, from) end,
        digest = function(owner, r) return "c" .. owner .. "\31" .. r.ts .. "\31" .. R.ClaimLine(r) end,
        count = true, registry = true },
    { wire = "l", part = 1, source = function() return (select(2, R:All())) end, valid = R.ValidLapseOf,
        mergeAll = function(t, from) return R:MergeLapses(t, from) end,
        digest = function(owner, t) return "l" .. owner .. "\31" .. t end, count = true, registry = true },
    -- (Achievements.lua loads after this file: its functions are looked up when called.)
    { wire = "a", part = 1, source = function() return ns.Achievements:GuildRecords() end,
        valid = function(id, rec) return ns.Achievements.ValidGuildRecord(id, rec) end,
        mergeAll = function(t) return (ns.Achievements:MergeGuild(t)) end,
        digest = function(id, rec) return "a" .. id .. "\31" .. rec.at .. "\31" .. tostring(rec.ann or "-") end },
    { wire = "n", part = 2, nested = true, source = function() return (select(3, R:All())) end, valid = R.ValidNaming,
        merge = function(key, namer, e, from) return R:MergeName(key, namer, e, from) end,
        digest = function(key, namer, e) return "n" .. key .. "\31" .. namer .. "\31" .. e.at .. "\31" .. R.NameLine(e) end,
        count = true, registry = true },
    -- Bonds by level, not points: points go out lazily (Bond.lua), and peers
    -- shouldn't SYNC over a few points. A level change goes out at once.
    { wire = "b", part = 3, nested = true, source = function() return R:AdoptedLife() end, valid = R.ValidBond,
        merge = function(key, carer, e, from) return R:MergeLife(key, carer, e, from) end,
        digest = function(key, carer, e) return "b" .. key .. "\31" .. carer .. "\31" .. ns.Bond:Level(e.p) end,
        count = true, registry = true, keyed = true },
}

-- Adler-32 of a canonical listing of every store.
function Sync:Digest()
    local parts = {}
    for _, row in ipairs(Sync.TABLES) do
        for k, v in pairs(row.source()) do
            if row.nested then
                ---@diagnostic disable-next-line: redundant-parameter (the rows' digests differ: nested ones take an author)
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

-- A part too big to send (a big guild's years of lapses: part 1 passed MAX_PARTS chunks at ~800 of them, and went
-- unsent without a word, review 2026-11-19) goes as several: its biggest table halved, by its sorted keys, until
-- each piece fits. Receivers merge any part by its tables' keys whatever its number (MergeAll), older clients too,
-- so this needs no protocol; a SYNC of an everyday size is laid out as before. An entry too big alone is logged.
local function Halve(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    local a, b = {}, {}
    for i, k in ipairs(keys) do if i <= #keys / 2 then a[k] = t[k] else b[k] = t[k] end end
    return a, b, #keys
end
-- (measured with what SendFull and Comm:Send add to a part, at their biggest: a part that only just fitted without
-- them was refused by Send, every time for the same data, review 2026-11-21)
local SENT_WITH = { i = 999, of = 999, d = 4294967295, k = "SYNC", p = 999 }
local function Fit(msg, out)
    if ns.Comm.Fits(msg, SENT_WITH) then out[#out + 1] = msg; return end
    local wire, most = nil, 0
    for w, t in pairs(msg) do
        local n = 0
        for _ in pairs(t) do n = n + 1 end
        if n > most then wire, most = w, n end
    end
    if most < 2 then return ns.Log("Sync", "a SYNC part too big to send, with one entry in it: left out") end
    local a, b = Halve(msg[wire])
    local first, second = {}, {}
    for w, t in pairs(msg) do first[w], second[w] = t, t end
    first[wire], second[wire] = a, b
    -- (the other tables go in the first half only)
    for w in pairs(second) do if w ~= wire then second[w] = nil end end
    Fit(first, out); Fit(second, out)
end

local function SendFull()
    pending = nil
    if not IsInGuild() then return end
    lastSent = GetTime()
    local byPart = {}
    for _, row in ipairs(Sync.TABLES) do
        byPart[row.part] = byPart[row.part] or {}
        byPart[row.part][row.wire] = row.source()
    end
    local parts = {}
    for _, msg in ipairs(byPart) do Fit(msg, parts) end
    if #parts > #byPart then ns.Log("Sync", "SYNC in %d parts (a part was too big for one)", #parts) end
    for i, msg in ipairs(parts) do
        msg.i, msg.of = i, #parts
        if i == #parts then msg.d = Sync:Digest() end
        if not ns.Comm:Send("SYNC", msg, "GUILD") then ns.Log("Sync", "SYNC part %d of %d not sent", i, #parts) end
    end
end

-- However often others' SYNCs hold ours back (below), it goes out
-- Config.SYNC_MAX_HOLD seconds after it was first scheduled: parts anyone can
-- send, rising and starting over, held it forever (code review 2026-11-11). A
-- real SYNC of a big guild takes well under this; past it, two SYNCs at once
-- only cost traffic.
local deadline -- GetTime() by which the pending SYNC goes out

local function Later(delay)
    local token = {}
    if not pending then deadline = GetTime() + C.SYNC_MAX_HOLD end
    pending = token
    delay = math.max(0, math.min(delay, deadline - GetTime()))
    if lastSent then delay = math.max(delay, lastSent + C.SYNC_GAP - GetTime()) end
    C_Timer.After(delay, function()
        if pending == token then SendFull() end
    end)
end

local function Schedule()
    if pending then return end
    Later(ns.Within(C.SYNC_DELAY))
end

-- Someone's SYNC is on its way: wait for it before sending ours (it may
-- say it all). Comes back to it if that SYNC never finishes arriving.
-- Once per SYNC of ours: a chunk that starts and never finishes (anyone can
-- send one) held it back again every time (code review 2026-11-10).
-- (For Config.SYNC_HOLD seconds.)
local held
local function Hold()
    if pending and pending ~= held then
        Later(C.SYNC_HOLD)
        held = pending
    end
end

-- Ask the guild for bonds with a pet (its card is showing): once per pet a
-- session, and not while flicking through pets (one ask per Config.BOND_ASK_GAP).
-- Once more, Sync.REASK later, if no answer came (review 2026-11-21: peers skip answering while their outbox has a
-- queue, as it does right after someone logs in, and the card then went without its bonds all session).
Sync.REASK = 60
local asked, heard, lastAsk = {}, {}, nil -- pet -> { at, n }; pet -> a BONDS or BOND for it came
function Sync:AskBonds(key)
    if not key or not IsInGuild() then return end
    local now, a = GetTime(), asked[key]
    if a and (heard[key] or a.n >= 2 or now - a.at < Sync.REASK) then return end
    if lastAsk and now - lastAsk < C.BOND_ASK_GAP then return end
    asked[key], lastAsk = { at = now, n = a and a.n + 1 or 1 }, now
    ns.Comm:Send("BONDS_REQ", { pet = key }, "GUILD")
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
-- Config.BOND_ANSWERS a minute (a card asks once per pet a session; a bond answered
-- late is fine, by design), and none while the outbox already has a queue.
local budget = {} -- asker -> { n = answers, at = GetTime() the window began }
local function AnswerBudget(asker)
    local now, b = GetTime(), budget[asker]
    if not b or now - b.at >= C.BOND_ANSWER_WINDOW then
        b = { n = 0, at = now }
        budget[asker] = b
    end
    if b.n >= C.BOND_ANSWERS then return false end
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
-- returns true if the registry changed. from: its sender.
local function MergeAll(msg, from)
    local changed, whole, keys = false, false, {}
    local function Changed(row, key)
        changed = true
        if row.keyed then keys[key] = true else whole = true end
    end
    for _, row in ipairs(Sync.TABLES) do
        local t = msg[row.wire]
        if type(t) == "table" then
            if row.mergeAll then
                if row.mergeAll(t, from) and row.registry then Changed(row) end
            elseif row.nested then
                for key, byKey in pairs(t) do
                    if type(byKey) == "table" then
                        for author, e in pairs(byKey) do
                            ---@diagnostic disable-next-line: redundant-parameter (as above: a nested row's merge)
                            if row.merge(key, author, e, from) and row.registry then Changed(row, key) end
                        end
                    end
                end
            else
                for key, e in pairs(t) do
                    if row.merge(key, e, from) and row.registry then Changed(row, key) end
                end
            end
        end
    end
    if changed then
        ns.Registry:Changed(not whole and keys or nil)
        ns.Registry:CheckMine()
    end
    return changed
end

-- One answer for the guild (review 2026-11-19, 2.3, the user): every member with a bond answered BOND_REQ
-- with their own, so a common pet's card cost everyone online forty messages. Every client keeps the bonds
-- it hears, so one can answer for all: each that knows any waits BONDS_WAIT (random, within it), and one
-- that hears a BONDS saying all it knows (every carer, as many points) before its turn says nothing. Older
-- clients don't know these kinds: they ask and answer with BOND_REQ and BOND as before, which we still
-- answer, and their bonds reach us through their own BONDs. New kinds: no X-Protocol bump (spec 52).
Sync.BONDS_WAIT = { 0.3, 2.5 }
local bondsT = {} -- pet -> its pending answer's timers
local function Ours(key)
    local g = ns.DB:Guild()
    local t = g and g.life[key]
    if not t or not next(t) then return nil end
    local out = {}
    for carer, e in pairs(t) do out[carer] = { p = e.p, f = e.f, t = e.t } end
    return out
end
-- Does `theirs` (carer -> entry) say all `mine` does? Each entry one a merge would take (review 2026-11-21: one
-- with p = math.huge or NaN "covered" every honest answer, and none went), as many points; ours only needs to be
-- there: it's always freshest here (points go out lazily, Bond.lua), and a little behind is fine, by design. Ours
-- missing (a bond with a pet we haven't adopted, which no SYNC carries) isn't covered: it went unheard.
local function Covers(theirs, mine, key)
    if type(theirs) ~= "table" then return false end
    local me = ns.PlayerKey()
    for carer, e in pairs(mine) do
        local o = theirs[carer]
        if not R.ValidBond(key, carer, o) or (carer ~= me and o.p < e.p) then return false end
    end
    return true
end

function Sync:OnBondsReq(key, sender, channel)
    if bondsT[key] or not Ours(key) or ns.Comm:Backlog() > C.BOND_ANSWER_BACKLOG then return end
    if not (ns.Comm:MayReply("BONDS:" .. key, channel) and AnswerBudget(sender)) then return end
    local t = ns.Timers()
    bondsT[key] = t
    local lo, hi = Sync.BONDS_WAIT[1], Sync.BONDS_WAIT[2]
    t:After(lo + (hi - lo) * ns.random(), function()
        bondsT[key] = nil
        local b = Ours(key)
        if b then ns.Comm:Send("BONDS", { pet = key, b = b }, "GUILD") end
    end)
end

-- Someone's answer: ours goes if it said all we'd say.
function Sync:OnBonds(key, b, sender)
    if TooBig({ b = { [key] = b } }) then
        return ns.Log("Sync", "refused a BONDS from %s: too many entries", tostring(sender))
    end
    MergeAll({ b = { [key] = b } }, sender)
    local t, mine = bondsT[key], Ours(key)
    heard[key] = true
    if t and (not mine or Covers(b, mine, key)) then
        t:Cancel(); bondsT[key] = nil
        ns.Log("Sync", "%s's BONDS for %s said it all: ours dropped", tostring(sender), key)
    end
end

-- Registry traffic only counts on the guild channel: a whisper or party
-- message comes from anyone, guild member or not.

function Sync:Init()
    -- (HELLO gets through with any protocol: Version compares them; we don't)
    ns.Comm:Register("HELLO", function(msg)
        if ns.Wire.Compatible(msg.p) and msg.d ~= Sync:Digest() then Schedule() end
    end, "GUILD")
    ns.Comm:Register("SYNC", function(msg, sender, channel)
        if TooBig(msg) then
            ns.Log("Sync", "refused a SYNC from %s: too many entries", tostring(sender))
            return
        end
        MergeAll(msg, sender)
        local i, of = tonumber(msg.i), tonumber(msg.of)
        if i and of and i < of then
            -- More parts to come: judge when the last is in. A whole part arriving is progress,
            -- so it holds ours back again (a big SYNC can take longer than one hold). Only a
            -- part past the sender's last one is: the same first part sent over and over held
            -- ours forever (code review 2026-11-11).
            if i > (progress[sender] or 0) then
                progress[sender] = i
                if pending then Later(C.SYNC_HOLD) end
            end
            return
        end
        -- A whole SYNC (every part before this one came, in order) saying what we'd say: ours isn't
        -- needed. Only a whole one: a lone forged last part carrying our digest (anyone reads it in
        -- HELLO) cancelled the answer a newcomer was waiting for (found 2026-11-11).
        local whole = of and of >= 2 and progress[sender] == of - 1
        progress[sender] = nil
        local mine = Sync:Digest() -- (once, at the last part)
        -- Still apart: one of our rosters may be older than the other's (someone joined or left
        -- in between), and what each keeps differs until both have read a newer one.
        if mine ~= msg.d then ns.Guild:Soon() end
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
            Later(ns.Within(C.SYNC_DELAY))
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
        MergeAll({ r = { [sender] = msg.r } }, sender)
    end, "GUILD", { r = "table" })
    ns.Comm:Register("NICK", function(msg, sender, channel)
        -- Only the namer writes their entry, like UPD.
        MergeAll({ n = { [msg.pet] = { [sender] = msg.e } } }, sender)
    end, "GUILD", { pet = "key", e = "table" })
    ns.Comm:Register("BOND", function(msg, sender, channel)
        heard[msg.pet] = true
        MergeAll({ b = { [msg.pet] = { [sender] = msg.e } } }, sender)
    end, "GUILD", { pet = "key", e = "table" })
    ns.Comm:Register("BONDS_REQ", function(msg, sender, channel) Sync:OnBondsReq(msg.pet, sender, channel) end,
        "GUILD", { pet = "key" })
    ns.Comm:Register("BONDS", function(msg, sender) Sync:OnBonds(msg.pet, msg.b, sender) end,
        "GUILD", { pet = "key", b = "table" })
    ns.Comm:Register("BOND_REQ", function(msg, sender, channel)
        local e = ns.Registry:Life(msg.pet, ns.PlayerKey())
        if not e or ns.Comm:Backlog() > C.BOND_ANSWER_BACKLOG then return end
        if ns.Comm:MayReply("BOND:" .. msg.pet, channel) and AnswerBudget(sender) then
            ns.Comm:Send("BOND", { pet = msg.pet, e = e }, "GUILD")
        end
    end, "GUILD", { pet = "key" })
    ns.Comm:Register("LAPSE", function(msg, sender, channel)
        -- (a SYNC part's cap, so one LAPSE can't fill the lapses' with made-up names)
        if TooBig({ l = msg.l }) then
            ns.Log("Sync", "refused a LAPSE from %s: too many entries", tostring(sender))
            return
        end
        MergeAll({ l = msg.l }, sender)
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
    -- A fresh roster may reveal owners who left or went inactive, and judges what non-members
    -- wrote (Registry: members only; after the lapses, so a claim lapsed now goes now).
    ns.Bus:On("ROSTER", function()
        local added = ns.Registry:CheckRoster()
        if added then ns.Comm:Send("LAPSE", { l = added }, "GUILD") end
        local pruned = ns.Registry:Prune()
        if added or pruned then
            ns.Registry:Changed()
            ns.Registry:CheckMine()
        end
        -- (a stale or partial read judges nothing: what waits for one asks again)
        if ns.Registry:Held() > 0 then ns.Guild:Soon() end
    end)
end

ns.Start("loaded", function() Sync:Init() end)
