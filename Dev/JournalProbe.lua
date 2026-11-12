local _, ns = ...

-- The journal's layout probes (development only, never packaged:
-- #@do-not-package@ in the TOC): /dp probe card and /dp probe tabs. They
-- extend ns.JournalUI and ns.AchPage.
local JournalUI, Page = ns.JournalUI, ns.AchPage

-- /dp probe card: what Blizzard's pet card is made of on Forever (2026-11-08:
-- to hide its title row, the pet's icon and name at the top, we need its
-- name). Logs the card's children and regions, two levels down: the key
-- they're stored under on their parent, the type, shown, size and anchor.
function JournalUI:ProbeCard()
    local c = rawget(_G, "PetJournalPetCard")
    if not c then return ns.Print("Open the pet journal first.") end
    local function KeyOf(parent, obj)
        for k, v in pairs(parent) do if v == obj and type(k) == "string" then return k end end
        return "-"
    end
    local function Describe(obj, parent, depth)
        local ok, kind = pcall(obj.GetObjectType, obj)
        local name = obj.GetName and obj:GetName() or nil
        local w, h
        if obj.GetSize then w, h = obj:GetSize() end
        local point, rel, relPoint, x, y = nil, nil, nil, nil, nil
        if obj.GetPoint then point, rel, relPoint, x, y = obj:GetPoint(1) end
        local relName = rel and ((rel.GetName and rel:GetName()) or KeyOf(parent, rel)) or "-"
        local text = obj.GetText and obj:GetText() or nil
        ns.Log("Probe", "card %s%s key=%s name=%s shown=%s size=%sx%s at=%s %s %s %s,%s%s", ("  "):rep(depth),
            tostring(ok and kind or "?"), KeyOf(parent, obj), tostring(name), tostring(obj.IsShown and obj:IsShown()),
            tostring(w and math.floor(w)), tostring(h and math.floor(h)), tostring(point), tostring(relName),
            tostring(relPoint), tostring(x and math.floor(x)), tostring(y and math.floor(y)),
            text and (" text=" .. tostring(text)) or "")
    end
    local function Walk(frame, depth)
        for _, r in ipairs({ frame:GetRegions() }) do Describe(r, frame, depth) end
        for _, child in ipairs({ frame:GetChildren() }) do
            Describe(child, frame, depth)
            if depth < 2 then Walk(child, depth + 1) end
        end
    end
    Walk(c, 0)
    ns.Print("Pet card probed; /reload and send the debug log.")
end

-- /dp probe tabs: what the side tabs look like, to match them.
function Page:Probe()
    local host = ns.SidePage:Host()
    if not host then return ns.Print("Open the pet journal first.") end
    local L = function(...) ns.Log("Probe", ...) end
    L("host %s %s right=%s level=%s", tostring(host:GetName()), host:GetObjectType(), tostring(host:GetRight()),
        tostring(host:GetFrameLevel()))
    for _, key in ipairs({ "NineSlice", "PortraitContainer", "TitleContainer", "CloseButton", "Bg", "TopTileStreaks" }) do
        local f = rawget(host, key)
        L("host.%s: %s level=%s", key, tostring(f ~= nil), tostring(f and f.GetFrameLevel and f:GetFrameLevel()))
    end
    for i, f in ipairs({ host:GetChildren() }) do
        L("child %d %s %s shown=%s l=%s r=%s t=%s b=%s w=%s h=%s", i, tostring(f:GetName()), f:GetObjectType(),
            tostring(f:IsShown()), tostring(f:GetLeft()), tostring(f:GetRight()), tostring(f:GetTop()),
            tostring(f:GetBottom()), tostring(f:GetWidth()), tostring(f:GetHeight()))
    end
    local tabs = ns.SidePage:SideTabs()
    for i, f in ipairs(tabs) do
        L("tab %d %s %s l=%s t=%s w=%s h=%s kids=%d", i, tostring(f:GetName()), f:GetObjectType(),
            tostring(f:GetLeft()), tostring(f:GetTop()), tostring(f:GetWidth()), tostring(f:GetHeight()),
            select("#", f:GetChildren()))
        for j, r in ipairs({ f:GetRegions() }) do
            local tex = r.GetTexture and r:GetTexture()
            local atlas = r.GetAtlas and r:GetAtlas()
            L("tab %d region %d %s layer=%s tex=%s atlas=%s w=%s h=%s", i, j, r:GetObjectType(),
                tostring(r.GetDrawLayer and r:GetDrawLayer()), tostring(tex), tostring(atlas),
                tostring(r:GetWidth()), tostring(r:GetHeight()))
        end
    end
    ns.Print(("Probed %d side tabs; /reload and send the debug log."):format(#tabs))
end
