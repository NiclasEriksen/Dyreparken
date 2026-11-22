-- Loyalty points (Bond.lua, 2026-11-19, the user): from the top level on, everything a pet earns with you counts
-- on without the day's limit (the per-activity caps stay), continuing from the bond's points; at the pet's rate;
-- kept on this client only for now. On the card and the pet frame a counter replaces the bar, and the level's
-- number becomes a gold star.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA, KITTEN = "s:5159", "s:46"
    local TOP = 2250

    local function Setup()
        local w, ola = H.Setup{ ola = { 5159, 46 }, journal = true }
        ola:Slash("adopter panda"); w:Run(5)
        -- (today's wish done already: these count likes, and a wish for one would add its 10)
        ola.ns.DB.char.wish = { done = true, pet = PANDA, day = ola.ns.Today() }
        return w, ola, ola.ns.Bond
    end
    -- n of a liked activity (the panda likes herbs and fishing: Personality), each counted.
    local function Liked(w, ola, id, n)
        for _ = 1, n do ola.ns.Activity:Emit(id, 1) end
        w:RunTimers()
    end

    test("below the top: no loyalty points, and the day's limit holds", function()
        local w, ola, B = Setup()
        ola:SetBond(PANDA, 2000)
        eq(B:Loyalty(PANDA), nil)
        Liked(w, ola, "herb", 6); Liked(w, ola, "fish", 6); Liked(w, ola, "cuddle", 6)
        local today, max = B:Today(PANDA)
        eq(today, max, "the day full at 75")
        ok(ola:Printed("fullt for i dag", true), "and said so")
    end)

    test("at the top: counting on from the bond's points, past the day's 75, each like still at most 25 a day", function()
        local w, ola, B = Setup()
        ola:SetBond(PANDA, TOP + 50)
        eq(B:Loyalty(PANDA), TOP + 50, "from the bond's points")
        local start, p0 = B:Loyalty(PANDA), ola:Points(PANDA)
        Liked(w, ola, "herb", 6); Liked(w, ola, "fish", 6); Liked(w, ola, "cuddle", 6)
        eq(B:Loyalty(PANDA) - start, 75, "25 for each like: the per-activity caps stay")
        Liked(w, ola, "quest", 3) -- (not liked: 1 each, the everyday pot)
        local lp = B:Loyalty(PANDA)
        ok(lp > start + 75, "past the day's 75: " .. lp - start)
        eq(B:LoyalToday(PANDA), lp - start, "today's loyalty points")
        local today, max = B:Today(PANDA)
        ok(today <= max, "the bond's own points keep their day")
        ok(ola:Points(PANDA) - p0 <= max, "and the wire's cap: only the day's share in the bond")
        eq(ola:CountPrinted("fullt for i dag"), 0, "no full day at the top")
        -- The wish's 10 (past the day anyway): all of it.
        local before = B:Loyalty(PANDA)
        B:Reward("wish", PANDA, false)
        eq(B:Loyalty(PANDA) - before, 10)
        -- Kept on this client only: not in the bond's entry, nothing new on the wire.
        local e = ola.ns.Registry:Life(PANDA, "Ola Nord")
        eq(e.lp, nil); eq(ola.ns.DB:Guild().loyal["Ola Nord"][PANDA], B:Loyalty(PANDA))
        local sent = 0
        for _, m in ipairs(w.wire) do
            if m.kind == "BOND" then sent = sent + 1; eq(m.msg.e.lp, nil, "no loyalty points in a BOND") end
        end
        ok(sent > 0, "its bond went out, as before")
        eq(B:LoyaltyTotal(), B:Loyalty(PANDA), "the character's total: one pet at the top")
        -- Kept across a reload.
        local kept = B:Loyalty(PANDA)
        ola:Reload()
        eq(ola.ns.Bond:Loyalty(PANDA), kept)
    end)

    test("a pet you haven't adopted counts at its half rate", function()
        local w, ola, B = Setup()
        ola:SetBond(KITTEN, TOP)
        ola:Summon(46); w:Run(2)
        local start = B:Loyalty(KITTEN)
        Liked(w, ola, "fish", 8)
        eq(B:Loyalty(KITTEN) - start, math.ceil(ola.ns.Config.BOND_LIKED_CAP * ola.ns.Config.BOND_OTHER_RATE))
    end)

    test("the card: a counter for the bar, a gold star for the 7, the numbers rising; the tooltip says 7/7", function()
        local w, ola, B = Setup()
        ola:SetBond(PANDA, TOP + 1234)
        local card = ola:SelectPet(5159)
        local b = card.bond
        ok(b.count:IsShown()); eq(b.count.text, "3 484 lojalitetspoeng")
        no(b.bg:IsShown()); eq(b:GetStatusBarTexture().alpha, 0, "the bar's fill gone")
        ok(b.medal.star:IsShown(), "a gold star"); no(b.level:IsShown(), "for the number")
        local tip = ola:TipOf(b.medal).text
        match(tip, "^Bånd: Sjelevenn %(level 7/7%)")
        match(tip, "Lojalitetspoeng: 3 484 / I dag: %+0 / På høyeste level teller")
        -- A gain: the counter goes on, its number rises.
        Liked(w, ola, "herb", 1)
        card = ola:SelectPet(5159)
        eq(b.count.text, "3 489 lojalitetspoeng")
        w:Run(1)
        local rising
        for _, f in ipairs(b.numbers or {}) do if f:IsShown() and f.text.text == "+5" then rising = true end end
        ok(rising, "+5 rises")
        -- Below the top: the bar and the number back.
        ola:SetBond(PANDA, 1000)
        card = ola:SelectPet(5159)
        no(b.count:IsShown()); ok(b.bg:IsShown()); eq(b:GetStatusBarTexture().alpha, 1)
        no(b.medal.star:IsShown()); ok(b.level:IsShown())
        match(ola:TipOf(b.medal).text, "^Bånd: Bestevenn %(level 5%)")
    end)

    test("a guildmate's adopted pet at the top: its star, but its bar (their loyalty points aren't sent yet)", function()
        local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 5159 }, journal = true }
        kari:Slash("adopter panda"); w:Run(5)
        ola:SetBond(PANDA, TOP + 100, { who = "Kari Berg" })
        local card = ola:SelectPet(5159)
        local b = card.bond
        ok(b.medal.star:IsShown())
        no(b.count:IsShown(), "no counter: not ours")
        ok(b.bg:IsShown())
    end)

    test("the pet frame: the star and the counter at the top", function()
        local w, ola, B = Setup()
        ola.ns.DB.global.settings.petFrame = true
        local PF = ola.ns.PetFrame
        PF:Apply(); w:Run(2)
        ola:SetBond(PANDA, TOP + 10)
        PF:Bond()
        local bar = PF.frame.bar
        ok(bar.count:IsShown()); eq(bar.count.text, "2 260 lojalitetspoeng")
        ok(bar.star:IsShown()); no(bar.level:IsShown())
        ola:SetBond(PANDA, 500)
        PF:Bond()
        no(bar.count:IsShown()); no(bar.star:IsShown()); ok(bar.level:IsShown())
    end)

    test("numbers in groups of three", function()
        local w, ola = Setup()
        local G = ola.ns.Grouped
        eq(G(7), "7"); eq(G(999), "999"); eq(G(1000), "1 000"); eq(G(12345), "12 345"); eq(G(1234567), "1 234 567")
        eq(G(-1234), "-1 234")
    end)
end
