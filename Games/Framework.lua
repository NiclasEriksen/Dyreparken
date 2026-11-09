local _, ns = ...

-- Party games framework.
--
-- A game is a definition table registered with ns.Games:Define:
--   ns.Games:Define({
--       id = "hideandseek",          -- stable, used on the wire and in history
--       name = "Hide and Seek",
--       minVersion = "0.0.1",        -- players below this are told to update
--       ui = { hide = { "Minimap" }, cvars = { nameplateShowFriends = "0" } },
--       OnStart = function(game, session) end,     -- every participant
--       OnMessage = function(game, session, msg, sender) end,
--       OnEnd = function(game, session, result) end,
--   })
--
-- Lifecycle: the leader (raid/party leader or assist) runs /dp game start <id>.
--   GAME_START { id, sid, at, minVersion }  -> participants check version,
--                                              apply UI changes, OnStart
--   GAME_MSG   { sid, ... }                 -> game-specific traffic
--   GAME_END   { sid, result }              -> restore UI, OnEnd, history
-- Restoring UI also happens on logout/reload mid-game: the stash is saved,
-- and anything left in it is restored at the next login.
--
-- result = { kind = "single"|"teams"|"ranked", ranking = { {names...}, ... }, notes = s? }
--   single: ranking[1] = { winner }
--   teams:  ranking[1] = winning team's names (teams map in result.teams)
--   ranked: ranking[n] = names in nth place (ties share a place)
--
-- Building blocks (TODO, add as games need them): countdown, timer, scoreboard,
-- item-count tracking (BAG_UPDATE_DELAYED, only while a game runs), zone/area
-- check, raid warnings.
local Games = { defs = {}, active = nil }
ns.Games = Games

function Games:Define(def)
    assert(type(def.id) == "string" and def.name, "game needs id and name")
    self.defs[def.id] = def
end

function Games:CanLead()
    return UnitIsGroupLeader("player") or UnitIsGroupAssistant("player")
end

-- UI changes a game asked for, saved so they can be undone even after a crash.
local UIState = {}
Games.UIState = UIState

function UIState:Apply(spec)
    local stash = { cvars = {}, hidden = {} }
    ns.DB.global.games.stash = stash
    for cvar, value in pairs(spec.cvars or {}) do
        stash.cvars[cvar] = C_CVar.GetCVar(cvar)
        C_CVar.SetCVar(cvar, value)
    end
    -- Hiding protected frames is blocked in combat: queue it.
    ns.Events:OutOfCombat(function()
        for _, name in ipairs(spec.hide or {}) do
            local f = _G[name]
            if f and f:IsShown() then
                stash.hidden[#stash.hidden + 1] = name
                f:Hide()
            end
        end
    end)
end

function UIState:Restore()
    local stash = ns.DB.global.games.stash
    if not stash then return end
    for cvar, value in pairs(stash.cvars) do C_CVar.SetCVar(cvar, value) end
    ns.Events:OutOfCombat(function()
        for _, name in ipairs(stash.hidden) do
            local f = _G[name]
            if f then f:Show() end
        end
        ns.DB.global.games.stash = nil
    end)
end

function Games:Record(def, session, result)
    local history = ns.DB.global.games.history
    history[#history + 1] = {
        id = def.id, sid = session.sid, at = session.at, ended = ns.Now(),
        leader = session.leader, result = result,
    }
end

function Games:Init()
    -- A stash left over from a game that never ended (reload, crash, disconnect).
    UIState:Restore()
    -- TODO: GAME_START / GAME_MSG / GAME_END handlers, version gate, start/end commands.
end

ns.Start("loaded", function() Games:Init() end)
