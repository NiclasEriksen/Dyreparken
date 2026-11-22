-- Which lines have too few ways to be said (2026-11-22, the content review §1a): the worklist for new variants.
-- Counts each group's texts the way ns.Lines does (the bare key and its .N variants; not the class or race ones,
-- which only some players hear), against a minimum by how often the group can come. Run from the addon folder:
--
--   luajit tools/variants.lua            every group below its minimum, the furthest below first
--   luajit tools/variants.lua --all      every group, with its count
--   luajit tools/variants.lua -g egg.    only groups whose key starts with this
--
-- Minimums (Variants.MIN, below): a line that can come on most days 5, any other egg, reaction or dislike 3, a
-- nature's own lines 2 (they mix with the general ones: Moments.NATURE_SHARE). A nature whose row lists it as
-- `apart` replaces the general lines, so it needs as many as they do. tools/test/spec/49_content.lua holds the
-- minimums once the lines are written (Variants.ENFORCED).
package.path = "tools/test/?.lua;" .. package.path
local args, opt = { ... }, {}
local i = 1
while i <= #args do
    local a = args[i]
    if a == "--all" then opt.all = true
    elseif a == "-g" then i = i + 1; opt.grep = args[i]
    elseif a == "-h" or a == "--help" then
        for line in io.lines(arg[0]) do
            if not line:find("^%-%-") then break end
            print((line:gsub("^%-%- ?", "")))
        end
        os.exit(0)
    else
        io.stderr:write("unknown option ", a, " (-h for help)\n"); os.exit(2)
    end
    i = i + 1
end

local Variants = dofile("tools/variants_rules.lua")
local H = require("harness")
local w = H.World()
local c = w:AddClient("Ola Nord", { pets = { 5159 }, login = false, debug = false })
c:Login()
local rows = Variants.Groups(c.ns)
table.sort(rows, function(a, b)
    local da, db = a.n - a.min, b.n - b.min
    if da ~= db then return da < db end
    return a.key < b.key
end)
local below = 0
for _, r in ipairs(rows) do
    if not opt.grep or r.key:find(opt.grep, 1, true) == 1 then
        if r.n < r.min then below = below + 1 end
        if opt.all or r.n < r.min then
            print(("%-40s %2d of %d  %s"):format(r.key, r.n, r.min, r.why))
        end
    end
end
print(("%d groups below their minimum, of %d"):format(below, #rows))
