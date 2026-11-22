---@class Dyreparken
local ns = select(2, ...)

-- /dp probe verify: one checklist of everything still unconfirmed in game (2026-11-20, the user: "go through all
-- our unconfirmed interactions / eggs ... a single large probe, so we can ensure the addon is working
-- correctly"; and what could become a new interaction). Play as usual with it on: each item ticks itself the first
-- time it happens, a chat line says so, and the ticks are kept account-wide across sessions and characters
-- (DyreparkenDebugDB.verify), so the list only shrinks.
--
-- How an item ticks:
--   log     a line the debug log writes anyway (Debug.tap: every line written, a release leaves it nil): an
--           activity counted ("dance +1 ..."), an egg's moment rolled or said, a reaction sensed (even one held
--           back by its day's roll: the sensor worked), a ride's route, a meal's buff name
--   event   a game event the probe listens to itself while on (API questions: PLAYER_CONTROL_GAINED, a RESIST)
--   now     an answer read on the spot (an achievement by its id alone, the calendar's clock)
--   ok      by hand, for what only eyes can judge: /dp probe verify ok <id>
--   before  an activity, egg or reaction this character's saved counters have already: done, nothing to do
-- Areas: activity, egg, react (your class's and race's), api, zone (Data/Zones' names as GetZoneText gives
-- them), route (Voyage's), look (by hand), new (events that might become interactions: their first payloads).
-- Nothing here changes what the addon does: it only listens and writes to the debug log (on while it runs).
---@class Dyreparken.Verify
local Verify = {}
ns.Verify = Verify

local Plain = ns.Plain
Verify.ITEMS, Verify.BY = {}, {}
Verify.AREAS = { "activity", "api", "react", "egg", "zone", "route", "look", "new" }
Verify.KEEP = 12 -- details kept for an item that collects (interaction types, unknown zone names)
Verify.CAMP_GAIN = 3 -- seconds after a fire's countdown ends: the buffs that came then (api:campgain)
Verify.INN_AFTER = 70 -- seconds: resting that long with no sleeping bag's Well-Rested is an inn or a city
Verify.MOUNT_AFTER = 3 -- seconds: mounted that long and not on a taxi is a mount of your own
local innT, mountT = ns.Timers(), ns.Timers()

local function Item(t)
    assert(not Verify.BY[t.id], "Verify: two items " .. t.id)
    Verify.ITEMS[#Verify.ITEMS + 1] = t
    Verify.BY[t.id] = t
    return t
end
local function Esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- What to do for each activity, English (developer output). 49_content-like: 72_verify asks for one per kind.
Verify.HOW = {
    day = "log in with a pet out", boss = "kill a boss", quest = "turn in a quest", taxi = "take a flight path",
    pvp = "get an honorable kill", herb = "pick a herb", mine = "mine a vein", fish = "catch a fish",
    skin = "skin a beast", explore = "take your pet to a zone it hasn't been", skill = "get a skill-up",
    rep = "gain reputation", dance = "/dance", cuddle = "click your pet on its card", chat = "talk in guild chat",
    dive = "swim down until the breath bar shows", level = "gain a level", revive = "die and come back",
    nap = "go /afk for a while", hearth = "use your hearthstone (or Astral Recall)", jump = "jump (counts every 10)",
    roll = "/roll a 1", hundred = "/roll a 100", epic = "loot an epic", fishfail = "let two fish in a row get away",
    duelwon = "win a duel", duellost = "lose a duel", duel = "fight a duel", newpath = "learn a new flight path",
    campnear = "stand near a campfire", campwarm = "sit at a Welcoming Campfire", camp = "stay a minute at one",
    campviolet = "sit at a fire with Violet Flames powder on it",
    rested = "sleep in a sleeping bag (Well-Rested)", gold = "loot money", fun = "a silly emote (/silly, /chicken)",
    sneak = "go into stealth (rogue, druid, night elf's Shadowmeld)", meet = "hover another player's companion",
    dmgtop = "top damage at a boss kill in a group of 3+", healtop = "top healing at a raid boss kill",
    kicktop = "most interrupts at a boss kill in a group", fall = "fall hard out of combat",
    zeppelin = "ride a zeppelin", boat = "ride a boat",
    rain = "be outdoors when rain starts", snow = "be outdoors when snow starts", sand = "be outdoors when a sandstorm starts",
    feat = "a class quest's reward, learning to ride, or level 60", train = "learn spells at a trainer",
    specswap = "switch your dual spec", respec = "reset your talents",
    wake = "come back from /afk with the pet frame on", guildgroup = "group with a guildmate",
    guildpet = "hover a guildmate's companion", playmate = "a playdate: group with a guildmate whose pet is out",
    patted = "a guildmate does /klapp at your pet", errand = "open a bank, mailbox or auction house",
    eat = "eat or drink", dungeon = "walk into a dungeon", misses = "miss (dodge, parry) several swings in a row",
    resisted = "have several spells in a row fully resisted", wipe = "your whole group dies at a boss",
    routed = "die in a battleground with most of your team dead",
}

---------------------------------------------------------------------------
-- The items
---------------------------------------------------------------------------
local function Build()
    local char = ns.DB.char
    for _, k in ipairs(ns.Activity.KINDS) do
        local id = k[1]
        Item({ id = "activity:" .. id, area = "activity", how = Verify.HOW[id] or "?",
            logs = { { "Activity", "^" .. Esc(id) .. " %+%d" } },
            before = function() local c = char.activity[id]; return c and (c.total or 0) > 0 end })
    end
    for _, e in ipairs(ns.Quirks.EGGS) do
        local how = e.on == "day" and "comes by itself on its day or date"
            or e.on == "*" and "any moment, at its time"
            or Verify.HOW[e.on] and ("with " .. e.on .. ": " .. Verify.HOW[e.on])
            or ("on " .. tostring(e.on))
        Item({ id = "egg:" .. e.id, area = "egg", how = how,
            logs = { { "Moments", "^egg:" .. Esc(e.id) .. "[: ]" }, { "Chat", "^egg%." .. Esc(e.id) .. "%." },
                { "Quirks", "^egg " .. Esc(e.id) .. ":" } },
            before = function() return char.eggs[e.id] ~= nil end })
    end
    local _, class = UnitClass("player")
    local _, race = UnitRace("player")
    for _, r in ipairs(ns.Reactions.ROWS) do
        if (r.class and r.class == class) or (r.race and r.race == race) then
            Item({ id = "react:" .. r.id, area = "react",
                how = r.spells and ("cast " .. table.concat(r.spells, " or ")) or ("its moment: " .. tostring(r.on)),
                logs = { { "Reactions", "^" .. Esc(r.id) .. "[:,]" }, { "Chat", "^react%." .. Esc(r.id) .. "%." } },
                before = function() return char.reacts[r.id] ~= nil end })
        end
    end
    for name, row in pairs(ns.Zones.rows) do
        -- (a goblin town is a subzone: GetSubZoneText names it, review 2026-11-21)
        Item({ id = "zone:" .. name, area = "zone", how = "go to " .. name, zone = name, sub = row.neutral or nil })
    end
    for kind, list in pairs(ns.Voyage.ROUTES) do
        for _, r in ipairs(list) do
            local a, b = r[1], r[2]
            local function Way(x, y)
                return { "Voyage", "^" .. kind .. ": " .. Esc(x) .. " at .* %-> " .. (y == "*" and "" or Esc(y) .. " at") }
            end
            local logs = { Way(a, b) }
            if b ~= "*" then logs[2] = Way(b, a) else logs[2] = { "Voyage", "^" .. kind .. ": .* %-> " .. Esc(a) .. " at" } end
            Item({ id = ("route:%s:%s-%s"):format(kind, a, b), area = "route",
                how = ("the %s between %s and %s"):format(kind, a, b == "*" and "anywhere" or b), logs = logs })
        end
    end
    -- The API's open questions (docs/FOREVER_API.md, the code's "unverified" comments).
    local explored = {}
    for _, g in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
        local p = ns.Activity.FormatPattern(rawget(_G, g))
        if p then explored[#explored + 1] = p end
    end
    local function Discovered(event, ...)
        local text = Plain(event == "UI_INFO_MESSAGE" and select(2, ...) or (...))
        if type(text) ~= "string" then return end
        for _, p in ipairs(explored) do if text:match(p) then return event .. ": " .. text end end
    end
    local api = {
        -- (a landing only: control comes back after a stun or a fear too, review 2026-11-21; at the landing
        -- UnitOnTaxi is still true, docs/FOREVER_API.md)
        { "control", "land from a flight path", events = { "PLAYER_CONTROL_GAINED" },
            seen = function() if Plain(UnitOnTaxi("player")) == true then return "landed, on a taxi: true" end end },
        { "discovered", "discover a new subzone (the yellow \"Discovered\" line)",
            events = { "UI_INFO_MESSAGE", "CHAT_MSG_SYSTEM" }, seen = Discovered },
        { "resist", "cast at a target until one spell is fully resisted", events = { "UNIT_COMBAT" }, unit = "target",
            seen = function(_, _, action) if Plain(action) == "RESIST" then return "RESIST" end end },
        { "raid", "walk into a raid", events = { "PLAYER_ENTERING_WORLD" },
            seen = function()
                local yes, kind = IsInInstance()
                if Plain(yes) == true and Plain(kind) == "raid" then return tostring(Plain(GetZoneText())) end
            end },
        -- (2026-11-20, the user: a fire's buff renews itself while you sit; renewing one with under 45 minutes left
        -- is a new fire; its bonuses, and maybe its name, come from what's around the camp.)
        { "camprenew", "sit at a fire with under 45 minutes left on Camp Benefits (a new fire, its buff renewed)",
            logs = { { "Aura", "^camp renewed" } } },
        { "campbuffs", "Camp Benefits at different camps: its name, spell id and length each time",
            logs = { { "Aura", "^camp on" }, { "Aura", "^camp renewed" } }, collect = true },
        -- (2026-11-20, from the log: a countdown at a fire outside Thunder Bluff ended with no Camp Benefits after it, as far as
        -- its name tells; whatever came then is kept, whatever it's called.)
        { "campgain", "sit a minute at a fire: the buffs that come as its countdown ends (any name)",
            events = { "UNIT_AURA" }, unit = "player", collect = true,
            seen = function(_, _, info)
                if not (Verify.campEnd and GetTime() - Verify.campEnd <= Verify.CAMP_GAIN) then return end
                local added = type(info) == "table" and Plain(info.addedAuras)
                if type(added) ~= "table" then return end
                local list = {}
                for _, a in ipairs(added) do
                    local name, id, d = Plain(a.name), Plain(a.spellId), Plain(a.duration)
                    list[#list + 1] = ("%s %s (%s s)"):format(tostring(name), tostring(id), tostring(d))
                end
                if #list > 0 then return table.concat(list, ", ") end
            end },
        { "newpet", "learn a new companion", events = { "NEW_PET_ADDED" },
            seen = function(_, guid) return "guid " .. tostring(Plain(guid)) end },
        { "foodanddrink", "eat or drink something that gives \"Food & Drink\"",
            logs = { { "Activity", "^eat: Food & Drink is spell" } } },
        { "refreshment", "eat a mage's conjured food (\"Refreshment\")", logs = { { "Activity", "^eat: Refreshment is spell" } } },
        { "nodewords", "with a gathering wish today, hover a herb, a vein or a skinnable corpse",
            logs = { { "Wish", "^hovered: .*%(herb%)$" }, { "Wish", "^hovered: .*%(mine%)$" },
                { "Wish", "^hovered: .*%(skin%)$" } } },
        { "explorewish", "fulfil an explore wish", logs = { { "Wish", "^explore wish by" } } },
        { "moonglade", "Teleport: Moonglade", class = "DRUID", logs = { { "Activity", "^hearth %+%d.* 18960$" },
            { "Activity", "^hearth %+%d.* Teleport: Moonglade$" } } },
        { "achbyid", "(read now) an achievement by its id alone, GetAchievementInfo(62353)",
            now = function()
                local ok, _, name = pcall(GetAchievementInfo, 62353)
                name = ok and Plain(name)
                if type(name) == "string" and name ~= "" then return true, name end
                return false, ok and "no name" or "error"
            end },
        { "hiddenname", "(read now) a hidden species' name, GetPetInfoBySpeciesID(5179) (Azurky)",
            now = function()
                local ok, name = pcall(C_PetJournal.GetPetInfoBySpeciesID, 5179)
                name = ok and Plain(name)
                if type(name) == "string" and name ~= "" then return true, name end
                return false, ok and "no name" or "error"
            end },
        -- For 0.10.0 (2026-11-22): weather, a clickable link, the racials (Dev/ApiProbe.lua's sections of the same names).
        { "weathernow", "(read now) the weather, C_Weather.GetCurrentWeather()",
            now = function()
                local W = rawget(_G, "C_Weather")
                if not (W and type(W.GetCurrentWeather) == "function") then return false, "no C_Weather.GetCurrentWeather" end
                local r = { pcall(W.GetCurrentWeather) }
                if not r[1] then return false, "error" end
                local out = {}
                -- A table on Forever ({ type, intensity }, 2026-11-22): its fields, not its address.
                for i = 2, #r do
                    local v = r[i]
                    if ns.IsSecret(v) then out[#out + 1] = "<secret>"
                    elseif type(v) == "table" then
                        local f = {}
                        for k, x in pairs(v) do f[#f + 1] = tostring(k) .. "=" .. (ns.IsSecret(x) and "<secret>" or tostring(x)) end
                        table.sort(f)
                        out[#out + 1] = "{" .. table.concat(f, ", ") .. "}"
                    else out[#out + 1] = tostring(v) end
                end
                return true, #out > 0 and table.concat(out, ", ") or "(nothing)"
            end },
        -- weatherturn, not weatherchange: the first probe ticked that one on any step you took (2026-11-22).
        { "weatherturn", "run /dp probe api weather, then see the weather change (rain, snow, a sandstorm)",
            logs = { { "Api", "^weather WEATHER_CHANGED" }, { "Api", "^weather turned" }, { "Weather", "^WEATHER_CHANGED" },
                { "Weather", "^clear %-> " }, { "Weather", "^%a%a%a%a+ %-> clear" } } }, -- (a turn seen live, not the login's first read;
            -- seen 2026-11-22: WEATHER_CHANGED fires as it turns)
        { "addonlink", "run /dp probe api links and click the addon link in chat",
            logs = { { "Api", "^links .*addon:Dyreparken" } } },
        { "racials", "(read now) which of Forever's racials this character knows (/dp probe api racials: all)",
            now = function()
                local ok, summary = pcall(function() return ns.ApiProbe and ns.ApiProbe.Racials and ns.ApiProbe.Racials() end)
                if ok and summary then return true, summary end
                return false, "run /dp probe api racials"
            end },
        { "calendarclock", "(read now) the calendar's clock against date()",
            now = function()
                local ok, t = pcall(C_DateAndTime.GetCurrentCalendarTime)
                if not ok or type(t) ~= "table" then return false, "no calendar time" end
                local cal = (Plain(t.hour) or 0) * 60 + (Plain(t.minute) or 0)
                local mine = tonumber(date("%H")) * 60 + tonumber(date("%M"))
                return true, ("calendar %02d:%02d, date() %s: %+d min"):format(math.floor(cal / 60), cal % 60,
                    date("%H:%M"), cal - mine)
            end },
    }
    for _, a in ipairs(api) do
        if not a.class or a.class == class then
            Item({ id = "api:" .. a[1], area = "api", how = a[2], events = a.events, unit = a.unit, seen = a.seen,
                logs = a.logs, now = a.now, collect = a.collect })
        end
    end

    -- Only eyes can tell: ticked by hand.
    local look = {
        { "groupfights", "in a group, the pet frame's pet joins fights less often than solo" },
        { "autoshot", "with a ranged weapon or wand, the pet frame's pet joins in on auto shot" },
        { "afknap", "the pet frame's pet falls asleep while you're /afk, and wakes with a line now and then" },
        { "sleepstill", "at night the card's sleeping pet holds still (not standing up after a second)" },
        { "portraits", "Parken: every portrait draws, none blank" },
        { "gardensounds", "Parken: the garden's pieces make sounds when clicked" },
        { "compartment", "the addon compartment (by the minimap) lists Dyreparken" },
        { "combatkey", "after clicking the pet frame, the Collections key binding still opens it in combat" },
        { "unownedcard", "Parken: clicking a pet you don't own shows its card" },
        { "dungeonline", "a pet that likes dungeons says its line going in" },
    }
    for _, l in ipairs(look) do Item({ id = "look:" .. l[1], area = "look", how = l[2], manual = true }) end

    -- Might become interactions: listened to while the probe is on, their first payloads kept.
    local new = {
        { "emote", "/pet, /hug or another emote at your own companion (target it)", events = { "CHAT_MSG_TEXT_EMOTE" },
            seen = function(_, text, sender)
                sender = Plain(sender) -- (yours: the client's name or ours, "First Surname")
                if sender == Plain(UnitName("player")) or sender == ns.PlayerKey() then return tostring(Plain(text)) end
            end, collect = true },
        -- (2026-11-20, the user: a sleeping bag makes you resting too, at once, and its Well-Rested comes only a
        -- minute later; it was taken for an inn. So it's decided Verify.INN_AFTER on: still resting then with no
        -- Well-Rested is an inn or a city, with it the bag (logged only); resting no more, nothing.)
        { "inn", "stay a minute in an inn or a city (resting, no sleeping bag)", events = { "PLAYER_UPDATE_RESTING" },
            seen = function()
                if Plain(IsResting()) ~= true then return end
                local where = tostring(Plain(GetZoneText())) .. " / " .. tostring(Plain(GetSubZoneText()))
                innT:Cancel()
                innT:After(Verify.INN_AFTER, function()
                    if Plain(IsResting()) ~= true then return ns.Log("Verify", "resting in %s: over before it was told", where) end
                    if ns.Activity.HasAura(ns.Activity.AuraName("rested")) then
                        return ns.Log("Verify", "resting in %s: the sleeping bag's", where)
                    end
                    Verify:Tick(Verify.BY["new:inn"], "resting in " .. where)
                end)
            end, collect = true },
        -- (2026-11-20, the user: a flight path ticked it: IsMounted() is true on a taxi, at its take-off's
        -- PLAYER_MOUNT_DISPLAY_CHANGED. So it's decided Verify.MOUNT_AFTER on, once the taxi has started.)
        { "mount", "mount up (your own mount, not a flight path)", events = { "PLAYER_MOUNT_DISPLAY_CHANGED" },
            seen = function()
                if Plain(IsMounted()) ~= true then return end
                local taxi = Plain(UnitOnTaxi("player"))
                mountT:Cancel()
                mountT:After(Verify.MOUNT_AFTER, function()
                    if taxi == true or Plain(UnitOnTaxi("player")) == true then
                        return ns.Log("Verify", "mounted: a flight path's (on the taxi at the event: %s)", tostring(taxi))
                    end
                    if Plain(IsMounted()) ~= true then return end
                    Verify:Tick(Verify.BY["new:mount"], "mounted in " .. tostring(Plain(GetZoneText())))
                end)
            end },
        { "trade", "open a trade with a player", events = { "TRADE_SHOW" }, seen = function() return "trade" end },
        { "npctalk", "hear an NPC say or yell something (a boss)", events = { "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL" },
            seen = function(_, text, sender) return tostring(Plain(sender)) .. ": " .. tostring(Plain(text)):sub(1, 60) end,
            collect = true },
        { "achievement", "earn one of the game's own achievements", events = { "ACHIEVEMENT_EARNED" },
            seen = function(_, id) return "id " .. tostring(Plain(id)) end, collect = true },
        { "petbattle", "start a pet battle (if Forever has them)", events = { "PET_BATTLE_OPENING_START" },
            seen = function() return "a pet battle" end },
        { "questaccept", "accept a quest", events = { "QUEST_ACCEPTED" },
            seen = function(_, a, b) return "quest " .. tostring(Plain(b or a)) end },
        { "interactions", "open any NPC's window (vendor, trainer, stable, barber...): its type number",
            events = { "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" }, collect = true,
            seen = function(_, kind)
                kind = Plain(kind)
                local types = Enum and Enum.PlayerInteractionType or {}
                for name, n in pairs(types) do if n == kind then return name .. " " .. tostring(kind) end end
                return "? " .. tostring(kind)
            end },
        { "zonenames", "go to a zone Data/Zones doesn't know (its name as the client gives it)",
            events = { "ZONE_CHANGED_NEW_AREA" }, collect = true,
            seen = function()
                local z = Plain(GetZoneText())
                if Plain(IsInInstance()) == true then return end -- (a dungeon isn't Data/Zones', 2026-11-20: Maraudon)
                if type(z) == "string" and z ~= "" and not ns.Zones.rows[z] then return z end
            end },
    }
    for _, n in ipairs(new) do
        Item({ id = "new:" .. n[1], area = "new", how = n[2], events = n.events, seen = n.seen, collect = n.collect })
    end
    table.sort(Verify.ITEMS, function(x, y)
        if x.area ~= y.area then return x.area < y.area end
        return x.id < y.id
    end)
end

---------------------------------------------------------------------------
-- Ticking
---------------------------------------------------------------------------
local function Store()
    local db = DyreparkenDebugDB
    db.verify = db.verify or {}
    local v = db.verify
    v.seen = v.seen or {}
    v.notes = v.notes or {}
    return v
end

-- An item's state: "seen" (with its record), "before" (this character's counters), "missing" (its event isn't in
-- the client), else "open".
function Verify:State(item)
    local rec = Store().seen[item.id]
    if rec then return "seen", rec end
    if item.before and item.before() then return "before" end
    if item.missing then return "missing" end
    return "open"
end

function Verify:Tick(item, detail)
    local v = Store()
    local rec = v.seen[item.id]
    detail = detail and tostring(detail) or ""
    if rec then
        if not item.collect then return end
        rec.details = rec.details or {}
        for _, d in ipairs(rec.details) do if d == detail then return end end
        if #rec.details >= self.KEEP then return end
        rec.details[#rec.details + 1] = detail
        ns.Log("Verify", "%s also: %s", item.id, detail)
        if #rec.details >= self.KEEP and item.events then ns.Events:OffAll(item) end -- (full: nothing more to keep)
        return
    end
    -- Known: this character's counters had it when the probe started (2026-11-20, the user: the verified ones
    -- silent, "less spam + I get a better feeling for when I should reload"). Taken at the start, not now: an
    -- activity is counted before its log line, so its first time would look known already.
    local known = item.known or nil
    v.seen[item.id] = { at = ns.Now(), who = tostring(ns.PlayerKey()), detail = detail, known = known,
        details = item.collect and { detail } or nil }
    v.notes[item.id] = nil
    if item.events and not item.collect then ns.Events:OffAll(item) end -- (answered: no need to listen on)
    ns.Log("Verify", "seen %s%s: %s", item.id, known and " (known)" or "", detail)
    if known then return end
    self.fresh = (self.fresh or 0) + 1
    ns.Print(("|cff7fd47fVerify|r: %s%s |cff999999(%d new this session)|r"):format(item.id,
        detail ~= "" and (" (" .. detail .. ")") or "", self.fresh))
end

-- The debug log's lines, by module, against the items that read them.
local byModule
local function Tap(module, msg)
    if module == "Aura" and msg:find("^campwarm off") then Verify.campEnd = GetTime() end
    local list = byModule[module]
    if not list then return end
    for i = 1, #list do
        local e = list[i]
        if msg:find(e[2]) then Verify:Tick(e[1], msg) end
    end
end

local function OnEvent(item)
    return function(_, event, ...) -- (Events: fn(owner, event, ...))
        local ok, detail = pcall(item.seen, event, ...)
        if not ok then return ns.Log("Verify", "%s: %s", item.id, tostring(detail)) end
        if detail then Verify:Tick(item, detail) end
    end
end

-- Zones: ticked when the client names one (at the zone's change and at a loading screen's end); a subzone's
-- (the goblin towns) at a subzone's change too, heard only while one of them is open.
local function SubOpen()
    local seen = Store().seen
    for _, item in ipairs(Verify.ITEMS) do if item.sub and not seen[item.id] then return true end end
end
local function ZoneNow()
    if not Verify.armed then return end
    for _, read in ipairs({ GetZoneText, GetSubZoneText }) do
        local z = Plain(read())
        local item = type(z) == "string" and Verify.BY["zone:" .. z]
        if item then Verify:Tick(item, z) end
    end
    if ns.Events:Has("ZONE_CHANGED", Verify) and not SubOpen() then ns.Events:Off("ZONE_CHANGED", Verify) end
end

local valid = C_EventUtils and C_EventUtils.IsEventValid
function Verify:Arm()
    if self.armed then return end
    if #self.ITEMS == 0 then Build() end
    self.armed = true
    -- (2026-11-20: the flight path's tick, from before a taxi was told apart)
    local stale = Store().seen["new:mount"]
    if stale and stale.detail == "mounted true" then Store().seen["new:mount"] = nil end
    local names = Store().seen["new:zonenames"] -- (and Maraudon, a dungeon, collected before they were left out)
    if names and names.detail == "Maraudon" and #(names.details or {}) <= 1 then Store().seen["new:zonenames"] = nil end
    -- A tick of an item that's gone (new:resting became new:inn, 2026-11-20). Only an area this character builds
    -- all of: a react or a class's api item exists for other characters.
    local whole = { activity = true, egg = true, zone = true, route = true, look = true, new = true }
    for id in pairs(Store().seen) do
        local area = id:match("^(%a+):")
        if whole[area] and not self.BY[id] then Store().seen[id] = nil; Store().notes[id] = nil end
    end
    if not ns.Debug.enabled then ns.Debug:SetEnabled(true, ns.Debug.echo) end
    byModule = {}
    -- What this character's counters had at the session's first start, not at a forget's or reset's re-arm, when
    -- what just happened is counted already (review 2026-11-21).
    local baseline = not self.based
    self.based = true
    for _, item in ipairs(self.ITEMS) do
        if baseline then item.known = item.before and item.before() or nil end
        for _, l in ipairs(item.logs or {}) do
            byModule[l[1]] = byModule[l[1]] or {}
            table.insert(byModule[l[1]], { item, l[2] })
        end
        local rec = Store().seen[item.id]
        if item.events and (not rec or (item.collect and #(rec.details or {}) < self.KEEP)) then
            item.missing = nil
            for _, ev in ipairs(item.events) do
                if valid and not valid(ev) then
                    item.missing = true
                else
                    ns.Events:On(ev, item, OnEvent(item), item.unit)
                end
            end
        end
    end
    ns.Debug.tap = Tap
    ns.Events:On("ZONE_CHANGED_NEW_AREA", self, ZoneNow)
    ns.Events:On("PLAYER_ENTERING_WORLD", self, ZoneNow)
    if SubOpen() then ns.Events:On("ZONE_CHANGED", self, ZoneNow) end
    self:Now()
    ZoneNow()
end

function Verify:Disarm()
    if not self.armed then return end
    self.armed = false
    ns.Debug.tap = nil
    for _, item in ipairs(self.ITEMS) do ns.Events:OffAll(item) end
    ns.Events:OffAll(self)
    innT:Cancel(); mountT:Cancel()
end

-- The answers read on the spot; an open one keeps its last answer as a note.
function Verify:Now()
    local v = Store()
    for _, item in ipairs(self.ITEMS) do
        if item.now and not v.seen[item.id] then
            local ok, yes, detail = pcall(item.now)
            if not ok then detail = tostring(yes); yes = false end
            if yes then self:Tick(item, detail) else v.notes[item.id] = detail end
        end
    end
end

---------------------------------------------------------------------------
-- The command
---------------------------------------------------------------------------
function Verify:Counts()
    local all, done, open = 0, 0, {}
    for _, item in ipairs(self.ITEMS) do
        all = all + 1
        local s = self:State(item)
        if s == "seen" or s == "before" then done = done + 1 else open[item.area] = (open[item.area] or 0) + 1 end
    end
    return all, done, open
end

function Verify:Summary()
    local all, done, open = self:Counts()
    local parts = {}
    for _, a in ipairs(self.AREAS) do if open[a] then parts[#parts + 1] = a .. " " .. open[a] end end
    ns.Print(("Verify: %d of %d confirmed. Open: %s."):format(done, all, #parts > 0 and table.concat(parts, ", ") or "none"))
    ns.Print("/dp probe verify <area> lists one (activity, api, react, egg, zone, route, look, new; \"all\" after it: "
        .. "the done ones too), ok <id> ticks a look by hand, forget <id> undoes a wrong tick, off, reset.")
end

function Verify:List(area, all)
    local n = 0
    for _, item in ipairs(self.ITEMS) do
        if item.area == area then
            local s, rec = self:State(item)
            if all or (s ~= "seen" and s ~= "before") then
                n = n + 1
                local tail = s == "seen" and (" - seen: " .. (rec.details and table.concat(rec.details, "; ") or rec.detail))
                    or s == "before" and " - counted before" or s == "missing" and " - its event isn't in the client"
                    or Store().notes[item.id] and (" - last answer: " .. Store().notes[item.id]) or ""
                ns.Print(("  %s %s: %s%s"):format((s == "seen" or s == "before") and "|cff7fd47fok|r" or "-",
                    (item.id:gsub("^[^:]+:", "")), item.how, tail))
            end
        end
    end
    if n == 0 then ns.Print("  (nothing " .. (all and "here" or "open") .. ")") end
end

function Verify:Command(arg)
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    if #self.ITEMS == 0 then Build() end
    local v = Store()
    if word == "off" then
        v.on = false
        self:Disarm()
        return ns.Print("Verify off (its ticks are kept).")
    elseif word == "reset" then
        v.seen, v.notes = {}, {}
        self:Disarm(); if v.on then self:Arm() end
        return ns.Print("Verify: every tick forgotten.")
    elseif word == "ok" then
        local item = self.BY[rest] or self.BY["look:" .. rest]
        if not item then return ns.Print("Verify: no item \"" .. rest .. "\" (/dp probe verify look lists them).") end
        return self:Tick(item, "by hand")
    elseif word == "forget" then
        local item = self.BY[rest] or self.BY["look:" .. rest]
        if not (item and v.seen[item.id]) then return ns.Print("Verify: no tick \"" .. rest .. "\" to forget.") end
        v.seen[item.id] = nil
        self:Disarm(); if v.on then self:Arm() end
        return ns.Print("Verify: " .. item.id .. " open again.")
    end
    v.on = true
    self:Arm()
    for _, a in ipairs(self.AREAS) do
        if word == a then return self:List(a, rest == "all") end
    end
    if word ~= "" then return ns.Print("Verify: no area \"" .. word .. "\".") end
    self:Summary()
end

-- On again at every login once started, until /dp probe verify off.
ns.Start("settled", function()
    local v = DyreparkenDebugDB and DyreparkenDebugDB.verify
    if v and v.on then Verify:Arm() end
end)
