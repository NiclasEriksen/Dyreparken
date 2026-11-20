-- Addon messages, with the server's throttle (10 per prefix, +1 a second), and Enum.
local H, P = ...

return function(c, env, S)
    local w = c.world
    -- Addon messages
    env.C_ChatInfo = {
        RegisterAddonMessagePrefix = function(p)
            assert(#p <= 16, "prefix too long")
            c.prefixes[p] = true
            return true
        end,
        IsAddonMessagePrefixRegistered = function(p) return c.prefixes[p] == true end,
        SendAddonMessage = function(prefix, text, chan, target)
            assert(type(text) == "string" and #text <= 255, "addon message over 255 bytes")
            assert(chan ~= "WHISPER" or target, "whisper without target")
            if c.trial then return 7 end -- Trial/Veteran accounts can't send
            -- A test's own answer from the server (c.sendCode(text, chan): a code, nil to send; it may throw).
            local code = c.sendCode and c.sendCode(text, chan)
            if code then return code end
            -- The server's throttle (docs/FOREVER_API.md): per prefix, 10
            -- messages, +1 per second. Over it, the message is dropped.
            c.throttle = c.throttle or {}
            local b = c.throttle[prefix] or { tokens = 10, at = w.t }
            c.throttle[prefix] = b
            b.tokens, b.at = math.min(10, b.tokens + (w.t - b.at)), w.t
            if b.tokens < 1 then
                w.throttled = (w.throttled or 0) + 1
                return 3
            end
            b.tokens = b.tokens - 1
            w:Transmit(c, prefix, text, chan, target)
            return 0
        end,
    }
    env.Enum = {
        SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, NotInGroup = 5, ChannelThrottle = 8,
            NotInGuild = 10, AddOnMessageLockdown = 11, TargetOffline = 12 },
        TooltipDataType = { Unit = 2, Object = 4 },
        UITextureSliceMode = { Stretched = 0, Tiled = 1 },
        PlayerInteractionType = { Merchant = 5, Trainer = 7, Banker = 8, CharacterBanker = 67, MailInfo = 17, Auctioneer = 21 }, -- (Trainer 7 on
        -- Forever: /dp probe api feats; MailInfo, Auctioneer seen there 2026-11-20; the two bankers in its enum)
    }

end
