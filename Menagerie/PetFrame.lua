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

PF.W, PF.H = 200, 170   -- the model's area; the name and the bar go under it ...
PF.FOOT = 50            -- ... in this much (2026-11-11: the level badge was snug against the bottom)
PF.MIN_SCALE, PF.MAX_SCALE, PF.SCALE_STEP = 0.5, 2, 0.05
PF.VIEW_TOP = 86        -- the card's view: 86 px above the scene's bottom ...
PF.VIEW_BOTTOM = -50    -- ... to 50 below it
PF.DEFAULT_POINT = { "CENTER", "CENTER", -380, -160 }
PF.ZZZ_EVERY = 2.5      -- seconds between the Zzz over a sleeping pet
PF.ZZZ_AT = { 22, 66 }  -- where they rise from: right of the middle, about head height in the card's view
-- The bond bar and level show only under the mouse (2026-11-11, the user: "only visible on mouseover regardless
-- of settings for now"), and while points rise (the numbers are drawn on the bar; a new level comes with points).
PF.PEEK_HOLD = 1          -- seconds the bar stays after its last number has faded

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
    f:SetSize(self.W, self.H + self.FOOT)
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

    -- The footer (2026-11-11, the user: "improve the layout + visual language"): the name, and
    -- under it the bond as on the card, a bar in its level's colors with a dark edge, the level on
    -- a badge (a dark disc in a gold ring) at its left end.
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.name:SetPoint("TOP", scene, "BOTTOM", 0, -2)
    f.name:SetShadowColor(0, 0, 0, 1)
    f.name:SetShadowOffset(1, -1)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetSize(self.W - 76, 9)
    bar:SetPoint("TOP", f.name, "BOTTOM", 14, -9)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, -2)
    bar.edge:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    bar.edge:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    bar.edge:SetColorTexture(0, 0, 0, 0.9)
    bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, -1)
    bar.bg:SetAllPoints()
    bar.bg:SetColorTexture(0.12, 0.1, 0.08, 0.85)
    bar.medal = bar:CreateTexture(nil, "ARTWORK")
    bar.medal:SetTexture(ns.Decor.MEDIA .. "dot")
    bar.medal:SetSize(26, 26)
    bar.medal:SetPoint("CENTER", bar, "LEFT", -19, 0) -- (clear of the bar)
    bar.medal:SetVertexColor(0.08, 0.06, 0.04, 1)
    bar.ring = bar:CreateTexture(nil, "OVERLAY")
    bar.ring:SetTexture(ns.Decor.MEDIA .. "ring")
    bar.ring:SetSize(24, 24)
    bar.ring:SetPoint("CENTER", bar.medal, "CENTER")
    bar.level = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    bar.level:SetPoint("CENTER", bar.medal, "CENTER", 0, 0)
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
    click:EnableMouseWheel(false) -- (a wheel script turns it on: the camera would never zoom over it)
    click:SetScript("OnEnter", function(b)
        PF.hover = true; PF:ShowBar()
        if PF.editing or not PF.key then return end
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(ns.Registry:NameOf(PF.key), 1, 0.82, 0)
        GameTooltip:AddLine(L[PF:OtherPage() and "petframe.tip.pets" or "petframe.tip"], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    click:SetScript("OnLeave", function(b) PF.hover = nil; PF:ShowBar(); ns.HideTip(b) end)
    f.click = click

    self:Art()
    self.stage = ns.Moves.NewStage("frame", {
        moments = false, -- (the sulk, playing dead, the wish's hop: the card's, once; code review 2026-11-11)
        actor = function() return PF.actor end,
        scene = function() return PF.scene end,
        anchor = function() return PF.frame end,
    })
    self:Place()
    return f
end

-- Frame art (2026-11-11, the user: "toggle background+border, in the same modern client style as
-- everything else uses"; Settings: petFrameArt, off by default): the rock of Blizzard's windows
-- behind the pet, and their nine-slice border (NineSliceUtil, NineSliceLayouts: both on Forever).
-- (SimplePanelTemplate first: ButtonFrameTemplateNoPortrait brought a title bar strip, 2026-11-11.)
PF.ART_LAYOUTS = { "SimplePanelTemplate", "ButtonFrameTemplateNoPortrait" }
function PF:Art()
    local f = self.frame
    local on = ns.Settings:Get("petFrameArt") == true
    if on and not f.bg then
        f.bg = f:CreateTexture(nil, "BACKGROUND", nil, -7) -- (on the frame itself: under the scene)
        -- (to 2 px from the edge: the border covers it; at 4 a gap showed on the left, 2026-11-11)
        f.bg:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
        f.bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
        f.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
        f.bg:SetHorizTile(true)
        f.bg:SetVertTile(true)
        local border = CreateFrame("Frame", nil, f, "NineSlicePanelTemplate")
        border:SetAllPoints()
        border:SetFrameLevel(self.scene:GetFrameLevel() + 2) -- (over the scene's edges, under the click layer)
        local layouts = rawget(_G, "NineSliceLayouts")
        local util = rawget(_G, "NineSliceUtil")
        for _, name in ipairs(self.ART_LAYOUTS) do
            local layout = layouts and layouts[name]
            if layout and util and util.ApplyLayout then
                local ok = pcall(util.ApplyLayout, border, layout)
                ns.Log("PetFrame", "art: %s %s", name, ok and "applied" or "failed")
                if ok then break end
            end
        end
        f.border = border
    end
    if f.bg then
        f.bg:SetShown(on)
        f.border:SetShown(on)
    end
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
    if not points then self.points = nil; bar:Hide(); return end
    local top = nextAt or math.max(points, 1)
    bar:SetMinMaxValues(from, top)
    bar:SetValue(nextAt and points or top)
    local tier = ns.Scenes.Tier(level)
    -- As the card's bar: from the tier's dark to its bright.
    local fill = bar:GetStatusBarTexture()
    if fill and CreateColor then
        fill:SetGradient("HORIZONTAL", CreateColor(tier[1] * 0.55, tier[2] * 0.55, tier[3] * 0.55, 1),
            CreateColor(math.min(1, tier[1] * 1.15), math.min(1, tier[2] * 1.15), math.min(1, tier[3] * 1.15), 1))
    else
        bar:SetStatusBarColor(tier[1], tier[2], tier[3])
    end
    bar.ring:SetVertexColor(tier[1], tier[2], tier[3], 1)
    bar.level:SetText(level)
    local last = self.points
    self.points = points
    if animate and last and points > last then
        local T = ns.BondTrack
        self:Peek(T.GROW.delay + T.NUMBER.fadeIn + T.NUMBER.rise + T.NUMBER.fadeOut + self.PEEK_HOLD)
        T:Animate(self.track, points, from, top, last, { points - last })
    end
    self:ShowBar()
end

-- The bar shows while the mouse is over the frame or during a peek, and only with a bond to show.
function PF:ShowBar()
    local bar = self.frame and self.frame.bar
    if not bar then return end
    bar:SetShown(self.points ~= nil and (self.hover or self.peek) and true or false)
end

-- Shown for `secs`; a later peek extends it (one token: the last timer decides).
function PF:Peek(secs)
    self.peekToken = (self.peekToken or 0) + 1
    local token = self.peekToken
    self.peek = true
    self:ShowBar()
    C_Timer.After(secs, function()
        if PF.peekToken ~= token then return end
        PF.peek = nil
        PF:ShowBar()
    end)
end

-- Show what should show now: the pet that's out (or Edit Mode's empty frame), or nothing.
function PF:Refresh()
    if not self:Enabled() then return self:Off() end
    local f = self:Build()
    local key = not self.battle and ns.Pets:OutKey() or nil
    if not key then
        self.stage:Update(f, nil)
        if self.key and self.actor then Call(self.actor, "ClearModel") end -- (Edit Mode's empty frame: no pet in it)
        self.key, self.points = nil, nil
        if self.editing then
            f.name:SetText(L["petframe.name"]); f.bar:Hide(); f:Show()
        else
            f:Hide()
        end
        return
    end
    if key ~= self.key then
        -- The last pet's rise, and the peek it kept up, end here: else its growth's timers set
        -- its points on this pet's bar, and the check below would leave that bar to them.
        ns.BondTrack:StopGains(self.track)
        self.peekToken, self.peek = (self.peekToken or 0) + 1, nil
        self.key, self.points = key, nil
        self.stage:Update(f, nil) -- (the last pet's pose ends)
        self:Load(key)
    end
    f.name:SetText(ns.Registry:NameOf(key))
    f:Show()
    if not f.bar.growTo then self:Bond(false) end -- (its rise is still on: left to it)
    self.stage:Update(f, key)
    self:Sleepy()
    self:NextChange()
end

-- Asleep: a Zzz now and then, as over the card's pet (2026-11-11, "reactions only": no ambience).
-- A timer chain that ends itself once the pet wakes or the frame hides; none at "no particles".
function PF:Sleepy()
    if self.zzz then return end
    local function Tick()
        local f = self.frame
        if not (f and f:IsShown() and self.stage.shown.mode == "sleep" and ns.Settings:Get("cardParticles") ~= "none") then
            self.zzz = nil
            return
        end
        ns.Fx:Burst({ self.scene, "BOTTOM", self.ZZZ_AT[1], self.ZZZ_AT[2] }, "zee",
            { n = 1, color = { 0.8, 0.85, 1 }, alpha = 0.9, size = 0.7, spread = 6, rise = 40 })
        C_Timer.After(self.ZZZ_EVERY, Tick)
    end
    self.zzz = true
    Tick()
end

-- The card's pet is posed anew each time the card opens; this one is always there, so it's
-- posed again when night falls or ends (Personality.IsNight: 22 to 4), by one timer to then.
function PF:NextChange()
    local now = ns.Now()
    local d = date("*t", now)
    local hour = (d.hour >= 22 or d.hour < 4) and 4 or 22
    local at = time({ year = d.year, month = d.month, day = d.day, hour = hour, min = 0, sec = 1 })
    if at <= now then at = at + 86400 end
    -- One timer at a time (code review 2026-11-11: a new one on every refresh piled up thousands).
    if self.changeAt == at then return end
    self.changeAt = at
    C_Timer.After(at - now, function()
        if PF.changeAt ~= at then return end
        PF.changeAt = nil
        if PF.frame and PF.frame:IsShown() then PF:Refresh() end
    end)
end

-- A new level with this pet: its cheer, and stars.
function PF:LevelUp(key)
    if not (self.frame and self.frame:IsShown() and key == self.key) then return end
    self.stage:Cheer(key)
    if ns.Settings:Get("cardParticles") ~= "none" then
        ns.Fx:Burst({ self.scene, "BOTTOM", 0, self.ZZZ_AT[2] }, "star",
            { n = 8, color = { 1, 0.85, 0.35 }, size = 0.8, spread = 50, rise = 50 })
    end
end

------------------------------------------------------------------------------
-- A click: the pet journal, on this pet's card
------------------------------------------------------------------------------
-- Only onto the Pets page as it is: switching the window's tab is Blizzard's CollectionsJournal_SetTab,
-- which we never call (Core/SidePage.lua: taint; the Toy Box's buttons are secure), so neither is
-- ToggleCollectionsJournal given a tab (it would call it). Closed, the window opens on the page it
-- had: the Pets page, the card; another, it's left to the player. Open on another page: nothing (a
-- toggle would close it), as on the park's map (ParkPage.lua); the tooltip says so.
function PF:PetsPage() return rawget(_G, "PetJournal") ~= nil and PetJournal:IsVisible() == true end

function PF:OtherPage()
    local cj = rawget(_G, "CollectionsJournal")
    return cj ~= nil and cj:IsShown() and not self:PetsPage()
end

function PF:OpenCard()
    local sid = self.key and ns.Pets:SpeciesOfKey(self.key)
    if not sid or ns.InCombat() or self:OtherPage() then return end
    if not self:PetsPage() then
        if type(ToggleCollectionsJournal) ~= "function" then return end
        ToggleCollectionsJournal()
        if not self:PetsPage() then return end
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
    local okB, inBattle = pcall(function() return C_PetBattles and C_PetBattles.IsInBattle() end)
    self.battle = okB and ns.Plain(inBattle) and true or nil -- (a /reload in a pet battle)
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
        if self.frame then self:Place(); self:Art() end
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
    ns.Bus:On("BOND_LEVEL", function(key) PF:LevelUp(key) end)
    -- Its day full: it sits (Moves:Rest), as on the card.
    ns.Bus:On("BOND_FULL", function(key) if PF.frame and PF.frame:IsShown() and key == PF.key then PF:Refresh() end end)
    ns.Bus:On("REGISTRY", function() if PF.frame and PF.key then PF.frame.name:SetText(ns.Registry:NameOf(PF.key)) end end)
    PF:HookEditMode()
    PF:Apply()
end)
