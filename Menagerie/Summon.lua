local _, ns = ...

-- Auto-summon the reserved companion when none is out.
--
-- Dormant by design: no OnUpdate, no timers. We react to a few events
-- (entering the world, combat end, the companion changing) and do at most
-- one check each time.
--
-- Defers to AutoCompanion: if it's loaded, auto-summon is off and we say so
-- once per session.
--
-- Forever quirks (from AutoCompanion):
--  * C_PetJournal.SummonPetByGUID toggles: called on the pet that's out, it
--    dismisses it. Always check GetSummonedPetGUID first.
--  * Summoning is blocked in combat; there's a short companion-only cooldown
--    (~1.1 s after a pet appears; "Ability is not ready yet").
--  * TODO: skip while mounted, on taxi, dead, stealthed/invisible, sitting,
--    eating/drinking, in arenas/battlegrounds (decide which).
local Summon = {}
ns.Summon = Summon

function Summon:Deferring()
    return C_AddOns.IsAddOnLoaded("AutoCompanion")
end

function Summon:Enabled()
    return ns.DB.char.autoSummon and not self:Deferring()
end

-- States where a summon fails or makes no sense. Out of combat these are
-- plain values, but treat a secret value as "blocked" to be safe.
local function Truthy(v)
    if issecretvalue and issecretvalue(v) then return true end
    return v and true or false
end
local function Blocked()
    if Truthy(IsMounted()) or Truthy(UnitOnTaxi("player")) or Truthy(UnitIsDeadOrGhost("player")) then
        return true
    end
    if IsFlying and Truthy(IsFlying()) then return true end
    return false
end

function Summon:Check(reason)
    if not self:Enabled() or ns.InCombat() or Blocked() then return end
    local key = ns.Registry:MyPet()
    if not key then return end
    local out = ns.Pets:Summoned()
    if out and ns.Pets:KeyOf(out) == key then return end
    local guid = ns.Pets:Owned()[key]
    if not guid then return end
    ns.Log("Summon", "summoning %s (%s)", key, tostring(reason))
    -- TODO: stealth, sitting, eating/drinking, BG/arena (open question), and
    -- the cooldown retry.
    C_PetJournal.SummonPetByGUID(guid)
end

function Summon:Init()
    if self:Deferring() then
        ns.Log("Summon", "AutoCompanion loaded, auto-summon off")
        return
    end
    local function check(_, event) Summon:Check(event) end
    -- After a loading screen the summon can fail: give the world a moment.
    ns.Events:On("PLAYER_ENTERING_WORLD", Summon, function()
        C_Timer.After(3, function() Summon:Check("PLAYER_ENTERING_WORLD") end)
    end)
    ns.Events:On("PLAYER_REGEN_ENABLED", Summon, check)
    -- Landing / dismounting is when the pet usually goes missing.
    ns.Events:On("PLAYER_MOUNT_DISPLAY_CHANGED", Summon, function()
        C_Timer.After(1.5, function() Summon:Check("dismount") end)
    end)
    -- Just reserved one: bring it out.
    ns.Bus:On("MY_RECORD", function(_, r)
        if r.k then Summon:Check("claimed") end
    end)
    -- TODO: COMPANION_UPDATE / pet changed event on Forever (verify name).
end

function Summon:AnnounceDeferral()
    if self:Deferring() and ns.DB.char.autoSummon then
        ns.Print("AutoCompanion is loaded, so Dyreparken won't auto-summon. Your reservation still shows to the guild.")
    end
end
