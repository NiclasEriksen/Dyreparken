---@class Dyreparken
local ns = select(2, ...)

-- A new player's first steps (2026-11-19, review 05 2.1, the user: "1+2+3, but obviously don't show this for
-- players who already adopted a pet. Give me a command to test it"): a new member saw nothing at all, and the
-- first word after adopting was "Du adopterte Panda Cub." Three small things:
--   * once an account, after the login: what Dyreparken is and where it lives (DyreparkenDB.welcomed);
--   * once a character, right after its first adoption: how the bond grows (char.toldAdoptHow);
--   * a "?" on the card, under the story's book: how to bond with this pet (likes, today's wish, playdates),
--     on hover only.
-- An account or character that had Dyreparken before this came isn't new: the migrations set both flags
-- (DB.lua, account 15, char 4). /dp fresh (Dev/Commands.lua) replays them as a new player sees them.
---@class Dyreparken.Onboarding
local Onboarding = {}
ns.Onboarding = Onboarding

local L = ns.L
Onboarding.SAY_AFTER = 0.5 -- seconds after the adoption's own line

-- force: said again (/dp fresh), solo: as outside a guild.
-- A member with no pet at all is told where they come from, not to adopt one (review 2026-11-24 Q18: three in the
-- guild were).
function Onboarding:Welcome(force, solo)
    local db = ns.DB.global
    if db.welcomed and not force then return end
    db.welcomed = true
    if ns.Registry:MyPet() and not force then return end -- (an old hand on a new install: nothing to tell)
    local guild = IsInGuild() and not solo
    ns.Print(L[not guild and "welcome.solo" or next(ns.Pets:Owned()) == nil and "welcome.nopets" or "welcome.guild"])
    ns.Print(L["welcome.where"])
end

-- A minute after the login, out of a fight (review 2026-11-24 Q17: at 10 s it came among the guild's message of the
-- day, other addons' banners and the login's own lines).
Onboarding.WELCOME_AFTER = 60

function Onboarding:AfterAdopt(key, force)
    local char = ns.DB.char
    if char.toldAdoptHow and not force then return end
    char.toldAdoptHow = true
    C_Timer.After(self.SAY_AFTER, function()
        ns.Print(ns.T("welcome.adopted", { pet = ns.Registry:NameOf(key), day = ns.Config.BOND_DAY_POINTS,
            max = ns.Config.BOND_DAILY_MAX }))
    end)
end

-- Forgotten: the next login and adoption are a new player's again (/dp fresh reset).
function Onboarding:Forget() ns.DB.global.welcomed, ns.DB.char.toldAdoptHow = nil, nil end

-- The "?"'s tooltip: how this pet's bond grows, from what's known of it.
function Onboarding.HelpLines(key)
    if not key then return nil end
    local C, name = ns.Config, ns.Registry:NameOf(key)
    -- (at this pet's rate: one you haven't adopted earns half, review 2026-11-24 Q13: every card said an adopted pet's)
    local rate = ns.Bond:Rate(key)
    local function At(v) return math.ceil(v * rate) end
    local lines = { { ns.T("help.title", { pet = name }), 1, 0.82, 0 },
        { ns.T("help.day", { pet = name, n = At(C.BOND_DAY_POINTS), max = ns.Bond:DailyMax(key) }), 1, 1, 1, true } }
    if rate < 1 then lines[#lines + 1] = { ns.T("help.half", { pet = name }), 0.8, 0.8, 0.8, true } end
    if ns.Personality:Known(key) then
        local likes = ns.Personality:LikedWords(key)
        if #likes > 0 then
            lines[#lines + 1] = { ns.T("help.likes", { pet = name, list = table.concat(likes, ns.L["list.sep"]) }), 1, 1, 1, true }
        end
    else
        lines[#lines + 1] = { L["help.unknown"], 0.8, 0.8, 0.8, true }
    end
    local w = key == ns.Registry:MyPet() and ns.Wish:Today()
    if w and w.id then
        lines[#lines + 1] = { w.done and L["wish.done"] or ns.T("help.wish", { line = ns.Wish.Line(w), n = C.BOND_WISH_POINTS }),
            1, 1, 1, true }
    elseif ns.Registry:Status(key) ~= "mine" then
        lines[#lines + 1] = { L["help.wish.adopt"], 0.8, 0.8, 0.8, true }
    end
    lines[#lines + 1] = { ns.T("help.play", { n = At(C.BOND_PLAY_POINTS) }), 1, 1, 1, true }
    lines[#lines + 1] = { ns.T("help.pat", { n = At(C.BOND_PAT_POINTS) }), 1, 1, 1, true }
    return lines
end

-- The card's "?" (a widget: Card.lua).
local SIZE = 24
function Onboarding:Build(card, c)
    local b = ns.RoundBadge(c, SIZE, { disc = 2, ring = true, ringOver = true, hover = { 1, 0.85, 0.5, 0.5 } })
    b.q = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    b.q:SetPoint("CENTER", b, "CENTER", 1, 0)
    b.q:SetText("?")
    b:SetPoint("TOP", card.story or c, card.story and "BOTTOM" or "TOPRIGHT", card.story and 0 or -34, -8)
    b:SetFrameLevel(c:GetFrameLevel() + 30)
    ns.SetTip(b, "ANCHOR_LEFT", function() return Onboarding.HelpLines(card.key) end)
    b:Hide()
    card.help = b
end

function Onboarding:Update(card, key)
    if card.help then card.help:SetShown(key ~= nil) end
end

ns.Card.Register({
    id = "help",
    build = function(card, c) Onboarding:Build(card, c) end,
    update = function(card, key) Onboarding:Update(card, key) end,
    still = true,
})

ns.Start("loaded", function()
    ns.Bus:On("ADOPTED", function(key) Onboarding:AfterAdopt(key) end)
end)
-- (after the login's own lines: the milestones and the pet of the day come at 30 s, Bonds.lua)
ns.Start("settled", function()
    if ns.DB.global.welcomed then return end
    C_Timer.After(Onboarding.WELCOME_AFTER, function() ns.Events:OutOfCombat(function() Onboarding:Welcome() end) end)
end)
