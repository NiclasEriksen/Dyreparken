-- Assertions for the specs: H.eq, H.ok, H.no, H.match (with H.Show for values), and
-- H.converged / H.assertConverged (every client agrees on the registry).
local H, P = ...

local function Show(v)
    if type(v) == "string" then return string.format("%q", v) end
    if type(v) ~= "table" then return tostring(v) end
    local parts = {}
    for k, x in pairs(v) do parts[#parts + 1] = tostring(k) .. "=" .. Show(x) end
    table.sort(parts)
    return "{" .. table.concat(parts, ", ") .. "}"
end
H.Show = Show

function H.eq(actual, expected, msg)
    if actual ~= expected then
        error(("%sexpected %s, got %s"):format(msg and (msg .. ": ") or "", Show(expected), Show(actual)), 2)
    end
end

function H.ok(v, msg)
    if not v then error(msg or "expected a true value", 2) end
    return v
end

function H.no(v, msg)
    if v then error((msg or "expected a false value") .. " (got " .. Show(v) .. ")", 2) end
end

function H.match(s, pattern, msg)
    if type(s) ~= "string" or not s:find(pattern) then
        error(("%sexpected %s to match %q"):format(msg and (msg .. ": ") or "", Show(s), pattern), 2)
    end
end

-- Every client in the world agrees on the registry: same digest, same holders.
function H.converged(w, names)
    local ref, refHolders
    for _, c in ipairs(w.clients) do
        if c.online and c.guild and (not names or names[c.name]) then
            local d = c.ns.Sync:Digest()
            local R = c.ns.Registry
            local nicks = {}
            for key in pairs(select(3, R:All())) do nicks[key] = R:Nickname(key) or false end
            local holders = Show(R:Holders()) .. " names " .. Show(nicks)
            if not ref then
                ref, refHolders = d, holders
            elseif d ~= ref or holders ~= refHolders then
                return false, ("%s differs: %s vs %s"):format(c.name, holders, refHolders)
            end
        end
    end
    return true
end

function H.assertConverged(w, msg)
    -- Let what's already on its way land first (a bond published at the
    -- 30-second day visit after a login, say), then compare.
    w:Run(3)
    local ok, why = H.converged(w)
    if not ok then error((msg and (msg .. ": ") or "") .. why, 2) end
end
