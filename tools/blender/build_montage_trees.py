"""
Out of Town - Windsor opening montage: forest-edge trees (scripted trunks + alpha leaf / needle cards).

Run headless (re-runnable, deterministic):
    /opt/homebrew/bin/blender -b -P tools/blender/build_montage_trees.py

Blender 5's Sapling Tree Gen is an extension and is not bundled with the LTS build, so the trees are grown by a small
recursive limb generator (the same idea as make_tree in build_windsor_exterior.py, but taller, denser and forest-shaped):
  - deciduous: tapered trunk and limbs (bark texture), alpha leaf-cluster cards at the limb tips (our own CC0 cards from
    game/environments/windsor/exterior/textures/leaf_*.png, copied nowhere: they are embedded in the .glb);
  - conifer (spruce): trunk plus whorls of drooping needle-branch cards; the needle texture is drawn here with numpy.
  - shrubs: low leaf-card clumps for the understorey.

Outputs
    game/environments/windsor/montage/trees/<name>.glb      origin at the foot of the trunk, +Y up (glTF)
    game/environments/windsor/montage/trees/spruce_cards.png   (generated needle-branch card, ours, CC0)
    art_source/environments/windsor/montage/trees.blend
Material names ("MBark", "MBirchBark", "MLeaf*", "MSpruce") are swapped for engine materials by the .glb.import files
(game/environments/windsor/montage/trees/materials/*.tres); the flat colours here are only the fallback.
"""
import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "game", "environments", "windsor", "montage", "trees")
LEAF_DIR = os.path.join(ROOT, "game", "environments", "windsor", "exterior", "textures")
OUT_BLEND = os.path.join(ROOT, "art_source", "environments", "windsor", "montage", "trees.blend")
V = Vector
UPV = V((0.0, 0.0, 1.0))        # Blender up (we build in Blender coordinates here; glTF export converts to +Y up)
MATS = {}


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


def make_mat(name, hexc, img=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    r, g, bl = hexcol(hexc)
    b.inputs["Base Color"].default_value = (r, g, bl, 1.0)
    b.inputs["Roughness"].default_value = 0.9
    if img:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(img)
        tex.image.pack()
        m.node_tree.links.new(tex.outputs["Color"], b.inputs["Base Color"])
        m.node_tree.links.new(tex.outputs["Alpha"], b.inputs["Alpha"])
        try:
            m.surface_render_method = "DITHERED"
        except Exception:
            pass
    MATS[name] = m
    return m


def spruce_texture(path):
    """A drooping spruce branch card (RGBA, 256 x 512): central stem along +V, needles in two rows."""
    import numpy as np
    rng = np.random.RandomState(7)
    W, H, S = 256, 512, 2
    img = np.zeros((H * S, W * S, 4), dtype=np.float32)

    def dot(x, y, col, r=1.2):
        x0, x1 = int(max(0, x - r)), int(min(W * S, x + r + 1))
        y0, y1 = int(max(0, y - r)), int(min(H * S, y + r + 1))
        img[y0:y1, x0:x1, :3] = col
        img[y0:y1, x0:x1, 3] = 1.0
    cx = W * S * 0.5
    for yy in range(int(H * S * 0.02), int(H * S * 0.98)):       # stem
        wob = math.sin(yy * 0.01) * 3
        dot(cx + wob, yy, (0.16, 0.11, 0.07), 1.6)
    n = 150
    for i in range(n):
        t = i / (n - 1)
        y = H * S * (0.03 + 0.94 * t)
        L = (W * S * 0.47) * (math.sin(math.pi * (0.12 + 0.84 * t)) ** 0.7)       # branchlets taper to the tip
        for side in (-1, 1):
            ang = math.radians(rng.uniform(52, 72))
            ln = L * rng.uniform(0.75, 1.0)
            tone = rng.uniform(0.0, 1.0)
            base = np.array([0.07, 0.22, 0.11]) * (0.7 + 0.5 * tone)
            steps = int(ln)
            for s in range(steps):
                f = s / max(steps, 1)
                x = cx + side * math.sin(ang) * s
                yv = y + math.cos(ang) * s * 0.75 * (1 + 0.5 * f)
                dot(x, yv, base * (1.15 - 0.45 * f) + np.array([0.03, 0.04, 0.0]) * rng.uniform(0, 1), 1.4 - 0.5 * f)
    img = img.reshape(H, S, W, S, 4).mean(axis=(1, 3))
    a = img[..., 3:4]
    rgb = np.where(a > 0.02, img[..., :3] / np.maximum(a, 1e-4), 0.0)
    out = np.concatenate([np.clip(rgb, 0, 1), np.clip(a * 1.6, 0, 1)], axis=-1)
    im = bpy.data.images.new("spruce_cards", W, H, alpha=True)
    im.colorspace_settings.name = "sRGB"
    flat = np.flipud(out).astype(np.float32)            # Blender images are bottom-up
    im.pixels.foreach_set(flat.ravel())
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()
    return path


def build_materials():
    MATS["MBark"] = make_mat("MBark", "#4a3a2c")
    MATS["MBirchBark"] = make_mat("MBirchBark", "#d9d6cc")
    for n, f in (("MLeafOrange", "leaf_orange.png"), ("MLeafYellow", "leaf_yellow.png"), ("MLeafRust", "leaf_rust.png"),
                 ("MLeafGreen", "leaf_green.png")):
        make_mat(n, "#c07a2a", os.path.join(LEAF_DIR, f))
    sp = spruce_texture(os.path.join(OUT, "spruce_cards.png"))
    make_mat("MSpruce", "#1c3a22", sp)


# ----------------------------------------------------------------------------------------------------------
def _rand_unit(rng):
    while True:
        v = V((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
        if 0.01 < v.length_squared <= 1.0:
            return v.normalized()


def _rotate_about(d, axis, ang):
    return (Matrix.Rotation(ang, 3, axis) @ d).normalized()


def _tube(bm, uvl, pts, radii, nseg, tile=0.9):
    P = [V(p) for p in pts]
    if len(P) < 2:
        return
    t0 = (P[1] - P[0]).normalized()
    ref = V((0, 1, 0)) if abs(t0.y) < 0.9 else V((1, 0, 0))
    u = t0.cross(ref).normalized()
    ucnt = max(1, int(round(2 * math.pi * radii[0] / tile)))
    rings, dist, acc = [], [], 0.0
    for i, p in enumerate(P):
        if i:
            acc += (p - P[i - 1]).length
        dist.append(acc)
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        u = (u - t * u.dot(t))
        if u.length < 1e-5:
            u = t.cross(V((1, 0, 0)))
        u.normalize()
        v = t.cross(u)
        rings.append([bm.verts.new(p + (u * math.cos(a) + v * math.sin(a)) * radii[i])
                      for a in (math.tau * j / nseg for j in range(nseg))])
    for i in range(len(P) - 1):
        for j in range(nseg):
            j1 = (j + 1) % nseg
            f = bm.faces.new([rings[i][j], rings[i][j1], rings[i + 1][j1], rings[i + 1][j]])
            f.smooth = True
            uj, uj1 = ucnt * j / nseg, ucnt * (j + 1) / nseg
            v0, v1 = dist[i] / tile, dist[i + 1] / tile
            for l, uv in zip(f.loops, ((uj, v0), (uj1, v0), (uj1, v1), (uj, v1))):
                l[uvl].uv = uv


def _card(bm, uvl, c, u_, v_, w, h, normals=None, nrm_fn=None):
    corners = [c + u_ * (-0.5 * w) + v_ * (-0.5 * h), c + u_ * (0.5 * w) + v_ * (-0.5 * h),
               c + u_ * (0.5 * w) + v_ * (0.5 * h), c + u_ * (-0.5 * w) + v_ * (0.5 * h)]
    vs = [bm.verts.new(p) for p in corners]
    f = bm.faces.new(vs)
    f.smooth = True
    for l, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        l[uvl].uv = uv
    if normals is not None:
        for p in corners:
            normals.append(nrm_fn(p))


def _finish(name, trunk_bm, leaf_bm, trunk_mat, leaf_mat, normals=None):
    objs = []
    me = bpy.data.meshes.new(name + "_Trunk")
    trunk_bm.to_mesh(me)
    trunk_bm.free()
    me.materials.append(MATS[trunk_mat])
    ob = bpy.data.objects.new(name + "_Trunk", me)
    bpy.context.collection.objects.link(ob)
    objs.append(ob)
    lme = bpy.data.meshes.new(name + "_Leaves")
    leaf_bm.to_mesh(lme)
    leaf_bm.free()
    lme.materials.append(MATS[leaf_mat])
    if normals:
        try:
            lme.normals_split_custom_set_from_vertices(normals)
        except Exception as e:
            print("custom normals unavailable:", e)
    lob = bpy.data.objects.new(name + "_Leaves", lme)
    bpy.context.collection.objects.link(lob)
    objs.append(lob)
    return objs


def make_deciduous(name, seed, leaf_mat, height=15.0, angle=(35, 60), cards=9, card_size=(1.9, 2.8), density=1.0,
                   crown=5.2, clear=4.0, limbs_n=8, bark="MBark", trunk_r=0.32, lean=0.05):
    rng = random.Random(seed)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    tips = []

    def grow(p, d, length, r0, r1, depth, n_child, child_len, child_ang, up_bias):
        n = max(3, int(length / 0.9))
        pts, rad, cur, dd = [p], [r0], p, d
        for i in range(n):
            dd = (dd + _rand_unit(rng) * (0.10 + 0.05 * depth) + UPV * up_bias * 0.1).normalized()
            cur = cur + dd * (length / n)
            pts.append(cur)
            rad.append(r0 + (r1 - r0) * (i + 1) / n)
        if depth == 0:
            pts.insert(0, p - UPV * 0.2)
            rad.insert(0, r0)
        nseg = 9 if depth == 0 else (6 if rad[0] > 0.06 else 4)
        _tube(bm, uvl, pts, rad, nseg)
        if depth >= 2 or n_child <= 0:
            tips.append(cur)
            return
        for i in range(n_child):
            if depth == 0:
                t = clear / height + (0.92 - clear / height) * (i + rng.uniform(0.0, 0.6)) / n_child
            else:
                t = rng.uniform(0.35, 0.95)
            fi = t * (len(pts) - 1)
            idx = min(int(fi), len(pts) - 2)
            fr = fi - idx
            base = pts[idx].lerp(pts[idx + 1], fr)
            rb = rad[idx] * (1 - fr) + rad[idx + 1] * fr
            az = math.radians(137.5 * i + rng.uniform(-20, 20)) if depth == 0 else rng.uniform(0, math.tau)
            ang = math.radians(rng.uniform(*child_ang)) * ((1.0 - 0.4 * t) if depth == 0 else 1.0)
            axis = d.cross(V((1, 0, 0)))
            if axis.length < 0.2:
                axis = d.cross(V((0, 1, 0)))
            axis.normalize()
            cd = _rotate_about(_rotate_about(d, axis, ang), d, az)
            cd = (cd + UPV * 0.18).normalized()
            L = child_len * (1.0 - 0.4 * (t if depth == 0 else 0.0)) * rng.uniform(0.8, 1.15)
            grow(base, cd, L, max(rb * 0.55, 0.04), 0.014, depth + 1, 3 if depth == 0 else 2, L * 0.62, (28, 58), 0.6)
        tips.append(cur)

    up = V((rng.uniform(-lean, lean), rng.uniform(-lean, lean), 1.0)).normalized()
    grow(V((0, 0, 0)), up, height * 0.95, trunk_r, 0.04, 0, limbs_n, crown, angle, 0.5)
    lb = bmesh.new()
    luv = lb.loops.layers.uv.new("UVMap")
    centre = V((0, 0, height * 0.66))
    normals = []

    def nrm(p):
        n = (p - centre)
        return (n.normalized() * 0.8 + UPV * 0.35).normalized()
    for tp in tips:
        k = max(1, int(round(cards * density * rng.uniform(0.7, 1.3))))
        for _ in range(k):
            c = tp + _rand_unit(rng) * V((1.2, 1.2, 0.9)) * rng.uniform(0.2, 1.0)
            if c.z < clear * 0.9:
                continue
            s = rng.uniform(*card_size)
            a, q = _rand_unit(rng), _rand_unit(rng)
            n_ = a.cross(q)
            if n_.length < 0.1:
                continue
            n_.normalize()
            u_ = n_.cross(UPV)
            if u_.length < 0.1:
                u_ = n_.cross(V((1, 0, 0)))
            u_.normalize()
            v_ = n_.cross(u_)
            _card(lb, luv, c, u_, v_, s, s, normals, nrm)
    return _finish(name, bm, lb, bark, leaf_mat, normals)


def make_spruce(name, seed, height=16.0, whorls=17, spread=3.3, droop=0.55):
    rng = random.Random(seed)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    pts = [V((rng.uniform(-0.1, 0.1) * (z / height), 0, z)) for z in (-0.2, height * 0.3, height * 0.65, height)]
    _tube(bm, uvl, pts, [0.28, 0.2, 0.1, 0.012], 8)
    lb = bmesh.new()
    luv = lb.loops.layers.uv.new("UVMap")
    normals = []
    for w in range(whorls):
        t = (w + rng.uniform(-0.2, 0.2)) / (whorls - 1)
        z = 1.3 + (height - 1.5) * (1.0 - (1.0 - t) ** 1.0) * 0.98
        z = 1.6 + (height - 2.0) * t
        reach = spread * (1.0 - t * 0.93) + 0.3
        nb = 6 + int(5 * (1.0 - t))
        az0 = rng.uniform(0, math.tau)
        for i in range(nb):
            az = az0 + math.tau * i / nb + rng.uniform(-0.2, 0.2)
            dirh = V((math.cos(az), math.sin(az), 0))
            ln = reach * rng.uniform(0.85, 1.1)
            drop = droop * rng.uniform(0.7, 1.2) * ln * (0.55 + 0.45 * t)
            tilt = V((dirh.x * ln, dirh.y * ln, -drop)).normalized()
            c = V((0, 0, z)) + V((dirh.x * ln * 0.5, dirh.y * ln * 0.5, -drop * 0.5))
            # the card's V axis runs along the branch (stem along +V in the texture), U across it
            v_ = tilt
            u_ = v_.cross(UPV)
            if u_.length < 0.05:
                u_ = V((1, 0, 0))
            u_.normalize()
            # base of the card sits at the trunk: shift so the stem starts at the trunk
            c = V((0, 0, z)) + v_ * (ln * 0.5)
            wd = ln * 0.78
            _card(lb, luv, c - v_ * 0.0, u_, v_, wd, ln, normals,
                  lambda p, z=z: (p - V((0, 0, z - 0.8))).normalized() * 0.7 + UPV * 0.4)
            # a second, tilted card makes the branch read as a volume instead of a plane
            u2 = (u_ * 0.8 + UPV * 0.6).normalized()
            _card(lb, luv, c + UPV * 0.12, u2, v_, wd * 0.9, ln * 0.96, normals,
                  lambda p, z=z: (p - V((0, 0, z - 0.8))).normalized() * 0.7 + UPV * 0.4)
    return _finish(name, bm, lb, "MBark", "MSpruce", normals)


def make_shrub(name, seed, leaf_mat, r=1.6, h=1.8, n=44):
    rng = random.Random(seed)
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    for i in range(3):
        a = rng.uniform(0, math.tau)
        _tube(bm, uvl, [V((0, 0, -0.1)), V((math.cos(a) * 0.15, math.sin(a) * 0.15, h * 0.5)),
                        V((math.cos(a) * 0.4, math.sin(a) * 0.4, h * 0.95))], [0.05, 0.035, 0.015], 5, 0.5)
    lb = bmesh.new()
    luv = lb.loops.layers.uv.new("UVMap")
    normals = []
    centre = V((0, 0, h * 0.5))
    for i in range(n):
        a = rng.uniform(0, math.tau)
        rr = r * math.sqrt(rng.uniform(0.05, 1.0))
        c = V((math.cos(a) * rr, math.sin(a) * rr, h * rng.uniform(0.25, 1.0) * (1.0 - 0.45 * rr / r)))
        q, w_ = _rand_unit(rng), _rand_unit(rng)
        n_ = q.cross(w_)
        if n_.length < 0.1:
            continue
        n_.normalize()
        u_ = n_.cross(UPV)
        if u_.length < 0.1:
            u_ = V((1, 0, 0))
        u_.normalize()
        v_ = n_.cross(u_)
        s = rng.uniform(0.8, 1.2)
        _card(lb, luv, c, u_, v_, s, s, normals, lambda p: ((p - centre).normalized() * 0.8 + UPV * 0.3).normalized())
    return _finish(name, bm, lb, "MBark", leaf_mat, normals)


# ----------------------------------------------------------------------------------------------------------
def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False, export_animations=False,
                              export_materials="EXPORT")


def tris(objs):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    build_materials()
    jobs = [
        ("oak_a", make_deciduous("oak_a", 11, "MLeafYellow", height=15.5, crown=5.6, angle=(38, 62), cards=9)),
        ("oak_b", make_deciduous("oak_b", 12, "MLeafOrange", height=13.5, crown=6.2, angle=(46, 70), cards=9, limbs_n=7)),
        ("maple_a", make_deciduous("maple_a", 21, "MLeafRust", height=14.0, crown=4.6, angle=(30, 52), cards=10)),
        ("maple_b", make_deciduous("maple_b", 22, "MLeafOrange", height=16.5, crown=4.9, angle=(28, 48), cards=10, trunk_r=0.36)),
        ("beech_a", make_deciduous("beech_a", 31, "MLeafYellow", height=17.5, crown=4.4, angle=(24, 44), cards=10, clear=5.0)),
        ("birch_a", make_deciduous("birch_a", 41, "MLeafYellow", height=13.0, crown=3.0, angle=(24, 42), cards=7, clear=3.0,
                                   bark="MBirchBark", trunk_r=0.17, limbs_n=9, card_size=(1.4, 2.0), density=0.9)),
        ("spruce_a", make_spruce("spruce_a", 51, height=16.5, whorls=18, spread=3.4)),
        ("spruce_b", make_spruce("spruce_b", 52, height=12.5, whorls=15, spread=2.9, droop=0.65)),
        ("shrub_a", make_shrub("shrub_a", 61, "MLeafRust")),
        ("shrub_b", make_shrub("shrub_b", 62, "MLeafYellow", r=1.3, h=1.4, n=36)),
    ]
    rows, x = [], 0.0
    for name, objs in jobs:
        path = os.path.join(OUT, name + ".glb")
        export(objs, path)
        rows.append((name, tris(objs), os.path.getsize(path)))
        for o in objs:                              # lay the finished trees out side by side in the .blend
            o.location.x += x
        x += 14.0
    print("\nASSETS")
    for n, t, s in rows:
        print("%-12s %6d tris %8.1f KB" % (n, t, s / 1024))
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    if os.path.exists(OUT_BLEND + "1"):
        os.remove(OUT_BLEND + "1")


if __name__ == "__main__":
    main()
