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

local SCHEMA = 1
local CHAR_SCHEMA = 1

local ACCOUNT_DEFAULTS = {
    -- guilds[guildKey] = { pets = { [petKey] = record }, members = { [player] = { seen = t, version = "x" } } }
    -- record = { owner = "Name-Realm", at = serverTime, nick = string?, nickAt = serverTime?, rev = n }
    guilds = {},
    games = { history = {} },
    settings = {},
}

local CHAR_DEFAULTS = {
    autoSummon = true,   -- may be overridden at runtime if AutoCompanion is loaded
    warnedVersion = nil, -- newest version we've already told the player about
}

local MIGRATIONS = {
    -- [2] = function(db) ... end,
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
-- Keyed by guild name + realm so alts in other guilds don't mix data.
function DB:Guild()
    local name, _, _, realm = GetGuildInfo("player")
    if not name then return nil end
    local key = name .. "-" .. (realm or GetNormalizedRealmName() or "")
    local g = self.global.guilds[key]
    if not g then
        g = { pets = {}, members = {} }
        self.global.guilds[key] = g
    end
    return g, key
end
