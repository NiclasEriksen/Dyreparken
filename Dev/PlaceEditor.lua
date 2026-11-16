---@class Dyreparken
local ns = select(2, ...)

-- /dp probe place (development, 2026-11-16, the user's pick: pets placed by their feet, a floor and a size
-- set by eye): a small window to step through the pets' models (pets that share one, the cats, the parrots,
-- the whelps, share their standing box: Moves.ModelOf), a pet of each on the card (or on Parken's stage, while
-- Parken is open), and set where the floor is and how tall a pet stands with two sliders. Every pet of that
-- model follows (Moves.FRAMING); < and > step through them, to see they all stand right. A model not set
-- stands as its scene's row has it (Data/PetScenes.lua: set by scene first, the user, the same day: "1271
-- seems to have a lot of different types of scales"). Picks that differ from the file are saved in
-- DyreparkenDB.modelPicks (stage -> model -> { floor, size }), to be written into ns.PetModels. While the
-- window is open the stages use the picks (Moves:FitFor); closed, the file's again.
---@class Dyreparken.PlaceEditor
local Editor = {}
ns.PlaceEditor = Editor

Editor.FLOOR = { -8, 8, 0.05 }
Editor.SIZE = { 0.5, 20, 0.05 }

local function Call(obj, method, ...)
    local args = { ... }
    return pcall(function() return obj[method](obj, unpack(args)) end)
end

-- Every model with its species: a list of { model, scene, sids }, by scene, then by model.
local function Models()
    local by, list = {}, {}
    for sid in pairs(ns.Companions and ns.Companions.species or {}) do
        local box = ns.Moves:Box(sid)
        if box then
            local model = ns.Moves.ModelOf(box)
            if not by[model] then
                by[model] = { model = model, scene = box.scene, sids = {} }
                list[#list + 1] = by[model]
            end
            table.insert(by[model].sids, sid)
        end
    end
    table.sort(list, function(a, b)
        if a.scene ~= b.scene then return (a.scene or 0) < (b.scene or 0) end
        return a.model < b.model
    end)
    for _, m in ipairs(list) do table.sort(m.sids) end
    return list
end

-- The stage being edited: Parken's while its stage shows, else the card's.
function Editor:Stage()
    for _, st in ipairs(ns.Moves.stages) do
        if st.name == "park" and (st.shown.key or st.shown.still) then return st end
    end
    return ns.Moves.card
end

function Editor:Model() return self.models[self.index] end
function Editor:Pet()
    local m = self:Model()
    return m and m.sids[self.pet]
end

-- The file's row for this model on a stage (ns.PetModels), or nil.
local function FileRow(stage, model)
    local rows = ns.PetModels and ns.PetModels[stage]
    return rows and rows[model] or nil
end

-- The model's fit now and where it's from: the pick, the file's row for it, its scene's (Moves:FitFor), else
-- where Blizzard has the pet now (its box's middle at the actor's height, as its scene centers it), so the
-- sliders start near what shows.
function Editor:Fit()
    local stage, m = self:Stage(), self:Model()
    local sid = self:Pet()
    local box = sid and ns.Moves:Box(sid)
    local fit, from = nil, nil
    if box then fit, from = ns.Moves:FitFor(stage.name, box, box.scene) end
    if fit then
        local picks = ns.DB.global.modelPicks[stage.name]
        return fit, picks and picks[m.model] and "changed" or from
    end
    local actor = stage.ActorNow and stage.ActorNow()
    local okP, _, _, z = Call(actor or {}, "GetPosition")
    local okS, s = Call(actor or {}, "GetScale")
    if box and okP and okS and type(z) == "number" and type(s) == "number" then
        local h = box.high - box.low
        return { floor = z - s * h / 2, size = s * h }, "Blizzard's"
    end
    return { floor = 0, size = 3 }, "a guess"
end

local function Round(v, step) return tonumber(("%.2f"):format(math.floor(v / step + 0.5) * step)) end

-- Set the model's floor or size (saved when the pick differs from the file's row for it).
function Editor:Set(field, value)
    local stage, m = self:Stage(), self:Model()
    if not m then return end
    local range = field == "floor" and self.FLOOR or self.SIZE
    local fit = self:Fit()
    local new = { floor = fit.floor, size = fit.size }
    new[field] = math.max(range[1], math.min(range[2], Round(value, range[3])))
    local picks = ns.DB.global.modelPicks
    picks[stage.name] = picks[stage.name] or {}
    local file = FileRow(stage.name, m.model)
    if file and math.abs(file.floor - new.floor) < 1e-6 and math.abs(file.size - new.size) < 1e-6 then
        picks[stage.name][m.model] = nil
    else
        picks[stage.name][m.model] = new
    end
    stage:Relift()
    self:Redraw(true)
end

-- The pet shown: the i-th model's pet-th pet, on the stage being edited.
function Editor:Show(index, pet)
    if #self.models == 0 then return end
    self.index = (index - 1) % #self.models + 1
    local sids = self:Model().sids
    self.pet = ((pet or 1) - 1) % #sids + 1
    local sid = self:Pet()
    local stage = self:Stage()
    if stage.name == "park" then
        ns.ParkPage:Spot(ns.Pets:KeyOfSpecies(sid))
    else
        ns.JournalUI:ShowSpecies(sid)
    end
    stage:Relift()
    self:Redraw()
end

function Editor:Redraw(fromSlider)
    local f = self.frame
    local sid, m = self:Pet(), self:Model()
    if not (f and sid) then return end
    local stage = self:Stage()
    local fit, from = self:Fit()
    local name = ns.Pets:NameOfKey(ns.Pets:KeyOfSpecies(sid)) or "?"
    f.stage:SetText(("%s's stage"):format(stage.name))
    f.scene:SetText(("model %d / %d, scene %s, %d pets"):format(self.index, #self.models, tostring(m.scene), #m.sids))
    f.name:SetText(("%s (%d), %d / %d"):format(name, sid, self.pet, #m.sids))
    f.value:SetText(("floor %.2f, size %.2f (%s)"):format(fit.floor, fit.size, tostring(from)))
    local n = 0
    for _, models in pairs(ns.DB.global.modelPicks) do for _ in pairs(models) do n = n + 1 end end
    f.saved:SetText(("%d changed (DyreparkenDB.modelPicks)"):format(n))
    if not fromSlider then
        self.quiet = true
        f.floor:SetValue(fit.floor)
        f.size:SetValue(fit.size)
        self.quiet = false
    end
end

local function Button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 60, 22)
    b:SetText(text)
    return b
end

local function Slider(f, field, range, y)
    local s = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    s:SetPoint("TOP", f, "TOP", 0, y)
    s:SetSize(200, 16)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(range[1], range[2])
    s:SetValueStep(range[3])
    s:SetObeyStepOnDrag(true)
    s:SetScript("OnValueChanged", function(_, v) if not Editor.quiet then Editor:Set(field, v) end end)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("RIGHT", s, "LEFT", -6, 0)
    label:SetText(field)
    local down = Button(f, "-", 22)
    down:SetPoint("LEFT", s, "RIGHT", 6, 0)
    down:SetScript("OnClick", function() Editor:Set(field, Editor:Fit()[field] - range[3]) end)
    local up = Button(f, "+", 22)
    up:SetPoint("LEFT", down, "RIGHT", 2, 0)
    up:SetScript("OnClick", function() Editor:Set(field, Editor:Fit()[field] + range[3]) end)
    s.down, s.up = down, up
    return s
end

function Editor:Build()
    local f = CreateFrame("Frame", "DyreparkenPlaceEditor", UIParent)
    f:SetSize(380, 230)
    f:SetPoint("LEFT", UIParent, "CENTER", 360, 0)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.05, 0.04, 0.03, 0.92)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOP", f, "TOP", 0, -8)
    f.title:SetText("Dyreparken: place (dev)")
    f.close = Button(f, "X", 24)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.close:SetScript("OnClick", function() Editor:Close() end)
    f.stage = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.stage:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -10)
    f.scene = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.scene:SetPoint("TOP", f, "TOP", 0, -34)
    f.prevScene = Button(f, "<<", 34)
    f.prevScene:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    f.prevScene:SetScript("OnClick", function() Editor:Show(Editor.index - 1) end)
    f.nextScene = Button(f, ">>", 34)
    f.nextScene:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -30)
    f.nextScene:SetScript("OnClick", function() Editor:Show(Editor.index + 1) end)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetPoint("TOP", f, "TOP", 0, -62)
    f.prevPet = Button(f, "<", 26)
    f.prevPet:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -58)
    f.prevPet:SetScript("OnClick", function() Editor:Show(Editor.index, Editor.pet - 1) end)
    f.nextPet = Button(f, ">", 26)
    f.nextPet:SetPoint("TOPRIGHT", f, "TOPRIGHT", -18, -58)
    f.nextPet:SetScript("OnClick", function() Editor:Show(Editor.index, Editor.pet + 1) end)
    f.floor = Slider(f, "floor", self.FLOOR, -96)
    f.size = Slider(f, "size", self.SIZE, -132)
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.value:SetPoint("TOP", f, "TOP", 0, -160)
    f.value:SetWidth(360)
    f.reset = Button(f, "File's", 70)
    f.reset:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    f.reset:SetScript("OnClick", function()
        local stage, m = Editor:Stage(), Editor:Model()
        local picks = ns.DB.global.modelPicks
        if picks[stage.name] then picks[stage.name][m.model] = nil end
        stage:Relift()
        Editor:Redraw()
    end)
    f.saved = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.saved:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 12)
    self.frame = f
end

function Editor:Open()
    if not (rawget(_G, "PetJournal") and PetJournal:IsVisible()) then
        return ns.Print("Open the pet journal first (the Pets page, or Parken).")
    end
    self.models = Models()
    if #self.models == 0 then return ns.Print("No models: Data/PetBoxes.lua is empty (/dp probe api boxes).") end
    if not self.frame then self:Build() end
    -- Picks already written into the file are no longer changes (scene picks too: written in by now). Keys
    -- from before Moves.ModelOf read "-0.000" as "0.000" are put right first.
    for _, models in pairs(ns.DB.global.modelPicks) do
        for model, pick in pairs(models) do
            local fixed = model:gsub("%-0%.000", "0.000")
            if fixed ~= model then models[model] = nil; models[fixed] = models[fixed] or pick end
        end
    end
    for stage, models in pairs(ns.DB.global.modelPicks) do
        for model, pick in pairs(models) do
            local file = FileRow(stage, model)
            if file and math.abs(file.floor - pick.floor) < 1e-6 and math.abs(file.size - pick.size) < 1e-6 then
                models[model] = nil
            end
        end
    end
    for stage, scenes in pairs(ns.DB.global.placePicks) do
        for scene, pick in pairs(scenes) do
            local rows = ns.PetScenes and ns.PetScenes[stage]
            local file = rows and rows[scene]
            if file and math.abs(file.floor - pick.floor) < 0.01 and math.abs(file.size - pick.size) < 0.01 then
                scenes[scene] = nil
            end
        end
    end
    ns.Moves:SetPlaceEditing(true)
    -- Start at the model of the pet shown, if any.
    local st = self:Stage()
    local key = st.shown.key or st.shown.still
    local sid = key and ns.Pets:SpeciesOfKey(key)
    local at, pet = 1, 1
    for i, m in ipairs(self.models) do
        for j, x in ipairs(m.sids) do if x == sid then at, pet = i, j end end
    end
    self.frame:Show()
    self:Show(at, pet)
end

function Editor:Close()
    if self.frame then self.frame:Hide() end
    ns.Moves:SetPlaceEditing(false)
    for _, st in ipairs(ns.Moves.stages) do st:Relift() end -- (the file's again)
end

function Editor:Toggle()
    if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
