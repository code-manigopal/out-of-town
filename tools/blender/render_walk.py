"""Contact sheet of an animation clip (side view, orthographic, N frames) + foot-slide / knee report.

    blender -b <mani blend> -P tools/blender/render_walk.py -- OUT.png [--clip=walk] [--frames=8] [--view=side|front|34]

The pose is evaluated from the action stored in the blend (actions walk/jog/idle/carry). Prints the stance-foot
slide (m/s error against the clip's authored ground speed), knee flexion at heel strike and at swing peak, trunk
lean and head sway.
"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
clip = next((a.split("=")[1] for a in args if a.startswith("--clip=")), "walk")
nfr = int(next((a.split("=")[1] for a in args if a.startswith("--frames=")), "8"))
view = next((a.split("=")[1] for a in args if a.startswith("--view=")), "side")
sc = bpy.context.scene
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
act = bpy.data.actions[clip]
rig.animation_data_create()
rig.animation_data.action = act
rig.data.pose_position = "POSE"
f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
n_clip = f1 - f0
fps = 30.0
speed = {"walk": 1.333, "jog": 2.8}.get(clip, 0.0)


def pose_at(f):
    sc.frame_set(f)
    bpy.context.view_layer.update()


def wp(name, tail=False):
    pb = rig.pose.bones[name]
    return rig.matrix_world @ (pb.tail if tail else pb.head)


# ---- numbers ----
rows = []
for f in range(f0, f1):
    pose_at(f)
    rows.append(dict(
        fl=wp("foot_l"), fr=wp("foot_r"), kl=wp("calf_l"), kr=wp("calf_r"), hl=wp("thigh_l"), hr=wp("thigh_r"),
        al=wp("calf_l", True), ar=wp("calf_r", True), head=wp("head"), pelvis=wp("pelvis"), s3=wp("spine_03"),
        neck=wp("neck_01")))


def knee_flex(h, k, a):
    u, v = (k - h), (a - k)
    return math.degrees(u.angle(v))


if clip in ("walk", "jog"):
    kfl = [max(knee_flex(r["hl"], r["kl"], r["al"]), 0) for r in rows]
    kfr = [max(knee_flex(r["hr"], r["kr"], r["ar"]), 0) for r in rows]
    # heel strike = frame where a foot's y is most forward (-Y) before it starts moving back
    ys = np.array([r["fl"].y for r in rows])
    hs = int(np.argmin(ys))
    print("[walk] knee flex at left heel strike %.1f deg, max in swing %.1f deg, stance-mid min %.1f deg" % (
        kfl[hs], max(kfl), min(kfl)))
    zs = np.array([r["fl"].z for r in rows])
    stance = zs < (zs.min() + 0.02)
    dy = np.diff(np.append(ys, ys[0])) * fps
    err = np.abs(dy[stance] - speed)
    print("[walk] foot slide in stance: mean %.3f m/s, max %.3f m/s (%d stance frames, speed %.2f)" % (err.mean(), err.max(), stance.sum(), speed))
    lean = [math.degrees(math.atan2(-(r["neck"].y - r["pelvis"].y), r["neck"].z - r["pelvis"].z)) for r in rows]
    print("[walk] trunk lean (pelvis->neck) mean %.1f deg range %.1f..%.1f" % (np.mean(lean), min(lean), max(lean)))
    hz = [r["pelvis"].z for r in rows]
    print("[walk] pelvis height %.3f..%.3f (drop range %.3f m); head x sway %.4f m" % (min(hz), max(hz), max(hz) - min(hz),
          max(r["head"].x for r in rows) - min(r["head"].x for r in rows)))

if os.environ.get("NO_RENDER"):
    sys.exit(0)
# ---- render ----
for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]:
    bpy.data.objects.remove(o)
world = sc.world or bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.36, 0.36, 0.37, 1)
for name, loc, e in (("key", (-2.5, -3.0, 2.8), 300), ("fill", (3.0, -2.5, 1.6), 130), ("top", (0, 0, 4.0), 70)):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size = e, 3.0
    ob = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
sc.render.engine = "BLENDER_EEVEE"
sc.eevee.taa_render_samples = 12
sc.view_settings.view_transform = "Standard"
cd = bpy.data.cameras.new("c")
cd.type = "ORTHO"
cd.ortho_scale = 2.0
cam = bpy.data.objects.new("c", cd)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 300, 560
frames = [f0 + int(round(i * n_clip / nfr)) for i in range(nfr)]
paths = []
for i, f in enumerate(frames):
    pose_at(f)
    if view == "side":
        cam.location = (6, 0, 0.95)
    elif view == "front":
        cam.location = (0, -6, 0.95)
    else:
        cam.location = (4.2, -4.2, 0.95)
    cam.rotation_euler = (Vector((0, 0, 0.95)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    p = os.path.join(os.path.dirname(OUT), "_ws_%d.png" % i)
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)
ims = []
for p in paths:
    im = bpy.data.images.load(p)
    w, h = im.size
    ims.append(np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4))
S = np.concatenate(ims, axis=1)
o = bpy.data.images.new("sheet", S.shape[1], S.shape[0])
o.pixels = S.ravel()
o.filepath_raw = OUT
o.file_format = "PNG"
o.save()
for p in paths:
    os.remove(p)
print("wrote", OUT)
