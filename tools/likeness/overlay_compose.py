"""Warp the raw ortho renders onto the sheet panels and write 50% overlays. Run in tools/.venv."""
import json
import os
import sys

import cv2
import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
L = os.path.join(REPO, "art_source/characters/mani/likeness")
out = sys.argv[1]
params = json.load(open(os.path.join(out, "overlay_params.json")))
for view, p in params.items():
    panel = cv2.imread(os.path.join(L, "panel_%s.png" % view))
    raw = cv2.imread(os.path.join(out, "raw_%s.png" % view))
    R, t, s = np.array(p["R"]), np.array(p["t"]), p["s"]
    W, H = p["size"]
    mc = np.array(p["mc"])
    # render pixel = (W/2, H/2) + s * (view_xy - mc);  view_xy = R^-1 (sheet_uv - t) / 1  (R carries the scale)
    Rinv = np.linalg.inv(R)
    A = s * Rinv
    off = np.array([W / 2, H / 2]) - s * mc - A @ t
    M = np.hstack([A, off[:, None]]).astype(np.float32)
    warped = cv2.warpAffine(raw, M, (W, H), flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP, borderValue=(94, 92, 92))
    ov = cv2.addWeighted(panel, 0.5, warped, 0.5, 0)
    for (x, y), (qx, qy) in zip(np.array(p["model"]) @ R.T + t, p["sheet"]):
        cv2.circle(ov, (int(round(x)), int(round(y))), 3, (0, 255, 0), -1)
        cv2.circle(ov, (int(round(qx)), int(round(qy))), 3, (0, 0, 255), 1)
    cv2.imwrite(os.path.join(out, "overlay_%s.png" % view), ov)
    print(view, "similarity landmark error %.2f px" % p["err_px"])
