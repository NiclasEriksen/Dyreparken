-- Timers (C_Timer), muted sounds, CVars, addon metadata.
local H, P = ...
local ADDON, TOC = P.ADDON, P.TOC

return function(c, env, S)
    local w = c.world
    -- Timers
    env.C_Timer = {
        After = function(s, fn) w:Timer(c, s, fn) end,
        NewTimer = function(s, fn)
            local h = { cancelled = false }
            function h:Cancel() self.cancelled = true end
            w:Timer(c, s, function() if not h.cancelled then fn(h) end end)
            return h
        end,
    }

    -- Sound: mutes are a set of file IDs (the client forgets them on reload).
    c.muted = {}
    env.MuteSoundFile = function(id) c.muted[id] = true end
    env.UnmuteSoundFile = function(id) c.muted[id] = nil end

    -- Settings, addons
    env.C_CVar = { GetCVar = function(k) return (c.cvars or {})[k] or "1" end,
        SetCVar = function(k, v) c.cvars = c.cvars or {}; c.cvars[k] = tostring(v) end }
    env.C_AddOns = {
        GetAddOnMetadata = function(name, k)
            if name ~= ADDON then return nil end
            if k == "Version" then return c.version end
            if k == "X-Protocol" then return c.protocol end
            if k == "X-Protocol-Floor" then return c.floor end
            return TOC.meta[k]
        end,
        IsAddOnLoaded = function(n) return c.loaded[n] or false end,
    }
    -- Blizzard's options panel (Esc > Options > AddOns; on Forever: docs/FOREVER_API.md). A category is
    -- a canvas frame with a name; the panel shows it when picked (c:OpenOptions).
    c.optionCategories = {}
    env.Settings = {
        RegisterCanvasLayoutCategory = function(frame, name)
            assert(type(frame) == "table" and type(name) == "string", "RegisterCanvasLayoutCategory(frame, name)")
            local cat = { frame = frame, name = name, ID = #c.optionCategories + 1 }
            function cat:GetID() return self.ID end
            return cat
        end,
        RegisterAddOnCategory = function(cat)
            assert(type(cat) == "table" and cat.frame, "RegisterAddOnCategory(category)")
            c.optionCategories[#c.optionCategories + 1] = cat
        end,
        -- (Esc > Options at a category; c.optionsOpened: its id)
        OpenToCategory = function(id) c.optionsOpened = id end,
    }

end
