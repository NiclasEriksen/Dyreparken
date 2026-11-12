local _, ns = ...

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
local Bonds = {}
ns.Bonds = Bonds

local SHOW_AFTER = 30 -- seconds after login: the login SYNC has arrived by then
local REPEAT_AFTER = 3600 -- seconds before the same announcement can be posted again
local MAX_OTHERS = 5  -- guild milestone lines; the rest are counted

local Plain = ns.Plain

-- Days counted at local noon, so DST shifts never move a day.
local function DayNumber(t)
    local d = date("*t", t)
    return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
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

-- A minor like or dislike your bond just unlocked (Personality: levels 4 and 6), once each per pet
-- (char.unlocksTold). The like is told; the dislike only that there's something new to find.
function Bonds:TellUnlocks(key, level)
    local P, C = ns.Personality, ns.Config
    local like, dislike = P:Minor(key)
    local told = ns.DB.char.unlocksTold
    told[key] = told[key] or {}
    local name = ns.Registry:NameOf(key)
    if like and level >= C.MINOR_LIKE_LEVEL and not told[key].like then
        told[key].like = true
        -- (always: said even with chat lines off, as it was; docs/REFACTOR.md Q6)
        ns.PetSays(ns.T("unlock.like", { pet = name, what = P.NOUN[like] }), key, "major", true)
    end
    if dislike and level >= C.MINOR_DISLIKE_LEVEL and not told[key].dislike then
        told[key].dislike = true
        ns.PetSays(ns.T("unlock.dislike", { pet = name }), key, "major", true)
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
ns.Bus:On("BOND_FULL", function(key) ns.Print(ns.T("bond.full", { pet = ns.Registry:NameOf(key) })) end)
ns.Bus:On("BOND_LINE", function(key, text, kind)
    if ns.Settings:On("chatLines") then ns.PrintGold(text) end
    ns.Bus:Fire("PET_SAID", key, kind or "like", text)
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
    local lines = {}
    for petKey, owner in pairs(ns.Registry:Holders()) do
        local _, rec = ns.Registry:Holder(petKey)
        local m = owner ~= me and self:Milestone(rec.at, now)
        if m then lines[#lines + 1] = ns.T("milestone.other", { owner = owner, pet = ns.Registry:NameOf(petKey), time = m }) end
    end
    table.sort(lines)
    for i = 1, math.min(#lines, MAX_OTHERS) do ns.Print(lines[i]) end
    if #lines > MAX_OTHERS then ns.Print(ns.T("milestone.more", { n = #lines - MAX_OTHERS })) end
end

-- key, owner of today's pet, or nil when nobody has adopted one.
function Bonds:PetOfTheDay(now)
    local keys = {}
    local known = ns.Companions and ns.Companions.species
    for key in pairs(ns.Registry:Holders()) do
        if not known or known[ns.Pets:SpeciesOfKey(key) or false] then keys[#keys + 1] = key end
    end
    if #keys == 0 then return nil end
    table.sort(keys)
    local day = ns.Today(now)
    local pick = keys[LibStub("LibDeflate"):Adler32("dagens dyr " .. day) % #keys + 1]
    return pick, (ns.Registry:Holder(pick))
end

-- A guildmate's /dp klapp on your pet (2026-11-10): their emote reaches you
-- as CHAT_MSG_EMOTE ("klapper Pepe (Ola Nord sin Panda Cub)."); no message of
-- ours. Your pet answers with hearts at the chat window and a line, at most
-- once per guildmate every PAT_AGAIN. Listened to only while you have an
-- adopted pet. Unverified on Forever: that custom emotes arrive like this.
Bonds.PAT_AGAIN = 300
local patted = {} -- sender -> GetTime()
function Bonds:Patted(text, sender)
    text, sender = Plain(text), ns.NormalizeName(Plain(sender))
    local key = ns.Registry:MyPet()
    if type(text) ~= "string" or type(sender) ~= "string" or not key or ns.Pets:OutKey() ~= key then return end
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
    ns.PetSays(ns.T("pat.thanks", { pet = ns.Registry:NameOf(key), who = sender }), key, "like", true) -- (Q6)
    if ns.Fx then ns.Fx:Burst({ DEFAULT_CHAT_FRAME, "TOPRIGHT", -24, -8 }, "heart", { n = 4, color = ns.Fx.PINK, size = 0.7 }) end
end

function Bonds:WatchPats()
    if ns.Registry:MyPet() then
        ns.Events:On("CHAT_MSG_EMOTE", Bonds, function(_, _, text, sender) Bonds:Patted(text, sender) end)
    else
        ns.Events:Off("CHAT_MSG_EMOTE", Bonds)
    end
end

function Bonds:Init()
    C_Timer.After(SHOW_AFTER, function() Bonds:Celebrate() end)
    ns.Bus:On("MY_RECORD", function() Bonds:WatchPats() end)
    C_Timer.After(SHOW_AFTER, function() Bonds:WatchPats() end) -- (our record may come with the login SYNC)
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
            nick or species, key
    end
    local key = ns.Pets:OutKey()
    if not key then return nil end
    local name = ns.Registry:NameFor(key, me)
    return ns.T("pat.own", { pet = name }), name, key
end

-- The pet answers a pat in its family's voice, for you only (2026-11-10):
-- Locale voice.<family>; a family without one says nothing.
function Bonds:Voice(key, name)
    for _, family in ipairs(key and ns.Scenes:Families(key) or {}) do
        if ns.Strings["voice." .. family] then
            return ns.T("voice." .. family, { pet = name })
        end
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

function Bonds:SetAnnounce(on)
    ns.DB.char.announce = on
    ns.Print(ns.L[on and "announce.on" or "announce.off"])
end

function Bonds:Pat()
    if ns.InCombat() then return ns.Print(ns.L["pat.combat"]) end
    local text, name, key = self:PatText()
    if not text then return ns.Print(ns.L["pat.nothing"]) end
    SendChatMessage(text, "EMOTE")
    local voice = self:Voice(key, name)
    if voice then ns.PetSays(voice, nil, nil, true) end -- (Q6)
end

ns.Start("login", function() Bonds:Init() end)
