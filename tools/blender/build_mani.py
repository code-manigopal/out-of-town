"""Build Mani (Out of Town, Part 1) as a game-ready rigged character.

Run headless:
    blender -b -P tools/blender/build_mani.py [-- --no-export]

Needs MPFB 2 (Blender extension) and the MakeHuman CC0 system assets pack installed
into MPFB's user data (see tools/blender/README-style notes at the bottom of this file).

What it does
  1. MPFB basemesh (male, 29, South-Indian tuned macro + face targets), scaled to 175 cm
  2. Painted skin texture (medium brown, moustache, goatee, stubble, tired eyes)
  3. MPFB game-engine rig, pack clothes (hoodie+jeans from casualsuit02, navy jacket from
     casualsuit05, shoes01) recoloured with generated fabrics, pack eyes/eyebrows/hair
     (hair gets extra curl volume), modelled glasses / hoops / watch / hood / collar
  4. Procedural idle / walk / jog (IK-driven feet, baked to FK, looping)
  5. Exports game/characters/mani/mani.glb and art_source/characters/mani/mani.blend
"""
import bpy
import bmesh
import math
import os
import sys
import random
import numpy as np
from mathutils import Vector, Matrix, Euler, Quaternion

from bl_ext.user_default.mpfb.services import (
    HumanService, TargetService, AssetService, LocationService, ObjectService)
from bl_ext.user_default.mpfb.entities.objectproperties import HumanObjectProperties

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_GLB = os.path.join(REPO, "game/characters/mani/mani.glb")
OUT_TEX = os.path.join(REPO, "game/characters/mani/textures")
OUT_BLEND = os.path.join(REPO, "art_source/characters/mani/mani.blend")
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
NO_EXPORT = "--no-export" in ARGS
DATA = LocationService.get_user_data()

HEIGHT_M = 1.75
FPS = 30
random.seed(7)
np.random.seed(7)

# ---------------------------------------------------------------------------------------------
# Look-dev knobs (tuned against docs/art/sheets/mani/*)
# ---------------------------------------------------------------------------------------------
MACRO = dict(gender=1.0, age=0.53, muscle=0.42, weight=0.46, proportions=0.5, height=0.5)
RACE = dict(asian=0.22, caucasian=0.43, african=0.35)
# detail targets: (target file stem, value)  -- face shaped toward the approved face sheet
FACE_TARGETS = [
    ("head-round", 0.30), ("head-fat-incr", 0.10), ("head-scale-vert-decr", 0.10),
    ("nose-width1-incr", 0.40), ("nose-width2-incr", 0.30), ("nose-width3-incr", 0.45),
    ("nose-flaring-incr", 0.30), ("nose-volume-incr", 0.15), ("nose-point-width-incr", 0.2),
    ("mouth-lowerlip-volume-incr", 0.35), ("mouth-upperlip-volume-incr", 0.30),
    ("mouth-scale-horiz-incr", 0.10), ("mouth-philtrum-volume-incr", 0.2),
    ("head-scale-horiz-incr", 0.15), ("chin-width-incr", 0.10),
    ("l-eye-bag-incr", 0.35), ("r-eye-bag-incr", 0.35),
    ("l-eye-scale-incr", 0.30), ("r-eye-scale-incr", 0.30),
    ("l-eye-height1-decr", 0.10), ("r-eye-height1-decr", 0.10),
    ("l-cheek-volume-incr", 0.25), ("r-cheek-volume-incr", 0.25),
    ("l-ear-wing-incr", 0.20), ("r-ear-wing-incr", 0.20),
    ("eyebrows-trans-down", 0.20),
]
SKIN_TARGET_RGB = np.array([0.37, 0.265, 0.195])      # sRGB mean of the painted skin (medium brown)
HAIR_RGB = np.array([0.025, 0.02, 0.02])


def log(*a):
    print("[mani]", *a, flush=True)


# ---------------------------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------------------------
def clear_scene():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.armatures,
                 bpy.data.actions, bpy.data.curves):
        for d in list(coll):
            coll.remove(d)


def asset_path(fragment, subdir):
    p = AssetService.find_asset_absolute_path(fragment, subdir)
    assert p, "asset not found: %s %s" % (subdir, fragment)
    return p


def load_raw(path, size=None):
    """Load an image as raw (non-colour-managed) float RGBA numpy array [h, w, 4]."""
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    w, h = img.size
    arr = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    bpy.data.images.remove(img)
    return arr


def save_raw(name, arr, directory=OUT_TEX, alpha=False, fmt="PNG", quality=90):
    """Save a raw float array as an 8-bit PNG/JPEG without colour conversion; returns path."""
    os.makedirs(directory, exist_ok=True)
    h, w = arr.shape[:2]
    out = np.ones((h, w, 4), dtype=np.float32)
    out[..., :arr.shape[2]] = np.clip(arr, 0, 1)
    img = bpy.data.images.new(name + "_tmp", w, h, alpha=True)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "CHANNEL_PACKED"
    img.pixels = out.ravel()
    path = os.path.join(directory, name + (".png" if fmt == "PNG" else ".jpg"))
    img.filepath_raw = path
    img.file_format = fmt
    if fmt == "JPEG":
        bpy.context.scene.render.image_settings.quality = quality
    img.save()
    bpy.data.images.remove(img)
    return path


def tex_node(nt, path, srgb=True, alpha=False):
    n = nt.nodes.new("ShaderNodeTexImage")
    img = bpy.data.images.load(path, check_existing=True)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    if alpha:
        img.alpha_mode = "STRAIGHT"
    n.image = img
    return n


def make_material(name, base_path=None, color=(0.5, 0.5, 0.5), rough=0.6, metal=0.0, normal_path=None,
                  normal_strength=1.0, alpha_clip=False, spec=0.4, sss=0.0, sss_color=None,
                  orm_path=None, alpha_const=None, double_sided=False, alpha_cutoff=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    for k in ("Specular IOR Level", "Specular"):
        if k in bsdf.inputs:
            bsdf.inputs[k].default_value = spec
    if base_path:
        t = tex_node(nt, base_path, True, alpha=alpha_clip)
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        if alpha_clip:
            # Alpha -> Math(GREATER_THAN cutoff) -> Alpha: the glTF exporter turns this into alphaMode MASK
            # (Godot: alpha scissor with this threshold).
            gt = nt.nodes.new("ShaderNodeMath")
            gt.operation = "GREATER_THAN"
            gt.inputs[1].default_value = alpha_cutoff
            nt.links.new(t.outputs["Alpha"], gt.inputs[0])
            nt.links.new(gt.outputs["Value"], bsdf.inputs["Alpha"])
    else:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if normal_path:
        t = tex_node(nt, normal_path, False)
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    if orm_path:
        t = tex_node(nt, orm_path, False)
        sp = nt.nodes.new("ShaderNodeSeparateColor")
        nt.links.new(t.outputs["Color"], sp.inputs["Color"])
        nt.links.new(sp.outputs["Green"], bsdf.inputs["Roughness"])
    if alpha_const is not None:
        bsdf.inputs["Alpha"].default_value = alpha_const
        mat.surface_render_method = "BLENDED"
    if double_sided:
        mat.use_backface_culling = False
    if sss > 0:
        for k in ("Subsurface Weight", "Subsurface"):
            if k in bsdf.inputs:
                bsdf.inputs[k].default_value = sss
        if "Subsurface Radius" in bsdf.inputs:
            bsdf.inputs["Subsurface Radius"].default_value = (0.9, 0.35, 0.2)
        if "Subsurface Scale" in bsdf.inputs:
            bsdf.inputs["Subsurface Scale"].default_value = 0.01
    if alpha_clip:
        mat.surface_render_method = "DITHERED"
        mat.use_backface_culling = False if double_sided else mat.use_backface_culling
    return mat


def set_single_material(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.material_index = 0


def srgb_to_lin(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def value_noise(h, w, cells, seed=0):
    rng = np.random.RandomState(seed)
    g = rng.rand(cells + 1, cells + 1).astype(np.float32)
    ys = np.linspace(0, cells, h, endpoint=False)
    xs = np.linspace(0, cells, w, endpoint=False)
    y0 = ys.astype(int); x0 = xs.astype(int)
    fy = (ys - y0)[:, None]; fx = (xs - x0)[None, :]
    fy = fy * fy * (3 - 2 * fy); fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]; b = g[y0][:, x0 + 1]; c = g[y0 + 1][:, x0]; d = g[y0 + 1][:, x0 + 1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def height_to_normal(hmap, strength=2.0):
    gy, gx = np.gradient(hmap)
    nx, ny, nz = -gx * strength, gy * strength, np.ones_like(hmap)
    ln = np.sqrt(nx * nx + ny * ny + nz * nz)
    return np.stack([nx / ln * 0.5 + 0.5, ny / ln * 0.5 + 0.5, nz / ln * 0.5 + 0.5], axis=-1)


def fabric_textures(name, rgb, kind, size=512):
    """Generated tileable-ish fabric colour + normal maps. rgb is sRGB."""
    h = w = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    n_fine = value_noise(h, w, size // 2, 1) - 0.5
    n_mid = value_noise(h, w, 64, 2) - 0.5
    n_big = value_noise(h, w, 6, 3) - 0.5
    if kind == "denim":
        weave = 0.5 + 0.25 * np.sin(xx * 1.9) * np.sin(yy * 0.6) + 0.25 * np.sin(yy * 1.9 + xx * 0.2)
        height = weave * 0.6 + n_fine * 0.5
        lum = 1.0 + (weave - 0.5) * 0.30 + n_fine * 0.25 + n_mid * 0.35 + n_big * 0.45
    elif kind == "knit":
        weave = 0.5 + 0.5 * np.sin(xx * 0.9) * np.sin(yy * 0.9 + np.sin(xx * 0.9) * 0.8)
        height = weave * 0.7 + n_fine * 0.4
        lum = 1.0 + (weave - 0.5) * 0.22 + n_fine * 0.22 + n_mid * 0.25 + n_big * 0.3
    else:  # twill (jacket)
        weave = 0.5 + 0.5 * np.sin((xx + yy) * 2.1)
        height = weave * 0.25 + n_fine * 0.6
        lum = 1.0 + (weave - 0.5) * 0.07 + n_fine * 0.22 + n_mid * 0.30 + n_big * 0.35
    col = np.array(rgb)[None, None, :] * lum[..., None]
    nrm = height_to_normal(height, 1.6 if kind != "twill" else 1.2)
    return save_raw(name + "_c", col), save_raw(name + "_n", nrm)


# ---------------------------------------------------------------------------------------------
# 1. human
# ---------------------------------------------------------------------------------------------
def measure_height(obj):
    dg = bpy.context.evaluated_depsgraph_get()
    me = obj.evaluated_get(dg).to_mesh()
    zs = [v.co.z for v in me.vertices]
    obj.evaluated_get(dg).to_mesh_clear()
    return max(zs) - min(zs)


def build_human():
    md = TargetService.get_default_macro_info_dict()
    md.update(MACRO)
    md["race"] = dict(RACE)
    hm = HumanService.create_human(mask_helpers=True, detailed_helpers=True, extra_vertex_groups=True,
                                   feet_on_ground=True, scale=0.1, macro_detail_dict=md)
    hm.name = "Mani"
    for stem, val in FACE_TARGETS:
        path = TargetService.target_full_path(stem)
        assert path, stem
        TargetService.load_target(hm, path, weight=val, name=stem)
    # exact stature: uniform scale to 175 cm, feet on the ground
    hgt = measure_height(hm)
    s = HEIGHT_M / hgt
    log("raw height %.4f -> scale %.4f" % (hgt, s))
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
    log("final height %.4f" % measure_height(hm))
    return hm


# ---------------------------------------------------------------------------------------------
# 2. skin (painted)
# ---------------------------------------------------------------------------------------------
def eval_coords(hm):
    """All basemesh vertex positions with shape keys mixed (helper mask modifier bypassed)."""
    masks = [m for m in hm.modifiers if m.type == "MASK"]
    for m in masks:
        m.show_viewport = False
    dg = bpy.context.evaluated_depsgraph_get()
    me = hm.evaluated_get(dg).to_mesh()
    co = np.array([v.co[:] for v in me.vertices])
    hm.evaluated_get(dg).to_mesh_clear()
    for m in masks:
        m.show_viewport = True
    return co


def landmarks(hm):
    co = eval_coords(hm)

    def grp(name):
        vg = hm.vertex_groups[name]
        return np.array([i for i, v in enumerate(hm.data.vertices) if any(g.group == vg.index for g in v.groups)])
    lips = co[grp("lips")]
    ears = co[grp("ears")]
    le = co[grp("helper-l-eye")].mean(0)
    L = {}
    L["lips_c"] = lips.mean(0)
    L["lips_zmin"], L["lips_zmax"] = lips[:, 2].min(), lips[:, 2].max()
    L["lips_hw"] = np.abs(lips[:, 0]).max()
    L["eye_l"] = le
    L["eye_r"] = co[grp("helper-r-eye")].mean(0)
    el = ears[ears[:, 0] > 0]
    er = ears[ears[:, 0] < 0]
    L["ear_l"], L["ear_r"] = el, er
    # chin: lowest front head vertex near midline
    cand = co[(np.abs(co[:, 0]) < 0.02) & (co[:, 1] < L["lips_c"][1] + 0.03) & (co[:, 2] > L["lips_zmin"] - 0.09)
              & (co[:, 2] < L["lips_zmin"])]
    L["chin_z"] = cand[:, 2].min()
    L["face_front_y"] = co[(np.abs(co[:, 0]) < 0.02) & (co[:, 2] > L["lips_zmax"]) & (co[:, 2] < L["eye_l"][2])][:, 1].min()
    L["co"] = co
    return L


def paint_skin(hm, L):
    """Medium brown skin from the pack textures + moustache / goatee / stubble painted via UV raster."""
    base = os.path.join(DATA, "skins")
    af = load_raw(os.path.join(base, "young_african_male/young_darkskinned_male_diffuse.png"))[..., :3]
    asn = load_raw(os.path.join(base, "young_asian_male/young_lightskinned_male_diffuse3.png"))[..., :3]
    mix = af * 0.55 + asn * 0.45
    lum0 = mix.mean(-1, keepdims=True)
    mix = mix * 0.68 + lum0 * 0.32
    # tint toward target mean colour while keeping the pack's detail
    cur = mix.reshape(-1, 3).mean(0)
    skin = mix * (SKIN_TARGET_RGB / cur)[None, None, :]
    skin = np.clip(skin, 0, 1)
    H, W = skin.shape[:2]
    # --- rasterise UV triangles of the head region, evaluate beard fields from 3D position
    me = hm.data
    uvl = me.uv_layers.active.data
    co = L["co"]
    mouth_z = 0.5 * (L["lips_zmin"] + L["lips_zmax"])
    zlo, zhi = L["lips_zmax"], L["lips_zmax"] + 0.021
    beard = np.zeros((H, W), dtype=np.float32)
    dark_eye = np.zeros((H, W), dtype=np.float32)
    rng = np.random.RandomState(11)
    grain = rng.rand(H, W).astype(np.float32)
    grain_s = value_noise(H, W, 380, 5)
    grain_m = value_noise(H, W, 70, 9)
    eye_z = L["eye_l"][2]
    ear_y = float(np.mean(np.concatenate([L["ear_l"], L["ear_r"]])[:, 1]))
    front = L["face_front_y"]

    def fields(P):
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ax = np.abs(x)
        in_face = (y < ear_y + 0.015)
        # moustache: band above upper lip, strong in the middle, thinning at the philtrum edges
        must_hw = L["lips_hw"] * 1.35
        xr = np.clip(ax / must_hw, 0, 1.2)
        ztop = zlo + 0.022 - 0.014 * xr ** 2          # thicker in the middle, curling down at the corners
        zbot = zlo - 0.003 - 0.006 * xr ** 2          # follows the lip edge
        must = smoothstep(zbot - 0.002, zbot + 0.004, z) * (1 - smoothstep(ztop - 0.006, ztop, z)) \
            * (1 - smoothstep(must_hw * 0.85, must_hw, ax))
        # goatee: chin patch under lower lip, joined to moustache by a thin band at the mouth corners
        goat = smoothstep(L["chin_z"] - 0.012, L["chin_z"] + 0.004, z) * (1 - smoothstep(L["lips_zmin"] - 0.002, L["lips_zmin"] + 0.004, z)) \
            * (1 - smoothstep(0.012, 0.027, ax)) * (0.35 + 0.65 * (1 - smoothstep(L["lips_zmin"] - 0.03, L["chin_z"] - 0.004, z) * 0 + smoothstep(L["chin_z"] - 0.01, L["lips_zmin"] - 0.012, z)))
        corner = (1 - smoothstep(0.004, 0.012, np.abs(z - mouth_z))) * smoothstep(L["lips_hw"] * 0.7, L["lips_hw"] * 1.1, ax) \
            * (1 - smoothstep(L["lips_hw"] * 1.35, L["lips_hw"] * 1.7, ax)) * 0.9
        # light stubble over jaw and lower cheeks
        stub_top = zlo + 0.028 - 0.5 * smoothstep(0.03, 0.075, ax) * 0.0
        stubble = smoothstep(L["chin_z"] - 0.05, L["chin_z"] - 0.005, z) * 0 + (1 - smoothstep(stub_top - 0.012, stub_top + 0.01, z)) \
            * smoothstep(L["chin_z"] - 0.03, L["chin_z"] - 0.002, z) * (1 - smoothstep(0.068, 0.092, ax)) * 0.7
        # sideburn: in front of the ear
        side = smoothstep(eye_z - 0.045, eye_z - 0.02, z) * 0 + (1 - smoothstep(eye_z - 0.0, eye_z + 0.02, z)) \
            * smoothstep(0.052, 0.062, ax) * (1 - smoothstep(0.075, 0.095, ax)) \
            * smoothstep(ear_y - 0.045, ear_y - 0.02, y) * (1 - smoothstep(ear_y + 0.006, ear_y + 0.02, y)) \
            * smoothstep(L["lips_zmax"] + 0.0, L["lips_zmax"] + 0.03, z) * 0.8
        # keep stubble off the lips themselves
        lip_mask = 1 - (smoothstep(L["lips_zmin"] - 0.001, L["lips_zmin"] + 0.003, z) * (1 - smoothstep(L["lips_zmax"] - 0.004, L["lips_zmax"] + 0.0005, z))) \
            * (1 - smoothstep(L["lips_hw"] * 0.85, L["lips_hw"] * 1.05, ax))
        front_only = 1 - smoothstep(ear_y + 0.005, ear_y + 0.03, y)
        stubble = stubble * lip_mask * front_only
        side = side * front_only
        must = must * front_only
        goat = goat * front_only
        corner = corner * front_only
        return in_face, must, goat + corner, stubble + side, lip_mask

    # eye shadow: soft darker patch below each eye
    def tired(P):
        d = 0
        for e in (L["eye_l"], L["eye_r"]):
            dx = (P[:, 0] - e[0]) / 0.020
            dz = (P[:, 2] - (e[2] - 0.011)) / 0.010
            d = np.maximum(d, np.exp(-(dx * dx + dz * dz)))
        return d

    nt = 0
    for poly in me.polygons:
        vs = list(poly.vertices)
        pz = co[vs, 2]
        if pz.min() < L["chin_z"] - 0.06 or pz.max() > eye_z + 0.06 or co[vs, 1].min() > 0.02:
            continue
        li = list(poly.loop_indices)
        for k in range(1, len(vs) - 1):
            ids = [0, k, k + 1]
            uv = np.array([[uvl[li[i]].uv[0] * (W - 1), uvl[li[i]].uv[1] * (H - 1)] for i in ids])
            P = co[[vs[i] for i in ids]]
            x0, x1 = int(np.floor(uv[:, 0].min())), int(np.ceil(uv[:, 0].max()))
            y0, y1 = int(np.floor(uv[:, 1].min())), int(np.ceil(uv[:, 1].max()))
            if x1 - x0 > 200 or y1 - y0 > 200:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            a, b, c = uv
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
            l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
            l3 = 1 - l1 - l2
            m = (l1 >= -0.02) & (l2 >= -0.02) & (l3 >= -0.02)
            if not m.any():
                continue
            pp = (l1[m][:, None] * P[0] + l2[m][:, None] * P[1] + l3[m][:, None] * P[2])
            inf, must, goat, stub, lipm = fields(pp)
            ty, tx = gy[m], gx[m]
            ok = (ty >= 0) & (ty < H) & (tx >= 0) & (tx < W)
            gr = grain[ty[ok], tx[ok]]
            gs = grain_s[ty[ok], tx[ok]]
            gm = grain_m[ty[ok], tx[ok]]
            solid = np.clip(must * (0.80 + 0.25 * gs) + goat[ok] * (0.78 + 0.25 * gs) * 1.0, 0, 1) if False else None
            mu = must[ok]; go = goat[ok]; st = stub[ok]
            dens = np.clip(mu * 0.92 + go * 0.85, 0, 1)
            dens = np.clip(dens * (0.62 + 0.75 * gm) * 1.1 - 0.33 * (1 - gs), 0, 1) * (0.75 + 0.5 * gr) ** 0.5
            stub_a = np.clip(st, 0, 1) * (gr > 0.55) * (0.55 + 0.4 * gs)
            hair_px = (dens > gr * 0.9 + 0.05).astype(np.float32) * 0.95 * np.clip(dens * 2.0, 0, 1) + dens * 0.18
            beard[ty[ok], tx[ok]] = np.maximum(beard[ty[ok], tx[ok]], np.maximum(hair_px, stub_a * 0.6))
            dark_eye[ty[ok], tx[ok]] = np.maximum(dark_eye[ty[ok], tx[ok]], tired(pp[ok]))
            nt += 1
    log("painted %d tris" % nt)
    # a little blur so stubble is not pixel-sharp
    try:
        from scipy.ndimage import gaussian_filter  # noqa
        beard = gaussian_filter(beard, 0.8)
    except Exception:
        k = beard.copy()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            k += np.roll(np.roll(beard, dy, 0), dx, 1) * 0.5
        beard = k / 3.0
    beard = np.clip(beard, 0, 1)[..., None]
    shade = (1 - 0.18 * dark_eye)[..., None]
    skin2 = skin * shade * (1 - 0.93 * beard) + (HAIR_RGB * 1.1)[None, None, :] * 0.93 * beard
    return save_raw("mani_skin_c", skin2)


# ---------------------------------------------------------------------------------------------
# assets
# ---------------------------------------------------------------------------------------------
def add_asset(hm, fragment, subdir, atype, rigging=True):
    p = asset_path(fragment, subdir)
    o = HumanService.add_mhclo_asset(p, hm, asset_type=atype, material_type="MAKESKIN",
                                     set_up_rigging=rigging, subdiv_levels=0)
    for m in list(o.modifiers):
        if m.type == "SUBSURF":
            o.modifiers.remove(m)
    return o


def split_loose(obj):
    """Separate loose parts into objects, returned sorted by face count (desc)."""
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.separate(type="LOOSE")
    bpy.ops.object.mode_set(mode="OBJECT")
    parts = [o for o in bpy.context.selected_objects]
    parts.sort(key=lambda o: -len(o.data.polygons))
    return parts


def part_info(o):
    zs = [v.co.z for v in o.data.vertices]
    return len(o.data.polygons), min(zs), max(zs)


def push_along_normals(obj, d):
    me = obj.data
    for v in me.vertices:
        v.co += v.normal * d


# ---------------------------------------------------------------------------------------------
# 3. rig + clothes + hair
# ---------------------------------------------------------------------------------------------
def rig_and_dress(hm):
    rig = HumanService.add_builtin_rig(hm, "game_engine", import_weights=True)
    rig.name = "ManiRig"
    rig.data.name = "ManiRig"
    objs = {"hm": hm, "rig": rig}

    # ---- hoodie + jeans (casualsuit02), jacket (casualsuit05), boots (shoes01)
    c2 = add_asset(hm, "male_casualsuit02/male_casualsuit02.mhclo", "clothes", "Clothes")
    parts = split_loose(c2)
    for p in parts:
        n, zmin, zmax = part_info(p)
        log("suit02 part", n, zmin, zmax)
        if zmin < 0.3:
            p.name = "Mani_jeans"; objs["jeans"] = p
        else:
            p.name = "Mani_hoodie"; objs["hoodie"] = p
    c5 = add_asset(hm, "male_casualsuit05/male_casualsuit05.mhclo", "clothes", "Clothes")
    parts = split_loose(c5)
    keep = []
    maxn = max(len(q.data.polygons) for q in parts)
    for p in parts:
        n, zmin, zmax = part_info(p)
        if n == maxn:
            p.name = "Mani_jacket"; objs["jacket"] = p
        else:
            bpy.data.objects.remove(p)      # trousers, inner shirt, blazer lapels: replaced by our own pieces
    objs["jacket_extra"] = keep      # decided in build_main after a look (inner shirt / lapel pieces)
    push_along_normals(objs["jacket"], 0.007)
    push_along_normals(objs["hoodie"], -0.001)
    sh = add_asset(hm, "shoes01/shoes01.mhclo", "clothes", "Clothes")
    sh.name = "Mani_boots"; objs["boots"] = sh

    # ---- eyes, eyebrows, hair
    objs["eyes"] = add_asset(hm, "low-poly/low-poly.mhclo", "eyes", "Eyes")
    objs["eyes"].name = "Mani_eyes"
    objs["brows"] = add_asset(hm, "eyebrow009/eyebrow009.mhclo", "eyebrows", "Eyebrows")
    objs["brows"].name = "Mani_brows"
    objs["hair"] = add_asset(hm, "short01/short01.mhclo", "hair", "Hair")
    objs["hair"].name = "Mani_hair"
    return objs


def apply_materials(objs):
    L = objs["L"]
    objs["hm"].data.materials.clear()
    set_single_material(objs["hm"], make_material("Mani_skin", base_path=objs["skin_path"], rough=0.78, spec=0.06, sss=0.0))
    c, n = fabric_textures("mani_denim", (0.115, 0.115, 0.125), "denim")
    set_single_material(objs["jeans"], make_material("Mani_jeans", c, rough=0.85, normal_path=n, normal_strength=0.8))
    c, n = fabric_textures("mani_hoodie", (0.19, 0.19, 0.20), "knit")
    set_single_material(objs["hoodie"], make_material("Mani_hoodie", c, rough=0.95, normal_path=n, normal_strength=0.9, spec=0.2))
    c, n = fabric_textures("mani_jacket", (0.065, 0.085, 0.17), "twill")
    jm = make_material("Mani_jacket", c, rough=0.85, normal_path=n, normal_strength=0.4, spec=0.2)
    set_single_material(objs["jacket"], jm)
    for p in objs.get("jacket_extra", []):
        set_single_material(p, jm)
    # boots: tint the pack's diffuse to dark leather brown
    d = load_raw(os.path.join(DATA, "clothes/shoes01/shoes01_diffuse.png"))[..., :3]
    lum = d.mean(-1, keepdims=True)
    boot = np.clip(lum / max(lum.mean(), 1e-3), 0, 2.2) * np.array([0.23, 0.12, 0.065])[None, None, :]
    bp = save_raw("mani_boots_c", boot)
    nrm = os.path.join(DATA, "clothes/shoes01/shoes01_normal.png")
    set_single_material(objs["boots"], make_material("Mani_boots", bp, rough=0.5, normal_path=nrm if os.path.exists(nrm) else None, normal_strength=0.6, spec=0.5))
    # eyes
    e = load_raw(os.path.join(DATA, "eyes/materials/brown_eye.png"))[..., :3]
    sat = e.max(-1, keepdims=True) - e.min(-1, keepdims=True)
    iris = np.clip((sat - 0.10) / 0.12, 0, 1)
    e = e * (1 - iris) + (e * np.array([0.42, 0.40, 0.40])) * iris
    lum = e.mean(-1, keepdims=True)
    e = e * (1 - 0.45 * (1 - iris)) + lum * 0.45 * (1 - iris)      # take the pink out of the sclera
    set_single_material(objs["eyes"], make_material("Mani_eyes", save_raw("mani_eyes_c", e), rough=0.2, spec=0.5))
    # brows / hair: dark colour keeping the pack's alpha
    for key, frag, sub, nm in (("brows", "eyebrow009", "eyebrows", "mani_brows"), ("hair", "short01", "hair", "mani_hair")):
        files = [f for f in os.listdir(os.path.join(DATA, sub, frag)) if f.endswith(".png") and "normal" not in f and "bump" not in f]
        a = load_raw(os.path.join(DATA, sub, frag, files[0]))
        if key == "hair":
            a = a[::2, ::2]
            hh, ww = a.shape[:2]
            r1 = np.abs(value_noise(hh, ww, 70, 21) - 0.5) * 2
            r2 = np.abs(value_noise(hh, ww, 170, 22) - 0.5) * 2
            clump = 1 - (r1 * 0.65 + r2 * 0.35)               # ridged noise -> curl clumps (1 = ridge)
            lum = (0.35 + 1.4 * clump ** 2.0)[..., None]
            save_raw("mani_hair_n", height_to_normal(clump, 5.0))
        else:
            lum = a[..., :3].mean(-1, keepdims=True)
            lum = lum / max(lum.mean(), 1e-3)
        rgb = np.clip(lum, 0.3, 2.5) * HAIR_RGB[None, None, :] * (1.0 if key == "hair" else 0.9)
        out = np.concatenate([rgb, a[..., 3:4]], axis=-1)
        path = save_raw(nm + "_c", out)
        set_single_material(objs[key], make_material("Mani_" + key, path, rough=0.7 if key == "hair" else 0.6,
                                                     alpha_clip=True, spec=0.12,
                                                     normal_path=os.path.join(OUT_TEX, "mani_hair_n.png") if key == "hair" else None,
                                                     normal_strength=1.0))


# ---------------------------------------------------------------------------------------------
# 4. modelled accessories (glasses, hoops, watch, collar, hood, zip, drawstrings)
# ---------------------------------------------------------------------------------------------
def bone_pt(rig, name, tail=False):
    b = rig.data.bones[name]
    return rig.matrix_world @ (b.tail_local if tail else b.head_local)


def new_obj(name, me):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def tube(name, pts, radius, closed=False, sides=5):
    """Poly-line swept with a small round profile (curve bevel -> mesh)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = max(1, (sides - 3) // 2)
    cu.resolution_u = 1
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1)
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name + "_c", cu)
    bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    return me


def join_meshes(name, meshes):
    bm = bmesh.new()
    for me in meshes:
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    out = bpy.data.meshes.new(name)
    bm.to_mesh(out)
    bm.free()
    return new_obj(name, out)


def bind_rigid(obj, rig, bone):
    vg = obj.vertex_groups.new(name=bone)
    vg.add([v.index for v in obj.data.vertices], 1.0, "REPLACE")
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    m = obj.modifiers.new("Armature", "ARMATURE")
    m.object = rig
    for poly in obj.data.polygons:
        poly.use_smooth = True


def rounded_rect(cx, cz, w, h, r, y, n=5):
    pts = []
    corners = [(cx + w / 2 - r, cz + h / 2 - r, 0), (cx - w / 2 + r, cz + h / 2 - r, 90),
               (cx - w / 2 + r, cz - h / 2 + r, 180), (cx + w / 2 - r, cz - h / 2 + r, 270)]
    for ccx, ccz, a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90.0 * i / n)
            pts.append((ccx + r * math.cos(a), y, ccz + r * math.sin(a)))
    return pts


def frustum(name, c, z0, z1, rx0, ry0, rx1, ry1, seg=24, gap_deg=0.0, thickness=0.007, front_dir=-1):
    """Elliptical band around the neck (open at the front by gap_deg)."""
    bm = bmesh.new()
    rings = []
    a_lo = math.radians(gap_deg / 2)
    a_hi = 2 * math.pi - a_lo
    n = seg
    for zi, (z, rx, ry) in enumerate(((z0, rx0, ry0), (z1, rx1, ry1))):
        ring = []
        for i in range(n + 1):
            a = a_lo + (a_hi - a_lo) * i / n
            ring.append(bm.verts.new((c[0] + rx * math.sin(a), c[1] + front_dir * ry * math.cos(a), z)))
        rings.append(ring)
    for i in range(n):
        bm.faces.new((rings[0][i], rings[0][i + 1], rings[1][i + 1], rings[1][i]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = new_obj(name, me)
    sol = ob.modifiers.new("s", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 1
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.modifier_apply(modifier="s")
    return ob


def build_accessories(objs, rig):
    L = objs["L"]
    co = L["co"]
    bm_mat_metal = make_material("Mani_metal", color=(0.035, 0.035, 0.04), rough=0.4, metal=0.7)
    black_plastic = make_material("Mani_black", color=(0.012, 0.012, 0.014), rough=0.45, spec=0.5)
    zip_mat = make_material("Mani_zip", color=(0.05, 0.05, 0.055), rough=0.5, metal=0.5)
    cord_mat = make_material("Mani_cord", color=(0.30, 0.30, 0.31), rough=0.9)
    created = []

    ez = float(L["eye_l"][2])
    ex = float(L["eye_l"][0])
    # ---- glasses -------------------------------------------------------------------------
    nose = co[(np.abs(co[:, 0]) < 0.006) & (np.abs(co[:, 2] - ez) < 0.006)]
    bridge_y = float(nose[:, 1].min())
    gy = bridge_y - 0.010
    lw, lh, lr = 0.053, 0.040, 0.010
    cz = ez + 0.002
    cxs = ex * 1.02
    meshes = []
    for sgn in (1, -1):
        meshes.append(tube("rim", [(sgn * p[0], p[1], p[2]) for p in rounded_rect(cxs, cz, lw, lh, lr, gy)], 0.00075, closed=True))
    ztop = cz + lh / 2
    xo = cxs + lw / 2
    meshes.append(tube("topbar", [(-xo, gy - 0.001, ztop - 0.002), (-cxs * 0.4, gy - 0.003, ztop - 0.002),
                                   (cxs * 0.4, gy - 0.003, ztop - 0.002), (xo, gy - 0.001, ztop - 0.002)], 0.0007))
    meshes.append(tube("bridge", [(-(cxs - lw / 2 + 0.001), gy, cz + 0.004), (-0.004, gy - 0.004, cz + 0.008),
                                   (0.004, gy - 0.004, cz + 0.008), ((cxs - lw / 2 + 0.001), gy, cz + 0.004)], 0.0007))
    ears_l, ears_r = L["ear_l"], L["ear_r"]
    for sgn, ear in ((1, ears_l), (-1, ears_r)):
        top = ear[np.argmax(ear[:, 2])]
        hinge = (sgn * xo, gy, ztop - 0.004)
        e1 = (sgn * (abs(top[0]) - 0.002), top[1] - 0.012, min(top[2] - 0.006, ztop - 0.006))
        e2 = (sgn * (abs(top[0]) - 0.003), top[1] + 0.024, e1[2] - 0.004)
        e3 = (sgn * (abs(top[0]) - 0.006), top[1] + 0.034, e1[2] - 0.026)
        meshes.append(tube("temple", [hinge, e1, e2, e3], 0.0008))
        # nose pad
        meshes.append(tube("pad", [(sgn * 0.0075, gy + 0.001, cz + 0.001), (sgn * 0.0048, gy + 0.008, cz - 0.003)], 0.0009))
    g = join_meshes("Mani_glasses", meshes)
    g.data.materials.append(bm_mat_metal)
    bind_rigid(g, rig, "head")
    created.append(g)

    # ---- hoop earrings -------------------------------------------------------------------
    meshes = []
    for sgn, ear in ((1, ears_l), (-1, ears_r)):
        low = ear[np.argmin(ear[:, 2])]
        c = Vector((low[0] + sgn * 0.0015, low[1], low[2] + 0.0012))
        r = 0.0058
        pts = []
        for i in range(14):
            a = 2 * math.pi * i / 14
            # hoop plane contains the x axis tilted toward y so it reads from the front and the side
            pts.append((c.x + sgn * r * 0.55 * math.sin(a) , c.y + r * 0.8 * math.sin(a) * 0.6 * 0 + 0.0 + r * 0.45 * math.sin(a),
                        c.z - r * math.cos(a) + 0.0))
        meshes.append(tube("hoop", pts, 0.00085, closed=True))
    h = join_meshes("Mani_hoops", meshes)
    h.data.materials.append(black_plastic)
    bind_rigid(h, rig, "head")
    created.append(h)

    # ---- digital watch (left wrist) ------------------------------------------------------
    wh = bone_pt(rig, "lowerarm_l"); wt = bone_pt(rig, "lowerarm_l", True)
    a = (wt - wh).normalized()
    c = wh.lerp(wt, 0.90)
    n = Vector((1, -0.15, 0.25)); n = (n - a * n.dot(a)).normalized()       # dorsal side of the wrist
    v = a.cross(n).normalized()
    rx, ry = 0.0295, 0.0215
    bm = bmesh.new()
    segs = 24
    top_ring, bot_ring = [], []
    for i in range(segs):
        t = 2 * math.pi * i / segs
        p = c + n * (ry * math.cos(t)) + v * (rx * math.sin(t))
        top_ring.append(bm.verts.new(p + a * 0.010)); bot_ring.append(bm.verts.new(p - a * 0.010))
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new((top_ring[i], top_ring[j], bot_ring[j], bot_ring[i]))
    me = bpy.data.meshes.new("strap"); bm.to_mesh(me); bm.free()
    strap = new_obj("Mani_watch_strap", me)
    sol = strap.modifiers.new("s", "SOLIDIFY"); sol.thickness = 0.003; sol.offset = 1
    bpy.context.view_layer.objects.active = strap; strap.select_set(True)
    bpy.ops.object.modifier_apply(modifier="s")
    strap.data.materials.append(black_plastic)
    bind_rigid(strap, rig, "lowerarm_l")
    created.append(strap)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for vtx in bm.verts:
        vtx.co = Vector((vtx.co.x * 0.040, vtx.co.y * 0.034, vtx.co.z * 0.011))   # x: across wrist, y: along arm, z: out of wrist
    rot = Matrix((v, a, n)).transposed()      # columns: x->v, y->a, z->n
    for vtx in bm.verts:
        vtx.co = c + n * (ry + 0.0065) + rot @ vtx.co
    bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.0022, segments=2, affect="EDGES")
    me = bpy.data.meshes.new("case"); bm.to_mesh(me); bm.free()
    case = new_obj("Mani_watch_case", me)
    case.data.materials.append(black_plastic)
    # lit grey display
    disp = tube("disp", [tuple(c + n * (ry + 0.0125) + v * (-0.011) + a * 0.001), tuple(c + n * (ry + 0.0125) + v * (0.011) + a * 0.001)], 0.0085, sides=4)
    d = new_obj("Mani_watch_display", disp)
    d.data.materials.append(make_material("Mani_display", color=(0.22, 0.24, 0.2), rough=0.2))
    d.scale = (1, 1, 1)
    bind_rigid(case, rig, "lowerarm_l"); bind_rigid(d, rig, "lowerarm_l")
    created += [case, d]

    objs["glasses_params"] = dict(gy=gy, cz=cz, cxs=cxs, lw=lw, lh=lh, lr=lr)
    if "jacket" not in objs:
        objs["extras"] = created
        return created
    # ---- jacket collar, hood, zip tapes, hoodie drawstrings -----------------------------
    jk = objs["jacket"]
    jv = np.array([(jk.matrix_world @ v_.co)[:] for v_ in jk.data.vertices])
    zmax = jv[:, 2].max()
    nk = bone_pt(rig, "neck_01")
    cx, cy = float(nk.x), float(nk.y)
    zmax = float(nk.z) - 0.045               # where the jacket's neckline sits
    ring = jv[(np.abs(jv[:, 2] - zmax) < 0.03) & (np.abs(jv[:, 0]) < 0.14)]
    rx_, ry_ = 0.072, 0.074
    log("jacket neckline", cx, cy, rx_, ry_, zmax)
    collar = frustum("Mani_collar", (cx, cy, 0), zmax - 0.012, zmax + 0.050, rx_ + 0.003, ry_ + 0.003,
                     rx_ * 0.93, ry_ * 0.93, seg=22, gap_deg=50, thickness=0.010)
    collar.data.materials.append(objs["jacket"].data.materials[0])
    bind_rigid(collar, rig, "spine_03")
    created.append(collar)
    # hood bunched behind the neck: back arc of a flattened torus
    bm = bmesh.new()
    major, minor = 0.074, 0.040
    arc0, arc1 = math.radians(55), math.radians(305)
    na, nm = 14, 8
    grid = []
    for i in range(na + 1):
        th = arc0 + (arc1 - arc0) * i / na
        taper = 0.55 + 0.45 * math.sin(math.pi * i / na)
        row = []
        for j in range(nm):
            ph = 2 * math.pi * j / nm
            rr = major + minor * taper * math.cos(ph)
            row.append(bm.verts.new((cx + rr * 1.05 * math.sin(th), cy - rr * 0.95 * math.cos(th) + 0.012,
                                     zmax + 0.012 + minor * 0.8 * taper * math.sin(ph))))
        grid.append(row)
    for i in range(na):
        for j in range(nm):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][(j + 1) % nm], grid[i][(j + 1) % nm]))
    me = bpy.data.meshes.new("hood"); bm.to_mesh(me); bm.free()
    hood = new_obj("Mani_hood", me)
    hood.data.materials.append(objs["jacket"].data.materials[0])
    bind_rigid(hood, rig, "spine_03")
    for poly in hood.data.polygons:
        poly.use_smooth = True
    created.append(hood)
    # zip tapes along the open front edge of the jacket
    bmj = bmesh.new(); bmj.from_mesh(jk.data); bmj.edges.ensure_lookup_table()
    sides = {1: [], -1: []}
    for e in bmj.edges:
        if e.is_boundary:
            for vv in e.verts:
                w = jk.matrix_world @ vv.co
                if abs(w.x) < 0.14 and w.y < cy - 0.02 and w.z < zmax - 0.02:
                    sides[1 if w.x > 0 else -1].append(w)
    bmj.free()
    zm = []
    for sgn, vs in sides.items():
        if len(vs) < 4:
            continue
        uniq = {}
        for w in vs:
            uniq[(round(w.x, 3), round(w.y, 3), round(w.z, 3))] = w
        pts = sorted(uniq.values(), key=lambda w: -w.z)
        pts = [Vector((w.x - sgn * 0.0, w.y - 0.003, w.z)) for w in pts]
        zm.append(tube("zip", [tuple(p) for p in pts], 0.0032))
    if zm:
        z = join_meshes("Mani_zip", zm)
        z.data.materials.append(zip_mat)
        bind_rigid(z, rig, "spine_02")
        created.append(z)
    # hoodie drawstrings (hang from the neckline, under the open jacket)
    hv = np.array([(objs["hoodie"].matrix_world @ v_.co)[:] for v_ in objs["hoodie"].data.vertices])
    ntop = hv[hv[:, 2] > hv[:, 2].max() - 0.04]
    front = ntop[ntop[:, 1] < cy - 0.03]
    fz = float(front[:, 2].min()) if len(front) else zmax - 0.05
    fy = float(front[:, 1].min()) if len(front) else cy - 0.09
    cords = []
    for sgn in (1, -1):
        x0 = sgn * 0.028
        cords.append(tube("cord", [(x0, fy + 0.004, fz - 0.005), (x0 + sgn * 0.002, fy - 0.010, fz - 0.07),
                                    (x0 + sgn * 0.003, fy - 0.012, fz - 0.15), (x0 + sgn * 0.003, fy - 0.012, fz - 0.17)], 0.0028))
    cd = join_meshes("Mani_cords", cords)
    cd.data.materials.append(cord_mat)
    bind_rigid(cd, rig, "spine_03")
    created.append(cd)
    objs["extras"] = created
    for ob in created:
        ob.name = ob.name if ob.name.startswith("Mani_") else "Mani_" + ob.name
    return created


# ---------------------------------------------------------------------------------------------
# 5. bake shapes, strip hidden geometry
# ---------------------------------------------------------------------------------------------
def finalize_meshes(objs, bake=True):
    hm, rig = objs["hm"], objs["rig"]
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = hm
    hm.select_set(True)
    # bake face/macro targets into the basis
    if bake:
        bpy.ops.object.shape_key_remove(all=True, apply_mix=True)
    # drop helper geometry and every body face covered by clothing
    bm = bmesh.new()
    bm.from_mesh(hm.data)
    dl = bm.verts.layers.deform.active
    names = {vg.index: vg.name for vg in hm.vertex_groups}
    kill = []
    for v in bm.verts:
        w = {names[i]: x for i, x in v[dl].items() if i in names}
        in_body = w.get("body", 0) > 0.5
        covered = any(n.startswith("Delete.") and x > 0.5 for n, x in w.items())
        if (not in_body) or covered or (v.co.z < 0.17 and abs(v.co.x) > 0.04):
            kill.append(v)
    bmesh.ops.delete(bm, geom=kill, context="VERTS")
    bm.to_mesh(hm.data)
    bm.free()
    for m in list(hm.modifiers):
        if m.type == "MASK":
            hm.modifiers.remove(m)
    bone_names = {b.name for b in rig.data.bones}
    for ob in [o for o in bpy.data.objects if o.type == "MESH"]:
        for vg in list(ob.vertex_groups):
            if vg.name not in bone_names:
                ob.vertex_groups.remove(vg)
        for poly in ob.data.polygons:
            poly.use_smooth = True
        if not any(m.type == "ARMATURE" for m in ob.modifiers):
            m = ob.modifiers.new("Armature", "ARMATURE"); m.object = rig
        if ob.parent is None:
            ob.parent = rig
    # name tidy
    hm.name = "Mani_body"
    hm.data.name = "Mani_body"


def tri_count():
    dg = bpy.context.evaluated_depsgraph_get()
    n = 0
    detail = {}
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            me = ob.data
            t = sum(len(p.vertices) - 2 for p in me.polygons)
            detail[ob.name] = t
            n += t
    return n, detail


# ---------------------------------------------------------------------------------------------
# 6. animation (procedural, IK feet baked to FK)
# ---------------------------------------------------------------------------------------------
def smoother(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * t * (t * (t * 6 - 15) + 10)


class Animator:
    def __init__(self, rig):
        self.rig = rig
        self.bones = rig.data.bones
        self.Br = {b.name: b.matrix_local.to_3x3() for b in self.bones}
        self.rest_head = {b.name: (rig.matrix_world @ b.head_local) for b in self.bones}
        self.rest_tail = {b.name: (rig.matrix_world @ b.tail_local) for b in self.bones}
        self.deform = [b.name for b in self.bones]

    # --- IK rig -------------------------------------------------------------------------
    def add_ik(self):
        rig = self.rig
        bpy.context.view_layer.objects.active = rig
        bpy.ops.object.mode_set(mode="EDIT")
        eb = rig.data.edit_bones
        for s in ("l", "r"):
            f = eb["foot_" + s]
            t = eb.new("ik_foot_" + s)
            t.head, t.tail, t.roll = f.head.copy(), f.tail.copy(), f.roll
            t.parent = eb["Root"]
            knee = eb["calf_" + s].head
            pl = eb.new("ik_pole_" + s)
            pl.head = knee + Vector((0, -0.55, 0))
            pl.tail = pl.head + Vector((0, 0, 0.05))
            pl.parent = eb["Root"]
        bpy.ops.object.mode_set(mode="POSE")
        self.ik_names = ["ik_foot_l", "ik_foot_r", "ik_pole_l", "ik_pole_r"]
        for n in self.ik_names:
            self.Br[n] = rig.data.bones[n].matrix_local.to_3x3()
        for s in ("l", "r"):
            pb = rig.pose.bones["calf_" + s]
            c = pb.constraints.new("IK")
            c.target, c.subtarget = rig, "ik_foot_" + s
            c.pole_target, c.pole_subtarget = rig, "ik_pole_" + s
            c.chain_count = 2
            c.pole_angle = 0.0
            cr = rig.pose.bones["foot_" + s].constraints.new("COPY_ROTATION")
            cr.target, cr.subtarget = rig, "ik_foot_" + s
            cr.target_space = cr.owner_space = "WORLD"
        self.calibrate_pole()

    def calibrate_pole(self):
        """Pick the pole angle that bends the knee forward (-Y)."""
        rig = self.rig
        bpy.ops.object.mode_set(mode="POSE")
        best = None
        for deg in (-90, 0, 90, 180):
            for s in ("l", "r"):
                rig.pose.bones["calf_" + s].constraints["IK"].pole_angle = math.radians(deg)
            self.set_loc("ik_foot_l", Vector((0, -0.10, 0.28)))
            bpy.context.view_layer.update()
            knee = rig.matrix_world @ rig.pose.bones["calf_l"].head
            hip = rig.matrix_world @ rig.pose.bones["thigh_l"].head
            ank = rig.matrix_world @ rig.pose.bones["calf_l"].tail
            fwd = ((hip + ank) / 2).y - knee.y          # positive when the knee is in front (-Y)
            if best is None or fwd > best[0]:
                best = (fwd, deg)
        log("pole angle", best)
        self.pole = math.radians(best[1])
        for s in ("l", "r"):
            rig.pose.bones["calf_" + s].constraints["IK"].pole_angle = self.pole
        self.set_loc("ik_foot_l", Vector((0, 0, 0)))

    # --- keyframing helpers ---------------------------------------------------------------
    def set_loc(self, name, d):
        """d = armature-space offset from rest."""
        self.rig.pose.bones[name].location = self.Br[name].inverted() @ d

    def rot(self, name, mat):
        """mat = rotation in rest-armature axes, applied relative to the parent's motion."""
        q = (self.Br[name].inverted() @ mat @ self.Br[name]).to_quaternion()
        pb = self.rig.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = q

    @staticmethod
    def R(axis, deg):
        return Matrix.Rotation(math.radians(deg), 3, axis)

    def key(self, names, frame):
        for n in names:
            pb = self.rig.pose.bones[n]
            pb.keyframe_insert("location", frame=frame)
            pb.keyframe_insert("rotation_quaternion", frame=frame)

    def reset(self):
        for pb in self.rig.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_mode = "QUATERNION"
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.scale = (1, 1, 1)

    # --- leg geometry ---------------------------------------------------------------------
    def leg_info(self):
        th = self.rest_head["thigh_l"]; kn = self.rest_head["calf_l"]; an = self.rest_head["foot_l"]
        self.leg_len = (th - kn).length + (kn - an).length
        self.hip_h = th.z - an.z
        self.foot_x = abs(an.x)
        self.hip_x = abs(th.x)
        log("leg length %.3f hip height above ankle %.3f foot x %.3f hip x %.3f" % (self.leg_len, self.hip_h, self.foot_x, self.hip_x))

    def rest_bend(self, s):
        u = self.rest_head["lowerarm_" + s] - self.rest_head["upperarm_" + s]
        f = self.rest_head["hand_" + s] - self.rest_head["lowerarm_" + s]
        return math.degrees(u.angle(f))

    def arm_adduct_deg(self, s, target_deg):
        a = (self.rest_tail["upperarm_" + s] - self.rest_head["upperarm_" + s])
        ang = math.degrees(math.atan2(abs(a.x), -a.z))
        return ang - target_deg

    # --- the clips ------------------------------------------------------------------------
    def clip(self, name, frames, fn):
        rig = self.rig
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        if rig.animation_data is None:
            rig.animation_data_create()
        rig.animation_data.action = act
        driven = ["pelvis", "spine_01", "spine_02", "spine_03", "neck_01", "head", "clavicle_l", "clavicle_r",
                  "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"] + self.ik_names
        fingers = [b for b in self.deform if any(k in b for k in ("index_", "middle_", "ring_", "pinky_", "thumb_"))]
        for f in range(frames + 1):
            self.reset()
            fn(f / frames)
            self.relax_hands()
            self.key(driven + fingers, f)
        # bake IK to FK on the deform bones
        bpy.ops.object.mode_set(mode="POSE")
        bpy.ops.pose.select_all(action="DESELECT")
        for pb in rig.pose.bones:
            if pb.name not in self.ik_names:
                pb.select = True
        bpy.ops.nla.bake(frame_start=0, frame_end=frames, only_selected=True, visual_keying=True,
                         clear_constraints=False, clear_parents=False, use_current_action=True,
                         bake_types={"POSE"})
        act = rig.animation_data.action
        act.name = name
        # drop curves for IK helper bones and constant channels
        removed = kept = 0
        for layer in act.layers:
            for strip in layer.strips:
                for cb in strip.channelbags:
                    for fc in list(cb.fcurves):
                        bn = fc.data_path.split('"')[1] if '"' in fc.data_path else ""
                        vals = [kp.co[1] for kp in fc.keyframe_points]
                        const = (max(vals) - min(vals)) < 1e-5
                        drop = bn in self.ik_names
                        if const and not drop:
                            v0 = vals[0]
                            if "location" in fc.data_path and abs(v0) < 1e-5: drop = True
                            elif "scale" in fc.data_path and abs(v0 - 1) < 1e-5: drop = True
                            elif "rotation_quaternion" in fc.data_path and abs(v0 - (1 if fc.array_index == 0 else 0)) < 1e-5: drop = True
                        if drop:
                            cb.fcurves.remove(fc); removed += 1
                        else:
                            kept += 1
        log("clip %s: %d curves kept, %d dropped" % (name, kept, removed))
        act.use_frame_range = True
        act.frame_start, act.frame_end = 0, frames
        return act

    def relax_hands(self):
        for s, sg in (("l", 1), ("r", -1)):
            for fi, base in (("index", 14), ("middle", 18), ("ring", 22), ("pinky", 26)):
                for k, mult in ((1, 1.0), (2, 1.3), (3, 0.9)):
                    n = "%s_0%d_%s" % (fi, k, s)
                    if n in self.rig.pose.bones:
                        self.rot(n, self.R("Y", sg * self.curl_sign * base * mult))
            for k, a in ((1, 8), (2, 12), (3, 10)):
                n = "thumb_0%d_%s" % (k, s)
                if n in self.rig.pose.bones:
                    self.rot(n, self.R("Y", sg * self.curl_sign * a))

    def calibrate_curl(self):
        """Curl direction: fingertips must move toward the palm side (toward the body midline)."""
        self.curl_sign = 1.0
        rig = self.rig
        bpy.ops.object.mode_set(mode="POSE")
        self.reset()
        bpy.context.view_layer.update()
        t0 = rig.matrix_world @ rig.pose.bones["middle_03_l"].tail
        self.rot("middle_01_l", self.R("Y", 30)); self.rot("middle_02_l", self.R("Y", 30))
        bpy.context.view_layer.update()
        t1 = rig.matrix_world @ rig.pose.bones["middle_03_l"].tail
        self.curl_sign = 1.0 if t1.x < t0.x else -1.0
        log("curl sign", self.curl_sign, (t0.x, t1.x))
        self.reset()


def build_animations(objs):
    rig = objs["rig"]
    bpy.context.view_layer.objects.active = rig
    for o in bpy.data.objects:
        o.select_set(False)
    rig.select_set(True)
    A = Animator(rig)
    A.leg_info()
    A.add_ik()
    A.calibrate_curl()
    R = A.R
    add_l = A.arm_adduct_deg("l", 14)
    add_r = A.arm_adduct_deg("r", 14)
    rb_l, rb_r = A.rest_bend("l"), A.rest_bend("r")
    log("rest elbow bend", rb_l, rb_r)

    def arms(fwd_l, fwd_r, elbow_l, elbow_r, add=1.0):
        A.rot("upperarm_l", R("Y", add_l * add) @ R("X", -fwd_l))
        A.rot("upperarm_r", R("Y", -add_r * add) @ R("X", -fwd_r))
        A.rot("lowerarm_l", R("X", -(elbow_l - rb_l)))
        A.rot("lowerarm_r", R("X", -(elbow_r - rb_r)))

    def legs(sL, zL, pitchL, sR, zR, pitchR, foot_x):
        for s, sg, off, z, pitch in (("l", 1, sL, zL, pitchL), ("r", -1, sR, zR, pitchR)):
            dx = sg * (foot_x - A.foot_x)
            A.set_loc("ik_foot_" + s, Vector((dx, -off, z)))
            A.rot("ik_foot_" + s, R("X", -pitch))
            A.set_loc("ik_pole_" + s, Vector((dx * 0.5, 0, 0)))

    # ---------------- idle: 4 s, breathing + slow weight shift ----------------
    def idle(p):
        w = 2 * math.pi * p
        breath = math.sin(w)
        A.set_loc("pelvis", Vector((0.006 * math.sin(w), 0, -0.004 + 0.0015 * breath)))
        A.rot("pelvis", R("Y", 0.9 * math.sin(w)) @ R("Z", 0.8 * math.sin(w + 0.7)))
        A.rot("spine_01", R("X", 0.4 * breath) @ R("Y", -0.5 * math.sin(w)))
        A.rot("spine_02", R("X", 0.7 * breath) @ R("Y", -0.4 * math.sin(w)))
        A.rot("spine_03", R("X", 1.1 * breath) @ R("Y", -0.3 * math.sin(w)))
        A.rot("neck_01", R("X", -0.6 * breath))
        A.rot("head", R("X", 1.2 * math.sin(w - 0.5) * 0.5 + 1.5) @ R("Z", 2.2 * math.sin(w + 1.2)) @ R("Y", 0.8 * math.sin(w)))
        A.rot("clavicle_l", R("Z", 0.8 * breath)); A.rot("clavicle_r", R("Z", -0.8 * breath))
        arms(1.5 * math.sin(w), -1.5 * math.sin(w), 16 + 1.5 * breath, 16 + 1.5 * breath)
        legs(0, 0, 0, 0, 0, 0, 0.105)

    # ---------------- locomotion generator ----------------
    def locomotion(T, sf, S, clearance, speed, bob, sway, yaw, arm_sw, elbow, lean, foot_x, knee_bias=0.0):
        need = A.hip_h - math.sqrt((0.985 * A.leg_len) ** 2 - S * S)
        drop = max(need - bob * 1.9, 0.0) + 0.006 + (A.hip_h - 0.985 * A.leg_len if A.hip_h > 0.985 * A.leg_len else 0)
        log("loco D=%.3f need=%.3f" % (drop, need))

        def foot(p):
            if p < sf:
                u = p / sf
                s = S - 2 * S * u
                z = 0.028 * smoother((u - 0.72) / 0.28)
                pitch = 14 * (1 - smoother(u / 0.2)) - 38 * smoother((u - 0.75) / 0.25)
            else:
                v = (p - sf) / (1 - sf)
                s = -S + 2 * S * smoother(v)
                z = 0.028 + clearance * math.sin(math.pi * min(v * 1.15, 1.0)) ** 0.8 * (1 - v * 0.15) - 0.028 * v
                pitch = -38 * (1 - smoother(v / 0.35)) + 14 * smoother((v - 0.55) / 0.45)
            return s, max(z, 0.0), pitch

        def fn(p):
            w = 2 * math.pi * p
            sL, zL, pL = foot(p % 1.0)
            sR, zR, pR = foot((p + 0.5) % 1.0)
            legs(sL, zL, pL, sR, zR, pR, foot_x)
            if speed < 2.0:      # walk: pelvis highest at mid-stance, lowest at double support
                dz = -drop - bob * (1 - math.cos(4 * math.pi * (p - sf / 2)))
            else:                # jog: lowest at mid-stance, highest in flight
                dz = -drop - bob * (1 + math.cos(4 * math.pi * (p - sf / 2)))
            A.set_loc("pelvis", Vector((sway * math.cos(w - 2 * math.pi * 0.3), 0.0 + lean * -0.0, dz)))
            yw = -yaw * math.cos(w)
            A.rot("pelvis", R("Z", yw) @ R("X", -lean) @ R("Y", -2.0 * math.cos(w - 1.9)))
            for n, k in (("spine_01", 0.3), ("spine_02", 0.35), ("spine_03", 0.35)):
                A.rot(n, R("Z", -yw * k * 1.7) @ R("X", lean * 0.25 - 0.0) @ R("Y", 1.2 * math.cos(w - 1.9) * 0.5))
            A.rot("neck_01", R("Z", -yw * 0.25) @ R("X", lean * 0.6))
            A.rot("head", R("Z", -yw * 0.3) @ R("X", lean * 0.5))
            A.rot("clavicle_l", R("Z", 0.0)); A.rot("clavicle_r", R("Z", 0.0))
            sw = math.cos(w)
            arms(-arm_sw * sw, arm_sw * sw, elbow + 8 * max(-sw, 0) + 6, elbow + 8 * max(sw, 0) + 6, add=1.0)
        return fn

    walk = locomotion(T=1.0, sf=0.60, S=0.40, clearance=0.075, speed=1.4, bob=0.012, sway=0.014,
                      yaw=4.5, arm_sw=22, elbow=14, lean=0.0, foot_x=0.108)
    jog = locomotion(T=19 / 30, sf=0.38, S=0.34, clearance=0.17, speed=3.0, bob=0.020, sway=0.012,
                     yaw=6.5, arm_sw=38, elbow=70, lean=5.0, foot_x=0.10)
    A.clip("idle", 120, idle)
    A.clip("walk", 30, walk)
    A.clip("jog", 19, jog)          # 0.63 s at 30 fps, ~2.8 m/s
    # tidy: remove IK helpers
    bpy.ops.object.mode_set(mode="POSE")
    for pb in rig.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode="EDIT")
    for n in A.ik_names:
        rig.data.edit_bones.remove(rig.data.edit_bones[n])
    bpy.ops.object.mode_set(mode="OBJECT")
    A.reset() if False else None
    rig.animation_data.action = bpy.data.actions["idle"]
    rig.data.pose_position = "POSE"
    return A


def noise3(p, f):
    from mathutils import noise as mn
    return mn.noise(Vector((p[0] * f, p[1] * f + 11.3, p[2] * f - 5.1)))


def shape_hair(objs):
    """Give the pack's short hair the volume and lumpy curl silhouette of the approved sheet."""
    L = objs["L"]
    hair = objs["hair"]
    ez = L["eye_l"][2]
    ey = float(np.mean(np.concatenate([L["ear_l"], L["ear_r"]])[:, 1]))
    c = Vector((0, ey - 0.005, ez + 0.02))
    me = hair.data
    me.update()
    for v in me.vertices:
        p = v.co.copy()
        d = p - c
        n = d.normalized()
        top = float(smoothstep(ez + 0.03, ez + 0.13, p.z))
        side_lo = float(smoothstep(ez - 0.06, ez + 0.02, p.z))
        edge = float(smoothstep(ez + 0.015, ez + 0.07, p.z)) if p.y < ey - 0.05 else 1.0   # keep hairline low at front
        w = (0.30 + 0.70 * top) * (0.35 + 0.65 * side_lo) * (0.4 + 0.6 * edge)
        lump = noise3(p, 55.0) * 0.5 + noise3(p, 120.0) * 0.28
        disp = (0.012 + 0.017 * top) * 1.0 + 0.013 * lump * (0.7 + top)
        v.co = p + n * disp * w + Vector((0, 0.002 + (0.010 * top if p.y < ey - 0.05 else 0.0), 0.004 * top)) * w
    me.update()


def main():
    clear_scene()
    hm = build_human()
    L = landmarks(hm)
    skin_path = paint_skin(hm, L)
    objs = rig_and_dress(hm)
    objs["L"] = L
    objs["skin_path"] = skin_path
    shape_hair(objs)
    apply_materials(objs)
    build_accessories(objs, objs["rig"])
    return objs


def export_glb(objs):
    os.makedirs(os.path.dirname(OUT_GLB), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.type in ("MESH", "ARMATURE"):
            ob.select_set(True)
    bpy.context.view_layer.objects.active = objs["rig"]
    bpy.context.scene.render.fps = FPS
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_skins=True, export_image_format="AUTO", export_materials="EXPORT",
        export_cameras=False, export_lights=False)
    log("exported", OUT_GLB, "%.1f MB" % (os.path.getsize(OUT_GLB) / 1e6))


def pack_images():
    for img in bpy.data.images:
        if img.filepath and not img.packed_file and img.source == "FILE":
            try:
                img.pack()
            except Exception as e:
                log("pack failed", img.name, e)


def run_all():
    objs = main()
    finalize_meshes(objs)
    n, detail = tri_count()
    log("TRIANGLES", n, detail)
    build_animations(objs)
    pack_images()
    return objs


if __name__ == "__main__" and "--v1" not in ARGS:
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import mani_v2
    mani_v2.main_entry()
elif __name__ == "__main__":
    objs = run_all()
    scratch = "/private/tmp/claude-501/-Users-kamanika-Downloads-out-of-town/5498a04d-a1fe-4ca0-a447-3242544418f6/scratchpad/mani/w/stage1.blend"
    bpy.ops.wm.save_as_mainfile(filepath=scratch)
    if not NO_EXPORT:
        export_glb(objs)
        os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
