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
    end
    return w
end

function Wish:OnActivity(id, key)
    local w = self:Today()
    if not w or w.done or w.pet ~= key or w.id ~= id then return end
    w.done = true
    ns.Bond:Reward("wish", key, ns.T("wish.granted", { pet = ns.Registry:NameOf(key),
        activity = ns.Personality.NOUN[id], n = ns.Config.BOND_WISH_POINTS }))
    self:Count(w.day)
end

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
    f:SetScript("OnEnter", function(self)
        local w = Wish:Today()
        if not w then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText(ns.L["wish.title"], 1, 0.82, 0)
        GameTooltip:AddLine(ns.T(w.done and "wish.tip.done" or "wish.tip", { pet = ns.Registry:NameOf(w.pet),
            n = ns.Config.BOND_WISH_POINTS }), 1, 1, 1, true)
        local run, counted = Wish:Streak()
        if counted and run >= 2 then
            GameTooltip:AddLine(ns.T("wish.streak.tip", { n = run }), 0.4, 1, 0.4, true)
        elseif not counted and run >= 1 then
            GameTooltip:AddLine(ns.T("wish.streak.keep", { n = run + 1 }), 1, 0.82, 0, true)
        end
        GameTooltip:Show()
    end)
    f:SetScript("OnLeave", ns.HideTip)
    f:Hide()
    card.wish = f
end

function Wish:Update(card, key)
    local f = card.wish
    if not f then return end
    local w = key and self:Today()
    if not w or w.pet ~= key then f:Hide(); return end
    f.icon:SetTexture(ns.Stats.Icon(w.id) or (ns.Decor.MEDIA .. "heart")) -- (the first that exists)
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

ns.Start("login", function() Wish:Init() end)
