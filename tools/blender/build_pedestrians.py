"""Build six generic Windsor pedestrians (Out of Town, exterior background crowd).

Run headless (re-runnable; rebuilds every ped):
    blender -b -P tools/blender/build_pedestrians.py [-- --only 1,3 --no-export]

Same MPFB 2 game-engine rig and bone names as Mani (tools/blender/build_mani.py), so Mani's clips
(game/characters/mani/mani.glb) play on every pedestrian: no animations are exported here, the Godot
side (game/scripts/npc/oot_pedestrian.gd) takes the AnimationLibrary from mani.glb.

Look: MakeHuman CC0 pack bodies, skins (resized to 1K), hair, eyes, clothes (recoloured with generated
fabrics), plus a few modelled November accessories (long coat hem, quilted puffer, scarf, beanie, flat
cap, backpack, tote). Budget: <= 15k triangles, 1K textures, glb < 5 MB.

Output: game/characters/pedestrians/ped_<n>.glb, art_source/characters/pedestrians/ped_<n>.blend
"""
import bpy
import bmesh
import json
import math
import os
import sys
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_mani as B                      # shared helpers (materials, assets, textures)
from bl_ext.user_default.mpfb.services import HumanService, TargetService, AssetService

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(REPO, "game/characters/pedestrians")
SRC_DIR = os.path.join(REPO, "art_source/characters/pedestrians")
TEX_DIR = os.path.join(SRC_DIR, "tex")
DATA = B.DATA
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NO_EXPORT = "--no-export" in ARGS
ONLY = None
if "--only" in ARGS:
    ONLY = [int(x) for x in ARGS[ARGS.index("--only") + 1].split(",")]
TRI_BUDGET = 15000


def log(*a):
    print("[ped]", *a, flush=True)


# ---------------------------------------------------------------------------------------------
# the six pedestrians
# ---------------------------------------------------------------------------------------------
PEDS = [
    dict(n=1, label="office worker, long charcoal coat", height=1.80,
         macro=dict(gender=1.0, age=0.64, muscle=0.45, weight=0.56, proportions=0.5, height=0.55),
         race=dict(caucasian=1.0, asian=0.0, african=0.0), skin="middleage_caucasian_male", eyes="brown",
         top=dict(rgb=(0.42, 0.50, 0.60), kind="knit"), trousers=dict(rgb=(0.09, 0.09, 0.11), kind="twill"),
         outer=dict(rgb=(0.085, 0.085, 0.10), kind="twill", style="coat", drop=0.40, flare=0.07, inflate=0.016),
         scarf=(0.30, 0.07, 0.10), shoes=("shoes02", (0.05, 0.045, 0.045)),
         hair=("short02", (0.17, 0.145, 0.125)), brows=("eyebrow004", (0.12, 0.10, 0.09)), extras=[]),
    dict(n=2, label="older man, tan jacket and flat cap", height=1.72,
         macro=dict(gender=1.0, age=0.90, muscle=0.30, weight=0.52, proportions=0.45, height=0.45),
         race=dict(caucasian=1.0, asian=0.0, african=0.0), skin="old_caucasian_male", eyes="blue",
         top=dict(rgb=(0.30, 0.34, 0.31), kind="knit"), trousers=dict(rgb=(0.36, 0.31, 0.23), kind="twill"),
         outer=dict(rgb=(0.28, 0.24, 0.15), kind="twill", style="jacket", inflate=0.012),
         scarf=None, shoes=("shoes04", (0.16, 0.10, 0.06)),
         hair=("short03", (0.55, 0.55, 0.54)), brows=("eyebrow002", (0.55, 0.55, 0.55)), extras=["flatcap"]),
    dict(n=3, label="student, maroon hoodie and backpack", height=1.73,
         macro=dict(gender=0.9, age=0.45, muscle=0.40, weight=0.38, proportions=0.5, height=0.5),
         race=dict(caucasian=0.1, asian=0.9, african=0.0), skin="young_asian_male", eyes="brown",
         top=dict(rgb=(0.33, 0.07, 0.09), kind="knit", inflate=0.012),
         trousers=dict(rgb=(0.12, 0.16, 0.26), kind="denim"), outer=None,
         scarf=None, shoes=("shoes05", (0.78, 0.78, 0.76)),
         hair=("short04", (0.03, 0.025, 0.025)), brows=("eyebrow009", (0.03, 0.025, 0.025)),
         extras=["backpack"]),
    dict(n=4, label="woman in a green quilted puffer jacket", height=1.67,
         macro=dict(gender=0.03, age=0.50, muscle=0.35, weight=0.42, proportions=0.5, height=0.5),
         race=dict(caucasian=0.2, asian=0.0, african=0.8), skin="young_african_female", eyes="brown",
         top=dict(rgb=(0.80, 0.74, 0.62), kind="knit"), trousers=dict(rgb=(0.07, 0.08, 0.12), kind="denim"),
         outer=dict(rgb=(0.07, 0.24, 0.18), kind="puffer", style="puffer", drop=0.17, flare=0.0, inflate=0.032),
         scarf=(0.80, 0.76, 0.66), shoes=("shoes06", (0.04, 0.04, 0.045)),
         dec=dict(hair=0.42), hair=("braid01", (0.03, 0.025, 0.025)), brows=("eyebrow007", (0.03, 0.025, 0.025)), extras=[]),
    dict(n=5, label="young man in a grey hoodie and beanie", height=1.80,
         macro=dict(gender=1.0, age=0.47, muscle=0.58, weight=0.36, proportions=0.5, height=0.55),
         race=dict(caucasian=0.85, asian=0.0, african=0.15), skin="young_caucasian_male2", eyes="green",
         top=dict(rgb=(0.20, 0.21, 0.23), kind="knit", inflate=0.014),
         trousers=dict(rgb=(0.05, 0.05, 0.06), kind="knit"), outer=None,
         scarf=None, shoes=("shoes03", (0.82, 0.80, 0.74)),
         hair=None, brows=("eyebrow005", (0.16, 0.12, 0.09)), extras=["beanie", "hood"]),
    dict(n=6, label="middle-aged woman, camel coat, red scarf and tote", height=1.60,
         macro=dict(gender=0.03, age=0.70, muscle=0.30, weight=0.62, proportions=0.5, height=0.42),
         race=dict(caucasian=0.25, asian=0.75, african=0.0), skin="middleage_asian_female", eyes="brown",
         top=dict(rgb=(0.30, 0.10, 0.14), kind="knit"), trousers=dict(rgb=(0.06, 0.06, 0.07), kind="twill"),
         outer=dict(rgb=(0.42, 0.30, 0.18), kind="twill", style="coat", drop=0.31, flare=0.06, inflate=0.016),
         scarf=(0.58, 0.09, 0.11), shoes=("shoes06", (0.05, 0.04, 0.04)),
         dec=dict(hair=0.26), hair=("bob01", (0.22, 0.21, 0.21)), brows=("eyebrow003", (0.10, 0.09, 0.09)), extras=["tote"]),
]


# ---------------------------------------------------------------------------------------------
# generic helpers
# ---------------------------------------------------------------------------------------------
def smooth01(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def downscale(arr, size):
    h = arr.shape[0]
    f = max(h // size, 1)
    if f > 1:
        arr = arr[:h // f * f, :arr.shape[1] // f * f].reshape(h // f, f, arr.shape[1] // f, f, arr.shape[2]).mean((1, 3))
    return arr


def save(name, arr, fmt="PNG", quality=88):
    return B.save_raw(name, arr, directory=TEX_DIR, fmt=fmt, quality=quality)


def fabric(name, rgb, kind, size=512):
    """Generated fabric colour + normal maps (rgb is sRGB). kinds: denim, knit, twill, puffer."""
    h = w = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n_fine = B.value_noise(h, w, size // 2, 1) - 0.5
    n_mid = B.value_noise(h, w, 64, 2) - 0.5
    n_big = B.value_noise(h, w, 6, 3) - 0.5
    if kind == "denim":
        weave = 0.5 + 0.25 * np.sin(xx * 1.9) * np.sin(yy * 0.6) + 0.25 * np.sin(yy * 1.9 + xx * 0.2)
        height = weave * 0.6 + n_fine * 0.5
        lum = 1.0 + (weave - 0.5) * 0.30 + n_fine * 0.25 + n_mid * 0.18 + n_big * 0.18
        ns = 1.6
    elif kind == "knit":
        weave = 0.5 + 0.5 * np.sin(xx * 0.9) * np.sin(yy * 0.9 + np.sin(xx * 0.9) * 0.8)
        height = weave * 0.7 + n_fine * 0.4
        lum = 1.0 + (weave - 0.5) * 0.22 + n_fine * 0.22 + n_mid * 0.12 + n_big * 0.12
        ns = 1.6
    elif kind == "puffer":
        # four horizontal baffles per tile (v spans 0.5 m): pillowed, dark seam between them
        v = (yy / h * 4.0) % 1.0
        pillow = np.sin(np.pi * v) ** 0.6
        seam = smooth01_np(0.0, 0.10, v) * smooth01_np(0.0, 0.10, 1 - v)
        height = pillow * 6.0 + n_fine * 0.15
        lum = (0.55 + 0.45 * seam) * (0.85 + 0.25 * pillow) * (1.0 + n_fine * 0.12 + n_mid * 0.12)
        ns = 2.2
    else:  # twill / wool
        weave = 0.5 + 0.5 * np.sin((xx + yy) * 2.1)
        height = weave * 0.25 + n_fine * 0.6
        lum = 1.0 + (weave - 0.5) * 0.07 + n_fine * 0.20 + n_mid * 0.12 + n_big * 0.12
        ns = 1.2
    col = np.array(rgb)[None, None, :] * lum[..., None]
    nrm = B.height_to_normal(height, ns)
    return save(name + "_c", col, "JPEG"), save(name + "_n", nrm, "JPEG", 85)


def smooth01_np(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def mat(name, color_path, normal_path=None, rough=0.85, spec=0.2, nstr=0.6, **kw):
    return B.make_material(name, color_path, rough=rough, normal_path=normal_path, normal_strength=nstr, spec=spec, **kw)


def new_mesh_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return B.new_obj(name, me)


def ellipsoid(name, center, radii, zcut=None, seg=18, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((center[0] + v.co.x * radii[0], center[1] + v.co.y * radii[1], center[2] + v.co.z * radii[2]))
    if zcut is not None:
        # clamp the lower rings onto the cut circle (exact rim, no gap to the cuff)
        k = math.sqrt(max(0.0, 1 - ((zcut - center[2]) / radii[2]) ** 2))
        for v in bm.verts:
            if v.co.z < zcut:
                dx, dy = v.co.x - center[0], v.co.y - center[1]
                a = math.atan2(dy / radii[1], dx / radii[0])
                v.co = Vector((center[0] + radii[0] * k * math.cos(a), center[1] + radii[1] * k * math.sin(a), zcut))
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=0.0005)
    return new_mesh_obj(name, bm)


def box(name, center, size, bevel=0.012, segments=2):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((center[0] + v.co.x * size[0], center[1] + v.co.y * size[1], center[2] + v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=segments, profile=0.5, affect="EDGES")
    return new_mesh_obj(name, bm)


def box_uv(obj):
    """Simple box-projected UVs (fabric noise does not need to be continuous)."""
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    me.uv_layers.active = me.uv_layers[0]
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            a, b = [(1, 2), (0, 2), (0, 1)][ax]
            uv[li].uv = (p[a] * 2.5 % 1.0, p[b] * 2.5 % 1.0)


def bind(obj, rig, weights):
    """weights: callable(vertex.co) -> {bone: w} (or dict for rigid)."""
    for v in obj.data.vertices:
        w = weights(v.co) if callable(weights) else weights
        for bone, val in w.items():
            if val <= 0.001:
                continue
            vg = obj.vertex_groups.get(bone) or obj.vertex_groups.new(name=bone)
            vg.add([v.index], val, "REPLACE")
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = rig
    for p in obj.data.polygons:
        p.use_smooth = True


# ---------------------------------------------------------------------------------------------
# human
# ---------------------------------------------------------------------------------------------
def build_human(cfg):
    md = TargetService.get_default_macro_info_dict()
    md.update(cfg["macro"])
    md["race"] = dict(cfg["race"])
    hm = HumanService.create_human(mask_helpers=True, detailed_helpers=True, extra_vertex_groups=True,
                                   feet_on_ground=True, scale=0.1, macro_detail_dict=md)
    hm.name = "ped%d_body" % cfg["n"]
    hgt = B.measure_height(hm)
    s = cfg["height"] / hgt
    bpy.context.view_layer.objects.active = hm
    hm.select_set(True)
    hm.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    dg = bpy.context.evaluated_depsgraph_get()
    me = hm.evaluated_get(dg).to_mesh()
    low = min(v.co.z for v in me.vertices)
    hm.evaluated_get(dg).to_mesh_clear()
    hm.location.z -= low
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    log("height %.3f" % B.measure_height(hm))
    return hm


def piece_by_height(parts):
    """Split casualsuit parts into (top, trousers) by lowest z."""
    parts = sorted(parts, key=lambda o: min(v.co.z for v in o.data.vertices))
    return parts[-1], parts[0]


def join_objs(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name
    return objs[0]


def dress(cfg, hm):
    n = cfg["n"]
    P = "ped%d_" % n
    rig = HumanService.add_builtin_rig(hm, "game_engine", import_weights=True)
    rig.name = rig.data.name = "PedRig%d" % n
    o = {"hm": hm, "rig": rig}
    female = cfg["macro"]["gender"] < 0.5
    suit = "female_casualsuit01" if female else "male_casualsuit02"
    parts = B.split_loose(B.add_asset(hm, "%s/%s.mhclo" % (suit, suit), "clothes", "Clothes"))
    top, trs = piece_by_height(parts)
    for p in parts:
        if p not in (top, trs):
            bpy.data.objects.remove(p)
    top.name, trs.name = P + "top", P + "trousers"
    o["top"], o["trousers"] = top, trs
    if cfg["top"].get("inflate"):
        B.push_along_normals(top, cfg["top"]["inflate"])
    else:
        B.push_along_normals(top, 0.002)
    if cfg["outer"]:
        parts = B.split_loose(B.add_asset(hm, "male_casualsuit05/male_casualsuit05.mhclo", "clothes", "Clothes"))
        parts.sort(key=lambda q: -len(q.data.polygons))
        main = parts[0]
        collar = [q for q in parts[1:] if min(v.co.z for v in q.data.vertices) > 1.15 * cfg["height"] / 1.75 * 0.0 + 1.1
                  and len(q.data.polygons) < 300]
        for q in parts[1:]:
            if q not in collar:
                bpy.data.objects.remove(q)
        for q in collar[:1]:
            for q2 in collar[1:]:
                bpy.data.objects.remove(q2)
            break
        main = join_objs([main] + collar[:1], P + "outer") if collar else main
        main.name = P + "outer"
        B.push_along_normals(main, cfg["outer"]["inflate"])
        o["outer"] = main
    sh = cfg["shoes"][0]
    o["shoes"] = B.add_asset(hm, "%s/%s.mhclo" % (sh, sh), "clothes", "Clothes")
    o["shoes"].name = P + "shoes"
    o["eyes"] = B.add_asset(hm, "low-poly/low-poly.mhclo", "eyes", "Eyes")
    o["eyes"].name = P + "eyes"
    b = cfg["brows"][0]
    o["brows"] = B.add_asset(hm, "%s/%s.mhclo" % (b, b), "eyebrows", "Eyebrows")
    o["brows"].name = P + "brows"
    if cfg["hair"]:
        hr = cfg["hair"][0]
        o["hair"] = B.add_asset(hm, "%s/%s.mhclo" % (hr, hr), "hair", "Hair")
        o["hair"].name = P + "hair"
    return o


# ---------------------------------------------------------------------------------------------
# garment shaping: long coat hem / puffer hem (extrude the waist hem downwards, split front and back)
# ---------------------------------------------------------------------------------------------
def extend_hem(obj, rig, drop, flare, rings=4, slit=True):
    me = obj.data
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.edges.ensure_lookup_table()
    bnd = [e for e in bm.edges if e.is_boundary and all(abs(v.co.x) < 0.30 for v in e.verts)]
    zlow = min(v.co.z for e in bnd for v in e.verts)
    hem_edges = [e for e in bnd if all(v.co.z < zlow + 0.05 for v in e.verts)]
    hem_verts = {v for e in hem_edges for v in e.verts}
    cy = sum(v.co.y for v in hem_verts) / len(hem_verts)
    cur = hem_edges
    if slit:    # leave the front and back centre open so each leg moves its own side
        cur = [e for e in cur if not (e.verts[0].co.x * e.verts[1].co.x <= 0 and abs(e.verts[0].co.x - e.verts[1].co.x) < 0.15)]
    z0 = zlow
    dl = bm.verts.layers.deform.verify()
    gi = {name: (obj.vertex_groups.get(name) or obj.vertex_groups.new(name=name)).index
          for name in ("thigh_l", "thigh_r", "pelvis")}
    thigh_x = rig.data.bones["thigh_l"].head_local.x      # +x is the character's left
    for r in range(1, rings + 1):
        res = bmesh.ops.extrude_edge_only(bm, edges=cur)
        nv = [g for g in res["geom"] if isinstance(g, bmesh.types.BMVert)]
        nvs = set(nv)
        t = r / rings
        for v in nv:
            ang_f = 1.0 + flare * t
            v.co.x *= ang_f
            v.co.y = cy + (v.co.y - cy) * ang_f
            v.co.z = z0 - drop * t * (1.0 + 0.0)
            # hem rides with the legs the lower it goes
            k = 0.85 * t
            wl = smooth01(-0.05, 0.05, v.co.x * (1 if thigh_x > 0 else -1))
            old = dict(v[dl].items())
            tot = sum(old.values()) or 1.0
            v[dl].clear()
            for gidx, wv in old.items():
                v[dl][gidx] = wv / tot * (1 - k)
            v[dl][gi["thigh_l"]] = v[dl].get(gi["thigh_l"], 0.0) + k * wl
            v[dl][gi["thigh_r"]] = v[dl].get(gi["thigh_r"], 0.0) + k * (1 - wl)
        cur = [e for e in res["geom"] if isinstance(e, bmesh.types.BMEdge) and all(v in nvs for v in e.verts) and e.is_boundary]
    # UVs for the new faces (cylindrical)
    uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        if any(l[uvl].uv.length < 1e-6 for l in f.loops):
            for l in f.loops:
                p = l.vert.co
                l[uvl].uv = (math.atan2(p.x, p.y - cy) / (2 * math.pi) % 1.0, p.z * 2.0 % 1.0)
    bm.to_mesh(me)
    bm.free()
    me.update()


def uv_cylindrical(obj, v_scale=2.0, cy=0.0):
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        for li in poly.loop_indices:
            p = me.vertices[me.loops[li].vertex_index].co
            uv[li].uv = (math.atan2(p.x, p.y - cy) / (2 * math.pi) % 1.0, p.z * v_scale)


# ---------------------------------------------------------------------------------------------
# finalize: cull covered body, clean groups, normals
# ---------------------------------------------------------------------------------------------
def finalize(o, cfg):
    hm, rig = o["hm"], o["rig"]
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = hm
    hm.select_set(True)
    bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    bm = bmesh.new()
    bm.from_mesh(hm.data)
    dl = bm.verts.layers.deform.active
    names = {vg.index: vg.name for vg in hm.vertex_groups}
    kill = []
    for v in bm.verts:
        w = {names[i]: x for i, x in v[dl].items() if i in names}
        in_body = w.get("body", 0) > 0.5
        covered = any(nm.startswith("Delete.") and x > 0.5 for nm, x in w.items())
        if (not in_body) or covered or (v.co.z < 0.17 and abs(v.co.x) > 0.04):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(hm.data)
    bm.free()
    for m in list(hm.modifiers):
        if m.type == "MASK":
            hm.modifiers.remove(m)
    for key, ratio in (("hm", DEC["body"]), ("top", DEC["top_hidden"] if "outer" in o else DEC["top"]),
                       ("trousers", DEC["trousers"]), ("outer", DEC["outer"]), ("shoes", DEC["shoes"]), ("hair", DEC["hair"])):
        if key in o:
            decimate(o[key], cfg.get("dec", {}).get(key, ratio))
    bone_names = {b.name for b in rig.data.bones}
    for ob in [x for x in bpy.data.objects if x.type == "MESH"]:
        for vg in list(ob.vertex_groups):
            if vg.name not in bone_names:
                ob.vertex_groups.remove(vg)
        for poly in ob.data.polygons:
            poly.use_smooth = True
        if not any(m.type == "ARMATURE" for m in ob.modifiers):
            m = ob.modifiers.new("Armature", "ARMATURE")
            m.object = rig
        if ob.parent is None:
            ob.parent = rig


def decimate(obj, ratio):
    if ratio >= 0.99:
        return
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    for m in list(obj.modifiers):
        if m.type == "ARMATURE":
            obj.modifiers.remove(m)
    m = obj.modifiers.new("Dec", "DECIMATE")
    m.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=m.name)


DEC = dict(body=0.34, top=0.55, top_hidden=0.40, trousers=0.5, outer=0.72, shoes=0.42, hair=0.7)


def head_box(hm, rig):
    zc = rig.data.bones["head"].head_local.z
    vs = [v.co for v in hm.data.vertices if v.co.z > zc]
    xs = [v.x for v in vs]; ys = [v.y for v in vs]; zs = [v.z for v in vs]
    return dict(x0=min(xs), x1=max(xs), y0=min(ys), y1=max(ys), z1=max(zs), zc=zc)


def torso_ring(o, z):
    """(center y, half depth, half width) of the topmost garment around height z."""
    src = o.get("outer") or o["top"]
    pts = [v.co for v in src.data.vertices if abs(v.co.z - z) < 0.025 and abs(v.co.x) < 0.30]
    ys = [p.y for p in pts]; xs = [abs(p.x) for p in pts]
    return (min(ys) + max(ys)) / 2, (max(ys) - min(ys)) / 2, max(xs)


# ---------------------------------------------------------------------------------------------
# accessories
# ---------------------------------------------------------------------------------------------
def accessories(cfg, o):
    rig, hm = o["rig"], o["hm"]
    P = "ped%d_" % cfg["n"]
    H = cfg["height"]
    hb = head_box(hm, rig)
    made = []
    sh_z = rig.data.bones["clavicle_l"].head_local.z + 0.02          # about shoulder-top height
    neck = rig.data.bones["neck_01"].head_local

    def fab(name, rgb, kind="knit", **kw):
        c, nrm = fabric(P + name, rgb, kind)
        return mat(P + name, c, nrm, **kw)

    if cfg["scarf"]:
        cyy, hd, hw = torso_ring(o, neck.z - 0.03)
        pts = []
        rx, ry = hw * 0.55 + 0.045, hd * 0.9 + 0.05
        # two loops around the neck + a tail hanging at the front
        for k in range(2):
            for i in range(20):
                a = 2 * math.pi * i / 20
                pts.append((rx * math.sin(a) * (1 + 0.02 * k), neck.y + 0.0 + ry * 0.0 + math.cos(a) * ry * (1 + 0.02 * k), neck.z - 0.02 - 0.035 * k))
        me = B.tube(P + "scarf_loop", pts[:20], 0.034, closed=True, sides=7)
        me2 = B.tube(P + "scarf_loop2", pts[20:], 0.034, closed=True, sides=7)
        fy = neck.y - ry
        tail = [(0.05, fy - 0.01, neck.z - 0.04), (0.055, fy - 0.025, neck.z - 0.16), (0.055, fy - 0.02, neck.z - 0.27)]
        me3 = B.tube(P + "scarf_tail", tail, 0.032, sides=7)
        ob = B.join_meshes(P + "scarf", [me, me2, me3])
        box_uv(ob)
        bind(ob, rig, lambda co: {"neck_01": 0.5, "spine_03": 0.5} if co.z > neck.z - 0.07 else {"spine_03": 1.0})
        ob.data.materials.append(fab("scarf", cfg["scarf"], "knit", rough=0.95))
        made.append(ob)

    for ex in cfg["extras"]:
        if ex in ("beanie", "flatcap"):
            hw = (hb["x1"] - hb["x0"]) / 2
            cy = (hb["y0"] + hb["y1"]) / 2
            hd = (hb["y1"] - hb["y0"]) / 2
            if ex == "beanie":
                rz = 0.125
                cz = hb["z1"] + 0.014 - rz
                zc_cut = hb["z1"] - 0.062           # just above the brows
                k = math.sqrt(1 - ((zc_cut - cz) / rz) ** 2)
                rx, ry = (hw + 0.018) * k, (hd + 0.018) * k
                ob = ellipsoid(P + "beanie", (0, cy + 0.004, cz), (hw + 0.018, hd + 0.018, rz),
                               zcut=zc_cut, seg=20, rings=10)
                cuff = B.tube(P + "beanie_cuff", [(rx * math.sin(a), cy + 0.004 + ry * math.cos(a), zc_cut + 0.004)
                                                  for a in [2 * math.pi * i / 22 for i in range(22)]], 0.013, closed=True, sides=6)
                ob2 = new_obj_from_mesh(P + "beanie_cuff", cuff)
                ob = join_objs([ob, ob2], P + "beanie")
                rgb, kind = cfg.get("beanie_rgb", (0.10, 0.15, 0.24)), "knit"
            else:
                ob = ellipsoid(P + "cap", (0, cy + 0.004, hb["z1"] + 0.026 - 0.082), (hw + 0.02, hd + 0.026, 0.082),
                               zcut=hb["z1"] - 0.062, seg=20, rings=8)
                brim = box(P + "brim", (0, hb["y0"] - 0.030, hb["z1"] - 0.062), (hw * 1.5, 0.085, 0.009), bevel=0.003, segments=1)
                ob = join_objs([ob, brim], P + "cap")
                rgb, kind = (0.27, 0.23, 0.19), "twill"
            box_uv(ob)
            bind(ob, rig, {"head": 1.0})
            ob.data.materials.append(fab(ex, rgb, kind, rough=0.95))
            made.append(ob)
        elif ex == "hood":
            cyy, hd, hw = torso_ring(o, neck.z - 0.02)
            # bunched hood: a flattened sack resting behind the neck
            ob = ellipsoid(P + "hood", (0, neck.y + hd * 0.9 + 0.03, neck.z - 0.04), (hw * 0.55 + 0.03, 0.065, 0.075),
                           seg=14, rings=8)
            box_uv(ob)
            bind(ob, rig, {"spine_03": 0.6, "neck_01": 0.4})
            ob.data.materials.append(o["top"].data.materials[0])
            made.append(ob)
        elif ex == "backpack":
            zc = H * 0.70
            cyy, hd, hw = torso_ring(o, zc)
            back = cyy + hd
            ob = box(P + "backpack", (0, back + 0.085, zc - 0.02), (0.31, 0.15, 0.43), bevel=0.035, segments=3)
            pocket = box(P + "bp_pocket", (0, back + 0.185, zc - 0.10), (0.22, 0.05, 0.20), bevel=0.018, segments=2)
            top_h = box(P + "bp_handle", (0, back + 0.085, zc + 0.215), (0.07, 0.02, 0.025), bevel=0.008, segments=1)
            ob = join_objs([ob, pocket, top_h], P + "backpack")
            box_uv(ob)
            bind(ob, rig, {"spine_03": 1.0})
            ob.data.materials.append(fab("backpack", (0.10, 0.21, 0.24), "twill", rough=0.8))
            made.append(ob)
            straps = []
            for sgn in (-1, 1):
                x = sgn * (hw * 0.55 + 0.02)
                p = [(x, back + 0.02, zc + 0.15), (x, back + 0.012, sh_z - 0.03)]
                for a in range(0, 181, 20):
                    ar = math.radians(a)
                    p.append((x, cyy + (hd + 0.03) * math.cos(ar), sh_z - 0.005 + 0.045 * math.sin(ar) - (1 - math.cos(ar)) * 0.05))
                p += [(x, cyy - hd - 0.025, zc + 0.02), (x, cyy - hd * 0.4, zc - 0.15)]
                straps.append(B.tube(P + "strap", p, 0.017, sides=5))
            st = B.join_meshes(P + "bp_straps", straps)
            box_uv(st)
            bind(st, rig, {"spine_03": 1.0})
            st.data.materials.append(fab("bpstrap", (0.07, 0.07, 0.08), "twill", rough=0.9))
            made.append(st)
        elif ex == "tote":
            zc = H * 0.50
            cyy, hd, hw = torso_ring(o, H * 0.55)
            x = -(hw + 0.065)       # right hip
            bag = box(P + "tote", (x, cyy + 0.01, zc), (0.11, 0.36, 0.34), bevel=0.012, segments=2)
            shape = B.tube(P + "tote_handles",
                           [(x - 0.01, cyy - 0.09, zc + 0.16), (x + 0.01, cyy - 0.09, zc + 0.30), (-hw * 0.55, cyy - 0.02, sh_z + 0.03),
                            (x + 0.01, cyy + 0.11, zc + 0.30), (x - 0.01, cyy + 0.11, zc + 0.16)], 0.011, sides=4)
            hobj = new_obj_from_mesh(P + "tote_handles", shape)
            ob = join_objs([bag, hobj], P + "tote")
            box_uv(ob)
            bind(ob, rig, lambda co: {"pelvis": max(0.0, 1 - max(0.0, co.z - zc - 0.17) / 0.3), "spine_03": min(1.0, max(0.0, co.z - zc - 0.17) / 0.3)})
            ob.data.materials.append(fab("tote", (0.76, 0.70, 0.56), "twill", rough=0.95))
            made.append(ob)
    return made


def new_obj_from_mesh(name, me):
    me.name = name
    return B.new_obj(name, me)


# ---------------------------------------------------------------------------------------------
# materials
# ---------------------------------------------------------------------------------------------
def tint_pack_image(path, rgb, size, name, gain=(0.3, 2.4)):
    a = downscale(B.load_raw(path), size)
    lum = a[..., :3].mean(-1, keepdims=True)
    lum = lum / max(lum.mean(), 1e-3)
    return np.clip(lum, *gain) * np.array(rgb)[None, None, :], a[..., 3:4]


def find_png(folder, avoid=("normal", "bump", "ao", "spec")):
    fs = [f for f in sorted(os.listdir(folder)) if f.endswith(".png") and not any(k in f for k in avoid)]
    return os.path.join(folder, fs[0])


def materials(cfg, o):
    P = "ped%d_" % cfg["n"]
    hm = o["hm"]
    # skin: the pack's own diffuse for this age/ethnicity, 1K
    skd = os.path.join(DATA, "skins", cfg["skin"])
    sk = downscale(B.load_raw(find_png(skd)), 1024)[..., :3]
    hm.data.materials.clear()
    B.set_single_material(hm, mat(P + "skin", save(P + "skin_c", sk, "JPEG", 90), rough=0.72, spec=0.1))
    # clothes
    t = cfg["top"]
    c, n = fabric(P + "top", t["rgb"], t["kind"])
    B.set_single_material(o["top"], mat(P + "top", c, n, rough=0.95, nstr=0.9, spec=0.2))
    tr = cfg["trousers"]
    c, n = fabric(P + "trousers", tr["rgb"], tr["kind"])
    B.set_single_material(o["trousers"], mat(P + "trousers", c, n, rough=0.85, nstr=0.8))
    if cfg["outer"]:
        ou = cfg["outer"]
        c, n = fabric(P + "outer", ou["rgb"], ou["kind"])
        B.set_single_material(o["outer"], mat(P + "outer", c, n, rough=0.9 if ou["kind"] != "puffer" else 0.55,
                                              nstr=0.5 if ou["kind"] != "puffer" else 1.0, spec=0.25))
    # shoes: tint the pack diffuse
    sname, srgb = cfg["shoes"]
    sdir = os.path.join(DATA, "clothes", sname)
    rgb, _ = tint_pack_image(find_png(sdir), srgb, 512, P + "shoes")
    B.set_single_material(o["shoes"], mat(P + "shoes", save(P + "shoes_c", rgb, "JPEG"), rough=0.55, spec=0.4))
    # eyes
    e = downscale(B.load_raw(os.path.join(DATA, "eyes/materials/%s_eye.png" % cfg["eyes"])), 256)[..., :3]
    B.set_single_material(o["eyes"], mat(P + "eyes", save(P + "eyes_c", e, "JPEG", 90), rough=0.2, spec=0.5))
    # brows / hair
    for key, cfgkey, sub in (("brows", "brows", "eyebrows"), ("hair", "hair", "hair")):
        if key not in o:
            continue
        frag, rgb = cfg[cfgkey]
        a = downscale(B.load_raw(find_png(os.path.join(DATA, sub, frag))), 1024 if key == "hair" else 512)
        lum = a[..., :3].mean(-1, keepdims=True)
        lum = lum / max(lum.mean(), 1e-3)
        col = np.clip(lum, 0.35, 2.2) * np.array(rgb)[None, None, :]
        path = save(P + key + "_c", np.concatenate([np.clip(col, 0, 1), a[..., 3:4]], -1), "PNG")
        B.set_single_material(o[key], mat(P + key, path, rough=0.65, spec=0.12, alpha_clip=True))


# ---------------------------------------------------------------------------------------------
def tri_count():
    total, detail = 0, {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            t = sum(len(p.vertices) - 2 for p in ob.data.polygons)
            detail[ob.name] = t
            total += t
    return total, detail


def pack_images():
    for img in bpy.data.images:
        if img.filepath and not img.packed_file and img.source == "FILE":
            try:
                img.pack()
            except Exception as e:  # noqa
                log("pack failed", img.name, e)


def build_one(cfg):
    n = cfg["n"]
    log("=== ped_%d: %s" % (n, cfg["label"]))
    B.clear_scene()
    for img in list(bpy.data.images):
        bpy.data.images.remove(img)
    hm = build_human(cfg)
    o = dress(cfg, hm)
    rig = o["rig"]
    if cfg["outer"]:
        ou = cfg["outer"]
        if ou["style"] in ("coat", "puffer"):
            extend_hem(o["outer"], rig, ou["drop"], ou["flare"], rings=4 if ou["style"] == "coat" else 2)
        if ou["style"] == "puffer":
            uv_cylindrical(o["outer"], v_scale=2.0, cy=torso_ring({"top": o["outer"]}, cfg["height"] * 0.70)[0])
    if cfg["extras"] or cfg["scarf"]:
        pass
    materials(cfg, o)
    finalize(o, cfg)
    accessories(cfg, o)
    tris, detail = tri_count()
    log("TRIS", tris, detail)
    assert tris <= TRI_BUDGET, "over budget: %d" % tris
    return o, tris


def export(o, n):
    rig = o["rig"]
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(SRC_DIR, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.type in ("MESH", "ARMATURE"):
            ob.select_set(True)
    bpy.context.view_layer.objects.active = rig
    rig.name = "Armature"
    glb = os.path.join(OUT_DIR, "ped_%d.glb" % n)
    bpy.ops.export_scene.gltf(
        filepath=glb, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_animations=False, export_skins=True, export_image_format="AUTO", export_materials="EXPORT",
        export_cameras=False, export_lights=False)
    mb = os.path.getsize(glb) / 1e6
    log("exported", glb, "%.2f MB" % mb)
    assert mb < 5.0
    blend = os.path.join(SRC_DIR, "ped_%d.blend" % n)
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    for f in os.listdir(SRC_DIR):
        if f.endswith(".blend1"):
            os.remove(os.path.join(SRC_DIR, f))
    return mb


def main():
    os.makedirs(TEX_DIR, exist_ok=True)
    report = {}
    for cfg in PEDS:
        if ONLY and cfg["n"] not in ONLY:
            continue
        o, tris = build_one(cfg)
        mb = None
        if not NO_EXPORT:
            mb = export(o, cfg["n"])
        report[cfg["n"]] = dict(label=cfg["label"], tris=tris, mb=mb)
    log("REPORT", json.dumps(report))


if __name__ == "__main__":
    main()
