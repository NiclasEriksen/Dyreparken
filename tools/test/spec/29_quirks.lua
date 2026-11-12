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
        ola:Companions{ [40] = { a = true, t = { "cat" } } }
        ola:Traits(traits or { "glupsk", "rampete" }, 40)
        w:Settle("hello")
        ola:Slash("debug off") -- (the debug log wants every activity)
        ola:Slash("adopter bombay")
        w:Run(40)
        local Q = ola.ns.Quirks
        ola:Dice(0)
        ola:QuirksNow() -- (said at once; the delay has its own test)
        return w, ola, Q
    end
    local function Dive(c) c:Fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath") end

    test("a dislike doesn't stop the eggs: a wolf that minds naps still has its fifth nap's", function()
        local w, ola = Setup()
        ola:Companions{ [40] = { a = true, t = { "wolf" } } }
        ok(ola.ns.Personality:Dislikes(CAT).nap, "a wolf minds naps")
        ola:Dice(0.5) -- (the dislike's 35% says no; the nap egg has no chance of its own)
        for _ = 1, 4 do ola.ns.Activity:Emit("nap") end
        no(ola:Said("lurer på om dere"), "not before the fifth")
        ola.ns.Activity:Emit("nap")
        ok(ola:Said("Bombay Cat lurer på om dere har tenkt å bli her for godt."))
    end)

    test("dislikes: from families and traits, never something the pet likes", function()
        local w, ola = Setup()
        local P = ola.ns.Personality
        local set, list = P:Dislikes(CAT)
        ok(set.dive, "cats and the water"); eq(#list, 1)
        ola:Traits({ "dykker", "latsabb" }, 40)
        set, list = P:Dislikes(CAT)
        no(set.dive, "a Dykker cat doesn't mind"); ok(set.jump, "Latsabb: jumping"); eq(#list, 1)
        ola:Traits({ "reiseglad", "einstoing" }, 40)
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
        local before = ola:Points(CAT)
        Dive(ola)
        ok(ola:Said("Bombay Cat rister vannet av seg og ser fornærmet på deg."))
        ok(ola:Said("Nå vet du det: Bombay Cat liker ikke dykking."))
        eq(ola:Points(CAT), before, "no effect on the bond")
        ok(ola.ns.DB.char.dislikes[CAT].dive)
        eq(card.likes.text, "Liker fisking, quests og PvP · liker ikke dykking")
        match(ola:TipOf(card.personalityHit).text, "Liker ikke: dykking")
        -- At most one an hour.
        Dive(ola)
        eq(ola:CountPrinted("Bombay Cat rister"), 1)
        w:Run(3601) -- (a dive counts once a minute, by the client's clock)
        ola:Dice(0.9, 2) -- the dice say no
        Dive(ola)
        eq(ola:CountPrinted("dukkert"), 0)
        w:Run(61)
        ola:Dice(0, 2)
        Dive(ola)
        ok(ola:Said("Bombay Cat nekter å se på deg etter den dukkerten."), "another line")
        eq(ola:CountPrinted("Nå vet du det"), 1, "found once")
        -- Alone on the card: capitalized. And it's kept across a reload.
        ola:Traits({ "kosete", "festglad" }, 40)
        ola.ns.Personality.BY_FAMILY = {}
        ola.ns.Personality.DEFAULT = {}
        ola:SelectPet(40)
        eq(card.likes.text, "Liker ikke dykking")
        ola:Reload()
        ok(ola.ns.DB.char.dislikes[CAT].dive)
    end)

    test("a line comes a while after what caused it, not the moment it happens", function()
        local w, ola, Q = Setup()
        for k in pairs(Q.DELAY) do Q.DELAY[k] = { 5, 20 } end -- (every egg tier alike)
        Q.DELAY.dislike = { 20, 60 }
        ola:Dice(0.25) -- yes, and halfway-ish: 20 + 0.25 * 40 = 30 s
        Dive(ola)
        eq(ola:CountPrinted("Bombay Cat rister"), 0, "not at once")
        w:Run(29)
        eq(ola:CountPrinted("Bombay Cat rister"), 0)
        no(ola:Printed("Nå vet du det", true))
        no(Q:Ready(), "nothing else slips in meanwhile")
        eq(ola.ns.DB.char.quirkAt, nil, "the hour is saved only once it's said (a /reload here spends nothing)")
        ola.ns.Activity:Emit("fish")
        w:Run(1.1)
        eq(ola:CountPrinted("Bombay Cat rister"), 1, "about half a minute later")
        ok(ola:Printed("Nå vet du det: Bombay Cat liker ikke dykking.", true), "and then that it's found out")
        w:Run(30)
        eq(ola:CountPrinted("fangsten"), 0, "the catch came in the dislike's hour")
        -- An egg's line: sooner (5 + 0.25 * 15 s).
        w:Skip(3601)
        ola.ns.Activity:Emit("fish")
        w:Run(8.6)
        eq(ola:CountPrinted("fangsten"), 0)
        w:Run(0.3)
        eq(ola:CountPrinted("fangsten"), 1)
    end)

    test("what Quirks watches gives no bond points: level-ups, deaths, dislikes, even with a moment trait", function()
        local w, ola, Q = Setup({ "glupsk", "friluftsdyr" })
        ola:Dice(0.99) -- (no lines in the way)
        ok(ola.ns.Activity:IsListening("PLAYER_LEVEL_UP"), "the eggs want level-ups")
        local before = ola:Points(CAT)
        ola:Fire("PLAYER_LEVEL_UP", 29)
        Dive(ola)
        eq(ola:Points(CAT), before, "not the bond's to count (friluftsdyr outdoors would make it 5)")
        ola:Fire("QUEST_TURNED_IN", 1)
        ok(ola:Points(CAT) > before, "what the bond watches still counts")
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
        eq(ola:CountPrinted("bodd sammen"), 0, "100: the milestone line's")
        while Day(w:ServerTime()) - Day(at) < 200 do w:Skip(3600) end
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("day")
        ok(ola:Said("Bombay Cat og du har bodd sammen i 200 dager!"))
        w:SkipDays(1)
        A:Emit("day")
        eq(ola:CountPrinted("bodd sammen"), 1, "only on the day")
        -- A holiday, once a day.
        w:SetDate(2027, 5, 17, 12)
        A:Emit("day")
        ok(ola:Said("Bombay Cat har fått sløyfe i rødt, hvitt og blått. Hipp hurra!"))
        A:Emit("day"); A:Emit("day")
        eq(ola:CountPrinted("sløyfe"), 1, "once a day")
        eq(ola:Eggs("mai17"), 1)
        -- Not for a pet you haven't adopted.
        no(Q.EGGS[7].test({ key = "s:5159", t = ola.ns.Now() }))
        -- Friday the 13th.
        w:SetDate(2027, 8, 13, 12)
        A:Emit("day")
        ok(ola:Said("Bombay Cat går i en stor bue rundt alle svarte katter i dag."))
    end)

    test("easter eggs by chance and by the hour: fish, bosses, levels, deaths, midnight", function()
        local w, ola, Q = Setup()
        local A = ola.ns.Activity
        A:Emit("fish")
        ok(ola:Said("Bombay Cat har allerede spist halve fangsten."), "a cat and the catch")
        A:Emit("boss", 1, "Hogger")
        no(ola:Said("som minne"), "the hour isn't up")
        w:Skip(3601)
        ola:Dice(0.5)
        A:Emit("boss", 1, "Hogger")
        no(ola:Said("som minne"), "the dice said no (15%)")
        ola:Dice(0)
        A:Emit("boss", 1, "?")
        no(ola:Said("som minne"), "no name, no trophy")
        A:Emit("boss", 1, "Hogger")
        ok(ola:Said("Bombay Cat tok med seg en liten bit av Hogger som minne."))
        w:Skip(3601)
        A:Emit("level", 1, "29")
        no(ola:Said("kake"))
        A:Emit("level", 1, "30")
        ok(ola:Said("Bombay Cat har bakt kake til level 30!"))
        w:Skip(3601)
        A:Emit("revive"); A:Emit("revive")
        no(ola:Said("trygt"))
        A:Emit("revive")
        ok(ola:Said("Bombay Cat lurer på om det er trygt å bo hos deg."), "the third death today")
        eq(ola.ns.DB.char.eggs.dodsfall.key, CAT, "which pet: it plays dead on its card (Moves.lua)")
        w:Skip(3601)
        ola.ns.DB.char.activity.quest = { total = 499, mine = 0, today = 0, pets = { [CAT] = 98 } }
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("quest")
        no(ola:Said("quests. Det"), "500 quests in all, but 99 with this pet")
        A:Emit("quest")
        ok(ola:Said("Bombay Cat har hjulpet deg med 100 quests. Det fortjener en godbit!"),
            "its own hundredth, not held back by the hour")
        -- Midnight: any activity in its first ten minutes.
        w:SetDate(2027, 3, 2, 0, 5)
        A:Emit("herb")
        ok(ola:Said("Bombay Cat gjesper. Det er midnatt, vet du."))
    end)

    test("your pet meets its own kind under the mouse", function()
        local w, ola, Q = Setup()
        ola:Hover{ species = 40, owner = "Kari Berg" }
        ok(ola:Said("Bombay Cat stirrer på Kari Berg sitt dyr. Er det et speil?"))
        w:Skip(3601)
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(ola:CountPrinted("speil"), 1, "once a day")
        w:SkipDays(1)
        ola:Hover{ species = 46, owner = "Kari Berg" }
        ola:Hover{ species = 40, owner = "Ola Nord" }
        ola:Hover{ species = 40 }
        eq(ola:CountPrinted("speil"), 1, "not another species, not your own, not one without an owner")
        ola:Hover{ species = 40, owner = "Kari Berg" }
        eq(ola:CountPrinted("speil"), 2)
    end)

    test("the pet makes fun of you: a 1 of 100 (yours, /roll or loot), two fish lost in a row", function()
        local w, ola, Q = Setup()
        local LINE = "Bombay Cat så terningen lande på 1"
        local function Roll(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Roll("Ola Nord rolls 1 (1-10)"); Roll("Ola Nord rolls 1 (2-100)"); Roll("Kari Berg rolls 1 (1-100)")
        Roll("Ola Nord rolls 11 (1-100)")
        eq(ola:CountPrinted(LINE), 0, "not 1-100, not yours, not a 1")
        Roll("Ola Nord rolls 1 (1-100)")
        eq(ola:CountPrinted(LINE), 1)
        w:SkipDays(1)
        ola:Fire("CHAT_MSG_LOOT", "|HlootHistory:1|h[Loot]|h: Greed Roll - 1 for [Linen Cloth] by Kari Berg"); w:Run(1)
        eq(ola:CountPrinted(LINE), 1, "someone else's")
        ola:Fire("CHAT_MSG_LOOT", "|HlootHistory:1|h[Loot]|h: Need Roll - 55 for [Linen Cloth] by Ola Nord"); w:Run(1)
        eq(ola:CountPrinted(LINE), 1, "a 55 (the 1 in the loot history link isn't the roll)")
        ola:Fire("CHAT_MSG_LOOT", "|HlootHistory:12|h[Loot]|h: Need Roll - 1 for [Linen Cloth] by Ola Nord"); w:Run(1)
        eq(ola:CountPrinted(LINE), 2, "a loot roll")
        -- Fishing: once at the second fish in a row that got away; a catch starts over.
        w:Skip(2700) -- (not an `always` egg: the 45 minutes since the roll's line)
        local FISH = "Bombay Cat ser på deg, så på vannet"
        local function Lost(text) ola:Fire("UI_ERROR_MESSAGE", 0, text or "Your fish got away!"); w:Run(1) end
        Lost()
        ola:Fire("LOOT_OPENED"); w:Run(1)
        Lost("No fish are hooked.")
        eq(ola:CountPrinted(FISH), 0, "a catch between them")
        Lost()
        eq(ola:CountPrinted(FISH), 1, "two in a row")
        Lost()
        eq(ola:CountPrinted(FISH), 1, "once")
        Lost("You can't do that yet")
        eq(ola:CountPrinted(FISH), 1)
    end)

    test("the pet is amazed: a 100 of 100 (yours, /roll or loot), an epic you looted", function()
        local w, ola, Q = Setup()
        local function Roll(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Roll("Ola Nord rolls 100 (1-1000)"); Roll("Kari Berg rolls 100 (1-100)"); Roll("Ola Nord rolls 99 (1-100)")
        eq(ola:Eggs("hundre"), 0, "not 1-100, not yours, not a 100")
        Roll("Ola Nord rolls 100 (1-100)")
        eq(ola:Eggs("hundre"), 1)
        Roll("Ola Nord rolls 100 (1-100)")
        eq(ola:Eggs("hundre"), 1, "once a day")
        w:SkipDays(1)
        ola:Fire("CHAT_MSG_LOOT", "Disenchant Roll - 100 for [Linen Cloth] by Ola Nord"); w:Run(1)
        eq(ola:Eggs("hundre"), 2, "a loot roll, no history link")
        -- Loot: epic or better, yours, looted (not pushed to you).
        local function Loot(text) ola:Fire("CHAT_MSG_LOOT", text); w:Run(1) end
        local EPIC_LINK = "|cffa335ee|Hitem:19019::::::::60:::::|h[Thunderfury]|h|r"
        Loot("You receive loot: |cff0070dd|Hitem:1::::::::60:::::|h[Blue Thing]|h|r")
        Loot("You receive item: " .. EPIC_LINK)
        Loot("Kari Berg receives loot: " .. EPIC_LINK)
        eq(ola:Eggs("lilla"), 0, "a rare, a reward pushed to you, someone else's")
        Loot("You receive loot: " .. EPIC_LINK)
        eq(ola:Eggs("lilla"), 1, "an epic, at once (no 45 minutes needed)")
        w:SkipDays(1)
        Loot("You receive loot: |cffff8000|Hitem:2::::::::60:::::|h[Orange]|h|rx2.")
        eq(ola:Eggs("lilla"), 2, "a legendary, in a stack")
    end)

    test("a duel won or lost (yours), a new flight path, fishing in Stranglethorn on the contest's day", function()
        local w, ola, Q = Setup()
        local function Sys(text) ola:Fire("CHAT_MSG_SYSTEM", text); w:Run(1) end
        Sys("Kari Berg has defeated Per Hansen in a duel")
        eq(ola:Eggs("duellvinner") + ola:Eggs("duelltaper"), 0, "not yours")
        Sys("Ola Nord has defeated Kari Berg in a duel")
        eq(ola:Eggs("duellvinner"), 1)
        ok(ola:Said("Bombay Cat") and ola:Printed("Kari Berg", true), "who it was against")
        Sys("Ola Nord has fled from Kari Berg in a duel")
        eq(ola:Eggs("duelltaper"), 1, "fleeing is losing")
        w:SkipDays(1)
        Sys("Kari Berg has fled from Ola Nord in a duel")
        eq(ola:Eggs("duellvinner"), 2, "they fled: you won")
        -- A new flight path: this cat neither likes nor dislikes flying, so it doesn't care.
        local function Path() ola:Fire("UI_INFO_MESSAGE", 0, "New flight path discovered!"); w:Run(4) end
        Path()
        eq(ola:Eggs("nyrute"), 0, "doesn't care")
        -- Dislikes flying: shivers.
        local P = ola.ns.Personality
        local dislikes = P.Dislikes
        P.Dislikes = function() return { taxi = true }, { "taxi" } end
        Path()
        eq(ola:Eggs("nyrute"), 1)
        ok(ola:Said("Bombay Cat skjelver ved tanken"), "a shiver")
        P.Dislikes = dislikes
        -- Likes flying (Reiseglad): thrilled.
        local w2, kari = Setup({ "reiseglad", "glupsk" })
        kari:Fire("UI_INFO_MESSAGE", 0, "New flight path discovered!"); w2:Run(4)
        ok(kari:Said("Bombay Cat er i ekstase"), "thrilled")
    end)

    test("a lot of guild chat at once: a pet that isn't a Pratsom comments, now and then", function()
        local w, ola, Q = Setup()
        local function Say(n, gap)
            for _ = 1, n do ola:Fire("CHAT_MSG_GUILD", "hei", "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, ola.env.UnitGUID("player")); w:Run(gap or 5) end
        end
        Say(5, 40)
        eq(ola:Eggs("skravle"), 0, "five lines over three minutes: not a lot")
        Say(5)
        eq(ola:Eggs("skravle"), 1, "five in half a minute")
        ola:Dice(0.9)
        w:SkipDays(1); Say(5)
        eq(ola:Eggs("skravle"), 1, "by chance only")
        -- A Pratsom just likes it.
        local w2, kari = Setup({ "pratsom", "glupsk" })
        for _ = 1, 6 do kari:Fire("CHAT_MSG_GUILD", "hei", "Ola Nord", "", "", "", "", 0, 0, "", 0, 1, kari.env.UnitGUID("player")); w2:Run(5) end
        eq(kari:Eggs("skravle"), 0)
    end)

    test("how long a line waits depends on the line: a roll's at once, a holiday's soon after, a flight's dislike later", function()
        local w, ola, Q = Setup({ "glupsk", "reiseglad" })
        local _, other = H.Setup{ ola = {} } -- (Setup pinned the waits to 0: the file's, from a fresh client)
        Q.DELAY = other.ns.Quirks.DELAY
        ola:Dice(0.49) -- (within the egg's chance; near the middle of each wait)
        ola:Fire("CHAT_MSG_SYSTEM", "Ola Nord rolls 1 (1-100)")
        w:Run(Q.DELAY.now[2] + 0.1)
        ok(ola:Said("Bombay Cat så terningen lande på 1"), "a roll: within " .. Q.DELAY.now[2] .. " s")
        ok(Q.DELAY.now[2] <= 3 and Q.DELAY.egg[2] <= 15 and Q.DELAY.dislike[2] <= 15, "nothing waits half a minute but the flight")
        eq(Q.DISLIKE_DELAY.taxi, "slow")
        ok(Q.DELAY.slow[1] >= 20, "a flight's dislike: not the moment you take off")
    end)

    test("the fishing contest: a pet that likes fishing looks forward to it, and gets a bonus fishing in Stranglethorn", function()
        local w, ola, Q = Setup({ "vannhund", "glupsk" })
        local B = ola.ns.Bond
        -- The contest is on tomorrow; the calendar answers after the day's visit (past midnight).
        w:SkipDays(1)
        ola.state.holidays = { [ola.ns.Today()] = { 301 } }
        ola.ns.Activity:Emit("day"); w:Run(2)
        eq(ola:Eggs("fiskedag"), 1, "once the calendar answered: the day's eggs again")
        ok(ola:Said("fiskekonkurransen i Stranglethorn i dag"))
        eq(ola.ns.Personality.Holiday(w:ServerTime()), nil, "not a holiday")
        -- Fishing: in Elwynn nothing more, in Stranglethorn the bonus, once.
        local function Fish() local was = B:Today("s:40"); ola.ns.Activity:Emit("fish"); w:Run(1); return B:Today("s:40") - was end
        Fish()
        eq(ola:CountPrinted("jubler over at du fisket"), 0, "not in Elwynn")
        ola.state.zone = "Stranglethorn Vale"
        ok(Fish() >= ola.ns.Config.BOND_CONTEST_POINTS, "the bonus, on top of the fishing")
        eq(ola:CountPrinted("Bombay Cat jubler over at du fisket i fiskekonkurransen! (+10 båndpoeng)"), 1)
        ok(Fish() < ola.ns.Config.BOND_CONTEST_POINTS, "once a day")
        eq(ola:CountPrinted("jubler over at du fisket"), 1)
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
        eq(kari:Eggs("fiskedag"), 0)
        kari.state.zone = "Stranglethorn Vale"
        kari.ns.Activity:Emit("fish"); w2:Run(1)
        no(kari:Printed("jubler over at du fisket", true))
    end)

    test("tiers: a dislike's discovery and the clock's eggs aren't held back; a known dislike, the fire and the trophy are", function()
        local w, ola, Q = Setup({ "latsabb", "glupsk" }) -- (a cozy cat: the fire's lines)
        local A = ola.ns.Activity
        -- Something else just spoke: the 45 minutes run.
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        Dive(ola)
        ok(ola:Said("Nå vet du det: Bombay Cat liker ikke dykking."), "a discovery comes anyway")
        -- Known now: held back by the 45 minutes, and only now and then after them.
        w:Run(61); Dive(ola)
        eq(ola:CountPrinted("Bombay Cat rister"), 1, "known, and the 45 minutes run")
        w:Skip(Q.EVERY + 1)
        ola:Dice(0.2) -- (above 15%, below 35%)
        w:Run(61); Dive(ola)
        eq(ola:CountPrinted("Bombay Cat rister"), 1, "a known dislike again: 15%")
        ola:Dice(0)
        -- Midnight within the 45 minutes: rare, it comes.
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        w:SetDate(2027, 3, 3, 0, 5)
        ola.ns.DB.char.quirkAt = ola.ns.Now()
        A:Emit("herb")
        ok(ola:Said("Bombay Cat gjesper. Det er midnatt, vet du."), "the clock's egg: not held back")
        -- The fire: its stages are one fire, one line (the 45 minutes); the countdown only now and then.
        w:Skip(Q.EVERY + 1)
        ola:Dice(0.3) -- (above the countdown's 25%, below the warmth's 60%)
        A:Emit("campwarm"); w:RunTimers()
        eq(ola:Eggs("baalvarm"), 0, "the countdown: 25%")
        A:Emit("camp"); w:RunTimers()
        ok(ola:Eggs("baal") > 0, "the warmth gets its turn")
        A:Emit("rested"); w:RunTimers()
        eq(ola:Eggs("sovepose"), 0, "the same fire: no second line")
        ola:Dice(0)
        -- The trophy: a boss new to the pet half the time, one it has seen fall 15%.
        w:Skip(Q.EVERY + 1)
        ola:Dice(0.3)
        A:Emit("boss", 1, "Hogger")
        ok(ola:Said("Bombay Cat tok med seg en liten bit av Hogger som minne."), "new to it: 0.3 < 50%")
        w:SkipDays(1); w:Skip(Q.EVERY + 1)
        A:Emit("boss", 1, "Hogger")
        eq(ola:CountPrinted("bit av Hogger"), 1, "seen it fall before: 0.3 > 15%")
    end)
end
