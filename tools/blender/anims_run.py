"""Mani easy-run (jog) clip, rebuilt from running mechanics.  Replaces the `jog` action only.

    blender -b art_source/characters/mani/mani.blend -P tools/blender/anims_run.py -- [--no-export] [--save=FILE]

Everything else in the blend (fitted clothes, face, the other 16 clips) is untouched; the glb is re-exported the same
way anims_v5.py does.  World frame: rig faces -Y, +Z up, character left = +X.  The clip is authored in place: stance
feet travel backwards at SPEED (no slide), the pelvis rides a bounce curve clamped by what the legs can reach.

Mechanics (PARAMS): 22 frames = 0.733 s per 2 steps (164 steps/min), foot on the ground 40 % of the cycle -> two flight
phases of 10 % (20 % total), mid-foot strike just ahead of the hip, stance knee ~40 deg at mid-stance, swing knee ~100
deg, trunk lean ~6 deg as one piece from the ankles, arms at ~90 deg swinging forward / back beside the body.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_mani as B  # noqa: E402

# anims_v5 ends with an unguarded main(): load its definitions without running it
V5 = type(sys)("anims_v5_defs")
V5.__file__ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "anims_v5.py")
exec(compile(open(V5.__file__).read().rsplit("\nmain()", 1)[0], V5.__file__, "exec"), V5.__dict__)

log = B.log
FPS = 30
P = dict(
    frames=22, speed=2.8, sf=0.38, S0=0.26, S1=0.52, clearance=0.30, pitch_hs=4.0, pitch_to=42.0,
    bob_peak=0.012, stance_dip=0.05, lean_pelvis=2.5, lean_spine=3.5, yaw=5.0, roll=1.5, counter=0.9,
    arm_fwd=10.0, arm_back=-36.0, elbow=98.0, foot_x=0.13, reach=0.992, sway=0.006,
)
HA, HEEL, TOE = 0.069, 0.07, 0.13
ARGS = B.ARGS


def smoother(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * x * (x * (x * 6 - 15) + 10)


BALL = (0.141, -0.064)       # ball-of-foot joint relative to the ankle (forward, up), from the rig
HEEL_PT = (-0.08, -0.069)    # heel contact point relative to the ankle


def pivot(th):
    """(forward offset, lift) of the ankle relative to its flat position when the foot is pitched `th` deg (toes up +)
    about the heel (th > 0, heel strike) or about the ball joint (th < 0, rolling onto the toes): that point stays put."""
    r = math.radians(th)
    c, sn = math.cos(r), math.sin(r)
    pf, pz = (HEEL_PT if th >= 0 else BALL)
    rf, rz = pf * c - pz * sn, pf * sn + pz * c
    gz = 0.0 if th >= 0 else 0.005                       # ground height of the pivot point (flat foot: heel 0, ball joint 0.005)
    return pf - rf, (gz - rz) - HA


def pivot_z(th):
    return pivot(th)[1]


def foot(p, q):
    """p in [0,1): (ankle s ahead of the hip, ankle lift above its flat height, pitch deg, in_stance)."""
    sf, S0, S1 = q["sf"], q["S0"], q["S1"]
    if p < sf:
        u = p / sf
        th = q["pitch_hs"] * (1 - smoother(u / 0.15)) - q["pitch_to"] * smoother((u - 0.55) / 0.45)
        s = S0 - (S0 + S1) * u + pivot(th)[0]
        return s, pivot_z(th), th, True
    v = (p - sf) / (1 - sf)
    th0, th1 = -q["pitch_to"], q["pitch_hs"]
    s0 = -S1 + pivot(th0)[0]
    z0, z1 = pivot_z(th0), pivot_z(th1)
    e = smoother(v)
    th = th0 * (1 - smoother(v / 0.5)) + th1 * smoother((v - 0.6) / 0.4)
    z = z0 + (z1 - z0) * e + q["clearance"] * math.sin(math.pi * v ** 0.72) ** 1.1
    s = s0 + (S0 - s0) * (0.6 * e + 0.4 * math.sin(math.pi / 2 * v) ** 2)
    return s, z, th, False


def pelvis_dz(q, A, N=120):
    """Per-sample pelvis height offset: bounce (low at mid-stance, high mid-flight) clamped by leg reach."""
    lat = abs(A.hip_x - q["foot_x"])
    bob = q["stance_dip"] + q["bob_peak"]
    out = np.zeros(N)
    for i in range(N):
        p = i / N
        ph = (p % 0.5) * 2
        z = q["bob_peak"] - bob * 0.5 * (1 + math.cos(2 * math.pi * (ph - q["sf"])))
        for pp in (p, (p + 0.5) % 1.0):
            s, zl, th, st = foot(pp, q)
            if True:
                dist = A.leg_len * q["reach"]
                top = zl + math.sqrt(max(dist * dist - s * s - lat * lat, 0.01)) - A.hip_h
                z = min(z, top)
        out[i] = z
    k = 3
    sm = np.array([np.mean([out[(i + j) % N] for j in range(-k, k + 1)]) for i in range(N)])
    return np.minimum(sm, out + 0.003)


class Runner:
    def __init__(self, A, q=P):
        self.A, self.q = A, q
        self.N = 120
        self.dz = pelvis_dz(q, A, self.N)
        self.rest_sh = {s: A.rest_head["upperarm_" + s].copy() for s in ("l", "r")}
        self.ua = (A.rest_head["lowerarm_l"] - A.rest_head["upperarm_l"]).length
        self.fa = (A.rest_head["hand_l"] - A.rest_head["lowerarm_l"]).length
        log("run: leg %.3f hip_h %.3f upperarm %.3f forearm %.3f" % (A.leg_len, A.hip_h, self.ua, self.fa))

    def pose(self, p):
        q, A = self.q, self.A
        BASE = V5.BASE
        S = {k: v.copy() for k, v in BASE.items()}
        w = 2 * math.pi * p
        dz = float(np.interp(p * self.N, np.arange(self.N + 1), np.append(self.dz, self.dz[0])))
        # pelvis: bounce, lateral shift over the stance leg (left stance at p ~ 0.2)
        S["pel"] = V5.REST_PELVIS + np.array([q["sway"] * math.sin(w + 0.3), 0.0, dz])
        yaw = q["yaw"] * math.cos(w)                                   # +: left hip forward at left strike (p=0)
        roll = q["roll"] * math.sin(w - 0.3)                           # swing-side hip drops
        S["pelr"] = np.array([q["lean_pelvis"], -yaw, roll])
        S["sp"] = np.array([q["lean_spine"], yaw * q["counter"] * 1.1, -roll * 0.8])
        S["nk"] = np.array([-q["lean_spine"] * 0.35, yaw * 0.05])
        S["hd"] = np.array([-(q["lean_pelvis"] + q["lean_spine"]) * 0.65, yaw * 0.1])
        for key, pp in (("L", p % 1.0), ("R", (p + 0.5) % 1.0)):
            s, zl, th, st = foot(pp, q)
            sg = 1 if key == "L" else -1
            S["f" + key] = np.array([sg * q["foot_x"], -0.015 - s, V5.FOOT_L[2] + zl])
            S["f" + key + "r"] = np.array([th, 0.0, 0.0])
        # arms: filled after a first pass (shoulder position follows the pelvis / lean)
        return S

    def arms(self, S, p):
        """Sagittal swing: upper arm swings fwd/back by alpha, forearm flexed by `elbow` -> wrists, elbow pole behind."""
        q, A = self.q, self.A
        rig = A.rig
        A.apply(S, arm_ik=False)
        bpy.context.view_layer.update()
        w = 2 * math.pi * p
        for s, key, sg, ph in (("l", "L", 1, 0.0), ("r", "R", -1, math.pi)):
            sh = rig.matrix_world @ rig.pose.bones["upperarm_" + s].head
            # arm swings opposite the same-side leg: left leg forward at p=0 -> left arm back
            c = math.cos(w + ph)
            mid, amp = (q["arm_fwd"] + q["arm_back"]) / 2, (q["arm_fwd"] - q["arm_back"]) / 2
            alpha = math.radians(mid - amp * c)
            flex = math.radians(q["elbow"] + 10 * (-c))                 # a touch more flexed on the forward swing
            u = Vector((0, -math.sin(alpha), -math.cos(alpha)))
            f = Vector((0, -math.sin(alpha + flex), -math.cos(alpha + flex)))
            out = Vector((sg * 0.07, 0, 0))
            elbow = sh + u * self.ua + out
            wrist = elbow + f * self.fa - out * 0.5
            S["h" + key] = np.array([wrist.x, wrist.y, wrist.z])
            S["e" + key] = np.array([sg * 0.20, 0.55, 0.05])           # pole behind and slightly out of the elbow
            S["h" + key + "r"] = np.array([-8.0, 0.0, 0.0])
            S["c" + key] = np.array([0.9])
        return S

    def fn(self, t):
        p = (t / (self.q["frames"] / FPS)) % 1.0
        S = self.pose(p)
        S = self.arms(S, p)
        if os.environ.get("RUN_DEBUG"):
            A = self.A
            A.apply(S, True)
            bpy.context.view_layer.update()
            es = []
            for s_, k_ in (("l", "L"), ("r", "R")):
                got = A.rig.matrix_world @ A.rig.pose.bones["calf_" + s_].tail
                es.append((got - Vector(S["f" + k_])).length)
                hip = A.rig.matrix_world @ A.rig.pose.bones["thigh_" + s_].head
            log("dbg p=%.3f err L %.3f R %.3f pel z %.3f fL %s" % (p, es[0], es[1], S["pel"][2], np.round(S["fL"], 3)))
        return S


def main():
    rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    bpy.context.view_layer.objects.active = rig
    for o in bpy.data.objects:
        o.select_set(False)
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="OBJECT")
    A = V5.A5(rig)
    A.leg_info()
    A.add_ik()
    A.add_arm_ik()
    A.calibrate_curl()
    for a in ARGS:
        if a.startswith("--p."):
            k, v = a[4:].split("=")
            P[k] = float(v) if k != "frames" else int(v)
    R = Runner(A)
    length = P["frames"] / FPS
    if "jog" in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions["jog"])
    # make() calls fn(t) once per frame (0..frames) in sequence
    m = A.make("jog", length, R.fn, True)
    log("run clip meta", {k: v for k, v in m.items() if k != "root"})
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode="EDIT")
    for n in A.ik_names:
        rig.data.edit_bones.remove(rig.data.edit_bones[n])
    bpy.ops.object.mode_set(mode="OBJECT")
    rig.animation_data.action = bpy.data.actions["idle"]
    rig.data.pose_position = "POSE"
    save = [a.split("=", 1)[1] for a in ARGS if a.startswith("--save=")]
    if save:
        bpy.ops.wm.save_as_mainfile(filepath=save[0])
    if "--no-export" not in ARGS:
        B.export_glb({"rig": rig})
        bpy.ops.wm.save_as_mainfile(filepath=B.OUT_BLEND)


main()
