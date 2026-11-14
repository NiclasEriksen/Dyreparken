-- The stub client's basics: print, the clocks, the error handler, hooksecurefunc, secret values.
local H, P = ...

return function(c, env, S)
    local w = c.world
    env.print = function(...) c.printed[#c.printed + 1] = table.concat({ ... }, " ") end
    env.GetTime = function() return w.t end
    env.GetServerTime = function() return w:ServerTime() end
    env.time, env.date = os.time, os.date
    env.geterrorhandler = function() return function(e) c.errors[#c.errors + 1] = tostring(e) end end
    env.debugstack = function() return debug.traceback() end
    env.hooksecurefunc = function(a, b, fn)
        local t, name = env, a
        if type(a) == "table" then t, name = a, b else fn = b end
        local old = rawget(t, name)
        assert(type(old) == "function", "hooksecurefunc: " .. tostring(name) .. " is not a function")
        -- (The hook is the addon's code: insecure, whoever called the function.)
        rawset(t, name, function(...)
            local r = { old(...) }
            P.Insecure(c, fn, ...)
            return unpack(r)
        end)
    end
    env.issecretvalue = function(v) return v == H.SECRET end
    -- A secret can't be walked (Forever, 2026-11-14: "bad argument #1 to 'ipairs' (table expected, got secret)",
    -- UNIT_AURA's addedAuras in a fight).
    for _, name in ipairs({ "ipairs", "pairs" }) do
        local real = _G[name]
        env[name] = function(t, ...)
            if t == H.SECRET then error("bad argument #1 to '" .. name .. "' (table expected, got secret)", 2) end
            return real(t, ...)
        end
    end
    env.C_Secrets = { ShouldAurasBeSecret = function() return S.secretAuras == true end }

end
