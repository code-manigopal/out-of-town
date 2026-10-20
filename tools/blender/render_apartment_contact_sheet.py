"""
Render a labelled contact sheet of every asset in apartment_props.blend.

    blender -b art_source/environments/windsor/apartment_props.blend -P tools/blender/render_apartment_contact_sheet.py -- OUT.png [COLS]
"""
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "/tmp/contact_sheet.png"
COLS = int(argv[1]) if len(argv) > 1 else 6
TILE = 380
tmpdir = os.path.join(os.path.dirname(OUT), "tiles")
os.makedirs(tmpdir, exist_ok=True)

sc = bpy.context.scene
for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
    try:
        sc.render.engine = engine
        break
    except TypeError:
        continue
sc.render.resolution_x = sc.render.resolution_y = TILE
sc.render.film_transparent = False
sc.view_settings.view_transform = "Standard"
try:
    sc.eevee.taa_render_samples = 24
except Exception:
    pass

# world
world = bpy.data.worlds.new("W")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.62, 0.64, 0.68, 1)
bg.inputs["Strength"].default_value = 1.1
sc.world = world

# lights
sun = bpy.data.lights.new("Sun", "SUN")
sun.energy = 3.0
sun.angle = math.radians(8)
sun_ob = bpy.data.objects.new("Sun", sun)
sun_ob.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
sc.collection.objects.link(sun_ob)

# camera
cam = bpy.data.cameras.new("Cam")
cam.lens = 50
cam_ob = bpy.data.objects.new("Cam", cam)
sc.collection.objects.link(cam_ob)
sc.camera = cam_ob

# floor
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, -0.0005))
floor = bpy.context.active_object
fm = bpy.data.materials.new("floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.42, 0.42, 0.43, 1)
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.9
floor.data.materials.append(fm)

# label
txt_mat = bpy.data.materials.new("txt")
txt_mat.use_nodes = True
nt = txt_mat.node_tree
nt.nodes.clear()
em = nt.nodes.new("ShaderNodeEmission")
em.inputs["Color"].default_value = (1, 1, 1, 1)
em.inputs["Strength"].default_value = 1.0
out = nt.nodes.new("ShaderNodeOutputMaterial")
nt.links.new(em.outputs[0], out.inputs[0])
tcurve = bpy.data.curves.new("lbl", "FONT")
tcurve.size = 0.045
tcurve.align_x = "CENTER"
tcurve.materials.append(txt_mat)
tob = bpy.data.objects.new("lbl", tcurve)
sc.collection.objects.link(tob)
tob.parent = cam_ob
tob.location = (0, -0.44, -1.5)

assets = [o for o in bpy.data.collections["Assets"].objects]
tiles = []
for ob in assets:
    for o in assets:
        o.hide_render = o is not ob
    corners = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    mn = Vector((min(c.x for c in corners), min(c.y for c in corners), min(c.z for c in corners)))
    mx = Vector((max(c.x for c in corners), max(c.y for c in corners), max(c.z for c in corners)))
    ctr = (mn + mx) / 2
    rad = (mx - mn).length / 2
    d = Vector((-0.55, -1.0, 0.55)).normalized()
    dist = rad * 3.15
    cam_ob.location = ctr + d * dist
    cam_ob.rotation_euler = (ctr - cam_ob.location).to_track_quat("-Z", "Y").to_euler()
    # place sun and floor relative to the object
    floor.location = (ctr.x, ctr.y, mn.z - 0.0005)
    tcurve.body = "%s  %.2f x %.2f x %.2f m" % (ob.name, mx.x - mn.x, mx.y - mn.y, mx.z - mn.z)
    p = os.path.join(tmpdir, ob.name + ".png")
    sc.render.filepath = p
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(p)
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(TILE, TILE, 4)
    tiles.append(arr)
    bpy.data.images.remove(img)

rows = math.ceil(len(tiles) / COLS)
sheet = np.ones((rows * TILE, COLS * TILE, 4), dtype=np.float32) * 0.2
sheet[..., 3] = 1
for i, t in enumerate(tiles):
    r, c = divmod(i, COLS)
    y0 = (rows - 1 - r) * TILE   # image origin is bottom-left
    sheet[y0:y0 + TILE, c * TILE:(c + 1) * TILE] = t
img = bpy.data.images.new("sheet", COLS * TILE, rows * TILE)
img.pixels = sheet.ravel().tolist()
img.filepath_raw = OUT
img.file_format = "PNG"
img.save()
print("Wrote", OUT, "engine", sc.render.engine)
