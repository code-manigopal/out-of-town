"""Render Mani turnaround + face close-up for comparison with docs/art/sheets/mani/.

    blender -b art_source/characters/mani/mani.blend -P tools/blender/render_mani.py -- OUT_DIR [--fast]

Writes OUT_DIR/turnaround.png (front, side, back, three-quarter; orthographic, neutral light)
and OUT_DIR/face.png (front, three-quarter, profile close-ups).
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
FAST = "--fast" in args
SUFFIX = next((a.split("=")[1] for a in args if a.startswith("--suffix=")), "")
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene

# neutral studio: grey world + soft key/fill/rim
for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]:
    bpy.data.objects.remove(o)
world = bpy.data.worlds.new("w") if not sc.world else sc.world
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.36, 0.36, 0.37, 1)
bg.inputs["Strength"].default_value = 1.0


def light(name, kind, loc, energy, size=2.0):
    ld = bpy.data.lights.new(name, kind)
    ld.energy = energy
    if kind == "AREA":
        ld.size = size
    ob = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(ob)
    ob.location = loc
    d = Vector((0, 0, 1.1)) - Vector(loc)
    ob.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    return ob


# the character faces -Y in Blender
light("key", "AREA", (-2.2, -3.2, 2.8), 330, 2.5)
light("fill", "AREA", (3.0, -2.5, 1.6), 130, 3.0)
light("rim", "AREA", (0.5, 3.0, 2.5), 150, 2.5)
light("top", "AREA", (0, 0, 4.0), 70, 3.0)

rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
if rig:
    rig.data.pose_position = "REST"
sc.render.engine = "BLENDER_EEVEE"
try:
    sc.eevee.taa_render_samples = 16 if FAST else 64
except Exception:
    pass
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = False
sc.render.image_settings.file_format = "PNG"

cam_data = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
sc.camera = cam


def shoot(path, loc, target, ortho=None, lens=85):
    if ortho:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho
    else:
        cam_data.type = "PERSP"
        cam_data.lens = lens
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def stitch(out, files):
    ims = []
    for f in files:
        im = bpy.data.images.load(f)
        w, h = im.size
        ims.append((np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4), w, h))
    H = max(i[2] for i in ims)
    Wt = sum(i[1] for i in ims)
    S = np.ones((H, Wt, 4), dtype=np.float32)
    x = 0
    for p, w, h in ims:
        S[:h, x:x + w] = p
        x += w
    o = bpy.data.images.new("stitched", Wt, H)
    o.pixels = S.ravel()
    o.filepath_raw = out
    o.file_format = "PNG"
    o.save()


# ---- turnaround (A-pose rest) ----
sc.render.resolution_x, sc.render.resolution_y = (240, 420) if FAST else (480, 840)
cx, cz, D = 0.0, 0.88, 6.0
views = {
    "front": (0, -D), "side": (D, 0), "back": (0, D),
    "q34": (D * math.sin(math.radians(40)), -D * math.cos(math.radians(40))),
}
files = []
for name, (x, y) in views.items():
    p = os.path.join(OUT, "_t_%s.png" % name)
    shoot(p, (cx + x, y, cz), (cx, 0, cz), ortho=1.95)
    files.append(p)
stitch(os.path.join(OUT, "turnaround%s.png" % SUFFIX), files)

# ---- face (eye height ~1.62 m) ----
sc.render.resolution_x, sc.render.resolution_y = (300, 380) if FAST else (600, 760)
fz = 1.60
files = []
for name, ang in (("f", 0), ("q", 35), ("s", 90)):
    a = math.radians(ang)
    p = os.path.join(OUT, "_f_%s.png" % name)
    shoot(p, (math.sin(a) * 1.3, -math.cos(a) * 1.3, fz + 0.02), (0, 0, fz), lens=90)
    files.append(p)
stitch(os.path.join(OUT, "face%s.png" % SUFFIX), files)
print("rendered", OUT)
