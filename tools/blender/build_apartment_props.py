"""
Out of Town - Mani's Windsor apartment: furniture, fixtures and story props.

Run headless (re-runnable, deterministic):
    /opt/homebrew/bin/blender -b -P tools/blender/build_apartment_props.py

Outputs
    game/environments/windsor/apartment/models/<asset>.glb      (one per asset)
    art_source/environments/windsor/apartment_props.blend       (whole scene, laid out in rows)

Conventions
    * metres, real scale, Z up in Blender (glTF export converts to Y up)
    * every asset is built at the origin: X/Y centred on the asset, Z = 0 at the lowest point
      (wall-mounted items: Z = 0 is their bottom edge; see ASSET_NOTES)
    * the front of every asset faces -Y in Blender (glTF/Godot: +Z, the glTF "front" axis)
    * UVs are box-projected at 1 UV unit = 1 m, except photo surfaces (0..1 so an image maps whole)
    * material slots use the names Godot is expected to remap (mat_*)
"""
import bpy
import bmesh
import math
import os
import random
from contextlib import contextmanager
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_GLB = os.path.join(ROOT, "game", "environments", "windsor", "apartment", "models")
OUT_BLEND = os.path.join(ROOT, "art_source", "environments", "windsor", "apartment_props.blend")

V = Vector


def T(x, y, z):
    return Matrix.Translation((x, y, z))


def Rx(a):
    return Matrix.Rotation(math.radians(a), 4, "X")


def Ry(a):
    return Matrix.Rotation(math.radians(a), 4, "Y")


def Rz(a):
    return Matrix.Rotation(math.radians(a), 4, "Z")


def S(x, y, z):
    return Matrix.Diagonal((x, y, z, 1.0))


# --------------------------------------------------------------------------------------
# Materials
# --------------------------------------------------------------------------------------
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


MATS = {}


def make_mat(name, hexc, rough=0.5, metal=0.0, alpha=1.0, spec=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    r, g, b = hexcol(hexc)
    bsdf.inputs["Base Color"].default_value = (r, g, b, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = spec
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    m.diffuse_color = (r, g, b, alpha)
    m.roughness = rough
    m.metallic = metal
    MATS[name] = m
    return m


def build_materials():
    # names Godot will remap
    make_mat("mat_wood_oak", "#b58a5a", 0.55)
    make_mat("mat_paint_white", "#e9e7e1", 0.6)
    make_mat("mat_counter_granite", "#3a3c3e", 0.25, spec=0.6)
    make_mat("mat_tile_white", "#eeeeea", 0.2, spec=0.6)
    make_mat("mat_fabric", "#5a6671", 0.95, spec=0.2)
    make_mat("mat_metal_brushed", "#b9bcc0", 0.35, metal=1.0)
    make_mat("mat_plastic_black", "#1b1b1d", 0.4)
    make_mat("mat_glass", "#dbe8ee", 0.03, alpha=0.18, spec=0.8)
    make_mat("mat_clay", "#b0603a", 0.9, spec=0.2)
    make_mat("mat_cardboard", "#b4936a", 0.9, spec=0.2)
    make_mat("mat_wrapping_paper", "#7b1f2a", 0.4)
    make_mat("mat_ribbon", "#d6b04a", 0.3, metal=0.4)
    make_mat("mat_whiteboard", "#f3f3f1", 0.12, spec=0.7)
    make_mat("mat_leather_dark", "#2c211b", 0.5)
    make_mat("mat_photo_graduation", "#8a8f94", 0.3)
    make_mat("mat_photo_nila", "#94908a", 0.3)
    # extras (not in the requested list; Godot can remap or ignore)
    make_mat("mat_fabric_duffel", "#2e3a33", 0.95, spec=0.2)
    make_mat("mat_denim", "#2d3f5e", 0.9, spec=0.15)
    make_mat("mat_bedding", "#dcd9d0", 0.95, spec=0.2)
    make_mat("mat_duvet", "#566679", 0.95, spec=0.2)
    make_mat("mat_glass_frosted", "#f1efe8", 0.45)
    make_mat("mat_plastic_white", "#ecebe6", 0.4)
    make_mat("mat_cellophane", "#e6eef2", 0.08, alpha=0.2, spec=0.8)
    make_mat("mat_screen", "#07080a", 0.08, spec=0.8)
    make_mat("mat_marker_red", "#b3202a", 0.4)


# --------------------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------------------
class B:
    def __init__(self, name, thresh=35.0, photos=None):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.stack = [Matrix.Identity(4)]
        self.thresh = math.radians(thresh)
        self.photos = photos or []   # material names with 0..1 UVs

    def mi(self, mat):
        if mat not in self.mats:
            self.mats.append(mat)
        return self.mats.index(mat)

    @contextmanager
    def xf(self, M):
        self.stack.append(self.stack[-1] @ M)
        yield
        self.stack.pop()

    @property
    def M(self):
        return self.stack[-1]

    def _setmat(self, verts, mat):
        i = self.mi(mat)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.material_index = i
        return faces

    def _bevel(self, verts, w, seg, mi=-1):
        if w <= 0:
            return
        edges = list({e for v in verts for e in v.link_edges})
        bmesh.ops.bevel(self.bm, geom=edges, offset=w, offset_type="OFFSET", segments=seg,
                        profile=0.5, affect="EDGES", clamp_overlap=True, material=mi)

    # -- primitives
    def box(self, c, size, mat, bevel=0.003, seg=1):
        sx, sy, sz = size
        w = min(bevel, min(size) * 0.45)
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=self.M @ T(*c) @ S(sx, sy, sz))
        self._setmat(r["verts"], mat)
        self._bevel(r["verts"], w, seg, self.mi(mat))

    def cyl(self, c, r, h, mat, axis="z", seg=16, r2=None, rot=None, bevel=0.0):
        a = {"z": Matrix.Identity(4), "x": Ry(90), "y": Rx(90)}[axis]
        m = self.M @ T(*c) @ (rot if rot is not None else Matrix.Identity(4)) @ a
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                                    radius1=r, radius2=r if r2 is None else r2, depth=h, matrix=m)
        self._setmat(res["verts"], mat)
        self._bevel(res["verts"], min(bevel, r * 0.45, h * 0.45), 1, self.mi(mat))

    def rod(self, p0, p1, r, mat, seg=6):
        p0, p1 = V(p0), V(p1)
        d = p1 - p0
        q = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        self.cyl(((p0 + p1) / 2), r, d.length, mat, seg=seg, rot=q)

    def sphere(self, c, r, mat, scale=(1, 1, 1), u=14, v=9, rot=None):
        m = self.M @ T(*c) @ (rot if rot is not None else Matrix.Identity(4)) @ S(*scale)
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=r, matrix=m)
        self._setmat(res["verts"], mat)

    def surf(self, fn, nu, nv, mat, cu=False, cv=False, fix=True):
        """Parametric surface; fn(u, v) -> local point, u,v in [0,1]. Returns the vertex grid."""
        bm = self.bm
        mi = self.mi(mat)
        vs = []
        for i in range(nu):
            u = i / nu if cu else i / (nu - 1)
            row = []
            for j in range(nv):
                v = j / nv if cv else j / (nv - 1)
                row.append(bm.verts.new(self.M @ V(fn(u, v))))
            vs.append(row)
        faces = []
        for i in range(nu if cu else nu - 1):
            for j in range(nv if cv else nv - 1):
                a = vs[i][j]
                b = vs[(i + 1) % nu][j]
                c = vs[(i + 1) % nu][(j + 1) % nv]
                d = vs[i][(j + 1) % nv]
                f = bm.faces.new((a, b, c, d))
                f.material_index = mi
                faces.append(f)
        if fix:
            bmesh.ops.recalc_face_normals(bm, faces=faces)
        return vs

    def prism(self, pts_yz, x0, x1, mat):
        """Extrude a closed (y,z) profile along X from x0 to x1."""
        bm = self.bm
        mi = self.mi(mat)
        r0 = [bm.verts.new(self.M @ V((x0, y, z))) for y, z in pts_yz]
        r1 = [bm.verts.new(self.M @ V((x1, y, z))) for y, z in pts_yz]
        faces = [bm.faces.new(r0), bm.faces.new(r1)]
        n = len(pts_yz)
        for i in range(n):
            faces.append(bm.faces.new((r0[i], r0[(i + 1) % n], r1[(i + 1) % n], r1[i])))
        for f in faces:
            f.material_index = mi
        bmesh.ops.recalc_face_normals(bm, faces=faces)

    def quad(self, p, mat):
        f = self.bm.faces.new([self.bm.verts.new(self.M @ V(q)) for q in p])
        f.material_index = self.mi(mat)

    def solidify(self, before_faces, thickness):
        bm = self.bm
        faces = [f for f in bm.faces if f not in before_faces]
        pre = set(bm.faces)
        mi = faces[0].material_index if faces else 0
        bmesh.ops.solidify(bm, geom=faces, thickness=thickness)
        new = [f for f in bm.faces if f not in pre]
        for f in new:
            f.material_index = mi
        bmesh.ops.recalc_face_normals(bm, faces=list(set(faces) | set(new)))

    # -- finish
    def finish(self, collection):
        bm = self.bm
        bm.normal_update()
        uv = bm.loops.layers.uv.new("UVMap")
        photo_idx = {self.mats.index(m) for m in self.photos if m in self.mats}
        for f in bm.faces:
            n = f.normal
            if f.material_index in photo_idx:
                xs = [l.vert.co.x for l in f.loops]
                zs = [l.vert.co.z for l in f.loops]
                x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
                for l in f.loops:
                    p = l.vert.co
                    l[uv].uv = ((p.x - x0) / max(x1 - x0, 1e-6), (p.z - z0) / max(z1 - z0, 1e-6))
                continue
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for l in f.loops:
                p = l.vert.co
                if az >= ax and az >= ay:
                    u_, v_ = (p.x, p.y) if n.z > 0 else (p.x, -p.y)
                elif ay >= ax:
                    u_, v_ = (p.x, p.z) if n.y < 0 else (-p.x, p.z)
                else:
                    u_, v_ = (p.y, p.z) if n.x > 0 else (-p.y, p.z)
                l[uv].uv = (u_, v_)
        for f in bm.faces:
            f.smooth = True
        for e in bm.edges:
            if len(e.link_faces) == 2:
                e.smooth = e.calc_face_angle(0.0) < self.thresh
            else:
                e.smooth = False
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(MATS[m])
        ob = bpy.data.objects.new(self.name, me)
        collection.objects.link(ob)
        return ob


# --------------------------------------------------------------------------------------
# Shared pieces
# --------------------------------------------------------------------------------------
def handle_v(b, x, y_front, zc, length, mat="mat_metal_brushed", r=0.006, stand=0.025):
    """Vertical bar pull standing off a face whose front plane is y_front (front = -Y)."""
    y = y_front - stand
    b.rod((x, y, zc - length / 2), (x, y, zc + length / 2), r, mat, 8)
    b.rod((x, y_front, zc - length / 2 + 0.015), (x, y, zc - length / 2 + 0.015), r * 0.9, mat, 6)
    b.rod((x, y_front, zc + length / 2 - 0.015), (x, y, zc + length / 2 - 0.015), r * 0.9, mat, 6)


def handle_h(b, xc, y_front, z, length, mat="mat_metal_brushed", r=0.006, stand=0.025):
    y = y_front - stand
    b.rod((xc - length / 2, y, z), (xc + length / 2, y, z), r, mat, 8)
    b.rod((xc - length / 2 + 0.015, y_front, z), (xc - length / 2 + 0.015, y, z), r * 0.9, mat, 6)
    b.rod((xc + length / 2 - 0.015, y_front, z), (xc + length / 2 - 0.015, y, z), r * 0.9, mat, 6)


# --------------------------------------------------------------------------------------
# KITCHEN
# --------------------------------------------------------------------------------------
def kitchen_base_run(col):
    b = B("kitchen_base_run")
    L, D = 2.4, 0.6
    W, DK, G, MET = "mat_paint_white", "mat_plastic_black", "mat_counter_granite", "mat_metal_brushed"
    b.box((0, 0.03, 0.05), (L - 0.02, D - 0.1, 0.1), DK, 0.0)                       # toe-kick plinth
    b.box((-0.9, 0.01, 0.48), (0.6, 0.58, 0.76), W, 0.002)                          # module 0
    b.box((0.6, 0.01, 0.48), (1.2, 0.58, 0.76), W, 0.002)                           # modules 2-3
    # sink bay shell (hollow so the basin shows)
    b.box((-0.6 + 0.009, 0.01, 0.48), (0.018, 0.58, 0.76), W, 0.001)
    b.box((-0.009, 0.01, 0.48), (0.018, 0.58, 0.76), W, 0.001)
    b.box((-0.3, 0.29 - 0.009, 0.48), (0.6, 0.018, 0.76), W, 0.001)
    b.box((-0.3, 0.01, 0.115), (0.6, 0.58, 0.018), W, 0.001)
    b.box((-0.3, -0.25, 0.82), (0.58, 0.06, 0.04), W, 0.001)
    dz, dh, yf = 0.485, 0.75, -0.30

    def door(x, w):
        b.box((x, yf + 0.009, dz), (w, 0.018, dh), W, 0.002, 2)
    door(-0.9, 0.596)
    door(-0.45, 0.296)
    door(-0.15, 0.296)
    door(0.9, 0.596)
    handle_v(b, -0.9 + 0.25, yf, 0.72, 0.16)
    handle_v(b, -0.45 + 0.12, yf, 0.72, 0.16)
    handle_v(b, -0.15 - 0.12, yf, 0.72, 0.16)
    handle_v(b, 0.9 - 0.25, yf, 0.72, 0.16)
    for zc, h in ((0.77, 0.15), (0.55, 0.25), (0.28, 0.27)):                       # drawer stack
        b.box((0.3, yf + 0.009, zc), (0.596, 0.018, h - 0.004), W, 0.002, 2)
        handle_h(b, 0.3, yf, zc + h / 2 - 0.035, 0.14)
    # counter with sink cut-in: four slabs around the hole
    th = 0.04
    cz = 0.9 - th / 2
    hx0, hx1, hy0, hy1 = -0.55, -0.05, -0.20, 0.17
    b.box(((-L / 2 + hx0) / 2, 0, cz), (hx0 + L / 2, D, th), G, 0.002)
    b.box(((hx1 + L / 2) / 2, 0, cz), (L / 2 - hx1, D, th), G, 0.002)
    b.box(((hx0 + hx1) / 2, (-D / 2 + hy0) / 2, cz), (hx1 - hx0, hy0 + D / 2, th), G, 0.002)
    b.box(((hx0 + hx1) / 2, (hy1 + D / 2) / 2, cz), (hx1 - hx0, D / 2 - hy1, th), G, 0.002)
    sx, sy = (hx0 + hx1) / 2, (hy0 + hy1) / 2
    bw, bd, top, bot, t = hx1 - hx0, hy1 - hy0, 0.9, 0.72, 0.004
    b.box((sx, hy0 + t / 2, (top + bot) / 2), (bw, t, top - bot), MET, 0.001)
    b.box((sx, hy1 - t / 2, (top + bot) / 2), (bw, t, top - bot), MET, 0.001)
    b.box((hx0 + t / 2, sy, (top + bot) / 2), (t, bd, top - bot), MET, 0.001)
    b.box((hx1 - t / 2, sy, (top + bot) / 2), (t, bd, top - bot), MET, 0.001)
    b.box((sx, sy, bot + t / 2), (bw, bd, t), MET, 0.001)
    b.cyl((sx, sy, bot + t + 0.002), 0.025, 0.004, DK, seg=14)
    lip = 0.015
    b.box((sx, hy0 - lip / 2, 0.9015), (bw + 2 * lip, lip, 0.003), MET, 0.0005)
    b.box((sx, hy1 + lip / 2, 0.9015), (bw + 2 * lip, lip, 0.003), MET, 0.0005)
    b.box((hx0 - lip / 2, sy, 0.9015), (lip, bd, 0.003), MET, 0.0005)
    b.box((hx1 + lip / 2, sy, 0.9015), (lip, bd, 0.003), MET, 0.0005)
    # tap
    tx, ty = sx, 0.235
    b.cyl((tx, ty, 0.915), 0.03, 0.03, MET, seg=16, r2=0.022)
    b.rod((tx, ty, 0.93), (tx, ty, 1.14), 0.013, MET, 12)
    pts = [V((tx, ty - 0.1 + 0.1 * math.cos(math.radians(k * 22.5)), 1.14 + 0.1 * math.sin(math.radians(k * 22.5))))
           for k in range(9)]
    for p0, p1 in zip(pts[:-1], pts[1:]):
        b.rod(p0, p1, 0.011, MET, 10)
    b.rod(pts[-1], pts[-1] + V((0, 0, -0.06)), 0.013, MET, 10)
    # (the lever is a separate animated asset: tap_lever)
    # tile splashback
    yb = 0.294
    b.box((0, yb + 0.003, 1.1), (L, 0.004, 0.4), W, 0.0)
    tw, tho, g = 0.2, 0.1, 0.004
    for row in range(4):
        for ci in range(13):
            off = 0.1 if row % 2 else 0.0
            x0 = -L / 2 + ci * tw - off
            x1 = x0 + tw - g
            x0 = max(x0, -L / 2)
            x1 = min(x1, L / 2)
            if x1 - x0 < 0.03:
                continue
            b.box(((x0 + x1) / 2, yb - 0.001, 0.9 + row * tho + tho / 2 + 0.002), (x1 - x0, 0.008, tho - g),
                  "mat_tile_white", 0.0008)
    return b.finish(col)


def kitchen_wall_cabinets(col):
    b = B("kitchen_wall_cabinets")
    L, D, H = 2.4, 0.32, 0.7
    W = "mat_paint_white"
    b.box((0, 0.01, H / 2), (L, D - 0.02, H), W, 0.002)
    yf = -D / 2
    for i in range(4):
        x = -0.9 + 0.6 * i
        b.box((x, yf + 0.009, H / 2), (0.596, 0.018, H - 0.004), W, 0.002, 2)
        handle_v(b, x + (0.25 if i % 2 else -0.25), yf, 0.12, 0.13)
    b.box((0, -0.12, 0.01), (L - 0.02, 0.04, 0.02), W, 0.001)
    return b.finish(col)


def stove(col):
    b = B("stove")
    MET, BK, GL = "mat_metal_brushed", "mat_plastic_black", "mat_glass"
    b.box((0, 0.02, 0.45), (0.6, 0.56, 0.9), MET, 0.004, 2)
    b.box((0, 0.0, 0.895), (0.6, 0.6, 0.01), BK, 0.003)
    for bx, by, r in ((-0.15, -0.1, 0.045), (0.15, -0.1, 0.06), (-0.15, 0.12, 0.06), (0.15, 0.12, 0.045)):
        b.cyl((bx, by, 0.905), r + 0.012, 0.012, BK, seg=16)
        b.cyl((bx, by, 0.913), r * 0.55, 0.012, MET, seg=14)
        zz = 0.935
        b.rod((bx - 0.11, by, zz), (bx + 0.11, by, zz), 0.006, BK, 6)
        b.rod((bx, by - 0.11, zz), (bx, by + 0.11, zz), 0.006, BK, 6)
        for dx, dy in ((-0.1, 0), (0.1, 0), (0, -0.1), (0, 0.1)):
            b.rod((bx + dx, by + dy, 0.9), (bx + dx, by + dy, zz), 0.006, BK, 6)
    b.box((0, -0.295, 0.84), (0.6, 0.02, 0.1), MET, 0.003)
    for x in (-0.2, -0.067, 0.067, 0.2):
        b.cyl((x, -0.318, 0.84), 0.02, 0.028, BK, axis="y", seg=14)
        b.box((x, -0.334, 0.846), (0.004, 0.006, 0.016), "mat_plastic_white", 0.0)
    b.box((0, 0.29, 0.97), (0.6, 0.03, 0.14), MET, 0.003)
    b.box((0, -0.322, 0.4), (0.58, 0.04, 0.68), MET, 0.006, 2)
    b.box((0, -0.3445, 0.42), (0.46, 0.004, 0.3), BK, 0.001)
    b.box((0, -0.3475, 0.42), (0.46, 0.002, 0.3), GL, 0.0)
    handle_h(b, 0, -0.342, 0.7, 0.5, r=0.009, stand=0.03)
    b.box((0, -0.322, 0.04), (0.58, 0.04, 0.06), BK, 0.002)
    return b.finish(col)


# --------------------------------------------------------------------------------------
# LIVING
# --------------------------------------------------------------------------------------
def sofa(col):
    b = B("sofa")
    F, WD = "mat_fabric", "mat_wood_oak"
    for x in (-0.7, 0.7):
        for y in (-0.36, 0.36):
            b.cyl((x, y, 0.05), 0.022, 0.1, WD, seg=10, r2=0.015)
    b.box((0, 0.0, 0.2), (1.6, 0.85, 0.2), F, 0.04, 3)
    for x in (-0.74, 0.74):
        b.box((x, 0.0, 0.38), (0.12, 0.85, 0.56), F, 0.045, 3)
    b.box((0, 0.35, 0.5), (1.36, 0.15, 0.7), F, 0.05, 3)
    for x in (-0.34, 0.34):
        b.box((x, -0.06, 0.37), (0.67, 0.6, 0.14), F, 0.045, 3)
    for x in (-0.33, 0.33):
        with b.xf(T(x, 0.19, 0.58) @ Rx(-14)):
            b.box((0, 0, 0), (0.64, 0.14, 0.42), F, 0.05, 3)
    with b.xf(T(-0.5, 0.0, 0.57) @ Rx(-12) @ Rz(18)):
        b.box((0, 0, 0), (0.38, 0.1, 0.38), "mat_duvet", 0.04, 3)
    return b.finish(col)


def coffee_table(col):
    b = B("coffee_table")
    WD = "mat_wood_oak"
    b.box((0, 0, 0.4), (1.0, 0.5, 0.035), WD, 0.006, 2)
    b.box((0, 0, 0.12), (0.88, 0.38, 0.02), WD, 0.004)
    for x in (-0.44, 0.44):
        for y in (-0.19, 0.19):
            b.box((x, y, 0.19), (0.045, 0.045, 0.38), WD, 0.004)
    b.box((0, -0.2, 0.355), (0.84, 0.02, 0.05), WD, 0.002)
    b.box((0, 0.2, 0.355), (0.84, 0.02, 0.05), WD, 0.002)
    return b.finish(col)


def desk(col):
    b = B("desk")
    WD, MET = "mat_wood_oak", "mat_metal_brushed"
    b.box((0, 0, 0.735), (1.2, 0.6, 0.03), WD, 0.004, 2)
    for y in (-0.25, 0.25):
        b.box((-0.56, y, 0.36), (0.05, 0.05, 0.72), WD, 0.003)
    b.box((-0.56, 0, 0.64), (0.03, 0.5, 0.08), WD, 0.002)
    b.box((-0.06, 0.27, 0.45), (1.0, 0.02, 0.5), WD, 0.002)
    b.box((0.4, 0.0, 0.36), (0.4, 0.56, 0.72), WD, 0.003)
    b.box((0.4, -0.285, 0.64), (0.37, 0.018, 0.14), WD, 0.002)
    b.box((0.4, -0.285, 0.35), (0.37, 0.018, 0.5), WD, 0.002)
    handle_h(b, 0.4, -0.294, 0.64, 0.12, stand=0.02)
    b.cyl((0.25, -0.31, 0.5), 0.011, 0.016, MET, axis="y", seg=12)
    return b.finish(col)


def office_chair(col):
    b = B("office_chair")
    BK, F = "mat_plastic_black", "mat_fabric"
    for k in range(5):
        with b.xf(Rz(k * 72 + 18)):
            b.box((0.14, 0, 0.075), (0.28, 0.04, 0.025), BK, 0.004)
            b.cyl((0.27, 0, 0.0215), 0.021, 0.04, BK, axis="y", seg=10)
            b.cyl((0.27, 0, 0.0355), 0.022, 0.016, BK, seg=10)
    b.cyl((0, 0, 0.07), 0.045, 0.06, BK, seg=14, r2=0.025)
    b.cyl((0, 0, 0.25), 0.02, 0.32, "mat_metal_brushed", seg=12)
    b.cyl((0, 0, 0.36), 0.03, 0.12, BK, seg=12)
    b.box((0, 0, 0.425), (0.3, 0.28, 0.025), BK, 0.005)
    b.box((0, -0.01, 0.465), (0.47, 0.47, 0.06), F, 0.025, 3)
    b.box((0, 0.2, 0.52), (0.05, 0.03, 0.2), BK, 0.004)
    with b.xf(T(0, 0.24, 0.74) @ Rx(-8)):
        b.box((0, 0, 0), (0.44, 0.07, 0.36), F, 0.03, 3)
    return b.finish(col)


def bookshelf(col):
    b = B("bookshelf")
    WD = "mat_wood_oak"
    rnd = random.Random(7)
    W_, D_, H_ = 0.8, 0.3, 1.8
    for x in (-W_ / 2 + 0.01, W_ / 2 - 0.01):
        b.box((x, 0, H_ / 2), (0.02, D_, H_), WD, 0.002)
    b.box((0, 0.147, H_ / 2), (W_ - 0.04, 0.006, H_), WD, 0.0)
    b.box((0, -0.01, 0.03), (W_ - 0.04, D_ - 0.06, 0.06), "mat_plastic_black", 0.0)
    shelves = [0.07, 0.43, 0.79, 1.15, 1.51, 1.79]
    for z in shelves:
        b.box((0, 0, z), (W_ - 0.04, D_ - 0.008, 0.02), WD, 0.002)
    bookmats = ["mat_leather_dark", "mat_cardboard", "mat_fabric", "mat_paint_white", "mat_wrapping_paper", "mat_fabric_duffel"]
    for si, z in enumerate(shelves[:-1]):
        if si in (3, 4):
            continue
        x = -W_ / 2 + 0.035
        end = W_ / 2 - 0.035 - (0.28 if si == 1 else 0.0)
        while True:
            w = rnd.uniform(0.018, 0.04)
            h = rnd.uniform(0.2, 0.32)
            d = rnd.uniform(0.18, 0.23)
            if x + w > end:
                break
            tilt = rnd.uniform(-1.5, 1.5) if rnd.random() < 0.1 else 0
            with b.xf(T(x + w / 2, 0.02, z + 0.01 + h / 2) @ Ry(tilt)):
                b.box((0, 0, 0), (w, d, h), rnd.choice(bookmats), 0.002)
            x += w + 0.001
    return b.finish(col)


# --------------------------------------------------------------------------------------
# BEDROOM
# --------------------------------------------------------------------------------------
def bed(col):
    b = B("bed")
    WD = "mat_wood_oak"
    for x in (-0.74, 0.74):
        b.box((x, 0, 0.22), (0.04, 2.0, 0.2), WD, 0.003)
    b.box((0, 0.0, 0.305), (1.44, 1.98, 0.02), WD, 0.002)
    b.box((0, 1.025, 0.55), (1.5, 0.05, 1.1), WD, 0.006, 2)
    b.box((0, -1.025, 0.3), (1.5, 0.05, 0.6), WD, 0.006, 2)
    for x in (-0.73, 0.73):
        b.box((x, 0.975, 0.07), (0.07, 0.07, 0.14), WD, 0.004)
        b.box((x, -0.975, 0.07), (0.07, 0.07, 0.14), WD, 0.004)
    b.box((0, 0, 0.44), (1.4, 1.95, 0.25), "mat_bedding", 0.05, 3)
    # duvet: a swept cross-section over the mattress, rumpled, then given thickness
    cx, cz, rr = 0.70, 0.55, 0.075
    prof = [(-0.775, 0.30), (-0.775, 0.42), (-0.775, cz)]
    for a in range(165, 89, -15):
        prof.append((-cx + rr * math.cos(math.radians(a)), cz + rr * math.sin(math.radians(a))))
    for k in range(1, 8):
        prof.append((-cx + 2 * cx * k / 8, cz + rr))
    for a in range(90, -76, -15):
        prof.append((cx + rr * math.cos(math.radians(a)), cz + rr * math.sin(math.radians(a))))
    prof += [(0.775, 0.42), (0.775, 0.30)]
    y0, y1 = -1.0, 0.42
    before = set(b.bm.faces)

    def fn(u, v):
        k = u * (len(prof) - 1)
        i = min(int(k), len(prof) - 2)
        f = k - i
        px = prof[i][0] * (1 - f) + prof[i + 1][0] * f
        pz = prof[i][1] * (1 - f) + prof[i + 1][1] * f
        y = y0 + (y1 - y0) * v
        w = 1.0 if pz > 0.5 else max(0.0, (pz - 0.3) / 0.2)
        rump = (0.016 * math.sin(9 * y + 4 * px + 1.0) * math.cos(6 * px)
                + 0.010 * math.sin(17 * y + 2.0 + 3 * px)
                + 0.025 * math.exp(-((y - 0.30) / 0.07) ** 2) * (0.6 + 0.4 * math.sin(5 * px)))
        pz2 = pz + w * rump
        if y < -0.93:
            pz2 -= ((-0.93 - y) / 0.07) ** 2 * 0.11
        if y > 0.37:
            pz2 -= ((y - 0.37) / 0.05) ** 2 * 0.05
        return (px, y, pz2)
    b.surf(fn, len(prof) * 2 - 1, 44, "mat_duvet", fix=False)
    b.solidify(before, -0.025)
    for x, rotz in ((-0.37, 5), (0.37, -4)):
        with b.xf(T(x, 0.72, 0.62) @ Rz(rotz) @ Rx(-6)):
            b.box((0, 0, 0), (0.68, 0.44, 0.13), "mat_bedding", 0.055, 4)
    return b.finish(col)


def bedside_table(col):
    b = B("bedside_table")
    WD = "mat_wood_oak"
    b.box((0, 0, 0.485), (0.42, 0.36, 0.03), WD, 0.004, 2)
    for x in (-0.18, 0.18):
        for y in (-0.14, 0.14):
            b.box((x, y, 0.2), (0.035, 0.035, 0.4), WD, 0.003)
    b.box((0, 0.0, 0.43), (0.4, 0.34, 0.12), WD, 0.003)
    b.box((0, -0.178, 0.43), (0.35, 0.016, 0.1), WD, 0.002)
    b.cyl((0, -0.2, 0.43), 0.014, 0.014, "mat_metal_brushed", axis="y", seg=12)
    b.box((0, 0, 0.2), (0.36, 0.3, 0.015), WD, 0.002)
    return b.finish(col)


# --------------------------------------------------------------------------------------
# FIXTURES
# --------------------------------------------------------------------------------------
def door_assembly(col, name, slab_w, slab_h, jamb, depth, front, casing):
    """Frame only (jambs, head, casing, threshold). The moving leaf is door_slab()."""
    b = B(name)
    W, MET = "mat_paint_white", "mat_metal_brushed"
    gap = 0.01
    cw = slab_w + 2 * gap
    ch = slab_h + gap + (0.02 if front else 0.012)
    oh = ch + jamb
    for s in (-1, 1):
        b.box((s * (cw / 2 + jamb / 2), 0, oh / 2), (jamb, depth, oh), W, 0.002)
    b.box((0, 0, ch + jamb / 2), (cw + 2 * jamb, depth, jamb), W, 0.002)
    if front:
        b.box((0, 0, 0.01), (cw, depth, 0.02), MET, 0.003)
    for s in (-1, 1):
        b.box((s * (cw / 2 - 0.006), -depth / 2 + 0.01, ch / 2 + 0.01), (0.012, 0.02, ch - 0.02), W, 0.001)
    if casing:
        cwid, ct = 0.07, 0.014
        for side in (-1, 1):
            yy = side * (depth / 2 + ct / 2 - 0.002)
            for s in (-1, 1):
                b.box((s * (cw / 2 + jamb + cwid / 2), yy, (oh + cwid) / 2), (cwid, ct, oh + cwid), W, 0.002)
            b.box((0, yy, oh + cwid / 2), (cw + 2 * jamb, ct, cwid), W, 0.002)
    return b.finish(col)


def door_slab(col, name, slab_w, slab_h, front):
    """The moving leaf of a door. Origin = hinge axis (bottom, mid-thickness); the leaf extends along +X."""
    b = B(name)
    W, MET = "mat_paint_white", "mat_metal_brushed"
    thick = 0.045 if front else 0.04
    z0 = 0.02 if front else 0.012
    sh = slab_h
    b.stack.append(b.M @ T(slab_w / 2 + 0.004, thick / 2, 0))
    smat = "mat_wood_oak" if front else W
    b.box((0, 0.0, z0 + sh / 2), (slab_w, thick, sh), smat, 0.003, 2)
    for side in (-1, 1):
        yp = side * (thick / 2 + 0.0015)
        pw = slab_w - 0.3
        b.box((0, yp, z0 + sh * 0.76), (pw, 0.004, sh * 0.26), smat, 0.002)
        b.box((0, yp, z0 + sh * 0.3), (pw, 0.004, sh * 0.42), smat, 0.002)
    for z in (0.25, 1.0, sh - 0.25):
        b.cyl((-slab_w / 2 - 0.004, -thick / 2, z0 + z), 0.007, 0.09, MET, seg=8)
    hx = slab_w / 2 - 0.06
    hz = z0 + 1.0
    for side in (-1, 1):
        yy = side * (thick / 2)
        b.cyl((hx, yy + side * 0.006, hz), 0.027, 0.012, MET, axis="y", seg=16)
        b.rod((hx, yy + side * 0.012, hz), (hx, yy + side * 0.05, hz), 0.009, MET, 8)
        b.rod((hx, yy + side * 0.05, hz), (hx - 0.115, yy + side * 0.05, hz - 0.004), 0.009, MET, 8)
        b.cyl((hx - 0.115, yy + side * 0.05, hz - 0.004), 0.011, 0.02, MET, axis="x", seg=8)
    if front:
        b.cyl((hx, -thick / 2 - 0.012, hz + 0.14), 0.024, 0.024, MET, axis="y", seg=16)
        b.cyl((hx, thick / 2 + 0.01, hz + 0.14), 0.02, 0.02, MET, axis="y", seg=16)
        b.cyl((0, -thick / 2 - 0.004, 1.55), 0.011, 0.008, MET, axis="y", seg=12)
        b.rod((hx - 0.03, thick / 2 + 0.01, hz + 0.28), (hx - 0.12, thick / 2 + 0.01, hz + 0.28), 0.003, MET, 5)
        b.box((hx - 0.15, thick / 2 + 0.008, hz + 0.28), (0.03, 0.01, 0.02), MET, 0.001)
    b.stack.pop()
    return b.finish(col)


def door_interior_slab(col):
    return door_slab(col, "door_interior_slab", 0.9, 2.03, False)


def door_front_slab(col):
    return door_slab(col, "door_front_slab", 0.9, 2.13, True)


def door_interior(col):
    return door_assembly(col, "door_interior", 0.9, 2.03, 0.04, 0.10, False, True)


def door_front(col):
    return door_assembly(col, "door_front", 0.9, 2.13, 0.04, 0.12, True, False)


def window_frame(col):
    b = B("window_frame")
    W, GL = "mat_paint_white", "mat_glass"
    FW, FD, m, depth = 1.4, 1.2, 0.06, 0.10
    b.box((0, 0, 0.015), (FW, depth, 0.03), W, 0.002)
    b.box((0, 0, FD - m / 2), (FW, depth, m), W, 0.002)
    for s in (-1, 1):
        b.box((s * (FW / 2 - m / 2), 0, FD / 2), (m, depth, FD), W, 0.002)
    b.box((0, 0, FD / 2), (0.05, depth * 0.9, FD - 0.06), W, 0.002)
    pw = (FW - 2 * m - 0.05) / 2
    ph = FD - m - 0.03
    sw = 0.032
    for s in (-1, 1):
        cx = s * (0.025 + pw / 2)
        zc = 0.03 + ph / 2
        for ss in (-1, 1):
            b.box((cx + ss * (pw / 2 - sw / 2), 0.0, zc), (sw, 0.04, ph), W, 0.002)
        for zz in (-1, 1):
            b.box((cx, 0.0, zc + zz * (ph / 2 - sw / 2)), (pw - 2 * sw, 0.04, sw), W, 0.002)
        b.box((cx, 0.0, zc), (pw - 2 * sw + 0.01, 0.006, ph - 2 * sw + 0.01), GL, 0.0)
    b.box((0, -0.06, 0.015), (FW, 0.14, 0.03), W, 0.004, 2)
    b.box((0.0, -0.035, 0.62), (0.012, 0.03, 0.12), "mat_plastic_white", 0.003)
    b.box((0.04, -0.045, 0.62), (0.08, 0.012, 0.014), "mat_plastic_white", 0.003)
    return b.finish(col)


def window_blinds(col):
    b = B("window_blinds", thresh=20)
    W, RL = "mat_paint_white", "mat_plastic_white"
    bw, n, pitch, z = 1.30, 40, 0.0258, 0.03
    for i in range(n):
        with b.xf(T(0, 0, z + i * pitch) @ Rx(38)):
            b.box((0, 0, 0), (bw, 0.0255, 0.0018), W, 0.0)
    ztop = z + (n - 1) * pitch + 0.02
    b.box((0, 0, ztop + 0.015), (bw + 0.02, 0.04, 0.03), RL, 0.004)
    b.box((0, 0, 0.012), (bw, 0.026, 0.014), RL, 0.002)
    for x in (-0.55, 0.55):
        b.box((x, 0.0, ztop / 2), (0.003, 0.003, ztop), RL, 0.0)
    b.rod((0.62, -0.03, 0.12), (0.62, -0.03, ztop), 0.004, RL, 5)
    b.rod((-0.64, -0.02, 0.03), (-0.64, -0.02, ztop), 0.0015, RL, 4)
    b.cyl((-0.64, -0.02, 0.016), 0.007, 0.03, RL, seg=8, r2=0.004)
    return b.finish(col)


def skirting_1m(col):
    b = B("skirting_1m", thresh=30)
    pts = [(0.0075, 0.0), (-0.0075, 0.0), (-0.0075, 0.07), (-0.0055, 0.0775), (-0.0025, 0.0875), (0.0075, 0.09)]
    b.prism(pts, -0.5, 0.5, "mat_paint_white")
    return b.finish(col)


def ceiling_light(col):
    b = B("ceiling_light")
    b.cyl((0, 0, 0.0075), 0.18, 0.015, "mat_metal_brushed", seg=32)
    b.cyl((0, 0, 0.055), 0.165, 0.08, "mat_glass_frosted", seg=32)
    b.cyl((0, 0, 0.105), 0.17, 0.02, "mat_metal_brushed", seg=32)
    b.cyl((0, 0, 0.12), 0.05, 0.01, "mat_plastic_white", seg=20)
    return b.finish(col)


def light_switch(col):
    b = B("light_switch")
    b.box((0, 0.003, 0.043), (0.086, 0.012, 0.086), "mat_plastic_white", 0.003)
    with b.xf(T(0, -0.0045, 0.043) @ Rx(6)):
        b.box((0, 0, 0), (0.026, 0.008, 0.05), "mat_plastic_white", 0.002)
    return b.finish(col)


# --------------------------------------------------------------------------------------
# STORY PROPS
# --------------------------------------------------------------------------------------
# Weekend duffel: 0.75 long (X) x 0.38 wide (Y) x 0.38 tall (Z) body, handles rise above.
DUF_HL = 0.375      # half length
DUF_R = 0.19        # half width and half height (body is 0.38 x 0.38)
DUF_FILL_TOP = 0.165  # top of the packed layer inside the open bag (items rest here)


def _duffel_scale(x, L=DUF_HL, dome=0.09):
    ax = abs(x)
    if ax <= L - dome:
        return 1.0
    t = (ax - (L - dome)) / dome
    return max(0.12, (max(0.0, 1.0 - t * t)) ** 0.5)


def _sup(t, y_half, z_half, n=3.4):
    a = t * 2 * math.pi
    c, s = math.cos(a), math.sin(a)
    p = 2.0 / n
    return (y_half * math.copysign(abs(c) ** p, c), z_half * math.copysign(abs(s) ** p, s))


def _strap(b, x, mat, ytop=0.0):
    zt = 2 * DUF_R - 0.002
    p0, p1, top = V((x, -0.055, zt)), V((x, 0.055, zt)), V((x, 0, zt + 0.095))
    arc = []
    for k in range(11):
        t = k / 10
        arc.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * top + t * t * p1)
    for q0, q1 in zip(arc[:-1], arc[1:]):
        b.rod(q0, q1, 0.013, mat, 6)
    b.box((x, -0.055, zt + 0.002), (0.036, 0.024, 0.014), mat, 0.002)
    b.box((x, 0.055, zt + 0.002), (0.036, 0.024, 0.014), mat, 0.002)


def duffel_zipped(col):
    b = B("duffel_zipped")
    F, BK, LT = "mat_fabric_duffel", "mat_plastic_black", "mat_leather_dark"
    nu, nv = 28, 22
    R = DUF_R

    def fn(u, v):
        x = -DUF_HL + 2 * DUF_HL * v
        sc = _duffel_scale(x)
        y, z = _sup(u, R, R)
        return (x, y * sc, R + z * sc)
    vs = b.surf(fn, nu, nv, F, cu=True, fix=False)
    for ri in (0, nv - 1):
        f = b.bm.faces.new([vs[i][ri] for i in range(nu)])
        f.material_index = b.mi(F)
    bmesh.ops.recalc_face_normals(b.bm, faces=list(b.bm.faces))
    b.box((0, 0, 2 * R - 0.001), (0.58, 0.017, 0.007), BK, 0.001)                 # zip run
    b.box((0.2, 0, 2 * R + 0.003), (0.036, 0.024, 0.01), "mat_metal_brushed", 0.002)  # zip pull
    for x in (-0.14, 0.14):
        _strap(b, x, LT)
    b.box((0, -R - 0.004, 0.14), (0.34, 0.026, 0.18), F, 0.012, 2)               # end pocket on the front
    b.box((0, -R - 0.018, 0.19), (0.31, 0.005, 0.01), BK, 0.0)
    b.box((0.14, -0.06, 2 * R + 0.035), (0.05, 0.004, 0.075), "mat_cardboard", 0.001)  # luggage tag
    return b.finish(col)


def _folded(b, c, size, mat, rz=0.0):
    """A folded garment: bevelled slab with a fold crease line."""
    with b.xf(T(*c) @ Rz(rz)):
        b.box((0, 0, 0), size, mat, 0.01, 3)


def duffel_open(col):
    b = B("duffel_open")
    F, BK, LT = "mat_fabric_duffel", "mat_plastic_black", "mat_leather_dark"
    n_ = 3.4
    nv = 22
    R = DUF_R
    CAP = 0.33

    def cross(sc):
        pts = []
        a0, a1, steps = math.radians(150), math.radians(390), 14
        p = 2.0 / n_
        for k in range(steps + 1):
            a = a0 + (a1 - a0) * k / steps
            c, s = math.cos(a), math.sin(a)
            y = R * math.copysign(abs(c) ** p, c)
            z = R + R * math.copysign(abs(s) ** p, s)
            pts.append((y * sc, min(z, CAP)))
        l, r = pts[0], pts[-1]
        return ([(l[0] - 0.057 * sc, l[1] - 0.025), (l[0] - 0.025 * sc, l[1] + 0.012)] + pts[1:-1] +
                [(r[0] + 0.025 * sc, r[1] + 0.012), (r[0] + 0.057 * sc, r[1] - 0.025)])
    npts = len(cross(1.0))
    before = set(b.bm.faces)

    def fn(u, v):
        x = -DUF_HL + 2 * DUF_HL * v
        pts = cross(_duffel_scale(x))
        k = u * (len(pts) - 1)
        i = min(int(k), len(pts) - 2)
        f = k - i
        return (x, pts[i][0] * (1 - f) + pts[i + 1][0] * f, pts[i][1] * (1 - f) + pts[i + 1][1] * f)
    b.surf(fn, npts, nv, F, fix=False)
    b.solidify(before, -0.01)
    # packed layer: a soft hoodie spread across the bag floor; the three item slots rest on it
    b.box((0, 0, 0.09), (0.60, 0.32, 0.15), "mat_fabric", 0.035, 3)
    # clothes already packed at the left end: jeans, then three shirts, folded and stacked
    _folded(b, (-0.245, 0.0, 0.195), (0.16, 0.31, 0.06), "mat_denim", 2)
    _folded(b, (-0.245, 0.005, 0.238), (0.15, 0.29, 0.03), "mat_paint_white", -3)
    _folded(b, (-0.245, -0.004, 0.268), (0.15, 0.285, 0.03), "mat_duvet", 4)
    _folded(b, (-0.24, 0.002, 0.298), (0.145, 0.28, 0.03), "mat_fabric", -2)
    # tuck a sock ball and a rolled belt beside the stack so the end reads as packed, not stacked
    b.sphere((-0.15, -0.12, 0.2), 1.0, "mat_leather_dark", scale=(0.03, 0.04, 0.03), u=10, v=7)
    b.box((0, 0.2, 0.245), (0.62, 0.012, 0.004), BK, 0.001)
    b.box((0, -0.2, 0.245), (0.62, 0.012, 0.004), BK, 0.001)
    for x in (-0.14, 0.14):
        arc = [V((x, -0.04 + 0.08 * k / 10, 0.335 + 0.095 * math.sin(math.pi * k / 10))) for k in range(11)]
        for q0, q1 in zip(arc[:-1], arc[1:]):
            b.rod(q0, q1, 0.013, LT, 6)
    return b.finish(col)


def sweets_box(col):
    b = B("sweets_box")
    C = "mat_cardboard"
    b.box((0, 0, 0.0325), (0.25, 0.2, 0.065), C, 0.002)
    b.box((0, 0, 0.0705), (0.258, 0.208, 0.02), C, 0.002)
    b.box((0, 0, 0.0808), (0.12, 0.06, 0.0016), "mat_paint_white", 0.0)
    b.box((0, 0, 0.0755), (0.014, 0.21, 0.0215), "mat_ribbon", 0.0008)
    return b.finish(col)


def _diya_fn():
    prof = [(0.0, 0.0), (0.014, 0.0), (0.026, 0.004), (0.031, 0.011), (0.030, 0.018), (0.027, 0.021),
            (0.0235, 0.021), (0.0225, 0.0165), (0.017, 0.010), (0.0, 0.0085)]
    n = len(prof)

    def fn(u, v):
        i = min(int(v * n), n - 1)
        f = v * n - i
        p0, p1 = prof[i], prof[(i + 1) % n]
        r = p0[0] * (1 - f) + p1[0] * f
        z = p0[1] * (1 - f) + p1[1] * f
        a = u * 2 * math.pi
        c, s = math.cos(a), math.sin(a)
        w = max(0.0, (c - 0.7) / 0.3)
        k = w * min(1.0, max(0.0, (z - 0.012) / 0.009))
        rr = r * (1 + 0.22 * k)
        return (rr * c, rr * s * (1 - 0.45 * k), z + 0.0015 * k)
    return fn, n


def add_diya(b, c, seg, rot=0):
    fn, n = _diya_fn()
    with b.xf(T(*c) @ Rz(rot)):
        vs = b.surf(fn, seg, n, "mat_clay", cu=True, cv=True, fix=False)
        bmesh.ops.remove_doubles(b.bm, verts=[v for row in vs for v in row], dist=1e-6)
    faces = [f for f in b.bm.faces if f.material_index == b.mi("mat_clay")]
    bmesh.ops.recalc_face_normals(b.bm, faces=faces)


def diya(col):
    b = B("diya", thresh=45)
    add_diya(b, (0, 0, 0), 20)
    return b.finish(col)


def diyas_packet(col):
    b = B("diyas_packet", thresh=45)
    rnd = random.Random(3)
    for r in range(3):
        for c in range(4):
            x = (c - 1.5) * 0.062 + rnd.uniform(-0.003, 0.003)
            y = (r - 1.0) * 0.062 - 0.012 + rnd.uniform(-0.003, 0.003)
            add_diya(b, (x, y, 0.003), 12, rnd.uniform(0, 360))
    b.box((0, -0.012, 0.0185), (0.272, 0.2, 0.034), "mat_cellophane", 0.015, 3)
    b.box((0, 0.1, 0.0175), (0.272, 0.03, 0.004), "mat_cellophane", 0.0)
    b.box((0, 0.114, 0.0185), (0.272, 0.045, 0.003), "mat_cardboard", 0.0005)
    b.box((0, 0.114, 0.0205), (0.15, 0.025, 0.0012), "mat_paint_white", 0.0)
    return b.finish(col)


def radio_gift(col):
    b = B("radio_gift")
    P, R = "mat_wrapping_paper", "mat_ribbon"
    X, Y, Z = 0.12, 0.06, 0.2
    b.box((0, 0, Z / 2), (X, Y, Z), P, 0.003, 1)
    rw, t = 0.012, 0.002
    b.box((0, -Y / 2 - t / 2 + 0.0005, Z / 2), (rw, t, Z + 0.003), R, 0.0004)
    b.box((0, Y / 2 + t / 2 - 0.0005, Z / 2), (rw, t, Z + 0.003), R, 0.0004)
    b.box((0, 0, Z + t / 2 - 0.0005), (rw, Y + 0.004, t), R, 0.0004)
    for s in (-1, 1):
        b.box((s * (X / 2 + t / 2 - 0.0005), 0, Z / 2), (t, rw, Z + 0.003), R, 0.0004)
    b.box((0, 0, Z + t / 2), (X + 0.004, rw, t), R, 0.0004)

    def loop_fn():
        a_, b_ = 0.022, 0.016

        def fn(u, v):
            th = u * 2 * math.pi
            px, pz = a_ * math.cos(th), b_ * math.sin(th)
            nx, nz = b_ * math.cos(th), a_ * math.sin(th)
            l = math.hypot(nx, nz)
            nx, nz = nx / l, nz / l
            ph = v * 2 * math.pi
            return (px + nx * 0.0012 * math.cos(ph), 0.0075 * math.sin(ph), pz + nz * 0.0012 * math.cos(ph))
        return fn
    with b.xf(T(0.008, 0.002, Z + 0.004) @ Rz(24) @ Ry(8)):
        for s in (-1, 1):
            with b.xf(T(s * 0.021, 0, 0.012) @ Ry(s * -22)):
                b.surf(loop_fn(), 20, 8, R, cu=True, cv=True)
        b.box((0, 0, 0.004), (0.016, 0.016, 0.01), R, 0.003, 2)
        for ang, ln in ((205, 0.06), (-25, 0.05)):
            with b.xf(Rz(ang)):
                b.box((ln / 2, 0, 0.0015), (ln, rw, 0.0018), R, 0.0004)
    return b.finish(col)


def laptop(col):
    b = B("laptop")
    MET, BK, SC = "mat_metal_brushed", "mat_plastic_black", "mat_screen"
    BW, BD, BH = 0.32, 0.22, 0.016
    b.box((0, 0, BH / 2), (BW, BD, BH), MET, 0.003, 2)
    b.box((0, 0.0, BH + 0.0003), (BW - 0.02, BD - 0.03, 0.0008), BK, 0.0)
    kp, ks = 0.0188, 0.0165
    ky0 = 0.1 - 0.016
    for r in range(5):
        for c in range(14):
            if r == 4 and 3 <= c <= 9:
                continue
            b.box(((c - 6.5) * kp, ky0 - 0.018 - r * kp, BH + 0.0023), (ks, ks, 0.0035), BK, 0.0)
    b.box((0, ky0 - 0.018 - 4 * kp, BH + 0.0023), (7 * kp - 0.002, ks, 0.0035), BK, 0.0)
    b.box((0, -0.075, BH + 0.0005), (0.1, 0.065, 0.001), BK, 0.0)
    b.cyl((0, 0.108, BH + 0.002), 0.005, 0.2, BK, axis="x", seg=10)
    with b.xf(T(0, 0.11, BH + 0.002) @ Rx(-110)):
        b.box((0, -0.11, 0.0035), (BW, BD, 0.007), MET, 0.003, 2)
        b.box((0, -0.11, -0.0003), (BW - 0.02, BD - 0.02, 0.0008), BK, 0.0)
        b.box((0, -0.112, -0.0008), (BW - 0.036, BD - 0.052, 0.0008), SC, 0.0)
        b.cyl((0, -0.209, -0.0012), 0.0018, 0.001, "mat_plastic_white", seg=8)
    return b.finish(col)


def whiteboard(col):
    b = B("whiteboard")
    MET = "mat_metal_brushed"
    W_, H_, D_, f = 0.9, 0.6, 0.02, 0.015
    b.box((0, 0, f / 2), (W_, D_, f), MET, 0.002)
    b.box((0, 0, H_ - f / 2), (W_, D_, f), MET, 0.002)
    for s in (-1, 1):
        b.box((s * (W_ / 2 - f / 2), 0, H_ / 2), (f, D_, H_ - 2 * f), MET, 0.002)
    b.box((0, 0.0045, H_ / 2), (W_ - 2 * f, 0.01, H_ - 2 * f), "mat_whiteboard", 0.0)
    b.box((0, -0.0055, H_ / 2), (W_ - 2 * f, 0.001, H_ - 2 * f), "mat_whiteboard", 0.0)
    b.box((0, -0.03, 0.005), (0.5, 0.05, 0.012), MET, 0.003)
    b.box((0, -0.054, 0.015), (0.5, 0.004, 0.015), MET, 0.001)
    with b.xf(T(0.12, -0.034, 0.025) @ Rz(8)):
        b.cyl((0, 0, 0), 0.0075, 0.12, "mat_plastic_black", axis="x", seg=10)
        b.cyl((0.055, 0, 0), 0.0082, 0.03, "mat_marker_red", axis="x", seg=10)
        b.cyl((-0.062, 0, 0), 0.005, 0.01, "mat_marker_red", axis="x", seg=8)
    return b.finish(col)


def picture_frame(col, name, ow, oh, photo_mat, frame_w, mount_w, fmat):
    b = B(name, photos=[photo_mat])
    D_ = 0.02
    b.box((0, 0, frame_w / 2), (ow, D_, frame_w), fmat, 0.002)
    b.box((0, 0, oh - frame_w / 2), (ow, D_, frame_w), fmat, 0.002)
    for s in (-1, 1):
        b.box((s * (ow / 2 - frame_w / 2), 0, oh / 2), (frame_w, D_, oh - 2 * frame_w), fmat, 0.002)
    iw, ih = ow - 2 * frame_w, oh - 2 * frame_w
    b.box((0, 0.004, oh / 2), (iw, 0.004, ih), "mat_plastic_black", 0.0)
    b.box((0, -0.003, oh / 2), (iw, 0.0015, ih), "mat_paint_white", 0.0)
    pw, ph = iw - 2 * mount_w, ih - 2 * mount_w
    y = -0.00375
    x0, x1, z0, z1 = -pw / 2, pw / 2, oh / 2 - ph / 2, oh / 2 + ph / 2
    b.quad([(x0, y, z0), (x1, y, z0), (x1, y, z1), (x0, y, z1)], photo_mat)
    yg = -0.006
    b.quad([(-iw / 2, yg, oh / 2 - ih / 2), (iw / 2, yg, oh / 2 - ih / 2),
            (iw / 2, yg, oh / 2 + ih / 2), (-iw / 2, yg, oh / 2 + ih / 2)], "mat_glass")
    return b.finish(col)


def frame_graduation(col):
    return picture_frame(col, "frame_graduation", 0.30, 0.22, "mat_photo_graduation", 0.018, 0.02, "mat_wood_oak")


def frame_nila(col):
    return picture_frame(col, "frame_nila", 0.18, 0.24, "mat_photo_nila", 0.016, 0.014, "mat_plastic_black")


# --------------------------------------------------------------------------------------
# INTERACTIVE PROPS (round 2): fridge with contents, wardrobe, taps, toilet, mirror, keys, pin board
# Door leaves and lids are separate assets whose origin is their hinge axis, so Godot can rotate them.
# --------------------------------------------------------------------------------------
def extra_materials():
    make_mat("mat_glass_shelf", "#cfe3ea", 0.1, alpha=0.42, spec=0.8)
    make_mat("mat_gasket", "#cfcfca", 0.7, spec=0.2)
    make_mat("mat_ceramic", "#f1f1ee", 0.12, spec=0.8)
    make_mat("mat_tomato", "#c4301f", 0.32)
    make_mat("mat_onion", "#b8793f", 0.55)
    make_mat("mat_chilli", "#2f8a2a", 0.35)
    make_mat("mat_cucumber", "#3f7b34", 0.4)
    make_mat("mat_curry_leaf", "#2b5e2a", 0.5)
    make_mat("mat_carrot", "#e0801f", 0.5)
    make_mat("mat_pet", "#cfe6f2", 0.08, alpha=0.4, spec=0.8)
    make_mat("mat_cap_blue", "#2d62b3", 0.4)
    make_mat("mat_can_red", "#b32a2a", 0.3, metal=0.6)
    make_mat("mat_can_blue", "#2b56a8", 0.3, metal=0.6)
    make_mat("mat_can_green", "#2f8a4a", 0.3, metal=0.6)
    make_mat("mat_carton_white", "#f1efe8", 0.6)
    make_mat("mat_carton_blue", "#4673b5", 0.6)
    make_mat("mat_egg", "#e4cfa8", 0.5)
    make_mat("mat_egg_carton", "#a9a393", 0.95, spec=0.1)
    make_mat("mat_curry", "#c98a2c", 0.6)
    make_mat("mat_jar_red", "#8b2a22", 0.4)
    make_mat("mat_tub_cream", "#efe6d0", 0.5)
    make_mat("mat_lid_pink", "#d9708f", 0.45)
    make_mat("mat_lid_brown", "#6b4630", 0.45)
    make_mat("mat_lid_green", "#6aa86a", 0.45)
    make_mat("mat_choc_wrap", "#5d2a1d", 0.35)
    make_mat("mat_ice_tray", "#7fa6c9", 0.4)
    make_mat("mat_ice", "#e9f4fa", 0.1, alpha=0.65, spec=0.8)
    make_mat("mat_paratha", "#d8b777", 0.8)
    make_mat("mat_brass", "#b8923a", 0.3, metal=1.0)
    make_mat("mat_cork", "#b58d5c", 0.95, spec=0.1)
    make_mat("mat_cork_dark", "#8f6a3f", 0.95, spec=0.1)
    make_mat("mat_paper", "#f1eee3", 0.9, spec=0.1)
    make_mat("mat_pin_red", "#c0262d", 0.3)
    make_mat("mat_shirt_blue", "#4a6a9a", 0.9, spec=0.2)
    make_mat("mat_shirt_check", "#8a5a4a", 0.9, spec=0.2)
    make_mat("mat_towel", "#c9d3d6", 0.95, spec=0.1)


def put(col, objs, name, fn, pos=(0, 0, 0), rz=0.0):
    b = B(name, thresh=40)
    with b.xf(T(*pos) @ Rz(rz)):
        fn(b)
    ob = b.finish(col)
    ob.name = name
    objs.append(ob)
    return ob


# ---- fridge ------------------------------------------------------------------------
FR_X, FR_Y0, FR_Y1 = 0.35, -0.30, 0.35
FR_HX, FR_HY = 0.348, -0.325          # hinge axis of both fridge doors (x, y); doors are 0.696 wide, 0.05 thick
FR_BINS = {"fridge_door_top": [], "fridge_door_bottom": [0.36, 0.72, 1.06]}


def fridge(col):
    b = B("fridge")
    W, PW, BK = "mat_paint_white", "mat_plastic_white", "mat_plastic_black"
    t = 0.03
    dep = FR_Y1 - FR_Y0
    ym = (FR_Y0 + FR_Y1) / 2
    for x in (-0.28, 0.28):
        for y in (-0.22, 0.28):
            b.cyl((x, y, 0.015), 0.02, 0.03, BK, seg=10)
    for s in (-1, 1):
        b.box((s * (FR_X - t / 2), ym, 0.915), (t, dep, 1.77), W, 0.004, 2)
    b.box((0, FR_Y1 - t / 2, 0.915), (2 * FR_X, t, 1.77), W, 0.004, 2)
    b.box((0, ym, 1.785), (2 * FR_X, dep, 0.03), W, 0.004, 2)
    b.box((0, ym, 0.06), (2 * FR_X, dep, 0.06), W, 0.004, 2)
    b.box((0, ym, 1.275), (2 * FR_X - 2 * t, dep, 0.05), W, 0.002)
    li = 0.004
    for z0, z1 in ((0.09, 1.25), (1.30, 1.77)):
        h = z1 - z0
        zc = (z0 + z1) / 2
        for s in (-1, 1):
            b.box((s * (0.32 - li / 2), 0.01, zc), (li, 0.62, h), PW, 0.0)
        b.box((0, 0.32 - li / 2, zc), (0.64, li, h), PW, 0.0)
        b.box((0, 0.01, z0 + li / 2), (0.64, 0.62, li), PW, 0.0)
        b.box((0, 0.01, z1 - li / 2), (0.64, 0.62, li), PW, 0.0)
    b.box((0, 0.3, 1.22), (0.12, 0.012, 0.04), "mat_plastic_white", 0.003)       # lamp cover
    # glass shelves (front edge at y = -0.20 so the door bins clear them)
    for zs in (0.34, 0.60, 0.86, 1.10):
        b.box((0, 0.06, zs), (0.636, 0.52, 0.006), "mat_glass_shelf", 0.001)
        b.box((0, -0.196, zs + 0.007), (0.636, 0.01, 0.02), PW, 0.002)
    b.box((0, 0.06, 1.55), (0.636, 0.52, 0.008), PW, 0.002)                     # freezer shelf
    # crisper drawer
    cm = "mat_glass_shelf"
    b.box((0, 0.02, 0.10), (0.60, 0.56, 0.006), cm, 0.001)
    b.box((0, -0.26, 0.20), (0.60, 0.008, 0.2), cm, 0.001)
    b.box((0, 0.29, 0.20), (0.60, 0.008, 0.2), cm, 0.001)
    for s in (-1, 1):
        b.box((s * 0.296, 0.015, 0.20), (0.008, 0.56, 0.2), cm, 0.001)
    b.box((0, -0.27, 0.27), (0.2, 0.014, 0.018), PW, 0.004)
    return b.finish(col)


def _pet_bottle(b, c, h=0.17, r=0.032):
    x, y, z = c
    b.cyl((x, y, z + h / 2), r, h, "mat_pet", seg=14)
    b.cyl((x, y, z + h + 0.0125), r, 0.025, "mat_pet", seg=14, r2=0.0145)
    b.cyl((x, y, z + h + 0.031), 0.0145, 0.012, "mat_pet", seg=10)
    b.cyl((x, y, z + h + 0.044), 0.0165, 0.014, "mat_cap_blue", seg=10)
    b.cyl((x, y, z + h * 0.5), r + 0.0006, h * 0.38, "mat_plastic_white", seg=14)


def _can(b, c, mat, r=0.033, h=0.122):
    x, y, z = c
    b.cyl((x, y, z + h / 2), r, h, mat, seg=16)
    b.cyl((x, y, z + h - 0.002), r * 0.9, 0.004, "mat_metal_brushed", seg=16)
    b.cyl((x, y, z + 0.0015), r * 0.92, 0.003, "mat_metal_brushed", seg=16)
    b.box((x, y, z + h + 0.0005), (0.012, 0.008, 0.002), "mat_metal_brushed", 0.0005)


def _fridge_door(col, name, zc, h, handle_z, handle_len):
    b = B(name)
    W, PW = "mat_paint_white", "mat_plastic_white"
    with b.xf(T(-FR_HX, -FR_HY, 0)):
        b.box((0, -0.325, zc), (0.696, 0.05, h), W, 0.008, 3)
        handle_v(b, -0.29, -0.35, handle_z, handle_len, stand=0.03)
        gz0, gz1 = zc - h / 2 + 0.016, zc + h / 2 - 0.016
        gm = "mat_gasket"
        for s in (-1, 1):
            b.box((s * 0.322, -0.2985, zc), (0.02, 0.006, gz1 - gz0), gm, 0.001)
        for z in (gz0, gz1):
            b.box((0, -0.2985, z), (0.664, 0.006, 0.02), gm, 0.001)
        for zb in FR_BINS[name]:
            b.box((-0.02, -0.2625, zb), (0.55, 0.075, 0.006), "mat_glass_shelf", 0.001)
            b.box((-0.02, -0.2265, zb + 0.032), (0.55, 0.006, 0.062), "mat_glass_shelf", 0.001)
            for s in (-1, 1):
                b.box((-0.02 + s * 0.2735, -0.2625, zb + 0.032), (0.006, 0.075, 0.062), "mat_glass_shelf", 0.001)
        if name == "fridge_door_bottom":
            zb = 0.363
            for i, x in enumerate((-0.22, -0.13, -0.04)):
                _pet_bottle(b, (x, -0.262, zb), h=0.2, r=0.034)
            for i, (x, m) in enumerate(((0.06, "mat_can_blue"), (0.13, "mat_can_green"), (0.20, "mat_can_red"))):
                _can(b, (x, -0.262, zb), m)
            zj = 0.723
            for x, m in ((-0.2, "mat_jar_red"), (-0.12, "mat_curry"), (-0.04, "mat_jar_red")):
                b.cyl((x, -0.262, zj + 0.035), 0.028, 0.07, "mat_glass_shelf", seg=12)
                b.cyl((x, -0.262, zj + 0.036), 0.0255, 0.05, m, seg=12)
                b.cyl((x, -0.262, zj + 0.074), 0.029, 0.01, "mat_metal_brushed", seg=12)
            zq = 1.063
            for x, m in ((0.0, "mat_can_green"), (0.07, "mat_can_blue"), (0.14, "mat_can_red")):
                _can(b, (x, -0.262, zq), m)
        else:
            b.box((0, -0.352, 1.80), (0.1, 0.004, 0.012), "mat_metal_brushed", 0.001)
    return b.finish(col)


def fridge_door_top(col):
    return _fridge_door(col, "fridge_door_top", 1.545, 0.505, 1.38, 0.28)


def fridge_door_bottom(col):
    return _fridge_door(col, "fridge_door_bottom", 0.655, 1.205, 1.0, 0.5)


def fridge_contents(col):
    objs = []
    zc = 0.103          # crisper floor
    # vegetables in the crisper
    for i, (x, y) in enumerate([(-0.24, -0.15), (-0.17, -0.15), (-0.10, -0.15), (-0.22, -0.08), (-0.15, -0.08), (-0.08, -0.07)]):
        def tom(b):
            b.sphere((0, 0, 0.029), 0.033, "mat_tomato", scale=(1, 1, 0.86), u=12, v=8)
            b.sphere((0, 0, 0.0565), 0.012, "mat_curry_leaf", scale=(1, 1, 0.3), u=7, v=4)
        put(col, objs, "Tomato_%d" % (i + 1), tom, (x, y, zc))
    for i, (x, y) in enumerate([(0.0, -0.15), (0.09, -0.15), (0.02, -0.06), (0.11, -0.07)]):
        def onion(b):
            b.sphere((0, 0, 0.036), 0.04, "mat_onion", scale=(1, 1, 0.9), u=12, v=8)
            b.cyl((0, 0, 0.074), 0.005, 0.02, "mat_onion", seg=6, r2=0.0015)
        put(col, objs, "Onion_%d" % (i + 1), onion, (x, y, zc), rz=i * 40)

    def chillies(b):
        for k in range(7):
            yaw = math.radians(-30 + k * 10)
            L = 0.09 + 0.01 * (k % 3)
            pts = []
            for s in range(6):
                t_ = s / 5
                pts.append(V((L * t_ * math.cos(yaw) - 0.012 * math.sin(math.pi * t_) * math.sin(yaw),
                              L * t_ * math.sin(yaw) + 0.012 * math.sin(math.pi * t_) * math.cos(yaw), 0.006 + 0.0035 * (k % 2))))
            for s in range(5):
                b.rod(pts[s], pts[s + 1], 0.0058 - 0.0009 * s, "mat_chilli", 6)
            b.cyl(pts[0] - V((0.003, 0, 0)), 0.0065, 0.005, "mat_curry_leaf", seg=6)
    put(col, objs, "GreenChillies", chillies, (0.17, -0.14, zc))

    def cucumber(b):
        pts = [V((-0.11 + 0.22 * s / 8, 0.012 * math.sin(math.pi * s / 8), 0.02)) for s in range(9)]
        for s in range(8):
            b.rod(pts[s], pts[s + 1], 0.02 if 0 < s < 7 else 0.017, "mat_cucumber", 10)
        b.sphere(pts[0], 0.017, "mat_cucumber", u=9, v=6)
        b.sphere(pts[-1], 0.017, "mat_cucumber", u=9, v=6)
    put(col, objs, "Cucumber", cucumber, (-0.12, 0.06, zc))

    def carrot_bag(b):
        b.box((0, 0, 0.035), (0.21, 0.1, 0.07), "mat_cellophane", 0.012, 2)
        for k in range(6):
            yy = -0.028 + 0.0112 * k
            zz = 0.022 + 0.018 * (k % 2)
            b.cyl((0.0, yy, zz), 0.015, 0.19, "mat_carrot", axis="x", seg=8, r2=0.003)
        b.cyl((0.112, 0, 0.035), 0.01, 0.025, "mat_ribbon", axis="x", seg=8, r2=0.004)
    put(col, objs, "CarrotBag", carrot_bag, (0.17, 0.17, zc), rz=8)

    def curry(b):
        for k in range(7):
            ang = math.radians(-24 + 8 * k)
            ca, sa = math.cos(ang), math.sin(ang)
            b.rod((0, 0, 0.012), (0.16 * ca, 0.16 * sa, 0.012), 0.0016, "mat_curry_leaf", 4)
            for j in range(5):
                tt = 0.32 + 0.14 * j
                px, py = 0.16 * tt * ca, 0.16 * tt * sa
                for sd in (-1, 1):
                    b.sphere((px - sd * 0.011 * sa, py + sd * 0.011 * ca, 0.016), 0.011, "mat_curry_leaf",
                             scale=(1.0, 0.5, 0.22), u=6, v=4, rot=Rz(math.degrees(ang) + sd * 38))
        b.cyl((0.012, 0, 0.013), 0.007, 0.014, "mat_ribbon", axis="x", seg=8)
    put(col, objs, "CurryLeaves", curry, (-0.28, 0.2, zc))

    # shelf at 0.60 (top 0.603): milk, a takeaway tub, two water bottles
    def milk(b):
        b.box((0, 0, 0.085), (0.07, 0.07, 0.17), "mat_carton_white", 0.002)
        b.box((0, 0, 0.075), (0.0712, 0.0712, 0.05), "mat_carton_blue", 0.0)
        b.prism([(-0.035, 0.17), (0.035, 0.17), (0.0, 0.215)], -0.035, 0.035, "mat_carton_white")
        b.box((0, 0, 0.221), (0.07, 0.01, 0.012), "mat_carton_white", 0.002)
        b.cyl((0.0, -0.012, 0.201), 0.011, 0.012, "mat_cap_blue", seg=10, rot=Rx(-28))
    put(col, objs, "MilkCarton", milk, (-0.22, 0.12, 0.603))

    def takeaway(b):
        b.box((0, 0, 0.0225), (0.17, 0.12, 0.045), "mat_plastic_black", 0.005)
        b.box((0, 0, 0.041), (0.15, 0.1, 0.012), "mat_curry", 0.003)
        b.box((0, 0, 0.0535), (0.176, 0.126, 0.012), "mat_cellophane", 0.004)
    put(col, objs, "TakeawayContainer", takeaway, (0.05, -0.03, 0.603), rz=6)
    for i, (x, y) in enumerate(((-0.05, 0.2), (0.03, 0.2))):
        put(col, objs, "WaterBottle_%d" % (i + 1), lambda b: _pet_bottle(b, (0, 0, 0)), (x, y, 0.603))
    # shelf at 0.86 (top 0.863): eggs, a lone bottle
    def eggs(b):
        b.box((0, 0, 0.012), (0.19, 0.10, 0.024), "mat_egg_carton", 0.004)
        for i in range(3):
            for j in range(2):
                b.sphere(((i - 1) * 0.058, (j - 0.5) * 0.048, 0.042), 0.022, "mat_egg", scale=(1, 1, 1.28), u=10, v=7)
        with b.xf(T(0, 0.05, 0.024) @ Rx(-100)):
            b.box((0, -0.05, 0.002), (0.19, 0.10, 0.004), "mat_egg_carton", 0.002)
    put(col, objs, "EggCarton", eggs, (-0.1, 0.06, 0.863))
    put(col, objs, "WaterBottle_3", lambda b: _pet_bottle(b, (0, 0, 0)), (0.2, 0.14, 0.863))
    put(col, objs, "WaterBottle_4", lambda b: _pet_bottle(b, (0, 0, 0)), (0.27, 0.14, 0.863))
    # top shelf at 1.10 (top 1.103): soda cans
    mats = ["mat_can_red", "mat_can_blue", "mat_can_green"]
    for i in range(6):
        x = -0.24 + 0.07 * (i % 6)
        put(col, objs, "SodaCan_%d" % (i + 1), (lambda m: (lambda b: _can(b, (0, 0, 0), m)))(mats[i % 3]), (x, 0.1, 1.103))
    for i in range(3):
        put(col, objs, "SodaCan_%d" % (i + 7), (lambda m: (lambda b: _can(b, (0, 0, 0), m)))(mats[(i + 1) % 3]), (-0.2 + 0.07 * i, 0.19, 1.103))

    # ---- freezer: floor top 1.304, shelf top 1.554
    zf = 1.304
    for i, (x, lid) in enumerate(((-0.2, "mat_lid_pink"), (-0.03, "mat_lid_brown"))):
        def tub(b, lid=lid):
            b.cyl((0, 0, 0.055), 0.075, 0.11, "mat_tub_cream", seg=20, r2=0.085)
            b.cyl((0, 0, 0.104), 0.086, 0.012, lid, seg=20)
            b.cyl((0, 0, 0.056), 0.0762, 0.05, lid, seg=20, r2=0.0795)
        put(col, objs, "IceCreamTub_%d" % (i + 1), tub, (x, 0.08, zf))

    def paratha(b):
        b.box((0, 0, 0.0225), (0.22, 0.2, 0.045), "mat_cellophane", 0.012, 2)
        for k in range(5):
            b.cyl((0, 0, 0.01 + 0.0075 * k), 0.085, 0.007, "mat_paratha", seg=20)
        for s in (-1, 1):
            b.box((s * 0.108, 0, 0.0225), (0.008, 0.2, 0.03), "mat_plastic_white", 0.001)
        b.box((0, 0, 0.0452), (0.12, 0.08, 0.001), "mat_plastic_white", 0.0)
    put(col, objs, "ParathaPack", paratha, (0.19, 0.04, zf))

    for i in range(5):
        def bar(b):
            b.box((0, 0, 0.0055), (0.16, 0.07, 0.011), "mat_choc_wrap", 0.002)
            b.box((0, 0, 0.0095), (0.165, 0.02, 0.0045), "mat_ribbon", 0.0005)
        put(col, objs, "ChocolateBar_%d" % (i + 1), bar, (-0.2 + 0.01 * (i % 2), 0.0 + 0.003 * i, 1.554 + 0.012 * i), rz=-6 + 3 * i)
    for i in range(2):
        def tray(b, full=(i == 0)):
            b.box((0, 0, 0.012), (0.24, 0.11, 0.024), "mat_ice_tray", 0.004)
            b.box((0, 0, 0.0245), (0.225, 0.095, 0.002), "mat_plastic_white", 0.0)
            if full:
                for a in range(6):
                    for c in range(2):
                        b.box(((a - 2.5) * 0.036, (c - 0.5) * 0.04, 0.03), (0.029, 0.029, 0.014), "mat_ice", 0.004)
        put(col, objs, "IceTray_%d" % (i + 1), tray, (0.15, 0.12, 1.554 + 0.026 * i), rz=2)
    return objs


# ---- wardrobe ----------------------------------------------------------------------
WD_HX, WD_HY = 0.446, -0.241          # door hinge axes (x = +-0.446, y)


def _hung(b, x, ln, mat, kind="shirt", rail=1.66):
    MET = "mat_metal_brushed"
    with b.xf(T(x, 0, rail)):
        b.rod((0, 0, 0.0), (0, 0, -0.03), 0.0012, MET, 4)
        b.rod((0, -0.2, -0.075), (0, 0, -0.03), 0.0015, MET, 4)
        b.rod((0, 0.2, -0.075), (0, 0, -0.03), 0.0015, MET, 4)
        b.rod((0, -0.2, -0.075), (0, 0.2, -0.075), 0.0015, MET, 4)
        if kind == "trousers":
            for s in (-1, 1):
                b.box((0, s * 0.085, -0.08 - ln / 2), (0.03, 0.15, ln), mat, 0.006, 2)
        else:
            b.box((0, 0, -0.085 - ln / 2), (0.034, 0.36, ln), mat, 0.007, 2)
            b.box((0, 0, -0.095), (0.036, 0.43, 0.05), mat, 0.01, 2)
            for s in (-1, 1):
                b.box((0, s * 0.205, -0.085 - ln * 0.4), (0.03, 0.07, ln * 0.8), mat, 0.008, 2)


def wardrobe(col):
    b = B("wardrobe")
    WD, BK = "mat_wood_oak", "mat_plastic_black"
    b.box((0, 0.0, 0.05), (0.88, 0.46, 0.1), BK, 0.0)
    b.box((0, 0.01, 0.35), (0.9, 0.48, 0.5), WD, 0.003)                     # lower block (drawers)
    for s in (-1, 1):
        b.box((s * 0.44, 0.01, 1.18), (0.02, 0.48, 1.16), WD, 0.002)
    b.box((0, 0.245, 1.18), (0.9, 0.01, 1.16), WD, 0.002)
    b.box((0, 0.01, 0.605), (0.86, 0.48, 0.01), WD, 0.002)
    b.box((0, 0, 1.78), (0.92, 0.5, 0.04), WD, 0.004)
    yf = -0.25
    b.box((0, yf + 0.009, 0.4), (0.89, 0.018, 0.17), WD, 0.003, 2)
    b.box((0, yf + 0.009, 0.595), (0.89, 0.014, 0.004), BK, 0.0)
    handle_h(b, 0, yf, 0.44, 0.14, stand=0.02)
    # inside: rail and clothes
    b.cyl((0, 0.0, 1.66), 0.008, 0.86, "mat_metal_brushed", axis="x", seg=10)
    cols = ["mat_shirt_blue", "mat_paint_white", "mat_shirt_check", "mat_duvet", "mat_fabric", "mat_denim", "mat_leather_dark", "mat_shirt_blue", "mat_fabric", "mat_paint_white"]
    xs = [-0.38 + 0.062 * i for i in range(10)]
    kinds = ["shirt", "shirt", "shirt", "shirt", "jacket", "trousers", "jacket", "shirt", "trousers", "shirt"]
    for x, m, k in zip(xs, cols, kinds):
        _hung(b, x, {"shirt": 0.62, "jacket": 0.78, "trousers": 0.5}[k], m, k)
    # on the floor of the hanging space: towels and two pairs of shoes
    for i in range(3):
        b.box((-0.28, 0.1, 0.62 + 0.034 * i + 0.017), (0.3, 0.3, 0.032), "mat_towel", 0.012, 2)
    for x in (0.12, 0.3):
        for y in (-0.05, 0.1):
            b.box((x, y, 0.64), (0.09, 0.26, 0.05), "mat_leather_dark", 0.012, 2)
    return b.finish(col)


def _wardrobe_door(col, name, side):
    b = B(name)
    WD, MET = "mat_wood_oak", "mat_metal_brushed"
    d = -side                     # leaf extends from the hinge toward the centre
    b.box((d * 0.225, 0, 1.19), (0.442, 0.018, 1.18), WD, 0.003, 2)
    handle_v(b, d * 0.40, -0.009, 1.19, 0.2, stand=0.02)
    for z in (0.8, 1.2, 1.6):
        b.cyl((0, -0.009, z), 0.005, 0.06, MET, seg=8)
    return b.finish(col)


def wardrobe_door_l(col):
    return _wardrobe_door(col, "wardrobe_door_l", -1)


def wardrobe_door_r(col):
    return _wardrobe_door(col, "wardrobe_door_r", 1)


# ---- bathroom + kitchen fittings -----------------------------------------------------
def tap_lever(col):
    """Single lever; origin = pivot. The arm points to -Y (Godot +Z); lift it (rotate about X) to turn the water on."""
    b = B("tap_lever")
    MET = "mat_metal_brushed"
    b.cyl((0, 0, 0), 0.0095, 0.022, MET, axis="x", seg=12)
    b.rod((0, 0, 0), (0, -0.075, 0), 0.0055, MET, 8)
    b.sphere((0, -0.078, 0), 0.009, MET, u=10, v=7)
    return b.finish(col)


def bath_faucet(col):
    """Basin mixer for a vessel sink: base at the origin, spout reaches toward -Y, tip at (0, -0.18, 0.135)."""
    b = B("bath_faucet")
    MET = "mat_metal_brushed"
    b.cyl((0, 0, 0.006), 0.03, 0.012, MET, seg=20)
    b.cyl((0, 0, 0.09), 0.015, 0.16, MET, seg=14)
    pts = [V((0, -0.09 + 0.09 * math.cos(math.radians(a)), 0.17 + 0.045 * math.sin(math.radians(a)))) for a in range(0, 181, 22)]
    pts[-1] = V((0, -0.18, 0.17))
    for p0, p1 in zip(pts[:-1], pts[1:]):
        b.rod(p0, p1, 0.0115, MET, 10)
    b.rod(pts[-1], V((0, -0.18, 0.135)), 0.0125, MET, 10)
    b.cyl((0, -0.18, 0.133), 0.0105, 0.004, "mat_plastic_black", seg=10)
    return b.finish(col)


def bath_basin(col):
    """Vessel sink bowl, 0.34 m across, 0.12 m tall. Origin = bottom centre."""
    b = B("bath_basin", thresh=50)
    prof = [(0.065, 0.0), (0.09, 0.004), (0.125, 0.02), (0.155, 0.06), (0.168, 0.105), (0.17, 0.118), (0.162, 0.12),
            (0.155, 0.108), (0.14, 0.07), (0.1, 0.035), (0.05, 0.026), (0.0, 0.025)]
    n = len(prof)

    def fn(u, v):
        k = v * (n - 1)
        i = min(int(k), n - 2)
        f = k - i
        r = prof[i][0] * (1 - f) + prof[i + 1][0] * f
        z = prof[i][1] * (1 - f) + prof[i + 1][1] * f
        a = 2 * math.pi * u
        return (r * math.cos(a), r * math.sin(a), z)
    b.surf(fn, 36, n, "mat_ceramic", cu=True)
    b.cyl((0, 0, 0.0265), 0.02, 0.003, "mat_metal_brushed", seg=14)
    b.cyl((0, 0, 0.0285), 0.011, 0.002, "mat_plastic_black", seg=10)
    return b.finish(col)


def toilet_seat(col):
    b = B("toilet_seat", thresh=50)
    ro, ri = (0.185, 0.215), (0.115, 0.155)
    before = set(b.bm.faces)

    def fn(u, v):
        a = 2 * math.pi * u
        return ((ri[0] + (ro[0] - ri[0]) * v) * math.cos(a), (ri[1] + (ro[1] - ri[1]) * v) * math.sin(a), 0.03)
    b.surf(fn, 40, 2, "mat_plastic_white", cu=True)
    b.solidify(before, -0.028)
    for s in (-1, 1):
        b.cyl((s * 0.08, 0.2, 0.034), 0.012, 0.01, "mat_metal_brushed", seg=10)
    return b.finish(col)


def flush_button(col):
    b = B("flush_button")
    b.cyl((0, 0, 0.003), 0.036, 0.006, "mat_metal_brushed", seg=24)
    b.cyl((0, 0, 0.011), 0.026, 0.01, "mat_plastic_white", seg=24, bevel=0.003)
    return b.finish(col)


def mirror_frame(col):
    """Frame + dark backing for a 0.50 x 0.70 m mirror. Origin = bottom centre of the back plane; front = -Y."""
    b = B("mirror_frame")
    MET, BK = "mat_metal_brushed", "mat_plastic_black"
    ow, oh, fw, d = 0.56, 0.76, 0.03, 0.02
    b.box((0, -d / 2, fw / 2), (ow, d, fw), MET, 0.003)
    b.box((0, -d / 2, oh - fw / 2), (ow, d, fw), MET, 0.003)
    for s in (-1, 1):
        b.box((s * (ow / 2 - fw / 2), -d / 2, oh / 2), (fw, d, oh - 2 * fw), MET, 0.003)
    b.box((0, -0.002, oh / 2), (ow - 0.02, 0.004, oh - 0.02), BK, 0.0)
    return b.finish(col)


# ---- keys ---------------------------------------------------------------------------
def car_keys(col):
    """A key fob and two keys on a ring, lying flat. Origin = bottom centre of the ring."""
    b = B("car_keys", thresh=40)
    MET, BR, BK = "mat_metal_brushed", "mat_brass", "mat_plastic_black"
    n = 18
    for k in range(n):
        a0, a1 = 2 * math.pi * k / n, 2 * math.pi * (k + 1) / n
        b.rod((0.018 * math.cos(a0), 0.018 * math.sin(a0), 0.006), (0.018 * math.cos(a1), 0.018 * math.sin(a1), 0.006), 0.0014, MET, 5)
    b.box((0, 0.04, 0.006), (0.034, 0.062, 0.012), BK, 0.005, 2)
    for i, y in enumerate((0.03, 0.043, 0.056)):
        b.box((0, y, 0.0125), (0.012 if i != 1 else 0.016, 0.009, 0.002), "mat_plastic_white", 0.0005)
    for ang, m in ((-24, MET), (22, BR)):
        with b.xf(T(0, -0.014, 0.0035) @ Rz(ang)):
            b.cyl((0, -0.012, 0), 0.0115, 0.003, m, seg=14)
            b.box((0, -0.045, 0), (0.0095, 0.052, 0.003), m, 0.0005)
            for j in range(4):
                b.box((0.0065 * (1 if j % 2 else -1), -0.034 - 0.009 * j, 0), (0.005, 0.004, 0.003), m, 0.0004)
    return b.finish(col)


# ---- pin board ----------------------------------------------------------------------
def pin_board(col):
    """Cork board, 0.90 x 0.60 m, 0.03 m deep. Origin = bottom centre, y = 0 mid-depth (back at +0.015), front = -Y."""
    b = B("pin_board", thresh=40)
    WD = "mat_wood_oak"
    w, h, d, f = 0.9, 0.6, 0.03, 0.03
    b.box((0, 0, f / 2), (w, d, f), WD, 0.003)
    b.box((0, 0, h - f / 2), (w, d, f), WD, 0.003)
    for s in (-1, 1):
        b.box((s * (w / 2 - f / 2), 0, h / 2), (f, d, h - 2 * f), WD, 0.003)
    b.box((0, 0.0, h / 2), (w - 2 * f + 0.002, 0.02, h - 2 * f + 0.002), "mat_cork", 0.0)
    rnd = random.Random(7)
    y = -0.0101
    for i in range(160):
        cx = rnd.uniform(-w / 2 + f + 0.01, w / 2 - f - 0.01)
        cz = rnd.uniform(f + 0.01, h - f - 0.01)
        s = rnd.uniform(0.003, 0.009)
        b.quad([(cx - s, y, cz - s), (cx + s, y, cz - s), (cx + s, y, cz + s), (cx - s, y, cz + s)], "mat_cork_dark")
    return b.finish(col)


def pin_card(col):
    """A blank index card with a red pin. Origin = card centre; front = -Y."""
    b = B("pin_card", thresh=40)
    b.box((0, 0, 0), (0.12, 0.002, 0.08), "mat_paper", 0.0005)
    b.sphere((0, -0.0055, 0.03), 0.0055, "mat_pin_red", u=10, v=7)
    b.cyl((0, -0.0025, 0.03), 0.0012, 0.006, "mat_metal_brushed", axis="y", seg=6)
    return b.finish(col)


# --------------------------------------------------------------------------------------
# Driver
# --------------------------------------------------------------------------------------
ASSETS = [
    "kitchen_base_run", "kitchen_wall_cabinets", "fridge", "stove",
    "sofa", "coffee_table", "desk", "office_chair", "bookshelf",
    "bed", "bedside_table", "wardrobe",
    "door_interior", "door_front", "window_frame", "window_blinds", "skirting_1m", "ceiling_light", "light_switch",
    "duffel_open", "duffel_zipped", "sweets_box", "diya", "diyas_packet", "radio_gift", "laptop",
    "whiteboard", "frame_graduation", "frame_nila",
    "door_interior_slab", "door_front_slab", "fridge_door_top", "fridge_door_bottom",
    "wardrobe_door_l", "wardrobe_door_r", "tap_lever", "bath_faucet", "bath_basin", "toilet_seat",
    "flush_button", "mirror_frame", "car_keys", "pin_board", "pin_card",
]
GROUPS = {"fridge_contents": "fridge_contents"}   # one glb holding many named mesh objects, already placed in the fridge frame
SMALL = {"duffel_open", "duffel_zipped", "sweets_box", "diya", "diyas_packet", "radio_gift", "laptop",
         "whiteboard", "frame_graduation", "frame_nila", "light_switch", "ceiling_light", "skirting_1m",
         "tap_lever", "bath_faucet", "bath_basin", "toilet_seat", "flush_button", "mirror_frame", "car_keys", "pin_board", "pin_card",
         "wardrobe_door_l", "wardrobe_door_r", "fridge_door_top", "fridge_door_bottom", "door_interior_slab", "door_front_slab"}


def stats(ob):
    me = ob.data
    tris = sum(len(p.vertices) - 2 for p in me.polygons)
    vs = [v.co for v in me.vertices]
    mn = V((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = V((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    return tris, mn, mx


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
              export_yup=True, export_cameras=False, export_lights=False, export_animations=False,
              export_materials="EXPORT")
    bpy.ops.export_scene.gltf(**kw)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_materials()
    extra_materials()
    os.makedirs(OUT_GLB, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    col = bpy.data.collections.new("Assets")
    sc.collection.children.link(col)

    objs = []
    for name in ASSETS:
        ob = globals()[name](col)
        ob.name = name
        objs.append(ob)
    report = []
    for ob in objs:
        tris, mn, mx = stats(ob)
        path = os.path.join(OUT_GLB, ob.name + ".glb")
        export(ob, path)
        report.append((ob.name, tris, mx - mn, mn, mx, [m.name for m in ob.data.materials], os.path.getsize(path)))
    for gname, fnname in GROUPS.items():
        gobs = globals()[fnname](col)
        bpy.ops.object.select_all(action="DESELECT")
        for o in gobs:
            o.select_set(True)
        bpy.context.view_layer.objects.active = gobs[0]
        gpath = os.path.join(OUT_GLB, gname + ".glb")
        bpy.ops.export_scene.gltf(filepath=gpath, export_format="GLB", use_selection=True, export_apply=True,
                                  export_yup=True, export_cameras=False, export_lights=False, export_animations=False,
                                  export_materials="EXPORT")
        tris = sum(stats(o)[0] for o in gobs)
        mn = V((min(stats(o)[1].x for o in gobs), min(stats(o)[1].y for o in gobs), min(stats(o)[1].z for o in gobs)))
        mx = V((max(stats(o)[2].x for o in gobs), max(stats(o)[2].y for o in gobs), max(stats(o)[2].z for o in gobs)))
        report.append((gname + " (%d objects)" % len(gobs), tris, mx - mn, mn, mx,
                       sorted({m.name for o in gobs for m in o.data.materials}), os.path.getsize(gpath)))
        for o in gobs:
            o.location = (-3.0, 0.0, 0.0)   # parked beside the rows in the .blend
    # lay out in rows for the .blend (after export; exported files are at the origin)
    x = y = rowh = 0.0
    for ob in objs:
        _, mn, mx = stats(ob)
        w, d = mx.x - mn.x, mx.y - mn.y
        if x + w > 10.0:
            x, y, rowh = 0.0, y + rowh + 0.6, 0.0
        ob.location = (x - mn.x, y - mn.y, 0.0)
        x += w + 0.4
        rowh = max(rowh, d)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

    print("\nASSET REPORT (metres, size = X x Y x Z)")
    for name, tris, size, mn, mx, mats, sz in report:
        print("%-22s %6d tris  %5.3f x %5.3f x %5.3f   zmin %+.3f ctr(%+.3f,%+.3f)  %6.1f KB" %
              (name, tris, size.x, size.y, size.z, mn.z, (mn.x + mx.x) / 2, (mn.y + mx.y) / 2, sz / 1024))
        if tris > (5000 if name in SMALL else 15000):
            print("   !! OVER TRIANGLE BUDGET")
    print("\nMaterials used:", ", ".join(sorted({m for r in report for m in r[5]})))
    print("Exported %d assets to %s" % (len(report), OUT_GLB))
    print("Saved", OUT_BLEND)


main()
