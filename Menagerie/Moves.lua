local _, ns = ...

-- Animating the pet on the card (docs/IDEAS.md, "Animating the pet on
-- demand"). For now only the research probe, in a git checkout:
--   /dp probe anim          which of the animations below the card's pet has
--                           (the actor's HasAnimation, if the client has it)
--   /dp probe anim <id|name> play one (EmoteDance, 69, PetBattleVictory...)
--   /dp probe anim all      play each one it has, 3 s apart, naming it in chat
--   /dp probe anim stop     back to standing
-- Everything goes to chat and the debug log: what was found, what the client
-- accepted. What the pet actually did is for the eye; ask the user.
local Moves = {}
ns.Moves = Moves

-- AnimationData ids as https://wowdev.wiki/M2/AnimationList lists them
-- (read 2026-11-10; not checked against the client's own table yet).
Moves.ANIMS = {
    { 0, "Stand" }, { 1, "Death" }, { 4, "Walk" }, { 5, "Run" },
    { 37, "JumpStart" }, { 38, "Jump" }, { 39, "JumpEnd" },
    { 60, "EmoteTalk" }, { 66, "EmoteBow" }, { 67, "EmoteWave" }, { 68, "EmoteCheer" }, { 69, "EmoteDance" },
    { 70, "EmoteLaugh" }, { 71, "EmoteSleep" }, { 72, "EmoteSitGround" }, { 74, "EmoteRoar" }, { 75, "EmoteKneel" },
    { 79, "EmoteBeg" }, { 80, "EmoteApplaud" }, { 82, "EmoteFlex" }, { 83, "EmoteShy" }, { 84, "EmotePoint" },
    { 96, "SitGroundDown" }, { 97, "SitGround" }, { 98, "SitGroundUp" },
    { 99, "SleepDown" }, { 100, "Sleep" }, { 101, "SleepUp" },
    { 113, "EmoteSalute" }, { 185, "EmoteYes" }, { 186, "EmoteNo" },
    { 742, "PetBattleStand" }, { 744, "PetBattleDeath" }, { 746, "PetBattleRun" }, { 748, "PetBattleWound" },
    { 750, "PetBattleAttack" }, { 752, "PetBattleReadySpell" }, { 754, "PetBattleSpellCast" },
    { 756, "PetBattleCustom0" }, { 758, "PetBattleCustom1" }, { 760, "PetBattleCustom2" },
    { 762, "PetBattleCustom3" }, { 764, "PetBattleVictory" }, { 766, "PetBattleLoss" }, { 768, "PetBattleStun" },
    { 770, "PetBattleDead" }, { 772, "PetBattleFreeze" },
}
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
    if word == "all" then
        cycle = cycle + 1
        local mine, list = cycle, {}
        for _, a in ipairs(self.ANIMS) do
            if has[a[1]] ~= false then list[#list + 1] = a end -- (unknown: try it too)
        end
        local function Step(i)
            if mine ~= cycle then return end
            local a = list[i]
            if not a then
                Call(actor, "SetAnimation", 0)
                return Say("all: done, %d tried", #list)
            end
            local ok, err = Call(actor, "SetAnimation", a[1])
            Say("%d/%d %s (%d): %s", i, #list, a[2], a[1], ok and "playing" or tostring(err))
            C_Timer.After(self.EVERY, function() Step(i + 1) end)
        end
        return Step(1)
    end
    local id, name = Find(word)
    if not id then return Say("unknown animation %q (a number, or a name from the list)", word) end
    local ok, err = Call(actor, "SetAnimation", id)
    Say("%s (%d): SetAnimation %s; has it: %s", name, id, ok and "ok" or tostring(err), tostring(has[id]))
end
