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
-- The nickname takes the title line, and the species moves to a new line 2.
-- A tooltip can't insert lines, so one is added at the end and every line
-- from 2 down shifts by one. Each line keeps its own font string, so the
-- title keeps the header font.
--
-- The tooltip data gets the same shift. Tooltip addons that draw their own
-- panel read it instead of the font strings (PrettyTooltip: the title is
-- data.lines[1], and native lines whose lineIndex the data doesn't list are
-- appended as extras, so without the shift its title stays the species and
-- the moved last line shows twice; seen 2026-11-08).
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

local Plain = ns.Plain

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

local function Line(tooltip, side, i)
    return _G[tooltip:GetName() .. "Text" .. side .. i]
end

local function CopyLine(tooltip, side, from, to)
    local src, dst = Line(tooltip, side, from), Line(tooltip, side, to)
    if not (src and dst) then return end
    if src:IsShown() then
        dst:SetText(src:GetText())
        dst:SetTextColor(src:GetTextColor())
        dst:Show()
    else
        dst:SetText(nil)
        dst:Hide()
    end
end

local function ShiftData(data, species, nick)
    local lines = type(data) == "table" and data.lines
    local first = type(lines) == "table" and lines[1]
    if type(first) ~= "table" or Plain(first.leftText) ~= species then return end
    for _, line in ipairs(lines) do
        local index = type(line) == "table" and Plain(line.lineIndex)
        if type(index) == "number" and index >= 2 then line.lineIndex = index + 1 end
    end
    first.leftText = nick
    table.insert(lines, 2, { type = 0, leftText = species, leftColor = { r = 0.7, g = 0.7, b = 0.7 },
        lineIndex = type(Plain(first.lineIndex)) == "number" and first.lineIndex + 1 or nil })
end

-- Title line = nickname, line 2 = the species name it replaced.
function Tooltip:ShowNickname(tooltip, nick, data)
    local title = Line(tooltip, "Left", 1)
    local species = title and Plain(title:GetText())
    if type(species) ~= "string" or species == nick then return end
    local n = tooltip:NumLines()
    tooltip:AddLine(" ")
    for i = n + 1, 3, -1 do
        CopyLine(tooltip, "Left", i - 1, i)
        CopyLine(tooltip, "Right", i - 1, i)
    end
    title:SetText(nick)
    local second, right = Line(tooltip, "Left", 2), Line(tooltip, "Right", 2)
    second:SetText(species)
    second:SetTextColor(0.7, 0.7, 0.7)
    second:Show()
    if right then right:SetText(nil); right:Hide() end
    ShiftData(data, species, nick)
end

-- A companion the client has no name for yet shows as "Unknown"
-- (UNKNOWNOBJECT), on its nameplate and as the tooltip's title: new species
-- not in the journal, e.g. Azurky (5179), seen 2026-11-09. Its species id
-- still gives the name, so the title gets it (the nameplate is the game's).
function Tooltip:NameUnknown(tooltip, data, unit)
    local title = Line(tooltip, "Left", 1)
    local text = title and Plain(title:GetText())
    if text ~= (UNKNOWNOBJECT or "Unknown") then return end
    if not Plain(UnitIsBattlePetCompanion and UnitIsBattlePetCompanion(unit)) then return end
    local sid = Plain(UnitBattlePetSpeciesID and UnitBattlePetSpeciesID(unit))
    local name = type(sid) == "number" and C_PetJournal.GetPetInfoBySpeciesID(sid)
    name = Plain(name)
    if type(name) ~= "string" or name == "" then return end
    title:SetText(name)
    local first = type(data) == "table" and type(data.lines) == "table" and data.lines[1]
    if type(first) == "table" and Plain(first.leftText) == text then first.leftText = name end
    tooltip:Show()
    ns.Log("Tooltip", "named an unknown companion: species %d = %s", sid, name)
end

local function OnUnitTooltip(tooltip, data)
    if tooltip ~= GameTooltip or ns.InCombat() then return end
    local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
    unit = ok and Plain(unit)
    if not unit then return end
    Tooltip:NameUnknown(tooltip, data, unit)
    local owner, r = Tooltip:ReservationOf(unit, data and data.lines)
    if not owner then return end
    local nick = ns.Registry:Nickname(r.k)
    if nick then Tooltip:ShowNickname(tooltip, nick, data) end
    local who = owner == ns.PlayerKey() and ns.L["home.you"] or owner
    local home = ns.Home(who, r.at)
    tooltip:AddLine(ns.T("tip.world", { home = home:sub(1, 1):lower() .. home:sub(2), level = select(3, ns.Bond:Of(r.k)) }),
        0.5, 0.8, 0.5)
    -- Resizes the tooltip to the changed lines, not only the added ones.
    if nick then tooltip:Show() end
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

ns.Start("loaded", function() Tooltip:Init() end)
