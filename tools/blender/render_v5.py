"""Contact sheets of the v5 clips with reference props (side or front view), root motion applied.

    blender -b <blend with the v5 actions> -P tools/blender/render_v5.py -- OUT_DIR clip[,clip...] [--frames=8] [--view=side|front|34]
"""
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
args = sys.argv[sys.argv.index("--") + 1:]
OUT = args[0]
CLIPS = args[1].split(",")
nfr = int(next((a.split("=")[1] for a in args if a.startswith("--frames=")), "8"))
view = next((a.split("=")[1] for a in args if a.startswith("--view=")), "side")
os.makedirs(OUT, exist_ok=True)
META = json.load(open(os.path.join(REPO, "art_source/characters/mani/anims_v5.json")))
sc = bpy.context.scene
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
rig.animation_data_create()
rig.data.pose_position = "POSE"
rig.rotation_mode = "XYZ"

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
sc.eevee.taa_render_samples = 8
sc.view_settings.view_transform = "Standard"
cd = bpy.data.cameras.new("c")
cd.type = "ORTHO"
cd.ortho_scale = 2.6
cam = bpy.data.objects.new("c", cd)
sc.collection.objects.link(cam)
sc.camera = cam
sc.render.resolution_x, sc.render.resolution_y = 320, 480

PROPS = []


def box(name, size, center, color=(0.5, 0.5, 0.55, 1)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob = bpy.context.active_object
    ob.name = name
    ob.scale = size
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    ob.data.materials.append(m)
    PROPS.append(ob)
    return ob


def cyl(name, r, d, center, rot, color):
    bpy.ops.mesh.primitive_torus_add(location=center, rotation=rot, major_radius=r, minor_radius=0.015)
    ob = bpy.context.active_object
    ob.name = name
    m = bpy.data.materials.new(name)
    m.diffuse_color = color
    ob.data.materials.append(m)
    PROPS.append(ob)


def clear_props():
    for p in PROPS:
        bpy.data.objects.remove(p)
    PROPS.clear()


# world frame: forward = -Y, character right = -X.  P(r,f,u)
def P(r, f, u):
    return (-r, -f, u)


def add_props(clip):
    gray, red, blue = (0.55, 0.55, 0.58, 1), (0.7, 0.25, 0.2, 1), (0.2, 0.35, 0.7, 1)
    box("floor", (4, 4, 0.01), (0, 0, -0.005), (0.25, 0.25, 0.27, 1))
    if clip in ("reach_low", "put_down"):
        box("table", (0.9, 0.6, 0.57), P(0, 0.62, 0.285), gray)       # top at 0.57 -> object sits on it
        box("obj", (0.28, 0.2, 0.12), P(0.0, 0.46, 0.63), red)
    elif clip == "door_open_push":
        box("door", (0.9, 0.04, 2.0), P(0.15, 0.50, 1.0), gray)
        box("handle", (0.05, 0.1, 0.03), P(0.55, 0.45, 1.0), red)
    elif clip in ("trunk_open", "trunk_close"):
        box("car", (1.8, 1.0, 0.95), P(0, 0.41 + 0.5 , 0.475), gray)
        box("lidedge", (1.2, 0.04, 0.04), P(0, 0.41, 1.0), red)
        box("lidtop", (1.2, 0.6, 0.03), P(0, 0.41 + 0.3, 0.995 + 0.0), blue)
    elif clip == "carry_duffel":
        box("duffel", (0.75, 0.30, 0.30), P(0, 0.31, 0.79), red)
    elif clip in ("car_enter_driver", "car_exit_driver"):
        box("carside", (0.04, 2.0, 0.9), P(0, 0.30, 0.7), gray)  # placeholder, replaced below
        PROPS[-1].location = (0, -0.30, 0.7)
        PROPS[-1].scale = (2.4, 0.04, 0.9)
        box("seat", (0.5, 0.5, 0.5), (0, -0.75, 0.25), blue)
        box("sill", (2.4, 0.1, 0.3), (0, -0.30, 0.15), gray)
    elif clip == "sit_drive":
        box("seat", (0.5, 0.5, 0.5), (0, 0, 0.25), blue)
        cyl("wheel", 0.19, 0.0, (0, -0.40, 0.90), (math.radians(90 - 25), 0, math.radians(90)), (0.1, 0.1, 0.1, 1))
        # wheel plane faces driver (driver faces -Y in the rig because sit_drive is root-frame)
    elif clip == "stairs_down":
        for i in range(-2, 8):
            top = -0.18 * i
            box("step%d" % i, (1.2, 0.28, 1.5), P(0, 0.28 * i, top - 0.75), gray)


UPPER = ["spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r",
         "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]


def fcurves(act):
    out = []
    for layer in act.layers:
        for strip in layer.strips:
            for cb in strip.channelbags:
                out += list(cb.fcurves)
    return out


def mix_pose(base, over, f):
    """walk (legs, pelvis, lower spine) + the upper-body bones of the carry clip: the game's filtered blend"""
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
    for act, only_upper in ((bpy.data.actions[base], False), (bpy.data.actions[over], True)):
        for fc in fcurves(act):
            if '"' not in fc.data_path:
                continue
            bn = fc.data_path.split('"')[1]
            isup = bn in UPPER or any(k in bn for k in ("index_", "middle_", "ring_", "pinky_", "thumb_"))
            if only_upper != isup and only_upper:
                continue
            if (not only_upper) and isup:
                continue
            pb = rig.pose.bones.get(bn)
            if pb is None:
                continue
            v = fc.evaluate(f if not only_upper else 0)
            if "rotation_quaternion" in fc.data_path:
                q = list(pb.rotation_quaternion)
                q[fc.array_index] = v
                pb.rotation_quaternion = q
            elif "location" in fc.data_path:
                l = list(pb.location)
                l[fc.array_index] = v
                pb.location = l


for clip in CLIPS:
    clear_props()
    add_props(clip)
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
    mix = clip.split("+") if "+" in clip else None
    if mix:
        rig.animation_data.action = None
        m = dict(frames=bpy.data.actions[mix[0]].frame_range[1] and int(bpy.data.actions[mix[0]].frame_range[1]), loop=True,
                 root=[[0, 0, 0, 0]] * 200)
        add_props("carry_duffel" if "duffel" in mix[1] else "none")
    else:
        act = bpy.data.actions[clip]
        rig.animation_data.action = act
        m = META[clip]
    n = m["frames"]
    frames = [int(round(i * n / nfr)) for i in range(nfr)]
    if m["loop"]:
        pass
    paths = []
    for i, f in enumerate(frames):
        f = min(f, n)
        if mix:
            mix_pose(mix[0], mix[1], f)
        else:
            sc.frame_set(f)
        root = m["root"][f]
        rig.location = (root[0], root[1], root[2])
        rig.rotation_euler = (0, 0, math.radians(root[3]))
        bpy.context.view_layer.update()
        c = Vector((root[0], root[1], 0.95 + root[2]))
        if view == "side":
            cam.location = (6 + root[0] * 0, c.y * 0, 0.95)
            cam.location = (6, c.y, c.z)
            tgt = Vector((0, c.y, c.z))
        elif view == "front":
            cam.location = (c.x, -6, 0.95)
            tgt = Vector((c.x, 0, 0.95))
        else:
            cam.location = (c.x + 4.2, c.y - 4.2, 0.95)
            tgt = Vector((c.x, c.y, 0.95))
        if clip in ("car_enter_driver", "car_exit_driver"):
            tgt = Vector((0.0, -0.35, 0.95))
            cam.location = (6, -0.35, 0.95) if view == "side" else cam.location
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        p = os.path.join(OUT, "_f%d.png" % i)
        sc.render.filepath = p
        bpy.ops.render.render(write_still=True)
        paths.append(p)
    ims = []
    for p in paths:
        im = bpy.data.images.load(p)
        w, h = im.size
        ims.append(np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4))
    S = np.concatenate(ims, axis=1)
    o = bpy.data.images.new("sheet_" + clip, S.shape[1], S.shape[0])
    o.pixels = S.ravel()
    outp = os.path.join(OUT, "%s_%s.png" % (clip.replace("+", "_"), view))
    o.filepath_raw = outp
    o.file_format = "PNG"
    o.save()
    for p in paths:
        os.remove(p)
    print("wrote", outp)
