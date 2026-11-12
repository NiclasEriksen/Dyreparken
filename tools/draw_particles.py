"""Draws the pet card's particle textures (Media/Particles/*.tga): python3 tools/draw_particles.py [sheet.png]
[--only name,name] (only those: the other files are left as they are)

White shapes with soft alpha edges, so the addon can tint them (SetVertexColor) and animate them. Drawn at
4x and scaled down for smooth edges. Written as uncompressed 32-bit TGA, bottom-left origin: the plainest
form WoW loads.
"""
import math, os, struct
from PIL import Image, ImageDraw, ImageFilter, ImageChops

SIZE, SS = 64, 4
BIG = SIZE * SS
OUT = os.path.join(os.path.dirname(__file__), "..", "Media", "Particles")


def canvas():
    return Image.new("L", (BIG, BIG), 0)


def P(x, y):
    """-1..1 coordinates (y up) to pixels."""
    return ((x + 1) / 2 * BIG, (1 - y) / 2 * BIG)


def poly(d, pts, fill=255):
    d.polygon([P(x, y) for x, y in pts], fill=fill)


def ellipse(d, cx, cy, rx, ry, fill=255):
    (x0, y1), (x1, y0) = P(cx - rx, cy - ry), P(cx + rx, cy + ry)
    d.ellipse([x0, y0, x1, y1], fill=fill)


def heart():
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(400):
        t = i / 400 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 18, (y + 2) / 18))
    poly(d, pts)
    return m


def sparkle():
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(400):
        t = i / 400 * 2 * math.pi
        c, s = math.cos(t), math.sin(t)
        pts.append((0.92 * math.copysign(abs(c) ** 3, c), 0.92 * math.copysign(abs(s) ** 3, s)))
    poly(d, pts)
    ellipse(d, 0, 0, 0.16, 0.16)
    return m


def star():
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(10):
        r = 0.92 if i % 2 == 0 else 0.4
        a = math.pi / 2 + i * math.pi / 5
        pts.append((r * math.cos(a), r * math.sin(a) - 0.06))
    poly(d, pts)
    return m


def dot():
    m = Image.new("L", (SIZE, SIZE), 0)
    px = m.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r = math.hypot((x + 0.5) / SIZE * 2 - 1, (y + 0.5) / SIZE * 2 - 1)
            px[x, y] = int(255 * max(0.0, 1 - r) ** 2)
    return m.resize((BIG, BIG))


def bubble():
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0, 0.9, 0.9, 235)
    ellipse(d, 0, 0, 0.78, 0.78, 40)
    ellipse(d, -0.32, 0.36, 0.2, 0.13, 255)
    ellipse(d, 0.4, -0.38, 0.07, 0.07, 160)
    return m


def confetti():
    m = canvas(); d = ImageDraw.Draw(m)
    (x0, y1), (x1, y0) = P(-0.7, -0.32), P(0.7, 0.32)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.04, fill=255)
    return m


def note():
    m = canvas(); d = ImageDraw.Draw(m)
    head = canvas(); hd = ImageDraw.Draw(head)
    ellipse(hd, 0, 0, 0.32, 0.22)
    head = head.rotate(25, resample=Image.BICUBIC)
    head = ImageChops.offset(head, int(-0.2 * BIG / 2), int(0.6 * BIG / 2))
    m = ImageChops.lighter(m, head)
    d = ImageDraw.Draw(m)
    poly(d, [(0.06, -0.55), (0.18, -0.55), (0.18, 0.9), (0.06, 0.9)])
    poly(d, [(0.18, 0.9), (0.18, 0.62), (0.62, 0.28), (0.66, 0.42)])
    return m


def paw():
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, -0.32, 0.44, 0.36)
    for x, y, r in ((-0.6, 0.18, 0.2), (-0.22, 0.52, 0.21), (0.22, 0.52, 0.21), (0.6, 0.18, 0.2)):
        ellipse(d, x, y, r * 0.9, r * 1.12)
    return m


def leaf():
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(201):
        t = i / 200
        pts.append((-0.85 + 1.7 * t, 0.42 * math.sin(math.pi * t)))
    for i in range(201):
        t = 1 - i / 200
        pts.append((-0.85 + 1.7 * t, -0.42 * math.sin(math.pi * t)))
    poly(d, pts)
    poly(d, [(-0.95, 0.03), (0.7, 0.01), (0.7, -0.01), (-0.95, -0.03)], fill=70)
    m = m.rotate(35, resample=Image.BICUBIC)
    return m


def moon():
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0, 0.82, 0.82)
    ellipse(d, 0.36, 0.22, 0.7, 0.7, 0)
    return m


def snowflake():
    m = canvas(); d = ImageDraw.Draw(m)
    for k in range(6):
        a = k * math.pi / 3
        c, s = math.cos(a), math.sin(a)
        def R(x, y): return (x * c - y * s, x * s + y * c)
        poly(d, [R(0, -0.05), R(0.9, -0.05), R(0.9, 0.05), R(0, 0.05)])
        for b in (0.45, 0.68):
            for sign in (1, -1):
                poly(d, [R(b, 0), R(b + 0.2, sign * 0.2), R(b + 0.26, sign * 0.15), R(b + 0.07, 0)])
    return m


def ring():
    """A soft ring, for a ripple."""
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0, 0.9, 0.9, 255)
    ellipse(d, 0, 0, 0.72, 0.72, 0)
    return m.filter(ImageFilter.GaussianBlur(SS * 1.5))


def rays():
    """A sunburst: 12 soft, tapering rays (drawn bigger: 128x128)."""
    m = canvas(); d = ImageDraw.Draw(m)
    for k in range(12):
        a = k * math.pi / 6
        w = 0.09
        pts = [(0, 0), (math.cos(a - w), math.sin(a - w)), (math.cos(a + w), math.sin(a + w))]
        poly(d, [(x * 1.0, y * 1.0) for x, y in pts], fill=200)
    m = m.filter(ImageFilter.GaussianBlur(SS * 3))
    # fade toward the edge
    fade = Image.new("L", (BIG, BIG), 0)
    px = fade.load()
    for y in range(0, BIG, 2):
        for x in range(0, BIG, 2):
            r = math.hypot((x + 0.5) / BIG * 2 - 1, (y + 0.5) / BIG * 2 - 1)
            v = int(255 * max(0.0, 1 - r) ** 1.2)
            px[x, y] = v; px[min(x + 1, BIG - 1), y] = v; px[x, min(y + 1, BIG - 1)] = v
            px[min(x + 1, BIG - 1), min(y + 1, BIG - 1)] = v
    return ImageChops.multiply(m, fade)


# Family ambience and the rest of the traits (2026-11-09).
def rot(pts, a, cx=0, cy=0):
    c, s = math.cos(a), math.sin(a)
    return [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]


def oval(cx, cy, rx, ry, a=0, n=120):
    return rot([(rx * math.cos(2 * math.pi * i / n), ry * math.sin(2 * math.pi * i / n)) for i in range(n)], a, cx, cy)


def drop_pts(rx, ry, m, cy=0):
    """A teardrop, tip up."""
    pts = []
    for i in range(300):
        t = i / 300 * 2 * math.pi
        pts.append((rx * math.sin(t) * abs(math.sin(t / 2)) ** m, cy + ry * math.cos(t)))
    return pts


def feather():
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(101):
        t = i / 100
        pts.append((0.08 * math.sin(math.pi * t) - 0.36 * math.sin(math.pi * t) ** 0.7, -0.9 + 1.8 * t))
    for i in range(101):
        t = 1 - i / 100
        pts.append((0.08 * math.sin(math.pi * t) + 0.26 * math.sin(math.pi * t) ** 0.7, -0.9 + 1.8 * t))
    poly(d, pts)
    for y, side in ((0.35, -1), (-0.05, -1), (0.15, 1), (-0.3, 1)):  # notches in the vane
        x = side * 0.4
        poly(d, [(x, y), (side * 0.12, y - 0.12), (x, y - 0.04)], fill=0)
    poly(d, [(0.0, -0.95), (0.05, -0.95), (0.1, 0.85), (0.06, 0.85)], fill=120)  # the quill
    return m.rotate(-28, resample=Image.BICUBIC)


def ember():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, drop_pts(0.42, 0.8, 1.6, -0.05))
    ellipse(d, 0, -0.35, 0.22, 0.25, 255)
    return m


def gear():
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0, 0.62, 0.62)
    for k in range(8):
        poly(d, rot([(-0.13, 0.5), (0.13, 0.5), (0.1, 0.88), (-0.1, 0.88)], k * math.pi / 4))
    ellipse(d, 0, 0, 0.24, 0.24, 0)
    return m


def wisp():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.85, -0.8), (0.12, 0.52), (0.52, 0.12)], fill=140)
    ellipse(d, 0.32, 0.32, 0.36, 0.36)
    return m


def coin():
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0, 0.86, 0.86, 255)
    ellipse(d, 0, 0, 0.68, 0.68, 150)
    ellipse(d, 0, 0, 0.6, 0.6, 225)
    poly(d, rot([(-0.08, -0.4), (0.08, -0.4), (0.08, 0.4), (-0.08, 0.4)], 0.6), fill=255)
    return m


def grain():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.03, -0.95), (0.03, -0.95), (0.03, 0.55), (-0.03, 0.55)], fill=200)
    for k in range(5):
        y = -0.35 + k * 0.27
        for side in (-1, 1):
            poly(d, oval(side * 0.13, y, 0.2, 0.1, side * 0.75))
    poly(d, oval(0, 0.82, 0.09, 0.17))
    return m.rotate(-30, resample=Image.BICUBIC)


def seed():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, drop_pts(0.42, 0.85, 1.0))
    poly(d, [(-0.03, -0.7), (0.03, -0.7), (0.03, 0.6), (-0.03, 0.6)], fill=140)
    return m.rotate(20, resample=Image.BICUBIC)


def clover():
    m = canvas(); d = ImageDraw.Draw(m)
    heart_pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        heart_pts.append((x / 18 * 0.48, ((y + 2) / 18 + 0.83) * 0.48))
    for k in range(3):
        poly(d, rot(heart_pts, k * 2 * math.pi / 3, 0, 0.1))
    poly(d, [(-0.03, 0.1), (0.04, 0.1), (0.32, -0.9), (0.24, -0.9)])
    return m


def zee():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.6, 0.7), (0.62, 0.7), (0.62, 0.48), (-0.22, -0.48), (0.62, -0.48), (0.62, -0.7), (-0.62, -0.7),
             (-0.62, -0.48), (0.22, 0.48), (-0.6, 0.48)])
    return m


def speech():
    m = canvas(); d = ImageDraw.Draw(m)
    (x0, y1), (x1, y0) = P(-0.85, -0.3), P(0.85, 0.7)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.16, fill=255)
    poly(d, [(-0.5, -0.25), (-0.15, -0.25), (-0.62, -0.75)])
    for x in (-0.42, 0, 0.42):
        ellipse(d, x, 0.2, 0.12, 0.12, 0)
    return m


def crumb():
    m = canvas(); d = ImageDraw.Draw(m)
    r = (0.55, 0.42, 0.6, 0.38, 0.5, 0.62, 0.4)
    poly(d, [(r[k] * math.cos(k * 2 * math.pi / 7), r[k] * math.sin(k * 2 * math.pi / 7)) for k in range(7)])
    ellipse(d, 0.68, 0.55, 0.1, 0.1)
    ellipse(d, -0.6, -0.62, 0.08, 0.08)
    return m


def cloud():
    m = canvas(); d = ImageDraw.Draw(m)
    for cx, cy, r in ((-0.45, -0.08, 0.33), (0.0, 0.14, 0.42), (0.45, -0.04, 0.32)):
        ellipse(d, cx, cy, r, r)
    (x0, y1), (x1, y0) = P(-0.76, -0.4), P(0.76, -0.08)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.08, fill=255)
    return m


def pebble():
    m = canvas(); d = ImageDraw.Draw(m)
    r = (0.8, 0.7, 0.55, 0.62, 0.75, 0.68, 0.5, 0.58)
    pts = []
    for k in range(64):  # a smooth, lumpy outline
        a = k / 64 * 2 * math.pi
        f = k / 64 * 8
        i = int(f) % 8
        w = f - int(f)
        rr = r[i] * (1 - w) + r[(i + 1) % 8] * w
        pts.append((rr * math.cos(a), 0.72 * rr * math.sin(a) - 0.05))
    poly(d, pts, fill=215)
    ellipse(d, -0.2, 0.15, 0.25, 0.12, 255)
    return m


def chevron():
    m = canvas(); d = ImageDraw.Draw(m)
    for y in (-0.45, 0.25):
        poly(d, [(-0.75, y - 0.1), (0, y + 0.6), (0.75, y - 0.1), (0.75, y - 0.38), (0, y + 0.3), (-0.75, y - 0.38)])
    return m


def bolt():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(0.15, 0.95), (-0.45, 0.0), (-0.02, 0.0), (-0.25, -0.95), (0.5, 0.15), (0.06, 0.15), (0.4, 0.95)])
    return m


def halo():
    """A flat ring, seen from the side: worn over a head."""
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, oval(0, 0, 0.92, 0.4))
    poly(d, oval(0, 0.02, 0.74, 0.24), fill=0)
    return m.filter(ImageFilter.GaussianBlur(SS * 1.5))


def sword():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.1, -0.3), (0.1, -0.3), (0.1, 0.7), (0, 0.92), (-0.1, 0.7)])
    poly(d, [(-0.04, -0.25), (0.0, -0.25), (0.0, 0.7), (-0.04, 0.7)], fill=170)  # the edge catches the light
    (x0, y1), (x1, y0) = P(-0.42, -0.42), P(0.42, -0.3)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.03, fill=255)
    poly(d, [(-0.06, -0.42), (0.06, -0.42), (0.06, -0.72), (-0.06, -0.72)])
    ellipse(d, 0, -0.8, 0.11, 0.11)
    return m.rotate(-40, resample=Image.BICUBIC)


def drop():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, drop_pts(0.55, 0.85, 1.0, -0.05), fill=200)
    ellipse(d, -0.2, -0.25, 0.11, 0.2, 255)  # where the light catches it
    return m


def butterfly():
    m = canvas(); d = ImageDraw.Draw(m)
    for side in (-1, 1):
        poly(d, oval(side * 0.42, 0.22, 0.44, 0.34, side * 0.5))
        poly(d, oval(side * 0.3, -0.38, 0.28, 0.24, -side * 0.4))
        ellipse(d, side * 0.48, 0.3, 0.12, 0.1, 140)  # a spot on each wing
    poly(d, oval(0, -0.05, 0.07, 0.55), fill=255)
    poly(d, [(-0.02, 0.45), (0.0, 0.45), (-0.18, 0.85), (-0.21, 0.83)])
    poly(d, [(0.0, 0.45), (0.02, 0.45), (0.21, 0.83), (0.18, 0.85)])
    return m


def mist():
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, oval(0, 0, 0.8, 0.26), fill=200)
    poly(d, oval(-0.25, 0.08, 0.4, 0.18), fill=255)
    return m


def house():
    """A little house with a door: the list's mark for a pet that needs a home."""
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.88, 0.12), (0, 0.86), (0.88, 0.12)])                 # roof
    poly(d, [(0.42, 0.5), (0.42, 0.78), (0.6, 0.78), (0.6, 0.35)])    # chimney
    poly(d, [(-0.62, 0.16), (0.62, 0.16), (0.62, -0.8), (-0.62, -0.8)])  # walls
    poly(d, [(-0.2, -0.8), (-0.2, -0.22), (0.2, -0.22), (0.2, -0.8)], fill=0)  # the door, open
    return m


def cake():
    """A two-tier cake: frosting (full white) dripping over darker tiers, three candles. The
    flames are separate, to flicker."""
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.85, -0.85), (0.85, -0.85), (0.85, -0.3), (-0.85, -0.3)], fill=150)  # bottom tier
    poly(d, [(-0.85, -0.3), (0.85, -0.3), (0.85, -0.42), (-0.85, -0.42)])            # its frosting
    for x in (-0.68, -0.34, 0, 0.34, 0.68):
        ellipse(d, x, -0.44, 0.12, 0.12)                                               # ... dripping
    poly(d, [(-0.55, -0.3), (0.55, -0.3), (0.55, 0.15), (-0.55, 0.15)], fill=190)   # top tier
    poly(d, [(-0.55, 0.15), (0.55, 0.15), (0.55, 0.04), (-0.55, 0.04)])
    for x in (-0.4, -0.13, 0.13, 0.4):
        ellipse(d, x, 0.02, 0.1, 0.1)
    for x in (-0.3, 0, 0.3):                                                           # candles
        poly(d, [(x - 0.055, 0.15), (x + 0.055, 0.15), (x + 0.055, 0.55), (x - 0.055, 0.55)])
    poly(d, [(-0.95, -0.92), (0.95, -0.92), (0.95, -0.85), (-0.95, -0.85)], fill=110)  # the plate
    return m


def crown():
    """A small crown: a band, three points with a ball each, jewels left dark. The pet of the day's badge."""
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.8, -0.62), (0.8, -0.62), (0.8, -0.3), (-0.8, -0.3)])                          # the band
    poly(d, [(-0.8, -0.3), (-0.85, 0.42), (-0.4, 0.0), (0, 0.6), (0.4, 0.0), (0.85, 0.42), (0.8, -0.3)])  # points
    for x, y in ((-0.85, 0.5), (0, 0.7), (0.85, 0.5)):
        ellipse(d, x, y, 0.13, 0.13)                                                           # balls
    for x in (-0.45, 0, 0.45):
        ellipse(d, x, -0.46, 0.09, 0.09, fill=110)                                             # jewels
    return m


# 2026-11-12: the pet frame's bubbles (PetFrame: PET_SAID) and a few the families and new traits lacked.
def speechblank():
    """The speech bubble with room inside: an icon goes there (a like)."""
    m = canvas(); d = ImageDraw.Draw(m)
    (x0, y1), (x1, y0) = P(-0.85, -0.3), P(0.85, 0.7)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.16, fill=255)
    poly(d, [(-0.5, -0.25), (-0.15, -0.25), (-0.62, -0.75)])
    return m


def thought():
    """A thought bubble: puffs, and two little ones trailing down-left (a dislike: grumbling)."""
    m = canvas(); d = ImageDraw.Draw(m)
    for cx, cy, r in ((-0.48, 0.22, 0.32), (-0.14, 0.48, 0.34), (0.28, 0.46, 0.33), (0.56, 0.18, 0.3),
                      (0.3, -0.06, 0.3), (-0.12, -0.06, 0.32), (0.0, 0.2, 0.42)):
        ellipse(d, cx, cy, r, r)
    ellipse(d, -0.56, -0.42, 0.13, 0.13)
    ellipse(d, -0.78, -0.7, 0.08, 0.08)
    return m


def shout():
    """A spiky shout, as in a comic, with a spike down-left: something big (a level, a feat)."""
    m = canvas(); d = ImageDraw.Draw(m)
    pts, n = [], 16
    for i in range(n * 2):
        a = math.pi / 2 + i * math.pi / n
        r = (0.9 if i % 2 == 0 else 0.66) * (1.0 if i % 4 else 0.94)
        pts.append((0.06 + r * math.cos(a) * 0.95, 0.14 + r * math.sin(a) * 0.82))
    poly(d, pts)
    poly(d, [(-0.4, -0.3), (-0.12, -0.36), (-0.8, -0.9)])
    return m


def rain():
    """A small rain cloud: a dislike's icon and its burst."""
    m = canvas(); d = ImageDraw.Draw(m)
    for cx, cy, r in ((-0.4, 0.25, 0.28), (0.02, 0.45, 0.36), (0.42, 0.28, 0.27)):
        ellipse(d, cx, cy, r, r)
    (x0, y1), (x1, y0) = P(-0.68, 0.02), P(0.68, 0.32)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.07, fill=255)
    for x in (-0.38, 0.02, 0.42):
        poly(d, rot([(-0.05, 0), (0.05, 0), (0.05, -0.3), (-0.05, -0.3)], -0.35, x, -0.18))
    return m


def yarn():
    """A ball of yarn with a loose end: the cats' ambience. Darker strands wound round it."""
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0.05, 0.66, 0.66)
    c = P(0, 0.05)
    for k, (rx, ry, a) in enumerate(((0.62, 0.3, 20), (0.62, 0.36, -35), (0.5, 0.62, 70), (0.3, 0.6, -10))):
        band = Image.new("L", (BIG, BIG), 0); bd = ImageDraw.Draw(band)
        w, h = rx * BIG / 2, ry * BIG / 2
        bd.ellipse([c[0] - w, c[1] - h, c[0] + w, c[1] + h], outline=255, width=int(BIG * 0.022))
        band = band.rotate(a, center=c, resample=Image.BICUBIC)
        m = ImageChops.subtract(m, band.point(lambda v: int(v * 0.5)))
    d = ImageDraw.Draw(m)
    for i in range(41):
        t = i / 40
        ellipse(d, 0.52 + 0.36 * t, -0.42 - 0.3 * math.sin(t * 3.2), 0.045, 0.045)
    return m


def petal():
    """A flower petal, turning as it falls: the plants' ambience."""
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(200):
        t = i / 200 * 2 * math.pi
        x = 0.42 * math.sin(t) * (1 - 0.35 * math.cos(t))
        y = 0.82 * math.cos(t)
        pts.append((x, y))
    poly(d, rot(pts, 0.5))
    poly(d, rot([(-0.02, -0.6), (0.02, -0.6), (0.02, 0.3), (-0.02, 0.3)], 0.5), fill=150)
    return m


def shell():
    """A scallop shell, ribbed: the murlocs' coast."""
    m = canvas(); d = ImageDraw.Draw(m)
    def edge(a):  # the fan's edge at angle a, from its hinge
        return 1 / math.sqrt((math.cos(a) / 0.85) ** 2 + (math.sin(a) / 1.3) ** 2)
    pts = [(0, -0.6)]
    for i in range(61):
        a = math.pi * (0.12 + 0.76 * i / 60)
        pts.append((edge(a) * math.cos(a), -0.6 + edge(a) * math.sin(a)))
    poly(d, pts)
    for k in range(7):
        a = math.pi * (0.2 + 0.6 * k / 6)
        r = edge(a) * 0.9
        poly(d, [(0.03 * math.sin(a), -0.6 - 0.03 * math.cos(a)), (-0.03 * math.sin(a), -0.6 + 0.03 * math.cos(a)),
                 (r * math.cos(a), -0.6 + r * math.sin(a))], fill=120)
    poly(d, [(-0.28, -0.6), (0.28, -0.6), (0.2, -0.82), (-0.2, -0.82)])
    return m


def banana():
    """A banana (Skøyer: Julius, Dyreparken's chimpanzee): plump in the middle, a stalk at one end."""
    m = canvas(); d = ImageDraw.Draw(m)
    outer, inner = [], []
    for i in range(81):
        t = i / 80
        a = math.pi * (1.12 + 0.76 * t)
        fat = math.sin(math.pi * t) ** 0.8
        outer.append((0.86 * math.cos(a), 0.62 + 0.86 * math.sin(a)))
        r = 0.86 - 0.08 - 0.34 * fat
        inner.append((r * math.cos(a), 0.62 + r * math.sin(a) + 0.1 * fat))
    poly(d, rot(outer + inner[::-1], 0.25))
    a = math.pi * 1.88
    x, y = rot([(0.8 * math.cos(a), 0.62 + 0.8 * math.sin(a))], 0.25)[0]
    poly(d, rot([(-0.06, 0), (0.06, 0), (0.05, 0.2), (-0.05, 0.2)], 0.9, x, y))
    ellipse(d, *rot([(0.86 * math.cos(math.pi * 1.12), 0.62 + 0.86 * math.sin(math.pi * 1.12))], 0.25)[0], 0.05, 0.05, 90)
    return m


def mask():
    """A robber's eye mask (Røverdyr: Kasper, Jesper og Jonatan)."""
    m = canvas(); d = ImageDraw.Draw(m)
    (x0, y1), (x1, y0) = P(-0.82, -0.26), P(0.82, 0.26)
    d.rounded_rectangle([x0, y0, x1, y1], radius=BIG * 0.12, fill=255)
    poly(d, [(-0.12, 0.26), (0.12, 0.26), (0, 0.12)], fill=0)   # the dip over the nose
    poly(d, [(-0.08, -0.26), (0.08, -0.26), (0, -0.1)], fill=0)
    ellipse(d, -0.42, 0.0, 0.2, 0.12, 0)
    ellipse(d, 0.42, 0.0, 0.2, 0.12, 0)
    poly(d, [(0.8, 0.05), (0.98, 0.3), (0.98, 0.12)])            # the ties
    poly(d, [(0.8, -0.05), (0.98, -0.28), (0.98, -0.1)])
    return m


def sun():
    """A sun: a disc and eight rays (Solelsker)."""
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, 0, 0.42, 0.42)
    for k in range(8):
        a = k * math.pi / 4
        poly(d, rot([(-0.1, 0.55), (0.1, 0.55), (0, 0.92)], a))
    return m


def badge():
    """A sheriff's star, balls on its points (Ordensdyr: Politimester Bastian)."""
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(12):
        r = 0.78 if i % 2 == 0 else 0.42
        a = math.pi / 2 + i * math.pi / 6
        pts.append((r * math.cos(a), r * math.sin(a)))
    poly(d, pts)
    for i in range(6):
        a = math.pi / 2 + i * math.pi / 3
        ellipse(d, 0.84 * math.cos(a), 0.84 * math.sin(a), 0.1, 0.1)
    ellipse(d, 0, 0, 0.22, 0.22, 120)
    return m


SHAPES = {"heart": heart, "sparkle": sparkle, "star": star, "dot": dot, "bubble": bubble, "confetti": confetti,
          "note": note, "paw": paw, "leaf": leaf, "moon": moon, "snowflake": snowflake, "ring": ring, "rays": rays,
          "feather": feather, "ember": ember, "gear": gear, "wisp": wisp, "coin": coin, "grain": grain,
          "seed": seed, "clover": clover, "zee": zee, "speech": speech, "crumb": crumb, "cloud": cloud,
          "pebble": pebble, "chevron": chevron, "bolt": bolt, "halo": halo, "sword": sword, "drop": drop,
          "butterfly": butterfly, "mist": mist, "house": house, "cake": cake, "crown": crown,
          "speechblank": speechblank, "thought": thought, "shout": shout, "rain": rain, "yarn": yarn, "petal": petal,
          "shell": shell, "banana": banana, "mask": mask, "sun": sun, "badge": badge}
BIGGER = {"rays": 128}  # drawn at this size instead of SIZE
SOFTER = {"ember": 3.5, "wisp": 4, "cloud": 2.5, "mist": 9}  # blurred more: they glow or drift


def write_tga(path, mask):
    w, h = mask.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    a = mask.load()
    rows = []
    for y in range(h - 1, -1, -1):  # bottom-left origin
        rows.append(b"".join(struct.pack("BBBB", 255, 255, 255, a[x, y]) for x in range(w)))
    with open(path, "wb") as f:
        f.write(header + b"".join(rows))


def main(only=None):
    """only: the names to draw (--only a,b); the rest of the files are left as they are."""
    os.makedirs(OUT, exist_ok=True)
    shapes = [(n, f) for n, f in SHAPES.items() if not only or n in only]
    sheet = Image.new("RGBA", (SIZE * len(shapes), SIZE), (40, 32, 26, 255))
    for i, (name, fn) in enumerate(shapes):
        big = fn().filter(ImageFilter.GaussianBlur(SS * SOFTER.get(name, 0.6)))
        size = BIGGER.get(name, SIZE)
        write_tga(os.path.join(OUT, name + ".tga"), big.resize((size, size), Image.LANCZOS))
        mask = big.resize((SIZE, SIZE), Image.LANCZOS)
        sheet.paste(Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255)), (i * SIZE, 0), mask)
        print("wrote", name)
    return sheet


if __name__ == "__main__":
    import sys
    args = sys.argv[1:]
    only = None
    if "--only" in args:
        i = args.index("--only")
        only = set(args[i + 1].split(","))
        del args[i:i + 2]
    s = main(only)
    if args:
        s.save(args[0])
