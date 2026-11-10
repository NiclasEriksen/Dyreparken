local _, ns = ...

-- The pet on the card moves (2026-11-10, docs/IDEAS.md "Animating the pet on
-- demand"; what plays is in docs/FOREVER_API.md):
--   at night it's asleep when you open the card (not a Nattugle), and a click
--     wakes it with a happy hop. Asleep is PetBattleDead, lying still: the
--     sleep ones (99-101) didn't hold on companions (2026-11-10: lying down is a
--     one-off that ends standing, and Sleep itself isn't there);
--   a Latsabb sits down after a few seconds;
--   a click on it (Cuddle.lua) makes it happy: PetBattleCustom0, a joyful
--     hop on the Panda Cub;
--   a bond level-up (BondTrack's celebration) makes it cast a little spell;
--   the day the "is it safe to live with you?" egg (three deaths) came up,
--     it plays dead for a moment, the first time you see its card.
-- The client can't tell us which animations a model has (no HasAnimation,
-- SetAnimation takes any id, GetAnimation echoes it), and they differ: the
-- most basic pets have only stand, death, walk, run and the pet battle set.
-- A missing one leaves the pet standing, which is fine for the idle poses;
-- the reactions use the pet battle set every pet has.
-- Timers only while the card shows a pet; a new pet, the journal closing or
-- our pages covering the card cancel them.
--
-- And the research probe, in a git checkout:
--   /dp probe anim          the actor, and the animations we try
--   /dp probe anim <id|name> play one
--   /dp probe anim all|custom  play each (or the four custom ones), 3 s apart
--   /dp probe anim stop     back to standing
local Moves = {}
ns.Moves = Moves

-- AnimationData ids as https://wowdev.wiki/M2/AnimationList lists them
-- (read 2026-11-10). Only those that played on a companion: the emotes
-- (60-186) and PetBattleStand, Victory, Loss, Stun and Freeze did nothing.
Moves.ANIMS = {
    { 0, "Stand" }, { 1, "Death" }, { 4, "Walk" }, { 5, "Run" },
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
    local word = (arg or "list"):lower()
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
    local ok, err = Call(actor, "SetAnimation", id)
    Say("%s (%d): SetAnimation %s; has it: %s; now %s", name, id, ok and "ok" or tostring(err), tostring(has[id]),
        Now(actor))
end

------------------------------------------------------------------------------
-- The pet on the card
------------------------------------------------------------------------------
local A = { STAND = 0, SIT_DOWN = 96, SIT = 97, SIT_UP = 98, SLEEP_DOWN = 99, SLEEP = 100, SLEEP_UP = 101,
    CAST = 754, HAPPY = 756, DEAD = 770 }
Moves.A = A
Moves.SIT_AFTER = 6 -- seconds on the card before a Latsabb sits down
Moves.T = { down = 1.2, up = 1.4, happy = 2, cast = 2.5, dead = 4 } -- how long each one-off plays

local shown = { token = 0, awake = {} } -- the card's pet, its pose, and pets woken this session

-- Set an animation, and check on it a moment later: the card refreshes
-- often, and Blizzard may load the model anew and stand it up again
-- (2026-11-10: a pet lay down, then flickered back to standing). If it was
-- reset, once more. Both logged, to learn what the client does.
Moves.RECHECK = 0.3
local function Play(id, again)
    local actor = Moves:Actor()
    if not actor then return end
    shown.playing = id
    local ok = Call(actor, "SetAnimation", id)
    local token = shown.token
    C_Timer.After(Moves.RECHECK, function()
        if token ~= shown.token or shown.playing ~= id then return end
        local now = Moves:Actor()
        local got, at = Call(now or actor, "GetAnimation")
        local reset = now ~= actor or (got and at ~= id)
        ns.Log("Moves", "%s %d: %s; after %.1f s %s%s", tostring(shown.key), id, ok and "set" or "refused",
            Moves.RECHECK, got and tostring(at) or "?", now ~= actor and " (a new actor)" or "")
        if reset and not again then Play(id, true) end
    end)
end

-- Steps { id, seconds }: each in turn; the last one stays. Replaces any running.
function Moves:Sequence(steps)
    shown.token = shown.token + 1
    local mine = shown.token
    local function Step(i)
        if mine ~= shown.token then return end
        local s = steps[i]
        if not s then return end
        Play(s[1])
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
    if DeadToday(key) then return "dead" end
    if not shown.awake[key] then
        if ns.Personality.IsNight(t or ns.Now()) and not HasTrait(key, "nattugle") then return "sleep" end
        if HasTrait(key, "latsabb") then return "sit" end
    end
    return "stand"
end

local REST = {
    sleep = { { A.DEAD } },
    sit = { { A.STAND, Moves.SIT_AFTER }, { A.SIT_DOWN, Moves.T.down }, { A.SIT } },
    dead = { { A.DEAD, Moves.T.dead }, { A.STAND } },
    stand = { { A.STAND } },
}

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
        if shown.playing then Play(shown.playing, true) end
        return
    end
    shown.key, shown.mode = key, mode
    if mode == "dead" then ns.DB.char.eggs.dodsfall.played = true end
    self:Sequence(REST[mode])
end

-- After a reaction: back to its pose (awake now, if it slept or sat).
local function Back(key)
    shown.awake[key] = true
    shown.mode = Moves:Rest(key)
    return REST[shown.mode][#REST[shown.mode]][1]
end

-- A click on the pet (Cuddle.lua): wakes it up, or a happy hop.
function Moves:Cuddle(key)
    if key ~= shown.key then return end
    local mode = shown.mode
    local back = Back(key)
    if mode == "sit" then
        self:Sequence({ { A.SIT_UP, self.T.up }, { A.HAPPY, self.T.happy }, { back } })
    else
        self:Sequence({ { A.HAPPY, self.T.happy }, { back } })
    end
end

-- A bond level reached (BondTrack's celebration): a little spell of joy.
function Moves:Cheer(key)
    if key ~= shown.key then return end
    local back = Back(key)
    self:Sequence({ { A.CAST, self.T.cast }, { back } })
end

-- The journal closing or our pages covering the card: stop, and start over next time.
function Moves:Stop()
    self:Update(nil, nil)
end
