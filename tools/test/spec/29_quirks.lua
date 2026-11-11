-- Quirks (Menagerie/Quirks.lua): dislikes, secret until they happen, and
-- easter eggs. No effect on anything; at most one line an hour.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local CAT = "s:40"

    -- Ola with a Bombay Cat (a cat: dislikes the water), adopted and out.
    -- The dice always say yes, and pick the first line.
    local function Setup(traits)
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 40 } })
        ola.ns.Companions = { build = 1, species = { [40] = { a = true, t = { "cat" } } } }
        ola.ns.Personality.PINNED = { [40] = traits or { "glupsk", "rampete" } }
        w:Settle("hello")
        ola:Slash("debug off") -- (the debug log wants every activity)
        ola:Slash("adopter bombay")
        w:Run(40)
        local Q = ola.ns.Quirks
        Q.random = function(n) return n and 1 or 0 end
        Q.DELAY = { dislike = { 0, 0 }, egg = { 0, 0 } } -- (said at once; the delay has its own test)
        return w, ola, Q
    end
    local function Said(c, text) c.world:RunTimers(); return c:Printed(text, true) end
    local function Count(c, text)
        c.world:RunTimers()
        local n = 0
        for _, l in ipairs(c.printed) do if l:find(text, 1, true) then n = n + 1 end end
        return n
    end
    local function Dive(c) c:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath") end
    local function Points(c) local e = c.ns.Registry:Life(CAT, "Ola Nord"); return e and e.p or 0 end

    test("dislikes: from families and traits, never something the pet likes", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        local set, list = P:Dislikes(CAT)
        ok(set.dive, "cats and the water"); eq(#list, 1)
        P.PINNED[40] = { "dykker", "latsabb" }
        set, list = P:Dislikes(CAT)
        no(set.dive, "a Dykker cat doesn't mind"); ok(set.jump, "Latsabb: jumping"); eq(#list, 1)
        P.PINNED[40] = { "reiseglad", "einstoing" }
        set = P:Dislikes(CAT)
        ok(set.hearth); ok(set.chat); ok(set.dive)
        for family, acts in pairs(P.DISLIKE_BY_FAMILY) do
            for _, a in ipairs(acts) do ok(ola.ns.Activity.KIND[a], family .. ": " .. a) end
        end
    end)

    test("a disliked dive: a line, no points, and from then on it's on the card", function()
        local w, ola, Q = Setup()
        ola:OpenJournal()
        local card = ola:SelectPet(40)
        eq(card.likes.text, "Liker fisking, quests og PvP", "a secret until it happens")
        ok(ola.ns.Activity:IsListening("MIRROR_TIMER_START"), "watched for the cat")
        local before = Points(ola)
        Dive(ola)
        ok(Said(ola, "Bombay Cat rister vannet av seg og ser fornærmet på deg."))
        ok(Said(ola, "Nå vet du det: Bombay Cat liker ikke dykking."))
        eq(Points(ola), before, "no effect on the bond")
        ok(ola.ns.DB.char.dislikes[CAT].dive)
        eq(card.likes.text, "Liker fisking, quests og PvP · liker ikke dykking")
        card.personalityHit.scripts.OnEnter(card.personalityHit)
        local lines = table.concat(ola.env.GameTooltip.lines, "\n")
        match(lines, "Liker ikke: dykking")
        -- At most one an hour.
        Dive(ola)
        eq(Count(ola, "Bombay Cat rister"), 1)
        w:Run(3601) -- (a dive counts once a minute, by the client's clock)
        Q.random = function(n) return n and 2 or 0.9 end -- the dice say no
        Dive(ola)
        eq(Count(ola, "dukkert"), 0)
        w:Run(61)
        Q.random = function(n) return n and 2 or 0 end
        Dive(ola)
        ok(Said(ola, "Bombay Cat nekter å se på deg etter den dukkerten."), "another line")
        eq(Count(ola, "Nå vet du det"), 1, "found once")
        -- Alone on the card: capitalized. And it's kept across a reload.
        ola.ns.Personality.PINNED[40] = { "kosete", "festglad" }
        ola.ns.Personality.BY_FAMILY = {}
        ola.ns.Personality.DEFAULT = {}
        ola:SelectPet(40)
        eq(card.likes.text, "Liker ikke dykking")
        ola:Reload()
        ok(ola.ns.DB.char.dislikes[CAT].dive)
    end)

    test("a line comes a while after what caused it, not the moment it happens", function()
        local w, ola, Q = Setup()
        Q.DELAY = { dislike = { 20, 60 }, egg = { 5, 20 } }
        Q.random = function(n) return n and 1 or 0.25 end -- yes, and halfway-ish: 20 + 0.25 * 40 = 30 s
        Dive(ola)
        eq(Count(ola, "Bombay Cat rister"), 0, "not at once")
        w:Run(29)
        eq(Count(ola, "Bombay Cat rister"), 0)
        no(ola:Printed("Nå vet du det", true))
        no(Q:Ready(), "nothing else slips in meanwhile")
        eq(ola.ns.DB.char.quirkAt, nil, "the hour is saved only once it's said (a /reload here spends nothing)")
        ola.ns.Activity:Emit("fish")
        w:Run(1.1)
        eq(Count(ola, "Bombay Cat rister"), 1, "about half a minute later")
        ok(ola:Printed("Nå vet du det: Bombay Cat liker ikke dykking.", true), "and then that it's found out")
        w:Run(30)
        eq(Count(ola, "fangsten"), 0, "the catch came in the dislike's hour")
        -- An egg's line: sooner (5 + 0.25 * 15 s).
        w:Skip(3601)
        ola.ns.Activity:Emit("fish")
        w:Run(8.6)
        eq(Count(ola, "fangsten"), 0)
        w:Run(0.3)
        eq(Count(ola, "fangsten"), 1)
    end)

    test("what Quirks watches gives no bond points: level-ups, deaths, dislikes, even with a moment trait", function()
        local w, ola, Q = Setup({ "glupsk", "friluftsdyr" })
        Q.random = function(n) return n and 1 or 0.99 end -- (no lines in the way)
        ok(ola.ns.Activity:IsListening("PLAYER_LEVEL_UP"), "the eggs want level-ups")
        local before = Points(ola)
        ola:Fire("PLAYER_LEVEL_UP", 29)
        Dive(ola)
        eq(Points(ola), before, "not the bond's to count (friluftsdyr outdoors would make it 5)")
        ola:Fire("QUEST_TURNED_IN", 1)
        ok(Points(ola) > before, "what the bond watches still counts")
    end)

    test("dislikes are watched only for the pets we'd have out", function()
        local w, ola = Setup({ "glupsk", "latsabb" })
        local A = ola.ns.Activity
        ok(A:IsListening("MIRROR_TIMER_START")); ok(ola.ns.Personality:Dislikes(CAT).jump)
        ola:Slash("gislipp")
        w:Run(5)
        ola.ns.Summon:SetActive(CAT, false)
        no(A:IsListening("MIRROR_TIMER_START"), "nobody here minds the water now")
        ok(A:IsListening("PLAYER_LEVEL_UP"), "the eggs' own")
    end)

    test("the guild unknown at login: the adopted pet's dislikes are watched once it's known", function()
        local w, ola = Setup()
        ola.ns.DB.char.activePet = nil -- (adopted before 0.2: no active pet saved)
        ola:Logout()
        local guild = ola.guild
        ola.guild = nil -- GetGuildInfo is nil for the first moments of a login
        ola:Login()
        w:Run(3)
        no(ola.ns.Activity:IsListening("MIRROR_TIMER_START"), "nothing known yet")
        ola.guild = guild
        w:Run(30)
        ok(ola.ns.Activity:IsListening("MIRROR_TIMER_START"), "the cat's dislike, watched after all")
    end)

    test("easter eggs: holidays and anniversaries, once a day, not held back by the hour", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        -- The adoption's round days, each once (the hour doesn't hold them back).
        -- On the day itself, in calendar days (the milestone lines have 30, 100 and the
        -- years); not days later, as the first version did.
        local at = select(3, ola.ns.Registry:Status(CAT)).at
        local Day = ola.ns.Bonds.DayNumber
        w:Skip(at + 100 * 86400 - w:ServerTime())
        while Day(w:ServerTime()) - Day(at) < 100 do w:Skip(3600) end
        A:Emit("day")
        eq(Count(ola, "bodd sammen"), 0, "100: the milestone line's")
        while Day(w:ServerTime()) - Day(at) < 200 do w:Skip(3600) end
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("day")
        ok(Said(ola, "Bombay Cat og du har bodd sammen i 200 dager!"))
        w:SkipDays(1)
        A:Emit("day")
        eq(Count(ola, "bodd sammen"), 1, "only on the day")
        -- A holiday, once a day.
        w:Skip(os.time({ year = 2027, month = 5, day = 17, hour = 12 }) - w:ServerTime())
        A:Emit("day")
        ok(Said(ola, "Bombay Cat har fått sløyfe i rødt, hvitt og blått. Hipp hurra!"))
        A:Emit("day"); A:Emit("day")
        eq(Count(ola, "sløyfe"), 1, "once a day")
        eq(ola.ns.DB.char.eggs.mai17.n, 1)
        -- Not for a pet you haven't adopted.
        no(Q.EGGS[7].test({ key = "s:5159", t = ola.ns.Now() }))
        -- Friday the 13th.
        w:Skip(os.time({ year = 2027, month = 8, day = 13, hour = 12 }) - w:ServerTime())
        A:Emit("day")
        ok(Said(ola, "Bombay Cat går i en stor bue rundt alle svarte katter i dag."))
    end)

    test("easter eggs by chance and by the hour: fish, bosses, levels, deaths, midnight", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        A:Emit("fish")
        ok(Said(ola, "Bombay Cat har allerede spist halve fangsten."), "a cat and the catch")
        A:Emit("boss", 1, "Hogger")
        no(Said(ola, "som minne"), "the hour isn't up")
        w:Skip(3601)
        Q.random = function(n) return n and 1 or 0.5 end
        A:Emit("boss", 1, "Hogger")
        no(Said(ola, "som minne"), "the dice said no (15%)")
        Q.random = function(n) return n and 1 or 0 end
        A:Emit("boss", 1, "?")
        no(Said(ola, "som minne"), "no name, no trophy")
        A:Emit("boss", 1, "Hogger")
        ok(Said(ola, "Bombay Cat tok med seg en liten bit av Hogger som minne."))
        w:Skip(3601)
        A:Emit("level", 1, "29")
        no(Said(ola, "kake"))
        A:Emit("level", 1, "30")
        ok(Said(ola, "Bombay Cat har bakt kake til level 30!"))
        w:Skip(3601)
        A:Emit("revive"); A:Emit("revive")
        no(Said(ola, "trygt"))
        A:Emit("revive")
        ok(Said(ola, "Bombay Cat lurer på om det er trygt å bo hos deg."), "the third death today")
        eq(ola.ns.DB.char.eggs.dodsfall.key, CAT, "which pet: it plays dead on its card (Moves.lua)")
        w:Skip(3601)
        ola.ns.DB.char.activity.quest = { total = 499, mine = 0, today = 0, pets = { [CAT] = 98 } }
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("quest")
        no(Said(ola, "quests. Det"), "500 quests in all, but 99 with this pet")
        A:Emit("quest")
        ok(Said(ola, "Bombay Cat har hjulpet deg med 100 quests. Det fortjener en godbit!"),
            "its own hundredth, not held back by the hour")
        -- Midnight: any activity in its first ten minutes.
        w:Skip(os.time({ year = 2027, month = 3, day = 2, hour = 0, min = 5 }) - w:ServerTime())
        A:Emit("herb")
        ok(Said(ola, "Bombay Cat gjesper. Det er midnatt, vet du."))
    end)

    test("your pet meets its own kind under the mouse", function()
        local w, ola, Q = Setup()
        ola:Hover{ species = 40, owner = "Kari Berg" }
        ok(Said(ola, "Bombay Cat stirrer på Kari Berg sitt dyr. Er det et speil?"))
        w:Skip(3601)
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(Count(ola, "speil"), 1, "once a day")
        w:SkipDays(1)
        ola:Hover{ species = 46, owner = "Kari Berg" }
        ola:Hover{ species = 40, owner = "Ola Nord" }
        ola:Hover{ species = 40 }
        eq(Count(ola, "speil"), 1, "not another species, not your own, not one without an owner")
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(Count(ola, "speil"), 2)
    end)

    test("the pet makes fun of you: a 1 of 100 (yours, /roll or loot), two fish lost in a row", function()
        local w, ola, Q = Setup()
        local LINE = "Bombay Cat så terningen lande på 1"
        local function Roll(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Roll("Ola Nord rolls 1 (1-10)"); Roll("Ola Nord rolls 1 (2-100)"); Roll("Kari Berg rolls 1 (1-100)")
        Roll("Ola Nord rolls 11 (1-100)")
        eq(Count(ola, LINE), 0, "not 1-100, not yours, not a 1")
        Roll("Ola Nord rolls 1 (1-100)")
        eq(Count(ola, LINE), 1)
        w:SkipDays(1)
        ola:Fire("CHAT_MSG_LOOT", "|HlootHistory:1|h[Loot]|h: Greed Roll - 1 for [Linen Cloth] by Kari Berg"); w:Run(1)
        eq(Count(ola, LINE), 1, "someone else's")
        ola:Fire("CHAT_MSG_LOOT", "|HlootHistory:1|h[Loot]|h: Need Roll - 55 for [Linen Cloth] by Ola Nord"); w:Run(1)
        eq(Count(ola, LINE), 1, "a 55 (the 1 in the loot history link isn't the roll)")
        ola:Fire("CHAT_MSG_LOOT", "|HlootHistory:12|h[Loot]|h: Need Roll - 1 for [Linen Cloth] by Ola Nord"); w:Run(1)
        eq(Count(ola, LINE), 2, "a loot roll")
        -- Fishing: once at the second fish in a row that got away; a catch starts over.
        w:Skip(2700) -- (not an `always` egg: the 45 minutes since the roll's line)
        local FISH = "Bombay Cat ser på deg, så på vannet"
        local function Lost(text) ola:Fire("UI_ERROR_MESSAGE", 0, text or "Your fish got away!"); w:Run(1) end
        Lost()
        ola:Fire("LOOT_OPENED"); w:Run(1)
        Lost("No fish are hooked.")
        eq(Count(ola, FISH), 0, "a catch between them")
        Lost()
        eq(Count(ola, FISH), 1, "two in a row")
        Lost()
        eq(Count(ola, FISH), 1, "once")
        Lost("You can't do that yet")
        eq(Count(ola, FISH), 1)
    end)

    test("the pet is amazed: a 100 of 100 (yours, /roll or loot), an epic you looted", function()
        local w, ola, Q = Setup()
        local function Eggs(id) local e = ola.ns.DB.char.eggs[id]; return e and e.n or 0 end
        local function Roll(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Roll("Ola Nord rolls 100 (1-1000)"); Roll("Kari Berg rolls 100 (1-100)"); Roll("Ola Nord rolls 99 (1-100)")
        eq(Eggs("hundre"), 0, "not 1-100, not yours, not a 100")
        Roll("Ola Nord rolls 100 (1-100)")
        eq(Eggs("hundre"), 1)
        Roll("Ola Nord rolls 100 (1-100)")
        eq(Eggs("hundre"), 1, "once a day")
        w:SkipDays(1)
        ola:Fire("CHAT_MSG_LOOT", "Disenchant Roll - 100 for [Linen Cloth] by Ola Nord"); w:Run(1)
        eq(Eggs("hundre"), 2, "a loot roll, no history link")
        -- Loot: epic or better, yours, looted (not pushed to you).
        local function Loot(text) ola:Fire("CHAT_MSG_LOOT", text); w:Run(1) end
        local EPIC_LINK = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
        Loot("You receive loot: |cff0070dd|Hitem:1::::::::60:::::|h[Blue Thing]|h|r")
        Loot("You receive item: " .. EPIC_LINK)
        Loot("Kari Berg receives loot: " .. EPIC_LINK)
        eq(Eggs("lilla"), 0, "a rare, a reward pushed to you, someone else's")
        Loot("You receive loot: " .. EPIC_LINK)
        eq(Eggs("lilla"), 1, "an epic, at once (no 45 minutes needed)")
        w:SkipDays(1)
        Loot("You receive loot: |cffff8000|Hitem:2::::::::60:::::|h[Orange]|h|rx2.")
        eq(Eggs("lilla"), 2, "a legendary, in a stack")
    end)

    test("a duel won or lost (yours), a new flight path, fishing in Stranglethorn on the contest's day", function()
        local w, ola, Q = Setup()
        local function Eggs(id) local e = ola.ns.DB.char.eggs[id]; return e and e.n or 0 end
        local function Sys(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Sys("Kari Berg has defeated Per Hansen in a duel")
        eq(Eggs("duellvinner") + Eggs("duelltaper"), 0, "not yours")
        Sys("Ola Nord has defeated Kari Berg in a duel")
        eq(Eggs("duellvinner"), 1)
        ok(Said(ola, "Bombay Cat") and ola:Printed("Kari Berg", true), "who it was against")
        Sys("Ola Nord has fled from Kari Berg in a duel")
        eq(Eggs("duelltaper"), 1, "fleeing is losing")
        w:SkipDays(1)
        Sys("Kari Berg has fled from Ola Nord in a duel")
        eq(Eggs("duellvinner"), 2, "they fled: you won")
        -- A new flight path: this cat neither likes nor dislikes flying, so it doesn't care.
        local function Path() ola:Fire("UI_INFO_MESSAGE", 0, "New flight path discovered!"); w:Run(4) end
        Path()
        eq(Eggs("nyrute"), 0, "doesn't care")
        -- Dislikes flying: shivers.
        local P = ola.ns.Personality
        local dislikes = P.Dislikes
        P.Dislikes = function() return { taxi = true }, { "taxi" } end
        Path()
        eq(Eggs("nyrute"), 1)
        ok(Said(ola, "Bombay Cat skjelver ved tanken"), "a shiver")
        P.Dislikes = dislikes
        -- Likes flying (Reiseglad): thrilled.
        local w2, kari = Setup({ "reiseglad", "glupsk" })
        kari:Fire("UI_INFO_MESSAGE", 0, "New flight path discovered!"); w2:Run(4)
        ok(Said(kari, "Bombay Cat er i ekstase"), "thrilled")
    end)

    test("a lot of guild chat at once: a pet that isn't a Pratsom comments, now and then", function()
        local w, ola, Q = Setup()
        local function Eggs(id) local e = ola.ns.DB.char.eggs[id]; return e and e.n or 0 end
        local function Say(n, gap)
            for _ = 1, n do ola:Fire("CHAT_MSG_GUILD", "hei", "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, ola.env.UnitGUID("player")); w:Run(gap or 5) end
        end
        Say(5, 40)
        eq(Eggs("skravle"), 0, "five lines over three minutes: not a lot")
        Say(5)
        eq(Eggs("skravle"), 1, "five in half a minute")
        Q.random = function(n) return n and 1 or 0.9 end
        w:SkipDays(1); Say(5)
        eq(Eggs("skravle"), 1, "by chance only")
        -- A Pratsom just likes it.
        local w2, kari = Setup({ "pratsom", "glupsk" })
        for _ = 1, 6 do kari:Fire("CHAT_MSG_GUILD", "hei", "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, kari.env.UnitGUID("player")); w2:Run(5) end
        eq(kari.ns.DB.char.eggs.skravle, nil)
    end)

    test("how long a line waits depends on the line: a roll's at once, a holiday's soon after, a flight's dislike later", function()
        local w, ola, Q = Setup({ "glupsk", "reiseglad" })
        local _, other = H.Setup{ ola = {} } -- (Setup pinned the waits to 0: the file's, from a fresh client)
        Q.DELAY = other.ns.Quirks.DELAY
        Q.random = function(n) return n and 1 or 0.49 end -- (within the egg's chance; near the middle of each wait)
        ola:Fire("CHAT_MSG_SYSTEM", "Ola Nord rolls 1 (1-100)")
        w:Run(Q.DELAY.now[2] + 0.1)
        ok(Said(ola, "Bombay Cat så terningen lande på 1"), "a roll: within " .. Q.DELAY.now[2] .. " s")
        ok(Q.DELAY.now[2] <= 3 and Q.DELAY.egg[2] <= 15 and Q.DELAY.dislike[2] <= 15, "nothing waits half a minute but the flight")
        eq(Q.DISLIKE_DELAY.taxi, "slow")
        ok(Q.DELAY.slow[1] >= 20, "a flight's dislike: not the moment you take off")
    end)

    test("the fishing contest: a pet that likes fishing looks forward to it, and gets a bonus fishing in Stranglethorn", function()
        local w, ola, Q = Setup({ "vannhund", "glupsk" })
        local function Eggs(id) local e = ola.ns.DB.char.eggs[id]; return e and e.n or 0 end
        local B = ola.ns.Bond
        -- The contest is on tomorrow; the calendar answers after the day's visit (past midnight).
        w:SkipDays(1)
        ola.state.holidays = { [ola.ns.Today()] = { 301 } }
        ola.ns.Activity:Emit("day"); w:Run(2)
        eq(Eggs("fiskedag"), 1, "once the calendar answered: the day's eggs again")
        ok(Said(ola, "fiskekonkurransen i Stranglethorn i dag"))
        eq(ola.ns.Personality.Holiday(w:ServerTime()), nil, "not a holiday")
        -- Fishing: in Elwynn nothing more, in Stranglethorn the bonus, once.
        local function Fish() local was = B:Today("s:40"); ola.ns.Activity:Emit("fish"); w:Run(1); return B:Today("s:40") - was end
        Fish()
        eq(Count(ola, "jubler over at du fisket"), 0, "not in Elwynn")
        ola.state.zone = "Stranglethorn Vale"
        ok(Fish() >= ola.ns.Config.BOND_CONTEST_POINTS, "the bonus, on top of the fishing")
        eq(Count(ola, "Bombay Cat jubler over at du fisket i fiskekonkurransen! (+10 bånd-poeng)"), 1)
        ok(Fish() < ola.ns.Config.BOND_CONTEST_POINTS, "once a day")
        eq(Count(ola, "jubler over at du fisket"), 1)
        -- A pet that doesn't care for fishing: no bonus, no day egg.
        local w2, kari = Setup({ "glupsk", "rampete" })
        local Of = kari.ns.Personality.Of
        kari.ns.Personality.Of = function(self, key)
            local likes, a, b = Of(self, key)
            local copy = {}
            for k, v in pairs(likes) do if k ~= "fish" then copy[k] = v end end
            return copy, a, b
        end
        w2:SkipDays(1)
        kari.state.holidays = { [kari.ns.Today()] = { 301 } }
        kari.ns.Activity:Emit("day"); w2:Run(2)
        eq(kari.ns.DB.char.eggs.fiskedag, nil)
        kari.state.zone = "Stranglethorn Vale"
        kari.ns.Activity:Emit("fish"); w2:Run(1)
        no(kari:Printed("jubler over at du fisket", true))
    end)
end
