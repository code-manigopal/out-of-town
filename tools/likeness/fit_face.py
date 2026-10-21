"""Fit the MPFB face modifiers to the sheet landmarks (front + profile) in Blender, headless:

    blender -b -P tools/likeness/fit_face.py

1. builds the macro-only MPFB human, maps every named sheet landmark to a fixed basemesh vertex
   (rules below, stored under "mapping" in art_source/characters/mani/likeness/sheet_landmarks.json);
2. measures the linear effect of every candidate target on those vertices;
3. per-view similarity (scale, rotation, translation) Procrustes + projected coordinate descent
   (scipy-free) over tools/likeness/face_vars.py to minimise the 2D landmark error in both
   orthographic views (front: u=+X, v=-Z; profile: u=+Y, v=-Z);
4. prints the per-view mean landmark error (px) for the previous hand-tuned face and the fit, and
   stores the modifier values under "fit" in the same json (build_mani.py applies them).
"""
import importlib.util
import json
import os
import sys

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools/likeness"))
sys.argv = [sys.argv[0], "--", "--no-export"]
spec = importlib.util.spec_from_file_location("B", os.path.join(REPO, "tools/blender/build_mani.py"))
B = importlib.util.module_from_spec(spec)
spec.loader.exec_module(B)
import bpy  # noqa: E402
from bl_ext.user_default.mpfb.services import TargetService  # noqa: E402
import face_vars  # noqa: E402

JSON = os.path.join(REPO, "art_source/characters/mani/likeness/sheet_landmarks.json")
OLD_FACE = list(B.FACE_TARGETS)          # the earlier hand-tuned face (for the "before" number)
LAMBDA = float(os.environ.get("FIT_LAMBDA", "2.5"))


def build_base():
    B.face_target_list = lambda: []
    B.clear_scene()
    hm = B.build_human()
    return hm


def group_idx(hm, name):
    vg = hm.vertex_groups[name]
    return np.array([v.index for v in hm.data.vertices if any(g.group == vg.index for g in v.groups)])


def map_landmarks(hm, co, nrm):
    body = group_idx(hm, "body")
    ears = group_idx(hm, "ears")
    lips = group_idx(hm, "lips")
    front = body[(co[body, 1] < -0.09) & (co[body, 2] > 1.45) & (nrm[body, 1] < -0.1)]
    center = body[(np.abs(co[body, 0]) < 1e-4) & (co[body, 1] < -0.09) & (co[body, 2] > 1.45)]
    eye = {s: co[group_idx(hm, "helper-%s-eye" % s)].mean(0) for s in ("l", "r")}

    def nearest_xz(x, z, pool=front):
        d = (co[pool, 0] - x) ** 2 + (co[pool, 2] - z) ** 2
        k = np.argsort(d)[:4]
        return int(pool[k[np.argmin(co[pool[k], 1])]])

    def csel(lo, hi, how):
        c = center[(co[center, 2] >= lo) & (co[center, 2] <= hi)]
        return int(c[np.argmin(co[c, 1]) if how == "front" else np.argmax(co[c, 1])])

    tip = int(center[(co[center, 2] > 1.59) & (co[center, 2] < 1.62)][np.argmin(co[center[(co[center, 2] > 1.59) & (co[center, 2] < 1.62)], 1])])
    tz = co[tip, 2]
    lc = lips[np.abs(co[lips, 0]) < 1e-4]
    lip_up = int(lc[np.argmax(co[lc, 2])])
    lip_low = int(lc[np.argmin(co[lc, 2])])
    ml = int(lips[np.argmax(co[lips, 0])])
    mr = int(lips[np.argmin(co[lips, 0])])
    mz = co[ml, 2]
    stom = int(center[np.argmin(np.abs(co[center, 2] - mz) + (co[center, 1] > -0.15) * 1.0)])
    # chin: lowest forward centre vertex, forward-most chin, labiomental sulcus
    cc = center[(co[center, 1] < -0.13) & (co[center, 2] < lip_low_z(co, lip_low) - 0.006)]
    menton = int(cc[np.argmin(co[cc, 2])])
    pg = center[(co[center, 2] > co[menton, 2]) & (co[center, 2] < co[menton, 2] + 0.016)]
    pogonion = int(pg[np.argmin(co[pg, 1])])
    sc = center[(co[center, 2] > co[pogonion, 2] + 0.004) & (co[center, 2] < co[lip_low, 2] - 0.001)]
    sulcus = int(sc[np.argmax(co[sc, 1])])
    ulf = center[(co[center, 2] > co[stom, 2] + 0.002) & (co[center, 2] <= co[lip_up, 2])]
    llf = center[(co[center, 2] < co[stom, 2] - 0.002) & (co[center, 2] >= co[lip_low, 2])]
    m = {"front": {}, "profile": {}}
    F, P = m["front"], m["profile"]
    cl, cr = eye["l"], eye["r"]
    for side, c, sg in (("l", cl, 1), ("r", cr, -1)):
        F["eye_%s_in" % side] = nearest_xz(c[0] - sg * 0.014, c[2])
        F["eye_%s_out" % side] = nearest_xz(c[0] + sg * 0.016, c[2])
        F["pupil_%s" % side] = nearest_xz(c[0], c[2])
        F["alar_%s" % side] = nearest_xz(sg * 0.0215, 1.598)
    F["nose_tip"] = tip
    F["subnasale"] = csel(tz - 0.0105, tz - 0.0085, "front")
    F["mouth_l"], F["mouth_r"] = ml, mr
    F["stomion"], F["lip_up"], F["lip_low"], F["menton"] = stom, lip_up, lip_low, menton
    for name, dz in (("cheek", 0.0255), ("jaw1", -0.0133), ("jaw2", -0.032)):
        band = body[(np.abs(co[body, 2] - (mz + dz)) < 0.0035) & (co[body, 1] < -0.04)]
        F[name + "_l"] = int(band[np.argmax(co[band, 0])])
        F[name + "_r"] = int(band[np.argmin(co[band, 0])])
    F["ear_l_out"] = int(ears[np.argmax(co[ears, 0])])
    F["ear_r_out"] = int(ears[np.argmin(co[ears, 0])])
    el = ears[co[ears, 0] > 0]
    P.update(dict(nose_tip=tip, subnasale=F["subnasale"], lip_up=int(ulf[np.argmin(co[ulf, 1])]), stomion=stom,
                  lip_low=int(llf[np.argmin(co[llf, 1])]), sulcus=sulcus, pogonion=pogonion, menton=menton,
                  eye_l_out=F["eye_l_out"], nasion=csel(cl[2] + 0.0, cl[2] + 0.006, "front"),
                  ear_top=int(el[np.argmax(co[el, 2])]), ear_back=int(el[np.argmax(co[el, 1])]),
                  ear_lobe=int(el[np.argmin(co[el, 2])])))
    mid = co[el, 2].mean()
    tr = el[np.abs(co[el, 2] - mid) < 0.012]
    P["tragus"] = int(tr[np.argmin(co[tr, 1])])
    return m


def D_sum(j, v, D):
    p, n = face_vars.FACE_VARS[j][1], face_vars.FACE_VARS[j][2]
    return sum(D[s] for s in (p if v >= 0 else n)) * abs(v)


def lip_low_z(co, v):
    return float(co[v, 2])


def eval_co(hm):
    return B.eval_coords(hm)


def load_deltas(hm, stems):
    """stem -> delta array for ALL vertices (target at weight 1)."""
    base = eval_co(hm)
    for s in stems:
        TargetService.load_target(hm, TargetService.target_full_path(s), weight=0.0, name=s)
    kb = hm.data.shape_keys.key_blocks
    out = {}
    for s in stems:
        kb[s].value = 1.0
        bpy.context.view_layer.update()
        out[s] = eval_co(hm) - base
        kb[s].value = 0.0
    bpy.context.view_layer.update()
    return base, out


def procrustes(P, Q, w):
    """Similarity (s, theta, t) minimising sum w |s R P + t - Q|^2. P,Q: [n,2]."""
    w = w / w.sum()
    pm, qm = (w[:, None] * P).sum(0), (w[:, None] * Q).sum(0)
    p, q = P - pm, Q - qm
    a = (w * (p[:, 0] * q[:, 0] + p[:, 1] * q[:, 1])).sum()
    b = (w * (p[:, 0] * q[:, 1] - p[:, 1] * q[:, 0])).sum()
    den = (w * (p ** 2).sum(1)).sum()
    c, s_ = a / den, b / den                       # s*cos, s*sin
    R = np.array([[c, -s_], [s_, c]])
    t = qm - R @ pm
    return R, t


def project(view, XYZ):
    X = XYZ
    return np.stack([X[:, 0], -X[:, 2]], 1) if view == "front" else np.stack([X[:, 1], -X[:, 2]], 1)


def view_error(view, pts3, Q, w):
    P = project(view, pts3)
    R, t = procrustes(P, Q, w)
    A = P @ R.T + t
    e = np.linalg.norm(A - Q, axis=1)
    return e, R, t


def main():
    hm = build_base()
    co0 = eval_co(hm)
    nrm = np.array([v.normal[:] for v in hm.data.vertices])
    mapping = map_landmarks(hm, co0, nrm)
    sheet = json.load(open(JSON))
    pts = sheet["points"]
    names = {v: [k for k in mapping[v] if k in pts[v]] for v in ("front", "profile")}
    W = {"sulcus": 0.4, "nasion": 0.5, "ear_top": 0.7, "ear_back": 0.7, "ear_lobe": 0.7, "tragus": 0.7, "cheek_l": 0.6, "cheek_r": 0.6,
         "ear_l_out": 0.6, "ear_r_out": 0.6, "lip_up": 0.8, "lip_low": 0.8}
    Q, V, WT = {}, {}, {}
    for v in ("front", "profile"):
        Q[v] = np.array([pts[v][k] for k in names[v]], float)
        V[v] = np.array([mapping[v][k] for k in names[v]])
        WT[v] = np.array([W.get(k, 1.0) for k in names[v]])
    allv = sorted(set(np.concatenate([V["front"], V["profile"]]).tolist()))
    stems = sorted({s for _, p, n, *_ in face_vars.FACE_VARS for s in p + n} | {s for s, _ in OLD_FACE})
    for s in stems:
        assert TargetService.target_full_path(s), s
    base, D = load_deltas(hm, stems)
    # delta rows at the landmark vertices only
    Dl = {s: D[s][allv] for s in stems}
    pos = {v: i for i, v in enumerate(allv)}
    L0 = base[allv]

    def landmarks3(values):
        P = L0.copy()
        for stem, wgt in values:
            P += Dl[stem] * wgt
        return P

    def errors(P):
        out = {}
        for v in ("front", "profile"):
            e, R, t = view_error(v, P[[pos[i] for i in V[v]]], Q[v], WT[v])
            out[v] = (e, R, t)
        return out

    old_e = errors(landmarks3([(s, w) for s, w in OLD_FACE]))
    zero_e = errors(landmarks3([]))
    log = lambda *a: print("[fit]", *a, flush=True)
    log("mean landmark error px  macro-only: front %.2f profile %.2f | previous hand-tuned face: front %.2f profile %.2f" % (
        zero_e["front"][0].mean(), zero_e["profile"][0].mean(), old_e["front"][0].mean(), old_e["profile"][0].mean()))

    vars_ = face_vars.FACE_VARS
    nv = len(vars_)
    col = []   # per var: (pos delta, neg delta) at landmark verts
    for name, p, n, lo, hi in vars_:
        col.append((sum(Dl[s] for s in p), sum(Dl[s] for s in n)))
    val = np.zeros(nv)

    def delta_of(j, v):
        return col[j][0] * v if v >= 0 else col[j][1] * (-v)

    P_cur = L0.copy()
    for _sweep in range(40):
        tr = errors(P_cur)
        cf = {v: (tr[v][1], tr[v][2]) for v in tr}
        idx = {v: [pos[i] for i in V[v]] for v in V}

        def cost(P):
            c = 0.0
            for v in ("front", "profile"):
                A = project(v, P[idx[v]]) @ cf[v][0].T + cf[v][1]
                c += (WT[v] * ((A - Q[v]) ** 2).sum(1)).sum()
            return c
        moved = 0.0
        for j in np.random.RandomState(_sweep).permutation(nv):
            Pj = P_cur - delta_of(j, val[j])
            lo, hi = vars_[j][3], vars_[j][4]
            best, bv = None, val[j]
            for v in np.linspace(lo, hi, 41).tolist() + [val[j]]:
                c = cost(Pj + delta_of(j, v)) + LAMBDA * 40.0 * v * v
                if best is None or c < best:
                    best, bv = c, v
            for v in np.linspace(bv - 0.05, bv + 0.05, 11):
                if lo <= v <= hi:
                    c = cost(Pj + delta_of(j, v)) + LAMBDA * 40.0 * v * v
                    if c < best:
                        best, bv = c, v
            moved += abs(bv - val[j])
            val[j] = bv
            P_cur = Pj + delta_of(j, bv)
        if moved < 0.02:
            break
    fin = errors(P_cur)
    log("sweeps %d, lambda %.1f" % (_sweep + 1, LAMBDA))
    log("FINAL mean landmark error px: front %.2f (max %.1f) profile %.2f (max %.1f)" % (
        fin["front"][0].mean(), fin["front"][0].max(), fin["profile"][0].mean(), fin["profile"][0].max()))
    for v in ("front", "profile"):
        log(v, {k: round(float(e), 1) for k, e in zip(names[v], fin[v][0])})
    log("values", {vars_[j][0]: round(float(val[j]), 3) for j in range(nv) if abs(val[j]) > 0.005})
    sheet["mapping"] = {v: {k: int(i) for k, i in mapping[v].items()} for v in mapping}
    sheet["fit"] = {
        "values": {vars_[j][0]: round(float(val[j]), 4) for j in range(nv)},
        "error_px": {
            "front": {"macro_only": round(float(zero_e["front"][0].mean()), 2), "before": round(float(old_e["front"][0].mean()), 2),
                      "after": round(float(fin["front"][0].mean()), 2)},
            "profile": {"macro_only": round(float(zero_e["profile"][0].mean()), 2), "before": round(float(old_e["profile"][0].mean()), 2),
                        "after": round(float(fin["profile"][0].mean()), 2)}},
        "lambda": LAMBDA,
    }
    json.dump(sheet, open(JSON, "w"), indent=1)
    log("wrote", JSON)
    dbg = os.environ.get("FIT_DEBUG")
    if dbg:   # full-head coordinates of the fit + view transforms for plotting overlays (venv: matplotlib/PIL)
        cof = base.copy()
        for j in range(nv):
            cof += (D_sum(j, val[j], D))
        body = group_idx(hm, "body")
        np.savez(dbg, co=cof, body=body, **{"R_" + v: fin[v][1] for v in fin}, **{"t_" + v: fin[v][2] for v in fin},
                 **{"lm_" + v: P_cur[[pos[i] for i in V[v]]] for v in V}, center=np.array([k for k in range(len(cof)) if abs(cof[k, 0]) < 1e-4]))


main()
