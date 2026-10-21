"""Derived textures for the Windsor exterior (run with tools/.venv/bin/python):
  - white_planks_h_*: Poly Haven white_planks_clean rotated 90 degrees (horizontal clapboard), normal map re-oriented
  - leaf_*.png: procedurally drawn autumn leaf-cluster cards (alpha cut-outs) for the street trees (ours, CC0)
  - paint_c.png: worn road-paint alpha mask (ours, CC0)"""
import os, math, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
PH = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "textures", "ph")
TX = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "textures")

def rot_planks():
    for tag in ("diff", "rough"):
        Image.open(os.path.join(PH, "white_planks_clean_%s.jpg" % tag)).rotate(90).save(os.path.join(PH, "white_planks_h_%s.jpg" % tag), quality=92)
    n = np.asarray(Image.open(os.path.join(PH, "white_planks_clean_nor.jpg")).convert("RGB")).astype(np.float32)
    r, g, b = n[..., 0], n[..., 1], n[..., 2]
    out = np.stack([255 - g, r, b], -1)
    out = np.rot90(out, 1)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(os.path.join(PH, "white_planks_h_nor.jpg"), quality=92)

def leaf_poly(cx, cy, ang, ln, wd, rng, lobes=True):
    pts = []
    n = 14
    for i in range(n + 1):
        t = i / n
        w = math.sin(math.pi * t) ** 0.8 * wd * (1.0 + (0.18 * math.sin(t * 22) if lobes else 0))
        pts.append((t * ln, w))
    for i in range(n, -1, -1):
        t = i / n
        w = math.sin(math.pi * t) ** 0.8 * wd * (1.0 + (0.18 * math.sin(t * 22 + 1.7) if lobes else 0))
        pts.append((t * ln, -w))
    ca, sa = math.cos(ang), math.sin(ang)
    return [(cx + x * ca - y * sa, cy + x * sa + y * ca) for x, y in pts]

def leaf_card(name, palette, seed, size=512, count=190, bare_gap=0.0):
    rng = random.Random(seed)
    S = 2
    im = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    # twig
    for k in range(6):
        a = rng.uniform(-0.5, 0.5) - math.pi / 2
        x, y = size * S * 0.5, size * S * 0.97
        pts = [(x, y)]
        for s in range(14):
            a += rng.uniform(-0.12, 0.12)
            x += math.cos(a) * size * S * 0.05
            y += math.sin(a) * size * S * 0.05
            pts.append((x, y))
        d.line(pts, fill=(70, 52, 38, 255), width=4 * S)
    cx0, cy0 = size * S * 0.5, size * S * 0.5
    for i in range(count):
        r = rng.random() ** 0.7 * size * S * 0.44
        a = rng.uniform(0, math.tau)
        cx = cx0 + math.cos(a) * r
        cy = cy0 + math.sin(a) * r * 0.9
        ang = rng.uniform(0, math.tau)
        ln = rng.uniform(0.085, 0.13) * size * S
        wd = ln * rng.uniform(0.28, 0.4)
        base = rng.choice(palette)
        sh = rng.uniform(0.82, 1.1)
        col = tuple(int(min(255, c * sh)) for c in base) + (255,)
        poly = leaf_poly(cx, cy, ang, ln, wd, rng)
        d.polygon(poly, fill=col)
        edge = tuple(int(c * 0.72) for c in base) + (255,)
        d.line(poly + [poly[0]], fill=edge, width=max(1, S))
        vein = tuple(min(255, int(c * 1.25)) for c in base) + (255,)
        ca, sa = math.cos(ang), math.sin(ang)
        d.line([(cx, cy), (cx + ca * ln * 0.92, cy + sa * ln * 0.92)], fill=vein, width=max(1, S))
    im = im.resize((size, size), Image.LANCZOS)
    a = np.asarray(im)[..., 3]
    # fix fringe: bleed colour into transparent pixels
    rgb = Image.fromarray(np.asarray(im)[..., :3]).filter(ImageFilter.MaxFilter(5))
    out = np.asarray(im).copy()
    mask = out[..., 3] < 8
    out[..., :3][mask] = np.asarray(rgb)[mask]
    Image.fromarray(out).save(os.path.join(TX, name), optimize=True)

def litter_card(name, palette, seed, size=256, count=11):
    """Loose fallen leaves scattered over a transparent card (no twig), for the Proton Scatter litter."""
    rng = random.Random(seed)
    S = 2
    im = Image.new("RGBA", (size * S, size * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    for i in range(count):
        cx = rng.uniform(0.12, 0.88) * size * S
        cy = rng.uniform(0.12, 0.88) * size * S
        ang = rng.uniform(0, math.tau)
        ln = rng.uniform(0.12, 0.2) * size * S
        wd = ln * rng.uniform(0.3, 0.42)
        base = rng.choice(palette)
        col = tuple(int(min(255, c * rng.uniform(0.7, 1.0))) for c in base) + (255,)
        poly = leaf_poly(cx, cy, ang, ln, wd, rng)
        d.polygon(poly, fill=col)
        d.line(poly + [poly[0]], fill=tuple(int(c * 0.6) for c in base) + (255,), width=S)
        ca, sa = math.cos(ang), math.sin(ang)
        d.line([(cx, cy), (cx + ca * ln * 0.9, cy + sa * ln * 0.9)], fill=tuple(min(255, int(c * 1.15)) for c in base) + (255,), width=S)
    im = im.resize((size, size), Image.LANCZOS)
    rgb = Image.fromarray(np.asarray(im)[..., :3]).filter(ImageFilter.MaxFilter(5))
    out = np.asarray(im).copy()
    mask = out[..., 3] < 8
    out[..., :3][mask] = np.asarray(rgb)[mask]
    Image.fromarray(out).save(os.path.join(TX, name), optimize=True)


def puddle_mask():
    """An irregular puddle: soft alpha blob with a wobbly edge (the Puddle material uses it on a round mesh)."""
    n = 256
    rng = np.random.RandomState(9)
    ys, xs = np.mgrid[0:n, 0:n].astype(np.float32)
    cx = cy = (n - 1) / 2.0
    ang = np.arctan2(ys - cy, xs - cx)
    r = np.hypot(xs - cx, ys - cy) / (n / 2.0)
    wob = np.zeros_like(r)
    for k, amp in ((2, 0.16), (3, 0.12), (5, 0.07), (8, 0.04)):
        wob += amp * np.sin(k * ang + rng.uniform(0, 6.28))
    edge = 0.74 + wob
    a = np.clip((edge - r) / 0.12, 0.0, 1.0)
    a = a * a * (3 - 2 * a)
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = (12, 15, 18)
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img).save(os.path.join(TX, "puddle_c.png"), optimize=True)


def paint_mask():
    rng = np.random.RandomState(5)
    n = 256
    a = np.ones((n, n), np.float32)
    for _ in range(150):
        x, y = rng.randint(0, n, 2)
        r = rng.randint(1, 3)
        a[max(0, y - r):y + r, max(0, x - r):x + r] = rng.uniform(0.0, 0.45)
    # scuffs: faint streaks
    for _ in range(40):
        x, y = rng.randint(0, n, 2)
        L = rng.randint(10, 60)
        a[y:y + 2, max(0, x - L // 2):x + L // 2] *= 0.7
    img = np.zeros((n, n, 4), np.uint8)
    img[..., :3] = 255
    img[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(img).save(os.path.join(TX, "paint_c.png"), optimize=True)

if __name__ == "__main__":
    rot_planks()
    leaf_card("leaf_orange.png", [(214, 112, 28), (226, 140, 36), (190, 78, 24), (232, 168, 48)], 11)
    leaf_card("leaf_yellow.png", [(224, 182, 46), (238, 204, 66), (206, 150, 34), (190, 150, 40)], 12)
    leaf_card("leaf_rust.png", [(166, 66, 28), (184, 90, 30), (140, 52, 26), (200, 120, 40)], 13)
    leaf_card("leaf_green.png", [(110, 130, 40), (140, 150, 46), (190, 160, 46), (96, 112, 38)], 14)
    litter_card("litter_orange.png", [(176, 84, 24), (196, 110, 30), (150, 66, 22), (206, 140, 40)], 21)
    litter_card("litter_yellow.png", [(196, 150, 36), (210, 172, 52), (170, 120, 30), (156, 124, 34)], 22)
    litter_card("litter_rust.png", [(120, 52, 24), (140, 66, 26), (98, 46, 24), (156, 92, 34)], 23)
    puddle_mask()
    paint_mask()
