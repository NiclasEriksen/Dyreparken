-- Test harness: a simulated world with several WoW clients, each running its
-- own copy of the addon, connected by a fake addon-message network.
--
--   local w = H.World()                       -- clock, guild, network
--   local ola = w:AddClient("Ola Nord", { pets = { 5159, 46 } })
--   local kari = w:AddClient("Kari Berg")
--   w:Run(15)                                 -- advance time: OnUpdate, timers, delivery
--   w:Settle("hello")                         -- ... to a named stage of the login (World.SETTLE)
--   local w, ola, kari = H.Setup{ ola = { 5159 }, kari = { 40 } } -- the usual world, settled
--   ola:Slash("claim panda")
--   assert(kari.ns.Registry:Holder("s:5159") == "Ola Nord")
--
-- Pinning a test's world (each holds across c:Reload()):
--   ola:Traits{ "latsabb", "glupsk" }        -- every species' traits (ola:Traits(ids, sid): one species)
--   ola:Companions(H.COMPANIONS)              -- the journal's species and tags (Data/Companions.lua)
--   ola:Fixture(function(ns, c) ... end)      -- any other data change, after load, before ADDON_LOADED
--   ola:Dice(roll, pick)                      -- every chance (ns.random): 0 = yes, the first line
--   ola:QuirksNow()                           -- quirk lines at once, no 45 minutes in the way
--   w:SetDate(2027, 3, 2, 14)                 -- the players' clock (tests run on Europe/Oslo time)
--   ola:Said(text), ola:CountPrinted(text), ola:Points(key, who)
--   ola:TipOf(frame)                          -- hover a frame: its tooltip's lines (.text: joined)
-- Don't replace Personality.Traits or ns.Companions by hand: a reload loses it, and
-- Personality's own rules (Known, likes) are skipped.
--
-- Each client gets its own global environment (setfenv), so its addon
-- files, libraries, SavedVariables and frames are separate. `c.ns` is the
-- addon namespace, `c.env` its globals. The stubs follow the real client as
-- probed on Forever (docs/FOREVER_API.md); keep them realistic.
--
-- Network: GUILD reaches everyone online in the sender's guild (the sender
-- too: WoW echoes your own guild/party addon messages), PARTY/RAID the
-- group, WHISPER one name. Delivery takes LATENCY seconds and keeps order.
-- `w.drop = function(m, recipient) return true end` loses messages.
-- Every message that goes on the wire is also decoded into `w.wire`
-- ({ from, chan, kind, msg, at }) so tests can count traffic.
--
-- The harness lives in tools/test/harness/, one file per concern, loaded in this order:
--   base.lua      the TOC, Load (compiled once), NewEnv, the wire codec, known events, species
--   frames.lua    Frame, Region and animation group stubs; H.NewActor, H.Hardware
--   world.lua     World: clock, timers, guild roster, group, network (H.World, H.Setup)
--   client.lua    Client: login, reload, SavedVariables, invariants, pinning, player state;
--                 BuildEnv runs env/*.lua (core, frames, tooltip, player, calendar, units,
--                 guild, group, system, comm, journal): the stub client API
--   ui.lua        tooltips, nameplates, the pet journal, popups, what's on screen
--   assert.lua    H.eq, H.ok, H.no, H.match, H.converged
-- Each part is `local H, P = ...`: H is this module, P the parts' shared internals (not for specs).
local H, P = {}, {}
P.dir = (debug.getinfo(1, "S").source:match("^@(.-)[^/]*$") or "") .. "harness/"
for _, part in ipairs({ "base", "frames", "world", "client", "ui", "assert" }) do
    assert(loadfile(P.dir .. part .. ".lua"))(H, P)
end
return H
