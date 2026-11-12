-- CreateFrame (with the templates' mixins), templates, file ids, atlases, UIParent, the chat
-- frame, slash commands, StaticPopup, ToggleCollectionsJournal.
local H, P = ...
local Frame = P.Frame

return function(c, env, S)
    local w = c.world
    -- Frames
    -- The Collections window by its key binding's function (c.toggled counts), as Blizzard's: shown on
    -- that tab (no tab: hidden, or shown, the first time loaded, on the page it had: CollectionsJournal_SetTab
    -- only with a tab); hidden again when it's open on that tab or none was given.
    env.ToggleCollectionsJournal = function(tab)
        c.toggled = (c.toggled or 0) + 1
        local cj = rawget(env, "CollectionsJournal")
        if cj and cj:IsShown() and (not tab or tab == cj.selectedTab) then cj:Hide(); return end
        if not cj then c:OpenJournal() end
        env.CollectionsJournal:Show()
        if tab then env.CollectionsJournal_SetTab(env.CollectionsJournal, tab) end
    end
    env.CreateFrame = function(ftype, name, parent, template)
        local f = setmetatable({ type = ftype, frameName = name, parent = parent, events = {}, scripts = {},
            shown = true, enabled = true, checked = false, textures = {}, fontStrings = {}, template = template }, Frame)
        f.client = c
        c.frames[#c.frames + 1] = f
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
