"""Render the built Mani with orthographic cameras matching the face-sheet front / profile panels.

    blender -b <mani.blend> -P tools/likeness/overlay.py -- OUT_DIR
    tools/.venv/bin/python -I tools/likeness/overlay_compose.py OUT_DIR

Writes raw_front.png / raw_profile.png plus overlay_params.json (view similarity from the model landmarks
in model_landmarks.json to the sheet landmarks); overlay_compose.py warps the renders onto the panels
and writes overlay_front.png / overlay_profile.png (50 % blend) and prints the mean landmark error.
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
L = os.path.join(REPO, "art_source/characters/mani/likeness")
OUT = sys.argv[sys.argv.index("--") + 1]
os.makedirs(OUT, exist_ok=True)
sheet = json.load(open(os.path.join(L, "sheet_landmarks.json")))
model = json.load(open(os.path.join(L, "model_landmarks.json")))
PANEL = {"front": (411, 825), "profile": (404, 825)}

sc = bpy.context.scene
for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]:
    bpy.data.objects.remove(o)
world = sc.world or bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.36, 0.36, 0.37, 1)
bg.inputs["Strength"].default_value = 1.0
for name, loc, e, size in (("key", (-1.2, -3.0, 2.4), 260, 2.5), ("fill", (2.5, -2.0, 1.6), 140, 3.0), ("top", (0, 0, 3.0), 60, 3.0)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size = e, size
    ob = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 1.6)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
if rig:
    rig.data.pose_position = "REST"
sc.render.engine = "BLENDER_EEVEE"
sc.eevee.taa_render_samples = 48
sc.view_settings.view_transform = "Standard"
sc.render.image_settings.file_format = "PNG"
cd = bpy.data.cameras.new("cam")
cd.type = "ORTHO"
cam = bpy.data.objects.new("cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam


def procrustes(P, Q):
    pm, qm = P.mean(0), Q.mean(0)
    p, q = P - pm, Q - qm
    a = (p * q).sum()
    b = (p[:, 0] * q[:, 1] - p[:, 1] * q[:, 0]).sum()
    c, s = a / (p ** 2).sum(), b / (p ** 2).sum()
    R = np.array([[c, -s], [s, c]])
    return R, qm - R @ pm


params = {}
for view in ("front", "profile"):
    names = [k for k in model[view] if k in sheet["points"][view]]
    M = np.array([model[view][k] for k in names])
    P = np.stack([M[:, 0], -M[:, 2]], 1) if view == "front" else np.stack([M[:, 1], -M[:, 2]], 1)
    Q = np.array([sheet["points"][view][k] for k in names], float)
    R, t = procrustes(P, Q)
    s = math.sqrt(abs(np.linalg.det(R)))
    W, H = PANEL[view]
    Rinv = np.linalg.inv(R)
    mc = Rinv @ (np.array([W / 2, H / 2]) - t)       # view-plane point rendered at the image centre
    sc.render.resolution_x, sc.render.resolution_y = W, H
    cd.ortho_scale = W / s
    if view == "front":
        cam.location = (mc[0], -5.0, -mc[1])
        direction = Vector((0, 1, 0))
    else:
        cam.location = (5.0, mc[0], -mc[1])
        direction = Vector((-1, 0, 0))
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(OUT, "raw_%s.png" % view)
    bpy.ops.render.render(write_still=True)
    params[view] = {"R": R.tolist(), "t": t.tolist(), "s": s, "mc": mc.tolist(), "size": [W, H],
                    "err_px": float(np.linalg.norm(P @ R.T + t - Q, axis=1).mean()),
                    "model": P.tolist(), "sheet": Q.tolist(), "names": names}
json.dump(params, open(os.path.join(OUT, "overlay_params.json"), "w"))
print("overlay renders done", {v: round(params[v]["err_px"], 2) for v in params})
