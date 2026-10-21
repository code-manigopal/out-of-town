"""
Out of Town - road-works kit for the Windsor exterior: the closures that block every wrong turn off the intended drive
(barricade, cone, channelizer drum, "ROAD WORK" and "ROAD CLOSED" signs). Plain generic text, no agency logos.

Run headless (re-runnable, deterministic):
    /opt/homebrew/bin/blender -b -P tools/blender/build_roadworks.py

Outputs
    game/environments/windsor/exterior/roadworks/<asset>.glb
    art_source/environments/windsor/exterior/roadworks.blend

Conventions: metres, origin on the ground at the bottom centre, front (the face seen by approaching traffic) = +Z in Godot
coordinates (same helpers as build_windsor_exterior.py). Stripes are an embedded 45-degree orange/white texture.
The barricade's amber lamps are a separate mesh named *_Lamps with the LampAmber material (Godot flashes its emission).
"""
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import build_windsor_exterior as bw   # noqa: E402  (GB, G, make_mat, make_text, export)

ROOT = bw.ROOT
OUT = os.path.join(bw.OUT, "roadworks")
OUT_BLEND = os.path.join(ROOT, "art_source", "environments", "windsor", "exterior", "roadworks.blend")
GB = bw.GB
G = bw.G
V = Vector


def stripe_image(name="barricade_stripes", n=256):
    """45-degree orange / white stripes, tileable."""
    import numpy as np
    img = bpy.data.images.new(name, n, n, alpha=False)
    ys, xs = np.mgrid[0:n, 0:n]
    band = (((xs + ys) * 4 // n) % 2).astype(np.float32)          # 4 bands per tile diagonal
    orange = np.array([1.0, 0.33, 0.0])
    white = np.array([0.92, 0.92, 0.9])
    rgb = np.where(band[..., None] > 0.5, white, orange)
    # Blender wants linear floats; the colours above are already tuned for sRGB display, convert
    lin = np.where(rgb <= 0.04045, rgb / 12.92, ((rgb + 0.055) / 1.055) ** 2.4)
    px = np.ones((n, n, 4), np.float32)
    px[..., :3] = lin
    img.pixels = px.flatten().tolist()
    img.pack()
    return img


def textured_mat(name, img, rough=0.35, tile=0.4):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    t = nt.nodes.new("ShaderNodeTexImage")
    t.image = img
    t.interpolation = "Linear"
    nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = rough
    bw.MATS[name] = m
    bw.TILE[name] = tile
    return m


def frustum(gb, cx, y0, cz, r0, r1, h, mat, seg=20):
    m = Matrix.Translation(G(cx, y0 + h / 2, cz))
    res = bmesh.ops.create_cone(gb.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=h, matrix=m)
    i = gb.mi(mat)
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = i


def plate(gb, cx, cy, cz, w, h, t, mat, roll_deg=0.0):
    """A flat plate facing +Z (Godot), optionally rolled about its facing axis (a diamond sign)."""
    m = Matrix.Translation(G(cx, cy, cz)) @ Matrix.Rotation(math.radians(roll_deg), 4, "Y") @ Matrix.Diagonal((w, t, h, 1.0))
    res = bmesh.ops.create_cube(gb.bm, size=1.0, matrix=m)
    i = gb.mi(mat)
    for f in {f for v in res["verts"] for f in v.link_faces}:
        f.material_index = i


def build_barricade(col):
    """Type III style barricade, 2.4 m wide: three striped boards on two A-frame legs, amber lamps on top."""
    b = GB()
    W = 2.4
    for y0 in (0.42, 0.72, 1.02):
        b.box(-W / 2, y0, -0.03, W / 2, y0 + 0.24, 0.03, "BarricadeStripe")
    for sx in (-W / 2 + 0.12, W / 2 - 0.12):
        b.box(sx - 0.03, 0.0, -0.015, sx + 0.03, 1.38, 0.015, "RoadworkLeg")
        # splayed feet front and back
        b.rod((sx, 0.9, 0.0), (sx, 0.0, 0.62), 0.025, "RoadworkLeg", seg=6)
        b.rod((sx, 0.9, 0.0), (sx, 0.0, -0.62), 0.025, "RoadworkLeg", seg=6)
        b.box(sx - 0.05, 0.0, 0.52, sx + 0.05, 0.04, 0.7, "RoadworkLeg")
        b.box(sx - 0.05, 0.0, -0.7, sx + 0.05, 0.04, -0.52, "RoadworkLeg")
        b.box(sx - 0.07, 0.0, 0.5, sx + 0.07, 0.07, 0.62, "BinGrey")           # sand bag on the foot
    lamps = GB()
    for sx in (-W / 2 + 0.12, W / 2 - 0.12):
        lamps.cyl(sx, 1.38, 0.0, 0.07, 0.14, "LampAmber", seg=12)
        lamps.cyl(sx, 1.52, 0.0, 0.045, 0.02, "Black", seg=10)
    return [b.finish("Barricade", col), lamps.finish("Barricade_Lamps", col, smooth=True)]


def build_cone(col):
    b = GB()
    b.box(-0.22, 0.0, -0.22, 0.22, 0.035, 0.22, "Black")
    frustum(b, 0, 0.035, 0, 0.14, 0.095, 0.2, "ConeOrange")
    frustum(b, 0, 0.235, 0, 0.095, 0.075, 0.07, "ConeWhite")          # reflective collar
    frustum(b, 0, 0.305, 0, 0.075, 0.055, 0.13, "ConeOrange")
    frustum(b, 0, 0.435, 0, 0.055, 0.04, 0.06, "ConeWhite")
    frustum(b, 0, 0.495, 0, 0.04, 0.022, 0.1, "ConeOrange")
    return [b.finish("Cone", col, smooth=True)]


def build_drum(col):
    b = GB()
    b.cyl(0, 0.0, 0, 0.3, 0.05, "Black", seg=18)
    bands = ["ConeOrange", "ConeWhite", "ConeOrange", "ConeWhite", "ConeOrange"]
    y = 0.05
    for k, m in enumerate(bands):
        frustum(b, 0, y, 0, 0.23 - 0.004 * k, 0.23 - 0.004 * (k + 1), 0.16, m, seg=18)
        y += 0.16
    b.cyl(0, 0.88, 0, 0.25, 0.04, "Black", seg=18)
    return [b.finish("Drum", col, smooth=True)]


def stand(b, h=0.7):
    """Portable sign stand: two crossed feet with weights and a post."""
    b.box(-0.55, 0.0, -0.04, 0.55, 0.05, 0.04, "RoadworkLeg")
    b.box(-0.04, 0.0, -0.55, 0.04, 0.05, 0.55, "RoadworkLeg")
    b.box(-0.42, 0.05, -0.1, -0.3, 0.12, 0.1, "BinGrey")
    b.box(0.3, 0.05, -0.1, 0.42, 0.12, 0.1, "BinGrey")
    b.box(-0.03, 0.05, -0.03, 0.03, h, 0.03, "RoadworkLeg")


def build_sign_road_work(col):
    b = GB()
    stand(b, 0.95)
    plate(b, 0.0, 1.5, 0.03, 0.76, 0.76, 0.012, "SignOrange", 45.0)
    plate(b, 0.0, 1.5, 0.036, 0.69, 0.69, 0.004, "NumberDark", 45.0)
    plate(b, 0.0, 1.5, 0.04, 0.66, 0.66, 0.004, "SignOrange", 45.0)
    objs = [b.finish("SignRoadWork", col)]
    objs.append(bw.make_text("RW1", "ROAD", 0.17, (0, 1.62, 0.047), "+z", col, mat="NumberDark", extrude=0.002))
    objs.append(bw.make_text("RW2", "WORK", 0.17, (0, 1.42, 0.047), "+z", col, mat="NumberDark", extrude=0.002))
    return objs


def build_sign_road_closed(col):
    b = GB()
    stand(b, 0.95)
    b.box(-0.5, 0.85, 0.025, 0.5, 1.6, 0.04, "SignRed")
    b.box(-0.47, 0.88, 0.04, 0.47, 1.57, 0.046, "SignWhite")
    objs = [b.finish("SignRoadClosed", col)]
    objs.append(bw.make_text("RC1", "ROAD", 0.2, (0, 1.37, 0.052), "+z", col, mat="NumberDark", extrude=0.002))
    objs.append(bw.make_text("RC2", "CLOSED", 0.2, (0, 1.1, 0.052), "+z", col, mat="NumberDark", extrude=0.002))
    return objs


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    bw.build_materials()
    img = stripe_image()
    textured_mat("BarricadeStripe", img)
    bw.make_mat("RoadworkLeg", "#e6e6e0", 0.45)
    bw.make_mat("ConeOrange", "#ff5a00", 0.5)
    bw.make_mat("ConeWhite", "#f0f0ea", 0.35)
    bw.make_mat("SignOrange", "#ff6a00", 0.4)
    bw.make_mat("LampAmber", "#ffb000", 0.2, emit=("#ffb000", 0.0))
    sc = bpy.context.scene
    col = bpy.data.collections.new("Roadworks")
    sc.collection.children.link(col)
    jobs = [("barricade", build_barricade(col)), ("cone", build_cone(col)), ("drum", build_drum(col)),
            ("sign_road_work", build_sign_road_work(col)), ("sign_road_closed", build_sign_road_closed(col))]
    print("\nROADWORKS")
    x = 0.0
    for name, objs in jobs:
        path = os.path.join(OUT, name + ".glb")
        bw.export(objs, path)
        print("%-18s %5d tris %7.1f KB" % (name, bw.tris(objs), os.path.getsize(path) / 1024))
        for o in objs:
            o.location.x += x
        x += 3.5
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    if os.path.exists(OUT_BLEND + "1"):
        os.remove(OUT_BLEND + "1")


if __name__ == "__main__":
    main()
