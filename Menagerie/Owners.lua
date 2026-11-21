---@class Dyreparken
local ns = select(2, ...)

-- Who in the guild owns which companions (2026-11-15, the user: "essential for many of the features I
-- have planned"; X-Protocol 11). Parken shows a pet nobody in the guild has as a question mark, a card's
-- home line names the others who have it, and a pet someone owns has a known personality.
--
-- DATA: one entry per member, written only by them:
--   g.owns[member] = { at = when they wrote it, s = "40,5159" }
--     s: the species ids they own, ascending (Wire.Owned). Copies merge by the higher `at` (ties: the
--     greater s). Pets are for good (the user: "we can assume that people don't lose companions"), so our
--     own list only grows: what the journal says now joins what we wrote before, and a read before the
--     journal is ready can't empty it.
-- What else says someone owns a pet joins it (Owners:Of): its holder (a claim), and every carer with a bond
-- with it (Bond: a pet earns points only while it's out). So a 0.7 client's adoptions and bonds count too.
--
-- THE WIRE, lazier than the registry's (Sync.lua): our own list goes out when it changes (OWN), and the
-- whole store in parts (OWN_SYNC, Config.OWN_PER_PART members each) when a HELLO's `o` (this store's
-- digest) differs from ours, after a longer random wait than the registry's SYNC; held back while someone
-- else's arrives, cancelled when one whole says what ours would. Neither kind is in the registry's digest,
-- so a 0.7 client (X-Protocol 10, which drops kinds stamped 11: Wire.Stamp) syncs the registry as before.
--
-- Members only, as the registry (Registry.lua's header): an entry by someone the last complete roster
-- doesn't list is dropped (not held: the next OWN_SYNC brings it again, and nothing here is urgent), and
-- each complete roster prunes the store. Our own entry is never taken from a peer: a copy of it that
-- isn't ours (a forgery) is answered with ours, written newer.
---@class Dyreparken.Owners
local Owners = {}
ns.Owners = Owners

local C, Wire = ns.Config, ns.Wire
local LibDeflate = LibStub("LibDeflate")

local function G() return ns.DB:Guild() end

function Owners.Valid(owner, e)
    return Wire.Name(owner) and type(e) == "table" and Wire.Since(e.at) and Wire.Owned(e.s)
end

------------------------------------------------------------------------------
-- Who owns what (on demand, cached until something changes)
------------------------------------------------------------------------------
local index, dirty, builtFor = {}, true, nil -- index[petKey] = { [member] = true }

local function Build()
    wipe(index)
    local g, name = G()
    builtFor, dirty = name, false
    if not g then return end
    local function Add(key, who)
        local t = index[key]
        if not t then t = {}; index[key] = t end
        t[who] = true
    end
    for owner, e in pairs(g.owns) do
        for id in e.s:gmatch("%d+") do Add("s:" .. id, owner) end
    end
    for key, owner in pairs(ns.Registry:Holders()) do Add(key, owner) end
    for key, byKey in pairs(g.life) do
        for carer in pairs(byKey) do Add(key, carer) end
    end
end

local function Index()
    if dirty or select(2, G()) ~= builtFor then Build() end
    return index
end

-- { [member] = true } for everyone in the guild known to own this pet (us too, once our entry is written), or nil.
function Owners:Of(key) return Index()[key] end

-- Does anyone in the guild, us included, own this pet?
function Owners:Any(key)
    if not key then return false end
    local t = Index()[key]
    return (t ~= nil and next(t) ~= nil) or ns.Pets:IsOwned(key)
end

-- The others who own it, sorted: not us, and not `except` (its holder, whom the home line names already).
function Owners:Others(key, except)
    local out, me = {}, ns.PlayerKey()
    for who in pairs(self:Of(key) or {}) do
        if who ~= me and who ~= except then out[#out + 1] = who end
    end
    table.sort(out)
    return out
end

local ONLY = { "owners.one", "owners.two", "owners.many" }
local ALSO = { "owners.also.one", "owners.also.two", "owners.also.many" }
-- The card's line under its home (the user: two by name, from three a count), or nil. "også" when someone
-- else has it already: its holder, or us.
function Owners:Line(key)
    local holder = ns.Registry:Holder(key)
    local list = self:Others(key, holder)
    if #list == 0 then return nil end
    local keys = (holder or ns.Pets:IsOwned(key)) and ALSO or ONLY
    return ns.T(keys[math.min(#list, 3)], { a = list[1], b = list[2], n = #list })
end

function Owners:Changed()
    dirty = true
    ns.Bus:Fire("OWNERS")
end

------------------------------------------------------------------------------
-- Our own entry
------------------------------------------------------------------------------
-- Our list as the journal has it, joined with what we wrote before (pets are for good). Returns the entry,
-- and whether it changed.
function Owners:Mine()
    local g, me = G(), ns.PlayerKey()
    if not g then return nil, false end
    local ids, prev = {}, g.owns[me]
    for key in pairs(ns.Pets:Owned()) do
        local sid = ns.Pets:SpeciesOfKey(key)
        if sid and sid > 0 then ids[sid] = true end
    end
    if prev and Wire.Owned(prev.s) then
        for id in prev.s:gmatch("%d+") do ids[tonumber(id)] = true end
    end
    local list = {}
    for id in pairs(ids) do list[#list + 1] = id end
    table.sort(list)
    for i = #list, Wire.LIMITS.OWNS_MAX + 1, -1 do list[i] = nil end -- (more than any collection: still one peers take)
    local s = table.concat(list, ",")
    if prev and prev.s == s then return prev, false end
    local e = { at = math.max(ns.Now(), prev and (prev.at or 0) + 1 or 0), s = s }
    g.owns[me] = e
    return e, true
end

-- Tell the guild when our list changed (and only then: the OWN_SYNC carries it to whoever missed it).
function Owners:Update()
    if not IsInGuild() then return end
    local e, changed = self:Mine()
    if not changed then return end
    ns.Log("Owners", "ours: %d species", select(2, e.s:gsub("%d+", "")))
    ns.Comm:Send("OWN", { e = e }, "GUILD")
    self:Changed()
end

------------------------------------------------------------------------------
-- Merge, prune, digest
------------------------------------------------------------------------------
local loginAt
ns.Start("login", function() loginAt = ns.Now() end)

-- A peer's copy of an entry (from: who sent it on the guild channel). Returns true when the store changed.
function Owners:Merge(owner, e, from)
    local g = G()
    if not g or not Owners.Valid(owner, e) then return false end
    local cur = g.owns[owner]
    if owner == ns.PlayerKey() then
        -- Ours is only ours: a copy that isn't it and would win is outdone by ours, written newer. One written
        -- before this login may be our other PC's, with pets this one's SavedVariables haven't seen yet (review
        -- 2026-11-19): its pets join ours (pets are for good). One since our login can only be made up.
        if cur and (cur.s ~= e.s or cur.at ~= e.at) and e.at >= cur.at then
            if loginAt and e.at < loginAt then
                local ids = {}
                for id in (cur.s .. "," .. e.s):gmatch("%d+") do ids[tonumber(id)] = true end
                local list = {}
                for id in pairs(ids) do list[#list + 1] = id end
                table.sort(list)
                for i = #list, Wire.LIMITS.OWNS_MAX + 1, -1 do list[i] = nil end
                cur.s = table.concat(list, ",")
                ns.Log("Owners", "a copy of ours from before this login (%s): joined", tostring(from))
                self:Changed()
            else
                ns.Log("Owners", "a copy of ours from %s wasn't ours: ours again", tostring(from))
            end
            -- (past theirs, within the clock slack peers allow: one second further, ours was refused too)
            cur.at = math.max(ns.Now(), math.min(e.at + 1, ns.Now() + C.CLOCK_SLACK))
            ns.Comm:Send("OWN", { e = cur }, "GUILD")
        end
        return false
    end
    if cur and (cur.at > e.at or (cur.at == e.at and cur.s >= e.s)) then return false end
    if not ns.Registry.Admit(owner, from) then return false end
    g.owns[owner] = { at = e.at, s = e.s }
    dirty = true
    return true
end

-- After a complete roster (as Registry:Prune): only members' entries stay. Returns true when it changed.
function Owners:Prune()
    local g, roster = G(), ns.Registry.Roster()
    if not g or not roster or ns.Guild.knownAt ~= ns.Guild.at then return false end
    local me, n = ns.PlayerKey(), 0
    for owner in pairs(g.owns) do
        if owner ~= me and not roster[owner] then g.owns[owner], n = nil, n + 1 end
    end
    if n > 0 then ns.Log("Owners", "members only: %d pruned", n) end
    return n > 0
end

-- Adler-32 of the store, every entry a line (DigestLine: the wire, spec 52 pins it). 0 for none.
function Owners.DigestLine(owner, e) return owner .. "\31" .. e.at .. "\31" .. e.s end
function Owners:Digest()
    local g = G()
    if not g then return 0 end
    local lines = {}
    for owner, e in pairs(g.owns) do lines[#lines + 1] = Owners.DigestLine(owner, e) end
    if #lines == 0 then return 0 end
    table.sort(lines)
    return LibDeflate:Adler32(table.concat(lines, "\30"))
end

------------------------------------------------------------------------------
-- OWN_SYNC: the whole store, when a HELLO says someone's differs
------------------------------------------------------------------------------
local pending, deadline, lastSent -- the scheduled OWN_SYNC (a token), when it goes at the latest, our last one
local answered, progress = {}, {} -- sender -> "their digest/ours" last answered; sender -> their last part in

local function Send()
    pending = nil
    local g = G()
    if not g or not IsInGuild() then return end
    lastSent = GetTime()
    local owners = {}
    for owner in pairs(g.owns) do owners[#owners + 1] = owner end
    table.sort(owners)
    local per = C.OWN_PER_PART
    local of = math.max(1, math.ceil(#owners / per))
    for i = 1, of do
        local o = {}
        for j = (i - 1) * per + 1, math.min(i * per, #owners) do o[owners[j]] = g.owns[owners[j]] end
        local msg = { o = o, i = i, of = of }
        if i == of then msg.d = Owners:Digest() end
        ns.Comm:Send("OWN_SYNC", msg, "GUILD")
    end
    ns.Log("Owners", "OWN_SYNC: %d members in %d parts", #owners, of)
end

local held -- the pending OWN_SYNC a chunk on its way held back already
local function Later(delay)
    local token = {}
    if not pending then deadline = GetTime() + C.OWN_MAX_HOLD end
    pending = token
    delay = math.max(0, math.min(delay, deadline - GetTime()))
    if lastSent then delay = math.max(delay, lastSent + C.OWN_GAP - GetTime()) end
    C_Timer.After(delay, function()
        if pending == token then Send() end
    end)
end

-- (timing, not a chance: math.random, as Sync's)
local function Soon() return ns.Within(C.OWN_DELAY) end

local function OnSync(msg, sender)
    local n = 0
    for _ in pairs(msg.o) do n = n + 1 end
    if n > C.SYNC_MAX_ENTRIES then
        ns.Log("Owners", "refused an OWN_SYNC from %s: too many entries", tostring(sender))
        return
    end
    local changed = false
    for owner, e in pairs(msg.o) do
        if Owners:Merge(owner, e, sender) then changed = true end
    end
    if changed then Owners:Changed() end
    local i, of = tonumber(msg.i), tonumber(msg.of)
    if i and of and i < of then
        -- More to come: a part past the sender's last one holds ours back again (Sync's reasons).
        if i > (progress[sender] or 0) then
            progress[sender] = i
            if pending then Later(C.OWN_HOLD) end
        end
        return
    end
    -- Whole: every part before this one came. (One part alone is whole too: a forger with our digest could
    -- cancel our answer to a newcomer, who then asks again at their next login. Nothing here is urgent.)
    local whole = of == 1 or (of and progress[sender] == of - 1)
    progress[sender] = nil
    local mine = Owners:Digest()
    if mine == msg.d then
        if whole and pending then
            ns.Log("Owners", "%s's OWN_SYNC said it all: ours cancelled", tostring(sender))
            pending = nil
        end
    elseif answered[sender] ~= tostring(msg.d) .. "/" .. mine then
        -- We know something they don't (the same disagreement again isn't answered: Sync's reasons).
        answered[sender] = tostring(msg.d) .. "/" .. mine
        Later(Soon())
    end
end

function Owners:Init()
    ns.Comm:Register("HELLO", function(msg)
        -- (a 0.7 client's HELLO has no `o`: it never hears this store)
        if msg.o ~= nil and Wire.Compatible(msg.p) and msg.o ~= Owners:Digest() and not pending then Later(Soon()) end
    end, "GUILD")
    ns.Comm:Register("OWN", function(msg, sender)
        -- Only the owner writes their entry, like UPD.
        if Owners:Merge(sender, msg.e, sender) then Owners:Changed() end
    end, "GUILD", { e = "table" })
    ns.Comm:Register("OWN_SYNC", OnSync, "GUILD", { o = "table" })
    -- Someone's long message is on its way (an OWN_SYNC, or the registry's SYNC): ours waits for it, once per
    -- answer of ours (Sync's Hold). Held only once a whole part was in, every peer whose turn came while the
    -- first part's chunks went out sent too (review 2026-11-21: 14 of 20 answered one login).
    ns.Bus:On("COMM_INCOMING", function(_, channel)
        if channel == "GUILD" and pending and pending ~= held then
            Later(C.OWN_HOLD)
            held = pending
        end
    end)
    ns.Bus:On("ROSTER", function() if Owners:Prune() then Owners:Changed() end end)
    -- Holders and bonds are part of who owns what (Build).
    ns.Bus:On("REGISTRY", function() dirty = true end)
end

ns.Start("loaded", function() Owners:Init() end)
-- Our list, before the HELLO carries the digest (Version: the "hello" phase), and after each pet learned.
ns.Start("settled", function()
    Owners:Update()
    local later = ns.Timers()
    ns.Events:On("NEW_PET_ADDED", Owners, function()
        later:Cancel()
        later:After(C.OWN_LEARN_DELAY, function() Owners:Update() end)
    end)
end)
