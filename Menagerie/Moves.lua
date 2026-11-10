local _, ns = ...

-- The pet on the card moves (2026-11-10, docs/IDEAS.md "Animating the pet on
-- demand"; what plays is in docs/FOREVER_API.md):
--   at night it's asleep when you open the card (not a Nattugle), and a click
--     wakes it with a happy move;
--   a Latsabb sits down after a few seconds;
--   a click on it (Cuddle.lua) makes it happy;
--   a bond level-up (BondTrack's celebration) makes it cheer;
--   the day the "is it safe to live with you?" egg (three deaths) came up,
--     it plays dead for a moment, the first time you see its card;
--   (all 2026-11-10) your pet sits once its day's bond is full; hops the first
--     time you see it after its wish came true; the pet you keep out walks and
--     runs with you; after a dislike it turns its back once; and a species'
--     `lift` moves it up or down to stand on its shadow.
-- The client can't tell us which animations a model has (no HasAnimation,
-- SetAnimation takes any id, GetAnimation echoes it), and they differ: the
-- most basic pets have only stand, death, walk, run and the pet battle set.
-- Which animation each reaction uses, per species, is in Data/PetMoves.lua,
-- edited by hand (found by eye with the probe below). Asleep is Dead (6),
-- held frozen at its end (Play): the sleep ones (99-101) didn't hold, and
-- PetBattleDead (770) sank some pets into the floor (2026-11-10).
-- Timers only while the card shows a pet; a new pet, the journal closing or
-- our pages covering the card cancel them (the sulk turns back then too).
--
-- And the research probe, in a git checkout:
--   /dp probe anim          the actor, and the animations we try
--   /dp probe anim <id|name> [speed] [offset]  play one (speed 0: frozen; offset:
--                           start that many seconds in)
--   /dp probe anim blend none|anim  cut straight to an animation, or blend (the default)
--   /dp probe anim all|custom  play each (or the four custom ones), 3 s apart
--   /dp probe anim stop     back to standing
--   /dp probe anim night    pretend it's night (or day again), to test sleep by day
--   /dp probe anim sleep <id|name> [seconds]  lie down and hold as the card does at night,
--                           with that animation, held that many seconds in (default: the file's sleepAt)
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

------------------------------------------------------------------------------
-- /dp probe pos (2026-11-10): where the pet on the card is, and whether we
-- can move it or find its head. Some models sit too high or too low, and the
-- halo hangs at a fixed height. Logs what the scene, its camera and the
-- actor answer; "x|y|z <delta>" moves the actor (to see if SetPosition
-- shows), "scale <n>" scales it, "reset" puts it back.
------------------------------------------------------------------------------
local function Vals(ok, ...)
    if not ok then return "error: " .. tostring((...)) end
    local out = {}
    for i = 1, select("#", ...) do
        local v = ns.Plain(select(i, ...))
        out[i] = type(v) == "number" and ("%.3f"):format(v) or tostring(v)
    end
    return #out > 0 and table.concat(out, ", ") or "(nothing)"
end
local function Has(obj, method)
    local ok, fn = pcall(function() return obj[method] end)
    return ok and type(fn) == "function"
end
local function PosSay(fmt, ...)
    local msg = fmt:format(...)
    ns.Print("pos probe: " .. msg)
    ns.Log("Probe", "pos %s", msg)
end
local posStart -- the actor's position and scale before we moved it

-- Where the pet is on the card: its box's eight corners projected onto the
-- model scene, as left, bottom, right, top in the scene's pixels (from its
-- bottom left). nil when the client can't say. (2026-11-10: Forever has
-- GetActiveBoundingBox and Project3DPointTo2D, but /dp probe pos box showed
-- the box well off the pet: the projection isn't the camera the card draws
-- with. A probe only.)
function Moves:PetRect()
    local actor = self:Actor()
    local scene = actor and PetJournalPetCard.modelScene
    if not scene then return nil end
    local okp, x, y, z = Call(actor, "GetPosition")
    local okb, x1, y1, z1, x2, y2, z2 = Call(actor, "GetActiveBoundingBox")
    local oks, s = Call(actor, "GetScale")
    if not (okp and okb and type(x) == "number" and type(z2) == "number") then return nil end
    s = (oks and type(s) == "number") and s or 1
    local l, b, r, t
    for _, cx in ipairs({ x1, x2 }) do
        for _, cy in ipairs({ y1, y2 }) do
            for _, cz in ipairs({ z1, z2 }) do
                local ok, px, py = Call(scene, "Project3DPointTo2D", x + cx * s, y + cy * s, z + cz * s)
                if not (ok and type(px) == "number" and type(py) == "number") then return nil end
                l, r = math.min(l or px, px), math.max(r or px, px)
                b, t = math.min(b or py, py), math.max(t or py, py)
            end
        end
    end
    return l, b, r, t
end

-- /dp probe pos box: the rectangle drawn on the card (red, see-through),
-- again to hide it. Each click on the pet logs where it landed (Cuddle).
local boxFrame
function Moves:ShowBox()
    local scene = PetJournalPetCard and PetJournalPetCard.modelScene
    if boxFrame and boxFrame:IsShown() then boxFrame:Hide(); return PosSay("box hidden") end
    local l, b, r, t = self:PetRect()
    if not (scene and l) then return PosSay("no box: the client can't project it") end
    if not boxFrame then
        boxFrame = CreateFrame("Frame", nil, scene)
        boxFrame:SetFrameLevel(scene:GetFrameLevel() + 50)
        local tex = boxFrame:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetColorTexture(1, 0, 0, 0.25)
    end
    boxFrame:ClearAllPoints()
    boxFrame:SetPoint("BOTTOMLEFT", scene, "BOTTOMLEFT", l, b)
    boxFrame:SetSize(math.max(1, r - l), math.max(1, t - b))
    boxFrame:Show()
    PosSay("box: left %.0f, bottom %.0f, right %.0f, top %.0f (scene %s)", l, b, r, t, Vals(Call(scene, "GetSize")))
end

function Moves:ProbePos(arg)
    local actor, how = self:Actor()
    if not actor then return PosSay("%s", how) end
    local scene = PetJournalPetCard.modelScene
    local word, n = (arg or ""):match("^(%S*)%s*(%S*)$")
    n = tonumber(n)
    if posStart and posStart.species ~= Species() then posStart = nil end -- (another pet: its own start)
    if word == "box" then return self:ShowBox() end
    if word == "reset" then
        if posStart then
            Call(actor, "SetPosition", posStart[1], posStart[2], posStart[3])
            if posStart[4] then Call(actor, "SetScale", posStart[4]) end
            posStart = nil
        end
        return PosSay("reset: %s", Vals(Call(actor, "GetPosition")))
    end
    if (word == "x" or word == "y" or word == "z") and n then
        local ok, x, y, z = Call(actor, "GetPosition")
        if not (ok and type(x) == "number") then return PosSay("no GetPosition: %s", Vals(ok, x)) end
        posStart = posStart or { x, y, z, select(2, Call(actor, "GetScale")), species = Species() }
        if word == "x" then x = x + n elseif word == "y" then y = y + n else z = z + n end
        PosSay("SetPosition(%.3f, %.3f, %.3f): %s; now %s", x, y, z, Vals(Call(actor, "SetPosition", x, y, z)),
            Vals(Call(actor, "GetPosition")))
        return
    end
    if word == "scale" and n then
        local ok, s = Call(actor, "GetScale")
        if not posStart then
            local okp, x, y, z = Call(actor, "GetPosition")
            posStart = okp and type(x) == "number" and { x, y, z, ok and s or nil, species = Species() } or nil
        end
        return PosSay("SetScale(%.3f): %s; now %s", n, Vals(Call(actor, "SetScale", n)), Vals(Call(actor, "GetScale")))
    end
    -- The dump.
    PosSay("species %s, actor by %s", Species(), how)
    local function Methods(obj, list)
        local yes, no = {}, {}
        for _, m in ipairs(list) do if Has(obj, m) then yes[#yes + 1] = m else no[#no + 1] = m end end
        return table.concat(yes, " "), table.concat(no, " ")
    end
    PosSay("actor has: %s | lacks: %s", Methods(actor, { "GetPosition", "SetPosition", "GetActiveBoundingBox",
        "GetMaxBoundingBox", "GetScale", "SetScale", "GetYaw", "SetYaw", "GetPitch", "GetModelFileID",
        "GetModelPath", "SetUseCenterForOrigin", "GetUseCenterForOrigin" }))
    PosSay("scene has: %s | lacks: %s", Methods(scene, { "Project3DPointTo2D", "GetActiveCamera", "GetCameraPosition",
        "GetCameraForward", "GetCameraFieldOfView", "GetViewInsets", "GetModelSceneID" }))
    PosSay("actor position: %s", Vals(Call(actor, "GetPosition")))
    PosSay("actor scale: %s; yaw %s", Vals(Call(actor, "GetScale")), Vals(Call(actor, "GetYaw")))
    PosSay("active box (minX, minY, minZ, maxX, maxY, maxZ): %s", Vals(Call(actor, "GetActiveBoundingBox")))
    PosSay("max box: %s", Vals(Call(actor, "GetMaxBoundingBox")))
    PosSay("center for origin: %s", Vals(Call(actor, "GetUseCenterForOrigin")))
    PosSay("scene camera position: %s; forward %s; fov %s", Vals(Call(scene, "GetCameraPosition")),
        Vals(Call(scene, "GetCameraForward")), Vals(Call(scene, "GetCameraFieldOfView")))
    PosSay("scene id %s; size %s; insets %s", Vals(Call(scene, "GetModelSceneID")), Vals(Call(scene, "GetSize")),
        Vals(Call(scene, "GetViewInsets")))
    local okc, cam = Call(scene, "GetActiveCamera")
    if okc and cam then
        PosSay("camera: target %s; zoom %s; yaw %s; pitch %s", Vals(Call(cam, "GetTarget")),
            Vals(Call(cam, "GetZoomDistance")), Vals(Call(cam, "GetYaw")), Vals(Call(cam, "GetPitch")))
    end
    -- Where the actor and its box's bottom and top land on the scene (pixels from its bottom left).
    if Has(scene, "Project3DPointTo2D") then
        local okp, x, y, z = Call(actor, "GetPosition")
        local okb, x1, y1, z1, x2, y2, z2 = Call(actor, "GetActiveBoundingBox")
        if okp and type(x) == "number" then
            PosSay("projected position: %s", Vals(Call(scene, "Project3DPointTo2D", x, y, z)))
            if okb and type(z1) == "number" then
                local okS, s = Call(actor, "GetScale")
                s = (okS and type(s) == "number") and s or 1
                local cx, cy = x + (x1 + x2) / 2 * s, y + (y1 + y2) / 2 * s
                PosSay("projected box bottom: %s; top: %s", Vals(Call(scene, "Project3DPointTo2D", cx, cy, z + z1 * s)),
                    Vals(Call(scene, "Project3DPointTo2D", cx, cy, z + z2 * s)))
            end
        end
    end
    PosSay("done; try /dp probe pos z 0.2 (and reset)")
end

function Moves:Probe(arg)
    local actor, how = self:Actor()
    if not actor then return Say("%s", how) end
    local words = {}
    for w in (arg or ""):lower():gmatch("%S+") do words[#words + 1] = w end
    local word = words[1] or "list"
    local speed, offset = tonumber(words[2]), tonumber(words[3])
    if word == "night" then return self:ForceNight() end
    if word == "sleep" then
        local id, name = Find(words[2] or "")
        if not id then return Say("sleep <id|name> [seconds]") end
        local at = tonumber(words[3]) or ns.PetMoves.default.sleepAt
        self:Sequence({ { id, at }, { id, nil, at } })
        return Say("sleep: %s (%d), held at %.2f s, %s", name, id, at,
            Has(actor, "SetPaused") and "by pausing (SetPaused)" or "frozen (no SetPaused)")
    end
    -- 2026-11-10: frozen at speed 0, Dead (6) stood still instead of lying: the
    -- blend from standing seems frozen too. Retail's actors take a blend
    -- operation (Enum.ModelBlendOperation: 0 None, 1 Anim); unknown on Forever.
    if word == "blend" then
        local op = ({ none = 0, anim = 1 })[words[2] or ""]
        if not op then return Say("blend none|anim") end
        local ok, err = Call(actor, "SetAnimationBlendOperation", op)
        return Say("blend %s: SetAnimationBlendOperation(%d) %s", words[2], op, ok and "ok" or tostring(err))
    end
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
    if offset then ok, err = Call(actor, "SetAnimation", id, 0, speed or 1, offset)
    elseif speed then ok, err = Call(actor, "SetAnimation", id, 0, speed)
    else ok, err = Call(actor, "SetAnimation", id) end
    Say("%s (%d)%s%s: SetAnimation %s; has it: %s; now %s", name, id, speed and (" at speed " .. speed) or "",
        offset and (" from " .. offset .. " s") or "",
        ok and "ok" or tostring(err), tostring(has[id]), Now(actor))
end

------------------------------------------------------------------------------
-- The pet on the card
------------------------------------------------------------------------------
local SIT_DOWN, SIT_UP = 96, 98
Moves.STAND = 0
Moves.SIT_AFTER = 6 -- seconds on the card before a Latsabb sits down
-- A new pet loads standing; its pose comes after this. Posed while loading,
-- the Zergling and Mini Diablo were framed small and low and stayed so
-- (2026-11-10): the card's camera seems to fit the model as it loads.
Moves.SETTLE = 0.6
-- Standing this long on a new card before it lies down to sleep (2026-11-10): paused 0.8 s
-- into lying down 0.6 s after the model was set, every pet got up and froze standing, while
-- the same on a card open a while lay still. The model seems to load (and its animation
-- start) later than our clock says.
Moves.SLEEP_AFTER = 2
Moves.T = { down = 1.2, up = 1.4, happy = 2, cheer = 2.5, dead = 4 } -- how long each one-off plays

-- The animation a pet uses for a reaction (Data/PetMoves.lua, edited by
-- hand): its species' own, else the default; nil when it doesn't do it.
function Moves:For(key, what)
    local data = ns.PetMoves or { default = {}, species = {} }
    local sid = ns.Pets:SpeciesOfKey(key) or 0
    -- While /dp probe lift is open: its picks (DyreparkenDB.liftPicks) go first.
    if what == "lift" and self.liftEditing then
        local pick = ns.DB.global.liftPicks[sid]
        if pick ~= nil then return pick ~= 0 and pick or nil end
    end
    local own = data.species[sid]
    local id = own and own[what]
    if id == nil then id = data.default[what] end
    return id or nil
end

local shown = { token = 0, awake = {}, reposed = 0 } -- the card's pet, its pose, and pets woken this session

-- Set an animation, and check on it a moment later: the card refreshes
-- often, and Blizzard may load the model anew and stand it up again
-- (2026-11-10: a pet lay down, then flickered back to standing). If it was
-- reset, once more. Both logged, to learn what the client does.
Moves.RECHECK = 0.3
-- pose: a held pose instead, frozen (speed 0) that many seconds in, cut to
-- without a blend. 2026-11-10: Dead (6) played on lay the pet flat, then
-- ended and stood it up again; frozen at its start it stood still, the blend
-- from standing frozen too; with no blend, frozen 1.2 s in (the fall over) it
-- lay still.
local NO_BLEND, BLEND = 0, 1 -- Enum.ModelBlendOperation (None, Anim)
local STAND = 0
local Play
local UnSulk, Steps -- (below)

-- 2026-11-10: about one time in three a held pose stood up again by itself
-- right away, and GetAnimation (it only echoes what was set) can't tell. So
-- we watch the actor: anything else that sets an animation or loads a model
-- while a pose is held is logged, and the pose put back (after a model, once
-- it has settled), at most Moves.REPOSE times per pet shown.
Moves.REPOSE = 5
local hooked, own = setmetatable({}, { __mode = "k" }), false
local function Outside(what, arg)
    ns.Log("Moves", "%s(%s) from outside, holding %s", what, tostring(arg), tostring(shown.pose and shown.playing))
    if what ~= "SetAnimation" and shown.key then -- (a model loaded anew: its height again, once it has settled)
        local key, token = shown.key, shown.token
        C_Timer.After(Moves.SETTLE, function() if token == shown.token and shown.key == key then Moves.Lift(key) end end)
    end
    if not shown.pose or shown.reposed >= Moves.REPOSE then return end
    shown.reposed = shown.reposed + 1
    local token, id, pose = shown.token, shown.playing, shown.pose
    C_Timer.After(what == "SetAnimation" and 0 or Moves.SETTLE, function()
        if token == shown.token and shown.playing == id and shown.pose == pose then Play(id, true, pose) end
    end)
end
local function Watch(actor)
    if hooked[actor] then return end
    hooked[actor] = true
    for _, m in ipairs({ "SetAnimation", "SetModelByCreatureDisplayID", "SetModelByFileID" }) do
        local ok, fn = pcall(function() return actor[m] end)
        if ok and type(fn) == "function" then
            hooksecurefunc(actor, m, function(_, arg) if not own then Outside(m, arg) end end)
        end
    end
end

-- A held pose by pausing the actor (2026-11-10): frozen with speed 0 at an
-- offset, the pet lay still for a second and then stood up to its idle (the
-- user: "no longer frozen when they stand up"). Retail's ModelSceneActor has
-- SetPaused; unverified on Forever, so used only when the actor has it: the
-- animation plays at its own speed and is paused `pose` seconds in.
local function Unpause(actor)
    if shown.paused then Call(actor, "SetPaused", false); shown.paused = nil end
end
local function PlayPaused(actor, id, pose)
    -- Already playing it (the lie-down step before this one): pause where it is now.
    local playingFor = shown.playing == id and not shown.pose and shown.since and GetTime() - shown.since
    shown.playing, shown.pose = id, pose
    if not playingFor then
        own = true
        Call(actor, "SetAnimationBlendOperation", BLEND)
        Call(actor, "SetAnimation", STAND) -- (else the one it's already on isn't started over)
        Call(actor, "SetAnimation", id)
        own = false
        shown.since, playingFor = GetTime(), 0
    end
    local token = shown.token
    local function Pause()
        if token ~= shown.token or shown.playing ~= id or shown.pose ~= pose then return end
        local ok = Call(actor, "SetPaused", true)
        shown.paused = ok or nil
        ns.Log("Moves", "%s %d: paused %.2f s in: %s", tostring(shown.key), id, pose, ok and "ok" or "failed")
    end
    local wait = pose - playingFor
    if wait <= 0.02 then Pause() else C_Timer.After(wait, Pause) end
end

Play = function(id, again, pose)
    local actor = Moves:Actor()
    if not actor then return end
    Watch(actor)
    Unpause(actor)
    if pose and Has(actor, "SetPaused") then return PlayPaused(actor, id, pose) end
    shown.playing, shown.pose = id, pose
    shown.since = GetTime()
    own = true
    Call(actor, "SetAnimationBlendOperation", pose and NO_BLEND or BLEND)
    local ok
    if pose then
        -- Standing first, in the same moment: 2026-11-10, Dead (6) frozen right after Dead (6)
        -- played (the lie-down) didn't take, and the pet stood up as the first one ended. The
        -- client seems to ignore the animation it's already playing.
        Call(actor, "SetAnimation", STAND)
        ok = Call(actor, "SetAnimation", id, 0, 0, pose)
    else
        ok = Call(actor, "SetAnimation", id)
    end
    own = false
    local token = shown.token
    C_Timer.After(Moves.RECHECK, function()
        if token ~= shown.token or shown.playing ~= id then return end
        local now = Moves:Actor()
        local got, at = Call(now or actor, "GetAnimation")
        local reset = now ~= actor or (got and at ~= id)
        ns.Log("Moves", "%s %d: %s; after %.1f s %s%s", tostring(shown.key), id, ok and "set" or "refused",
            Moves.RECHECK, got and tostring(at) or "?", now ~= actor and " (a new actor)" or "")
        if reset and not again then Play(id, true, pose) end
    end)
end

-- Steps { id, seconds, pose }: each in turn; the last one stays. Replaces any running.
function Moves:Sequence(steps)
    shown.token = shown.token + 1
    shown.reposed = 0
    local mine = shown.token
    local function Step(i)
        if mine ~= shown.token then return end
        local s = steps[i]
        if not s then return end
        shown.last = i == #steps -- (a refresh puts back only the step that stays)
        if s.on then s.on() end -- (a once-a-day moment counts as seen only when it plays)
        local id = s[1]
        if shown.last and not s[3] then
            -- Back to rest after a one-off: as things are now (code review 2026-11-10: a stop
            -- during the hop left it walking; after playing dead it never walked).
            if shown.mode == "dead" and Moves:Rest(shown.key) == "stand" then shown.mode = "stand" end
            -- (stopped moving meanwhile, and it's a sitter: it settles again)
            if shown.mode == "stand" and Moves:Rest(shown.key) == "sit" then
                shown.mode = "sit"
                return Moves:Sequence(Steps(shown.key, "sit"))
            end
            if shown.mode == "stand" then id = Moves:MotionId(shown.key) or Moves.STAND end
        end
        Play(id, nil, s[3])
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
        -- Moving with you beats sitting (the user, 2026-11-10); sleep at night still wins.
        if self:MotionId(key) then return "stand" end
        if HasTrait(key, "latsabb") and self:For(key, "sit") then return "sit" end
        -- Content for today: your pet sits once its day's bond is full (2026-11-10).
        if self:For(key, "sit") and ns.Pets:IsOwned(key) then
            local today, max = ns.Bond:Today(key)
            if today >= max then return "sit" end
        end
    end
    return "stand"
end

-- Your adopted pet's wish came true and you haven't seen it on the card since:
-- a happy hop, once (2026-11-10).
local function WishJoy(key)
    local w = ns.DB.char.wish
    return w and w.done and w.pet == key and w.day == ns.Today() and not w.shown and Moves:For(key, "happy")
end

------------------------------------------------------------------------------
-- Moving with you (2026-11-10, the user's idea): the pet you keep out
-- (auto-summon's active pet) walks on its card while you move on foot, and
-- runs while you're mounted and moving; on a taxi it stands. Sleep at night, a
-- hop, a cheer and playing dead win over it; sitting doesn't (the user,
-- 2026-11-10): a sitter gets up and goes with you, and sits again once you've
-- stopped. Events
-- only while that pet's card shows. PLAYER_STARTED/STOPPED_MOVING and
-- GetUnitSpeed are unverified on Forever: without them it simply stands.
------------------------------------------------------------------------------
local motion = { on = false, moving = false, token = 0 }
Moves.STOP_AFTER = 0.3 -- a stop this short isn't one (tapped keys would twitch it)
local MOTION_EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_CONTROL_GAINED" }
local function Truthy(v) return ns.Plain(v) and true or false end

-- The walk or run it plays now, or nil (standing still, on a taxi, not the pet you keep out).
function Moves:MotionId(key)
    if not (motion.on and motion.moving and key and ns.Summon:ActiveKey() == key) then return nil end
    if Truthy(UnitOnTaxi("player")) then return nil end
    return self:For(key, Truthy(IsMounted()) and "run" or "walk")
end

-- Are we moving (GetUnitSpeed), or nil when the client can't say.
function Moves.Moving()
    local ok, speed = pcall(function() return GetUnitSpeed and GetUnitSpeed("player") end)
    speed = ok and ns.Plain(speed)
    if type(speed) ~= "number" then return nil end
    return speed > 0
end

-- Moving changed: a sitting pet gets up and goes with you, and sits again when
-- you stop; a pet resting standing (its last step held) takes the walk up.
local function Repose()
    local key = shown.key
    if not key then return end
    local mode = Moves:Rest(key)
    if shown.mode == "sit" and mode == "stand" then -- (sitting, or about to: up and away)
        local seated = shown.playing == SIT_DOWN or shown.playing == Moves:For(key, "sit")
        shown.mode = "stand"
        local steps = seated and { { SIT_UP, Moves.T.up } } or {}
        steps[#steps + 1] = { STAND }
        return Moves:Sequence(steps)
    end
    if shown.mode == "stand" and mode == "sit" and shown.last then -- (stopped: it settles again)
        shown.mode = "sit"
        return Moves:Sequence(Steps(key, "sit"))
    end
    if shown.mode ~= "stand" or not shown.last then return end
    local id = Moves:MotionId(key) or STAND
    if shown.playing ~= id then Play(id) end
end

function Moves:Follow(key)
    local want = key ~= nil and ns.Summon:ActiveKey() == key
    if want == motion.on then return end
    motion.on, motion.token = want, motion.token + 1
    if not want then
        motion.moving = false
        for _, e in ipairs(MOTION_EVENTS) do ns.Events:Off(e, Moves) end
        return Repose() -- (code review 2026-11-10: turned off mid-walk, it walked on)
    end
    motion.moving = Moves.Moving() or false
    if key == shown.key then Repose() end
    ns.Events:On("PLAYER_STARTED_MOVING", Moves, function()
        motion.token = motion.token + 1
        if not motion.moving then motion.moving = true; Repose() end
    end)
    ns.Events:On("PLAYER_STOPPED_MOVING", Moves, function()
        motion.token = motion.token + 1
        local mine = motion.token
        C_Timer.After(Moves.STOP_AFTER, function()
            if mine == motion.token and motion.moving then motion.moving = false; Repose() end
        end)
    end)
    -- Mounting, landing, a flight's end: how fast we really go now. (2026-11-10: landed from a
    -- flight path and standing, the pet walked: no stop came after the flight.)
    local function Resync()
        local now = Moves.Moving()
        if now ~= nil then motion.moving = now end
        Repose()
    end
    ns.Events:On("PLAYER_MOUNT_DISPLAY_CHANGED", Moves, Resync)
    ns.Events:On("PLAYER_CONTROL_GAINED", Moves, Resync)
end

-- A pose's steps for this pet; the last one is held.
Steps = function(key, mode)
    -- Lying down: played (blended) up to sleepAt, then held there. 2026-11-10: blended, Dead
    -- (6) lies a pet down smoothly but then stands it up; sometimes it doesn't play at all,
    -- and the held pose still comes.
    if mode == "sleep" then
        local id, at = Moves:For(key, "sleep"), Moves:For(key, "sleepAt") or 0
        return { { STAND, Moves.SLEEP_AFTER }, { id, at }, { id, nil, at } }
    end
    if mode == "sit" then
        return { { STAND, Moves.SIT_AFTER }, { SIT_DOWN, Moves.T.down }, { Moves:For(key, "sit") } }
    end
    if mode == "dead" then
        return { { STAND, Moves.SETTLE },
            { Moves:For(key, "dead"), Moves.T.dead, on = function() ns.DB.char.eggs.dodsfall.played = true end },
            { STAND } }
    end
    -- Walking or running: only once the model has loaded. 2026-11-10: the client scales a
    -- model to its size as it loads, and a walking one is bigger, so a pet shown mid-walk
    -- came out at two thirds of its size (scale 13.4 instead of 19.5) until loaded again.
    local motion = Moves:MotionId(key)
    if motion then return { { STAND, Moves.SETTLE }, { motion } } end
    return { { STAND } }
end

-- Standing on its shadow (2026-11-10): Blizzard puts each model at a height
-- of its own, and some float or sink. A species' `lift` (Data/PetMoves.lua,
-- found by eye) moves it at once, and again once the model has loaded (or the
-- client loads it anew) if it was put back. (Working it out from the model's box and the camera didn't
-- match what's on screen: /dp probe pos box, 2026-11-10.)
-- The height isn't the pet's but its model scene's (GetModelSceneID: a few scenes,
-- heights 0.5, 1, 1.5, 2.5...): Blizzard sets it only when the card changes scene,
-- and between two pets of one scene leaves the actor where we put it. So each
-- scene's height is read once, as it arrives, and a lift always lands on that,
-- never on what's left from the last pet (reading heights by pet was wrong
-- whenever two pets shared a scene: 2026-11-10).
local bases, lastScene = {}, nil
local function Scene(key)
    local scene = PetJournalPetCard and rawget(PetJournalPetCard, "modelScene")
    local ok, id = Call(scene or {}, "GetModelSceneID")
    if ok and id then return "scene " .. tostring(id) end
    return key -- (no scene ids: by pet)
end
local function Lift(key)
    local actor = Moves:Actor()
    local ok, x, y, z = Call(actor or {}, "GetPosition")
    if not (ok and type(z) == "number") then return end
    local scene = Scene(key)
    if scene ~= lastScene or not bases[scene] then bases[scene] = z end -- (just set by Blizzard)
    lastScene = scene
    local base = bases[scene]
    local lift = Moves:For(key, "lift")
    local target = base + (lift or 0)
    if math.abs(z - target) < 1e-3 then return end
    Call(actor, "SetPosition", x, y, target)
    ns.Log("Moves", "%s at %.2f (%s at %.2f%s)", key, target, scene, base, lift and ("%+.2f"):format(lift) or "")
end
local function LiftSoon(key)
    local token = shown.token
    C_Timer.After(Moves.SETTLE, function()
        if token == shown.token and shown.key == key then Lift(key) end
    end)
end
Moves.Lift = Lift

-- The card's pet at its own height again, then lifted as For says now (the lift editor).
function Moves:Relift()
    if shown.key then Lift(shown.key) end
end

-- Its back turned again to face you (the sulk's end, another pet, the card closing).
UnSulk = function()
    local b = shown.sulk
    if not b then return end
    shown.sulk = nil
    Call(b.actor, "SetYaw", b.yaw)
end

-- Sulking (2026-11-10): the first time you open its card on a day a dislike
-- of its came up (Quirks: char.sulk), the pet turns its back for a few
-- seconds, a little cloud over it. ModelSceneActor:SetYaw is unverified on
-- Forever: without it, just the cloud.
Moves.SULK = 3
local function Sulk(key)
    local s = ns.DB.char.sulk
    if not (s and s.key == key and s.day == ns.Today() and not s.shown) then return end
    local token = shown.token
    C_Timer.After(Moves.SETTLE, function()
        if token ~= shown.token or shown.key ~= key then return end
        s.shown = true
        local card = rawget(_G, "PetJournalPetCard")
        if card and ns.Fx then
            ns.Fx:Burst({ card, "CENTER", 0, 60 }, "cloud", { n = 2, color = { 0.8, 0.8, 0.85 }, alpha = 0.7, size = 0.6, rise = 30 })
        end
        local actor = Moves:Actor()
        local ok, yaw = Call(actor or {}, "GetYaw")
        if not (ok and type(yaw) == "number") then return ns.Log("Moves", "sulk: no GetYaw") end
        Call(actor, "SetYaw", yaw + math.pi)
        ns.Log("Moves", "sulk %s: back turned", key)
        local back = { actor = actor, yaw = yaw }
        shown.sulk = back
        C_Timer.After(Moves.SULK, function() if shown.sulk == back then UnSulk() end end)
    end)
end

-- A card widget (JournalUI's WIDGETS): the pet's pose, once per pet shown.
function Moves:Update(card, key)
    -- The pet's moves turned off (Settings: cardMoves): it just stands, on its shadow.
    if key and not ns.Settings:On("cardMoves") then
        local was = shown.key or shown.playing
        self:Update(card, nil)
        if was then Play(STAND); shown.playing = nil end -- (out of a held pose, once)
        Lift(key)
        return
    end
    self:Follow(key)
    if not key then
        UnSulk()
        local actor = Moves:Actor()
        if actor then Unpause(actor) end -- (a paused actor would stay so for Blizzard's next pet)
        -- (nothing held either: a model loading on a closed card isn't posed again)
        shown.key, shown.mode, shown.playing, shown.pose, shown.last = nil, nil, nil, nil, nil
        shown.token = shown.token + 1
        return
    end
    local mode = self:Rest(key)
    if key == shown.key and mode == shown.mode then
        -- The same pet refreshed: Blizzard may have stood the model up again; put back the
        -- step that stays. Not a one-off (a hop, a cheer, the lie-down): it would start over
        -- on every guildmate's BOND message (code review 2026-11-10).
        -- Paused where it lies: nothing to put back. (Played again, the client ignored the
        -- Dead it was already on, so unpaused it got up, and the pause caught it standing: 2026-11-10.)
        if shown.paused then return end
        if shown.playing and shown.last then Play(shown.playing, true, shown.pose) end
        return
    end
    UnSulk()
    shown.key, shown.mode = key, mode
    local steps = Steps(key, mode)
    -- A one-off first, once the model has loaded: a level-up's cheer (celebrated as the card
    -- opened, before the pet was posed: code review 2026-11-10), or a wish come true.
    local cheer = shown.cheerFor == key and mode ~= "dead" and self:For(key, "cheer")
    local joy = not cheer and mode ~= "dead" and mode ~= "sleep" and WishJoy(key)
    shown.cheerFor = nil
    if cheer or joy then
        if cheer then shown.awake[key] = true; mode = self:Rest(key); shown.mode = mode; steps = Steps(key, mode) end
        table.insert(steps, 1, { cheer or joy, cheer and self.T.cheer or self.T.happy,
            on = joy and function() ns.DB.char.wish.shown = true end or nil })
        table.insert(steps, 1, { STAND, self.SETTLE })
    end
    self:Sequence(steps)
    Lift(key)     -- at once (2026-11-10: a moment later read as a jump) ...
    LiftSoon(key) -- ... and again if the model, done loading, was put back
    Sulk(key)
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
    -- Up first only if it's sitting already (2026-11-10: clicked in its first seconds, still
    -- standing, it "got up" for 1.4 s before the hop).
    local seated = shown.playing == SIT_DOWN or shown.playing == self:For(key, "sit")
    if mode == "sit" and seated then steps[#steps + 1] = { SIT_UP, self.T.up } end
    if happy then steps[#steps + 1] = { happy, self.T.happy } end
    steps[#steps + 1] = { back }
    self:Sequence(steps)
    -- Woken up: its Zzz go (Decor reads the pose; the card's refresh leaves the hop playing).
    if mode == "sleep" and ns.JournalUI then ns.JournalUI:Refresh() end
end

-- A bond level reached (BondTrack's celebration): its cheer, if it has one.
function Moves:Cheer(key)
    if key ~= shown.key then shown.cheerFor = key; return end -- (posed next: Update plays it)
    local cheer = self:For(key, "cheer")
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

-- Another pet made the one kept out (or auto-summon off) while the card shows.
ns.Bus:On("ACTIVE_PET", function()
    if shown.key then Moves:Follow(shown.key) end
end)
