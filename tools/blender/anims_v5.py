"""Mani animation pack v5: duffel carry, pick-up / put-down, door push, trunk open / close, car enter / sit / exit,
stairs down.  Adds actions to the existing rig and re-exports game/characters/mani/mani.glb.

    blender -b art_source/characters/mani/mani.blend -P tools/blender/anims_v5.py -- [--no-export] [--only=a,b]

Face, hair and body geometry are untouched: only actions are (re)created.  Same procedural style as build_mani.py
(Animator: IK feet baked to FK), plus IK arms so hands can be put on world points (handle, wheel, lid, bag).

Conventions (armature space, the rig faces -Y, +Z up, character LEFT = +X):
  * Every pose key is authored in a world frame W whose origin is where the character stands at t=0, facing forward.
  * Feet (and knees) are keyed in W; hands, pelvis, spine in the ROOT frame (so they follow the body).
  * Root motion (translation + yaw) is NOT baked into the bones. The Root bone stays at the origin; the travel the game
    must apply to the body is written to art_source/characters/mani/anims_v5.json (per clip: `travel`, `yaw`,
    `window` = [t0, t1] over which the body moves, and a per-frame `root` track for tools).
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector, Matrix

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_mani as B  # noqa: E402

REPO = B.REPO
META_PATH = os.path.join(REPO, "art_source/characters/mani/anims_v5.json")
ARGS = B.ARGS
FPS = 30
log = B.log

UPPER = ["spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r",
         "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]
BODY = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r",
        "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]


def rad(d):
    return math.radians(d)


def HL(f, u, r=0.0):
    """left-hand point: r = lateral distance from the midline (outward positive), f forward, u up"""
    return np.array([r, -f, u], dtype=float)


def HR(f, u, r=0.0):
    return np.array([-r, -f, u], dtype=float)


def W(r, f, u):
    """world point: r to the character's right, f forward, u up"""
    return np.array([-r, -f, u], dtype=float)


# ---------------------------------------------------------------------------------------------
# key-pose interpolation (Hermite, zero tangent in holds)
# ---------------------------------------------------------------------------------------------
REST_PELVIS = np.array([0.0, -0.004, 0.945])
FOOT_L = np.array([0.14, -0.015, 0.069])
FOOT_R = np.array([-0.14, -0.015, 0.069])
BASE = dict(
    T=np.zeros(3), psi=np.zeros(1),
    pel=REST_PELVIS.copy(), pelr=np.zeros(3),          # pelvis pos (root frame), pitch(+fwd) / yaw(+left) / roll
    sp=np.zeros(3), nk=np.zeros(2),                    # spine pitch/yaw/roll, neck pitch / yaw
    hd=np.zeros(2),                                    # head pitch / yaw
    fL=FOOT_L.copy(), fR=FOOT_R.copy(),                # ankle, world
    fLr=np.zeros(3), fRr=np.zeros(3),                  # foot pitch(+toes up) / yaw (world) / roll
    kL=np.zeros(3), kR=np.zeros(3),                    # knee pole offset in W (zero = auto, in front of the knee)
    hL=HL(0.10, 0.93, 0.24), hR=HR(0.10, 0.93, 0.24),  # wrists, root frame
    hLr=np.zeros(3), hRr=np.zeros(3),                  # wrist rotation (rest axes: rx, ry, rz)
    eL=np.array([0.25, 0.40, -0.30]), eR=np.array([-0.25, 0.40, -0.30]),   # elbow pole offset from the wrist
    cL=np.array([1.0]), cR=np.array([1.0]),            # finger curl scale (1 relaxed, 0.3 open, 2.5 grip)
)


class Keys:
    def __init__(self, base=None):
        self.base = {k: np.array(v, dtype=float) for k, v in (base or BASE).items()}
        self.keys = []

    def k(self, t, **kw):
        prev = self.keys[-1][1] if self.keys else self.base
        d = {k: v.copy() for k, v in prev.items()}
        for name, v in kw.items():
            d[name] = np.array(v, dtype=float).reshape(d[name].shape)
        self.keys.append((t, d))
        return self

    def at(self, t):
        ks = self.keys
        if t <= ks[0][0]:
            return {k: v.copy() for k, v in ks[0][1].items()}
        if t >= ks[-1][0]:
            return {k: v.copy() for k, v in ks[-1][1].items()}
        i = max(j for j in range(len(ks) - 1) if ks[j][0] <= t)
        t0, a = ks[i]
        t1, b = ks[i + 1]
        h = t1 - t0
        u = (t - t0) / h
        h00, h10, h01, h11 = 2 * u**3 - 3 * u**2 + 1, u**3 - 2 * u**2 + u, -2 * u**3 + 3 * u**2, u**3 - u**2
        out = {}
        for name in a:
            va, vb = a[name], b[name]
            m0 = self._tan(i, name, h)
            m1 = self._tan(i + 1, name, h)
            out[name] = h00 * va + h10 * h * m0 + h01 * vb + h11 * h * m1
        return out

    def _tan(self, i, name, h):
        ks = self.keys
        v = ks[i][1][name]
        if i == 0 or i == len(ks) - 1:
            return np.zeros_like(v)
        pv, nv = ks[i - 1][1][name], ks[i + 1][1][name]
        m = (nv - pv) / (ks[i + 1][0] - ks[i - 1][0])
        hold = (np.abs(v - pv) < 1e-9) | (np.abs(v - nv) < 1e-9)
        return np.where(hold, 0.0, m)


def swing(v):
    return v * v * (3 - 2 * v)


# ---------------------------------------------------------------------------------------------
# animator with IK arms
# ---------------------------------------------------------------------------------------------
class A5(B.Animator):
    curl_l = 1.0
    curl_r = 1.0

    def add_arm_ik(self):
        rig = self.rig
        bpy.ops.object.mode_set(mode="EDIT")
        eb = rig.data.edit_bones
        for s in ("l", "r"):
            h = eb["hand_" + s]
            t = eb.new("ik_hand_" + s)
            t.head, t.tail, t.roll = h.head.copy(), h.tail.copy(), h.roll
            t.parent = eb["Root"]
            sg = 1 if s == "l" else -1
            p = eb.new("ik_hpole_" + s)
            p.head = h.head + Vector((sg * 0.25, 0.40, -0.30))
            p.tail = p.head + Vector((0, 0, 0.05))
            p.parent = eb["Root"]
        bpy.ops.object.mode_set(mode="POSE")
        for n in ("ik_hand_l", "ik_hand_r", "ik_hpole_l", "ik_hpole_r"):
            self.ik_names.append(n)
            self.Br[n] = rig.data.bones[n].matrix_local.to_3x3()
        self.arm_cons = {}
        for s in ("l", "r"):
            pb = rig.pose.bones["lowerarm_" + s]
            c = pb.constraints.new("IK")
            c.target, c.subtarget = rig, "ik_hand_" + s
            c.pole_target, c.pole_subtarget = rig, "ik_hpole_" + s
            c.chain_count = 2
            self.arm_cons[s] = c
        self.calibrate_arm_pole()

    def calibrate_arm_pole(self):
        rig = self.rig
        self.reset()
        for s, sg in (("l", 1), ("r", -1)):
            c = self.arm_cons[s]
            best = None
            tgt = Vector((sg * 0.16, -0.40, 1.10))
            self.set_loc("ik_hand_" + s, tgt - self.rest_head["hand_" + s])
            self.set_loc("ik_hpole_" + s, (tgt + Vector((sg * 0.25, 0.40, -0.30))) - (self.rest_head["hand_" + s] + Vector((sg * 0.25, 0.40, -0.30))))
            want = Vector((sg * 0.30, 0.0, 0.95))
            for deg in np.arange(-180, 180, 3.0):
                c.pole_angle = math.radians(deg)
                bpy.context.view_layer.update()
                elbow = rig.matrix_world @ rig.pose.bones["lowerarm_" + s].head
                cost = (elbow - want).length
                if best is None or cost < best[0]:
                    best = (cost, deg)
            c.pole_angle = math.radians(best[1])
            log("arm pole angle", s, best)
        self.reset()

    def set_arm_ik(self, on):
        for c in self.arm_cons.values():
            c.influence = 1.0 if on else 0.0

    def relax_hands(self):
        for s, sg, sc in (("l", 1, self.curl_l), ("r", -1, self.curl_r)):
            for fi, base in (("index", 14), ("middle", 18), ("ring", 22), ("pinky", 26)):
                for k, mult in ((1, 1.0), (2, 1.3), (3, 0.9)):
                    n = "%s_0%d_%s" % (fi, k, s)
                    if n in self.rig.pose.bones:
                        self.rot(n, self.R("Y", sg * self.curl_sign * base * mult * sc))
            for k, a in ((1, 8), (2, 12), (3, 10)):
                n = "thumb_0%d_%s" % (k, s)
                if n in self.rig.pose.bones:
                    self.rot(n, self.R("Y", sg * self.curl_sign * a * min(sc, 1.8)))

    # --- apply one world pose ---------------------------------------------------------------
    def apply(self, S, arm_ik=True):
        R = self.R
        T = Vector(S["T"])
        psi = float(S["psi"][0])
        Rz = Matrix.Rotation(rad(psi), 3, "Z")
        Rzi = Rz.inverted()

        def w2r(p):
            return Rzi @ (Vector(p) - T)

        pel = Vector(S["pel"])
        self.set_loc("pelvis", pel - Vector(REST_PELVIS))
        pp, py, pr = S["pelr"]
        self.rot("pelvis", R("Z", py) @ R("X", pp) @ R("Y", pr))
        sp, sy, sr = S["sp"]
        for n, w in (("spine_01", 0.25), ("spine_02", 0.35), ("spine_03", 0.40)):
            self.rot(n, R("Z", sy * w) @ R("X", sp * w) @ R("Y", sr * w))
        self.rot("neck_01", R("Z", S["nk"][1]) @ R("X", S["nk"][0]))
        self.rot("head", R("Z", S["hd"][1]) @ R("X", S["hd"][0]))
        # legs
        hips = {}
        for s, sg, key in (("l", 1, "L"), ("r", -1, "R")):
            ank = Vector(S["f" + key])
            loc = w2r(ank)
            self.set_loc("ik_foot_" + s, loc - self.rest_head["foot_" + s])
            fp, fy, fr = S["f" + key + "r"]
            self.rot("ik_foot_" + s, R("Z", fy - psi) @ R("X", -fp) @ R("Y", fr))
            # knee pole: in front of the knee (facing direction = root yaw + pelvis yaw)
            face = Rz @ Matrix.Rotation(rad(py), 3, "Z") @ Vector((0, -1, 0))
            hip_w = T + Rz @ (pel + Vector((sg * 0.111, 0.01, -0.007)) - Vector(REST_PELVIS) * 0 - Vector((0, 0, 0)))
            knee_est = (hip_w + ank) * 0.5
            pole_w = knee_est + face * 0.55 + Vector(S["k" + key])
            pole_loc = w2r(pole_w)
            rest_pole = self.rest_head["calf_" + s] + Vector((0, -0.55, 0))
            self.set_loc("ik_pole_" + s, pole_loc - rest_pole)
        # arms (IK) or leave to the caller (FK)
        for s, sg, key in (("l", 1, "L"), ("r", -1, "R")):
            wr = Vector(S["h" + key])
            self.set_loc("ik_hand_" + s, wr - self.rest_head["hand_" + s])
            e = Vector(S["e" + key])
            self.set_loc("ik_hpole_" + s, (wr + e) - (self.rest_head["hand_" + s] + Vector((sg * 0.25, 0.40, -0.30))))
            rx, ry, rz = S["h" + key + "r"]
            self.rot("hand_" + s, R("Z", rz) @ R("X", rx) @ R("Y", ry))
        self.curl_l = float(S["cL"][0])
        self.curl_r = float(S["cR"][0])
        self.set_arm_ik(arm_ik)

    # --- clip creation with sampling/validation -----------------------------------------------------
    def make(self, name, length, fn, loop, upper=False, arm_ik=True):
        """fn(t) -> world pose dict. Returns meta."""
        frames = int(round(length * FPS))
        driven = (UPPER if upper else BODY) + self.ik_names
        rig = self.rig
        root = []
        hand_err = 0.0
        foot_err = 0.0
        floor_min = 9.0

        def pose_fn(p):
            nonlocal hand_err, foot_err, floor_min
            S = fn(p * length)
            self.apply(S, arm_ik)
            root.append([float(S["T"][0]), float(S["T"][1]), float(S["T"][2]), float(S["psi"][0])])
            bpy.context.view_layer.update()
            for s, key in (("l", "L"), ("r", "R")):
                if arm_ik:
                    got = rig.matrix_world @ rig.pose.bones["lowerarm_" + s].tail
                    hand_err = max(hand_err, (got - Vector(S["h" + key])).length)
                got = rig.matrix_world @ rig.pose.bones["calf_" + s].tail
                Rz = Matrix.Rotation(rad(float(S["psi"][0])), 3, "Z")
                want = Rz.inverted() @ (Vector(S["f" + key]) - Vector(S["T"]))
                foot_err = max(foot_err, (got - want).length)
                floor_min = min(floor_min, rig.matrix_world.translation.z + (rig.pose.bones["foot_" + s].head).z)

        if name in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[name])
        act = self.clip(name, frames, pose_fn, bones=driven, keep_const=upper)
        meta = dict(length=frames / FPS, frames=frames, loop=loop, root=root)
        log("clip %s: %d frames, max wrist error %.3f m, max ankle error %.3f m, lowest ankle z %.3f" % (
            name, frames, hand_err, foot_err, floor_min))
        meta["wrist_err"] = round(hand_err, 4)
        meta["ankle_err"] = round(foot_err, 4)
        return meta


# ---------------------------------------------------------------------------------------------
# the clips (world frame W, see module docstring)
# ---------------------------------------------------------------------------------------------
GRIP, OPEN = 2.5, 0.35


def stand_feet(k, **kw):
    return dict(fL=FOOT_L, fR=FOOT_R, **kw)


def lerp_pose(a, b, u):
    return {k: a[k] * (1 - u) + b[k] * u for k in a}


def clip_carry_duffel(A):
    """Both hands on the two top handles of a 0.75 m duffel held in front of the belly (handles 0.26 m apart)."""
    def fn(t):
        w = 2 * math.pi * t / 4.0
        br = math.sin(w)
        S = {k: v.copy() for k, v in BASE.items()}
        S["sp"] = np.array([-2.5 + 0.4 * br, 0, 0])          # lean back a little against the weight
        S["nk"] = np.array([2.0 - 0.4 * br, 0])
        S["hd"] = np.array([0.5, 0])
        S["hL"] = HL(0.27, 1.04 + 0.003 * br, 0.13)
        S["hR"] = HR(0.27, 1.04 + 0.003 * br, 0.13)
        S["hLr"] = np.array([25.0, 0, 0])
        S["hRr"] = np.array([25.0, 0, 0])
        S["eL"] = np.array([0.30, 0.25, -0.25])
        S["eR"] = np.array([-0.30, 0.25, -0.25])
        S["cL"] = np.array([GRIP]); S["cR"] = np.array([GRIP])
        return S
    return fn, 4.0, True, True, {}


def relaxed(**kw):
    return dict(hL=HL(0.10, 0.93, 0.24), hR=HR(0.10, 0.93, 0.24), hLr=np.zeros(3), hRr=np.zeros(3),
                cL=[1.0], cR=[1.0], **kw)


def bend_pose(depth):
    """hip hinge: depth 0..1 -> pelvis back/down, torso forward, feet planted."""
    return dict(pel=REST_PELVIS + np.array([0.0, 0.16 * depth, -0.16 * depth]), pelr=[38 * depth, 0, 0],
                sp=[22 * depth, 0, 0], nk=[-10 * depth, 0], hd=[-6 * depth, 0])


def clip_reach_low(A):
    """Right hand reaches a 0.65 m high object 0.42 m ahead, grabs at t=0.45, stands with it at the belly."""
    ks = Keys()
    ks.k(0.0, **relaxed(), **stand_feet(ks))
    obj = HR(0.46, 0.67, 0.10)
    b = bend_pose(1.0)
    ks.k(0.30, **b, hR=obj, hRr=[-30, 0, 0], eR=[-0.15, 0.30, -0.30], hL=HL(0.28, 0.80, 0.22), cR=[OPEN],
         eL=[0.25, 0.30, -0.25])
    ks.k(0.45, **b, hR=obj + np.array([0, 0, -0.01]), hRr=[-30, 0, 0], eR=[-0.15, 0.30, -0.30], hL=HL(0.28, 0.80, 0.22), cR=[GRIP],
         eL=[0.25, 0.30, -0.25])
    b2 = bend_pose(0.45)
    ks.k(0.75, **b2, hR=HR(0.34, 1.00, 0.10), hL=HL(0.30, 1.00, 0.10), hRr=[20, 0, 0], hLr=[20, 0, 0],
         cR=[GRIP], cL=[1.5], eR=[-0.3, 0.3, -0.25], eL=[0.3, 0.3, -0.25])
    ks.k(1.0, **bend_pose(0.0), hR=HR(0.30, 1.04, 0.13), hL=HL(0.30, 1.04, 0.13), hRr=[25, 0, 0], hLr=[25, 0, 0],
         cR=[GRIP], cL=[1.5], eR=[-0.3, 0.3, -0.25], eL=[0.3, 0.3, -0.25])
    return (lambda t: ks.at(t)), 1.0, False, False, dict(events={"grab": 0.45})


def clip_put_down(A):
    """Both hands carry an object at the belly, bend and set it on a 0.65 m high surface 0.42 m ahead, release at 0.40."""
    ks = Keys()
    ks.k(0.0, hR=HR(0.30, 1.04, 0.13), hL=HL(0.30, 1.04, 0.13), hRr=[25, 0, 0], hLr=[25, 0, 0], cR=[GRIP], cL=[GRIP],
         eR=[-0.3, 0.3, -0.25], eL=[0.3, 0.3, -0.25])
    b = bend_pose(1.0)
    put = dict(hR=HR(0.46, 0.67, 0.12), hL=HL(0.46, 0.67, 0.12), hRr=[-20, 0, 0], hLr=[-20, 0, 0],
               eR=[-0.15, 0.30, -0.30], eL=[0.15, 0.30, -0.30])
    ks.k(0.30, **b, **put, cR=[GRIP], cL=[GRIP])
    ks.k(0.40, **b, **put, cR=[OPEN], cL=[OPEN])
    ks.k(0.58, **bend_pose(0.5), hR=HR(0.32, 0.92, 0.18), hL=HL(0.32, 0.92, 0.18), hRr=[0, 0, 0], hLr=[0, 0, 0],
         cR=[OPEN], cL=[OPEN], eR=[-0.3, 0.3, -0.25], eL=[0.3, 0.3, -0.25])
    ks.k(0.80, **bend_pose(0.0), **relaxed())
    return (lambda t: ks.at(t)), 0.8, False, False, dict(events={"release": 0.40})


DOOR_S = 0.86            # body travel (m)
DOOR_T0, DOOR_T1 = 0.10, 1.0


def door_root(t):
    u = min(max((t - DOOR_T0) / (DOOR_T1 - DOOR_T0), 0.0), 1.0)
    return -DOOR_S * u        # world -Y is forward


def clip_door_open_push(A):
    """Right palm flat on a door at 1.02 m (door plane 0.50 m ahead, hand r=0.15), pushes it open and walks through."""
    ks = Keys()
    lead = dict(pelr=[6, 0, 0], sp=[4, 0, 0])
    ks.k(0.0, **relaxed())
    ks.k(0.18, **lead, hR=HR(0.40, 1.02, 0.15), hRr=[-75, 0, 0], eR=[-0.30, 0.40, -0.20], hL=HL(0.05, 0.93, 0.26))
    ks.k(0.40, **lead, hR=HR(0.37, 1.02, 0.15), hRr=[-75, 0, 0], eR=[-0.30, 0.40, -0.20], hL=HL(0.05, 0.93, 0.26))
    ks.k(0.70, **lead, hR=HR(0.34, 1.00, 0.18), hRr=[-60, 0, 0], eR=[-0.30, 0.40, -0.20], hL=HL(0.05, 0.93, 0.26))
    ks.k(0.85, pelr=[3, 0, 0], sp=[2, 0, 0], hR=HR(0.20, 0.97, 0.26), hRr=[0, 0, 0], hL=HL(-0.05, 0.93, 0.26), eR=[-0.25, 0.4, -0.30])
    ks.k(1.0, pelr=[0, 0, 0], sp=[0, 0, 0], hR=HR(-0.05, 0.93, 0.26), hL=HL(0.10, 0.93, 0.26), hRr=[0, 0, 0])
    # feet in W (forward = -Y): left steps to 0.62 at 0.50, right to 1.10 at 0.92
    fl = [(0.0, 0.0, 0, 0.0), (0.12, 0.0, 0, 0.0), (0.22, 0.12, 0.08, -22), (0.36, 0.40, 0.11, -10), (0.50, 0.62, 0.0, 18), (1.0, 0.62, 0.0, 0.0)]
    fr = [(0.0, 0.0, 0, 0.0), (0.45, 0.0, 0, 0.0), (0.58, 0.20, 0.10, -22), (0.72, 0.65, 0.13, -10), (0.92, 1.10, 0.0, 18), (1.0, 1.10, 0.0, 12)]

    def foot(track, base_p, t):
        ts = [k[0] for k in track]
        if t <= ts[0]:
            return base_p + np.array([0, -track[0][1], track[0][2]]), track[0][3]
        for i in range(len(track) - 1):
            if track[i][0] <= t <= track[i + 1][0]:
                u = (t - track[i][0]) / (track[i + 1][0] - track[i][0])
                e = swing(u) if track[i][1] != track[i + 1][1] else u
                fx = track[i][1] + (track[i + 1][1] - track[i][1]) * e
                z = track[i][2] + (track[i + 1][2] - track[i][2]) * e
                if track[i][1] != track[i + 1][1]:
                    z += 0.0
                pit = track[i][3] + (track[i + 1][3] - track[i][3]) * e
                return base_p + np.array([0, -fx, z]), pit
        return base_p + np.array([0, -track[-1][1], track[-1][2]]), track[-1][3]

    def fn(t):
        S = ks.at(t)
        S["T"] = np.array([0.0, door_root(t), 0.0])
        S["fL"], pl = foot(fl, FOOT_L, t)
        S["fR"], pr = foot(fr, FOOT_R, t)
        S["fLr"] = np.array([pl, 0, 0]); S["fRr"] = np.array([pr, 0, 0])
        S["pel"] = REST_PELVIS + np.array([0.0, 0.0, -0.03 + 0.01 * math.sin(2 * math.pi * t)])
        return S
    return fn, 1.0, False, False, dict(travel=[0, 0, DOOR_S], window=[DOOR_T0, DOOR_T1],
                                        events={"contact": 0.18, "release": 0.70})


TRUNK_S = 0.22
TRUNK_T0, TRUNK_T1 = 0.45, 0.95


def clip_trunk_open(A):
    """Lid free edge 0.40 m ahead at 1.0 m; grips with both hands (0.26 apart), lifts to 1.68 m while taking a 0.22 m step in."""
    ks = Keys()
    ks.k(0.0, **relaxed())
    lean = dict(pelr=[10, 0, 0], sp=[6, 0, 0], pel=REST_PELVIS + np.array([0, -0.04, -0.03]))
    grip = dict(hL=HL(0.36, 1.02, 0.13), hR=HR(0.36, 1.02, 0.13), hLr=[-10, 0, 0], hRr=[-10, 0, 0],
                eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40])
    ks.k(0.28, **lean, **grip, cL=[OPEN], cR=[OPEN])
    ks.k(0.38, **lean, **grip, cL=[GRIP], cR=[GRIP])
    ks.k(0.70, pelr=[2, 0, 0], sp=[0, 0, 0], pel=REST_PELVIS + np.array([0, 0.01, -0.01]),
         hL=HL(0.40, 1.42, 0.13), hR=HR(0.40, 1.42, 0.13), hLr=[-30, 0, 0], hRr=[-30, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[GRIP], cR=[GRIP])
    ks.k(0.95, pelr=[-3, 0, 0], sp=[-4, 0, 0], pel=REST_PELVIS + np.array([0, 0.02, 0.0]),
         hL=HL(0.42, 1.68, 0.14), hR=HR(0.42, 1.68, 0.14), hLr=[-45, 0, 0], hRr=[-45, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[1.0], cR=[1.0])
    ks.k(1.20, pelr=[0, 0, 0], sp=[0, 0, 0], pel=REST_PELVIS, **relaxed())

    def fn(t):
        S = ks.at(t)
        u = min(max((t - TRUNK_T0) / (TRUNK_T1 - TRUNK_T0), 0.0), 1.0)
        S["T"] = np.array([0.0, -TRUNK_S * u, 0.0])
        # right foot steps 0.25 (0.45..0.70), left follows 0.20 (0.70..0.95)
        sr = swing(min(max((t - 0.45) / 0.25, 0.0), 1.0))
        sl = swing(min(max((t - 0.70) / 0.25, 0.0), 1.0))
        S["fR"] = FOOT_R + np.array([0, -0.25 * sr, 0.10 * math.sin(math.pi * sr)])
        S["fL"] = FOOT_L + np.array([0, -0.20 * sl, 0.10 * math.sin(math.pi * sl)])
        return S
    return fn, 1.2, False, False, dict(travel=[0, 0, TRUNK_S], window=[TRUNK_T0, TRUNK_T1],
                                       events={"grip": 0.38, "lid_top": 0.95})


def clip_trunk_close(A):
    """Starts where trunk_open ended: pulls the raised lid down, presses it shut with both palms, lets go."""
    ks = Keys()
    ks.k(0.0, pel=REST_PELVIS, hL=HL(0.42, 1.68, 0.14), hR=HR(0.42, 1.68, 0.14), hLr=[-45, 0, 0], hRr=[-45, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[1.0], cR=[1.0])
    ks.k(0.10, pel=REST_PELVIS, hL=HL(0.42, 1.68, 0.14), hR=HR(0.42, 1.68, 0.14), hLr=[-45, 0, 0], hRr=[-45, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[GRIP], cR=[GRIP])
    ks.k(0.40, pelr=[8, 0, 0], sp=[6, 0, 0], pel=REST_PELVIS + np.array([0, -0.02, -0.04]),
         hL=HL(0.38, 1.30, 0.14), hR=HR(0.38, 1.30, 0.14), hLr=[-30, 0, 0], hRr=[-30, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[GRIP], cR=[GRIP])
    ks.k(0.58, pelr=[14, 0, 0], sp=[8, 0, 0], pel=REST_PELVIS + np.array([0, -0.04, -0.06]),
         hL=HL(0.36, 1.03, 0.14), hR=HR(0.36, 1.03, 0.14), hLr=[-10, 0, 0], hRr=[-10, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[OPEN], cR=[OPEN])
    ks.k(0.76, pelr=[17, 0, 0], sp=[10, 0, 0], pel=REST_PELVIS + np.array([0, -0.05, -0.09]),
         hL=HL(0.36, 0.96, 0.14), hR=HR(0.36, 0.96, 0.14), hLr=[-10, 0, 0], hRr=[-10, 0, 0],
         eL=[0.20, 0.30, -0.40], eR=[-0.20, 0.30, -0.40], cL=[OPEN], cR=[OPEN])
    ks.k(1.0, pelr=[0, 0, 0], sp=[0, 0, 0], pel=REST_PELVIS, **relaxed())

    def fn(t):
        S = ks.at(t)
        return S
    return fn, 1.0, False, False, dict(events={"release_lid": 0.58, "press": 0.76})


# ---- car ----------------------------------------------------------------------------------------
SEAT_PEL_Z = 0.575          # pelvis bone height with the seat cushion at 0.50 m
SEAT_SHIFT = 0.75           # seat centre, sideways from the standing spot
CAR_T = [0.0, 2.0]


def sit_base():
    """sit_drive neutral pose, root frame (root under the pelvis, facing car-forward)."""
    return dict(pel=np.array([0.0, 0.04, SEAT_PEL_Z]), pelr=[-4, 0, 0], sp=[-6, 0, 0], nk=[3, 0], hd=[2, 0],
                fL=np.array([0.12, -0.50, 0.075]), fR=np.array([-0.12, -0.50, 0.060]),
                fLr=[0, 0, 0], fRr=[-12, 0, 0],
                hL=HL(0.40, 0.90, 0.19), hR=HR(0.40, 0.90, 0.19), hLr=[10, 0, 0], hRr=[10, 0, 0],
                eL=[0.30, 0.30, -0.30], eR=[-0.30, 0.30, -0.30], cL=[2.2], cR=[2.2])


def clip_sit_drive(A):
    """Seated (cushion 0.50 m), hands at 9 and 3 on a wheel whose centre is 0.46 m ahead of the pelvis (~0.4 m ahead of
    the chest), 4 s loop with breathing, small steering corrections and mirror checks. Root = floor under the hips,
    facing car-forward."""
    sb = sit_base()

    def fn(t):
        w = 2 * math.pi * t / 4.0
        S = {k: v.copy() for k, v in BASE.items()}
        S.update({k: np.array(v, dtype=float) for k, v in sb.items()})
        br = math.sin(w)
        steer = 4.0 * math.sin(w) + 1.5 * math.sin(2 * w + 1.0)       # degrees of wheel rotation about its centre
        cx, cu = 0.40, 0.90
        for key, sg, hf in (("hL", 1, HL), ("hR", -1, HR)):
            a = rad(steer)
            r0, u0 = 0.19, 0.0                                         # hand at 9 / 3 o'clock on a 0.19 m radius rim
            dr = r0 * math.cos(a)
            du = r0 * math.sin(a) * sg
            S[key] = hf(cx + 0.03 * math.sin(a) * sg * 0, cu + du, dr)
        S["sp"] = S["sp"] + np.array([0.5 * br, 0.0, 0.0])
        S["hd"] = np.array([2.0, 6.0 * math.sin(w * 0.5)])               # glances at mirror / road
        S["nk"] = np.array([3.0 - 0.3 * br, 3.0 * math.sin(w * 0.5)])
        return S
    return fn, 4.0, True, False, {}


def enter_keys():
    ks = Keys()
    sb = sit_base()
    ks.k(0.0, **relaxed())
    # 0.30 right hand on the door handle (r=0.20, 0.34 ahead, 0.98 high)
    ks.k(0.30, pelr=[6, 0, 0], sp=[4, 0, 0], hR=HR(0.34, 0.98, 0.20), hRr=[-10, 0, 0], cR=[GRIP], eR=[-0.3, 0.3, -0.3])
    # 0.55 pulls it open to the belly, then lets go
    ks.k(0.55, pelr=[4, 0, 0], sp=[2, 0, 0], hR=HR(0.20, 0.96, 0.10), hRr=[-10, 0, 0], cR=[GRIP], eR=[-0.3, 0.3, -0.3])
    ks.k(0.75, pelr=[8, 0, 0], sp=[4, 0, 0], pel=REST_PELVIS + np.array([0, 0.03, -0.12]),
         hR=HR(0.28, 0.80, 0.22), hL=HL(0.28, 0.80, 0.22), hRr=[0, 0, 0], cR=[OPEN], cL=[OPEN],
         eR=[-0.3, 0.3, -0.25], eL=[0.3, 0.3, -0.25])
    # 1.20 on the seat edge, torso upright, hands on the thighs
    ks.k(1.20, pelr=[0, 0, 0], sp=[6, 0, 0], pel=np.array([0.0, 0.0, SEAT_PEL_Z + 0.02]), hd=[0, 0],
         hR=HR(0.22, 0.72, 0.22), hL=HL(0.22, 0.72, 0.22), cR=[1.0], cL=[1.0], eR=[-0.3, 0.3, -0.25], eL=[0.3, 0.3, -0.25])
    ks.k(1.75, pelr=[-3, 0, 0], sp=[-2, 0, 0], pel=np.array([0.0, 0.03, SEAT_PEL_Z]),
         hR=HR(0.30, 0.82, 0.20), hL=HL(0.30, 0.82, 0.20), cR=[1.4], cL=[1.4])
    ks.k(2.0, **{k: v for k, v in sb.items() if k in ("pel", "pelr", "sp", "nk", "hd", "hL", "hR", "hLr", "hRr", "eL", "eR", "cL", "cR")})
    return ks


# root path (world): follows the pelvis horizontally. yaw 0 -> +90 (turn left, to face car-forward = +X)
def enter_root(t):
    # translation toward the seat (-Y in W): starts at 0.55, edge at 1.2, centre at 1.75
    tr = Keys()
    tr.k(0.0, T=[0, 0, 0], psi=[0]).k(0.55, T=[0, 0, 0], psi=[0]).k(1.20, T=[0, -0.50, 0], psi=[90]).k(1.75, T=[0, -SEAT_SHIFT, 0], psi=[90])
    tr.k(2.0, T=[0, -SEAT_SHIFT, 0], psi=[90])
    return tr.at(t)


def enter_feet(t):
    """world ankle targets: both feet outside until 1.20, then swing over the sill into the footwell (x=+0.45, y~-0.65/-0.85)."""
    sb = sit_base()
    endL = np.array([0.50, -SEAT_SHIFT + 0.12, 0.075])
    endR = np.array([0.50, -SEAT_SHIFT - 0.12, 0.060])
    u = min(max((t - 1.15) / 0.65, 0.0), 1.0)
    e = swing(u)
    # left foot: stays, then steps up and over
    sL = FOOT_L + np.array([0.0, -0.10 * swing(min(max((t - 0.55) / 0.5, 0), 1)), 0.0])
    sR = FOOT_R + np.array([0.0, -0.05 * swing(min(max((t - 0.55) / 0.5, 0), 1)), 0.0])
    # arcs: lift in the middle of the swing
    fL = sL * (1 - e) + endL * e + np.array([0, 0, 0.26 * math.sin(math.pi * e)])
    fR = sR * (1 - e) + endR * e + np.array([0, 0, 0.30 * math.sin(math.pi * min(e * 1.1, 1.0))])
    yaw = 90 * e
    return fL, fR, yaw


def enter_pose(t):
    S = enter_keys().at(t)
    r = enter_root(t)
    S["T"] = r["T"]
    S["psi"] = r["psi"]
    S["fL"], S["fR"], yaw = enter_feet(t)
    S["fLr"] = np.array([0.0, yaw, 0.0]); S["fRr"] = np.array([0.0 - 12 * (t > 1.8), yaw, 0.0])
    return S


def clip_car_enter_driver(A):
    """Opens the door, turns 90 deg left, sits on the seat edge, slides in and swings the legs over the sill; ends in the
    first frame of sit_drive. Body motion for the game: see anims_v5.json (travel (0,0.75) sideways toward the seat,
    yaw +90 over t=0.55..1.75; the car script snaps the player to the seat anchor at the end)."""
    return enter_pose, 2.0, False, False, dict(travel=[0, 0, 0.75], yaw=90, window=[0.55, 1.75],
                                               events={"door_grip": 0.30, "door_open": 0.55, "seated": 1.75})


def clip_car_exit_driver(A):
    """car_enter_driver played backwards (seat -> legs out -> stand and turn to the door). Body motion reversed."""
    def fn(t):
        return enter_pose(2.0 - t)
    return fn, 2.0, False, False, dict(travel=[-0.75, 0, 0], yaw=-90, window=[0.25, 1.45],
                                       events={"seat_released": 0.25, "door_push": 1.45})


# ---- stairs ------------------------------------------------------------------------------------
STAIR_CYCLE = 1.2
STAIR_RUN, STAIR_RISE = 0.56, 0.36


def clip_stairs_down(A):
    """Descending 0.18 m risers / 0.28 m treads, 2 steps per 1.2 s. The root must move 0.56 m forward and 0.36 m DOWN
    every cycle (0.467 m/s horizontal, 0.30 m/s down); the stance foot rises relative to it, as in the game."""
    v = STAIR_RUN / STAIR_CYCLE
    vz = STAIR_RISE / STAIR_CYCLE

    def foot_at(base, off, t):
        ph = (t / STAIR_CYCLE + off) % 1.0
        ts = t - ph * STAIR_CYCLE                       # landing time of the current cycle
        spot = base + np.array([0.0, -v * ts, -vz * ts])
        if ph < 0.55:
            return spot, 0.0
        u = (ph - 0.55) / 0.45
        e = swing(u)
        pitch = -28 * math.sin(math.pi * min(u * 1.25, 1.0)) + 20 * max(0.0, (u - 0.8) / 0.2)
        return spot + np.array([0.0, -STAIR_RUN * e, -STAIR_RISE * e + 0.14 * math.sin(math.pi * u) ** 1.2]), pitch

    def fn(t):
        w = 2 * math.pi * t / STAIR_CYCLE
        S = {k: v_.copy() for k, v_ in BASE.items()}
        S["T"] = np.array([0.0, -v * t, -vz * t])
        S["fL"], pL = foot_at(FOOT_L, 0.0, t)
        S["fR"], pR = foot_at(FOOT_R, 0.5, t)
        S["fLr"] = np.array([pL, 0, 0]); S["fRr"] = np.array([pR, 0, 0])
        S["pel"] = REST_PELVIS + np.array([0.0, 0.03, -0.045 + 0.012 * math.sin(2 * w)])
        S["pelr"] = np.array([-2.0, 0.0, 0.0])
        S["sp"] = np.array([-2.0, 4.0 * math.sin(w), 0.0])
        sw = math.sin(w)
        S["hL"] = HL(0.10 - 0.09 * sw, 0.93, 0.24)
        S["hR"] = HR(0.10 + 0.09 * sw, 0.93, 0.24)
        return S
    return fn, STAIR_CYCLE, True, False, dict(travel=[0, 0, STAIR_RUN], down=STAIR_RISE, window=[0.0, STAIR_CYCLE])


CLIPS = [
    ("carry_duffel", clip_carry_duffel),
    ("reach_low", clip_reach_low),
    ("put_down", clip_put_down),
    ("door_open_push", clip_door_open_push),
    ("trunk_open", clip_trunk_open),
    ("trunk_close", clip_trunk_close),
    ("car_enter_driver", clip_car_enter_driver),
    ("sit_drive", clip_sit_drive),
    ("car_exit_driver", clip_car_exit_driver),
    ("stairs_down", clip_stairs_down),
]


def main():
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bpy.context.view_layer.objects.active = rig
    for o in bpy.data.objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="OBJECT")
    only = [a.split("=")[1].split(",") for a in ARGS if a.startswith("--only=")]
    only = only[0] if only else None
    A = A5(rig)
    A.leg_info()
    A.add_ik()
    A.add_arm_ik()
    A.calibrate_curl()
    meta = json.load(open(META_PATH)) if os.path.exists(META_PATH) else {}
    for name, builder in CLIPS:
        if only and name not in only:
            continue
        fn, length, loop, upper, extra = builder(A)
        m = A.make(name, length, fn, loop, upper=upper)
        m.update(extra)
        if name == "car_exit_driver":
            # make the root track relative to the clip's first frame, in the first frame's body axes
            r0 = m["root"][0]
            rel = []
            for x, y, z, psi in m["root"]:
                dx, dy = x - r0[0], y - r0[1]
                a = math.radians(r0[3])
                # world delta -> start body frame (x = left, y = backwards)
                fwd = (math.sin(a), -math.cos(a))           # forward direction in W for yaw a (facing -Y at a=0)
                left = (math.cos(a), math.sin(a))
                rel.append([dx * left[0] + dy * left[1], -(dx * fwd[0] + dy * fwd[1]), z - r0[2], psi - r0[3]])
            m["root"] = rel
        meta[name] = m
    # tidy: drop IK helpers
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode="EDIT")
    for n in A.ik_names:
        rig.data.edit_bones.remove(rig.data.edit_bones[n])
    bpy.ops.object.mode_set(mode="OBJECT")
    A.reset() if False else None
    rig.animation_data.action = bpy.data.actions["idle"]
    os.makedirs(os.path.dirname(META_PATH), exist_ok=True)
    json.dump(meta, open(META_PATH, "w"))
    log("wrote", META_PATH)
    # runtime copy for the game (root-motion tracks + events), world frame W: x = character left, y = backwards, z = up
    game_meta = {}
    for k, m in meta.items():
        moving = any(abs(v) > 1e-6 for r in m["root"] for v in r)
        g = {"length": m["length"], "loop": m["loop"], "events": m.get("events", {})}
        for key in ("travel", "yaw", "window", "down"):
            if key in m:
                g[key] = m[key]
        if moving:
            g["root"] = [[round(v, 4) for v in r] for r in m["root"]]
        game_meta[k] = g
    json.dump(game_meta, open(os.path.join(REPO, "game/characters/mani/mani_actions.json"), "w"), indent=0)
    save = [a.split("=", 1)[1] for a in ARGS if a.startswith("--save=")]
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=save[0])
    if "--no-export" not in ARGS:
        objs = {"rig": rig}
        B.export_glb(objs)
        bpy.ops.wm.save_as_mainfile(filepath=B.OUT_BLEND)


main()
