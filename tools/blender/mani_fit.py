"""Mani likeness fit: slim the parka / hoodie / jeans toward the approved turnaround sheet, measure by numbers.

    blender -b art_source/characters/mani/mani.blend -P tools/blender/mani_fit.py -- COMMAND [options]

Commands
  measure                 pose the rig into the sheet's A-pose, render silhouettes (workbench, same framing as
                          tools/likeness/vendor/blender_kiln/fidelity_check.py) and print IoU per panel and height band
  stats                   print clothing-to-body offsets (for choosing parameters)
  apply  --save           apply the slimming (PARAMS below, or --params=file.json) to the rest-pose meshes, save the
                          blend, re-export game/characters/mani/mani.glb (animations are the ones in the blend)
  apose-glb               write art_source/characters/mani/likeness/mani_apose.glb: the same meshes, skinning baked in
                          the A-pose (measurement only, never used by the game)

Options  --params=FILE.json   override PARAMS      --views=front,side,back      --refdir=DIR (reference_<view>.png)
The game's rest pose and every animation clip are untouched: only the parka / hoodie / jeans rest vertices (and the
small parka parts that ride on them) move.
"""
import json
import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Vector, Matrix, Quaternion, kdtree
from mathutils.bvhtree import BVHTree

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
CMD = ARGV[0] if ARGV else "measure"
OPT = {a.split("=")[0]: (a.split("=", 1)[1] if "=" in a else True) for a in ARGV[1:] if a.startswith("--")}
SCRATCH = "/private/tmp/claude-501/-Users-kamanika-Downloads-out-of-town/5498a04d-a1fe-4ca0-a447-3242544418f6/scratchpad/mani_fit"
OUT_GLB = os.path.join(REPO, "game/characters/mani/mani.glb")
OUT_BLEND = os.path.join(REPO, "art_source/characters/mani/mani.blend")
OUT_APOSE = os.path.join(REPO, "art_source/characters/mani/likeness/mani_apose.glb")

# ---- measurement pose: upper-arm angle from vertical, read off the front panel of the sheet -----------------
POSE = dict(arm_deg=18.0, fore_extra_deg=12.0, leg_deg=0.0)

# ---- slimming parameters: radial scale factors (1 = unchanged) about the skeleton, keyed by height / arm position ----
#  tx/ty : torso half-width / half-depth factor at hem z=0.87, 1.0, 1.15, 1.3, 1.45 (about the body centre line)
#  sl    : sleeve radius factor at shoulder, elbow, wrist (about the arm bones)
#  jx/jy : jeans radius factor at z=0.2, 0.35, 0.55, 0.8, 0.93 (about the leg bones; 1 at the boot and at the waist)
#  hood  : the hoodie under the parka is slimmed this much more than the parka
PARAMS = dict(
    tx=[0.80, 0.82, 0.86, 0.88, 0.9], ty=[0.80, 0.85, 0.88, 0.9, 0.9],
    sl=[0.88, 0.88, 0.92], hood_s=1.0, jc=[0.0] * 5, jx=[1.0, 0.9, 0.88, 0.88, 0.9], jy=[1.0, 0.9, 0.88, 0.88, 0.9], hood=0.03,
)
TZ = [0.87, 1.0, 1.15, 1.3, 1.45]
JZ = [0.22, 0.35, 0.55, 0.8, 0.93]
FIT_PARAMS = os.path.join(REPO, "art_source/characters/mani/likeness/fit_params.json")
for _f in (OPT.get("--params") or (FIT_PARAMS if os.path.exists(FIT_PARAMS) else None),):
    if _f:
        PARAMS.update(json.load(open(_f)))


PARTS_ON_PARKA = []


# The sheet's side figure faces left in the image, so it is the character's RIGHT side (camera at +X). The stock
# run_fidelity.sh renders the "left" view (character facing right) for --panel side, which mirrors the figure.
SIDE_VIEW = OPT.get("--sideview", "right")


def log(*a):
    print("[fit]", *a, flush=True)


def ob(name):
    return bpy.data.objects[name]


RIG = ob("ManiRig")
PARTS_ON_PARKA_ALL = ["Mani_parka_placket", "Mani_parka_ziptape", "Mani_parka_snaps", "Mani_zip_puller",
                  "Mani_parka_neckband", "Mani_parka_hood", "Mani_hoodie_hood", "Mani_drawstrings"]


# --------------------------------------------------------------------------------------------- pose
def rest_pose():
    RIG.animation_data_clear() if RIG.animation_data else None
    for pb in RIG.pose.bones:
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.location = (0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def rot_in_bone(pb, axis_world, ang):
    """Rotate pose bone about a world-axis through its head by `ang` (radians), from rest."""
    R = Quaternion(axis_world, ang).to_matrix()
    rest = pb.bone.matrix_local.to_3x3()
    ql = (rest.inverted() @ R @ rest).to_quaternion()
    pb.rotation_mode = "QUATERNION"
    pb.rotation_quaternion = ql


def apose(arm_deg=None, fore_extra=None):
    arm_deg = POSE["arm_deg"] if arm_deg is None else arm_deg
    fore_extra = POSE["fore_extra_deg"] if fore_extra is None else fore_extra
    rest_pose()
    for s, sg in (("l", 1.0), ("r", -1.0)):
        ua = RIG.data.bones["upperarm_" + s]
        d = (ua.tail_local - ua.head_local).normalized()
        cur = math.degrees(math.acos(max(-1, min(1, -d.z))))           # from straight down
        # rotate about Y so the arm swings toward the body (left arm, +X: positive rotation about +Y moves -Z to +X? use sign test)
        ang = math.radians(cur - arm_deg)
        for sign in (1, -1):
            rot_in_bone(RIG.pose.bones["upperarm_" + s], Vector((0, 1, 0)), sign * ang * sg)
            bpy.context.view_layer.update()
            tail = RIG.pose.bones["upperarm_" + s].tail
            d2 = (tail - RIG.pose.bones["upperarm_" + s].head).normalized()
            got = math.degrees(math.acos(max(-1, min(1, -d2.z))))
            if abs(got - arm_deg) < 1.0:
                break
        if fore_extra:
            fa = RIG.data.bones["lowerarm_" + s]
            rot_in_bone(RIG.pose.bones["lowerarm_" + s], Vector((0, 1, 0)), -sg * math.radians(fore_extra))
    if POSE["leg_deg"]:
        for s, sg in (("l", 1.0), ("r", -1.0)):
            pb = RIG.pose.bones["thigh_" + s]
            x0 = RIG.data.bones["foot_" + s].head_local.x
            for sign in (1, -1):
                rot_in_bone(pb, Vector((0, 1, 0)), sign * sg * math.radians(POSE["leg_deg"]))
                bpy.context.view_layer.update()
                if (RIG.pose.bones["foot_" + s].head.x - x0) * sg < 0:   # toward the centre line for +leg_deg
                    break
    bpy.context.view_layer.update()


# --------------------------------------------------------------------------------------------- meshes
def meshes():
    return [o for o in bpy.data.objects if o.type == "MESH"]


def rest_bmesh(o):
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)       # objects are parented to the rig at identity; keep world coordinates
    return bm


def bvh_of(o):
    bm = rest_bmesh(o)
    t = BVHTree.FromBMesh(bm)
    return bm, t


def set_world_coords(o, pts):
    inv = o.matrix_world.inverted()
    for v, p in zip(o.data.vertices, pts):
        v.co = inv @ p
    o.data.update()


def world_coords(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


class Garment:
    """Rest-pose coordinates of a mesh as numpy, with its arm weight; remembers the pre-fit shape on the mesh datablock."""

    def __init__(self, name):
        self.o = ob(name)
        me = self.o.data
        n = len(me.vertices)
        if "fit_orig" in me:
            flat = np.array(me["fit_orig"], dtype=np.float64)
        else:
            flat = np.empty(n * 3)
            me.vertices.foreach_get("co", flat)
            me["fit_orig"] = flat.tolist()
        self.co = flat.reshape(n, 3)                       # armature space == object space (identity parent)
        self.mw = np.array(self.o.matrix_world)
        assert np.allclose(self.mw, np.eye(4), atol=1e-5), name
        names = {g.index: g.name for g in self.o.vertex_groups}
        self.arm = np.zeros(n)
        self.groups = [dict() for _ in range(n)]
        for v in me.vertices:
            for g in v.groups:
                nm = names[g.group]
                self.groups[v.index][nm] = g.weight
                if nm.startswith(("upperarm", "lowerarm", "hand")):
                    self.arm[v.index] += g.weight
        self.arm = np.clip(self.arm, 0, 1)

    def write(self, co):
        self.o.data.vertices.foreach_set("co", np.asarray(co, dtype=np.float64).ravel())
        self.o.data.update()


def bone_pts(name):
    b = RIG.data.bones[name]
    return np.array(b.head_local), np.array(b.tail_local)


def nearest_on_polyline(P, pts):
    """P: (n,3); pts: list of polyline points. returns nearest points (n,3) and the arclength fraction (n,)."""
    best = np.full(len(P), 1e9); out = np.zeros_like(P); frac = np.zeros(len(P))
    seg_len = [np.linalg.norm(pts[i + 1] - pts[i]) for i in range(len(pts) - 1)]
    tot = sum(seg_len); acc = 0.0
    for i in range(len(pts) - 1):
        a, b = pts[i], pts[i + 1]
        d = b - a
        t = np.clip(((P - a) @ d) / (d @ d), 0, 1)
        q = a + t[:, None] * d
        dist = np.linalg.norm(P - q, axis=1)
        m = dist < best
        best[m] = dist[m]; out[m] = q[m]; frac[m] = (acc + t[m] * seg_len[i]) / tot
        acc += seg_len[i]
    return out, frac


def arm_axis(side):
    up_h, up_t = bone_pts("upperarm_" + side)
    lo_h, lo_t = bone_pts("lowerarm_" + side)
    hd_h, hd_t = bone_pts("hand_" + side)
    return [up_h, lo_h, hd_h]


def leg_axis(side):
    th, _ = bone_pts("thigh_" + side)
    ch, _ = bone_pts("calf_" + side)
    fh, _ = bone_pts("foot_" + side)
    return [th, ch, fh]


_TORSO_CY = {}


def torso_cy(g):
    key = g.o.name
    if key not in _TORSO_CY:
        sel = (np.abs(g.co[:, 0]) < 0.2) & (g.arm < 0.3)
        zs, ys = g.co[sel, 2], g.co[sel, 1]
        bins = np.arange(0.85, 1.56, 0.05)
        cy = []
        for b in bins:
            m = (zs >= b) & (zs < b + 0.05)
            cy.append((ys[m].min() + ys[m].max()) / 2 if m.any() else np.nan)
        cy = np.array(cy); ok = ~np.isnan(cy)
        _TORSO_CY[key] = (bins[ok] + 0.025, cy[ok])
    return _TORSO_CY[key]


def top_transform(g, P, extra=0.0):
    """Hoodie / parka: torso scaled about the body centre line, sleeves about the arm bones, blended by arm weight."""
    co = g.co
    z = co[:, 2]
    tx = np.interp(z, TZ, np.array(P["tx"]) - extra)
    ty = np.interp(z, TZ, np.array(P["ty"]) - extra)
    zb, cyb = _cy_ref(g)
    cy = np.interp(z, zb, cyb)
    torso = co.copy()
    torso[:, 0] = co[:, 0] * tx
    torso[:, 1] = cy + (co[:, 1] - cy) * ty
    arm = co.copy()
    for side, sel in (("l", co[:, 0] > 0), ("r", co[:, 0] <= 0)):
        pts = arm_axis(side)
        q, fr = nearest_on_polyline(co[sel], pts)
        k = np.interp(fr, [0.0, 0.5, 1.0], np.array(P["sl"]) - extra)
        arm[sel] = q + (co[sel] - q) * k[:, None]
    w = g.arm[:, None]
    return torso * (1 - w) + arm * w


_CY_REF = {}


def _cy_ref(g):
    if "ref" not in _CY_REF:
        _CY_REF["ref"] = torso_cy(g)
    return _CY_REF["ref"]


def jeans_transform(g, P):
    co = g.co
    out = co.copy()
    z = co[:, 2]
    for side, sel in (("l", co[:, 0] > 0), ("r", co[:, 0] <= 0)):
        pts = leg_axis(side)
        q, fr = nearest_on_polyline(co[sel], pts)
        zz = z[sel]
        kx = np.interp(zz, [0.16] + JZ + [1.0], [1.0] + list(P["jx"]) + [1.0])
        ky = np.interp(zz, [0.16] + JZ + [1.0], [1.0] + list(P["jy"]) + [1.0])
        # below the lowest key the jeans keep their boot-hem fit
        d = co[sel] - q
        o = q.copy()
        o[:, 0] += d[:, 0] * kx
        o[:, 1] += d[:, 1] * ky
        o[:, 2] = co[sel][:, 2]
        # the sheet's stance is a little narrower than the rig's rest stance: draw the leg in toward the centre line
        jc = np.interp(zz, [0.16] + JZ + [1.0], [0.0] + list(P.get("jc", [0.0] * 5)) + [0.0])
        o[:, 0] *= (1.0 - jc)
        out[sel] = o
    return out


def slim(P=None, parts="neck"):
    P = P or PARAMS
    global PARTS_ON_PARKA
    PARTS_ON_PARKA = PARTS_ON_PARKA_ALL if parts == "all" else ["Mani_parka_neckband", "Mani_parka_hood"]
    hood, parka, jeans = Garment("Mani_hoodie"), Garment("Mani_parka"), Garment("Mani_jeans")
    _CY_REF.clear(); _CY_REF["ref"] = torso_cy(parka)
    newp = top_transform(parka, P)
    hood.write(top_transform(hood, P, extra=P["hood"]))
    parka.write(newp)
    jeans.write(jeans_transform(jeans, P))
    if parts:
        disp = newp - parka.co
        kd = kdtree.KDTree(len(parka.co))
        for i, p in enumerate(parka.co):
            kd.insert(Vector(p), i)
        kd.balance()
        for name in PARTS_ON_PARKA:
            if name not in bpy.data.objects:
                continue
            g = Garment(name)
            out = g.co.copy()
            for i, p in enumerate(g.co):
                dv = np.zeros(3); ws = 0.0
                for co_, j, dist in kd.find_n(Vector(p), 4):
                    w = 1.0 / (dist + 0.01); dv += disp[j] * w; ws += w
                out[i] = p + dv / ws
            if name in ("Mani_parka_neckband", "Mani_parka_hood"):
                hs = P.get("hood_s", 1.0)
                out[:, 0] *= hs
                out[:, 1] = -0.005 + (out[:, 1] + 0.005) * hs
            g.write(out)
    return parka


def stats():
    rest_pose()
    for name in ("Mani_hoodie", "Mani_parka", "Mani_jeans"):
        g = Garment(name)
        z = g.co[:, 2]
        log(name, {round(b, 2): (round(float(np.abs(g.co[(z >= b) & (z < b + 0.1) & (g.arm < 0.3), 0]).max()), 3),
                                 round(float(g.co[(z >= b) & (z < b + 0.1) & (g.arm < 0.3), 1].min()), 3),
                                 round(float(g.co[(z >= b) & (z < b + 0.1) & (g.arm < 0.3), 1].max()), 3))
                   for b in np.arange(0.2, 1.5, 0.1) if ((z >= b) & (z < b + 0.1) & (g.arm < 0.3)).any()})


# --------------------------------------------------------------------------------------------- measurement
BANDS = 5


def eval_positions():
    dg = bpy.context.evaluated_depsgraph_get()
    cs = []
    for o in meshes():
        if o.hide_render:
            continue
        e = o.evaluated_get(dg)
        mw = e.matrix_world
        cs += [mw @ Vector(c) for c in e.bound_box]
    lo = Vector([min(c[i] for c in cs) for i in range(3)])
    hi = Vector([max(c[i] for c in cs) for i in range(3)])
    return lo, hi


def render_sil(view, path, res=768):
    sc = bpy.context.scene
    lo, hi = eval_positions()
    ctr, H = (lo + hi) / 2, hi.z - lo.z
    cam = bpy.data.objects.get("_fit_cam")
    if cam is None:
        cam = bpy.data.objects.new("_fit_cam", bpy.data.cameras.new("_fit_cam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.type = "ORTHO"
    offset, rot = {
        "front": (Vector((0, -3 * H, 0)), (math.pi / 2, 0, 0)),
        "back": (Vector((0, 3 * H, 0)), (math.pi / 2, 0, math.pi)),
        "left": (Vector((-3 * H, 0, 0)), (math.pi / 2, 0, -math.pi / 2)),
        "right": (Vector((3 * H, 0, 0)), (math.pi / 2, 0, math.pi / 2)),
    }[view]
    cam.location = ctr + offset
    cam.rotation_euler = rot
    bpy.context.view_layer.update()
    inv = cam.matrix_world.inverted()
    corners = [inv @ Vector((x, y, z)) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    xs, ys = [c.x for c in corners], [c.y for c in corners]
    cam.data.ortho_scale = max(max(xs) - min(xs), max(ys) - min(ys)) * 1.04
    shift = cam.matrix_world.to_3x3() @ Vector(((max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2, 0))
    cam.location = cam.location + shift
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.film_transparent = True
    sc.render.resolution_x = sc.render.resolution_y = res
    sc.render.image_settings.color_mode = "RGBA"
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


def load_rgba(path):
    im = bpy.data.images.load(path, check_existing=False)
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(im)
    m = a[..., 3] > 0.5
    ys, xs = np.where(m)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def fit_h(a, H):
    h, w = a.shape[:2]
    W = max(1, round(w * H / h))
    return a[(np.arange(H) * h / H).astype(int)][:, (np.arange(W) * w / W).astype(int)]


def pad_to(a, W):
    d = W - a.shape[1]
    return np.pad(a, ((0, 0), (d // 2, d - d // 2)))


def row_widths(m):
    return np.array([(np.ptp(np.where(r)[0]) + 1) if r.any() else 0 for r in m], float)


def measure(views, refdir, tag=""):
    res = {}
    for view in views:
        panel = {"front": "front", "left": "side", "back": "back"}.get(view, view)
        p = os.path.join(SCRATCH, "_sil_%s.png" % panel)
        render_sil(SIDE_VIEW if panel == "side" else panel, p)
        ref = load_rgba(os.path.join(refdir, panel, "reference_%s.png" % panel))
        H = ref.shape[0]
        mod = fit_h(load_rgba(p), H)
        W = max(ref.shape[1], mod.shape[1])
        R, M = pad_to(ref[..., 3] > 0.5, W), pad_to(mod[..., 3] > 0.5, W)
        iou = float((R & M).sum() / (R | M).sum())
        rw, mw = row_widths(R), row_widths(M)
        bands = []
        for i in range(BANDS):
            s = slice(i * H // BANDS, (i + 1) * H // BANDS)
            bi = (R[s] & M[s]).sum() / max((R[s] | M[s]).sum(), 1)
            bands.append((round(float(bi), 3), round(float((mw[s].mean() - rw[s].mean()) / rw[s].mean()), 3)))
        res[panel] = (round(iou, 4), bands)
        if panel == "side":
            # diagnostics (NOT the official number): align on the body instead of the bounding box, then drop the
            # sheet pixels behind the model's back edge (the backpack)
            best = (iou, 0)
            for dx in range(-90, 91, 2):
                M2 = np.roll(M, dx, axis=1)
                if dx > 0: M2[:, :dx] = False
                elif dx < 0: M2[:, dx:] = False
                v = (R & M2).sum() / (R | M2).sum()
                if v > best[0]: best = (float(v), dx)
            dx = best[1]
            M2 = np.roll(M, dx, axis=1)
            facing_left = True
            keep = np.ones_like(R)
            for r in range(H):
                xs = np.where(M2[r])[0]
                if len(xs):
                    keep[r, xs.max() + 1:] = False        # model faces left: its back is its right edge
            iou_c = float((R & M2 & keep).sum() / ((R | M2) & keep).sum())
            log("side diagnostics: shift %+d px -> IoU %.4f ; plus backpack removed -> %.4f (official %.4f)" % (dx, best[0], iou_c, iou))
        ov = np.zeros(R.shape + (3,), np.float32)
        ov[..., 0] = R & ~M; ov[..., 1] = M & ~R; ov[..., 2] = M & ~R
        ov[R & M] = (0.95, 0.85, 0.95)
        img = bpy.data.images.new("ov", W, H, alpha=False)
        rgba = np.concatenate([ov, np.ones(R.shape + (1,), np.float32)], -1)[::-1]
        img.pixels = rgba.ravel().tolist()
        img.filepath_raw = os.path.join(SCRATCH, "q_%s%s.png" % (panel, tag))
        img.file_format = "PNG"
        img.save()
        bpy.data.images.remove(img)
    for k, (iou, b) in res.items():
        log("IOU %-5s %.4f   bands(iou,widthdiff) %s" % (k, iou, b))
    return res


# --------------------------------------------------------------------------------------------- export
def bake_apose_glb(path):
    apose()
    dg = bpy.context.evaluated_depsgraph_get()
    bpy.ops.object.select_all(action="DESELECT")
    keep = []
    for o in list(meshes()):
        e = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(e)
        n = bpy.data.objects.new(o.name + "_ap", me)
        n.matrix_world = e.matrix_world.copy()
        for m in o.data.materials:
            n.data.materials.append(m)
        bpy.context.scene.collection.objects.link(n)
        n.hide_render = o.hide_render
        keep.append(n)
    for o in list(meshes()):
        if o not in keep:
            o.hide_set(True); o.hide_viewport = True
    RIG.hide_set(True)
    for n in keep:
        n.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
                              export_apply=False, export_animations=False, export_skins=False,
                              export_image_format="AUTO", export_materials="EXPORT", export_cameras=False, export_lights=False)
    log("wrote", path, "%.1f MB" % (os.path.getsize(path) / 1e6))


def export_game():
    if RIG.animation_data is None:
        RIG.animation_data_create()
    RIG.animation_data.action = bpy.data.actions["idle"]
    for pb in RIG.pose.bones:
        pb.rotation_mode = "QUATERNION"
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.data.objects:
        if o.type in ("MESH", "ARMATURE") and not o.name.startswith("_"):
            o.select_set(True)
    bpy.context.view_layer.objects.active = RIG
    bpy.context.scene.render.fps = 30
    bpy.ops.export_scene.gltf(
        filepath=OUT_GLB, export_format="GLB", use_selection=True, export_yup=True, export_apply=False,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_skins=True, export_image_format="AUTO", export_materials="EXPORT",
        export_cameras=False, export_lights=False)
    log("exported", OUT_GLB, "%.1f MB" % (os.path.getsize(OUT_GLB) / 1e6))


# --------------------------------------------------------------------------------------------- optimiser
_REFS = {}


def score(views=("front", "side", "back"), res=512, refdir=None):
    refdir = refdir or os.path.join(SCRATCH, "base")
    out = {}
    for panel in views:
        p = os.path.join(SCRATCH, "_sil_%s.png" % panel)
        render_sil(SIDE_VIEW if panel == "side" else panel, p, res)
        if panel not in _REFS:
            _REFS[panel] = load_rgba(os.path.join(refdir, panel, "reference_%s.png" % panel))
        ref = _REFS[panel]
        H = ref.shape[0]
        mod = fit_h(load_rgba(p), H)
        W = max(ref.shape[1], mod.shape[1])
        R, M = pad_to(ref[..., 3] > 0.5, W), pad_to(mod[..., 3] > 0.5, W)
        out[panel] = float((R & M).sum() / (R | M).sum())
    return out


VEC = [("tx", 5, 0.70, 1.0), ("ty", 5, 0.70, 1.0), ("sl", 3, 0.80, 1.0), ("hood_s", 1, 1.0, 1.001), ("jx", 5, 0.70, 1.0), ("jy", 5, 0.70, 1.0), ("jc", 5, 0.0, 0.14)]
POSE_VEC = [("arm_deg", 10.0, 24.0), ("fore_extra_deg", 0.0, 26.0)]


def flat(P):
    return [x for k, n, lo, hi in VEC for x in np.atleast_1d(P[k])] + [POSE[k] for k, lo, hi in POSE_VEC]


def unflat(v):
    P = dict(PARAMS); i = 0
    for k, n, lo, hi in VEC:
        P[k] = list(v[i:i + n]) if n > 1 or k != "hood_s" else float(v[i]); i += n
    for k, lo, hi in POSE_VEC:
        P[k] = float(v[i]); i += 1
    return P


def objective(v, w_side=0.0, reg=0.03):
    P = unflat(v)
    for k, lo, hi in POSE_VEC:
        POSE[k] = P[k]
    apose()
    slim(P)
    sc = score()
    smooth = 0.0
    for k, n, lo, hi in VEC:
        x = np.atleast_1d(np.array(P[k])); smooth += float(np.sum(np.diff(x) ** 2))
    return (sc["front"] + sc["back"] + w_side * sc["side"]) / (2 + w_side) - reg * smooth, sc


def optimise(iters=3):
    v = np.array(flat(PARAMS))
    best, sc = objective(v)
    log("start %.4f" % best, sc)
    lo = np.array([lo for k, n, lo, hi in VEC for _ in range(n)])
    hi = np.array([hi for k, n, lo, hi in VEC for _ in range(n)])
    lo = np.concatenate([lo, [l for k, l, h in POSE_VEC]]); hi = np.concatenate([hi, [h for k, l, h in POSE_VEC]])
    scale = np.array([1.0] * (len(lo) - 2) + [30.0, 30.0])      # pose steps are in degrees
    for step in (0.06, 0.03, 0.015)[:iters]:
        improved = True
        while improved:
            improved = False
            for i in range(len(v)):
                for d in (+step, -step):
                    t = v.copy(); t[i] = np.clip(t[i] + d * scale[i], lo[i], hi[i])
                    if t[i] == v[i]:
                        continue
                    f, s2 = objective(t)
                    if f > best + 1e-5:
                        best, v, sc = f, t, s2
                        improved = True
                        break
            log("step %.3f obj %.4f %s params %s" % (step, best, {k: round(x, 3) for k, x in sc.items()}, json.dumps(unflat(v))))
            json.dump(unflat(v), open(os.path.join(SCRATCH, "params_best.json"), "w"))
    return unflat(v)


if __name__ == "__main__":
    views = OPT.get("--views", "front,side,back").split(",")
    refdir = OPT.get("--refdir", os.path.join(SCRATCH, "base"))
    if True:
        for k in POSE:
            if k in PARAMS:
                POSE[k] = PARAMS[k]
    if "--arm" in OPT:
        POSE["arm_deg"] = float(OPT["--arm"])
    if "--leg" in OPT:
        POSE["leg_deg"] = float(OPT["--leg"])
    if "--fore" in OPT:
        POSE["fore_extra_deg"] = float(OPT["--fore"])
    if CMD == "stats":
        stats()
    elif CMD == "measure":
        if "--slim" in OPT:
            slim(parts="all")
        apose()
        measure(views, refdir, OPT.get("--tag", ""))
    elif CMD == "opt":
        apose()
        optimise()
    elif CMD == "apose-glb":
        bake_apose_glb(OPT.get("--out", OUT_APOSE))
    elif CMD == "apply":
        slim(parts="all")
        if "--save" in OPT:
            export_game()
            bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)
            b1 = OUT_BLEND + "1"
            if os.path.exists(b1):
                os.remove(b1)
