local _, ns = ...

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
    { "lift", function() ns.LiftEditor:Toggle() end },
    { "moves", function() ns.MovesEditor:Toggle() end },
    { "gains", function(a) ns.BondTrack:PreviewGains(a) end, "[n n ...]" },
    { "api", function(a) ns.ApiProbe:Run(a) end, "[section|clear]" },
    { "sense", function(a) ns.Commands.Sense(a) end, "[off]" },
    { "perf", function(a) ns.Perf:Command(a) end, "[on|off|show]" },
}

-- /dp probe sense: every sensor (Menagerie/Sense.lua) on for this session, each subject to the debug log
-- ("Sense <kind> ..."); off turns them off again.
local SENSE = {}
function ns.Commands.Sense(arg)
    for _, kind in ipairs(ns.Sense.KINDS) do
        if arg == "off" then ns.Sense:Drop(kind, SENSE) else ns.Sense:Want(kind, SENSE) end
    end
    ns.Print(arg == "off" and "Sensors off." or "Sensors on: every subject goes to the debug log (/dp debug on).")
end
local usage = {}
for _, p in ipairs(PROBES) do usage[#usage + 1] = p[3] and (p[1] .. " " .. p[3]) or p[1] end
Add("probe", "probe [" .. table.concat(usage, "|") .. "] - dump API info to the debug log (development)", function(arg)
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    for _, p in ipairs(PROBES) do
        if p[1] == word then return p[2](rest ~= "" and rest or nil) end
    end
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
        D:Clear()
        ns.Print("Debug log cleared.")
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
