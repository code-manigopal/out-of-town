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
    b.rod((tx, ty, 1.0), (tx + 0.07, ty, 1.03), 0.006, MET, 6)
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


def fridge(col):
    b = B("fridge")
    W, MET = "mat_paint_white", "mat_metal_brushed"
    b.box((0, 0.025, 0.915), (0.7, 0.65, 1.77), W, 0.004, 2)
    for x in (-0.28, 0.28):
        for y in (-0.22, 0.28):
            b.cyl((x, y, 0.015), 0.02, 0.03, "mat_plastic_black", seg=10)
    yc = -0.325
    b.box((0, yc, 1.545), (0.696, 0.05, 0.505), W, 0.008, 3)
    b.box((0, yc, 0.655), (0.696, 0.05, 1.205), W, 0.008, 3)
    handle_v(b, -0.29, -0.35, 1.38, 0.28, stand=0.03)
    handle_v(b, -0.29, -0.35, 1.0, 0.5, stand=0.03)
    b.box((0, -0.352, 1.78), (0.1, 0.004, 0.012), MET, 0.001)
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


def wardrobe(col):
    b = B("wardrobe")
    WD = "mat_wood_oak"
    b.box((0, 0.0, 0.05), (0.88, 0.46, 0.1), "mat_plastic_black", 0.0)
    b.box((0, 0.01, 0.95), (0.9, 0.48, 1.7), WD, 0.003)
    b.box((0, 0, 1.78), (0.92, 0.5, 0.04), WD, 0.004)
    yf = -0.25
    for x in (-0.223, 0.223):
        b.box((x, yf + 0.009, 1.2), (0.442, 0.018, 1.26), WD, 0.003, 2)
    b.box((0, yf + 0.009, 0.4), (0.89, 0.018, 0.17), WD, 0.003, 2)
    b.box((0, yf + 0.009, 0.595), (0.89, 0.014, 0.004), "mat_plastic_black", 0.0)
    handle_v(b, -0.04, yf, 1.2, 0.2, stand=0.02)
    handle_v(b, 0.04, yf, 1.2, 0.2, stand=0.02)
    handle_h(b, 0, yf, 0.44, 0.14, stand=0.02)
    return b.finish(col)


# --------------------------------------------------------------------------------------
# FIXTURES
# --------------------------------------------------------------------------------------
def door_assembly(col, name, slab_w, slab_h, jamb, depth, front, casing):
    b = B(name)
    W, MET = "mat_paint_white", "mat_metal_brushed"
    gap = 0.01
    cw = slab_w + 2 * gap
    ch = slab_h + gap + (0.02 if front else 0.012)
    oh = ch + jamb
    thick = 0.045 if front else 0.04
    for s in (-1, 1):
        b.box((s * (cw / 2 + jamb / 2), 0, oh / 2), (jamb, depth, oh), W, 0.002)
    b.box((0, 0, ch + jamb / 2), (cw + 2 * jamb, depth, jamb), W, 0.002)
    if front:
        b.box((0, 0, 0.01), (cw, depth, 0.02), MET, 0.003)
    for s in (-1, 1):
        b.box((s * (cw / 2 - 0.006), -depth / 2 + 0.01, ch / 2 + 0.01), (0.012, 0.02, ch - 0.02), W, 0.001)
    z0 = 0.02 if front else 0.012
    sh = slab_h
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
    if casing:
        cwid, ct = 0.07, 0.014
        for side in (-1, 1):
            yy = side * (depth / 2 + ct / 2 - 0.002)
            for s in (-1, 1):
                b.box((s * (cw / 2 + jamb + cwid / 2), yy, (oh + cwid) / 2), (cwid, ct, oh + cwid), W, 0.002)
            b.box((0, yy, oh + cwid / 2), (cw + 2 * jamb, ct, cwid), W, 0.002)
    return b.finish(col)


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
# Driver
# --------------------------------------------------------------------------------------
ASSETS = [
    "kitchen_base_run", "kitchen_wall_cabinets", "fridge", "stove",
    "sofa", "coffee_table", "desk", "office_chair", "bookshelf",
    "bed", "bedside_table", "wardrobe",
    "door_interior", "door_front", "window_frame", "window_blinds", "skirting_1m", "ceiling_light", "light_switch",
    "duffel_open", "duffel_zipped", "sweets_box", "diya", "diyas_packet", "radio_gift", "laptop",
    "whiteboard", "frame_graduation", "frame_nila",
]
SMALL = {"duffel_open", "duffel_zipped", "sweets_box", "diya", "diyas_packet", "radio_gift", "laptop",
         "whiteboard", "frame_graduation", "frame_nila", "light_switch", "ceiling_light", "skirting_1m"}


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
