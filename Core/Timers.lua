local _, ns = ...

-- Cancellable timers (docs/REFACTOR.md, Phase 4). C_Timer.After can't be taken back, so every
-- module that needed to wrote its own token guard ("if self.token ~= token then return end"), and
-- two of them were found wrong. A group of timers instead:
--
--   local t = ns.Timers()
--   t:After(2, fn)            fn() in 2 s
--   t:Every(0.1, 5, fn)       fn(1) .. fn(5), one every 0.1 s (one timer at a time, a chain)
--   t:Cancel()                every pending callback of this group does nothing
--
-- Cancel bumps a generation: a callback scheduled before it is a no-op when it comes; one
-- scheduled after it runs. Nothing polls.
local Proto = {}
Proto.__index = Proto

function ns.Timers()
    return setmetatable({ gen = 0 }, Proto)
end

function Proto:After(s, fn)
    local gen = self.gen
    C_Timer.After(s, function()
        if self.gen == gen then fn() end
    end)
end

function Proto:Every(s, n, fn)
    local gen, i = self.gen, 0
    local function Tick()
        if self.gen ~= gen then return end -- (cancelled, maybe by fn itself: the chain ends)
        i = i + 1
        fn(i)
        if i < n and self.gen == gen then C_Timer.After(s, Tick) end
    end
    if n > 0 then C_Timer.After(s, Tick) end
end

function Proto:Cancel()
    self.gen = self.gen + 1
end
