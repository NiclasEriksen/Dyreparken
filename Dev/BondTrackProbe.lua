local _, ns = ...

-- The bond track's previews (development only, never packaged:
-- #@do-not-package@ in the TOC). They extend ns.BondTrack.
local Track = ns.BondTrack

-- /dp probe gains [n n ...]: the gains animation on the card's pet as if these
-- were gained since the last look (development; saves nothing).
function Track:PreviewGains(arg)
    local card = ns.JournalUI._card
    if not (card and card.key and card.bond and card.bond:IsShown()) then
        return ns.Print("Open a pet's card with a bond bar first.")
    end
    local list = {}
    for n in (arg or "5 10 25"):gmatch("%d+") do list[#list + 1] = tonumber(n) end
    if #list == 0 then list = { 5, 10, 25 } end
    local points, _, _, from, nextAt = ns.Bond:Shown(card.key)
    local sum = 0
    for _, n in ipairs(list) do sum = sum + n end
    self:Animate(card, points, from, nextAt or math.max(points, 1), points - sum, list)
    ns.Print(("Gains preview: %s on %s."):format(table.concat(list, ", "), card.key))
end

-- /dp probe celebrate: the celebration on the card as it is (development).
function Track:Preview()
    local card = ns.JournalUI._card
    if not (card and card.key and card.celebration) then
        return ns.Print("Open the pet card first.")
    end
    local _, level = ns.Bond:Shown(card.key)
    self:Celebrate(card, card.key, ns.Decor.preview or level or 1)
end
