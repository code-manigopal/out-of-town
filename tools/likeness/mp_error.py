"""Mean MediaPipe-landmark distance between the sheet panels and renders of the 3D head.

    tools/.venv/bin/python -I tools/likeness/mp_error.py SHEET_DET.json RENDER_DET.json [OUT.json]

Per view (front, q34L, q34R): similarity (scale, rotation, translation) Procrustes of the render's 468 face
landmarks (irises excluded) onto the sheet's, then the mean / median point distance in SHEET pixels and as a
percentage of the sheet inter-ocular distance. Also reports the face-width / face-height ratio of both sides.
"""
import json
import sys

import numpy as np

IRIS = set(range(468, 478))
IDX = np.array([i for i in range(478) if i not in IRIS])
OVAL = [10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
        172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109]


def procrustes(P, Q):
    pm, qm = P.mean(0), Q.mean(0)
    p, q = P - pm, Q - qm
    a = (p * q).sum()
    b = (p[:, 0] * q[:, 1] - p[:, 1] * q[:, 0]).sum()
    den = (p ** 2).sum()
    c, s = a / den, b / den
    R = np.array([[c, -s], [s, c]])
    return R, qm - R @ pm


def compare(sheet, render):
    out = {}
    for v in ("front", "q34L", "q34R"):
        if not (sheet.get(v, {}).get("ok") and render.get(v, {}).get("ok")):
            continue
        Q = np.array(sheet[v]["pts"])[IDX]
        P = np.array(render[v]["pts"])[IDX]
        R, t = procrustes(P, Q)
        e = np.linalg.norm(P @ R.T + t - Q, axis=1)
        iod = np.linalg.norm(np.array(sheet[v]["pts"])[33] - np.array(sheet[v]["pts"])[263])
        # face proportions: width (cheek to cheek, 234..454) / height (forehead 10 .. chin 152), on both sides
        def prop(d):
            p = np.array(d[v]["pts"])
            return float(np.linalg.norm(p[234] - p[454]) / np.linalg.norm(p[10] - p[152]))
        out[v] = {"mean_px": float(e.mean()), "median_px": float(np.median(e)), "pct_iod": float(100 * e.mean() / iod),
                  "n": int(len(IDX)), "aspect_sheet": prop(sheet), "aspect_render": prop(render),
                  "yaw_sheet": sheet[v]["yaw"], "yaw_render": render[v]["yaw"]}
    return out


if __name__ == "__main__":
    s, r = json.load(open(sys.argv[1])), json.load(open(sys.argv[2]))
    res = compare(s, r)
    for k, v in res.items():
        print("%-5s mean %.2f px (%.1f%% IOD) median %.2f  n=%d  w/h sheet %.3f render %.3f  yaw %.1f/%.1f" % (
            k, v["mean_px"], v["pct_iod"], v["median_px"], v["n"], v["aspect_sheet"], v["aspect_render"], v["yaw_sheet"], v["yaw_render"]))
    if len(sys.argv) > 3:
        json.dump(res, open(sys.argv[3], "w"), indent=1)
