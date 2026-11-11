local _, ns = ...

-- SavedVariables and their migrations.
--
--   DyreparkenDB      (account): guild registry cache, game history, settings
--   DyreparkenCharDB  (character): this character's own settings
--   DyreparkenDebugDB (account): debug ring buffer, see Debug.lua
--
-- Every saved table carries a schema number. To change the shape of saved
-- data: bump SCHEMA and add MIGRATIONS[n] that turns schema n-1 into n.
-- Migrations run once, in order, at ADDON_LOADED. Never edit an old
-- migration after it has shipped.
--
-- Until 0.1.0 we allow breaking changes: a schema we can't migrate is wiped.
local DB = {}
ns.DB = DB

local SCHEMA = 11
local CHAR_SCHEMA = 1

local ACCOUNT_DEFAULTS = {
    guilds = {}, -- [guildName] = GUILD_DEFAULTS' shape

    games = { history = {} },
    ach = { got = {}, seen = {} }, -- account-scope achievements (Achievements.lua)
    achHeard = {}, -- ["sender\31id"] = when: others' achievements already told (Achievements: OnEarned)
    settings = { -- the account's settings (Menagerie/Settings.lua)
        chatLines = true, worldHearts = true, cardParticles = "all", cardMoves = true, celebrate = true,
        petFrame = false, petFrameArt = false, -- (the pet frame and its background and border: off unless chosen, PetFrame.lua)
    },
    scenePicks = {}, -- family -> background path, picked in /dp probe bg (SceneGallery.lua)
    liftPicks = {},  -- species id -> lift, set in /dp probe lift (LiftEditor.lua); to write into Data/PetMoves.lua
    movePicks = {},  -- species id -> { reaction = id or false, sleepAt = n }, from /dp probe moves (MovesEditor.lua)
    decorPicks = {}, -- slot -> texture path or "atlas:<name>", picked in /dp probe decor (Decor.lua)
}

-- Each guild's shared data (Menagerie/Registry.lua has the shapes). A new
-- field only needs a line here; a migration only when old data must change.
local GUILD_DEFAULTS = {
    claims = {},  -- [owner] = record
    lapses = {},  -- [owner] = time their record lapsed
    names = {},   -- [petKey] = { [namer] = nickname entry }
    life = {},    -- [petKey] = { [carer] = bond entry }
    ach = {},     -- guild achievements earned
    achSeen = {}, -- guild achievements looked at
    born = nil,   -- the guild's first adoption we know of: the park's birthday (Bonds:ParkBorn)
    story = {},   -- [petKey] = its story as this client saw it (Menagerie/Story.lua; local, never sent)
}

local CHAR_DEFAULTS = {
    autoSummon = true,   -- may be overridden at runtime if AutoCompanion is loaded
    activePet = nil,     -- the pet auto-summon keeps out ("Med deg" on its card); nil: the adopted one
    muteSummonSound = true, -- the clank when a companion is summoned (Summon:QuietSummon)
    achNotify = true,          -- tell other addon users when I earn an achievement
    announce = true,           -- post adoptions and nicknames to guild chat (Bonds:Announce)
    activity = {},             -- activity counters (Core/Activity.lua)
    places = {},               -- [petKey] = { [zone] = true }: where each companion has been ("explore")
    chipRounds = {},           -- [petKey] = { [activity] = { m, day } }: a chip's round number reached (Stats)
    playmates = {},            -- [petKey] = { ["owner\31theirKey"] = playdates }: best friends (Playdate)
    congratulated = nil,       -- { day, pets = { [petKey] = true } }: cakes clicked today (Cake: once a day per pet)
    sulk = nil,                -- { key, day, shown }: a dislike came up today (Moves: the pet turns its back, once)
    named = nil,               -- { day, at = { [petKey] = when } }: today's first new name per pet (Registry: once a day)
    nameLines = nil,           -- { day, n }: name lines posted to guild chat today (Bonds:Announce)
    bondGains = {},            -- [petKey] = { gains not yet shown on its card } (Bond:Add; BondTrack shows them)
    bondLook = {},             -- [petKey] = the bond points its card last showed (BondTrack: the bar grows from there)
    lastPlace = {},            -- [petKey] = the newest place it discovered with you (Stats: the explore chip)
    firsts = {},               -- [petKey] = { [boss name] = true }: bosses it has seen fall with you (Bond:First)
    dislikes = {},             -- [petKey] = { [activity] = true }: dislikes seen happen (Quirks.lua; the card shows these)
    eggs = {},                 -- [egg id] = { n, day, ... }: easter eggs found (Quirks.lua)
    wishes = { n = 0, streak = 0, best = 0 }, -- wishes come true: in all, days in a row (to `last`, a day), the best run (Wish.lua)
    quirkAt = nil,             -- when the last quirk line was shown (at most one an hour)
    cardCuddle = nil,          -- the day a click on the card last counted as a cuddle (Cuddle.lua)
    bondSeen = {},             -- [petKey] = the bond level last shown on its card (BondTrack: celebrate once)
    petFrame = nil,            -- { point, relativePoint, x, y, scale }: where the pet frame stands, how big (PetFrame.lua, Edit Mode)
    ach = { got = {}, seen = {} }, -- character-scope achievements (Achievements.lua)
    warnedVersion = nil, -- newest version we've already told the player about
}

local MIGRATIONS = {
    -- 2: guild keys drop the realm ("Dyreparken-CAMWOWEU4Realm5PvE" -> "Dyreparken").
    -- Realms are invisible and unstable on Forever. If two old keys collapse
    -- into one, the first one seen wins (pre-0.1.0, these are empty anyway).
    [2] = function(db)
        local old = db.guilds or {}
        db.guilds = {}
        for key, g in pairs(old) do
            local name = key:match("^(.-)%-[^%-%s]+$") or key
            if not db.guilds[name] then db.guilds[name] = g end
        end
    end,
    -- 3: per-pet records became per-owner records (Registry.lua). Nothing
    -- was ever claimed under the old shape, so start the guild tables fresh.
    [3] = function(db)
        for name in pairs(db.guilds or {}) do db.guilds[name] = { claims = {}, lapses = {} } end
    end,
    -- 4: the "known" species list is gone; the counter's total comes from
    -- Data/Companions.lua now.
    [4] = function(db)
        db.known = nil
    end,
    -- 5: guild achievements, synced (ach) and what this client has looked at
    -- (achSeen), see Achievements.lua.
    [5] = function(db)
        for _, g in pairs(db.guilds or {}) do
            g.ach = g.ach or {}
            g.achSeen = g.achSeen or {}
        end
    end,
    -- 6: nicknames belong to the pet (g.names, see Registry.lua) instead of
    -- the adoption record. A name the holder gave keeps its time.
    [6] = function(db)
        for _, g in pairs(db.guilds or {}) do
            g.names = g.names or {}
            for owner, r in pairs(g.claims or {}) do
                if r.k and type(r.n) == "string" then
                    g.names[r.k] = g.names[r.k] or {}
                    g.names[r.k][owner] = { n = r.n, at = type(r.na) == "number" and r.na or r.ts }
                end
                r.n, r.na = nil, nil
            end
        end
    end,
    -- 7: bonds between carers and pets (g.life, see Registry.lua). Empty:
    -- each carer seeds their own from the days already together (Bond.lua).
    [7] = function(db)
        for _, g in pairs(db.guilds or {}) do g.life = g.life or {} end
    end,
    -- 8 (2026-11-09): bond entries within the new bound (75 a day, a spare
    -- day, not before the epoch). Clamped the same way on every client, so
    -- all copies agree again; one peers would refuse kept a SYNC going forever.
    [8] = function(db)
        local Registry = ns.Registry
        for _, g in pairs(db.guilds or {}) do
            for key, byKey in pairs(g.life or {}) do
                for carer, e in pairs(byKey) do
                    if type(e) == "table" and type(e.p) == "number" and type(e.f) == "number" and type(e.t) == "number" then
                        e.p = math.min(e.p, Registry.LifeCap(e.f, e.t))
                    end
                    if not Registry.ValidLife(e) then byKey[carer] = nil end
                end
                if not next(byKey) or not Registry.ValidKey(key) then g.life[key] = nil end
            end
            for key in pairs(g.names or {}) do
                if not Registry.ValidKey(key) then g.names[key] = nil end
            end
        end
    end,
    -- 9 (2026-11-09, code review): at most Config.NAMES_PER_MEMBER nickname
    -- entries per namer and LIFE_PER_MEMBER bonds per carer, the oldest
    -- going first (Registry: Trim), as merges keep them from now on.
    [9] = function(db)
        local Registry, C = ns.Registry, ns.Config
        for _, g in pairs(db.guilds or {}) do
            -- (and keys with a "|", which ValidKey refuses from now on)
            for _, t in ipairs({ g.names or {}, g.life or {} }) do
                for key in pairs(t) do if not Registry.ValidKey(key) then t[key] = nil end end
            end
            if type(g.names) == "table" then Registry.TrimAll(g.names, "at", C.NAMES_PER_MEMBER) end
            if type(g.life) == "table" then Registry.TrimAll(g.life, "t", C.LIFE_PER_MEMBER) end
        end
    end,
    -- 10 (2026-11-10, code review): records, lapses and names from before the
    -- addon (BOND_EPOCH), claims dated after their record's write, and times
    -- more than CLOCK_SLACK ahead are refused now: drop the stored ones, so
    -- peers agree on what they keep. Only forgeries fail these.
    [10] = function(db)
        local R = ns.Registry
        for _, g in pairs(db.guilds or {}) do
            for owner, r in pairs(g.claims or {}) do
                if not R.ValidRecord(r) then g.claims[owner] = nil end
            end
            for owner, t in pairs(g.lapses or {}) do
                if not R.ValidLapse(t) then g.lapses[owner] = nil end
            end
            for key, byKey in pairs(g.names or {}) do
                if type(byKey) == "table" then
                    for namer, e in pairs(byKey) do
                        if not R.ValidEntry(e) then byKey[namer] = nil end
                    end
                end
                if type(byKey) ~= "table" or not next(byKey) then g.names[key] = nil end
            end
        end
    end,
    -- 11 (2026-11-11, code review): guild achievements dated before the addon
    -- (BOND_EPOCH), or shared before they were earned, are refused now: drop
    -- the stored ones, so peers agree on what they keep. Only forgeries fail these.
    [11] = function(db)
        local valid = ns.Achievements.ValidGuildRecord
        for _, g in pairs(db.guilds or {}) do
            if type(g.ach) == "table" then
                for id, rec in pairs(g.ach) do
                    if not valid(id, rec) then g.ach[id] = nil end
                end
            end
        end
    end,
}
local CHAR_MIGRATIONS = {}

local function ApplyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(t[k]) == "table" then
            ApplyDefaults(t[k], v)
        end
    end
end

local function Migrate(db, target, migrations, label)
    db.schema = db.schema or target
    while db.schema < target do
        local step = migrations[db.schema + 1]
        if not step then
            ns.Log("DB", "%s: no migration %d->%d, resetting", label, db.schema, db.schema + 1)
            wipe(db)
            db.schema = target
            break
        end
        step(db)
        db.schema = db.schema + 1
        ns.Log("DB", "%s migrated to %d", label, db.schema)
    end
end

function DB:Init()
    DyreparkenDB = DyreparkenDB or {}
    DyreparkenCharDB = DyreparkenCharDB or {}
    Migrate(DyreparkenDB, SCHEMA, MIGRATIONS, "account")
    Migrate(DyreparkenCharDB, CHAR_SCHEMA, CHAR_MIGRATIONS, "char")
    ApplyDefaults(DyreparkenDB, ACCOUNT_DEFAULTS)
    ApplyDefaults(DyreparkenCharDB, CHAR_DEFAULTS)
    self.global, self.char = DyreparkenDB, DyreparkenCharDB
end

-- The registry for the player's current guild, or nil when guildless.
-- Keyed by guild name only (no realm, see ns.PlayerKey), so alts in other
-- guilds don't mix data.
local filled = {} -- guild tables given their defaults this session
function DB:Guild()
    local name = GetGuildInfo("player")
    if not name then return nil end
    local g = self.global.guilds[name]
    if not g then
        g = {}
        self.global.guilds[name] = g
    end
    if filled[name] ~= g then
        ApplyDefaults(g, GUILD_DEFAULTS)
        filled[name] = g
    end
    return g, name
end

ns.Start("loaded", function() DB:Init() end)
