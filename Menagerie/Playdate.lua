local _, ns = ...

-- Playdates (2026-11-09): in a group with a guildmate who has their pet out,
-- both pets get Config.BOND_PLAY_POINTS (at the pet's rate) and a line, once
-- a day per pet: "Pepe lekte med Mjau (Kari Berg)!".
--
-- How they meet: with a pet out in a group, we tell the group which
-- (PLAY { pet } on PARTY or RAID) when the group changes and after a summon,
-- at most once per PLAY_EVERY. Whoever hears it with a pet of their own out
-- has their playdate, and answers (at most once a minute) so ours happens
-- too; the answer can't start a ping-pong, since the first side just spoke.
-- Guild members only (the roster must say so); the group channels only.
-- GROUP_ROSTER_UPDATE stays registered: it's how we learn we've joined, and
-- the handler returns at once outside a group or with no pet out.
local Playdate = {}
ns.Playdate = Playdate

local PLAY_EVERY = 600 -- seconds between our own announcements
local ANSWER_EVERY = 60 -- ... and between answers
local SETTLE = 2 -- a group just formed: the server refuses PARTY messages for a moment
local lastSent

local Channel = ns.GroupChannel
local function PetOut() return (ns.Pets:OutKey()) end

-- Tell the group which pet we have out (answer: replying to someone's).
function Playdate:Announce(answer)
    local channel, key = Channel(), PetOut()
    if not (channel and key) or ns.InCombat() then return end
    local now = GetTime()
    if lastSent and now - lastSent < (answer and ANSWER_EVERY or PLAY_EVERY) then return end
    lastSent = now
    ns.Comm:Send("PLAY", { pet = key }, channel)
end

-- Soon, once: group changes come in bursts.
local announceSoon = ns.Debounce(SETTLE, function() Playdate:Announce() end)
function Playdate:Soon()
    if IsInGroup() then announceSoon() end
end

-- Best friends in the park (2026-11-10): playdates counted per pair, in
-- char.playmates[ours]["owner\31theirs"] = n. The bond's tooltip names the
-- one it has played with most (from two); the fifth with the same friend gets a line.
Playdate.INSEPARABLE = 5
function Playdate:Count(mine, sender, theirs)
    local all = ns.DB.char.playmates
    all[mine] = all[mine] or {}
    local id = sender .. "\31" .. theirs
    local n = (all[mine][id] or 0) + 1
    all[mine][id] = n
    local total = 0
    for _, m in pairs(all[mine]) do total = total + m end
    if total == 1 then ns.Story:Mine(mine, "first.play", id) end -- (its very first playdate with you)
    if n == self.INSEPARABLE then
        ns.PetSays(ns.T("play.inseparable", { pet = ns.Registry:NameOf(mine), friend = ns.Registry:NameFor(theirs, sender) }))
    end
end

-- A pet's best friend: owner, their pet's key, playdates; nil without one.
function Playdate:BestFriend(mine)
    local best, bestN
    for id, n in pairs(ns.DB.char.playmates[mine] or {}) do
        if not bestN or n > bestN or (n == bestN and id < best) then best, bestN = id, n end
    end
    if not best or bestN < 2 then return nil end -- (one playdate isn't a best friend yet)
    local owner, theirs = best:match("^(.-)\31(.+)$")
    return owner, theirs, bestN
end

-- A full house: PLAY from this many guildmates within FULL_WITHIN seconds
-- (the messages arrive anyway: no new traffic) is a party, once a day.
Playdate.FULL, Playdate.FULL_WITHIN = 3, 600
local heard = {} -- sender -> GetTime(), this session
function Playdate:Party(sender, mine)
    local now, n = GetTime(), 0
    heard[sender] = now
    for who, at in pairs(heard) do
        if now - at > self.FULL_WITHIN then heard[who] = nil else n = n + 1 end
    end
    if n >= self.FULL then ns.Quirks:Egg("party", mine, n + 1) end -- (theirs and ours)
end

-- Their unit in our group ("party2", "raid7"), or nil.
local function UnitOf(sender)
    local raid = IsInRaid()
    local n = raid and GetNumGroupMembers() or GetNumSubgroupMembers()
    for i = 1, n do
        local unit = (raid and "raid" or "party") .. i
        if ns.UnitKey(unit) == sender then return unit end
    end
end

-- Close enough to play (2026-11-11, the user: "play date works on way too long distances, it should only
-- trigger when they're in range of us"): UnitInRange, a group member within about 40 yards; where it
-- can't say (another instance, say), whether the client shows them at all (UnitIsVisible).
-- Both exist on Forever (/dp probe api); what they answer there is logged until seen.
function Playdate:Near(sender)
    local unit = UnitOf(sender)
    if not unit then return false end
    local okR, inRange, checked = pcall(function() return UnitInRange(unit) end)
    inRange, checked = okR and ns.Plain(inRange), okR and ns.Plain(checked)
    local okV, visible = pcall(function() return UnitIsVisible(unit) end)
    visible = okV and ns.Plain(visible)
    ns.Log("Bond", "playdate range: %s (%s) in range %s, checked %s, visible %s", sender, unit,
        tostring(inRange), tostring(checked), tostring(visible))
    if checked then return inRange and true or false end
    return visible and true or false
end

-- Someone in our group has a pet out.
function Playdate:Heard(sender, theirs)
    local mine = PetOut()
    if not mine or ns.Guild:IsMember(sender) ~= true then return end
    if not self:Near(sender) then return end -- (no answer either: they're far from us too)
    local line = ns.T("play.line", { pet = ns.Registry:NameOf(mine), friend = ns.Registry:NameFor(theirs, sender),
        owner = sender })
    if ns.Bond:Reward("play", mine, line) then
        ns.Log("Bond", "playdate: %s with %s's %s", mine, sender, theirs)
        self:Count(mine, sender, theirs)
    end
    self:Party(sender, mine)
    self:Announce(true) -- so theirs happens too (they may not have heard us)
end

function Playdate:Init()
    ns.Comm:Register("PLAY", function(msg, sender)
        if ns.Registry.ValidKey(msg.pet) then Playdate:Heard(sender, msg.pet) end
    end, "GROUP")
    ns.Events:On("GROUP_ROSTER_UPDATE", Playdate, function() Playdate:Soon() end)
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function() Playdate:Soon() end)
end

ns.Start("login", function() Playdate:Init() end)
