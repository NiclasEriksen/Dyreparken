-- Frame, Region (textures, font strings) and animation group stubs, shared by every client:
-- anchors and sizes recorded, not laid out (f.points, f.size; geometry only with f.geo),
-- Show/Hide cascading OnShow/OnHide like the client, unknown methods throwing. Also a
-- model scene's actor (H.NewActor) and hardware events (H.Hardware: clicks, keypresses).
local H, P = ...
local KNOWN_EVENTS = P.KNOWN_EVENTS

-- A pet's actor in a model scene (retail's ModelSceneActor, as on Forever: /dp probe api). It has
-- the animations in client.petAnims (default: stand, the happy hop, playing dead).
function H.NewActor(client)
    local actor = { played = {} }
    function actor:SetAnimation(id, variation, speed, offset)
        self.anim, self.speed, self.offset = id, speed, offset
        self.played[#self.played + 1] = id
    end
    -- What plays: the id, or standing (0) for one the model lacks (client.petAnims set).
    function actor:GetAnimation()
        if client.petAnims and not client.petAnims[self.anim] then return 0 end
        return self.anim
    end
    -- Retail's Enum.ModelBlendOperation: 0 None (cut straight to it), 1 Anim (blend).
    function actor:SetAnimationBlendOperation(op) self.blendOp = op end
    actor.pos, actor.scale = { 0, 0, 0 }, 1
    function actor:GetPosition() return unpack(self.pos) end
    function actor:SetPosition(x, y, z) self.pos = { x, y, z } end
    function actor:GetScale() return self.scale end
    function actor:SetScale(s) self.scale = s end
    function actor:GetActiveBoundingBox() return -0.3, -0.2, 0, 0.3, 0.2, 0.8 end
    function actor:GetYaw() return self.yaw or 0 end
    function actor:OnModelLoaded() end -- (the mixin's: the client calls it once a model has loaded)
    function actor:SetYaw(y) self.yaw = y end
    function actor:SetModelByCreatureDisplayID(id) self.display = id end
    function actor:HasAnimation(id)
        return (client.petAnims or { [0] = true, [756] = true, [770] = true })[id] == true
    end
    return actor
end
local Frame = {}
Frame.__index = function(self, k)
    local m = Frame[k]
    if m then return m end
    -- Unknown methods are errors on purpose: stub them here when the addon
    -- starts using one, with realistic behavior.
    if type(k) == "string" and k:match("^%u") then
        error("frame method " .. k .. " is not stubbed (tools/test/harness/frames.lua)", 2)
    end
end
local function noop() end
for _, m in ipairs({ "SetSize", "SetWidth", "SetHeight", "SetPoint", "ClearAllPoints", "SetAllPoints",
    "SetMotionScriptsWhileDisabled", "SetFrameStrata", "EnableMouse", "SetMovable", "RegisterForDrag",
    "StopMovingOrSizing",
    "RegisterForClicks", "SetNormalTexture", "SetHighlightTexture", "SetPushedTexture", "SetJustifyH",
    "SetJustifyV", "SetFontObject", "SetWordWrap" }) do
    Frame[m] = noop
end

function Frame:SetClampedToScreen(v) self.clamped = v end
-- Like the client: a named frame moved by StartMoving is user-placed, and the client keeps its spot in
-- its own layout cache (layout-local.txt) until told otherwise.
function Frame:StartMoving() self.moving = true; self.userPlaced = true end
function Frame:SetUserPlaced(v) self.userPlaced = v and true or false end
function Frame:IsUserPlaced() return self.userPlaced == true end
function Frame:EnableMouseWheel(v) self.wheel = v end
function Frame:SetScale(s) self.scale = s end
function Frame:GetScale() return self.scale or 1 end

function Frame:RegisterEvent(e)
    if not KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    self.events[e] = true
end
function Frame:UnregisterEvent(e) self.events[e] = nil end
function Frame:LockHighlight() self.highlightLocked = true end
function Frame:UnlockHighlight() self.highlightLocked = false end
function Frame:RegisterUnitEvent(e, ...)
    if not KNOWN_EVENTS[e] then error("Attempt to register unknown event \"" .. tostring(e) .. "\"", 2) end
    self.events[e] = true
    self.unitFilter = self.unitFilter or {}
    self.unitFilter[e] = { ... }
end
function Frame:UnregisterAllEvents() self.events = {} end
function Frame:IsEventRegistered(e) return self.events[e] == true end
function Frame:SetScript(k, fn) self.scripts[k] = fn end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:HookScript(k, fn)
    local old = self.scripts[k]
    self.scripts[k] = old and function(...) old(...); fn(...) end or fn
end
-- Like the client: showing or hiding a frame also fires OnShow/OnHide on
-- its shown descendants, whose visibility changes with it.
local function Cascade(f, script)
    for _, kid in ipairs(f.client and f.client.frames or {}) do
        if kid.parent == f and kid.shown then
            if kid.scripts[script] then kid.scripts[script](kid) end
            Cascade(kid, script)
        end
    end
end
function Frame:Show()
    if self.shown then return end
    self.shown = true
    if self:IsVisible() then
        if self.scripts.OnShow then self.scripts.OnShow(self) end
        Cascade(self, "OnShow")
    end
end
function Frame:Hide()
    if not self.shown then return end
    local was = self.parent == nil or self.parent:IsVisible()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
    if was then Cascade(self, "OnHide") end
end
function Frame:IsShown() return self.shown end
function Frame:IsForbidden() return self.forbidden == true end
function Frame:IsVisible()
    if not self.shown then return false end
    return self.parent == nil or self.parent:IsVisible()
end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) self.parent = p end
function Frame:GetName() return self.frameName end
function Frame:SetText(t) self.text = t end
function Frame:GetText() return self.text end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:IsEnabled() return self.enabled end
function Frame:SetEnabled(v) self.enabled = not not v end
-- Geometry: nil (not laid out) unless a test sets f.geo = { l, r, t, b }.
function Frame:GetLeft() return self.geo and self.geo.l end
-- Its own scale times its parents' (geometry, as the client reports it, is in the frame's own units).
function Frame:GetEffectiveScale() return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1) end
function Frame:GetCenter()
    if self.geo then return (self.geo.l + self.geo.r) / 2, (self.geo.t + self.geo.b) / 2 end
end
function Frame:GetFrameStrata() return "MEDIUM" end -- (a new frame's)
function Frame:GetRight() return self.geo and self.geo.r end
function Frame:GetTop() return self.geo and self.geo.t end
function Frame:GetBottom() return self.geo and self.geo.b end
function Frame:GetWidth() return self.geo and (self.geo.r - self.geo.l) end
function Frame:GetHeight() return self.geo and (self.geo.t - self.geo.b) end
function Frame:GetObjectType() return self.type end
-- The recorded anchors and size, as the client reports them.
function Frame:GetPoint(i) local p = (self.points or {})[i or 1]; if p then return unpack(p) end end
function Frame:GetSize() if self.size then return self.size[1], self.size[2] end return 0, 0 end
function Frame:GetChildren()
    local kids = {}
    for _, f in ipairs(self.client.frames) do if f.parent == self then kids[#kids + 1] = f end end
    return unpack(kids)
end
function Frame:GetRegions()
    local all = {}
    for _, t in ipairs(self.textures) do all[#all + 1] = t end
    for _, t in ipairs(self.fontStrings) do all[#all + 1] = t end
    return unpack(all)
end
function Frame:SetCheckedTexture(x) self.checkedTex = x end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetFrameLevel(n) self.level = n end
-- StatusBar
function Frame:SetStatusBarTexture(x) self.barTex = x end
function Frame:SetStatusBarColor(...) self.barColor = { ... } end
function Frame:GetStatusBarTexture()
    if not self.barRegion then self.barRegion = self:CreateTexture() end
    return self.barRegion
end
function Frame:SetMinMaxValues(a, b) self.min, self.max = a, b end
function Frame:GetMinMaxValues() return self.min, self.max end
-- A Slider tells its OnValueChanged (userInput false), like the client.
function Frame:SetValue(v)
    local old = self.value
    self.value = v
    if self.type == "Slider" and old ~= v and self.scripts and self.scripts.OnValueChanged then
        self.scripts.OnValueChanged(self, v, false)
    end
end
function Frame:GetValue() return self.value end
function Frame:SetValueStep(s) self.step = s end
function Frame:SetObeyStepOnDrag() end
function Frame:SetOrientation(o) self.orientation = o end
-- Anchors and size are recorded (not laid out): f.points, f.size.
function Frame:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetSize(w, h) self.size = { w, h } end
function Frame:SetWidth(w) self.size = { w, self.size and self.size[2] } end
function Frame:SetHeight(h) self.size = { self.size and self.size[1], h } end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:SetScrollChild(f) self.scrollChild = f end
function Frame:SetVerticalScroll(v) self.vscroll = v end
function Frame:GetVerticalScroll() return self.vscroll or 0 end
function Frame:SetChecked(v) self.checked = not not v end
function Frame:GetChecked() return self.checked end
-- Like the client: a disabled button ignores clicks; a check button flips
-- its state before OnClick runs.
-- Runs fn as a hardware event (a keypress or click) for client c: only then
-- may the addon post to guild chat (Forever, docs/FOREVER_API.md).
local function Hardware(c, fn, ...)
    if not c then return fn(...) end
    c.hardware = (c.hardware or 0) + 1
    local r = { pcall(fn, ...) }
    c.hardware = c.hardware - 1
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, table.maxn(r))
end
H.Hardware = Hardware

function Frame:Click()
    if not self.enabled then return end
    if self.type == "CheckButton" then self.checked = not self.checked end
    if self.scripts.OnClick then Hardware(self.client, self.scripts.OnClick, self, "LeftButton") end
end

local Region = {}
Region.__index = Region
for _, m in ipairs({ "SetWidth", "SetHeight", "SetAllPoints", "SetJustifyH", "SetJustifyV",
    "SetDrawLayer", "SetWordWrap" }) do
    Region[m] = noop
end
function Region:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = { ... } end
function Region:ClearAllPoints() self.points = {} end
function Region:SetTexture(x) self.tex = x; self.atlas = nil end -- (an atlas set before is gone)
function Region:GetTexture() return self.tex end
function Region:SetAtlas(x) self.tex = x; self.atlas = x end
function Region:SetTexCoord(...) self.texCoord = { ... } end

-- Animation groups (texture:CreateAnimationGroup): recorded, not run. The
-- client plays them on its own (no OnUpdate in the addon).
local AnimGroup, Anim = {}, {}
AnimGroup.__index, Anim.__index = AnimGroup, Anim
local ANIM_TYPES = { Alpha = true, Translation = true, Scale = true, Rotation = true }
function AnimGroup:CreateAnimation(kind)
    if not ANIM_TYPES[kind] then error("unknown animation type " .. tostring(kind), 2) end
    local a = setmetatable({ kind = kind, group = self }, Anim)
    self.anims[#self.anims + 1] = a
    return a
end
function AnimGroup:SetLooping(v) self.looping = v end
function AnimGroup:SetToFinalAlpha(v) self.finalAlpha = v end
function AnimGroup:Play() self.playing = true; self.plays = (self.plays or 0) + 1 end
function AnimGroup:Stop() self.playing = false end
function AnimGroup:IsPlaying() return self.playing == true end
function AnimGroup:GetAnimations() return unpack(self.anims) end
-- OnFinished etc.: kept, and run by a test with g:Finish() (a one-shot group ending).
function AnimGroup:SetScript(name, fn) self.scripts = self.scripts or {}; self.scripts[name] = fn end
function AnimGroup:Finish()
    self.playing = false
    if self.scripts and self.scripts.OnFinished then self.scripts.OnFinished(self) end
end
for _, m in ipairs({ "Duration", "StartDelay", "Order", "Smoothing", "FromAlpha", "ToAlpha", "Degrees" }) do
    local key = m:sub(1, 1):lower() .. m:sub(2)
    Anim["Set" .. m] = function(self, v) self[key] = v end
end
function Anim:SetOffset(x, y) self.offset = { x, y } end
function Anim:SetScale(x, y) self.scale = { x, y } end
function Anim:SetScaleFrom(x, y) self.scaleFrom = { x, y } end
function Anim:SetScaleTo(x, y) self.scaleTo = { x, y } end
function Anim:SetOrigin(point, x, y) self.origin = { point, x, y } end
function Region:CreateAnimationGroup()
    local g = setmetatable({ anims = {}, parent = self }, AnimGroup)
    self.animGroups = self.animGroups or {}
    self.animGroups[#self.animGroups + 1] = g
    return g
end
function Region:SetRotation(r) self.rotation = r end
Frame.CreateAnimationGroup = Region.CreateAnimationGroup
function Frame:SetAlpha(a) self.alpha = a end
function Frame:GetAlpha() return self.alpha or 1 end
function Region:SetSize(w, h) self.size = { w, h } end
function Region:SetVertexColor(r, g, b, a) self.vertexColor = { r, g, b, a } end
-- Nine-slice a texture (Retail 10.0+): the margins stay, the middle stretches.
function Region:SetTextureSliceMargins(l, t, r, b) self.slice = { l, t, r, b } end
function Region:SetTextureSliceMode(m) self.sliceMode = m end
function Region:GetAtlas() return self.atlas end
function Region:SetColorTexture(...) self.color = { ... } end
function Region:SetHorizTile(v) self.horizTile = v end
function Region:SetVertTile(v) self.vertTile = v end
function Region:AddMaskTexture(m) self.mask = m end
function Region:GetObjectType() return self.ftype or "Texture" end
function Region:GetPoint(i) local p = (self.points or {})[i or 1]; if p then return unpack(p) end end
function Region:GetSize() if self.size then return self.size[1], self.size[2] end return 0, 0 end
function Region:GetDrawLayer() return "ARTWORK" end
function Region:GetWidth() return 16 end
function Region:GetHeight() return 16 end
function Region:SetDesaturated(v) self.desaturated = not not v end
function Region:Show() self.shown = true end
function Region:Hide() self.shown = false end
function Region:IsShown() return self.shown end
function Region:SetShown(v) self.shown = not not v end
local function StripColors(x) return (tostring(x):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
H.StripColors = StripColors
-- .text as set, .plain without color codes (for assertions)
function Region:SetText(x) self.text = x; self.plain = x and StripColors(x) end
function Region:GetText() return self.text end
function Region:SetTextColor(r, g, b) self.color = { r, g, b } end
function Region:SetShadowOffset(x, y) self.shadow = { x, y } end
function Region:SetShadowColor(r, g, b, a) self.shadowColor = { r, g, b, a } end
-- A font string's font: path, size, flags (OUTLINE...), as the client returns it.
function Region:GetFont() return self.fontPath or "Fonts\\FRIZQT__.TTF", self.fontSize or 16, self.fontFlags or "" end
function Region:SetFont(path, size, flags) self.fontPath, self.fontSize, self.fontFlags = path, size, flags; return true end
function Region:SetAlpha(a) self.alpha = a end
function Region:SetGradient(o, a, b) self.gradient = { o, a, b } end
function Region:SetBlendMode(m) self.blend = m end
-- The font in use, and the text's width estimated from it (px per character).
local FONT_W = { GameFontNormalHuge = 13, GameFontNormalLarge = 10, GameFontNormal = 8 }
function Region:SetFontObject(f) self.font = f end
function Region:GetStringWidth() return #(self.plain or self.text or "") * (FONT_W[self.font] or 7) end
-- About 14 px a line, like GameFontHighlight.
function Region:GetStringHeight()
    local _, n = (self.text or ""):gsub("\n", "")
    return self.text and (n + 1) * 14 or 0
end

function Frame:CreateTexture()
    local t = setmetatable({ shown = true }, Region)
    self.textures[#self.textures + 1] = t
    return t
end
function Frame:CreateMaskTexture()
    local t = setmetatable({ shown = true, ftype = "MaskTexture" }, Region)
    self.textures[#self.textures + 1] = t
    return t
end
function Frame:CreateFontString(_, _, template)
    local t = setmetatable({ shown = true, ftype = "FontString", font = template }, Region)
    self.fontStrings[#self.fontStrings + 1] = t
    return t
end

P.Frame, P.Region, P.Hardware, P.StripColors = Frame, Region, Hardware, StripColors
