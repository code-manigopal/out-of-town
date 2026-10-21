"""Overlay the 3D head renders on the sheet panels using the MediaPipe landmark similarity transform.

    tools/.venv/bin/python -I tools/likeness/overlay_mp.py OUT_PREFIX SHEET_DET.json RENDER_DET.json CAMS.json \
        front=render_rgba.png q34L=... q34R=... [profile=...]

Per view the render (RGBA, transparent background) is mapped into sheet pixels with the similarity that best
aligns its 468 landmarks (profile: the 14 hand-annotated points) to the sheet's, then written as
OUT_PREFIX_<view>.png (left: 50% blend, right: render outline red / sheet head outline green) and
OUT_PREFIX_all.png. Prints the head-silhouette IoU above the eyebrows (hair volume check) and the hair
top / side extents (sheet px) of both.
"""
import json
import os
import sys

import cv2
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from mp_error import IDX, procrustes  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHEET = cv2.imread(os.path.join(REPO, "docs/art/sheets/mani/mani_p1_face.png"))
PANELS = {"front": (0, 0, 411, 825), "q34L": (411, 0, 849, 825), "profile": (849, 0, 1253, 825), "q34R": (1253, 0, 1672, 825)}
LDIR = os.path.join(REPO, "art_source/characters/mani/likeness")


def cam_project(cam, P):
    M = np.array(cam["mat"])
    Xc = (P - M[:3, 3]) @ M[:3, :3]
    z = -Xc[:, 2]
    W, H = cam["res"]
    f = cam["lens"] / cam["sensor"] * W
    return np.stack([W / 2 + f * Xc[:, 0] / z, H / 2 - f * Xc[:, 1] / z], 1)


def sheet_head_mask(box):
    x0, y0, x1, y1 = box
    p = SHEET[y0:y1, x0:x1].astype(np.float32)
    bg = np.median(np.concatenate([p[5:40, 5:40].reshape(-1, 3), p[5:40, -40:-5].reshape(-1, 3)]), axis=0)
    m = (np.abs(p - bg).max(-1) > 28).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_OPEN, np.ones((5, 5), np.uint8))
    return m


def main():
    prefix, sd, rd, cj = sys.argv[1:5]
    sheet, rend, cams = json.load(open(sd)), json.load(open(rd)), json.load(open(cj))
    items = dict(a.split("=", 1) for a in sys.argv[5:])
    ml = json.load(open(os.path.join(LDIR, "model_landmarks.json")))
    sj = json.load(open(os.path.join(LDIR, "sheet_landmarks.json")))
    tiles, warps = [], []
    for v, path in items.items():
        box = PANELS[v]
        img = cv2.imread(path, cv2.IMREAD_UNCHANGED)
        if v == "profile":
            names = [k for k in sj["points"]["profile"] if k in ml["profile"]]
            P3 = np.array([ml["profile"][k] for k in names])
            P = cam_project(cams["profile"], P3)
            Q = np.array([sj["points"]["profile"][k] for k in names], float) + np.array([box[0], box[1]])
        else:
            P = np.array(rend[v]["pts"])[IDX]
            Q = np.array(sheet[v]["pts"])[IDX]
        R, t = procrustes(P, Q)
        M = np.hstack([R, t[:, None]]).astype(np.float32)
        warped = cv2.warpAffine(img, M, (SHEET.shape[1], SHEET.shape[0]), flags=cv2.INTER_LINEAR, borderValue=(0, 0, 0, 0))
        x0, y0, x1, y1 = box
        crop = warped[y0:y1, x0:x1]
        alpha = (crop[..., 3] > 128).astype(np.uint8) if crop.shape[2] == 4 else np.ones(crop.shape[:2], np.uint8)
        panel = SHEET[y0:y1, x0:x1].copy()
        a = (crop[..., 3:4] / 255.0) if crop.shape[2] == 4 else 1.0
        blend = (panel * 0.5 + crop[..., :3] * 0.5 * a + panel * 0.5 * (1 - a)).astype(np.uint8)
        left = blend
        right = (panel * 0.55).astype(np.uint8)
        smask = sheet_head_mask(box)
        for m, col in ((alpha, (40, 40, 255)), (smask, (60, 255, 60))):
            cs, _ = cv2.findContours(m, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_NONE)
            cv2.drawContours(right, cs, -1, col, 1)
        # metrics above the brows (front/q34): head silhouette IoU + top/side extents
        yb = int((Q[:, 1].min() if v != "profile" else 330) - y0)
        top = lambda m: int(np.argmax(m.any(1)))
        cut = max(yb, 50)
        inter = (alpha[:cut] & smask[:cut]).sum()
        uni = (alpha[:cut] | smask[:cut]).sum()
        ext = lambda m: (int(np.argmax(m[:cut].any(0))), int(m.shape[1] - np.argmax(m[:cut].any(0)[::-1])))
        print("%-7s IoU above brows %.3f | top y sheet %d render %d | x-extent sheet %s render %s" % (v, inter / max(uni, 1), top(smask), top(alpha), ext(smask), ext(alpha)))
        bgc = np.median(SHEET[5:40, 5:40].reshape(-1, 3), axis=0)
        warp_tile = (np.ones_like(panel) * bgc + 0).astype(np.float32)
        if crop.shape[2] == 4:
            warp_tile = warp_tile * (1 - a) + crop[..., :3].astype(np.float32) * a
        warps.append((panel, warp_tile.astype(np.uint8)))
        tile = np.hstack([left, right])
        cv2.imwrite("%s_%s.png" % (prefix, v), tile)
        tiles.append(tile)
    if warps:
        top = np.hstack([w[0] for w in warps]); bot = np.hstack([w[1] for w in warps])
        cv2.imwrite("%s_face_vs_sheet.png" % prefix, np.vstack([top, bot]))
    def padw(t, w):
        return np.hstack([t, np.zeros((t.shape[0], w - t.shape[1], 3), np.uint8)]) if t.shape[1] < w else t
    if len(tiles) == 4:
        r1, r2 = np.hstack(tiles[:2]), np.hstack(tiles[2:])
        w = max(r1.shape[1], r2.shape[1])
        cv2.imwrite("%s_all.png" % prefix, np.vstack([padw(r1, w), padw(r2, w)]))
    else:
        cv2.imwrite("%s_all.png" % prefix, np.hstack(tiles))


main()
