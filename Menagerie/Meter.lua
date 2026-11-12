local _, ns = ...

-- The pet and the damage meter (0.5, 2026-11-12, the user; probed: docs/FOREVER_API.md, docs/IDEAS.md).
--
-- After a boss kill in a group, with a pet out, the pet may react to how you did: first in damage (in a
-- dungeon or a raid), first in healing (in a raid only: in a five-man the one healer is always first), most
-- interrupts. Flavor only (Quirks' eggs: lines, a bubble on the pet frame, a cheer), no points; likelier in
-- a raid and for a very good result (well ahead of the next).
--
-- How (no polling: one read per boss kill): Activity's "boss" comes after combat with the pet that was out;
-- READ_AFTER seconds later the meter's Current session (type 1) is that boss fight alone, in plain numbers,
-- its sources sorted highest first, ours marked isLocalPlayer. In combat it's all secret, so never then.
local Meter = {}
ns.Meter = Meter

Meter.READ_AFTER = 1     -- seconds after the boss activity (the probe read a second after combat)
Meter.MIN_GROUP = 3      -- group members, at least: first of two isn't much
Meter.MIN_KICKS = 2      -- interrupts of ours, at least, to count as the most
Meter.SESSION = 1        -- Enum.DamageMeterSessionType: Current
Meter.DAMAGE, Meter.HEALING, Meter.INTERRUPTS = 0, 2, 5 -- Enum.DamageMeterType
Meter.FAR_AHEAD = 1.5    -- ours this many times the next one's: a very good result

for _, id in ipairs({ "dmgtop", "healtop", "kicktop" }) do
    ns.Activity:Source({ id = id, events = {}, available = function() return rawget(_G, "C_DamageMeter") ~= nil end })
end

-- Our place in one kind of the last fight: place, our amount, the next one's (or nil: unreadable, secret, or
-- we're not in it).
function Meter.Place(kind)
    local DM = rawget(_G, "C_DamageMeter")
    if not (DM and DM.GetCombatSessionFromType) then return nil end
    local ok, s = pcall(DM.GetCombatSessionFromType, Meter.SESSION, kind)
    if not ok or type(s) ~= "table" or ns.IsSecret(s) then return nil end
    local sources = s.combatSources
    if type(sources) ~= "table" or ns.IsSecret(sources) then return nil end
    for i, src in ipairs(sources) do
        if type(src) == "table" and src.isLocalPlayer == true then
            local mine = ns.Plain(src.totalAmount)
            local other = sources[i == 1 and 2 or 1]
            local next = type(other) == "table" and ns.Plain(other.totalAmount) or 0
            if type(mine) ~= "number" or type(next) ~= "number" then return nil end
            return i, mine, next
        end
    end
end

-- The last result: { raid, kind = "damage" | "healing" | "kicks", far = ahead by FAR_AHEAD } (the eggs read it).
Meter.last = nil

function Meter:Read()
    if not IsInGroup() or (GetNumGroupMembers() or 0) < self.MIN_GROUP then return end
    local raid = IsInRaid() == true
    local function Top(kind, word, activity, least)
        local place, mine, next = Meter.Place(kind)
        ns.Log("Meter", "%s: place %s, %s against %s", word, tostring(place), tostring(mine), tostring(next))
        if place ~= 1 or mine <= 0 or (least and mine < least) then return end
        Meter.last = { raid = raid, kind = word, far = next <= 0 or mine >= next * Meter.FAR_AHEAD }
        ns.Activity:Emit(activity, 1, word)
    end
    Top(self.DAMAGE, "damage", "dmgtop")
    if raid then Top(self.HEALING, "healing", "healtop") end
    Top(self.INTERRUPTS, "kicks", "kicktop", self.MIN_KICKS)
end

function Meter:Init()
    if not rawget(_G, "C_DamageMeter") then return end
    -- (the boss activity is watched always: the bond counts it)
    ns.Bus:On("ACTIVITY", function(id, _, key)
        if id ~= "boss" or not key then return end
        C_Timer.After(Meter.READ_AFTER, function() Meter:Read() end)
    end)
end

ns.Start("login", function() Meter:Init() end)
