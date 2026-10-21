"""Mani v2: hair cards, beard/stubble cards, modelled parka + hood, lace-up boots, 4K head, lenses.

Entry point is `build_mani.py` (it imports this module and calls main_entry()).  Reuses the
helpers (materials, rig, animation, export) from build_mani.py.
"""
import bpy
import bmesh
import math
import os
import sys
import random
import numpy as np
from mathutils import Vector, Matrix

import build_mani as B
from build_mani import (log, make_material, save_raw, load_raw, smoothstep, value_noise, height_to_normal,
                        set_single_material, bone_pt, new_obj, tube, join_meshes, bind_rigid, rounded_rect,
                        OUT_TEX, DATA, HAIR_RGB)

UP = Vector((0, 0, 1))


def norm_v(v):
    return v.normalized() if v.length > 1e-9 else Vector((0, 0, 1))


# ---------------------------------------------------------------------------------------------
# procedural strand atlases (curly hair, short beard hair, stubble dots)
# ---------------------------------------------------------------------------------------------
def _disk(r):
    r = max(int(math.ceil(r)), 1)
    return [(dx, dy) for dx in range(-r, r + 1) for dy in range(-r, r + 1) if dx * dx + dy * dy <= r * r + 0.5]


def strand_tile(S, n, turns, amp, loop, width_px, spread, rng, dirvar=0.10, grow=0.93, root_fill=0.0):
    """One card tile: n curly strands rooted along the bottom edge growing toward the top."""
    alpha = np.zeros((S, S), np.float32)
    shade = np.zeros((S, S), np.float32)
    npts = int(S * 2.4)
    t = np.linspace(0, 1, npts)
    disks = {}
    for k in range(n):
        x0 = 0.5 + rng.normal(0, spread)
        ph = rng.rand() * 6.283
        tr = turns * (0.8 + 0.4 * rng.rand())
        th = 2 * np.pi * tr * t + ph
        a_k = amp * (0.7 + 0.6 * rng.rand())
        x = x0 + rng.normal(0, dirvar) * t + a_k * (0.35 + 0.9 * t) * np.sin(th)
        y = 0.015 + grow * t * (0.62 + 0.38 * rng.rand()) + loop * (0.3 + 0.7 * t) * np.cos(th)
        w = width_px * (1.0 - 0.5 * t) * (0.8 + 0.4 * rng.rand())
        sh = 0.45 + 0.75 * rng.rand()
        px = np.rint(x * S).astype(int)
        py = np.rint(y * S).astype(int)
        for r in np.unique(np.round(w).astype(int)):
            sel = np.round(w).astype(int) == r
            if r not in disks:
                disks[r] = _disk(r / 2.0 + 0.6)
            for dx, dy in disks[r]:
                xx = px[sel] + dx
                yy = py[sel] + dy
                ok = (xx >= 0) & (xx < S) & (yy >= 0) & (yy < S)
                alpha[yy[ok], xx[ok]] = 1.0
                shade[yy[ok], xx[ok]] = sh * (0.55 + 0.45 * t[sel][ok])
    if root_fill > 0:
        r0 = int(root_fill * S)
        x0, x1 = int(S * (0.5 - spread * 1.6)), int(S * (0.5 + spread * 1.6))
        for yy_ in range(r0):
            fall = 1.0 - yy_ / r0
            half = int((x1 - x0) / 2 * (0.55 + 0.45 * fall))
            alpha[yy_, S // 2 - half:S // 2 + half] = 1.0
            shade[yy_, S // 2 - half:S // 2 + half] = np.maximum(shade[yy_, S // 2 - half:S // 2 + half], 0.35)
    return alpha, shade


def box_blur(a, n=2):
    for _ in range(n):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


def strand_atlas(name, tiles_cfg, S, base_rgb, glint_rgb, seed):
    """2x2 atlas RGBA (colour+alpha) and normal map. tiles_cfg: 4 dicts for strand_tile."""
    rng = np.random.RandomState(seed)
    A = np.zeros((2 * S, 2 * S, 4), np.float32)
    N = np.zeros((2 * S, 2 * S, 3), np.float32)
    yy = np.linspace(0, 1, S)[:, None]
    for i, cfg in enumerate(tiles_cfg):
        alpha, shade = strand_tile(S, rng=rng, **cfg)
        sh = np.clip(shade, 0, 1.3)
        glint = np.clip((sh - 0.85) * 2.2, 0, 1)
        base = np.array(base_rgb)[None, None, :] * (0.55 + 0.9 * sh[..., None]) * (0.18 + 0.82 * yy[..., None] ** 1.3)
        col = base + glint[..., None] * np.array(glint_rgb)[None, None, :]
        # bleed colour into transparent pixels so mip-mapping does not make dark/white halos
        col = np.where(alpha[..., None] > 0, col, np.array(base_rgb)[None, None, :] * 0.8)
        h = box_blur(alpha * (0.6 + 0.4 * sh), 2)
        nrm = height_to_normal(h, 6.0)
        ox, oy = (i % 2) * S, (i // 2) * S
        A[oy:oy + S, ox:ox + S, :3] = col
        A[oy:oy + S, ox:ox + S, 3] = alpha
        N[oy:oy + S, ox:ox + S] = nrm
    return save_raw(name + "_c", A), save_raw(name + "_n", N)


def stubble_atlas(name, S=128):
    rng = np.random.RandomState(5)
    A = np.zeros((2 * S, 2 * S, 4), np.float32)
    for i in range(4):
        al = np.zeros((S, S), np.float32)
        for _ in range(125):
            x, y = rng.randint(2, S - 4, 2)
            al[y:y + 3, x:x + 3] = 1
            al[y, x] = 0 if rng.rand() < 0.5 else 1
        ox, oy = (i % 2) * S, (i // 2) * S
        A[oy:oy + S, ox:ox + S, :3] = np.array([0.03, 0.025, 0.024])
        A[oy:oy + S, ox:ox + S, 3] = al
    return save_raw(name + "_c", A)


def make_atlases():
    hair_cfg = [
        dict(n=190, turns=5.0, amp=0.040, loop=0.046, width_px=8.0, spread=0.15, grow=0.9, root_fill=0.16),
        dict(n=200, turns=6.0, amp=0.034, loop=0.050, width_px=7.6, spread=0.17, grow=0.9, root_fill=0.16),
        dict(n=180, turns=4.2, amp=0.050, loop=0.040, width_px=8.4, spread=0.15, grow=0.9, root_fill=0.16),
        dict(n=210, turns=6.8, amp=0.030, loop=0.052, width_px=7.2, spread=0.18, grow=0.9, root_fill=0.16),
    ]
    hair_c, hair_n = strand_atlas("mani_haircards", hair_cfg, 512, (0.008, 0.0065, 0.0065), (0.028, 0.021, 0.018), 3)
    beard_cfg = [
        dict(n=70, turns=2.4, amp=0.030, loop=0.020, width_px=2.3, spread=0.16, grow=0.72, root_fill=0.30),
        dict(n=78, turns=3.0, amp=0.026, loop=0.020, width_px=2.2, spread=0.17, grow=0.72, root_fill=0.30),
        dict(n=64, turns=2.0, amp=0.036, loop=0.016, width_px=2.4, spread=0.15, grow=0.72, root_fill=0.30),
        dict(n=84, turns=3.4, amp=0.022, loop=0.020, width_px=2.1, spread=0.18, grow=0.72, root_fill=0.30),
    ]
    beard_c, beard_n = strand_atlas("mani_beardcards", beard_cfg, 256, (0.012, 0.010, 0.010), (0.0, 0.0, 0.0), 9)
    stub_c = stubble_atlas("mani_stubble")
    return dict(hair_c=hair_c, hair_n=hair_n, beard_c=beard_c, beard_n=beard_n, stub_c=stub_c)


# ---------------------------------------------------------------------------------------------
# card meshes
# ---------------------------------------------------------------------------------------------
class CardBuilder:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.count = 0

    def card(self, P, d, n, w, l, droop, tile, rows=4, cols=3, curv=0.25, taper=0.35, flip=False, sag=None):
        d = norm_v(d)
        b = norm_v(d.cross(n))
        n2 = norm_v(b.cross(d))
        verts = []
        tx, ty = (tile % 2) * 0.5, (tile // 2) * 0.5
        sag = sag if sag is not None else Vector((0, 0, -1))
        for i in range(rows):
            v = i / (rows - 1)
            c = P + d * (l * v) + sag * (droop * v * v)
            wv = w * (1 - taper * v)
            row = []
            for j in range(cols):
                u = j / (cols - 1) - 0.5
                pos = c + b * (u * wv) + n2 * (-curv * (u * u) * w * 1.6 * (0.4 + v))
                row.append((self.bm.verts.new(pos), (0.5 - u if flip else u + 0.5), v))
            verts.append(row)
        for i in range(rows - 1):
            for j in range(cols - 1):
                quad = [verts[i][j], verts[i][j + 1], verts[i + 1][j + 1], verts[i + 1][j]]
                f = self.bm.faces.new([q[0] for q in quad])
                for lp, q in zip(f.loops, quad):
                    lp[self.uv].uv = (tx + q[1] * 0.5 * 0.98 + 0.005, ty + q[2] * 0.5 * 0.98 + 0.005)
        self.count += 1

    def to_object(self):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = new_obj(self.name, me)
        for p in me.polygons:
            p.use_smooth = True
        return ob


def mesh_arrays(ob):
    me = ob.data
    co = np.array([(ob.matrix_world @ v.co)[:] for v in me.vertices])
    tris = []
    for p in me.polygons:
        vs = list(p.vertices)
        for k in range(1, len(vs) - 1):
            tris.append((vs[0], vs[k], vs[k + 1]))
    return co, np.array(tris)


def sample_tris(co, tris, count, weight, rng, outward_from=None, unique=False):
    """Area*weight sampling of surface points. Returns list of (P, n)."""
    a, b, c = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
    cr = np.cross(b - a, c - a)
    area = np.linalg.norm(cr, axis=1) * 0.5
    nrm = cr / np.maximum(np.linalg.norm(cr, axis=1, keepdims=True), 1e-12)
    cen = (a + b + c) / 3
    if outward_from is not None:
        flip = ((cen - np.array(outward_from)) * nrm).sum(1) < 0
        nrm[flip] *= -1
    w = area * np.array([weight(cen[i], nrm[i]) for i in range(len(cen))])
    if w.sum() <= 0:
        return []
    if unique and count <= int((w > 0).sum()):
        idx = rng.choice(len(w), size=count, replace=False, p=w / w.sum())
    else:
        idx = rng.choice(len(w), size=count, p=w / w.sum())
    out = []
    for i in idx:
        r1, r2 = rng.rand(), rng.rand()
        if r1 + r2 > 1:
            r1, r2 = 1 - r1, 1 - r2
        P = a[i] + (b[i] - a[i]) * r1 + (c[i] - a[i]) * r2
        out.append((Vector(P), Vector(nrm[i])))
    return out


def head_frame(L):
    ez = float(L["eye_l"][2])
    ey = float(np.mean(np.concatenate([L["ear_l"], L["ear_r"]])[:, 1]))
    return ez, ey


# ---------------------------------------------------------------------------------------------
# hair cards
# ---------------------------------------------------------------------------------------------
def build_hair_cards(objs, atl, count=1650):
    L = objs["L"]
    rig = objs["rig"]
    cap = objs["hair"]
    ez, ey = head_frame(L)
    c = Vector((0, ey, ez + 0.02))
    # scalp cap: the pack's hair mesh, nudged out and made a matte dark skullcap under the cards
    for v in cap.data.vertices:
        n = (v.co - c).normalized()
        v.co += n * 0.0035
    co, tris = mesh_arrays(cap)
    rng = np.random.RandomState(21)

    def weight(p, n):
        h = p[2] - (ez + 0.02)
        if p[2] < ez - 0.055:
            return 0.0
        if p[1] < ey - 0.035 and p[2] < ez + 0.070:          # forehead / temples stay clear
            return 0.0
        if abs(p[0]) > 0.058 and p[2] < ez + 0.012 and ey - 0.05 < p[1] < ey + 0.035:   # ears stay clear
            return 0.0
        top = float(smoothstep(0.0, 0.08, h))
        side = 0.55 + 0.45 * top
        back = 1.0 if p[1] > ey else 0.85
        return (0.5 + 1.2 * top) * back * side

    samples = sample_tris(co, tris, count, weight, rng, outward_from=c)
    cb = CardBuilder("Mani_haircards")
    for P, n in samples:
        h = P.z - (ez + 0.02)
        tw = float(smoothstep(0.0, 0.085, h))
        front = P.y < ey - 0.05 and abs(P.x) < 0.08
        lowside = P.z < ez + 0.045
        L_ = (0.022 + 0.030 * tw) * rng.uniform(0.85, 1.2)
        W_ = (0.040 + 0.020 * tw) * rng.uniform(0.9, 1.2)
        jitter = Vector((rng.normal(0, 0.30), rng.normal(0, 0.30), rng.normal(0, 0.22)))
        d = n * (1.0 - 0.1 * tw) + UP * (0.05 + 0.20 * tw) + jitter * (0.8 + 0.6 * tw)
        sag = Vector((0, 0, -1))
        droop = L_ * (0.30 + 0.25 * (1 - tw))
        if front:                                           # fringe lifts up and back, never over the face
            d = UP * 0.8 + Vector((0, 0.45, 0)) + n * 0.15 + jitter * 0.35
            sag = Vector((0, 0.5, -0.5))
            L_ *= 0.85
            droop = L_ * 0.2
        elif lowside:                                       # sides: short, swept back over the ears' top, tight
            d = n * 0.35 + Vector((0, 0.55, 0.12)) + jitter * 0.3
            sag = Vector((0, 0.3, -0.7))
            L_ = 0.020 * rng.uniform(0.8, 1.2)
            droop = L_ * 0.25
        root = P - n * 0.004
        cb.card(root, d, n, W_, L_, droop, int(rng.randint(4)), rows=3, cols=3, curv=0.45, flip=bool(rng.rand() < 0.5), sag=sag)
    ob = cb.to_object()
    ob.name = "Mani_hair"
    ob.data.materials.append(make_material("Mani_haircards", atl["hair_c"], rough=0.8, spec=0.02, alpha_clip=True,
                                           normal_path=atl["hair_n"], normal_strength=0.55, double_sided=True,
                                           alpha_cutoff=0.5))
    bind_rigid(ob, rig, "head")
    # trim the scalp cap above the forehead so no flat black band shows under the fringe
    bmc = bmesh.new(); bmc.from_mesh(cap.data)
    bmesh.ops.delete(bmc, geom=[f for f in bmc.faces if all((v.co.z < ez + 0.105 and v.co.y < ey - 0.03) or (abs(v.co.x) > 0.052 and v.co.z < ez + 0.02 and ey - 0.065 < v.co.y < ey + 0.045) or v.co.z < ez - 0.012 for v in f.verts)], context="FACES_ONLY")
    bmc.to_mesh(cap.data); bmc.free()
    # cap material: flat dark, matte
    set_single_material(cap, make_material("Mani_scalp", color=(0.012, 0.010, 0.010), rough=0.8, spec=0.1))
    objs["hair_cards"] = ob
    log("hair cards", cb.count)
    return ob


# ---------------------------------------------------------------------------------------------
# dressing (rig, hoodie, jeans, eyes, brows, scalp cap)
# ---------------------------------------------------------------------------------------------
SCRATCH = "/private/tmp/claude-501/-Users-kamanika-Downloads-out-of-town/5498a04d-a1fe-4ca0-a447-3242544418f6/scratchpad/mani/w/stage2.blend"


def dress(hm):
    rig = B.HumanService.add_builtin_rig(hm, "game_engine", import_weights=True)
    rig.name = rig.data.name = "ManiRig"
    objs = {"hm": hm, "rig": rig}
    c2 = B.add_asset(hm, "male_casualsuit02/male_casualsuit02.mhclo", "clothes", "Clothes")
    for p in B.split_loose(c2):
        n, zmin, zmax = B.part_info(p)
        if zmin < 0.3:
            p.name = "Mani_jeans"; objs["jeans"] = p
        else:
            p.name = "Mani_hoodie"; objs["hoodie"] = p
    B.push_along_normals(objs["hoodie"], 0.0015)
    objs["eyes"] = B.add_asset(hm, "low-poly/low-poly.mhclo", "eyes", "Eyes"); objs["eyes"].name = "Mani_eyes"
    objs["brows"] = B.add_asset(hm, "eyebrow009/eyebrow009.mhclo", "eyebrows", "Eyebrows"); objs["brows"].name = "Mani_brows"
    objs["hair"] = B.add_asset(hm, "short01/short01.mhclo", "hair", "Hair"); objs["hair"].name = "Mani_scalp"
    return objs


def base_materials(objs, sk):
    hm = objs["hm"]
    hm.data.materials.clear()
    hm.data.materials.append(make_material("Mani_body", base_path=sk["body_c"], rough=0.72, spec=0.06))
    hm.data.materials.append(make_material("Mani_head", base_path=sk["head_c"], rough=0.64, spec=0.12,
                                           normal_path=sk["head_n"], normal_strength=1.0, orm_path=sk["head_orm"]))
    c, n = B.fabric_textures("mani_denim", (0.115, 0.115, 0.125), "denim")
    set_single_material(objs["jeans"], make_material("Mani_jeans", c, rough=0.85, normal_path=n, normal_strength=0.8))
    c, n = B.fabric_textures("mani_hoodie", (0.19, 0.19, 0.20), "knit")
    set_single_material(objs["hoodie"], make_material("Mani_hoodie", c, rough=0.95, normal_path=n, normal_strength=0.9, spec=0.2))
    e = load_raw(os.path.join(DATA, "eyes/materials/brown_eye.png"))[..., :3]
    sat = e.max(-1, keepdims=True) - e.min(-1, keepdims=True)
    iris = np.clip((sat - 0.10) / 0.12, 0, 1)
    e = e * (1 - iris) + (e * np.array([0.42, 0.40, 0.40])) * iris
    lum = e.mean(-1, keepdims=True)
    e = e * (1 - 0.45 * (1 - iris)) + lum * 0.45 * (1 - iris)
    set_single_material(objs["eyes"], make_material("Mani_eyes", save_raw("mani_eyes_c", e), rough=0.2, spec=0.5))
    a = load_raw(os.path.join(DATA, "eyebrows/eyebrow009/eyebrow009.png"))
    lum = a[..., :3].mean(-1, keepdims=True)
    lum = lum / max(lum.mean(), 1e-3)
    rgb = np.clip(lum, 0.3, 2.5) * HAIR_RGB[None, None, :] * 0.9
    p = save_raw("mani_brows_c", np.concatenate([rgb, a[..., 3:4]], axis=-1))
    set_single_material(objs["brows"], make_material("Mani_brows", p, rough=0.6, alpha_clip=True, spec=0.12, double_sided=True))


def main_entry():
    stage = [a for a in B.ARGS if a.startswith("--stage=")]
    stage = int(stage[0].split("=")[1]) if stage else 99
    B.clear_scene()
    hm = B.build_human()
    L = B.landmarks(hm)
    objs = dress(hm)
    objs["L"] = L
    sk = paint_skin_v2(hm, L)
    base_materials(objs, sk)
    bake_shapes(hm)
    build_parka(objs)
    build_parka_parts(objs)
    build_boots(objs)
    fit_jeans(objs)
    B.finalize_meshes(objs, bake=False)
    atl = make_atlases()
    build_hair_cards(objs, atl)
    build_beard(objs, atl)
    B.build_accessories(objs, objs['rig'])
    build_lenses(objs)
    build_drawstrings(objs)
    n, detail = B.tri_count()
    log("TRIANGLES", n, detail)
    if stage < 50:
        bpy.ops.wm.save_as_mainfile(filepath=SCRATCH)
        return
    B.build_animations(objs)
    B.pack_images()
    bpy.ops.wm.save_as_mainfile(filepath=SCRATCH)
    if "--no-export" not in B.ARGS:
        B.export_glb(objs)
        os.makedirs(os.path.dirname(B.OUT_BLEND), exist_ok=True)
        bpy.ops.wm.save_as_mainfile(filepath=B.OUT_BLEND)


# ---------------------------------------------------------------------------------------------
# beard / stubble density fields (shared by the skin shadow tone and the hair cards)
# ---------------------------------------------------------------------------------------------
def beard_fields(L):
    ez = float(L["eye_l"][2])
    ear_y = float(np.mean(np.concatenate([L["ear_l"], L["ear_r"]])[:, 1]))
    zlo = L["lips_zmax"]
    mouth_z = 0.5 * (L["lips_zmin"] + L["lips_zmax"])
    hw = L["lips_hw"]
    chin = L["chin_z"]

    def f(P):
        P = np.atleast_2d(P)
        x, y, z = P[:, 0], P[:, 1], P[:, 2]
        ax = np.abs(x)
        front_only = 1 - smoothstep(ear_y + 0.005, ear_y + 0.03, y)
        must_hw = hw * 1.45
        xr = np.clip(ax / must_hw, 0, 1.2)
        ztop = zlo + 0.023 - 0.015 * xr ** 2
        zbot = zlo - 0.003 - 0.006 * xr ** 2
        must = smoothstep(zbot - 0.002, zbot + 0.004, z) * (1 - smoothstep(ztop - 0.006, ztop, z)) \
            * (1 - smoothstep(must_hw * 0.85, must_hw, ax))
        goat = smoothstep(chin - 0.004, chin + 0.008, z) * (1 - smoothstep(L["lips_zmin"] - 0.003, L["lips_zmin"] + 0.002, z)) \
            * (1 - smoothstep(0.012, 0.026, ax))
        corner = (1 - smoothstep(0.004, 0.012, np.abs(z - mouth_z))) * smoothstep(hw * 0.7, hw * 1.1, ax) \
            * (1 - smoothstep(hw * 1.35, hw * 1.75, ax)) * 0.9
        stub_top = zlo + 0.030
        stubble = (1 - smoothstep(stub_top - 0.014, stub_top + 0.008, z)) \
            * smoothstep(chin - 0.045, chin - 0.002, z) * (1 - smoothstep(0.066, 0.090, ax)) * 0.75
        side = (1 - smoothstep(ez - 0.0, ez + 0.02, z)) * smoothstep(0.052, 0.062, ax) * (1 - smoothstep(0.075, 0.095, ax)) \
            * smoothstep(ear_y - 0.045, ear_y - 0.02, y) * (1 - smoothstep(ear_y + 0.006, ear_y + 0.02, y)) \
            * smoothstep(zlo, zlo + 0.03, z) * 0.8
        lip_mask = 1 - (smoothstep(L["lips_zmin"] - 0.001, L["lips_zmin"] + 0.003, z)
                        * (1 - smoothstep(L["lips_zmax"] - 0.004, L["lips_zmax"] + 0.0005, z))) \
            * (1 - smoothstep(hw * 0.85, hw * 1.05, ax))
        return dict(must=must * front_only, goat=goat * front_only, corner=corner * front_only,
                    stub=stubble * lip_mask * front_only, side=side * front_only, lip=lip_mask)
    return f


# ---------------------------------------------------------------------------------------------
# 4K head texture (+ normal, ORM) with remapped UVs; 2K body texture for neck and hands
# ---------------------------------------------------------------------------------------------
SKIN_RGB = np.array([0.345, 0.255, 0.195])


def zoom_array(arr, new_w, new_h):
    img = bpy.data.images.new("zoom_tmp", arr.shape[1], arr.shape[0], alpha=True, float_buffer=True)
    img.colorspace_settings.name = "Non-Color"
    rgba = np.ones((arr.shape[0], arr.shape[1], 4), np.float32)
    rgba[..., :3] = arr
    img.pixels = rgba.ravel()
    img.scale(new_w, new_h)
    out = np.array(img.pixels[:], dtype=np.float32).reshape(new_h, new_w, 4)[..., :3]
    bpy.data.images.remove(img)
    return out


def paint_skin_v2(hm, L):
    log("skin: base atlas")
    base = os.path.join(DATA, "skins")
    af = load_raw(os.path.join(base, "young_african_male/young_darkskinned_male_diffuse.png"))[..., :3]
    asn = load_raw(os.path.join(base, "young_asian_male/young_lightskinned_male_diffuse3.png"))[..., :3]
    mix = af * 0.5 + asn * 0.5
    del af, asn
    lum0 = mix.mean(-1, keepdims=True)
    mix = mix * 0.55 + lum0 * 0.45                       # take most of the orange/red out
    cur = mix.reshape(-1, 3).mean(0)
    skin = np.clip(mix * (SKIN_RGB / cur)[None, None, :], 0, 1)
    A = skin.shape[0]
    me = hm.data
    uvl = me.uv_layers.active.data
    co = L["co"]

    # head faces = the head UV island
    head_polys = []
    for p in me.polygons:
        li = list(p.loop_indices)
        us = [uvl[l].uv[0] for l in li]; vs = [uvl[l].uv[1] for l in li]
        zc = co[list(p.vertices), 2].mean()
        if min(us) > 0.60 and 0.10 < min(vs) and max(vs) < 0.92 and zc > 1.30:
            head_polys.append(p)
    log("head faces", len(head_polys))
    us = [uvl[l].uv[0] for p in head_polys for l in p.loop_indices]
    vs = [uvl[l].uv[1] for p in head_polys for l in p.loop_indices]
    pad = 8
    cx0 = int(min(us) * A) - pad; cy0 = int(min(vs) * A) - pad
    cx1 = int(max(us) * A) + pad; cy1 = int(max(vs) * A) + pad
    cw, ch = cx1 - cx0, cy1 - cy0
    HS = 4096
    Z = HS * 0.998 / max(cw, ch)
    log("head crop %dx%d zoom %.2f" % (cw, ch, Z))
    # remap the head UVs so the head island fills the 4K canvas
    for p in head_polys:
        p.material_index = 1
        for l in p.loop_indices:
            u, v = uvl[l].uv
            uvl[l].uv = ((u * A - cx0) * Z / HS, (v * A - cy0) * Z / HS)
    crop = skin[cy0:cy1, cx0:cx1]
    nw, nh = int(round(cw * Z)), int(round(ch * Z))
    up = zoom_array(crop, nw, nh)
    canvas = np.empty((HS, HS, 3), np.float32)
    canvas[:] = SKIN_RGB
    canvas[:nh, :nw] = up
    del up, crop
    # ---- feature rasterisation (3D position -> fields) -----------------------------------
    fields = beard_fields(L)
    ez = float(L["eye_l"][2])
    ear_y = float(np.mean(np.concatenate([L["ear_l"], L["ear_r"]])[:, 1]))
    F = np.zeros((HS, HS, 6), np.float32)    # beard shadow, tired, lips, flush, forehead, covered
    nose = co[(np.abs(co[:, 0]) < 0.02) & (co[:, 2] > ez - 0.06) & (co[:, 2] < ez + 0.0)]
    nose_tip = nose[np.argmin(nose[:, 1])]

    def tired(P):
        d = 0
        for e in (L["eye_l"], L["eye_r"]):
            dx = (P[:, 0] - e[0]) / 0.021
            dz = (P[:, 2] - (e[2] - 0.0115)) / 0.0105
            d = np.maximum(d, np.exp(-(dx * dx + dz * dz)))
            dz2 = (P[:, 2] - (e[2] + 0.0045)) / 0.0075
            d = np.maximum(d, 0.35 * np.exp(-(dx * dx + dz2 * dz2)))     # heavy upper lids
        return d

    for p in head_polys:
        vs_ = list(p.vertices)
        li = list(p.loop_indices)
        for k in range(1, len(vs_) - 1):
            ids = [0, k, k + 1]
            uv = np.array([[uvl[li[i]].uv[0] * (HS - 1), uvl[li[i]].uv[1] * (HS - 1)] for i in ids])
            P3 = co[[vs_[i] for i in ids]]
            x0, x1 = int(np.floor(uv[:, 0].min())), int(np.ceil(uv[:, 0].max()))
            y0, y1 = int(np.floor(uv[:, 1].min())), int(np.ceil(uv[:, 1].max()))
            if x1 - x0 > 400 or y1 - y0 > 400:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            a, b, c = uv
            den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(den) < 1e-9:
                continue
            l1 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
            l2 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
            l3 = 1 - l1 - l2
            m = (l1 >= -0.03) & (l2 >= -0.03) & (l3 >= -0.03)
            if not m.any():
                continue
            pp = l1[m][:, None] * P3[0] + l2[m][:, None] * P3[1] + l3[m][:, None] * P3[2]
            fl = fields(pp)
            ty, tx = gy[m], gx[m]
            ok = (ty >= 0) & (ty < HS) & (tx >= 0) & (tx < HS)
            sh = np.clip(fl["must"] + fl["goat"] + fl["corner"] + fl["stub"] * 0.9 + fl["side"], 0, 1)
            x, z, y = pp[:, 0], pp[:, 2], pp[:, 1]
            ax = np.abs(x)
            lips = (1 - fl["lip"]) * (y < nose_tip[1] + 0.03)
            # rosy flush: cheeks and nose
            flush = np.exp(-(((ax - 0.05) / 0.025) ** 2 + ((z - (ez - 0.03)) / 0.022) ** 2)) * (y < ear_y - 0.03) \
                + np.exp(-((x / 0.014) ** 2 + ((z - (ez - 0.032)) / 0.02) ** 2)) * (y < nose_tip[1] + 0.03)
            fore = smoothstep(ez + 0.025, ez + 0.04, z) * (1 - smoothstep(ez + 0.075, ez + 0.095, z)) * (y < ear_y - 0.03)
            vals = np.stack([sh, tired(pp), lips, np.clip(flush, 0, 1), fore, np.ones_like(sh)], axis=-1)
            F[ty[ok], tx[ok]] = vals[ok]
    log("skin: features rasterised")
    # ---- compose colour ----------------------------------------------------------------------
    rng = np.random.RandomState(4)
    n_big = value_noise(HS, HS, 12, 31) - 0.5
    n_mid = value_noise(HS, HS, 70, 32) - 0.5
    n_fine = value_noise(HS, HS, 900, 33) - 0.5
    pore_n = value_noise(HS, HS, 1650, 34)
    pores = smoothstep(0.80, 0.93, pore_n)
    pore_n2 = value_noise(HS, HS, 780, 35)
    pores2 = smoothstep(0.78, 0.92, pore_n2) * 0.6
    pore = np.clip(pores + pores2, 0, 1)
    col = canvas
    del canvas
    lum = 1 + n_big * 0.10 + n_mid * 0.10 + n_fine * 0.08 - pore * 0.11
    col *= lum[..., None]
    # warmer blotches (slightly redder / yellower patches)
    warm = (n_mid * 0.7 + n_big * 0.6)[..., None] * np.array([0.10, 0.015, -0.03])[None, None, :]
    col += col * warm
    col *= (1 + F[..., 3:4] * np.array([0.10, -0.03, -0.05])[None, None, :])        # flush
    tired_t = np.array([0.74, 0.70, 0.72])[None, None, :]
    col = col * (1 - F[..., 1:2] * 0.62) + col * tired_t * F[..., 1:2] * 0.62        # tired eyes
    lipc = np.array([0.30, 0.165, 0.14])[None, None, :]
    col = col * (1 - F[..., 2:3] * 0.6) + lipc * (0.9 + 0.2 * n_fine[..., None]) * F[..., 2:3] * 0.6
    shade = F[..., 0:1]
    col = col * (1 - 0.30 * shade) + np.array([0.12, 0.10, 0.10])[None, None, :] * 0.30 * shade   # beard shadow tone
    covered = F[..., 5] > 0.5
    out_c = save_raw("mani_head_c", np.where(covered[..., None], col, SKIN_RGB[None, None, :]), fmt="JPEG", quality=92)
    del col
    # ---- normal map -----------------------------------------------------------------------------
    hmap = -pore * 0.55 + n_fine * 0.18 + n_mid * 0.10
    ys = np.arange(HS)[:, None].astype(np.float32); xs = np.arange(HS)[None, :].astype(np.float32)
    hmap += F[..., 4] * 0.10 * np.sin(ys * 0.045 + n_big * 9) * (0.5 + 0.5 * n_mid)      # faint forehead lines
    hmap += F[..., 1] * -0.18 * (0.6 + n_mid)                                              # eye-bag hollow
    hmap += F[..., 2] * 0.12 * np.sin(xs * 0.5 + n_mid * 12)                              # lip lines
    nrm = height_to_normal(hmap, 3.2)
    out_n = save_raw("mani_head_n", nrm, fmt="JPEG", quality=92)
    del nrm, hmap
    # ---- occlusion / roughness / metal ------------------------------------------------------------
    rough = 0.64 + n_mid * 0.14 + n_fine * 0.05 - F[..., 3] * 0.04 - pore * 0.05
    rough = rough * (1 - F[..., 2]) + 0.40 * F[..., 2]
    rough = rough * (1 - np.clip(F[..., 0], 0, 1) * 0.5) + 0.85 * np.clip(F[..., 0], 0, 1) * 0.5
    orm = np.stack([np.ones_like(rough) * (1 - 0.35 * pore), np.clip(rough, 0.2, 1), np.zeros_like(rough)], axis=-1)
    out_o = save_raw("mani_head_orm", orm, fmt="JPEG", quality=90)
    del orm, rough, F
    # ---- body (neck, hands) 2K ----------------------------------------------------------------------
    nb = value_noise(A, A, 700, 41); nbm = value_noise(A, A, 60, 42) - 0.5
    body = skin * (1 + nbm * 0.10 - smoothstep(0.82, 0.93, nb) * 0.10)[..., None]
    out_b = save_raw("mani_body_c", np.clip(body, 0, 1), fmt="JPEG", quality=92)
    return dict(head_c=out_c, head_n=out_n, head_orm=out_o, body_c=out_b)


# ---------------------------------------------------------------------------------------------
# moustache / goatee cards and stubble patches
# ---------------------------------------------------------------------------------------------
def build_beard(objs, atl):
    L, rig, hm = objs["L"], objs["rig"], objs["hm"]
    fields = beard_fields(L)
    co, tris = mesh_arrays(hm)
    cen = (co[tris[:, 0]] + co[tris[:, 1]] + co[tris[:, 2]]) / 3
    keep = (cen[:, 2] > L["chin_z"] - 0.08) & (cen[:, 2] < L["eye_l"][2] + 0.02) & (cen[:, 1] < 0.0)
    tris = tris[keep]
    fl_cache = {}
    rng = np.random.RandomState(33)
    centre = (L["lips_c"][0], 0.0, L["eye_l"][2])

    def sampler(key, count):
        def weight(p, n):
            f = fields(np.array(p))
            return float(sum(f[k][0] for k in key))
        return sample_tris(co, tris, count, weight, rng, outward_from=(0, 0.02, L["eye_l"][2] - 0.04))

    def tangent_down(n):
        t = -UP + n * UP.dot(n)
        return norm_v(t)

    cb = CardBuilder("Mani_beard")
    # moustache: hairs fan down and out from the philtrum
    for P, n in sampler(["must"], 700):
        td = tangent_down(n)
        lat = norm_v(UP.cross(n)) * (1 if P.x > 0 else -1)
        lat = lat * (1 if lat.x * P.x >= 0 else -1)
        d = norm_v(td * 0.85 + lat * (0.25 + 0.5 * min(abs(P.x) / 0.03, 1.0)) + n * 0.22 + Vector((rng.normal(0, .08),) * 3))
        cb.card(P - n * 0.0015, d, n, rng.uniform(0.016, 0.022), rng.uniform(0.014, 0.020), 0.002, int(rng.randint(4)), rows=3, cols=2, curv=0.2,
                flip=bool(rng.rand() < 0.5), sag=td)
    # goatee: short dense cards down the chin
    for P, n in sampler(["goat"], 380):
        td = tangent_down(n)
        d = norm_v(td + n * 0.22 + Vector((rng.normal(0, .10), rng.normal(0, .06), rng.normal(0, .06))))
        cb.card(P - n * 0.0015, d, n, rng.uniform(0.015, 0.021), rng.uniform(0.016, 0.022), 0.002, int(rng.randint(4)), rows=3, cols=2, curv=0.2,
                flip=bool(rng.rand() < 0.5), sag=td)
    # joins at the mouth corners
    for P, n in sampler(["corner"], 60):
        td = tangent_down(n)
        d = norm_v(td * 0.8 + n * 0.22 + Vector((rng.normal(0, .1), 0, 0)))
        cb.card(P - n * 0.0015, d, n, rng.uniform(0.013, 0.017), rng.uniform(0.012, 0.016), 0.002, int(rng.randint(4)), rows=3, cols=2, curv=0.2, sag=td)
    ob = cb.to_object()
    ob.name = "Mani_beard"
    ob.data.materials.append(make_material("Mani_beard", atl["beard_c"], rough=1.0, spec=0.0, alpha_clip=True,
                                           double_sided=True, alpha_cutoff=0.5))
    bind_rigid(ob, rig, "head")
    nb = cb.count

    # stubble patches: tiny alpha dot quads lying on the skin (jaw, cheeks, sideburns, upper neck)
    stub_mat = make_material("Mani_stubble", atl["stub_c"], rough=1.0, spec=0.0, alpha_clip=True, double_sided=True, alpha_cutoff=0.5)
    # extend the candidate area down the neck
    keep2 = (cen[:, 2] > L["chin_z"] - 0.10) & (cen[:, 2] < L["eye_l"][2] + 0.02)
    tris2 = np.array([t for t, k in zip(np.array(list(zip(*[(0,)]))), [])]) if False else None
    co_all, tris_all = mesh_arrays(hm)
    cen_all = (co_all[tris_all[:, 0]] + co_all[tris_all[:, 1]] + co_all[tris_all[:, 2]]) / 3
    tsel = tris_all[(cen_all[:, 2] > L["chin_z"] - 0.10) & (cen_all[:, 2] < L["eye_l"][2] + 0.02)]

    def sw(p, n):
        f = fields(np.array(p))
        neck = float(smoothstep(L["chin_z"] - 0.002, L["chin_z"] - 0.03, p[2])) * (1 - float(smoothstep(0.04, 0.07, abs(p[0]))))
        front_neck = 1.0 if p[1] < -0.01 else 0.0
        return float(f["stub"][0] + f["side"][0] + 0.5 * neck * front_neck * 0.7)
    for part, zsel in (("head", lambda z: z >= L["chin_z"] - 0.012), ("neck", lambda z: z < L["chin_z"] - 0.012)):
        samples = [(P, n) for P, n in sample_tris(co_all, tsel, 1000 if part == "head" else 400, sw, rng, outward_from=(0, 0.02, L["eye_l"][2] - 0.08), unique=True)
                   if zsel(P.z)]
        sb = CardBuilder("Mani_stubble_" + part)
        for P, n in samples:
            if np.sum(np.abs(n)) == 0:
                continue
            ref = norm_v(UP.cross(n)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
            ang = rng.uniform(0, 6.283)
            r_ = ref * math.cos(ang) + n.cross(ref) * math.sin(ang)
            sz = rng.uniform(0.012, 0.016)
            sb.card(P + n * 0.0007 - r_ * sz * 0.5, r_, n, sz, sz, 0.0, int(rng.randint(4)), rows=2, cols=2, curv=0.0, taper=0.0)
        so = sb.to_object()
        so.name = "Mani_stubble_" + part
        so.data.materials.append(stub_mat)
        bind_rigid(so, rig, "head" if part == "head" else "neck_01")
        objs["stubble_" + part] = so
    log("beard cards", nb, "stubble head/neck", len(objs["stubble_head"].data.polygons), len(objs["stubble_neck"].data.polygons))
    objs["beard"] = ob


# ---------------------------------------------------------------------------------------------
# shapes baked, then the parka is derived from the body so it fits and skins exactly
# ---------------------------------------------------------------------------------------------
def bake_shapes(hm):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = hm
    hm.select_set(True)
    bpy.ops.object.shape_key_remove(all=True, apply_mix=True)


def vgroup_names(ob):
    return {vg.index: vg.name for vg in ob.vertex_groups}


def new_mesh_object_like(src, bm, name, group_order=None):
    """bmesh (with deform layer copied from src) -> object with src's vertex groups."""
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = new_obj(name, me)
    for vg in src.vertex_groups:
        ob.vertex_groups.new(name=vg.name)
    return ob


def planar_uv(bm, scale=1.0 / 0.30):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for lp in f.loops:
            p = lp.vert.co
            if ax == 0:
                uvv = (p.y, p.z)
            elif ax == 1:
                uvv = (p.x, p.z)
            else:
                uvv = (p.x, p.y)
            lp[uv].uv = (uvv[0] * scale, uvv[1] * scale)


def parka_selection(hm):
    bm = bmesh.new()
    bm.from_mesh(hm.data)
    dl = bm.verts.layers.deform.active
    names = vgroup_names(hm)
    hem = 0.86
    sel = set()
    for v in bm.verts:
        w = {names[i]: x for i, x in v[dl].items() if i in names}
        if w.get("body", 0) < 0.5:
            continue
        arm = sum(w.get(k, 0) for k in ("clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"))
        torso = sum(w.get(k, 0) for k in ("spine_01", "spine_02", "spine_03", "pelvis"))
        z = v.co.z
        if z > 0.86:
            torso += sum(w.get(k, 0) for k in ("thigh_l", "thigh_r"))
        if arm > 0.55 and z > 0.95:
            sel.add(v.index)
        elif (torso + 0.5 * arm) > 0.55 and hem < z < 1.50 and abs(v.co.x) < 0.24:
            sel.add(v.index)
    bm.verts.ensure_lookup_table()
    drop = [f for f in bm.faces if not all(v.index in sel for v in f.verts)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    return bm


def inset_patch(bm, faces, thickness, depth):
    if faces:
        bmesh.ops.inset_region(bm, faces=faces, thickness=thickness, depth=depth, use_even_offset=True)


def build_parka(objs):
    hm, rig = objs["hm"], objs["rig"]
    bm = parka_selection(hm)
    log("parka base faces", len(bm.faces))
    # ---- open front: remove the centre-front strip -------------------------------------------
    gap = 0.050
    front = [f for f in bm.faces if abs(f.calc_center_median().x) < gap and f.calc_center_median().y < -0.02
             and f.calc_center_median().z > 0.80]
    bmesh.ops.delete(bm, geom=front, context="FACES")
    bm.normal_update()
    # ---- inflate: torso, puffy sleeves, A-line flare ---------------------------------------------
    arm_dir = {}
    for s in ("l", "r"):
        arm_dir[s] = (bone_pt(rig, "lowerarm_" + s, True), bone_pt(rig, "upperarm_" + s))
    for v in bm.verts:
        z = v.co.z
        is_arm = abs(v.co.x) > 0.19 and z > 0.95 or (abs(v.co.x) > 0.16 and z > 1.15 and v.co.y > -0.1 and False)
        thick = 0.026 if is_arm else 0.030
        thick += 0.028 * float(smoothstep(1.03, 0.86, z))
        v.co += v.normal * thick
    bmesh.ops.smooth_vert(bm, verts=list(bm.verts), factor=0.45, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    # keep the parka clear of the (loose) hoodie and jeans underneath
    from mathutils.bvhtree import BVHTree
    for key, clear in (("hoodie", 0.022), ("jeans", 0.016)):
        ob = objs[key]
        tmp = bmesh.new(); tmp.from_mesh(ob.data)
        tree = BVHTree.FromBMesh(tmp)
        for _ in range(2):
            for v in bm.verts:
                loc, nrm, idx, dist = tree.find_nearest(v.co)
                if loc is None:
                    continue
                inside = (v.co - loc).dot(nrm) < 0
                if inside or dist < clear:
                    v.co = loc + nrm * clear
            bmesh.ops.smooth_vert(bm, verts=list(bm.verts), factor=0.25, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        tmp.free()
    bm.normal_update()
    # quilting: horizontal puffs with sharp seams
    for v in bm.verts:
        z = v.co.z
        frac = ((z - 0.86) / 0.118) % 1.0
        puff = math.sin(math.pi * frac) ** 0.55
        v.co += v.normal * (0.0085 * puff - 0.004)
    bm.normal_update()
    # ---- details: hem band, lower flap pockets, chest zip pocket, cuffs ---------------------------
    def faces_in(xr, zr, front_facing=True, max_y=None):
        out = []
        for f in bm.faces:
            c = f.calc_center_median()
            if xr[0] <= c.x <= xr[1] and zr[0] <= c.z <= zr[1]:
                if front_facing and f.normal.y > -0.25:
                    continue
                out.append(f)
        return out
    for sx in (1, -1):
        cx = sx * 0.135
        body = faces_in(sorted((cx - 0.085, cx + 0.085)), (0.93, 1.05))
        inset_patch(bm, body, 0.006, 0.010)
        flap = faces_in(sorted((cx - 0.092, cx + 0.092)), (1.035, 1.075))
        inset_patch(bm, flap, 0.004, 0.007)
    inset_patch(bm, faces_in((0.095, 0.125), (1.22, 1.36)), 0.004, 0.003)                          # chest zip pocket welt
    for s in ("l", "r"):
        wrist = bone_pt(rig, "lowerarm_" + s, True)
        cuff = [f for f in bm.faces if (f.calc_center_median() - wrist).length < 0.05]
        inset_patch(bm, cuff, 0.003, 0.005)
    bm.normal_update()
    planar_uv(bm)
    ob = new_mesh_object_like(hm, bm, "Mani_parka")
    objs["parka_front_edge"] = None
    # collect the opening's boundary (for zip tape / plackets) before freeing
    edge_pts = {1: [], -1: []}
    for e in bm.edges:
        if e.is_boundary:
            for v in e.verts:
                if abs(v.co.x) < 0.12 and v.co.y < -0.03 and v.co.z > 0.87:
                    edge_pts[1 if v.co.x > 0 else -1].append(v.co.copy())
    bm.free()
    bpy.context.view_layer.objects.active = ob
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    m = ob.modifiers.new("Armature", "ARMATURE"); m.object = rig
    for p in ob.data.polygons:
        p.use_smooth = True
    c, n = B.fabric_textures("mani_parka", (0.075, 0.095, 0.18), "twill")
    ob.data.materials.append(make_material("Mani_parka", c, rough=0.78, normal_path=n, normal_strength=0.8, spec=0.25,
                                           double_sided=True))
    objs["parka"] = ob
    objs["parka_edges"] = edge_pts
    log("parka tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    return ob


def arc_torus(name, c, major, minor, a0, a1, squash, rng, n_a=18, n_m=9, noise=0.006, back=0.0, taper=0.5):
    bm = bmesh.new()
    grid = []
    for i in range(n_a + 1):
        th = math.radians(a0) + (math.radians(a1) - math.radians(a0)) * i / n_a
        tp = (1 - taper) + taper * math.sin(math.pi * i / n_a)
        row = []
        for j in range(n_m):
            ph = 2 * math.pi * j / n_m
            rr = major + minor * tp * math.cos(ph) + rng.normal(0, noise)
            row.append(bm.verts.new((c[0] + rr * 1.06 * math.sin(th), c[1] + back - rr * math.cos(th),
                                     c[2] + minor * squash * tp * math.sin(ph) + rng.normal(0, noise * 0.6))))
        grid.append(row)
    for i in range(n_a):
        for j in range(n_m):
            bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][(j + 1) % n_m], grid[i][(j + 1) % n_m]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    ob = new_obj(name, me)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def build_parka_parts(objs):
    rig = objs["rig"]
    rng = np.random.RandomState(5)
    nk = bone_pt(rig, "neck_01")
    cx, cy, zn = float(nk.x), float(nk.y), float(nk.z)
    par_mat = objs["parka"].data.materials[0]
    hood_mat = objs["hoodie"].data.materials[0]
    # hoodie hood resting at the back of the neck, under the parka
    hh = arc_torus("Mani_hoodie_hood", (cx, cy, zn + 0.0), 0.085, 0.036, 46, 314, 0.75, rng, n_a=26, noise=0.0018, back=0.018)
    hh.data.materials.append(hood_mat)
    bind_rigid(hh, rig, "spine_03")
    # parka hood: thick folded cowl lying on the upper back / shoulders
    hp = arc_torus("Mani_parka_hood", (cx, cy, zn + 0.012), 0.100, 0.052, 72, 288, 0.58, rng, n_a=26, n_m=12, noise=0.0025, back=0.040, taper=0.7)
    hp.data.materials.append(par_mat)
    bind_rigid(hp, rig, "spine_03")
    # funnel collar, open at the front
    col = B.frustum("Mani_parka_collar", (cx, cy + 0.004, 0), zn - 0.020, zn + 0.046, 0.078, 0.080, 0.084, 0.088, seg=28, gap_deg=44, thickness=0.012)
    col.data.materials.append(par_mat)
    for p in col.data.polygons:
        p.use_smooth = True
    bind_rigid(col, rig, "spine_03")
    created = [hh, hp, col]
    # ---- plackets, zip tape, snaps, puller along the open front ---------------------------------
    metal = make_material("Mani_zip", color=(0.07, 0.07, 0.075), rough=0.45, metal=0.6)
    snap = make_material("Mani_snaps", color=(0.10, 0.10, 0.11), rough=0.35, metal=0.8)
    tape = make_material("Mani_ziptape", color=(0.025, 0.027, 0.035), rough=0.9)
    plackets, tapes, snaps_m, tops = [], [], [], {}
    for sgn, pts in objs["parka_edges"].items():
        if len(pts) < 4:
            continue
        uniq = {}
        for p in pts:
            uniq[(round(p.x, 3), round(p.y, 3), round(p.z, 3))] = p
        line = sorted(uniq.values(), key=lambda p: -p.z)
        # smooth the polyline a little
        sm = []
        for i, p in enumerate(line):
            a = line[max(i - 1, 0)]; b = line[min(i + 1, len(line) - 1)]
            sm.append((a + p * 2 + b) / 4)
        line = sm
        bm = bmesh.new()
        prev = None
        for p in line:
            out = Vector((sgn, 0, 0))
            a_ = bm.verts.new(p + Vector((0, -0.004, 0)))
            b_ = bm.verts.new(p + out * 0.034 + Vector((0, -0.004, 0)))
            if prev:
                bm.faces.new((prev[0], prev[1], b_, a_))
            prev = (a_, b_)
        me = bpy.data.meshes.new("pl"); bm.to_mesh(me); bm.free()
        plackets.append(me)
        tapes.append(tube("zip", [tuple(p + Vector((sgn * -0.003, -0.006, 0))) for p in line], 0.0028, sides=5))
        # snaps down the outer strip
        z0, z1 = line[0].z - 0.05, line[-1].z + 0.04
        zk = z0
        while zk > z1:
            p = min(line, key=lambda q: abs(q.z - zk))
            cyl = bmesh.new()
            bmesh.ops.create_cone(cyl, cap_ends=True, segments=8, radius1=0.0065, radius2=0.0055, depth=0.0045)
            bmesh.ops.rotate(cyl, verts=cyl.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
            bmesh.ops.translate(cyl, verts=cyl.verts, vec=p + Vector((sgn * 0.022, -0.0085, 0)))
            m2 = bpy.data.meshes.new("sn"); cyl.to_mesh(m2); cyl.free()
            snaps_m.append(m2)
            zk -= 0.088
        tops[sgn] = line[0]
    if plackets:
        ob = join_meshes("Mani_parka_placket", plackets)
        ob.data.materials.append(par_mat)
        for p in ob.data.polygons:
            p.use_smooth = True
        bind_rigid(ob, rig, "spine_02"); created.append(ob)
        t = join_meshes("Mani_parka_ziptape", tapes)
        t.data.materials.append(tape); bind_rigid(t, rig, "spine_02"); created.append(t)
        sn = join_meshes("Mani_parka_snaps", snaps_m)
        sn.data.materials.append(snap); bind_rigid(sn, rig, "spine_02"); created.append(sn)
        # zip puller: slider + tab on the left of the opening, near the collar
        if 1 in tops:
            p = tops[1] + Vector((-0.003, -0.012, -0.045))
            bm = bmesh.new()
            bmesh.ops.create_cube(bm, size=1.0)
            for v in bm.verts:
                v.co = Vector((v.co.x * 0.012, v.co.y * 0.004, v.co.z * 0.020)) + p
            m3 = bpy.data.meshes.new("pull"); bm.to_mesh(m3); bm.free()
            tab = tube("tab", [tuple(p + Vector((0, -0.003, -0.008))), tuple(p + Vector((0, -0.005, -0.032)))], 0.0045, sides=5)
            pu = join_meshes("Mani_zip_puller", [m3, tab])
            pu.data.materials.append(metal); bind_rigid(pu, rig, "spine_02"); created.append(pu)
    objs["parka_parts"] = created
    return created


# ---------------------------------------------------------------------------------------------
# lace-up ankle boots (lofted around each foot) + jeans hem
# ---------------------------------------------------------------------------------------------
def lerp_table(xs, ys, x):
    return float(np.interp(x, xs, ys))


def boot_plan_hw(t, wmax):
    if t <= 0:
        return 0.0
    if t >= 1:
        return 0.0
    if t < 0.62:
        u = abs((t - 0.62) / 0.62); p = 2.6
    else:
        u = abs((t - 0.62) / 0.38); p = 2.2
    return wmax / 2 * max(1 - u ** p, 0.0) ** (1 / p)


TOP_T = [0.0, 0.04, 0.12, 0.45, 0.50, 0.60, 0.70, 0.80, 0.90, 1.0]
TOP_Z = [0.100, 0.150, 0.160, 0.160, 0.152, 0.114, 0.084, 0.066, 0.053, 0.041]
SOLE_TOP = 0.030


def foot_frame(objs, s):
    hm, rig = objs["hm"], objs["rig"]
    names = vgroup_names(hm)
    me = hm.data
    pts = []
    for v in me.vertices:
        w = {names[g.group]: g.weight for g in v.groups if g.group in names}
        if w.get("foot_" + s, 0) + w.get("ball_" + s, 0) > 0.5 and v.co.z < 0.13:
            pts.append(v.co[:])
    pts = np.array(pts)
    ank = bone_pt(rig, "foot_" + s)
    ball = bone_pt(rig, "ball_" + s)
    F = Vector((ball.x - ank.x, ball.y - ank.y, 0)).normalized()
    Fn = np.array([F.x, F.y])
    proj = (pts[:, :2] - np.array([ank.x, ank.y])) @ Fn
    Rt = Vector((-F.y, F.x, 0))
    if (Rt.x > 0) != (s == "l"):
        Rt = -Rt
    lat = (pts[:, :2] - np.array([ank.x, ank.y])) @ np.array([Rt.x, Rt.y])
    amin, amax = proj.min(), proj.max()
    sel = (proj > amin + 0.5 * (amax - amin)) & (proj < amin + 0.8 * (amax - amin))
    wmax = float(lat[sel].max() - lat[sel].min()) + 0.020
    lat_c = float(0.5 * (lat[sel].max() + lat[sel].min()))
    O = Vector((ank.x, ank.y, 0)) + F * (amin - 0.010) + Rt * lat_c
    Lb = float(amax - amin) + 0.028
    return dict(O=O, F=F, Rt=Rt, L=Lb, W=wmax, ank=ank)


def to_world(fr, a, b, c):
    return fr["O"] + fr["F"] * a + fr["Rt"] * b + Vector((0, 0, c))


def loft_upper(fr, name, t0=0.0, t1=1.0, grow=0.0, n_st=20, n_sec=15):
    bm = bmesh.new()
    L, W = fr["L"], fr["W"]
    rows = []
    for i in range(n_st + 1):
        t = t0 + (t1 - t0) * i / n_st
        t = min(max(t, 0.004), 0.996)
        hw = boot_plan_hw(t, W) - 0.002 + grow
        top = lerp_table(TOP_T, TOP_Z, t) + grow
        e = 2.9 if t < 0.5 else 2.0 + 0.9 * (1 - (t - 0.5) / 0.5) ** 1.5
        hz = max(top - SOLE_TOP, 0.004)
        row = []
        for j in range(n_sec + 1):
            th = math.pi * j / n_sec
            cb, sb = math.cos(th), math.sin(th)
            b = hw * math.copysign(abs(cb) ** (2 / e), cb)
            c = SOLE_TOP - 0.002 + hz * (abs(sb) ** (2 / e))
            row.append(bm.verts.new(to_world(fr, t * L, b, c)))
        rows.append(row)
    for i in range(n_st):
        for j in range(n_sec):
            bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]))
    # close heel / toe ends
    if t0 <= 0.0:
        bm.faces.new(rows[0])
    if t1 >= 1.0:
        bm.faces.new(list(reversed(rows[-1])))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    return new_obj(name, me)


def make_sole(fr, name):
    L, W = fr["L"], fr["W"]
    bm = bmesh.new()
    n = 44
    outline = []
    for k in range(n):
        ang = 2 * math.pi * k / n
        # parametrise by angle around the plan: x along length, y across
        ca, sa = math.cos(ang), math.sin(ang)
        # sample the plan by t (0..1) on each side
        outline.append(ang)
    ring_pts = []
    ts = [i / 22 for i in range(1, 22)]
    side_a = [(t, boot_plan_hw(t, W) + 0.0045) for t in ts]
    # outer ring: toe -> heel on +b side, then heel -> toe on -b side
    pts = [(0.0, 0.0)] + [(t, h) for t, h in side_a] + [(1.0, 0.0)] + [(t, -h) for t, h in reversed(side_a)]
    ring_bot, ring_top = [], []
    for t, b in pts:
        ring_bot.append(bm.verts.new(to_world(fr, t * L + (0.003 if t == 0 else (-0.003 if t == 1.0 else 0)), b, 0.007)))
        ring_top.append(bm.verts.new(to_world(fr, t * L, b * 1.0, SOLE_TOP)))
    m = len(pts)
    for i in range(m):
        j = (i + 1) % m
        bm.faces.new((ring_bot[i], ring_bot[j], ring_top[j], ring_top[i]))
    bm.faces.new(list(reversed(ring_bot)))
    bm.faces.new(ring_top)
    # tread lugs under the sole + heel block
    for k in range(13):
        t = 0.34 + k * 0.047 if k < 13 else 0
        if t > 0.95:
            continue
        hw = boot_plan_hw(t, W) * 0.78
        cuboid = bmesh.new()
        bmesh.ops.create_cube(cuboid, size=1.0)
        for v in cuboid.verts:
            v.co = Vector((v.co.x * 0.016, v.co.y * (2 * hw), v.co.z * 0.0075)) + Vector((0, 0, 0.0035))
        mat = Matrix.Identity(3)
        for v in cuboid.verts:
            lo = v.co
            v.co = to_world(fr, t * L + lo.x, lo.y, lo.z)
        mm = bpy.data.meshes.new("lug"); cuboid.to_mesh(mm); cuboid.free()
        bm.from_mesh(mm); bpy.data.meshes.remove(mm)
    # heel block
    hb = bmesh.new()
    bmesh.ops.create_cube(hb, size=1.0)
    for v in hb.verts:
        lo = Vector((v.co.x * 0.07, v.co.y * (boot_plan_hw(0.13, W) * 1.7), v.co.z * 0.0075 + 0.0035))
        v.co = to_world(fr, 0.17 * L * 0.5 + 0.012 + lo.x, lo.y, lo.z)
    mh = bpy.data.meshes.new("heel"); hb.to_mesh(mh); hb.free()
    bm.from_mesh(mh); bpy.data.meshes.remove(mh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    return new_obj(name, me)


def boot_details(fr, s):
    """Eyelets, laces (criss-cross + bow), collar ring."""
    L, W = fr["L"], fr["W"]
    eyelets, laces = [], []
    ts = np.linspace(0.745, 0.535, 7)
    pairs = []
    for t in ts:
        top = lerp_table(TOP_T, TOP_Z, t)
        hw = boot_plan_hw(t, W) - 0.002
        e = 2.0 + 0.9 * (1 - (t - 0.5) / 0.5) ** 1.5 if t >= 0.5 else 2.9
        b = 0.0165
        th = math.acos(min(b / max(hw, 1e-4), 0.98))
        c = SOLE_TOP - 0.002 + (top - SOLE_TOP) * (abs(math.sin(th)) ** (2 / e))
        # offset slightly out of the surface
        pairs.append((to_world(fr, t * L, b, c + 0.0015), to_world(fr, t * L, -b, c + 0.0015)))
    for pl, pr in pairs:
        for p in (pl, pr):
            cone = bmesh.new()
            bmesh.ops.create_cone(cone, cap_ends=True, segments=6, radius1=0.0042, radius2=0.0042, depth=0.0016)
            bmesh.ops.translate(cone, verts=cone.verts, vec=p + Vector((0, 0, 0.0004)))
            m_ = bpy.data.meshes.new("ey"); cone.to_mesh(m_); cone.free()
            eyelets.append(m_)
    for i in range(len(pairs) - 1):
        a0, b0 = pairs[i]; a1, b1 = pairs[i + 1]
        lift = Vector((0, 0, 0.0035))
        laces.append(tube("lc", [tuple(a0 + lift), tuple((a0 + b1) / 2 + lift * 1.8), tuple(b1 + lift)], 0.0018, sides=4))
        laces.append(tube("lc", [tuple(b0 + lift), tuple((b0 + a1) / 2 + lift * 1.8), tuple(a1 + lift)], 0.0018, sides=4))
    top_l, top_r = pairs[-1]
    mid = (top_l + top_r) / 2 + Vector((0, 0, 0.004))
    for sg in (1, -1):
        laces.append(tube("bow", [tuple(mid), tuple(mid + fr["Rt"] * sg * 0.012 + Vector((0, 0, 0.010)) + fr["F"] * -0.004),
                                  tuple(mid + fr["Rt"] * sg * 0.024 + Vector((0, 0, 0.002)) + fr["F"] * -0.006),
                                  tuple(mid + fr["Rt"] * sg * 0.012 - fr["F"] * 0.010)], 0.0017, sides=4))
        laces.append(tube("end", [tuple(mid), tuple(mid + fr["Rt"] * sg * 0.008 - fr["F"] * 0.022 + Vector((0, 0, -0.012)))], 0.0017, sides=4))
    # padded collar ring at the top of the shaft
    t_c = 0.27
    pts = []
    for a in np.linspace(0, 2 * math.pi, 22)[:-1]:
        pts.append(tuple(to_world(fr, t_c * L + 0.056 * math.cos(a) * 1.0, 0.049 * math.sin(a), 0.160)))
    collar = tube("cuffring", pts, 0.0075, closed=True, sides=6)
    return eyelets, laces, collar


def weight_foot(ob, rig, s):
    vg_f = ob.vertex_groups.new(name="foot_" + s)
    vg_c = ob.vertex_groups.new(name="calf_" + s)
    for v in ob.data.vertices:
        z = (ob.matrix_world @ v.co).z
        wc = float(smoothstep(0.095, 0.165, z))
        if wc < 0.999:
            vg_f.add([v.index], 1 - wc, "REPLACE")
        if wc > 0.001:
            vg_c.add([v.index], wc, "REPLACE")
    ob.parent = rig
    ob.matrix_parent_inverse = rig.matrix_world.inverted()
    m = ob.modifiers.new("Armature", "ARMATURE"); m.object = rig
    for p in ob.data.polygons:
        p.use_smooth = True


def leather_textures(size=1024):
    h = w = size
    n_fine = value_noise(h, w, 260, 51) - 0.5
    n_mid = value_noise(h, w, 40, 52) - 0.5
    n_big = value_noise(h, w, 5, 53) - 0.5
    cells = np.abs(value_noise(h, w, 150, 54) - 0.5) * 2
    grain = smoothstep(0.0, 0.25, cells)
    lum = 1 + n_fine * 0.18 + n_mid * 0.28 + n_big * 0.45 - (1 - grain) * 0.25
    col = np.array([0.20, 0.105, 0.058])[None, None, :] * lum[..., None]
    return save_raw("mani_leather_c", col, fmt="JPEG"), save_raw("mani_leather_n", height_to_normal(grain * 0.7 + n_fine * 0.5, 2.2), fmt="JPEG")


def build_boots(objs):
    rig = objs["rig"]
    lc, ln = leather_textures()
    leather = make_material("Mani_leather", lc, rough=0.55, normal_path=ln, normal_strength=0.9, spec=0.45, double_sided=True)
    rubber = make_material("Mani_sole", color=(0.028, 0.026, 0.025), rough=0.9, spec=0.2)
    lace_m = make_material("Mani_laces", color=(0.30, 0.22, 0.13), rough=0.9, spec=0.1)
    eyelet_m = make_material("Mani_eyelets", color=(0.22, 0.16, 0.08), rough=0.35, metal=0.9)
    objs["boots"] = []
    objs["boot_frames"] = {}
    for s in ("l", "r"):
        fr = foot_frame(objs, s)
        objs["boot_frames"][s] = fr
        up = loft_upper(fr, "Mani_boot_" + s)
        for p in up.data.polygons:
            pass
        bm = bmesh.new(); bm.from_mesh(up.data)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        planar_uv(bm, 1 / 0.22)
        bm.to_mesh(up.data); bm.free()
        up.data.materials.append(leather)
        weight_foot(up, rig, s)
        toe = loft_upper(fr, "Mani_boot_toecap_" + s, t0=0.80, t1=1.0, grow=0.0013, n_st=6)
        bm = bmesh.new(); bm.from_mesh(toe.data)
        for f in list(bm.faces):
            if len(f.verts) > 4:
                bm.faces.remove(f)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        planar_uv(bm, 1 / 0.22)
        bm.to_mesh(toe.data); bm.free()
        toe.data.materials.append(leather)
        weight_foot(toe, rig, s)
        sole = make_sole(fr, "Mani_sole_" + s)
        sole.data.materials.append(rubber)
        weight_foot(sole, rig, s)
        eye, lac, col = boot_details(fr, s)
        e = join_meshes("Mani_eyelets_" + s, eye); e.data.materials.append(eyelet_m); weight_foot(e, rig, s)
        l_ = join_meshes("Mani_laces_" + s, lac); l_.data.materials.append(lace_m); weight_foot(l_, rig, s)
        c_ = new_obj("Mani_bootcuff_" + s, col); c_.data.materials.append(leather); weight_foot(c_, rig, s)
        objs["boots"] += [up, toe, sole, e, l_, c_]
    log("boots built")
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.data.name = ob.name + "_mesh"


def fit_jeans(objs):
    jeans = objs["jeans"]
    hem = 0.138
    bm = bmesh.new(); bm.from_mesh(jeans.data)
    low = [v for v in bm.verts if v.co.z < hem]
    bmesh.ops.delete(bm, geom=low, context="VERTS")
    centres = {s: objs["boot_frames"][s]["ank"] for s in ("l", "r")}
    hem_r = []
    for v in bm.verts:
        if v.co.z < hem + 0.012:
            c = centres["l"] if v.co.x > 0 else centres["r"]
            hem_r.append(math.hypot(v.co.x - c.x, v.co.y - c.y))
    mean_r = float(np.mean(hem_r)) if hem_r else 0.05
    target = 0.0585
    k = max(target / mean_r - 1.0, 0.0)
    log("jeans hem radius %.3f -> %.3f (k %.2f)" % (mean_r, target, k))
    for v in bm.verts:
        z = v.co.z
        if z < 0.30:
            c = centres["l"] if v.co.x > 0 else centres["r"]
            f = 1 + k * float(smoothstep(0.30, hem, z))
            v.co.x = c.x + (v.co.x - c.x) * f
            v.co.y = c.y + (v.co.y - c.y) * f
    bm.to_mesh(jeans.data); bm.free()


# ---------------------------------------------------------------------------------------------
# glasses lenses, hoodie drawstrings
# ---------------------------------------------------------------------------------------------
def build_lenses(objs):
    g = objs["glasses_params"]
    rig = objs["rig"]
    meshes = []
    for sgn in (1, -1):
        pts = rounded_rect(g["cxs"], g["cz"], g["lw"] - 0.0006, g["lh"] - 0.0006, g["lr"], g["gy"] + 0.0006, n=5)
        bm = bmesh.new()
        vs = [bm.verts.new((sgn * p[0], p[1], p[2])) for p in pts]
        bm.faces.new(vs if sgn > 0 else list(reversed(vs)))
        bmesh.ops.triangulate(bm, faces=bm.faces)
        me = bpy.data.meshes.new("lens"); bm.to_mesh(me); bm.free()
        meshes.append(me)
    ob = join_meshes("Mani_lenses", meshes)
    mat = make_material("Mani_lens", color=(0.55, 0.62, 0.68), rough=0.02, spec=0.6, alpha_const=0.07, double_sided=True)
    ob.data.materials.append(mat)
    bind_rigid(ob, rig, "head")
    objs["lenses"] = ob


def build_drawstrings(objs):
    from mathutils.bvhtree import BVHTree
    hoodie, rig = objs["hoodie"], objs["rig"]
    tmp = bmesh.new(); tmp.from_mesh(hoodie.data)
    tree = BVHTree.FromBMesh(tmp)
    top = max(v.co.z for v in tmp.verts if abs(v.co.x) < 0.06)
    tmp.free()
    cords = []
    for sgn in (1, -1):
        x = sgn * 0.034
        pts = []
        for k, z in enumerate(np.linspace(top - 0.045, top - 0.215, 10)):
            hit = tree.ray_cast(Vector((x + sgn * 0.0012 * k * 0.0, -0.6, z)), Vector((0, 1, 0)))
            if hit[0] is None:
                continue
            drift = sgn * 0.004 * math.sin(k * 0.7)
            pts.append(tuple(hit[0] + Vector((drift, -0.0045, 0))))
        if len(pts) > 3:
            cords.append(tube("cord", pts, 0.0030, sides=5))
            end = Vector(pts[-1])
            cyl = bmesh.new()
            bmesh.ops.create_cone(cyl, cap_ends=True, segments=6, radius1=0.0036, radius2=0.0036, depth=0.016)
            bmesh.ops.translate(cyl, verts=cyl.verts, vec=end + Vector((0, 0, -0.006)))
            m = bpy.data.meshes.new("agl"); cyl.to_mesh(m); cyl.free()
            cords.append(m)
    if cords:
        ob = join_meshes("Mani_drawstrings", cords)
        ob.data.materials.append(make_material("Mani_cord", color=(0.10, 0.10, 0.11), rough=0.95, spec=0.05))
        bind_rigid(ob, rig, "spine_03")
        objs["drawstrings"] = ob
