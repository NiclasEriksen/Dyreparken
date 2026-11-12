local _, ns = ...

-- The research probes for the pet on the card (development only, never
-- packaged: #@do-not-package@ in the TOC). They extend ns.Moves.
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
-- And the editors' hook: while /dp probe lift or moves is open, or /dp probe
-- anim night is on, Moves.override (which a release never sets) puts their
-- picks first (Moves:For), stands the pet (Moves:Rest) or makes it night.
local Moves = ns.Moves

-- A method call that may not exist (a missing method, or our harness's
-- strict frames, throw on the lookup itself): ok, results.
local function Call(obj, method, ...)
    local args = { ... }
    return pcall(function() return obj[method](obj, unpack(args)) end)
end
local function Has(obj, method)
    local ok, fn = pcall(function() return obj[method] end)
    return ok and type(fn) == "function"
end

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
-- The editors' hook. Moves.override = { For(sid, what), rest, night } while
-- anything here is on, else nil: the release code only asks whether it's set.
------------------------------------------------------------------------------
local OVERRIDE = {}

-- A pick (false: none), or nil when the editors have none for it.
function OVERRIDE.For(sid, what)
    -- While /dp probe lift is open: its picks (DyreparkenDB.liftPicks) go first.
    if what == "lift" and Moves.liftEditing then
        local pick = ns.DB.global.liftPicks[sid]
        if pick ~= nil then return pick ~= 0 and pick or false end
    end
    -- While /dp probe moves is open: its picks (DyreparkenDB.movePicks) go first.
    if Moves.movesEditing then
        local picks = ns.DB.global.movePicks[sid]
        if picks and picks[what] ~= nil then return picks[what] end
    end
end

function Moves:SyncOverride()
    OVERRIDE.rest = self.movesEditing and "stand" or nil -- (the moves editor plays what you try)
    OVERRIDE.night = self.night
    self.override = (self.liftEditing or self.movesEditing or self.night) and OVERRIDE or nil
end

-- /dp probe lift (LiftEditor.lua): its picks first while it's open.
function Moves:SetLiftEditing(on)
    self.liftEditing = on or nil
    self:SyncOverride()
end

-- /dp probe anim night: night until toggled off or /reload, every pet asleep
-- again, and every stage's pet posed anew.
function Moves:ForceNight()
    self.night = not self.night or nil
    self:SyncOverride()
    wipe(self.awake)
    local any
    for _, s in ipairs(self.stages) do
        local key = s.shown.key
        s.shown.key = nil
        if key then s:Update(nil, key); any = true end
    end
    Say("night %s%s", self.night and "on" or "off", any and "" or " (open a pet's card)")
end

-- /dp probe moves (MovesEditor.lua): the card's pet stands while it's open, and
-- plays a reaction whole when asked, from a clean start.
function Moves:SetEditing(on)
    self.movesEditing = on or nil
    self:SyncOverride()
    local key = self.card.shown.key
    self.card.shown.key = nil
    if key then self.card:Update(nil, key) end
end
