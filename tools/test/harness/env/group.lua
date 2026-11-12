-- The group, and chat: guild posts only from a keypress or click, like Forever.
local H, P = ...
local LATENCY = P.LATENCY

return function(c, env, S)
    local w = c.world
    -- Group
    env.IsInGroup = function() return w:GroupOf(c.name) ~= nil end
    env.IsInRaid = function() local g = w:GroupOf(c.name); return g ~= nil and #g.members > 5 end
    env.GetNumGroupMembers = function() local g = w:GroupOf(c.name); return g and #g.members or 0 end
    env.GetNumSubgroupMembers = function() local g = w:GroupOf(c.name); return g and math.min(#g.members, 5) - 1 or 0 end
    env.UnitIsGroupLeader = function(u)
        local g = w:GroupOf(c.name)
        return g ~= nil and (u == "player" and g.members[1] == c.name)
    end
    env.UnitIsGroupAssistant = function() return c.assist == true end
    env.UnitInParty = function(u) return u == "player" and w:GroupOf(c.name) ~= nil end
    env.UnitInRaid = function(u) return u == "player" and env.IsInRaid() and 1 or nil end
    -- Guild and group chat come back to every online member, the sender included.
    -- c.chatBlocked = "error" | "silent" simulates a client that refuses.
    -- Like Forever, a GUILD post that isn't from a keypress or click (Slash,
    -- Click) is blocked: nothing is posted, no Lua error, and the test fails
    -- unless it takes the error (c:TakeErrors()). PARTY/RAID are unprobed.
    env.SendChatMessage = function(text, chan)
        if c.chatBlocked == "error" then error("SendChatMessage: blocked", 2) end
        if c.chatBlocked == "silent" then return end
        if chan == "GUILD" and (c.hardware or 0) == 0 then
            c.errors[#c.errors + 1] = "ADDON_ACTION_BLOCKED: SendChatMessage GUILD outside a keypress or click"
            return
        end
        w.chat[#w.chat + 1] = { from = c.name, text = text, chan = chan }
        local g = w:GroupOf(c.name)
        w:Timer(c, LATENCY, function()
            for _, r in ipairs(w.clients) do
                if r.online and chan == "GUILD" and c.guild and r.guild == c.guild then
                    r:Fire("CHAT_MSG_GUILD", text, c.name)
                elseif r.online and (chan == "PARTY" or chan == "RAID") and g and w:GroupOf(r.name) == g then
                    r:Fire("CHAT_MSG_" .. chan, text, c.name)
                end
            end
        end)
    end

end
