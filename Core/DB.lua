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

local SCHEMA = 7
local CHAR_SCHEMA = 1

local ACCOUNT_DEFAULTS = {
    -- guilds[guildName] = { claims = { [owner] = record }, lapses = { [owner] = t }, names = ..., ach = ..., achSeen = ... }
    -- record: see Menagerie/Registry.lua
    guilds = {},
    games = { history = {} },
    ach = { got = {}, seen = {} }, -- account-scope achievements (Achievements.lua)
    settings = {},
    scenePicks = {}, -- family -> background path, picked in /dp probe bg (SceneGallery.lua)
    decorPicks = {}, -- slot -> texture path or "atlas:<name>", picked in /dp probe decor (Decor.lua)
}

local CHAR_DEFAULTS = {
    autoSummon = true,   -- may be overridden at runtime if AutoCompanion is loaded
    muteSummonSound = true, -- the clank when a companion is summoned (Summon:QuietSummon)
    achNotify = true,          -- tell other addon users when I earn an achievement
    announce = true,           -- post adoptions and nicknames to guild chat (Bonds:Announce)
    activity = {},             -- activity counters (Core/Activity.lua)
    places = {},               -- [petKey] = { [zone] = true }: where each companion has been ("explore")
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
function DB:Guild()
    local name = GetGuildInfo("player")
    if not name then return nil end
    local g = self.global.guilds[name]
    if not g then
        g = { claims = {}, lapses = {}, names = {}, life = {}, ach = {}, achSeen = {} }
        self.global.guilds[name] = g
    end
    return g, name
end
