local _, ns = ...

-- Achievements: evaluation, saved state, notices, sharing, and guild sync.
-- The plan and its decisions are in docs/ACHIEVEMENTS.md.
--
-- WHAT COUNTS: pets marked `a` in Data/Companions.lua (obtainable in game,
-- event pets included), owned by this account. Families are tags there.
--
-- STORAGE: scope "account" in DyreparkenDB.ach, "char" in DyreparkenCharDB.ach:
--   got[id]  = { at = earned, told = sentToAddonUsers, ann = sharedInGuildChat }
--              told/ann: a time, or "quiet" (never offered), "off", "none"
--   seen[id] = true once a definition has been evaluated here
--   owned    = how many pets the last account check saw (account only)
-- Once earned, an achievement stays earned.
--
-- NEVER ANNOUNCE OLD NEWS. Recorded quietly (told/ann = "quiet"):
--  * a definition met the first time it's evaluated: a fresh install, a
--    reinstall, or an achievement added by an update;
--  * anything met when the collection grew by more pets than we saw being
--    learned (NEW_PET_ADDED) since the last check: pets learned without the
--    addon, or a journal that was still loading. A pet learned while we
--    watch is the only real "moment".
-- Quiet ones get one local summary line, never a notice.
--
-- NOTICES: Forever blocks guild chat from addons unless it comes from a
-- keypress or click (docs/FOREVER_API.md). So a new achievement is sent to
-- other addon users on the addon channel (ACH_EARNED), each prints one line,
-- and posting to guild chat is the player's choice: /dp ach share (later a
-- button in the panel).
--
-- GUILD ACHIEVEMENTS (scope "guild", ids "guild:...") come from the registry
-- every client already has, so every client works them out itself:
--   DB:Guild().ach[id]     = { at = earned, ann = shared, q = quiet } -- synced
--   DB:Guild().achSeen[id] = true                                      -- local only
-- Merge: earliest `at`, earliest `ann`. `q` marks one first noticed by a
-- client looking for the first time (a fresh install): nobody prints a line
-- for it, but officers can still share it. It only affects that first print,
-- so it isn't merged or part of the digest.
-- They ride on the registry sync (digest, SYNC) plus ACH { a = { [id] = rec } }
-- for news. A client that finds a new one prints one line, then waits 2-8 s
-- before broadcasting and stays quiet if someone else's ACH arrives first,
-- so a whole online guild doesn't send it at once. Only an officer or the GM
-- can share one to guild chat. Ids from newer versions are kept and relayed
-- (not shown), so digests still agree across versions.
--
-- Dormant: checks run at login, when a pet is learned (NEW_PET_ADDED), when
-- the journal opens, when your own adoption changes, and (debounced) when
-- the registry changes. No polling.
local Ach = {}
ns.Achievements = Ach

local DAY = 86400
local NOTICE_MAX = 20 -- ids per ACH_EARNED; more than any real batch
local GUILD_MAX = 64  -- records per ACH / SYNC we accept
local GUILD_DEBOUNCE = 5

local defsById = {}
for _, d in ipairs(ns.AchDefs) do defsById[d.id] = d end
Ach.defsById = defsById

local function T() return ns.AchTexts.generic end

function Ach:Name(id)
    local t = ns.AchTexts[id]
    return t and t.name or id
end

function Ach:Link(id) return "[" .. self:Name(id) .. "]" end

local function Scope(d) return d.scope or "account" end

local function Store(scope)
    if scope == "char" then return ns.DB.char.ach end
    return ns.DB.global.ach
end

local function IsOfficer()
    local GI = C_GuildInfo
    return (GI and GI.IsGuildOfficer and GI.IsGuildOfficer()) or (IsGuildLeader and IsGuildLeader()) or false
end
Ach.IsOfficer = IsOfficer

------------------------------------------------------------------------------
-- Evaluation
------------------------------------------------------------------------------
-- species id -> entry, for every pet that counts toward achievements.
local function Counting()
    local list, n = {}, 0
    local data = ns.Companions and ns.Companions.species
    if type(data) == "table" then
        for sid, e in pairs(data) do
            if type(e) == "table" and e.a then list[sid] = e; n = n + 1 end
        end
    end
    return list, n
end

local function HasTag(e, tag)
    for _, t in ipairs(e.t or {}) do if t == tag then return true end end
    return false
end

-- Each returns done, have, need; or nil when the achievement doesn't exist
-- (yet): a count above what exists, a family with no counting pets.
local Eval = {}
function Eval.count(d, ctx)
    if ctx.total < d.n then return nil end
    return ctx.have >= d.n, math.min(ctx.have, d.n), d.n
end
function Eval.all(d, ctx)
    if ctx.total == 0 then return nil end
    return ctx.have >= ctx.total, ctx.have, ctx.total
end
function Eval.family(d, ctx)
    local need, have = 0, 0
    for sid, e in pairs(ctx.counting) do
        if HasTag(e, d.tag) then
            need = need + 1
            if ctx.owned[sid] then have = have + 1 end
        end
    end
    if need == 0 then return nil end
    return have == need, have, need
end
function Eval.loyal(d, ctx)
    local r = ctx.record
    local days = (r and r.k) and math.max(0, math.floor((ctx.now - r.at) / DAY)) or 0
    return days >= d.days, math.min(days, d.days), d.days
end
function Eval.nick(d, ctx)
    local r = ctx.record
    local has = (r and r.k and r.n) and 1 or 0
    return has == 1, has, 1
end
function Eval.guildcount(d, ctx)
    if ctx.total < d.n then return nil end
    return ctx.caredCount >= d.n, math.min(ctx.caredCount, d.n), d.n
end
function Eval.guildall(d, ctx)
    if ctx.total == 0 then return nil end
    return ctx.caredCount >= ctx.total, ctx.caredCount, ctx.total
end
function Eval.guildfamily(d, ctx)
    local need, have = 0, 0
    for sid, e in pairs(ctx.counting) do
        if HasTag(e, d.tag) then
            need = need + 1
            if ctx.cared[sid] then have = have + 1 end
        end
    end
    if need == 0 then return nil end
    return have == need, have, need
end

local function Context()
    local ctx = { now = ns.Now(), owned = {}, have = 0, ownedCount = 0 }
    ctx.counting, ctx.total = Counting()
    for key in pairs(ns.Pets:Owned()) do
        local sid = ns.Pets:SpeciesOfKey(key)
        if sid and not ctx.owned[sid] then
            ctx.owned[sid] = true
            ctx.ownedCount = ctx.ownedCount + 1
            if ctx.counting[sid] then ctx.have = ctx.have + 1 end
        end
    end
    ctx.record = ns.Registry:MyRecord()
    -- Counting pets someone in the guild cares for (one pet per member).
    ctx.cared, ctx.caredCount = {}, 0
    for key in pairs(ns.Registry:Holders()) do
        local sid = ns.Pets:SpeciesOfKey(key)
        if sid and ctx.counting[sid] and not ctx.cared[sid] then
            ctx.cared[sid] = true
            ctx.caredCount = ctx.caredCount + 1
        end
    end
    return ctx
end

-- done, have, need for one definition (nil: doesn't exist yet).
function Ach:Evaluate(d, ctx)
    local fn = Eval[d.kind]
    if not fn then return nil end
    return fn(d, ctx or Context())
end

function Ach:Progress(d, have, need)
    if d.kind == "loyal" then return T().days:format(have, need) end
    return ("%d/%d"):format(have, need)
end

------------------------------------------------------------------------------
-- Checking
------------------------------------------------------------------------------
local function Run(scope, ctx, quietAll, new)
    local store, quiet = Store(scope), 0
    for _, d in ipairs(ns.AchDefs) do
        if Scope(d) == scope then
            local done = Ach:Evaluate(d, ctx)
            if done ~= nil then
                local firstLook = not store.seen[d.id]
                store.seen[d.id] = true
                if done and not store.got[d.id] then
                    local q = firstLook or quietAll
                    store.got[d.id] = { at = ctx.now, told = q and "quiet" or nil, ann = q and "quiet" or nil }
                    if q then quiet = quiet + 1 else new[#new + 1] = d.id end
                end
            end
        end
    end
    return quiet
end

------------------------------------------------------------------------------
-- Guild scope
------------------------------------------------------------------------------
local outgoing, outgoingTimer = {}, nil -- ids we found and will broadcast

local function GuildName() return (GetGuildInfo("player")) end

local function GuildLine(ids)
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = Ach:Link(id) end
    local last = table.remove(names)
    local list = #names > 0 and (table.concat(names, ", ") .. " og " .. last) or last
    return T().guild_earned:format(GuildName() or "?", list)
end

local function Appeared(ids)
    if #ids == 0 then return end
    ns.Print(GuildLine(ids))
    if IsOfficer() then ns.Print(T().guild_hint) end
end

local function Broadcast()
    outgoingTimer = nil
    local g = ns.DB:Guild()
    if not g then outgoing = {}; return end
    local a, n = {}, 0
    for id in pairs(outgoing) do
        if g.ach[id] then a[id] = g.ach[id]; n = n + 1 end
    end
    outgoing = {}
    if n > 0 then ns.Comm:Send("ACH", { a = a }, "GUILD") end
end

local function QueueBroadcast(id)
    outgoing[id] = true
    if outgoingTimer then return end
    local token = {}
    outgoingTimer = token
    C_Timer.After(2 + math.random() * 6, function()
        if outgoingTimer == token then Broadcast() end
    end)
end

local function RunGuild(ctx, new)
    local g = ns.DB:Guild()
    if not g then return 0 end
    local quiet = 0
    for _, d in ipairs(ns.AchDefs) do
        if Scope(d) == "guild" then
            local done = Ach:Evaluate(d, ctx)
            if done ~= nil then
                local firstLook = not g.achSeen[d.id]
                g.achSeen[d.id] = true
                if done and not g.ach[d.id] then
                    g.ach[d.id] = { at = ctx.now, q = firstLook or nil }
                    QueueBroadcast(d.id)
                    if firstLook then quiet = quiet + 1 else new[#new + 1] = d.id end
                end
            end
        end
    end
    return quiet
end

local function ValidGuildRecord(id, rec)
    return type(id) == "string" and #id <= 64 and id:find("^guild:[%w:_]+$") ~= nil
        and type(rec) == "table" and type(rec.at) == "number" and rec.at > 0
        and (rec.ann == nil or (type(rec.ann) == "number" and rec.ann > 0))
        and (rec.q == nil or rec.q == true)
end

-- Merge guild records from a peer (ACH or SYNC). Returns true if anything
-- changed. Records new to us that aren't quiet get one line.
function Ach:MergeGuild(list)
    local g = ns.DB:Guild()
    if not g or type(list) ~= "table" then return false end
    local changed, seen, appeared = false, 0, {}
    for id, rec in pairs(list) do
        seen = seen + 1
        if seen > GUILD_MAX then break end
        if ValidGuildRecord(id, rec) then
            outgoing[id] = nil -- someone said it for us
            local cur = g.ach[id]
            if not cur then
                g.ach[id] = { at = rec.at, ann = rec.ann, q = rec.q }
                changed = true
                if defsById[id] and not rec.q then appeared[#appeared + 1] = id end
            else
                if rec.at < cur.at then cur.at = rec.at; changed = true end
                if rec.ann and (cur.ann == nil or rec.ann < cur.ann) then cur.ann = rec.ann; changed = true end
            end
        end
    end
    table.sort(appeared)
    Appeared(appeared)
    if changed then ns.Bus:Fire("ACH") end
    return changed
end

-- For the sync: every guild record (including ids from newer versions).
function Ach:GuildRecords()
    local g = ns.DB:Guild()
    return g and g.ach or {}
end

function Ach:DigestParts(parts)
    for id, rec in pairs(self:GuildRecords()) do
        parts[#parts + 1] = "a" .. id .. "\31" .. rec.at .. "\31" .. tostring(rec.ann or "-")
    end
end

local summarized -- the "you already have N" line, once per session
local learned = 0 -- NEW_PET_ADDED events since the last account check

-- which: "account", "char", "guild", or nil for all.
function Ach:Check(reason, which)
    local ctx = Context()
    local new, quiet = {}, 0
    if which == nil or which == "account" then
        -- No pets at all: the journal isn't ready (or truly empty). Either
        -- way there's nothing to judge, and marking definitions as seen now
        -- would turn the real collection into a flood of "new" ones later.
        if ctx.ownedCount > 0 then
            local acc = Store("account")
            local jump = acc.owned ~= nil and ctx.ownedCount > acc.owned + learned
            quiet = quiet + Run("account", ctx, jump, new)
            acc.owned, learned = ctx.ownedCount, 0
        end
    end
    if which == nil or which == "char" then
        quiet = quiet + Run("char", ctx, false, new)
    end
    local newGuild = {}
    if which == nil or which == "guild" then
        RunGuild(ctx, newGuild)
        Appeared(newGuild)
    end
    ns.Log("Ach", "check (%s): %d new, %d quiet, %d guild", tostring(reason), #new, quiet, #newGuild)
    if quiet > 0 and not summarized then
        summarized = true
        ns.Print(T().already:format(self:Count()))
    end
    if #new > 0 then self:Notify(new) end
    if #new > 0 or quiet > 0 or #newGuild > 0 then ns.Bus:Fire("ACH") end
end

-- How many achievements this character has (account + char).
function Ach:Count()
    local n = 0
    for _, d in ipairs(ns.AchDefs) do
        if Scope(d) ~= "guild" and Store(Scope(d)).got[d.id] then n = n + 1 end
    end
    return n
end

function Ach:Got(id)
    local d = defsById[id]
    if not d then return nil end
    if Scope(d) == "guild" then
        local g = ns.DB:Guild()
        return g and g.ach[id]
    end
    return Store(Scope(d)).got[id]
end

------------------------------------------------------------------------------
-- Notices (addon channel) and sharing (guild chat, on request)
------------------------------------------------------------------------------
local function Links(ids)
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = Ach:Link(id) end
    return names
end

local function EarnedLine(who, ids)
    local names = Links(ids)
    if #names == 1 then return T().earned_one:format(who, names[1]) end
    local last = table.remove(names)
    return T().earned_many:format(who, table.concat(names, ", "), last)
end
Ach.EarnedLine = EarnedLine

function Ach:Notify(ids)
    ns.Print(EarnedLine(ns.PlayerKey(), ids))
    ns.Print(T().share_hint)
    local told
    if not ns.DB.char.achNotify then
        told = "off"
    elseif not IsInGuild() then
        told = "none"
    else
        ns.Comm:Send("ACH_EARNED", { a = ids }, "GUILD")
        told = ns.Now()
    end
    for _, id in ipairs(ids) do
        local g = self:Got(id)
        if g then g.told = told end
    end
end

local function OnEarned(msg, sender, channel)
    if channel ~= "GUILD" or type(msg.a) ~= "table" then return end
    local ids = {}
    for i = 1, math.min(#msg.a, NOTICE_MAX) do
        local id = msg.a[i]
        -- Unknown ids come from newer versions: skip them, show the rest.
        if type(id) == "string" and defsById[id] then ids[#ids + 1] = id end
    end
    if #ids == 0 then return end
    ns.Print(EarnedLine(sender, ids))
end

-- The guild chat line for an achievement: its flavor, with placeholders.
function Ach:ShareLine(id, ctx)
    local t = ns.AchTexts[id] or {}
    local d = defsById[id]
    local progress = ""
    if d then
        local done, have, need = self:Evaluate(d, ctx)
        if done ~= nil then progress = self:Progress(d, have, need) end
    end
    local values = { player = ns.PlayerKey(), name = self:Link(id), progress = progress, guild = GuildName() or "" }
    return ((t.flavor or T().share):gsub("{(%a+)}", function(k) return values[k] end))
end

-- Post every earned, unshared achievement to guild chat. Only from a
-- keypress or click (/dp ach share, the panel's button): Forever blocks
-- guild chat from anything else.
-- Can this player share this achievement now?
function Ach:Shareable(id)
    local d, g = defsById[id], self:Got(id)
    if not (d and g) or g.ann ~= nil then return false end
    return Scope(d) ~= "guild" or IsOfficer()
end

function Ach:Share()
    if not IsInGuild() then return ns.Print(T().not_in_guild) end
    local ctx, n, guild = Context(), 0, {}
    for _, d in ipairs(ns.AchDefs) do
        if self:Shareable(d.id) then
            local g = self:Got(d.id)
            SendChatMessage(self:ShareLine(d.id, ctx), "GUILD")
            g.ann = ctx.now
            n = n + 1
            if Scope(d) == "guild" then guild[d.id] = g end
        end
    end
    -- Other officers' clients stop offering it.
    if next(guild) then ns.Comm:Send("ACH", { a = guild }, "GUILD") end
    if n == 0 then ns.Print(T().none_to_share) else ns.Bus:Fire("ACH") end
end

function Ach:SetNotify(on)
    ns.DB.char.achNotify = on
    ns.Print(on and T().notify_on or T().notify_off)
end

-- /dp ach: every achievement that exists, earned or with progress.
function Ach:List()
    local ctx, rows, got = Context(), {}, 0
    for _, d in ipairs(ns.AchDefs) do
        local done, have, need = self:Evaluate(d, ctx)
        local g = self:Got(d.id)
        if done ~= nil or g then
            if g then
                got = got + 1
                rows[#rows + 1] = ("  |cff40ff40%s|r %s%s"):format(self:Link(d.id), date("%d.%m.%Y", g.at),
                    self:Shareable(d.id) and " *" or "")
            else
                rows[#rows + 1] = ("  |cff909090%s|r %s"):format(self:Link(d.id), self:Progress(d, have, need))
            end
        end
    end
    ns.Print(T().list_header:format(got, #rows))
    for _, row in ipairs(rows) do ns.Print(row) end
end

function Ach:Init()
    ns.Comm:Register("ACH_EARNED", OnEarned)
    local pending
    ns.Events:On("NEW_PET_ADDED", Ach, function()
        learned = learned + 1
        -- A batch of pets can arrive at once; one check covers them all.
        if pending then return end
        pending = true
        C_Timer.After(1, function()
            pending = false
            Ach:Check("NEW_PET_ADDED", "account")
        end)
    end)
    ns.Bus:On("MY_RECORD", function() Ach:Check("MY_RECORD", "char") end)

    ns.Comm:Register("ACH", function(msg, sender, channel)
        if channel ~= "GUILD" or msg.p ~= ns.PROTOCOL then return end
        Ach:MergeGuild(msg.a)
    end)
    -- The registry changes in bursts (a SYNC merges many records): check
    -- the guild ones once it settles.
    local guildPending
    ns.Bus:On("REGISTRY", function()
        if guildPending then return end
        guildPending = true
        C_Timer.After(GUILD_DEBOUNCE, function()
            guildPending = false
            Ach:Check("REGISTRY", "guild")
        end)
    end)
end
