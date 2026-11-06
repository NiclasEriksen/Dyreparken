local _, ns = ...

-- Reservation info on companion tooltips in the world.
--
-- A companion unit (probed 2026-11-06, build 70790, another player's White Kitten):
--   UnitIsBattlePetCompanion(unit) = true
--   UnitBattlePetSpeciesID(unit)   = 46
--   UnitCreator(unit)              = nil (no API for the owner)
--   tooltip line 2                 = "Gnikke Guri's Companion"
-- So the owner comes from the tooltip text, matched with the game's own
-- format string (UNITNAME_TITLE_COMPANION, "%s's Companion"), which keeps it
-- working in other client languages.
--
-- Lines are only added when the companion's owner is also the one holding
-- the reservation, so a nickname never shows on someone else's copy of the
-- same pet.
--
-- (unverified) whether the unit's species ID uses the same numbering as the
-- journal (Panda Cub = 5159 in the journal). `/dp probe more` with your own
-- companion targeted answers it.
--
-- Skipped in combat: tooltip text and unit data can be secret values then.
local Tooltip = {}
ns.Tooltip = Tooltip

local ownerPattern
local function OwnerPattern()
    if not ownerPattern then
        local fmt = UNITNAME_TITLE_COMPANION or "%s's Companion"
        -- Escape pattern characters, then turn the %s into a capture.
        local escaped = fmt:gsub("([%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        ownerPattern = "^" .. escaped:gsub("%%s", "(.+)") .. "$"
    end
    return ownerPattern
end

local function Plain(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

-- Owner key ("First Surname") of a companion unit, from its tooltip text.
function Tooltip:OwnerOf(unit, lines)
    if not lines then
        local data = C_TooltipInfo and C_TooltipInfo.GetUnit and C_TooltipInfo.GetUnit(unit)
        lines = data and data.lines
    end
    if type(lines) ~= "table" then return nil end
    local pattern = OwnerPattern()
    for i = 2, math.min(#lines, 4) do
        local text = Plain(lines[i] and lines[i].leftText)
        if type(text) == "string" then
            local owner = text:match(pattern)
            if owner then return ns.NormalizeName(owner) end
        end
    end
end

-- The reservation shown on this companion unit: owner, record. Or nil.
function Tooltip:ReservationOf(unit, lines)
    if not Plain(UnitIsBattlePetCompanion and UnitIsBattlePetCompanion(unit)) then return nil end
    local sid = Plain(UnitBattlePetSpeciesID and UnitBattlePetSpeciesID(unit))
    if type(sid) ~= "number" then return nil end
    local owner = self:OwnerOf(unit, lines)
    if not owner then return nil end
    local holder, r = ns.Registry:Holder(ns.Pets:KeyOfSpecies(sid))
    if holder ~= owner then return nil end
    return owner, r
end

local function OnUnitTooltip(tooltip, data)
    if tooltip ~= GameTooltip or InCombatLockdown() then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    unit = ok and Plain(unit)
    if not unit then return end
    local owner, r = Tooltip:ReservationOf(unit, data and data.lines)
    if not owner then return end
    if r.n then tooltip:AddLine('"' .. r.n .. '"', 1, 0.82, 0) end
    local who = owner == ns.PlayerKey() and "you" or owner
    tooltip:AddLine(("Dyreparken: cared for by %s %s"):format(who, ns.CaredFor(r.at)), 0.5, 0.8, 0.5)
end

function Tooltip:Init()
    if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum.TooltipDataType) then
        ns.Log("Tooltip", "no TooltipDataProcessor; world tooltips off")
        return
    end
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        local ok, err = pcall(OnUnitTooltip, tooltip, data)
        if not ok then ns.Log("Tooltip", "error: %s", tostring(err)) end
    end)
end
