---@class Dyreparken
local ns = select(2, ...)

-- The friendship between a member and their companion.
--
-- Milestones: once a day, shortly after login, one line for each bond that
-- has a milestone today (1 month, 100 days, every year), counted in calendar
-- days. Our own gets its own line; the guild's are listed after it. Shown
-- once per day: our own per character, the guild's per guild (so alts don't
-- repeat them). Also, once per adoption, a note when the nickname unlocks.
-- All of it comes from the registry every client already has: no messages.
--
-- Petting: /dp klapp sends a custom emote with the companion's nickname,
-- from the keypress (chat is only allowed from a keypress or click).
--
-- Dagens dyr (pet of the day): every client picks the same adopted pet for
-- a calendar day from the date alone (a hash over the sorted holders), so
-- it needs no messages and everyone sees the same one. Shown on the card.
--
-- Announcements: adopting a companion or naming it posts one line to guild
-- chat, so members without the addon see the park too. Only ever called from
-- the click or command that did it (guild chat needs a hardware event).
-- Per character, on by default (/dp kunngjør). The same line isn't repeated
-- within an hour, in case someone flips back and forth.
---@class Dyreparken.Bonds
local Bonds = {}
ns.Bonds = Bonds

local SHOW_AFTER = 30 -- seconds after login: the login SYNC has arrived by then
local REPEAT_AFTER = 3600 -- seconds before the same announcement can be posted again
local MAX_OTHERS = 3  -- guildmates named in the milestones' line; the rest are counted

local Plain = ns.Plain

-- The local calendar day as a number (a Julian day): from the date alone, so no DST shift or timezone moves it
-- (local noon over 86400 did, far from UTC, review 2026-11-19).
local function DayNumber(t)
    local d = date("*t", t)
    local a = math.floor((14 - d.month) / 12)
    local y, m = d.year + 4800 - a, d.month + 12 * a - 3
    return d.day + math.floor((153 * m + 2) / 5) + 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) - 32045
end
Bonds.DayNumber = DayNumber

-- "1 måned", "100 dager", "2 år", or nil when there's no milestone today.
function Bonds:Milestone(at, now)
    now = now or ns.Now()
    local days = DayNumber(now) - DayNumber(at)
    if days <= 0 then return nil end
    if days == 30 then return ns.L["milestone.month"] end
    if days == 100 then return ns.L["milestone.days100"] end
    local years = Bonds.Anniversary(at, now)
    if years then return ns.T("milestone.years", { n = years }) end
end

-- Whole years since t, if now is its day of the year; else nil. Born on 29
-- February: the 28th in the years without one.
function Bonds.Anniversary(t, now)
    local a, n = date("*t", t), date("*t", now)
    local day = a.day
    if a.month == 2 and day == 29 and date("*t", time({ year = n.year, month = 3, day = 0, hour = 12 })).day == 28 then
        day = 28
    end
    if a.month == n.month and day == n.day and n.year > a.year then return n.year - a.year end
end



local Gold = ns.Gold

-- Once per adoption, when naming opens up (the bond reached NICKNAME_LEVEL):
-- after login, or right when the level is reached (BOND_LEVEL).
function Bonds:TellNameUnlock()
    local key, r = ns.Registry:MyPet()
    local char = ns.DB.char
    if key and ns.Registry:CanNickname(r) and char.toldNameUnlock ~= r.at then
        char.toldNameUnlock = r.at
        local named = ns.Registry:Nickname(key)
        ns.Print(ns.T(named and "nick.unlocked_rename" or "nick.unlocked", { pet = named or ns.Pets:NameOfKey(key) }))
    end
end

-- A minor like or dislike your bond just unlocked (Personality: levels 4 and 6), or its third trait (7), once
-- each per pet (char.unlocksTold). The like and the trait are told; the dislike only that there's something new.
function Bonds:TellUnlocks(key, level)
    local P, C = ns.Personality, ns.Config
    local like, dislike = P:Minor(key)
    local told = ns.DB.char.unlocksTold
    told[key] = told[key] or {}
    local name = ns.Registry:NameOf(key)
    if like and level >= C.MINOR_LIKE_LEVEL and not told[key].like then
        told[key].like = true
        -- (always: a level reached, not a random line; chatter is about those)
        ns.PetSays(ns.T("unlock.like", { pet = name, what = P.NOUN[like] }), key, "major", true)
    end
    if dislike and level >= C.MINOR_DISLIKE_LEVEL and not told[key].dislike then
        told[key].dislike = true
        ns.PetSays(ns.T("unlock.dislike", { pet = name }), key, "major", true)
    end
    local trait = level >= C.THIRD_TRAIT_LEVEL and P:Third(key, true)
    if trait and not told[key].trait then
        told[key].trait = true
        ns.PetSays(ns.T("unlock.trait", { pet = name, trait = trait.name }), key, "major", true)
    end
end

-- What Bond.lua has to say (it prints nothing itself).
ns.Bus:On("BOND_LEVEL", function(key, level, name)
    local line = ns.T("bond.levelup", { pet = ns.Registry:NameOf(key), n = level, level = name })
    ns.Print(line)
    ns.Bus:Fire("PET_SAID", key, "major", line)
    if key == ns.Registry:MyPet() then Bonds:TellNameUnlock() end
    if ns.Personality:Known(key) then Bonds:TellUnlocks(key, level) end
end)
-- Only for the adopted pet (2026-11-19, the user: each pet out earns its own day, and every swap brought a line;
-- the card's tick shows the others'). A nudge toward another pet with room today when there is one (2026-11-22,
-- the content review §4.2), else the plain line, only its first FULL_HINTS times (char.fullHints): daily, it read
-- as "stop playing".
Bonds.FULL_HINTS = 3
-- The nudge stops after NUDGES_IGNORED days of it with no other pet out after it (review 2026-11-24 Q11: with a
-- second pet, it came every full day, forever). Any swap brings it back (char.nudges: { ignored, day }).
Bonds.NUDGES_IGNORED = 3
local function Nudge()
    local char, today = ns.DB.char, ns.Today()
    local n = char.nudges or { ignored = 0 }
    char.nudges = n
    if n.day and n.day ~= today then n.ignored, n.day = n.ignored + 1, nil end -- (the last one went unheeded)
    if n.ignored >= Bonds.NUDGES_IGNORED then return false end
    n.day = today
    return true
end
ns.Bus:On("PET_SWAP", function() if ns.DB.char then ns.DB.char.nudges = nil end end)

function Bonds:FullLine(key)
    local pet = ns.Registry:NameOf(key)
    local other, days = ns.Bond:NextOpen(key)
    if other and Nudge() then
        local vars = { pet = pet, other = ns.Registry:NameOf(other), n = days }
        local which = not days and "bond.full.next.new" or days == 0 and "bond.full.next.today"
            or days == 1 and "bond.full.next.yesterday" or "bond.full.next"
        return ns.PickLine(which, vars), other
    end
    local char = ns.DB.char
    if (char.fullHints or 0) >= self.FULL_HINTS then return nil end
    char.fullHints = (char.fullHints or 0) + 1
    return ns.T("bond.full", { pet = pet })
end
-- The nudge's pet, clickable (2026-11-22, 0.10.0, §4.2): the link takes it out, as its card's swap badge does.
ns.Bus:On("BOND_FULL", function(key)
    if ns.Turnus:TakeOver(key) then return end -- (Turnus' next pet takes over, and says so)
    if key ~= ns.Registry:MyPet() then return end
    local line, other = Bonds:FullLine(key)
    if not line then return end
    line = ns.Gold(line)
    if other then line = line .. " " .. ns.Link("swap", other, ns.T("bond.full.swap", { pet = ns.Registry:NameOf(other) }), "73f28c") end
    ns.Print(line)
end)
ns.OnLink("swap", function(key)
    if not (ns.Registry.Real(key) and ns.Pets:IsOwned(key)) then return end
    ns.Summon:SetActive(key, true)
    ns.JournalUI:Refresh()
end)
ns.Bus:On("COMEBACK", function(key, given)
    local name = ns.Registry:NameOf(key)
    local text = given and ns.PickLine("bond.comeback", { pet = name, n = given })
        or ns.PickLine("bond.comeback.full", { pet = name })
    ns.PrintGold(text)
    ns.Bus:Fire("PET_SAID", key, "major", text)
end)
-- One at a time (review 2026-11-24 Q10, the user: "build that queue"): a boss kill printed the first's line, the wish's
-- and a reaction's in the same second. A bond line comes LINE_GAP after the one before it, in order, and none is lost
-- (a /reload in the wait drops what waits: the points are given already, only the words go).
Bonds.LINE_GAP = 4
local nextLineAt, waiting = 0, 0
-- Lines waiting their turn (/dp state; the tests' c:LinesOut).
function Bonds:Waiting() return waiting end
ns.Bus:On("BOND_LINE", function(key, text, kind)
    local now = GetTime()
    local at = math.max(now, nextLineAt)
    nextLineAt = at + Bonds.LINE_GAP
    local function Say()
        if ns.Settings:Chatty() then ns.PrintGold(text) end
        ns.Bus:Fire("PET_SAID", key, kind or "like", text)
    end
    if at <= now then return Say() end
    ns.Log("Bonds", "a line waits %.1f s", at - now)
    waiting = waiting + 1
    C_Timer.After(at - now, function() waiting = waiting - 1; Say() end)
end)

-- The park's birthday (2026-11-10): the day of the guild's first adoption we
-- know of (the oldest claim: a bond with a pet you haven't adopted isn't an
-- adoption), kept as it only ever gets earlier (g.born: a claim made again
-- later moves its time on). A guild fact, not a player's birthday. Read at login.
function Bonds:ParkBorn()
    local g = ns.DB:Guild()
    if not g then return nil end
    local born = g.born
    for _, r in pairs(g.claims) do if r.at and (not born or r.at < born) then born = r.at end end
    g.born = born
    return born
end

-- How many years old the park is today, on its birthday; else nil.
function Bonds:ParkBirthday(t)
    local g = ns.DB:Guild()
    local born = g and g.born
    if not born then return nil end
    return Bonds.Anniversary(born, t or ns.Now())
end

function Bonds:Celebrate()
    local g = ns.DB:Guild()
    if not g then return end
    self:ParkBorn()
    local now, me = ns.Now(), ns.PlayerKey()
    local today = ns.Today(now)
    local char = ns.DB.char

    local key, r = ns.Registry:MyPet()
    if key and char.bondDay ~= today then
        char.bondDay = today
        local m = self:Milestone(r.at, now)
        if m then ns.Print(Gold(ns.T("milestone.mine", { pet = ns.Registry:NameOf(key), time = m }))) end
        -- Your own pet is the guild's pet of the day (2026-11-10).
        if self:PetOfTheDay(now) == key then ns.Print(Gold(ns.T("today.mine", { pet = ns.Registry:NameOf(key) }))) end
    end
    self:TellNameUnlock()

    if g.bondDay == today then return end
    g.bondDay = today
    local years = self:ParkBirthday(now)
    if years then ns.Print(Gold(ns.T("park.birthday", { n = years }))) end
    -- Guildmates' milestones: one alone in full; more in one line, the first names and how many in all
    -- (2026-11-19, the user: the login's burst in one line).
    local lines, owners = {}, {}
    for petKey, owner in pairs(ns.Registry:Holders()) do
        local _, rec = ns.Registry:Holder(petKey)
        local m = owner ~= me and self:Milestone(rec.at, now)
        if m then
            lines[#lines + 1] = ns.T("milestone.other", { owner = owner, pet = ns.Registry:NameOf(petKey), time = m })
            owners[#owners + 1] = owner
        end
    end
    if #lines == 1 then return ns.Print(lines[1]) end
    if #lines == 0 then return end
    table.sort(owners)
    local shown = {}
    for i = 1, math.min(#owners, MAX_OTHERS) do shown[i] = owners[i] end
    local list = #owners > MAX_OTHERS and table.concat(shown, ns.L["list.sep"]) .. ns.T("milestone.and_more", { n = #owners - MAX_OTHERS })
        or ns.Join(shown)
    ns.Print(ns.T("milestone.others", { list = list }))
end

-- A string's 32-bit FNV-1a hash, with a final mix: the same number on every client. (The multiply by the FNV prime,
-- 2^24 + 403, in two parts: a double holds 53 bits exactly, not 56.)
local M32 = 4294967296
local function Times(h) return ((h % 256) * 16777216 + h * 403) % M32 end
function Bonds.Hash(s)
    local bxor, rshift = bit.bxor, bit.rshift
    local h = 2166136261
    for i = 1, #s do h = Times(bxor(h, s:byte(i)) % M32) end
    h = Times(bxor(h, rshift(h, 15)) % M32)
    return bxor(h, rshift(h, 13)) % M32
end

-- key, owner of today's pet, or nil when nobody has adopted one. Each adopted pet's score for the day, the highest
-- wins (2026-11-23, the user: it changed at random times: the day's number picked a place in the list of adopted
-- pets, and every adoption, letting go or lapse anywhere in the guild moved them all). Now a new adoption takes the
-- crown only if it outscores today's pet (1 in n), and letting go moves it only if it was today's.
function Bonds:PetOfTheDay(now)
    local known = ns.Companions and ns.Companions.species
    local day = ns.Today(now)
    local pick, best
    for key in pairs(ns.Registry:Holders()) do
        if not known or known[ns.Pets:SpeciesOfKey(key) or false] then
            local score = Bonds.Hash("dagens dyr " .. day .. " " .. key)
            if not best or score > best or (score == best and key < pick) then pick, best = key, score end
        end
    end
    if not pick then return nil end
    return pick, (ns.Registry:Holder(pick))
end

-- A guildmate's /dp klapp on your pet (2026-11-10): their emote reaches you
-- as CHAT_MSG_EMOTE ("klapper Pepe (Ola Nord sin Panda Cub)."); no message of
-- ours. Your pet answers with hearts at the chat window and a line, at most
-- once per guildmate every PAT_AGAIN. Unverified on Forever: that custom emotes arrive like this.
-- 2026-11-19 (the user): any pet of yours that's out, adopted or not, and it earns Config.BOND_PAT_POINTS
-- (Bond.REWARDS.pat: within the day's limit, at the pet's rate), and counts as the activity "patted" (a wish
-- now and then: Wish.PAT_EVERY). So it's listened to always (Bonds:Init): no event says a pet of ours came
-- out but COMPANION_UPDATE, every companion nearby; anything not a pat goes at the first check.
Bonds.PAT_AGAIN = 300
local patted = {} -- sender -> GetTime()
function Bonds:Patted(text, sender)
    text = Plain(text)
    if type(text) ~= "string" or text:sub(1, 8) ~= "klapper " then return end
    sender = ns.NormalizeName(Plain(sender))
    local key = ns.Pets:OutKey()
    if type(sender) ~= "string" or not key then return end
    local me = ns.PlayerKey()
    if sender == me or ns.Guild:IsMember(sender) ~= true then return end
    -- Our own emote's two shapes (pat.other, pat.other_nick), anchored: a nickname that
    -- holds "Ola Nord sin" mustn't count (code review 2026-11-10).
    local mine = me .. " sin "
    local plain = not text:find("(", 1, true) and text:sub(1, #mine + 8) == "klapper " .. mine
    local inner = text:match("%(([^()]*)%)%.$") -- (the last brackets: the owner and species)
    if not plain and not (inner and inner:sub(1, #mine) == mine) then return end
    local now = GetTime()
    if patted[sender] and now - patted[sender] < self.PAT_AGAIN then return end
    patted[sender] = now
    -- (always: an answer to a guildmate's pat; the name it has for us, as our own /klapp says it)
    ns.PetSays(ns.PickLine("pat.thanks", { pet = ns.Registry:NameFor(key, me), who = sender }), key, "like", true)
    if ns.Fx then ns.Fx:Burst({ DEFAULT_CHAT_FRAME, "TOPRIGHT", -24, -8 }, "heart", { n = 4, color = ns.Fx.PINK, size = 0.7 }) end
    ns.Bond:Reward("pat", key)
    ns.Activity:Emit("patted", 1, sender)
end

-- Your own /bonk, /boop or /pat at the pet that's out (2026-11-22, the user, before 0.10.x): it answers, a line of
-- emote.<kind>.N, at most once a minute per kind (a session's memory). No points: flavor. CHAT_MSG_TEXT_EMOTE
-- names the pet by its name in the world (as "cuddle" reads it, Activity.EmoteKind); the enUS texts: "You bonk %s on
-- the noggin. Doh!", "You gently pat %s.", and /boop's "You boop %s..." unverified (Verify: emote:<kind>).
Bonds.EMOTES = { bonk = "^you bonk ", boop = "^you boop ", pat = "^you [%a ]-pat " }
Bonds.EMOTE_AGAIN = 60
local emoted = {} -- kind -> GetTime()
function Bonds:EmotedAt(text, guid)
    text = Plain(text)
    if type(text) ~= "string" or not (type(Plain(guid)) == "string" and guid == UnitGUID("player")) then return end
    local lower, kind = text:lower(), nil
    for k, pat in pairs(self.EMOTES) do if lower:find(pat) then kind = k end end
    if not kind then return end
    local key, out = ns.Pets:OutKey()
    local name = out and ns.Pets:WorldName(out)
    if not (key and name and text:find(name, 1, true)) then return end
    local now = GetTime()
    if emoted[kind] and now - emoted[kind] < self.EMOTE_AGAIN then return end
    emoted[kind] = now
    ns.Log("Bonds", "emote %s at %s", kind, key)
    ns.PetSays(ns.PickLine("emote." .. kind, { pet = ns.Registry:NameFor(key, ns.PlayerKey()) }), key,
        kind == "bonk" and "say" or "like", true)
end

function Bonds:Init()
    C_Timer.After(SHOW_AFTER, function() Bonds:Celebrate() end)
    ns.Events:On("CHAT_MSG_EMOTE", Bonds, function(_, _, text, sender) Bonds:Patted(text, sender) end)
    -- (always: emotes are rare, and Activity's emote sources listen only while a like wants them)
    ns.Events:On("CHAT_MSG_TEXT_EMOTE", Bonds, function(_, _, text, ...) Bonds:EmotedAt(text, (select(11, ...))) end)
end

-- The emote text for petting the target companion, or our own. nil if
-- there's nothing to pet. Also: what the pet is called and its key (nil when
-- the target's species is unknown), for its answer.
function Bonds:PatText()
    local me = ns.PlayerKey()
    if Plain(UnitIsBattlePetCompanion and UnitIsBattlePetCompanion("target")) then
        local species = Plain(UnitName("target"))
        if type(species) ~= "string" then return nil end
        local sid = Plain(UnitBattlePetSpeciesID and UnitBattlePetSpeciesID("target"))
        local key = type(sid) == "number" and ns.Pets:KeyOfSpecies(sid) or nil
        local owner, r = ns.Tooltip:ReservationOf("target")
        local nick = owner and ns.Registry:Nickname(r.k)
        owner = owner or ns.Tooltip:OwnerOf("target")
        if owner == me or not owner then return ns.T("pat.own", { pet = nick or species }), nick or species, key end
        return ns.T(nick and "pat.other_nick" or "pat.other", { nick = nick, owner = owner, species = species }),
            nick or species, key, owner
    end
    local key = ns.Pets:OutKey()
    if not key then return nil end
    local name = ns.Registry:NameFor(key, me)
    return ns.T("pat.own", { pet = name }), name, key
end

-- The pet answers a pat in its family's voice, for you only (2026-11-10):
-- Locale voice.<family> (and its variants, ns.Lines); a family without one says nothing.
function Bonds:Voice(key, name)
    for _, family in ipairs(key and ns.Scenes:Families(key) or {}) do
        local line = ns.PickLine("voice." .. family, { pet = name })
        if line then return line end
    end
end

local announced = {} -- kind .. key -> GetTime(), this session

-- kind: "adopt" or "name". Call only right after the player's own action.
function Bonds:Announce(kind, key)
    if not (ns.DB.char.announce and IsInGuild() and key) then return end
    local nick = ns.Registry:Nickname(key)
    if kind == "name" and not nick then return end
    local id = kind .. key .. (kind == "name" and nick or "")
    if announced[id] and GetTime() - announced[id] < REPEAT_AFTER then return end
    if kind == "name" then -- (at most Config.NAME_LINES a day: a typo fixed twice, say)
        local today, lines = ns.Today(), ns.DB.char.nameLines
        if not lines or lines.day ~= today then lines = { day = today, n = 0 }; ns.DB.char.nameLines = lines end
        if lines.n >= ns.Config.NAME_LINES then return end
        lines.n = lines.n + 1
    end
    announced[id] = GetTime()
    local me, species = ns.PlayerKey(), ns.Pets:NameOfKey(key)
    local text
    if kind == "adopt" then
        text = ns.T(nick and "announce.adopt_nick" or "announce.adopt", { player = me, species = species, nick = nick })
    else
        text = ns.T("announce.name", { player = me, species = species, nick = nick })
    end
    SendChatMessage(text, "GUILD")
end

-- quiet: from the settings page, whose checkbox already shows it.
function Bonds:SetAnnounce(on, quiet)
    ns.DB.char.announce = on
    if quiet then return end
    ns.Print(ns.L[on and "announce.on" or "announce.off"])
end

function Bonds:Pat()
    if ns.InCombat() then return ns.Print(ns.L["pat.combat"]) end
    local text, name, key, owner = self:PatText()
    if not text then return ns.Print(ns.L["pat.nothing"]) end
    SendChatMessage(text, "EMOTE")
    -- A guildmate's pet (2026-11-22, 0.10.0: the achievement pats:10): each pet of each guildmate once.
    if owner and key and ns.Guild:IsMember(owner) then
        local given = ns.DB.char.patsGiven or {}
        ns.DB.char.patsGiven = given
        local id = owner .. "\31" .. key
        if not given[id] then given[id] = true; ns.Bus:Fire("PAT_GIVEN", key, owner) end
    end
    local voice = self:Voice(key, name)
    if voice then ns.PetSays(voice, nil, nil, true) end -- (always: your own /dp klapp)
end

ns.Start("login", function() Bonds:Init() end)
