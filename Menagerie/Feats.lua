local _, ns = ...

-- Feats (2026-11-12, the user, for 0.5): a character's big moments, shared with the pet that's out.
--
--   A feat (Feats.LIST): a major class quest's reward (a stance, a demon, a form, a totem, an epic
--   mount...), learning to ride, and level 60. BOND_FEAT_POINTS (25) once per character, only with a
--   pet out (the user: "only with a pet out"), past the day's 75, not counted in it (Bond.REWARDS.feat.beyond); a line in chat and a moment in
--   the pet's story. Done without a pet out, it's done: no reward later.
--   Flavor only (Quirks' eggs, no points; the user): a trainer visit, a dual-spec switch, a talent
--   reset, and the levels 10 to 50 (egg.kake, likelier the higher the level).
--
-- How they're seen, built without a probe of the moments themselves (the user can't respec, switch
-- spec or visit a trainer for a while), on what the client is known to have (/dp probe api, 2026-11-11):
--   by the spell it teaches  SPELLS_CHANGED, then IsPlayerSpell over the list: every race's copy of a
--                            chain at once (Forever's new pairings have their own quest IDs, 94xxx+)
--   by the quest's ID        QUEST_TURNED_IN: rewards that are items (the totems, a weapon), and the
--                            spells' quests too, in case a spell ID is wrong (both: once)
--   level 60                 PLAYER_LEVEL_UP
-- A wrong ID only never fires. What a character already had when we first looked (FIRST_LOOK seconds
-- after login, once spells have loaded) isn't new: no flood of rewards for a character who did them
-- before installing (or before a feat was added in an update). More than AT_ONCE new at one look can't
-- be real (the spellbook arriving late): those are taken as already had.
-- The IDs are Classic's (Forever uses them: 189, 582, 596 in the log) and Forever's where known
-- (docs/IDEAS.md, 2026-11-12; /dp probe api feats reads them in the client).
local Feats = {}
ns.Feats = Feats

Feats.FIRST_LOOK = 30   -- seconds after login: the spells known then were known before
Feats.AT_ONCE = 2       -- more new feats than this at one look: the spellbook loading, not feats
Feats.SETTLE = 1        -- seconds: SPELLS_CHANGED comes in bursts (a stance, a form); one look after it
Feats.TRAIN_TOGETHER = 60 -- learned-spell lines this close together are one trainer visit
Feats.TRAIN_AFTER_FEAT = 15 -- a feat's own "You have learned" line isn't a trainer visit
Feats.SWAP_QUIET = 10   -- seconds after a spec switch when talents change by themselves (not a reset)
Feats.RESET_JUMP = 2    -- unspent talent points up by this many at once: a reset (a level gives one)
Feats.RESET_RANKS = 2   -- talent ranks taken back in one change: a reset (a level-up only adds one)

-- { id, spells = { spell ids }, quests = { quest ids }, level = n, line = "spell" | "quest" | own }.
-- line: how its chat line and story read (Locale feat.<line>, feat.story.<line>): the spell's name,
-- the quest's title, or a line of its own.
Feats.LIST = {
    -- Warrior: the stances (10, one quest per race; 30), the Whirlwind Axe
    { id = "defstance", spells = { 71 }, quests = { 1503 } },
    { id = "berserker", spells = { 2458 }, quests = { 1719 } },
    { id = "whirlwind", quests = { 1792 }, line = "quest" },
    -- Paladin: Redemption (Forever's Horde copy 94441), Verigan's Fist, the Charger
    { id = "redemption", spells = { 7328 }, quests = { 1788, 94441 } },
    { id = "verigan", quests = { 1806 }, line = "quest" },
    { id = "charger", spells = { 23214 }, quests = { 7647 } },
    { id = "moonsilver", quests = { 95126 }, line = "quest" }, -- (Forever: the Horde paladin's blade)
    -- Hunter: taming (10), Rhok'delar
    { id = "taming", spells = { 1515 }, quests = { 6103 } },
    { id = "rhokdelar", quests = { 7636 }, line = "quest" },
    -- Rogue: poisons (20)
    { id = "poisons", spells = { 2842 }, quests = { 2607, 2609 } },
    -- Priest: Benediction
    { id = "benediction", quests = { 7622 }, line = "quest" },
    -- Shaman: the four totems, by the item itself as it's given ("You receive item:"), whichever race's
    -- chain gave it: every step of a chain has its element's name and Forever adds copies (92466-8,
    -- 94373-5, 96136, 97243 among a level 36 shaman's completed quests, 2026-11-12), so the finals'
    -- ids can't be listed with any certainty. The Classic finals stay, as a second way.
    { id = "earth", items = { 5175 }, quests = { 1518, 1521, 94375 }, line = "totem", totem = "earth" },
    { id = "fire", items = { 5176 }, quests = { 1527 }, line = "totem", totem = "fire" },
    { id = "water", items = { 5177 }, quests = { 220 }, line = "totem", totem = "water" },
    { id = "air", items = { 5178 }, quests = { 1531, 94789 }, line = "totem", totem = "air" },
    -- Mage: the wand
    { id = "wand", quests = { 1952 }, line = "quest" },
    -- Warlock: the demons (every city's "The Binding"), the Orb, the Infernal, the Doomguard, the Dreadsteed
    { id = "voidwalker", spells = { 697 }, quests = { 1689, 1504, 1471 } },
    { id = "succubus", spells = { 712 }, quests = { 1739, 1513, 1474 } },
    { id = "felhunter", spells = { 691 }, quests = { 1795 } },
    { id = "soranruk", quests = { 1740 }, line = "quest" },
    { id = "inferno", spells = { 1122 }, quests = { 7603 } },
    { id = "doom", spells = { 18540 }, quests = { 7583 } },
    { id = "dreadsteed", spells = { 23161 }, quests = { 7631 } },
    -- Druid: the forms (Bear: Forever's Skyborne copy 94638; Cat: Forever's quest at 20)
    { id = "bear", spells = { 5487 }, quests = { 6001, 6002, 94638 } },
    { id = "aquatic", spells = { 1066 }, quests = { 31, 5061 } },
    { id = "cat", spells = { 768 } },
    -- Everyone: riding (from level 10 on Forever, ERR_NO_RIDING_SKILL; both kinds are in the client:
    -- retail's Apprentice and Journeyman, and Classic's per race; /dp probe api feats, 2026-11-12), level 60
    { id = "riding", line = "riding", spells = { 33388, 33391, 824, 825, 826, 828, 10861, 10906, 10907, 18995 } },
    { id = "level60", line = "level60", level = 60 },
}
Feats.BY_ID, Feats.BY_QUEST, Feats.BY_ITEM = {}, {}, {}
for _, f in ipairs(Feats.LIST) do
    Feats.BY_ID[f.id] = f
    for _, q in ipairs(f.quests or {}) do Feats.BY_QUEST[q] = f end
    for _, i in ipairs(f.items or {}) do Feats.BY_ITEM[i] = f end
end

local Plain = ns.Plain
local ready = false -- the first look is done: from now on, what's new is a feat
local function Done(id) return ns.DB.char.feats[id] ~= nil end

local function Known(id)
    if type(id) ~= "number" then return false end
    for _, fn in ipairs({ IsPlayerSpell, IsSpellKnown }) do
        if type(fn) == "function" then
            local ok, v = pcall(fn, id)
            if ok and Plain(v) then return true end
        end
    end
    return false
end

-- Has the character got it now (by spell or level; a quest only says so as it's handed in)?
function Feats:Has(f)
    if f.level then return (Plain(UnitLevel("player")) or 0) >= f.level end
    for _, id in ipairs(f.spells or {}) do if Known(id) then return id end end
    return false
end

-- Feats had now and not counted: { f, ... }.
function Feats:Look()
    local found = {}
    for _, f in ipairs(self.LIST) do
        if not Done(f.id) then
            local how = self:Has(f)
            if how then found[#found + 1] = { f = f, spell = type(how) == "number" and how or nil } end
        end
    end
    return found
end

local function Record(id, before, what)
    ns.DB.char.feats[id] = { t = ns.Now(), before = before or nil, what = what }
end

-- Done before we looked, by its quests' completed flags (they work on Forever: /dp probe api feats,
-- 2026-11-12) or the item in the bags.
function Feats:HadBefore(f)
    local flagged = C_QuestLog and C_QuestLog.IsQuestFlaggedCompleted
    for _, q in ipairs(f.quests or {}) do
        if flagged then
            local ok, v = pcall(flagged, q)
            if ok and Plain(v) then return true end
        end
    end
    local count = C_Item and C_Item.GetItemCount
    for _, i in ipairs(f.items or {}) do
        if count then
            local ok, n = pcall(count, i)
            n = ok and Plain(n)
            if type(n) == "number" and n > 0 then return true end
        end
    end
    return false
end

-- The first look: whatever the character has now, or did before, it had before.
function Feats:FirstLook()
    for _, got in ipairs(self:Look()) do Record(got.f.id, true) end
    for _, f in ipairs(self.LIST) do
        if not Done(f.id) and self:HadBefore(f) then Record(f.id, true) end
    end
    ready = true
    Feats.unspent = Feats.Unspent()
    Feats.ranks = Feats.Ranks()
    ns.Log("Feats", "first look: %d feats already had", self:Count())
end

function Feats:Count()
    local n = 0
    for _ in pairs(ns.DB.char.feats) do n = n + 1 end
    return n
end

-- What its line names: the spell's name or the quest's title as the client has it, else the id.
function Feats:What(f, spell, quest)
    if spell then return ns.SpellName(spell) or tostring(spell) end
    for _, id in ipairs(f.spells or {}) do
        local name = ns.SpellName(id)
        if name then return name end
    end
    local q = quest or (f.quests and f.quests[1])
    local get = C_QuestLog and C_QuestLog.GetTitleForQuestID
    local title = q and get and Plain(get(q))
    if type(title) == "string" and title ~= "" then return title end
    return f.id
end

-- Seen: recorded now (so a second look in the meantime doesn't count it again), counted with the
-- pet that's out once out of combat (Activity:Emit).
function Feats:Got(f, spell, quest)
    if Done(f.id) then return end
    local what = self:What(f, spell, quest)
    Record(f.id, false, what)
    self.lastAt = GetTime()
    ns.Log("Feats", "%s: %s", f.id, tostring(what))
    ns.Activity:Emit("feat", 1, f.id)
end

local looking = false
function Feats:LookSoon()
    if looking or not ready then return end
    looking = true
    C_Timer.After(self.SETTLE, function()
        looking = false
        local found = Feats:Look()
        if #found > Feats.AT_ONCE then
            ns.Log("Feats", "%d new at once: taken as already had", #found)
            for _, got in ipairs(found) do Record(got.f.id, true) end
            return
        end
        for _, got in ipairs(found) do Feats:Got(got.f, got.spell) end
    end)
end

-- An item given to you or looted (LOOT_ITEM_PUSHED_SELF "You receive item: %s", LOOT_ITEM_SELF...):
-- its id from the link. Your own lines only: others' loot reads "X receives ...".
function Feats.ItemOf(text)
    text = Plain(text)
    if type(text) ~= "string" then return nil end
    for _, global in ipairs({ "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE",
        "LOOT_ITEM_SELF_MULTIPLE" }) do
        local pattern = ns.Activity.FormatPattern(_G[global])
        local link = pattern and text:match(pattern)
        local id = link and tonumber(link:match("|Hitem:(%d+)"))
        if id then return id end
    end
end

ns.Activity:Source({ id = "feat", events = { "SPELLS_CHANGED", "QUEST_TURNED_IN", "PLAYER_LEVEL_UP", "CHAT_MSG_LOOT" },
    filter = function(event, a)
        if event == "SPELLS_CHANGED" then return Feats:LookSoon() end
        if event == "CHAT_MSG_LOOT" then
            local f = Feats.BY_ITEM[Feats.ItemOf(a)]
            if f and ready then Feats:Got(f) end
            return nil
        end
        if event == "QUEST_TURNED_IN" then
            local f = Feats.BY_QUEST[Plain(a)]
            if f then Feats:Got(f, nil, Plain(a)) end
            return nil
        end
        if Plain(a) == 60 then Feats:Got(Feats.BY_ID.level60) end
    end })

-- The reward, with the pet that was out (Activity's ACTIVITY carries it).
function Feats:OnFeat(id, key)
    local f, rec = self.BY_ID[id], ns.DB.char.feats[id]
    if not (f and rec) then return end
    if not key then return ns.Log("Feats", "%s with no pet out: no reward", id) end
    rec.key = key
    local name = ns.Registry:NameOf(key)
    local line = f.line or "spell"
    local vars = { pet = name, what = rec.what, totem = f.totem and ns.L["feat.totem." .. f.totem],
        n = math.ceil(ns.Config.BOND_FEAT_POINTS * ns.Bond:Rate(key)) }
    ns.Bond:Reward("feat", key, ns.T("feat." .. line, vars))
    ns.Story:Mine(key, "feat", ns.T("feat.story." .. line, vars), id)
    ns.Bus:Fire("FEAT", id, key)
end

------------------------------------------------------------------------------
-- Flavor: a trainer visit, a dual-spec switch, a talent reset (Quirks' eggs; no points)
------------------------------------------------------------------------------
-- The trainer: its window opening (PLAYER_INTERACTION_MANAGER_FRAME_SHOW with
-- Enum.PlayerInteractionType.Trainer, 7 on Forever: /dp probe api feats, 2026-11-12), or "You have learned
-- a new spell/ability: %s." in system chat (ERR_LEARN_SPELL_S/ABILITY_S are in the client; that it prints
-- them there is unverified). A visit's window and lines are one.
local lastTrain
local function TrainerType()
    local E = rawget(_G, "Enum")
    return E and E.PlayerInteractionType and E.PlayerInteractionType.Trainer or nil
end
ns.Activity:Source({ id = "train", events = { "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "CHAT_MSG_SYSTEM" },
    filter = function(event, text)
        local name
        if event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
            if Plain(text) ~= TrainerType() or TrainerType() == nil then return nil end
            name = "trainer"
        else
            text = Plain(text)
            if type(text) ~= "string" then return nil end
            for _, global in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S" }) do
                local pattern = ns.Activity.FormatPattern(_G[global])
                name = name or (pattern and text:match(pattern))
            end
        end
        if not name then return nil end
        local now = GetTime()
        local together = lastTrain and now - lastTrain < Feats.TRAIN_TOGETHER
        lastTrain = now
        if together or (Feats.lastAt and now - Feats.lastAt < Feats.TRAIN_AFTER_FEAT) then return nil end
        return 1, name
    end })

-- Dual spec (Forever: from level 40): ACTIVE_TALENT_GROUP_CHANGED (current, previous) is in the client.
ns.Activity:Source({ id = "specswap", events = { "ACTIVE_TALENT_GROUP_CHANGED" },
    filter = function(_, now, before)
        now, before = Plain(now), Plain(before)
        if not ready or type(now) ~= "number" or now == before then return nil end
        Feats.swapAt = GetTime()
        return 1, now
    end })

-- A talent reset. Forever's talents are retail's system with Classic trees (/dp probe api feats,
-- 2026-11-12: an active config, "Reset All Talents", left and right trees, rest areas only), and a change
-- can't be applied with points unspent (ERR_TALENT_FAILED_UNSPENT_TALENT_POINTS): a reset in the talent
-- frame is a refund and new picks in one change. So each applied change (TRAIT_CONFIG_UPDATED) is
-- compared with the ranks before it: RESET_RANKS or more taken back is a reset. Another config (the other
-- spec's) is a switch, not a reset. A trainer's "unlearn all" (CONFIRM_TALENT_WIPE's dialog) leaves points
-- unspent: the unspent points jumping as the spells change (GetNumUnspentTalents) is that one.
-- Not after a spec switch either way (each spec has its own).
function Feats.Ranks()
    local CT, TR = rawget(_G, "C_ClassTalents"), rawget(_G, "C_Traits")
    if not (CT and TR and CT.GetActiveConfigID and TR.GetConfigInfo and TR.GetTreeNodes and TR.GetNodeInfo) then return nil end
    local ok, result = pcall(function()
        local config = Plain(CT.GetActiveConfigID())
        local info = config and TR.GetConfigInfo(config)
        if type(info) ~= "table" or type(info.treeIDs) ~= "table" then return nil end
        local ranks = { config = config }
        for _, tree in ipairs(info.treeIDs) do
            for _, node in ipairs(TR.GetTreeNodes(tree) or {}) do
                local n = TR.GetNodeInfo(config, node)
                local r = type(n) == "table" and Plain(n.activeRank or n.currentRank)
                if type(r) == "number" and r > 0 then ranks[node] = r end
            end
        end
        return ranks
    end)
    return ok and result or nil
end

-- Ranks taken back from one snapshot to the next (nil: another config, or none to compare).
function Feats.TakenBack(before, after)
    if not (before and after) or before.config ~= after.config then return nil end
    local n = 0
    for node, r in pairs(before) do
        if node ~= "config" then n = n + math.max(0, r - (after[node] or 0)) end
    end
    return n
end

function Feats.Unspent()
    if type(GetNumUnspentTalents) ~= "function" then return nil end
    local ok, n = pcall(GetNumUnspentTalents)
    n = ok and Plain(n)
    return type(n) == "number" and n or nil
end
ns.Activity:Source({ id = "respec", events = { "SPELLS_CHANGED", "TRAIT_CONFIG_UPDATED" },
    filter = function(event)
        if not ready then return nil end
        local quiet = Feats.swapAt and GetTime() - Feats.swapAt < Feats.SWAP_QUIET
        if event == "TRAIT_CONFIG_UPDATED" then
            local now = Feats.Ranks()
            local back = Feats.TakenBack(Feats.ranks, now)
            Feats.ranks = now or Feats.ranks
            ns.Log("Feats", "talents changed: %s ranks taken back", tostring(back))
            if quiet or not back or back < Feats.RESET_RANKS then return nil end
            return 1, back
        end
        local n, last = Feats.Unspent(), Feats.unspent
        Feats.unspent = n
        if not (n and last) or n - last < Feats.RESET_JUMP or quiet then return nil end
        return 1, n
    end })

function Feats:Init()
    ns.Activity:Want("feat", Feats)
    ns.Bus:On("ACTIVITY", function(id, _, key, _, extra) if id == "feat" then Feats:OnFeat(extra, key) end end)
    C_Timer.After(self.FIRST_LOOK, function() Feats:FirstLook() end)
end

ns.Start("login", function() Feats:Init() end)
