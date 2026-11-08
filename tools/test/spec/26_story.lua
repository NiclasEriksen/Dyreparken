-- Your story with a pet, on its card (2026-11-08): what you've done together
-- (Stats.lua), today's wish (Wish.lua), and petting it on the card.
return function(test, H)
    local eq, ok, no, match = H.eq, H.ok, H.no, H.match
    local PANDA = "s:5159"

    local function Setup()
        local w = H.World()
        local ola = w:AddClient("Ola Nord", { pets = { 5159, 40 } })
        local kari = w:AddClient("Kari Berg", { pets = { 40 } })
        w:Run(20)
        ola:Slash("adopter panda")
        w:Run(5)
        ola:OpenJournal()
        return w, ola, kari
    end

    local function Shown(row)
        local list = {}
        for _, chip in ipairs(row.chips) do if chip:IsShown() then list[#list + 1] = chip end end
        return list
    end

    test("the chips: days out together first, then the biggest counts, yours only", function()
        local w, ola, kari = Setup()
        local card = ola:SelectPet(5159)
        no(card.stats:IsShown(), "nothing done together yet")
        ola.ns.Activity:CheckDay()
        for _ = 1, 3 do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", 2366) end
        ola:Fire("ENCOUNTER_END", 1, "Hogger", 1, 5, 1)
        card = ola:SelectPet(5159)
        ok(card.stats:IsShown())
        local chips = Shown(card.stats)
        eq(#chips, 3)
        eq(chips[1].id, "day"); eq(chips[1].count.text, 1)
        eq(chips[2].id, "herb"); eq(chips[2].count.text, 3)
        eq(chips[3].id, "boss")
        eq(chips[2].icon.tex, "Interface\\Icons\\Trade_Herbalism")
        chips[2].scripts.OnEnter(chips[2])
        eq(ola.env.GameTooltip.lines[1], "3 herbs sammen med Panda Cub")
        chips[1].scripts.OnEnter(chips[1])
        eq(ola.env.GameTooltip.lines[1], "1 dager ute sammen med Panda Cub")
        -- At the top; under the ribbon when there is one.
        eq(card.stats.points[1][3], "TOP"); eq(card.stats.points[1][5], -14)
        ola:Slash("probe level 6")
        eq(card.stats.points[1][2], card.decor.ribbon, "under the ribbon")
        ola:Slash("probe level off")
        -- At most five, the biggest.
        for _, id in ipairs({ 2575, 7620, 8613 }) do ola:Fire("UNIT_SPELLCAST_SUCCEEDED", "player", "Cast", id) end
        ola:Fire("QUEST_TURNED_IN", 1); ola:Fire("QUEST_TURNED_IN", 2)
        card = ola:SelectPet(5159)
        chips = Shown(card.stats)
        eq(#chips, 5)
        eq(chips[1].id, "day"); eq(chips[2].id, "herb"); eq(chips[3].id, "quest")
        -- A missing icon: a question mark, not a hole.
        ola.missingFiles = { ["Interface\\Icons\\Trade_Herbalism"] = true }
        card = ola:SelectPet(5159)
        eq(Shown(card.stats)[2].icon.tex, "Interface\\Icons\\INV_Misc_QuestionMark")
        -- Kari has done nothing with the panda: no chips for her.
        kari:OpenJournal()
        kari:GivePet(5159)
        no(kari:SelectPet(5159).stats:IsShown())
        -- No pet selected: hidden.
        local c = ola.env.PetJournalPetCard
        c.speciesID, c.petID = nil, nil
        ola.env.PetJournal_UpdatePetCard(c)
        no(card.stats:IsShown())
    end)
end
