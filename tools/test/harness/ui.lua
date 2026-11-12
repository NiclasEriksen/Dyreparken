-- What a test sees and touches of the UI: the world's tooltips and nameplates (Hover,
-- Target, Nameplate), a frame's own tooltip (TipOf), the pet journal (OpenJournal, ClickTab,
-- ListPets, Marker, Button, SelectPet, Card) and popups (PopupAccept).
local H, P = ...
local Client, Hardware, SpeciesName = P.Client, P.Hardware, P.SpeciesName

-- A nameplate comes up over a unit: o = { species, owner, companion (false: not a pet), name, forbidden }.
-- Returns the unit token and the plate.
function Client:Nameplate(o)
    local n = 0
    for _ in pairs(self.plates) do n = n + 1 end
    local unit = "nameplate" .. (n + 1)
    local lines = { { leftText = o.name or SpeciesName(o.species or 0), lineIndex = 1 } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner), lineIndex = 2 }
    end
    self.units[unit] = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = o.name or SpeciesName(o.species or 0) }
    local plate = self.env.CreateFrame("Frame")
    plate.namePlateUnitToken, plate.forbidden = unit, o.forbidden
    plate:Show()
    self.plates[unit] = plate
    self:Fire(o.forbidden and "FORBIDDEN_NAME_PLATE_UNIT_ADDED" or "NAME_PLATE_UNIT_ADDED", unit)
    return unit, plate
end


-- A frame's own tooltip: hover it (OnEnter), read GameTooltip, leave (OnLeave). Returns its
-- lines ({} if it showed none; .text: them joined with " / "), and their colors (by line).
function Client:TipOf(f)
    local tip = self.env.GameTooltip
    tip:SetOwner(nil) -- (nothing left over from an earlier hover)
    f.scripts.OnEnter(f)
    local lines, colors = {}, {}
    if tip.owner == f and tip.shown then
        for i, l in ipairs(tip.lines) do lines[i], colors[i] = l, tip.colors[i] end
    end
    lines.text = table.concat(lines, " / ")
    if f.scripts.OnLeave then f.scripts.OnLeave(f) end
    return lines, colors
end

-- World tooltip -------------------------------------------------------------------
-- Hover a companion: o = { species, owner ("First Surname" or nil), companion (false: not a pet) }.
-- Returns the lines the addon added (and the whole tooltip, third).
function Client:Hover(o)
    local unit = "mouseover"
    local lines = { { leftText = SpeciesName(o.species or 0) } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner) }
    end
    lines[#lines + 1] = { leftText = "Pet Level 1 Critter" }
    if o.lines then lines = o.lines end
    for i, l in ipairs(lines) do if type(l) == "table" and l.lineIndex == nil then l.lineIndex = i end end
    self.units[unit] = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = SpeciesName(o.species or 0) }
    local tip = self.env.GameTooltip
    tip:ClearLines()
    -- The client fills in the unit's own lines before the post-calls run.
    for _, l in ipairs(lines) do
        if type(l.leftText) == "string" then tip:AddLine(l.leftText) end
    end
    tip.unit = unit
    if o.unit == false then tip.unit = nil end
    local before = #tip.lines
    local data = not o.noData and { lines = lines } or nil
    self.lastTooltipData = data
    for _, fn in ipairs(self.tooltipCalls) do
        fn(o.tooltip or tip, data)
    end
    local added = {}
    for i = before + 1, #tip.lines do added[#added + 1] = tip.lines[i] end
    -- Third: every line of the tooltip as shown, after any rewriting.
    return added, table.concat(added, " / "), tip.lines
end

-- Target a companion (same o as Hover; nil clears the target).
function Client:Target(o)
    if not o then self.units.target = nil; return end
    local lines = { { leftText = SpeciesName(o.species or 0) } }
    if o.owner then
        lines[2] = { leftText = (self.env.UNITNAME_TITLE_COMPANION or "%s's Companion"):format(o.owner) }
    end
    lines[#lines + 1] = { leftText = "Pet Level 1 Critter" }
    self.units.target = { companion = o.companion ~= false, species = o.species, lines = lines,
        name = o.name or SpeciesName(o.species or 0) }
end

-- Pet journal -----------------------------------------------------------------------
-- Loads "Blizzard_Collections" (stub frames) on first open, shows it, and
-- lists the owned pets plus `o.extra` unowned species.
-- o.bare: list buttons without .speciesID (fallback via elementData.index)
-- o.scrollUtil: no PetJournal_InitPetButton, use ScrollUtil callbacks
function Client:OpenJournal(o)
    o = o or {}
    local env = self.env
    if not rawget(env, "PetJournal") then
        -- Forever's Collections window (probed 2026-11-07), with its side tabs
        -- along the right edge when o.sideTabs = n (laid out: geometry set):
        -- an unnamed strip as tall as the window, 55 px past its right edge,
        -- holding Frames CollectionsJournalTab1..n drawn with atlases. Tab 1
        -- is Mounts, tab 2 Pets (selected). A tab switches on mouse up
        -- (CollectionsJournal_SetTab): pages, the selected highlight, the title.
        local CJ = env.CreateFrame("Frame", "CollectionsJournal")
        CJ.shown = false
        CJ.titleFS = CJ:CreateFontString()
        CJ.GetTitleText = function(self) return self.titleFS end -- PortraitFrameMixin
        -- PortraitFrameTemplate's parentKeys: border, portrait, title, close
        -- button (frames), and the background (a tiled texture).
        CJ.NineSlice = env.CreateFrame("Frame", nil, CJ); CJ.NineSlice.level = 3
        CJ.PortraitContainer = env.CreateFrame("Frame", nil, CJ); CJ.PortraitContainer.level = 4
        CJ.PortraitContainer.portrait = CJ.PortraitContainer:CreateTexture()
        CJ.PortraitContainer.portrait:SetTexture(1001) -- Pets' portrait, a file id
        CJ.TitleContainer = env.CreateFrame("Frame", nil, CJ); CJ.TitleContainer.level = 5
        CJ.CloseButton = env.CreateFrame("Button", "CollectionsJournalCloseButton", CJ); CJ.CloseButton.level = 5
        CJ.Bg = CJ:CreateTexture(); CJ.Bg:SetTexture(2002)
        local MJ = env.CreateFrame("Frame", "MountJournal", CJ)
        MJ.shown = false
        local PJ = env.CreateFrame("Frame", "PetJournal", CJ)
        CJ.geo = o.sideTabs and { l = 0, r = 700, t = 600, b = 0 } or nil
        local strip = env.CreateFrame("Frame", nil, CJ)
        strip.geo = o.sideTabs and { l = 700, r = 755, t = 600, b = 0 } or nil
        local tabs = {}
        rawset(env, "CollectionsJournal_SetTab", function(cj, n)
            cj.selectedTab = n
            for i, t in ipairs(tabs) do
                t.sel1:SetShown(i == n); t.sel2:SetShown(i == n)
            end
            MJ:SetShown(n == 1)
            PJ:SetShown(n == 2)
            cj.titleFS:SetText(n == 1 and "Mounts" or n == 2 and "Pet Journal" or "Tab " .. n)
        end)
        for i = 1, o.sideTabs or 0 do
            local t = env.CreateFrame("Frame", "CollectionsJournalTab" .. i, strip)
            t:CreateTexture():SetAtlas("common-sidetab")
            t:CreateTexture():SetTexture("tab" .. i)
            t.sel1 = t:CreateTexture(); t.sel1:SetAtlas("common-sidetab-selected")
            t.sel2 = t:CreateTexture(); t.sel2:SetAtlas("common-sidetab-selected")
            t:CreateTexture():SetAtlas("common-sidetab-hover")
            t.geo = { l = 700, r = 755, t = 560 - (i - 1) * 57, b = 505 - (i - 1) * 57 }
            t:SetScript("OnMouseUp", function() env.CollectionsJournal_SetTab(CJ, i) end)
            tabs[i] = t
        end
        PJ.shown = false
        PJ.ScrollBox = { buttons = {} }
        function PJ.ScrollBox:ForEachFrame(fn) for _, b in ipairs(self.buttons) do fn(b) end end
        local petCard = env.CreateFrame("Frame", "PetJournalPetCard", PJ)
        -- Its title row: the pet's icon and name (Forever, /dp probe card 2026-11-08).
        petCard.PetInfo = env.CreateFrame("Button", "PetJournalPetCardPetInfo", petCard)
        petCard.PetInfo.icon = petCard.PetInfo:CreateTexture()
        petCard.PetInfo.name = petCard.PetInfo:CreateFontString()
        -- The "Total Pets" box (o.noPetCount leaves it out).
        if not o.noPetCount then PJ.PetCount = env.CreateFrame("Frame", nil, PJ) end
        -- The model with its two turn buttons (parentKeys, like Retail's
        -- ModelScene; o.noRotate leaves them out).
        if not o.noRotate then
            local model = env.CreateFrame("Frame", nil, petCard)
            petCard.modelScene = model
            model.RotateLeftButton = env.CreateFrame("Button", nil, model)
            model.RotateRightButton = env.CreateFrame("Button", nil, model)
            -- The pet's actor (retail's ModelScene: GetActorByTag). It has the animations in
            -- self.petAnims (default: stand, the happy hop, playing dead); o.noActor leaves it out.
            if not o.noActor then
                local actor = H.NewActor(self)
                function model:Project3DPointTo2D(x, y, z) return 200 + x * 100, 150 + z * 100, 1 end
                function model:GetModelSceneID() return self.sceneID end
                function model:GetActorByTag(tag) if tag == "unwrapped" then return actor end end
                self.petActor = actor
            end
        end
        env.CreateFrame("Button", "PetJournalSummonButton", PJ)
        if o.scrollUtil then
            self.scrollCallbacks = {}
            rawset(env, "ScrollUtil", { AddInitializedFrameCallback = function(box, fn, owner)
                assert(box == PJ.ScrollBox)
                self.scrollCallbacks[#self.scrollCallbacks + 1] = fn
            end })
        else
            rawset(env, "PetJournal_InitPetButton", function() end)
        end
        rawset(env, "PetJournal_UpdatePetCard", function() end)
        -- Selects a species and shows its card (Blizzard_Collections; o.noSelect: missing).
        -- Forever's selects only a pet in the list, one you own (2026-11-09); any other
        -- species' card comes from ShowPetCardBySpeciesID.
        if not o.noSelect then
            rawset(env, "PetJournal_SelectSpecies", function(pj, sid)
                assert(pj == env.PetJournal, "PetJournal_SelectSpecies(PetJournal, speciesID)")
                if not self:GuidOf(sid) then return end
                self.selectedSpecies = sid
                self:SelectPet(sid)
            end)
        end
        rawset(env, "PetJournal_ShowPetCardBySpeciesID", function(sid)
            self.shownSpecies = sid
            self:SelectPet(sid)
        end)
        self.loaded.Blizzard_Collections = true
        self:Fire("ADDON_LOADED", "Blizzard_Collections")
    end
    self:ListPets(o)
    env.CollectionsJournal:Show()
    if env.CollectionsJournal.selectedTab == nil and rawget(env, "CollectionsJournalTab2") then
        env.CollectionsJournal_SetTab(env.CollectionsJournal, 2)
    end
    env.PetJournal:Show()
    return self
end

function Client:CloseJournal() self.env.CollectionsJournal:Hide() end

-- Press side tab n of the Collections window: mouse down, then up (a click).
function Client:ClickTab(n)
    local t = self.env["CollectionsJournalTab" .. n]
    for _, s in ipairs({ "OnMouseDown", "OnMouseUp" }) do
        if t.scripts[s] then Hardware(self, t.scripts[s], t, "LeftButton") end
    end
end

function Client:ListPets(o)
    o = o or {}
    local env = self.env
    local list = {}
    for _, p in ipairs(self.pets) do list[#list + 1] = { guid = p.guid, sid = p.sid, owned = true } end
    for _, sid in ipairs(o.extra or {}) do list[#list + 1] = { sid = sid, owned = false } end
    self.journalList = list
    local buttons = {}
    for i, e in ipairs(list) do
        local b = env.CreateFrame("Button", nil, env.PetJournal)
        if not o.bare then b.petID, b.speciesID, b.owned = e.guid, e.sid, e.owned end
        b.sid = e.sid -- for the harness only
        b.name = b:CreateFontString() -- the species' name, as on Retail's list buttons
        buttons[i] = b
    end
    env.PetJournal.ScrollBox.buttons = buttons
    for i, b in ipairs(buttons) do
        if rawget(env, "PetJournal_InitPetButton") then
            env.PetJournal_InitPetButton(b, { index = i })
        else
            for _, fn in ipairs(self.scrollCallbacks or {}) do fn(nil, b, { index = i }) end
        end
    end
end

-- Texture path of the marker on a species' list button, or nil if hidden.
function Client:Marker(sid)
    for _, b in ipairs(self.env.PetJournal.ScrollBox.buttons) do
        if b.sid == sid then
            local t = b.textures[1]
            return t and t.shown and t.tex or nil
        end
    end
    error("no list button for species " .. sid)
end

function Client:Button(sid)
    for _, b in ipairs(self.env.PetJournal.ScrollBox.buttons) do if b.sid == sid then return b end end
end

-- Select a pet on the card, as the journal does.
-- The card's model scene: each species has one (c.modelScenes[sid], default: one per
-- height in c.modelHeights[sid], default 0), and the actor's height is the scene's. Like
-- Blizzard's TransitionToModelSceneID, the height is set only when the scene changes:
-- between two pets of one scene the actor stays where it was (2026-11-10).
function Client:SelectPet(sid, byPetID)
    local card = self.env.PetJournalPetCard
    local actor = self.petActor
    if actor and actor.pos then
        local height = (self.modelHeights or {})[sid] or 0
        local scene = (self.modelScenes or {})[sid] or 1000 + math.floor(height * 100 + 0.5)
        local model = card.modelScene
        if scene ~= model.sceneID then
            model.sceneID = scene
            actor.pos = { 0, 0, height }
        end
    end
    self.cardSpecies = sid
    if byPetID then card.speciesID, card.petID = nil, self:GuidOf(sid) else card.speciesID, card.petID = sid, nil end
    self.env.PetJournal_UpdatePetCard(card)
    return self.ns.JournalUI:Card()
end

function Client:Card() return self.ns.JournalUI:Card() end

-- The last StaticPopup shown; Accept types `text` into its edit box.
function Client:PopupAccept(text, viaEnter)
    local p = assert(self.popup, "no popup shown")
    local dialog = self.env.StaticPopupDialogs[p.which]
    local eb = { text = "" }
    function eb:SetText(t) self.text = t end
    function eb:GetText() return self.text end
    function eb:HighlightText() end
    -- StaticPopup_Show(which, text1, text2, data): data reaches OnAccept (and dialog.data), as in the client.
    local data = p.args[3]
    local frame = { editBox = eb, data = data, Hide = function(f) f.hidden = true end }
    function eb:GetParent() return frame end
    if dialog.OnShow then dialog.OnShow(frame) end
    local shown = eb.text
    eb.text = text
    -- Clicking Accept or pressing Enter is a hardware event.
    if viaEnter then Hardware(self, dialog.EditBoxOnEnterPressed, eb) else Hardware(self, dialog.OnAccept, frame, data) end
    self.popup = nil
    return shown, frame
end
