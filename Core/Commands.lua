local _, ns = ...

-- /dp and /dyreparken
local commands = {}
local help = {}

-- A command and its help line. Only the Norwegian words (2026-11-09: the
-- addon spread beyond the guild, so the old English aliases, /dp versjon and
-- /dp rapport went; the developer commands exist only in a git checkout).
local function Add(name, usage, fn)
    commands[name] = fn
    help[#help + 1] = usage
end

-- An action's ok, message: the message is shown either way.
local function Say(_, msg) if msg then ns.Print(msg) end end

local ON = { ["på"] = true, on = true }
local OFF = { av = true, off = true }

-- lower() leaves Æ, Ø and Å alone (bytes, not letters): "/dp KUNNGJØR PÅ".
local function Lower(s)
    return (s:lower():gsub("Æ", "æ"):gsub("Ø", "ø"):gsub("Å", "å"))
end

-- "på"/"av" (or on/off) say which; nothing else flips the current setting.
local function Toggle(arg, current)
    if ON[arg or ""] then return true end
    if OFF[arg or ""] then return false end
    return not current
end

local function Adopt(_, raw)
    local key
    if raw and raw ~= "" then
        key = ns.Pets:FindOwned(raw)
        if not key then return ns.Print(ns.T("cmd.adopt.nomatch", { text = raw })) end
    else
        key = ns.Pets:OutKey()
        if not key then return ns.Print(ns.L["cmd.adopt.nothing"]) end
    end
    local ok, msg = ns.Registry:Claim(key)
    Say(ok, msg)
    if ok then ns.Bonds:Announce("adopt", key) end
end
local function LetGo() Say(ns.Registry:Release()) end

local function Nick(_, raw)
    local ok, msg = ns.Registry:SetNickname(raw)
    Say(ok, msg)
    if ok then ns.Bonds:Announce("name", (ns.Registry:MyPet())) end
end

local function Announce(arg)
    ns.Bonds:SetAnnounce(Toggle(arg, ns.DB.char.announce))
end

local function List()
    local holders = ns.Registry:Holders()
    local rows = {}
    for key, owner in pairs(holders) do
        rows[#rows + 1] = { name = ns.Pets:NameOfKey(key), owner = owner, nick = ns.Registry:Nickname(key) }
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    local total = ns.Pets:Total()
    local pct = total > 0 and math.floor(#rows / total * 100 + 0.5) or 0
    ns.Print(ns.T("cmd.list.head", { n = #rows, total = total, pct = pct }))
    for _, row in ipairs(rows) do
        ns.Print(ns.T(row.nick and "cmd.list.row_nick" or "cmd.list.row", { pet = row.name, owner = row.owner,
            nick = row.nick }))
    end
end

local function Sound(arg)
    if ns.Summon:Deferring() then
        return ns.Print(ns.L["cmd.sound.deferred"])
    end
    local on = Toggle(arg, not ns.DB.char.muteSummonSound)
    ns.Summon:SetMuteSound(not on)
    ns.Print(ns.L[on and "cmd.sound.on" or "cmd.sound.off"])
end

local function Achievements(arg)
    local A = ns.Achievements
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    if word == "del" then
        A:Share()
    elseif word == "varsel" and (ON[rest] or OFF[rest]) then
        A:SetNotify(ON[rest] == true)
    else
        A:List()
    end
end

-- The command words are code; what the help says about them is text
-- (Locale/nb.lua, cmd.help.*).
local L = ns.L
Add("adopter", L["cmd.help.adopter"], Adopt)
Add("gislipp", L["cmd.help.gislipp"], LetGo)
Add("navn", L["cmd.help.navn"], Nick)
Add("liste", L["cmd.help.liste"], List)
Add("lyd", L["cmd.help.lyd"], Sound)
Add("prestasjoner", L["cmd.help.prestasjoner"], Achievements)
Add("kunngjør", L["cmd.help.kunngjor"], Announce)
Add("klapp", L["cmd.help.klapp"], function() ns.Bonds:Pat() end)

SLASH_DYREPARKEN1 = "/dp"
SLASH_DYREPARKEN2 = "/dyreparken"
SlashCmdList.DYREPARKEN = function(input)
    local cmd, arg = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = Lower(cmd)
    local fn = commands[cmd]
    -- fn(lowercased arg, arg as typed): names and nicknames keep their case.
    if fn then return fn(arg ~= "" and Lower(arg) or nil, arg) end
    ns.Print(ns.T("cmd.help.head", { version = ns.VERSION }))
    for _, line in ipairs(help) do ns.Print("  /dp " .. line) end
end

-- Developer commands, English: only in a git checkout (ns.DEV), never in a
-- packaged release.
if not ns.DEV then return end

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
}
local usage = {}
for _, p in ipairs(PROBES) do usage[#usage + 1] = p[3] and (p[1] .. " " .. p[3]) or p[1] end
Add("probe", "probe [" .. table.concat(usage, "|") .. "] - dump API info to the debug log (development)", function(arg)
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    for _, p in ipairs(PROBES) do
        if p[1] == word then return p[2](rest ~= "" and rest or nil) end
    end
    ns.Pets:Probe()
end)

Add("debug", "debug [on|off|echo|clear] - debug log (saved on /reload)", function(arg)
    local D = ns.Debug
    if arg == "clear" then
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
