local _, ns = ...

-- /dp probe moves (development, 2026-11-10): a window to step through every
-- companion on the pet card and pick, for each part of each reaction (lying
-- down, held asleep, getting up; sitting down...; happy, cheer...), which
-- animation it plays, and how far into lying down it's paused (sleepAt).
-- Like /dp probe lift: the user's idea, after quick /dp probe anim tries on
-- one card after another (and at night) gave muddled results.
--
-- Every part is a row: its animation (< >) and >>, which plays it at once and
-- leaves it so (a lie-down paused at its point, a loop looping; 2026-11-10, the
-- user: a delay first and a reset to standing after felt buggy). "Hele" plays the
-- whole reaction of the last row tried, in order; "Stå" stands it up. While the
-- window is open the card's pet just stands otherwise (Moves.movesEditing: no
-- sleeping at night). Every pick that differs from Data/PetMoves.lua is saved in
-- DyreparkenDB.movePicks (species id -> { part = id or false, sleepAt = n }), to be
-- read from the SavedVariables and written into the file. While open, the card
-- uses the picks (Moves:For).
local Editor = {}
ns.MovesEditor = Editor

-- The parts, top to bottom, with what the window calls them (the user, 2026-11-10:
-- "select the lay down, sleep, get up animations").
Editor.PARTS = {
    { "sleep", "Sleep: lie down" }, { "sleepHold", "Sleep: held (none: paused)" }, { "sleepUp", "Sleep: get up" },
    { "sitDown", "Sit: sit down" }, { "sit", "Sit: sitting" }, { "sitUp", "Sit: get up" },
    { "happy", "Happy (a click)" }, { "happyToo", "Happy: now and then" }, { "cheer", "Cheer (level-up)" }, { "dead", "Playing dead" },
    { "walk", "Walk" }, { "run", "Run" },
}
Editor.MIN, Editor.MAX, Editor.STEP = 0.1, 2.5, 0.05
local ROW_H = 24

-- The file's value for a species (no picks).
local function FileValue(sid, what)
    local data = ns.PetMoves
    local own = data.species[sid]
    local v = own and own[what]
    if v == nil then v = data.default[what] end
    return v
end

local function List()
    local list = {}
    for sid in pairs(ns.Companions and ns.Companions.species or {}) do list[#list + 1] = sid end
    table.sort(list)
    return list
end

local function Picks(sid, make)
    local all = ns.DB.global.movePicks
    if make and not all[sid] then all[sid] = {} end
    return all[sid]
end

function Editor:Species() return self.list and self.list[self.index] end

-- The value in use for the current pet: its pick, else the file's.
function Editor:Value(what)
    local sid = self:Species()
    local p = Picks(sid)
    if p and p[what] ~= nil then return p[what] end
    return FileValue(sid, what)
end

-- Saves a value for the current pet (dropped when it's the file's).
function Editor:Set(what, value)
    local sid = self:Species()
    if not sid then return end
    if what == "sleepAt" then
        value = tonumber(("%.2f"):format(math.max(self.MIN, math.min(self.MAX,
            math.floor(value / self.STEP + 0.5) * self.STEP))))
    end
    local same = value == FileValue(sid, what)
    local p = Picks(sid, not same)
    if p then
        if same then p[what] = nil else p[what] = value end -- (value may be false: "none", or can't sit)
        if not next(p) then ns.DB.global.movePicks[sid] = nil end
    end
    self:Redraw(what == "sleepAt")
end

-- The next (or previous) animation for a part, "none" among them.
function Editor:StepAnim(what, dir)
    local ids = { false }
    for _, a in ipairs(ns.Moves.ANIMS) do ids[#ids + 1] = a[1] end
    local now = self:Value(what) or false
    local at = 1
    for i, id in ipairs(ids) do if id == now then at = i end end
    self:Set(what, ids[(at - 1 + dir) % #ids + 1])
end

function Editor:Try(what, whole)
    local sid = self:Species()
    if not sid then return end
    if what ~= "stand" then self.last = what end
    ns.Moves:Try(ns.Pets:KeyOfSpecies(sid), what, whole)
end

function Editor:Show(index)
    self.index = math.max(1, math.min(#self.list, index))
    ns.JournalUI:ShowSpecies(self:Species())
    self:Redraw()
end

local function AnimName(id)
    if id == false or id == nil then return "none" end
    for _, a in ipairs(ns.Moves.ANIMS) do if a[1] == id then return ("%s (%d)"):format(a[2], id) end end
    return "#" .. tostring(id)
end

function Editor:Redraw(fromSlider)
    local f = self.frame
    local sid = self:Species()
    if not (f and sid) then return end
    local p = Picks(sid) or {}
    f.name:SetText(("%s (%d)"):format(ns.Pets:NameOfKey(ns.Pets:KeyOfSpecies(sid)) or "?", sid))
    f.count:SetText(("%d / %d"):format(self.index, #self.list))
    local sits = self:Value("canSit") ~= false
    f.sits:SetChecked(sits)
    if p.canSit ~= nil then f.sits.label:SetTextColor(0.4, 1, 0.4) else f.sits.label:SetTextColor(1, 0.82, 0) end
    for _, row in ipairs(f.rows) do
        row.anim:SetText(AnimName(self:Value(row.what)))
        local off = row.what:find("^sit") and not sits -- (a pet that can't sit: its sit rows are unused)
        if off then row.anim:SetTextColor(0.4, 0.4, 0.4)
        elseif p[row.what] ~= nil then row.anim:SetTextColor(0.4, 1, 0.4)
        else row.anim:SetTextColor(1, 1, 1) end
        for _, b in ipairs({ row.prev, row.next, row.play }) do b:SetEnabled(not off) end
    end
    -- Paused there, or (with a held loop) how long lying down plays before the loop: cut
    -- short, it snaps (2026-11-11, the user: the cats jittered as they lay down).
    local paused = not self:Value("sleepHold")
    f.time:SetText((paused and "paused %.2f s into lying down%s" or "lying down for %.2f s, then the loop%s"):format(
        self:Value("sleepAt") or 0, p.sleepAt ~= nil and " (changed)" or ""))
    if not fromSlider then
        self.quiet = true
        f.slider:SetValue(self:Value("sleepAt") or 0)
        self.quiet = false
    end
    local n = 0
    for _ in pairs(ns.DB.global.movePicks) do n = n + 1 end
    f.saved:SetText(("%d pets changed (DyreparkenDB.movePicks). Green: changed."):format(n))
end

local function Button(parent, text, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 60, 22)
    b:SetText(text)
    return b
end

-- The pause point changed: show it at once.
local function SetAt(v)
    Editor:Set("sleepAt", v)
    Editor:Try("sleep")
end

function Editor:Build()
    local f = CreateFrame("Frame", "DyreparkenMovesEditor", UIParent)
    f:SetSize(400, 70 + #self.PARTS * ROW_H + 136)
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
    f.title:SetText("Dyreparken: moves (dev)")
    f.close = Button(f, "X", 24)
    f.close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
    f.close:SetScript("OnClick", function() Editor:Close() end)
    -- The pet.
    f.name = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.name:SetPoint("TOP", f, "TOP", 0, -32)
    f.count = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.count:SetPoint("TOP", f.name, "BOTTOM", 0, -2)
    f.prev = Button(f, "<", 30)
    f.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -30)
    f.prev:SetScript("OnClick", function() Editor:Show(Editor.index - 1) end)
    f.next = Button(f, ">", 30)
    f.next:SetPoint("TOPRIGHT", f, "TOPRIGHT", -40, -30)
    f.next:SetScript("OnClick", function() Editor:Show(Editor.index + 1) end)
    -- A row per part: its name, < animation >, and >> to play it.
    f.rows = {}
    for i, part in ipairs(self.PARTS) do
        local y = -70 - (i - 1) * ROW_H
        local row = { what = part[1] }
        row.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.label:SetPoint("TOPLEFT", f, "TOPLEFT", 12, y - 5)
        row.label:SetText(part[2])
        row.prev = Button(f, "<", 22)
        row.prev:SetPoint("TOPLEFT", f, "TOPLEFT", 180, y)
        row.prev:SetScript("OnClick", function() Editor:StepAnim(part[1], -1) end)
        row.anim = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.anim:SetPoint("LEFT", row.prev, "RIGHT", 4, 0)
        row.anim:SetWidth(130)
        row.next = Button(f, ">", 22)
        row.next:SetPoint("LEFT", row.anim, "RIGHT", 4, 0)
        row.next:SetScript("OnClick", function() Editor:StepAnim(part[1], 1) end)
        row.play = Button(f, ">>", 30)
        row.play:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, y)
        row.play:SetScript("OnClick", function() Editor:Try(part[1]) end)
        f.rows[i] = row
    end
    -- Sit? Unticked, the pet never sits on the card (the user, 2026-11-11).
    f.sits = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    f.sits:SetSize(22, 22)
    f.sits:SetPoint("RIGHT", f.rows[5].label, "LEFT", 0, 0)
    f.sits.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.sits.label:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -70 - #self.PARTS * ROW_H - 4)
    f.sits:ClearAllPoints()
    f.sits:SetPoint("LEFT", f.sits.label, "RIGHT", 2, 0)
    f.sits.label:SetText("Sit?")
    f.sits:SetScript("OnClick", function(self) Editor:Set("canSit", self:GetChecked() and true or false) end)
    -- How far into lying down it's paused; a change shows at once.
    local y = -70 - #self.PARTS * ROW_H - 36
    f.slider = CreateFrame("Slider", "DyreparkenMovesSlider", f, "OptionsSliderTemplate")
    f.slider:SetPoint("TOP", f, "TOP", 0, y)
    f.slider:SetSize(200, 16)
    f.slider:SetOrientation("HORIZONTAL")
    f.slider:SetMinMaxValues(self.MIN, self.MAX)
    f.slider:SetValueStep(self.STEP)
    f.slider:SetObeyStepOnDrag(true)
    f.slider:SetScript("OnValueChanged", function(_, v)
        if not Editor.quiet then SetAt(v) end
    end)
    f.time = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.time:SetPoint("TOP", f.slider, "BOTTOM", 0, -4)
    f.down = Button(f, "-0.05", 50)
    f.down:SetPoint("RIGHT", f.slider, "LEFT", -10, 0)
    f.down:SetScript("OnClick", function() SetAt((Editor:Value("sleepAt") or 0) - Editor.STEP) end)
    f.up = Button(f, "+0.05", 50)
    f.up:SetPoint("LEFT", f.slider, "RIGHT", 10, 0)
    f.up:SetScript("OnClick", function() SetAt((Editor:Value("sleepAt") or 0) + Editor.STEP) end)
    -- The whole reaction of the last part tried; standing; back to the file's for this pet.
    f.whole = Button(f, "Hele", 90)
    f.whole:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 30, 26)
    f.whole:SetScript("OnClick", function() Editor:Try(Editor.last or "sleep", true) end)
    f.stand = Button(f, "Stå", 70)
    f.stand:SetPoint("BOTTOM", f, "BOTTOM", 0, 26)
    f.stand:SetScript("OnClick", function() Editor:Try("stand") end)
    f.reset = Button(f, "File's", 90)
    f.reset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -30, 26)
    f.reset:SetScript("OnClick", function()
        ns.DB.global.movePicks[Editor:Species()] = nil
        Editor:Redraw()
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
    ns.Moves:SetEditing(true)
    local card = ns.JournalUI._card
    local sid = card and card.key and ns.Pets:SpeciesOfKey(card.key)
    local at = 1
    for i, s in ipairs(self.list) do if s == sid then at = i end end
    self.frame:Show()
    self:Show(at)
end

function Editor:Close()
    if self.frame then self.frame:Hide() end
    ns.Moves:SetEditing(false)
end

function Editor:Toggle()
    if self.frame and self.frame:IsShown() then self:Close() else self:Open() end
end
