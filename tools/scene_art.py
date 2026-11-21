#!/usr/bin/env python3
"""Every large picture Forever's client has that could sit behind a pet on its card (2026-11-21, the user: "we were
acting out of a severely limited pool of built-in textures"). Writes Dev/SceneArt.lua for `/dp probe bg`.

Where they come from, all through wago.tools (product `wowf`, no game needed):
  - Forever's own loading screens: the LoadingScreens and Map tables (the new dungeons have theirs).
  - Every loading screen file in the build's file list (interface/glues/loadingscreens/), every expansion's.
  - The dungeon journal's backgrounds (interface/encounterjournal/ui-ej-background-*).
  - Large atlases (UiTextureAtlasMember) whose names say they're scenery: starting zones, hunter stables,
    professions, talents, delves, islands, factions... (ATLAS_PATTERNS).
Each file is downloaded once into tools/.scene_art/ (gitignored) to measure the part that's art: a loading screen's
frame and logo come off (rules by era in Crop, OVERRIDE for odd ones), and to draw the previews.

  python3 tools/scene_art.py                 fetch what's missing, write Dev/SceneArt.lua and the preview page
  python3 tools/scene_art.py --build 1.60.1.71037
  python3 tools/scene_art.py --no-fetch      only what's cached (no network)
  python3 tools/scene_art.py --redo          measure and draw every preview again (after changing a crop rule)

The preview page: tools/.scene_art/preview/index.html (each family's suggestions first, then every group).
Downloaded files are data: decoded as images by Pillow, never run.
"""
import argparse, concurrent.futures as cf, csv, html, io, json, os, re, struct, sys, time, urllib.error, urllib.parse, urllib.request
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    sys.exit("needs Pillow (python3 -m pip install pillow)")

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
CACHE = HERE / ".scene_art"
OUT = ROOT / "Dev" / "SceneArt.lua"
API = "https://wago.tools"
UA = {"User-Agent": "dyreparken-scene-art/1.0"}

# Scenery among the atlases, by name (lower case). Anything else large (frames, flipbooks, glows, store cards) is
# left out on purpose.
ATLAS_PATTERNS = [
    r"charactercreate-startingzone-", r"housing-dashboard-bg-(elwynn|duratar|welcome)$", r"hunter-stable-bg-art",
    r"ui-stables-pet-model-bg", r"talents-background-", r"talent-background-", r"delves?-entrance-background-",
    r"creditsscreen-keyart-", r"campcollection-bg-image", r"covenantsanctum-background-", r"chromietime-portrait-large-",
    r"legionmission-complete-background-", r"collections-background-c60$", r"legacy-.*-c60$", r"welcome-background-keyart",
    r"showdowns-background-", r"ritual-sites-background-", r"scoreboard-background-(islands|warfronts)",
    r"bfa-mission-complete-background-", r"adventures-endcombat-", r"ui-frame-.*choice-scrollingbg",
    r"dragonflight-majorfactions-.*-background", r"thewarwithin-majorfactions-.*-background", r"lair-entrance-background",
]
# (Left out after a look at the previews, 2026-11-21: near-empty or dark pages (professions, artifacts, cypher,
# landing pages), frames with a hole, plain color swatches (*-highlight-top), island cards (drawn in masks).)
ATLAS_SKIP = r"(-2x|_2x|-zhcn|-cn|-apac|-tw|_cn|_tw|-krtw|-row)$|sheen|flipbook|mask|shadow|glow|-fx"

# Loading screen files that aren't scenery.
LS_SKIP = r"dynamicelements|logo_|inv_bullroarer|blizzcon"

# An atlas's art within its own rectangle, by name (left, right, top, bottom): the delve entrances are art on the
# left and parchment on the right.
ATLAS_CROP = [(r"delves?-entrance-background-", (0, 0.6, 0, 1))]

# A crop by hand where the era's rule misses (file id -> left, right, top, bottom, as parts of the file).
OVERRIDE = {
}

# The family suggestions, best first: a file id, "atlas:<name>", a loading screen's file name or Forever's map name
# for its own. The family's current background goes first by itself (Scenes.BY_FAMILY, read from the Lua). Picked
# by name and from the previews, 2026-11-21: a first round for the user to choose from in game.
SUGGEST = {
    "cat": ["loadscreenzulaman2", "loadscreenzulaman", "atlas:charactercreate-startingzone-nightelf",
            "loadscreen_waycrestmanor_wide", "loadscreen_druidorderhall_wide", "loadscreenuldumdungeon"],
    "bird": ["Zephras Isle", "loadscreen_skyreach", "loadscreen_rookerydungeon", "loadscreen_spiresofascension",
             "loadscreen_zerethmortis", "loadscreenterraceofendlesssprings", "loadscreenskywall",
             "atlas:charactercreate-startingzone-highmountaintauren"],
    "owl": ["Ruins of Lordaeron", "loadscreen_blackrookhold_wide", "loadscreen_emeralddreamway_wide", "loadscreenhyjal", "loadscreen_suramarcatacombs_wide", "loadscreenshadowfangkeep",
            "loadscreen_druidorderhall_wide"],
    "farm": [ "atlas:welcome-background-keyart", "atlas:charactercreate-startingzone-human",
             "atlas:charactercreate-startingzone-kultiran", "atlas:charactercreate-startingzone-tauren", "loadscreen_alliancegarrison"],
    "rabbit": [ "atlas:charactercreate-startingzone-human", "loadscreen_emeralddreamzone",
               "atlas:charactercreate-startingzone-pandaren", "loadscreenwanderingisle", "atlas:welcome-background-keyart"],
    "frog": ["Zephras Isle", "loadscreenwailingcaverns", "loadscreen_underrot_wide", "loadscreen_nazmirraid",
             "loadscreen_everbloom", "Alcaz Prison"],
    "snake": ["loadscreenzulfarrak", "loadscreenuldumdungeon", "loadscreenhallsoforigination",
              "loadingscreen_serpentinetunnels_wide", "loadingscreen_goldencityexterior_wide_battleforazeroth",
              "loadscreen_nazmirraid", "atlas:charactercreate-startingzone-vulpera", "loadscreenrazorfenkraul"],
    "mechanical": ["loadscreengnomeregan", "loadingscreen_mechagoncity", "loadingscreen_mechagonzone",
                   "atlas:charactercreate-startingzone-mechagnome", "atlas:charactercreate-startingzone-gnome",
                   "atlas:charactercreate-startingzone-goblin", "loadscreen_zone_undermine", "loadscreen_dungeon_waterworks",
                   "loadscreenblackrocktraindepot", "The Hall of Thanes"],
    "dragon": ["loadscreen_neltharusdungeon", "loadscreenrubysanctum", "loadscreenchamberblack", "loadscreenmalygos", "loadscreen_vaultoftheincarnates", "loadscreen_dawnoftheinfinite", "loadscreenblackwinglair", "loadscreen_aberrusraid"],
    "pirate": ["The Drowned City", "loadscreendeadmines", "loadingscreen_freeholddungeon",
               "loadingscreen_boralusdungeon", "loadscreen_irondocks", "atlas:charactercreate-startingzone-kultiran", "loadscreenthroneofthetides"],
    "bug": ["Excavation Site: Wetlands", "loadscreenahnqiraj20man", "loadscreenahnqiraj40man", "loadscreenheartoffear",
            "loadscreen_cityofthreadsdungeon", "loadscreen_arakaradungeon", "loadscreen_nerubianraid",
            "loadscreenazjolnerub76"],
    "rodent": ["loadscreen_cinderbrewmeaderydungeon", "loadscreenstormstoutbrewery", "The Hall of Thanes", "Krol'dok Stronghold",
               "loadscreendeepruntram", "loadscreen_darkflamecleftdungeon", "loadscreen_thestonevaultdungeon",
               "atlas:charactercreate-startingzone-dwarf", "loadscreenscholomance"],
    "wolf": ["loadscreenshadowfangkeep", "loadscreen_hunterorderhall_wide", "atlas:charactercreate-startingzone-worgen",
             "loadscreengilneasbg", "loadscreenwintergrasp", "loadscreen_hallsofvalor_wide",
             "loadscreenutgarde", "atlas:charactercreate-startingzone-orc"],
    "plant": ["The Shaper's Terrace", "loadscreenwailingcaverns", "loadscreen_everbloom", "loadscreen_emeralddreamway_wide",
              "loadscreen_tirnascithedungeon", "loadscreen_emeralddreamzone", "loadscreen_amirdrassilraid",
              "loadscreen_lifepoolsdungeon"],
    "festive": ["loadscreendarkmoonisland", "loadscreendarkmoonisland_classiclogo",
                "loadscreen_cinderbrewmeaderydungeon", "loadscreen_raid_casino", "loadscreen_tazaveshtheveiledmarket"],
    "demon": ["loadscreenmoltencore", "loadscreen_hellfireraid", "loadscreen_mardumwide",
              "loadscreen_tombofsargerasraid_wide", "loadscreen_argusraid_widescreen", "loadscreenblacktemple",
              "loadscreen_demonhunterorderhall_wide", "loadscreen_warlockorderhall_wide",
              "atlas:charactercreate-startingzone-demonhunter"],
    "ooze": ["loadscreenuldaman", "loadscreen_plaguefalldungeon", "loadscreen_underrot_wide", "loadscreen_necroticwake",
             "loadscreen_nzothraid", "loadscreen_nazjatar", "loadscreenblackfathomdeeps"],
    "spirit": ["loadscreenblackfathomdeeps", "Ruins of Lordaeron", "loadscreen_emeralddreamway_wide",
               "loadscreen_theotherside", "loadscreen_tirnascithedungeon", "loadscreen_spiresofascension",
               "loadscreenhyjal"],
    "bear": ["Blackmaw Hold", "atlas:charactercreate-startingzone-pandaren",
             "loadscreenstormstoutbrewery", "loadscreenwanderingisle", "loadscreen_hallsofvalor_wide"],
    "reptile": ["Darkspear Islands", "loadscreensunkentemple", "loadscreen_nazmirraid", "Alcaz Prison", "The Shaper's Terrace",
                "atlas:charactercreate-startingzone-zandalaritroll",
                "loadingscreen_goldencityexterior_wide_battleforazeroth", "loadscreenzulfarrak",
                "loadscreen_brackenhidehollowdungeon", "loadscreenzulgurub"],
    "murloc": ["The Drowned City", "Darkspear Islands", "loadscreenblackfathomdeeps", "loadscreenthroneofthetides",
               "loadscreen_nazjatar", "loadscreen_nazjatar_raid",
               "loadingscreen_masterwidescreen_shrineofthestorm_wide"],
    "default": ["Kalimdor", "Eastern Kingdoms", "Zephras Isle", "atlas:welcome-background-keyart", "loadscreenblackrockdepths"],
}



def fetch(url, binary=False, tries=6):
    for n in range(tries):
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=120) as r:
                data = r.read()
            time.sleep(0.4)  # (wago.tools answers 429 to a hurry)
            return data if binary else data.decode("utf-8")
        except Exception as e:  # (a flaky connection or a 429: a pause and again)
            if n == tries - 1:
                raise
            wait = 2 + 3 * n
            if isinstance(e, urllib.error.HTTPError) and e.code == 429:
                wait = int(e.headers.get("Retry-After") or 0) or 15 * (n + 1)
            print(f"  retry in {wait} s: {url}: {e}", file=sys.stderr)
            time.sleep(wait)


def newest_build():
    builds = json.loads(fetch(f"{API}/api/builds")).get("wowf") or []
    if not builds:
        sys.exit("wago.tools lists no wowf builds")
    return builds[0]["version"]


def table(build, name, offline):
    path = CACHE / build / f"{name}.csv"
    if not path.exists():
        if offline:
            sys.exit(f"{path} isn't cached (run without --no-fetch)")
        text = fetch(f"{API}/db2/{name}/csv?build={build}")
        if not text.startswith(("ID,", "CommittedName,", "Name,")):
            sys.exit(f"{name} for {build}: not a CSV ({text[:80]!r})")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return list(csv.DictReader(io.StringIO(path.read_text(encoding="utf-8"))))


def files(build, prefix, offline):
    safe = re.sub(r"[^a-z0-9]+", "_", prefix)
    path = CACHE / build / f"files_{safe}.json"
    if not path.exists():
        if offline:
            sys.exit(f"{path} isn't cached (run without --no-fetch)")
        text = fetch(f"{API}/api/files?search={urllib.parse.quote(prefix)}&version={build}")
        json.loads(text)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return {int(k): v for k, v in json.loads(path.read_text()).items()}


def blob(build, fid, offline):
    """The file's bytes (cached; None when the build doesn't serve it: encrypted, or not shipped)."""
    path = CACHE / "files" / f"{fid}.blp"
    if path.exists():
        data = path.read_bytes()
        return data if data[:3] == b"BLP" else None
    if offline:
        return None
    data = fetch(f"{API}/api/casc/{fid}?version={build}", binary=True)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data if data[:3] == b"BLP" else b"")  # (remember a miss as an empty file)
    return data if data[:3] == b"BLP" else None


def image(build, fid, offline):
    data = blob(build, fid, offline)
    if not data:
        return None
    if data[:4] == b"BLP2" and data[8] == 3:  # raw BGRA, which Pillow doesn't read (the talents' and others)
        w, h = struct.unpack_from("<II", data, 12)
        offset = struct.unpack_from("<I", data, 20)[0]
        return Image.frombuffer("RGBA", (w, h), data[offset:offset + w * h * 4], "raw", "BGRA", 0, 1)
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
        return im
    except Exception as e:
        print(f"  {fid}: can't decode ({e})", file=sys.stderr)
        return None


def ls_crop(fid, name, im):
    """A loading screen's art: (l, r, t, b) as parts of the file, and its shown size (w, h) for its aspect."""
    W, H = im.size
    if fid in OVERRIDE:
        l, r, t, b = OVERRIDE[fid]
    elif im.mode == "RGBA" and im.getchannel("A").getextrema()[0] < 128:
        # The modern ones (Shadowlands on, Forever's own): the art is the rows and columns that are mostly opaque
        # (a small icon above the art, the retail ones' numbered diamond, doesn't count).
        small = im.getchannel("A").resize((W // 8, H // 8)).point(lambda a: 1 if a > 128 else 0)
        w8, h8 = small.size
        px = small.load()
        rows = [y for y in range(h8) if sum(px[x, y] for x in range(w8)) > w8 * 0.6]
        cols = [x for x in range(w8) if sum(px[x, y] for y in range(h8)) > h8 * 0.3]
        if not rows or not cols:
            rows, cols = [0, h8 - 1], [0, w8 - 1]
        l, r = cols[0] / w8, (cols[-1] + 1) / w8
        t, b = rows[0] / h8, (rows[-1] + 1) / h8
    elif W == 2 * H:  # Legion and Battle for Azeroth wide: a frame top and bottom, the logo in the top band
        l, r, t, b = 0, 1, 0.31, 0.85
    elif W == H:  # framed, 4:3 on screen: below the logo, above the frame's bottom bar, by era (file ids)
        if fid < 236000:
            t, b = 0.27, 0.80  # classic and the Burning Crusade
        elif fid < 390000:
            t, b = 0.28, 0.86  # Wrath
        elif fid < 570000:
            t, b = 0.26, 0.86  # Cataclysm
        elif fid < 1000000:
            t, b = 0.27, 0.82  # Mists
        elif "classiclogo" in name:
            t, b = 0.25, 0.80
        else:
            t, b = 0.26, 0.85  # Warlords
        l, r = 0.012, 0.988
    else:
        l, r, t, b = 0, 1, 0, 1
    # Shown size: a square file is a 4:3 screen (16:9 when named wide), a 2:1 file 16:9; others as they are.
    if W == H:
        sw, sh = (1920, 1080) if "wide" in name else (1024, 768)
    elif W == 2 * H:
        sw, sh = 1920, 1080
    else:
        sw, sh = W, H
    return (l, r, t, b), (round((r - l) * sw), round((b - t) * sh))


def thumb(im, crop, size, dest):
    W, H = im.size
    l, r, t, b = crop
    part = im.crop((round(l * W), round(t * H), round(r * W), round(b * H))).convert("RGB")
    part = part.resize(size, Image.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    part.save(dest, quality=78)


def nice(name):
    name = re.sub(r"\.blp$", "", name)
    name = re.sub(r"^(loadscreen|loadingscreen)_?", "", name)
    name = re.sub(r"_?\d{6,}$", "", name)
    return name.replace("_", " ").strip()


def bare(name):
    """A loading screen's file name without the prefix and extension: their prefixes vary (loadscreen, loadingscreen)."""
    return re.sub(r"^(loadscreen|loadingscreen)_?", "", re.sub(r"\.blp$", "", str(name)))


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def current_families():
    """Scenes.BY_FAMILY's first entry per family, read from the Lua (EJ .. "Name")."""
    text = (ROOT / "Menagerie" / "Scenes.lua").read_text(encoding="utf-8")
    block = text[text.index("Scenes.BY_FAMILY = {"):]
    block = block[:block.index("\n}\n")]
    out = {}
    for fam, rest in re.findall(r"^\s*(\w+) = \{ (.*?) \}", block, re.M):
        m = re.search(r'EJ \.\. "(\w+)"', rest)
        if m:
            out[fam] = "ui-ej-background-" + m.group(1).lower()
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build")
    ap.add_argument("--no-fetch", action="store_true")
    ap.add_argument("--jobs", type=int, default=1)
    ap.add_argument("--redo", action="store_true", help="measure and draw every preview again (after a crop rule changed)")
    a = ap.parse_args()
    off = a.no_fetch
    build = a.build or (None if off else newest_build())
    if not build:
        builds = sorted(p.name for p in CACHE.iterdir() if p.is_dir() and p.name[0].isdigit())
        build = builds[-1] if builds else sys.exit("nothing cached")
    print(f"build {build}")

    maps = table(build, "Map", off)
    screens = {r["ID"]: r for r in table(build, "LoadingScreens", off)}
    atlases = {r["ID"]: r for r in table(build, "UiTextureAtlas", off)}
    members = table(build, "UiTextureAtlasMember", off)
    ls_files = files(build, "interface/glues/loadingscreens/", off)
    ej_files = files(build, "interface/encounterjournal/ui-ej-background", off)

    cands = []  # { id, group, label, file, crop, size }
    # Forever's own loading screens: by the maps that use them (the label names the place).
    forever = {}
    for m in maps:
        s = screens.get(m["LoadingScreenID"])
        if not s:
            continue
        fid = int(s["MainImageFileDataID"]) or int(s["NarrowScreenFileDataID"])
        if fid and fid >= 6000000 and fid not in forever:
            forever[fid] = m["MapName_lang"]
    for fid, path in sorted(ls_files.items()):
        name = path.rsplit("/", 1)[-1]
        if re.search(LS_SKIP, name):
            continue
        group = "forever" if fid in forever or fid >= 7900000 else "loading"
        label = forever.get(fid) or nice(name)
        cands.append({"id": fid, "group": group, "label": label, "file": fid, "name": name})
    for fid, label in forever.items():  # (one the file list lacks: Forever's newest)
        if fid not in ls_files:
            cands.append({"id": fid, "group": "forever", "label": label, "file": fid, "name": str(fid)})
    for fid, path in sorted(ej_files.items()):
        name = path.rsplit("/", 1)[-1]
        cands.append({"id": fid, "group": "journal", "label": nice(name.replace("ui-ej-background-", "")), "file": fid,
                      "name": name[:-4], "crop": (0, 0.76953125, 0, 0.830078125)})
    seen = set()
    for r in members:
        n = r["CommittedName"]
        low = n.lower()
        if low in seen or not any(re.search(p, low) for p in ATLAS_PATTERNS) or re.search(ATLAS_SKIP, low):
            continue
        w, h = int(r["Width"]), int(r["Height"])
        if w < 300 or h < 200 or not 0.6 <= w / h <= 2.8:
            continue
        at = atlases.get(r["UiTextureAtlasID"])
        if not at:
            continue
        seen.add(low)
        AW, AH = int(at["AtlasWidth"]), int(at["AtlasHeight"])
        crop = (int(r["CommittedLeft"]) / AW, int(r["CommittedRight"]) / AW, int(r["CommittedTop"]) / AH,
                int(r["CommittedBottom"]) / AH)
        sub = next((c for pat, c in ATLAS_CROP if re.search(pat, low)), (0, 1, 0, 1))
        crop = (crop[0] + (crop[1] - crop[0]) * sub[0], crop[0] + (crop[1] - crop[0]) * sub[1],
                crop[2] + (crop[3] - crop[2]) * sub[2], crop[2] + (crop[3] - crop[2]) * sub[3])
        cands.append({"id": "atlas:" + n, "group": "atlas", "label": n, "file": int(at["FileDataID"]), "name": n,
                      "crop": crop, "size": (round(w * (sub[1] - sub[0])), round(h * (sub[3] - sub[2]))), "atlas": True,
                      "sub": sub})

    # Download (cached), measure, draw the previews.
    todo = sorted({c["file"] for c in cands if not (CACHE / "files" / f"{c['file']}.blp").exists()})
    if todo and not off:
        print(f"fetching {len(todo)} files ({a.jobs} at a time)...")
        done = 0
        with cf.ThreadPoolExecutor(a.jobs) as ex:
            for _ in ex.map(lambda f: blob(build, f, False), todo):
                done += 1
                if done % 25 == 0:
                    print(f"  {done}/{len(todo)}")
    prev = CACHE / "preview" / "img"
    missing = []
    cache = {}
    # Each file's measure (its size, and a loading screen's crop), kept: a rerun decodes only what it draws.
    measured_path = CACHE / "measured.json"
    measured = json.loads(measured_path.read_text()) if measured_path.exists() and not a.redo else {}
    if a.redo:
        for f in prev.glob("*.jpg"):
            f.unlink()
    for c in sorted(cands, key=lambda c: c["file"]):
        fid = c["file"]
        slug = re.sub(r"[^a-z0-9]+", "-", str(c["id"]).lower())
        dest = prev / f"{slug}.jpg"
        m = measured.get(str(fid))
        if m is None or not dest.exists():
            if fid not in cache:
                cache.clear()  # (one big image in memory at a time; candidates sharing a file sit together)
                cache[fid] = image(build, fid, True)
            im = cache[fid]
            if im is None:
                missing.append(c)
                continue
            m = {"size": im.size}
            if not c.get("atlas") and c["group"] != "journal":
                m["crop"], m["shown"] = ls_crop(fid, c["name"], im)
            measured[str(fid)] = m
        if c.get("atlas"):
            crop, size = c["crop"], c["size"]
        elif c["group"] == "journal":
            crop = c["crop"]
            size = (round(m["size"][0] * crop[1]), round(m["size"][1] * crop[3]))
        else:
            crop, size = tuple(m["crop"]), tuple(m["shown"])
        c["crop"], c["size"] = crop, size
        if not dest.exists():
            tw = 320
            th = max(40, round(tw * size[1] / max(1, size[0])))
            thumb(cache[fid], crop, (tw, min(th, 480)), dest)
        c["thumb"] = f"img/{slug}.jpg"
    measured_path.write_text(json.dumps(measured))
    keep = [c for c in cands if "thumb" in c]
    print(f"{len(keep)} candidates ({len(missing)} not served by the build: encrypted or not shipped)")

    by_id = {c["id"]: c for c in keep}
    cur = current_families()
    by_name = {c["name"]: c["id"] for c in keep if c["group"] == "journal"}
    alias = {}  # a loading screen's file name, or the map's name for Forever's own -> its id
    for c in keep:
        if not c.get("atlas"):
            alias[bare(c["name"])] = c["id"]
            if c["group"] == "forever":
                alias[c["label"]] = c["id"]
    families = {}
    for fam in sorted(set(SUGGEST) | set(cur)):
        ids = []
        if cur.get(fam) in by_name:
            ids.append(by_name[cur[fam]])
        for i in SUGGEST.get(fam, []):
            i = alias.get(i) or alias.get(bare(i)) or i
            if i in by_id and i not in ids:
                ids.append(i)
            elif i not in by_id:
                print(f"  suggestion {i} for {fam}: no such candidate", file=sys.stderr)
        families[fam] = ids

    write_lua(build, keep, families)
    write_html(build, keep, families)


GROUPS = [("forever", "Forever's loading screens"), ("loading", "Loading screens"), ("journal", "Dungeon journal"),
          ("atlas", "Atlases")]


def write_lua(build, keep, families):
    def ref(i):
        return lua_str(i) if isinstance(i, str) else str(i)

    def num(v):
        return ("%.4f" % v).rstrip("0").rstrip(".") or "0"

    lines = [
        "---@class Dyreparken",
        "local ns = select(2, ...)",
        "",
        f"-- GENERATED by tools/scene_art.py from Forever's {build} (wago.tools): every large picture that could sit",
        "-- behind a pet on its card, for /dp probe bg (Dev/ScenesProbe.lua). Don't edit: change the script and rerun it.",
        "-- A row: { id, group, label, left, right, top, bottom, width, height }: id is a file id or \"atlas:<name>\"",
        "-- (what Scenes.BY_FAMILY takes); the crop is the art's part of the file (an atlas's: of its own rectangle),",
        "-- the size its shape on screen. An atlas's crop is within its own rectangle (most: the whole).",
        "---@class Dyreparken.SceneArt",
        "ns.SceneArt = {",
        "    build = %s," % lua_str(build),
        "    groups = { " + ", ".join("{ %s, %s }" % (lua_str(g), lua_str(t)) for g, t in GROUPS) + " },",
        "    list = {",
    ]
    for c in keep:
        l, r, t, b = c["crop"]
        if c.get("atlas"):
            l, r, t, b = c["sub"]
        lines.append("        { %s, %s, %s, %s, %s, %s, %s, %d, %d }," % (
            ref(c["id"]), lua_str(c["group"]), lua_str(c["label"]), num(l), num(r), num(t), num(b), c["size"][0],
            c["size"][1]))
    lines.append("    },")
    lines.append("    -- family -> suggestions, best first (its background now, then SUGGEST in the script)")
    lines.append("    families = {")
    for fam, ids in sorted(families.items()):
        lines.append("        %s = { %s }," % (fam, ", ".join(ref(i) for i in ids)))
    lines.append("    },")
    lines.append("}")
    OUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)} ({len(keep)} rows)")


def write_html(build, keep, families):
    by_id = {c["id"]: c for c in keep}

    def card(c):
        return ('<figure><img loading="lazy" src="%s" alt=""><figcaption><b>%s</b><span>%s</span></figcaption></figure>'
                % (c["thumb"], html.escape(c["label"]), html.escape(str(c["id"]))))

    parts = [f"<!doctype html><meta charset=utf-8><title>Pet card backgrounds</title><style>"
             "body{background:#16130f;color:#eee;font:14px system-ui;margin:16px}h2{margin:28px 0 8px}"
             ".g{display:flex;flex-wrap:wrap;gap:10px}figure{margin:0;width:240px}img{width:240px;display:block;"
             "border-radius:4px}figcaption{font-size:12px;display:flex;flex-direction:column}span{color:#999}</style>",
             f"<h1>Pet card backgrounds ({len(keep)}, build {build})</h1>"]
    for fam, ids in sorted(families.items()):
        parts.append(f"<h2>{fam}</h2><div class=g>" + "".join(card(by_id[i]) for i in ids if i in by_id) + "</div>")
    for g, title in GROUPS:
        cs = [c for c in keep if c["group"] == g]
        parts.append(f"<h2>{title} ({len(cs)})</h2><div class=g>" + "".join(card(c) for c in cs) + "</div>")
    dest = CACHE / "preview" / "index.html"
    dest.write_text("".join(parts), encoding="utf-8")
    print(f"wrote {dest.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
