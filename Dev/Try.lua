---@class Dyreparken
local ns = select(2, ...)

-- /dp try (2026-11-14, the user: "we both need better tools to log / test in game"): a line now, to see its
-- text and its move in game without waiting for its moment. Nothing is counted or spent (no egg found, no
-- cooldown, no day used), except `wish`, which makes that today's wish for the card, and `dislike`, which owes
-- its sulk as a real one does (the pet frame turns away until the card plays it: Plan.Away).
--
--   /dp try egg <id> [n|all]      an egg's line by your pet's nature (n: that variant; all: every line it has,
--                                 by nature too, in chat), with its cheer if it has one
--   /dp try react <id> [n|all]    a class reaction's, the same way
--   /dp try dislike <activity>    a dislike's line, the way the pet frame shows one, and its sulk
--   /dp try line <prefix> [n|all] any lines in Locale/nb.lua (wish.say.fish, bond.like...)
--   /dp try wish <id> [zone]      today's wish becomes this one (not done yet), the card redrawn
-- A {placeholder} the moment would fill shows as <name>.
if not ns.DEV then return end
---@class Dyreparken.Try
local Try = {}
ns.Try = Try

local function Vars(key)
    return setmetatable({ pet = key and ns.Registry:NameOf(key) or "?" }, { __index = function(_, k) return "<" .. k .. ">" end })
end

-- Every prefix a row's lines can come from: its own, then each trait's and family's with lines.
local function Prefixes(kind, row)
    local out = { kind .. "." .. row.id }
    for _, list in ipairs({ row.traits or {}, row.families or {} }) do
        for _, x in ipairs(list) do
            local p = kind .. "." .. row.id .. "." .. x
            if ns.Strings[p .. ".1"] then out[#out + 1] = p end
        end
    end
    return out
end

-- Say prefix's line n (or one at random), or list every line of the prefixes.
local function Show(prefixes, which, key, bubble)
    if which == "all" then
        local n = 0
        for _, p in ipairs(prefixes) do
            for _, k in ipairs(ns.Variants(p)) do
                n = n + 1
                ns.Print(("|cff999999%s|r %s"):format(k, ns.T(k, Vars(key))))
            end
        end
        if n == 0 then ns.Print("No lines for " .. prefixes[1] .. ".") end
        return n > 0
    end
    local prefix = prefixes[1]
    local list = ns.Variants(prefix)
    if #list == 0 then ns.Print("No lines for " .. prefix .. "."); return false end
    local k = list[tonumber(which) or ns.random(#list)]
    if not k then ns.Print(("%s has %d lines."):format(prefix, #list)); return false end
    local text = ns.T(k, Vars(key))
    ns.Log("Try", "%s: %s", k, text)
    ns.PetSays(text, key, bubble or "say", true)
    return true
end

function Try:Row(kind, row, which)
    local key = ns.Pets:OutKey() or ns.Registry:MyPet()
    if which == "all" then return Show(Prefixes(kind, row), "all", key) end
    local nature = key and ns.Moments.ByNature(kind, row, key) or {}
    local ok = Show({ nature._key or (kind .. "." .. row.id) }, which, key, row.bubble)
    if ok and row.cheer and key and ns.Moves then ns.Moves:Cheer(key) end
    return ok
end

function Try:Command(arg)
    local what, id, which = (arg or ""):match("^(%S*)%s*(%S*)%s*(.-)%s*$")
    which = which ~= "" and which or nil
    local key = ns.Pets:OutKey() or ns.Registry:MyPet()
    if what == "egg" then
        local e = ns.Quirks.EggById(id)
        if not e then return ns.Print("No egg " .. id .. ".") end
        return self:Row("egg", e, which)
    elseif what == "react" then
        local row = ns.Reactions.ById(id)
        if not row then return ns.Print("No reaction " .. id .. ".") end
        return self:Row("react", row, which)
    elseif what == "dislike" then
        local ok = Show({ "dislike." .. id }, which, key, "dislike")
        if ok and key and which ~= "all" then ns.Moves:Owe(key, "sulk") end
        return ok
    elseif what == "line" and id ~= "" then
        return Show({ id }, which, key)
    elseif what == "wish" and id ~= "" then
        local w = ns.Wish:Today()
        if not w then return ns.Print("No adopted pet: no wish.") end
        w.id, w.zone, w.done = id, which, false
        ns.Wish:Arm()
        if ns.JournalUI then ns.JournalUI:Refresh() end
        return ns.Print(("Today's wish: %s%s."):format(id, which and (" (" .. which .. ")") or ""))
    end
    ns.Print("/dp try egg/react <id> [n/all], dislike <activity>, line <prefix> [n/all], wish <id> [zone]")
end

ns.Commands.Add("try", "try egg/react <id> [n/all], dislike <activity>, line <prefix>, wish <id> - a line now (development)",
    function(_, typed) Try:Command(typed) end)
