local _, ns = ...

-- /dp and /dyreparken
local commands = {}
local help = {}

local function Add(name, usage, fn)
    commands[name] = fn
    help[#help + 1] = usage
end

local function Say(ok, msg) if msg then ns.Print(msg) end end

local ON = { ["på"] = true, on = true }
local OFF = { av = true, off = true }

local function Adopt(_, raw)
    local key
    if raw and raw ~= "" then
        key = ns.Pets:FindOwned(raw)
        if not key then return ns.Print(ns.T("cmd.adopt.nomatch", { text = raw })) end
    else
        local guid = ns.Pets:Summoned()
        if not guid then return ns.Print(ns.L["cmd.adopt.nothing"]) end
        key = ns.Pets:KeyOf(guid)
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
    if ON[arg or ""] or OFF[arg or ""] then ns.Bonds:SetAnnounce(ON[arg] == true)
    else ns.Bonds:SetAnnounce(not ns.DB.char.announce) end
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
    local on
    if ON[arg or ""] or OFF[arg or ""] then on = ON[arg] == true else on = ns.DB.char.muteSummonSound and true or false end
    ns.Summon:SetMuteSound(not on)
    ns.Print(ns.L[on and "cmd.sound.on" or "cmd.sound.off"])
end

local function Achievements(arg)
    local A = ns.Achievements
    local word, rest = (arg or ""):match("^(%S*)%s*(.-)$")
    if word == "del" or word == "share" then
        A:Share()
    elseif word == "ikoner" or word == "icons" then
        A:ShowIcons()
    elseif (word == "varsel" or word == "notify") and (ON[rest] or OFF[rest]) then
        A:SetNotify(ON[rest] == true)
    else
        A:List()
    end
end

local function Version(arg)
    local group = arg == "gruppe" or arg == "group"
    ns.Version:Check(group and (IsInRaid() and "RAID" or "PARTY") or "GUILD")
end

local function Report() ns.Report:Run() end

-- The command words are code (both the Norwegian and the old English ones
-- work); what the help says about them is text (Locale/nb.lua, cmd.help.*).
local L = ns.L
Add("adopter", L["cmd.help.adopter"], Adopt)
Add("gislipp", L["cmd.help.gislipp"], LetGo)
Add("navn", L["cmd.help.navn"], Nick)
Add("liste", L["cmd.help.liste"], List)
Add("lyd", L["cmd.help.lyd"], Sound)
Add("prestasjoner", L["cmd.help.prestasjoner"], Achievements)
Add("versjon", L["cmd.help.versjon"], Version)
Add("kunngjør", L["cmd.help.kunngjor"], Announce)
Add("klapp", L["cmd.help.klapp"], function() ns.Bonds:Pat() end)
Add("rapport", L["cmd.help.rapport"], Report)
-- The English names from before the Norwegian interface (2026-11-08), and
-- the oldest ones (claim, release), still work but aren't in the help.
commands.adopt, commands.letgo, commands.claim, commands.release = Adopt, LetGo, Adopt, LetGo
commands.nick, commands.list, commands.sound, commands.ach = Nick, List, Sound, Achievements
commands.version, commands.report, commands.pat = Version, Report, commands.klapp
commands.announce = Announce

Add("probe", "probe [more|tabs|kills|life|bg|decor|level <n|off>|celebrate [n|off]|ach [post|now|group|groupnow]] - dump API info to the debug log (development)", function(arg)
    if arg and arg:find("^bg") then
        ns.Scenes:Probe(arg:match("^bg%s+(%S+)$"))
    elseif arg == "kills" then
        ns.Kills:Probe()
    elseif arg == "decor" then
        ns.Decor:Probe()
    elseif arg == "celebrate" then
        ns.BondTrack:Preview()
    elseif arg and arg:find("^level") then
        ns.Decor:Preview(arg:match("^level%s+(%S+)$"))
    elseif arg == "life" then
        ns.Kills:ProbeLife()
    elseif arg == "tabs" then
        ns.AchPage:Probe()
    elseif arg == "more" then
        ns.Pets:ProbeMore()
    elseif arg and arg:find("^ach") then
        ns.Pets:ProbeAch(arg:match("^ach%s+(%a+)$"))
    else
        ns.Pets:Probe()
    end
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

SLASH_DYREPARKEN1 = "/dp"
SLASH_DYREPARKEN2 = "/dyreparken"
SlashCmdList.DYREPARKEN = function(input)
    local cmd, arg = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    local fn = commands[cmd]
    -- fn(lowercased arg, arg as typed): names and nicknames keep their case.
    if fn then return fn(arg ~= "" and arg:lower() or nil, arg) end
    ns.Print(ns.T("cmd.help.head", { version = ns.VERSION }))
    for _, line in ipairs(help) do ns.Print("  /dp " .. line) end
end
