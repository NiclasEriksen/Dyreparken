local _, ns = ...

-- /dp and /dyreparken
local commands = {}
local help = {}

local function Add(name, usage, fn)
    commands[name] = fn
    help[#help + 1] = usage
end

local function Say(ok, msg) if msg then ns.Print(msg) end end

local function Adopt(_, raw)
    local key
    if raw and raw ~= "" then
        key = ns.Pets:FindOwned(raw)
        if not key then return ns.Print('You have no companion matching "' .. raw .. '".') end
    else
        local guid = ns.Pets:Summoned()
        if not guid then return ns.Print("Summon the companion you want, or give its name.") end
        key = ns.Pets:KeyOf(guid)
    end
    Say(ns.Registry:Claim(key))
end
local function LetGo() Say(ns.Registry:Release()) end

Add("adopt", "adopt [name] - adopt your summoned companion, or one by name", Adopt)
Add("letgo", "letgo - let your companion go", LetGo)
-- The old names from before the wording change (2026-11-06), not in help.
commands.claim, commands.release = Adopt, LetGo

Add("nick", "nick [name] - nickname your companion (empty clears it)", function(_, raw)
    Say(ns.Registry:SetNickname(raw))
end)

Add("list", "list - which companions the guild cares for", function()
    local holders = ns.Registry:Holders()
    local rows = {}
    for key, owner in pairs(holders) do
        local _, r = ns.Registry:Holder(key)
        rows[#rows + 1] = { name = ns.Pets:NameOfKey(key), owner = owner, nick = r and r.n }
    end
    table.sort(rows, function(a, b) return a.name < b.name end)
    local total = ns.Pets:Total()
    local pct = total > 0 and math.floor(#rows / total * 100 + 0.5) or 0
    ns.Print(("The guild cares for %d of %d companions (%d%%):"):format(#rows, total, pct))
    for _, row in ipairs(rows) do
        ns.Print(("  %s - %s%s"):format(row.name, row.owner, row.nick and (' ("' .. row.nick .. '")') or ""))
    end
end)

Add("sound", "sound [on|off] - the clank when a companion is summoned (muted by default)", function(arg)
    if ns.Summon:Deferring() then
        return ns.Print("AutoCompanion is loaded: use its \"Mute summoning sounds\" option instead.")
    end
    local on
    if arg == "on" or arg == "off" then on = arg == "on" else on = ns.DB.char.muteSummonSound and true or false end
    ns.Summon:SetMuteSound(not on)
    ns.Print(("Summon sound %s."):format(on and "on" or "muted"))
end)

Add("version", "version [guild|group] - who runs which version", function(arg)
    local channel = arg == "group" and (IsInRaid() and "RAID" or "PARTY") or "GUILD"
    ns.Version:Check(channel)
end)

Add("report", "report - call out group members without a companion", function()
    ns.Report:Run()
end)

Add("probe", "probe [more|ach [post|now|group|groupnow]] - dump API info to the debug log (development)", function(arg)
    if arg == "more" then
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
    ns.Print(ns.VERSION .. " commands:")
    for _, line in ipairs(help) do ns.Print("  /dp " .. line) end
end
