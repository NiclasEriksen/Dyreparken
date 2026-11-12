local _, ns = ...

-- /dp probe lift (development, 2026-11-10): a small window to step through
-- every companion on the pet card and set how far up or down it stands
-- (`lift`, Data/PetMoves.lua) with a slider. Every value that differs from
-- the file's is saved in DyreparkenDB.liftPicks (species id -> lift), to be
-- read from the SavedVariables and written into Data/PetMoves.lua. While the
-- window is open the card uses the picks (Moves:For); closed, the file's again.
local Editor = {}
ns.LiftEditor = Editor

Editor.MIN, Editor.MAX, Editor.STEP = -3, 3, 0.05

local function Default(sid)
    local own = ns.PetMoves and ns.PetMoves.species[sid]
    return own and own.lift or 0
end

-- Every species in the journal data, by id.
local function List()
    local list = {}
    for sid in pairs(ns.Companions and ns.Companions.species or {}) do list[#list + 1] = sid end
    table.sort(list)
    return list
end

function Editor:Current()
    local sid = self.list and self.list[self.index]
    if not sid then return nil end
    local pick = ns.DB.global.liftPicks[sid]
    if pick == nil then pick = Default(sid) end
    return sid, pick
end

local function Round(v) return tonumber(("%.2f"):format(math.floor(v / Editor.STEP + 0.5) * Editor.STEP)) end -- (0.6, not 0.6000000000000001)

-- Set the current species' lift (saved when it differs from the file's).
function Editor:Set(value)
    local sid = self:Current()
    if not sid then return end
    value = math.max(self.MIN, math.min(self.MAX, Round(value)))
    if math.abs(value - Default(sid)) < 1e-6 then
        ns.DB.global.liftPicks[sid] = nil
    else
        ns.DB.global.liftPicks[sid] = value
    end
    ns.Moves:Relift()
    self:Redraw(true)
end

function Editor:Show(index)
    self.index = math.max(1, math.min(#self.list, index))
    local sid = self:Current()
    if ns.JournalUI:ShowSpecies(sid) then ns.Moves:Relift() end
    self:Redraw()
end

function Editor:Redraw(fromSlider)
    local f = self.frame
    local sid, lift = self:Current()
    if not (f and sid) then return end
    local name = ns.Pets:NameOfKey(ns.Pets:KeyOfSpecies(sid)) or "?"
    f.name:SetText(("%s (%d)"):format(name, sid))
    f.count:SetText(("%d / %d"):format(self.index, #self.list))
    f.value:SetText(("lift %+.2f%s"):format(lift, ns.DB.global.liftPicks[sid] ~= nil and " (changed)" or ""))
    local n = 0
    for _ in pairs(ns.DB.global.liftPicks) do n = n + 1 end
    f.saved:SetText(("%d changed (DyreparkenDB.liftPicks)"):format(n))
    if not fromSlider then
        self.quiet = true
        f.slider:SetValue(lift)
        self.quiet = false
    end
end

local function Button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 60, 22)
    b:SetText(text)
    return b
end

function Editor:Build()
    local f = CreateFrame("Frame", "DyreparkenLiftEditor", UIParent)
    f:SetSize(300, 170)
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
    f.title:SetText("Dyreparken: lift (dev)")
    f.close = Button(f, "X", 24)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.close:SetScript("OnClick", function() Editor:Close() end)
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.name:SetPoint("TOP", f, "TOP", 0, -32)
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("TOP", f.name, "BOTTOM", 0, -2)
    f.prev = Button(f, "<", 30)
    f.prev:SetPoint("LEFT", f, "LEFT", 10, 34)
    f.prev:SetScript("OnClick", function() Editor:Show(Editor.index - 1) end)
    f.next = Button(f, ">", 30)
    f.next:SetPoint("RIGHT", f, "RIGHT", -10, 34)
    f.next:SetScript("OnClick", function() Editor:Show(Editor.index + 1) end)
    f.slider = CreateFrame("Slider", "DyreparkenLiftSlider", f, "OptionsSliderTemplate")
    f.slider:SetPoint("TOP", f, "TOP", 0, -80)
    f.slider:SetSize(220, 16)
    f.slider:SetOrientation("HORIZONTAL")
    f.slider:SetMinMaxValues(self.MIN, self.MAX)
    f.slider:SetValueStep(self.STEP)
    f.slider:SetObeyStepOnDrag(true)
    f.slider:SetScript("OnValueChanged", function(_, v)
        if not Editor.quiet then Editor:Set(v) end
    end)
    f.value = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.value:SetPoint("TOP", f.slider, "BOTTOM", 0, -6)
    f.down = Button(f, "-0.05", 50)
    f.down:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -112)
    f.down:SetScript("OnClick", function() Editor:Set(select(2, Editor:Current()) - Editor.STEP) end)
    f.up = Button(f, "+0.05", 50)
    f.up:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -112)
    f.up:SetScript("OnClick", function() Editor:Set(select(2, Editor:Current()) + Editor.STEP) end)
    f.reset = Button(f, "File's", 70)
    f.reset:SetPoint("TOP", f, "TOP", 0, -112)
    f.reset:SetScript("OnClick", function()
        local sid = Editor:Current()
        if sid then Editor:Set(Default(sid)) end
    end)
    f.saved = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.saved:SetPoint("BOTTOM", f, "BOTTOM", 0, 8)
    self.frame = f
end

function Editor:Open()
    if not (rawget(_G, "PetJournal") and PetJournal:IsVisible()) then
        return ns.Print("Open the pet journal first.")
    end
    if not self.frame then self:Build() end
    self.list = List()
    -- Picks already written into the file are no longer changes.
    local picks = ns.DB.global.liftPicks
    for sid, v in pairs(picks) do
        if math.abs(v - Default(sid)) < 1e-6 then picks[sid] = nil end
    end
    ns.Moves:SetLiftEditing(true)
    -- Start at the pet on the card, if it's one of them.
    local card = ns.JournalUI:Card()
    local at = 1
    local sid = card and card.key and ns.Pets:SpeciesOfKey(card.key)
    for i, s in ipairs(self.list) do if s == sid then at = i end end
    self.frame:Show()
    self:Show(at)
end

function Editor:Close()
    if self.frame then self.frame:Hide() end
    ns.Moves:SetLiftEditing(false)
    ns.Moves:Relift() -- (the file's lift again)
end

function Editor:Toggle()
    if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
