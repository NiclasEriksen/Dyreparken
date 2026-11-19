---@class Dyreparken
local ns = select(2, ...)

-- Developer commands, English: only in a git checkout (ns.DEV). The file
-- isn't packaged (#@do-not-package@ in the TOC), and a checkout given a
-- release's version (the tests do) has none either.
if not ns.DEV then return end
-- (A usage's "|" as "/" in chat: a single | starts an escape there, and "|tabs" is a texture's.)
local function Add(name, usage, fn) return ns.Commands.Add(name, (usage:gsub("|", "/")), fn) end

-- /dp probe <word> [arg]: development dumps to the debug log. One line each;
-- the usage is built from this list. (no word: the journal probe)
local PROBES = {
    { "more", function() ns.Pets:ProbeMore() end },
    { "tabs", function() ns.AchPage:Probe() end },
    { "kills", function() ns.Kills:Probe() end },
    { "life", function() ns.Kills:ProbeLife() end },
    { "world", function() ns.Kills:ProbeWorld() end },
    { "card", function() ns.JournalUI:ProbeCard() end },
    { "bg", function(a) ns.Scenes:Probe(a) end, "<family>" },
    { "decor", function() ns.Decor:Probe() end },
    { "frames", function() ns.Decor:ProbeFrames() end },
    { "level", function(a) ns.Decor:Preview(a) end, "<n|off>" },
    { "celebrate", function() ns.BondTrack:Preview() end },
    { "anim", function(a) ns.Moves:Probe(a) end, "[list|all|custom|stop|night|sleep <id> [s]|blend none|anim|<id|name> [speed] [offset]]" },
    { "ach", function(a) ns.Pets:ProbeAch(a) end, "[post|now|group|groupnow]" },
    { "pos", function(a) ns.Moves:ProbePos(a) end, "[box|x|y|z <delta>|scale <n>|reset]" },
    { "place", function() ns.PlaceEditor:Toggle() end },
    { "lift", function() ns.LiftEditor:Toggle() end },
    { "moves", function() ns.MovesEditor:Toggle() end },
    { "gains", function(a) ns.BondTrack:PreviewGains(a) end, "[n n ...]" },
    { "api", function(a) ns.ApiProbe:Run(a) end, "[section|clear]" },
    { "sense", function(a) ns.Commands.Sense(a) end, "[off]" },
    { "perf", function(a) ns.Perf:Command(a) end, "[on|off|show]" },
    { "garden", function(a) ns.Commands.Garden(a) end, "<hour> [month]|off" },
    { "sound", function(a) ns.Commands.Sound(a) end, "[species id|set|quiet]" },
}

-- /dp probe sound: a pet's own sound (Data/PetSounds.lua), to check by ear: the card's pet (none given), a
-- species id, or a set by name; each time another of its files. quiet: the species that have none.
function ns.Commands.Sound(arg)
    local P = ns.PetSounds
    arg = arg and arg:match("^%s*(.-)%s*$") or ""
    if arg == "quiet" then
        local quiet = {}
        for sid in pairs(ns.Companions.species) do
            if not P.SPECIES[sid] then quiet[#quiet + 1] = ("%d %s"):format(sid, ns.Pets:NameOfKey("s:" .. sid) or "?") end
        end
        table.sort(quiet)
        ns.Print(("sound: %d quiet: %s"):format(#quiet, table.concat(quiet, ", ")))
        return
    end
    local sid = tonumber(arg)
    if arg == "" then
        local card = rawget(_G, "PetJournalPetCard")
        sid = card and card.speciesID
    end
    local name = sid and P.SPECIES[sid] or (not sid and P.SETS[arg] and arg)
    local id = name and ns.PlaySoundFiles(P.SETS[name], true)
    ns.Print(("sound: %s %s: %s"):format(sid and ("species " .. sid) or "set", tostring(name),
        id and ("file " .. id) or "nothing played"))
end

-- /dp probe garden: Parken's garden at another hour and month (night's fireflies, December's snow, the
-- seasons' lawns), through ParkPage.override, which a release leaves nil; off: the clock again.
function ns.Commands.Garden(arg)
    local hour, month = (arg or ""):match("^(%d+)%s*(%d*)$")
    local Park = ns.ParkPage
    if hour then
        Park.override = { hour = tonumber(hour) % 24, month = tonumber(month) or tonumber(date("%m")) }
    else
        Park.override = nil
    end
    ns.Print(("garden: %s"):format(Park.override and ("hour %d, month %d"):format(Park.override.hour, Park.override.month) or "the clock"))
    if Park.Refresh then Park:Refresh() end
end

-- /dp probe sense: every sensor (Menagerie/Sense.lua) on for this session, each subject to the debug log
-- ("Sense <kind> ..."); off turns them off again.
local SENSE = {}
function ns.Commands.Sense(arg)
    for _, kind in ipairs(ns.Sense.KINDS) do
        if arg == "off" then ns.Sense:Drop(kind, SENSE) else ns.Sense:Want(kind, SENSE) end
    end
    ns.Debug:Mute("Sense.cast", arg == "off") -- (each cast too, quiet otherwise: Debug.QUIET)
    ns.Print(arg == "off" and "Sensors off." or "Sensors on: every subject goes to the debug log (/dp debug on).")
end
local usage = {}
for _, p in ipairs(PROBES) do usage[#usage + 1] = p[3] and (p[1] .. " " .. p[3]) or p[1] end
Add("probe", "probe [" .. table.concat(usage, "|") .. "] - dump API info to the debug log (development)", function(arg)
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    for _, p in ipairs(PROBES) do
        ---@diagnostic disable-next-line: redundant-parameter (some probes take the rest of the line)
        if p[1] == word then return p[2](rest ~= "" and rest or nil) end
    end
    -- (a typo used to run the journal's probe without a word, 2026-11-19)
    if word ~= "" then return ns.Print("No probe \"" .. word .. "\". Probes: " .. table.concat(usage, ", ") .. ".") end
    ns.Pets:Probe()
end)

Add("debug", "debug [on|off|echo|clear|mute [module]|unmute <module>] - debug log (saved on /reload)", function(arg, typed)
    local D = ns.Debug
    local word, module = (typed or arg or ""):match("^(%S*)%s*(%S*)") -- (a module keeps its case: Moves)
    word = word:lower()
    if word == "mute" or word == "unmute" then
        local list = D:Mute(module ~= "" and module or nil, word == "mute")
        ns.Print("Muted in the log: " .. (#list > 0 and table.concat(list, ", ") or "none") .. ".")
        return
    elseif arg == "clear" then
        ns.Print("Debug log cleared.")
        D:Clear() -- (after: what's printed goes to the log too)
        return
    elseif arg == "echo" then
        D:SetEnabled(true, not D.echo)
    elseif arg == "on" or arg == "off" then
        D:SetEnabled(arg == "on", D.echo)
    else
        D:SetEnabled(not D.enabled, D.echo)
    end
    ns.Print(("Debug %s%s."):format(D.enabled and "on" or "off", D.echo and " (echo to chat)" or ""))
end)
