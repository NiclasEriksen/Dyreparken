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
-- and posting to guild chat is the player's choice: /dp ach share, or the
-- Del button on the page (Page.lua).
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
-- Guild records we store at most. Ids from newer versions are kept (and
-- relayed), so this leaves room for many; past it, new ids are refused.
-- The cap is on the store, not per message: a per-message cut-off depends
-- on table order, so clients would keep different sets and never agree.
local GUILD_MAX = 128
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

------------------------------------------------------------------------------
-- Icons (Defs.lua: one candidate or a list, best first)
------------------------------------------------------------------------------
local NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
Ach.NO_ICON = NO_ICON

local function Candidates(d)
    local list = type(d.icon) == "table" and d.icon or { d.icon }
    local out = {}
    for _, c in ipairs(list) do
        if type(c) == "string" and not c:find("\\") then c = "Interface\\Icons\\" .. c end
        out[#out + 1] = c
    end
    return out
end

-- Does the client have this icon? File ids are taken on trust; paths are
-- looked up (GetFileIDFromPath). Without that API, every path is assumed to
-- exist.
local function Exists(c)
    if type(c) == "number" then return true end
    if type(c) ~= "string" then return false end
    if not GetFileIDFromPath then return true end
    return GetFileIDFromPath(c) ~= nil
end

local iconCache = {}
function Ach:Icon(d)
    local hit = iconCache[d.id]
    if hit then return hit end
    local icon = NO_ICON
    for _, c in ipairs(Candidates(d)) do
        if Exists(c) then icon = c; break end
    end
    iconCache[d.id] = icon
    return icon
end

local function Scope(d) return d.scope or "account" end

-- Where a scope keeps what it has seen and earned ({ seen, got }), or nil
-- (the guild's, outside a guild). Account and character: { seen, got, owned }
-- as stored; the guild's: its records g.ach and g.achSeen (synced).
local function Store(scope)
    if scope == "char" then return ns.DB.char.ach end
    if scope == "account" then return ns.DB.global.ach end
    local g = ns.DB:Guild()
    return g and { seen = g.achSeen, got = g.ach }
end

local function IsOfficer() return ns.Guild:IsOfficer() end

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
-- The collection kinds, for your own pets (count, all, family) and the
-- guild's (guildcount...: pets someone in the guild cares for). ctx[set]:
-- species id -> truthy; ctx[n]: how many of those count.
local COLLECTIONS = { [""] = { set = "owned", n = "have" }, guild = { set = "cared", n = "caredCount" } }
for prefix, c in pairs(COLLECTIONS) do
    Eval[prefix .. "count"] = function(d, ctx)
        if ctx.total < d.n then return nil end
        local have = ctx[c.n]
        return have >= d.n, math.min(have, d.n), d.n
    end
    Eval[prefix .. "all"] = function(_, ctx)
        if ctx.total == 0 then return nil end
        return ctx[c.n] >= ctx.total, ctx[c.n], ctx.total
    end
    Eval[prefix .. "family"] = function(d, ctx)
        local need, have, set = 0, 0, ctx[c.set]
        for sid, e in pairs(ctx.counting) do
            if HasTag(e, d.tag) then
                need = need + 1
                if set[sid] then have = have + 1 end
            end
        end
        if need == 0 then return nil end
        return have == need, have, need
    end
end
-- Bond points with the pet you care for, against the level's threshold.
function Eval.bond(d)
    local need = ns.Bond.LEVELS[d.level][1]
    local key = ns.Registry:MyPet()
    local e = key and ns.Registry:Life(key, ns.PlayerKey())
    local have = e and e.p or 0
    return have >= need, math.min(have, need), need
end
function Eval.nick(d, ctx)
    -- The holder named it themselves; an inherited name doesn't count.
    local key = ns.Registry:MyPet()
    local _, namer = ns.Registry:Nickname(key)
    local has = (key and namer == ns.PlayerKey()) and 1 or 0
    return has == 1, has, 1
end
-- Every dislike of your adopted pet found out (2026-11-10): seen happen, its
-- line said (char.dislikes). A pet that dislikes nothing: nothing to judge.
function Eval.dislikes()
    local key = ns.Registry:MyPet()
    if not key then return false, 0, 1 end
    local _, list = ns.Personality:Dislikes(key)
    if #list == 0 then return nil end
    local found, have = ns.DB.char.dislikes[key] or {}, 0
    for _, id in ipairs(list) do if found[id] then have = have + 1 end end
    return have == #list, have, #list
end
-- Different easter eggs found (2026-11-10, creative review 2026-11-09).
function Eval.eggs(d)
    local have = 0
    for _, e in pairs(ns.DB.char.eggs) do if type(e) == "table" and (e.n or 0) > 0 then have = have + 1 end end
    return have >= d.n, math.min(have, d.n), d.n
end
-- Wishes come true (Wish.lua, 2026-11-11): the best run of days, and all of them.
function Eval.wishstreak(d)
    local have = ns.DB.char.wishes.best or 0
    return have >= d.n, math.min(have, d.n), d.n
end
function Eval.wishes(d)
    local have = ns.DB.char.wishes.n or 0
    return have >= d.n, math.min(have, d.n), d.n
end
function Eval.activity(d)
    if not ns.Activity:Available(d.act) then return nil end
    local total, mine = ns.Activity:Count(d.act)
    local have = d.pet and mine or total
    return have >= d.n, math.min(have, d.n), d.n
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
    -- Counting pets someone in the guild cares for (one pet per member):
    -- species id -> who.
    ctx.cared, ctx.caredCount = {}, 0
    for key, owner in pairs(ns.Registry:Holders()) do
        local sid = ns.Pets:SpeciesOfKey(key)
        if sid and ctx.counting[sid] and not ctx.cared[sid] then
            ctx.cared[sid] = owner
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

-- The pets behind an achievement, for the page's tooltips. Returns a title,
-- a list of { text, done } sorted by name, and how many didn't fit; or nil
-- for kinds that aren't about particular pets.
--   family, all         the pets you're missing
--   guildfamily         every pet in the family, and who cares for it
--   guildall            the pets nobody cares for yet
local DETAILS_MAX = 12
function Ach:Details(d, ctx)
    ctx = ctx or Context()
    local items = {}
    local function Name(sid) return ns.Pets:NameOfKey(ns.Pets:KeyOfSpecies(sid)) end
    local title
    if d.kind == "family" or d.kind == "all" then
        title = T().tip_missing
        for sid, e in pairs(ctx.counting) do
            if (d.kind == "all" or HasTag(e, d.tag)) and not ctx.owned[sid] then
                items[#items + 1] = { text = Name(sid), done = false }
            end
        end
    elseif d.kind == "guildfamily" then
        for sid, e in pairs(ctx.counting) do
            if HasTag(e, d.tag) then
                local who = ctx.cared[sid]
                items[#items + 1] = { text = Name(sid) .. ": " .. (who or T().tip_no_home), done = who ~= nil }
            end
        end
    elseif d.kind == "guildall" then
        title = T().tip_no_home_title
        for sid in pairs(ctx.counting) do
            if not ctx.cared[sid] then items[#items + 1] = { text = Name(sid), done = false } end
        end
    else
        return nil
    end
    if #items == 0 then return nil end
    table.sort(items, function(x, y) return x.text < y.text end)
    local more = math.max(0, #items - DETAILS_MAX)
    for i = #items, DETAILS_MAX + 1, -1 do items[i] = nil end
    return title, items, more
end

function Ach:Progress(d, have, need)
    if d.kind == "bond" then return ns.Fill(T().points, { have = have, need = need }) end
    return ("%d/%d"):format(have, need)
end

------------------------------------------------------------------------------
-- Checking
------------------------------------------------------------------------------
------------------------------------------------------------------------------
-- Guild scope
------------------------------------------------------------------------------
local outgoing, outgoingTimer = {}, nil -- ids we found and will broadcast

local function GuildName() return (GetGuildInfo("player")) end

local function GuildLine(ids)
    local names = {}
    for _, id in ipairs(ids) do names[#names + 1] = Ach:Link(id) end
    return ns.Fill(T().guild_earned, { guild = GuildName() or "?", list = ns.Join(names) })
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

-- A new achievement's record, per scope: quiet ones (first looks, a jump in
-- the collection) are marked so they're never announced. The guild's go out
-- to everyone (ACH).
local EARNED = {
    account = function(id, at, quiet) return { at = at, told = quiet and "quiet" or nil, ann = quiet and "quiet" or nil } end,
    guild = function(id, at, quiet)
        QueueBroadcast(id)
        return { at = at, q = quiet or nil }
    end,
}
EARNED.char = EARNED.account

-- Judge a scope's achievements. New ones go in `new`, unless quiet: a
-- definition seen for the first time (it may have been true for ages), or
-- quietAll. Returns how many were quiet.
-- Bond levels and nicknames come back from the guild after a reinstall or a
-- crash (the SYNC brings our bond and name a while after login): only one
-- reached here, this session, is news (code review 2026-11-10).
local HERE = { bond = true, nick = true }
local grew = {}

local function Run(scope, ctx, quietAll, new)
    local store, quiet = Store(scope), 0
    if not store then return 0 end
    for _, d in ipairs(ns.AchDefs) do
        if Scope(d) == scope then
            local done = Ach:Evaluate(d, ctx)
            if done ~= nil then
                local firstLook = not store.seen[d.id]
                store.seen[d.id] = true
                if done and not store.got[d.id] then
                    local q = firstLook or quietAll or (HERE[d.kind] and not grew[d.kind])
                    store.got[d.id] = EARNED[scope](d.id, ctx.now, q)
                    if q then quiet = quiet + 1 else new[#new + 1] = d.id end
                end
            end
        end
    end
    return quiet
end

local function ValidGuildRecord(id, rec)
    return type(id) == "string" and #id <= 64 and id:find("^guild:[%w:_]+$") ~= nil
        and type(rec) == "table" and ns.SaneTime(rec.at)
        and (rec.ann == nil or ns.SaneTime(rec.ann))
        and (rec.q == nil or rec.q == true)
end

-- Merge guild records from a peer (ACH or SYNC). Returns true if anything
-- changed. Records new to us that aren't quiet get one line.
function Ach:MergeGuild(list)
    local g = ns.DB:Guild()
    if not g or type(list) ~= "table" then return false end
    local changed, behind, appeared = false, false, {}
    local stored = 0
    for _ in pairs(g.ach) do stored = stored + 1 end
    for id, rec in pairs(list) do
        if ValidGuildRecord(id, rec) and (g.ach[id] or stored < GUILD_MAX) then
            outgoing[id] = nil -- someone said it for us
            local cur = g.ach[id]
            if not cur then
                g.ach[id] = { at = rec.at, ann = rec.ann, q = rec.q }
                stored = stored + 1
                changed = true
                if defsById[id] and not rec.q then appeared[#appeared + 1] = id end
            else
                if rec.at < cur.at then cur.at = rec.at; changed = true end
                if rec.ann and (cur.ann == nil or rec.ann < cur.ann) then cur.ann = rec.ann; changed = true end
                -- The sender has a later date, or no share we know of: they're behind.
                if cur.at < rec.at or (cur.ann and (rec.ann == nil or cur.ann < rec.ann)) then behind = true end
            end
        end
    end
    table.sort(appeared)
    Appeared(appeared)
    if changed then ns.Bus:Fire("ACH") end
    return changed, behind
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
local learnedWaited = false -- some of them had no pet to show at the last check

-- which: "account", "char", "guild", or nil for all.
function Ach:Check(reason, which)
    -- Character achievements (bond, nickname, activities) read their own
    -- data: the full context (the collection, every holder) isn't needed.
    local ctx = which == "char" and { now = ns.Now() } or Context()
    local new, quiet = {}, 0
    if which == nil or which == "account" then
        -- No pets at all: the journal isn't ready (or truly empty). Either
        -- way there's nothing to judge, and marking definitions as seen now
        -- would turn the real collection into a flood of "new" ones later.
        if ctx.ownedCount > 0 then
            local acc = Store("account")
            local jump = acc.owned ~= nil and ctx.ownedCount > acc.owned + learned
            quiet = quiet + Run("account", ctx, jump, new)
            -- Only the pets the collection shows count off: one learned before the journal
            -- lists it still explains the growth at the next check (code review 2026-11-10).
            local growth = math.max(0, ctx.ownedCount - (acc.owned or ctx.ownedCount))
            -- What's left over waits one more check, no longer: a second copy of a species
            -- adds to learned but never to the count, and must not explain a later jump.
            local left = math.max(0, learned - growth)
            if left > 0 and learnedWaited then left = 0 end
            learnedWaited = left > 0
            acc.owned, learned = ctx.ownedCount, left
        end
    end
    if which == nil or which == "char" then
        quiet = quiet + Run("char", ctx, false, new)
    end
    local newGuild = {}
    if which == nil or which == "guild" then
        Run("guild", ctx, false, newGuild)
        Appeared(newGuild)
    end
    ns.Log("Ach", "check (%s): %d new, %d quiet, %d guild", tostring(reason), #new, quiet, #newGuild)
    if quiet > 0 and not summarized then
        summarized = true
        ns.Print(ns.Fill(T().already, { n = self:Count() }))
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
    local store = Store(Scope(d))
    return store and store.got[id]
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
    if #names == 1 then return ns.Fill(T().earned_one, { player = who, name = names[1] }) end
    local last = table.remove(names)
    return ns.Fill(T().earned_many, { player = who, list = table.concat(names, ns.L["list.sep"]), last = last })
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
    ns.Story:Achievements(ids) -- (in the story of the pet out now)
    for _, id in ipairs(ids) do
        local g = self:Got(id)
        if g then g.told = told end
    end
end

-- Others' achievements we've told about, so one isn't told twice: a crash
-- loses the earner's record of it, and they earn it again (code review
-- 2026-11-10). Each is earned once, so the oldest go past HEARD_MAX.
local HEARD_MAX = 500
local function Heard(sender, id)
    local heard = ns.DB.global.achHeard
    local k = sender .. "\31" .. id
    if heard[k] then return true end
    heard[k] = ns.Now()
    local n, oldest, at = 0, nil, nil
    for key, t in pairs(heard) do
        n = n + 1
        if not at or t < at then oldest, at = key, t end
    end
    if n > HEARD_MAX then heard[oldest] = nil end
    return false
end

local function OnEarned(msg, sender, channel)
    if type(msg.a) ~= "table" then return end
    local ids = {}
    for i = 1, math.min(#msg.a, NOTICE_MAX) do
        local id = msg.a[i]
        -- Unknown ids come from newer versions: skip them, show the rest.
        if type(id) == "string" and defsById[id] and not Heard(sender, id) then ids[#ids + 1] = id end
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
    local key = ns.Registry:MyPet()
    if key then
        values.species = ns.Pets:NameOfKey(key)
        values.nick = ns.Registry:Nickname(key)
        values.pet = values.nick or values.species
    end
    -- The first line whose placeholders all have a value.
    for _, line in ipairs({ t.flavor or false, t.plain or false, T().share }) do
        if line then
            local missing = false
            local text = line:gsub("{(%a+)}", function(k)
                if values[k] ~= nil then return values[k] end
                -- Unknown placeholders stay, so typos show.
                if k == "pet" or k == "species" or k == "nick" then missing = true end
            end)
            if not missing then return text end
        end
    end
end

-- Can this player share this achievement now?
function Ach:Shareable(id)
    local d, g = defsById[id], self:Got(id)
    if not (d and g) or g.ann ~= nil then return false end
    return Scope(d) ~= "guild" or IsOfficer()
end

-- Post every earned, unshared achievement (or just `only`) to guild chat.
-- Only from a keypress or click (/dp ach share, the page's Del button):
-- Forever blocks guild chat from anything else.
function Ach:Share(only)
    if not IsInGuild() then return ns.Print(T().not_in_guild) end
    local ctx, n, guild = Context(), 0, {}
    for _, d in ipairs(ns.AchDefs) do
        if (only == nil or only == d.id) and self:Shareable(d.id) then
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

-- Every achievement that exists or was earned, in Defs.lua order:
-- { id, def, got, have, need } (have/need nil when it no longer exists).
-- Guild ones only while in a guild. Also returns the context, for Details.
function Ach:Rows(ctx)
    ctx = ctx or Context()
    local rows, inGuild = {}, ns.DB:Guild() ~= nil
    for _, d in ipairs(ns.AchDefs) do
        if Scope(d) ~= "guild" or inGuild then
            local done, have, need = self:Evaluate(d, ctx)
            local g = self:Got(d.id)
            if done ~= nil or g then
                rows[#rows + 1] = { id = d.id, def = d, got = g, have = have, need = need }
            end
        end
    end
    return rows, ctx
end

-- What a row shows on the right: the date earned, or the progress.
function Ach:RowInfo(row)
    if row.got then return ns.Date(row.got.at) end
    return self:Progress(row.def, row.have, row.need)
end

-- /dp ach: the same list as the panel, in chat.
function Ach:List()
    local rows, got = self:Rows(), 0
    local lines = {}
    for _, row in ipairs(rows) do
        if row.got then
            got = got + 1
            lines[#lines + 1] = ("  |cff40ff40%s|r %s%s"):format(self:Link(row.id), self:RowInfo(row),
                self:Shareable(row.id) and " *" or "")
        else
            lines[#lines + 1] = ("  |cff909090%s|r %s"):format(self:Link(row.id), self:RowInfo(row))
        end
    end
    ns.Print(ns.Fill(T().list_header, { n = got, total = #rows }))
    for _, line in ipairs(lines) do ns.Print(line) end
end

-- Ask the activity engine to watch what our activity achievements count;
-- they're checked again when one happens.
local counted = {} -- activities some achievement counts
function Ach:WatchActivities()
    local any = false
    for _, d in ipairs(ns.AchDefs) do
        if d.kind == "activity" then
            any = true
            counted[d.act] = true
            ns.Activity:Want(d.act, Ach)
        end
    end
    if any and not self.watching then
        self.watching = true
        ns.Bus:On("ACTIVITY", function(id)
            if counted[id] then Ach:CheckCharSoon("activity") end
        end)
    end
end

-- One character check for a burst: an activity and the bond points it gave
-- arrive together (ACTIVITY, then BOND), and one check covers both.
Ach.CheckCharSoon = ns.Debounce(0, function(_, reason) Ach:Check(reason, "char") end)

function Ach:Init()
    ns.Comm:Register("ACH_EARNED", OnEarned, "GUILD")
    self:WatchActivities()
    -- A batch of pets can arrive at once; one check covers them all.
    local checkLearned = ns.Debounce(1, function() Ach:Check("NEW_PET_ADDED", "account") end)
    ns.Events:On("NEW_PET_ADDED", Ach, function()
        learned = learned + 1
        checkLearned()
    end)
    -- (soon: an adoption fires ADOPTED right after its MY_RECORD, and that's a real moment)
    ns.Bus:On("MY_RECORD", function() Ach:CheckCharSoon("MY_RECORD") end)
    -- Adopting a pet you already have a bond with, reaching a loyalty level that way: news
    -- (the user, 2026-11-10).
    ns.Bus:On("ADOPTED", function() grew.bond = true end)
    ns.Bus:On("BOND_LEVEL", function(key) if key == ns.Registry:MyPet() then grew.bond = true end end)
    ns.Bus:On("BOND", function() Ach:CheckCharSoon("BOND") end)
    ns.Bus:On("DISLIKE_FOUND", function() Ach:Check("DISLIKE_FOUND", "char") end)
    ns.Bus:On("EGG_FOUND", function() Ach:Check("EGG_FOUND", "char") end)
    ns.Bus:On("WISH_DONE", function() Ach:Check("WISH_DONE", "char") end)
    ns.Bus:On("MY_NAME", function()
        grew.nick = true
        Ach:Check("MY_NAME", "char")
    end)

    ns.Comm:Register("ACH", function(msg)
        local _, behind = Ach:MergeGuild(msg.a)
        -- Nobody else would correct them: their ACH "said it for us".
        if behind then ns.Sync:Nudge() end
    end, "GUILD")
    -- The registry changes in bursts (a SYNC merges many records): check
    -- the guild ones once it settles.
    ns.Bus:On("REGISTRY", ns.Debounce(GUILD_DEBOUNCE, function() Ach:Check("REGISTRY", "guild") end))
end

ns.Start("loaded", function() Ach:Init() end)
ns.Start("settled", function() Ach:Check("login") end)
