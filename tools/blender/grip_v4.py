"""Mani v4 carry grips: fit the two-handed hold (arm spread, finger curls, thumb on top) and the item position for
each carried apartment item so that no finger capsule intersects the item and the hands wrap it.

Used by build_mani.build_animations: for every item in ITEMS a coordinate-descent search over the arm / hand / item
parameters (below) minimises  finger penetration  +  palm / fingertip / thumb contact error,  evaluated by posing the
real rig.  The result sets the `carry_<item>` clip and the per-item offset written to
art_source/characters/mani/grip.json (copied into player.gd CARRY_ITEMS).

Frames: Blender world, character faces -Y, +X is his left. Body space of the game (x right, y up, z back):
(x, y, z)_body = (-X, Z, Y)_blender.
"""
import json
import math
import os

import bpy
import numpy as np
from mathutils import Vector

# item box dims in body axes (width x, height y, depth z) as modelled in game/environments/windsor/apartment/models
ITEMS = {
    "sweets": dict(dims=(0.258, 0.086, 0.210), yaws=(0,)),
    "diyas": dict(dims=(0.272, 0.034, 0.249), yaws=(0,)),
    "radio": dict(dims=(0.124, 0.239, 0.079), yaws=(0, 90)),
}
NOMINAL = {"index": (14, 18.2, 12.6), "middle": (18, 23.4, 16.2), "ring": (22, 28.6, 19.8), "pinky": (26, 33.8, 23.4)}
THUMB = (8, 12, 10)
START = dict(inward=26.0, fwd=14.0, elbow=98.0, twist=0.0, flex=0.0, ci=0.5, cm=0.5, cr=0.5, cp=0.5, ct=0.6,
             tx=0.0, ty=0.0, tz=0.0, cy=-0.09, cz=0.03)
BOUNDS = dict(inward=(8, 55), fwd=(0, 40), elbow=(70, 115), twist=(-35, 35), flex=(-30, 30), ci=(0, 2.4), cm=(0, 2.4),
              cr=(0, 2.4), cp=(0, 2.4), ct=(0, 2.4), tx=(-45, 45), ty=(-45, 45), tz=(-45, 45), cy=(-0.20, 0.05),
              cz=(-0.08, 0.14))
STEP = dict(inward=6, fwd=5, elbow=6, twist=8, flex=8, ci=0.4, cm=0.4, cr=0.4, cp=0.4, ct=0.4, tx=12, ty=12, tz=12,
            cy=0.02, cz=0.015)


def grip_from(prm):
    g = {k: tuple(a * prm["c" + k[0]] for a in v) for k, v in NOMINAL.items()}
    g["thumb"] = tuple(a * prm["ct"] for a in THUMB)
    g["thumb_rot"] = (prm["tx"], prm["ty"], prm["tz"])
    return g


class Probe:
    def __init__(self, rig):
        self.rig = rig

    def wp(self, name, tail=False):
        pb = self.rig.pose.bones[name]
        return np.array(self.rig.matrix_world @ (pb.tail if tail else pb.head))


def box_sd(p, ctr, half, yaw):
    """signed distance from point p to the item box (Blender axes, centred at ctr, yawed about Z)."""
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    d = p - ctr
    q = np.array([c * d[0] + s * d[1], -s * d[0] + c * d[1], d[2]])
    a = np.abs(q) - half
    out = np.linalg.norm(np.maximum(a, 0))
    return out + min(max(a[0], a[1], a[2]), 0.0), q


def evaluate(probe, prm, dims, yaw, detail=False):
    """cost of the currently posed rig for item box `dims` (body axes) at yaw."""
    w, h, d = dims
    half = np.array([w / 2, d / 2, h / 2])        # item frame (yaw is applied in box_sd)
    wl, wr = probe.wp("hand_l"), probe.wp("hand_r")
    ctr = (wl + wr) / 2 + np.array([0.0, prm["cy"], prm["cz"]])
    pen_cost, tip_cost, thumb_cost, worst = 0.0, 0.0, 0.0, 0.0
    # right hand (the left is its mirror image)
    caps = [("hand_r", 0.026)]
    for f in ("index", "middle", "ring", "pinky"):
        caps += [("%s_0%d_r" % (f, k), 0.0085) for k in (1, 2, 3)]
    caps += [("thumb_0%d_r" % k, 0.0105) for k in (1, 2, 3)]
    for n, r in caps:
        p0, p1 = probe.wp(n), probe.wp(n, True)
        deep = max(r - box_sd(p0 + (p1 - p0) * t, ctr, half, yaw)[0] for t in (0.0, 0.25, 0.5, 0.75, 1.0))
        worst = max(worst, deep)
        pen_cost += max(deep + 0.003, 0.0) ** 2
    # palm touches the side face
    pm = probe.wp("hand_r") + (probe.wp("hand_r", True) - probe.wp("hand_r")) * 0.5
    sd_palm, _ = box_sd(pm, ctr, half, yaw)
    palm_cost = (sd_palm - 0.024) ** 2
    # fingertips close to the surface (wrapping) but never inside
    for f in ("index", "middle", "ring", "pinky"):
        tip = probe.wp("%s_03_r" % f, True)
        sd, _ = box_sd(tip, ctr, half, yaw)
        tip_cost += max(sd - 0.0085 - 0.004, 0.0) ** 2
    # thumb tip rests on top of the item (above its mid height), touching
    tt = probe.wp("thumb_03_r", True)
    sd_t, q = box_sd(tt, ctr, half, yaw)
    thumb_cost += max(sd_t - 0.0105 - 0.004, 0.0) ** 2 + max(0.004 - q[2], 0.0) ** 2 * 2.0
    # keep the item between the hands and level with them
    total = 900 * pen_cost + 300 * palm_cost + 25 * tip_cost + 10 * thumb_cost
    if detail:
        return total, dict(worst_pen=worst, sd_palm=sd_palm, sd_thumb=sd_t, ctr=ctr, half=half)
    return total


def optimize(rig, pose_fn, item, sweeps=7, log=print):
    cfg = ITEMS[item]
    probe = Probe(rig)
    best_all = None
    for yaw in cfg["yaws"]:
        prm = dict(START)
        if item == "diyas":
            prm["cz"] = 0.05
        pose_fn(prm)
        cost = evaluate(probe, prm, cfg["dims"], yaw)
        step = dict(STEP)
        for sw in range(sweeps):
            for k in prm:
                for sgn in (1, -1):
                    lo, hi = BOUNDS[k]
                    v = min(max(prm[k] + sgn * step[k], lo), hi)
                    if v == prm[k]:
                        continue
                    old = prm[k]
                    prm[k] = v
                    pose_fn(prm)
                    c = evaluate(probe, prm, cfg["dims"], yaw)
                    if c < cost - 1e-12:
                        cost = c
                    else:
                        prm[k] = old
            step = {k: s * 0.6 for k, s in step.items()}
        # random pattern search on top (escapes the coordinate-descent local minimum)
        rng = np.random.RandomState(5)
        scale = 0.7
        for it in range(520):
            if it % 130 == 129:
                scale *= 0.55
            cand = dict(prm)
            ks = rng.choice(list(prm), size=rng.randint(2, 6), replace=False)
            for k in ks:
                lo, hi = BOUNDS[k]
                cand[k] = float(min(max(cand[k] + rng.normal(0, STEP[k] * scale), lo), hi))
            pose_fn(cand)
            c = evaluate(probe, cand, cfg["dims"], yaw)
            if c < cost:
                cost, prm = c, cand
        pose_fn(prm)
        cost, info = evaluate(probe, prm, cfg["dims"], yaw, detail=True)
        log("grip %s yaw %d: cost %.5f worst penetration %.4f m, palm %.4f thumb %.4f" % (
            item, yaw, cost, info["worst_pen"], info["sd_palm"], info["sd_thumb"]))
        if best_all is None or cost < best_all[0]:
            best_all = (cost, yaw, dict(prm), info)
    cost, yaw, prm, info = best_all
    pose_fn(prm)
    wr = probe.wp("hand_r")
    v = info["ctr"] - wr
    offset_body = (round(float(-v[0]), 4), round(float(v[2]), 4), round(float(v[1]), 4))
    return dict(params={k: round(float(x), 4) for k, x in prm.items()}, yaw=yaw, offset_body=offset_body,
                worst_penetration=round(float(info["worst_pen"]), 4))
