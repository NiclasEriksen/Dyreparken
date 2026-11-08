"""Draws the pet card's particle textures (Media/Particles/*.tga): python3 tools/draw_particles.py

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


SHAPES = {"heart": heart, "sparkle": sparkle, "star": star, "dot": dot, "bubble": bubble, "confetti": confetti,
          "note": note, "paw": paw, "leaf": leaf, "moon": moon, "snowflake": snowflake}


def write_tga(path, mask):
    w, h = mask.size
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    a = mask.load()
    rows = []
    for y in range(h - 1, -1, -1):  # bottom-left origin
        rows.append(b"".join(struct.pack("BBBB", 255, 255, 255, a[x, y]) for x in range(w)))
    with open(path, "wb") as f:
        f.write(header + b"".join(rows))


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet = Image.new("RGBA", (SIZE * len(SHAPES), SIZE), (40, 32, 26, 255))
    for i, (name, fn) in enumerate(SHAPES.items()):
        big = fn().filter(ImageFilter.GaussianBlur(SS * 0.6))
        mask = big.resize((SIZE, SIZE), Image.LANCZOS)
        write_tga(os.path.join(OUT, name + ".tga"), mask)
        sheet.paste(Image.new("RGBA", (SIZE, SIZE), (255, 255, 255, 255)), (i * SIZE, 0), mask)
        print("wrote", name)
    return sheet


if __name__ == "__main__":
    import sys
    s = main()
    if len(sys.argv) > 1:
        s.save(sys.argv[1])
