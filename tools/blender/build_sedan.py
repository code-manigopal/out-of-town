"""
Out of Town - Mani's grey mid-size sedan (generic design, no logos, badges or text) and the simple traffic cars.

Run headless (re-runnable, deterministic):
    /opt/homebrew/bin/blender -b -P tools/blender/build_sedan.py

Outputs
    game/vehicles/sedan/sedan.glb              hero car, separate parts (see PARTS)
    game/vehicles/sedan/traffic_sedan.glb      one-piece sedan (parked / moving background cars)
    game/vehicles/sedan/traffic_hatchback.glb  one-piece hatchback
    game/vehicles/sedan/traffic_suv.glb        one-piece SUV
    art_source/vehicles/sedan/sedan.blend      the whole scene

Conventions (docs/tech/technical-design.md "Asset pipeline")
    metres, Z up in Blender (the glTF exporter converts to Y up); the car's FRONT points -Y in Blender, which is +Z in
    Godot. The origin is on the ground, centred between the axles. The driver (left) side is +X.
    Body paint material is named "CarPaint" so Godot can recolour it per car.

PARTS of sedan.glb (each an object whose origin is the pivot Godot needs):
    Body            shell + glass (materials CarPaint, Glass, Trim, ...), origin = car origin
    TrunkLid        hinge at the front edge of the deck (rotate about X to open)
    DriverDoor      hinge at the A-pillar edge (rotate about Z to open)
    Wheel_FL/FR/RL/RR   origin = hub centre, axle along X
    SteeringWheel   origin = wheel hub, rotate about the column axis (tilted)
    Seat_Driver, Seat_Passenger, Seat_Rear, Dash, DashLights (emissive, off), Headlights, Taillights, MirrorPassenger
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "game", "vehicles", "sedan")
OUT_BLEND = os.path.join(ROOT, "art_source", "vehicles", "sedan", "sedan.blend")
V = Vector


def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


MATS = {}


def make_mat(name, hexc, rough=0.5, metal=0.0, alpha=1.0, emit=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    r, g, bl = hexcol(hexc)
    b.inputs["Base Color"].default_value = (r, g, bl, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
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
    return m


def build_materials():
    make_mat("CarPaint", "#5a5e63", 0.32, metal=0.55)          # mid grey metallic
    make_mat("Glass", "#1c2a30", 0.04, alpha=0.32)
    make_mat("Trim", "#17181a", 0.55)                           # bumpers, grille, sills
    make_mat("Tire", "#141414", 0.9)
    make_mat("Rim", "#a9adb2", 0.28, metal=1.0)
    make_mat("Interior", "#2a2b2e", 0.85)
    make_mat("Fabric", "#4a4d52", 0.95)
    make_mat("Floor", "#1d1e20", 0.95)
    make_mat("DashLight", "#222222", 0.4, emit=("#ffffff", 0.0))
    make_mat("Headlight", "#9aa2a8", 0.1, emit=("#fff4d8", 0.0))
    make_mat("Taillight", "#8c1218", 0.2, emit=("#ff1c22", 0.0))
    make_mat("Plate", "#e9e9e4", 0.5)
    make_mat("Underbody", "#101112", 0.9)


# ----------------------------------------------------------------------------------------------------------
# helpers
# ----------------------------------------------------------------------------------------------------------
def T(x, y, z):
    return Matrix.Translation((x, y, z))


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


class M:
    """Tiny bmesh accumulator with named materials."""

    def __init__(self):
        self.bm = bmesh.new()
        self.mats = []

    def mi(self, name):
        if name not in self.mats:
            self.mats.append(name)
        return self.mats.index(name)

    def box(self, c, size, mat, rot=None):
        m = T(*c) @ (rot if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        for f in {f for v in r["verts"] for f in v.link_faces}:
            f.material_index = self.mi(mat)

    def cyl(self, c, r, h, mat, axis="z", seg=20, r2=None):
        a = {"z": Matrix.Identity(4), "x": Matrix.Rotation(math.radians(90), 4, "Y"),
             "y": Matrix.Rotation(math.radians(90), 4, "X")}[axis]
        res = bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r,
                                    radius2=r if r2 is None else r2, depth=h, matrix=T(*c) @ a)
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.material_index = self.mi(mat)

    def poly(self, pts, mat):
        f = self.bm.faces.new([self.bm.verts.new(V(p)) for p in pts])
        f.material_index = self.mi(mat)
        return f

    def build(self, name, col, origin=None, smooth_angle=45.0):
        bm = self.bm
        bm.normal_update()
        me = bpy.data.meshes.new(name)
        if origin is not None:
            bmesh.ops.translate(bm, verts=bm.verts, vec=-V(origin))
        bm.to_mesh(me)
        bm.free()
        for n in self.mats:
            me.materials.append(MATS[n])
        ob = bpy.data.objects.new(name, me)
        col.objects.link(ob)
        if origin is not None:
            ob.location = V(origin)
        for p in me.polygons:
            p.use_smooth = True
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        try:
            bpy.ops.object.shade_smooth_by_angle(angle=math.radians(smooth_angle))
        except Exception:
            pass
        ob.select_set(False)
        return ob


# ----------------------------------------------------------------------------------------------------------
# hull: lofted from cross-sections
# ----------------------------------------------------------------------------------------------------------
class Style:
    """Side-profile and plan parameters of one body style (all metres, Blender axes, front = -Y)."""

    def __init__(self, **kw):
        self.length = 4.72
        self.width = 1.82          # half = 0.91
        self.zb = 0.14             # underside
        self.belt_nose = 0.74
        self.belt_cowl = 0.92
        self.belt_cabin = 0.94
        self.belt_tail = 0.90
        self.roof = 1.47
        self.wind_y0, self.wind_y1 = -1.05, -0.20     # windshield: roof ramps from the hood line
        self.roof_y1 = 0.70                            # roof flat until here
        self.rear_y1 = 1.40                            # rear window ends at the deck
        self.wr = 0.60                                 # roof half-width
        self.rear_y_deck = 0.96
        self.tail_belt = 0.92
        self.__dict__.update(kw)

    @property
    def hl(self):
        return self.length / 2


SEDAN = Style()
HATCH = Style(length=4.25, belt_tail=0.95, belt_cabin=0.95, roof=1.50, rear_y1=1.55, roof_y1=1.0,
              tail_belt=1.05, rear_y_deck=1.30)
SUV = Style(length=4.65, width=1.88, zb=0.22, belt_nose=0.92, belt_cowl=1.05, belt_cabin=1.07, belt_tail=1.05,
            roof=1.72, wind_y0=-0.95, wind_y1=-0.15, roof_y1=1.20, rear_y1=1.95, wr=0.64, tail_belt=1.12,
            rear_y_deck=1.70)


def belt(st, y):
    hl = st.hl
    if y < -1.0:
        return lerp(st.belt_nose, st.belt_cowl, smooth((y + hl) / (hl - 1.0)) ** 0.8)
    if y < st.wind_y0:
        return lerp(st.belt_cowl, st.belt_cabin, 0.5)
    if y < st.rear_y_deck:
        return st.belt_cabin
    return lerp(st.belt_cabin, st.belt_tail, smooth((y - st.rear_y_deck) / (hl - st.rear_y_deck)))


def cabin_c(st, y):
    """0 on the hood / deck, 1 across the greenhouse."""
    if y < st.wind_y0:
        return 0.0
    if y < st.wind_y1:
        return smooth((y - st.wind_y0) / (st.wind_y1 - st.wind_y0))
    if y < st.roof_y1:
        return 1.0
    if y < st.rear_y1:
        return 1.0 - smooth((y - st.roof_y1) / (st.rear_y1 - st.roof_y1))
    return 0.0


def end_scale(st, y):
    """Rounds the nose and tail: 1 in the middle, small at the very ends (plan + elevation)."""
    hl = st.hl
    d = min(y + hl, hl - y)          # distance from the nearest end
    r = 0.38
    if d >= r:
        return 1.0
    t = max(d, 0.0) / r
    return math.sqrt(max(1e-4, 1 - (1 - t) ** 2)) * 0.97 + 0.03


def section_right(st, y, inset=0.0):
    """Right half of the cross-section (x, z), bottom centre -> top centre. `inset` shrinks it for the inner skin."""
    sc = end_scale(st, y)
    c = cabin_c(st, y)
    zb = st.zb + (0.10 * (1 - sc) + (0.09 if abs(y) > st.hl - 0.5 else 0.0))
    zbelt = belt(st, y)
    zt = zbelt + 0.05 + c * (st.roof - zbelt - 0.05)
    wm = 0.91 * (st.width / 1.82) * (0.80 + 0.20 * sc)
    wr = lerp(wm - 0.12, st.wr, c)
    # lower body, belt line, glass band, roof
    zs = [zb, zb + 0.015, zb + 0.10, zb + 0.32, lerp(zb, zbelt, 0.78), zbelt]
    ws = [wm - 0.13, wm - 0.095, wm - 0.055, wm - 0.012, wm - 0.002, wm - 0.012]
    # glass band
    zg0 = zbelt + 0.025
    zg1 = zt - 0.075
    gl = [(wm - 0.035, zg0), (lerp(wm - 0.035, wr + 0.06, 0.5), lerp(zg0, zg1, 0.5)), (wr + 0.06, zg1)]
    pts = [(0.0, zs[0])] + [(w, z) for w, z in zip(ws, zs)] + gl
    pts += [(wr + 0.015, zt - 0.03), (wr - 0.10, zt - 0.003), (wr * 0.45, zt + 0.006 * (1 - c) + 0.002), (0.0, zt + 0.012 * (1 - c) + 0.004)]
    out = []
    for i, (x, z) in enumerate(pts):
        x *= sc if i > 0 else 1.0
        zc = (zb + zt) / 2
        z = zc + (z - zc) * (0.55 + 0.45 * sc)
        out.append((x, z))
    # strictly increasing z on the way up, and x never negative
    for i in range(1, len(out)):
        if out[i][1] < out[i - 1][1] + 0.002 and out[i][0] < 1e-6 + out[i - 1][0] + 0.5:
            out[i] = (out[i][0], out[i - 1][1] + 0.002)
    if inset > 0:
        cx, cz = 0.0, (out[0][1] + out[-1][1]) / 2
        out = [(max(0.0, x - inset), z + (inset if i == 0 else 0) - (inset if i == len(out) - 1 else 0) +
                (0 if i in (0, len(out) - 1) else 0)) for i, (x, z) in enumerate(out)]
        out[0] = (0.0, out[0][1] + inset)
        out[-1] = (0.0, out[-1][1] - inset)
    return out


def stations(st, extra=()):
    hl = st.hl
    ys = set()
    n = 44
    for i in range(n + 1):
        ys.add(round(-hl + 2 * hl * i / n, 4))
    # fine spacing on the rounded ends
    for k in (0.02, 0.06, 0.12, 0.2, 0.3):
        ys.add(round(-hl + k, 4))
        ys.add(round(hl - k, 4))
    for e in extra:
        ys.add(round(e, 4))
    return sorted(ys)


def loft(m, st, ys, inset, mat_fn, flip=False, skip=None):
    """Lofts the hull into M `m`. Returns (rings, faces); rings[i] = list of verts for station i in ring order.
    Ring order: right half bottom->top (indices 0..k), then left half top->bottom (mirror)."""
    bm = m.bm
    rings = []
    for y in ys:
        right = section_right(st, y, inset)
        k = len(right)
        full = right + [(-x, z) for (x, z) in reversed(right[1:-1])]
        # remove duplicated centre points when x == 0 at the first / last entry
        rings.append([bm.verts.new((x, y, z)) for (x, z) in full])
    n = len(rings[0])
    faces = []
    for i in range(len(ys) - 1):
        for j in range(n):
            a, b = rings[i][j], rings[i][(j + 1) % n]
            c, d = rings[i + 1][(j + 1) % n], rings[i + 1][j]
            try:
                f = bm.faces.new((a, b, c, d) if not flip else (d, c, b, a))
            except ValueError:
                continue
            mat = mat_fn(f, ys[i], ys[i + 1], j, n)
            if skip is not None and skip(mat):
                bm.faces.remove(f)
                continue
            f.material_index = m.mi(mat)
            faces.append(f)
    for idx, ring in ((0, rings[0]), (-1, rings[-1])):
        try:
            seq = ring if (idx == 0) != flip else list(reversed(ring))
            f = bm.faces.new(seq if idx == 0 else list(reversed(seq)))
            f.material_index = m.mi("Trim")
            faces.append(f)
        except ValueError:
            pass
    return rings, faces


def classify_factory(st, glass=True):
    """Material for a loft quad from its centroid: paint / glass / trim."""
    def fn(f, y0, y1, j, n):
        c = f.calc_center_median()
        yc = c.y
        x = abs(c.x)
        z = c.z
        zbelt = belt(st, yc)
        hl = st.hl
        if z < st.zb + 0.30 and (yc < -hl + 0.45 or yc > hl - 0.45):
            return "Trim"
        if z < st.zb + 0.17:
            return "Trim"
        if yc < -hl + 0.12 and 0.42 < z < 0.66 and x < 0.55:
            return "Trim"               # grille
        if glass and zbelt + 0.03 < z:
            cc = cabin_c(st, yc)
            side = x > 0.5 and z < st.roof - 0.09
            if side and ((-0.50 < yc < 0.36) or (0.52 < yc < st.rear_y1 - 0.02 - (0.1 if st is not SEDAN else 0.0))):
                return "Glass"
            if (not side) and x < wr_at(st, yc) - 0.07 and 0.04 < cc < 0.96 and z > zbelt + 0.05 and \
                    (st.wind_y0 + 0.08 < yc < st.wind_y1 - 0.05 or st.roof_y1 + 0.05 < yc < st.rear_y1 - 0.05):
                return "Glass"
        return "CarPaint"
    return fn


def wr_at(st, y):
    return lerp(0.79, st.wr, cabin_c(st, y))


# ----------------------------------------------------------------------------------------------------------
# splitting the skins into body / door / lid
# ----------------------------------------------------------------------------------------------------------
def make_hull_object(name, col, st, ys, hollow=True, door=False, lid=False):
    """Returns dict of M builders: body, door, lid. hollow: add an inner skin so the shell has an interior."""
    body, doorm, lidm = M(), M(), M()
    fnc = classify_factory(st)
    rings_o, faces_o = loft(body, st, ys, 0.0, fnc)
    if hollow:
        rings_i, faces_i = loft(body, st, ys, 0.045, lambda *a: "Interior", flip=True)
    return body, doorm, lidm, (rings_o, rings_i if hollow else None), (faces_o, faces_i if hollow else None)


DOOR_Y0, DOOR_Y1 = -0.62, 0.50
LID_Y0 = 1.34


def move_face(bm, f, dst_bm, vmap):
    """Copies face f into dst_bm (keeping the material index) and removes it from bm."""
    nv = []
    for v in f.verts:
        if v not in vmap:
            vmap[v] = dst_bm.verts.new(v.co)
        nv.append(vmap[v])
    nf = dst_bm.faces.new(nv)
    nf.material_index = f.material_index
    nf.smooth = True


def split_parts(st, ys, body, rings, with_door=True, with_lid=True):
    """Moves the door / lid faces out of `body` (outer AND inner skins) and closes the openings with rim faces.
    Returns (door M, lid M) with their own bmeshes."""
    bm = body.bm
    bm.verts.ensure_lookup_table()
    bm.faces.ensure_lookup_table()
    rings_o, rings_i = rings
    n = len(rings_o[0])
    # ring index of the right-hand roof corner & sill. right half has k points: 0..k-1 (k-1 is the top centre)
    k = (n + 2) // 2
    j_sill = 2           # right-side vertex index above the bottom edge
    j_top = k - 4        # roof corner (before the roof crown)
    door_m, lid_m = M(), M()
    door_m.mats = list(body.mats)
    lid_m.mats = list(body.mats)
    # --- door: right half is passenger (-x)... the DRIVER is +X, which is the "right half" list in section_right.
    if with_door:
        sel_o, sel_i = set(), set()
        for i in range(len(ys) - 1):
            if ys[i] >= DOOR_Y0 - 1e-6 and ys[i + 1] <= DOOR_Y1 + 1e-6:
                for j in range(j_sill, j_top):
                    sel_o.add((i, j))
        _split(bm, rings_o, rings_i, sel_o, door_m, ys)
    if with_lid:
        sel = set()
        for i in range(len(ys) - 1):
            if ys[i] >= LID_Y0 - 1e-6:
                for j in list(range(5, n - 5 + 1)):
                    sel.add((i, j % n))
        _split(bm, rings_o, rings_i, sel, lid_m, ys, tail_cap=True)
    return door_m, lid_m


def _face_between(bm, ring_a, ring_b, j, n):
    va = {ring_a[j], ring_a[(j + 1) % n], ring_b[(j + 1) % n], ring_b[j]}
    for f in ring_a[j].link_faces:
        if set(f.verts) == va:
            return f
    return None


def _split(bm, rings_o, rings_i, sel, dst, ys, tail_cap=False):
    n = len(rings_o[0])
    vmap = {}
    boundary = []
    for (i, j) in sel:
        for rings in (rings_o, rings_i):
            f = _face_between(bm, rings[i], rings[i + 1], j, n)
            if f is not None:
                move_face(bm, f, dst.bm, vmap)
                bmesh.ops.delete(bm, geom=[f], context="FACES_ONLY")
    # rim: quads between the outer and inner copies along the open boundary of the outer part
    # (edges used by exactly one moved outer face)
    cnt = {}
    for (i, j) in sel:
        for (a, b) in (((i, j), (i, (j + 1) % n)), ((i + 1, j), (i + 1, (j + 1) % n)),
                       ((i, j), (i + 1, j)), ((i, (j + 1) % n), (i + 1, (j + 1) % n))):
            key = frozenset((a, b))
            cnt[key] = cnt.get(key, 0) + 1
    for key, c in cnt.items():
        if c != 1:
            continue
        a, b = tuple(key)
        oa, ob = rings_o[a[0]][a[1]], rings_o[b[0]][b[1]]
        ia, ib = rings_i[a[0]][a[1]], rings_i[b[0]][b[1]]
        for v in (oa, ob, ia, ib):
            if v not in vmap:
                vmap[v] = dst.bm.verts.new(v.co)
        try:
            f = dst.bm.faces.new((vmap[oa], vmap[ob], vmap[ib], vmap[ia]))
            f.material_index = dst.mi("Interior")
            # the body keeps a matching rim so the opening has depth
        except ValueError:
            pass
        # rim on the body side
        try:
            bf = bm.faces.new((oa, ob, ib, ia))
            bf.material_index = dst.mi("Interior") if "Interior" in [x for x in dst.mats] else 0
        except ValueError:
            pass


def finish_bm(m, name, col, origin=None):
    bmesh.ops.recalc_face_normals(m.bm, faces=m.bm.faces)
    return m.build(name, col, origin)


# ----------------------------------------------------------------------------------------------------------
# other parts
# ----------------------------------------------------------------------------------------------------------
TRACK = 1.60
WHEELBASE = 2.80
TIRE_R = 0.325
TIRE_W = 0.215


def wheel_object(name, col, pos, side):
    """Tyre + rim, axle along X, origin at the hub. side +1 = driver side (outward = +X)."""
    m = M()
    seg = 28
    m.cyl((0, 0, 0), TIRE_R, TIRE_W, "Tire", axis="x", seg=seg)
    # rim face (outer)
    o = side * (TIRE_W / 2 + 0.002)
    m.cyl((o, 0, 0), TIRE_R * 0.66, 0.012, "Rim", axis="x", seg=seg)
    m.cyl((o + side * 0.004, 0, 0), TIRE_R * 0.20, 0.02, "Trim", axis="x", seg=12)
    for a in range(5):
        ang = a * math.tau / 5
        rot = Matrix.Rotation(ang, 4, "X")
        m.box((o + side * 0.002, 0, 0), (0.008, 0.07, TIRE_R * 1.1), "Trim", rot=rot)
    ob = m.build(name, col, None, smooth_angle=35)
    ob.location = pos
    return ob


def seat_object(name, col, centre, width=0.50, bench=False):
    m = M()
    cx, cy, cz = centre
    w = 1.30 if bench else width
    m.box((cx, cy, cz + 0.07), (w, 0.50, 0.14), "Fabric")                       # cushion (top at cz + 0.14)
    m.box((cx, cy + 0.27, cz + 0.42), (w, 0.10, 0.62), "Fabric", rot=Matrix.Rotation(math.radians(-8), 4, "X"))   # back
    if not bench:
        m.box((cx, cy + 0.31, cz + 0.84), (0.30, 0.09, 0.15), "Fabric")         # headrest
    else:
        for dx in (-0.4, 0.0, 0.4):
            m.box((cx + dx, cy + 0.31, cz + 0.80), (0.26, 0.09, 0.14), "Fabric")
    return m.build(name, col, None, smooth_angle=60)


def steering_wheel(col, hub):
    m = M()
    ring = bmesh.ops.create_circle(m.bm, cap_ends=False, segments=28, radius=0.19, matrix=Matrix.Identity(4))
    # torus-like rim from boxes around the hub (local frame: wheel plane = XZ, column along +Y)
    for a in range(28):
        ang = a * math.tau / 28
        c = (math.cos(ang) * 0.18, 0.0, math.sin(ang) * 0.18)
        rot = Matrix.Rotation(-ang + math.pi / 2, 4, "Y")
        m.box(c, (0.052, 0.03, 0.028), "Interior", rot=rot)
    m.box((0, 0, 0), (0.12, 0.05, 0.12), "Interior")
    m.box((0, 0, 0), (0.34, 0.025, 0.035), "Interior")
    m.box((0, 0, -0.08), (0.035, 0.025, 0.16), "Interior")
    # delete the helper circle
    for f in list(m.bm.faces):
        pass
    bmesh.ops.delete(m.bm, geom=ring["verts"], context="VERTS")
    ob = m.build("SteeringWheel", col, origin=hub, smooth_angle=60)
    ob.rotation_euler = (math.radians(-20), 0, 0)    # wheel faces the driver (tilts toward -Y... top edge forward)
    return ob


def dash_object(col):
    m = M()
    # dash top + binnacle + centre stack; driver on +X. The dash sits behind the windshield base (y -0.95..-0.55).
    m.box((0.0, -0.74, 0.86), (1.62, 0.34, 0.10), "Interior")              # upper pad
    m.box((0.0, -0.66, 0.70), (1.56, 0.22, 0.34), "Interior")              # lower fascia
    m.box((0.36, -0.77, 0.95), (0.52, 0.18, 0.12), "Interior")             # binnacle hood over the cluster
    m.box((0.0, -0.58, 0.56), (0.24, 0.30, 0.50), "Interior")              # centre console front
    m.box((0.0, -0.05, 0.50), (0.26, 0.90, 0.22), "Interior")              # console
    # floor + door cards + roof lining
    m.box((0.0, -0.3, 0.17), (1.55, 2.0, 0.02), "Floor")
    m.box((0.0, 1.0, 0.40), (1.55, 1.3, 0.02), "Floor")
    m.box((0.0, 0.95, 0.52), (1.5, 0.05, 0.76), "Interior")                # bulkhead behind the rear seat / to the trunk
    return m.build("Dash", col, None, smooth_angle=50)


def dash_lights(col):
    m = M()
    # cluster face (driver binnacle) + a few warning icons: flat emissive rectangles
    m.box((0.36, -0.665, 0.915), (0.30, 0.008, 0.095), "DashLight")
    return m.build("DashLights", col, None)


def lights(col, st):
    hl = st.hl
    mh = M()
    mt = M()
    for s in (-1, 1):
        mh.box((s * 0.66, -hl + 0.12, st.belt_nose - 0.12), (0.34, 0.12, 0.07), "Headlight",
               rot=Matrix.Rotation(math.radians(s * 14), 4, "Z"))
        mt.box((s * 0.68, hl - 0.10, st.tail_belt - 0.14), (0.40, 0.14, 0.11), "Taillight",
               rot=Matrix.Rotation(math.radians(s * -14), 4, "Z"))
    mt.box((0, hl - 0.03, 0.58), (0.36, 0.02, 0.11), "Plate")
    return mh.build("Headlights", col), mt.build("Taillights", col)


def mirror_box(name, col, sx, y, z):
    m = M()
    m.box((sx * 1.00, y, z), (0.16, 0.08, 0.11), "CarPaint")
    m.box((sx * 0.95, y, z - 0.03), (0.06, 0.05, 0.05), "CarPaint")
    return m.build(name, col, None)


def underbody(col, st):
    m = M()
    m.box((0, 0, st.zb + 0.015), (1.62, st.length - 0.5, 0.03), "Underbody")
    return m.build("Underbody", col, None)


# ----------------------------------------------------------------------------------------------------------
# build the hero sedan
# ----------------------------------------------------------------------------------------------------------
def build_hero(col):
    st = SEDAN
    extra = [DOOR_Y0, DOOR_Y1, LID_Y0, -0.50, 0.36, 0.52, st.rear_y1 - 0.02, st.wind_y0 + 0.08, st.wind_y1 - 0.05,
             st.roof_y1 + 0.05, st.wind_y0, st.wind_y1, st.roof_y1, st.rear_y1, st.rear_y_deck, -1.0, 0.5]
    ys = stations(st, extra)
    body = M()
    rings_o, faces_o = loft(body, st, ys, 0.0, classify_factory(st))
    inner_fn = classify_factory(st)
    rings_i, faces_i = loft(body, st, ys, 0.045, lambda f, y0, y1, j, n: "Glass" if inner_fn(f, y0, y1, j, n) == "Glass" else "Interior",
                            flip=True, skip=lambda mat: mat == "Glass")
    door_m, lid_m = split_parts(st, ys, body, (rings_o, rings_i))
    objs = {}
    # hinge pivots
    hinge_door = V((0.905, DOOR_Y0, 0.0))
    hinge_lid = V((0.0, LID_Y0, 0.93))
    objs["Body"] = finish_bm(body, "Body", col)
    objs["DriverDoor"] = finish_bm(door_m, "DriverDoor", col, origin=hinge_door)
    objs["TrunkLid"] = finish_bm(lid_m, "TrunkLid", col, origin=hinge_lid)
    # driver door extras: mirror
    # wheels
    ax = WHEELBASE / 2
    for nm, (sx, sy) in {"Wheel_FL": (1, -1), "Wheel_FR": (-1, -1), "Wheel_RL": (1, 1), "Wheel_RR": (-1, 1)}.items():
        objs[nm] = wheel_object(nm, col, (sx * TRACK / 2, sy * ax, TIRE_R), sx)
    objs["Dash"] = dash_object(col)
    objs["DashLights"] = dash_lights(col)
    hubz = 0.89
    objs["SteeringWheel"] = steering_wheel(col, V((0.36, -0.69, hubz)))
    objs["Seat_Driver"] = seat_object("Seat_Driver", col, (0.36, -0.23, 0.34))
    objs["Seat_Passenger"] = seat_object("Seat_Passenger", col, (-0.36, -0.23, 0.34))
    objs["Seat_Rear"] = seat_object("Seat_Rear", col, (0.0, 0.88, 0.34), bench=True)
    h, t = lights(col, st)
    objs["Headlights"], objs["Taillights"] = h, t
    objs["MirrorPassenger"] = mirror_box("MirrorPassenger", col, -1, -0.62, 0.99)
    objs["Underbody"] = underbody(col, st)
    # door mirror is part of the door
    dm = M()
    dm.box((0.10, 0.05, 1.0 - 0.0), (0.16, 0.08, 0.11), "CarPaint")
    return objs


def build_simple(col, name, st, body_col_only=True):
    """One-piece car for traffic: closed outer skin + 4 fixed wheels merged into a single object."""
    ys = stations(st, [-0.50, 0.36, 0.52, st.rear_y1 - 0.02, st.wind_y0 + 0.08, st.wind_y1 - 0.05,
                       st.roof_y1 + 0.05, st.wind_y0, st.wind_y1, st.roof_y1, st.rear_y1, st.rear_y_deck])
    m = M()
    loft(m, st, ys, 0.0, classify_factory(st))
    ax = WHEELBASE / 2 if st.length > 4.4 else 2.55 / 2
    zr = TIRE_R if st is not SUV else 0.37
    for sx in (1, -1):
        for sy in (-1, 1):
            c = (sx * (TRACK / 2 + (0.03 if st is SUV else 0.0)), sy * ax, zr)
            m.cyl(c, zr, TIRE_W, "Tire", axis="x", seg=20)
            m.cyl((c[0] + sx * (TIRE_W / 2 + 0.002), c[1], c[2]), zr * 0.64, 0.01, "Rim", axis="x", seg=20)
    hl = st.hl
    for s in (-1, 1):
        m.box((s * 0.66, -hl + 0.10, st.belt_nose - 0.12), (0.40, 0.16, 0.09), "Headlight")
        m.box((s * 0.68, hl - 0.08, st.tail_belt - 0.14), (0.40, 0.12, 0.10), "Taillight")
    m.box((0, 0, st.zb + 0.015), (1.62, st.length - 0.5, 0.03), "Underbody")
    bmesh.ops.recalc_face_normals(m.bm, faces=m.bm.faces)
    return m.build(name, col)


# ----------------------------------------------------------------------------------------------------------
def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False, export_animations=False,
                              export_materials="EXPORT")


def bbox(ob):
    pts = [ob.matrix_world @ V(c) for c in ob.bound_box]
    return (V((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            V((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_materials()
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    col = bpy.data.collections.new("Sedan")
    sc.collection.children.link(col)
    parts = build_hero(col)
    objs = list(parts.values())
    export(objs, os.path.join(OUT_DIR, "sedan.glb"))
    tri = 0
    for o in objs:
        tri += sum(len(p.vertices) - 2 for p in o.data.polygons)
    mn = V((1e9,) * 3)
    mx = V((-1e9,) * 3)
    for o in objs:
        a, b = bbox(o)
        mn = V((min(mn.x, a.x), min(mn.y, a.y), min(mn.z, a.z)))
        mx = V((max(mx.x, b.x), max(mx.y, b.y), max(mx.z, b.z)))
    print("sedan.glb: %d tris, size %.2f x %.2f x %.2f" % (tri, mx.x - mn.x, mx.y - mn.y, mx.z - mn.z))
    # traffic variants (placed beside the hero in the .blend)
    tcol = bpy.data.collections.new("Traffic")
    sc.collection.children.link(tcol)
    off = 0.0
    for nm, st in (("traffic_sedan", SEDAN), ("traffic_hatchback", HATCH), ("traffic_suv", SUV)):
        o = build_simple(tcol, nm, st)
        export([o], os.path.join(OUT_DIR, nm + ".glb"))
        off += 3.0
        o.location = (off, 0, 0)
        a, b = bbox(o)
        print("%s.glb: size %.2f x %.2f x %.2f" % (nm, b.x - a.x, b.y - a.y, b.z - a.z))
    for o in objs:
        o.location.x += 0.0
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
    for p in (OUT_BLEND + "1",):
        if os.path.exists(p):
            os.remove(p)


if __name__ == "__main__":
    main()
