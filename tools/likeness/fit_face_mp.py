"""Fit the MPFB face modifiers to the sheet using MediaPipe's 478 landmarks (Blender, headless):

    blender -b -P tools/likeness/fit_face_mp.py -- SHEET_DET.json RENDER_DET.json CAMS.json [--bind-only] [--mu=0.4]

Workflow (see tools/likeness/run_fit.sh): render the current head from the sheet's view angles
(render_fit_views.py), run MediaPipe on the renders and on the sheet (mp_detect.py), then this script:
  1. builds the current MPFB head (art_source/.../sheet_landmarks.json "fit"), and for every MediaPipe landmark of
     every detected view casts the camera ray through the landmark detected on the *render* onto the basemesh. The
     hit (triangle + barycentric) is that landmark on the model, so both sides use MediaPipe's own definition;
  2. measures the linear effect of every face modifier on those points;
  3. per view similarity-Procrustes (perspective-projected with the render camera) + projected coordinate descent
     to minimise the distance to the *sheet's* landmarks, plus the hand-annotated profile points (the profile
     panel is beyond what MediaPipe sees);
  4. writes the new modifier values ("fit") and the landmark bindings ("mp", used for the texture projection and by
     overlays) back into sheet_landmarks.json.
--bind-only: only refresh "mp" for the current values (after the final build).
"""
import importlib.util
import json
import os
import sys

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools/likeness"))
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
sys.argv = [sys.argv[0], "--", "--no-export"]
spec = importlib.util.spec_from_file_location("B", os.path.join(REPO, "tools/blender/build_mani.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)
import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402
from mathutils.bvhtree import BVHTree  # noqa: E402
from bl_ext.user_default.mpfb.services import TargetService  # noqa: E402
import face_vars  # noqa: E402

JSON = os.path.join(REPO, "art_source/characters/mani/likeness/sheet_landmarks.json")
SHEET_DET, REND_DET, CAMS = [json.load(open(p)) for p in ARGV[:3]]
BIND_ONLY = "--bind-only" in ARGV
MU = float(next((a.split("=")[1] for a in ARGV if a.startswith("--mu=")), "0.4"))
PROFILE_W = float(next((a.split("=")[1] for a in ARGV if a.startswith("--profile-w=")), "6.0"))
IRIS = set(range(468, 478))
OVAL = {10, 338, 297, 332, 284, 251, 389, 356, 454, 323, 361, 288, 397, 365, 379, 378, 400, 377, 152, 148, 176, 149, 150, 136,
        172, 58, 132, 93, 234, 127, 162, 21, 54, 103, 67, 109}
CHIN = {152, 148, 176, 149, 150, 136, 172, 58, 132, 377, 400, 378, 379, 365, 397, 288, 361, 175, 171, 396}
VIEWS = ("front", "q34L", "q34R")


def log(*a):
    print("[fitmp]", *a, flush=True)


# ---------------------------------------------------------------------------------------------------
# camera helpers
# ---------------------------------------------------------------------------------------------------
def cam_rays(cam, px):
    M = np.array(cam["mat"])
    W, H = cam["res"]
    sx = (px[:, 0] / W - 0.5) * cam["sensor"] / cam["lens"]
    sy = -(px[:, 1] / H - 0.5) * (cam["sensor"] * H / W) / cam["lens"]
    d = np.stack([sx, sy, -np.ones(len(px))], 1) @ M[:3, :3].T
    return M[:3, 3], d / np.linalg.norm(d, axis=1, keepdims=True)


def cam_project(cam, P):
    M = np.array(cam["mat"])
    Xc = (P - M[:3, 3]) @ M[:3, :3]          # R^T (P - C)
    z = -Xc[:, 2]
    W, H = cam["res"]
    f = cam["lens"] / cam["sensor"] * W
    return np.stack([W / 2 + f * Xc[:, 0] / z, H / 2 - f * Xc[:, 1] / z], 1)


def procrustes(P, Q, w):
    w = w / w.sum()
    pm, qm = (w[:, None] * P).sum(0), (w[:, None] * Q).sum(0)
    p, q = P - pm, Q - qm
    a = (w * (p[:, 0] * q[:, 0] + p[:, 1] * q[:, 1])).sum()
    b = (w * (p[:, 0] * q[:, 1] - p[:, 1] * q[:, 0])).sum()
    den = (w * (p ** 2).sum(1)).sum()
    c, s_ = a / den, b / den
    R = np.array([[c, -s_], [s_, c]])
    return R, qm - R @ pm


# ---------------------------------------------------------------------------------------------------
# build + bind
# ---------------------------------------------------------------------------------------------------
def tri_list(me):
    tris = []
    for p in me.polygons:
        vs = list(p.vertices)
        for k in range(1, len(vs) - 1):
            tris.append((vs[0], vs[k], vs[k + 1]))
    return np.array(tris)


def bary(P, A, Bv, C):
    v0, v1, v2 = Bv - A, C - A, P - A
    d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
    d20, d21 = v2 @ v0, v2 @ v1
    den = d00 * d11 - d01 * d01
    v = (d11 * d20 - d01 * d21) / den
    w = (d00 * d21 - d01 * d20) / den
    return np.array([1 - v - w, v, w])


def bind_views(co, tris):
    """Cast the render-detected landmarks onto the basemesh -> per view dict."""
    bvh = BVHTree.FromPolygons([tuple(v) for v in co], [tuple(t) for t in tris])
    out = {}
    for v in VIEWS:
        if not (SHEET_DET.get(v, {}).get("ok") and REND_DET.get(v, {}).get("ok")):
            continue
        cam = CAMS[v]
        rp = np.array(REND_DET[v]["pts"])
        sp = np.array(SHEET_DET[v]["pts"])
        orig, dirs = cam_rays(cam, rp)
        ids, tv, bw, Q, wt = [], [], [], [], []
        for i in range(478):
            if i in IRIS:
                continue
            hit = bvh.ray_cast(Vector(orig), Vector(dirs[i]))
            if hit[0] is None:
                continue
            loc, nrm = np.array(hit[0]), np.array(hit[1])
            if -nrm @ dirs[i] < 0.28:
                continue
            t = tris[hit[2]]
            ids.append(i)
            tv.append(t)
            bw.append(bary(loc, co[t[0]], co[t[1]], co[t[2]]))
            Q.append(sp[i])
            wt.append(2.2 if i in CHIN else (0.45 if i in OVAL else 1.0))
        out[v] = {"idx": ids, "tri": np.array(tv), "bary": np.array(bw), "Q": np.array(Q), "w": np.array(wt)}
        log("bound %s: %d of 468 landmarks" % (v, len(ids)))
    return out


def load_deltas(hm, stems):
    base = B.eval_coords(hm)
    for s in stems:
        TargetService.load_target(hm, TargetService.target_full_path(s), weight=0.0, name=s)
    kb = hm.data.shape_keys.key_blocks
    out = {}
    for s in stems:
        kb[s].value = 1.0
        bpy.context.view_layer.update()
        out[s] = B.eval_coords(hm) - base
        kb[s].value = 0.0
    bpy.context.view_layer.update()
    return base, out


def main():
    sj = json.load(open(JSON))
    cur = dict(sj["fit"]["values"])
    # ---- 1. current head + bindings ------------------------------------------------------
    B.clear_scene()
    hm = B.build_human()
    co_cur = B.eval_coords(hm)
    tris = tri_list(hm.data)
    binds = bind_views(co_cur, tris)
    if BIND_ONLY:
        write_bind(sj, binds)
        return
    prof = {k: v for k, v in sj["mapping"]["profile"].items() if k in sj["points"]["profile"]}
    pnames = list(prof)
    pQ = np.array([sj["points"]["profile"][k] for k in pnames], float)
    pV = np.array([prof[k] for k in pnames])
    # ---- 2. linear basis from the macro-only head ---------------------------------------------
    B.face_target_list = lambda: []
    B.clear_scene()
    hm = B.build_human()
    vars_ = face_vars.FACE_VARS
    stems = sorted({s for _, p, n, *_ in vars_ for s in p + n})
    for s in stems:
        assert TargetService.target_full_path(s), s
    base, D = load_deltas(hm, stems)
    nv = len(vars_)
    # per view: delta tensors at the bound points  [nv, 2(sign), k, 3]
    VW = {}
    for v, b in binds.items():
        w = b["bary"][:, :, None]
        def at(stem_sum, b=b, w=w):
            return (stem_sum[b["tri"]] * w).sum(1)
        VW[v] = dict(b)
        VW[v]["cam"] = CAMS[v]
        VW[v]["P0"] = (co_cur[b["tri"]] * w).sum(1)
        VW[v]["col"] = [(at(sum(D[s] for s in p)) if p else 0.0, at(sum(D[s] for s in n)) if n else 0.0) for _, p, n, *_ in vars_]
    # profile (orthographic side view u = +Y, v = -Z; vertex landmarks)
    PW = dict(V=pV, Q=pQ, w=np.full(len(pV), PROFILE_W), P0=co_cur[pV],
              col=[(sum(D[s] for s in p)[pV] if p else 0.0, sum(D[s] for s in n)[pV] if n else 0.0) for _, p, n, *_ in vars_])

    def dlt(col, j, val):
        return col[j][0] * val if val >= 0 else col[j][1] * (-val)

    def proj(v, P):
        return np.stack([P[:, 1], -P[:, 2]], 1) if v == "profile" else cam_project(VW[v]["cam"], P)

    def view_state(vals_):
        """per view positions for the given modifier values (relative to the current built head)."""
        out = {}
        for v in list(VW) + ["profile"]:
            src = PW if v == "profile" else VW[v]
            P = src["P0"].copy()
            for j in range(nv):
                P += dlt(src["col"], j, vals_[j]) - dlt(src["col"], j, curv[j])
            out[v] = P
        return out

    def errors(P):
        res = {}
        for v in P:
            src = PW if v == "profile" else VW[v]
            A = proj(v, P[v])
            R, t = procrustes(A, src["Q"], src["w"])
            e = np.linalg.norm(A @ R.T + t - src["Q"], axis=1)
            res[v] = (e, R, t)
        return res

    names = [x[0] for x in vars_]
    curv = np.array([float(cur.get(n, 0.0)) for n in names])
    val = curv.copy()
    P_cur = view_state(val)
    e0 = errors(P_cur)
    log("current head, landmark error px (model-bound): " + ", ".join(
        "%s %.2f (n=%d)" % (v, e0[v][0].mean(), len(e0[v][0])) for v in e0))
    wtot = sum((PW if v == "profile" else VW[v])["w"].sum() for v in P_cur)
    for sweep in range(60):
        tr = errors(P_cur)
        cf = {v: (tr[v][1], tr[v][2]) for v in tr}
        moved = 0.0

        def cost(P):
            c = 0.0
            for v in P:
                src = PW if v == "profile" else VW[v]
                A = proj(v, P[v]) @ cf[v][0].T + cf[v][1]
                c += (src["w"] * ((A - src["Q"]) ** 2).sum(1)).sum()
            return c / wtot

        for j in np.random.RandomState(sweep).permutation(nv):
            lo, hi = vars_[j][3], vars_[j][4]
            base_P = {}
            for v in P_cur:
                src = PW if v == "profile" else VW[v]
                base_P[v] = P_cur[v] - dlt(src["col"], j, val[j])

            def at_val(x):
                return {v: base_P[v] + dlt((PW if v == "profile" else VW[v])["col"], j, x) for v in base_P}
            best, bv = None, val[j]
            for x in np.linspace(lo, hi, 21).tolist() + [val[j]]:
                c = cost(at_val(x)) + MU * x * x
                if best is None or c < best:
                    best, bv = c, x
            for x in np.linspace(bv - 0.06, bv + 0.06, 13):
                if lo <= x <= hi:
                    c = cost(at_val(x)) + MU * x * x
                    if c < best:
                        best, bv = c, x
            moved += abs(bv - val[j])
            val[j] = bv
            P_cur = at_val(bv)
        if moved < 0.01:
            break
    fin = errors(P_cur)
    log("sweeps %d  mu %.2f" % (sweep + 1, MU))
    log("FITTED model-bound mean error px: " + ", ".join("%s %.2f" % (v, fin[v][0].mean()) for v in fin))
    log("changed:", {names[j]: (round(float(curv[j]), 3), round(float(val[j]), 3)) for j in range(nv) if abs(val[j] - curv[j]) > 0.02})
    sj["fit"]["values"] = {names[j]: round(float(val[j]), 4) for j in range(nv)}
    sj["fit"]["method"] = "mediapipe-478 (front,q34L,q34R) + 14 hand profile points"
    sj["fit"].setdefault("history", []).append({v: round(float(fin[v][0].mean()), 3) for v in fin})
    write_bind(sj, binds)


def write_bind(sj, binds):
    sj["mp"] = {v: {"cam": CAMS[v], "idx": [int(i) for i in b["idx"]], "tri": b["tri"].tolist(),
                    "bary": [[round(float(x), 5) for x in r] for r in b["bary"]],
                    "Q": [[round(float(x), 2) for x in r] for r in b["Q"]]} for v, b in binds.items()}
    json.dump(sj, open(JSON, "w"), indent=1)
    log("wrote", JSON, {v: len(b["idx"]) for v, b in binds.items()})


main()
