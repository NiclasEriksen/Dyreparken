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

function Summon:Check(reason)
    if not self:Enabled() or ns.InCombat() then return end
    local key = ns.Registry:Mine()
    if not key then return end
    local out = ns.Pets:Summoned()
    if out and ns.Pets:KeyOf(out) == key then return end
    local guid = ns.Pets:Owned()[key]
    if not guid then return end
    ns.Log("Summon", "summoning %s (%s)", key, tostring(reason))
    -- TODO: the blockers listed above, and the cooldown retry.
    C_PetJournal.SummonPetByGUID(guid)
end

function Summon:Init()
    if self:Deferring() then
        ns.Log("Summon", "AutoCompanion loaded, auto-summon off")
        return
    end
    local function check(_, event) Summon:Check(event) end
    ns.Events:On("PLAYER_ENTERING_WORLD", Summon, check)
    ns.Events:On("PLAYER_REGEN_ENABLED", Summon, check)
    -- TODO: COMPANION_UPDATE / pet changed event on Forever (verify name).
end

function Summon:AnnounceDeferral()
    if self:Deferring() and ns.DB.char.autoSummon then
        ns.Print("AutoCompanion is loaded, so Dyreparken won't auto-summon. Your reservation still shows to the guild.")
    end
end
