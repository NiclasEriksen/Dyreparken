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
    local a, n = date("*t", at), date("*t", now)
    local day = a.day
    -- Adopted on 29 February: the 28th in the years without one.
    if a.month == 2 and day == 29 and date("*t", time({ year = n.year, month = 3, day = 0, hour = 12 })).day == 28 then
        day = 28
    end
    if a.month == n.month and day == n.day then return ns.T("milestone.years", { n = n.year - a.year }) end
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

-- What Bond.lua has to say (it prints nothing itself).
ns.Bus:On("BOND_LEVEL", function(key, level, name)
    ns.Print(ns.T("bond.levelup", { pet = ns.Registry:NameOf(key), n = level, level = name }))
    if key == ns.Registry:MyPet() then Bonds:TellNameUnlock() end
end)
ns.Bus:On("BOND_FULL", function(key) ns.Print(ns.T("bond.full", { pet = ns.Registry:NameOf(key) })) end)
ns.Bus:On("BOND_LINE", function(_, text) ns.PrintGold(text) end)

function Bonds:Celebrate()
    local g = ns.DB:Guild()
    if not g then return end
    local now, me = ns.Now(), ns.PlayerKey()
    local today = ns.Today(now)
    local char = ns.DB.char

    local key, r = ns.Registry:MyPet()
    if key and char.bondDay ~= today then
        char.bondDay = today
        local m = self:Milestone(r.at, now)
        if m then ns.Print(Gold(ns.T("milestone.mine", { pet = ns.Registry:NameOf(key), time = m }))) end
    end
    self:TellNameUnlock()

    if g.bondDay == today then return end
    g.bondDay = today
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

function Bonds:Init()
    C_Timer.After(SHOW_AFTER, function() Bonds:Celebrate() end)
end

-- The emote text for petting the target companion, or our own. nil if
-- there's nothing to pet.
function Bonds:PatText()
    local me = ns.PlayerKey()
    if Plain(UnitIsBattlePetCompanion and UnitIsBattlePetCompanion("target")) then
        local species = Plain(UnitName("target"))
        if type(species) ~= "string" then return nil end
        local owner, r = ns.Tooltip:ReservationOf("target")
        local nick = owner and ns.Registry:Nickname(r.k)
        owner = owner or ns.Tooltip:OwnerOf("target")
        if owner == me or not owner then return ns.T("pat.own", { pet = nick or species }) end
        return ns.T(nick and "pat.other_nick" or "pat.other", { nick = nick, owner = owner, species = species })
    end
    local key = ns.Pets:OutKey()
    if not key then return nil end
    return ns.T("pat.own", { pet = ns.Registry:NameFor(key, me) })
end

local announced = {} -- kind .. key -> GetTime(), this session

-- kind: "adopt" or "name". Call only right after the player's own action.
function Bonds:Announce(kind, key)
    if not (ns.DB.char.announce and IsInGuild() and key) then return end
    local nick = ns.Registry:Nickname(key)
    if kind == "name" and not nick then return end
    local id = kind .. key .. (kind == "name" and nick or "")
    if announced[id] and GetTime() - announced[id] < REPEAT_AFTER then return end
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
    local text = self:PatText()
    if not text then return ns.Print(ns.L["pat.nothing"]) end
    SendChatMessage(text, "EMOTE")
end

ns.Start("login", function() Bonds:Init() end)
