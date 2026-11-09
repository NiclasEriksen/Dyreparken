local _, ns = ...

-- Auto-summon the reserved companion when none is out.
--
-- As unintrusive as possible: only when you're idle (decided 2026-11-06).
-- Not in combat, mounted, on a taxi, flying, dead, stealthed, sitting,
-- eating/drinking, casting or channeling, or in a battleground/arena.
--
-- Only when NO companion is out: one you summoned yourself is left alone.
--
-- Dormant by design: no OnUpdate. A few events trigger a check (entering the
-- world, combat end, dismount, claiming). A pet you dismiss yourself is NOT
-- noticed until the next of those (decided 2026-11-06): COMPANION_UPDATE
-- would catch it, but it fires for every nearby player's companion too.
--
-- If the check finds you busy, it retries every RETRY_EVERY seconds for up to
-- RETRY_FOR seconds, then waits for the next trigger. One timer at most.
--
-- Defers to AutoCompanion: if it's loaded, auto-summon is off and we say so
-- once per session.
--
-- Forever quirks (from AutoCompanion):
--  * C_PetJournal.SummonPetByGUID toggles: called on the pet that's out, it
--    dismisses it. We only call it when no pet of ours is out.
--  * There's a short companion-only cooldown (~1.1 s after a pet appears;
--    "Ability is not ready yet"). A retry covers it.
--  * Food/drink buffs are found by spell name (the client's language), via
--    C_UnitAuras.GetAuraDataBySpellName; auras can be secret, so a secret or
--    unreadable answer counts as "busy".
local Summon = {}
ns.Summon = Summon

local RETRY_EVERY, RETRY_FOR = 3, 60
local MAX_ATTEMPTS = 3 -- actual summon calls per trigger; each failure shows an error

function Summon:Deferring()
    return C_AddOns.IsAddOnLoaded("AutoCompanion")
end

-- The pet auto-summon keeps out (2026-11-09: independent of adoption): the
-- one picked on its card ("Hold ute"), else your adopted pet; nil while
-- auto-summon is off (unticked on the card).
function Summon:ActiveKey()
    local char = ns.DB.char
    if not char or not char.autoSummon or self:Deferring() then return nil end
    return char.activePet or ns.Registry:MyPet()
end

-- Make a pet the active one (on), or turn auto-summon off (its box unticked).
function Summon:SetActive(key, on)
    local char = ns.DB.char
    if on then
        char.activePet, char.autoSummon = key, true
    elseif self:ActiveKey() == key then
        char.autoSummon = false
    end
    ns.Log("Summon", "active: %s", tostring(self:ActiveKey()))
    self:Watch()
    ns.Bus:Fire("ACTIVE_PET", self:ActiveKey())
    if on then self:Check("active") end
end

function Summon:Enabled()
    return ns.DB.char.autoSummon and not self:Deferring()
end

-- The Auto-summon checkbox (per character). Turning it on checks right away.
function Summon:SetEnabled(on)
    ns.DB.char.autoSummon = on
    ns.Log("Summon", "auto-summon %s", on and "on" or "off")
    self:Watch()
    if on then self:Check("enabled") end
end


-- Out of combat these are plain values; a secret value counts as busy.
local function Truthy(v)
    if issecretvalue and issecretvalue(v) then return true end
    return v and true or false
end

-- Food, Drink, Refreshment, Food & Drink: names in the client's language,
-- with the English names as a fallback.
local EATING_SPELLS = { 433, 430, 43180, 45548 }
local eatingNames
local function EatingNames()
    if eatingNames then return eatingNames end
    eatingNames = { ["Food"] = true, ["Drink"] = true, ["Refreshment"] = true, ["Food & Drink"] = true }
    for _, id in ipairs(EATING_SPELLS) do
        local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
        if type(name) == "string" and name ~= "" then eatingNames[name] = true end
    end
    return eatingNames
end

local function Eating()
    local byName = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
    if not byName then return false end
    if C_Secrets and C_Secrets.ShouldAurasBeSecret and C_Secrets.ShouldAurasBeSecret() then return true end
    for name in pairs(EatingNames()) do
        local ok, data = pcall(byName, "player", name, "HELPFUL")
        if not ok then return true end
        if data then return true end
    end
    return false
end

-- Stand state: AutoCompanion treats 0 and 7 as standing, anything else as
-- sitting/lying. (unverified on Forever whether UnitStandState exists.)
local function Sitting()
    if type(UnitStandState) ~= "function" then return false end
    local ok, state = pcall(UnitStandState, "player")
    return ok and type(state) == "number" and state ~= 0 and state ~= 7
end

-- Why we can't summon right now, or nil when idle.
local function Busy()
    if ns.InCombat() then return "combat" end
    if Truthy(UnitIsDeadOrGhost("player")) then return "dead" end
    if Truthy(IsMounted()) then return "mounted" end
    if Truthy(UnitOnTaxi("player")) then return "taxi" end
    if IsFlying and Truthy(IsFlying()) then return "flying" end
    if IsStealthed and Truthy(IsStealthed()) then return "stealthed" end
    if Truthy(UnitCastingInfo("player")) or Truthy(UnitChannelInfo("player")) then return "casting" end
    if Sitting() then return "sitting" end
    if Eating() then return "eating" end
    local _, kind = IsInInstance()
    if kind == "pvp" or kind == "arena" then return "pvp" end
    return nil
end
Summon.Busy = Busy

local retryUntil, retrying
local attempts = 0

function Summon:Check(reason)
    if not self:Enabled() then return end
    local key = self:ActiveKey()
    if not key then return end
    -- Any companion out counts: never replace one you summoned yourself.
    local out = ns.Activity.Plain(ns.Pets:Summoned()) -- (a secret would throw in tostring below)
    -- Every check is logged (not only summons): checks while a pet is out
    -- are how a stray trigger shows up in the log.
    ns.Log("Summon", "check (%s): out=%s", tostring(reason), tostring(out))
    if out then return end
    local guid = ns.Pets:Owned()[key]
    if not guid then return end

    local busy = Busy()
    if busy then
        ns.Log("Summon", "busy: %s", busy)
        -- PvP is a place, not a moment: don't keep polling there.
        if busy ~= "pvp" then self:Retry(reason) end
        return
    end
    if reason ~= "retry" and reason ~= "verify" then attempts = 0 end
    if attempts >= MAX_ATTEMPTS then
        ns.Log("Summon", "giving up on %s after %d attempts", key, attempts)
        retryUntil = nil
        return
    end
    attempts = attempts + 1
    ns.Log("Summon", "summoning %s (%s, attempt %d)", key, tostring(reason), attempts)
    C_PetJournal.SummonPetByGUID(guid)
    -- Verify, and retry if the cooldown or something else refused it.
    self:Retry("verify")
end

function Summon:Retry(reason)
    local now = GetTime()
    if reason ~= "retry" then retryUntil = now + RETRY_FOR end
    if retrying or not retryUntil or now > retryUntil then return end
    retrying = true
    C_Timer.After(RETRY_EVERY, function()
        retrying = false
        if GetTime() <= retryUntil then Summon:Check("retry") end
    end)
end

------------------------------------------------------------------------------
-- Quiet summons
------------------------------------------------------------------------------
-- Summoning a companion on Forever plays a metal clank and an armour sound
-- (file IDs found by AutoCompanion, see docs/FOREVER_API.md). The game uses
-- both elsewhere too (item pickup, gear), so they're muted only for a moment
-- after a summon call, ours or the journal's. The mute is per character
-- (default on). WoW forgets sound mutes on reload, so nothing can stick.
local SUMMON_SOUNDS = { 567569, 568424 }
local QUIET_FOR = 2.5 -- the sound comes with the server's answer, plus the ~1 s cooldown retry
local quietGen, quiet = 0, false

local function SetMuted(on)
    local fn = on and MuteSoundFile or UnmuteSoundFile
    if not fn then return end
    for _, id in ipairs(SUMMON_SOUNDS) do fn(id) end
end

function Summon:QuietSummon()
    if not ns.DB.char.muteSummonSound then return end
    if not quiet then SetMuted(true); quiet = true end
    quietGen = quietGen + 1
    local gen = quietGen
    C_Timer.After(QUIET_FOR, function()
        if gen ~= quietGen then return end
        quiet = false
        SetMuted(false)
    end)
end

function Summon:SetMuteSound(on)
    ns.DB.char.muteSummonSound = on
    ns.Log("Summon", "summon sound %s", on and "muted" or "on")
    if not on and quiet then
        quiet, quietGen = false, quietGen + 1
        SetMuted(false)
    end
end

function Summon:Init()
    if self:Deferring() then
        -- AutoCompanion has its own mute option; two mutes would unmute each other early.
        ns.Log("Summon", "AutoCompanion loaded, auto-summon off")
        return
    end
    -- A post-hook: the sound comes later, with the server's answer. Also
    -- catches the journal's Summon button and other addons.
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function() Summon:QuietSummon() end)
    self:Watch()
    -- Just adopted one: it becomes the active pet, out it comes.
    ns.Bus:On("MY_RECORD", function(_, r)
        if r.k and ns.DB.char.activePet ~= r.k then
            ns.DB.char.activePet = r.k
            ns.Bus:Fire("ACTIVE_PET", Summon:ActiveKey())
        end
        Summon:Watch()
        if r.k then Summon:Check("claimed") end
    end)
end

-- The triggers, registered only while auto-summon can do anything: it's on,
-- and there's an adopted pet (every mount change started a timer before).
local watching = false
function Summon:Watch()
    local want = self:Enabled() and self:ActiveKey() ~= nil
    if want == watching then return end
    watching = want
    if not want then
        for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED", "PLAYER_MOUNT_DISPLAY_CHANGED" }) do
            ns.Events:Off(e, Summon)
        end
        return
    end
    -- After a loading screen the summon can fail: give the world a moment.
    ns.Events:On("PLAYER_ENTERING_WORLD", Summon, function()
        C_Timer.After(3, function() Summon:Check("PLAYER_ENTERING_WORLD") end)
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", Summon, function(_, event) Summon:Check(event) end)
    -- Landing / dismounting is when the pet usually goes missing.
    ns.Events:On("PLAYER_MOUNT_DISPLAY_CHANGED", Summon, function()
        C_Timer.After(1.5, function() Summon:Check("dismount") end)
    end)
end

function Summon:AnnounceDeferral()
    if self:Deferring() and ns.DB.char.autoSummon then
        ns.Print(ns.L["summon.deferred"])
    end
end
