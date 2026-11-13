-- CreateFrame (with the templates' mixins), templates, file ids, atlases, UIParent, the chat
-- frame, slash commands, StaticPopup, ToggleCollectionsJournal.
local H, P = ...
local Frame = P.Frame

return function(c, env, S)
    local w = c.world
    -- Frames
    -- The Collections window by its key binding's function (c.toggled counts), as Blizzard's: shown on
    -- that tab (no tab: hidden, or shown on the page it had; the first time, loaded, on Pets); hidden again
    -- when it's open on that tab or none was given. Called by addon code (insecure: c.insecureCJ counts), it
    -- writes the window's selected tab tainted (c.cjTainted): from then on, opening it in combat, even by its
    -- key binding, is blocked, as seen on Forever (2026-11-13, docs/FOREVER_API.md).
    env.ToggleCollectionsJournal = P.SecureFn(function(tab)
        c.toggled = (c.toggled or 0) + 1
        if (c.secure or 0) == 0 then c.insecureCJ = (c.insecureCJ or 0) + 1; c.cjTainted = true end
        local cj = rawget(env, "CollectionsJournal")
        if cj and cj:IsShown() and (not tab or tab == cj.selectedTab) then cj:Hide(); return end
        if c.cjTainted and S.combat and (c.secure or 0) > 0 then
            c.errors[#c.errors + 1] = "ADDON_ACTION_BLOCKED: AddOn 'Dyreparken' tried to call the protected function "
                .. "'MountJournal:SetShown()' (CollectionsJournal_UpdateSelectedTab: its tab was set by addon code)"
            return
        end
        local first = not cj
        if first then c:LoadCollections(); c:ListPets() end
        env.CollectionsJournal:Show()
        if tab or first then env.CollectionsJournal_SetTab(env.CollectionsJournal, tab or 2) end
    end)
    env.CreateFrame = function(ftype, name, parent, template)
        local f = setmetatable({ type = ftype, frameName = name, parent = parent, events = {}, scripts = {},
            shown = true, enabled = true, checked = false, textures = {}, fontStrings = {}, template = template }, Frame)
        f.client = c
        c.frames[#c.frames + 1] = f
        -- A secure template: a protected frame (P.Blocked), made out of combat only.
        if template and template:find("Secure") then
            if S.combat and (c.secure or 0) == 0 then
                c.errors[#c.errors + 1] = "ADDON_ACTION_BLOCKED: AddOn 'Dyreparken' tried to call the protected function 'CreateFrame()' ("
                    .. template .. " in combat)"
            end
            f.protected = true
            c.protectedFrames = c.protectedFrames or {}
            c.protectedFrames[#c.protectedFrames + 1] = f
        end
        -- SecureActionButtonTemplate's OnClick (Blizzard's SecureActionButton_OnClick, retail 10.x): it acts on
        -- the down or the up of a click as the ActionButtonUseKeyDown cvar says (default 1: the down), then
        -- does its "type": here "click" (clicks the "clickbutton" frame) and none.
        if template and template:find("SecureActionButtonTemplate") then
            f.scripts.OnClick = P.SecureFn(function(self, button, down)
                local useDown = env.C_CVar.GetCVar("ActionButtonUseKeyDown") == "1"
                if (down and true or false) ~= useDown then return end
                local kind = self:GetAttribute("type1") or self:GetAttribute("*type1") or self:GetAttribute("type")
                if kind == "click" then
                    local to = self:GetAttribute("clickbutton1") or self:GetAttribute("*clickbutton1")
                        or self:GetAttribute("clickbutton")
                    if to and not to:IsForbidden() then to:Click(button) end
                elseif kind ~= nil then
                    error("secure action type " .. tostring(kind) .. " is not stubbed (tools/test/harness/env/frames.lua)")
                end
            end)
        end
        -- PortraitFrameMixin, mixed in (a plain field, like the real client).
        if template == "ButtonFrameTemplate" then f.SetTitle = function(self, t) self.titleText = t end end
        -- A model scene of our own (ModelSceneMixinTemplate, as on Forever: /dp probe api petframe):
        -- set to a scene id, its "unwrapped" actor, view insets; it takes the mouse unless told not to.
        if ftype == "ModelScene" and template == "ModelSceneMixinTemplate" then
            f.mouse = true
            -- The mixin's OnUpdate (it drives the camera, on every frame drawn): counted.
            f.updates = 0
            f.scripts.OnUpdate = function(self) self.updates = self.updates + 1 end
            function f:TransitionToModelSceneID(id) self.sceneID = id end
            function f:GetModelSceneID() return self.sceneID end
            function f:SetViewInsets(l, r, t, b) self.insets = { l, r, t, b } end
            function f:EnableMouseWheel(v) self.wheel = v end
            function f:EnableMouse(v) self.mouse = v end
            function f:GetActorByTag(tag)
                if tag ~= "unwrapped" or not self.sceneID then return nil end
                self.actor = self.actor or H.NewActor(c)
                return self.actor
            end
        end
        -- Our side pages (Core/SidePage.lua names them Dyreparken<Id>Page): which one shows under
        -- which window title, so c:Page(title) finds a page by what the player reads.
        if name and name:match("^Dyreparken%w+Page$") then
            function f:Show()
                local cj = rawget(env, "CollectionsJournal")
                local title = cj and cj.titleFS and cj.titleFS.text
                if title then c.sidePages[title] = self end
                return Frame.Show(self)
            end
        end
        if name then rawset(env, name, f) end
        return f
    end
    -- Templates the client has. c.oldTemplates: only the pre-Dragonflight ones.
    local MODERN = { ButtonFrameTemplate = true, ScrollFrameTemplate = true }
    env.C_XMLUtil = { GetTemplateInfo = function(name)
        if MODERN[name] and c.oldTemplates then return nil end
        return { type = "Frame", width = 0, height = 0 }
    end }
    -- Paths the client has: every one, except those in c.missingFiles.
    env.GetFileIDFromPath = function(path)
        if c.missingFiles and c.missingFiles[path] then return nil end
        return 100000 + #path
    end
    -- Atlases the client has: those in c.atlases (none by default).
    env.C_Texture = { GetAtlasInfo = function(name)
        if c.atlases and c.atlases[name] then
            return { width = 64, height = 64, file = 4000 + #name, leftTexCoord = 0.25, rightTexCoord = 0.5,
                topTexCoord = 0.125, bottomTexCoord = 0.375 }
        end
        return nil
    end }
    env.ButtonFrameTemplate_HidePortrait = function(f) f.portraitHidden = true end
    env.ButtonFrameTemplate_HideButtonBar = function(f) f.buttonBarHidden = true end
    env.UIParent = env.CreateFrame("Frame", "UIParent")
    -- The micro menu's Collections button (Forever has it: the client's API dump): Blizzard's click,
    -- ToggleCollectionsJournal() with no tab, so the window opens on the page it had.
    env.CollectionsMicroButton = env.CreateFrame("Button", "CollectionsMicroButton", env.UIParent)
    env.CollectionsMicroButton:RegisterForClicks("AnyUp")
    env.CollectionsMicroButton:SetScript("OnClick", P.SecureFn(function() env.ToggleCollectionsJournal() end))
    -- Secure state drivers (SecureStateDriver.lua): the frame's state from macro conditions, applied by
    -- Blizzard's code, even in combat (Client:Drive). Registering is protected in combat.
    c.drivers = {}
    env.RegisterStateDriver = function(f, state, cond)
        if P.Blocked(f, "RegisterStateDriver") then return end
        c.drivers[f] = { state = state, cond = cond }
        c:Drive()
    end
    env.UnregisterStateDriver = function(f, state)
        if P.Blocked(f, "UnregisterStateDriver") then return end
        if c.drivers[f] and c.drivers[f].state == state then c.drivers[f] = nil end
    end
    env.Minimap = env.CreateFrame("Frame", "Minimap", env.UIParent)
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m)
        c.printed[#c.printed + 1] = (tostring(m):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    end }
    env.SlashCmdList = {}
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show = function(which, ...) c.popup = { which = which, args = { ... } } end
    env.ACCEPT, env.CANCEL = "Accept", "Cancel"
    env.UNITNAME_TITLE_COMPANION = "%s's Companion"
    env.UNKNOWNOBJECT = "Unknown" -- a unit the client has no name for yet

end
