---@class Dyreparken
local ns = select(2, ...)

-- /dp and /dyreparken
local commands = {}
local help, devHelp = {}, {}

-- A command and its help line. Only the Norwegian words (2026-11-09: the
-- addon spread beyond the guild, so the old English aliases, /dp versjon and
-- /dp rapport went; the developer commands exist only in a git checkout, and their help only under /dp dev,
-- 2026-11-19: they took over the list).
local function Add(name, usage, fn, dev)
    commands[name] = fn
    local list = dev and devHelp or help
    if usage then list[#list + 1] = usage end
end

-- An action's ok, message: the message is shown either way.
local function Say(_, msg) if msg then ns.Print(msg) end end

local ON = { ["på"] = true, on = true }
local OFF = { av = true, off = true }

local Lower = ns.Lower

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
    if not IsInGuild() then return ns.Print(ns.L["adopt.no_guild"]) end
    local ok, msg = ns.Registry:SetNickname(raw)
    Say(ok, msg)
    if ok then ns.Bonds:Announce("name", (ns.Registry:MyPet())) end
end

local function Announce(arg)
    ns.Bonds:SetAnnounce(Toggle(arg, ns.DB.char.announce))
end

local function List()
    if not IsInGuild() then return ns.Print(ns.L["adopt.no_guild"]) end
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
        A:List(word == "alle")
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
Add("kunngjor", nil, Announce) -- (the same, for a keyboard without ø, 2026-11-19, the user; not in the help)
-- The settings in Blizzard's options (Settings.Canvas): they open in combat too, the canvas being ours.
Add("innstillinger", L["cmd.help.innstillinger"], function()
    local api, cat = rawget(_G, "Settings"), ns.Settings.category
    if type(api) == "table" and api.OpenToCategory and cat then return api.OpenToCategory(cat:GetID()) end
    ns.Print(L["cmd.settings.where"])
end)
Add("klapp", L["cmd.help.klapp"], function() ns.Bonds:Pat() end)

-- /klapp on its own (2026-11-19, the user): the same as /dp klapp, the one players type the most.
SLASH_DYREPARKENKLAPP1 = "/klapp"
SlashCmdList.DYREPARKENKLAPP = function() ns.Bonds:Pat() end

SLASH_DYREPARKEN1 = "/dp"
SLASH_DYREPARKEN2 = "/dyreparken"
SlashCmdList.DYREPARKEN = function(input)
    local cmd, arg = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = Lower(cmd)
    local fn = commands[cmd]
    -- fn(lowercased arg, arg as typed): names and nicknames keep their case.
    if fn then return fn(arg ~= "" and Lower(arg) or nil, arg) end
    if cmd == "dev" and #devHelp > 0 then
        for _, line in ipairs(devHelp) do ns.Print("  /dp " .. line) end
        return
    end
    -- (a word we don't know is said so, review 2026-11-19; "hjelp" and nothing just ask for the list)
    if cmd ~= "" and cmd ~= "hjelp" then ns.Print(ns.T("cmd.unknown", { cmd = cmd })) end
    ns.Print(ns.T("cmd.help.head", { version = ns.VERSION }))
    for _, line in ipairs(help) do ns.Print("  /dp " .. line) end
    ns.Print(L["cmd.help.ui"])
    if #devHelp > 0 then ns.Print(L["cmd.help.dev"]) end
end

-- The developer commands (probe, debug) are in Dev/Commands.lua, only in a
-- git checkout: a packaged release doesn't have the file. Theirs are listed under /dp dev.
ns.Commands = { Add = function(name, usage, fn) Add(name, usage, fn, true) end }
