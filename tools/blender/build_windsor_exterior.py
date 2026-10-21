"""
Out of Town - Windsor, Ontario: the building exterior, side alley, back lot and street props for the Episode 1 exit
sequence (verandah -> stairs -> main door -> street -> alley -> back lot -> car).

Run headless (re-runnable, deterministic):
    /opt/homebrew/bin/blender -b -P tools/blender/build_windsor_exterior.py

Outputs
    game/environments/windsor/exterior/<asset>.glb            (see ASSETS)
    game/environments/windsor/exterior/textures/*.png          (generated: brick, concrete, asphalt, grass, ...)
    art_source/environments/windsor/exterior/windsor_exterior.blend

Conventions (docs/tech/technical-design.md "Asset pipeline")
    metres, 1 unit = 1 m. The layout below is written in GODOT coordinates (x east, y up, z south = toward the street);
    G() converts to Blender (Z up, front = -Y). Items that are placed once in the scene (building, neighbours, alley props)
    are exported in WORLD position (origin = the lot origin) so Godot instantiates them at identity. Repeated items
    (houses, shops, trees, poles, people...) are exported with the origin on the ground at their bottom centre, front = +Z.

World layout (Godot metres)
    Mani's building (two-storey brick two-flat): x -5..5, z -4.5..4.5, floors at y 0 and 2.9, flat roof 5.9.
    Verandah (upper flat's walkway, railing, roof): deck y 2.9, z 4.5..6.0, x -5.4..5.
    Stair tower at the west end (turn left at the end of the verandah): clear x -5.4..-3.0, stairs descend south
    z 6.0..9.6 (15 risers), lobby z 9.6..11.4 with the MAIN DOOR in the south wall (x -3.9), mailboxes 1 and 2 on the
    south wall beside it, flat 1 door on the lobby's east wall, flat 2 door on the verandah (x 2.0).
    Front street: sidewalk z 12.6..14.1, two lanes z 17.4..23.8, shops across the street from z 28.5.
    Side alley x 5.1..8.5 (graffiti wall = the east neighbour's wall x 8.6), back lot z -4.5..-18.5, back street z -25.5..-18.5.
"""
import bpy
import bmesh
import math
import os
import random
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "game", "environments", "windsor", "exterior")
TEX = os.path.join(OUT, "textures")
OUT_BLEND = os.path.join(ROOT, "art_source", "environments", "windsor", "exterior", "windsor_exterior.blend")
V = Vector


def G(x, y, z):
    """Godot (x east, y up, z south) -> Blender (X, Y, Z up; front = -Y)."""
    return V((x, -z, y))


# ----------------------------------------------------------------------------------------------------------
# textures (numpy, tileable, deterministic)
# ----------------------------------------------------------------------------------------------------------
def _np():
    import numpy as np
    return np


def tile_noise(n, cells, seed, octaves=4):
    np = _np()
    rng = np.random.RandomState(seed)
    out = np.zeros((n, n), dtype=np.float32)
    amp, tot = 1.0, 0.0
    c = cells
    for _ in range(octaves):
        grid = rng.rand(c, c).astype(np.float32)
        xs = (np.arange(n) * c / n)
        i0 = np.floor(xs).astype(int) % c
        i1 = (i0 + 1) % c
        f = xs - np.floor(xs)
        f = f * f * (3 - 2 * f)
        a = grid[i0][:, i0] * (1 - f)[None, :] + grid[i0][:, i1] * f[None, :]
        b = grid[i1][:, i0] * (1 - f)[None, :] + grid[i1][:, i1] * f[None, :]
        layer = a * (1 - f)[:, None] + b * f[:, None]
        out += layer * amp
        tot += amp
        amp *= 0.5
        c *= 2
    return out / tot


def save_png(name, arr):
    np = _np()
    h, w, _ = arr.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    a = np.clip(arr, 0, 1)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = a
    img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw = os.path.join(TEX, name)
    img.file_format = "PNG"
    img.save()
    return img


def gen_textures():
    np = _np()
    os.makedirs(TEX, exist_ok=True)
    n = 512
    # brick: 0.9 m x 0.9 m tile, 12 courses, 4 bricks per course
    rng = np.random.RandomState(7)
    img = np.zeros((n, n, 3), dtype=np.float32)
    mort = np.array([0.66, 0.63, 0.58])
    img[:] = mort
    courses, per = 12, 4
    ch = n / courses
    cw = n / per
    noise = tile_noise(n, 16, 3, 3)
    for r in range(courses):
        off = (cw / 2) if r % 2 else 0
        for c in range(per + 1):
            x0 = int(c * cw - cw / 2 + off + 3)
            x1 = int(c * cw + cw / 2 + off - 3)
            y0 = int(r * ch + 3)
            y1 = int((r + 1) * ch - 3)
            base = np.array([0.50, 0.19, 0.13]) * (0.78 + rng.rand() * 0.42)
            base = base + np.array([0.04, 0.02, 0.02]) * (rng.rand() - 0.5) * 3
            for yy in range(y0, y1):
                for xx in range(x0, x1):
                    img[yy % n, xx % n] = base
    img = img * (0.88 + 0.24 * noise[:, :, None])
    save_png("brick_c.png", img)
    # concrete slab 1.5 m with joints on the borders
    nz = tile_noise(n, 8, 5, 5)
    g = 0.58 + 0.20 * nz
    c = np.stack([g, g * 0.99, g * 0.96], axis=2)
    fine = np.random.RandomState(11).rand(n, n).astype(np.float32)
    c *= (0.96 + 0.08 * fine[:, :, None])
    c[:5, :, :] *= 0.45
    c[:, :5, :] *= 0.45
    save_png("concrete_c.png", c)
    # asphalt
    nz = tile_noise(n, 8, 9, 5)
    fine = np.random.RandomState(13).rand(n, n).astype(np.float32)
    g = 0.17 + 0.07 * nz + 0.05 * fine
    a = np.stack([g, g, g * 1.04], axis=2)
    save_png("asphalt_c.png", a)
    # grass (late autumn)
    nz = tile_noise(n, 16, 21, 5)
    fine = np.random.RandomState(17).rand(n, n).astype(np.float32)
    base = np.stack([0.30 + 0.10 * nz, 0.34 + 0.10 * nz, 0.15 + 0.04 * nz], axis=2)
    base *= (0.85 + 0.30 * fine[:, :, None])
    save_png("grass_c.png", base)
    # wood: horizontal grey-painted boards, 0.9 m tile / 8 boards
    nz = tile_noise(n, 32, 31, 3)
    wd = np.zeros((n, n, 3), dtype=np.float32)
    bh = n // 8
    for i in range(8):
        tone = 0.80 + 0.2 * ((i * 37) % 7) / 7
        wd[i * bh:(i + 1) * bh] = np.array([0.42, 0.40, 0.37]) * tone
        wd[i * bh:i * bh + 3] *= 0.45
    wd *= (0.9 + 0.2 * nz[:, :, None])
    save_png("deck_c.png", wd)
    # vertical wooden fence planks
    pl = np.zeros((n, n, 3), dtype=np.float32)
    pw = n // 6
    for i in range(6):
        tone = 0.75 + 0.25 * ((i * 53) % 5) / 5
        pl[:, i * pw:(i + 1) * pw] = np.array([0.45, 0.33, 0.22]) * tone
        pl[:, i * pw:i * pw + 3] *= 0.4
    pl *= (0.88 + 0.24 * tile_noise(n, 24, 41, 3)[:, :, None])
    save_png("fence_c.png", pl)
    # roof membrane / gravel
    nz = tile_noise(n, 24, 51, 4)
    fine = np.random.RandomState(19).rand(n, n).astype(np.float32)
    g = 0.22 + 0.10 * nz + 0.08 * fine
    save_png("roof_c.png", np.stack([g, g, g * 1.03], axis=2))
    # clapboard siding (cream), 0.9 m / 10 boards
    nz = tile_noise(n, 16, 61, 3)
    sd = np.zeros((n, n, 3), dtype=np.float32)
    sh = n // 10
    for i in range(10):
        sd[i * sh:(i + 1) * sh] = np.array([0.80, 0.77, 0.68])
        sd[i * sh:i * sh + 5] *= 0.55
    sd *= (0.93 + 0.14 * nz[:, :, None])
    save_png("siding_c.png", sd)


# ----------------------------------------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------------------------------------
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


MATS = {}
TILE = {}     # material name -> metres per UV unit


def make_mat(name, hexc, rough=0.7, metal=0.0, alpha=1.0, tex=None, tile=1.0, emit=None, tint=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    r, g, bl = hexcol(hexc)
    b.inputs["Base Color"].default_value = (r, g, bl, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    # Textured materials (tex=...) are NOT embedded in the .glb: Godot swaps in game/environments/windsor/exterior/
    # materials/<name>.tres (see OOTMaterialRemap) that use textures/<tex>. The flat colour here is the fallback.
    if tex and tint:
        r2, g2, b2 = hexcol(tint)
        b.inputs["Base Color"].default_value = (r2 * 0.6, g2 * 0.6, b2 * 0.6, 1.0)
    elif tex:
        b.inputs["Base Color"].default_value = (0.3, 0.2, 0.16, 1.0)
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except Exception:
            pass
    if emit:
        er, eg, eb = hexcol(emit[0])
        b.inputs["Emission Color"].default_value = (er, eg, eb, 1.0)
        b.inputs["Emission Strength"].default_value = emit[1]
    m.diffuse_color = (r, g, bl, alpha)
    MATS[name] = m
    TILE[name] = tile
    return m


def build_materials():
    make_mat("Brick", "#ffffff", 0.85, tex="brick_c.png", tile=0.9)
    make_mat("BrickTan", "#e2c9a4", 0.85, tex="brick_c.png", tile=0.9, tint="#e8d6b0")
    make_mat("BrickBrown", "#7a5a48", 0.85, tex="brick_c.png", tile=0.9, tint="#a58978")
    make_mat("Trim", "#ece9e1", 0.55)
    make_mat("TrimDark", "#2b2d30", 0.5)
    make_mat("Concrete", "#ffffff", 0.9, tex="concrete_c.png", tile=1.5)
    make_mat("Deck", "#ffffff", 0.75, tex="deck_c.png", tile=0.9)
    make_mat("Roof", "#ffffff", 0.95, tex="roof_c.png", tile=1.5)
    make_mat("Siding", "#ffffff", 0.8, tex="siding_c.png", tile=0.9)
    make_mat("SidingBlue", "#8aa0b2", 0.8, tex="siding_c.png", tile=0.9, tint="#9fb4c4")
    make_mat("Fence", "#ffffff", 0.9, tex="fence_c.png", tile=0.9)
    make_mat("Glass", "#2a3a44", 0.05, metal=0.0, alpha=0.7)
    make_mat("GlassShop", "#4a6270", 0.04, alpha=0.55)
    make_mat("Blind", "#cfc7b4", 0.9)
    make_mat("DoorBlue", "#2f4b6e", 0.5)
    make_mat("DoorGreen", "#2f5a3c", 0.5)
    make_mat("DoorMain", "#6c1f20", 0.5)
    make_mat("Brass", "#c9a24a", 0.3, metal=1.0)
    make_mat("Steel", "#8c9096", 0.4, metal=1.0)
    make_mat("MailGrey", "#7a8088", 0.4, metal=0.8)
    make_mat("Dumpster", "#244d34", 0.55, metal=0.3)
    make_mat("DumpsterLid", "#16171a", 0.6)
    make_mat("BinBlue", "#245a8c", 0.6)
    make_mat("BinGrey", "#4a4d50", 0.6)
    make_mat("PoleWood", "#4a3a2c", 0.9)
    make_mat("Wire", "#101010", 0.6)
    make_mat("Awning1", "#7d2a2a", 0.8)
    make_mat("Awning2", "#2a5a4a", 0.8)
    make_mat("Awning3", "#2a3a6a", 0.8)
    make_mat("SignPanel", "#e8e4d6", 0.6)
    make_mat("SignBack", "#2a2d33", 0.6)
    make_mat("BusRed", "#a8281f", 0.5)
    make_mat("Bark", "#3a2f27", 0.95)
    make_mat("LeafOrange", "#c4741f", 0.9)
    make_mat("LeafYellow", "#d3a82c", 0.9)
    make_mat("LeafRust", "#9b4a1c", 0.9)
    make_mat("Skin", "#b98a68", 0.8)
    make_mat("Skin2", "#8a5d44", 0.8)
    make_mat("Skin3", "#e0b896", 0.8)
    make_mat("CoatNavy", "#25324a", 0.9)
    make_mat("CoatRed", "#7a2a28", 0.9)
    make_mat("CoatGrey", "#555a60", 0.9)
    make_mat("CoatOlive", "#4c5236", 0.9)
    make_mat("Jeans", "#33435d", 0.9)
    make_mat("Black", "#151515", 0.8)
    make_mat("Hair", "#2a2018", 0.9)
    make_mat("Number", "#d9b45a", 0.3, metal=1.0)
    make_mat("NumberDark", "#1c1d1f", 0.5)
    make_mat("Light", "#fff1c9", 0.3, emit=("#fff1c9", 0.0))


# ----------------------------------------------------------------------------------------------------------
# geometry builder in Godot coordinates
# ----------------------------------------------------------------------------------------------------------
class GB:
    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def box(self, x0, y0, z0, x1, y1, z1, mat):
        """Axis-aligned box from min/max corners (Godot coords)."""
        if x1 <= x0 or y1 <= y0 or z1 <= z0:
            return
        c = G((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
        m = Matrix.Translation(c) @ Matrix.Diagonal((x1 - x0, z1 - z0, y1 - y0, 1.0))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        i = self.mi(mat)
        for f in {f for v in r["verts"] for f in v.link_faces}:
            f.material_index = i

    def boxc(self, cx, cy, cz, sx, sy, sz, mat):
        self.box(cx - sx / 2, cy - sy / 2, cz - sz / 2, cx + sx / 2, cy + sy / 2, cz + sz / 2, mat)

    def cyl(self, cx, y0, cz, r, h, mat, seg=14, axis="y"):
        """Vertical (axis y) or horizontal cylinder; for horizontal the centre is (cx, y0, cz) and h is the length."""
        if axis == "y":
            m = Matrix.Translation(G(cx, y0 + h / 2, cz))
        elif axis == "x":
            m = Matrix.Translation(G(cx, y0, cz)) @ Matrix.Rotation(math.radians(90), 4, "Y")
        else:
            m = Matrix.Translation(G(cx, y0, cz)) @ Matrix.Rotation(math.radians(90), 4, "X")
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r,
                                    depth=h, matrix=m)
        i = self.mi(mat)
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.material_index = i

    def rod(self, p0, p1, r, mat, seg=6):
        a, b = G(*p0), G(*p1)
        d = b - a
        q = d.to_track_quat("Z", "Y").to_matrix().to_4x4()
        m = Matrix.Translation((a + b) / 2) @ q
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r, radius2=r,
                                    depth=d.length, matrix=m)
        i = self.mi(mat)
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.material_index = i

    def sphere(self, cx, cy, cz, r, mat, scale=(1, 1, 1), u=8, v=6):
        m = Matrix.Translation(G(cx, cy, cz)) @ Matrix.Diagonal((scale[0], scale[2], scale[1], 1.0))
        res = bmesh.ops.create_uvsphere(self.bm, u_segments=u, v_segments=v, radius=r, matrix=m)
        i = self.mi(mat)
        for f in {f for v_ in res["verts"] for f in v_.link_faces}:
            f.material_index = i

    def prism_roof(self, x0, x1, z0, z1, y0, ridge_h, mat, ridge_axis="x", overhang=0.3):
        """Gable roof over a rectangle (ridge along x or z)."""
        bm = self.bm
        i = self.mi(mat)
        x0 -= overhang
        x1 += overhang
        z0 -= overhang
        z1 += overhang
        if ridge_axis == "x":
            zm = (z0 + z1) / 2
            pts = [(x0, y0, z0), (x1, y0, z0), (x1, y0 + ridge_h, zm), (x0, y0 + ridge_h, zm),
                   (x0, y0, z1), (x1, y0, z1)]
            quads = [(0, 1, 2, 3), (4, 5, 2, 3)]
            tris = [(0, 3, 4), (1, 5, 2)]
        else:
            xm = (x0 + x1) / 2
            pts = [(x0, y0, z0), (x0, y0, z1), (xm, y0 + ridge_h, z1), (xm, y0 + ridge_h, z0),
                   (x1, y0, z0), (x1, y0, z1)]
            quads = [(0, 1, 2, 3), (4, 5, 2, 3)]
            tris = [(0, 3, 4), (1, 5, 2)]
        vs = [bm.verts.new(G(*p)) for p in pts]
        for q in quads:
            f = bm.faces.new([vs[k] for k in q])
            f.material_index = i
        for t in tris:
            f = bm.faces.new([vs[k] for k in t])
            f.material_index = i
        # underside / base
        f = bm.faces.new([vs[0], vs[1], vs[5], vs[4]])
        f.material_index = i

    def finish(self, name, col, origin=(0, 0, 0), smooth=False):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        uv = bm.loops.layers.uv.new("UVMap")
        for f in bm.faces:
            mat = self.mats[f.material_index] if f.material_index < len(self.mats) else None
            tile = TILE.get(mat, 1.0)
            n = f.normal
            ax, ay, az = abs(n.x), abs(n.y), abs(n.z)
            for l in f.loops:
                p = l.vert.co
                if az >= ax and az >= ay:
                    u_, v_ = p.x, p.y
                elif ay >= ax:
                    u_, v_ = p.x, p.z
                else:
                    u_, v_ = p.y, p.z
                l[uv].uv = (u_ / tile, v_ / tile)
        if origin != (0, 0, 0):
            bmesh.ops.translate(bm, verts=bm.verts, vec=-G(*origin))
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        for n_ in self.mats:
            me.materials.append(MATS[n_])
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        if origin != (0, 0, 0):
            ob.location = G(*origin)
        for p in me.polygons:
            p.use_smooth = smooth
        return ob


# ----------------------------------------------------------------------------------------------------------
# helpers: walls with openings, windows, doors, text
# ----------------------------------------------------------------------------------------------------------
def wall_x(gb, z0, z1, x0, x1, y0, y1, openings, mat):
    """Wall slab along X between z0..z1 (thickness) from x0..x1, y0..y1, cut by openings [(xa, xb, ya, yb), ...]."""
    ys = sorted({y0, y1} | {o[2] for o in openings} | {o[3] for o in openings})
    for ya, yb in zip(ys[:-1], ys[1:]):
        ym = (ya + yb) / 2
        cuts = sorted([(o[0], o[1]) for o in openings if o[2] <= ym <= o[3]])
        x = x0
        for ca, cb in cuts:
            if ca > x:
                gb.box(x, ya, z0, ca, yb, z1, mat)
            x = max(x, cb)
        if x < x1:
            gb.box(x, ya, z0, x1, yb, z1, mat)


def wall_z(gb, x0, x1, z0, z1, y0, y1, openings, mat):
    """Wall slab along Z between x0..x1 (thickness), z0..z1, cut by openings [(za, zb, ya, yb)]."""
    ys = sorted({y0, y1} | {o[2] for o in openings} | {o[3] for o in openings})
    for ya, yb in zip(ys[:-1], ys[1:]):
        ym = (ya + yb) / 2
        cuts = sorted([(o[0], o[1]) for o in openings if o[2] <= ym <= o[3]])
        z = z0
        for ca, cb in cuts:
            if ca > z:
                gb.box(x0, ya, z, x1, yb, ca, mat)
            z = max(z, cb)
        if z < z1:
            gb.box(x0, ya, z, x1, yb, z1, mat)


def window_x(gb, cx, y0, y1, w, zf, face=1, depth=0.12, dark=True):
    """Window on a wall running along X whose outer face is at z = zf (face=+1: the wall faces +Z, -1: faces -Z)."""
    x0, x1 = cx - w / 2, cx + w / 2
    zo = zf
    zi = zf - face * depth
    zlo, zhi = min(zo, zi), max(zo, zi)
    fw = 0.07
    # frame
    gb.box(x0 - fw, y0 - fw, zlo - 0.02 * (face < 0), x1 + fw, y0, zhi + 0.02 * (face > 0), "Trim")      # sill (proud)
    gb.box(x0 - fw, y1, zlo, x1 + fw, y1 + fw, zhi, "Trim")                                             # head
    gb.box(x0 - fw, y0, zlo, x0, y1, zhi, "Trim")
    gb.box(x1, y0, zlo, x1 + fw, y1, zhi, "Trim")
    zg = zf - face * depth * 0.55
    gb.box(x0, y0, zg - 0.01, x1, y1, zg + 0.01, "Glass")
    gb.box(cx - 0.02, y0, zg - 0.02, cx + 0.02, y1, zg + 0.02, "Trim")                                  # mullion
    gb.box(x0, (y0 + y1) / 2 - 0.02, zg - 0.02, x1, (y0 + y1) / 2 + 0.02, zg + 0.02, "Trim")
    # blind / dark interior behind the glass so it never reads as a hole
    zb = zf - face * (depth - 0.02)
    gb.box(x0, y0, min(zb, zb - face * 0.02), x1, y1, max(zb, zb - face * 0.02), "Blind" if not dark else "TrimDark")


def window_z(gb, cz, y0, y1, w, xf, face=1, depth=0.12):
    """Same for a wall running along Z whose outer face is at x = xf (face=+1 faces +X, -1 faces -X)."""
    z0, z1 = cz - w / 2, cz + w / 2
    xi = xf - face * depth
    xlo, xhi = min(xf, xi), max(xf, xi)
    fw = 0.07
    gb.box(xlo - 0.02 * (face < 0), y0 - fw, z0 - fw, xhi + 0.02 * (face > 0), y0, z1 + fw, "Trim")
    gb.box(xlo, y1, z0 - fw, xhi, y1 + fw, z1 + fw, "Trim")
    gb.box(xlo, y0, z0 - fw, xhi, y1, z0, "Trim")
    gb.box(xlo, y0, z1, xhi, y1, z1 + fw, "Trim")
    xg = xf - face * depth * 0.55
    gb.box(xg - 0.01, y0, z0, xg + 0.01, y1, z1, "Glass")
    gb.box(xg - 0.02, y0, cz - 0.02, xg + 0.02, y1, cz + 0.02, "Trim")
    xb = xf - face * (depth - 0.02)
    gb.box(min(xb, xb - face * 0.02), y0, z0, max(xb, xb - face * 0.02), y1, z1, "TrimDark")


def window_flat_x(gb, cx, y0, y1, w, zf, face=1):
    """A window drawn ON a flat wall face (no recess): frame, glass, muntins. For solid-box buildings (houses, shops)."""
    x0, x1 = cx - w / 2, cx + w / 2
    fw = 0.07
    z0 = zf if face > 0 else zf - 0.05
    z1 = zf + 0.05 if face > 0 else zf
    gb.box(x0 - fw, y0 - fw, z0, x1 + fw, y0, z1 + 0.02 * (face > 0), "Trim")
    gb.box(x0 - fw, y1, z0, x1 + fw, y1 + fw, z1, "Trim")
    gb.box(x0 - fw, y0, z0, x0, y1, z1, "Trim")
    gb.box(x1, y0, z0, x1 + fw, y1, z1, "Trim")
    zg0 = z0 + 0.01 if face > 0 else z0
    zg1 = z1 if face > 0 else z1 - 0.01
    gb.box(x0, y0, zg0, x1, y1, zg1 - 0.012 * face, "TrimDark")
    zq = (zg1 - 0.004) if face > 0 else (zg0 + 0.004)
    gb.box(x0, y0, zq - 0.004, x1, y1, zq + 0.004, "Glass")
    gb.box(cx - 0.02, y0, z0, cx + 0.02, y1, z1 + 0.012 * (face > 0), "Trim")
    gb.box(x0, (y0 + y1) / 2 - 0.02, z0, x1, (y0 + y1) / 2 + 0.02, z1 + 0.012 * (face > 0), "Trim")


def make_text(name, text, size, pos_g, face, col, mat="Number", extrude=0.006, bold=False):
    """Flat 3-D text (a real mesh) at pos_g (Godot coords) facing `face` ('+z', '-z', '+x', '-x')."""
    cu = bpy.data.curves.new(name + "_c", "FONT")
    cu.body = text
    cu.size = size
    cu.extrude = extrude
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    ob = bpy.data.objects.new(name + "_tmp", cu)
    col.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    col.objects.unlink(ob)
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    # text lies in XY facing +Z with up = +Y. Rotate so the face points to the requested Godot direction (Blender:
    # +z godot = -Y blender, -z = +Y, +x = +X, -x = -X) with up = +Z.
    rot = {"+z": Matrix.Rotation(math.radians(90), 4, "X"),
           "-z": Matrix.Rotation(math.radians(180), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X"),
           "+x": Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Rotation(math.radians(-90), 4, "Z") @
           Matrix.Rotation(math.radians(90), 4, "X"),
           "-x": Matrix.Rotation(math.radians(-90), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")}[face]
    if face == "+x":
        rot = Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Rotation(math.radians(90), 4, "X")
    me.transform(Matrix.Translation(G(*pos_g)) @ rot)
    me.materials.append(MATS[mat])
    for p in me.polygons:
        p.use_smooth = False
    o = bpy.data.objects.new(name, me)
    col.objects.link(o)
    return o


# ----------------------------------------------------------------------------------------------------------
# Mani's building
# ----------------------------------------------------------------------------------------------------------
DECK_Y = 2.9
FLOOR_H = 2.9
RISERS = 15
RISE = DECK_Y / RISERS
TREAD = 0.24
STAIR_Z0 = 6.0
TOWER_X0, TOWER_X1 = -5.4, -3.0
LOBBY_Z1 = 11.4                # inner face of the lobby's south wall
MAIN_DOOR_X = -3.9
MAIN_DOOR_W = 0.95
FLAT2_X = 2.0


def build_building(col):
    objs = []
    b = GB()               # brick walls (the only mesh that also gets trimesh collision in Godot: name starts Collide_)
    # --- main mass: front wall (z 4.15..4.5), back, sides
    t = 0.35
    # openings on the front (outer face z=4.5)
    gh = (0.85, 2.15)
    uh = (DECK_Y + 0.85, DECK_Y + 2.15)
    front_open = []
    for cx in (-1.0, 2.0, 4.0):
        front_open.append((cx - 0.55, cx + 0.55, gh[0], gh[1]))
    front_open += [(-4.0 - 0.55, -4.0 + 0.55, uh[0], uh[1]), (-1.0 - 0.55, -1.0 + 0.55, uh[0], uh[1]),
                   (4.0 - 0.55, 4.0 + 0.55, uh[0], uh[1]),
                   (FLAT2_X - 0.5, FLAT2_X + 0.5, DECK_Y, DECK_Y + 2.15)]
    wall_x(b, 4.5 - t, 4.5, -5.0, 5.0, 0.0, 5.7, front_open, "Brick")
    back_open = [(cx - 0.55, cx + 0.55, gh[0], gh[1]) for cx in (-3.5, 2.5, 4.0)]
    back_open += [(cx - 0.55, cx + 0.55, uh[0], uh[1]) for cx in (-3.5, -1.0, 1.5, 4.0)]
    back_open += [(-1.0 - 0.5, -1.0 + 0.5, 0.0, 2.1)]       # flat 1 back door
    wall_x(b, -4.5, -4.5 + t, -5.0, 5.0, 0.0, 5.7, back_open, "Brick")
    east_open = [(z - 0.55, z + 0.55, gh[0], gh[1]) for z in (2.6, -0.2, -2.8)]
    east_open += [(z - 0.55, z + 0.55, uh[0], uh[1]) for z in (2.6, -0.2, -2.8)]
    wall_z(b, 5.0 - t, 5.0, -4.5, 4.5, 0.0, 5.7, east_open, "Brick")
    west_open = [(z - 0.55, z + 0.55, gh[0], gh[1]) for z in (-2.0, 0.5)]
    west_open += [(z - 0.55, z + 0.55, uh[0], uh[1]) for z in (-2.0, 0.5)]
    wall_z(b, -5.0, -5.0 + t, -4.5, 4.5, 0.0, 5.7, west_open, "Brick")
    # corbel band + parapet + coping
    b.box(-5.08, 5.4, -4.58, 5.08, 5.7, 4.58, "Brick")
    b.box(-5.0, 5.7, -4.5, 5.0, 6.25, -4.5 + 0.3, "Brick")
    b.box(-5.0, 5.7, 4.5 - 0.3, 5.0, 6.25, 4.5, "Brick")
    b.box(-5.0, 5.7, -4.5, -5.0 + 0.3, 6.25, 4.5, "Brick")
    b.box(5.0 - 0.3, 5.7, -4.5, 5.0, 6.25, 4.5, "Brick")
    b.box(-5.0, 2.85, -4.5, 5.0, 2.95, 4.5, "Brick")      # floor band (hidden inside; keeps the section closed)
    # foundation course
    b.box(-5.05, 0.0, -4.55, 5.05, 0.35, 4.55, "Concrete")
    # --- stair tower (west wing): west wall, lobby east wall, lobby south wall with the main door
    tw0 = TOWER_X0
    b.box(tw0 - 0.2, 0.0, 4.5, tw0, 5.7, LOBBY_Z1 + 0.2, "Brick")                # west wall
    main_open = [(MAIN_DOOR_X - MAIN_DOOR_W / 2 - 0.0, MAIN_DOOR_X + MAIN_DOOR_W / 2, 0.0, 2.15),
                 (MAIN_DOOR_X - MAIN_DOOR_W / 2, MAIN_DOOR_X + MAIN_DOOR_W / 2, 2.15, 2.55)]
    wall_x(b, LOBBY_Z1, LOBBY_Z1 + 0.2, tw0 - 0.2, TOWER_X1 + 0.2, 0.0, 3.35, [(main_open[0][0], main_open[0][1], 0.0, 2.55)], "Brick")
    flat1_z = 10.2
    wall_z(b, TOWER_X1, TOWER_X1 + 0.2, 8.4, LOBBY_Z1 + 0.2, 0.0, 3.35, [(flat1_z - 0.5, flat1_z + 0.5, 0.0, 2.15)], "Brick")
    b.box(tw0 - 0.28, 3.0, 8.4, TOWER_X1 + 0.28, 3.35, LOBBY_Z1 + 0.28, "Brick")  # lobby cornice
    # lobby floor / landing slab
    objs.append(b.finish("Collide_Walls", col))

    c = GB()               # concrete: foundation steps, stair mass, lobby floor, walks
    for i in range(RISERS):
        z0 = STAIR_Z0 + i * TREAD
        top = DECK_Y - (i + 1) * RISE
        c.box(tw0, 0.0, z0, TOWER_X1, top, z0 + TREAD, "Concrete")
    c.box(tw0, 0.0, 9.6, TOWER_X1, 0.03, LOBBY_Z1, "Concrete")
    c.box(MAIN_DOOR_X - 0.6, 0.0, LOBBY_Z1, MAIN_DOOR_X + 0.6, 0.04, LOBBY_Z1 + 0.5, "Concrete")   # threshold slab
    objs.append(c.finish("Stairs", col))

    d = GB()               # timber deck + posts + railings (collide)
    d.box(tw0, DECK_Y - 0.18, 4.5, 5.0, DECK_Y, STAIR_Z0, "Deck")                       # deck incl. the top landing
    d.box(tw0 - 0.05, DECK_Y - 0.4, 4.5, 5.05, DECK_Y - 0.18, STAIR_Z0 + 0.05, "Trim")  # fascia beam
    post_x = [TOWER_X1, -0.4, FLAT2_X + 1.8, 4.9]
    for x in post_x:
        d.box(x - 0.08, 0.0, 5.84, x + 0.08, 5.5, 6.0, "Trim")
    # verandah railing along z = 6.0 (from the tower opening to the east end) and the east end
    def railing(p0, p1, y0, h=1.02):
        d.rod((p0[0], y0 + h, p0[1]), (p1[0], y0 + h, p1[1]), 0.035, "Trim")
        d.rod((p0[0], y0 + 0.1, p0[1]), (p1[0], y0 + 0.1, p1[1]), 0.03, "Trim")
        n = max(2, int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) / 0.14))
        for i in range(n + 1):
            t_ = i / n
            x = p0[0] + (p1[0] - p0[0]) * t_
            z = p0[1] + (p1[1] - p0[1]) * t_
            d.box(x - 0.015, y0 + 0.1, z - 0.015, x + 0.015, y0 + h, z + 0.015, "Trim")
    railing((TOWER_X1, 5.95), (5.0, 5.95), DECK_Y)
    railing((4.97, 5.95), (4.97, 4.5), DECK_Y)
    # open east side of the tower stairs: sloped railing + posts
    z_top, z_bot = STAIR_Z0, STAIR_Z0 + RISERS * TREAD
    sx = TOWER_X1 - 0.04
    for i in range(0, RISERS + 1, 3):
        z = STAIR_Z0 + i * TREAD
        y = DECK_Y - i * RISE
        d.box(sx - 0.04, y, z - 0.04, sx + 0.04, y + 1.0, z + 0.04, "Trim")
    d.rod((sx, DECK_Y + 1.0, z_top), (sx, 1.0, z_bot), 0.035, "Trim")
    d.rod((sx, DECK_Y + 0.5, z_top), (sx, 0.5, z_bot), 0.025, "Trim")
    # posts supporting the tower roof
    for z in (6.0, 8.4):
        d.box(TOWER_X1 - 0.08, 0.0, z - 0.08, TOWER_X1 + 0.08, 5.5, z + 0.08, "Trim")
    objs.append(d.finish("Collide_Verandah", col))

    r = GB()               # roofs (no collision)
    r.box(tw0 - 0.35, 5.45, 4.3, 5.35, 5.65, 6.5, "Roof")                     # verandah + upper tower landing
    r.box(tw0 - 0.35, 5.45, 6.5, TOWER_X1 + 0.35, 5.65, 8.6, "Roof")          # over the stairs
    r.box(tw0 - 0.3, 3.35, 8.4, TOWER_X1 + 0.3, 3.55, LOBBY_Z1 + 0.35, "Roof")  # over the lobby
    r.box(-5.05, 5.7, -4.55, 5.05, 5.9, 4.55, "Roof")                         # main roof (below the parapet)
    r.box(-5.1, 6.25, -4.55, 5.1, 6.32, 4.55, "Trim")                         # coping
    objs.append(r.finish("Roof", col))

    w = GB()               # window frames + glass (no collision)
    for cx in (-1.0, 2.0, 4.0):
        window_x(w, cx, gh[0], gh[1], 1.1, 4.5)
    for cx in (-4.0, -1.0, 4.0):
        window_x(w, cx, uh[0], uh[1], 1.1, 4.5)
    for cx in (-3.5, 2.5, 4.0):
        window_x(w, cx, gh[0], gh[1], 1.1, -4.5 + t, face=-1)
    for cx in (-3.5, -1.0, 1.5, 4.0):
        window_x(w, cx, uh[0], uh[1], 1.1, -4.5 + t, face=-1)
    for z in (2.6, -0.2, -2.8):
        window_z(w, z, gh[0], gh[1], 1.1, 5.0)
        window_z(w, z, uh[0], uh[1], 1.1, 5.0)
    for z in (-2.0, 0.5):
        window_z(w, z, gh[0], gh[1], 1.1, -5.0 + t, face=-1)
        window_z(w, z, uh[0], uh[1], 1.1, -5.0 + t, face=-1)
    # lobby transom over the main door
    w.box(MAIN_DOOR_X - MAIN_DOOR_W / 2 - 0.05, 2.15, LOBBY_Z1 + 0.05, MAIN_DOOR_X + MAIN_DOOR_W / 2 + 0.05, 2.55, LOBBY_Z1 + 0.09, "Glass")
    objs.append(w.finish("Windows", col))

    # --- doors (static leaves): flat 2 on the verandah, flat 1 in the lobby; frames
    f = GB()
    # flat 2 door (closed, just left behind)
    zf = 4.5 - 0.08
    f.box(FLAT2_X - 0.5, DECK_Y, zf - 0.06, FLAT2_X - 0.43, DECK_Y + 2.12, 4.52, "Trim")
    f.box(FLAT2_X + 0.43, DECK_Y, zf - 0.06, FLAT2_X + 0.5, DECK_Y + 2.12, 4.52, "Trim")
    f.box(FLAT2_X - 0.5, DECK_Y + 2.12, zf - 0.06, FLAT2_X + 0.5, DECK_Y + 2.2, 4.52, "Trim")
    f.box(FLAT2_X - 0.43, DECK_Y, zf, FLAT2_X + 0.43, DECK_Y + 2.12, zf + 0.04, "DoorBlue")
    f.box(FLAT2_X - 0.34, DECK_Y + 0.25, zf + 0.04, FLAT2_X + 0.34, DECK_Y + 0.9, zf + 0.055, "DoorBlue")
    f.box(FLAT2_X - 0.34, DECK_Y + 1.1, zf + 0.04, FLAT2_X + 0.34, DECK_Y + 1.85, zf + 0.055, "DoorBlue")
    f.box(FLAT2_X + 0.30, DECK_Y + 0.98, zf + 0.04, FLAT2_X + 0.36, DECK_Y + 1.04, zf + 0.09, "Brass")       # handle
    f.box(FLAT2_X - 0.45, DECK_Y, 4.55, FLAT2_X + 0.45, DECK_Y + 0.02, 5.0, "TrimDark")                     # mat
    f.boxc(FLAT2_X + 0.9, DECK_Y + 2.1, 4.58, 0.14, 0.14, 0.1, "Black")                                      # porch light
    # flat 1 door in the lobby (east wall, faces -X)
    xf = TOWER_X1
    f1z = 10.2
    f.box(xf - 0.06, 0.0, f1z - 0.5, xf + 0.02, 2.12, f1z - 0.43, "Trim")
    f.box(xf - 0.06, 0.0, f1z + 0.43, xf + 0.02, 2.12, f1z + 0.5, "Trim")
    f.box(xf - 0.06, 2.12, f1z - 0.5, xf + 0.02, 2.2, f1z + 0.5, "Trim")
    f.box(xf - 0.05, 0.0, f1z - 0.43, xf - 0.01, 2.12, f1z + 0.43, "DoorGreen")
    f.box(xf - 0.065, 0.25, f1z - 0.34, xf - 0.05, 0.9, f1z + 0.34, "DoorGreen")
    f.box(xf - 0.065, 1.1, f1z - 0.34, xf - 0.05, 1.85, f1z + 0.34, "DoorGreen")
    f.box(xf - 0.1, 0.98, f1z + 0.30, xf - 0.05, 1.04, f1z + 0.36, "Brass")
    # main door frame + intercom
    mx0, mx1 = MAIN_DOOR_X - MAIN_DOOR_W / 2, MAIN_DOOR_X + MAIN_DOOR_W / 2
    zi = LOBBY_Z1
    f.box(mx0 - 0.07, 0.0, zi - 0.02, mx0, 2.2, zi + 0.22, "Trim")
    f.box(mx1, 0.0, zi - 0.02, mx1 + 0.07, 2.2, zi + 0.22, "Trim")
    f.box(mx0 - 0.07, 2.55, zi - 0.02, mx1 + 0.07, 2.62, zi + 0.22, "Trim")
    f.box(mx0, 2.15, zi - 0.02, mx1, 2.22, zi + 0.22, "Trim")
    f.box(mx1 + 0.12, 1.3, zi - 0.05, mx1 + 0.24, 1.6, zi, "TrimDark")        # intercom panel (inside face)
    f.boxc(TOWER_X1 - 0.5, 2.7, LOBBY_Z1 - 0.1, 0.22, 0.12, 0.22, "Light")      # lobby light fixture
    objs.append(f.finish("Doors", col))

    # --- mailboxes 1 and 2 on the lobby's south wall, west of the main door (face -Z toward the stairs)
    mbz = LOBBY_Z1 - 0.01
    for n_, cx in ((1, -4.54), (2, -4.88)):   # seen from the stairs (facing south) flat 1 is on the left
        m = GB()
        m.box(cx - 0.14, 1.28, mbz - 0.12, cx + 0.14, 1.58, mbz, "MailGrey")
        m.box(cx - 0.11, 1.46, mbz - 0.125, cx + 0.11, 1.49, mbz - 0.12, "TrimDark")     # slot
        m.box(cx - 0.12, 1.31, mbz - 0.125, cx + 0.12, 1.34, mbz - 0.12, "Steel")       # latch strip
        ob = m.finish("Mailbox_%d" % n_, col)
        objs.append(ob)
        objs.append(make_text("Mailbox_%d_Number" % n_, str(n_), 0.12, (cx, 1.405, mbz - 0.13), "-z", col, "NumberDark"))
    # flat numbers on each flat door
    objs.append(make_text("FlatNumber_2", "2", 0.16, (FLAT2_X, DECK_Y + 1.62, zf + 0.056 + 0.03), "+z", col, "Number"))
    objs.append(make_text("FlatNumber_1", "1", 0.16, (xf - 0.066 - 0.02, 1.62, f1z), "-x", col, "Number"))
    # small brass plates behind the numbers
    p = GB()
    p.box(FLAT2_X - 0.12, DECK_Y + 1.5, zf + 0.04, FLAT2_X + 0.12, DECK_Y + 1.76, zf + 0.056, "TrimDark")
    p.box(xf - 0.062, 1.5, f1z - 0.12, xf - 0.05, 1.76, f1z + 0.12, "TrimDark")
    objs.append(p.finish("NumberPlates", col))
    return objs


def build_main_door_leaf(col):
    """Main door leaf, origin on the hinge (bottom, mid-thickness); leaf extends along +X; front = +Z."""
    b = GB()
    w, h, th = MAIN_DOOR_W - 0.02, 2.1, 0.05
    b.box(0.0, 0.0, -th / 2, w, h, th / 2, "DoorMain")
    b.box(0.12, 0.25, th / 2, w - 0.12, 0.95, th / 2 + 0.015, "DoorMain")
    b.box(0.12, 1.15, th / 2, w - 0.12, 1.95, th / 2 + 0.015, "DoorMain")
    b.box(0.2, 1.35, th / 2 + 0.015, w - 0.2, 1.75, th / 2 + 0.02, "Glass")
    b.box(w - 0.12, 0.98, th / 2, w - 0.06, 1.04, th / 2 + 0.07, "Brass")
    b.box(w - 0.12, 0.98, -th / 2 - 0.07, w - 0.06, 1.04, -th / 2, "Brass")
    return [b.finish("MainDoorLeaf", col)]


# ----------------------------------------------------------------------------------------------------------
# neighbours, fences, lot
# ----------------------------------------------------------------------------------------------------------
def build_neighbours(col):
    objs = []
    b = GB()
    # east neighbour (graffiti wall = its west face x = 8.6) and west neighbour, as brick two-flats
    def two_flat(x0, x1, mat, alley_side):
        t = 0.35
        w = x1 - x0
        cx = (x0 + x1) / 2
        gh = (0.85, 2.15)
        uh = (DECK_Y + 0.85, DECK_Y + 2.15)
        fo = [(cx + o - 0.55, cx + o + 0.55, *gh) for o in (-w / 4, w / 4)] + \
             [(cx + o - 0.55, cx + o + 0.55, *uh) for o in (-w / 3, w / 3)] + \
             [(cx - 0.5, cx + 0.5, DECK_Y, DECK_Y + 2.15)]
        wall_x(b, 4.5 - t, 4.5, x0, x1, 0.0, 5.7, fo, mat)
        wall_x(b, -4.5, -4.5 + t, x0, x1, 0.0, 5.7,
               [(cx + o - 0.55, cx + o + 0.55, *gh) for o in (-w / 4, w / 4)] + [(cx + o - 0.55, cx + o + 0.55, *uh) for o in (-w / 4, w / 4)], mat)
        side_hi = [(z - 0.4, z + 0.4, 3.6, 4.4) for z in (1.0,)]                # one small high window on the alley side
        if alley_side == "west":
            wall_z(b, x0, x0 + t, -4.5, 4.5, 0.0, 5.7, side_hi, mat)
            wall_z(b, x1 - t, x1, -4.5, 4.5, 0.0, 5.7, [(z - 0.55, z + 0.55, *uh) for z in (-2.0, 2.0)], mat)
        else:
            wall_z(b, x1 - t, x1, -4.5, 4.5, 0.0, 5.7, side_hi, mat)
            wall_z(b, x0, x0 + t, -4.5, 4.5, 0.0, 5.7, [(z - 0.55, z + 0.55, *uh) for z in (-2.0, 2.0)], mat)
        b.box(x0 - 0.08, 5.4, -4.58, x1 + 0.08, 5.7, 4.58, mat)
        b.box(x0, 5.7, -4.5, x1, 6.2, -4.2, mat)
        b.box(x0, 5.7, 4.2, x1, 6.2, 4.5, mat)
        b.box(x0, 5.7, -4.5, x0 + 0.3, 6.2, 4.5, mat)
        b.box(x1 - 0.3, 5.7, -4.5, x1, 6.2, 4.5, mat)
        b.box(x0 - 0.05, 0.0, -4.55, x1 + 0.05, 0.3, 4.55, "Concrete")
        b.box(x0, 5.7, -4.5, x1, 5.9, 4.5, "Roof")
        # verandah
        b.box(x0, DECK_Y - 0.18, 4.5, x1, DECK_Y, 6.0, "Deck")
        for x in (x0 + 0.1, x1 - 0.1, cx):
            b.box(x - 0.08, 0.0, 5.84, x + 0.08, 5.5, 6.0, "Trim")
        b.box(x0 - 0.2, 5.45, 4.3, x1 + 0.2, 5.65, 6.5, "Roof")
        b.box(x0, DECK_Y + 1.0, 5.93, x1, DECK_Y + 1.05, 5.99, "Trim")
        b.box(x0, DECK_Y + 0.1, 5.95, x1, DECK_Y + 0.14, 5.99, "Trim")
        wins = GB()
        for o in (-w / 4, w / 4):
            window_x(wins, cx + o, gh[0], gh[1], 1.1, 4.5)
            window_x(wins, cx + o, gh[0], gh[1], 1.1, -4.5 + t, face=-1)
        for o in (-w / 3, w / 3):
            window_x(wins, cx + o, uh[0], uh[1], 1.1, 4.5)
        for o in (-w / 4, w / 4):
            window_x(wins, cx + o, uh[0], uh[1], 1.1, -4.5 + t, face=-1)
        if alley_side == "west":
            window_z(wins, 1.0, 3.6, 4.4, 0.8, x0 + t - 0.0, face=-1)
        return wins

    wins1 = two_flat(8.6, 18.6, "BrickBrown", "west")
    wins2 = two_flat(-16.5, -6.7, "BrickTan", "east")
    objs.append(b.finish("Collide_Neighbours", col))
    # merge windows (no collision)
    objs.append(wins1.finish("Neighbour_East_Windows", col))
    objs.append(wins2.finish("Neighbour_West_Windows", col))
    # fences (wood): lot west + back, alley front-yard sides, lot east
    fnc = GB()

    def fence(x0, z0, x1, z1, h=1.8):
        L = math.hypot(x1 - x0, z1 - z0)
        if abs(x1 - x0) > abs(z1 - z0):
            fnc.box(min(x0, x1), 0.0, z0 - 0.025, max(x0, x1), h, z0 + 0.025, "Fence")
            n = int(L / 2.4) + 1
            for i in range(n + 1):
                x = min(x0, x1) + L * i / n
                fnc.box(x - 0.06, 0.0, z0 - 0.07, x + 0.06, h + 0.06, z0 + 0.07, "Trim")
        else:
            fnc.box(x0 - 0.025, 0.0, min(z0, z1), x0 + 0.025, h, max(z0, z1), "Fence")
            n = int(L / 2.4) + 1
            for i in range(n + 1):
                z = min(z0, z1) + L * i / n
                fnc.box(x0 - 0.07, 0.0, z - 0.06, x0 + 0.07, h + 0.06, z + 0.06, "Trim")
    fence(-8.5, -4.5, -8.5, -18.5)                       # lot west
    fence(-8.5, -18.5, -3.0, -18.5)                      # lot back, west of the driveway
    fence(3.6, -18.5, 8.6, -18.5)                        # lot back, east of the driveway
    fence(8.6, -4.5, 8.6, -18.5)                         # lot east (neighbour's back yard)
    # low front-yard fences along the alley (keeps the alley an alley)
    fence(5.05, 6.2, 5.05, 12.6, 1.05)
    fence(8.6, 6.2, 8.6, 12.6, 1.05)
    objs.append(fnc.finish("Collide_Fences", col))
    return objs


def build_alley_props(col):
    """Dumpster, bins, pallet, crates, meters, downspouts, two utility poles with wires (world positions)."""
    objs = []
    d = GB()
    cx, cz = 7.8, -1.6         # against the east wall (x = 8.6), centred on z -1.6
    sx, sz, h = 1.4, 2.5, 1.45
    d.box(cx - sx / 2, 0.18, cz - sz / 2, cx + sx / 2, h, cz + sz / 2, "Dumpster")
    d.box(cx - sx / 2 - 0.03, 0.0, cz - sz / 2 + 0.1, cx + sx / 2 + 0.03, 0.18, cz + sz / 2 - 0.1, "Black")
    d.box(cx - sx / 2 - 0.04, h, cz - sz / 2 - 0.02, cx + sx / 2 + 0.04, h + 0.08, cz + sz / 2 + 0.02, "DumpsterLid")
    for z in (cz - 0.7, cz + 0.7):                                    # ribs
        d.box(cx - sx / 2 - 0.02, 0.3, z - 0.03, cx - sx / 2, h - 0.05, z + 0.03, "Steel")
    d.box(cx - sx / 2 - 0.03, 0.18, cz - 0.9, cx - sx / 2 + 0.0, 0.3, cz + 0.9, "Steel")
    d.box(cx - 0.55, h + 0.08, cz + 0.75, cx + 0.55, h + 0.12, cz + 1.1, "DumpsterLid")
    objs.append(d.finish("Dumpster", col))
    b = GB()
    for (x, z, mat) in ((5.65, 1.2, "BinBlue"), (5.65, 0.35, "BinGrey"), (5.65, -0.5, "BinBlue")):
        b.box(x - 0.3, 0.0, z - 0.25, x + 0.3, 1.0, z + 0.25, mat)
        b.box(x - 0.32, 1.0, z - 0.27, x + 0.32, 1.06, z + 0.27, "Black")
    # a few flattened boxes stacked at the lot end of the west wall (kept out of the walking line)
    b.box(5.15, 0.0, -2.35, 5.55, 0.45, -1.85, "Deck")
    # gas meter + pipe on the building wall, AC condenser at the rear
    b.box(5.0, 0.9, 1.6, 5.1, 1.35, 2.0, "Steel")
    b.rod((5.05, 0.9, 1.8), (5.05, 0.1, 1.8), 0.025, "Steel")
    b.box(5.1, 0.1, -3.9, 5.7, 0.95, -2.9, "BinGrey")
    b.box(5.1, 0.95, -3.9, 5.7, 1.0, -2.9, "Black")
    # downspouts
    b.box(5.0, 0.0, -4.45, 5.08, 5.4, -4.37, "Steel")
    b.box(5.0, 0.0, 3.7, 5.08, 5.4, 3.78, "Steel")
    objs.append(b.finish("AlleyClutter", col))
    # utility poles with cross arms + wires
    p = GB()
    for (x, z) in ((8.45, 9.0), (8.45, -9.5)):
        p.cyl(x, 0.0, z, 0.14, 9.0, "PoleWood", seg=10)
        p.box(x - 0.9, 8.3, z - 0.05, x + 0.9, 8.4, z + 0.05, "PoleWood")
        p.box(x - 0.6, 7.6, z - 0.04, x + 0.6, 7.7, z + 0.04, "PoleWood")
        p.box(x - 0.2, 6.4, z - 0.22, x + 0.2, 7.2, z + 0.22, "BinGrey")     # transformer
    for dx in (-0.8, 0.0, 0.8):
        for (z0, z1) in ((9.0, -9.5),):
            pts = [(8.45 + dx, 8.35 - 0.02, z0), (8.45 + dx, 7.9, (z0 + z1) / 2 + 0.0), (8.45 + dx, 8.35 - 0.02, z1)]
            for a, b_ in zip(pts[:-1], pts[1:]):
                p.rod(a, b_, 0.012, "Wire", seg=4)
    # drop to the building
    p.rod((8.45, 7.65, 9.0), (5.0, 5.6, 4.0), 0.012, "Wire", seg=4)
    p.rod((8.45, 7.65, -9.5), (5.0, 5.6, -4.0), 0.012, "Wire", seg=4)
    objs.append(p.finish("UtilityPoles", col))
    return objs


# ----------------------------------------------------------------------------------------------------------
# repeated props (origin at bottom centre, front +Z)
# ----------------------------------------------------------------------------------------------------------
def build_house(col, name, w, d, mat, style, roof="gable", stories=2, porch=True):
    b = GB()
    h = 2.7 * stories
    hw, hd = w / 2, d / 2
    b.box(-hw, 0.0, -hd, hw, h, hd, mat)
    b.box(-hw - 0.04, 0.0, -hd - 0.04, hw + 0.04, 0.3, hd + 0.04, "Concrete")
    if roof == "gable":
        b.prism_roof(-hw, hw, -hd, hd, h, 2.2, "Roof", ridge_axis="x", overhang=0.3)
    else:
        b.box(-hw - 0.1, h, -hd - 0.1, hw + 0.1, h + 0.22, hd + 0.1, "Roof")
        b.box(-hw, h + 0.22, -hd, hw, h + 0.5, hd, mat)
    wins = GB()
    n = 2 if w < 8 else 3
    for k in range(n):
        cx = -hw + (k + 0.5) * w / n
        for s in range(stories):
            y0 = s * 2.7 + 0.9
            if s == 0 and k == n // 2:
                continue
            window_flat_x(wins, cx, y0, y0 + 1.3, 1.0, hd)
    # front door + porch
    b.box(-0.45, 0.0, hd, 0.45, 2.1, hd + 0.05, "DoorGreen" if style % 2 else "DoorMain")
    if porch:
        b.box(-1.3, 0.0, hd, 1.3, 0.35, hd + 1.4, "Concrete")
        b.box(-1.4, 2.45, hd, 1.4, 2.6, hd + 1.5, "Roof")
        for x in (-1.25, 1.25):
            b.box(x - 0.07, 0.35, hd + 1.3, x + 0.07, 2.45, hd + 1.44, "Trim")
    ch = GB()
    ch.box(hw * 0.4, h - 0.2, -0.4, hw * 0.4 + 0.7, h + 2.8, 0.4, "BrickBrown")
    objs = [b.finish(name, col), wins.finish(name + "_Windows", col), ch.finish(name + "_Chimney", col)]
    return objs


def build_shop(col, name, w, mat, awn, upper_mat="Brick"):
    """Two-storey shopfront facing -Z (toward the street it faces: origin at the sidewalk edge, depth +Z away)."""
    b = GB()
    d = 10.0
    b.box(-w / 2, 0.0, 0.0, w / 2, 6.4, d, mat)
    b.box(-w / 2 - 0.05, 6.4, -0.05, w / 2 + 0.05, 6.8, d, "Trim")
    b.box(-w / 2, 6.8, 0.0, w / 2, 7.2, 0.35, mat)
    # glass front: shopfront opening
    g = GB()
    g.box(-w / 2 + 0.5, 0.35, -0.04, w / 2 - 0.5, 2.9, 0.0, "GlassShop")
    g.box(-w / 2 + 0.45, 0.0, -0.1, w / 2 - 0.45, 0.35, 0.0, "TrimDark")
    g.box(-w / 2 + 0.45, 2.9, -0.1, w / 2 - 0.45, 3.0, 0.0, "TrimDark")
    g.box(-w / 2 + 0.4, 0.35, -0.1, -w / 2 + 0.5, 2.9, 0.0, "TrimDark")
    g.box(w / 2 - 0.5, 0.35, -0.1, w / 2 - 0.4, 2.9, 0.0, "TrimDark")
    g.box(0.9, 0.0, -0.12, 1.0, 2.2, 0.0, "TrimDark")       # door stile
    # awning
    g.box(-w / 2 + 0.3, 3.05, -1.4, w / 2 - 0.3, 3.2, -0.05, awn)
    g.box(-w / 2 + 0.3, 2.85, -1.42, w / 2 - 0.3, 3.05, -1.35, awn)
    # sign board (blank; Godot adds the name as Label3D)
    g.box(-w / 2 + 0.6, 3.3, -0.12, w / 2 - 0.6, 4.1, -0.02, "SignBack")
    for k in range(2):
        cx = -w / 4 + k * w / 2
        window_flat_x(g, cx, 4.6, 5.9, 1.5, 0.0, face=-1)
    return [b.finish(name, col), g.finish(name + "_Front", col)]


def build_tree(col, name, seed, leaf="LeafOrange", bare=0.0):
    rng = random.Random(seed)
    b = GB()
    h = rng.uniform(5.5, 7.5)
    b.cyl(0, 0, 0, 0.22, h * 0.55, "Bark", seg=8)
    b.rod((0, h * 0.5, 0), (0.5, h * 0.8, 0.2), 0.12, "Bark")
    b.rod((0, h * 0.45, 0), (-0.6, h * 0.75, -0.3), 0.1, "Bark")
    l = GB()
    for i in range(7):
        a = rng.uniform(0, math.tau)
        r = rng.uniform(0.0, 1.5)
        x, z = math.cos(a) * r, math.sin(a) * r
        y = h * 0.75 + rng.uniform(-0.2, 1.4)
        mat = rng.choice([leaf, "LeafYellow", "LeafRust"] if i % 3 else [leaf])
        l.sphere(x, y, z, rng.uniform(1.0, 1.6), mat, scale=(1.0, 0.8, 1.0), u=7, v=5)
    return [b.finish(name + "_Trunk", col), l.finish(name + "_Leaves", col, smooth=True)]


def build_bus_shelter(col):
    b = GB()
    L = 3.0
    for x in (-L / 2, L / 2):
        b.box(x - 0.04, 0.0, -0.8, x + 0.04, 2.5, -0.72, "Steel")
        b.box(x - 0.04, 0.0, 0.72, x + 0.04, 2.5, 0.8, "Steel")
    b.box(-L / 2 - 0.1, 2.5, -0.9, L / 2 + 0.1, 2.6, 0.9, "Steel")
    b.box(-L / 2, 0.45, 0.6, L / 2 - 0.5, 0.5, 0.75, "Deck")          # bench
    b.box(-L / 2 + 0.1, 0.0, 0.62, -L / 2 + 0.16, 0.45, 0.73, "Steel")
    b.box(L / 2 - 0.62, 0.0, 0.62, L / 2 - 0.56, 0.45, 0.73, "Steel")
    g = GB()
    g.box(-L / 2, 0.2, 0.76, L / 2, 2.45, 0.78, "GlassShop")         # back glass
    g.box(-L / 2, 0.2, -0.8, -L / 2 + 0.02, 2.45, 0.78, "GlassShop")  # west glass
    g.box(L / 2 - 0.02, 0.2, 0.2, L / 2, 2.45, 0.78, "GlassShop")
    g.box(0.2, 0.3, 0.74, 1.2, 1.7, 0.762, "SignBack")                 # blank ad panel
    return [b.finish("BusShelter", col), g.finish("BusShelter_Glass", col)]


def build_signs(col):
    b = GB()
    b.box(-0.035, 0.0, -0.035, 0.035, 3.0, 0.035, "Steel")
    b.box(-0.3, 2.45, -0.04, 0.3, 3.0, 0.0, "BusRed")
    b.box(-0.22, 2.58, -0.045, 0.22, 2.86, -0.04, "SignPanel")
    s = GB()
    s.box(-0.035, 0.0, -0.035, 0.035, 2.5, 0.035, "Steel")
    s.box(-0.45, 2.2, -0.04, 0.45, 2.5, 0.0, "SignBack")                 # street-name blade (Godot adds the text)
    return [b.finish("BusStopSign", col), s.finish("StreetNameSign", col)]


def build_streetlight(col):
    b = GB()
    b.cyl(0, 0, 0, 0.09, 7.0, "Steel", seg=8)
    b.rod((0, 6.95, 0), (-1.8, 7.3, 0), 0.05, "Steel")
    b.box(-2.3, 7.2, -0.18, -1.7, 7.32, 0.18, "BinGrey")
    return [b.finish("Streetlight", col)]


def build_utility_pole(col):
    p = GB()
    p.cyl(0, 0, 0, 0.14, 9.0, "PoleWood", seg=10)
    p.box(-0.9, 8.3, -0.05, 0.9, 8.4, 0.05, "PoleWood")
    p.box(-0.6, 7.6, -0.04, 0.6, 7.7, 0.04, "PoleWood")
    return [p.finish("UtilityPole", col)]


def build_person(col, name, coat, trousers, skin, hair_mat="Hair", sitting=False, scale=1.0):
    b = GB()
    s = scale
    b.box(-0.13 * s, 0.0, -0.08 * s, -0.01 * s, 0.82 * s, 0.08 * s, trousers)
    b.box(0.01 * s, 0.0, -0.08 * s, 0.13 * s, 0.82 * s, 0.08 * s, trousers)
    b.box(-0.14 * s, 0.0, -0.08 * s, -0.01 * s, 0.07 * s, 0.14 * s, "Black")
    b.box(0.01 * s, 0.0, -0.08 * s, 0.14 * s, 0.07 * s, 0.14 * s, "Black")
    b.box(-0.2 * s, 0.8 * s, -0.11 * s, 0.2 * s, 1.42 * s, 0.11 * s, coat)
    b.box(-0.3 * s, 0.82 * s, -0.07 * s, -0.2 * s, 1.38 * s, 0.07 * s, coat)
    b.box(0.2 * s, 0.82 * s, -0.07 * s, 0.3 * s, 1.38 * s, 0.07 * s, coat)
    b.box(-0.29 * s, 0.7 * s, -0.05 * s, -0.21 * s, 0.82 * s, 0.05 * s, skin)
    b.box(0.21 * s, 0.7 * s, -0.05 * s, 0.29 * s, 0.82 * s, 0.05 * s, skin)
    b.box(-0.05 * s, 1.42 * s, -0.05 * s, 0.05 * s, 1.5 * s, 0.05 * s, skin)
    b.sphere(0, 1.6 * s, 0, 0.1 * s, skin, scale=(1, 1.15, 1.05), u=10, v=7)
    b.sphere(0, 1.65 * s, -0.01 * s, 0.105 * s, hair_mat, scale=(1, 1.0, 1.0), u=10, v=5)
    return [b.finish(name, col, smooth=True)]


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
    gen_textures()
    build_materials()
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    col = bpy.data.collections.new("Exterior")
    sc.collection.children.link(col)
    jobs = [
        ("building", build_building(col)),
        ("main_door_leaf", build_main_door_leaf(col)),
        ("neighbours", build_neighbours(col)),
        ("alley_props", build_alley_props(col)),
        ("house_a", build_house(col, "house_a", 8.0, 9.5, "Brick", 0)),
        ("house_b", build_house(col, "house_b", 7.0, 8.5, "Siding", 1, stories=2)),
        ("house_c", build_house(col, "house_c", 9.0, 9.0, "BrickBrown", 2, roof="flat", porch=True)),
        ("house_d", build_house(col, "house_d", 7.0, 8.0, "SidingBlue", 3, stories=1)),
        ("house_e", build_house(col, "house_e", 8.5, 9.0, "BrickTan", 4, stories=2)),
        ("shop_a", build_shop(col, "shop_a", 8.0, "Brick", "Awning1")),
        ("shop_b", build_shop(col, "shop_b", 7.0, "BrickTan", "Awning2")),
        ("shop_c", build_shop(col, "shop_c", 9.0, "BrickBrown", "Awning3")),
        ("shop_d", build_shop(col, "shop_d", 7.5, "Brick", "Awning2")),
        ("tree_a", build_tree(col, "tree_a", 1, "LeafOrange")),
        ("tree_b", build_tree(col, "tree_b", 2, "LeafYellow")),
        ("tree_c", build_tree(col, "tree_c", 3, "LeafRust")),
        ("bus_shelter", build_bus_shelter(col)),
        ("signs", build_signs(col)),
        ("streetlight", build_streetlight(col)),
        ("utility_pole", build_utility_pole(col)),
        ("person_a", build_person(col, "person_a", "CoatNavy", "Jeans", "Skin")),
        ("person_b", build_person(col, "person_b", "CoatRed", "Black", "Skin2", scale=0.95)),
        ("person_c", build_person(col, "person_c", "CoatOlive", "Jeans", "Skin3", scale=1.04)),
        ("person_d", build_person(col, "person_d", "CoatGrey", "Black", "Skin", scale=0.9)),
    ]
    rows = []
    for name, objs in jobs:
        path = os.path.join(OUT, name + ".glb")
        export(objs, path)
        rows.append((name, tris(objs), os.path.getsize(path)))
    print("\nASSETS")
    for n, t, s in rows:
        print("%-18s %6d tris %8.1f KB" % (n, t, s / 1024))
    # lay out the non-world-position assets beside the building in the .blend for browsing
    x = 40.0
    for name, objs in jobs:
        if name in ("building", "main_door_leaf", "neighbours", "alley_props"):
            continue
        for o in objs:
            o.location.x += x
        x += 14.0
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    for p in (OUT_BLEND + "1",):
        if os.path.exists(p):
            os.remove(p)


if __name__ == "__main__":
    main()
