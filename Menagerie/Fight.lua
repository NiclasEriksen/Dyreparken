local _, ns = ...

-- The pet joins your fights (2026-11-12, the user: "it looks like the pet is trying to be part of combat,
-- not necessarily that it's accurate"). On the pet frame only (the card is shut in a fight), now and then:
-- an attack move, or a timid pet cowers, by its traits.
--
-- No combat log on Forever (docs/FOREVER_API.md, /dp probe api combat): UNIT_COMBAT on the target fires each
-- hit, with its school and flags (CRITICAL) plain and its amount secret, but not who hit. So a "swing" is a
-- physical hit on your target while your own auto-attack (or auto shot) is on, at most one per swing of
-- your weapon (in a group others' hits come too: they only fill in the rhythm). Each cast of yours in a
-- fight is a chance as well. A roll per swing, at most one move every GAP seconds; a crit is likelier.
--
-- Cheap: nothing at all out of combat but the two combat events; in a fight, a frame of its own with
-- UNIT_COMBAT for the target only and your casts, and only while the pet frame shows a pet that joins in.
local Fight = {}
ns.Fight = Fight

-- Solo it may join in more (2026-11-12, the user: "a little bit too rare when solo"); in a group less,
-- with more going on (and others' hits filling in the swings).
Fight.CHANCE = { solo = 0.45, group = 0.2 }          -- a swing or a cast: the pet's move, maybe
Fight.FIGHTER_CHANCE = { solo = 0.7, group = 0.35 }  -- ... for a fighter
Fight.CRIT_BONUS = 0.3       -- added for a critical hit
Fight.START_CHANCE = 0.6     -- the fight's start: a pounce (a cower)
Fight.GAP = { solo = 3, group = 5 } -- seconds, at least, between two moves
Fight.SWING = 2.5            -- seconds: a swing when the weapon's speed can't be read
Fight.SWING_SHARE = 0.8      -- a hit counts as a swing this share of a swing after the last
Fight.PHYSICAL = 1           -- UNIT_COMBAT's school mask: white damage

-- By traits (Personality.TRAITS' `is`; a fighter trait wins over the others): they attack more;
-- the timid cower; a watcher (a Latsabb) watches. "fighter", "timid", "watch" or "normal".
function Fight.Nature(key)
    local P = ns.Personality
    if P:Tagged(key, "fighter") then return "fighter" end
    if P:Tagged(key, "timid") then return "timid" end
    if P:Tagged(key, "watcher") then return "watch" end
    return "normal"
end

local frame -- (in a fight only)
local key, nature, swing, attacking, autoRepeat, lastSwing, lastMove

-- The pet on the pet frame, shown, that joins in: its key, or nil.
local function Pet()
    local PF = ns.PetFrame
    local f = PF and PF.on and PF.frame
    -- (hidden in combat: PF.combatOn, its setting; read here, since its own handler may come after ours)
    if not (f and f:IsShown() and PF.key) or PF.combatOn then return nil end
    return PF.key
end

local function Number(fn, ...)
    local ok, v = pcall(fn, ...)
    v = ok and ns.Plain(v) or nil
    return type(v) == "number" and v > 0 and v or nil
end

local function Swing()
    if autoRepeat then
        local ranged = rawget(_G, "UnitRangedDamage") and Number(UnitRangedDamage, "player")
        if ranged then return ranged end
    end
    return Number(UnitAttackSpeed, "player") or Fight.SWING
end

local function Attacking()
    local S = rawget(_G, "C_Spell")
    if not (S and S.IsCurrentSpell) then return false end
    local ok, v = pcall(S.IsCurrentSpell, 6603) -- (Attack)
    return ok and ns.Plain(v) == true
end

-- A moment the pet may join in: chance on top of its own.
function Fight:Moment(extra, why)
    if not key or Pet() ~= key or nature == "watch" then return end
    local now = GetTime()
    local how = IsInGroup() and "group" or "solo"
    if lastMove and now - lastMove < self.GAP[how] then return end
    local p = (nature == "fighter" and self.FIGHTER_CHANCE or self.CHANCE)[how] + (extra or 0)
    if ns.random() >= p then return end
    local what = nature == "timid" and "cower" or "attack"
    if ns.PetFrame.stage:Act(key, what) then
        lastMove = now
        ns.Log("Fight", "%s %s (%s, %s)", tostring(key), what, nature, why)
    end
end

local function OnEvent(_, event, unit, action, flag, _, school)
    if event == "UNIT_COMBAT" then
        if unit ~= "target" or not (attacking or autoRepeat) then return end
        local now = GetTime()
        if lastSwing and now - lastSwing < swing * Fight.SWING_SHARE then return end
        if ns.Plain(school) ~= Fight.PHYSICAL then return end
        lastSwing = now
        return Fight:Moment(ns.Plain(flag) == "CRITICAL" and Fight.CRIT_BONUS or 0, "swing")
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        return Fight:Moment(0, "cast")
    elseif event == "PLAYER_ENTER_COMBAT" then
        attacking = true
    elseif event == "PLAYER_LEAVE_COMBAT" then
        attacking = false
    elseif event == "START_AUTOREPEAT_SPELL" then
        autoRepeat = true
    elseif event == "STOP_AUTOREPEAT_SPELL" then
        autoRepeat = false
    end
    swing = Swing()
end

Fight.EVENTS = { "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL" }

function Fight:Start()
    key = Pet()
    nature = key and self.Nature(key)
    if not key or nature == "watch" then key = nil; return end
    frame = frame or CreateFrame("Frame")
    frame:SetScript("OnEvent", OnEvent)
    for _, e in ipairs(self.EVENTS) do pcall(frame.RegisterEvent, frame, e) end
    pcall(frame.RegisterUnitEvent, frame, "UNIT_COMBAT", "target")
    pcall(frame.RegisterUnitEvent, frame, "UNIT_SPELLCAST_SUCCEEDED", "player")
    attacking, autoRepeat, lastSwing, lastMove = Attacking(), false, nil, nil
    swing = Swing()
    ns.Log("Fight", "%s joins in (%s), swing %.1f s, attacking %s", key, nature, swing, tostring(attacking))
    -- The fight's start: a pounce (or a cower), likely.
    local how = IsInGroup() and "group" or "solo"
    self:Moment(self.START_CHANCE - (nature == "fighter" and self.FIGHTER_CHANCE or self.CHANCE)[how], "start")
end

function Fight:Stop()
    if frame then frame:UnregisterAllEvents() end
    key = nil
end

-- While the pet frame is on (PetFrame:On/Off): the fights' start and end.
function Fight:Watch(on)
    if on then
        ns.Events:On("PLAYER_REGEN_DISABLED", Fight, function() Fight:Start() end)
        ns.Events:On("PLAYER_REGEN_ENABLED", Fight, function() Fight:Stop() end)
    else
        ns.Events:Off("PLAYER_REGEN_DISABLED", Fight)
        ns.Events:Off("PLAYER_REGEN_ENABLED", Fight)
        self:Stop()
    end
end
