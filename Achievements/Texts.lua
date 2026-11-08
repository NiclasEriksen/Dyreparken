local _, ns = ...

-- Every text players see for achievements, in one place so they're easy to
-- rename (decided 2026-11-06: Norwegian). Keyed by achievement id
-- (Defs.lua). Ids never change; everything here may.
--
--   name    shown in brackets: [Alle kattene]
--   desc    what it takes, shown on the page
--   flavor  the guild chat line when shared. Placeholders:
--             {player}    the earner ("Ola Nord")
--             {name}      the name in brackets ("[Alle kattene]")
--             {progress}  "12/12"
--             {guild}     the guild's name (guild achievements)
--           Without a flavor the generic "share" line below is used.
--
-- The generic lines are format strings (%s), not placeholders.
ns.AchTexts = {
    generic = {
        earned_one = "%s fikk %s!",                    -- Ola Nord fikk [Alle kattene]!
        earned_many = "%s fikk %s og %s!",             -- Ola Nord fikk [A], [B] og [C]!
        share = "{player} fikk {name}!",               -- guild chat, when an achievement has no flavor
        share_hint = "Del det i guild-chatten med /dp prestasjoner del.",
        already = "Du har allerede %d prestasjoner fra før. Se dem med /dp prestasjoner.",
        none_to_share = "Ingen nye prestasjoner å dele.",
        not_in_guild = "Du er ikke i en guild.",
        notify_on = "Andre med Dyreparken får beskjed når du får en prestasjon.",
        notify_off = "Andre med Dyreparken får ikke lenger beskjed om prestasjonene dine.",
        list_header = "Prestasjoner (%d av %d):",
        days = "%d/%d dager",
        guild_earned = "%s fikk %s!",                  -- Dyreparken fikk [Kattehuset]!
        guild_hint = "Som offiser kan du dele det i guild-chatten med /dp prestasjoner del.",

        -- Families in the plural, for "Mest populære familie" (Menagerie/ParkPage.lua).
        families = { cat = "katter", farm = "gårdsdyr", owl = "ugler", rabbit = "kaniner", snake = "slanger",
            frog = "frosker og padder", mechanical = "mekaniske kjæledyr", dragon = "drager", bird = "fugler",
            pirate = "piratkjæledyr" },

        -- The page in the Collections window (Page.lua)
        page_title = "Prestasjoner",
        page_count = "Fått",
        cat_collection = "Samlingen",
        cat_family = "Familier",
        cat_loyalty = "Lojalitet",
        cat_guild = "Guilden",
        share_button = "Del",
        share_button_tip = "Del det i guild-chatten.",
        tip_earned = "Fått %s",
        tip_shared = "Delt i guild-chatten.",
        tip_missing = "Mangler:",
        tip_no_home = "trenger et hjem",
        tip_no_home_title = "Trenger et hjem:",
        tip_more = "... og %d til",
    },

    -- Collection: pets you own that can be got in game (Data/Companions.lua).
    ["count:10"] = { name = "Ti små venner", desc = "Ha 10 kjæledyr.",
        flavor = "{player} har samlet ti kjæledyr! {name}" },
    ["count:25"] = { name = "Dyrevenn", desc = "Ha 25 kjæledyr.",
        flavor = "{player} har samlet 25 kjæledyr! {name}" },
    ["count:50"] = { name = "Dyrepasser", desc = "Ha 50 kjæledyr.",
        flavor = "{player} har samlet 50 kjæledyr og trenger et større hus! {name}" },
    ["count:all"] = { name = "Noahs ark", desc = "Ha alle kjæledyrene som finnes.",
        flavor = "{player} har samlet ALLE kjæledyrene! To av hver? Nei, én av hver holder. {name}" },

    -- Families (our tags; see tools/companions/tags.csv).
    ["family:cat"] = { name = "Alle kattene", desc = "Ha alle kattene.",
        flavor = "{player} har gitt alle kattene et hjem! {name}" },
    ["family:farm"] = { name = "Bondegården", desc = "Ha alle gårdsdyrene.",
        flavor = "{player} har fylt opp hele bondegården! {name}" },
    ["family:owl"] = { name = "Ugleredet", desc = "Ha alle uglene.",
        flavor = "Hu-hu! {player} har samlet alle uglene. {name}" },
    ["family:rabbit"] = { name = "Kaninhagen", desc = "Ha alle kaninene.",
        flavor = "{player} har alle kaninene. De formerer seg nok snart. {name}" },
    ["family:snake"] = { name = "Slangegropa", desc = "Ha alle slangene.",
        flavor = "Ssss! {player} har samlet alle slangene. {name}" },
    ["family:frog"] = { name = "Froskedammen", desc = "Ha alle froskene og paddene.",
        flavor = "{player} har samlet alle froskene. Ingen prinser ennå. {name}" },
    ["family:mechanical"] = { name = "Tannhjul og skruer", desc = "Ha alle de mekaniske kjæledyrene.",
        flavor = "{player} har samlet alle de mekaniske kjæledyrene! {name}" },
    ["family:dragon"] = { name = "Dragehulen", desc = "Ha alle dragene.",
        flavor = "{player} har samlet alle dragene. Pass på gardinene! {name}" },
    ["family:bird"] = { name = "Fuglekassa", desc = "Ha alle fuglene.",
        flavor = "{player} har samlet alle fuglene! {name}" },
    ["family:pirate"] = { name = "Kaptein Sabeltann", desc = "Ha alle piratkjæledyrene.",
        flavor = "Ingen er så tøff som {player}, med alle piratkjæledyrene om bord! {name}" },

    -- Loyalty: the companion you care for (per character).
    ["loyal:30"] = { name = "Bestevenner", desc = "Ta vare på det samme kjæledyret i 30 dager.",
        flavor = "{player} og kjæledyret sitt har vært bestevenner i en hel måned! {name}" },
    ["loyal:100"] = { name = "Uatskillelige", desc = "Ta vare på det samme kjæledyret i 100 dager.",
        flavor = "{player} og kjæledyret sitt har vært uatskillelige i 100 dager! {name}" },
    ["loyal:365"] = { name = "Venner for livet", desc = "Ta vare på det samme kjæledyret i et helt år.",
        flavor = "{player} har tatt vare på det samme kjæledyret i et helt år! {name}" },
    ["nick"] = { name = "Døpt", desc = "Gi kjæledyret ditt et kallenavn.",
        flavor = "{player} har gitt kjæledyret sitt et navn! {name}" },

    -- Guild: the companions the guild cares for, all at once (one per member).
    ["guild:count:10"] = { name = "Dyreparken åpner", desc = "Guilden tar vare på 10 kjæledyr samtidig.",
        flavor = "Portene er åpne: {guild} tar vare på ti kjæledyr! {name}" },
    ["guild:count:25"] = { name = "Full drift", desc = "Guilden tar vare på 25 kjæledyr samtidig.",
        flavor = "{guild} tar vare på 25 kjæledyr! Dyreparken er i full drift. {name}" },
    ["guild:count:50"] = { name = "Nordens største dyrepark", desc = "Guilden tar vare på 50 kjæledyr samtidig.",
        flavor = "{guild} tar vare på 50 kjæledyr! {name}" },
    ["guild:all"] = { name = "Hele parken", desc = "Guilden tar vare på alle kjæledyrene som finnes, samtidig.",
        flavor = "Hvert eneste kjæledyr har et hjem i {guild}! {name}" },
    ["guild:family:cat"] = { name = "Kattehuset", desc = "Hver katt har sin egen eier i guilden.",
        flavor = "Hver eneste katt har fått sitt eget hjem i {guild}! {name}" },
}
