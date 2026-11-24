---@class Dyreparken
local ns = select(2, ...)

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
-- A schema with no migration step is kept as it is, never wiped (it was wiped
-- until 0.1.0, which would now throw away every guild's registry for one
-- missing step); the tests check the steps have no gaps.
---@class Dyreparken.DB
local DB = {}
ns.DB = DB

local SCHEMA = 15
local CHAR_SCHEMA = 4
DB.SCHEMA, DB.CHAR_SCHEMA = SCHEMA, CHAR_SCHEMA

-- Every key a module keeps in the account's or the character's table has a
-- line here, under the module that owns it: [Owner] is the one file that
-- writes the key itself (others read it, or ask the owner: Bonds:SetAnnounce,
-- Wish:Shown, Quirks:EggPlayed ...). Keys with a nil default are listed too, so
-- the list is the whole saved shape: tools/test/spec/50_saved.lua reads this
-- file and fails for a key used but not listed, or written by another file.
local ACCOUNT_DEFAULTS = {
    -- [DB]
    guilds = {}, -- [guildName] = GUILD_DEFAULTS' shape (DB:Guild)
    -- [Framework]
    games = { history = {} }, -- games played; the UI changes to undo (stash)
    -- [Achievements]
    ach = { got = {}, seen = {} }, -- account-scope achievements
    achHeard = {}, -- ["sender\31id"] = when: others' achievements already told (OnEarned)
    -- [Unlisted]
    unlisted = {}, -- [speciesID] = { t, how, name, owner }: companions not in Data/Companions.lua, told once
    -- [Settings]
    settings = { -- the account's settings
        chatter = "normal", worldHearts = true, cardParticles = "all", cardMoves = true, celebrate = true, petSounds = true,
        petFrame = false, petFrameArt = false, -- (the pet frame and its background and border: off unless chosen, PetFrame.lua)
        petFrameCombat = false, petFrameFade = false, petFrameAlpha = 0.25, -- (hidden in combat; faded when nothing happens, to this)
        achOthers = true, -- guildmates' achievement lines (2026-11-19, the user: a box of its own, not the chatter's)
        chatFrame = "1", -- the chat window our lines go to (ns.Print; a window gone: the main one)
    },
    -- [Onboarding]
    welcomed = nil, -- told what Dyreparken is, once an account (account migration 15: not for an old install)
    -- [Bond]
    played = nil,   -- "YYYYMMDD": the last day a character of the account played (Bond:CheckComeback)
    comeback = nil, -- "YYYYMMDD": back after a week or more that day, the first pet out's double day still owed
    -- [SceneGallery] (developer galleries, through their picks tables; Scenes and Decor read them)
    scenePicks = {}, -- family -> background path, picked in /dp probe bg
    decorPicks = {}, -- slot -> texture path or "atlas:<name>", picked in /dp probe decor
    -- [LiftEditor]
    liftPicks = {},  -- species id -> lift, set in /dp probe lift; to write into Data/PetMoves.lua
    placePicks = {}, -- stage -> scene id -> { floor, size }, set in /dp probe place; to write into Data/PetScenes.lua
    modelPicks = {}, -- stage -> model ("low high wide", Moves.ModelOf) -> { floor, size }: the same, per model
    -- [MovesEditor]
    movePicks = {},  -- species id -> { reaction = id or false, sleepAt = n }, from /dp probe moves
}

-- Each guild's shared data (Menagerie/Registry.lua has the shapes). A new
-- field only needs a line here; a migration only when old data must change.
local GUILD_DEFAULTS = {
    claims = {},  -- [owner] = record
    lapses = {},  -- [owner] = time their record lapsed
    names = {},   -- [petKey] = { [namer] = nickname entry }
    life = {},    -- [petKey] = { [carer] = bond entry }
    owns = {},    -- [member] = { at, s = "40,5159" }: the pets they own (Menagerie/Owners.lua)
    ach = {},     -- guild achievements earned
    achSeen = {}, -- guild achievements looked at
    born = nil,   -- the guild's first adoption we know of: the park's birthday (Bonds:ParkBorn)
    story = {},   -- [petKey] = its story as this client saw it (Menagerie/Story.lua; local, never sent)
    loyal = {},   -- [carer] = { [petKey] = loyalty points } (Bond:Loyalty, from bond level 7; local, never sent yet)
    rosterHeld = nil, -- { at, owners = { [owner] = true } }: a roster batch held back as too big (Registry:CheckRoster; local)
}

local CHAR_DEFAULTS = {
    -- [Summon]
    autoSummon = true,         -- may be overridden at runtime if AutoCompanion is loaded (SetEnabled)
    activePet = nil,           -- the pet auto-summon keeps out ("Med deg" on its card); nil: the adopted one
    muteSummonSound = true,    -- the clank when a companion is summoned (QuietSummon; SetMuteSound)
    swapFrom = nil,            -- { day, key }: Turnus' swap waiting for its moment: the pet out to replace (Rotate)
    toldDeferral = nil,        -- the AutoCompanion notice, said once a character (AnnounceDeferral)
    -- [Onboarding]
    toldAdoptHow = nil,        -- how the bond grows, said after the character's first adoption (char migration 4)
    -- [Achievements]
    achNotify = true,          -- tell other addon users when I earn an achievement (SetNotify)
    shareHints = 0,            -- the "Del det..." hint after our own achievements, said the first SHARE_HINTS times
    ach = { got = {}, seen = {} }, -- character-scope achievements
    -- [Bonds]
    announce = true,           -- post adoptions and nicknames to guild chat (Announce; SetAnnounce)
    nameLines = nil,           -- { day, n }: name lines posted to guild chat today (Announce)
    patsGiven = nil,           -- ["owner\31petKey"] = true: guildmates' pets you patted (/dp klapp; achievement pats:10)
    unlocksTold = {},          -- [petKey] = { like, dislike, trait }: its minor ones and third trait told at the level-up (TellUnlocks)
    toldNameUnlock = nil,      -- the adoption (its record's `at`) whose nickname unlock was told (TellNameUnlock)
    bondDay = nil,             -- the day the login's milestone and pet-of-the-day lines last showed
    fullHints = nil,           -- how often the plain "full for today" line has shown (its first Bonds.FULL_HINTS times only)
    nudges = nil,              -- the full day's nudge: { ignored = days unheeded, day = the last one's } (Bonds, review 2026-11-24 Q11)
    -- [Weather]
    weather = nil,             -- [kind] = when it last started (Weather.AGAIN: the same weather again isn't new)
    -- [Turnus]
    turnus = nil,              -- { petKey, ... }: the pets that take turns being out, in order (Turnus.lua)
    turnusDay = nil,           -- { day, key, turn }: the day Turnus last picked a pet, which, and whose turn it is after the adopted one
    turnusvakt = nil,          -- { last, n, best, pets = { [petKey] = true } }: days in a row, each a new pet's visit
    -- [Activity]
    activity = {},             -- activity counters
    -- [Sources]
    places = {},               -- [petKey] = { [zone] = true }: where each companion has been ("explore")
    lastPlace = {},            -- [petKey] = the newest place it discovered with you (Stats: the explore chip)
    sourcesDay = nil,          -- { day, met, guildpet, guildgroup, emote }: today's "once a day" (and emotes' minutes)
    -- [Stats]
    chipRounds = {},           -- [petKey] = { [activity] = { m, day } }: a chip's round number reached
    -- [Playdate]
    playmates = {},            -- [petKey] = { ["owner\31theirKey"] = playdates }: best friends
    -- [Cake]
    congratulated = nil,       -- { day, pets = { [petKey] = true } }: cakes clicked today (once a day per pet)
    -- [Moves]
    owed = {},                 -- [petKey] = { [move] = day }: a move a moment earned it today, played once (Moves:Owe)
    -- [Quirks]
    dislikes = {},             -- [petKey] = { [activity] = true }: dislikes seen happen (the card shows these)
    dislikeSaid = {},          -- [petKey] = { [activity] = { n, at } }: how often each was said, the last when (Quirks: getting used to it)
    eggs = {},                 -- [egg id] = { n, day, ... }: easter eggs found (Moves plays dead once: EggPlayed)
    -- [Reactions]
    reacts = {},               -- [row id] = { n, day, key }: class reactions said (Reactions.lua; once a day each)
    homeAt = nil,              -- when you were last in one of your faction's capitals (Reactions' hjemby)
    -- [Familiar]
    familiar = nil,            -- { key, ends }: the mage's familiar out and when its buff ends (Familiar.lua)
    -- [Moments]
    quirkAt = nil,             -- when the last quirk line was shown (at most one every 45 minutes)
    reactAt = nil,             -- when the last common reaction line was said (at most one every 20 minutes)
    rolls = nil,               -- { day, [line id] = won }: today's roll per line, rolled at its first moment
    lastLines = nil,           -- [line prefix] = the variant said last (ns.PickLine: never the same twice in a row)
    -- [Registry]
    named = nil,               -- { day, at = { [petKey] = when } }: today's first new name per pet (once a day)
    ownChange = nil,           -- { k, at, who, to }: a copy from someone else took our pet; asked in the journal (Registry, CardActions)
    -- [Bond]
    bondToday = nil,           -- { day, pets = { [petKey] = { got = { [cap] = n }, total } } }: today's points (Ledger)
    bondGains = {},            -- [petKey] = { gains not yet shown on its card } (Add; BondTrack: TakeGains)
    firsts = {},               -- [petKey] = { [boss name] = true }: bosses it has seen fall with you (First)
    leaders = {},              -- [petKey] = { [leader slug] = true }: your faction's leaders it has met (Leader)
    -- [BondTrack]
    bondLook = {},             -- [petKey] = the bond points its card last showed (the bar grows from there)
    bondSeen = {},             -- [petKey] = the bond level last shown on its card (celebrate once)
    -- [Feats]
    feats = {},                -- [feat id] = { t, before, what, key }: a character's feats, each once
    -- [Wish]
    wish = nil,                -- { day, pet, id, done }: today's wish (Today)
    company = nil,             -- when a guildmate was last with you (a group, their pet met, a playdate): social wishes
    wishes = { n = 0, streak = 0, best = 0 }, -- wishes come true: in all, days in a row (to `last`, a day), the best run;
                               -- kinds = { [activity] = true }: the kinds come true (since 2026-11-22)
    -- [Cuddle]
    cardCuddle = nil,          -- the day a click on the card last counted as a cuddle
    cuddleDays = nil,          -- days with the card's cuddle for the bond, in all (achievement cuddle:30)
    -- [PetFrame]
    petFrame = nil,            -- { point, relativePoint, x, y, scale }: where the pet frame stands, how big (Edit Mode)
    -- [Version]
    warnedVersion = nil,       -- newest version we've already told the player about
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
    -- 12 (2026-11-12, B12): guild achievements with ids this version doesn't
    -- know are capped (Wire.LIMITS.GUILD_UNKNOWN_MAX, the lowest ids kept), as
    -- merges keep them from now on: junk stored under the old cap goes.
    [12] = function(db)
        for _, g in pairs(db.guilds or {}) do
            if type(g.ach) == "table" then ns.Achievements.TrimGuild(g.ach) end
        end
    end,
    -- 13 (2026-11-13, X-Protocol 10): times from the wire are whole seconds, and lapses are capped
    -- (Wire.LIMITS.LAPSES_MAX, the oldest going): drop what peers refuse now, the same on every
    -- client. Only forgeries fail these. (Members only needs no migration: it depends on the
    -- roster, so each complete roster prunes, Registry:Prune.)
    [13] = function(db)
        local R, ValidAch = ns.Registry, ns.Achievements.ValidGuildRecord
        for _, g in pairs(db.guilds or {}) do
            for _, store in ipairs({ { g.claims, R.ValidClaim }, { g.lapses, R.ValidLapseOf }, { g.ach, ValidAch } }) do
                local t, valid = store[1], store[2]
                if type(t) == "table" then
                    for k, e in pairs(t) do if not valid(k, e) then t[k] = nil end end
                end
            end
            for _, store in ipairs({ { g.names, R.ValidNaming }, { g.life, R.ValidBond } }) do
                local t, valid = store[1], store[2]
                if type(t) == "table" then
                    for key, byKey in pairs(t) do
                        if type(byKey) == "table" then
                            for author, e in pairs(byKey) do
                                if not valid(key, author, e) then byKey[author] = nil end
                            end
                        end
                        if type(byKey) ~= "table" or not next(byKey) then t[key] = nil end
                    end
                end
            end
            if type(g.lapses) == "table" then R.TrimLapses(g.lapses) end
        end
    end,
    -- 14 (2026-11-15, the user): "Småting i chatten" is four steps now (Settings.CHATTER), not on/off:
    -- off is "none" (the lines hidden, as before), on is "normal".
    [14] = function(db)
        local s = db.settings
        if type(s) ~= "table" then return end
        if s.chatLines == false then s.chatter = "none" end
        s.chatLines = nil
    end,
    -- 15 (2026-11-19, the user): the welcome is for new players only, so an account that had Dyreparken before
    -- is welcomed already (Onboarding.lua). A fresh one starts at the newest schema, without it.
    [15] = function(db) db.welcomed = true end,
}
DB.MIGRATIONS = MIGRATIONS
local CHAR_MIGRATIONS = {
    -- 2 (2026-11-12, the user): "Kjenner deg ut og inn" (dislikes) now counts the minor like and dislike
    -- too (Personality: unlocked at bond levels 4 and 6), so it was earned too early: taken back. Its
    -- seen flag stays, so earning it again is news, not quiet.
    [2] = function(db)
        if type(db.ach) == "table" and type(db.ach.got) == "table" then db.ach.got.dislikes = nil end
    end,
    -- 3 (2026-11-14, round 2): the card's once-only moves (playing dead, the wish's hop, the sulk) owed in one
    -- list, char.owed, instead of a flag in each module's data. Today's not yet seen carry over.
    [3] = function(db)
        local day = ns.Today()
        db.owed = type(db.owed) == "table" and db.owed or {}
        local function Owe(key, move, on)
            if type(key) == "string" and on == day then db.owed[key] = db.owed[key] or {}; db.owed[key][move] = on end
        end
        local s = db.sulk
        if type(s) == "table" and not s.shown then Owe(s.key, "sulk", s.day) end
        db.sulk = nil
        local e = type(db.eggs) == "table" and db.eggs.dodsfall
        if type(e) == "table" then
            if not e.played then Owe(e.key, "dead", e.day) end
            e.played = nil
        end
        local w = db.wish
        if type(w) == "table" then
            if w.done and not w.shown then Owe(w.pet, "joy", w.day) end
            w.shown = nil
        end
    end,
    -- 4 (2026-11-19, the user): the line after a first adoption is for new players only (Onboarding.lua).
    [4] = function(db) db.toldAdoptHow = true end,
}

local function ApplyDefaults(t, defaults)
    for k, v in pairs(defaults) do
        if t[k] == nil then
            t[k] = type(v) == "table" and CopyTable(v) or v
        elseif type(v) == "table" and type(t[k]) == "table" then
            ApplyDefaults(t[k], v)
        end
    end
end

DB.CHAR_MIGRATIONS = CHAR_MIGRATIONS

local function Migrate(db, target, migrations, label)
    db.schema = db.schema or target
    while db.schema < target do
        local step = migrations[db.schema + 1]
        if not step then
            ns.Log("DB", "%s: no migration %d->%d, kept as it is", label, db.schema, db.schema + 1)
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
