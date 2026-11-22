-- The minimum number of texts per line group (2026-11-22, the content review §1a), shared by tools/variants.lua
-- (the worklist) and tools/test/spec/49_content.lua (which holds the groups in ENFORCED to it). A group's count is
-- what ns.Lines gives every player: the bare key and its numbered variants, not the class or race ones.
local Variants = {}

-- How many texts a group needs, by how often a player can meet it.
Variants.MIN = {
    daily = 5,    -- can come on most days a player plays (a liked activity's line, a common egg or reaction)
    holiday = 5,  -- every day of a game holiday, one to three weeks
    common = 3,   -- an egg, reaction or dislike that comes now and then
    rare = 2,     -- once a year, once a character, or a milestone
    nature = 2,   -- a nature's own lines, mixed with the general ones (Moments.NATURE_SHARE)
}

-- Eggs by how often they can come (the rest are "common"). Rare: a date, a one-off, a milestone; holiday: the
-- game's holidays, said on every day they last.
local EGG_RARE = {
    mai17 = true, jul = true, nyttar = true, april = true, halloween = true, fredag13 = true, dager = true,
    paske = true, klokka = true, leet = true, navnebror = true, tvilling = true, tusenhopp = true,
    titusenhopp = true, maks = true, ridning = true, kake = true, toppen = true, helter = true, glemsel = true,
    talentbytte = true, duellvinner = true, duelltaper = true, fullfest = true, midnattsdans = true,
}
local EGG_HOLIDAY = { lunar = true, love = true, noblegarden = true, midsummer = true, harvest = true,
    hallowsend = true, winterveil = true }
local EGG_DAILY = { stup = true, lilla = true, bom = true, oppdrag = true, baal = true, hundre = true, ener = true,
    hopp = true, midnatt = true, wipe = true, nyrute = true, baalnaer = true, baalvarm = true, sovepose = true,
    mandag = true, morgen = true, skravle = true }
-- Dislikes that come with everyday play (the commonest activities); the rest are common.
local DISLIKE_DAILY = { taxi = true, boss = true, jump = true, quest = true, explore = true, herb = true,
    mine = true, fish = true, skin = true }

-- Single lines checked by hand: { key, kind }.
Variants.SINGLES = {
    { "wish.granted", "daily" }, { "pat.thanks", "daily" }, { "first.boss", "daily" }, { "first.place", "daily" },
    { "play.line", "common" }, { "today.mine", "common" }, { "dislike.found", "common" },
}

-- The groups the content spec holds to their minimum (empty until the audit's lines are in: then the worklist
-- becomes a test, group by group).
Variants.ENFORCED = {}

local function Count(strings, prefix)
    local n = strings[prefix] and 1 or 0
    while strings[prefix .. "." .. (n + (strings[prefix] and 0 or 1))] do n = n + 1 end
    return n
end
Variants.Count = Count

-- Every group: { key, n, min, why }.
function Variants.Groups(ns)
    local S, out, seen = ns.Strings, {}, {}
    local function Add(key, kind, why)
        if seen[key] then return end
        seen[key] = true
        out[#out + 1] = { key = key, n = Count(S, key), min = Variants.MIN[kind], why = why or kind }
    end
    local function Row(prefix, row, kind)
        local general = prefix .. "." .. row.id
        local generalN = Count(S, general)
        if generalN > 0 or not (row.traits or row.families) then Add(general, kind) end
        local apart = {}
        for _, x in ipairs(row.apart or {}) do apart[x] = true end
        for _, list in ipairs({ row.first or {}, row.traits or {}, row.families or {} }) do
            for _, x in ipairs(list) do
                local k = general .. "." .. x
                if S[k .. ".1"] then
                    if apart[x] then Add(k, kind, kind .. ", apart: replaces the general lines")
                    else Add(k, "nature") end
                end
            end
        end
    end
    for _, e in ipairs(ns.Quirks.EGGS) do
        Row("egg", e, EGG_RARE[e.id] and "rare" or EGG_HOLIDAY[e.id] and "holiday" or EGG_DAILY[e.id] and "daily"
            or "common")
    end
    for _, r in ipairs(ns.Reactions.ROWS) do Row("react", r, r.rare and "common" or "daily") end
    -- A row's own lines its test picks by hand (egg.nyrute.redd: a pet scared of flying), not by its lists.
    for k in pairs(S) do
        local kind, id, x = k:match("^(%a+)%.([%w_]+)%.([%a_]+)%.1$")
        if (kind == "egg" or kind == "react") and x ~= "class" and x ~= "race" then
            Add(kind .. "." .. id .. "." .. x, "nature", "nature, picked by its test")
        end
    end
    for _, a in ipairs(ns.Activity.KINDS) do
        local id = a[1]
        if S["dislike." .. id .. ".1"] then Add("dislike." .. id, DISLIKE_DAILY[id] and "daily" or "common") end
        if Count(S, "activity." .. id .. ".flavor") > 0 then Add("activity." .. id .. ".flavor", "daily", "daily (a liked activity's first time a day)") end
        if Count(S, "wish.say." .. id) > 0 then Add("wish.say." .. id, "common", "common (the card's wish line)") end
    end
    for _, t in ipairs(ns.Personality.TRAITS) do
        for _, part in ipairs({ "flavor", "dayflavor" }) do
            local k = "trait." .. t.id .. "." .. part
            if Count(S, k) > 0 then Add(k, "daily", "daily (the trait's moment)") end
        end
    end
    for _, f in ipairs(ns.Scenes.ORDER) do
        if Count(S, "voice." .. f) > 0 then Add("voice." .. f, "common", "common (a click on the card)") end
    end
    for _, s in ipairs(Variants.SINGLES) do Add(s[1], s[2]) end
    return out
end

return Variants
