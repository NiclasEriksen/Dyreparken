local _, ns = ...

-- The pet card's widgets, each registered once (Phase 4 of docs/REFACTOR.md). A widget used to
-- appear in up to four places: its Build in JournalUI, a line in its update list, a line in the
-- side page's pause list and an OnHide hook of its own. They drifted: opening one of our pages
-- stopped the decorations but not the bond's celebration or a cuddle's hearts (B14).
--
--   ns.Card.Register{ id, build = fn(card, c), update = fn(card, key, ctx),
--                     pause = fn(card), stop = fn(card), still = true }
--
-- build    once, when the card is made (c: Blizzard's PetJournalPetCard; card.panel once "panel"
--          has built it)
-- update   the card shows a pet (key), or none (nil). ctx: { level = the bond level shown,
--          tint = the family's color (set by "scenes", which runs first) }
-- stop     the card hides (the window closes): every animation and timer ends
-- pause    one of our pages covers the card (SidePage); stop when not given. The card is drawn
--          anew when the page closes.
-- still    nothing to stop: no animation, no timer. A widget declares this or a stop or pause, so
--          a new one can't forget it (tools/test/spec/53_card.lua).
--
-- They run in ORDER, the one place the order is written. Builds and updates depend on it: the
-- chips go under the decor's ribbon, the wish under the chips, the crown beside the cake, the
-- cuddle needs the model the "rotate" step finds, and the bond's celebration cheers before the
-- pet's pose (moves) is set.
local Card = {}
ns.Card = Card

Card.ORDER = {
    "scenes",  -- the backdrop behind the model (Scenes.lua)
    "panel",   -- the dark sheet along the bottom (JournalUI)
    "decor",   -- borders, glows, particles (Decor.lua)
    "stats",   -- the activity chips (Stats.lua)
    "wish",    -- today's wish, under the chips (Wish.lua)
    "bond",    -- the medallion, the stars, the bar, the celebration (BondTrack.lua)
    "outbadge", -- "Med deg" (OutBadge.lua)
    "cake",    -- a cake on its milestone day (Cake.lua)
    "crown",   -- the pet of the day's crown, beside the cake (Crown.lua)
    "story",   -- the story's button (Story.lua)
    "moves",   -- the pet's pose (Moves.lua, registered by JournalUI)
    "rows",    -- the name, home, traits and likes, and their hovers (JournalUI)
    "rotate",  -- Blizzard's turn buttons and title row moved out of the way (JournalUI)
    "cuddle",  -- a click on the pet (Cuddle.lua: needs the model "rotate" found)
    "actions", -- Adopter / Gi slipp, Kallenavn (CardActions.lua)
}
local byId = {}

local function Listed(id)
    for _, o in ipairs(Card.ORDER) do if o == id then return true end end
end

function Card.Register(spec)
    assert(type(spec) == "table" and Listed(spec.id), "Card.Register: an id from Card.ORDER")
    assert(not byId[spec.id], "Card.Register: " .. tostring(spec.id) .. " registered twice")
    assert(spec.stop or spec.pause or spec.still,
        "Card.Register: " .. spec.id .. " needs a stop or a pause (or still = true)")
    byId[spec.id] = spec
end

-- The registered widgets, in order.
function Card:List()
    local list = {}
    for _, id in ipairs(self.ORDER) do
        if byId[id] then list[#list + 1] = byId[id] end
    end
    return list
end

function Card:Get(id) return byId[id] end

local function Each(field, ...)
    for _, id in ipairs(Card.ORDER) do
        local w = byId[id]
        local fn = w and w[field]
        if fn then fn(...) end
    end
end

-- Built once; the card's one OnHide stops them all.
function Card:Build(card, c)
    for _, id in ipairs(self.ORDER) do
        assert(byId[id], "Card: " .. id .. " was never registered")
    end
    Each("build", card, c)
    c:HookScript("OnHide", function() Card:Stop(card) end)
end

function Card:Update(card, key, ctx) Each("update", card, key, ctx) end

function Card:Stop(card) Each("stop", card) end

-- Under one of our pages: each widget's pause, else its stop.
function Card:Pause(card)
    for _, id in ipairs(self.ORDER) do
        local w = byId[id]
        local fn = w and (w.pause or w.stop)
        if fn then fn(card) end
    end
end
