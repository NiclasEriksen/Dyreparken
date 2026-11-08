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
        if not key then return ns.Print(("Du har ikke noe kjæledyr som passer «%s»."):format(raw)) end
    else
        local guid = ns.Pets:Summoned()
        if not guid then return ns.Print("Tilkall kjæledyret du vil adoptere, eller skriv navnet.") end
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
    ns.Print(("Guilden har hjem til %d av %d kjæledyr (%d%%):"):format(#rows, total, pct))
    for _, row in ipairs(rows) do
        ns.Print(("  %s - %s%s"):format(row.name, row.owner, row.nick and (" («" .. row.nick .. "»)") or ""))
    end
end

local function Sound(arg)
    if ns.Summon:Deferring() then
        return ns.Print("AutoCompanion er lastet: bruk innstillingen «Mute summoning sounds» der.")
    end
    local on
    if ON[arg or ""] or OFF[arg or ""] then on = ON[arg] == true else on = ns.DB.char.muteSummonSound and true or false end
    ns.Summon:SetMuteSound(not on)
    ns.Print(on and "Tilkallingslyden er på." or "Tilkallingslyden er dempet.")
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

Add("adopter", "adopter [navn] - adopter kjæledyret du har ute, eller et ved navn", Adopt)
Add("gislipp", "gislipp - gi slipp på kjæledyret ditt", LetGo)
Add("navn", "navn [kallenavn] - gi kjæledyret ditt et kallenavn (tomt fjerner det)", Nick)
Add("liste", "liste - hvilke kjæledyr som har et hjem i guilden", List)
Add("lyd", "lyd [på|av] - klirringen når et kjæledyr tilkalles (dempet som standard)", Sound)
Add("prestasjoner", "prestasjoner [del|varsel på|av|ikoner] - prestasjonene dine; del nye i guild-chatten",
    Achievements)
Add("versjon", "versjon [guild|gruppe] - hvem som har hvilken versjon", Version)
Add("kunngjør", "kunngjør [på|av] - del adopsjoner og kallenavn i guild-chatten (på som standard)", Announce)
Add("klapp", "klapp - klapp kjæledyret du har valgt som mål, eller ditt eget", function() ns.Bonds:Pat() end)
Add("rapport", "rapport - rop ut dem i gruppa som ikke har kjæledyret ute", Report)
-- The English names from before the Norwegian interface (2026-11-08), and
-- the oldest ones (claim, release), still work but aren't in the help.
commands.adopt, commands.letgo, commands.claim, commands.release = Adopt, LetGo, Adopt, LetGo
commands.nick, commands.list, commands.sound, commands.ach = Nick, List, Sound, Achievements
commands.version, commands.report, commands.pat = Version, Report, commands.klapp
commands.announce = Announce

Add("probe", "probe [more|tabs|kills|bg [n|off]|ach [post|now|group|groupnow]] - dump API info to the debug log (development)", function(arg)
    if arg and arg:find("^bg") then
        ns.Scenes:Probe(arg:match("^bg%s+(%S+)$"))
    elseif arg == "kills" then
        ns.Kills:Probe()
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
    ns.Print(ns.VERSION .. " - kommandoer:")
    for _, line in ipairs(help) do ns.Print("  /dp " .. line) end
end
