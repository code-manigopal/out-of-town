"""Camera projection of the face-sheet panels onto the fitted head (Blender python, numpy only).

Per view: similarity transform (Procrustes over the mapped landmark vertices) plus a thin-plate-spline
residual warp so each landmark lands exactly on its sheet position; front view for faces looking at
-Y, profile view (subject's left side, mirrored for the right) for the sides. Blended by view angle,
faded where the panel shows its grey background.
"""
import json
import os

import numpy as np

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LDIR = os.path.join(REPO, "art_source/characters/mani/likeness")
JSON = os.path.join(LDIR, "sheet_landmarks.json")


def _to_view(view, P):
    return np.stack([P[:, 0], -P[:, 2]], 1) if view == "front" else np.stack([P[:, 1], -P[:, 2]], 1)


def procrustes(P, Q):
    pm, qm = P.mean(0), Q.mean(0)
    p, q = P - pm, Q - qm
    a = (p * q).sum()
    b = (p[:, 0] * q[:, 1] - p[:, 1] * q[:, 0]).sum()
    den = (p ** 2).sum()
    c, s = a / den, b / den
    R = np.array([[c, -s], [s, c]])
    return R, qm - R @ pm


class TPS:
    def __init__(self, src, dst, lam=2.0):
        n = len(src)
        d = np.linalg.norm(src[:, None] - src[None], axis=2)
        K = np.where(d > 0, d ** 2 * np.log(np.maximum(d, 1e-9)), 0.0) + lam * np.eye(n)
        P = np.hstack([np.ones((n, 1)), src])
        A = np.zeros((n + 3, n + 3))
        A[:n, :n], A[:n, n:], A[n:, :n] = K, P, P.T
        rhs = np.zeros((n + 3, 2))
        rhs[:n] = dst
        sol = np.linalg.solve(A, rhs)
        self.src, self.w, self.a = src, sol[:n], sol[n:]

    def __call__(self, X):
        d = np.linalg.norm(X[:, None] - self.src[None], axis=2)
        U = np.where(d > 0, d ** 2 * np.log(np.maximum(d, 1e-9)), 0.0)
        return U @ self.w + self.a[0] + X @ self.a[1:]


def bilinear(img, xy):
    h, w = img.shape[:2]
    x = np.clip(xy[:, 0], 0, w - 1.001)
    y = np.clip(xy[:, 1], 0, h - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
            + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class FaceProjector:
    def __init__(self, co, load_img):
        """co: [n,3] head-space vertex coordinates of the final (fitted) basemesh;
        load_img(path) -> float [h,w,3] sRGB-coded array (rows top to bottom)."""
        sj = json.load(open(JSON))
        self.img, self.bg, self.warp, self.tf = {}, {}, {}, {}
        for v in ("front", "profile"):
            names = [k for k in sj["mapping"][v] if k in sj["points"][v]]
            P = _to_view(v, co[[sj["mapping"][v][k] for k in names]])
            Q = np.array([sj["points"][v][k] for k in names], float)
            R, t = procrustes(P, Q)
            A = P @ R.T + t
            c = A.mean(0)
            ring = np.array([[c[0] + 190 * np.cos(a), c[1] + 230 * np.sin(a)] for a in np.linspace(0, 6.283, 13)[:-1]])
            self.warp[v] = TPS(np.vstack([A, ring]), np.vstack([Q, ring]), lam=3.0)
            self.tf[v] = (R, t)
            img = load_img(os.path.join(LDIR, "clean_%s.png" % v))[..., :3]
            self.img[v] = img
            grey = np.abs(img - img[2:6, 2:6].reshape(-1, 3).mean(0)).max(-1)
            mask = (grey < 0.045).astype(np.float32)
            k = np.ones(5) / 5
            for ax in (0, 1):
                mask = np.apply_along_axis(lambda r: np.convolve(r, k, "same"), ax, mask)
            self.bg[v] = np.clip(mask * 2.2, 0, 1)

    def map_xy(self, v, P):
        R, t = self.tf[v]
        A = _to_view(v, P) @ R.T + t
        return self.warp[v](A)

    def project(self, P, N):
        """P, N: [m,3] positions / unit normals. Returns (rgb [m,3], alpha [m])."""
        Pm = P.copy()
        Nm = N.copy()
        r = P[:, 0] < 0
        Pm[r, 0] *= -1
        Nm[r, 0] *= -1
        out = np.zeros((len(P), 3), np.float32)
        wsum = np.zeros(len(P), np.float32)
        wf = smooth(0.30, 0.85, -N[:, 1])
        ws = smooth(0.40, 0.92, Nm[:, 0]) * (1 - 0.6 * wf)
        for v, w, PP in (("front", wf, P), ("profile", ws, Pm)):
            sel = w > 1e-3
            if not sel.any():
                continue
            xy = self.map_xy(v, PP[sel])
            col = bilinear(self.img[v], xy)
            vis = 1 - bilinear(self.bg[v][..., None], xy)[:, 0]
            ww = w[sel] * vis
            out[sel] += col * ww[:, None]
            wsum[sel] += ww
        alpha = np.clip(wsum, 0, 1)
        rgb = out / np.maximum(wsum, 1e-4)[:, None]
        return rgb, alpha


# ---------------------------------------------------------------------------------------------------
# MediaPipe-landmark based projection (front + both three-quarter panels, hand-annotated profile for the sides)
# ---------------------------------------------------------------------------------------------------
PANEL_BOX = {"front": (0, 0), "q34L": (411, 0), "q34R": (1253, 0)}


def _cam_project(cam, P):
    M = np.array(cam["mat"])
    Xc = (P - M[:3, 3]) @ M[:3, :3]
    z = -Xc[:, 2]
    W, H = cam["res"]
    f = cam["lens"] / cam["sensor"] * W
    return np.stack([W / 2 + f * Xc[:, 0] / z, H / 2 - f * Xc[:, 1] / z], 1)


class FaceProjectorMP:
    """~150 MediaPipe landmarks per panel (bound to the basemesh by tools/likeness/fit_face_mp.py) drive a
    thin-plate warp per view; views are blended by view angle and masked by ray-cast visibility."""

    def __init__(self, co, load_img, visible):
        """visible(origin[3], target[3]) -> bool (True when the target is not occluded from origin)."""
        sj = json.load(open(JSON))
        self.old = FaceProjector(co, load_img)           # hand-annotated profile (and background masks)
        self.visible = visible
        self.view = {}
        for v, box in PANEL_BOX.items():
            m = sj["mp"][v]
            tri, bw = np.array(m["tri"]), np.array(m["bary"])
            Qp = np.array(m["Q"], float) - np.array(box)
            P3 = (co[tri] * bw[:, :, None]).sum(1)
            A = _cam_project(m["cam"], P3)
            R, t = procrustes(A, Qp)
            sel = np.arange(0, len(A), 2)
            c = A.mean(0)
            ring = np.array([[c[0] + 330 * np.cos(a), c[1] + 400 * np.sin(a)] for a in np.linspace(0, 6.283, 13)[:-1]])
            tps = TPS(np.vstack([A[sel], ring]), np.vstack([Qp[sel], ring @ R.T + t]), lam=3.0)
            img = load_img(os.path.join(LDIR, "clean_%s.png" % v))[..., :3]
            grey = np.abs(img - img[2:6, 2:6].reshape(-1, 3).mean(0)).max(-1)
            mask = (grey < 0.045).astype(np.float32)
            k = np.ones(5) / 5
            for ax in (0, 1):
                mask = np.apply_along_axis(lambda r: np.convolve(r, k, "same"), ax, mask)
            a = np.radians(m["cam"]["angle"])
            self.view[v] = dict(cam=m["cam"], tps=tps, img=img, bg=np.clip(mask * 2.2, 0, 1),
                                loc=np.array(m["cam"]["loc"]), dirv=np.array([np.sin(a), -np.cos(a), 0.0]))

    def project(self, P, N):
        out = np.zeros((len(P), 3), np.float32)
        wsum = np.zeros(len(P), np.float32)
        wmax = np.zeros(len(P), np.float32)
        for v, d in self.view.items():
            w = smooth(0.30, 0.80, N @ d["dirv"]) * (1.0 if v == "front" else 0.85)
            idx = np.nonzero(w > 1e-3)[0]
            if len(idx) == 0:
                continue
            ok = np.array([self.visible(d["loc"], P[i]) for i in idx])
            if os.environ.get("OOT_DEBUG"):
                print("[vis]", v, "candidates", len(ok), "visible", int(ok.sum()))
            idx = idx[ok]
            w = w[idx]
            xy = np.empty((len(idx), 2))
            A = _cam_project(d["cam"], P[idx])
            for s in range(0, len(idx), 60000):
                xy[s:s + 60000] = d["tps"](A[s:s + 60000])
            col = bilinear(d["img"], xy)
            vis = 1 - bilinear(d["bg"][..., None], xy)[:, 0]
            if os.environ.get("OOT_DEBUG"):
                H_, W_ = d["img"].shape[:2]
                bad = (xy[:, 0] < 0) | (xy[:, 0] > W_) | (xy[:, 1] < 0) | (xy[:, 1] > H_)
                print("[proj]", v, len(idx), "out-of-image", int(bad.sum()), "bg-masked", int((vis < 0.5).sum()), "xy range", xy.min(0), xy.max(0))
            ww = w * vis
            out[idx] += col * ww[:, None]
            wsum[idx] += ww
            wmax[idx] = np.maximum(wmax[idx], w)
        # hand-annotated profile for the sides / behind the ears (mirrored for the right side)
        Pm, Nm = P.copy(), N.copy()
        r = P[:, 0] < 0
        Pm[r, 0] *= -1
        Nm[r, 0] *= -1
        ws = smooth(0.40, 0.92, Nm[:, 0]) * (1 - 0.85 * np.clip(wmax * 1.4, 0, 1))
        idx = np.nonzero(ws > 1e-3)[0]
        if len(idx):
            xy = self.old.map_xy("profile", Pm[idx])
            col = bilinear(self.old.img["profile"], xy)
            vis = 1 - bilinear(self.old.bg["profile"][..., None], xy)[:, 0]
            ww = ws[idx] * vis
            out[idx] += col * ww[:, None]
            wsum[idx] += ww
        return out / np.maximum(wsum, 1e-4)[:, None], np.clip(wsum, 0, 1)
