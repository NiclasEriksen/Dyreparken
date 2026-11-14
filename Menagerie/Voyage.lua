local _, ns = ...

-- Zeppelins and boats (0.5, 2026-11-12, the user: "tie into fear of flying / love of flying like flight paths do";
-- the richer kind, boats too). The client has no API for being on a transport; /dp probe api transport showed what
-- a ride looks like (docs/FOREVER_API.md, a zeppelin from Grom'gol to Durotar): LOADING_SCREEN_ENABLED halfway,
-- then PLAYER_ENTERING_WORLD on the other continent, and the zone's name only right at ZONE_CHANGED_NEW_AREA a
-- few seconds later. So a ride is: a loading screen between two zones a route joins (ROUTES), not after a
-- hearthstone, teleport, portal or recall (cast within CAST_FOR seconds before), and not into or out of an
-- instance. Which route says which kind (Stranglethorn has both: Grom'gol's zeppelin, Booty Bay's boat).
--   zeppelin  counts as flying too (Activity "taxi": the flight lovers' points, the fearful's grumbles), and its
--             own activity for the remarks (egg "luftskip")
--   boat      its own activity, remarks only (egg "seilas"): pirates sing, cats get seasick...
-- A loading screen between two zones no route knows (Forever's own?) is logged, to add.
-- The zones are those of the loading screen's moment and of the arrival, both at sea, not the docks' own: the boat
-- from Ratchet reads "Durotar" halfway (2026-11-14, the user: a friend's pet said zeppelin lines on the boat to
-- Booty Bay), so Durotar to Stranglethorn is either kind. A pair both kinds list is decided by where you are on
-- the map of the end in SPLIT (Grom'gol's tower is in the north of Stranglethorn, Booty Bay at its southern tip).
local Voyage = {}
ns.Voyage = Voyage

-- The routes, by the zones of their ends: Classic's, and Forever's six new ones (wowforever.be's table from the
-- 1.60.1 game files, 2026-11-12; Tanaris to Riverglades ridden and probed by the user). Only a ride with a
-- loading screen on the way is seen, so a route is only ever judged after one: one on a single continent counts
-- too (Undercity to Grom'gol has one, the user, 2026-11-12), and listing one that has none costs nothing (Menethil
-- to Southshore, Auberdine to Rut'theran: unknown). "*": any zone at the other end (Zephras Isle's zeppelins,
-- "skyboats", go to Dalaran and to Skywatcher Plateau, zones unconfirmed). Not seen: Feathermoon to the
-- Forgotten Coast (one zone, Feralas, at both ends).
Voyage.ROUTES = {
    zeppelin = { { "Durotar", "Tirisfal Glades" }, { "Durotar", "Stranglethorn Vale" },
        { "Tirisfal Glades", "Stranglethorn Vale" }, { "Zephras Isle", "*" } },
    boat = { { "Wetlands", "Dustwallow Marsh" }, { "Wetlands", "Darkshore" }, { "Stranglethorn Vale", "The Barrens" },
        { "Tanaris", "Riverglades" }, { "Stormwind City", "Darkshore" }, { "Hillsbrad Foothills", "Darkshore" },
        { "Wetlands", "Hillsbrad Foothills" }, { "Darkshore", "Teldrassil" },
        { "Durotar", "Stranglethorn Vale" } }, -- (Ratchet's boat, out at sea: SPLIT says which)
}
-- y on the zone's own map (0 north, 1 south): Grom'gol about 0.29, Booty Bay about 0.77 (classic's maps; the line
-- between them is a guess until a ride's log shows where the loading screens come: "... at x,y").
Voyage.SPLIT = { ["Stranglethorn Vale"] = { y = 0.55, north = "zeppelin", south = "boat" } }
Voyage.CAST_FOR = 15  -- seconds: a cast this soon before the loading screen took you there (a hearthstone...)
Voyage.NOT_A_RIDE = { "Hearth", "Teleport", "Portal", "Recall", "Astral" } -- (spell names, enUS)

local Plain = ns.Plain
local byPair = {}
for kind, list in pairs(Voyage.ROUTES) do
    for _, r in ipairs(list) do
        for _, key in ipairs({ r[1] .. "\31" .. r[2], r[2] .. "\31" .. r[1] }) do
            byPair[key] = (byPair[key] and byPair[key] ~= kind) and "either" or kind
        end
    end
end

-- The casts that make a loading screen no ride go through the activity engine's one registration for the
-- player's casts (the zeppelin source reads them; it never counts anything itself: Voyage:Arrived does).
ns.Activity:Source({ id = "zeppelin", events = { "UNIT_SPELLCAST_SUCCEEDED" }, unit = "player",
    filter = function(_, _, _, spell) ns.Voyage:Cast(spell) end })
ns.Activity:Source({ id = "boat", events = {} })

-- The continent's map id the player is on (C_Map's parents up to a mapType 2), or nil.
function Voyage.Continent()
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    id = ok and Plain(id) or nil
    for _ = 1, 8 do
        local okI, info = pcall(C_Map.GetMapInfo, id)
        if not (okI and type(info) == "table") then return nil end
        if info.mapType == 2 then return info.mapID end
        id = info.parentMapID
    end
end

-- Where the player is on their zone's map (the parents up to a mapType 3), or nil.
function Voyage.Position()
    local ok, id = pcall(C_Map.GetBestMapForUnit, "player")
    id = ok and Plain(id) or nil
    for _ = 1, 8 do
        local okI, info = pcall(C_Map.GetMapInfo, id)
        if not (okI and type(info) == "table") or info.mapType == 2 then return nil end
        if info.mapType == 3 then break end
        id = info.parentMapID
    end
    local okP, pos = pcall(C_Map.GetPlayerMapPosition, id, "player")
    if not (okP and type(pos) == "table" and pos.GetXY) then return nil end
    local x, y = pos:GetXY()
    x, y = Plain(x), Plain(y)
    if type(x) == "number" and type(y) == "number" then return x, y end
end

local function Here()
    local inside = IsInInstance()
    local x, y = Voyage.Position()
    return { zone = Plain(GetZoneText()), continent = Voyage.Continent(), instance = Plain(inside) == true, x = x, y = y }
end

local from, lastCast, arriving
function Voyage:Cast(spell)
    local name = ns.SpellName(Plain(spell))
    if not name then return end
    for _, word in ipairs(self.NOT_A_RIDE) do
        if name:find(word, 1, true) then lastCast = GetTime(); return end
    end
end

-- The kind of ride from one place to another, or nil.
function Voyage.Kind(a, b)
    if not (a and b and a.zone and b.zone) or a.instance or b.instance then return nil end
    -- (only ever after a loading screen: a route on one continent counts, Undercity to Grom'gol)
    local kind = byPair[a.zone .. "\31" .. b.zone] or byPair[a.zone .. "\31*"] or byPair["*\31" .. b.zone]
    if kind ~= "either" then return kind end
    for _, p in ipairs({ a, b }) do
        local split = Voyage.SPLIT[p.zone]
        if split and p.y then return p.y < split.y and split.north or split.south end
    end
    return nil -- (no position: better no remark than the wrong one)
end

function Voyage:Arrived()
    if not arriving then return end
    arriving = nil
    local a, b = from, Here()
    from = b
    if not a then return end
    if a.cast then return ns.Log("Voyage", "%s -> %s: a cast took you there", tostring(a.zone), tostring(b.zone)) end
    local kind = Voyage.Kind(a, b)
    if not kind then
        if a.continent ~= b.continent and not (a.instance or b.instance) then
            ns.Log("Voyage", "an unknown way between continents: %s at %s,%s -> %s at %s,%s", tostring(a.zone),
                tostring(a.x), tostring(a.y), tostring(b.zone), tostring(b.x), tostring(b.y))
        end
        return
    end
    ns.Log("Voyage", "%s: %s at %s,%s -> %s at %s,%s", kind, tostring(a.zone), tostring(a.x), tostring(a.y),
        tostring(b.zone), tostring(b.x), tostring(b.y))
    ns.Activity:Emit(kind, 1, a.zone .. "\31" .. b.zone)
    if kind == "zeppelin" then ns.Activity:Emit("taxi", 1) end -- (flying: the flight lovers' and the fearful's)
end

-- Only while something wants the rides (Quirks' eggs, always): the events, on the shared frame.
function Voyage:Init()
    -- Our own want of the zeppelin source, for its cast filter: without it a hearthstone's loading
    -- screen could pass for a ride whenever no egg happened to want "zeppelin". Free: the gathering
    -- activities (always watched) keep UNIT_SPELLCAST_SUCCEEDED registered anyway.
    ns.Activity:Want("zeppelin", Voyage)
    ns.Events:On("LOADING_SCREEN_ENABLED", Voyage, function()
        -- (where we leave from: the zone and continent are still ours here, not at PLAYER_LEAVING_WORLD)
        from = Here()
        from.cast = lastCast ~= nil and GetTime() - lastCast <= Voyage.CAST_FOR
        lastCast, arriving = nil, nil
    end)
    ns.Events:On("PLAYER_ENTERING_WORLD", Voyage, function(_, _, login, reload)
        if Plain(login) or Plain(reload) then from, arriving = Here(), nil; return end -- (no ride)
        arriving = true
    end)
    -- The zone's name is right only now (the probe: a few seconds after the world loaded). A route always
    -- changes zones, so a ride always brings this.
    ns.Events:On("ZONE_CHANGED_NEW_AREA", Voyage, function() Voyage:Arrived() end)
end

ns.Start("login", function() Voyage:Init() end)
