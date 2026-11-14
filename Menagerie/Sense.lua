local _, ns = ...

-- Sensors (docs/CLASS_INTERACTIONS.md, part 1; built 2026-11-14, the user: "start building the sensors for
-- the class interactions"): moments that each describe what happened as a small table, the subject, for the
-- class, race and faction reactions to match (Sense.Match). Nothing reacts yet.
--
--   glance  a unit under the mouse, out of combat: kind (player, companion, pet: a hunter's, demon: a
--           warlock's, totem, critter, npc), guid, npc, name, class/race (file names), faction, reaction,
--           enemy, pvp, family/familyId (UnitCreatureFamily) and families (ours: Data/Creatures.lua),
--           type (UnitCreatureType's id: 1 beast ... 8 critter, 11 totem), classif, level, owner (a pet's,
--           a demon's or a companion's, from its tooltip line), species (a companion's), key (a player's)
--   cast    your own spell cast: id, name, combat (casts read plain in combat, /dp probe api glance)
--   form    your shapeshift form changed: id (GetShapeshiftFormID; nil out of a form), was
--   buff    a buff you gained: name, id (none while auras are secret)
--   pet     your combat pet came or went: out, name, family, familyId, families, type
--   group   your group changed: members { key, class, race, pet (family id), petFamilies }, raid
--   flag    your PvP flag went on or off: on
--   zone    a new zone or subzone: zone, subzone, instance (IsInInstance's kind), place (home / enemy: a
--           faction's capital, neutral: a goblin town, battleground), was (the zone before)
--   emote   someone's emote you saw: from (a key), class, race (from their GUID), text, me (at you)
--
-- DORMANT unless wanted (Sense:Want(kind, owner) / :Drop): a sensor's events are registered only while some
-- consumer wants it, and the glance's tooltip post-call returns at once. Each fires Bus "SENSE" (kind, subject).
-- What's secret (a unit in combat: no GUID, its name secret; auras in combat) gives no subject at all.
local Sense = {}
ns.Sense = Sense
local Plain = ns.Plain

Sense.GLANCE_AGAIN = 600 -- seconds before the same unit under the mouse is a glance again
-- Capitals by faction, and the goblins' neutral towns (subzones), for the zone's place.
Sense.CAPITALS = { ["Stormwind City"] = "Alliance", ["Ironforge"] = "Alliance", ["Darnassus"] = "Alliance",
    ["Orgrimmar"] = "Horde", ["Thunder Bluff"] = "Horde", ["Undercity"] = "Horde" }
Sense.NEUTRAL = { ["Booty Bay"] = true, ["Gadgetzan"] = true, ["Ratchet"] = true, ["Everlook"] = true,
    ["Steamwheedle Port"] = true }
Sense.TYPE = { beast = 1, demon = 3, critter = 8, totem = 11 } -- (UnitCreatureType's ids)

-- A value from the client, or nil if the call is missing, fails or is secret. All its values plain.
local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    for i = 2, table.maxn(r) do r[i] = Plain(r[i]) end
    return unpack(r, 2, table.maxn(r))
end
local function Families(id) return id and ns.Creatures.families[id] or nil end

------------------------------------------------------------------------------
-- Matching (part 1.2): a reaction's row says what it wants of the subject, field by field: a value, a set
-- (a list: any of them), true (present at all) or false (absent, or false). Pure.
------------------------------------------------------------------------------
local function Is(have, want)
    if want == true then return have ~= nil and have ~= false end
    if want == false then return have == nil or have == false end
    if type(want) == "table" then
        for _, v in ipairs(want) do
            if type(have) == "table" then
                for _, h in ipairs(have) do if h == v then return true end end
            elseif have == v then
                return true
            end
        end
        return false
    end
    if type(have) == "table" then
        for _, h in ipairs(have) do if h == want then return true end end
        return false
    end
    return have == want
end
function Sense.Match(subject, match)
    if type(subject) ~= "table" then return false end
    for field, want in pairs(match or {}) do
        if not Is(subject[field], want) then return false end
    end
    return true
end

------------------------------------------------------------------------------
-- Reading the world.
------------------------------------------------------------------------------
-- The owner on a pet's, a demon's or a companion's tooltip line ("Kari Berg's Pet"), with the client's own
-- strings; and which it is.
local OWNED = { { "UNITNAME_TITLE_PET", "%s's Pet", "pet" }, { "UNITNAME_TITLE_MINION", "%s's Minion", "demon" },
    { "UNITNAME_TITLE_COMPANION", "%s's Companion", "companion" } }
function Sense.Owner(lines)
    if type(lines) ~= "table" then return nil end
    for i = 2, 3 do
        local text = type(lines[i]) == "table" and Plain(lines[i].leftText)
        if type(text) == "string" then
            for _, o in ipairs(OWNED) do
                local pattern = ns.Activity.FormatPattern(_G[o[1]] or o[2])
                local who = pattern and text:match(pattern)
                if who then return ns.NormalizeName(who), o[3] end
            end
        end
    end
end

-- What a unit is, or nil while it can't be read (in combat, secret).
function Sense.Glance(unit, lines)
    if ns.InCombat() then return nil end
    if C_Secrets and Read(C_Secrets.ShouldUnitIdentityBeSecret, unit) == true then return nil end
    local guid = Read(UnitGUID, unit)
    if type(guid) ~= "string" then return nil end
    local s = { guid = guid, name = (Read(UnitName, unit)), level = Read(UnitLevel, unit),
        faction = (Read(UnitFactionGroup, unit)), reaction = Read(UnitReaction, "player", unit),
        enemy = Read(UnitIsEnemy, "player", unit) == true, pvp = Read(UnitIsPVP, unit) == true,
        classif = Read(UnitClassification, unit) }
    s.npc = tonumber(guid:match("^%a+%-%d+%-%d+%-%d+%-%d+%-(%d+)%-"))
    local _, typeId = Read(UnitCreatureType, unit)
    s.type = typeId
    local _, familyId = Read(UnitCreatureFamily, unit)
    s.family, s.familyId = (Read(UnitCreatureFamily, unit)), familyId
    s.families = Families(familyId)
    local owner, how = Sense.Owner(lines)
    if Read(UnitIsPlayer, unit) == true then
        s.kind = "player"
        s.class = select(2, Read(UnitClass, unit))
        s.race = select(2, Read(UnitRace, unit))
        s.key = ns.UnitKey(unit)
    elseif Read(UnitIsBattlePetCompanion, unit) == true then
        s.kind, s.species, s.owner = "companion", Read(UnitBattlePetSpeciesID, unit), ns.Tooltip:OwnerOf(unit, lines)
    elseif guid:find("^Pet%-") then
        s.kind, s.owner = (how == "demon" or typeId == Sense.TYPE.demon) and "demon" or "pet", owner
    elseif typeId == Sense.TYPE.totem then
        s.kind, s.owner = "totem", owner
    elseif typeId == Sense.TYPE.critter then
        s.kind = "critter"
    else
        s.kind = "npc"
    end
    return s
end

-- Your group's members (not you), and their pets' families.
function Sense.Group()
    local raid = Read(IsInRaid) == true
    local members = {}
    if not (raid or Read(IsInGroup) == true) then return members, raid end
    local me = ns.PlayerKey()
    for i = 1, raid and 40 or 4 do
        local unit = (raid and "raid" or "party") .. i
        if Read(UnitExists, unit) == true then
            local key = ns.UnitKey(unit)
            if key ~= me then
                local petUnit = (raid and "raidpet" or "partypet") .. i
                local _, pet = Read(UnitCreatureFamily, petUnit)
                members[#members + 1] = { key = key, class = select(2, Read(UnitClass, unit)),
                    race = select(2, Read(UnitRace, unit)), pet = pet, petFamilies = Families(pet) }
            end
        end
    end
    return members, raid
end

-- The zone as a place: home or enemy (a capital), neutral (a goblin town), battleground; nil elsewhere.
function Sense.Place(zone, subzone, instance)
    if instance == "pvp" then return "battleground" end
    local capital = Sense.CAPITALS[zone]
    if capital then return capital == Read(UnitFactionGroup, "player") and "home" or "enemy" end
    if Sense.NEUTRAL[subzone] or Sense.NEUTRAL[zone] then return "neutral" end
end

------------------------------------------------------------------------------
-- The sensors: their events (registered only while wanted), what each starts from, and the subject.
------------------------------------------------------------------------------
local function Fire(kind, s)
    ns.Log("Sense", "%s %s", kind, Sense.Show(s))
    ns.Bus:Fire("SENSE", kind, s)
end
-- A subject as one line, for the log.
function Sense.Show(s)
    local keys = {}
    for k in pairs(s) do keys[#keys + 1] = k end
    table.sort(keys)
    local parts = {}
    for _, k in ipairs(keys) do
        local v = s[k]
        if type(v) == "table" then
            local items = {}
            for _, x in ipairs(v) do items[#items + 1] = type(x) == "table" and (x.key or "?") or tostring(x) end
            v = "{" .. table.concat(items, ",") .. "}"
        end
        parts[#parts + 1] = k .. "=" .. tostring(v)
    end
    return table.concat(parts, " ")
end

local last = {} -- what each sensor last saw (its change is the moment)
local seen = {} -- glance: guid -> GetTime()
Sense.SENSORS = {
    glance = {}, -- (the tooltip post-call, below)
    cast = { events = { "UNIT_SPELLCAST_SUCCEEDED" }, on = function(_, unit, _, id)
        if unit ~= "player" then return end
        id = Plain(id)
        if type(id) ~= "number" then return end
        Fire("cast", { id = id, name = ns.SpellName(id), combat = ns.InCombat() })
    end },
    form = { events = { "UPDATE_SHAPESHIFT_FORM" },
        start = function() last.form = Read(GetShapeshiftFormID) end,
        on = function()
            -- (it fires with no change too: a cast, fishing)
            local id = Read(GetShapeshiftFormID)
            if id == last.form then return end
            local was = last.form
            last.form = id
            Fire("form", { id = id, was = was })
        end },
    buff = { events = { "UNIT_AURA" }, on = function(_, unit, info)
        if unit ~= "player" or type(info) ~= "table" then return end
        if issecretvalue and issecretvalue(info) or issecrettable and issecrettable(info) then return end
        local added = info.addedAuras
        if type(added) ~= "table" or issecrettable and issecrettable(added) then return end
        for _, aura in ipairs(added) do
            local name, id = type(aura) == "table" and Plain(aura.name), type(aura) == "table" and Plain(aura.spellId)
            if type(name) == "string" and Plain(aura.isHelpful) ~= false then Fire("buff", { name = name, id = id }) end
        end
    end },
    pet = { events = { "UNIT_PET" },
        start = function() last.pet = Read(UnitGUID, "pet") or false end,
        on = function(_, unit)
            if unit ~= "player" then return end
            local guid = Read(UnitExists, "pet") == true and Read(UnitGUID, "pet") or false
            if guid == last.pet then return end
            last.pet = guid
            if not guid then return Fire("pet", { out = false }) end
            local _, family = Read(UnitCreatureFamily, "pet")
            local _, typeId = Read(UnitCreatureType, "pet")
            Fire("pet", { out = true, name = (Read(UnitName, "pet")), family = (Read(UnitCreatureFamily, "pet")),
                familyId = family, families = Families(family), type = typeId })
        end },
    group = { events = { "GROUP_ROSTER_UPDATE" },
        start = function() last.group = nil end,
        on = function()
            if ns.InCombat() then return end -- (names can be secret in combat; the roster comes again)
            local members, raid = Sense.Group()
            local sig = {}
            for _, m in ipairs(members) do sig[#sig + 1] = ("%s/%s/%s"):format(tostring(m.key), tostring(m.class), tostring(m.pet)) end
            table.sort(sig)
            sig = table.concat(sig, ";")
            if sig == last.group then return end
            last.group = sig
            Fire("group", { members = members, raid = raid })
        end },
    flag = { events = { "PLAYER_FLAGS_CHANGED", "UNIT_FACTION" },
        start = function() last.flag = Read(UnitIsPVP, "player") == true end,
        on = function(_, unit)
            if unit ~= "player" then return end
            local on = Read(UnitIsPVP, "player") == true
            if on == last.flag then return end
            last.flag = on
            Fire("flag", { on = on })
        end },
    zone = { events = { "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED" },
        start = function() last.zone, last.subzone = Read(GetZoneText), Read(GetSubZoneText) end,
        on = function()
            local zone, subzone = Read(GetZoneText), Read(GetSubZoneText)
            if zone == last.zone and subzone == last.subzone then return end
            local was = last.zone
            last.zone, last.subzone = zone, subzone
            local _, instance = Read(IsInInstance)
            Fire("zone", { zone = zone, subzone = subzone ~= "" and subzone or nil, instance = instance,
                place = Sense.Place(zone, subzone, instance), was = was ~= zone and was or nil })
        end },
    emote = { events = { "CHAT_MSG_TEXT_EMOTE" }, on = function(_, text, sender, ...)
        text, sender = Plain(text), Plain(sender)
        if type(text) ~= "string" or type(sender) ~= "string" then return end
        local from = ns.NormalizeName(sender)
        if from == ns.PlayerKey() or from == Read(UnitName, "player") then return end
        local guid = Plain((select(10, ...)))
        local _, class, _, race = Read(GetPlayerInfoByGUID, guid)
        -- (enUS, as Forever's client is: "Kari bows before you.")
        Fire("emote", { from = from, class = class, race = race, text = text, me = text:find("%f[%a]you%f[%A]") ~= nil })
    end },
}
Sense.KINDS = { "glance", "cast", "form", "buff", "pet", "group", "flag", "zone", "emote" }

local wanted = {} -- kind -> { [owner] = true }
local owners = {} -- kind -> our ns.Events owner key
function Sense:Wants(kind) return wanted[kind] ~= nil and next(wanted[kind]) ~= nil end

local function Update(kind)
    local s = Sense.SENSORS[kind]
    owners[kind] = owners[kind] or {}
    local on = Sense:Wants(kind)
    for _, e in ipairs(s.events or {}) do
        if on and not ns.Events:Has(e, owners[kind]) then
            ns.Events:On(e, owners[kind], function(_, event, ...) s.on(event, ...) end)
        elseif not on then
            ns.Events:Off(e, owners[kind])
        end
    end
end
function Sense:Want(kind, owner)
    assert(self.SENSORS[kind], "Sense:Want: no sensor " .. tostring(kind))
    local was = self:Wants(kind)
    wanted[kind] = wanted[kind] or {}
    wanted[kind][owner] = true
    if not was and self.SENSORS[kind].start then self.SENSORS[kind].start() end
    Update(kind)
end
function Sense:Drop(kind, owner)
    if wanted[kind] then wanted[kind][owner] = nil end
    if self.SENSORS[kind] then Update(kind) end
end
-- Whether a sensor's events are registered now (for the tests: dormant unless wanted).
function Sense:Listening(kind)
    for _, e in ipairs(self.SENSORS[kind].events or {}) do
        if owners[kind] and ns.Events:Has(e, owners[kind]) then return true end
    end
    return false
end

-- The glance: the unit tooltip's post-call (Tooltip.lua has its own), which costs one check while unwanted.
local function OnUnitTooltip(tooltip, data)
    if not Sense:Wants("glance") or tooltip ~= GameTooltip then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    unit = ok and Plain(unit)
    if not unit then return end
    local s = Sense.Glance(unit, data and data.lines)
    if not s or (seen[s.guid] and GetTime() - seen[s.guid] < Sense.GLANCE_AGAIN) then return end
    seen[s.guid] = GetTime()
    Fire("glance", s)
end

ns.Start("login", function()
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, OnUnitTooltip)
    end
end)
