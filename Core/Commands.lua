local _, ns = ...

-- /dp and /dyreparken
local commands = {}
local help = {}

local function Add(name, usage, fn)
    commands[name] = fn
    help[#help + 1] = usage
end

Add("version", "version [guild|group] - who runs which version", function(arg)
    local channel = arg == "group" and (IsInRaid() and "RAID" or "PARTY") or "GUILD"
    ns.Version:Check(channel)
end)

Add("report", "report - call out group members without a companion", function()
    ns.Report:Run()
end)

Add("probe", "probe - dump companion API info (development)", function()
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

SLASH_DYREPARKEN1 = "/dp"
SLASH_DYREPARKEN2 = "/dyreparken"
SlashCmdList.DYREPARKEN = function(input)
    local cmd, arg = strtrim(input or ""):match("^(%S*)%s*(.-)$")
    cmd = cmd:lower()
    local fn = commands[cmd]
    if fn then return fn(arg ~= "" and arg:lower() or nil) end
    ns.Print("v" .. ns.VERSION .. " commands:")
    for _, line in ipairs(help) do ns.Print("  /dp " .. line) end
end
