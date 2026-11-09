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

-- Someone in our group has a pet out.
function Playdate:Heard(sender, theirs)
    local mine = PetOut()
    if not mine or ns.Guild:IsMember(sender) ~= true then return end
    local line = ns.T("play.line", { pet = ns.Registry:NameOf(mine), friend = ns.Registry:NameFor(theirs, sender),
        owner = sender })
    if ns.Bond:Reward("play", mine, line) then ns.Log("Bond", "playdate: %s with %s's %s", mine, sender, theirs) end
    self:Announce(true) -- so theirs happens too (they may not have heard us)
end

function Playdate:Init()
    ns.Comm:Register("PLAY", function(msg, sender)
        if ns.Registry.ValidKey(msg.pet) then Playdate:Heard(sender, msg.pet) end
    end, "GROUP")
    ns.Events:On("GROUP_ROSTER_UPDATE", Playdate, function() Playdate:Soon() end)
    hooksecurefunc(C_PetJournal, "SummonPetByGUID", function() Playdate:Soon() end)
end
