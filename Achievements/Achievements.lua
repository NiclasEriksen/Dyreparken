local _, ns = ...

-- Personal achievements: evaluation, saved state, notices and sharing.
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
-- Dormant: checks run at login, when a pet is learned (NEW_PET_ADDED), when
-- the journal opens, and when your own adoption changes. No polling.
local Ach = {}
ns.Achievements = Ach

local DAY = 86400
local NOTICE_MAX = 20 -- ids per ACH_EARNED; more than any real batch

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

local summarized -- the "you already have N" line, once per session
local learned = 0 -- NEW_PET_ADDED events since the last account check

-- which: "account", "char", or nil for both.
function Ach:Check(reason, which)
    local ctx = Context()
    local new, quiet = {}, 0
    if which ~= "char" then
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
    if which ~= "account" then
        quiet = quiet + Run("char", ctx, false, new)
    end
    ns.Log("Ach", "check (%s): %d new, %d quiet", tostring(reason), #new, quiet)
    if quiet > 0 and not summarized then
        summarized = true
        ns.Print(T().already:format(self:Count()))
    end
    if #new > 0 then self:Notify(new) end
    if #new > 0 or quiet > 0 then ns.Bus:Fire("ACH") end
end

-- How many achievements this character has (account + char).
function Ach:Count()
    local n = 0
    for _, d in ipairs(ns.AchDefs) do
        if Store(Scope(d)).got[d.id] then n = n + 1 end
    end
    return n
end

function Ach:Got(id)
    local d = defsById[id]
    return d and Store(Scope(d)).got[id]
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
    local values = { player = ns.PlayerKey(), name = self:Link(id), progress = progress }
    return ((t.flavor or T().share):gsub("{(%a+)}", function(k) return values[k] end))
end

-- Post every earned, unshared achievement to guild chat. Only from a
-- keypress or click (/dp ach share, the panel's button): Forever blocks
-- guild chat from anything else.
function Ach:Share()
    if not IsInGuild() then return ns.Print(T().not_in_guild) end
    local ctx, n = Context(), 0
    for _, d in ipairs(ns.AchDefs) do
        local g = Store(Scope(d)).got[d.id]
        if g and g.ann == nil then
            SendChatMessage(self:ShareLine(d.id, ctx), "GUILD")
            g.ann = ctx.now
            n = n + 1
        end
    end
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
        local g = Store(Scope(d)).got[d.id]
        if done ~= nil or g then
            if g then
                got = got + 1
                rows[#rows + 1] = ("  |cff40ff40%s|r %s%s"):format(self:Link(d.id), date("%d.%m.%Y", g.at),
                    g.ann == nil and " *" or "")
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
end
