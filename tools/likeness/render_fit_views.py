"""Render the head of a Mani .blend from the sheet's view angles (for MediaPipe on renders).

    blender -b scene.blend -P tools/likeness/render_fit_views.py -- OUT_DIR views.json [--res=W,H] [--all]

views.json: {"front": 0.0, "q34L": 26.4, "q34R": -28.2, "profile": 90.0}   (orbit angle in degrees about +Z; the
camera sits at (sin a, -cos a) * D, so a > 0 shows the subject's left side, face toward image-left).
Writes OUT_DIR/view_<name>.png and OUT_DIR/cams.json (camera pose, lens, sensor, resolution per view).
"""
import json
import math
import os
import sys

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
OUT, VIEWS = args[0], json.load(open(args[1]))
RES = next((a.split("=")[1] for a in args if a.startswith("--res=")), "800,1000")
W, H = [int(x) for x in RES.split(",")]
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene

KEEP = ("Mani_body", "Mani_eyes", "Mani_brows", "Mani_hair", "Mani_scalp", "Mani_glasses", "Mani_lenses", "Mani_hoops",
        "Mani_hoodie", "Mani_drawstrings", "Mani_stubble", "Mani_beard")
if "--all" not in args:
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = not o.name.startswith(KEEP) or o.name.startswith("Mani_hoodie_hood")
for o in [o for o in bpy.data.objects if o.type in ("LIGHT", "CAMERA")]:
    bpy.data.objects.remove(o)
world = sc.world or bpy.data.worlds.new("w")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.42, 0.42, 0.43, 1)
bg.inputs["Strength"].default_value = 1.0


def light(name, loc, energy, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy, ld.size = energy, size
    ob = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector((0, 0, 1.6)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


light("key", (-1.2, -2.2, 2.2), 180, 1.6)
light("fill", (1.6, -2.0, 1.4), 105, 2.0)
light("top", (0, -0.5, 3.0), 60, 2.0)

rig = next((o for o in bpy.data.objects if o.type == "ARMATURE"), None)
if rig:
    rig.data.pose_position = "REST"
sc.render.engine = "BLENDER_EEVEE"
try:
    sc.eevee.taa_render_samples = 32
except Exception:
    pass
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = "--alpha" in args
sc.render.image_settings.color_mode = "RGBA" if "--alpha" in args else "RGB"
sc.render.resolution_x, sc.render.resolution_y = W, H
sc.render.resolution_percentage = 100
sc.render.image_settings.file_format = "PNG"
cd = bpy.data.cameras.new("cam")
cam = bpy.data.objects.new("cam", cd)
sc.collection.objects.link(cam)
sc.camera = cam
cd.type, cd.lens, cd.sensor_width, cd.sensor_fit = "PERSP", 85.0, 36.0, "HORIZONTAL"
D, TARGET = 1.35, Vector((0.0, 0.0, 1.585))
cams = {}
for name, ang in VIEWS.items():
    a = math.radians(ang)
    loc = Vector((math.sin(a) * D, -math.cos(a) * D, TARGET.z + 0.02))
    cam.location = loc
    cam.rotation_euler = (TARGET - loc).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    sc.render.filepath = os.path.join(OUT, "view_%s.png" % name)
    bpy.ops.render.render(write_still=True)
    cams[name] = {"angle": ang, "loc": list(loc), "mat": [list(r) for r in cam.matrix_world], "lens": 85.0, "sensor": 36.0,
                  "res": [W, H]}
json.dump(cams, open(os.path.join(OUT, "cams.json"), "w"), indent=1)
print("rendered views", list(VIEWS))
