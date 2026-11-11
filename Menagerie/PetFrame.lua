local _, ns = ...

-- The pet frame (2026-11-11, the user): the pet that's out, on screen, with its name and your bond
-- with it. Optional, off by default (Settings: petFrame), on a transparent background. Only to look
-- at: it moves 1:1 as on the journal card (its own stage of Moves.lua: asleep at night, sitting,
-- playing dead, walking and running with you, turning its back in a sulk, a cheer at a new level),
-- and a click opens the pet journal on its card. Placed in Blizzard's Edit Mode (dragged while
-- it's open, and sized with the mouse wheel there: the spot and size saved per character,
-- char.petFrame; 2026-11-11, the user: "It would be optimal if we could resize it in edit mode").
--
-- How the model shows (docs/FOREVER_API.md, /dp probe api petframe, 2026-11-11): a ModelScene
-- of our own (ModelSceneMixinTemplate), set to the species' model scene and its "unwrapped" actor,
-- as Blizzard's card does; and the card's view insets for our height (the card: 0, 0, 300, -50 on
-- 386 px, the model's view 50 px below its bottom to 86 above), else the pet stands half out of the
-- top. The scene takes no mouse (it would rotate the pet): a button over it takes the clicks.
--
-- Dormant while off: no frame, no events. On: COMPANION_UPDATE (debounced: it fires for every
-- companion nearby) and pet battles, to follow the pet that's out; Bus BOND for the bar.
local PF = {}
ns.PetFrame = PF

PF.W, PF.H = 200, 170   -- the model's area; the name and the bar go under it
PF.MIN_SCALE, PF.MAX_SCALE, PF.SCALE_STEP = 0.5, 2, 0.05
PF.VIEW_TOP = 86        -- the card's view: 86 px above the scene's bottom ...
PF.VIEW_BOTTOM = -50    -- ... to 50 below it
PF.DEFAULT_POINT = { "CENTER", "CENTER", -380, -160 }

local L = ns.L

local function Call(obj, method, ...)
    if not obj then return false end
    local ok, fn = pcall(function() return obj[method] end)
    if not (ok and type(fn) == "function") then return false end
    return pcall(fn, obj, ...)
end

function PF:Enabled() return ns.Settings:Get("petFrame") == true end

------------------------------------------------------------------------------
-- The frame
------------------------------------------------------------------------------
function PF:Build()
    if self.frame then return self.frame end
    local f = CreateFrame("Frame", "DyreparkenPetFrame", UIParent)
    f:SetSize(self.W, self.H + 30)
    f:SetFrameStrata("LOW")
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:Hide()
    self.frame = f

    local scene = CreateFrame("ModelScene", nil, f, "ModelSceneMixinTemplate")
    scene:SetPoint("TOP", f, "TOP")
    scene:SetSize(self.W, self.H)
    Call(scene, "EnableMouse", false)
    Call(scene, "EnableMouseWheel", false)
    self.scene = scene

    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOP", scene, "BOTTOM", 0, 2)
    f.name:SetShadowColor(0, 0, 0, 1)
    f.name:SetShadowOffset(1, -1)

    -- The bond: a slim bar with the level on a medallion at its left end.
    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetSize(self.W - 60, 8)
    bar:SetPoint("TOP", f.name, "BOTTOM", 8, -4)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.bg = bar:CreateTexture(nil, "BACKGROUND")
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0, 0, 0, 0.5)
    bar.medal = bar:CreateTexture(nil, "ARTWORK")
    bar.medal:SetTexture(ns.Decor.MEDIA .. "dot")
    bar.medal:SetSize(22, 22)
    bar.medal:SetPoint("RIGHT", bar, "LEFT", -2, 0)
    bar.level = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.level:SetPoint("CENTER", bar.medal, "CENTER")
    f.bar = bar
    self.track = { bond = bar } -- (BondTrack:Animate's rising numbers, on this bar)

    -- Edit Mode's highlight, like Blizzard's own frames there: a blue wash, a bright edge, a label.
    -- (2026-11-11, the user: a faint wash alone wasn't seen.)
    local edit = CreateFrame("Frame", nil, f)
    edit:SetAllPoints()
    edit:SetFrameLevel(scene:GetFrameLevel() + 4)
    edit.wash = edit:CreateTexture(nil, "BACKGROUND")
    edit.wash:SetAllPoints()
    edit.wash:SetColorTexture(0.2, 0.5, 1, 0.35)
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 2 },
        { "TOPLEFT", "BOTTOMLEFT", 2, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 2, nil } }) do
        local t = edit:CreateTexture(nil, "BORDER")
        t:SetColorTexture(0.45, 0.75, 1, 1)
        t:SetPoint(side[1]); t:SetPoint(side[2])
        if side[3] then t:SetWidth(side[3]) else t:SetHeight(side[4]) end
    end
    edit.label = edit:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    edit.label:SetPoint("TOP", edit, "TOP", 0, -8)
    edit.label:SetWidth(self.W - 16)
    edit:Hide()
    f.edit = edit

    -- Over it all: a click opens the pet's card; in Edit Mode, a drag moves it.
    local click = CreateFrame("Button", nil, f)
    click:SetAllPoints()
    click:SetFrameLevel(scene:GetFrameLevel() + 5)
    click:RegisterForClicks("LeftButtonUp")
    click:SetScript("OnClick", function() if not PF.editing then PF:OpenCard() end end)
    click:SetScript("OnDragStart", function() if PF.editing then f:StartMoving() end end)
    click:SetScript("OnDragStop", function() f:StopMovingOrSizing(); PF:SavePoint() end)
    click:SetScript("OnMouseWheel", function(_, delta) if PF.editing then PF:Resize(delta) end end)
    click:SetScript("OnEnter", function(b)
        if PF.editing or not PF.key then return end
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(ns.Registry:NameOf(PF.key), 1, 0.82, 0)
        GameTooltip:AddLine(L["petframe.tip"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    click:SetScript("OnLeave", function(b) ns.HideTip(b) end)
    f.click = click

    self.stage = ns.Moves.NewStage("frame", {
        actor = function() return PF.actor end,
        scene = function() return PF.scene end,
        anchor = function() return PF.frame end,
    })
    self:Place()
    return f
end

function PF:Place()
    local f = self.frame
    local p = ns.DB.char.petFrame or self.DEFAULT_POINT
    f:ClearAllPoints()
    f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    f:SetScale(p[5] or 1)
end

function PF:SavePoint()
    local point, _, rel, x, y = self.frame:GetPoint()
    if point then ns.DB.char.petFrame = { point, rel, x, y, self.frame:GetScale() } end
end

-- The mouse wheel in Edit Mode: a size step up or down.
function PF:Resize(delta)
    local f = self.frame
    local scale = f:GetScale() + (delta > 0 and self.SCALE_STEP or -self.SCALE_STEP)
    scale = math.floor(math.max(self.MIN_SCALE, math.min(self.MAX_SCALE, scale)) * 100 + 0.5) / 100
    f:SetScale(scale)
    self:SavePoint()
    self:Label()
end

function PF:Label()
    self.frame.edit.label:SetText(ns.T("petframe.edit", { pct = math.floor(self.frame:GetScale() * 100 + 0.5) }))
end

-- The pet's model, as Blizzard's card shows it: its scene, then the unwrapped actor.
function PF:Load(key)
    local sid = ns.Pets:SpeciesOfKey(key)
    local scene = self.scene
    local okI, sceneID = pcall(C_PetJournal.GetPetModelSceneInfoBySpeciesID, sid)
    if okI and sceneID then
        Call(scene, "TransitionToModelSceneID", sceneID, rawget(_G, "CAMERA_TRANSITION_TYPE_IMMEDIATE") or 1,
            rawget(_G, "CAMERA_MODIFICATION_TYPE_DISCARD") or 1, true)
    end
    Call(scene, "SetViewInsets", 0, 0, self.H - self.VIEW_TOP, self.VIEW_BOTTOM)
    local okA, actor = Call(scene, "GetActorByTag", "unwrapped")
    actor = okA and actor or nil
    local display = select(12, C_PetJournal.GetPetInfoBySpeciesID(sid))
    if actor and display then Call(actor, "SetModelByCreatureDisplayID", display) end
    self.actor = actor
    ns.Log("PetFrame", "%s: scene %s, actor %s, display %s", key, tostring(sceneID), tostring(actor ~= nil), tostring(display))
end

-- Your bond with it: the bar, the level, and the points that came since (rising, as on the card).
function PF:Bond(animate)
    local bar, key = self.frame.bar, self.key
    local points, level, _, from, nextAt = ns.Bond:Own(key)
    if not points then bar:Hide(); return end
    bar:Show()
    local top = nextAt or math.max(points, 1)
    bar:SetMinMaxValues(from, top)
    bar:SetValue(nextAt and points or top)
    local tier = ns.Scenes.Tier(level)
    bar:SetStatusBarColor(tier[1], tier[2], tier[3])
    bar.medal:SetVertexColor(tier[1] * 0.5, tier[2] * 0.5, tier[3] * 0.5, 1)
    bar.level:SetText(level)
    local last = self.points
    self.points = points
    if animate and last and points > last then
        ns.BondTrack:Animate(self.track, points, from, top, last, { points - last })
    end
end

-- Show what should show now: the pet that's out (or Edit Mode's empty frame), or nothing.
function PF:Refresh()
    if not self:Enabled() then return self:Off() end
    local f = self:Build()
    local key = not self.battle and ns.Pets:OutKey() or nil
    if not key then
        self.stage:Update(f, nil)
        self.key, self.points = nil, nil
        if self.editing then
            f.name:SetText(L["petframe.name"]); f.bar:Hide(); f:Show()
        else
            f:Hide()
        end
        return
    end
    if key ~= self.key then
        self.key, self.points = key, nil
        self.stage:Update(f, nil) -- (the last pet's pose ends)
        self:Load(key)
    end
    f.name:SetText(ns.Registry:NameOf(key))
    f:Show()
    self:Bond(false)
    self.stage:Update(f, key)
end

------------------------------------------------------------------------------
-- A click: the pet journal, on this pet's card
------------------------------------------------------------------------------
function PF:OpenCard()
    local sid = self.key and ns.Pets:SpeciesOfKey(self.key)
    if not sid or ns.InCombat() then return end
    local open = rawget(_G, "PetJournal") and PetJournal:IsVisible()
    if not open and type(ToggleCollectionsJournal) == "function" then
        ToggleCollectionsJournal(rawget(_G, "COLLECTIONS_JOURNAL_TAB_INDEX_PETS") or 2)
    end
    ns.SidePage:CloseAll() -- (our pages would cover the card)
    C_Timer.After(0, function() ns.JournalUI:ShowSpecies(sid) end)
end

------------------------------------------------------------------------------
-- On and off; Edit Mode
------------------------------------------------------------------------------
local refreshSoon
function PF:On()
    if self.on then return self:Refresh() end
    self.on = true
    refreshSoon = refreshSoon or ns.Debounce(0.3, function() PF:Refresh() end)
    ns.Events:On("COMPANION_UPDATE", PF, refreshSoon)
    ns.Events:On("PLAYER_ENTERING_WORLD", PF, refreshSoon)
    ns.Events:On("PET_BATTLE_OPENING_START", PF, function() PF.battle = true; PF:Refresh() end)
    ns.Events:On("PET_BATTLE_CLOSE", PF, function() PF.battle = nil; PF:Refresh() end)
    self:Refresh()
end

function PF:Off()
    if not self.on and not self.frame then return end
    self.on = nil
    for _, e in ipairs({ "COMPANION_UPDATE", "PLAYER_ENTERING_WORLD", "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" }) do
        ns.Events:Off(e, PF)
    end
    if self.frame then
        self.stage:Update(self.frame, nil)
        self.frame:Hide()
    end
    self.key, self.points = nil, nil
end

-- Settings: turned on or off, or another size.
function PF:Apply()
    if self:Enabled() then
        self:On()
        if self.frame then self:Place() end
    else
        self:Off()
    end
end

function PF:EditMode(on)
    self.editing = on or nil
    if not self.frame then return end
    local f = self.frame
    f.edit:SetShown(on and true or false)
    f.click:EnableMouseWheel(on and true or false)
    if on then f.click:RegisterForDrag("LeftButton"); self:Label() else f.click:RegisterForDrag() end
    self:Refresh()
end

-- Blizzard's Edit Mode tells addons when it opens and closes (verified on Forever, 2026-11-11).
function PF:HookEditMode()
    local ER = rawget(_G, "EventRegistry")
    if not (ER and ER.RegisterCallback) then return end
    ER:RegisterCallback("EditMode.Enter", function() if PF:Enabled() then PF:EditMode(true) end end, PF)
    ER:RegisterCallback("EditMode.Exit", function() PF:EditMode(false) end, PF)
end

ns.Start("settled", function()
    -- The bar follows the bond; a new name, the name.
    ns.Bus:On("BOND", function(key) if PF.frame and key == PF.key then PF:Bond(true) end end)
    ns.Bus:On("REGISTRY", function() if PF.frame and PF.key then PF.frame.name:SetText(ns.Registry:NameOf(PF.key)) end end)
    PF:HookEditMode()
    PF:Apply()
end)
