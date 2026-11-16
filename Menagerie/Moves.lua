---@class Dyreparken
local ns = select(2, ...)

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
-- edited by hand (found by eye with /dp probe anim). Asleep is Dead (6),
-- held frozen at its end (Play): the sleep ones (99-101) didn't hold, and
-- PetBattleDead (770) sank some pets into the floor (2026-11-10).
-- What a pet does is planned in one place, Moves.Plan (step lists, no frames
-- or timers: test them without playing), and played by a stage (the card, the
-- pet frame), which only plays plans.
-- Timers only while the card shows a pet; a new pet, the journal closing or
-- our pages covering the card cancel them (the sulk turns back then too).
-- The research probes (/dp probe anim, pos) and the editors' hook are in
-- Dev/MovesProbe.lua, which a release doesn't have.
---@class Dyreparken.Moves
---@field Update fun(self, card, key) the card's stage's (made at the end of this file)
---@field Sequence fun(self, ...)
---@field Cuddle fun(self, key)
---@field Try fun(self, key, what, whole)
---@field Stop fun(self)
---@field Relift fun(self)
---@field override? table Dev/MovesProbe.lua's editors (a release leaves it nil)
local Moves = {}
ns.Moves = Moves

local Call = ns.Call -- (Init.lua: a method that may not exist)

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
        for a in scene:EnumerateActiveActors() do return a end -- luacheck: ignore 512 (the first one only)
    end)
    if ok and actor then return actor, "first active actor" end
    return nil, "no actor in the scene"
end

local function Has(obj, method)
    local ok, fn = pcall(function() return obj[method] end)
    return ok and type(fn) == "function"
end

------------------------------------------------------------------------------
-- The pet on the card
------------------------------------------------------------------------------
Moves.STAND = 0
Moves.SIT_AFTER = 6 -- seconds on the card before a Latsabb sits down
-- A new pet loads standing; its pose comes after this. Posed while loading,
-- the Zergling and Mini Diablo were framed small and low and stayed so
-- (2026-11-10): the card's camera seems to fit the model as it loads.
Moves.SETTLE = 0.6
-- A sulking pet keeps its back turned this long (seconds).
Moves.SULK = 3
-- Turning around (2026-11-13, the user: "it just instantly turns around and then back again (looks
-- just buggy)"): half a turn walking, eased, this long each way, in this many SetYaw steps (no
-- OnUpdate: a timer chain, only while it turns). Tune by eye.
Moves.TURN = 0.6
Moves.TURN_STEPS = 12
-- Moods over the pet on the card while it plays them out (Fx:Emit's particles, from a point over its
-- head), by step.mood; each given how long it lasts. The sulk (2026-11-13, the user: "particles that
-- match the mood"): a small grey cloud that settles over it and thins as it turns round, two puffs, and
-- a few drops falling from it now and then.
Moves.MOOD = {
    sulk = function(secs)
        local cloud, list = ns.Icon("cloud"), {}
        list[1] = { tex = cloud, color = { 0.55, 0.57, 0.62 }, alpha = 0.9, size = { 64, 40 }, x = -6,
            up = { 0, -8, 0.5, "OUT" }, fadeIn = { 0, 0.9, 0.5 }, drift = { 6, 2, secs - 0.5 }, fadeOut = { 0.9, 0, secs - 0.5 } }
        list[2] = { tex = cloud, color = { 0.48, 0.5, 0.56 }, alpha = 0.85, size = { 44, 28 }, x = 16, y = 6, delay = 0.15,
            up = { 0, -6, 0.5, "OUT" }, fadeIn = { 0, 0.85, 0.5 }, drift = { -4, 2, secs - 0.65 }, fadeOut = { 0.85, 0, secs - 0.65 } }
        local drops = math.max(0, math.floor((secs - 1) / 0.6))
        for i = 1, drops do
            list[#list + 1] = { tex = ns.Icon("drop"), color = { 0.6, 0.72, 0.9 }, alpha = 0.8, size = 7,
                x = ((i % 3) - 1) * 12, y = -12, delay = 0.5 + (i - 1) * 0.6,
                up = { 0, -10, 0.15 }, fadeIn = { 0, 0.8, 0.15 }, drift = { 0, -30, 0.5 }, fadeOut = { 0.8, 0, 0.5 } }
        end
        return list
    end,
}
-- Standing this long on a new card before it lies down to sleep (2026-11-10): paused 0.8 s
-- into lying down 0.6 s after the model was set, every pet got up and froze standing, while
-- the same on a card open a while lay still. The model seems to load (and its animation
-- start) later than our clock says.
Moves.SLEEP_AFTER = 2
-- A new model's load, waited for (2026-11-16, the user: pets too big or too low, waking up after a second
-- or two, a cat lying down halfway, standing up and snapping into its sleep; "it keeps coming back").
-- Retail's ModelSceneActorMixin, which Forever's actor has (/dp probe api: UpdateScale, MarkScaleDirty,
-- SetOnModelLoadedCallback): a model's load marks its scale dirty, and the next frame scales it to the box
-- of the pose it plays THEN; and the engine stands it up. A fixed SLEEP_AFTER lost both whenever a model
-- took longer: scaled lying down (too big, too low) and stood up mid lie-down or asleep. So the stage
-- that starts a new model's pose stands until the model says it has loaded (its loaded callback, else
-- IsGeoReady going true, looked at every LOAD_POLL), AFTER_LOAD more, and SLEEP_AFTER's seconds at least;
-- LOAD_MAX at most. Then its scale is worked out once standing, and kept (Pin), if the load was confirmed.
Moves.LOAD_MAX = 3
Moves.LOAD_POLL = 0.1
Moves.AFTER_LOAD = 0.3
-- Each animation's own data loads the first time it plays on a model, and again after a swap (2026-11-16,
-- the user: the moves editor's "Hele" stuttered the first time, then played well, and again after another
-- pet): the first lie-down stopped halfway and snapped. So a hidden PlayerModel of the same pet plays them
-- first, one every WARM_STEP, while the pet stands, to have them loaded before it shows them (Warm).
Moves.WARM_STEP = 0.15
Moves.WARM_MAX = 1.5 -- (its own load: at most this long before it plays them anyway)
Moves.WARM = { "sleep", "sleepHold", "sleepUp", "happy", "happyToo", "cheer", "sitDown", "sit", "sitUp", "walk", "run",
    "dead", "jumpStart", "jump", "jumpEnd" }
Moves.HAPPY_TOO_CHANCE = 1 / 3 -- a click plays happyToo instead of happy this often

-- Placing a pet ourselves (2026-11-16, the user: "half of them either is scaled wrong or positioned wrong,
-- and it feels cheap"; whelps too high and too low, cats sharing one model at different heights, the hare
-- too big). The log: each scene places the model by the CENTER of some box of its own on the up axis
-- (IsUsingCenterForOrigin false, false, true; not the box GetActiveBoundingBox reports), so its feet land
-- anywhere, and move as its pose changes; and its scale fits its biggest side, from whatever pose played as
-- it loaded. The lifts found by eye made up for one pose of one pet. Working it out on screen
-- (Project3DPointTo2D) was right in some scenes and far off in others, so (the user's pick, the same day):
-- the model's own origin (its feet) is placed, never its center, and every scene (a camera of its own, the
-- same for all its pets) has a floor and a size, set once by eye (Data/PetScenes.lua, /dp probe place). A
-- pet stands `size` tall there (its standing box, Data/PetBoxes.lua from /dp probe api boxes, else measured
-- the first time it stands), or WIDE times that wide if it's wider; a pet hovering over the ground (a whelp)
-- has its origin on the floor, so it lies on it asleep. A scene with no floor set yet: as Blizzard has it,
-- with the old lifts.
Moves.FRAMING = true
Moves.WIDE = 1.6
local measured = {} -- species id -> its box, measured standing this session (not in Data/PetBoxes.lua)
Moves.measured = measured
-- A species' standing box { scene, low, high, wide } (model units: its lowest and highest point, its widest
-- side), or nil.
function Moves:Box(sid)
    return sid and (ns.PetBoxes and ns.PetBoxes[sid] or measured[sid]) or nil
end
-- A model, by its standing box (pets that share a model share a box: the cats, the parrots, the whelps).
-- (Each to three decimals, a "-0.000" as "0.000": a box read again can come out a hair either side of zero,
-- 2026-11-16, the chickens' picks.)
local function Third(v)
    local text = ("%.3f"):format(v)
    return text == "-0.000" and "0.000" or text
end
function Moves.ModelOf(box)
    return Third(box.low) .. " " .. Third(box.high) .. " " .. Third(box.wide)
end
-- Where a pet with this box stands on a stage, in this scene { floor, size }, and from where: the stage's row
-- for its model, else for its scene, else the card's for its model, else for its scene (Data/PetScenes.lua);
-- the editor's picks first while it's open. nil: not set.
---@return { floor: number, size: number }|nil, string|nil
function Moves:FitFor(stage, box, scene)
    local o, model = self.override, Moves.ModelOf(box)
    for i, st in ipairs({ stage, "card" }) do
        if i == 1 or st ~= stage then
            local pick = o and o.Model and o.Model(st, model)
            if pick then return pick, st .. " model" end
            local rows = ns.PetModels and ns.PetModels[st]
            if rows and rows[model] then return rows[model], st .. " model" end
            pick = scene and o and o.Scene and o.Scene(st, scene)
            if pick then return pick, st .. " scene" end
            rows = ns.PetScenes and ns.PetScenes[st]
            if scene and rows and rows[scene] then return rows[scene], st .. " scene" end
        end
    end
    return nil
end
-- How big and how high a pet stands, for a box and a scene's fit: scale, z.
function Moves.Fit(box, fit)
    local h = box.high - box.low
    if h <= 1e-3 then return nil end
    local scale = math.min(fit.size / h, fit.size * Moves.WIDE / math.max(box.wide or 0, 1e-3))
    return scale, fit.floor - scale * math.min(box.low, 0)
end
Moves.T = { down = 1.2, up = 1.4, happy = 2, cheer = 2.5, dead = 4, attack = 1.5, cower = 1.5 } -- how long each one-off plays

-- How long a one-off plays on this pet: as measured (Data/AnimLengths.lua, /dp probe lengths), else
-- the fixed time. (2026-11-11: with a fixed 2 s, a pet froze on the end of a 1.1 s hop.)
function Moves:Length(key, id, fallback)
    local sid = key and ns.Pets:SpeciesOfKey(key)
    local own = sid and ns.AnimLengths and ns.AnimLengths[sid]
    return own and id and own[id] or fallback
end

-- The species with a one-off move not measured in Data/AnimLengths.lua (a new companion, or a move changed
-- in Data/PetMoves.lua): what /dp probe api lengths times by default (2026-11-12). A sit move counts only
-- for a pet that can sit. Sorted ids.
Moves.MEASURED = { "happy", "happyToo", "cheer", "sleepUp", "sitDown", "sitUp", "dead", "attack", "cower" }
function Moves:Unmeasured()
    local list = {}
    for sid in pairs(ns.Companions and ns.Companions.species or {}) do
        local key, own = ns.Pets:KeyOfSpecies(sid), ns.AnimLengths and ns.AnimLengths[sid]
        for _, what in ipairs(self.MEASURED) do
            local id = self:For(key, what)
            if id and id ~= 0 and (what:sub(1, 3) ~= "sit" or self:For(key, "canSit") ~= false)
                and not (own and own[id] ~= nil) then
                list[#list + 1] = sid
                break
            end
        end
    end
    table.sort(list)
    return list
end

-- The animation a pet uses for a reaction (Data/PetMoves.lua, edited by
-- hand): its species' own, else the default; nil when it doesn't do it.
function Moves:For(key, what)
    local data = ns.PetMoves or { default = {}, species = {} }
    local sid = ns.Pets:SpeciesOfKey(key) or 0
    -- An editor's pick goes first (Dev/MovesProbe.lua; never in a release): false is "none".
    local o = self.override
    if o then
        local pick = o.For(sid, what)
        if pick ~= nil then return pick or nil end
    end
    local own = data.species[sid]
    local id = own and own[what]
    if id == nil then id = data.default[what] end
    return id or nil
end

-- Stages (2026-11-11, groundwork for the pet frame: "share the code with the pet journal and be 1:1
-- in animation / reaction"): everything that poses a pet on a model actor lives in a stage, made by
-- Moves.NewStage. The journal card is one (Moves.card); the on-screen pet frame will be another, with
-- its own actor. What's shared: which pets were woken this session (awake), moving with you (motion),
-- and every rule of what a pet does (For, Length, and the planner, Moves.Plan). The old
-- Moves:Update/Cuddle/... calls are the card's.
local awake = {} -- pets woken this session (by a click, a cheer): on every stage
Moves.awake = awake
Moves.stages = {}
Moves.REPOSE = 5
local hooked, own = setmetatable({}, { __mode = "k" }), false

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
local motion = { on = false, moving = false }
local motionTimers = ns.Timers() -- (a stop's wait: taken back by a start, or by turning off)
Moves.STOP_AFTER = 0.3 -- a stop this short isn't one (tapped keys would twitch it)
-- A jump with you (2026-11-11, the user): the pet's JumpStart, its Jump held for the rest of the time
-- you're in the air (about JUMP_AIR from the key), then JumpEnd. No event says you landed, and no polling.
Moves.JUMP_AIR = 0.7
Moves.T.jumpStart, Moves.T.jumpEnd = 0.3, 0.4 -- (unmeasured lengths: else Data/AnimLengths.lua)
local MOTION_EVENTS = { "PLAYER_STARTED_MOVING", "PLAYER_STOPPED_MOVING", "PLAYER_MOUNT_DISPLAY_CHANGED",
    "PLAYER_CONTROL_GAINED", "UPDATE_SHAPESHIFT_FORM" }
-- Forms that ride like a mount, for the pet's run (the user, 2026-11-11): GetShapeshiftFormID's
-- Travel Form (druid) and Ghost Wolf (shaman).
Moves.RIDING_FORMS = { [3] = true, [16] = true }
local function Truthy(v) return ns.Plain(v) and true or false end

-- The walk or run it plays now, or nil (standing still, on a taxi, not the pet you keep out).
function Moves:MotionId(key)
    if not (motion.on and motion.moving and key and Moves.WithYou(key)) then return nil end
    if Truthy(UnitOnTaxi("player")) then return nil end
    return self:For(key, Moves.Riding() and "run" or "walk")
end

-- The pet with you: the one kept out, or (code review 2026-11-11: the pet frame shows the pet
-- that's out, and one summoned by hand just stood) the one that's out now.
function Moves.WithYou(key)
    return key ~= nil and (ns.Summon:ActiveKey() == key or ns.Pets:OutKey() == key)
end

-- On a mount, or in a form that's as fast as one.
function Moves.Riding()
    if Truthy(IsMounted()) then return true end
    local ok, form = pcall(function() return GetShapeshiftFormID and GetShapeshiftFormID() end)
    form = ok and ns.Plain(form)
    return form and Moves.RIDING_FORMS[form] or false
end

-- Are we moving (GetUnitSpeed), or nil when the client can't say.
function Moves.Moving()
    local ok, speed = pcall(function() return GetUnitSpeed and GetUnitSpeed("player") end)
    speed = ok and ns.Plain(speed)
    if type(speed) ~= "number" then return nil end
    return speed > 0
end

local function ReposeAll() for _, s in ipairs(Moves.stages) do s:Repose() end end

function Moves:JumpAll()
    for _, s in ipairs(self.stages) do s:Jump() end
end

-- Moving with you on every stage that shows the pet you keep out: the events while any does.
function Moves:FollowAll()
    local want = false
    for _, s in ipairs(self.stages) do if Moves.WithYou(s.want) then want = true end end
    if want == motion.on then return end
    motion.on = want
    motionTimers:Cancel()
    if not want then
        motion.moving = false
        for _, e in ipairs(MOTION_EVENTS) do ns.Events:Off(e, Moves) end
        return ReposeAll() -- (code review 2026-11-10: turned off mid-walk, it walked on)
    end
    motion.moving = Moves.Moving() or false
    ReposeAll()
    ns.Events:On("PLAYER_STARTED_MOVING", Moves, function()
        motionTimers:Cancel()
        if not motion.moving then motion.moving = true; ReposeAll() end
    end)
    ns.Events:On("PLAYER_STOPPED_MOVING", Moves, function()
        motionTimers:Cancel()
        motionTimers:After(Moves.STOP_AFTER, function()
            if motion.moving then motion.moving = false; ReposeAll() end
        end)
    end)
    -- Mounting, landing, a flight's end: how fast we really go now. (2026-11-10: landed from a
    -- flight path and standing, the pet walked: no stop came after the flight.)
    local function Resync()
        local now = Moves.Moving()
        if now ~= nil then motion.moving = now end
        ReposeAll()
    end
    -- Jumping: Blizzard's jump binding (a function hook, set once: idle while nothing shows a pet with you).
    if not motion.hooked and type(JumpOrAscendStart) == "function" then
        motion.hooked = true
        hooksecurefunc("JumpOrAscendStart", function() if motion.on then Moves:JumpAll() end end)
    end
    ns.Events:On("PLAYER_MOUNT_DISPLAY_CHANGED", Moves, Resync)
    ns.Events:On("PLAYER_CONTROL_GAINED", Moves, Resync)
    ns.Events:On("UPDATE_SHAPESHIFT_FORM", Moves, Resync)
end

------------------------------------------------------------------------------
-- The planner (2026-11-12, docs/REFACTOR.md): what a pet does, every rule of it in one place, as
-- plans a stage plays. A plan is a list of steps { id, seconds, pose }, played in turn, the last one
-- held. pose: held paused (or frozen) that many seconds in; keep: played as picked (the moves
-- editor's), not put back to rest; on: called as the step plays (a once-a-day moment counts as seen
-- only when it plays). A plan may also say the stage's mode after it (mode), that the pet is awake
-- now (wake), and why (for the log). Plans read the game and the saved data, and change nothing: no
-- frames, no timers, no state (the stage applies mode and wake as it plays one).
-- from: what a stage shows now, { mode, playing, last } (its `shown`). noMoments: a stage that leaves
-- the once-a-day moments (the sulk, playing dead, the wish's hop) to the card.
------------------------------------------------------------------------------
local Plan = {}
Moves.Plan = Plan
Moves.TRY_HOLD = 3 -- seconds a whole tried sleep or sit holds before it gets up

local function For(key, what) return Moves:For(key, what) end
local function HasTrait(key, id) return ns.Personality:Has(key, id) end

-- The steps given, in order, leaving out the nils and falses (moves the pet doesn't have).
local function List(...)
    local steps = {}
    for i = 1, select("#", ...) do
        local s = select(i, ...)
        if s then steps[#steps + 1] = s end
    end
    return steps
end

-- A one-off as a step, played as long as it lasts on this pet (else t); nil without one.
local function Once(key, id, t)
    if id then return { id, Moves:Length(key, id, t) } end
end

-- How long a lie-down plays before its sleep loop (sleepHold) takes over: sleepAt, but never past the
-- lie-down's own end. 2026-11-14 (the user: the cats "start laying down, then instantly stand up for 0.2s"):
-- their 99 plays 1.34 s and sleepAt was 1.4 (set by eye before lengths were measured), so the one-off
-- ended, the cat stood, and the loop blended in from standing. A frame early, the loop blends from lying.
Plan.LIE_MARGIN = 0.05
-- A lie-down the model follows with its own sleep loop (2026-11-16, the user: a cat's SleepDown (99) played
-- alone "stays asleep"): the M2's next animation. Then the loop isn't set at all: switching to it a frame
-- before the lie-down ended still showed the cat standing for a moment first. The step plays the lie-down
-- and says the loop shows after it (shows: what a put-back plays).
Moves.CHAINS = { [99] = 100 }
local function Chains(id, hold) return id ~= nil and hold ~= nil and Moves.CHAINS[id] == hold end
Plan.Chains = Chains
local function LieDown(key, id, at)
    local len = Moves:Length(key, id)
    at = at or Moves:Length(key, id, Moves.T.down)
    if len and at > len - Plan.LIE_MARGIN then at = math.max(0.1, len - Plan.LIE_MARGIN) end
    return at
end

-- Moves a moment earned the pet today, played once (2026-11-14, round 2: one list, char.owed, instead of
-- Moves reading each module's flags): "dead" (an egg with move = "dead": the three deaths), "joy" (a wish
-- come true: a happy hop, 2026-11-10), "sulk" (a dislike came up: its back turned). Owed for the day only.
function Moves:Owe(key, move)
    local o = ns.DB.char.owed
    o[key] = o[key] or {}
    o[key][move] = ns.Today()
end
function Moves:Owed(key, move)
    local o = key and ns.DB.char.owed[key]
    return o ~= nil and o[move] == ns.Today()
end
function Moves:Paid(key, move)
    local owed = ns.DB.char.owed
    local o = owed[key]
    if not o then return end
    o[move] = nil
    if next(o) == nil then owed[key] = nil end
end
-- (Yesterday's never played: gone at login.)
local function Forget()
    local today = ns.Today()
    for key, o in pairs(ns.DB.char.owed) do
        for move, day in pairs(o) do if day ~= today then o[move] = nil end end
        if next(o) == nil then ns.DB.char.owed[key] = nil end
    end
end

local function DeadToday(key) return Moves:Owed(key, "dead") end
local function WishJoy(key) return Moves:Owed(key, "joy") and For(key, "happy") end

-- The pose the pet takes on its own: "sleep", "sit", "dead" or "stand". woken: as if awake.
function Plan.Rest(key, t, noMoments, woken)
    local o = Moves.override -- (Dev/MovesProbe.lua: the moves editor stands it, /dp probe anim night)
    if o and o.rest then return o.rest end
    if not noMoments and DeadToday(key) and For(key, "dead") then return "dead" end
    if not (woken or awake[key]) then
        if ((o and o.night) or ns.Personality.IsNight(t or ns.Now())) and not HasTrait(key, "nattugle") and For(key, "sleep") then
            return "sleep"
        end
        -- Moving with you beats sitting (the user, 2026-11-10); sleep at night still wins.
        if Moves:MotionId(key) then return "stand" end
        -- Only a pet that can sit (canSit: the user's box in /dp probe moves, 2026-11-11).
        local sits = For(key, "canSit") and For(key, "sit")
        if HasTrait(key, "latsabb") and sits then return "sit" end
        -- Content for today: your pet sits once its day's bond is full (2026-11-10).
        if sits and ns.Pets:IsOwned(key) then
            local today, max = ns.Bond:Today(key)
            if today >= max then return "sit" end
        end
    end
    return "stand"
end
function Moves:Rest(key, t, noMoments) return Plan.Rest(key, t, noMoments) end

-- Standing first, at least t seconds and until a new model has loaded (the stage's load step: Moves.LOAD_MAX).
local function Standing(t) return { STAND, t, load = true } end
Plan.Standing = Standing

-- Into a pose and holding it (the last step is held). fresh: the pet was just put on the stage.
function Plan.Hold(key, mode, fresh)
    if mode == "sleep" then
        local id, at, hold = For(key, "sleep"), For(key, "sleepAt"), For(key, "sleepHold")
        -- Lying down: played (blended) up to sleepAt, then held there. 2026-11-10: blended, Dead
        -- (6) lies a pet down smoothly but then stands it up; sometimes it doesn't play at all,
        -- and the held pose still comes. Paused there, which needs the model loaded first
        -- (SLEEP_AFTER: a model still loading would stand it up again).
        if not hold then
            return { Standing(Moves.SLEEP_AFTER), { id, at or 0 }, { id, nil, at or 0 } }
        end
        -- A pet with a sleep loop of its own (sleepHold) is asleep already when its card opens
        -- (the user, 2026-11-11): a loop needs no timing. (Sleep starts only as a card opens: once
        -- woken, it stays awake.)
        if not fresh then return { { hold } } end
        -- ... but not just put on the stage (2026-11-11, the user: asleep on reopening, but "it
        -- quickly broke when swapping"): its model finishes loading in the engine and stands it up,
        -- with no call we can see (GetAnimation echoes what was set; IsLoaded said true at once). Set
        -- twice, the client played it as a one-off and got up. So a new pet stands while its model
        -- loads, as the lie-down sleepers do (SLEEP_AFTER), then sleeps; the same pet sleeps at once.
        -- (And now that it stands first, it lies down before the loop, as a pet with a lie-down of its
        -- own should: 2026-11-11, the user: "lacking the get up / down animations".)
        if Chains(id, hold) then return { Standing(Moves.SLEEP_AFTER), { id, shows = hold } } end
        return List(Standing(Moves.SLEEP_AFTER), id and id ~= hold and { id, LieDown(key, id, at) }, { hold })
    end
    if mode == "sit" then
        return List(Standing(Moves.SIT_AFTER), Once(key, For(key, "sitDown"), Moves.T.down), { For(key, "sit") })
    end
    if mode == "dead" then
        -- Lying still for a while: paused just before its fall ends, where it's measured
        -- (2026-11-11: a Death plays 1.4 to 2.7 s, then the pet stood up for the rest of T.dead).
        local id = For(key, "dead")
        local len = Moves:Length(key, id)
        local pose = len and math.max(0.1, len - 0.05) or nil
        return { Standing(Moves.SETTLE),
            { id, math.max(Moves.T.dead, (len or 0) + 1), pose, on = function() Moves:Paid(key, "dead") end },
            { STAND } }
    end
    -- Walking or running: only once the model has loaded. 2026-11-10: the client scales a
    -- model to its size as it loads, and a walking one is bigger, so a pet shown mid-walk
    -- came out at two thirds of its size (scale 13.4 instead of 19.5) until loaded again.
    local walk = Moves:MotionId(key)
    if walk then return { Standing(Moves.SETTLE), { walk } } end
    return { { STAND } }
end

-- A pet put on a stage: its pose (o.mode, else Rest), and first a one-off once the model has
-- loaded: a level-up's cheer (o.cheer: celebrated as the card opened, before the pet was posed: code
-- review 2026-11-10), which wakes it, or a wish come true. o.fresh: a new pet on the stage.
function Plan.Pose(key, o)
    local mode = o.mode or Plan.Rest(key, nil, o.noMoments)
    local plan = Plan.Hold(key, mode, o.fresh)
    local cheer = o.cheer and mode ~= "dead" and For(key, "cheer")
    local joy = not o.noMoments and not cheer and mode ~= "dead" and mode ~= "sleep" and WishJoy(key)
    if cheer then
        mode = Plan.Rest(key, nil, o.noMoments, true)
        plan = Plan.Hold(key, mode)
        plan.wake = true
    end
    -- First, once the model has loaded: a sulk (it turns its back and round again), then the one-off.
    local front = o.noMoments and {} or Plan.Sulk(key) or {}
    if cheer or joy then
        front[#front + 1] = { cheer or joy, Moves:Length(key, cheer or joy, cheer and Moves.T.cheer or Moves.T.happy),
            on = joy and function() Moves:Paid(key, "joy") end or nil }
    end
    if #front > 0 then
        table.insert(front, 1, Standing(Moves.SETTLE))
        for i = #front, 1, -1 do table.insert(plan, 1, front[i]) end
    end
    plan.mode, plan.why = mode, "pose " .. tostring(mode)
    return plan
end

-- A plan's last step, about to be held: back to rest as things are now (code review 2026-11-10: a
-- stop during the hop left it walking; after playing dead it never walked). The stage's mode and the
-- id to hold then; or, for a sitter that stopped moving meanwhile, a plan: it settles again.
function Plan.Settle(key, mode, id, noMoments)
    if mode == "dead" and Plan.Rest(key, nil, noMoments) == "stand" then mode = "stand" end
    if mode == "stand" and Plan.Rest(key, nil, noMoments) == "sit" then
        local plan = Plan.Hold(key, "sit")
        plan.mode, plan.why = "sit", "settles again"
        return "sit", nil, plan
    end
    if mode == "stand" then id = Moves:MotionId(key) or STAND end
    return mode, id
end

-- After a reaction: its pose, awake now (if it slept or sat). The mode, and the id it holds.
function Plan.Back(key, noMoments)
    local mode = Plan.Rest(key, nil, noMoments, true)
    local hold = Plan.Hold(key, mode)
    return mode, hold[#hold][1]
end

-- Sitting already, or sitting down (2026-11-10: clicked in its first seconds, still standing, it
-- "got up" for 1.4 s before the hop).
function Plan.Seated(key, playing)
    return playing == For(key, "sitDown") or playing == For(key, "sit")
end

-- A one-off, then back to its pose, awake.
local function Reaction(key, step, why, noMoments)
    local mode, back = Plan.Back(key, noMoments)
    local plan = List(step, { back })
    plan.mode, plan.wake, plan.why = mode, true, why
    return plan
end

-- A click on the pet (Cuddle.lua): wakes it up, gets it up, or a happy move (now and then its other
-- one; no happy move: none at all).
function Plan.Cuddle(key, from, noMoments)
    local happy, too = For(key, "happy"), For(key, "happyToo")
    if happy and too and ns.random() < Moves.HAPPY_TOO_CHANCE then happy = too end
    local mode, back = Plan.Back(key, noMoments)
    -- Up first only if it's sitting already (Seated).
    local up = from.mode == "sit" and Plan.Seated(key, from.playing) and For(key, "sitUp")
        or from.mode == "sleep" and For(key, "sleepUp")
    local plan = List(Once(key, up, Moves.T.up), Once(key, happy, Moves.T.happy), { back })
    plan.mode, plan.wake, plan.why = mode, true, "click"
    return plan
end

-- A bond level reached (BondTrack's celebration): its cheer; nil if it has none.
function Plan.Cheer(key, noMoments)
    local cheer = For(key, "cheer")
    if not cheer then return nil end
    return Reaction(key, Once(key, cheer, Moves.T.cheer), "cheer", noMoments)
end

-- A one-off reaction played once (Fight.lua: attack, cower); nil if the pet doesn't do it.
function Plan.Act(key, what, noMoments)
    local id = For(key, what)
    if not id then return nil end
    return Reaction(key, Once(key, id, Moves.T[what] or Moves.T.happy), what, noMoments)
end

-- Moving changed: a sitting pet gets up and goes with you, and sits again when you stop; a pet
-- resting standing (its last step held) takes the walk up. A plan; or nil and the id to play at once
-- in place of what plays (no new plan: the pose's timers run on); or nothing.
function Plan.Repose(key, from, noMoments)
    local mode = Plan.Rest(key, nil, noMoments)
    if from.mode == "sit" and mode == "stand" then -- (sitting, or about to: up and away)
        local plan = List(Plan.Seated(key, from.playing) and Once(key, For(key, "sitUp"), Moves.T.up), { STAND })
        plan.mode, plan.why = "stand", "up to go with you"
        return plan
    end
    if from.mode == "stand" and mode == "sit" and from.last then -- (stopped: it settles again)
        local plan = Plan.Hold(key, "sit")
        plan.mode, plan.why = "sit", "stopped: sits"
        return plan
    end
    if from.mode ~= "stand" or not from.last then return nil end
    local id = Moves:MotionId(key) or STAND
    if from.playing ~= id then return nil, id end
end

-- Taking off, in the air, landing (none of them: an empty list).
local function Airborne(key)
    local start, air = For(key, "jumpStart"), For(key, "jump")
    local startLen = start and Moves:Length(key, start, Moves.T.jumpStart) or 0
    return List(start and { start, startLen }, air and { air, math.max(0.1, Moves.JUMP_AIR - startLen) },
        Once(key, For(key, "jumpEnd"), Moves.T.jumpEnd))
end

-- You jumped: a pet with you that can jump does too, if it's only standing or walking (not
-- asleep, sitting, or in the middle of a reaction, a jump included); then as things are (standing,
-- walking or running). Swimming up isn't a jump, nor a press on a taxi. nil: it doesn't.
function Plan.Jump(key, from)
    if Truthy(IsSwimming and IsSwimming()) or Truthy(UnitOnTaxi("player")) then return nil end
    if not (key and Moves.WithYou(key) and For(key, "canJump")) then return nil end
    if from.mode ~= "stand" or not from.last then return nil end -- (in the air too: it lands first)
    local plan = Airborne(key)
    if #plan == 0 then return nil end
    plan[#plan + 1] = { STAND }
    plan.why = "jump"
    return plan
end

-- One part (the moves editor's ▶): it plays at once and stays (a lie-down paused at its point, a
-- loop looping, a one-off on its last frame).
local function Part(key, what)
    if what == "sleep" then
        local id, at, hold = For(key, "sleep"), For(key, "sleepAt") or 0, For(key, "sleepHold")
        if not id then return nil end
        if Chains(id, hold) then return { { id, shows = hold, keep = true } } end
        return { { id, hold and id ~= hold and LieDown(key, id, at) or at }, hold and { hold, keep = true } or { id, nil, at } }
    end
    local id = For(key, what)
    return id and { { id, keep = true } } or nil
end

-- The whole reaction in order (the moves editor's "Hele"), ending standing.
local function Whole(key, reaction)
    local plan
    if reaction:find("^sleep") then
        local id, at, hold = For(key, "sleep"), For(key, "sleepAt") or 0, For(key, "sleepHold")
        if Chains(id, hold) then -- (lying down into its loop, a while asleep, then up)
            plan = List({ id, Moves:Length(key, id, Moves.T.down) + Moves.TRY_HOLD }, Once(key, For(key, "sleepUp"), Moves.T.up))
            plan[#plan + 1] = { STAND, keep = true }
            return plan
        end
        plan = List(id and { id, hold and id ~= hold and LieDown(key, id, at) or at },
            hold and { hold, Moves.TRY_HOLD } or id and { id, Moves.TRY_HOLD, at },
            Once(key, For(key, "sleepUp"), Moves.T.up))
    elseif reaction:find("^sit") then
        local sit = For(key, "sit")
        plan = List(Once(key, For(key, "sitDown"), Moves.T.down), sit and { sit, Moves.TRY_HOLD },
            Once(key, For(key, "sitUp"), Moves.T.up))
    elseif reaction:find("^jump") then -- (as when you jump: take off, in the air, land)
        plan = Airborne(key)
    else
        local id = For(key, reaction)
        plan = List(id and { id, reaction == "dead" and Moves.T.dead or Moves:Length(key, id, Moves.T.cheer) })
    end
    plan[#plan + 1] = { STAND, keep = true }
    return plan
end

-- The moves editor's try: "stand", one part, or (whole) the reaction it belongs to. nil: nothing to play.
function Plan.Try(key, what, whole)
    local plan = what == "stand" and { { STAND, keep = true } } or whole and Whole(key, what) or Part(key, what)
    if not (plan and plan[1]) then return nil end
    plan.mode, plan.why = "stand", "try " .. tostring(what)
    return plan
end

-- Turning to face `yaw` (radians from where it faced as the turn began: pi its back to you, 0 facing
-- you again) over Moves.TURN, walking as it goes (a pet without a walk turns standing). The stage turns
-- the actor (step.yaw).
function Plan.Turn(key, yaw, on)
    return { For(key, "walk") or STAND, Moves.TURN, yaw = yaw, on = on }
end

-- Sulking (2026-11-10): the first time you open its card on a day a dislike of its came up
-- (Quirks owes it: "sulk"), the pet turns its back for a few seconds, a grey cloud over it (mood), and
-- turns round again (2026-11-13: walking, not at once). The steps, or false; seen once it starts turning.
function Plan.Sulk(key)
    if not Moves:Owed(key, "sulk") then return false end
    return {
        Plan.Turn(key, math.pi, function() Moves:Paid(key, "sulk") end),
        { STAND, Moves.SULK, mood = "sulk" },
        Plan.Turn(key, 0),
    }
end

------------------------------------------------------------------------------
-- The stage: plays plans on a model actor
------------------------------------------------------------------------------
-- A stage: opts.actor() the model actor, opts.scene() its model scene (for the lift's scene id),
-- opts.fx() where a mood's particles go ({ parent, level, anchor }: Fx:Emit's; nil: none), opts.refresh()
-- redraws around it (a woken pet's Zzz go).
function Moves.NewStage(name, opts)
    local shown = { reposed = 0 } -- what this stage shows: its pet, its pose
    -- Its timers, all cancelled when a new plan starts or the stage stops showing a pet.
    local timers = ns.Timers()

    local stage = setmetatable({ name = name, shown = shown }, { __index = Moves })

    local function Actor() return opts.actor() end
    stage.ActorNow = Actor -- (Dev/PlaceEditor.lua)
    -- The once-a-day moments (the sulk, playing dead, the wish's hop) are the card's: a stage with
    -- moments = false (the pet frame) leaves them to it (code review 2026-11-11: else the frame
    -- spent them hours later, at its next pose).
    local moments = opts.moments ~= false
    -- opts.rest(key): a pose the stage's own (the pet frame's: asleep while you're AFK), or nil for Plan.Rest's.
    local function Rest(key) return opts.rest and opts.rest(key) or Plan.Rest(key, nil, not moments) end

    local Play, Lift, Run, Turn, Mood

    ---------------------------------------------------------------------------
    -- A new model loading, and its scale (Moves.LOAD_MAX's comment). load: the model being loaded
    -- ({ at, notReady }), nil once it has (or the wait ran out). setAt: when the model now on was set (nil:
    -- not seen). confirmed: a real signal said this model has loaded (only then is its scale worth keeping).
    -- waiting: the load step's go-on, once the model has loaded and the warm-up is done. pinned: the scale it
    -- had standing, { scale, model, scene }.
    -- 2026-11-16, the second log: the size callback is NOT a load. It fired the moment a model was set (0.00 s,
    -- 36 swaps of 38), the loaded callback 0.01 to 0.2 s later, so the scale was pinned from a model not loaded
    -- yet, and Keep fought the engine's real one ("scaled 13.83, kept at 19.48"): half the pets came out too
    -- big, too small, too high or too low. Only the loaded callback (or IsGeoReady going true) counts now.
    local loadT, warmT = ns.Timers(), ns.Timers()
    local load, waiting, pinned, warming, setAt, confirmed
    local readyAt = 0 -- (when the model last loaded or warmed up: AFTER_LOAD runs from it)
    local function Ready() return load == nil and not warming end
    local function GoOn()
        if not (Ready() and waiting) then return end
        local go = waiting
        waiting = nil
        go()
    end

    -- The scene the actor is in now (its own scale comes with it: retail's ApplyFromModelSceneActorInfo).
    local function SceneID()
        local ok, id = Call(opts.scene() or {}, "GetModelSceneID")
        return ok and id or nil
    end
    -- What the actor says of itself (research, 2026-11-16: cats sharing one model stood at different heights,
    -- whelps too high and too low, a hare too big): logged at each load and pin, only with the log on.
    local function Describe(when)
        if not ns.Debug.enabled then return end
        local actor = Actor()
        if not actor then return end
        local function V(m) local r = { Call(actor, m) }; if not r[1] then return "-" end
            for i = 2, #r do r[i] = type(r[i]) == "number" and ("%.3f"):format(r[i]) or tostring(r[i]) end
            return table.concat(r, ",", 2)
        end
        ns.Log("Moves", "%s %s %s: scene %s, model %s, pos %s, scale %s (requested %s, aggressive %s), center %s, box %s, max %s",
            name, tostring(shown.key or shown.still), when, tostring(SceneID()), V("GetModelFileID"), V("GetPosition"), V("GetScale"),
            V("GetRequestedScale"), V("GetNormalizedScaleAggressiveness"), V("IsUsingCenterForOrigin"),
            V("GetActiveBoundingBox"), V("GetMaxBoundingBox"))
    end
    -- The pet shown, with its moves on (shown.key) or off (shown.still).
    local function Shown() return shown.key or shown.still end

    -- Placed by its feet in its scene (Moves.FRAMING's comment), at once: true if it was. placed: { key, scene,
    -- scale, z }; pinned keeps its scale against the engine's (a model loading scales it again).
    local placed
    local function Place(key)
        local actor, scene = Actor(), SceneID()
        local box = Moves.FRAMING and Moves:Box(ns.Pets:SpeciesOfKey(key)) or nil
        local fit, from
        if box then fit, from = Moves:FitFor(name, box, scene) end
        local scale, z
        if box and fit then scale, z = Moves.Fit(box, fit) end
        if not (actor and fit and scale) then placed = nil; return false end
        local okP, x, y, now = Call(actor, "GetPosition")
        local okS, was = Call(actor, "GetScale")
        Call(actor, "SetUseCenterForOrigin", false, false, false)
        if not (okS and was == scale) then Call(actor, "SetScale", scale) end
        if okP and now ~= z then Call(actor, "SetPosition", x, y, z) end
        local p = placed
        if not (p and p.key == key and p.scene == scene and p.scale == scale and p.z == z) then
            ns.Log("Moves", "%s %s: placed in scene %s, scale %.2f at z %.2f (floor %.2f, size %.2f: %s)", name, key,
                tostring(scene), scale, z, fit.floor, fit.size, tostring(from))
        end
        placed = { key = key, scene = scene, scale = scale, z = z }
        pinned = { scale = scale, key = key, scene = scene }
        return true
    end

    -- Standing now, its model loaded: its box measured, if Data/PetBoxes.lua doesn't have it (then placed),
    -- else its scale worked out standing (the box of the pose it plays: retail's UpdateScale) and kept, for
    -- this pet in this scene. Only for a model known to have loaded: else it was the box of nothing yet.
    local function Pin()
        local actor, key = Actor(), Shown()
        if not (actor and key) then return end
        local sid = ns.Pets:SpeciesOfKey(key)
        -- (once the load is over, by its signal or the wait: on the card the loaded callback seldom comes)
        if Moves.FRAMING and sid and not (ns.PetBoxes and ns.PetBoxes[sid]) and not load then
            local okB, x1, y1, z1, x2, y2, z2 = Call(actor, "GetActiveBoundingBox")
            if okB and type(z1) == "number" and z2 - z1 > 1e-3 then
                measured[sid] = { scene = SceneID(), low = z1, high = z2, wide = math.max(x2 - x1, y2 - y1) }
                ns.Log("Moves", "%s %s: its box measured standing, %.3f to %.3f, %.3f wide", name, key, z1, z2,
                    math.max(x2 - x1, y2 - y1))
            end
        end
        if Place(key) then return end
        pinned = nil
        if not confirmed then return end
        if Call(actor, "MarkScaleDirty") then Call(actor, "UpdateScale") end
        local okS, s = Call(actor, "GetScale")
        if not (okS and type(s) == "number") then return end
        pinned = { scale = s, key = key, scene = SceneID() }
        ns.Log("Moves", "%s %s: scale %.2f, standing", name, key, s)
        Describe("pinned")
    end
    -- Scaled again (a size callback, or before a move): back to the scale it had standing, for the same pet
    -- in the same scene. (2026-11-16, the first log: the card moving to the next pet's scene scaled it there,
    -- the old model still on, and Keep took that back: another scene, another scale, never kept.) While a
    -- model loads, only a placed pet's: its scale doesn't hang on the load.
    local function Keep()
        local p, actor = pinned, Actor()
        if not (p and actor) or (load and not placed) then return end
        if p.key ~= Shown() or SceneID() ~= p.scene then pinned = nil; return end
        local okS, s = Call(actor, "GetScale")
        if okS and type(s) == "number" and math.abs(s - p.scale) > 1e-3 then
            Call(actor, "SetScale", p.scale)
            ns.Log("Moves", "%s %s: scaled %.2f, kept at %.2f", name, tostring(p.key), s, p.scale)
        end
    end

    -- A signal about the model (how: "loaded callback", "geo ready", or "no signal": the wait ran out).
    local function Loaded(how)
        local real = how ~= "no signal"
        if real and confirmed then return end -- (said already)
        if not (load or (real and setAt)) then return end
        local was = load
        ns.Log("Moves", "%s %s: model loaded %.2f s after it was set (%s)%s", name, tostring(shown.key),
            setAt and GetTime() - setAt or -1, how, was and "" or ", after the wait")
        if real then confirmed = true end
        load = nil
        loadT:Cancel()
        readyAt = GetTime()
        local key = Shown()
        if key then Lift(key) end
        if real then Describe("loaded") end
        -- Standing now (a pose with no wait: by day): measured and placed a moment later (Pin).
        if key and (shown.playing == STAND or shown.playing == nil) and not waiting then
            loadT:After(Moves.AFTER_LOAD, function()
                if Shown() == key and (shown.playing == STAND or shown.playing == nil) then Pin() end
            end)
        end
        if was and waiting then return GoOn() end
        if not real then return end
        -- Loaded after the pet was posed (the wait ran out, or a model loaded anew under a held pose): the
        -- engine stands it up and scales it to what it plays. Standing, its scale, then its pose again.
        -- (also a walk with you that waited for the load: stage:Repose)
        if not key or shown.reposed >= Moves.REPOSE then return end
        if not (shown.playing and shown.playing ~= STAND) and not Moves:MotionId(key) then return end
        shown.reposed = shown.reposed + 1
        local mode, id, pose, last = shown.mode, shown.playing, shown.pose, shown.last
        if not last then timers:Cancel() end -- (mid-plan: posed anew below)
        Play(STAND) -- (standing as it scales: the next frame's UpdateScale)
        timers:After(Moves.AFTER_LOAD, function()
            if shown.key ~= key then return end
            Pin()
            if last then -- (the step that stays, put back; standing: as things are now, a walk stopped meanwhile)
                if not pose then
                    local again
                    mode, id, again = Plan.Settle(key, shown.mode or mode, id, not moments)
                    if again then return Run(key, again) end
                    shown.mode = mode
                end
                return Play(id, true, pose)
            end
            local plan = Plan.Pose(key, { mode = mode, noMoments = not moments })
            plan.why = "loaded late: " .. tostring(mode) .. " again"
            Run(key, plan)
        end)
    end

    -- A model was set on the actor: watched until it has loaded (LOAD_MAX at most).
    local function BeginLoad()
        loadT:Cancel()
        confirmed = false
        if not placed then pinned = nil end -- (a placed pet's scale holds through a load; another pet's Place replaces it)
        setAt = GetTime()
        local l = { at = setAt }
        load = l
        local n = math.max(1, math.floor(Moves.LOAD_MAX / Moves.LOAD_POLL + 0.5))
        loadT:Every(Moves.LOAD_POLL, n, function(i)
            if load ~= l then return loadT:Cancel() end
            -- (IsGeoReady counts only once seen false: right after a swap it may still answer for the old one)
            local okG, geo = Call(Actor() or {}, "IsGeoReady")
            if okG and geo == false then l.notReady = true
            elseif okG and geo and l.notReady then return Loaded("geo ready") end
            if i >= n then Loaded("no signal") end
        end)
    end

    -- The pet's moves, played first on a hidden model of the same pet (Moves.WARM_STEP's comment). need:
    -- the ids the pose plays next (the load step waits for these); then the pet's other moves.
    local warm = {}
    local function StopWarm()
        warmT:Cancel()
        warming = nil
        if warm.model and warm.display then warm.model:ClearModel(); warm.model:Hide() end
        warm.display = nil
    end
    local function Warm(key, need)
        warmT:Cancel()
        warming = nil
        local sid = ns.Pets:SpeciesOfKey(key)
        local display = sid and select(12, C_PetJournal.GetPetInfoBySpeciesID(sid))
        if not display then return end
        local ids, seen, gate = {}, { [STAND] = true }, 0
        local function Add(id) if id and not seen[id] then seen[id] = true; ids[#ids + 1] = id end end
        for _, id in ipairs(need) do Add(id) end
        gate = #ids
        for _, what in ipairs(Moves.WARM) do Add(Moves:For(key, what)) end
        if #ids == 0 then return end
        if not warm.model then
            local ok, m = pcall(CreateFrame, "PlayerModel", nil, UIParent)
            if not (ok and m) then return end
            m:SetSize(1, 1)
            m:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, 0)
            m:SetAlpha(0)
            m:SetScript("OnModelLoaded", function() if warm.go then warm.go() end end)
            warm.model = m
        end
        local m = warm.model
        if gate > 0 then warming = true end
        local started = false
        local function Go()
            if started then return end
            started = true
            warm.go = nil
            warmT:Every(Moves.WARM_STEP, #ids, function(i)
                m:SetAnimation(ids[i])
                if i == gate then
                    warming = nil
                    readyAt = GetTime()
                    ns.Log("Moves", "%s %s: warmed %d moves", name, key, gate)
                    GoOn()
                end
            end)
        end
        m:Show()
        if warm.display == display then return Go() end -- (loaded already: the same pet again)
        warm.display, warm.go = display, Go
        m:SetDisplayInfo(display)
        warmT:After(Moves.WARM_MAX, Go) -- (if it never says it has loaded)
    end

    -- The load step (Plan.Standing): s[2] seconds at least, and until the model has loaded and the moves
    -- it plays next are warm, AFTER_LOAD after that; then its scale is pinned, standing.
    local function LoadStep(s, nextStep)
        local started = GetTime()
        waiting = function()
            local due = math.max(started + (s[2] or 0), readyAt + Moves.AFTER_LOAD) - GetTime()
            timers:After(math.max(0, due), function() Pin(); nextStep() end)
        end
        GoOn()
    end

    -- 2026-11-10: about one time in three a held pose stood up again by itself
    -- right away, and GetAnimation (it only echoes what was set) can't tell. So
    -- we watch the actor: anything else that sets an animation or loads a model
    -- while a pose is held is logged, and the pose put back (after a model, once
    -- it has loaded: Loaded), at most Moves.REPOSE times per pet shown.
    local function Outside(what, arg)
        ns.Log("Moves", "%s %s: %s(%s) from outside, %.2f s into our %s%s", name, tostring(shown.key), what, tostring(arg),
            shown.since and GetTime() - shown.since or -1, tostring(shown.playing), shown.pose and " (held)" or "")
        shown.touched = true -- (a refresh may put our pose back now: Update)
        if what ~= "SetAnimation" then
            if shown.key then -- (its height again in a moment, whether or not the load says so)
                local key = shown.key
                timers:After(Moves.SETTLE, function() if shown.key == key then Lift(key) end end)
            end
            return BeginLoad()
        end
        if not shown.pose or shown.reposed >= Moves.REPOSE then return end
        shown.reposed = shown.reposed + 1
        local id, pose = shown.playing, shown.pose
        timers:After(0, function()
            if shown.playing == id and shown.pose == pose then Play(id, true, pose) end
        end)
    end
    -- Watched once per actor. Its two callbacks (retail's mixin calls them: a model loaded, scaled again)
    -- only where nobody has set one (the user, 2026-11-16: on Blizzard's card actor too, then); a hook on
    -- its OnModelLoaded never fired (2026-11-11), the method seems bound before an addon can hook it.
    -- true: watched just now (a model set before this went unseen).
    local function Watch(actor)
        if hooked[actor] then return false end
        hooked[actor] = true
        for _, m in ipairs({ "SetAnimation", "SetModelByCreatureDisplayID", "SetModelByFileID" }) do
            local ok, fn = pcall(function() return actor[m] end)
            if ok and type(fn) == "function" then
                hooksecurefunc(actor, m, function(_, arg) if not own then Outside(m, arg) end end)
            end
        end
        local okL, onLoaded = Call(actor, "GetOnModelLoadedCallback")
        if okL and onLoaded == nil then
            Call(actor, "SetOnModelLoadedCallback", function() Loaded("loaded callback") end)
        end
        local okS, onSize = Call(actor, "GetOnSizeChangedCallback")
        if okS and onSize == nil then
            Call(actor, "SetOnSizeChangedCallback", function() Keep() end) -- (not a load: Loaded's comment)
        end
        ns.Log("Moves", "%s: watching its actor (loaded callback %s, size callback %s)", name,
            okL and (onLoaded == nil and "ours" or "Blizzard's") or "none", okS and (onSize == nil and "ours" or "Blizzard's") or "none")
        return true
    end
    -- A stage of our own just set a model (Pets:LoadModel): watched from now if it wasn't.
    function stage:Loading()
        local actor = Actor()
        if actor and Watch(actor) then BeginLoad() end
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
        local function Pause()
            if shown.playing ~= id or shown.pose ~= pose then return end
            local ok = Call(actor, "SetPaused", true)
            shown.paused = ok or nil
            ns.Log("Moves", "%s %s: %d paused %.2f s in: %s", name, tostring(shown.key), id, pose, ok and "ok" or "failed")
        end
        local wait = pose - playingFor
        if wait <= 0.02 then Pause() else timers:After(wait, Pause) end
    end

    Play = function(id, again, pose)
        local actor = Actor()
        if not actor then return end
        Watch(actor)
        Unpause(actor)
        Keep() -- (scaled to another pose since: as it was standing)
        if pose and Has(actor, "SetPaused") then return PlayPaused(actor, id, pose) end
        shown.playing, shown.pose = id, pose
        shown.since = GetTime()
        shown.touched = nil
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
        -- (in a fight, the pet frame's moves are each a plan line already; their plays, a cower's 4 and 0 every
        -- second, were half the log's ring, 2026-11-15)
        if not (ok and name == "frame" and ns.Fight:Joined()) then
            ns.Log("Moves", "%s %s: play %d%s%s%s", name, tostring(shown.key), id, pose and (" at %.2f"):format(pose) or "",
                again and " (again)" or "", ok and "" or " REFUSED")
        end
        timers:After(Moves.RECHECK, function()
            if shown.playing ~= id then return end
            local now = Actor()
            local got, at = Call(now or actor, "GetAnimation")
            local reset = now ~= actor or (got and at ~= id)
            if reset then
                ns.Log("Moves", "%s %s: %d reads %s after %.1f s%s", name, tostring(shown.key), id,
                    got and tostring(at) or "?", Moves.RECHECK, now ~= actor and " (a new actor)" or "")
            end
            if reset and not again then Play(id, true, pose) end
        end)
    end

    -- Steps { id, seconds, pose }: each in turn; the last one stays. Replaces any running.
    function stage:Sequence(steps, why)
        if ns.Debug.enabled then -- (the steps' text only for the log: ns.Log's arguments are built even when it's off)
            local parts = {}
            for _, s in ipairs(steps) do
                parts[#parts + 1] = tostring(s[1]) .. (s[2] and ("/%.1fs"):format(s[2]) or "") .. (s[3] and "p" or "")
            end
            ns.Log("Moves", "%s %s: %s [%s] mode %s", name, tostring(shown.key), why or "steps", table.concat(parts, " > "),
                tostring(shown.mode))
        end
        timers:Cancel()
        waiting = nil
        shown.reposed = 0
        local function Step(i)
            local s = steps[i]
            if not s then return end
            shown.last = i == #steps -- (a refresh puts back only the step that stays)
            if s.on then s.on() end -- (a once-a-day moment counts as seen only when it plays)
            local id = s[1]
            if shown.last and not s[3] and not s.keep then -- (keep: the moves editor's, played as picked)
                local mode, again
                mode, id, again = Plan.Settle(shown.key, shown.mode, id, not moments)
                if again then return Run(shown.key, again) end
                shown.mode = mode
            end
            Play(id, nil, s[3])
            if s.shows then shown.playing = s.shows end -- (the loop the model goes on into: what's put back)
            if s.yaw then Turn(s.yaw, s[2]) end
            if s.mood then Mood(s.mood, (s[2] or 0) + Moves.TURN) end
            if s.load and not shown.last then return LoadStep(s, function() Step(i + 1) end) end
            if s[2] then timers:After(s[2], function() Step(i + 1) end) end
        end
        Step(1)
    end

    -- A plan played: the pet awake now and the stage's mode as it says, then its steps.
    Run = function(key, plan)
        if not plan then return end
        -- Its back still turned (a click, a cheer, another pose for it): it turns round first.
        if shown.sulk then table.insert(plan, 1, Plan.Turn(key, 0)) end
        if plan.wake then awake[key] = true end
        if plan.mode then shown.mode = plan.mode end
        stage:Sequence(plan, plan.why)
    end

    -- Moving changed (Plan.Repose).
    function stage:Repose()
        local key = shown.key
        if not key then return end
        local plan, id = Plan.Repose(key, shown, not moments)
        if plan then return Run(key, plan) end
        -- (not while its model loads: walking then, it came out at two thirds of its size, 2026-11-10;
        -- it goes with you once loaded: Loaded)
        if id and not load then Play(id) end
    end

    -- You jumped (Plan.Jump).
    function stage:Jump()
        Run(shown.key, Plan.Jump(shown.key, shown))
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
        local scene = opts.scene()
        local ok, id = Call(scene or {}, "GetModelSceneID")
        if ok and id then return "scene " .. tostring(id) end
        return key -- (no scene ids: by pet)
    end
    Lift = function(key)
        if Place(key) then return end -- (placed by its feet in its scene: FRAMING)
        local actor = Actor()
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
        timers:After(Moves.SETTLE, function()
            if shown.key == key then Lift(key) end
        end)
    end
    stage.Lift = Lift

    -- The card's pet at its own height again, then lifted as For says now (the lift editor).
    function stage:Relift()
        local key = shown.key or shown.still
        if key then Lift(key) end
    end

    -- A mood over the pet (Plan.Sulk's step.mood), on the stage's own layer (Fx), for `secs`.
    Mood = function(kind, secs)
        local fx, make = opts.fx and opts.fx(), Moves.MOOD[kind]
        if not (fx and make and ns.Fx) then return end
        ns.Fx:Emit({ parent = fx.parent, level = fx.level, tag = "mood", anchor = fx.anchor }, make(secs))
    end
    local function StopMood()
        local fx = opts.fx and opts.fx()
        if fx and fx.parent and ns.Fx then ns.Fx:Stop(fx.parent, "mood") end
    end

    -- Turning (step.yaw: Plan.Turn), eased, in Moves.TURN_STEPS steps on the stage's timers. shown.sulk:
    -- the actor, the yaw it faced first, and how far round it is now; gone once it faces you again.
    -- ModelSceneActor:SetYaw is unverified on Forever: without GetYaw it only walks on the spot.
    Turn = function(to, secs)
        local b = shown.sulk
        if not b then
            if to == 0 then return end
            local actor = Actor()
            local ok, yaw = Call(actor or {}, "GetYaw")
            if not (ok and type(yaw) == "number") then return ns.Log("Moves", "%s: no GetYaw, no turn", name) end
            b = { actor = actor, yaw = yaw, off = 0 }
            shown.sulk = b
        end
        -- By the clock, not by the count: at a low frame rate the steps come late, and the turn still
        -- ends on time (with fewer steps), before the step after it.
        local from, start = b.off, GetTime()
        local function Tick()
            local t = secs and secs > 0 and math.min(1, (GetTime() - start) / secs) or 1
            b.off = t >= 1 and to or from + (to - from) * (1 - math.cos(math.pi * t)) / 2 -- (eased in and out)
            Call(b.actor, "SetYaw", b.yaw + b.off)
            if t < 1 then return timers:After(secs / math.max(1, Moves.TURN_STEPS), Tick) end
            if to == 0 and shown.sulk == b then shown.sulk = nil; StopMood() end
        end
        ns.Log("Moves", "%s %s: turns to %.2f", name, tostring(shown.key), to)
        if not secs or secs <= 0 then return Tick() end
        timers:After(secs / math.max(1, Moves.TURN_STEPS), Tick)
    end

    -- Facing you again at once (another pet, the card closing), its mood gone.
    local function UnSulk()
        StopMood()
        local b = shown.sulk
        if not b then return end
        shown.sulk = nil
        Call(b.actor, "SetYaw", b.yaw)
    end

    -- A card widget (the card's widgets (ns.Card)): the pet's pose, once per pet shown.
    function stage:Update(card, key)
        -- The pet's moves turned off (Settings: cardMoves): it just stands, on its shadow. Only its pose
        -- stops: its model's load and where it's placed go on (2026-11-16: the full stop wiped them, and
        -- /dp probe place found no pet anywhere). shown.still: the pet it shows so.
        if key and not ns.Settings:On("cardMoves") then
            local was = shown.key or shown.playing
            self.want = nil
            Moves:FollowAll()
            UnSulk()
            timers:Cancel()
            waiting = nil
            local actor = Actor()
            if actor then Unpause(actor) end
            shown.key, shown.mode, shown.pose, shown.last, shown.still = nil, nil, nil, nil, key
            if was then Play(STAND) end -- (out of a held pose, once)
            shown.playing = nil
            Lift(key)
            return
        end
        shown.still = nil
        self.want = key -- (Moves:FollowAll: which pets the stages show)
        Moves:FollowAll()
        if not key then
            UnSulk()
            local actor = Actor()
            if actor then Unpause(actor) end -- (a paused actor would stay so for Blizzard's next pet)
            -- (nothing held either: a model loading on a closed card isn't posed again)
            shown.key, shown.mode, shown.playing, shown.pose, shown.last, shown.still = nil, nil, nil, nil, nil, nil
            timers:Cancel()
            waiting, load, pinned, confirmed, setAt, placed = nil, nil, nil, nil, nil, nil
            loadT:Cancel()
            StopWarm()
            return
        end
        local mode = Rest(key)
        if key == shown.key and mode == shown.mode then
            -- The same pet refreshed: Blizzard may have stood the model up again; put back the
            -- step that stays. Not a one-off (a hop, a cheer, the lie-down): it would start over
            -- on every guildmate's BOND message (code review 2026-11-10).
            -- Paused where it lies: nothing to put back. (Played again, the client ignored the
            -- Dead it was already on, so unpaused it got up, and the pause caught it standing: 2026-11-10.)
            if shown.paused then return end
            -- Only if something else has set the actor since: played again, the client starts the move
            -- over (2026-11-12: refreshed by every companion nearby, the frame's sleeping pet lay down again
            -- every 20 s), and a loop set again plays as a one-off and the pet gets up (2026-11-11). On the
            -- card a frozen pose (held at an offset) is put back anyway: Blizzard stood it up unseen now and
            -- then (2026-11-10). (Until 2026-11-16 the card's loops were set again on every refresh, a
            -- guildmate's BOND message: one way the user saw pets "exit their sleep after a second or two".
            -- What stood them up unseen was mostly a model loading late: Loaded puts them back now.)
            if shown.playing and shown.last and (shown.touched or (shown.pose and not opts.private)) then
                ns.Log("Moves", "%s %s: refresh, %s again", name, key, tostring(shown.playing))
                Play(shown.playing, true, shown.pose)
            end
            return
        end
        -- Why this pose (2026-11-11, the user: "none of them seem to be sleeping, but there's Zzz").
        if ns.Debug.enabled then
            local o = Moves.override
            ns.Log("Moves", "%s %s: pose %s (was %s %s; awake %s, night %s, editing %s, sleep %s/%s, hold %s)", name, key,
                mode, tostring(shown.key), tostring(shown.mode), tostring(awake[key] or false),
                tostring(ns.Personality.IsNight(ns.Now()) or (o and o.night) or false), tostring(o and o.rest ~= nil or false),
                tostring(Moves:For(key, "sleep")), tostring(Moves:For(key, "sleepAt")), tostring(Moves:For(key, "sleepHold")))
        end
        if key ~= shown.key then UnSulk() end -- (the same pet in another pose turns round first: Run)
        local fresh = key ~= shown.key
        local plan = Plan.Pose(key, { mode = mode, fresh = fresh, cheer = shown.cheerFor == key, noMoments = not moments })
        if fresh then -- (what it plays after standing, warm before it does: Warm)
            local need = {}
            for _, st in ipairs(plan) do if st[1] ~= STAND then need[#need + 1] = st[1] end end
            Warm(key, need)
        end
        shown.key, shown.cheerFor = key, nil
        Run(key, plan)
        Lift(key)     -- at once (2026-11-10: a moment later read as a jump) ...
        LiftSoon(key) -- ... and again if the model, done loading, was put back
    end

    -- A click on the pet (Cuddle.lua, Plan.Cuddle).
    function stage:Cuddle(key)
        if key ~= shown.key then return end
        local was = shown.mode
        -- A click while it sulks: it turns round to you (Run), then its happy move, standing (not as
        -- from the sleep or sit it will take after the sulk). Forgiven: the sulk is spent anyway.
        Run(key, Plan.Cuddle(key, shown.sulk and { mode = "stand" } or shown, not moments))
        -- Awake now on every stage that shows it (the frame wakes with the card's click).
        for _, s in ipairs(Moves.stages) do if s ~= stage and s.shown.key == key then s:Update(nil, key) end end
        -- Woken up: its Zzz go (Decor reads the pose; the card's refresh leaves the hop playing).
        if was == "sleep" and opts.refresh then opts.refresh() end
    end

    -- A bond level reached (BondTrack's celebration): its cheer, if it has one.
    function stage:Cheer(key)
        if key ~= shown.key then shown.cheerFor = key; return end -- (posed next: Update plays it)
        Run(key, Plan.Cheer(key, not moments))
    end

    -- A one-off reaction played once, then back to its pose (Fight.lua: attack, cower). false: the pet
    -- isn't on this stage, or doesn't do it.
    function stage:Act(key, what)
        if key ~= shown.key then return false end
        local plan = Plan.Act(key, what, not moments)
        if not plan then return false end
        Run(key, plan)
        return true
    end

    -- whole: the whole reaction the part belongs to; else just the part.
    function stage:Try(key, what, whole)
        if key ~= shown.key then return end
        local plan = Plan.Try(key, what, whole)
        if not plan then return end
        -- Standing first, in the same moment: the client doesn't start over the one it's on.
        Play(STAND)
        ns.Log("Moves", "try %s%s on %s", what, whole and " (whole)" or "", key)
        Run(key, plan)
    end

    -- The journal closing or our pages covering the card: stop, and start over next time.
    function stage:Stop()
        self:Update(nil, nil)
    end

    Moves.stages[#Moves.stages + 1] = stage
    return stage
end

-- The journal's pet card.
Moves.card = Moves.NewStage("card", {
    actor = function() return Moves:Actor() end,
    scene = function() return PetJournalPetCard and rawget(PetJournalPetCard, "modelScene") end,
    -- The card's own layer, over the pet, under our side pages (the user, 2026-11-12), like Cuddle's.
    fx = function()
        local card = ns.JournalUI and ns.JournalUI:Card()
        local c, panel = rawget(_G, "PetJournalPetCard"), card and card.panel
        if not (c and panel) then return nil end
        return { parent = c, level = c:GetFrameLevel() + 20, anchor = { panel, "TOP", 0, 175 } }
    end,
    refresh = function() if ns.JournalUI then ns.JournalUI:Refresh() end end,
})
for _, m in ipairs({ "Update", "Sequence", "Cuddle", "Try", "Stop", "Relift" }) do
    Moves[m] = function(_, ...) return Moves.card[m](Moves.card, ...) end
end
function Moves.Lift(key) return Moves.card.Lift(key) end

-- A bond level reached (BondTrack's celebration): its cheer, on every stage (those not showing it
-- play it when they next do).
function Moves:Cheer(key)
    for _, s in ipairs(self.stages) do s:Cheer(key) end
end

-- Another pet made the one kept out (or auto-summon off) while a stage shows one.
ns.Bus:On("ACTIVE_PET", function() Moves:FollowAll() end)
ns.Start("login", function() Forget() end) -- (owed moves from before today: gone)
