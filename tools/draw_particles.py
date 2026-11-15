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


# Parken's family signs (2026-11-15): marks that read at 12 px, where the cards' ambience particles didn't.
def snake():
    """A snake in an S, a head with a forked tongue."""
    m = canvas(); d = ImageDraw.Draw(m)
    for i in range(140):
        t = i / 139
        y = 0.72 - 1.44 * t
        x = 0.36 * math.sin(t * 2 * math.pi + 0.3)
        r = 0.2 * (1 - 0.5 * t) + 0.06
        ellipse(d, x, y, r, r)
    ellipse(d, 0.36 * math.sin(0.3), 0.74, 0.24, 0.19)
    poly(d, [(0.09, 0.9), (0.15, 0.9), (0.02, 1.0)])
    return m


def cheese():
    """A wedge of cheese with holes."""
    m = canvas(); d = ImageDraw.Draw(m)
    poly(d, [(-0.8, -0.45), (0.8, -0.45), (0.8, 0.15), (-0.8, -0.05)])
    poly(d, [(-0.8, -0.05), (0.8, 0.15), (0.45, 0.55)])
    for cx, cy, r in ((-0.35, -0.22, 0.11), (0.25, -0.12, 0.14), (0.55, -0.32, 0.08), (0.0, 0.18, 0.08)):
        ellipse(d, cx, cy, r, r, 0)
    return m


def horseshoe():
    """A horseshoe, open end down, with nail holes."""
    m = canvas(); d = ImageDraw.Draw(m)
    outer, inner = [], []
    for i in range(121):
        a = math.pi * (-0.15 + 1.3 * i / 120)
        outer.append((0.72 * math.cos(a), 0.05 + 0.78 * math.sin(a)))
        inner.append((0.4 * math.cos(a), 0.05 + 0.46 * math.sin(a)))
    poly(d, outer + inner[::-1])
    poly(d, [(0.4, -0.12), (0.72, -0.12), (0.7, -0.6), (0.44, -0.6)])
    poly(d, [(-0.4, -0.12), (-0.72, -0.12), (-0.7, -0.6), (-0.44, -0.6)])
    for a in (0.15, 0.4, 0.6, 0.85):
        t = math.pi * a
        ellipse(d, 0.56 * math.cos(t), 0.05 + 0.62 * math.sin(t), 0.05, 0.05, 0)
    return m


def lilypad():
    """A lily pad, a notch cut in, a flower on it."""
    m = canvas(); d = ImageDraw.Draw(m)
    ellipse(d, 0, -0.08, 0.82, 0.7)
    poly(d, [(0.05, -0.08), (0.9, 0.04), (0.9, -0.22)], fill=0)
    for k in range(6):
        a = k * math.pi / 3
        ellipse(d, -0.25 + 0.17 * math.cos(a), 0.12 + 0.17 * math.sin(a), 0.12, 0.12, 120)
    ellipse(d, -0.25, 0.12, 0.08, 0.08, 255)
    return m


def egg():
    """An egg with speckles (the reptiles: crocolisks and their kin hatch from them)."""
    m = canvas(); d = ImageDraw.Draw(m)
    pts = []
    for i in range(120):
        t = i / 120 * 2 * math.pi
        y = 0.82 * math.sin(t)
        x = 0.6 * math.cos(t) * (1 - 0.18 * math.sin(t))
        pts.append((x, y - 0.04))
    poly(d, pts)
    for cx, cy, r in ((-0.2, 0.3, 0.08), (0.18, 0.1, 0.1), (-0.15, -0.3, 0.07), (0.25, -0.4, 0.06)):
        ellipse(d, cx, cy, r, r, 110)
    return m


SHAPES = {"heart": heart, "sparkle": sparkle, "star": star, "dot": dot, "bubble": bubble, "confetti": confetti,
          "note": note, "paw": paw, "leaf": leaf, "moon": moon, "snowflake": snowflake, "ring": ring, "rays": rays,
          "feather": feather, "ember": ember, "gear": gear, "wisp": wisp, "coin": coin, "grain": grain,
          "seed": seed, "clover": clover, "zee": zee, "speech": speech, "crumb": crumb, "cloud": cloud,
          "pebble": pebble, "chevron": chevron, "bolt": bolt, "halo": halo, "sword": sword, "drop": drop,
          "butterfly": butterfly, "mist": mist, "house": house, "cake": cake, "crown": crown,
          "speechblank": speechblank, "thought": thought, "shout": shout, "rain": rain, "yarn": yarn, "petal": petal,
          "shell": shell, "banana": banana, "mask": mask, "sun": sun, "badge": badge,
          "snake": snake, "cheese": cheese, "horseshoe": horseshoe, "lilypad": lilypad, "egg": egg}
BIGGER = {"rays": 128}  # drawn at this size instead of SIZE
SOFTER = {"ember": 3.5, "wisp": 4, "cloud": 2.5, "mist": 9}  # blurred more: they glow or drift


# Wood (2026-11-15, Parken's fences: the user, "a wooden textured fence"): in color, not white to tint,
# so its grain shows. A rail (64x16, repeats along its length) and a post's top (16x16).
def plank():
    """A rail: brown, lit along its top edge, shaded along the bottom, grain in long wavy streaks and a knot.
    Seamless left to right (every wave and the knot's falloff repeat over the 64 px)."""
    w, h = 64, 16
    img = Image.new("RGBA", (w, h))
    px = img.load()
    base = (128, 88, 52)
    for y in range(h):
        for x in range(w):
            t = x / w * 2 * math.pi
            v = y / (h - 1)
            grain = math.sin(v * 9.5 + 0.9 * math.sin(t) + 0.4 * math.sin(3 * t + 1.3))
            grain = 0.11 * grain + 0.05 * math.sin(v * 31 + 2 * math.sin(2 * t))
            dx = min(abs(x - 40), w - abs(x - 40)) / 5.0
            knot = 0.22 * math.exp(-(dx * dx + ((y - 8) / 2.6) ** 2))
            light = 1.0 + grain - knot
            if y <= 1: light += 0.32 - 0.12 * y      # the top edge, in the light
            if y >= h - 2: light -= 0.3 + 0.1 * (y - (h - 2))  # the bottom, in shade
            px[x, y] = tuple(max(0, min(255, int(c * light))) for c in base) + (255,)
    return img


def post():
    """A post's top, seen from above: a darker square with a lit bevel, rings of the trunk."""
    n = 16
    img = Image.new("RGBA", (n, n))
    px = img.load()
    base = (104, 70, 40)
    for y in range(n):
        for x in range(n):
            r = math.hypot(x - 7.5, y - 7.5)
            light = 1.0 + 0.08 * math.sin(r * 2.2)
            if x <= 1 or y <= 1: light += 0.3
            if x >= n - 2 or y >= n - 2: light -= 0.35
            px[x, y] = tuple(max(0, min(255, int(c * light))) for c in base) + (255,)
    return img


def _rgba_canvas(n=64):
    return Image.new("RGBA", (n * SS, n * SS), (0, 0, 0, 0))


def _shrink(img, n=64):
    return img.resize((n, n), Image.LANCZOS)


def _q(v):  # -1..1 (y up) to the 4x canvas
    return P(v[0], v[1])


def _ell(d, cx, cy, rx, ry, fill):
    (x0, y1), (x1, y0) = P(cx - rx, cy - ry), P(cx + rx, cy + ry)
    d.ellipse([x0, y0, x1, y1], fill=fill)


def sign():
    """A little wooden sign board (Parken's family signs): planks, a dark rim, two nail heads. 32x24 on 32x32."""
    w, h = 32, 24
    img = Image.new("RGBA", (w * SS, h * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([0, 0, w * SS - 1, h * SS - 1], radius=3 * SS, fill=(62, 40, 22, 255))
    d.rounded_rectangle([2 * SS, 2 * SS, (w - 2) * SS - 1, (h - 2) * SS - 1], radius=2 * SS, fill=(150, 104, 62, 255))
    d.line([2 * SS, h * SS // 2, (w - 2) * SS, h * SS // 2], fill=(112, 76, 44, 255), width=SS)  # two planks
    for y in range(3 * SS, (h - 3) * SS, 3 * SS):
        d.line([3 * SS, y, (w - 3) * SS, y + SS], fill=(138, 95, 56, 255), width=1)
    d.line([2 * SS, 2 * SS, (w - 2) * SS, 2 * SS], fill=(186, 140, 92, 255), width=SS)  # lit top
    for x in (4, w - 5):
        d.ellipse([x * SS - SS, 4 * SS - SS, x * SS + SS, 4 * SS + SS], fill=(70, 66, 60, 255))
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))  # (on a 32x32: a texture's sides a power of two)
    out.paste(img.resize((w, h), Image.LANCZOS), (0, 4))
    return out


def tree():
    """A round tree seen from above: a shadow, a crown in three greens, a light side."""
    img = _rgba_canvas(); d = ImageDraw.Draw(img)
    _ell(d, 0.08, -0.1, 0.78, 0.74, (0, 0, 0, 90))
    _ell(d, 0, 0, 0.74, 0.72, (38, 82, 34, 255))
    for cx, cy, r in ((-0.3, 0.25, 0.36), (0.28, 0.22, 0.38), (0.0, -0.25, 0.4), (-0.28, -0.12, 0.3), (0.3, -0.2, 0.3)):
        _ell(d, cx, cy, r, r, (56, 112, 44, 255))
    for cx, cy, r in ((-0.32, 0.32, 0.18), (0.18, 0.34, 0.16), (-0.1, 0.05, 0.14)):
        _ell(d, cx, cy, r, r, (96, 150, 64, 255))
    return _shrink(img.filter(ImageFilter.GaussianBlur(SS * 0.5)))


def bush():
    """A low bush with a few flowers."""
    img = _rgba_canvas(); d = ImageDraw.Draw(img)
    _ell(d, 0.06, -0.3, 0.7, 0.36, (0, 0, 0, 80))
    for cx, cy, r in ((-0.38, -0.1, 0.32), (0.0, 0.05, 0.4), (0.38, -0.1, 0.32)):
        _ell(d, cx, cy, r, r * 0.85, (50, 100, 42, 255))
    for cx, cy in ((-0.4, 0.05), (0.05, 0.25), (0.35, 0.02), (-0.1, -0.08)):
        _ell(d, cx, cy, 0.07, 0.07, (240, 200, 220, 255))
    return _shrink(img.filter(ImageFilter.GaussianBlur(SS * 0.4)))


def pond():
    """A small pond: a stony rim, water darker in the middle, a glint and a lily pad."""
    img = _rgba_canvas(); d = ImageDraw.Draw(img)
    _ell(d, 0, 0, 0.86, 0.66, (112, 104, 90, 255))
    _ell(d, 0, 0, 0.76, 0.56, (52, 96, 128, 255))
    _ell(d, 0.05, -0.05, 0.5, 0.34, (36, 72, 104, 255))
    _ell(d, -0.35, 0.22, 0.2, 0.06, (170, 210, 230, 200))
    _ell(d, 0.35, -0.12, 0.17, 0.13, (70, 140, 60, 255))
    _ell(d, 0.34, -0.08, 0.04, 0.04, (240, 220, 240, 255))
    return _shrink(img.filter(ImageFilter.GaussianBlur(SS * 0.4)))


def flowers():
    """Three little clusters of flowers on leaves, no ground under them (a patch read as a blot, 2026-11-15)."""
    img = _rgba_canvas(); d = ImageDraw.Draw(img)
    for (x, y), c in (((-0.38, 0.22), (235, 96, 96, 255)), ((0.32, 0.3), (250, 210, 80, 255)),
                      ((0.0, -0.32), (186, 136, 236, 255))):
        for a in (-0.9, 0.9):
            _ell(d, x + 0.16 * math.cos(a - math.pi / 2), y - 0.12, 0.12, 0.06, (64, 120, 52, 255))
        for k in range(5):
            t = k / 5 * 2 * math.pi + 0.3
            _ell(d, x + 0.1 * math.cos(t), y + 0.1 * math.sin(t), 0.075, 0.075, c)
        _ell(d, x, y, 0.05, 0.05, (250, 236, 150, 255))
    return _shrink(img.filter(ImageFilter.GaussianBlur(SS * 0.3)))


def stump():
    """A tree stump from above: bark round a cut face with its rings, a small shadow."""
    img = _rgba_canvas(); d = ImageDraw.Draw(img)
    _ell(d, 0.08, -0.08, 0.66, 0.62, (0, 0, 0, 80))
    _ell(d, 0, 0, 0.62, 0.6, (84, 56, 32, 255))
    _ell(d, 0, 0, 0.52, 0.5, (196, 156, 104, 255))
    for r in (0.4, 0.28, 0.16):
        (x0, y1), (x1, y0) = P(-r, -r * 0.95), P(r, r * 0.95)
        d.ellipse([x0, y0, x1, y1], outline=(150, 112, 70, 255), width=SS)
    return _shrink(img.filter(ImageFilter.GaussianBlur(SS * 0.3)))


TURF = 128  # px: one tile of Parken's pens, laid over TURF_CELLS cells each way (ParkPage, Park.Grain)


def _wrap_noise(rnd, n, size):
    """Smooth noise from an n x n grid of random values that tiles seamlessly at size px."""
    small = Image.new("L", (n, n))
    small.putdata([rnd.randrange(256) for _ in range(n * n)])
    tiled = Image.new("L", (n * 3, n * 3))
    for i in range(3):
        for j in range(3):
            tiled.paste(small, (i * n, j * n))
    big = tiled.resize((size * 3, size * 3), Image.BICUBIC)
    return big.crop((size, size, size * 2, size * 2))


def turf():
    """The pens' ground (2026-11-15, the user: "some grain / texture without being too noisy"): near white,
    tinted by the family's color, with soft patches, smaller blotches and a fine grain; tiles seamlessly."""
    import random
    rnd = random.Random(1515)
    layers = [(_wrap_noise(rnd, 4, TURF), 0.10), (_wrap_noise(rnd, 16, TURF), 0.07),
              (_wrap_noise(rnd, TURF, TURF), 0.07)]
    px = [l.load() for l, _ in layers]
    img = Image.new("RGBA", (TURF, TURF)); out = img.load()
    for y in range(TURF):
        for x in range(TURF):
            dark = sum(w * p[x, y] / 255 for p, (_, w) in zip(px, layers))
            c = max(0, min(255, round(255 * (1 - dark))))
            # (in the alpha too: at the pens' faint tint, a change of color alone barely shows)
            out[x, y] = (c, c, c, max(0, min(255, round(255 * (1 - 2.2 * dark)))))
    return img


COLORED = {"plank": plank, "post": post, "sign": sign, "tree": tree, "bush": bush, "pond": pond,
           "flowers": flowers, "stump": stump, "turf": turf}


def write_rgba(path, img):
    w, h = img.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    p = img.load()
    rows = []
    for y in range(h - 1, -1, -1):
        rows.append(b"".join(struct.pack("BBBB", p[x, y][2], p[x, y][1], p[x, y][0], p[x, y][3]) for x in range(w)))
    with open(path, "wb") as f:
        f.write(header + b"".join(rows))


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
    for name, fn in COLORED.items():
        if not only or name in only:
            write_rgba(os.path.join(OUT, name + ".tga"), fn())
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
