local _, ns = ...

-- Today's wish (2026-11-08): each day your adopted pet wishes for one thing
-- it likes. Done with it out, the wish brings Config.BOND_WISH_POINTS (within
-- the day's limit), a line in chat, and a tick on its card. A reason to do
-- something with your pet today, not just have it out.
--
-- The wish is one of the pet's likes (Personality), picked from the date and
-- the pet, so it holds all day and through reloads; never something you
-- can't do when you like (dying, a level). Kept per character in
-- char.wish = { day, pet, id, done }.
--
-- Streaks (2026-11-11, the user): every day a wish comes true counts, whichever adopted pet
-- wished it (char.wishes); a day without one ends the run. Shown on the line from two days in a
-- row; achievements at 7 and 30 in a row and 100 in all.
local Wish = {}
ns.Wish = Wish

-- Likes that can't be a wish: you can't do them on demand (Activity.KINDS: wish = false).
Wish.NEVER = {}
for _, k in ipairs(ns.Activity.KINDS) do
    if k.wish == false then Wish.NEVER[k.id] = true end
end

-- Wishes beyond its likes (2026-11-11, the user): now and then any pet wishes for time by a
-- campfire, and a cozy one for a night in a sleeping bag. One day in CAMP_EVERY each, by the date.
Wish.CAMP_EVERY = 6
local function Sleeper(key) return ns.Personality:Tagged(key, "sleeper") end -- (Personality.TRAITS' `is`)

------------------------------------------------------------------------------
-- Wishes by nature (2026-11-14, the user: "wishing to meet guildies etc, using the events we already
-- track, and which suits the traits/family ... visit specific zones (also related to family)"). One day in
-- EXTRA_EVERY, a pet with one that fits wishes for it instead of a like:
--   company from the guild, for a social pet (Personality tag "social", or a family in SOCIAL's list),
--     never a loner (Einstøing): in a group with a guildmate, a playdate, a guildmate's pet met;
--   a trip to a zone of its nature: its families' homes (Quirks.HOME_ZONES) and its traits' zones
--     (Vinterpels the cold, Solelsker the warm, Skybåren the high, Ordensdyr the cities), only zones in
--     ZONES that your character can reach (its lowest level at most yours, not the other faction's).
-- Each choice is as likely (a pet with many zones doesn't wish for trips more often).
------------------------------------------------------------------------------
Wish.EXTRA_EVERY = 4
Wish.SOCIAL = {
    guildgroup = { "wolf" },          -- (a pack)
    playmate = { "rabbit", "festive" },
    guildpet = { "farm", "rodent" },
}
Wish.SOCIAL_ORDER = { "guildgroup", "playmate", "guildpet" }
-- Zones a trip can be to: the lowest level that goes there (classic's ranges), and the faction whose own
-- land it is (the other faction's never comes up). Not instances, nor battlegrounds. Zephras Isle is
-- Forever's own (the Skyborne's), level and faction unverified.
Wish.ZONES = {
    ["Elwynn Forest"] = { 1, "Alliance" }, ["Dun Morogh"] = { 1, "Alliance" }, ["Teldrassil"] = { 1, "Alliance" },
    ["Stormwind City"] = { 1, "Alliance" }, ["Ironforge"] = { 1, "Alliance" }, ["Darnassus"] = { 1, "Alliance" },
    ["Westfall"] = { 10, "Alliance" }, ["Darkshore"] = { 10, "Alliance" },
    ["Durotar"] = { 1, "Horde" }, ["Mulgore"] = { 1, "Horde" }, ["Tirisfal Glades"] = { 1, "Horde" },
    ["Orgrimmar"] = { 1, "Horde" }, ["Thunder Bluff"] = { 1, "Horde" }, ["Undercity"] = { 1, "Horde" },
    ["The Barrens"] = { 10, "Horde" }, ["Silverpine Forest"] = { 10, "Horde" },
    ["Zephras Isle"] = { 1 },
    ["Ashenvale"] = { 18 }, ["Wetlands"] = { 20 }, ["Thousand Needles"] = { 25 }, ["Alterac Mountains"] = { 30 },
    ["Desolace"] = { 30 }, ["Stranglethorn Vale"] = { 30 }, ["Dustwallow Marsh"] = { 35 }, ["Badlands"] = { 35 },
    ["Swamp of Sorrows"] = { 35 }, ["Feralas"] = { 40 }, ["Tanaris"] = { 40 }, ["Searing Gorge"] = { 43 },
    ["Blasted Lands"] = { 45 }, ["Felwood"] = { 48 }, ["Un'Goro Crater"] = { 48 }, ["Moonglade"] = { 48 },
    ["Burning Steppes"] = { 50 }, ["Eastern Plaguelands"] = { 53 }, ["Winterspring"] = { 55 }, ["Silithus"] = { 55 },
}
-- Its traits' zones (by the trait's moment: Personality's lists).
Wish.TRAIT_ZONES = { vinterpels = "COLD", solelsker = "WARM", skybaren = "HIGH", ordensdyr = "CITIES" }

-- The zones this pet would like a trip to, that you can reach now: sorted names.
function Wish.Zones(key)
    local set = {}
    for _, f in ipairs(ns.Scenes:Families(key)) do
        for _, z in ipairs(ns.Quirks.HOME_ZONES[f] or {}) do set[z] = true end
    end
    for trait, list in pairs(Wish.TRAIT_ZONES) do
        if ns.Personality:Has(key, trait) then
            for z in pairs(ns.Personality[list]) do set[z] = true end
        end
    end
    local level = tonumber(ns.Plain(UnitLevel("player"))) or 1
    local faction = ns.Plain((UnitFactionGroup("player")))
    local list = {}
    for z in pairs(set) do
        local row = Wish.ZONES[z]
        if row and row[1] <= level and (not row[2] or row[2] == faction) then list[#list + 1] = z end
    end
    table.sort(list)
    return list
end

-- The company wishes that fit this pet (SOCIAL_ORDER's order).
function Wish.Social(key)
    local list = {}
    if ns.Personality:Tagged(key, "loner") then return list end
    local social = ns.Personality:Tagged(key, "social")
    local families = {}
    for _, f in ipairs(ns.Scenes:Families(key)) do families[f] = true end
    for _, id in ipairs(Wish.SOCIAL_ORDER) do
        local fits = social
        for _, f in ipairs(Wish.SOCIAL[id]) do fits = fits or families[f] end
        if fits and ns.Activity:Available(id) then list[#list + 1] = id end
    end
    return list
end

local function Hash(text) return LibStub("LibDeflate"):Adler32(text) end

-- A wish by nature on this day, or nil: its id, and the zone for a trip.
function Wish:Extra(key, day)
    if Hash("extra " .. day .. " " .. key) % self.EXTRA_EVERY ~= 0 then return nil end
    local choices = self.Social(key)
    local zones = self.Zones(key)
    if #zones > 0 then choices[#choices + 1] = "zone" end
    if #choices == 0 then return nil end
    local id = choices[Hash("extra pick " .. day .. " " .. key) % #choices + 1]
    if id == "zone" then return id, zones[Hash("zone " .. day .. " " .. key) % #zones + 1] end
    return id
end

-- What the pet wishes for on a day ("YYYYMMDD"): the wish's id, and its zone for a trip.
function Wish:For(key, day)
    local roll = Hash("camp " .. day .. " " .. key) % self.CAMP_EVERY
    if roll == 0 and ns.Activity:Available("camp") then return "camp" end
    if roll == 1 and Sleeper(key) and ns.Activity:Available("rested") then return "rested" end
    local extra, zone = self:Extra(key, day)
    if extra then return extra, zone end
    local _, list = ns.Personality:Of(key)
    local choices = {}
    for _, act in ipairs(list) do
        -- (and only what this client can see happen: a wish nobody can fulfil wastes the day)
        if not self.NEVER[act] and ns.Activity:Available(act) then choices[#choices + 1] = act end
    end
    if #choices == 0 then choices = { "quest" } end
    return choices[Hash("wish " .. day .. " " .. key) % #choices + 1]
end

-- Today's wish for your adopted pet: { pet, id, done }, or nil without one.
function Wish:Today()
    local key = ns.Registry:MyPet()
    if not key then return nil end
    local day = ns.Today()
    local w = ns.DB.char.wish
    if not w or w.day ~= day or w.pet ~= key then
        local id, zone = self:For(key, day)
        w = { day = day, pet = key, id = id, zone = zone, done = false }
        ns.DB.char.wish = w
        self:Arm()
        self:Auto(w)
    end
    return w
end

-- Today's wish as it's stored, without making one (it's made on demand: Wish:Today).
local function Stored()
    local w = ns.DB.char and ns.DB.char.wish
    if w and w.day == ns.Today() and w.pet == ns.Registry:MyPet() then return w end
end

-- What a wish is for, as a noun ("fisking", "en tur til Tanaris").
function Wish.Noun(w)
    if w.id == "zone" then return ns.T("wish.zone.noun", { zone = w.zone }) end
    return ns.Personality.NOUN[w.id]
end

-- The card's line for a wish: one of its own lines (wish.say.<id>.N), the same all day; else the usual.
function Wish.Line(w)
    local vars = { pet = ns.Registry:NameOf(w.pet), activity = Wish.Noun(w), zone = w.zone }
    local list = ns.Variants("wish.say." .. w.id)
    if #list == 0 then return ns.T("wish.line", vars) end
    return ns.T(list[Hash("line " .. w.day .. " " .. w.pet) % #list + 1], vars)
end

-- The wish line's tooltip: what today's wish gives, and the streak.
function Wish.Lines()
    local w = Wish:Today()
    if not w then return nil end
    local lines = {
        { ns.L["wish.title"], 1, 0.82, 0 },
        { ns.T(w.done and "wish.tip.done" or "wish.tip", { pet = ns.Registry:NameOf(w.pet),
            n = ns.Config.BOND_WISH_POINTS }), 1, 1, 1, true },
    }
    local run, counted = Wish:Streak()
    if counted and run >= 2 then
        lines[3] = { ns.T("wish.streak.tip", { n = run }), 0.4, 1, 0.4, true }
    elseif not counted and run >= 1 then
        lines[3] = { ns.T("wish.streak.keep", { n = run + 1 }), 1, 0.82, 0, true }
    end
    return lines
end

-- The card's happy hop for today's wish come true has played (Moves): once.
function Wish:Shown()
    local w = ns.DB.char.wish
    if w then w.shown = true end
end

function Wish:OnActivity(id, key)
    local w = self:Today()
    if not w or w.done or w.pet ~= key then return end
    if w.id == id then return self:Grant(w) end
    self:Auto(w) -- (anything done with it out: the day's first time out, most of the time)
end

-- The wish comes true: its points (Bond.REWARDS.wish), its line (textKey, and fullKey for a full day;
-- the usual one by default) and the day in the streak.
function Wish:Grant(w, textKey, fullKey)
    textKey, fullKey = textKey or "wish.granted", fullKey or "wish.granted.full"
    w.done = true
    self:Arm()
    ns.Bond:Reward("wish", w.pet, ns.Bond.Line(textKey, fullKey, { pet = ns.Registry:NameOf(w.pet),
        activity = Wish.Noun(w) }))
    self:Count(w.day)
end

------------------------------------------------------------------------------
-- Wishes a character has outgrown (2026-11-13, the user, D2 option B). A new place for this pet was
-- the only way to an explore wish, so a pet that has seen your usual zones could hardly have one,
-- and a skill-up can't happen with every profession at its cap. So on an explore wish's day, finding
-- a new area yourself ("Discovered: %s") or entering a zone not fully explored (the Explore Eastern
-- Kingdoms / Kalimdor achievements' criteria) does it too; with all explored (Explore Azeroth) and
-- every zone on those lists seen by this pet, and with every profession at its current cap, the
-- wish comes true by itself, with its own line. Always with the pet out, like any wish. The explore
-- activity itself (the bond's firsts) is unchanged: this is only what fulfils the wish.
-- Cheap: the events are registered only while today's wish is an unfulfilled explore (Wish:Arm),
-- and the auto checks run when a wish is made, when its card shows, and when the pet does something.
------------------------------------------------------------------------------
Wish.EXPLORE = { all = 62053, lists = { 62353, 62355 }, category = 15607 } -- (/dp probe api legacy, 2026-11-13)

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    return unpack(r, 2, table.maxn(r))
end

-- Whether an achievement is done: by its id, else (if the id form gives nothing) found once in the
-- Explorer category by position.
local byIndex -- id -> index in Wish.EXPLORE.category
function Wish.AchievementDone(id)
    local got, _, _, done = Call(GetAchievementInfo, id)
    if ns.Plain(got) == id then return ns.Plain(done) == true end
    local cat = Wish.EXPLORE.category
    if not byIndex then
        byIndex = {}
        for i = 1, tonumber(ns.Plain((Call(GetCategoryNumAchievements, cat)))) or 0 do
            local aid = ns.Plain((Call(GetAchievementInfo, cat, i)))
            if type(aid) == "number" then byIndex[aid] = i end
        end
    end
    if not byIndex[id] then return false end
    _, _, _, done = Call(GetAchievementInfo, cat, byIndex[id])
    return ns.Plain(done) == true
end

-- Each zone criterion of Explore Eastern Kingdoms and Kalimdor: fn(name, done); true from fn stops.
local function EachZone(fn)
    for _, id in ipairs(Wish.EXPLORE.lists) do
        for j = 1, tonumber(ns.Plain((Call(GetAchievementNumCriteria, id)))) or 0 do
            local name, _, done = Call(GetAchievementCriteriaInfo, id, j)
            name, done = ns.Plain(name), ns.Plain(done)
            if type(name) == "string" and fn(name, done == true) then return true end
        end
    end
end

-- A zone on those lists not fully explored yet.
function Wish.ZoneOpen(zone)
    return type(zone) == "string" and EachZone(function(name, done) return name == zone and not done end) == true
end

-- Everything explored, and this pet has been to every zone on the lists (char.places: map ids, or
-- zone names in instances).
function Wish.SeenAll(key)
    if not Wish.AchievementDone(Wish.EXPLORE.all) then return false end
    local seen = {}
    for place in pairs(ns.DB.char.places[key] or {}) do
        local map = tonumber(place:match("^m(%d+)$"))
        local info = map and C_Map and C_Map.GetMapInfo and Call(C_Map.GetMapInfo, map)
        local name = info and ns.Plain(info.name) or place:match("^z(.+)$")
        if name then seen[name] = true end
    end
    local any = false
    local missing = EachZone(function(name) any = true; return not seen[name] end)
    return any and not missing
end

-- Every profession at its current cap (what a trainer can teach now). Weapon skills can't be read
-- (no GetSkillLineInfo on Forever), so they don't count. No professions at all: not capped, since
-- learning one is a skill-up you can still have.
function Wish.Capped()
    local slots = { Call(GetProfessions) }
    local any = false
    for slot = 1, 6 do
        local i = ns.Plain(slots[slot])
        if type(i) == "number" then
            local _, _, rank, max = Call(GetProfessionInfo, i)
            rank, max = ns.Plain(rank), ns.Plain(max)
            if type(rank) ~= "number" or type(max) ~= "number" or rank < max then return false end
            any = true
        end
    end
    return any
end

-- The wishes with no chip of their own borrow one's icon.
Wish.ICON = { zone = "explore", guildgroup = "chat", guildpet = "meet", playmate = "meet" }

-- A wish that comes true by itself, checked with the pet out (and out of combat: the pet can't be read in it).
function Wish:Auto(w)
    if not w or w.done or not Wish.AUTO[w.id] then return end
    if ns.InCombat() or ns.Pets:OutKey() ~= w.pet then return end
    -- (already there, or already together, as the wish is made or the pet comes out)
    if w.id == "zone" and ns.Plain(GetZoneText()) == w.zone then
        self:Grant(w)
    elseif w.id == "guildgroup" and ns.Activity.Guildmate() then
        self:Grant(w)
    elseif w.id == "skill" and self.Capped() then
        self:Grant(w, "wish.auto.skill", "wish.auto.skill.full")
    elseif w.id == "explore" and self.SeenAll(w.pet) then
        self:Grant(w, "wish.auto.explore", "wish.auto.explore.full")
    end
end

Wish.AUTO = { skill = true, explore = true, zone = true, guildgroup = true }

-- An explore wish's other ways, with the pet out.
local function Explored(how)
    ns.Events:OutOfCombat(function()
        local w = Wish:Today()
        if not w or w.done or w.id ~= "explore" or ns.Pets:OutKey() ~= w.pet then return end
        ns.Log("Wish", "explore wish by %s", how)
        Wish:Grant(w)
    end)
end
local WATCH = {} -- (our owner key for ns.Events and Activity:Want)
local armed = false -- the wish watched for: its id, or false
local function Pending(id)
    local w = Wish:Today() -- (past midnight: the new day's wish, which arms or drops these)
    return w and not w.done and w.id == id and w
end
local function OnDiscovered(_, event, a, b)
    if not Pending("explore") then return end
    local text = ns.Plain(event == "UI_INFO_MESSAGE" and b or a)
    if type(text) ~= "string" then return end
    for _, global in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
        local pattern = ns.Activity.FormatPattern(_G[global])
        if pattern and text:match(pattern) then return Explored("discovery") end
    end
end
local function OnZone()
    if not (Pending("explore") or Pending("zone")) then return end
    -- (a few seconds on, like Activity:CheckPlace: the companion is back out after the loading screen)
    C_Timer.After(5, function()
        if Pending("explore") and Wish.ZoneOpen(ns.Plain(GetZoneText())) then return Explored("zone") end
        local w = Pending("zone")
        if w then ns.Events:OutOfCombat(function() Wish:Auto(w) end) end
    end)
end
Wish.WATCH = WATCH

-- What today's wish needs watched, while it isn't done: its activity (a like is watched by the bond
-- already, but a campfire or company from the guild isn't), an explore's other ways, a trip's zone.
-- Nothing otherwise.
function Wish:Arm()
    local w = Stored()
    local want = (w and not w.done and w.id) or false
    if want == armed then return end
    armed = want
    ns.Events:OffAll(WATCH)
    ns.Activity:WantOnly(WATCH, (want and ns.Activity.KIND[want]) and { [want] = true } or {})
    if want == "explore" then
        ns.Events:On("UI_INFO_MESSAGE", WATCH, OnDiscovered)
        ns.Events:On("CHAT_MSG_SYSTEM", WATCH, OnDiscovered)
    end
    if want == "explore" or want == "zone" then ns.Events:On("ZONE_CHANGED_NEW_AREA", WATCH, OnZone) end
    ns.Log("Wish", "watch %s", tostring(want))
end
-- Whether today's wish has events of its own watched (an explore's, a trip's).
function Wish:Watching() return armed == "explore" or armed == "zone" end

-- The calendar day before a day ("YYYYMMDD"): noon of the day before, safe around DST.
local function DayBefore(day)
    local y, m, d = day:match("^(%d%d%d%d)(%d%d)(%d%d)$")
    return date("%Y%m%d", time({ year = tonumber(y), month = tonumber(m), day = tonumber(d) - 1, hour = 12 }))
end

-- A wish came true on `day`: counted once a day (another pet's wish the same day, after a swap, isn't
-- a second day).
function Wish:Count(day)
    local s = ns.DB.char.wishes
    if s.last == day then return end
    s.streak = (s.last and s.last == DayBefore(day)) and (s.streak or 0) + 1 or 1
    s.n = (s.n or 0) + 1
    s.best = math.max(s.best or 0, s.streak)
    s.last = day
    ns.Bus:Fire("WISH_DONE")
end

-- Days in a row so far: the run still holds today if its last day was today or yesterday.
-- Returns the run, and whether today already counts.
function Wish:Streak()
    local s, today = ns.DB.char.wishes, ns.Today()
    if s.last == today then return s.streak or 0, true end
    if s.last and s.last == DayBefore(today) then return s.streak or 0, false end
    return 0, false
end

function Wish:Init()
    -- (OnActivity checks the pet out is today's wisher: your adopted pet.)
    ns.Bus:On("ACTIVITY", function(id, _, key) Wish:OnActivity(id, key) end)
    self:Arm() -- (a wish made before a /reload)
    -- Adopted or let go: today's wish is another pet's, or none (and what it watched goes).
    ns.Bus:On("MY_RECORD", function() Wish:Arm() end)
end

------------------------------------------------------------------------------
-- On the card: a line under the chips, for your own pet.
------------------------------------------------------------------------------
function Wish:Build(card, c)
    local f = CreateFrame("Frame", nil, c)
    f:SetSize(260, 18)
    f:SetFrameLevel(c:GetFrameLevel() + 5)
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(16, 16)
    f.icon:SetPoint("LEFT")
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.text:SetPoint("LEFT", f.icon, "RIGHT", 4, 0)
    f:EnableMouse(true)
    ns.SetTip(f, "ANCHOR_BOTTOM", function() return Wish.Lines() end)
    f:Hide()
    card.wish = f
end

function Wish:Update(card, key)
    local f = card.wish
    if not f then return end
    local w = key and self:Today()
    if not w or w.pet ~= key then f:Hide(); return end
    self:Auto(w)
    f.icon:SetTexture(ns.Stats.Icon(Wish.ICON[w.id] or w.id) or ns.Icon("heart")) -- (the first that exists)
    if w.done then
        local run = self:Streak()
        f.text:SetText(run >= 2 and ns.T("wish.done.streak", { n = run }) or ns.L["wish.done"])
        f.text:SetTextColor(0.4, 1, 0.4)
        f.icon:SetDesaturated(false)
    else
        f.text:SetText(Wish.Line(w))
        f.text:SetTextColor(1, 0.82, 0)
    end
    f:SetWidth(20 + f.text:GetStringWidth())
    f:ClearAllPoints()
    local stats = card.stats
    if stats and stats:IsShown() then
        f:SetPoint("TOP", stats, "BOTTOM", 0, -4)
    elseif card.decor and card.decor.ribbon:IsShown() then
        f:SetPoint("TOP", card.decor.ribbon, "BOTTOM", 0, -2)
    else
        f:SetPoint("TOP", card.panel:GetParent(), "TOP", 0, -14)
    end
    f:Show()
end

ns.Card.Register{ id = "wish", still = true, -- (a line of text)
    build = function(card, c) Wish:Build(card, c) end,
    update = function(card, key) Wish:Update(card, key) end,
}

ns.Start("login", function() Wish:Init() end)
