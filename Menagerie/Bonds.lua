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

local function Plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

-- Days counted at local noon, so DST shifts never move a day.
local function DayNumber(t)
    local d = date("*t", t)
    return math.floor(time({ year = d.year, month = d.month, day = d.day, hour = 12 }) / 86400)
end

-- "1 måned", "100 dager", "2 år", or nil when there's no milestone today.
function Bonds:Milestone(at, now)
    now = now or ns.Now()
    local days = DayNumber(now) - DayNumber(at)
    if days <= 0 then return nil end
    if days == 30 then return "1 måned" end
    if days == 100 then return "100 dager" end
    local a, n = date("*t", at), date("*t", now)
    if a.month == n.month and a.day == n.day then return ("%d år"):format(n.year - a.year) end
end

-- What a pet is called: its nickname, or the species name.
function Bonds:NameOf(key)
    return ns.Registry:Nickname(key) or ns.Pets:NameOfKey(key)
end

local function Gold(text) return "|cffffd100" .. text .. "|r" end

function Bonds:Celebrate()
    local g = ns.DB:Guild()
    if not g then return end
    local now, me = ns.Now(), ns.PlayerKey()
    local today = date("%Y%m%d", now)
    local char = ns.DB.char

    local key, r = ns.Registry:MyPet()
    if key and char.bondDay ~= today then
        char.bondDay = today
        local m = self:Milestone(r.at, now)
        if m then ns.Print(Gold(("I dag har %s bodd hos deg i %s!"):format(self:NameOf(key), m))) end
    end
    if key and ns.Registry:CanNickname(r) and char.toldNameUnlock ~= r.at then
        char.toldNameUnlock = r.at
        local named = ns.Registry:Nickname(key)
        ns.Print(named and ("Nå kan du gi %s et nytt kallenavn hvis du vil: /dp navn"):format(named)
            or ("Nå kan du gi %s et kallenavn: /dp navn"):format(ns.Pets:NameOfKey(key)))
    end

    if g.bondDay == today then return end
    g.bondDay = today
    local lines = {}
    for petKey, owner in pairs(ns.Registry:Holders()) do
        local _, rec = ns.Registry:Holder(petKey)
        local m = owner ~= me and self:Milestone(rec.at, now)
        if m then lines[#lines + 1] = ("%s og %s feirer %s sammen i dag!"):format(owner, self:NameOf(petKey), m) end
    end
    table.sort(lines)
    for i = 1, math.min(#lines, MAX_OTHERS) do ns.Print(lines[i]) end
    if #lines > MAX_OTHERS then ns.Print(("... og %d til."):format(#lines - MAX_OTHERS)) end
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
    local day = date("%Y%m%d", now or ns.Now())
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
        if owner == me or not owner then return ("klapper %s."):format(nick or species) end
        if nick then return ("klapper %s (%s sin %s)."):format(nick, owner, species) end
        return ("klapper %s sin %s."):format(owner, species)
    end
    local guid = ns.Pets:Summoned()
    if not guid then return nil end
    local key = ns.Pets:KeyOf(guid)
    local mine = ns.Registry:MyPet()
    return ("klapper %s."):format(mine == key and self:NameOf(key) or ns.Pets:NameOfKey(key))
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
        text = nick and ("Dyreparken: %s adopterte %s («%s»)!"):format(me, species, nick)
            or ("Dyreparken: %s adopterte %s!"):format(me, species)
    else
        text = ("Dyreparken: %s ga %s kallenavnet «%s»!"):format(me, species, nick)
    end
    SendChatMessage(text, "GUILD")
end

function Bonds:SetAnnounce(on)
    ns.DB.char.announce = on
    ns.Print(on and "Adopsjoner og kallenavn kunngjøres i guild-chatten."
        or "Adopsjoner og kallenavn kunngjøres ikke lenger i guild-chatten.")
end

function Bonds:Pat()
    if ns.InCombat() then return ns.Print("Ikke nå, du er i kamp.") end
    local text = self:PatText()
    if not text then return ns.Print("Tilkall kjæledyret ditt, eller velg et kjæledyr som mål.") end
    SendChatMessage(text, "EMOTE")
end
