"""Close-up renders of Mani holding an apartment item (grip check) + finger/item penetration report.

    blender -b <mani blend> -P tools/blender/render_grip.py -- OUT_DIR [--items=sweets,diyas,radio] [--views=front,top,side]

For every item the clip `carry_<item>` (or `carry`) is posed at frame 0, the item glb is placed exactly as the game does
(game/scripts/player/player.gd CARRY_ITEMS: AABB-centred, offset from the right wrist in body space, yaw rot) and
OUT_DIR/grip_<item>.png (3 close-up views) is written. The report lists, per hand bone, the deepest penetration of its
capsule into the item's box (m); anything above 2 mm is a finger poking through.
"""
import json
import math
import os
import re
import sys

import bpy
import numpy as np
from mathutils import Vector, Matrix, Euler

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "tools/blender"))
args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
ITEMS = next((a.split("=")[1] for a in args if a.startswith("--items=")), "sweets,diyas,radio").split(",")
VIEWS = next((a.split("=")[1] for a in args if a.startswith("--views=")), "front,top,side").split(",")
os.makedirs(OUT, exist_ok=True)
MODELS = os.path.join(REPO, "game/environments/windsor/apartment/models")
FILES = {"sweets": "sweets_box.glb", "diyas": "diyas_packet.glb", "radio": "radio_gift.glb"}
# game/scripts/player/player.gd CARRY_ITEMS (read from the script so the harness always matches the game)
src = open(os.path.join(REPO, "game/scripts/player/player.gd")).read()
CFG = {}
for m in re.finditer(r'"(\w+)": \{"offset": Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\), "rot": (Vector3\(([-\d.]+), ([-\d.]+), ([-\d.]+)\)|Vector3\.ZERO)(?:, "clip": &?"(\w+)")?', src):
    rot = (0, 0, 0) if m.group(5) == "Vector3.ZERO" else (float(m.group(6)), float(m.group(7)), float(m.group(8)))
    CFG[m.group(1)] = dict(offset=(float(m.group(2)), float(m.group(3)), float(m.group(4))), rot=rot, clip=m.group(9) or "carry")
print("CFG", CFG)

sc = bpy.context.scene
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
rig.data.pose_position = "POSE"
rig.animation_data_create()
for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]:
    bpy.data.objects.remove(o)
world = sc.world or bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.5, 0.52, 1)


def light(loc, e):
    ld = bpy.data.lights.new("l", "AREA")
    ld.energy, ld.size = e, 1.5
    ob = bpy.data.objects.new("l", ld)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 1.0)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


light((-1.0, -1.8, 2.2), 150)
light((1.6, -1.2, 1.4), 90)
light((0, 1.5, 2.0), 50)
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 700, 560
sc.view_settings.view_transform = "Standard"
cd = bpy.data.cameras.new("c")
cam = bpy.data.objects.new("c", cd)
sc.collection.objects.link(cam)
sc.camera = cam
cd.lens = 70


def wp(name, tail=False):
    pb = rig.pose.bones[name]
    return rig.matrix_world @ (pb.tail if tail else pb.head)


def to_blender_from_body(v):
    """body space (x right, y up, z back) offset -> Blender world offset."""
    return Vector((-v[0], v[2], v[1]))


def import_item(name):
    for o in list(bpy.data.objects):
        if o.name.startswith("ITEM"):
            bpy.data.objects.remove(o)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, FILES[name]))
    new = [o for o in bpy.data.objects if o not in before]
    for o in new:
        o.name = "ITEM_" + o.name
    meshes = [o for o in new if o.type == "MESH"]
    pts = np.array([(o.matrix_world @ Vector(c))[:] for o in meshes for c in o.bound_box])
    return new, pts.min(0), pts.max(0)


def capsules():
    """(name, p0, p1, radius) of every hand / finger bone."""
    out = []
    for pb in rig.pose.bones:
        n = pb.name
        if n == "hand_r" or n == "hand_l":
            out.append((n, wp(n), wp(n, True), 0.034))
        elif re.match(r"(index|middle|ring|pinky|thumb)_0[123]_[lr]", n):
            out.append((n, wp(n), wp(n, True), 0.0105 if "thumb" in n else 0.0085))
    return out


def penetration(center, yaw_deg, half):
    """deepest penetration (m) per bone into the box with half extents `half` (Blender axes), centred at `center`."""
    R = Matrix.Rotation(math.radians(yaw_deg), 3, "Z")
    res = {}
    for n, p0, p1, r in capsules():
        if n.endswith("_l") or n == "hand_l":
            pass
        worst = -1e9
        for t in np.linspace(0, 1, 9):
            p = p0 + (p1 - p0) * t
            q = R.inverted() @ (p - center)
            d = Vector([abs(q[i]) - half[i] for i in range(3)])
            outside = Vector([max(x, 0) for x in d]).length
            inside = min(max(d.x, d.y, d.z), 0)
            sd = outside + inside                   # signed distance to the box surface
            worst = max(worst, r - sd)
        res[n] = worst
    return res


def shoot(path, target, loc):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


report = {}
for item in ITEMS:
    cfg = CFG.get(item, dict(offset=(-0.13, 0.03, -0.07), rot=(0, 0, 0), clip="carry"))
    clip = cfg["clip"] if cfg["clip"] in bpy.data.actions else "carry"
    rig.animation_data.action = bpy.data.actions[clip]
    sc.frame_set(0)
    bpy.context.view_layer.update()
    objs, mn, mx = import_item(item)
    ext = mx - mn
    centre_local = (mn + mx) / 2
    wrist = wp("hand_r")
    ctr = wrist + to_blender_from_body(cfg["offset"])
    yaw = cfg["rot"][1]
    # glTF Y-up import: item axes (xg, yg, zg) -> Blender (xg, -zg, yg); the game keeps them equal to body axes, which are
    # Blender (-x, z, y)  => extra 180 deg about Z. The item's own AABB centre is moved to `ctr`.
    R = Matrix.Rotation(math.radians(180 + yaw), 3, "Z")
    for o in objs:
        if o.parent is None:
            o.rotation_mode = "XYZ"
            o.matrix_world = Matrix.Translation(ctr - R @ Vector(centre_local)) @ R.to_4x4() @ o.matrix_world
    bpy.context.view_layer.update()
    pts = np.array([(o.matrix_world @ Vector(c))[:] for o in objs if o.type == "MESH" for c in o.bound_box])
    # box in the item's own (yawed) frame: extents from the unrotated AABB
    half = Vector((ext[0] / 2, ext[1] / 2, ext[2] / 2))
    pen = penetration(Vector(ctr), 180 + yaw, half)
    worst = sorted(pen.items(), key=lambda kv: -kv[1])[:5]
    report[item] = {k: round(v, 4) for k, v in worst}
    print("GRIP %s clip=%s item dims %s ctr %s  deepest penetrations(m): %s" % (item, clip, [round(x, 3) for x in ext], [round(c, 3) for c in ctr], report[item]))
    c = Vector(ctr)
    files = []
    for v in VIEWS:
        p = os.path.join(OUT, "_g_%s_%s.png" % (item, v))
        if v == "front":
            shoot(p, c, c + Vector((0.0, -0.55, 0.10)))
        elif v == "top":
            shoot(p, c, c + Vector((0.0, -0.12, 0.62)))
        else:
            shoot(p, c, c + Vector((-0.6, -0.15, 0.10)))
        files.append(p)
    ims = [bpy.data.images.load(f) for f in files]
    W, H = ims[0].size
    S = np.ones((H, W * len(ims), 4), np.float32)
    for i, im in enumerate(ims):
        S[:, i * W:(i + 1) * W] = np.array(im.pixels[:], np.float32).reshape(H, W, 4)
    o = bpy.data.images.new("grip_" + item, W * len(ims), H)
    o.pixels = S.ravel()
    o.filepath_raw = os.path.join(OUT, "grip_%s.png" % item)
    o.file_format = "PNG"
    o.save()
json.dump(report, open(os.path.join(OUT, "grip_report.json"), "w"), indent=1)
