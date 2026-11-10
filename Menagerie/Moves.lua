local _, ns = ...

-- The pet on the card moves (2026-11-10, docs/IDEAS.md "Animating the pet on
-- demand"; what plays is in docs/FOREVER_API.md):
--   at night it's asleep when you open the card (not a Nattugle), and a click
--     wakes it with a happy move;
--   a Latsabb sits down after a few seconds;
--   a click on it (Cuddle.lua) makes it happy;
--   a bond level-up (BondTrack's celebration) makes it cheer;
--   the day the "is it safe to live with you?" egg (three deaths) came up,
--     it plays dead for a moment, the first time you see its card.
-- The client can't tell us which animations a model has (no HasAnimation,
-- SetAnimation takes any id, GetAnimation echoes it), and they differ: the
-- most basic pets have only stand, death, walk, run and the pet battle set.
-- Which animation each reaction uses, per species, is in Data/PetMoves.lua,
-- edited by hand (found by eye with the probe below). Asleep is Dead (6):
-- the sleep ones (99-101) didn't hold, and PetBattleDead (770) sank some
-- pets into the floor (2026-11-10).
-- Timers only while the card shows a pet; a new pet, the journal closing or
-- our pages covering the card cancel them.
--
-- And the research probe, in a git checkout:
--   /dp probe anim          the actor, and the animations we try
--   /dp probe anim <id|name> [speed]  play one (speed 0: frozen on its first frame)
--   /dp probe anim all|custom  play each (or the four custom ones), 3 s apart
--   /dp probe anim stop     back to standing
--   /dp probe anim night    pretend it's night (or day again), to test sleep by day
local Moves = {}
ns.Moves = Moves

-- AnimationData ids as https://wowdev.wiki/M2/AnimationList lists them
-- (read 2026-11-10). Only those that played on a companion: the emotes
-- (60-186) and PetBattleStand, Victory, Loss, Stun and Freeze did nothing.
Moves.ANIMS = {
    { 0, "Stand" }, { 1, "Death" }, { 4, "Walk" }, { 5, "Run" }, { 6, "Dead" },
    { 37, "JumpStart" }, { 38, "Jump" }, { 39, "JumpEnd" },
    { 96, "SitGroundDown" }, { 97, "SitGround" }, { 98, "SitGroundUp" },
    { 99, "SleepDown" }, { 100, "Sleep" }, { 101, "SleepUp" },
    { 744, "PetBattleDeath" }, { 746, "PetBattleRun" }, { 748, "PetBattleWound" }, { 750, "PetBattleAttack" },
    { 752, "PetBattleReadySpell" }, { 754, "PetBattleSpellCast" },
    { 756, "PetBattleCustom0" }, { 758, "PetBattleCustom1" }, { 760, "PetBattleCustom2" },
    { 762, "PetBattleCustom3" }, { 770, "PetBattleDead" },
}
Moves.GROUPS = { custom = { 756, 758, 760, 762 } }
Moves.EVERY = 3 -- seconds per animation in "all"

local function Say(fmt, ...)
    local msg = fmt:format(...)
    ns.Print("anim probe: " .. msg)
    ns.Log("Probe", "anim %s", msg)
end

-- A method call that may not exist (a missing method, or our harness's
-- strict frames, throw on the lookup itself): ok, results.
local function Call(obj, method, ...)
    local args = { ... }
    return pcall(function() return obj[method](obj, unpack(args)) end)
end

-- The card's model actor, and how it was found. The scene is
-- PetJournalPetCard.modelScene (docs/FOREVER_API.md); the actor by
-- Blizzard's tags, else the first active one.
function Moves:Actor()
    local card = PetJournalPetCard
    local scene = card and rawget(card, "modelScene")
    if not scene then return nil, "no PetJournalPetCard.modelScene (open the pet journal)" end
    for _, tag in ipairs({ "unwrapped", "pet", "Pet" }) do
        local ok, actor = Call(scene, "GetActorByTag", tag)
        if ok and actor then return actor, "tag " .. tag end
    end
    local ok, actor = pcall(function()
        for a in scene:EnumerateActiveActors() do return a end
    end)
    if ok and actor then return actor, "first active actor" end
    return nil, "no actor in the scene"
end

local function Find(word)
    local id = tonumber(word)
    for _, a in ipairs(Moves.ANIMS) do
        if a[1] == id or a[2]:lower() == word then return a[1], a[2] end
    end
    return id, id and ("#" .. id) or nil
end

local cycle = 0 -- bumped to cancel a running "all"

-- What the actor says it plays now (GetAnimation, if it answers).
local function Now(actor)
    local ok, id = Call(actor, "GetAnimation")
    return ok and tostring(id) or "?"
end

-- The card's species, for the log: animations differ per model.
local function Species()
    local c = PetJournalPetCard
    return c and tostring(rawget(c, "speciesID")) or "?"
end

function Moves:Probe(arg)
    local actor, how = self:Actor()
    if not actor then return Say("%s", how) end
    local word, speedArg = (arg or "list"):lower():match("^(%S+)%s*(%S*)$")
    word = word or "list"
    local speed = tonumber(speedArg)
    if word == "night" then return self:ForceNight() end
    if word == "stop" then
        cycle = cycle + 1
        local ok = Call(actor, "SetAnimation", 0)
        return Say("stop: SetAnimation(0) %s", ok and "ok" or "failed")
    end
    -- Which of ours the model has (nil: the client can't tell us).
    local has, known = {}, Call(actor, "HasAnimation", 0)
    for _, a in ipairs(self.ANIMS) do
        local ok, yes = Call(actor, "HasAnimation", a[1])
        if ok then has[a[1]] = yes == true end -- (true, false, or nil: the client can't say)
    end
    if word == "list" then
        local names = {}
        for _, a in ipairs(self.ANIMS) do
            if has[a[1]] then names[#names + 1] = ("%s (%d)"):format(a[2], a[1]) end
        end
        local setAnim = Call(actor, "GetAnimation")
        return Say("actor by %s; HasAnimation=%s GetAnimation=%s; has %d of %d: %s", how, tostring(known),
            tostring(setAnim), #names, #self.ANIMS, table.concat(names, ", "))
    end
    if word == "all" or self.GROUPS[word] then
        cycle = cycle + 1
        local mine, list, only = cycle, {}, {}
        for _, id in ipairs(self.GROUPS[word] or {}) do only[id] = true end
        for _, a in ipairs(self.ANIMS) do
            if has[a[1]] ~= false and (word == "all" or only[a[1]]) then list[#list + 1] = a end -- (unknown: try it too)
        end
        local function Step(i)
            if mine ~= cycle then return end
            local a = list[i]
            if not a then
                Call(actor, "SetAnimation", 0)
                return Say("%s: done, %d tried", word, #list)
            end
            local ok, err = Call(actor, "SetAnimation", a[1])
            -- What the actor reports right away and a moment later: a model without the
            -- animation may fall back (2026-11-10: HasAnimation is missing on Forever, and
            -- SetAnimation takes any id without a word).
            local at = Now(actor)
            C_Timer.After(0.5, function()
                if mine ~= cycle then return end
                Say("%d/%d %s (%d) species %s: %s, then %s, after 0.5 s %s", i, #list, a[2], a[1], Species(),
                    ok and "set" or tostring(err), at, Now(actor))
            end)
            C_Timer.After(self.EVERY, function() Step(i + 1) end)
        end
        return Step(1)
    end
    local id, name = Find(word)
    if not id then return Say("unknown animation %q (a number, or a name from the list)", word) end
    local ok, err
    if speed then ok, err = Call(actor, "SetAnimation", id, 0, speed) else ok, err = Call(actor, "SetAnimation", id) end
    Say("%s (%d)%s: SetAnimation %s; has it: %s; now %s", name, id, speed and (" at speed " .. speed) or "",
        ok and "ok" or tostring(err), tostring(has[id]), Now(actor))
end

------------------------------------------------------------------------------
-- The pet on the card
------------------------------------------------------------------------------
local STAND, SIT_DOWN, SIT_UP = 0, 96, 98
Moves.SIT_AFTER = 6 -- seconds on the card before a Latsabb sits down
-- A new pet loads standing; its pose comes after this. Posed while loading,
-- the Zergling and Mini Diablo were framed small and low and stayed so
-- (2026-11-10): the card's camera seems to fit the model as it loads.
Moves.SETTLE = 0.6
Moves.T = { down = 1.2, up = 1.4, happy = 2, cheer = 2.5, dead = 4 } -- how long each one-off plays

-- The animation a pet uses for a reaction (Data/PetMoves.lua, edited by
-- hand): its species' own, else the default; nil when it doesn't do it.
function Moves:For(key, what)
    local data = ns.PetMoves or { default = {}, species = {} }
    local own = data.species[ns.Pets:SpeciesOfKey(key) or 0]
    local id = own and own[what]
    if id == nil then id = data.default[what] end
    return id or nil
end

local shown = { token = 0, awake = {} } -- the card's pet, its pose, and pets woken this session

-- Set an animation, and check on it a moment later: the card refreshes
-- often, and Blizzard may load the model anew and stand it up again
-- (2026-11-10: a pet lay down, then flickered back to standing). If it was
-- reset, once more. Both logged, to learn what the client does.
Moves.RECHECK = 0.3
-- speed: nil plays it normally; 0 freezes it on its first frame (a held pose:
-- 2026-11-10, Dead (6) lay the pet flat, then ended and stood it up again).
local function Play(id, again, speed)
    local actor = Moves:Actor()
    if not actor then return end
    shown.playing, shown.speed = id, speed
    local ok
    if speed then ok = Call(actor, "SetAnimation", id, 0, speed) else ok = Call(actor, "SetAnimation", id) end
    local token = shown.token
    C_Timer.After(Moves.RECHECK, function()
        if token ~= shown.token or shown.playing ~= id then return end
        local now = Moves:Actor()
        local got, at = Call(now or actor, "GetAnimation")
        local reset = now ~= actor or (got and at ~= id)
        ns.Log("Moves", "%s %d: %s; after %.1f s %s%s", tostring(shown.key), id, ok and "set" or "refused",
            Moves.RECHECK, got and tostring(at) or "?", now ~= actor and " (a new actor)" or "")
        if reset and not again then Play(id, true, speed) end
    end)
end

-- Steps { id, seconds, speed }: each in turn; the last one stays. Replaces any running.
function Moves:Sequence(steps)
    shown.token = shown.token + 1
    local mine = shown.token
    local function Step(i)
        if mine ~= shown.token then return end
        local s = steps[i]
        if not s then return end
        Play(s[1], nil, s[3])
        if s[2] then C_Timer.After(s[2], function() Step(i + 1) end) end
    end
    Step(1)
end

local function HasTrait(key, id)
    if not ns.Personality:Known(key) then return false end
    for _, t in ipairs(ns.Personality:Traits(key)) do if t.id == id then return true end end
    return false
end

-- Playing dead: the egg came up today with this pet, and it hasn't been seen yet.
local function DeadToday(key)
    local egg = ns.DB.char.eggs.dodsfall
    return egg and egg.key == key and egg.day == ns.Today() and not egg.played
end

-- The pose the card's pet takes on its own.
function Moves:Rest(key, t)
    if DeadToday(key) and self:For(key, "dead") then return "dead" end
    if not shown.awake[key] then
        if (Moves.night or ns.Personality.IsNight(t or ns.Now())) and not HasTrait(key, "nattugle") and self:For(key, "sleep") then
            return "sleep"
        end
        if HasTrait(key, "latsabb") and self:For(key, "sit") then return "sit" end
    end
    return "stand"
end

-- A pose's steps for this pet; the last one is held.
local function Steps(key, mode)
    if mode == "sleep" then return { { STAND, Moves.SETTLE }, { Moves:For(key, "sleep"), nil, 0 } } end
    if mode == "sit" then
        return { { STAND, Moves.SIT_AFTER }, { SIT_DOWN, Moves.T.down }, { Moves:For(key, "sit") } }
    end
    if mode == "dead" then return { { STAND, Moves.SETTLE }, { Moves:For(key, "dead"), Moves.T.dead }, { STAND } } end
    return { { STAND } }
end

-- A card widget (JournalUI's WIDGETS): the pet's pose, once per pet shown.
function Moves:Update(card, key)
    if not key then
        shown.key, shown.mode = nil, nil
        shown.token = shown.token + 1
        return
    end
    local mode = self:Rest(key)
    if key == shown.key and mode == shown.mode then
        -- The same pet refreshed: Blizzard may have stood the model up again; put back what plays.
        if shown.playing then Play(shown.playing, true, shown.speed) end
        return
    end
    shown.key, shown.mode = key, mode
    if mode == "dead" then ns.DB.char.eggs.dodsfall.played = true end
    self:Sequence(Steps(key, mode))
end

-- After a reaction: back to its pose (awake now, if it slept or sat).
local function Back(key)
    shown.awake[key] = true
    shown.mode = Moves:Rest(key)
    local steps = Steps(key, shown.mode)
    return steps[#steps][1]
end

-- A click on the pet (Cuddle.lua): wakes it up, gets it up, or a happy move.
function Moves:Cuddle(key)
    if key ~= shown.key then return end
    local mode, happy = shown.mode, self:For(key, "happy")
    local back = Back(key)
    local steps = {}
    if mode == "sit" then steps[#steps + 1] = { SIT_UP, self.T.up } end
    if happy then steps[#steps + 1] = { happy, self.T.happy } end
    steps[#steps + 1] = { back }
    self:Sequence(steps)
end

-- A bond level reached (BondTrack's celebration): its cheer, if it has one.
function Moves:Cheer(key)
    local cheer = key == shown.key and self:For(key, "cheer")
    if not cheer then return end
    local back = Back(key)
    self:Sequence({ { cheer, self.T.cheer }, { back } })
end

-- /dp probe anim night: night until toggled off or /reload, every pet asleep
-- again, and the card's pet posed anew.
function Moves:ForceNight()
    self.night = not self.night or nil
    wipe(shown.awake)
    local key = shown.key
    shown.key = nil
    if key then self:Update(nil, key) end
    Say("night %s%s", self.night and "on" or "off", key and "" or " (open a pet's card)")
end

-- The journal closing or our pages covering the card: stop, and start over next time.
function Moves:Stop()
    self:Update(nil, nil)
end
