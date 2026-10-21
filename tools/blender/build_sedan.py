"""
Out of Town - Mani's grey mid-size sedan (generic design: no badges, logos or real crests) and the traffic cars.

Run headless (re-runnable, deterministic):
    /opt/homebrew/bin/blender -b -P tools/blender/build_sedan.py
    SEDAN_ONLY=hero /opt/homebrew/bin/blender -b -P tools/blender/build_sedan.py      (hero car only, faster)

Outputs
    game/vehicles/sedan/sedan.glb              hero car, separate parts (see PARTS)
    game/vehicles/sedan/traffic_sedan.glb      one-piece sedan (parked / moving background cars)
    game/vehicles/sedan/traffic_hatchback.glb  one-piece hatchback
    game/vehicles/sedan/traffic_suv.glb        one-piece SUV
    art_source/vehicles/sedan/sedan.blend      the whole scene

Conventions
    All geometry is modelled directly in GODOT axes (x = the car's LEFT = the driver's side, y up, z forward) and rotated
    into Blender axes (x, -z, y) as each object is created, so the glTF exporter hands Godot the same numbers. Metres.
    The origin is on the ground, centred between the axles. The body paint material is named "CarPaint".

PARTS of sedan.glb (each an object whose origin is the pivot Godot needs)
    Body            hollow shell: paint, glass (alpha), trim, panel gaps, arches, grille, mirrors, plate, exhaust
    DriverDoor      hinge origin at the front edge (rotate about Y); trunk lid: TrunkLid hinge origin (rotate about X)
    Wheel_FL/FR/RL/RR   origin = hub centre, axle along X (tyre + alloy + brake disc)
    SteeringWheel   origin = wheel hub, plane pre-tilted 22 degrees; spin it about STEER_AXIS (see oot_car.gd)
    Dash, DashLights (emissive gauges), DashScreen (radio / nav), Seats, Pedals, InteriorTrim (rear bench, trunk floor,
    parcel shelf, visors, mirror), EngineBay, Headlights, Taillights (lens + emissive lamp elements), Underbody
"""
import bpy
import bmesh
import math
import os
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT_DIR = os.path.join(ROOT, "game", "vehicles", "sedan")
OUT_BLEND = os.path.join(ROOT, "art_source", "vehicles", "sedan", "sedan.blend")
V = Vector
RX = Matrix.Rotation(math.pi / 2, 4, "X")           # Godot (x, y, z) -> Blender (x, -z, y)
RXI = RX.inverted()
rad = math.radians


# ----------------------------------------------------------------------------------------------------------------
# materials
# ----------------------------------------------------------------------------------------------------------------
def _lin(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hexcol(h):
    h = h.lstrip("#")
    return tuple(_lin(int(h[i:i + 2], 16) / 255.0) for i in (0, 2, 4))


# name: (hex, roughness, metallic, alpha, (emission hex, strength) | None, flags)
MAT_DEFS = {
    "CarPaint": ("#6f757b", 0.32, 0.5, 1.0, None, "coat"),
    "Glass": ("#15222a", 0.03, 0.0, 0.30, None, "double"),
    "GlassTraffic": ("#10181d", 0.04, 0.1, 0.38, None, "double"),
    "Trim": ("#151618", 0.55, 0.0, 1.0, None, ""),
    "TrimSat": ("#2c2f33", 0.42, 0.2, 1.0, None, ""),
    "Gap": ("#040405", 0.9, 0.0, 1.0, None, ""),
    "Chrome": ("#cfd3d7", 0.10, 1.0, 1.0, None, ""),
    "Tire": ("#101010", 0.88, 0.0, 1.0, None, ""),
    "Rim": ("#a8adb3", 0.22, 1.0, 1.0, None, ""),
    "RimDark": ("#26282c", 0.45, 0.7, 1.0, None, ""),
    "Brake": ("#5d6064", 0.5, 0.8, 1.0, None, ""),
    "Interior": ("#3a3c40", 0.82, 0.0, 1.0, None, ""),
    "Headliner": ("#6e7073", 0.95, 0.0, 1.0, None, "double"),
    "Fabric": ("#5b5f65", 0.95, 0.0, 1.0, None, ""),
    "Leather": ("#17171a", 0.48, 0.0, 1.0, None, ""),
    "Floor": ("#1a1b1d", 0.97, 0.0, 1.0, None, ""),
    "DashLight": ("#1b1d20", 0.4, 0.0, 1.0, ("#ffffff", 0.0), ""),
    "Needle": ("#d84a12", 0.4, 0.0, 1.0, ("#ff5a1a", 0.0), ""),
    "Screen": ("#07090c", 0.12, 0.0, 1.0, ("#9fd0ff", 0.0), ""),
    "Headlight": ("#cfd2d4", 0.1, 0.0, 1.0, ("#fff2d2", 0.0), ""),
    "HeadLens": ("#a8b4bc", 0.02, 0.0, 0.20, None, "double"),
    "TailLens": ("#8a0d14", 0.04, 0.0, 0.58, None, "double"),
    "TailLamp": ("#7d0a10", 0.25, 0.0, 1.0, ("#ff1b22", 0.0), ""),
    "Indicator": ("#8a4a08", 0.25, 0.0, 1.0, ("#ff9a18", 0.0), ""),
    "Reverse": ("#bdbdbd", 0.25, 0.0, 1.0, ("#ffffff", 0.0), ""),
    "Reflector": ("#8c1218", 0.3, 0.0, 1.0, None, ""),
    "Plate": ("#ecece6", 0.5, 0.0, 1.0, None, ""),
    "PlateInk": ("#1b2c78", 0.5, 0.0, 1.0, None, ""),
    "Underbody": ("#0f1011", 0.92, 0.0, 1.0, None, ""),
    "MirrorGlass": ("#2c3a44", 0.04, 0.9, 1.0, None, ""),
    "Engine": ("#2c2f33", 0.55, 0.5, 1.0, None, ""),
    "EngineAlu": ("#80858a", 0.4, 0.9, 1.0, None, ""),
    "GlassHole": ("#ff00ff", 0.5, 0.0, 1.0, None, ""),      # tag only: deleted after the boolean
}
MAT_ORDER = list(MAT_DEFS.keys())
MI = {n: i for i, n in enumerate(MAT_ORDER)}
MATS = {}


def build_materials():
    for name, (h, rough, metal, alpha, emit, flags) in MAT_DEFS.items():
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        b = m.node_tree.nodes["Principled BSDF"]
        r, g, bl = hexcol(h)
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
        if "coat" in flags:
            for k, v in (("Coat Weight", 1.0), ("Coat Roughness", 0.04)):
                if k in b.inputs:
                    b.inputs[k].default_value = v
        m.use_backface_culling = "double" not in flags
        m.diffuse_color = (r, g, bl, alpha)
        MATS[name] = m


# ----------------------------------------------------------------------------------------------------------------
# small helpers
# ----------------------------------------------------------------------------------------------------------------
def lerp(a, b, t):
    return a + (b - a) * t


def clamp(x, a=0.0, b=1.0):
    return max(a, min(b, x))


def smooth(t):
    t = clamp(t)
    return t * t * (3 - 2 * t)


def pchip(pts):
    """Monotone cubic interpolation through (x, y) knots."""
    pts = sorted(pts)
    xs = [p[0] for p in pts]
    ys = [p[1] for p in pts]
    n = len(xs)
    h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    dl = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    d = [0.0] * n
    d[0], d[-1] = dl[0], dl[-1]
    for i in range(1, n - 1):
        if dl[i - 1] * dl[i] <= 0:
            d[i] = 0.0
        else:
            w1 = 2 * h[i] + h[i - 1]
            w2 = h[i] + 2 * h[i - 1]
            d[i] = (w1 + w2) / (w1 / dl[i - 1] + w2 / dl[i])

    def f(x):
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        lo, hi = 0, n - 1
        while hi - lo > 1:
            mid = (lo + hi) // 2
            if xs[mid] <= x:
                lo = mid
            else:
                hi = mid
        t = (x - xs[lo]) / h[lo]
        t2, t3 = t * t, t * t * t
        return ((2 * t3 - 3 * t2 + 1) * ys[lo] + (t3 - 2 * t2 + t) * h[lo] * d[lo] +
                (-2 * t3 + 3 * t2) * ys[hi] + (t3 - t2) * h[lo] * d[hi])
    return f


def rot_x(deg):
    return Matrix.Rotation(rad(deg), 4, "X")


def rot_y(deg):
    return Matrix.Rotation(rad(deg), 4, "Y")


def rot_z(deg):
    return Matrix.Rotation(rad(deg), 4, "Z")


def T(p):
    return Matrix.Translation(V(p))


SCENE_COL = None


class Msh:
    """bmesh accumulator in Godot axes with named materials."""

    def __init__(self):
        self.bm = bmesh.new()

    def vert(self, p):
        return self.bm.verts.new(V(p))

    def face(self, vs, mat):
        try:
            f = self.bm.faces.new(vs)
        except ValueError:
            return None
        f.material_index = MI[mat]
        f.smooth = True
        return f

    def poly(self, pts, mat):
        return self.face([self.vert(p) for p in pts], mat)

    def box(self, c, size, mat, rot=None, bevel=0.0, seg=1):
        m = T(c) @ (rot if rot is not None else Matrix.Identity(4)) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        r = bmesh.ops.create_cube(self.bm, size=1.0, matrix=m)
        faces = {f for v in r["verts"] for f in v.link_faces}
        for f in faces:
            f.material_index = MI[mat]
        if bevel > 0:
            edges = {e for f in faces for e in f.edges}
            bmesh.ops.bevel(self.bm, geom=list(edges), offset=bevel, offset_type="OFFSET", segments=seg, affect="EDGES")
        return r["verts"]

    def cyl(self, c, r, h, mat, axis="y", seg=16, r2=None, caps=True, rot=None):
        a = {"z": Matrix.Identity(4), "x": Matrix.Rotation(rad(90), 4, "Y"), "y": Matrix.Rotation(rad(-90), 4, "X")}[axis]
        res = bmesh.ops.create_cone(self.bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=r,
                                    radius2=r if r2 is None else r2, depth=h,
                                    matrix=T(c) @ (rot if rot is not None else Matrix.Identity(4)) @ a)
        for f in {f for v in res["verts"] for f in v.link_faces}:
            f.material_index = MI[mat]
            f.smooth = True
        return res["verts"]

    def revolve(self, prof, mat, axis="x", centre=(0, 0, 0), seg=32, closed=False, flip=False):
        """prof = [(a, r)] along the axis and radius; revolve about the axis through `centre`."""
        rings = []
        for a, r in prof:
            ring = []
            for s in range(seg):
                ang = s * math.tau / seg
                u, w = math.cos(ang) * r, math.sin(ang) * r
                if axis == "x":
                    p = (a, u, w)
                elif axis == "y":
                    p = (u, a, w)
                else:
                    p = (u, w, a)
                ring.append(self.vert(V(p) + V(centre)))
            rings.append(ring)
        for i in range(len(prof) - 1):
            for s in range(seg):
                q = [rings[i][s], rings[i][(s + 1) % seg], rings[i + 1][(s + 1) % seg], rings[i + 1][s]]
                self.face(q[::-1] if flip else q, mat)
        return rings


def mesh_to_object(m, name, pivot=(0, 0, 0), smooth_deg=45.0, recalc=True, link=True):
    bm = m.bm
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if bm.calc_volume(signed=True) < 0:
            bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bmesh.ops.translate(bm, verts=bm.verts, vec=-V(pivot))
    bmesh.ops.transform(bm, matrix=RX, verts=bm.verts)
    for f in bm.faces:
        f.smooth = True
    if smooth_deg is not None:
        lim = rad(smooth_deg)
        for e in bm.edges:
            if len(e.link_faces) == 2:
                try:
                    if e.calc_face_angle(0.0) > lim:
                        e.smooth = False
                except ValueError:
                    pass
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for mn in MAT_ORDER:
        me.materials.append(MATS[mn])
    ob = bpy.data.objects.new(name, me)
    ob.location = RX @ V(pivot)
    if link:
        SCENE_COL.objects.link(ob)
    return ob


def object_to_msh(ob):
    """Back to a Godot-axes bmesh (world space)."""
    m = Msh()
    m.bm.from_mesh(ob.data)
    bmesh.ops.transform(m.bm, matrix=RXI @ ob.matrix_world, verts=m.bm.verts)
    return m


def boolean(a, b, op):
    """In-place boolean a = a <op> b (EXACT). Faces from b keep b's material slots (identical slot lists)."""
    bpy.context.view_layer.update()
    mod = a.modifiers.new("bool", "BOOLEAN")
    mod.object = b
    mod.operation = op
    mod.solver = "EXACT"
    mod.use_self = True
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(a.evaluated_get(dg))
    a.modifiers.remove(mod)
    old = a.data
    a.data = me
    bpy.data.meshes.remove(old)
    bpy.context.view_layer.update()


def drop(ob):
    me = ob.data
    bpy.data.objects.remove(ob)
    if me.users == 0:
        bpy.data.meshes.remove(me)


def reorigin(ob, pivot):
    """Move the object origin to `pivot` (Godot-axes world position) keeping the geometry where it is."""
    pb = RX @ V(pivot)
    ob.data.transform(Matrix.Translation(-(pb - ob.location)))
    ob.location = pb


def delete_material_faces(ob, mat):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    idx = MI[mat]
    dead = [f for f in bm.faces if f.material_index == idx]
    bmesh.ops.delete(bm, geom=dead, context="FACES")
    # drop loose verts / edges
    loose = [v for v in bm.verts if not v.link_faces]
    bmesh.ops.delete(bm, geom=loose, context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def smooth_object(ob, deg=45.0):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    lim = rad(deg)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = True
        if len(e.link_faces) == 2:
            try:
                if e.calc_face_angle(0.0) > lim:
                    e.smooth = False
            except ValueError:
                pass
    bm.to_mesh(ob.data)
    bm.free()


def dbg(ob, label):
    if os.environ.get('SEDAN_DEBUG'):
        bm = bmesh.new(); bm.from_mesh(ob.data)
        nm = sum(1 for e in bm.edges if not e.is_manifold)
        print('DBG %-14s tris %6d  nonmanifold edges %d' % (label, tris(ob), nm)); bm.free()


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ----------------------------------------------------------------------------------------------------------------
# body style (side profile, plan view and cabin). Godot axes: z forward.
# ----------------------------------------------------------------------------------------------------------------
class Style:
    def __init__(self, name, **kw):
        self.name = name
        self.zf, self.zr = 2.40, -2.45
        self.ax_f, self.ax_r = 1.415, -1.415
        self.track = 1.57
        self.roof = 1.475
        self.wmax = 0.925
        self.ws_base, self.ws_top = 1.18, 0.25
        self.bl_top, self.bl_base = -0.95, -1.65
        self.belt_cab = 0.955
        self.belt_tail = 0.975
        self.deck = 1.005
        self.hood = 0.935
        self.zb0 = 0.15
        self.tire_r = 0.334
        self.side_glass = ((0.64, -0.34), (-0.50, -1.12))
        self.bpillar = (-0.34, -0.50)
        self.door = (0.80, -0.40)
        self.rear_door_gap = -1.18
        self.hatch = False
        self.traffic = False
        self.__dict__.update(kw)
        zf, zr = self.zf, self.zr
        wm = self.wmax
        self.W = pchip([(zr, 0.70), (zr + 0.04, 0.77), (zr + 0.12, 0.835), (zr + 0.28, 0.895), (zr + 0.50, wm - 0.01),
                        (-1.4, wm), (-0.6, wm - 0.005), (0.5, wm - 0.005), (1.2, wm), (self.ax_f + 0.2, wm - 0.002),
                        (zf - 0.60, wm - 0.007), (zf - 0.35, 0.90), (zf - 0.15, 0.85), (zf - 0.05, 0.79), (zf, 0.72)])
        self.belt = pchip([(zr, 0.93), (zr + 0.25, self.belt_tail - 0.01), (-1.5, self.belt_tail), (-0.45, self.belt_cab),
                           (0.5, self.belt_cab - 0.01), (1.0, 0.925), (1.5, 0.86), (2.0, 0.82), (zf - 0.10, 0.775),
                           (zf, 0.75)])
        self.top_front = pchip([(1.0, self.hood), (1.5, self.hood - 0.03), (2.0, self.hood - 0.075), (zf - 0.10, 0.80),
                                (zf, 0.775)])
        self.top_rear = pchip([(self.bl_base, self.deck - 0.02), (-1.9, self.deck), (zr + 0.25, self.deck + 0.01),
                               (zr + 0.05, self.deck), (zr, self.deck - 0.015)])
        self.zb = pchip([(zr, 0.38), (zr + 0.07, 0.33), (zr + 0.25, 0.24), (zr + 0.50, 0.17), (zr + 0.75, self.zb0),
                         (zf - 0.65, self.zb0), (zf - 0.40, 0.175), (zf - 0.15, 0.235), (zf, 0.30)])
        self.roof_at = pchip([(self.ws_top, self.roof - 0.012), (0.0, self.roof - 0.002), (-0.45, self.roof), (-0.95, self.roof - 0.010), (-1.45, self.roof - 0.04)]) if not self.hatch else (lambda z: self.roof)
        self.wr = pchip([(self.bl_base, 0.58), (-0.9, 0.60), (0.0, 0.635), (self.ws_top, 0.625), (self.ws_base, 0.60)])

    def cabin_c(self, z):
        def ramp(t):
            return 0.3 * smooth(t) + 0.7 * clamp(t)
        if z >= self.ws_top:
            return ramp((self.ws_base - z) / (self.ws_base - self.ws_top)) if z < self.ws_base else 0.0
        if z >= self.bl_top:
            return 1.0
        if z > self.bl_base:
            return ramp((z - self.bl_base) / (self.bl_top - self.bl_base))
        return 0.0

    def top(self, z):
        return self.top_front(z) if z > 0 else self.top_rear(z)

    # ---- section: right half (x >= 0), 16 points bottom centre -> top centre -------------------------------------
    def right_pts(self, z):
        wm, zb, belt = self.W(z), self.zb(z), self.belt(z)
        top = max(self.top(z), belt + 0.03)
        c = self.cabin_c(z)
        wr = self.wr(z)
        H = belt - zb
        fr = [0.0, 0.0, 0.045, 0.14, 0.28, 0.46, 0.64, 0.84, 1.0]
        xo = [0.0, wm - 0.22, wm - 0.10, wm - 0.040, wm - 0.016, wm - 0.004, wm, wm - 0.034, wm - 0.072]
        L = [(xo[i], zb + fr[i] * H) for i in range(9)]
        # greenhouse (c = 1)
        c1 = (wm - 0.098, belt + 0.022)
        roof = self.roof_at(z)
        c3 = (wr + 0.075, roof - 0.058)
        c2 = (lerp(c1[0], c3[0], 0.5) - 0.006, lerp(c1[1], c3[1], 0.5))
        sep = lerp(0.006, 0.072, smooth(c * 3.0))
        C = [c1, c2, c3, (c3[0] - sep, c3[1] + 0.004), (wr + 0.012 - sep * 0.2, roof - 0.030),
             (wr - 0.115, roof - 0.004), (0.0, roof + 0.012)]
        # hood / deck (c = 0)
        h1 = (wm - 0.110, belt + 0.014)
        h2 = (wm - 0.190, belt + 0.026)
        hb = h2[1]
        dh = top - hb
        Hh = [h1, h2, (0.664, hb + dh * 0.45), (0.658, hb + dh * 0.45 + 0.0008), (0.46, hb + dh * 0.82),
              (0.22, hb + dh * 0.97), (0.0, top)]
        U = [(lerp(Hh[i][0], C[i][0], c), lerp(Hh[i][1], C[i][1], c)) for i in range(7)]
        return L + U

    NPT = 16

    def full_ring(self, z, ins=None):
        pts = self.right_pts(z)
        if ins is not None:
            pts = self.inset_pts(pts, ins)
        return pts

    def inset_pts(self, pts, ins):
        """Offsets the closed ring (right half + mirrored left half) inwards by ins[i] along the 2D normals."""
        n = len(pts)
        full = pts + [(-x, y) for (x, y) in reversed(pts[1:-1])]
        insf = list(ins) + list(reversed(ins[1:-1]))
        m = len(full)
        out = []
        for i in range(m):
            p0, p1, p2 = full[i - 1], full[i], full[(i + 1) % m]

            def nrm(a, b):
                dx, dy = b[0] - a[0], b[1] - a[1]
                ln = math.hypot(dx, dy) or 1.0
                return (dy / ln, -dx / ln)
            n1, n2 = nrm(p0, p1), nrm(p1, p2)
            nx, ny = n1[0] + n2[0], n1[1] + n2[1]
            ln = math.hypot(nx, ny) or 1.0
            nx, ny = nx / ln, ny / ln
            out.append((p1[0] - nx * insf[i], p1[1] - ny * insf[i]))
        return out[:n]          # right half only (mirrored later)


SEDAN = Style("sedan")
HATCH = Style("hatchback", zf=2.12, zr=-2.12, ax_f=1.275, ax_r=-1.275, roof=1.50, ws_top=0.15, ws_base=0.90,
              bl_top=-1.25, bl_base=-1.95, belt_cab=0.95, belt_tail=1.00, deck=1.03, hood=0.90, wmax=0.90,
              side_glass=((0.55, -0.34), (-0.50, -1.50)), rear_door_gap=-9.0, hatch=True)
SUV = Style("suv", zf=2.33, zr=-2.32, ax_f=1.43, ax_r=-1.43, roof=1.72, ws_top=0.20, ws_base=1.00, bl_top=-1.30,
            bl_base=-2.05, belt_cab=1.13, belt_tail=1.15, deck=1.18, hood=1.07, wmax=0.945, zb0=0.22,
            tire_r=0.37, track=1.62, side_glass=((0.60, -0.34), (-0.50, -1.65)), rear_door_gap=-9.0, hatch=True)


# ----------------------------------------------------------------------------------------------------------------
# hull: lofted cross-sections -> outer solid and inner cavity solid
# ----------------------------------------------------------------------------------------------------------------
NR = Style.NPT
RING_N = 2 * NR - 2
COL_BAND = 0


def zone(S, z, k):
    """What the upper body is at station z, band k: 'glass', 'black', 'paint'."""
    c = S.cabin_c(z)
    (f0, f1), (r0, r1) = S.side_glass
    if k in (9, 10):
        fl = f0 if k == 9 else f0 - 0.20           # raked front edge of the side glass (the A-pillar line)
        if c > 0.5 and (f1 < z < fl or r1 < z < r0):
            return "glass"
        if c > 0.5 and S.bpillar[1] < z < S.bpillar[0]:
            return "black"
        return "paint"
    if k in (12, 13, 14):
        if 0.04 < c < 0.97:
            return "glass"
        return "paint"
    if k == 8 and c > 0.5 and (S.side_glass[0][1] < z < S.side_glass[0][0] or S.side_glass[1][1] < z < S.side_glass[1][0]):
        return "chrome"
    if k == 8 and c > 0.5 and S.bpillar[1] < z < S.bpillar[0]:
        return "black"
    return "paint"


def classify(S, z0, z1, k, cavity):
    zm = 0.5 * (z0 + z1)
    c = S.cabin_c(zm)
    zn = zone(S, zm, k)
    if cavity:
        if zn == "glass":
            return "GlassHole"
        if k <= 1:
            return "Floor"
        if k >= 13 and c > 0.5:
            return "Headliner"
        if k >= 12 and c > 0.5:
            return "Interior"
        return "Interior"
    # --- outer skin ---
    if k == 0:
        return "Underbody"
    # panel gap strips
    if S.rear_door_gap > -5 and S.rear_door_gap - 1e-4 <= z0 and z1 <= S.rear_door_gap + 0.006 + 1e-4 and 2 <= k <= 10:
        return "Gap"
    if 1.016 - 1e-4 <= z0 and z1 <= 1.024 + 1e-4 and 11 <= k <= 14 and S.cabin_c(z0) < 0.02:
        return "Gap"
    if k == 11 and S.cabin_c(zm) < 0.02 and S.ws_base + 0.02 < zm < S.zf - 0.12:
        return "Gap"
    if k <= 3 and (zm > S.zf - 0.35 or zm < S.zr + 0.38):
        return "Trim"
    if 2 <= k <= 3 and S.ax_r + 0.42 < zm < S.ax_f - 0.42:
        return "Trim"
    if zn == "glass":
        return "Glass" if not S.traffic else "GlassTraffic"
    if zn == "black":
        return "Trim"
    if zn == "chrome":
        return "Chrome"
    return "CarPaint"


def stations(S, lo, hi, extra=(), step=0.06, ends=(0.004, 0.012, 0.022, 0.035, 0.05, 0.07, 0.1, 0.15, 0.22)):
    zs = set()
    n = max(2, int(round((hi - lo) / step)))
    for i in range(n + 1):
        zs.add(round(lo + (hi - lo) * i / n, 4))
    for d in ends:
        zs.add(round(lo + d, 4))
        zs.add(round(hi - d, 4))
    for e in extra:
        if lo < e < hi:
            zs.add(round(e, 4))
    out = []
    for z in sorted(zs):
        if out and z - out[-1] < 0.0015:
            continue
        out.append(z)
    return out


def hull_extras(S):
    ex = [S.ws_base, S.ws_top, S.bl_top, S.bl_base, S.ws_base + 0.02, 1.016, 1.024, S.door[0], S.door[1], S.rear_door_gap,
          S.rear_door_gap + 0.006, S.bpillar[0], S.bpillar[1], S.ax_f + 0.45, S.ax_f - 0.45, S.ax_r + 0.45, S.ax_r - 0.45,
          S.side_glass[0][0], S.side_glass[0][1], S.side_glass[1][0], S.side_glass[1][1], S.ws_base - 0.2, S.ws_top + 0.2]
    for (a, b) in S.side_glass:
        ex += [a + 0.0012, b - 0.0012]
    # the hood seams are marked by 1.016-1.024 stations; the closest neighbours are inserted explicitly
    return ex


def ring_xy(S, z, zlo, zhi, ins=None, fillet=0.045):
    pts = S.full_ring(z, ins)
    full = pts + [(-x, y) for (x, y) in reversed(pts[1:-1])]
    d = min(z - zlo, zhi - z)
    if d < fillet:
        t = clamp(d / fillet)
        k = math.sqrt(max(0.0, 1 - (1 - t) ** 2))
        cy = sum(y for _, y in full) / len(full)
        out = []
        for (x, y) in full:
            vx, vy = -x, cy - y
            ln = math.hypot(vx, vy) or 1.0
            s = (1 - k) * fillet
            out.append((x + vx / ln * s, y + vy / ln * s))
        full = out
    return full


def cav_ins(S, z):
    c = S.cabin_c(z)
    lo = [0.05, 0.05, 0.05, 0.06, 0.07, 0.075, 0.075, 0.07, 0.05]
    g = [0.016, 0.012, 0.012, 0.012]
    up = [lerp(0.04, g[i], smooth(c * 2.0)) for i in range(4)] + [0.04, 0.04, 0.04]
    return lo + up


def loft(S, m, zs, zlo, zhi, cavity=False, fillet=0.045):
    rings = []
    for z in zs:
        full = ring_xy(S, z, zlo, zhi, cav_ins(S, z) if cavity else None, fillet)
        rings.append([m.vert((x, y, z)) for x, y in full])
    n = len(rings[0])
    for i in range(len(zs) - 1):
        for j in range(n):
            k = j if j <= NR - 2 else n - 1 - j
            mat = classify(S, zs[i], zs[i + 1], k, cavity)
            m.face([rings[i][j], rings[i][(j + 1) % n], rings[i + 1][(j + 1) % n], rings[i + 1][j]], mat)
    for ring in (rings[0], rings[-1]):
        cf = m.face(list(ring), "CarPaint" if not cavity else "Interior")
        if cf is not None:
            for e in cf.edges:
                e.smooth = False
    return rings


def prism(poly_zy, x0, x1, mat):
    """Convex prism: polygon given as (z, y) points, extruded along x."""
    m = Msh()
    a = [m.vert((x0, y, z)) for z, y in poly_zy]
    b = [m.vert((x1, y, z)) for z, y in poly_zy]
    m.face(a, mat)
    m.face(b[::-1], mat)
    n = len(a)
    for i in range(n):
        m.face([a[i], a[(i + 1) % n], b[(i + 1) % n], b[i]], mat)
    return m


def offset_poly(pts, d):
    """Offsets a convex polygon (z, y) outwards by d (inwards for d < 0)."""
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    sgn = 1.0 if area > 0 else -1.0
    out = []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]

        def nrm(a, b):
            dx, dy = b[0] - a[0], b[1] - a[1]
            ln = math.hypot(dx, dy) or 1.0
            return (dy / ln * sgn, -dx / ln * sgn)
        n1, n2 = nrm(p0, p1), nrm(p1, p2)
        bx, by = n1[0] + n2[0], n1[1] + n2[1]
        dot = n1[0] * bx + n1[1] * by
        out.append((p1[0] + bx / dot * d, p1[1] + by / dot * d))
    return out


# ----------------------------------------------------------------------------------------------------------------
# projected decals (lamps, grille): ruled patches ray-cast onto the body
# ----------------------------------------------------------------------------------------------------------------
class Bvh:
    def __init__(self, obs):
        verts, polys = [], []
        for ob in obs:
            base = len(verts)
            mw = RXI @ ob.matrix_world
            verts += [mw @ v.co for v in ob.data.vertices]
            polys += [tuple(base + i for i in p.vertices) for p in ob.data.polygons]
        self.tree = BVHTree.FromPolygons(verts, polys)

    def hit(self, x, y, zstart, dz):
        loc, nrm, _, _ = self.tree.ray_cast(V((x, y, zstart)), V((0, 0, dz)), 6.0)
        return loc, nrm


def patch(m, bvh, fn, mat, u0, u1, v0, v1, nu, nv, off, zstart, dz, flip_x=False):
    """Ruled patch: fn(u, v) -> (x, y); each node is ray-cast along z from zstart and lifted by off(u, v) along the hit
    normal. Quads face the viewer (-dz)."""
    grid = {}
    for i in range(nu + 1):
        for j in range(nv + 1):
            u = lerp(u0, u1, i / nu)
            v = lerp(v0, v1, j / nv)
            x, y = fn(u, v)
            if flip_x:
                x = -x
            loc, nrm = bvh.hit(x, y, zstart, dz)
            if loc is None:
                continue
            if nrm.dot(V((0, 0, -dz))) < 0:
                nrm = -nrm
            grid[(i, j)] = m.vert(loc + nrm * off(u, v))
    for i in range(nu):
        for j in range(nv):
            q = [grid.get((i, j)), grid.get((i + 1, j)), grid.get((i + 1, j + 1)), grid.get((i, j + 1))]
            if any(p is None for p in q):
                continue
            n = (q[1].co - q[0].co).cross(q[3].co - q[0].co)
            if n.z * dz > 0:          # facing away from the viewer
                q = q[::-1]
            m.face(q, mat)


def tail_fn(u, v):
    x = 0.515 + 0.365 * u
    yhi = 0.945 - 0.010 * u - 0.028 * u * u
    ylo = 0.795 + 0.050 * smooth(u)
    e = (1 - abs(2 * u - 1) ** 5) ** 0.38
    yc, hh = 0.5 * (yhi + ylo), 0.5 * (yhi - ylo) * e
    return x, yc + (2 * v - 1) * hh


def head_fn(u, v):
    x = 0.385 + 0.475 * u
    yhi = 0.790 - 0.045 * u * u
    ylo = 0.628 + 0.010 * u
    e = (1 - abs(2 * u - 1) ** 5) ** 0.38
    yc, hh = 0.5 * (yhi + ylo), 0.5 * (yhi - ylo) * e
    return x, yc + (2 * v - 1) * hh


def lens_off(depth, margin=0.14):
    def f(u, v):
        return depth * smooth(min(u, 1 - u, v, 1 - v) / margin)
    return f


def const_off(d):
    return lambda u, v: d


def tail_lights(bvh, S):
    m = Msh()
    zs, dz = S.zr - 1.2, 1.0
    for sx, flip in ((1, False), (-1, True)):
        kw = dict(zstart=zs, dz=dz, flip_x=flip)
        patch(m, bvh, tail_fn, "Trim", 0, 1, 0, 1, 24, 4, const_off(0.0025), **kw)
        patch(m, bvh, tail_fn, "TailLamp", 0.05, 0.95, 0.52, 0.93, 22, 3, const_off(0.0045), **kw)
        patch(m, bvh, tail_fn, "TailLamp", 0.05, 0.31, 0.07, 0.50, 6, 3, const_off(0.0045), **kw)
        patch(m, bvh, tail_fn, "Reverse", 0.35, 0.58, 0.07, 0.46, 6, 3, const_off(0.0045), **kw)
        patch(m, bvh, tail_fn, "Indicator", 0.62, 0.94, 0.07, 0.46, 8, 3, const_off(0.0045), **kw)
        patch(m, bvh, tail_fn, "TailLens", 0, 1, 0, 1, 26, 6, lens_off(0.010), **kw)
    return m


def head_lights(bvh, S):
    m = Msh()
    zs, dz = S.zf + 1.2, -1.0
    for sx, flip in ((1, False), (-1, True)):
        kw = dict(zstart=zs, dz=dz, flip_x=flip)
        patch(m, bvh, head_fn, "Trim", 0, 1, 0, 1, 24, 4, const_off(0.0025), **kw)
        patch(m, bvh, head_fn, "Chrome", 0.06, 0.52, 0.10, 0.74, 8, 3, const_off(0.0040), **kw)
        patch(m, bvh, head_fn, "EngineAlu", 0.56, 0.94, 0.10, 0.74, 8, 3, const_off(0.0040), **kw)
        patch(m, bvh, head_fn, "Headlight", 0.05, 0.95, 0.80, 0.93, 22, 1, const_off(0.0050), **kw)
        for uc, rr in ((0.30, 0.060), (0.74, 0.042)):
            x, y = head_fn(uc, 0.42)
            x = -x if flip else x
            loc, nrm = bvh.hit(x, y, zs, dz)
            if loc is not None:
                m.cyl(loc + nrm * 0.004, rr, 0.010, "Trim", axis="z", seg=16)
        patch(m, bvh, head_fn, "HeadLens", 0, 1, 0, 1, 26, 6, lens_off(0.010), **kw)
    return m


def front_grille(bvh, S):
    """Upper slot, lower intake and fog lamp pods on the nose (projected onto the body, merged into Body)."""
    m = Msh()
    zs, dz = S.zf + 1.2, -1.0
    kw = dict(zstart=zs, dz=dz)

    def slot(u, v):
        x = lerp(-0.43, 0.43, u)
        return x, lerp(0.598, 0.668, v) + 0.012 * (abs(x) / 0.43) ** 2
    patch(m, bvh, slot, "Trim", 0, 1, 0, 1, 24, 2, const_off(0.003), **kw)
    for a, b in ((0.12, 0.26), (0.40, 0.54), (0.70, 0.84)):
        patch(m, bvh, slot, "TrimSat", 0.02, 0.98, a, b, 22, 1, const_off(0.009), **kw)
    patch(m, bvh, slot, "Chrome", 0.0, 1.0, 0.0, 0.05, 24, 1, const_off(0.006), **kw)

    def intake(u, v):
        x = lerp(-0.62, 0.62, u)
        t = (abs(x) / 0.62) ** 2
        return x, lerp(0.318 + 0.03 * t, 0.50 - 0.05 * t, v)
    # the lower intake is a real opening in the nose (see build_hero): a frame and slats, the radiator shows behind
    for (u0, u1, v0, v1) in ((0.0, 1.0, 0.0, 0.14), (0.0, 1.0, 0.86, 1.0), (0.0, 0.04, 0.0, 1.0), (0.96, 1.0, 0.0, 1.0)):
        patch(m, bvh, intake, "Trim", u0, u1, v0, v1, 30 if u1 - u0 > 0.5 else 2, 2, const_off(0.004), **kw)
    for a in (0.28, 0.44, 0.60, 0.74):
        patch(m, bvh, intake, "TrimSat", 0.02, 0.98, a, a + 0.07, 26, 1, const_off(0.006), **kw)

    def fog(u, v):
        x = lerp(0.660, 0.800, u)
        return x, lerp(0.336, 0.436, v)
    for flip in (False, True):
        kw2 = dict(zstart=zs, dz=dz, flip_x=flip)
        patch(m, bvh, fog, "Trim", 0, 1, 0, 1, 8, 4, const_off(0.003), **kw2)
        patch(m, bvh, fog, "Chrome", 0.15, 0.85, 0.15, 0.85, 6, 3, const_off(0.0045), **kw2)
        patch(m, bvh, fog, "HeadLens", 0, 1, 0, 1, 8, 4, lens_off(0.006, 0.25), **kw2)
    return m


def rear_details(bvh, S):
    """Diffuser, bumper reflectors, plate pocket frame (projected onto the tail)."""
    m = Msh()
    zs, dz = S.zr - 1.2, 1.0
    kw = dict(zstart=zs, dz=dz)

    def diff(u, v):
        x = lerp(-0.60, 0.60, u)
        return x, lerp(S.zb(S.zr) + 0.02, 0.43, v)
    patch(m, bvh, diff, "Trim", 0, 1, 0, 1, 24, 3, const_off(0.003), **kw)

    def refl(u, v):
        x = lerp(0.60, 0.76, u)
        return x, lerp(0.40, 0.46, v)
    for flip in (False, True):
        patch(m, bvh, refl, "Reflector", 0, 1, 0, 1, 6, 1, const_off(0.004), zstart=zs, dz=dz, flip_x=flip)
    return m


# ----------------------------------------------------------------------------------------------------------------
# wheels
# ----------------------------------------------------------------------------------------------------------------
TIRE_W = 0.215


def wheel_object(name, pos, side, R=0.334, rim_r=0.216, hq=True):
    """Tyre + alloy wheel + brake disc. Axle along X; outward face is +X for side +1 (mirrored for -1)."""
    m = Msh()
    w2 = TIRE_W / 2
    seg = 40 if hq else 24
    sc = R / 0.334
    prof = [(0.088, rim_r - 0.002), (0.102, rim_r + 0.014), (0.1075, rim_r + 0.058), (0.1065, rim_r + 0.094),
            (0.099, R - 0.015), (0.083, R - 0.002), (0.045, R), (0.0, R + 0.001)]
    full = prof + [(-a, r) for a, r in reversed(prof[:-1])]
    # tread as seen from the outer face: profile runs from inner rim seat, around, to the other rim seat
    m.revolve([(a, r) for a, r in reversed(full)], "Tire", axis="x", seg=seg)
    # inner liner (so the tyre is not a see-through shell from inside the arch)
    m.revolve([(-0.088, rim_r - 0.002), (0.088, rim_r - 0.002)], "Tire", axis="x", seg=seg)
    # alloy: barrel lip + dish + hub
    lip = [(0.108, rim_r + 0.018), (0.110, rim_r + 0.004), (0.098, rim_r - 0.004), (0.082, rim_r - 0.014)]
    m.revolve(lip, "Rim", axis="x", seg=seg)
    dish = [(0.082, rim_r - 0.014), (0.074, rim_r - 0.040), (0.058, 0.115), (0.048, 0.075), (0.056, 0.060)]
    m.revolve(dish, "RimDark", axis="x", seg=seg)
    m.revolve([(0.056, 0.060), (0.072, 0.050), (0.080, 0.036)], "Rim", axis="x", seg=seg)
    m.cyl((0.082, 0, 0), 0.036, 0.006, "Rim", axis="x", seg=20)
    for a in range(5):
        base = a * math.tau / 5
        for d in (-0.13, 0.13):
            al = base + d
            r_mid = 0.5 * (0.050 + rim_r - 0.012)
            ln = rim_r - 0.012 - 0.050
            m.box((0.083, math.cos(al) * r_mid, math.sin(al) * r_mid), (0.016, 0.030, ln), "Rim",
                  rot=Matrix.Rotation(al - math.pi / 2, 4, "X"), bevel=0.003)
    for a in range(5):
        ang = a * math.tau / 5 + math.pi / 5
        c = V((0.088, math.cos(ang) * 0.043, math.sin(ang) * 0.043))
        m.cyl(c, 0.0085, 0.008, "Chrome", axis="x", seg=8)
    # brake disc + caliper (inside the spokes)
    m.cyl((0.020, 0, 0), 0.158 * sc, 0.020, "Brake", axis="x", seg=seg)
    m.cyl((0.030, 0, 0), 0.062, 0.050, "RimDark", axis="x", seg=24)
    m.box((0.022, 0.095 * sc, 0.060 * sc), (0.056, 0.060, 0.085), "RimDark", bevel=0.008, seg=2)
    ob = mesh_to_object(m, name, smooth_deg=35.0, recalc=False)
    if side < 0:
        ob.data.transform(Matrix.Rotation(math.pi, 4, "Z"))      # Blender Z = up: spin 180 about the vertical
        # (x, y) -> (-x, -y): outward face now -x
    ob.location = RX @ V(pos)
    return ob


# ----------------------------------------------------------------------------------------------------------------
# driver pose: Mani's sit_drive vectors (anchor frame: feet plane under the pelvis, body faces +z, measured in the car with
# gravity off), see game/characters/mani/mani_actions.json. The anchor is pitched back RECLINE degrees about the hip.
# ----------------------------------------------------------------------------------------------------------------
POSE = dict(pelvis=(0.0, 0.5747, -0.0395), head_top=(0.0, 1.441, -0.10), eye=(0.0, 1.356, -0.01),
            hand=(0.19, 0.9074, 0.40), heel=(0.12, -0.004, 0.47), ball=(0.124, -0.039, 0.63),
            ankle=(0.12, 0.075, 0.50), knee=(0.121, 0.536, 0.369))
RECLINE = 20.0
HIP = V((0.365, 0.575, -0.02))
DRV_X = HIP.x


def pose_r(p):
    c, s = math.cos(rad(RECLINE)), math.sin(rad(RECLINE))
    x, y, z = p
    return V((x, y * c + z * s, -y * s + z * c))


ANCHOR = HIP - pose_r(POSE["pelvis"])


def pose_pt(name, mirror=False):
    p = list(POSE[name])
    if mirror:
        p[0] = -p[0]
    return ANCHOR + pose_r(p)


EYE = pose_pt("eye") + V((0, 0, 0.05))
HUB = ANCHOR + pose_r((0.0, POSE["hand"][1], POSE["hand"][2] + 0.03))
STEER_TILT = 22.0
FLOOR_Y = 0.20


# ----------------------------------------------------------------------------------------------------------------
# steering wheel, dash, seats, pedals
# ----------------------------------------------------------------------------------------------------------------
def steering_wheel():
    m = Msh()
    R, r = 0.190, 0.0170
    nseg, nt = 44, 10
    ring = []
    for a in range(nseg):
        ang = a * math.tau / nseg
        cx, cy = math.cos(ang), math.sin(ang)
        tube = []
        for b in range(nt):
            bb = b * math.tau / nt
            rr = r * (1.12 if (abs(cx) > 0.8) else 1.0)       # slightly fatter grips at 9 and 3 o'clock
            p = (cx * (R + math.cos(bb) * rr), cy * (R + math.cos(bb) * rr), math.sin(bb) * rr)
            tube.append(m.vert(p))
        ring.append(tube)
    for a in range(nseg):
        for b in range(nt):
            m.face([ring[a][b], ring[(a + 1) % nseg][b], ring[(a + 1) % nseg][(b + 1) % nt], ring[a][(b + 1) % nt]], "Leather")
    # three spokes: 9, 3 and 6 o'clock
    for ang in (180.0, 0.0, 270.0):
        a = rad(ang)
        d = V((math.cos(a), math.sin(a), 0))
        mid = d * 0.115
        rot = Matrix.Rotation(a, 4, "Z")
        m.box(mid + V((0, 0, -0.004)), (0.145, 0.034 if ang != 270.0 else 0.030, 0.014), "Leather", rot=rot, bevel=0.004, seg=2)
        m.box(mid + V((0, 0, -0.0125)), (0.120, 0.012, 0.004), "Chrome", rot=rot)
    m.box((0, 0, 0.004), (0.118, 0.108, 0.050), "Leather", bevel=0.020, seg=3)         # airbag hub, facing the driver
    m.box((0, 0, 0.030), (0.100, 0.090, 0.004), "Interior", bevel=0.004)
    x, y, z = V((1, 0, 0)), V((0, math.cos(rad(STEER_TILT)), math.sin(rad(STEER_TILT)))), \
        V((0, math.sin(rad(STEER_TILT)), -math.cos(rad(STEER_TILT))))
    M3 = Matrix((x, y, z)).transposed()
    bmesh.ops.transform(m.bm, matrix=T(HUB) @ M3.to_4x4(), verts=m.bm.verts)
    return mesh_to_object(m, "SteeringWheel", pivot=HUB, smooth_deg=40.0, recalc=False)


def loft_x(m, xs, prof_fn, mat_fn):
    """Surface from profile polylines (z, y) at each x."""
    rows = [[m.vert((x, y, z)) for (z, y) in prof_fn(x)] for x in xs]
    for i in range(len(xs) - 1):
        for j in range(len(rows[0]) - 1):
            m.face([rows[i][j], rows[i + 1][j], rows[i + 1][j + 1], rows[i][j + 1]], mat_fn(j, 0.5 * (xs[i] + xs[i + 1])))
    return rows


DASH_BASE = [(1.00, 0.930), (0.90, 0.972), (0.70, 0.990), (0.585, 0.988), (0.555, 0.972), (0.545, 0.93), (0.545, 0.78),
             (0.560, 0.64), (0.605, 0.52), (0.72, 0.38), (0.98, 0.20)]
DASH_HUMP = [(1.00, 0.930), (0.90, 0.985), (0.70, 1.060), (0.575, 1.150), (0.520, 1.140), (0.512, 1.085),
             (0.515, 0.80), (0.545, 0.64), (0.600, 0.52), (0.72, 0.38), (0.98, 0.20)]


def dash_profile(x):
    w = smooth((0.34 - abs(x - DRV_X)) / 0.10)
    cs = smooth((0.17 - abs(x)) / 0.05)
    out = []
    for i in range(len(DASH_BASE)):
        z0, y0 = DASH_BASE[i]
        z1, y1 = DASH_HUMP[i]
        z, y = lerp(z0, z1, w), lerp(y0, y1, w)
        if 4 <= i <= 8:
            z -= 0.070 * cs * (1.0 if i < 8 else 0.4)
        out.append((z, y))
    return out


def vent(m, c, size, mat="Trim", fins=4, vertical=False):
    m.box(c, (size[0], size[1], 0.012), "Trim", bevel=0.004)
    for i in range(fins):
        t = (i + 0.5) / fins - 0.5
        if vertical:
            m.box((c[0] + t * size[0] * 0.8, c[1], c[2] - 0.003), (0.004, size[1] * 0.78, 0.012), "TrimSat")
        else:
            m.box((c[0], c[1] + t * size[1] * 0.8, c[2] - 0.003), (size[0] * 0.86, 0.004, 0.012), "TrimSat")


def build_dash():
    m = Msh()
    xs = sorted(set([round(-0.90 + 0.05 * i, 4) for i in range(37)] +
                    [round(DRV_X + d, 4) for d in (-0.34, -0.30, -0.26, -0.22, 0.22, 0.26, 0.30, 0.34)] +
                    [-0.17, -0.14, -0.11, -0.08, 0.08, 0.11, 0.14, 0.17]))

    def mat_fn(j, x):
        if j <= 3:
            return "Interior"
        if 4 <= j <= 6:
            return "Interior"
        return "TrimSat" if j == 7 else "Interior"
    loft_x(m, xs, dash_profile, mat_fn)
    # trim: aluminium-look strip across the fascia, glovebox, cluster surround
    m.box((-0.38, 0.80, 0.538), (0.76, 0.012, 0.012), "Chrome")
    m.box((DRV_X, 0.76, 0.532), (0.46, 0.010, 0.012), "Chrome")
    # glovebox outline
    gx0, gx1, gy0, gy1, gz = -0.78, -0.18, 0.60, 0.74, 0.555
    for (cx, cy, sx, sy) in ((0.5 * (gx0 + gx1), gy0, gx1 - gx0, 0.004), (0.5 * (gx0 + gx1), gy1, gx1 - gx0, 0.004),
                             (gx0, 0.5 * (gy0 + gy1), 0.004, gy1 - gy0), (gx1, 0.5 * (gy0 + gy1), 0.004, gy1 - gy0)):
        m.box((cx, cy, gz), (sx, sy, 0.006), "Gap")
    m.box((-0.48, 0.68, gz - 0.006), (0.10, 0.018, 0.014), "TrimSat", bevel=0.004)
    # vents
    vent(m, (0.800, 0.915, 0.548), (0.100, 0.046, 0.0))
    vent(m, (-0.800, 0.915, 0.548), (0.100, 0.046, 0.0))
    vent(m, (0.205, 0.925, 0.545), (0.075, 0.040, 0.0))
    vent(m, (-0.205, 0.925, 0.545), (0.075, 0.040, 0.0))
    vent(m, (0.0, 0.775, 0.488), (0.180, 0.034, 0.0), fins=3)
    # centre stack: screen bezel, knobs, buttons
    m.box((0.0, 0.905, 0.478), (0.225, 0.135, 0.016), "Trim", bevel=0.006)
    for kx in (-0.075, 0.0, 0.075):
        m.cyl((kx, 0.690, 0.478), 0.021, 0.026, "Chrome", axis="z", seg=16)
        m.cyl((kx, 0.690, 0.463), 0.016, 0.006, "Trim", axis="z", seg=16)
    for bx in (-0.075, -0.045, -0.015, 0.015, 0.045, 0.075):
        m.box((bx, 0.735, 0.486), (0.022, 0.012, 0.010), "TrimSat", bevel=0.002)
    m.box((0.0, 0.838, 0.492), (0.030, 0.026, 0.012), "Reflector", bevel=0.003)           # hazard button (red)
    # steering column shroud + stalks
    a = rad(STEER_TILT)
    cdir = V((0, -math.sin(a), math.cos(a)))
    m.cyl(HUB + cdir * 0.15 + V((0, 0, 0)), 0.050, 0.30, "Interior", axis="z", seg=20, rot=Matrix.Rotation(rad(STEER_TILT), 4, "X"))
    m.cyl(HUB + cdir * 0.03, 0.062, 0.05, "Interior", axis="z", seg=20, rot=Matrix.Rotation(rad(STEER_TILT), 4, "X"))
    for sgn in (1, -1):
        m.box(HUB + cdir * 0.06 + V((sgn * 0.085, 0.0, 0.0)), (0.090, 0.012, 0.012), "Interior", bevel=0.003)
    # dash pad speaker grille and defrost slot
    m.box((0.0, 0.982, 0.80), (0.60, 0.004, 0.06), "Trim")
    # instrument cluster surround
    m.box((DRV_X, 0.985, 0.508), (0.360, 0.150, 0.014), "Trim", bevel=0.005)
    # centre console
    m.box((0.0, 0.600, -0.080), (0.285, 0.170, 0.95), "Interior", bevel=0.016, seg=2)
    m.box((0.0, 0.690, -0.080), (0.270, 0.012, 0.90), "TrimSat", bevel=0.004)
    m.box((0.0, 0.742, -0.340), (0.240, 0.090, 0.340), "Leather", bevel=0.025, seg=2)               # armrest lid
    # gear selector (park / drive gate + lever), cup holders
    m.box((0.0, 0.699, 0.185), (0.090, 0.006, 0.225), "Trim", bevel=0.002)
    m.cyl((0.0, 0.765, 0.165), 0.015, 0.140, "Trim", axis="y", seg=12)
    m.box((0.0, 0.850, 0.165), (0.044, 0.070, 0.040), "Leather", bevel=0.014, seg=2)
    m.box((0.0, 0.700, 0.300), (0.050, 0.008, 0.050), "Chrome", bevel=0.002)             # drive-mode ring
    m.cyl((0.0, 0.696, 0.012), 0.036, 0.004, "Gap", axis="y", seg=18)
    m.cyl((0.0, 0.696, -0.070), 0.036, 0.004, "Gap", axis="y", seg=18)
    return mesh_to_object(m, "Dash", smooth_deg=50.0, recalc=False)


def dash_lights():
    """Two dials (speedometer, tachometer), a centre display and warning icons on the cluster face. Dark dial faces; only
    ticks, numerals, needles and icons carry the emissive DashLight / Needle materials."""
    m = Msh()
    zc = 0.5035
    for cx in (DRV_X + 0.115, DRV_X - 0.115):
        cy = 1.030
        m.cyl((cx, cy, zc), 0.060, 0.005, "Trim", axis="z", seg=32)                         # dial face
        m.revolve([(zc - 0.001, 0.062), (zc - 0.004, 0.064), (zc - 0.006, 0.060)], "Chrome", axis="z", centre=(cx, cy, 0.0),
                  seg=32)
        for t in range(27):
            ang = rad(-135 + t * 270 / 26)
            major = t % 3 == 0
            r0 = 0.049 if major else 0.052
            m.box((cx + math.sin(ang) * r0, cy + math.cos(ang) * r0, zc - 0.0035),
                  (0.0032 if major else 0.002, 0.010 if major else 0.005, 0.0018),
                  "Needle" if t > 21 else "DashLight", rot=Matrix.Rotation(-ang, 4, "Z"))
        for t in range(0, 9):                                                              # numerals (small blocks)
            ang = rad(-135 + t * 270 / 8)
            m.box((cx + math.sin(ang) * 0.034, cy + math.cos(ang) * 0.034, zc - 0.0035), (0.0075, 0.0105, 0.0016),
                  "DashLight")
        ang = rad(-110 if cx > DRV_X else -45)
        m.box((cx + math.sin(ang) * 0.024, cy + math.cos(ang) * 0.024, zc - 0.0055), (0.0045, 0.046, 0.0020), "Needle",
              rot=Matrix.Rotation(-ang, 4, "Z"))
        m.cyl((cx, cy, zc - 0.0065), 0.0085, 0.004, "Chrome", axis="z", seg=12)
    m.box((DRV_X, 1.030, zc - 0.0005), (0.082, 0.094, 0.003), "Trim", bevel=0.002)         # centre info display (dark)
    for i in range(4):
        m.box((DRV_X - 0.012 + (i % 2) * 0.008, 1.056 - i * 0.021, zc - 0.0035), (0.050 - (i % 2) * 0.016, 0.006, 0.0016),
              "DashLight")
    m.box((DRV_X, 1.0, zc - 0.0035), (0.060, 0.010, 0.0016), "Needle")
    for i in range(8):                                                                     # warning icons
        m.box((DRV_X - 0.07 + i * 0.020, 0.972, zc - 0.0025), (0.011, 0.011, 0.002), "Needle" if i % 3 == 0 else "DashLight")
    return mesh_to_object(m, "DashLights", smooth_deg=60.0, recalc=False)


def dash_screen():
    m = Msh()
    m.box((0.0, 0.905, 0.4695), (0.200, 0.112, 0.004), "Screen")
    for i in range(3):
        m.box((-0.055 + i * 0.055, 0.880, 0.4665), (0.040, 0.022, 0.002), "Interior")
    m.box((0.0, 0.935, 0.4665), (0.185, 0.012, 0.002), "Interior")
    return mesh_to_object(m, "DashScreen", smooth_deg=60.0, recalc=False)


def seat(m, x, kind="bucket", recline=22.0):
    """A seat whose hip point is at (x, HIP.y, HIP.z) (driver / passenger) in the car frame."""
    hp = V((x, HIP.y, HIP.z))
    a = rad(recline)
    ax = V((0, math.cos(a), -math.sin(a)))          # up the seat back
    nm = V((0, math.sin(a), math.cos(a)))           # out of the seat back, towards the occupant
    rot_back = Matrix.Rotation(-a, 4, "X")
    # cushion (front edge higher, 10 degrees)
    m.box(hp + V((0, -0.160, 0.17)), (0.50, 0.115, 0.54), "Fabric", rot=Matrix.Rotation(rad(10), 4, "X"), bevel=0.028, seg=3)
    for sx in (-1, 1):
        m.box(hp + V((sx * 0.235, -0.125, 0.17)), (0.055, 0.12, 0.50), "Fabric", rot=Matrix.Rotation(rad(10), 4, "X"), bevel=0.02, seg=2)
    # back
    m.box(hp + ax * 0.34 - nm * 0.085, (0.50, 0.66, 0.11), "Fabric", rot=rot_back, bevel=0.03, seg=3)
    for sx in (-1, 1):
        m.box(hp + ax * 0.30 - nm * 0.045 + V((sx * 0.235, 0, 0)), (0.06, 0.56, 0.12), "Fabric", rot=rot_back, bevel=0.022, seg=2)
    m.box(hp + ax * 0.36 - nm * 0.145, (0.46, 0.60, 0.06), "Leather", rot=rot_back, bevel=0.02, seg=2)         # back shell
    # headrest
    m.box(hp + ax * 0.72 - nm * 0.115, (0.23, 0.17, 0.095), "Fabric", rot=rot_back, bevel=0.035, seg=3)
    for sx in (-1, 1):
        m.cyl(hp + ax * 0.65 - nm * 0.125 + V((sx * 0.07, 0, 0)), 0.006, 0.10, "Chrome", axis="y", seg=8, rot=rot_back)
    # base / rails
    m.box(V((x, 0.33 + 0.0, hp.z + 0.12)), (0.42, 0.20, 0.38), "Trim", bevel=0.02)
    for sx in (-1, 1):
        m.box(V((x + sx * 0.20, FLOOR_Y + 0.025, hp.z + 0.10)), (0.035, 0.035, 0.62), "TrimSat", bevel=0.006)
    m.box(V((x + 0.255, 0.43, hp.z + 0.02)), (0.04, 0.05, 0.16), "Trim", bevel=0.01)     # recliner knob housing


def build_seats():
    m = Msh()
    seat(m, DRV_X)
    seat(m, -DRV_X)
    return mesh_to_object(m, "Seats", smooth_deg=55.0, recalc=False)


def build_interior_trim(S):
    m = Msh()
    # rear bench
    zc = -0.97
    a = rad(24.0)
    ax = V((0, math.cos(a), -math.sin(a)))
    nm = V((0, math.sin(a), math.cos(a)))
    rb = Matrix.Rotation(-a, 4, "X")
    hp = V((0.0, 0.565, zc))
    m.box(hp + V((0, -0.14, 0.14)), (1.24, 0.12, 0.52), "Fabric", rot=Matrix.Rotation(rad(7), 4, "X"), bevel=0.03, seg=2)
    m.box(hp + ax * 0.30 - nm * 0.07, (1.24, 0.60, 0.12), "Fabric", rot=rb, bevel=0.03, seg=2)
    for sx in (-0.38, 0.0, 0.38):
        m.box(hp + ax * 0.66 - nm * 0.10 + V((sx, 0, 0)), (0.20, 0.15, 0.085), "Fabric", rot=rb, bevel=0.03, seg=2)
    m.box(V((0, 0.34, zc + 0.10)), (1.05, 0.28, 0.40), "Trim")
    # parcel shelf and bulkhead behind the rear bench
    m.box(V((0.0, 0.962, -1.28)), (1.46, 0.020, 0.66), "Interior", bevel=0.004)
    m.box(V((0.0, 0.69, -1.16)), (1.50, 0.50, 0.03), "Interior")
    # trunk floor, side liners, boot sill
    m.box(V((0.0, 0.405, -1.78)), (1.30, 0.030, 1.20), "Floor")
    for sx in (-1, 1):
        m.box(V((sx * 0.63, 0.55, -1.80)), (0.04, 0.24, 1.12), "Floor", bevel=0.006)
    m.box(V((0.0, 0.50, -2.355)), (1.24, 0.12, 0.05), "Floor")
    # mirror, sun visors
    m.box(V((0.0, 1.335, 0.395)), (0.240, 0.060, 0.034), "Trim", bevel=0.012, seg=2)
    m.box(V((0.0, 1.335, 0.3775)), (0.205, 0.045, 0.002), "MirrorGlass")
    m.box(V((0.0, 1.390, 0.46)), (0.030, 0.050, 0.016), "Trim")
    for sx in (-1, 1):
        m.box(V((sx * 0.36, 1.418, 0.31)), (0.34, 0.010, 0.13), "Headliner", bevel=0.004)
    # floor mats, pedals
    for x, w, zc2 in ((DRV_X, 0.50, 0.35), (-DRV_X, 0.50, 0.35)):
        m.box(V((x + 0.02, FLOOR_Y + 0.004, zc2)), (w, 0.008, 0.62), "Fabric", bevel=0.002)
    ball = pose_pt("ball", mirror=True)         # right foot
    fwd = V((0, math.sin(rad(55)), math.cos(rad(55))))
    for (px, pw, ln) in ((ball.x - 0.005, 0.070, 0.13), (ball.x + 0.092, 0.105, 0.14)):
        c = V((px, ball.y + fwd.y * 0.045, ball.z + fwd.z * 0.045))
        m.box(c, (pw, 0.012, ln), "Trim", rot=Matrix.Rotation(rad(-55), 4, "X"), bevel=0.003)
        for i in range(4):
            m.box(c - V((0, 0.0, 0)) + (V((0, -fwd.z, fwd.y)) * 0.008) + fwd * (i - 1.5) * 0.028, (pw * 0.9, 0.004, 0.006), "TrimSat",
                  rot=Matrix.Rotation(rad(-55), 4, "X"))
        m.cyl(c + fwd * (ln / 2) + V((0, 0.12, 0.03)), 0.006, 0.26, "TrimSat", axis="z", seg=8,
              rot=Matrix.Rotation(rad(-40), 4, "X"))
    left = pose_pt("ball")
    m.box(V((left.x + 0.005, left.y + 0.035, left.z + 0.035)), (0.15, 0.012, 0.19), "TrimSat", rot=Matrix.Rotation(rad(-55), 4, "X"), bevel=0.004)
    return mesh_to_object(m, "InteriorTrim", smooth_deg=50.0, recalc=False)


def build_engine_bay(S):
    m = Msh()
    m.box(V((0.0, 0.50, 1.58)), (0.62, 0.48, 0.60), "Engine", bevel=0.03, seg=2)
    m.box(V((0.0, 0.80, 1.58)), (0.44, 0.10, 0.50), "EngineAlu", bevel=0.02, seg=2)
    for i in range(4):
        m.cyl(V((0.0, 0.78, 1.37 + i * 0.12)), 0.018, 0.30, "EngineAlu", axis="x", seg=10)
    m.box(V((0.0, 0.46, S.zf - 0.20)), (1.04, 0.34, 0.05), "Trim")                  # radiator + condenser
    for i in range(7):
        m.box(V((0.0, 0.335 + i * 0.045, S.zf - 0.228)), (0.96, 0.012, 0.012), "TrimSat")
    m.box(V((0.0, 0.46, S.zf - 0.27)), (0.74, 0.30, 0.05), "Engine", bevel=0.01)       # fan shroud
    m.box(V((-0.50, 0.70, 1.15)), (0.22, 0.17, 0.26), "Trim", bevel=0.01)          # battery
    m.box(V((0.43, 0.68, 1.15)), (0.28, 0.13, 0.20), "TrimSat", bevel=0.01)      # fuse / washer
    for sx in (-1, 1):
        m.cyl(V((sx * 0.52, 0.66, S.ax_f)), 0.075, 0.12, "EngineAlu", axis="y", seg=16)       # strut towers
        m.cyl(V((sx * 0.60, 0.43, S.ax_f - 0.30)), 0.03, 0.30, "Engine", axis="x", seg=10)
    m.box(V((0.0, 0.88, 1.0)), (1.5, 0.05, 0.05), "Trim")
    return mesh_to_object(m, "EngineBay", smooth_deg=50.0, recalc=False)


def build_underbody(S):
    m = Msh()
    m.box(V((0.0, S.zb0 + 0.008, 0.0)), (1.50, 0.016, 3.6), "Underbody")
    for sx in (-1, 1):
        m.box(V((sx * 0.50, 0.235, -2.02)), (0.24, 0.13, 0.62), "Engine", bevel=0.03, seg=2)           # mufflers
        m.cyl(V((sx * 0.50, 0.235, -0.95)), 0.032, 1.9, "Engine", axis="z", seg=10)
    m.cyl(V((0.12, 0.215, 0.1)), 0.05, 3.0, "Engine", axis="z", seg=10)
    return mesh_to_object(m, "Underbody", smooth_deg=50.0, recalc=False)


def plate_mesh():
    """Ontario-style plate (generic: no crest): white, blue lettering. Mounted in the rear pocket facing -z."""
    m = Msh()
    zc = -2.432
    m.box(V((0, 0.535, zc - 0.004)), (0.305, 0.152, 0.008), "Plate", bevel=0.003)
    for sy in (-1, 1):
        m.box(V((0, 0.535 + sy * 0.0745, zc - 0.0085)), (0.292, 0.003, 0.002), "PlateInk")
    for sx in (-1, 1):
        m.cyl(V((sx * 0.128, 0.590, zc - 0.009)), 0.0055, 0.003, "Chrome", axis="z", seg=8)
    return m


def add_text(m, txt, size, centre, mat, depth=0.0016):
    """Extruded text on the rear plate (reads left to right seen from behind the car)."""
    cu = bpy.data.curves.new("txt", "FONT")
    cu.body = txt
    cu.size = size
    cu.extrude = 0.0                      # flat glyphs: a thin ink layer in front of the plate (no extrusion artefacts)
    cu.align_x = "CENTER"
    cu.align_y = "CENTER"
    cu.resolution_u = 6
    cu.fill_mode = "FRONT"
    ob = bpy.data.objects.new("txt", cu)
    SCENE_COL.objects.link(ob)
    bpy.context.view_layer.update()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    bpy.data.objects.remove(ob)
    bpy.data.curves.remove(cu)
    bm = bmesh.new()
    bm.from_mesh(me)
    # text local (X right, Y up, Z towards the reader) -> car: right = -x, up = y, towards reader = -z
    mat4 = T(centre) @ rot_y(180)
    bmesh.ops.transform(bm, matrix=mat4, verts=bm.verts)
    for f in bm.faces:
        nf = m.bm.faces.new([m.bm.verts.new(v.co) for v in f.verts])
        nf.material_index = MI[mat]
        nf.smooth = False
    bm.free()
    bpy.data.meshes.remove(me)


# ----------------------------------------------------------------------------------------------------------------
# exterior details
# ----------------------------------------------------------------------------------------------------------------
def mirror_housing(m, sx, y, z):
    """Door mirror: stalk, shell, glass face towards the driver (-z). sx +1 = driver side."""
    x0 = sx * 0.935
    m.box(V((sx * 0.975, y - 0.032, z + 0.025)), (0.080, 0.024, 0.045), "Trim", bevel=0.008, seg=2)
    m.box(V((sx * 1.030, y, z)), (0.090, 0.095, 0.165), "CarPaint", bevel=0.030, seg=3,
          rot=Matrix.Rotation(rad(sx * 8), 4, "Y"))
    m.box(V((sx * 1.026, y, z - 0.084)), (0.075, 0.080, 0.004), "MirrorGlass", rot=Matrix.Rotation(rad(sx * 8), 4, "Y"))


def door_handle(m, bvh, sx, y, z, ln=0.15):
    loc, nrm = bvh.tree.ray_cast(V((sx * 1.4, y, z)), V((-sx, 0, 0)), 3.0)[:2]
    if loc is None:
        return
    m.box(loc + nrm * 0.002, (0.010, 0.040, ln + 0.05), "Trim", bevel=0.003)
    m.box(loc + nrm * 0.008, (0.014, 0.020, ln), "Chrome", bevel=0.005, seg=2)


def exhaust(m, S):
    for sx in (-1, 1):
        m.cyl(V((sx * 0.50, 0.275, S.zr + 0.015)), 0.040, 0.16, "Chrome", axis="z", seg=20)
        m.cyl(V((sx * 0.50, 0.275, S.zr - 0.008)), 0.031, 0.10, "Trim", axis="z", seg=16)


def body_extras(m, bvh, S):
    """Wipers, cowl vent, roof antenna fin, side repeaters (projected onto the body)."""
    slope = math.atan2(S.roof - 0.01 - S.hood, S.ws_base - S.ws_top)
    ph = slope
    sy = lambda z: S.hood + 0.0 + (S.ws_base - z) * math.tan(slope)          # windscreen surface height at z
    n = V((0, math.cos(ph), math.sin(ph)))
    m.box(V((0.0, S.hood + 0.012, S.ws_base + 0.065)), (1.34, 0.014, 0.12), "Trim", bevel=0.004)           # cowl vent strip
    for x0, ln, tilt in ((0.28, 0.58, 7.0), (-0.30, 0.50, 7.0)):
        z = S.ws_base - 0.055
        c = V((x0, sy(z), z)) + n * 0.010
        rot = rot_x(math.degrees(ph)) @ rot_y(tilt)
        m.box(c, (ln, 0.007, 0.016), "Trim", rot=rot, bevel=0.002)                                          # blade
        m.box(c + n * 0.006, (ln * 0.96, 0.004, 0.006), "Gap", rot=rot)
        m.box(V((x0 + (0.20 if x0 > 0 else 0.18), sy(S.ws_base - 0.03), S.ws_base - 0.03)) + n * 0.012, (0.02, 0.008, 0.04), "Trim",
              rot=rot_x(math.degrees(ph)))                                                                   # arm pivot
    m.box(V((0.0, S.roof - 0.018 + 0.026, -0.90)), (0.040, 0.050, 0.150), "Trim", bevel=0.012, seg=2,
          rot=rot_x(-8))                                                                                     # shark-fin antenna
    for sx in (-1, 1):
        loc, nrm = bvh.tree.ray_cast(V((sx * 1.4, 0.76, 1.72)), V((-sx, 0, 0)), 3.0)[:2]
        if loc is not None:
            m.box(loc + nrm * 0.002, (0.008, 0.026, 0.060), "Indicator", bevel=0.003)                       # side repeater
            m.box(loc + nrm * 0.001, (0.010, 0.034, 0.068), "Trim", bevel=0.003)


def join(objs, name):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    return ob


def copy_obj(ob, name):
    c = bpy.data.objects.new(name, ob.data.copy())
    c.location = ob.location.copy()
    SCENE_COL.objects.link(c)
    return c


def cutter_obj(m, name):
    return mesh_to_object(m, name, smooth_deg=None, recalc=True)


def build_hero():
    S = SEDAN
    ex = hull_extras(S)
    zs = stations(S, S.zr, S.zf, ex)
    m = Msh()
    loft(S, m, zs, S.zr, S.zf)
    outer = mesh_to_object(m, "Body", smooth_deg=40.0)
    czs = stations(S, S.zr + 0.06, S.zf - 0.06, ex, ends=(0.004, 0.012, 0.025, 0.04))
    m = Msh()
    loft(S, m, czs, S.zr + 0.06, S.zf - 0.06, cavity=True, fillet=0.03)
    cav = mesh_to_object(m, "Cavity", smooth_deg=40.0)
    # wheel arches
    m = Msh()
    t = Msh()
    for sx in (1, -1):
        for zc in (S.ax_f, S.ax_r):
            m.cyl(V((sx * 1.05, S.tire_r, zc)), S.tire_r + 0.046, 0.78, "Trim", axis="x", seg=40)
            t.cyl(V((sx * 1.00, S.tire_r, zc)), S.tire_r + 0.091, 0.80, "Interior", axis="x", seg=40)
    archcut = cutter_obj(m, "ArchCut")
    tubs = cutter_obj(t, "Tubs")
    dbg(outer, 'outer raw'); dbg(cav, 'cav raw'); dbg(archcut, 'archcut')
    boolean(outer, archcut, "DIFFERENCE")
    dbg(outer, 'outer-arch')
    boolean(cav, tubs, "DIFFERENCE")
    dbg(cav, 'cav-tubs')
    drop(archcut)
    drop(tubs)
    # plate pocket
    pm = Msh()
    pm.box(V((0, 0.535, (S.zr - 0.1 + -2.432) / 2)), (0.335, 0.176, (-2.432 - (S.zr - 0.1))), "Underbody")
    pocket = cutter_obj(pm, "Pocket")
    boolean(outer, cav, "DIFFERENCE")
    dbg(outer, 'outer-cav')
    boolean(outer, pocket, "DIFFERENCE")
    dbg(outer, 'outer-pocket')
    drop(cav)
    drop(pocket)
    bvh = Bvh([outer])
    nm = Msh()
    nm.box(V((0.0, 0.425, S.zf - 0.08)), (1.10, 0.12, 0.40), "Trim")                  # the lower intake opens into the engine bay
    nose = cutter_obj(nm, "NoseCut")
    boolean(outer, nose, "DIFFERENCE")
    drop(nose)
    body_full = outer
    # door + lid
    door_poly = [(0.80, 0.235), (0.80, 0.96), (0.30, 1.405), (-0.40, 1.405), (-0.40, 0.235)]
    lid_poly = [(-1.66, 0.78), (-1.66, 1.25), (-2.70, 1.25), (-2.70, 0.66), (-2.05, 0.66)]
    door = copy_obj(body_full, "DriverDoor")
    pin = cutter_obj(prism(offset_poly(door_poly, -0.0025), 0.55, 1.2, "Gap"), "pin")
    pout = cutter_obj(prism(offset_poly(door_poly, 0.0025), 0.55, 1.2, "Gap"), "pout")
    boolean(door, pin, "INTERSECT")
    dbg(door, 'door')
    boolean(body_full, pout, "DIFFERENCE")
    dbg(body_full, 'body-door')
    drop(pin)
    drop(pout)
    lid = copy_obj(body_full, "TrunkLid")
    lin = cutter_obj(prism(offset_poly(lid_poly, -0.0025), -0.4975, 0.4975, "Gap"), "lin")
    lout = cutter_obj(prism(offset_poly(lid_poly, 0.0025), -0.5025, 0.5025, "Gap"), "lout")
    boolean(lid, lin, "INTERSECT")
    dbg(lid, 'lid')
    boolean(body_full, lout, "DIFFERENCE")
    drop(lin)
    drop(lout)
    for ob in (body_full, door, lid):
        delete_material_faces(ob, "GlassHole")
    # --- details merged into the body ---
    det = []
    gm = front_grille(bvh, S)
    det.append(mesh_to_object(gm, "grille", smooth_deg=40.0, recalc=False))
    rm = rear_details(bvh, S)
    det.append(mesh_to_object(rm, "reardet", smooth_deg=40.0, recalc=False))
    pl = plate_mesh()
    add_text(pl, "OOT 2026", 0.064, V((0.0, 0.524, -2.4413)), "PlateInk")
    add_text(pl, "ONTARIO", 0.020, V((0.0, 0.5885, -2.4413)), "PlateInk")
    det.append(mesh_to_object(pl, "plate", smooth_deg=40.0, recalc=False))
    em = Msh()
    exhaust(em, S)
    body_extras(em, bvh, S)
    mirror_housing(em, -1, 1.01, 0.62)
    for (y, z) in ((0.89, -0.22), (0.90, -0.78)):
        door_handle(em, bvh, -1, y, z)
    door_handle(em, bvh, 1, 0.90, -0.78)
    det.append(mesh_to_object(em, "exdet", smooth_deg=45.0, recalc=False))
    body = join([body_full] + det, "Body")
    # door extras: mirror + exterior handle + interior handle / armrest
    dm = Msh()
    mirror_housing(dm, 1, 1.01, 0.62)
    door_handle(dm, bvh, 1, 0.89, -0.22)
    dm.box(V((0.80, 0.80, -0.10)), (0.06, 0.07, 0.62), "Interior", bevel=0.02, seg=2)         # armrest / door pull
    dm.box(V((0.825, 0.86, 0.10)), (0.03, 0.04, 0.16), "Chrome", bevel=0.01)                  # inside release
    dm.box(V((0.82, 0.76, 0.45)), (0.05, 0.14, 0.20), "TrimSat", bevel=0.01)                  # speaker grille
    for i in range(4):
        dm.box(V((0.806, 0.70 + i * 0.012, 0.45)), (0.02, 0.003, 0.17), "Trim")
    for i in range(4):
        dm.box(V((0.80, 0.835, -0.04 + i * 0.028)), (0.05, 0.02, 0.018), "Chrome", bevel=0.004)   # window switches
    dobj = mesh_to_object(dm, "doorx", smooth_deg=45.0, recalc=False)
    door = join([door, dobj], "DriverDoor")
    reorigin(door, V((0.925, 0.235, 0.80)))
    reorigin(lid, V((0.0, 0.985, -1.66)))
    # lamps use the lamp patches built on the final shape
    head = mesh_to_object(head_lights(bvh, S), "Headlights", smooth_deg=40.0, recalc=False)
    tail = mesh_to_object(tail_lights(bvh, S), "Taillights", smooth_deg=40.0, recalc=False)
    objs = {"Body": body, "DriverDoor": door, "TrunkLid": lid, "Headlights": head, "Taillights": tail}
    ax = S.ax_f
    for nm, (sx, sz) in {"Wheel_FL": (1, S.ax_f), "Wheel_FR": (-1, S.ax_f), "Wheel_RL": (1, S.ax_r),
                         "Wheel_RR": (-1, S.ax_r)}.items():
        objs[nm] = wheel_object(nm, (sx * S.track / 2, S.tire_r, sz), sx, R=S.tire_r)
    objs["SteeringWheel"] = steering_wheel()
    objs["Dash"] = build_dash()
    objs["DashLights"] = dash_lights()
    objs["DashScreen"] = dash_screen()
    objs["Seats"] = build_seats()
    objs["InteriorTrim"] = build_interior_trim(S)
    objs["EngineBay"] = build_engine_bay(S)
    objs["Underbody"] = build_underbody(S)
    return objs


def build_traffic(S, name):
    S.traffic = True
    ex = hull_extras(S)
    zs = stations(S, S.zr, S.zf, ex, step=0.08)
    m = Msh()
    loft(S, m, zs, S.zr, S.zf)
    outer = mesh_to_object(m, name, smooth_deg=40.0)
    m = Msh()
    for sx in (1, -1):
        for zc in (S.ax_f, S.ax_r):
            m.cyl(V((sx * 1.05, S.tire_r, zc)), S.tire_r + 0.06, 0.78, "Trim", axis="x", seg=24)
    cut = cutter_obj(m, "cut")
    boolean(outer, cut, "DIFFERENCE")
    drop(cut)
    bvh = Bvh([outer])
    # a cheap cabin behind the (translucent) glass: the inner skin with the window openings removed, plus seats and a dash,
    # so a driver placed at the seat anchor (OOTTrafficDriver) shows through the windows
    ex2 = hull_extras(S)
    czs = stations(S, S.zr + 0.06, S.zf - 0.06, ex2, step=0.12, ends=(0.01, 0.04))
    tm = Msh()
    loft(S, tm, czs, S.zr + 0.06, S.zf - 0.06, cavity=True, fillet=0.03)
    tub = mesh_to_object(tm, "tub", smooth_deg=40.0)
    tb = bmesh.new()
    tb.from_mesh(tub.data)
    bmesh.ops.reverse_faces(tb, faces=tb.faces)
    tb.to_mesh(tub.data)
    tb.free()
    delete_material_faces(tub, "GlassHole")
    im = Msh()
    seat(im, DRV_X)
    seat(im, -DRV_X)
    rb = Msh()
    zc = S.bl_base + 0.75 if S.hatch else -0.97
    rb.box(V((0.0, 0.50, zc)), (1.24, 0.14, 0.50), "Fabric", bevel=0.03, seg=2)
    rb.box(V((0.0, 0.84, zc - 0.20)), (1.24, 0.56, 0.12), "Fabric", rot=Matrix.Rotation(rad(-22), 4, "X"), bevel=0.03, seg=2)
    rb.box(V((0.0, 0.70, 0.78)), (1.60, 0.40, 0.55), "Interior", bevel=0.02, seg=2)               # dash
    rb.box(V((0.0, 0.50, 0.10)), (0.26, 0.30, 1.6), "Interior", bevel=0.02, seg=2)               # console
    parts_in = [tub, mesh_to_object(im, "seatsT", smooth_deg=55.0, recalc=False), mesh_to_object(rb, "restT", smooth_deg=55.0, recalc=False)]
    dy_t = S.belt(S.zr + 0.12) - SEDAN.belt(SEDAN.zr + 0.12)
    dy_h = S.belt(S.zf - 0.12) - SEDAN.belt(SEDAN.zf - 0.12)
    parts = [outer] + parts_in
    lm = Msh()
    for flip in (False, True):
        for fn, dyy, zst, dz in ((tail_fn, dy_t, S.zr - 1.2, 1.0), (head_fn, dy_h, S.zf + 1.2, -1.0)):
            def shifted(u, v, fn=fn, dyy=dyy):
                x, y = fn(u, v)
                return x, y + dyy
            lens = "TailLens" if dz > 0 else "HeadLens"
            core = "TailLamp" if dz > 0 else "Headlight"
            kw = dict(zstart=zst, dz=dz, flip_x=flip)
            patch(lm, bvh, shifted, "Trim", 0, 1, 0, 1, 12, 2, const_off(0.0025), **kw)
            patch(lm, bvh, shifted, core, 0.06, 0.94, 0.45, 0.90, 10, 1, const_off(0.0045), **kw)
            patch(lm, bvh, shifted, lens, 0, 1, 0, 1, 12, 2, lens_off(0.008), **kw)
    parts.append(mesh_to_object(lm, "lamps", smooth_deg=40.0, recalc=False))
    gm = Msh()
    gwid = 0.60

    def slot(u, v):
        x = lerp(-gwid, gwid, u)
        return x, lerp(S.zb(S.zf) + 0.03, S.zb(S.zf) + 0.17, v)
    patch(gm, bvh, slot, "Trim", 0, 1, 0, 1, 14, 2, const_off(0.003), zstart=S.zf + 1.2, dz=-1.0)
    patch(gm, bvh, slot, "TrimSat", 0.04, 0.96, 0.3, 0.7, 12, 1, const_off(0.008), zstart=S.zf + 1.2, dz=-1.0)
    parts.append(mesh_to_object(gm, "grille", smooth_deg=40.0, recalc=False))
    for nm, (sx, sz) in {"wFL": (1, S.ax_f), "wFR": (-1, S.ax_f), "wRL": (1, S.ax_r), "wRR": (-1, S.ax_r)}.items():
        parts.append(wheel_object(nm, (sx * S.track / 2, S.tire_r, sz), sx, R=S.tire_r, hq=False))
    ob = join(parts, name)
    return ob


# ----------------------------------------------------------------------------------------------------------------
def export(objs, path):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_cameras=False, export_lights=False, export_animations=False,
                              export_materials="EXPORT")


def bbox(ob):
    pts = [RXI @ (ob.matrix_world @ V(c)) for c in ob.bound_box]
    return (V((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            V((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def main():
    global SCENE_COL
    only = os.environ.get("SEDAN_ONLY", "")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    build_materials()
    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    SCENE_COL = bpy.data.collections.new("Sedan")
    sc.collection.children.link(SCENE_COL)
    print("ANCHOR", tuple(round(c, 3) for c in ANCHOR), "pitch", RECLINE, "HUB", tuple(round(c, 3) for c in HUB),
          "EYE", tuple(round(c, 3) for c in EYE))
    objs = build_hero()
    for nm in ("Body", "DriverDoor", "TrunkLid"):
        smooth_object(objs[nm], 35.0)
    export(list(objs.values()), os.path.join(OUT_DIR, "sedan.glb"))
    total = 0
    mn = V((1e9,) * 3)
    mx = V((-1e9,) * 3)
    for nm, o in objs.items():
        t = tris(o)
        total += t
        a, b = bbox(o)
        mn = V((min(mn.x, a.x), min(mn.y, a.y), min(mn.z, a.z)))
        mx = V((max(mx.x, b.x), max(mx.y, b.y), max(mx.z, b.z)))
        print("  %-14s %6d tris" % (nm, t))
    print("sedan.glb: %d tris, size %.2f x %.2f x %.2f" % (total, mx.x - mn.x, mx.y - mn.y, mx.z - mn.z))
    if only != "hero":
        tcol = bpy.data.collections.new("Traffic")
        sc.collection.children.link(tcol)
        off = 0.0
        for nm, st in (("traffic_sedan", Style("sedan")), ("traffic_hatchback", HATCH), ("traffic_suv", SUV)):
            SCENE_COL = tcol
            o = build_traffic(st, nm)
            smooth_object(o, 35.0)
            export([o], os.path.join(OUT_DIR, nm + ".glb"))
            a, b = bbox(o)
            print("%s.glb: %d tris, size %.2f x %.2f x %.2f" % (nm, tris(o), b.x - a.x, b.y - a.y, b.z - a.z))
            off += 3.2
            o.location.x += off
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND, compress=True)
    for p in (OUT_BLEND + "1",):
        if os.path.exists(p):
            os.remove(p)


if __name__ == "__main__":
    main()
