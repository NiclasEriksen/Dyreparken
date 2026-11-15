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
-- when it happened out of combat), rare, chance, traits / families (lines by nature, the first the pet has),
-- delay (Moments.DELAY's).
-- Pacing (the user's answer 2): common rows at most one line every 20 minutes (Moments' "react" budget,
-- char.reactAt), beside the eggs' 45; rare ones always. Each row once a day. Something done in a fight is said
-- after it. No line while another is on its way, an egg's either (Moments.lua).
-- Lines: Locale/nb.lua, react.<id>.N and react.<id>.<trait|family>.N.
---@class Dyreparken.Reactions
local Reactions = {}
ns.Reactions = Reactions

Reactions.CHANCE = 0.5 -- a common row's line, when its moment comes (once a day each)
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
    { id = "lommetyv", class = "ROGUE", on = "cast", spells = { "Pick Pocket" }, traits = { "roverdyr", "ordensdyr", "sjorover" } },
    { id = "lasedirk", class = "ROGUE", on = "cast", spells = { "Pick Lock" }, traits = { "sjorover", "oppdager" } },
    { id = "spurt", class = "ROGUE", on = "cast", spells = { "Sprint" }, calm = true, traits = { "hoppetass", "latsabb" } },
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
    { id = "inferno", class = "WARLOCK", on = "cast", spells = { "Inferno", "Ritual of Doom" }, rare = true, traits = { "balkos" } },
    -- Mage
    { id = "trylleskaffet", class = "MAGE", on = "cast", starts = { "Conjure Food", "Conjure Water" }, traits = { "glupsk" } },
    { id = "sau", class = "MAGE", on = "cast", starts = { "Polymorph" }, families = { "farm", "reptile", "rabbit" } },
    { id = "portal", class = "MAGE", on = "cast", starts = { "Teleport: ", "Portal: " }, traits = { "hjemlengsel", "reiseglad" } },
    { id = "fallskjerm", class = "MAGE", on = "cast", spells = { "Slow Fall" }, traits = { "skybaren" }, families = { "bird", "owl" } },
    -- Priest
    { id = "svev", class = "PRIEST", on = "cast", spells = { "Levitate" }, traits = { "skybaren", "hjemlengsel" } },
    { id = "skyggeform", class = "PRIEST", on = "cast", spells = { "Shadowform" }, traits = { "ordensdyr", "kjaelen" },
        families = { "spirit" } },
    { id = "indreild", class = "PRIEST", on = "cast", spells = { "Inner Fire" }, calm = true, traits = { "balkos", "vinterpels" } },
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
    { id = "kattedyr", class = "DRUID", on = "cast", spells = { "Cat Form" }, families = { "cat", "rodent", "bird", "frog" } },
    { id = "bjornemor", class = "DRUID", on = "cast", spells = { "Bear Form", "Dire Bear Form" }, families = { "bear" } },
    { id = "kjempeugle", class = "DRUID", on = "cast", spells = { "Moonkin Form" }, rare = true, traits = { "nattugle" },
        families = { "owl" } },
    { id = "moonglade", class = "DRUID", on = "cast", spells = { "Teleport: Moonglade" }, families = { "owl", "spirit" } },
    -- Shaman: totems; four kinds within TOTEM_SPAN are a whole garden, a row of its own (2026-11-14, in game: a
    -- garden inside the totems' row was lost to it, said already that day, six gardens in one evening). Common, not
    -- rare (the user, the same day: "Totem garden is not rare, I've gotten it twice in a short period").
    { id = "spokelsesulv", class = "SHAMAN", on = "cast", spells = { "Ghost Wolf" }, families = { "wolf", "rabbit", "farm" } },
    -- (in a fight too, said after it: a shaman drops them in fights, the garden most of all; seen 2026-11-14)
    { id = "totemhage", class = "SHAMAN", on = "cast", ends = { " Totem" }, test = function()
            local list = times.totem
            Within(list, Reactions.TOTEM_SPAN, 1)
            local kinds, n = {}, 0
            for _, x in ipairs(list) do
                if not kinds[x.name] then kinds[x.name] = true; n = n + 1 end
            end
            if n >= Reactions.TOTEMS then times.totem = {}; return {} end
        end },
    { id = "totemer", class = "SHAMAN", on = "cast", ends = { " Totem" }, traits = { "handverker" }, families = { "cat" } },
    { id = "astral", class = "SHAMAN", on = "cast", spells = { "Astral Recall" }, traits = { "hjemlengsel" } },
    -- (2026-11-15, from a shaman's evening in the log: the spells cast most with nothing to say; the heals left
    -- out, cast too often to stay fun)
    { id = "forfedre", class = "SHAMAN", on = "cast", spells = { "Ancestral Spirit" }, rare = true, traits = { "trofast" },
        families = { "spirit" } },
    { id = "renselse", class = "SHAMAN", on = "cast", spells = { "Purge" }, traits = { "skoyer", "rampete" } },
    -- Race: a row with a race and no class is every class's of that race (UnitRace's second, the client's
    -- English file name: Forever's undead are "Scourge", /dp probe sense 2026-11-15)
    { id = "krigsstamp", race = "Tauren", on = "cast", spells = { "War Stomp" }, traits = { "hoppetass" }, families = { "rabbit", "rodent" } },
}
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
    if type(name) ~= "string" then return false end
    for _, n in ipairs(row.spells or {}) do if name == n then return true end end
    for _, n in ipairs(row.starts or {}) do if name:sub(1, #n) == n then return true end end
    for _, n in ipairs(row.ends or {}) do if name:sub(-#n) == n then return true end end
    return false
end
Reactions.Named = Named

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
    if not rare and ns.random() >= (row.chance or self.CHANCE) then return "the roll" end
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
