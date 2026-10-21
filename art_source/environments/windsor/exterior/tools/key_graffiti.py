"""Cuts the paint of graffiti_1..4.png (they include their own brick wall and a ground strip) out to alpha:
writes graffiti_N_alpha.png (cropped to the paint) and graffiti/alpha_sizes.json (pixel size of each crop). Originals stay.
Run with tools/.venv/bin/python."""
import os, json, cv2, numpy as np
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", "..", ".."))
DIR = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "graffiti")
# per image: (open px, close px, hole area to fill, min component area)
PARAMS = {1: (5, 9, 30000, 1500), 2: (5, 9, 4000, 2500), 3: (7, 141, 90000, 4000), 4: (5, 9, 6000, 2500)}
LINK = {1: 28, 2: 50, 3: 40, 4: 120}   # components farther than this from the main paint are dropped

def fill_holes(mask, max_area):
    inv = (mask == 0).astype(np.uint8)
    n, lab, stats, _ = cv2.connectedComponentsWithStats(inv, connectivity=4)
    out = mask.copy()
    h, w = mask.shape
    for i in range(1, n):
        x, y, bw, bh, a = stats[i]
        touches = x == 0 or y == 0 or x + bw == w or y + bh == h
        if not touches and a <= max_area:
            out[lab == i] = 255
    return out

def key(i):
    img = cv2.imread(os.path.join(DIR, "graffiti_%d.png" % i), cv2.IMREAD_COLOR)
    h, w = img.shape[:2]
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    H, S, V = hsv[..., 0].astype(int), hsv[..., 1].astype(int), hsv[..., 2].astype(int)
    brick = ((H <= 14) | (H >= 170)) & (S >= 95) & (V >= 70) & (V <= 235)
    dark = V < 70
    pale = (S < (50 if i == 2 else 70)) & (V > (150 if i == 2 else 95))
    other_hue = (S >= 70) & ~((H <= 16) | (H >= 168))
    raw = (dark | pale | other_hue) & ~brick
    # rows that are wall: ground starts below the lowest row that is mostly brick
    rowbrick = brick.mean(axis=1)
    wall_rows = np.where(rowbrick > 0.45)[0]
    ground_y = int(wall_rows.max()) - 6 if len(wall_rows) else h - 40
    raw[ground_y:, :] = False
    if i == 1:
        raw[:120, :110] = False     # the wall vent in the corner
    m = raw.astype(np.uint8) * 255
    po, pc, hole, minc = PARAMS[i]
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (po, po)))
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (pc, pc)))
    n, lab, stats, _ = cv2.connectedComponentsWithStats(m, connectivity=8)
    keep = np.zeros_like(m)
    for k in range(1, n):
        x, y, bw, bh, a = stats[k]
        touches = x == 0 or y == 0 or x + bw == w
        if a < minc or (touches and a < 5000 and not (i == 2)):
            continue
        keep[lab == k] = 255
    m = fill_holes(keep, hole)
    # keep only the paint that is connected (within LINK px) to the biggest piece: drops vents, mortar patches
    grow = cv2.dilate(m, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (LINK[i] * 2 + 1, LINK[i] * 2 + 1)))
    n2, lab2, st2, _ = cv2.connectedComponentsWithStats(grow, connectivity=8)
    big = 1 + int(np.argmax(st2[1:, cv2.CC_STAT_AREA]))
    m = np.where(lab2 == big, m, 0).astype(np.uint8)
    if i == 3:
        m = cv2.morphologyEx(m, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (15, 15)))
    m = cv2.erode(m, np.ones((3, 3), np.uint8), iterations=1)
    a = cv2.GaussianBlur(m, (0, 0), 1.3)
    a = np.clip((a.astype(np.float32) - 40) * (255.0 / 175.0), 0, 255).astype(np.uint8)
    if i == 2:   # the wire runs off both edges: fade it out so it doesn't end in a hard cut
        ramp = np.ones(w, np.float32)
        e = int(w * 0.07)
        ramp[:e] = np.linspace(0, 1, e)
        ramp[-e:] = np.linspace(1, 0, e)
        a = (a.astype(np.float32) * ramp[None, :]).astype(np.uint8)
    ys, xs = np.where(a > 8)
    pad = 10
    x0, x1 = max(xs.min() - pad, 0), min(xs.max() + pad, w - 1)
    y0, y1 = max(ys.min() - pad, 0), min(ys.max() + pad, h - 1)
    rgba = np.dstack([img, a])[y0:y1 + 1, x0:x1 + 1]
    # bleed edge colours outward so mipmaps and filtering don't halo with the brick colour
    rgb = rgba[..., :3].copy()
    solid = (rgba[..., 3] > 200).astype(np.uint8)
    for _ in range(3):
        dil = cv2.dilate(rgb * solid[..., None], np.ones((3, 3), np.uint8))
        edge = (solid == 0)
        rgb[edge] = dil[edge]
        solid = cv2.dilate(solid, np.ones((3, 3), np.uint8))
    # pull the colour of semi-transparent edge pixels toward the solid paint beside them
    soft = (rgba[..., 3] < 235)
    rgba[..., :3] = np.where(soft[..., None], rgb, rgba[..., :3])
    out = os.path.join(DIR, "graffiti_%d_alpha.png" % i)
    cv2.imwrite(out, rgba, [cv2.IMWRITE_PNG_COMPRESSION, 9])
    return out, rgba.shape[1], rgba.shape[0], ground_y

if __name__ == "__main__":
    sizes = {}
    for i in range(1, 5):
        out, w, h, gy = key(i)
        sizes[str(i)] = [w, h]
        print(i, out, w, h, "ground at", gy, os.path.getsize(out) // 1024, "KB")
    json.dump(sizes, open(os.path.join(DIR, "alpha_sizes.json"), "w"))
