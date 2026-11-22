---@class Dyreparken
local ns = select(2, ...)

-- Class reactions (docs/CLASS_INTERACTIONS.md; the first batch 2026-11-14, the user: "your own class: casts and
-- forms", all nine classes, the 3-4 best rows each). Your pet, out with you, reacts to what your class does: a
-- warrior's Battle Shout, a hunter's Feign Death, a mage's sheep. Flavor only, like Quirks' eggs, and read
-- from the sensors (Sense.lua): only those your class's rows need are wanted.
--
-- A row: id (permanent: char.reacts, a pet's story and the achievements to come count them), class or race, on (a
-- sensor), spells / starts / ends (a cast's or buff's name: exactly, or how it starts or ends; names, not ids:
-- Forever has ids of its own), test (fn(subject, row, key) -> vars or nil; vars._key a line of its own), calm (only
-- when it happened out of combat), rare, chance, traits / families (lines by nature, the first the pet has, mixed
-- with the general ones: Moments.ByNature), apart (natures whose lines always replace the general ones),
-- delay (Moments.DELAY's), everyone (a row for every character, no class or race: the faction rows), any (no name to
-- match: its test decides, on a glance or a zone).
-- Pacing (the user's answer 2): common rows at most one line every 20 minutes (Moments' "react" budget,
-- char.reactAt), beside the eggs' 45; rare ones always. Each row once a day, on a share of days (its chance,
-- rolled once a day: Moments.Rolled). Something done in a fight is said
-- after it. No line while another is on its way, an egg's either (Moments.lua).
-- Lines: Locale/nb.lua, react.<id>.N and react.<id>.<trait|family>.N.
---@class Dyreparken.Reactions
local Reactions = {}
ns.Reactions = Reactions

-- (0.5 until 2026-11-15: a shaman's few rows spoke on most days, the same lines; "Mye" makes it 0.6. Rolled at every
-- moment until 2026-11-19, when a 40% still had the totems on 6 of 6 days: rolled once a day now, Moments.Rolled)
Reactions.CHANCE = 0.2 -- a common row's share of days (its first moment of a day rolls; once a day each)
-- A rare row with another line on its way (an egg's, Moments): said anyway this often, else lost (2026-11-14, the
-- user: "rare should have a chance to skip the one at a time rule, but only some of the time").
Reactions.RARE_SKIP = 0.5
Reactions.STANCES, Reactions.STANCE_SPAN = 3, 10 -- a warrior's stance dance: this many changes within this many seconds
Reactions.BUBBLE_SPAN = 20 -- seconds from Divine Shield to the hearthstone's end (its cast takes 10)
Reactions.TOTEMS, Reactions.TOTEM_SPAN = 4, 30 -- a whole garden: four totems within this many seconds

local now = GetTime
-- What a row needs to remember a moment (this session): the times of a warrior's stances, a paladin's bubble.
local times = { stance = {}, totem = {} }
local quiet = {} -- row id -> the day its "said today" was logged
local function Within(list, span, n)
    local t = now()
    while list[1] and t - list[1].t > span do table.remove(list, 1) end
    return #list >= n
end

Reactions.ROWS = {
    -- Warrior
    { id = "krigsrop", class = "WARRIOR", on = "cast", spells = { "Battle Shout" }, calm = true,
        traits = { "latsabb", "pratsom", "kjaelen" } },
    { id = "stansdans", class = "WARRIOR", on = "cast", spells = { "Battle Stance", "Defensive Stance", "Berserker Stance" },
        traits = { "hoppetass", "latsabb" }, test = function()
            local list = times.stance
            list[#list + 1] = { t = now() }
            if Within(list, Reactions.STANCE_SPAN, Reactions.STANCES) then return {} end
        end },
    { id = "blodraseri", class = "WARRIOR", on = "cast", spells = { "Bloodrage" }, calm = true, traits = { "kjaelen", "trofast" } },
    -- Rogue
    { id = "lommetyv", class = "ROGUE", on = "cast", spells = { "Pick Pocket" }, traits = { "roverdyr", "ordensdyr", "sjorover" },
        apart = { "ordensdyr" } },
    { id = "lasedirk", class = "ROGUE", on = "cast", spells = { "Pick Lock" }, traits = { "sjorover", "oppdager" } },
    { id = "spurt", class = "ROGUE", on = "cast", spells = { "Sprint" }, calm = true, traits = { "hoppetass", "latsabb" }, apart = { "latsabb" } },
    -- Hunter
    { id = "spilldod", class = "HUNTER", on = "cast", spells = { "Feign Death" }, traits = { "trofast", "skoyer" } },
    { id = "mating", class = "HUNTER", on = "cast", spells = { "Feed Pet" }, traits = { "glupsk" } },
    { id = "sjalusi", class = "HUNTER", on = "cast", spells = { "Tame Beast" }, rare = true,
        traits = { "trofast", "kjaelen", "einstoing" } },
    { id = "gepard", class = "HUNTER", on = "cast", spells = { "Aspect of the Cheetah", "Aspect of the Pack" }, calm = true,
        traits = { "hoppetass", "latsabb" } },
    -- Warlock: the demon called names its own lines (a demon of our own family first)
    { id = "demonen", class = "WARLOCK", on = "cast", spells = { "Summon Imp", "Summon Voidwalker", "Summon Succubus", "Summon Felhunter" },
        families = { "demon" }, test = function(s, row, key)
            local nature = Reactions.ByNature(row, key)
            if nature._key then return nature end
            return { _key = "react.demonen." .. s.name:match("^Summon (%a+)$"):lower() }
        end },
    { id = "helsestein", class = "WARLOCK", on = "cast", starts = { "Create Healthstone" }, traits = { "glupsk" } },
    -- (inferno and forfedre were rare until 2026-11-22, the user: "common-ish", so they only have a chance now)
    { id = "inferno", class = "WARLOCK", on = "cast", spells = { "Inferno", "Ritual of Doom" }, traits = { "balkos" }, apart = { "balkos" } },
    -- Mage
    { id = "trylleskaffet", class = "MAGE", on = "cast", starts = { "Conjure Food", "Conjure Water" }, traits = { "glupsk" } },
    { id = "sau", class = "MAGE", on = "cast", starts = { "Polymorph" }, families = { "farm", "reptile", "rabbit" } },
    { id = "portal", class = "MAGE", on = "cast", starts = { "Teleport: ", "Portal: " }, traits = { "hjemlengsel", "reiseglad" } },
    { id = "fallskjerm", class = "MAGE", on = "cast", spells = { "Slow Fall" }, traits = { "skybaren" }, families = { "owl", "bird" } },
    -- Priest
    { id = "svev", class = "PRIEST", on = "cast", spells = { "Levitate" }, traits = { "skybaren", "hjemlengsel" } },
    { id = "skyggeform", class = "PRIEST", on = "cast", spells = { "Shadowform" }, traits = { "ordensdyr", "kjaelen" },
        families = { "spirit" } },
    { id = "indreild", class = "PRIEST", on = "cast", spells = { "Inner Fire" }, calm = true, traits = { "balkos", "vinterpels" },
        apart = { "vinterpels" } },
    -- Paladin: the bubble-hearth (Divine Shield, then a hearthstone that ends within BUBBLE_SPAN)
    { id = "boblehjem", class = "PALADIN", on = "cast", spells = { "Hearthstone" }, rare = true, traits = { "skoyer", "ordensdyr" },
        test = function(_, row, key)
            local at = times.bubble
            if at and now() - at <= Reactions.BUBBLE_SPAN then times.bubble = nil; return Reactions.ByNature(row, key) end
        end },
    -- (Forever's Horde paladins' mount may have a name of its own: /dp probe sense shows it)
    { id = "stridshest", class = "PALADIN", on = "cast", spells = { "Summon Warhorse", "Summon Charger" }, calm = true,
        families = { "farm" } },
    { id = "velsignet", class = "PALADIN", on = "buff", starts = { "Blessing of ", "Greater Blessing of " }, calm = true,
        traits = { "ordensdyr" } },
    -- Druid: the forms are casts as well
    { id = "kattedyr", class = "DRUID", on = "cast", spells = { "Cat Form" }, families = { "cat", "rodent", "bird", "frog" },
        apart = { "rodent", "bird", "frog" } },
    { id = "bjornemor", class = "DRUID", on = "cast", spells = { "Bear Form", "Dire Bear Form" }, families = { "bear" } },
    { id = "kjempeugle", class = "DRUID", on = "cast", spells = { "Moonkin Form" }, rare = true, traits = { "nattugle" },
        families = { "owl" } },
    { id = "moonglade", class = "DRUID", on = "cast", spells = { "Teleport: Moonglade" }, families = { "owl", "spirit" } },
    -- Shaman: totems; four kinds within TOTEM_SPAN are a whole garden, a row of its own (2026-11-14, in game: a
    -- garden inside the totems' row was lost to it, said already that day, six gardens in one evening). Common, not
    -- rare (the user, the same day: "Totem garden is not rare, I've gotten it twice in a short period").
    { id = "spokelsesulv", class = "SHAMAN", on = "cast", spells = { "Ghost Wolf" }, families = { "wolf", "rabbit", "farm" } },
    -- (in a fight too, said after it: a shaman drops them in fights, the garden most of all; seen 2026-11-14)
    -- (both lower still, 2026-11-19: a shaman drops totems all day, every day)
    { id = "totemhage", class = "SHAMAN", on = "cast", ends = { " Totem" }, chance = 0.15, test = function()
            local list = times.totem
            Within(list, Reactions.TOTEM_SPAN, 1)
            local kinds, n = {}, 0
            for _, x in ipairs(list) do
                if not kinds[x.name] then kinds[x.name] = true; n = n + 1 end
            end
            if n >= Reactions.TOTEMS then times.totem = {}; return {} end
        end },
    { id = "totemer", class = "SHAMAN", on = "cast", ends = { " Totem" }, chance = 0.15, traits = { "handverker" }, families = { "cat" } },
    { id = "astral", class = "SHAMAN", on = "cast", spells = { "Astral Recall" }, traits = { "hjemlengsel" } },
    -- (2026-11-15, from a shaman's evening in the log: the spells cast most with nothing to say; the heals left
    -- out, cast too often to stay fun)
    { id = "forfedre", class = "SHAMAN", on = "cast", spells = { "Ancestral Spirit" }, traits = { "trofast" },
        families = { "spirit" } },
    { id = "renselse", class = "SHAMAN", on = "cast", spells = { "Purge" }, traits = { "skoyer", "rampete" } },
    -- More for the classes that had three (2026-11-22, 0.10.0, the content review §2.1): classic spell names (Forever's
    -- are matched by name); each on Verify's list until seen.
    { id = "storm", class = "WARRIOR", on = "cast", spells = { "Charge" }, traits = { "hoppetass", "latsabb" }, apart = { "latsabb" } },
    { id = "brol", class = "WARRIOR", on = "cast", spells = { "Intimidating Shout" }, traits = { "kjaelen", "pratsom" } },
    { id = "skjoldmur", class = "WARRIOR", on = "cast", spells = { "Shield Wall" }, traits = { "trofast", "kosete" } },
    { id = "forsvinn", class = "ROGUE", on = "cast", spells = { "Vanish" }, traits = { "skoyer", "kjaelen" } },
    { id = "distraksjon", class = "ROGUE", on = "cast", spells = { "Distract" }, traits = { "rampete", "oppdager" } },
    { id = "sap", class = "ROGUE", on = "cast", spells = { "Sap" }, calm = true, traits = { "ordensdyr", "roverdyr" } },
    { id = "sjelestein", class = "WARLOCK", on = "cast", spells = { "Soulstone Resurrection" }, calm = true,
        traits = { "trofast", "hjemlengsel" } },
    { id = "kilrogg", class = "WARLOCK", on = "cast", spells = { "Eye of Kilrogg" }, calm = true, traits = { "oppdager", "kjaelen" } },
    { id = "innkalling", class = "WARLOCK", on = "cast", spells = { "Ritual of Summoning" }, calm = true,
        traits = { "flokkdyr", "einstoing" } },
    { id = "undervann", class = "WARLOCK", on = "cast", spells = { "Unending Breath" }, calm = true, traits = { "dykker", "vannhund" } },
    { id = "styrkeord", class = "PRIEST", on = "cast", spells = { "Power Word: Fortitude", "Prayer of Fortitude" }, calm = true,
        traits = { "steinhard", "latsabb" } },
    { id = "skrik", class = "PRIEST", on = "cast", spells = { "Psychic Scream" }, traits = { "kjaelen", "roverdyr" } },
    { id = "tankesyn", class = "PRIEST", on = "cast", spells = { "Mind Vision" }, calm = true, traits = { "oppdager", "nattugle" } },
    { id = "gjenoppliv", class = "PRIEST", on = "cast", spells = { "Resurrection" }, calm = true, traits = { "trofast" },
        families = { "spirit" } },
    { id = "hendene", class = "PALADIN", on = "cast", spells = { "Lay on Hands" }, traits = { "kjaelen", "trofast" } },
    { id = "forlosning", class = "PALADIN", on = "cast", spells = { "Redemption" }, calm = true, traits = { "trofast" },
        families = { "spirit" } },
    { id = "rettferd", class = "PALADIN", on = "cast", spells = { "Hammer of Justice" }, traits = { "ordensdyr", "skoyer" } },
    -- Race: a row with a race and no class is every class's of that race (UnitRace's second, the client's
    -- English file name: Forever's undead are "Scourge", /dp probe sense 2026-11-15)
    { id = "krigsstamp", race = "Tauren", on = "cast", spells = { "War Stomp" }, traits = { "hoppetass" }, families = { "rabbit", "rodent" } },
    -- Every race's (2026-11-22, 0.10.0, the content review §2.1): Forever's own racials from its tables (wago.tools,
    -- 1.60.1.71037, the racial skill lines), the classic ones and the new. A Tauren knows both (the API probe), so
    -- every race is taken to (the user: "I won't check every race either"): a row for a spell a race lacks, or a
    -- passive one, just never comes. Each is on Verify's list (react:<id>), ticked the first time it's said.
    { id = "skarpsyn", race = "Human", on = "cast", spells = { "Perception" }, traits = { "oppdager", "jeger" } },
    { id = "overleve", race = "Human", on = "cast", spells = { "Will to Survive" }, traits = { "trofast", "steinhard" } },
    { id = "steinform", race = "Dwarf", on = "cast", spells = { "Stoneform" }, traits = { "steinhard", "kjaelen" } },
    { id = "skattejakt", race = "Dwarf", on = "cast", spells = { "Find Treasure" }, calm = true, traits = { "sjorover", "oppdager" } },
    { id = "maanelys", race = "NightElf", on = "cast", spells = { "Elune's Light" }, traits = { "nattugle" } },
    { id = "fluktkunst", race = "Gnome", on = "cast", spells = { "Escape Artist" }, traits = { "skoyer", "hoppetass" } },
    { id = "eureka", race = "Gnome", on = "cast", spells = { "Eureka!" }, traits = { "handverker", "ambisios" },
        families = { "mechanical" } },
    { id = "blodrus", race = "Orc", on = "cast", spells = { "Blood Fury" }, traits = { "kosete", "roverdyr" } },
    { id = "forbannelse", race = "Orc", on = "cast", spells = { "Shatter Curse" }, traits = { "trofast" } },
    { id = "viljestyrke", race = "Scourge", on = "cast", spells = { "Will of the Forsaken" }, traits = { "steinhard" } },
    { id = "kannibal", race = "Scourge", on = "cast", spells = { "Cannibalize" }, calm = true, traits = { "glupsk", "kosete" },
        apart = { "glupsk" } },
    { id = "dyrking", race = "Tauren", on = "cast", spells = { "Cultivation" }, calm = true, traits = { "gronnfinger" },
        families = { "plant", "rabbit" } },
    { id = "slettelop", race = "Tauren", on = "cast", spells = { "Plainsrunning" }, traits = { "hoppetass", "latsabb" },
        apart = { "latsabb" } },
    { id = "berserk", race = "Troll", on = "cast", spells = { "Berserking" }, traits = { "rampete", "latsabb" } },
    { id = "lekning", race = "Troll", on = "cast", spells = { "Rapid Regeneration" }, traits = { "kjaelen" } },
    { id = "luftgang", race = "Skyborne", on = "cast", spells = { "Walk on Air" }, traits = { "skybaren", "hoppetass" },
        families = { "bird" } },
    { id = "himmelsyn", race = "Skyborne", on = "cast", spells = { "Skysight" }, traits = { "skybaren", "oppdager" } },
    { id = "leylinje", race = "Skyborne", on = "cast", spells = { "Read Leyline" }, calm = true, traits = { "handverker" },
        families = { "spirit" } },
    -- The factions (2026-11-22, 0.10.0, the content review §2.1, all four moments): a pet or a player of the other
    -- faction under the mouse (the player only in a neutral town: elsewhere they're everywhere), the other
    -- faction's capital, and your own after HOME_AWAY days or more away (char.homeAt). Who's the other faction:
    -- UnitFactionGroup, against your own. A companion's faction is unverified (its owner's, presumably): Verify.
    { id = "fiendedyr", everyone = true, any = true, on = "glance", calm = true, traits = { "diplomat", "roverdyr", "venneflokk" },
        test = function(s, row, key)
            if s.kind ~= "companion" or not Reactions.Other(s.faction) then return nil end
            return Reactions.ByNature(row, key)
        end },
    { id = "fremmed", everyone = true, any = true, on = "glance", calm = true, traits = { "diplomat", "einstoing", "pratsom" },
        test = function(s, row, key)
            if s.kind ~= "player" or not Reactions.Other(s.faction) or Reactions.PlaceNow() ~= "neutral" then return nil end
            return Reactions.ByNature(row, key)
        end },
    { id = "fiendeby", everyone = true, any = true, on = "zone", traits = { "eventyrlysten", "hjemlengsel", "ordensdyr", "diplomat" },
        apart = { "hjemlengsel" }, test = function(s, row, key)
            if s.place ~= "enemy" then return nil end
            return Reactions.ByNature(row, key)
        end },
    { id = "hjemby", everyone = true, any = true, on = "zone", traits = { "hjemlengsel", "reiseglad", "ordensdyr" },
        test = function(s, row, key)
            if s.place ~= "home" then return nil end
            local at = ns.DB.char.homeAt -- (set after the rows, OnSense: with a pet out or not)
            local away = at and ns.Now() - at
            if not (away and away >= Reactions.HOME_AWAY * 86400) then return nil end
            return Reactions.ByNature(row, key)
        end },
    -- The Darkmoon Faire (2026-11-22, 0.10.0, the content review §2.3: Holidays leaves it out, "too often", but a
    -- Tivolidyr pet gets its own moment there): you walk into the faire (its subzone, Reactions.FAIRE: unverified on
    -- Forever) on one of its days (the calendar, Holidays' "darkmoon"), with a Tivolidyr pet out. Once a day, always.
    { id = "tivoli", everyone = true, any = true, on = "zone", rare = true, test = function(s, row, key)
        if s.subzone ~= Reactions.FAIRE or not ns.Holidays:Has(ns.Now(), "darkmoon") then return nil end
        if not ns.Personality:Has(key, "tivolidyr") then return nil end
        return {}
    end },
}
Reactions.FAIRE = "Darkmoon Faire"
Reactions.HOME_AWAY = 3 -- days away from your own capitals before coming back is a moment (hjemby)

-- A faction that's the other one, not yours (nil, unknown, or a neutral one: no).
function Reactions.Other(faction)
    faction = ns.Plain(faction)
    local mine = ns.Plain(UnitFactionGroup("player"))
    return (faction == "Alliance" or faction == "Horde") and (mine == "Alliance" or mine == "Horde") and faction ~= mine
end
-- Where you are now, as Sense names a place (neutral: a goblin town).
function Reactions.PlaceNow()
    local _, instance = IsInInstance()
    return ns.Sense.Place(ns.Plain(GetZoneText()), ns.Plain(GetSubZoneText()), ns.Plain(instance))
end
local byId = {}
for _, r in ipairs(Reactions.ROWS) do
    assert(not byId[r.id], "Reactions.ROWS: two rows " .. r.id)
    assert(ns.Sense.SENSORS[r.on], "Reactions.ROWS: " .. r.id .. " on " .. tostring(r.on))
    for _, t in ipairs(r.traits or {}) do assert(ns.Personality.ById(t), "Reactions.ROWS: " .. r.id .. ": no trait " .. t) end
    byId[r.id] = r
end
function Reactions.ById(id) return byId[id] end

-- Whether a name is one of the row's.
local function Named(row, name)
    if row.any then return true end
    if type(name) ~= "string" then return false end
    for _, n in ipairs(row.spells or {}) do if name == n then return true end end
    for _, n in ipairs(row.starts or {}) do if name:sub(1, #n) == n then return true end end
    for _, n in ipairs(row.ends or {}) do if name:sub(-#n) == n then return true end end
    return false
end

-- Lines by nature: the first of the row's traits the pet has with lines, then its families', else the plain.
function Reactions.ByNature(row, key) return ns.Moments.ByNature("react", row, key) end

function Reactions:Ready() return ns.Moments:Ready("react") end

-- The row's line, said a moment later (after the fight, if in one); what it uses up is saved as it's said.
function Reactions:Say(row, key, text, rare)
    ns.Moments:Say({ text = text, key = key, why = ("react %s %s"):format(row.id, key), id = "react:" .. row.id,
        delay = row.delay or "now",
        budget = not rare and "react" or nil, afterFight = true, said = function()
            local got = ns.Moments.Count(ns.DB.char.reacts, row.id, key, text, "react:" .. row.id) -- (the day it's said)
            if got.n == 1 then ns.Bus:Fire("REACT_FOUND", row.id) end
        end })
end

-- Why a row's moment said nothing, or nil when it speaks (the log says which: 2026-11-14, a Ghost Wolf
-- that never spoke couldn't be told from bad luck).
function Reactions:Try(row, s, key)
    if row.calm and s.combat then return "in a fight" end
    if not key then return "no pet out" end
    if ns.Moments.SaidToday(ns.DB.char.reacts, row.id) then return "said today" end
    if ns.Moments:Queued("react:" .. row.id) then return "on its way already" end
    local vars
    if row.test then vars = row.test(s, row, key) else vars = self.ByNature(row, key) end
    if not vars then return "not its moment" end
    return self:Speak(row, key, vars)
end

-- What's left once the moment is the row's: the line on its way (then its turn after it: Moments:Later), the
-- budget, the roll (with another line on its way: after it, Moments:Later; a rare one sometimes at once,
-- RARE_SKIP). Why not, or nil when it speaks.
function Reactions:Speak(row, key, vars, again)
    local rare = row.rare
    local M = ns.Moments
    if again and (M.SaidToday(ns.DB.char.reacts, row.id) or M:Queued("react:" .. row.id)) then return "said today" end
    if M:Pending() and not (rare and ns.random() < self.RARE_SKIP) then
        if not again and (rare or M:Left("react") == 0) then
            M:Later("react:" .. row.id, function()
                local why = Reactions:Speak(row, key, vars, true)
                if why then ns.Log("Reactions", "%s, its turn: %s", row.id, why) end
            end)
        end
        return "a line on its way"
    end
    if not (rare or self:Ready()) then return "the 20 minutes" end
    -- (a rare one counts, as an egg: only "few" rolls for it, at its half)
    local chance = rare and ns.Settings:Chance(1, "egg") or ns.Settings:Chance(row.chance or self.CHANCE, "flavor")
    if not ns.Moments.Rolled("react:" .. row.id, chance) then return "not today (the day's roll)" end
    local text = ns.PickLine(vars._key or ("react." .. row.id), setmetatable({ pet = ns.Registry:NameOf(key) }, { __index = vars }))
    if not text then return "no line" end
    self:Say(row, key, text, rare)
end

-- A sensor saw something: the rows of your class on it, with your pet out.
function Reactions:OnSense(kind, s)
    if kind == "cast" and s.name == "Divine Shield" then times.bubble = now() end
    if kind == "cast" and type(s.name) == "string" and s.name:sub(-6) == " Totem" then
        times.totem[#times.totem + 1] = { t = now(), name = s.name }
        Within(times.totem, Reactions.TOTEM_SPAN, 1) -- (trimmed here too: the garden's test may not run)
    end
    local key = ns.Pets:OutKey()
    for _, row in ipairs(self.mine or {}) do
        if row.on == kind and Named(row, s.name) then
            local why = self:Try(row, s, key)
            -- ("said today" once a row a day: every totem after the first wrote it twice, 2026-11-15)
            if why == "said today" then
                if quiet[row.id] == ns.Today() then why = nil else quiet[row.id] = ns.Today() end
            end
            if why then ns.Log("Reactions", "%s: %s (%s)", row.id, why, tostring(s.name)) end
        end
    end
    if kind == "zone" and s.place == "home" then ns.DB.char.homeAt = ns.Now() end
end

-- Your class's rows, and the sensors they need (wanted for good: the ones that cost nothing until used).
function Reactions:Watch()
    local class = ns.Plain(select(2, UnitClass("player")))
    local race = ns.Plain(select(2, UnitRace("player")))
    self.mine = {}
    local want = {}
    for _, row in ipairs(self.ROWS) do
        if (row.class == nil or row.class == class) and (row.race == nil or row.race == race) then
            self.mine[#self.mine + 1] = row
            want[row.on] = true
        end
    end
    for _, kind in ipairs(ns.Sense.KINDS) do
        if want[kind] then ns.Sense:Want(kind, Reactions) else ns.Sense:Drop(kind, Reactions) end
    end
end

ns.Start("login", function()
    ns.Bus:On("SENSE", function(kind, s) Reactions:OnSense(kind, s) end)
    Reactions:Watch()
end)
