---@class Dyreparken
local ns = select(2, ...)

-- Our own Lua errors into the debug log (2026-11-14, the user: "we both need better tools to log / test in
-- game"): read with the rest of the log, in order and with their stack, instead of from a screenshot.
-- BugGrabber (installed here) takes the error handler for itself and makes seterrorhandler a no-op, but it
-- tells EventRegistry "BugGrabber.BugGrabbed" with the error's id; without it, a handler of ours goes in
-- front of the one there. Only errors that name a file of ours; the first of each in full, then a count.
if not ns.DEV then return end
---@class Dyreparken.Errors
local Errors = { seen = {}, count = 0 }
ns.Errors = Errors

function Errors.Ours(text) return type(text) == "string" and text:find("Dyreparken[/\\]") ~= nil end

local function OneLine(text) return (tostring(text):gsub("[\r\n\t]+", " | ")) end

function Errors:Log(message, stack)
    message = tostring(message)
    if not (self.Ours(message) or self.Ours(stack)) then return end
    local n = (self.seen[message] or 0) + 1
    self.seen[message] = n
    if n == 1 then
        self.count = self.count + 1
        ns.Log("Error", "%s", OneLine(message))
        if type(stack) == "string" then ns.Log("Error", "stack: %s", OneLine(stack)) end
    elseif n == 10 or n % 100 == 0 then
        ns.Log("Error", "again (x%d): %s", n, OneLine(message))
    end
end

ns.Start("loaded", function()
    if type(BugGrabber) == "table" and type(EventRegistry) == "table" and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(_, id)
            local ok, e = pcall(BugGrabber.GetErrorByID, BugGrabber, id)
            if ok and type(e) == "table" then Errors:Log(e.message, e.stack) end
        end, Errors)
        Errors.via = "BugGrabber"
    elseif type(seterrorhandler) == "function" and type(geterrorhandler) == "function" then
        local before = geterrorhandler()
        seterrorhandler(function(message, ...)
            pcall(Errors.Log, Errors, message, type(debugstack) == "function" and debugstack(2) or nil)
            return before(message, ...)
        end)
        Errors.via = "handler"
    end
end)
