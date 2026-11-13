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

-- What the pet wishes for on a day ("YYYYMMDD").
function Wish:For(key, day)
    local roll = LibStub("LibDeflate"):Adler32("camp " .. day .. " " .. key) % self.CAMP_EVERY
    if roll == 0 and ns.Activity:Available("camp") then return "camp" end
    if roll == 1 and Sleeper(key) and ns.Activity:Available("rested") then return "rested" end
    local _, list = ns.Personality:Of(key)
    local choices = {}
    for _, act in ipairs(list) do
        -- (and only what this client can see happen: a wish nobody can fulfil wastes the day)
        if not self.NEVER[act] and ns.Activity:Available(act) then choices[#choices + 1] = act end
    end
    if #choices == 0 then choices = { "quest" } end
    local h = LibStub("LibDeflate"):Adler32("wish " .. day .. " " .. key)
    return choices[h % #choices + 1]
end

-- Today's wish for your adopted pet: { pet, id, done }, or nil without one.
function Wish:Today()
    local key = ns.Registry:MyPet()
    if not key then return nil end
    local day = ns.Today()
    local w = ns.DB.char.wish
    if not w or w.day ~= day or w.pet ~= key then
        w = { day = day, pet = key, id = self:For(key, day), done = false }
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
        activity = ns.Personality.NOUN[w.id] }))
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

-- A wish that comes true by itself, checked with the pet out (and out of combat: the pet can't be read in it).
function Wish:Auto(w)
    if not w or w.done or not (w.id == "skill" or w.id == "explore") then return end
    if ns.InCombat() or ns.Pets:OutKey() ~= w.pet then return end
    if w.id == "skill" and self.Capped() then
        self:Grant(w, "wish.auto.skill", "wish.auto.skill.full")
    elseif w.id == "explore" and self.SeenAll(w.pet) then
        self:Grant(w, "wish.auto.explore", "wish.auto.explore.full")
    end
end

-- An explore wish's other ways, with the pet out.
local function Explored(how)
    ns.Events:OutOfCombat(function()
        local w = Wish:Today()
        if not w or w.done or w.id ~= "explore" or ns.Pets:OutKey() ~= w.pet then return end
        ns.Log("Wish", "explore wish by %s", how)
        Wish:Grant(w)
    end)
end
local WATCH = {} -- (our owner key for ns.Events)
local armed = false
local function Pending()
    local w = Wish:Today() -- (past midnight: the new day's wish, which arms or drops these)
    return w and not w.done and w.id == "explore"
end
local function OnDiscovered(_, event, a, b)
    if not Pending() then return end
    local text = ns.Plain(event == "UI_INFO_MESSAGE" and b or a)
    if type(text) ~= "string" then return end
    for _, global in ipairs({ "ERR_ZONE_EXPLORED", "ERR_ZONE_EXPLORED_XP" }) do
        local pattern = ns.Activity.FormatPattern(_G[global])
        if pattern and text:match(pattern) then return Explored("discovery") end
    end
end
local function OnZone()
    if not Pending() then return end
    -- (a few seconds on, like Activity:CheckPlace: the companion is back out after the loading screen)
    C_Timer.After(5, function()
        if Pending() and Wish.ZoneOpen(ns.Plain(GetZoneText())) then Explored("zone") end
    end)
end
Wish.WATCH = WATCH

-- The explore wish's events while today's wish is an explore not done yet; none otherwise.
function Wish:Arm()
    local w = Stored()
    local want = (w and not w.done and w.id == "explore") and true or false
    if want == armed then return end
    armed = want
    if want then
        ns.Events:On("UI_INFO_MESSAGE", WATCH, OnDiscovered)
        ns.Events:On("CHAT_MSG_SYSTEM", WATCH, OnDiscovered)
        ns.Events:On("ZONE_CHANGED_NEW_AREA", WATCH, OnZone)
    else
        ns.Events:OffAll(WATCH)
    end
    ns.Log("Wish", "explore watch %s", want and "on" or "off")
end
function Wish:Watching() return armed end

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
    f.icon:SetTexture(ns.Stats.Icon(w.id) or ns.Icon("heart")) -- (the first that exists)
    if w.done then
        local run = self:Streak()
        f.text:SetText(run >= 2 and ns.T("wish.done.streak", { n = run }) or ns.L["wish.done"])
        f.text:SetTextColor(0.4, 1, 0.4)
        f.icon:SetDesaturated(false)
    else
        f.text:SetText(ns.T("wish.line", { pet = ns.Registry:NameOf(key), activity = ns.Personality.NOUN[w.id] }))
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
