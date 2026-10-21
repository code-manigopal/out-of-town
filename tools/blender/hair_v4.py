"""Mani v4 hair: thick curly black hair grown with Blender's hair curves + Geometry Nodes, baked to game hair cards.

Pipeline (all inside Blender, called from mani_v2.main_entry):
  1. HairShape: target volume from the approved sheet (short sides/back, full rounded curly top, a few curls
     at the front hairline) as a thickness field over the scalp, plus the hairline curve.
  2. The pack's scalp mesh is trimmed to the hairline, made a dense dark skullcap (opaque, rooted under every card),
     and a second opaque, lumpy "shell" carries the volume/silhouette so no skin or gap ever shows between the
     hairline and the curls.
  3. Guide curves are placed on the scalp (area x density), pushed into Blender's own *Essentials hair assets*
     (procedural_hair_node_assets.blend): "Curl Hair Curves" then "Clump Hair Curves" evaluated by a Geometry
     Nodes modifier on a Curves object -> real curly strands.
  4. Each curled strand is resampled to a few points and extruded into a flat alpha card (about 12 triangles) with a
     curly-strand alpha atlas -> game-friendly mesh, rigid to the head bone.
"""
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Vector

import build_mani as B
from build_mani import (log, make_material, save_raw, smoothstep, value_noise, height_to_normal, set_single_material,
                        bind_rigid, new_obj, HAIR_RGB)

ASSETS = "/Applications/Blender.app/Contents/Resources/5.2/datafiles/assets/nodes/procedural_hair_node_assets.blend"
UP = Vector((0, 0, 1))


# ---------------------------------------------------------------------------------------------
# target shape
# ---------------------------------------------------------------------------------------------
class HairShape:
    """Thickness / hairline fields in head space (z up, face toward -y). ez = eye line, ey = ear y."""

    def __init__(self, ez, ey, chin_z, skull_top_z):
        self.ez, self.ey = ez, ey
        self.c = np.array([0.0, ey, ez + 0.02])
        # sheet: the hair apex sits 1.16 x (pupil-to-chin) above the pupils (front 1.17, profile 1.15)
        self.top_z = ez + 1.16 * (ez - chin_z)
        self.top_t = 0.028        # overlay-calibrated: sheet hair apex is ~2.5 cm above the 1.16-ratio estimate

    def hairline_z(self, x, y):
        ez, ey = self.ez, self.ey
        ax = np.abs(x)
        z_front = ez + 0.074 - 0.064 * smoothstep(0.015, 0.068, ax)          # high at the centre, receding temples
        z_ear = ez + 0.012 + 0.0 * ax                                          # above the ear
        z_back = ez - 0.030 - 0.050 * smoothstep(ey + 0.04, ey + 0.10, y)       # nape
        a = smoothstep(ey - 0.075, ey - 0.040, y)                              # front -> ear blend
        b = smoothstep(ey + 0.030, ey + 0.055, y)                              # ear -> back blend
        zf = z_front * (1 - a) + z_ear * a
        return zf * (1 - b) + z_back * b

    def in_hair(self, P):
        P = np.atleast_2d(P)
        return P[:, 2] > self.hairline_z(P[:, 0], P[:, 1])

    def cap_line(self, x, y):
        """Where the opaque scalp cap / shell starts: 1.2 cm above the skin hairline at the front (the painted
        texture covers the gap, front curls hang over it), at the hairline elsewhere."""
        a = 1 - smoothstep(self.ey - 0.075, self.ey - 0.030, y)
        return self.hairline_z(x, y) + 0.016 * a

    def thick(self, P):
        """Hair thickness (m) above the scalp at scalp points P."""
        P = np.atleast_2d(P)
        z = P[:, 2] - self.ez
        top = smoothstep(0.030, 0.100, z)
        side = 0.004 + 0.003 * (P[:, 1] > self.ey)
        t = side + (self.top_t - side) * top ** 1.15
        # fringe: a bit more length right behind the front hairline
        fr = (P[:, 1] < self.ey - 0.05) * smoothstep(0.0, 0.035, P[:, 2] - self.hairline_z(P[:, 0], P[:, 1]) + 0.004)
        return t + 0.014 * fr * (1 - top)


# ---------------------------------------------------------------------------------------------
# textures
# ---------------------------------------------------------------------------------------------
def _stamp(a, x, y, r, val):
    h, w = a.shape[:2]
    xi, yi = int(round(x)), int(round(y))
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r + 0.3:
                px, py = xi + dx, yi + dy
                if 0 <= px < w and 0 <= py < h:
                    a[py, px] = max(a[py, px], val)


def card_atlas(name="mani_haircards4", cols=4, rows=2, TW=256, TH=512, seed=14):
    """Alpha atlas of dense curly strand locks. Row index = v (0 root ... 1 tip) in Blender's bottom-up order."""
    rng = np.random.RandomState(seed)
    W, H = TW * cols, TH * rows
    rgba = np.zeros((H, W, 4), np.float32)
    n_tiles = cols * rows
    for t in range(n_tiles):
        ox, oy = (t % cols) * TW, (t // cols) * TH
        alpha = np.zeros((TH, TW), np.float32)
        shade = np.zeros((TH, TW), np.float32)
        nstr = 70
        for s in range(nstr):
            x0 = TW * (0.5 + rng.normal(0, 0.17))
            x0 = float(np.clip(x0, 14, TW - 14))
            turns = rng.uniform(4.0, 8.0)
            amp = rng.uniform(5, 11)
            phase = rng.uniform(0, 6.28)
            length = TH * rng.uniform(0.60, 0.99) * (1 - 0.25 * abs(x0 / TW - 0.5))
            drift = rng.normal(0, 0.10)
            br = rng.uniform(0.7, 1.6)
            n = int(length * 1.3)
            for i in range(n):
                v = i / n
                yy = v * length
                xx = x0 + amp * math.sin(turns * 6.283 * v + phase) * (0.35 + 0.65 * v) + drift * yy
                # a tighter secondary curl riding the main one
                xx += 2.4 * math.sin(turns * 6.283 * v * 3.1 + phase * 2)
                yy += 2.8 * math.cos(turns * 6.283 * v * 3.1 + phase * 2)
                r = 4 if v < 0.45 else (3 if v < 0.8 else 2)
                _stamp(alpha, xx, yy, r, 1.0)
                _stamp(shade, xx, yy, r, br)
        # solid root band so nothing see-through sits at the scalp, feathered into the strands
        yy = np.arange(TH)[:, None] / TH
        xx = np.arange(TW)[None, :] / TW
        root = (1 - smoothstep(0.10, 0.26, yy)) * smoothstep(0.02, 0.16, xx) * (1 - smoothstep(0.84, 0.98, xx))
        ragged = value_noise(TH, TW, 90, 40 + t)
        alpha = np.maximum(alpha, (root > 0.35 + 0.35 * ragged).astype(np.float32))
        shade = np.where(shade == 0, 1.0, shade)
        rgba[oy:oy + TH, ox:ox + TW, 3] = alpha
        base = np.array([0.020, 0.0155, 0.0150])
        glint = np.array([0.045, 0.033, 0.027])
        k = np.clip((shade - 0.85) / 0.9, 0, 1)[..., None] * (yy > 0.18)[..., None]
        rgba[oy:oy + TH, ox:ox + TW, :3] = (base * (0.7 + 0.8 * shade[..., None]) * (1 - k) + glint * k * 0.8)
    return save_raw(name + "_c", rgba)


def shell_textures(name="mani_hairshell4", S=1024):
    """Opaque dark dense curl texture (albedo + normal) for the scalp skullcap and shell."""
    r1 = np.abs(value_noise(S, S, 90, 61) - 0.5) * 2
    r2 = np.abs(value_noise(S, S, 210, 62) - 0.5) * 2
    r3 = np.abs(value_noise(S, S, 420, 63) - 0.5) * 2
    clump = 1 - (r1 * 0.45 + r2 * 0.35 + r3 * 0.20)
    lum = (0.45 + 1.5 * clump ** 2.2)[..., None]
    rgb = np.clip(lum, 0.3, 2.6) * np.array([0.018, 0.0145, 0.0140])[None, None, :]
    c = save_raw(name + "_c", rgb)
    n = save_raw(name + "_n", height_to_normal(clump, 6.0))
    return c, n


# ---------------------------------------------------------------------------------------------
# geometry helpers
# ---------------------------------------------------------------------------------------------
def spherical_uv(bm, c, tile=1.0):
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops:
            p = l.vert.co - Vector(c)
            u = (math.atan2(p.x, -p.y) / (2 * math.pi) + 0.5) * tile
            v = (0.5 + math.atan2(p.z, math.hypot(p.x, p.y)) / math.pi) * tile * 2.0
            l[uv].uv = (u % 1.0 if tile == 1.0 else u, v)


def mesh_to_arrays(me):
    co = np.array([v.co[:] for v in me.vertices])
    tris = []
    for p in me.polygons:
        vs = list(p.vertices)
        for k in range(1, len(vs) - 1):
            tris.append((vs[0], vs[k], vs[k + 1]))
    return co, np.array(tris)


def sample_surface(co, tris, count, weight, rng):
    a, b, c = co[tris[:, 0]], co[tris[:, 1]], co[tris[:, 2]]
    cr = np.cross(b - a, c - a)
    area = np.linalg.norm(cr, axis=1) * 0.5
    cen = (a + b + c) / 3
    w = area * weight(cen)
    idx = rng.choice(len(w), size=count, p=w / w.sum())
    r1, r2 = rng.rand(count), rng.rand(count)
    flip = r1 + r2 > 1
    r1[flip], r2[flip] = 1 - r1[flip], 1 - r2[flip]
    return a[idx] + (b[idx] - a[idx]) * r1[:, None] + (c[idx] - a[idx]) * r2[:, None]


# ---------------------------------------------------------------------------------------------
# Geometry Nodes: curl + clump with the Essentials hair assets
# ---------------------------------------------------------------------------------------------
_ASSET_CACHE = {}


def load_assets():
    if _ASSET_CACHE:
        return _ASSET_CACHE
    with bpy.data.libraries.load(ASSETS, link=False) as (src, dst):
        dst.node_groups = [n for n in src.node_groups if n in ("Curl Hair Curves", "Clump Hair Curves", "Hair Curves Noise",
                                                               "Frizz Hair Curves")]
    for g in bpy.data.node_groups:
        _ASSET_CACHE[g.name] = g
    return _ASSET_CACHE


def grow_curls(guides, chain, name="hair_gn"):
    """guides: list of [P, 3] polylines (same point count). chain: [(asset name, {input: value})].
    Returns the evaluated curves as an array [n_curves, n_points, 3]."""
    assets = load_assets()
    n, k = len(guides), len(guides[0])
    cu = bpy.data.hair_curves.new(name)
    cu.add_curves([k] * n)
    cu.attributes["position"].data.foreach_set("vector", np.array(guides, np.float32).ravel())
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    mod = ob.modifiers.new("gn", "NODES")
    ng = bpy.data.node_groups.new(name + "_tree", "GeometryNodeTree")
    ng.interface.new_socket("Geometry", in_out="INPUT", socket_type="NodeSocketGeometry")
    ng.interface.new_socket("Geometry", in_out="OUTPUT", socket_type="NodeSocketGeometry")
    gi, go = ng.nodes.new("NodeGroupInput"), ng.nodes.new("NodeGroupOutput")
    prev = gi.outputs[0]
    for asset, vals in chain:
        nd = ng.nodes.new("GeometryNodeGroup")
        nd.node_tree = assets[asset]
        for key, v in vals.items():
            nd.inputs[key].default_value = v
        ng.links.new(prev, nd.inputs["Geometry"])
        prev = nd.outputs["Geometry"]
    ng.links.new(prev, go.inputs[0])
    mod.node_group = ng
    dg = bpy.context.evaluated_depsgraph_get()
    d = ob.evaluated_get(dg).data
    pos = np.zeros(len(d.points) * 3, np.float32)
    d.attributes["position"].data.foreach_get("vector", pos)
    out = pos.reshape(len(d.curves), -1, 3)
    bpy.data.objects.remove(ob)
    bpy.data.hair_curves.remove(cu)
    bpy.data.node_groups.remove(ng)
    return out.astype(np.float64)


def resample(curve, m):
    """Arc-length resample of [P,3] polyline to m points."""
    seg = np.linalg.norm(np.diff(curve, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    t = np.linspace(0, s[-1], m)
    return np.stack([np.interp(t, s, curve[:, i]) for i in range(3)], 1)


# ---------------------------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------------------------
def build(objs, atl=None, n_cards=1350, seed=33):
    L, rig = objs["L"], objs["rig"]
    cap = objs["hair"]
    ez = float(L["eye_l"][2])
    ey = float(np.mean(np.concatenate([L["ear_l"], L["ear_r"]])[:, 1]))
    rng = np.random.RandomState(seed)
    c0 = Vector((0, ey, ez + 0.02))
    # scalp: the pack's mesh nudged out so it never z-fights with the skin
    for v in cap.data.vertices:
        v.co += (v.co - c0).normalized() * 0.0030
    co, tris = mesh_to_arrays(cap.data)
    shape = HairShape(ez, ey, float(L["chin_z"]), float(co[:, 2].max()))
    log("hair: eye z %.3f skull top %.3f -> hair top %.3f (thickness %.3f)" % (ez, co[:, 2].max(), shape.top_z, shape.top_t))
    objs["hair_shape"] = shape
    # ---- trim to the hairline -----------------------------------------------------------------
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    kill = [f for f in bm.faces if f.calc_center_median().z <= float(shape.cap_line(f.calc_center_median().x, f.calc_center_median().y))]
    bmesh.ops.delete(bm, geom=kill, context="FACES")
    for v in [v for v in bm.verts if not v.link_faces]:
        bm.verts.remove(v)
    spherical_uv(bm, c0)
    bm.to_mesh(cap.data)
    shell_bm = bm.copy()
    bm.free()
    sc_c, sc_n = shell_textures()
    set_single_material(cap, make_material("Mani_scalp", sc_c, rough=0.85, spec=0.04, normal_path=sc_n, normal_strength=0.8))
    cap.name = "Mani_scalp"
    # ---- shell: the opaque lumpy volume under the cards -------------------------------------------
    SHELL_K = 0.42
    for v in shell_bm.verts:
        p = np.array(v.co)
        t = float(shape.thick(p)[0])
        n = (v.co - c0).normalized()
        top = float(smoothstep(0.03, 0.10, p[2] - ez))
        d = (n * (1 - 0.30 * top) + UP * 0.30 * top).normalized()
        lump = 0.5 + 0.5 * B_noise(p, 60.0) * 0.9 + 0.5 * B_noise(p, 130.0) * 0.5
        front = p[1] < ey - 0.05 and abs(p[0]) < 0.07
        ramp = 0.12 + 0.88 * float(smoothstep(0.0, 0.028, p[2] - float(shape.cap_line(p[0], p[1]))))   # flush at the cap edge
        v.co = v.co + d * (SHELL_K * t * (0.70 + 0.60 * lump) * ramp) + (Vector((0, -0.003, 0.003)) * ramp if front else Vector())
    me = bpy.data.meshes.new("Mani_hairshell")
    shell_bm.to_mesh(me)
    shell_bm.free()
    log("hair shell validate: %s" % me.validate(verbose=True))
    me.update()
    shell = new_obj("Mani_hairshell", me)
    for p in me.polygons:
        p.use_smooth = True
    shell.data.materials.append(make_material("Mani_hairshell", sc_c, rough=0.85, spec=0.04, normal_path=sc_n, normal_strength=1.0))
    bind_rigid(shell, rig, "head")
    objs["hair_shell"] = shell
    # ---- guides: roots ride on the shell surface ----------------------------------------------------
    cs, ts = mesh_to_arrays(shell.data)
    sn = np.zeros_like(cs)
    for t_ in ts:
        nn = np.cross(cs[t_[1]] - cs[t_[0]], cs[t_[2]] - cs[t_[0]])
        for k in t_:
            sn[k] += nn
    sn /= np.maximum(np.linalg.norm(sn, axis=1, keepdims=True), 1e-9)

    def weight(cen):
        h = cen[:, 2] - ez
        top = smoothstep(0.0, 0.09, h)
        near = 1 - smoothstep(0.0, 0.032, cen[:, 2] - shape.cap_line(cen[:, 0], cen[:, 1]))
        nrm = cen - shape.c
        nrm = nrm / np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-9)
        fronty = (nrm[:, 1] < -0.50) * (np.abs(cen[:, 0]) < 0.062) * smoothstep(0.0, 0.03, h)
        return 0.45 + 1.7 * top + 5.0 * near + 2.2 * fronty

    roots = sample_surface(cs, ts, n_cards, weight, rng)
    groups = {"low": [], "top": [], "front": []}
    meta = {}
    for P in roots:
        h = P[2] - ez
        top = float(smoothstep(0.02, 0.095, h))
        n = P - shape.c
        n /= np.linalg.norm(n)
        t = float(shape.thick(P)[0])
        hl = shape.hairline_z(P[0], P[1])
        front = (P[1] < ey - 0.02 and abs(P[0]) < 0.095 and P[2] < shape.cap_line(P[0], P[1]) + 0.026) or (n[1] < -0.55 and abs(P[0]) < 0.055 and P[2] < ez + 0.105 and P[2] > hl + 0.03)
        if front:
            # fringe: curls lie forward over the shell (never over the face), so no flat shell shows above the hairline
            # fringe: curls hang forward / down over the cap edge and the painted hairline (never over the eyes)
            d = n * 0.70 + np.array([0, -0.10, -0.12]) + rng.normal(0, 0.20, 3)
            L_ = max(t * rng.uniform(0.9, 1.3), 0.026)
            key = "front"
        elif top > 0.35:
            d = n * (0.75 - 0.25 * top) + np.array([0, 0, 0.18 + 0.38 * top]) + rng.normal(0, 0.30, 3)
            L_ = max(t * (1 - SHELL_K * 0.75) * rng.uniform(1.0, 1.45), 0.022)
            key = "top"
        else:
            d = n * 0.40 + np.array([0, 0.55, -0.10]) + rng.normal(0, 0.22, 3)
            L_ = max(t * (1 - SHELL_K * 0.75) * rng.uniform(0.9, 1.3), 0.014)
            key = "low"
        d /= np.linalg.norm(d)
        root = P - n * 0.003
        path = []
        for k in range(8):
            s_ = k / 7.0
            path.append(root + d * (L_ * s_) + np.array([0, 0, -1.0]) * (0.18 * L_ * s_ * s_) + n * (0.08 * L_ * s_))
        groups[key].append(np.array(path))
        meta.setdefault(key, []).append((n, t))
    cfg = {"low": dict(Radius=0.0035, Frequency=2.4, Subdivision=2, **{"Random Offset": 1.0}),
           "top": dict(Radius=0.0055, Frequency=3.0, Subdivision=2, **{"Random Offset": 1.0}),
           "front": dict(Radius=0.0065, Frequency=2.2, Subdivision=2, **{"Random Offset": 1.0})}
    cards = []
    for key, g in groups.items():
        if not g:
            continue
        chain = [("Curl Hair Curves", dict(cfg[key], **{"Curl Start": 0.0, "Seed": 3, "Guide Distance": 0.0})),
                 ("Clump Hair Curves", {"Factor": 0.25, "Shape": 0.3, "Tip Spread": 0.004, "Guide Distance": 0.0035})]
        curved = grow_curls(g, chain, "hair_" + key)
        gg = np.array(g)
        dev = np.linalg.norm(curved[:, 0] - gg[:, 0], axis=1)
        ln = np.linalg.norm(curved[:, -1] - curved[:, 0], axis=1)
        log("hair %s: %d strands x %d points; root moved mean %.4f max %.4f; span mean %.4f max %.4f; guide span %.4f" % (
            key, curved.shape[0], curved.shape[1], dev.mean(), dev.max(), ln.mean(), ln.max(),
            np.linalg.norm(gg[:, -1] - gg[:, 0], axis=1).mean()))
        for cv, (n, t) in zip(curved, meta[key]):
            cards.append((key, cv, n, t))
    # ---- cards ------------------------------------------------------------------------------------------
    atl = atl or card_atlas()
    cols, rows_t = 4, 2
    bmc = bmesh.new()
    uvl = bmc.loops.layers.uv.new("UVMap")
    ntri = 0
    for key, cv, n, t in cards:
        m = 7 if key == "top" else 6
        pts = resample(cv, m)
        w0 = {"low": 0.024, "top": 0.040, "front": 0.028}[key] * rng.uniform(0.85, 1.25)
        tile = int(rng.randint(cols * rows_t))
        tx, ty = (tile % cols) / cols, (tile // cols) / rows_t
        flip = rng.rand() < 0.5
        verts = []
        for i in range(m):
            s_ = i / (m - 1)
            tg = pts[min(i + 1, m - 1)] - pts[max(i - 1, 0)]
            tg /= max(np.linalg.norm(tg), 1e-9)
            wv = np.cross(tg, n)
            if np.linalg.norm(wv) < 1e-6:
                wv = np.cross(tg, np.array([0, 1.0, 0]))
            wv /= np.linalg.norm(wv)
            hw = w0 * 0.5 * (1.0 - 0.30 * s_)
            va = bmc.verts.new(Vector(pts[i] - wv * hw))
            vb = bmc.verts.new(Vector(pts[i] + wv * hw))
            verts.append((va, vb, s_))
        for i in range(m - 1):
            q = [verts[i][0], verts[i][1], verts[i + 1][1], verts[i + 1][0]]
            f = bmc.faces.new(q)
            uu = [0, 1, 1, 0] if not flip else [1, 0, 0, 1]
            vv = [verts[i][2], verts[i][2], verts[i + 1][2], verts[i + 1][2]]
            for lp, u_, v_ in zip(f.loops, uu, vv):
                lp[uvl].uv = (tx + (0.01 + 0.98 * u_) / cols, ty + (0.005 + 0.99 * v_) / rows_t)
            ntri += 2
    me = bpy.data.meshes.new("Mani_haircards")
    bmc.to_mesh(me)
    bmc.free()
    ob = new_obj("Mani_hair", me)
    for p in me.polygons:
        p.use_smooth = True
    ob.data.materials.append(make_material("Mani_haircards", atl, rough=0.85, spec=0.03, alpha_clip=True, double_sided=True,
                                           alpha_cutoff=0.5))
    bind_rigid(ob, rig, "head")
    objs["hair_cards"] = ob
    log("hair cards: %d cards, %d tris; scalp %d tris, shell %d tris" % (len(cards), ntri, sum(len(p.vertices) - 2 for p in cap.data.polygons),
                                                                       sum(len(p.vertices) - 2 for p in shell.data.polygons)))
    return ob


def B_noise(p, f):
    from mathutils import noise as mn
    return mn.noise(Vector((p[0] * f, p[1] * f + 11.3, p[2] * f - 5.1)))
